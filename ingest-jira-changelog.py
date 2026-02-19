"""
Jira issue changelog ingestion -> BigQuery (Cloud Run / Functions Framework)

Purpose
- Ingest Jira issue changelog histories so we can compute KPIs like:
  - P3 Defects Reopened
  - P9 Time to Triage
  - P11 SLA Compliance (needs first triage / resolution)
  - P39 Fix Verification Cycle Time

Key behavior
- Uses Jira Cloud /rest/api/3/search/jql (pagination via nextPageToken).
- Fetches per-issue changelog via /rest/api/3/issue/{key}/changelog.
- BigQuery streaming inserts with chunking (row-count + bytes).
- Robust against Jira rate limits / transient 5xx (retries + backoff).
- Per-issue error isolation: one failing issue doesn't kill the run.
- Optional incremental mode (watermark): uses MAX(history_created) as since_ts.

Required env vars
- GCP_PROJECT_ID
- BQ_DATASET_ID (default: qa_metrics)
- BQ_TABLE_ID   (default: jira_changelog_v2)

Jira auth (either naming is accepted)
- Preferred:
    JIRA_SITE, JIRA_USER, JIRA_API_TOKEN
- Also accepted:
    JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN

Optional env vars
- TARGET_PROJECT_KEY (default: PC)
- PAGE_SIZE (default: 50)
- CHANGELOG_PAGE_SIZE (default: 100)
- DEFAULT_LOOKBACK_DAYS (default: 730)
- MAX_LOOKBACK_DAYS (default: 730)
- MAX_ISSUES_PER_RUN (default: 0)         # 0 = no limit
- REQUEST_TIMEOUT (default: 60)
- MAX_RETRIES (default: 6)
- BASE_BACKOFF (default: 1.0)
- MAX_BACKOFF (default: 30.0)
- MAX_RUNTIME_SECONDS (default: 3300)     # keep below Cloud Run max
- OVERLAP_DAYS (default: 2)
- USE_WATERMARK_DEFAULT (default: true)

Request body (JSON)
- project_key / project: string
- debug: bool
- dry_run: bool
- lookback_days: int
- since_ts / until_ts: ISO datetime
- use_watermark: bool  (if true and no since/lookback provided -> use BQ watermark)
"""

import os
import json
import time
import random
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

MAX_ISSUES_PER_RUN = int(os.getenv("MAX_ISSUES_PER_RUN", "0"))  # 0 = no limit

BQ_INSERT_MAX_ROWS = int(os.getenv("BQ_INSERT_MAX_ROWS", "300"))
BQ_INSERT_MAX_BYTES = int(os.getenv("BQ_INSERT_MAX_BYTES", "8000000"))

REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "60"))

MAX_RETRIES = int(os.getenv("MAX_RETRIES", "6"))
BASE_BACKOFF = float(os.getenv("BASE_BACKOFF", "1.0"))
MAX_BACKOFF = float(os.getenv("MAX_BACKOFF", "30.0"))

MAX_RUNTIME_SECONDS = int(os.getenv("MAX_RUNTIME_SECONDS", "3300"))
OVERLAP_DAYS = int(os.getenv("OVERLAP_DAYS", "2"))

USE_WATERMARK_DEFAULT = os.getenv("USE_WATERMARK_DEFAULT", "true").lower() in ("1", "true", "yes", "y")


# ------------------------
# Helpers
# ------------------------
def _dt(ts: str) -> datetime.datetime:
    """
    Parse Jira datetime with timezone.
    Examples seen:
      - 2026-02-17T11:22:33.123+0000
      - 2026-02-17T11:22:33+0000
      - 2026-02-17T11:22:33.123Z
      - 2026-02-17T11:22:33+00:00
    """
    if not ts:
        raise ValueError("empty timestamp")

    s = ts.strip()

    # Normalize Z -> +0000
    if s.endswith("Z"):
        s = s[:-1] + "+0000"

    # Normalize +00:00 -> +0000 (remove colon)
    # also handles other offsets like +01:00
    if len(s) >= 6 and (s[-6] in ("+", "-")) and s[-3] == ":":
        s = s[:-3] + s[-2:]

    for fmt in ("%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return datetime.datetime.strptime(s, fmt)
        except ValueError:
            pass

    raise ValueError(f"Unparseable Jira datetime: {ts}")


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


def _utc_iso(dt: datetime.datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    dt = dt.astimezone(datetime.timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")


def request_with_retries(method: str, url: str, *, headers: Dict[str, str], params: Optional[Dict[str, Any]] = None) -> requests.Response:
    last_exc: Optional[Exception] = None
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.request(method, url, headers=headers, params=params, timeout=REQUEST_TIMEOUT)

            # Retry on rate limits / transient server errors
            if r.status_code in (429, 500, 502, 503, 504):
                retry_after = r.headers.get("Retry-After")
                if retry_after and retry_after.isdigit():
                    sleep_s = min(MAX_BACKOFF, float(retry_after))
                else:
                    backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
                    jitter = random.uniform(0, 0.25 * backoff)
                    sleep_s = backoff + jitter
                time.sleep(sleep_s)
                continue

            if r.status_code >= 400:
                raise requests.HTTPError(f"{r.status_code} {r.reason} for url: {r.url} :: {r.text[:800]}")

            return r

        except Exception as e:
            last_exc = e
            backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
            jitter = random.uniform(0, 0.25 * backoff)
            time.sleep(backoff + jitter)

    raise RuntimeError(f"HTTP failed after retries: {last_exc}")


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
        bigquery.SchemaField("items_json", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    table = bigquery.Table(table_fq, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY, field="history_created")
    table.clustering_fields = ["project_key", "issue_key", "history_id", "author"]
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


def get_last_history_created(project_key: str) -> datetime.datetime:
    """
    Watermark: last ingested changelog timestamp for this project.
    If table empty -> now - 30d
    """
    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"

    sql = f"""
      SELECT COALESCE(MAX(history_created), TIMESTAMP('1970-01-01')) AS last_created
      FROM `{table_fq}`
      WHERE project_key = @project_key
    """
    job = bq.query(
        sql,
        job_config=bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("project_key", "STRING", project_key),
            ]
        ),
    )
    ts = list(job)[0]["last_created"]

    now = datetime.datetime.now(datetime.timezone.utc)

    if ts is None or getattr(ts, "year", 1970) == 1970:
        return now - datetime.timedelta(days=30)

    # BigQuery can return naive/aware depending on client; normalize to UTC
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=datetime.timezone.utc)
    else:
        ts = ts.astimezone(datetime.timezone.utc)

    return ts - datetime.timedelta(days=OVERLAP_DAYS)


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
            "fields": "updated",
        }
        if next_page_token:
            params["nextPageToken"] = next_page_token

        resp = request_with_retries("GET", url, headers=_jira_headers(), params=params)
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
    ingested_at = _utc_iso(datetime.datetime.now(datetime.timezone.utc))

    while True:
        params = {"startAt": start_at, "maxResults": CHANGELOG_PAGE_SIZE}
        resp = request_with_retries("GET", url, headers=_jira_headers(), params=params)
        data = resp.json()

        values = data.get("values", []) or []
        total = data.get("total")
        is_last = bool(data.get("isLast", False))

        for h in values:
            hist_id = h.get("id")
            if hist_id is None:
                continue
            hist_id = str(hist_id)

            created = h.get("created")
            author = ((h.get("author") or {}).get("displayName") or None)

            items = h.get("items") or []
            items_json = json.dumps(items, ensure_ascii=False, separators=(",", ":"))
            if len(items_json) > 50000:
                items_json = items_json[:50000]

            history_created = None
            if created:
                try:
                    history_created = _utc_iso(_dt(created))
                except Exception:
                    # keep row but leave timestamp null; don't crash the run
                    history_created = None

            rows.append({
                "issue_key": issue_key,
                "project_key": issue_key.split("-")[0] if "-" in issue_key else None,
                "history_id": hist_id,
                "history_created": history_created,
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
    started = time.monotonic()
    try:
        ensure_table()

        body = request.get_json(silent=True) or {}
        project_key = body.get("project_key") or body.get("project") or TARGET_PROJECT_KEY
        if not isinstance(project_key, str) or not project_key.strip():
            raise RuntimeError("Pass a string for project_key/project")

        dry_run = bool(body.get("dry_run", False))
        debug = bool(body.get("debug", False))

        now = datetime.datetime.now(datetime.timezone.utc)
        until_ts = now

        # Decide since_ts:
        # 1) explicit since_ts in body
        # 2) explicit lookback_days in body
        # 3) else (default) watermark mode if enabled
        use_watermark = bool(body.get("use_watermark", USE_WATERMARK_DEFAULT))

        since_ts: datetime.datetime
        if body.get("since_ts"):
            since_ts = datetime.datetime.fromisoformat(body["since_ts"])
            if since_ts.tzinfo is None:
                since_ts = since_ts.replace(tzinfo=datetime.timezone.utc)
        elif body.get("lookback_days") is not None:
            lookback_days = int(body.get("lookback_days", DEFAULT_LOOKBACK_DAYS))
            lookback_days = min(lookback_days, MAX_LOOKBACK_DAYS)
            since_ts = now - datetime.timedelta(days=lookback_days)
        elif use_watermark:
            since_ts = get_last_history_created(project_key)
        else:
            since_ts = now - datetime.timedelta(days=min(DEFAULT_LOOKBACK_DAYS, MAX_LOOKBACK_DAYS))

        if body.get("until_ts"):
            until_ts = datetime.datetime.fromisoformat(body["until_ts"])
            if until_ts.tzinfo is None:
                until_ts = until_ts.replace(tzinfo=datetime.timezone.utc)

        # Debug mode: return 1 sample issue + 5 rows
        if debug:
            keys = []
            for k in fetch_issue_keys(project_key, since_ts, until_ts):
                keys.append(k)
                break
            if not keys:
                return jsonify({
                    "status": "DEBUG",
                    "message": "No issues found in window",
                    "project_key": project_key,
                    "since_ts": _utc_iso(since_ts),
                    "until_ts": _utc_iso(until_ts),
                }), 200

            sample_key = keys[0]
            sample_rows = fetch_issue_changelog(sample_key)[:5]
            return jsonify({
                "status": "DEBUG",
                "project_key": project_key,
                "since_ts": _utc_iso(since_ts),
                "until_ts": _utc_iso(until_ts),
                "sample_issue_key": sample_key,
                "sample_rows": sample_rows,
            }), 200

        issues_processed = 0
        histories_fetched = 0
        rows_inserted = 0
        all_errors: List[Any] = []
        stopped_early = False

        for issue_key in fetch_issue_keys(project_key, since_ts, until_ts):
            # runtime guard
            if (time.monotonic() - started) > (MAX_RUNTIME_SECONDS - 10):
                stopped_early = True
                break

            issues_processed += 1
            try:
                rows = fetch_issue_changelog(issue_key)
                histories_fetched += len(rows)

                if not dry_run:
                    ins, errs = insert_rows(rows)
                    rows_inserted += ins
                    if errs:
                        all_errors.extend(errs)

            except Exception as e:
                all_errors.append({
                    "issue_key": issue_key,
                    "error": str(e)[:800],
                })
                continue

        status = "OK"
        if all_errors or stopped_early:
            status = "PARTIAL"

        return jsonify({
            "status": status,
            "project_key": project_key,
            "since_ts": _utc_iso(since_ts),
            "until_ts": _utc_iso(until_ts),
            "issues_processed": issues_processed,
            "histories_fetched": histories_fetched,
            "rows_inserted": rows_inserted,
            "stopped_early": stopped_early,
            "runtime_seconds": round(time.monotonic() - started, 2),
            "errors": all_errors[:50],
        }), (200 if status == "OK" else 207)

    except Exception as e:
        return jsonify({
            "status": "ERROR",
            "error": str(e)[:1200],
            "runtime_seconds": round(time.monotonic() - started, 2),
        }), 500
