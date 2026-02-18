"""Jira changelog ingestion -> BigQuery (status transitions only)

Fixes vs previous version:
- Inserts are batched by BOTH row-count and payload bytes to avoid BigQuery 413.
- Only stores status transition items (dramatically smaller than full changelog).
- Adds (and uses) issue_updated watermark (safe even if table existed before).
- Streams inserts; no giant in-memory list.

This powers KPIs like triage time, reopen rate, verification cycle time, etc.
"""

import os
import json
import time
import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple

import requests
from flask import jsonify

from google.cloud import bigquery


GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET_ID = os.getenv("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.getenv("BQ_TABLE_ID", "jira_changelog")

JIRA_BASE_URL = os.getenv("JIRA_BASE_URL")
JIRA_EMAIL = os.getenv("JIRA_EMAIL")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")

TARGET_PROJECT_KEY = os.getenv("TARGET_PROJECT_KEY", "PC")

PAGE_SIZE = int(os.getenv("PAGE_SIZE", "50"))
DEFAULT_LOOKBACK_DAYS = int(os.getenv("DEFAULT_LOOKBACK_DAYS", "120"))

BQ_INSERT_MAX_ROWS = int(os.getenv("BQ_INSERT_MAX_ROWS", "200"))
BQ_INSERT_MAX_BYTES = int(os.getenv("BQ_INSERT_MAX_BYTES", "8000000"))

REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "60"))


def _dt(ts: str) -> datetime.datetime:
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

    token = base64.b64encode(f"{JIRA_EMAIL}:{JIRA_API_TOKEN}".encode("utf-8")).decode("utf-8")
    return {
        "Authorization": f"Basic {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def _bq_client() -> bigquery.Client:
    return bigquery.Client(project=GCP_PROJECT_ID)


def ensure_table() -> None:
    """Create jira_changelog table if missing, and ensure issue_updated exists."""
    bq = _bq_client()
    dataset_ref = bigquery.DatasetReference(GCP_PROJECT_ID, BQ_DATASET_ID)
    table_ref = dataset_ref.table(BQ_TABLE_ID)

    schema = [
        bigquery.SchemaField("issue_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("issue_key", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("history_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("history_created", "TIMESTAMP"),
        bigquery.SchemaField("author_display_name", "STRING"),
        bigquery.SchemaField("author_account_id", "STRING"),
        bigquery.SchemaField("items_json", "STRING"),
        bigquery.SchemaField("payload", "STRING"),
        bigquery.SchemaField("issue_updated", "TIMESTAMP"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    table = bigquery.Table(table_ref, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY, field="history_created")
    table.clustering_fields = ["issue_key", "history_id"]

    bq.create_table(table, exists_ok=True)

    # If table existed previously without the new column, add it (safe)
    bq.query(
        f"ALTER TABLE `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}` ADD COLUMN IF NOT EXISTS issue_updated TIMESTAMP"
    ).result()


def get_last_issue_updated_ts() -> Optional[datetime.datetime]:
    bq = _bq_client()
    query = f"""
      SELECT
        MAX(issue_updated) AS max_issue_updated,
        MAX(history_created) AS max_history_created
      FROM `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}`
    """
    rows = list(bq.query(query).result())
    if not rows:
        return None

    max_issue_updated = rows[0]["max_issue_updated"]
    max_history_created = rows[0]["max_history_created"]

    return max_issue_updated or max_history_created


def insert_rows(rows: List[Dict[str, Any]]) -> Tuple[int, List[Any]]:
    if not rows:
        return 0, []

    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"

    inserted = 0
    all_errors: List[Any] = []

    for chunk in _chunk_rows(rows, max_rows=BQ_INSERT_MAX_ROWS, max_bytes=BQ_INSERT_MAX_BYTES):
        row_ids = []
        for r in chunk:
            row_ids.append(f"{r.get('issue_key','')}:{r.get('history_id','')}")

        errors = bq.insert_rows_json(table_fq, chunk, row_ids=row_ids)
        if errors:
            all_errors.extend(errors)
        else:
            inserted += len(chunk)

    return inserted, all_errors


# ------------------------
# Jira fetch
# ------------------------

def fetch_issue_keys(project_key: str, since_ts: datetime.datetime, until_ts: datetime.datetime) -> Iterable[List[Dict[str, Any]]]:
    """Yield pages of issue stubs {id,key,updated} ordered by updated ASC."""

    since_s = since_ts.strftime("%Y/%m/%d %H:%M")
    until_s = until_ts.strftime("%Y/%m/%d %H:%M")

    jql = (
        f'project = "{project_key}" '
        f'AND updated >= "{since_s}" '
        f'AND updated <= "{until_s}" '
        f'ORDER BY updated ASC'
    )

    # NEW endpoint
    url = f"{JIRA_BASE_URL.rstrip('/')}/rest/api/3/search/jql"

    next_page_token: Optional[str] = None
    seen_tokens: set[str] = set()

    while True:
        body = {
            "jql": jql,
            "maxResults": PAGE_SIZE,
            "fields": ["updated"],
        }
        if next_page_token:
            body["nextPageToken"] = next_page_token

        resp = requests.post(url, headers=_jira_headers(), json=body, timeout=REQUEST_TIMEOUT)
        if resp.status_code >= 400:
            raise RuntimeError(f"Jira API error {resp.status_code}: {resp.text[:800]}")

        data = resp.json()
        issues = data.get("issues", []) or []
        if not issues:
            break

        stubs: List[Dict[str, Any]] = []
        for issue in issues:
            stubs.append(
                {
                    "id": issue.get("id"),
                    "key": issue.get("key"),
                    "updated": (issue.get("fields") or {}).get("updated"),
                }
            )

        yield stubs

        # Pagination for /search/jql
        if data.get("isLast") is True:
            break

        next_page_token = data.get("nextPageToken")
        if not next_page_token:
            break

        # Safety guard against pagination loops
        if next_page_token in seen_tokens:
            raise RuntimeError("Pagination loop detected in Jira /search/jql (repeated nextPageToken).")
        seen_tokens.add(next_page_token)

        time.sleep(0.1)


def fetch_issue_changelog(issue_id: str) -> Dict[str, Any]:
    base_url = f"{JIRA_BASE_URL.rstrip('/')}/rest/api/3/issue/{issue_id}/changelog"

    start_at = 0
    max_results = 100  # Jira commonly supports up to 100 here
    all_values: List[Dict[str, Any]] = []

    while True:
        resp = requests.get(
            base_url,
            headers=_jira_headers(),
            params={"startAt": start_at, "maxResults": max_results},
            timeout=REQUEST_TIMEOUT,
        )
        if resp.status_code >= 400:
            raise RuntimeError(f"Changelog fetch error {resp.status_code} for issue_id={issue_id}: {resp.text[:300]}")

        data = resp.json()
        values = data.get("values", []) or []
        all_values.extend(values)

        if data.get("isLast") is True or not values:
            break

        start_at += len(values)
        time.sleep(0.05)

    return {"values": all_values}



def extract_status_histories(changelog_json: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Return list of histories containing ONLY status-change items."""
    histories = changelog_json.get("values") or changelog_json.get("histories") or []
    out: List[Dict[str, Any]] = []

    for h in histories:
        items = h.get("items") or []
        status_items = [it for it in items if (it.get("field") == "status")]
        if not status_items:
            continue

        h2 = dict(h)
        h2["items"] = status_items
        out.append(h2)

    return out


# ------------------------
# Entrypoint
# ------------------------

def hello_http(request):
    try:
        ensure_table()

        if not (JIRA_BASE_URL and JIRA_EMAIL and JIRA_API_TOKEN):
            raise RuntimeError("Missing Jira env vars: JIRA_BASE_URL / JIRA_EMAIL / JIRA_API_TOKEN")

        body = request.get_json(silent=True) or {}

        project_key = body.get("project_key") or TARGET_PROJECT_KEY
        dry_run = bool(body.get("dry_run", False))

        now = datetime.datetime.now(datetime.timezone.utc)

        since_ts: Optional[datetime.datetime] = None
        until_ts: Optional[datetime.datetime] = None

        if body.get("since_ts"):
            since_ts = datetime.datetime.fromisoformat(body["since_ts"])
            if since_ts.tzinfo is None:
                since_ts = since_ts.replace(tzinfo=datetime.timezone.utc)
        if body.get("until_ts"):
            until_ts = datetime.datetime.fromisoformat(body["until_ts"])
            if until_ts.tzinfo is None:
                until_ts = until_ts.replace(tzinfo=datetime.timezone.utc)

        lookback_days = int(body.get("lookback_days", DEFAULT_LOOKBACK_DAYS))

        if since_ts is None:
            last_ts = get_last_issue_updated_ts()
            if last_ts is not None:
                since_ts = last_ts - datetime.timedelta(days=2)
            else:
                since_ts = now - datetime.timedelta(days=lookback_days)

            # clamp
            min_since = now - datetime.timedelta(days=lookback_days)
            if since_ts < min_since:
                since_ts = min_since

        if until_ts is None:
            until_ts = now

        issues_seen = 0
        histories_seen = 0
        inserted_rows = 0
        all_errors: List[Any] = []
        pages = 0

        for issue_page in fetch_issue_keys(project_key, since_ts, until_ts):
            pages += 1

            rows_to_insert: List[Dict[str, Any]] = []
            ingested_at = datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

            for stub in issue_page:
                issues_seen += 1
                issue_id = stub["id"]
                issue_key = stub["key"]
                issue_updated = stub.get("updated")

                cj = fetch_issue_changelog(issue_id)
                status_histories = extract_status_histories(cj)

                for h in status_histories:
                    histories_seen += 1
                    row = {
                        "issue_id": issue_id,
                        "issue_key": issue_key,
                        "history_id": str(h.get("id")),
                        "history_created": _dt(h["created"]).isoformat() if h.get("created") else None,
                        "author_display_name": ((h.get("author") or {}).get("displayName")),
                        "author_account_id": ((h.get("author") or {}).get("accountId")),
                        "items_json": json.dumps(h.get("items") or [], ensure_ascii=False),
                        "payload": None,
                        "issue_updated": _dt(issue_updated).isoformat() if issue_updated else None,
                        "_ingested_at": ingested_at,
                    }
                    rows_to_insert.append(row)

                # Avoid hammering Jira too hard
                time.sleep(0.05)

            if not dry_run:
                ins, errs = insert_rows(rows_to_insert)
                inserted_rows += ins
                if errs:
                    all_errors.extend(errs)

        status = "OK" if not all_errors else "PARTIAL"
        resp = {
            "status": status,
            "project_key": project_key,
            "since_ts": since_ts.isoformat(),
            "until_ts": until_ts.isoformat(),
            "pages_processed": pages,
            "issues_seen": issues_seen,
            "status_histories_seen": histories_seen,
            "rows_inserted": inserted_rows,
            "errors": all_errors[:50],
        }
        code = 200 if status == "OK" else 207
        return jsonify(resp), code

    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500
