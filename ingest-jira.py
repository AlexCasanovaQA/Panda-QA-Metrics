"""Ingest Jira issues into BigQuery.

Enhancements vs previous version:
- Adds `status_category` (Jira statusCategory.name) and `status_category_key`.
- Adds `severity` (custom field) with configurable field id.

Env vars:
- JIRA_BASE_URL (default: https://<your-domain>.atlassian.net)
- JIRA_EMAIL / JIRA_API_TOKEN
- JIRA_PROJECT_KEYS (comma-separated, e.g. "PC,PANDA")
- JIRA_SEVERITY_FIELD_ID (optional, e.g. "customfield_12345")
- LOOKBACK_DAYS (optional, default 30)

BQ env vars:
- GCP_PROJECT_ID (optional, else derived)
- BQ_DATASET_ID (default qa_metrics)
- BQ_TABLE_ID (default jira_issues_v2)

HTTP:
- POST body can override lookback_days and project_keys.
"""

import json
import os
import re
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, Optional

import functions_framework
import requests
from google.api_core.exceptions import NotFound
from google.cloud import bigquery


# ----------------------------
# Config
# ----------------------------

DEFAULT_LOOKBACK_DAYS = int(os.environ.get("LOOKBACK_DAYS", "30"))
BQ_DATASET_ID = os.environ.get("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.environ.get("BQ_TABLE_ID", "jira_issues_v2")

JIRA_BASE_URL = os.environ.get("JIRA_BASE_URL") or os.environ.get("JIRA_SITE")  # required
JIRA_EMAIL = os.environ.get("JIRA_EMAIL") or os.environ.get("JIRA_USER")  # required
JIRA_API_TOKEN = os.environ.get("JIRA_API_TOKEN")  # required
JIRA_PROJECT_KEYS = os.environ.get("JIRA_PROJECT_KEYS", "").strip()

# Custom field ids
TEAM_FIELD_ID = os.environ.get("JIRA_TEAM_FIELD_ID", "customfield_10001")
SEVERITY_FIELD_ID = os.environ.get("JIRA_SEVERITY_FIELD_ID", "").strip() or None
SPRINT_FIELD_ID = os.environ.get("JIRA_SPRINT_FIELD_ID", "customfield_10020")

# Runtime-resolved severity field id (explicit env var has priority).
RESOLVED_SEVERITY_FIELD_ID: Optional[str] = SEVERITY_FIELD_ID


def _error_response(error_type: str, code: str, message: str, status_code: int, details: Any = None):
    payload: Dict[str, Any] = {
        "ok": False,
        "error": {
            "type": error_type,
            "code": code,
            "message": message,
        },
    }
    if details is not None:
        payload["error"]["details"] = details
    return (json.dumps(payload), status_code, {"Content-Type": "application/json"})


def _jira_search_fields() -> str:
    """Build the Jira field list for search requests.

    Jira's search endpoint only returns requested fields, so custom field ids
    must be explicitly included when configured.
    """
    fields = [
        "summary",
        "project",
        "issuetype",
        "status",
        "priority",
        "created",
        "updated",
        "resolutiondate",
        "reporter",
        "assignee",
        "labels",
        "components",
        "fixVersions",
        "versions",
        "resolution",
        TEAM_FIELD_ID,
        SPRINT_FIELD_ID,
    ]
    if RESOLVED_SEVERITY_FIELD_ID:
        fields.append(RESOLVED_SEVERITY_FIELD_ID)
    # Keep deterministic order and avoid duplicates if ids overlap.
    return ",".join(dict.fromkeys(fields))


# ----------------------------
# Helpers
# ----------------------------


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(ts: Optional[datetime]) -> Optional[str]:
    return ts.isoformat().replace("+00:00", "Z") if ts else None


def _get_project_id() -> str:
    pid = os.environ.get("GCP_PROJECT_ID")
    if pid:
        return pid
    # Fallback to BigQuery client project
    return bigquery.Client().project


def _jira_headers() -> Dict[str, str]:
    return {"Accept": "application/json"}


def _jira_auth() -> requests.auth.HTTPBasicAuth:
    if not (JIRA_EMAIL and JIRA_API_TOKEN):
        raise RuntimeError("Missing JIRA_EMAIL or JIRA_API_TOKEN env vars")
    return requests.auth.HTTPBasicAuth(JIRA_EMAIL, JIRA_API_TOKEN)


def _jira_get(path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    if not JIRA_BASE_URL:
        raise RuntimeError("Missing JIRA_BASE_URL env var")
    url = JIRA_BASE_URL.rstrip("/") + path

    max_attempts = 5
    backoff = 1.0
    for attempt in range(1, max_attempts + 1):
        r = requests.get(url, headers=_jira_headers(), auth=_jira_auth(), params=params, timeout=60)

        if r.status_code in (429, 500, 502, 503, 504) and attempt < max_attempts:
            retry_after = r.headers.get("Retry-After")
            wait_seconds = float(retry_after) if retry_after and retry_after.isdigit() else backoff
            print(f"Jira request retryable status={r.status_code}. attempt={attempt}/{max_attempts}, waiting {wait_seconds}s")
            time.sleep(wait_seconds)
            backoff *= 2
            continue

        r.raise_for_status()
        return r.json()

    raise RuntimeError("Jira request failed after retries")


def _extract_user_display(user_obj: Any) -> Optional[str]:
    if not isinstance(user_obj, dict):
        return None
    # Jira Cloud: displayName
    return user_obj.get("displayName") or user_obj.get("name") or user_obj.get("emailAddress")


def _extract_severity(fields: Dict[str, Any]) -> Optional[str]:
    """Extract severity from a configured custom field.

    Many Jira instances implement Severity as a customfield.
    We support the explicit field id via JIRA_SEVERITY_FIELD_ID.

    If not configured, we return None (caller can fall back to priority logic).
    """
    candidate_keys: List[str] = []
    if RESOLVED_SEVERITY_FIELD_ID:
        candidate_keys.append(RESOLVED_SEVERITY_FIELD_ID)

    # Fallbacks commonly present in some Jira setups.
    candidate_keys.extend(["severity", "customfield_severity"])

    raw = None
    for field_key in candidate_keys:
        raw = fields.get(field_key)
        if raw is not None:
            break

    if raw is None:
        return None

    # Severity could be {"value": "(S1) Critical"} or {"name": "..."}
    if isinstance(raw, dict):
        return raw.get("value") or raw.get("name") or raw.get("displayName")

    # Or already a string
    if isinstance(raw, str):
        return raw

    # Or list (rare)
    if isinstance(raw, list) and raw:
        first = raw[0]
        if isinstance(first, dict):
            return first.get("value") or first.get("name")
        if isinstance(first, str):
            return first

    return None


def _resolve_severity_field_id() -> Optional[str]:
    """Resolve Jira severity field id.

    Priority:
    1) Explicit env var JIRA_SEVERITY_FIELD_ID.
    2) Auto-detect from Jira /field metadata using field name heuristics.
    """
    if SEVERITY_FIELD_ID:
        print(f"Using explicit severity field id from env: {SEVERITY_FIELD_ID}")
        return SEVERITY_FIELD_ID

    print("JIRA_SEVERITY_FIELD_ID not set; attempting best-effort auto-detection from Jira /field metadata.")

    try:
        payload = _jira_get("/rest/api/3/field")
    except Exception as exc:
        print(f"Could not auto-detect Jira severity field id: {exc}")
        return None

    if not isinstance(payload, list):
        return None

    def _score_field(name: str) -> int:
        lname = (name or "").strip().lower()
        if lname in {"severity", "severidad"}:
            return 3
        if "severity" in lname or "severidad" in lname:
            return 2
        return 0

    best: Optional[str] = None
    best_score = 0
    for fld in payload:
        if not isinstance(fld, dict):
            continue
        field_id = fld.get("id")
        field_name = str(fld.get("name") or "")
        score = _score_field(field_name)
        if not field_id or score == 0:
            continue
        if score > best_score:
            best = str(field_id)
            best_score = score

    if best:
        print(f"Auto-detected severity field id: {best}")
    else:
        print("No Jira severity field detected from /field metadata; severity may remain unknown.")
    return best


def _ensure_table(bq: bigquery.Client, table_ref: bigquery.TableReference) -> None:
    desired_schema = [
        bigquery.SchemaField("issue_key", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("project_key", "STRING"),
        bigquery.SchemaField("issue_type", "STRING"),
        bigquery.SchemaField("summary", "STRING"),
        bigquery.SchemaField("status", "STRING"),
        bigquery.SchemaField("status_category", "STRING"),
        bigquery.SchemaField("status_category_key", "STRING"),
        bigquery.SchemaField("priority", "STRING"),
        bigquery.SchemaField("severity", "STRING"),
        bigquery.SchemaField("created_at", "TIMESTAMP"),
        bigquery.SchemaField("updated_at", "TIMESTAMP"),
        bigquery.SchemaField("resolved_at", "TIMESTAMP"),
        bigquery.SchemaField("reporter", "STRING"),
        bigquery.SchemaField("assignee", "STRING"),
        bigquery.SchemaField("team", "STRING"),
        bigquery.SchemaField("labels", "STRING"),
        bigquery.SchemaField("components", "STRING"),
        bigquery.SchemaField("fix_versions", "STRING"),
        bigquery.SchemaField("affects_versions", "STRING"),
        bigquery.SchemaField("sprint", "STRING"),
        bigquery.SchemaField("resolution", "STRING"),
        bigquery.SchemaField("raw_json", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    try:
        table = bq.get_table(table_ref)
        existing_fields = {f.name: f for f in table.schema}
        to_add = [f for f in desired_schema if f.name not in existing_fields]
        if to_add:
            table.schema = list(table.schema) + to_add
            bq.update_table(table, ["schema"])
            print(f"Added {len(to_add)} columns to {table_ref}")
    except NotFound:
        # Create table
        table = bigquery.Table(table_ref, schema=desired_schema)
        # Partition by ingest time (safe)
        table.time_partitioning = bigquery.TimePartitioning(field="_ingested_at")
        bq.create_table(table)
        print(f"Created table {table_ref}")


def _parse_jira_ts(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    # Jira timestamps are ISO8601 with milliseconds and timezone, e.g. 2025-02-01T12:34:56.789+0000
    # Normalize timezone format for offsets without ":" (e.g. +0000, -0700).
    try:
        match = re.search(r"([+-]\d{2})(\d{2})$", value)
        if match:
            value = f"{value[:-5]}{match.group(1)}:{match.group(2)}"
        if value.endswith("Z"):
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        return datetime.fromisoformat(value)
    except Exception:
        return None


def _extract_team(team_val: Any) -> Optional[str]:
    if isinstance(team_val, dict):
        return team_val.get("value") or team_val.get("name")
    if isinstance(team_val, str):
        return team_val
    if isinstance(team_val, list) and team_val:
        first = team_val[0]
        if isinstance(first, dict):
            return first.get("value") or first.get("name")
        if isinstance(first, str):
            return first
    return None


def _extract_sprint(sprint_val: Any) -> Optional[str]:
    if isinstance(sprint_val, list) and sprint_val:
        return json.dumps(sprint_val, ensure_ascii=False)
    if isinstance(sprint_val, dict):
        return sprint_val.get("name") or json.dumps(sprint_val, ensure_ascii=False)
    if isinstance(sprint_val, str):
        return sprint_val
    return None


def _build_issue_record(issue: Dict[str, Any]) -> Dict[str, Any]:
    fields = issue.get("fields", {})

    status_obj = fields.get("status") or {}
    status_cat = status_obj.get("statusCategory") or {}

    rec = {
        "issue_key": issue.get("key"),
        "project_key": (fields.get("project") or {}).get("key"),
        "issue_type": (fields.get("issuetype") or {}).get("name"),
        "summary": fields.get("summary"),
        "status": status_obj.get("name"),
        "status_category": status_cat.get("name"),
        "status_category_key": status_cat.get("key"),
        "priority": (fields.get("priority") or {}).get("name"),
        "severity": _extract_severity(fields),
        "created_at": _iso(_parse_jira_ts(fields.get("created"))),
        "updated_at": _iso(_parse_jira_ts(fields.get("updated"))),
        "resolved_at": _iso(_parse_jira_ts(fields.get("resolutiondate"))),
        "reporter": _extract_user_display(fields.get("reporter")),
        "assignee": _extract_user_display(fields.get("assignee")),
        "team": _extract_team(fields.get(TEAM_FIELD_ID)),
        "labels": json.dumps(fields.get("labels") or []),
        "components": json.dumps([c.get("name") for c in (fields.get("components") or []) if isinstance(c, dict)]),
        "fix_versions": json.dumps([v.get("name") for v in (fields.get("fixVersions") or []) if isinstance(v, dict)]),
        "affects_versions": json.dumps([v.get("name") for v in (fields.get("versions") or []) if isinstance(v, dict)]),
        "sprint": _extract_sprint(fields.get(SPRINT_FIELD_ID) or fields.get("sprint")),
        "resolution": (fields.get("resolution") or {}).get("name"),
        "raw_json": json.dumps(issue, ensure_ascii=False),
        "_ingested_at": _iso(_utc_now()),
    }

    return rec


def _search_issues(project_key: str, since: datetime, until: datetime) -> Iterable[Dict[str, Any]]:
    """Generator that yields issues for a project within updated window."""

    jql = (
        f'project = "{project_key}" '
        f'AND updated >= "{since.strftime("%Y/%m/%d %H:%M")}" '
        f'AND updated <= "{until.strftime("%Y/%m/%d %H:%M")}" '
        f'ORDER BY updated DESC'
    )

    start_at = 0
    max_results = 100

    while True:
        data = _jira_get(
            "/rest/api/3/search",
            params={
                "jql": jql,
                "startAt": start_at,
                "maxResults": max_results,
                # request only what we need (fields are still heavy but ok)
                "fields": _jira_search_fields(),
            },
        )
        issues = data.get("issues") or []
        if not issues:
            break

        for issue in issues:
            yield issue

        start_at += len(issues)
        total = data.get("total")
        if total is not None and start_at >= total:
            break


@functions_framework.http
def ingest_jira(request):
    """Cloud Run / Functions Framework entrypoint."""

    req_json = request.get_json(silent=True) or {}

    lookback_days = int(req_json.get("lookback_days") or DEFAULT_LOOKBACK_DAYS)
    if lookback_days <= 0:
        return _error_response("config_error", "invalid_lookback_days", "lookback_days must be > 0", 400)

    project_keys_raw = (req_json.get("project_keys") or JIRA_PROJECT_KEYS)
    if isinstance(project_keys_raw, list):
        project_keys = [str(p).strip() for p in project_keys_raw if str(p).strip()]
    else:
        project_keys = [p.strip() for p in str(project_keys_raw).split(",") if p.strip()]
    if not project_keys:
        return _error_response(
            "config_error",
            "missing_project_keys",
            "No Jira projects provided. Set JIRA_PROJECT_KEYS or pass project_keys",
            400,
        )

    until = _utc_now()
    since = until - timedelta(days=lookback_days)

    global RESOLVED_SEVERITY_FIELD_ID
    RESOLVED_SEVERITY_FIELD_ID = _resolve_severity_field_id()

    bq = bigquery.Client(project=_get_project_id())
    table_ref = bq.dataset(BQ_DATASET_ID).table(BQ_TABLE_ID)
    _ensure_table(bq, table_ref)

    rows: List[Dict[str, Any]] = []
    inserted = 0

    for project_key in project_keys:
        print(f"Ingesting Jira issues for {project_key} from {since} to {until} (lookback {lookback_days}d)")
        for issue in _search_issues(project_key, since, until):
            rec = _build_issue_record(issue)
            if not rec.get("issue_key"):
                continue
            rows.append(rec)

            # Batch insert
            if len(rows) >= 500:
                row_ids = [f"{r['issue_key']}:{r.get('updated_at') or ''}" for r in rows]
                errors = bq.insert_rows_json(table_ref, rows, row_ids=row_ids)
                if errors:
                    print("BigQuery insert errors:", errors[:3])
                    return _error_response("runtime_error", "bigquery_insert_failed", "BigQuery insert failed", 500, errors[:3])
                inserted += len(rows)
                print(f"Inserted {inserted} rows so far")
                rows.clear()

        # gentle pause to avoid Jira throttling
        time.sleep(0.25)

    if rows:
        row_ids = [f"{r['issue_key']}:{r.get('updated_at') or ''}" for r in rows]
        errors = bq.insert_rows_json(table_ref, rows, row_ids=row_ids)
        if errors:
            print("BigQuery insert errors:", errors[:3])
            return _error_response("runtime_error", "bigquery_insert_failed", "BigQuery insert failed", 500, errors[:3])
        inserted += len(rows)

    return (
        json.dumps(
            {
                "ok": True,
                "projects": project_keys,
                "lookback_days": lookback_days,
                "inserted_rows": inserted,
                "bq_table": f"{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}",
            }
        ),
        200,
        {"Content-Type": "application/json"},
    )


def hello_http(request):
    if request.path.endswith("/healthz") or request.method == "GET":
        return (json.dumps({"ok": True, "service": "ingest-jira", "ready": True}), 200, {"Content-Type": "application/json"})
    return ingest_jira(request)
