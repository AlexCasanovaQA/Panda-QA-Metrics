#!/usr/bin/env python3
# ingest-jira.py (FIXED: batching + smaller payloads + safer backfill)
#
# Key fixes:
# - Avoid BigQuery 413 by batching streaming inserts (rows + bytes)
# - Do NOT store full Jira payload per issue (payload column left NULL)
# - Truncate large text fields to avoid per-row size issues
# - Clamp initial backfill window by default (configurable), and allow explicit since/until in request JSON

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
TABLE_ID = os.environ.get("BQ_TABLE", "jira_issues")
FULL_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
LATEST_VIEW_ID = f"{PROJECT_ID}.{DATASET_ID}.jira_issues_latest"

JIRA_BASE_URL = os.environ.get("JIRA_BASE_URL", "").rstrip("/")
JIRA_EMAIL = os.environ.get("JIRA_EMAIL", "")
JIRA_API_TOKEN_SECRET = os.environ.get("JIRA_API_TOKEN_SECRET", "jira_api_token")
JIRA_PROJECT_KEY = os.environ.get("JIRA_PROJECT_KEY", "PC")
JIRA_JQL = os.environ.get("JIRA_JQL", "").strip()  # optional override

# Custom fields / mappings (keep your existing envs)
TEAM_FIELD = os.environ.get("JIRA_TEAM_FIELD", "customfield_10001")
SPRINT_FIELD = os.environ.get("JIRA_SPRINT_FIELD", "customfield_10020")
STORY_POINTS_FIELD = os.environ.get("JIRA_STORY_POINTS_FIELD", "customfield_10016")

# Runtime / backfill behavior
DEFAULT_BACKFILL_DAYS = int(os.environ.get("DEFAULT_BACKFILL_DAYS", "180"))  # clamp huge historical pulls
OVERLAP_MINUTES = int(os.environ.get("OVERLAP_MINUTES", "60"))               # re-pull a bit to avoid missing edges
MAX_PAGES = int(os.environ.get("MAX_PAGES", "200"))
PAGE_SIZE = int(os.environ.get("PAGE_SIZE", "100"))
MAX_ISSUES_PER_INVOCATION = int(os.environ.get("MAX_ISSUES_PER_INVOCATION", "5000"))
MAX_RUNTIME_SECONDS = int(os.environ.get("MAX_RUNTIME_SECONDS", "840"))      # ~14 min (Cloud Run default 15m)

# BigQuery insert batching (prevents 413)
BQ_INSERT_MAX_ROWS = int(os.environ.get("BQ_INSERT_MAX_ROWS", "200"))
BQ_INSERT_MAX_BYTES = int(os.environ.get("BQ_INSERT_MAX_BYTES", "5000000"))  # 5 MB safety

# Text truncation (prevents single-row huge payloads)
MAX_SUMMARY_CHARS = int(os.environ.get("MAX_SUMMARY_CHARS", "1000"))
MAX_DESCRIPTION_CHARS = int(os.environ.get("MAX_DESCRIPTION_CHARS", "10000"))
MAX_SPRINT_CHARS = int(os.environ.get("MAX_SPRINT_CHARS", "2000"))

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("ingest-jira")

bq = bigquery.Client(project=PROJECT_ID)

# -------------------- SECRETS --------------------
def get_secret_value(secret_id: str) -> str:
    """Read latest secret version from Secret Manager."""
    sm = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
    resp = sm.access_secret_version(request={"name": name})
    return resp.payload.data.decode("utf-8")

def jira_headers() -> Dict[str, str]:
    token = get_secret_value(JIRA_API_TOKEN_SECRET)
    # Basic auth with email + API token
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
    if len(s) == 10:  # YYYY-MM-DD
        return dt.datetime.fromisoformat(s).replace(tzinfo=dt.timezone.utc)
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return dt.datetime.fromisoformat(s).astimezone(dt.timezone.utc)

def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)

def _to_rfc3339(ts: dt.datetime) -> str:
    return ts.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")

def _safe_trunc(s: Optional[str], n: int) -> Optional[str]:
    if s is None:
        return None
    if len(s) <= n:
        return s
    return s[:n]

def _approx_json_bytes(obj: Any) -> int:
    # quick conservative estimate for batching
    return len(json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

# -------------------- BQ SETUP --------------------
def ensure_table_and_view() -> None:
    schema = [
        bigquery.SchemaField("issue_id", "STRING"),
        bigquery.SchemaField("issue_key", "STRING"),
        bigquery.SchemaField("created", "TIMESTAMP"),
        bigquery.SchemaField("updated", "TIMESTAMP"),
        bigquery.SchemaField("issue_type", "STRING"),
        bigquery.SchemaField("team", "STRING"),
        bigquery.SchemaField("components", "STRING", mode="REPEATED"),
        bigquery.SchemaField("fix_versions", "STRING", mode="REPEATED"),
        bigquery.SchemaField("sprint", "STRING"),
        bigquery.SchemaField("priority", "STRING"),
        bigquery.SchemaField("resolution", "STRING"),
        bigquery.SchemaField("resolutiondate", "TIMESTAMP"),
        bigquery.SchemaField("status", "STRING"),
        bigquery.SchemaField("assignee_account_id", "STRING"),
        bigquery.SchemaField("reporter_account_id", "STRING"),
        bigquery.SchemaField("story_points", "FLOAT"),
        bigquery.SchemaField("summary", "STRING"),
        bigquery.SchemaField("description_plain", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
        # keep the column for backwards compatibility, but we DO NOT fill it anymore (NULL)
        bigquery.SchemaField("payload", "STRING"),
    ]

    table_ref = bigquery.Table(FULL_TABLE_ID, schema=schema)
    table_ref.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY,
        field="updated",
    )
    # BigQuery clustering max 4 fields
    table_ref.clustering_fields = ["issue_key", "updated", "team", "issue_type"]

    bq.create_table(table_ref, exists_ok=True)

    # Latest view
    view_sql = f"""
    CREATE OR REPLACE VIEW `{LATEST_VIEW_ID}` AS
    SELECT * EXCEPT(rn)
    FROM (
      SELECT
        t.*,
        ROW_NUMBER() OVER (PARTITION BY issue_id ORDER BY updated DESC, _ingested_at DESC) AS rn
      FROM `{FULL_TABLE_ID}` t
    )
    WHERE rn = 1
    """
    bq.query(view_sql).result()

# -------------------- STATE --------------------
def get_last_updated_ts() -> Optional[dt.datetime]:
    q = f"SELECT MAX(updated) AS max_updated FROM `{FULL_TABLE_ID}`"
    rows = list(bq.query(q).result())
    if not rows or rows[0].max_updated is None:
        return None
    # BigQuery returns naive datetime in UTC
    max_updated = rows[0].max_updated
    if isinstance(max_updated, dt.datetime):
        if max_updated.tzinfo is None:
            max_updated = max_updated.replace(tzinfo=dt.timezone.utc)
        else:
            max_updated = max_updated.astimezone(dt.timezone.utc)
        return max_updated
    return None

# -------------------- JQL / FETCH --------------------
def build_jql(since_ts: dt.datetime, until_ts: Optional[dt.datetime] = None) -> str:
    # Allow overriding with full JQL, but keep time bounds.
    if JIRA_JQL:
        base = f"({JIRA_JQL})"
    else:
        base = f'project = "{JIRA_PROJECT_KEY}"'

    since_s = _to_rfc3339(since_ts)
    clauses = [base, f'updated >= "{since_s}"']
    if until_ts is not None:
        until_s = _to_rfc3339(until_ts)
        clauses.append(f'updated < "{until_s}"')

    # Deterministic order for paging
    return " AND ".join(clauses) + " ORDER BY updated ASC"

def fetch_issues_page(jql: str, start_at: int, max_results: int) -> Dict[str, Any]:
    url = f"{JIRA_BASE_URL}/rest/api/3/search"
    # Only fetch what we actually store (smaller Jira response)
    fields = [
        "created","updated","issuetype","status","priority","resolution","resolutiondate",
        "assignee","reporter","components","fixVersions","summary","description",
        TEAM_FIELD, SPRINT_FIELD, STORY_POINTS_FIELD
    ]
    payload = {
        "jql": jql,
        "startAt": start_at,
        "maxResults": max_results,
        "fields": fields,
    }
    r = requests.post(url, headers=jira_headers(), json=payload, timeout=60)
    r.raise_for_status()
    return r.json()

# -------------------- ADF -> plain text --------------------
def adf_to_text(node: Any) -> str:
    # Jira descriptions often come in Atlassian Document Format (ADF).
    # We only need plain text for KPI completeness checks.
    if node is None:
        return ""
    if isinstance(node, str):
        return node
    if isinstance(node, dict):
        t = node.get("type")
        if t == "text":
            return node.get("text", "")
        parts = []
        for c in node.get("content", []) or []:
            parts.append(adf_to_text(c))
        return "\n".join([p for p in parts if p is not None and p != ""])
    if isinstance(node, list):
        return "\n".join([adf_to_text(x) for x in node])
    return ""

def extract_sprint_name(raw_sprint: Any) -> Optional[str]:
    # Sprint custom field can be:
    # - None
    # - List[str] with "name=..." embedded
    # - Str
    if raw_sprint is None:
        return None
    if isinstance(raw_sprint, str):
        return _safe_trunc(raw_sprint, MAX_SPRINT_CHARS)
    if isinstance(raw_sprint, list) and raw_sprint:
        # Try parse "name=XYZ"
        s0 = str(raw_sprint[0])
        m = re.search(r"name=([^,]+)", s0)
        if m:
            return _safe_trunc(m.group(1).strip(), MAX_SPRINT_CHARS)
        return _safe_trunc(s0, MAX_SPRINT_CHARS)
    return _safe_trunc(str(raw_sprint), MAX_SPRINT_CHARS)

# -------------------- TRANSFORM --------------------
import re

def issue_to_row(issue: Dict[str, Any]) -> Dict[str, Any]:
    fields = issue.get("fields", {}) or {}
    issue_id = str(issue.get("id"))
    issue_key = issue.get("key")

    created = fields.get("created")
    updated = fields.get("updated")

    issue_type = (fields.get("issuetype") or {}).get("name")
    status = (fields.get("status") or {}).get("name")
    priority = (fields.get("priority") or {}).get("name")
    resolution = (fields.get("resolution") or {}).get("name")
    resolutiondate = fields.get("resolutiondate")

    assignee = fields.get("assignee") or {}
    reporter = fields.get("reporter") or {}

    assignee_account_id = assignee.get("accountId")
    reporter_account_id = reporter.get("accountId")

    team = fields.get(TEAM_FIELD)
    if isinstance(team, dict):
        team = team.get("name") or team.get("value") or team.get("id")

    components = [c.get("name") for c in (fields.get("components") or []) if isinstance(c, dict) and c.get("name")]
    fix_versions = [v.get("name") for v in (fields.get("fixVersions") or []) if isinstance(v, dict) and v.get("name")]

    story_points = fields.get(STORY_POINTS_FIELD)
    if story_points is not None:
        try:
            story_points = float(story_points)
        except Exception:
            story_points = None

    summary = _safe_trunc(fields.get("summary"), MAX_SUMMARY_CHARS)

    desc = fields.get("description")
    desc_text = adf_to_text(desc).strip()
    desc_text = _safe_trunc(desc_text, MAX_DESCRIPTION_CHARS)

    sprint = extract_sprint_name(fields.get(SPRINT_FIELD))

    return {
        "issue_id": issue_id,
        "issue_key": issue_key,
        "created": created,
        "updated": updated,
        "issue_type": issue_type,
        "team": team,
        "components": components,
        "fix_versions": fix_versions,
        "sprint": sprint,
        "priority": priority,
        "resolution": resolution,
        "resolutiondate": resolutiondate,
        "status": status,
        "assignee_account_id": assignee_account_id,
        "reporter_account_id": reporter_account_id,
        "story_points": story_points,
        "summary": summary,
        "description_plain": desc_text,
        "_ingested_at": _to_rfc3339(_now_utc()),
        # DO NOT send payload to BigQuery (keeps request small)
        # "payload": json.dumps(issue)
    }

# -------------------- BQ INSERT (BATCHED) --------------------
def insert_rows_batched(rows_iter: Iterable[Tuple[str, Dict[str, Any]]]) -> Tuple[int, int]:
    """
    Insert rows in batches. rows_iter yields (row_id, row_dict).
    Returns (inserted_rows, batches).
    """
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
            # surface the first few errors
            raise RuntimeError(f"BigQuery insert_rows_json errors (sample): {errors[:3]}")
        inserted += len(buffer_rows)
        batches += 1
        buffer_rows = []
        buffer_ids = []
        buffer_bytes = 0

    for rid, row in rows_iter:
        row_bytes = _approx_json_bytes(row)
        # If a single row is massive, try to insert it alone (or it'll always blow batches)
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
    total_pages = 0

    def rows_generator():
        nonlocal total_issues, total_pages
        start_at = 0
        page = 0
        while True:
            if page >= MAX_PAGES:
                log.warning("Reached MAX_PAGES=%s, stopping.", MAX_PAGES)
                break
            if total_issues >= MAX_ISSUES_PER_INVOCATION:
                log.warning("Reached MAX_ISSUES_PER_INVOCATION=%s, stopping.", MAX_ISSUES_PER_INVOCATION)
                break
            if time.time() - start_time > MAX_RUNTIME_SECONDS:
                log.warning("Reached MAX_RUNTIME_SECONDS=%s, stopping.", MAX_RUNTIME_SECONDS)
                break

            data = fetch_issues_page(jql, start_at=start_at, max_results=PAGE_SIZE)
            issues = data.get("issues", []) or []
            total = int(data.get("total", 0) or 0)

            if not issues:
                break

            total_pages += 1
            for issue in issues:
                row = issue_to_row(issue)
                rid = f"{row['issue_id']}-{row['updated']}"
                yield rid, row
                total_issues += 1
                if total_issues >= MAX_ISSUES_PER_INVOCATION:
                    break

            start_at += len(issues)
            page += 1
            if start_at >= total:
                break

    inserted, batches = insert_rows_batched(rows_generator())

    return {
        "inserted_rows": inserted,
        "batches": batches,
        "issues_processed": total_issues,
        "pages_fetched": total_pages,
        "since": _to_rfc3339(since_ts),
        "until": _to_rfc3339(until_ts) if until_ts else None,
    }

# -------------------- HTTP ENTRYPOINT --------------------
def hello_http(request):
    """
    POST JSON options:
      {
        "since": "2026-01-01" or "2026-01-01T00:00:00Z",   (optional)
        "until": "2026-02-01" or "2026-02-01T00:00:00Z"    (optional)
      }

    If since not provided:
      - uses MAX(updated) from BigQuery minus OVERLAP_MINUTES
      - BUT clamps to now - DEFAULT_BACKFILL_DAYS if that max is too old (prevents huge first run)
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
        last = get_last_updated_ts()
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
