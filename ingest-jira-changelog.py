#!/usr/bin/env python3
# ingest-jira-changelog.py (FIXED: batching + only status transitions + smaller payloads)
#
# Key fixes:
# - Avoid BigQuery 413 by batching streaming inserts (rows + bytes)
# - Only store status-change items (dramatically smaller than full changelog)
# - Do NOT store full payload (payload column left NULL)
# - Clamp initial backfill window by default (configurable), allow explicit since/until in request JSON

import os
import json
import time
import logging
import datetime as dt
from typing import Any, Dict, Iterable, List, Optional, Tuple

import requests
from google.cloud import bigquery
from google.cloud import secretmanager

# -------------------- CONFIG --------------------
PROJECT_ID = os.environ.get("GCP_PROJECT", os.environ.get("GOOGLE_CLOUD_PROJECT", "qa-panda-metrics"))
DATASET_ID = os.environ.get("BQ_DATASET", "qa_metrics")
TABLE_ID = os.environ.get("BQ_TABLE", "jira_changelog")
FULL_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
LATEST_VIEW_ID = f"{PROJECT_ID}.{DATASET_ID}.jira_changelog_latest"

JIRA_BASE_URL = os.environ.get("JIRA_BASE_URL", "").rstrip("/")
JIRA_EMAIL = os.environ.get("JIRA_EMAIL", "")
JIRA_API_TOKEN_SECRET = os.environ.get("JIRA_API_TOKEN_SECRET", "jira_api_token")
JIRA_PROJECT_KEY = os.environ.get("JIRA_PROJECT_KEY", "PC")
JIRA_JQL = os.environ.get("JIRA_JQL", "").strip()  # optional override

DEFAULT_BACKFILL_DAYS = int(os.environ.get("DEFAULT_BACKFILL_DAYS", "180"))
OVERLAP_MINUTES = int(os.environ.get("OVERLAP_MINUTES", "60"))

MAX_RUNTIME_SECONDS = int(os.environ.get("MAX_RUNTIME_SECONDS", "840"))
MAX_ISSUES_PER_INVOCATION = int(os.environ.get("MAX_ISSUES_PER_INVOCATION", "500"))
ISSUE_SEARCH_PAGE_SIZE = int(os.environ.get("ISSUE_SEARCH_PAGE_SIZE", "100"))

# BigQuery insert batching
BQ_INSERT_MAX_ROWS = int(os.environ.get("BQ_INSERT_MAX_ROWS", "300"))
BQ_INSERT_MAX_BYTES = int(os.environ.get("BQ_INSERT_MAX_BYTES", "5000000"))

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("ingest-jira-changelog")

bq = bigquery.Client(project=PROJECT_ID)

# -------------------- SECRETS --------------------
def get_secret_value(secret_id: str) -> str:
    sm = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
    resp = sm.access_secret_version(request={"name": name})
    return resp.payload.data.decode("utf-8")

def jira_headers() -> Dict[str, str]:
    token = get_secret_value(JIRA_API_TOKEN_SECRET)
    import base64
    auth = base64.b64encode(f"{JIRA_EMAIL}:{token}".encode()).decode()
    return {
        "Authorization": f"Basic {auth}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }

# -------------------- HELPERS --------------------
def _parse_iso_date_or_ts(s: str) -> dt.datetime:
    s = s.strip()
    if len(s) == 10:
        return dt.datetime.fromisoformat(s).replace(tzinfo=dt.timezone.utc)
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return dt.datetime.fromisoformat(s).astimezone(dt.timezone.utc)

def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)

def _to_rfc3339(ts: dt.datetime) -> str:
    return ts.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")

def _approx_json_bytes(obj: Any) -> int:
    return len(json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

# -------------------- BQ SETUP --------------------
def ensure_table_and_view() -> None:
    schema = [
        bigquery.SchemaField("issue_id", "STRING"),
        bigquery.SchemaField("issue_key", "STRING"),
        bigquery.SchemaField("issue_updated", "TIMESTAMP"),
        bigquery.SchemaField("history_id", "STRING"),
        bigquery.SchemaField("history_created", "TIMESTAMP"),
        bigquery.SchemaField("author_account_id", "STRING"),
        bigquery.SchemaField("items_json", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
        # keep column but DO NOT fill
        bigquery.SchemaField("payload", "STRING"),
    ]

    table_ref = bigquery.Table(FULL_TABLE_ID, schema=schema)
    table_ref.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY,
        field="history_created",
    )
    table_ref.clustering_fields = ["issue_key", "history_created", "history_id", "author_account_id"]

    bq.create_table(table_ref, exists_ok=True)

    view_sql = f"""
    CREATE OR REPLACE VIEW `{LATEST_VIEW_ID}` AS
    SELECT * EXCEPT(rn)
    FROM (
      SELECT
        t.*,
        ROW_NUMBER() OVER (
          PARTITION BY issue_id, history_id
          ORDER BY history_created DESC, _ingested_at DESC
        ) AS rn
      FROM `{FULL_TABLE_ID}` t
    )
    WHERE rn = 1
    """
    bq.query(view_sql).result()

# -------------------- STATE --------------------
def get_last_history_created_ts() -> Optional[dt.datetime]:
    q = f"SELECT MAX(history_created) AS max_created FROM `{FULL_TABLE_ID}`"
    rows = list(bq.query(q).result())
    if not rows or rows[0].max_created is None:
        return None
    max_created = rows[0].max_created
    if isinstance(max_created, dt.datetime):
        if max_created.tzinfo is None:
            max_created = max_created.replace(tzinfo=dt.timezone.utc)
        else:
            max_created = max_created.astimezone(dt.timezone.utc)
        return max_created
    return None

# -------------------- JQL / FETCH --------------------
def build_jql(since_ts: dt.datetime, until_ts: Optional[dt.datetime] = None) -> str:
    if JIRA_JQL:
        base = f"({JIRA_JQL})"
    else:
        base = f'project = "{JIRA_PROJECT_KEY}"'

    since_s = _to_rfc3339(since_ts)
    clauses = [base, f'updated >= "{since_s}"']
    if until_ts is not None:
        until_s = _to_rfc3339(until_ts)
        clauses.append(f'updated < "{until_s}"')

    return " AND ".join(clauses) + " ORDER BY updated ASC"

def fetch_issue_keys(jql: str, start_at: int, max_results: int) -> Dict[str, Any]:
    url = f"{JIRA_BASE_URL}/rest/api/3/search"
    payload = {
        "jql": jql,
        "startAt": start_at,
        "maxResults": max_results,
        "fields": ["updated"],
    }
    r = requests.post(url, headers=jira_headers(), json=payload, timeout=60)
    r.raise_for_status()
    return r.json()

def fetch_changelog_for_issue(issue_id: str, start_at: int) -> Dict[str, Any]:
    url = f"{JIRA_BASE_URL}/rest/api/3/issue/{issue_id}/changelog?startAt={start_at}&maxResults=100"
    r = requests.get(url, headers=jira_headers(), timeout=60)
    r.raise_for_status()
    return r.json()

# -------------------- BQ INSERT (BATCHED) --------------------
def insert_rows_batched(rows_iter: Iterable[Tuple[str, Dict[str, Any]]]) -> Tuple[int, int]:
    buffer_rows: List[Dict[str, Any]] = []
    buffer_ids: List[str] = []
    buffer_bytes = 0
    inserted = 0
    batches = 0

    def flush() -> None:
        nonlocal buffer_rows, buffer_ids, buffer_bytes, inserted, batches
        if not buffer_rows:
            return
        errors = bq.insert_rows_json(FULL_TABLE_ID, buffer_rows, row_ids=buffer_ids)
        if errors:
            raise RuntimeError(f"BigQuery insert_rows_json errors (sample): {errors[:3]}")
        inserted += len(buffer_rows)
        batches += 1
        buffer_rows = []
        buffer_ids = []
        buffer_bytes = 0

    for rid, row in rows_iter:
        row_bytes = _approx_json_bytes(row)
        if buffer_rows and (len(buffer_rows) >= BQ_INSERT_MAX_ROWS or buffer_bytes + row_bytes >= BQ_INSERT_MAX_BYTES):
            flush()
        buffer_rows.append(row)
        buffer_ids.append(rid)
        buffer_bytes += row_bytes
        if len(buffer_rows) >= BQ_INSERT_MAX_ROWS or buffer_bytes >= BQ_INSERT_MAX_BYTES:
            flush()

    flush()
    return inserted, batches

# -------------------- MAIN INGEST --------------------
def ingest(since_ts: dt.datetime, until_ts: Optional[dt.datetime] = None) -> Dict[str, Any]:
    ensure_table_and_view()

    jql = build_jql(since_ts, until_ts)
    log.info("JQL: %s", jql)

    start_time = time.time()
    total_issues = 0
    total_histories = 0

    def rows_generator():
        nonlocal total_issues, total_histories
        start_at = 0
        while True:
            if total_issues >= MAX_ISSUES_PER_INVOCATION:
                log.warning("Reached MAX_ISSUES_PER_INVOCATION=%s, stopping.", MAX_ISSUES_PER_INVOCATION)
                break
            if time.time() - start_time > MAX_RUNTIME_SECONDS:
                log.warning("Reached MAX_RUNTIME_SECONDS=%s, stopping.", MAX_RUNTIME_SECONDS)
                break

            data = fetch_issue_keys(jql, start_at=start_at, max_results=ISSUE_SEARCH_PAGE_SIZE)
            issues = data.get("issues", []) or []
            total = int(data.get("total", 0) or 0)
            if not issues:
                break

            for issue in issues:
                if total_issues >= MAX_ISSUES_PER_INVOCATION:
                    break
                issue_id = str(issue.get("id"))
                issue_key = issue.get("key")
                issue_updated = (issue.get("fields") or {}).get("updated")

                # fetch changelog paginated
                c_start = 0
                while True:
                    if time.time() - start_time > MAX_RUNTIME_SECONDS:
                        break
                    c = fetch_changelog_for_issue(issue_id, start_at=c_start)
                    histories = c.get("values") or c.get("histories") or []
                    if not histories:
                        break

                    for h in histories:
                        # Keep only status changes (smaller + exactly what KPI queries need)
                        items = h.get("items") or []
                        status_items = [it for it in items if (it.get("field") == "status")]
                        if not status_items:
                            continue

                        history_id = str(h.get("id"))
                        history_created = h.get("created")
                        author = h.get("author") or {}
                        author_account_id = author.get("accountId")

                        row = {
                            "issue_id": issue_id,
                            "issue_key": issue_key,
                            "issue_updated": issue_updated,
                            "history_id": history_id,
                            "history_created": history_created,
                            "author_account_id": author_account_id,
                            "items_json": json.dumps(status_items, ensure_ascii=False),
                            "_ingested_at": _to_rfc3339(_now_utc()),
                            # payload omitted
                        }
                        rid = f"{issue_id}-{history_id}-{history_created}"
                        total_histories += 1
                        yield rid, row

                    # paginate changelog
                    c_start += int(c.get("maxResults", 100) or 100)
                    c_total = int(c.get("total", 0) or 0)
                    if c_start >= c_total:
                        break

                total_issues += 1

            start_at += len(issues)
            if start_at >= total:
                break

    inserted, batches = insert_rows_batched(rows_generator())

    return {
        "inserted_rows": inserted,
        "batches": batches,
        "issues_processed": total_issues,
        "status_histories_written": total_histories,
        "since": _to_rfc3339(since_ts),
        "until": _to_rfc3339(until_ts) if until_ts else None,
    }

# -------------------- HTTP ENTRYPOINT --------------------
def hello_http(request):
    """
    POST JSON:
      { "since": "...", "until": "..." }

    Default since:
      - MAX(history_created) from BigQuery minus OVERLAP_MINUTES
      - BUT clamps to now - DEFAULT_BACKFILL_DAYS if that max is too old
    """
    try:
        body = request.get_json(silent=True) or {}
    except Exception:
        body = {}

    explicit_since = body.get("since") or body.get("since_ts")
    explicit_until = body.get("until") or body.get("until_ts")

    now = _now_utc()

    if explicit_since:
        since_ts = _parse_iso_date_or_ts(str(explicit_since))
    else:
        last = get_last_history_created_ts()
        if last is None:
            since_ts = now - dt.timedelta(days=DEFAULT_BACKFILL_DAYS)
        else:
            since_ts = last - dt.timedelta(minutes=OVERLAP_MINUTES)

        clamp = now - dt.timedelta(days=DEFAULT_BACKFILL_DAYS)
        if since_ts < clamp:
            log.warning("Clamping since_ts from %s to %s (DEFAULT_BACKFILL_DAYS=%s).",
                        since_ts, clamp, DEFAULT_BACKFILL_DAYS)
            since_ts = clamp

    until_ts = None
    if explicit_until:
        until_ts = _parse_iso_date_or_ts(str(explicit_until))
        if until_ts <= since_ts:
            return (json.dumps({"status": "ERROR", "message": "until must be > since"}), 400, {"Content-Type": "application/json"})

    result = ingest(since_ts=since_ts, until_ts=until_ts)
    return (json.dumps({"status": "OK", **result}), 200, {"Content-Type": "application/json"})
