"""
Jira issue changelog ingestion -> BigQuery (Cloud Run / Functions Framework)

Purpose
- Ingest Jira issue changelog histories so we can compute KPIs like:
  - P3 Defects Reopened
  - P9 Time to Triage
  - P11 SLA Compliance (needs first triage / resolution)
  - P39 Fix Verification Cycle Time (if you later map states)

Key fixes / gotchas addressed
- Uses Jira Cloud's newer /rest/api/3/search/jql endpoint (pagination via nextPageToken).
- Batches BigQuery streaming inserts by row-count + payload bytes (prevents 413 Request Entity Too Large).
- Compatible with Cloud Run secrets-as-env (gcloud run --set-secrets ...), because it reads auth from ENV.

Required env vars
- GCP_PROJECT_ID
- BQ_DATASET_ID (default: qa_metrics)
- BQ_TABLE_ID   (default: jira_changelog_v2)

Jira auth (either naming is accepted)
- Preferred (matches Secret names):
    JIRA_SITE, JIRA_USER, JIRA_API_TOKEN
- Also accepted (legacy):
    JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN

Project/field mapping
- TARGET_PROJECT_KEY (default: PC)

Optional env vars
- PAGE_SIZE (default: 50)                    # for /search/jql
- CHANGELOG_PAGE_SIZE (default: 100)         # for /issue/{key}/changelog
- DEFAULT_LOOKBACK_DAYS (default: 730)       # 2 years
- MAX_LOOKBACK_DAYS (default: 730)
- MAX_ISSUES_PER_RUN (default: 0)            # 0 = no limit (useful for debugging)
- BQ_INSERT_MAX_ROWS (default: 300)
- BQ_INSERT_MAX_BYTES (default: 8_000_000)
- REQUEST_TIMEOUT (default: 60)
"""

import os
import json
import time
import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple

import requests
from flask import jsonify
from google.cloud import bigquery


# ------------------------
# Config
# ------------------------
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET_ID = os.getenv("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.getenv("BQ_TABLE_ID", "jira_changelog_v2")

JIRA_SITE = os.getenv("JIRA_SITE") or os.getenv("JIRA_BASE_URL")
JIRA_USER = os.getenv("JIRA_USER") or os.getenv("JIRA_EMAIL")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")

TARGET_PROJECT_KEY = os.getenv("TARGET_PROJECT_KEY", "PC")

PAGE_SIZE = int(os.getenv("PAGE_SIZE", "50"))
CHANGELOG_PAGE_SIZE = int(os.getenv("CHANGELOG_PAGE_SIZE", "100"))

DEFAULT_LOOKBACK_DAYS = int(os.getenv("DEFAULT_LOOKBACK_DAYS", "730"))
MAX_LOOKBACK_DAYS = int(os.getenv("MAX_LOOKBACK_DAYS", "730"))

MAX_ISSUES_PER_RUN = int(os.getenv("MAX_ISSUES_PER_RUN", "0"))

BQ_INSERT_MAX_ROWS = int(os.getenv("BQ_INSERT_MAX_ROWS", "300"))
BQ_INSERT_MAX_BYTES = int(os.getenv("BQ_INSERT_MAX_BYTES", "8000000"))

REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "60"))


# ------------------------
# Helpers
# ------------------------
def _dt(ts: str) -> datetime.datetime:
    """Parse Jira datetime with timezone. Example: 2026-02-17T11:22:33.123+0000"""
    try:
        return datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S.%f%z")
    except ValueError:
        return datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S%z")


def _safe_json_size(obj: Any) -> int:
    return len(json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


def _chunk_rows(rows: List[Dict[str, Any]], max_rows: int, max_bytes: int) -> Iterable[List[Dict[str, Any]]]:
    batch: List[Dict[str, Any]] = []
    batch_bytes = 0

    for r in rows:
        r_bytes = _safe_json_size(r)

        if batch and (len(batch) >= max_rows or batch_bytes + r_bytes > max_bytes):
            yield batch
            batch = []
            batch_bytes = 0

        batch.append(r)
        batch_bytes += r_bytes

        if len(batch) >= max_rows:
            yield batch
            batch = []
            batch_bytes = 0

    if batch:
        yield batch


def _jira_headers() -> Dict[str, str]:
    import base64
    token = base64.b64encode(f"{JIRA_USER}:{JIRA_API_TOKEN}".encode("utf-8")).decode("utf-8")
    return {
        "Authorization": f"Basic {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def _bq_client() -> bigquery.Client:
    if not GCP_PROJECT_ID:
        raise RuntimeError("Missing env var: GCP_PROJECT_ID")
    return bigquery.Client(project=GCP_PROJECT_ID)


# ------------------------
# BigQuery
# ------------------------
def ensure_table() -> None:
    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"

    schema = [
        bigquery.SchemaField("issue_key", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("project_key", "STRING"),
        bigquery.SchemaField("history_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("history_created", "TIMESTAMP"),
        bigquery.SchemaField("author", "STRING"),
        bigquery.SchemaField("items_json", "STRING"),  # JSON array of changelog items
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    table = bigquery.Table(table_fq, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY, field="history_created")
    table.clustering_fields = ["project_key", "issue_key", "history_id", "author"]  # max 4

    bq.create_table(table, exists_ok=True)


def insert_rows(rows: List[Dict[str, Any]]) -> Tuple[int, List[Any]]:
    if not rows:
        return 0, []

    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"

    inserted = 0
    all_errors: List[Any] = []

    for chunk in _chunk_rows(rows, max_rows=BQ_INSERT_MAX_ROWS, max_bytes=BQ_INSERT_MAX_BYTES):
        row_ids = [f'{r.get("issue_key","")}:{r.get("history_id","")}' for r in chunk]
        errors = bq.insert_rows_json(table_fq, chunk, row_ids=row_ids)
        if errors:
            all_errors.extend(errors)
        else:
            inserted += len(chunk)

    return inserted, all_errors


# ------------------------
# Jira fetch: list issue keys via /search/jql
# ------------------------
def fetch_issue_keys(project_key: str, since_ts: datetime.datetime, until_ts: datetime.datetime) -> Iterable[str]:
    if not (JIRA_SITE and JIRA_USER and JIRA_API_TOKEN):
        raise RuntimeError("Missing Jira env vars: JIRA_SITE / JIRA_USER / JIRA_API_TOKEN")

    since_s = since_ts.strftime("%Y/%m/%d %H:%M")
    until_s = until_ts.strftime("%Y/%m/%d %H:%M")
    jql = (
        f'project = "{project_key}" '
        f'AND updated >= "{since_s}" '
        f'AND updated <= "{until_s}" '
        f'ORDER BY updated ASC'
    )

    url = f"{JIRA_SITE.rstrip('/')}/rest/api/3/search/jql"
    next_page_token = None
    seen_tokens = set()
    page_num = 0
    yielded = 0

    while True:
        page_num += 1
        params = {
            "jql": jql,
            "maxResults": PAGE_SIZE,
            "fields": "updated",  # minimal
        }
        if next_page_token:
            params["nextPageToken"] = next_page_token

        resp = requests.get(url, headers=_jira_headers(), params=params, timeout=REQUEST_TIMEOUT)
        if resp.status_code >= 400:
            raise RuntimeError(f"Jira API error {resp.status_code}: {resp.text[:800]}")

        data = resp.json()
        issues = data.get("issues", []) or []
        is_last = bool(data.get("isLast", False))
        new_token = data.get("nextPageToken")

        print(f"[search/jql] page={page_num} issues={len(issues)} is_last={is_last}")

        for issue in issues:
            key = issue.get("key")
            if key:
                yield key
                yielded += 1
                if MAX_ISSUES_PER_RUN and yielded >= MAX_ISSUES_PER_RUN:
                    print(f"[search/jql] max issues reached ({MAX_ISSUES_PER_RUN}), stopping early")
                    return

        if is_last or not issues:
            break

        if not new_token:
            raise RuntimeError("Jira search/jql: missing nextPageToken but isLast=false (pagination would loop)")

        if new_token in seen_tokens:
            raise RuntimeError("Jira pagination loop detected (nextPageToken repeated)")
        seen_tokens.add(new_token)

        next_page_token = new_token
        time.sleep(0.1)


# ------------------------
# Jira fetch: per-issue changelog
# ------------------------
def fetch_issue_changelog(issue_key: str) -> List[Dict[str, Any]]:
    base = JIRA_SITE.rstrip("/")
    url = f"{base}/rest/api/3/issue/{issue_key}/changelog"

    start_at = 0
    rows: List[Dict[str, Any]] = []
    ingested_at = datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

    while True:
        params = {"startAt": start_at, "maxResults": CHANGELOG_PAGE_SIZE}
        resp = requests.get(url, headers=_jira_headers(), params=params, timeout=REQUEST_TIMEOUT)
        if resp.status_code >= 400:
            raise RuntimeError(f"Jira changelog error {resp.status_code} for {issue_key}: {resp.text[:800]}")

        data = resp.json()
        values = data.get("values", []) or []
        total = data.get("total")
        is_last = bool(data.get("isLast", False))

        for h in values:
            hist_id = str(h.get("id") or "")
            created = h.get("created")
            author = ((h.get("author") or {}).get("displayName") or None)

            items = h.get("items") or []
            items_json = json.dumps(items, ensure_ascii=False, separators=(",", ":"))
            if len(items_json) > 50000:
                items_json = items_json[:50000]

            rows.append({
                "issue_key": issue_key,
                "project_key": issue_key.split("-")[0] if "-" in issue_key else None,
                "history_id": hist_id,
                "history_created": _dt(created).isoformat() if created else None,
                "author": author,
                "items_json": items_json,
                "_ingested_at": ingested_at,
            })

        if is_last:
            break

        start_at += len(values)
        if total is not None and start_at >= int(total):
            break

        if not values:
            break

        time.sleep(0.1)

    return rows


# ------------------------
# Cloud Run entrypoint
# ------------------------
def hello_http(request):
    try:
        ensure_table()

        body = request.get_json(silent=True) or {}
        project_key = body.get("project_key") or body.get("project") or TARGET_PROJECT_KEY
        if not isinstance(project_key, str) or not project_key.strip():
            raise RuntimeError("Pass a string for project_key/project")

        dry_run = bool(body.get("dry_run", False))
        debug = bool(body.get("debug", False))

        now = datetime.datetime.now(datetime.timezone.utc)

        lookback_days = int(body.get("lookback_days", DEFAULT_LOOKBACK_DAYS))
        lookback_days = min(lookback_days, MAX_LOOKBACK_DAYS)

        since_ts = now - datetime.timedelta(days=lookback_days)
        until_ts = now

        if body.get("since_ts"):
            since_ts = datetime.datetime.fromisoformat(body["since_ts"])
            if since_ts.tzinfo is None:
                since_ts = since_ts.replace(tzinfo=datetime.timezone.utc)
        if body.get("until_ts"):
            until_ts = datetime.datetime.fromisoformat(body["until_ts"])
            if until_ts.tzinfo is None:
                until_ts = until_ts.replace(tzinfo=datetime.timezone.utc)

        # clamp to max lookback
        min_since = now - datetime.timedelta(days=lookback_days)
        if since_ts < min_since:
            since_ts = min_since

        if debug:
            # sanity check: list 1 issue key and fetch 1 changelog page
            keys = []
            for k in fetch_issue_keys(project_key, since_ts, until_ts):
                keys.append(k)
                break
            if not keys:
                return jsonify({"status": "DEBUG", "message": "No issues found in window", "project_key": project_key}), 200

            sample_key = keys[0]
            sample_rows = fetch_issue_changelog(sample_key)[:5]
            return jsonify({
                "status": "DEBUG",
                "project_key": project_key,
                "since_ts": since_ts.isoformat(),
                "until_ts": until_ts.isoformat(),
                "sample_issue_key": sample_key,
                "sample_rows": sample_rows,
            }), 200

        pages_processed = 0
        total_histories = 0
        inserted = 0
        all_errors: List[Any] = []

        # iterate issue keys; each key we treat as one "page" for metrics
        for issue_key in fetch_issue_keys(project_key, since_ts, until_ts):
            pages_processed += 1

            rows = fetch_issue_changelog(issue_key)
            total_histories += len(rows)

            if not dry_run:
                ins, errs = insert_rows(rows)
                inserted += ins
                if errs:
                    all_errors.extend(errs)

        status = "OK" if not all_errors else "PARTIAL"
        return jsonify({
            "status": status,
            "project_key": project_key,
            "since_ts": since_ts.isoformat(),
            "until_ts": until_ts.isoformat(),
            "issues_processed": pages_processed,
            "histories_fetched": total_histories,
            "rows_inserted": inserted,
            "errors": all_errors[:50],
        }), (200 if status == "OK" else 207)

    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500
