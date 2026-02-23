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
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, Optional

import functions_framework
import requests
from google.cloud import bigquery


# ----------------------------
# Config
# ----------------------------

DEFAULT_LOOKBACK_DAYS = int(os.environ.get("LOOKBACK_DAYS", "30"))
BQ_DATASET_ID = os.environ.get("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.environ.get("BQ_TABLE_ID", "jira_issues_v2")

JIRA_BASE_URL = os.environ.get("JIRA_BASE_URL")  # required
JIRA_EMAIL = os.environ.get("JIRA_EMAIL")  # required
JIRA_API_TOKEN = os.environ.get("JIRA_API_TOKEN")  # required
JIRA_PROJECT_KEYS = os.environ.get("JIRA_PROJECT_KEYS", "").strip()

# Custom field ids
TEAM_FIELD_ID = os.environ.get("JIRA_TEAM_FIELD_ID", "customfield_10001")
SEVERITY_FIELD_ID = os.environ.get("JIRA_SEVERITY_FIELD_ID", "").strip() or None
SPRINT_FIELD_ID = os.environ.get("JIRA_SPRINT_FIELD_ID", "customfield_10020")


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
    if SEVERITY_FIELD_ID:
        fields.append(SEVERITY_FIELD_ID)
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
    r = requests.get(url, headers=_jira_headers(), auth=_jira_auth(), params=params, timeout=60)
    r.raise_for_status()
    return r.json()


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
    if not SEVERITY_FIELD_ID:
        return None

    raw = fields.get(SEVERITY_FIELD_ID)

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
    except Exception:
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
    # Normalize timezone format
    try:
        # Insert colon in timezone if needed
        if value.endswith("+0000"):
            value = value[:-5] + "+00:00"
        elif value.endswith("-0000"):
            value = value[:-5] + "-00:00"
        # Some Jira returns Z
        if value.endswith("Z"):
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        return datetime.fromisoformat(value)
    except Exception:
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
        "team": None,
        "labels": json.dumps(fields.get("labels") or []),
        "components": json.dumps([c.get("name") for c in (fields.get("components") or []) if isinstance(c, dict)]),
        "fix_versions": json.dumps([v.get("name") for v in (fields.get("fixVersions") or []) if isinstance(v, dict)]),
        "affects_versions": json.dumps([v.get("name") for v in (fields.get("versions") or []) if isinstance(v, dict)]),
        "sprint": None,
        "resolution": (fields.get("resolution") or {}).get("name"),
        "raw_json": json.dumps(issue, ensure_ascii=False),
        "_ingested_at": _iso(_utc_now()),
    }

    # Team (POD) custom field
    team_val = fields.get(TEAM_FIELD_ID)
    if isinstance(team_val, dict):
        rec["team"] = team_val.get("value") or team_val.get("name")
    elif isinstance(team_val, str):
        rec["team"] = team_val

    # Sprint: could be list of sprint strings
    sprint_val = fields.get(SPRINT_FIELD_ID) or fields.get("sprint")
    if isinstance(sprint_val, list) and sprint_val:
        # store raw list
        rec["sprint"] = json.dumps(sprint_val)
    elif isinstance(sprint_val, str):
        rec["sprint"] = sprint_val

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

    project_keys_raw = (req_json.get("project_keys") or JIRA_PROJECT_KEYS)
    project_keys = [p.strip() for p in project_keys_raw.split(",") if p.strip()]
    if not project_keys:
        return (
            json.dumps({"error": "No Jira projects provided. Set JIRA_PROJECT_KEYS or pass project_keys"}),
            400,
            {"Content-Type": "application/json"},
        )

    until = _utc_now()
    since = until - timedelta(days=lookback_days)

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
                errors = bq.insert_rows_json(table_ref, rows)
                if errors:
                    print("BigQuery insert errors:", errors[:3])
                    return (
                        json.dumps({"error": "BigQuery insert failed", "details": errors[:3]}),
                        500,
                        {"Content-Type": "application/json"},
                    )
                inserted += len(rows)
                print(f"Inserted {inserted} rows so far")
                rows.clear()

        # gentle pause to avoid Jira throttling
        time.sleep(0.25)

    if rows:
        errors = bq.insert_rows_json(table_ref, rows)
        if errors:
            print("BigQuery insert errors:", errors[:3])
            return (
                json.dumps({"error": "BigQuery insert failed", "details": errors[:3]}),
                500,
                {"Content-Type": "application/json"},
            )
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
