"""
Jira issues ingestion -> BigQuery (Cloud Run / Functions Framework)

Fixes:
- Jira Cloud removed POST /rest/api/3/search on some tenants (HTTP 410). Use /rest/api/3/search/jql instead.
- Uses token-based pagination (nextPageToken) for /search/jql.
- Works with Cloud Run secrets-as-env (via --set-secrets) OR plain env vars.

Required env vars:
- GCP_PROJECT_ID
- BQ_DATASET_ID (default: qa_metrics)
- BQ_TABLE_ID   (default: jira_issues)

Jira auth (either naming is accepted):
- Preferred (matches your Secret names):
    JIRA_SITE, JIRA_USER, JIRA_API_TOKEN
- Also accepted (legacy):
    JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN

Project/field mapping:
- TARGET_PROJECT_KEY (default: PC)
- TARGET_TEAM_FIELD, TARGET_SPRINT_FIELD
- TARGET_STORYPOINTS_FIELD (default: customfield_10016)
  NOTE: If you use time estimates instead of story points, set:
    TARGET_STORYPOINTS_FIELD=timeoriginalestimate
  (Jira returns timeoriginalestimate in seconds.)

Optional:
- PAGE_SIZE (default: 50)
- DEFAULT_LOOKBACK_DAYS (default: 120)
- BQ_INSERT_MAX_ROWS (default: 200)
- BQ_INSERT_MAX_BYTES (default: 8_000_000)
- STORE_PAYLOAD (default: 0)
- STORE_DESCRIPTION (default: 0)
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
BQ_TABLE_ID = os.getenv("BQ_TABLE_ID", "jira_issues")

# Jira auth (secrets-as-env friendly)
JIRA_SITE = os.getenv("JIRA_SITE") or os.getenv("JIRA_BASE_URL")
JIRA_USER = os.getenv("JIRA_USER") or os.getenv("JIRA_EMAIL")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")

TARGET_PROJECT_KEY = os.getenv("TARGET_PROJECT_KEY", "PC")
TARGET_TEAM_FIELD = os.getenv("TARGET_TEAM_FIELD", "customfield_10001")
TARGET_SPRINT_FIELD = os.getenv("TARGET_SPRINT_FIELD", "customfield_10020")
TARGET_STORYPOINTS_FIELD = os.getenv("TARGET_STORYPOINTS_FIELD", "customfield_10016")

PAGE_SIZE = int(os.getenv("PAGE_SIZE", "50"))
DEFAULT_LOOKBACK_DAYS = int(os.getenv("DEFAULT_LOOKBACK_DAYS", "120"))

BQ_INSERT_MAX_ROWS = int(os.getenv("BQ_INSERT_MAX_ROWS", "200"))
BQ_INSERT_MAX_BYTES = int(os.getenv("BQ_INSERT_MAX_BYTES", "8000000"))

STORE_PAYLOAD = os.getenv("STORE_PAYLOAD", "0").lower() in {"1", "true", "yes"}
STORE_DESCRIPTION = os.getenv("STORE_DESCRIPTION", "0").lower() in {"1", "true", "yes"}

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


# ------------------------
# BigQuery
# ------------------------

def _bq_client() -> bigquery.Client:
    if not GCP_PROJECT_ID:
        raise RuntimeError("Missing env var: GCP_PROJECT_ID")
    return bigquery.Client(project=GCP_PROJECT_ID)


def ensure_table() -> None:
    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"
    table_ref = bigquery.Table(table_fq)

    schema = [
        bigquery.SchemaField("issue_key", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("issue_id", "STRING"),
        bigquery.SchemaField("project_key", "STRING"),
        bigquery.SchemaField("issue_type", "STRING"),
        bigquery.SchemaField("created", "TIMESTAMP"),
        bigquery.SchemaField("updated", "TIMESTAMP"),
        bigquery.SchemaField("resolutiondate", "TIMESTAMP"),
        bigquery.SchemaField("status", "STRING"),
        bigquery.SchemaField("priority", "STRING"),
        bigquery.SchemaField("resolution", "STRING"),
        bigquery.SchemaField("reporter", "STRING"),
        bigquery.SchemaField("reporter_account_id", "STRING"),
        bigquery.SchemaField("assignee", "STRING"),
        bigquery.SchemaField("assignee_account_id", "STRING"),
        bigquery.SchemaField("team", "STRING"),
        bigquery.SchemaField("components", "STRING"),
        bigquery.SchemaField("fix_versions", "STRING"),
        bigquery.SchemaField("sprint", "STRING"),
        bigquery.SchemaField("story_points", "FLOAT"),
        bigquery.SchemaField("description_plain", "STRING"),
        bigquery.SchemaField("payload", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    table_ref.schema = schema
    table_ref.time_partitioning = bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY, field="updated")
    table_ref.clustering_fields = ["project_key", "issue_type", "status", "team"]

    # create_table(exists_ok=True) will update nothing if it exists
    bq.create_table(table_ref, exists_ok=True)


def get_last_updated_ts(project_key: str) -> Optional[datetime.datetime]:
    bq = _bq_client()
    query = f"""
      SELECT MAX(updated) AS max_updated
      FROM `{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}`
      WHERE project_key = @project_key
    """
    job = bq.query(
        query,
        job_config=bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("project_key", "STRING", project_key)]
        ),
    )
    rows = list(job.result())
    if not rows or rows[0]["max_updated"] is None:
        return None
    return rows[0]["max_updated"]


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
            issue_key = r.get("issue_key") or ""
            updated = r.get("updated") or ""
            row_ids.append(f"{issue_key}:{updated}")

        errors = bq.insert_rows_json(table_fq, chunk, row_ids=row_ids)
        if errors:
            all_errors.extend(errors)
        else:
            inserted += len(chunk)

    return inserted, all_errors


# ------------------------
# Jira fetch (NEW endpoint)
# ------------------------

def fetch_jira_issues(
    project_key: str,
    since_ts: datetime.datetime,
    until_ts: datetime.datetime,
) -> Iterable[List[Dict[str, Any]]]:

    if not (JIRA_SITE and JIRA_USER and JIRA_API_TOKEN):
        raise RuntimeError("Missing Jira env vars: JIRA_SITE/JIRA_USER/JIRA_API_TOKEN (or legacy JIRA_BASE_URL/JIRA_EMAIL)")

    # /search/jql is GET + token pagination. Keep fields small.
    fields_to_fetch = [
        "project",
        "issuetype",
        "created",
        "updated",
        "resolutiondate",
        "status",
        "priority",
        "resolution",
        "reporter",
        "assignee",
        "components",
        "fixVersions",
        TARGET_TEAM_FIELD,
        TARGET_SPRINT_FIELD,
        TARGET_STORYPOINTS_FIELD,
    ]
    if STORE_DESCRIPTION:
        fields_to_fetch.append("description")

    # Jira JQL supports ISO 8601 timestamps in quotes.
    since_s = since_ts.astimezone(datetime.timezone.utc).isoformat()
    until_s = until_ts.astimezone(datetime.timezone.utc).isoformat()

    jql = (
        f'project = "{project_key}" '
        f'AND updated >= "{since_s}" '
        f'AND updated <= "{until_s}" '
        f'ORDER BY updated ASC'
    )

    url = f"{JIRA_SITE.rstrip('/')}/rest/api/3/search/jql"

    next_token: Optional[str] = None

    while True:
        params = {
            "jql": jql,
            "maxResults": PAGE_SIZE,
            # safest in practice: comma-separated field list
            "fields": ",".join(fields_to_fetch),
        }
        if next_token:
            params["nextPageToken"] = next_token

        resp = requests.get(url, headers=_jira_headers(), params=params, timeout=REQUEST_TIMEOUT)
        if resp.status_code >= 400:
            raise RuntimeError(f"Jira API error {resp.status_code}: {resp.text[:800]}")

        data = resp.json()
        issues = data.get("issues", []) or []
        next_token = data.get("nextPageToken")
        is_last = bool(data.get("isLast")) if "isLast" in data else (not next_token)

        if not issues:
            break

        rows: List[Dict[str, Any]] = []
        ingested_at = datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

        for issue in issues:
            fields = issue.get("fields", {}) or {}

            # safety filter
            if (fields.get("project") or {}).get("key") != project_key:
                continue

            components = ",".join([c.get("name", "") for c in (fields.get("components") or []) if c.get("name")])
            fix_versions = ",".join([v.get("name", "") for v in (fields.get("fixVersions") or []) if v.get("name")])

            sprint_val = fields.get(TARGET_SPRINT_FIELD)
            sprint_names: List[str] = []
            if isinstance(sprint_val, list):
                for s in sprint_val:
                    if isinstance(s, dict) and s.get("name"):
                        sprint_names.append(str(s["name"]))
            elif isinstance(sprint_val, dict) and sprint_val.get("name"):
                sprint_names.append(str(sprint_val["name"]))
            sprint = ",".join(sprint_names) if sprint_names else None

            sp_raw = fields.get(TARGET_STORYPOINTS_FIELD)
            try:
                story_points = float(sp_raw) if sp_raw is not None else None
            except Exception:
                story_points = None

            description_plain = None
            if STORE_DESCRIPTION:
                desc = fields.get("description")
                if desc is not None:
                    description_plain = json.dumps(desc, ensure_ascii=False)[:5000]

            payload = None
            if STORE_PAYLOAD:
                payload = json.dumps(issue, ensure_ascii=False)[:50000]

            row = {
                "issue_key": issue.get("key"),
                "issue_id": issue.get("id"),
                "project_key": (fields.get("project") or {}).get("key"),
                "issue_type": (fields.get("issuetype") or {}).get("name"),
                "created": _dt(fields["created"]).isoformat() if fields.get("created") else None,
                "updated": _dt(fields["updated"]).isoformat() if fields.get("updated") else None,
                "resolutiondate": _dt(fields["resolutiondate"]).isoformat() if fields.get("resolutiondate") else None,
                "status": (fields.get("status") or {}).get("name"),
                "priority": (fields.get("priority") or {}).get("name"),
                "resolution": (fields.get("resolution") or {}).get("name") if fields.get("resolution") else None,
                "reporter": (fields.get("reporter") or {}).get("displayName"),
                "reporter_account_id": (fields.get("reporter") or {}).get("accountId"),
                "assignee": (fields.get("assignee") or {}).get("displayName") if fields.get("assignee") else None,
                "assignee_account_id": (fields.get("assignee") or {}).get("accountId") if fields.get("assignee") else None,
                "team": fields.get(TARGET_TEAM_FIELD),
                "components": components or None,
                "fix_versions": fix_versions or None,
                "sprint": sprint,
                "story_points": story_points,
                "description_plain": description_plain,
                "payload": payload,
                "_ingested_at": ingested_at,
            }
            rows.append(row)

        yield rows

        if is_last:
            break

        time.sleep(0.1)


# ------------------------
# HTTP handler
# ------------------------

def hello_http(request):
    try:
        ensure_table()

        body = request.get_json(silent=True) or {}

        # accept both keys (people keep sending {"project":"PC"})
        project_key = body.get("project_key") or body.get("project") or TARGET_PROJECT_KEY
        if not isinstance(project_key, str) or not project_key.strip():
            raise RuntimeError("Pass a string for project_key/project")

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
            last_updated = get_last_updated_ts(project_key)
            if last_updated is not None:
                since_ts = last_updated - datetime.timedelta(days=2)
            else:
                since_ts = now - datetime.timedelta(days=lookback_days)

            min_since = now - datetime.timedelta(days=lookback_days)
            if since_ts < min_since:
                since_ts = min_since

        if until_ts is None:
            until_ts = now

        total_rows = 0
        inserted_rows = 0
        page_count = 0
        all_errors: List[Any] = []

        for page_rows in fetch_jira_issues(project_key, since_ts, until_ts):
            page_count += 1
            total_rows += len(page_rows)

            if not dry_run:
                ins, errs = insert_rows(page_rows)
                inserted_rows += ins
                if errs:
                    all_errors.extend(errs)

        status = "OK" if not all_errors else "PARTIAL"
        resp = {
            "status": status,
            "project_key": project_key,
            "since_ts": since_ts.isoformat(),
            "until_ts": until_ts.isoformat(),
            "pages_processed": page_count,
            "rows_fetched": total_rows,
            "rows_inserted": inserted_rows,
            "errors": all_errors[:50],
        }
        return jsonify(resp), (200 if status == "OK" else 207)

    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500
