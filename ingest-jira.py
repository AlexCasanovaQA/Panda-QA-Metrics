"""
Jira issues ingestion -> BigQuery (Cloud Run / Functions Framework)

Changes vs your current deploy:
- Uses Jira Cloud /rest/api/3/search/jql (some tenants return 410 for /search).
- Token pagination (nextPageToken) with loop protection.
- Adds safe caps: default lookback=730 days (2 years) + MAX_LOOKBACK_DAYS hard cap.
- Accepts both {"project_key":"PC"} and {"project":"PC"}.
- Creates/refreshes qa_metrics.jira_issues_latest view (dedupe by issue_key).
- Avoids schema drift pain: ensures BOTH id and issue_id columns exist (so Looker / old SQL won't break).

Auth env vars (Cloud Run secrets-as-env OK):
- JIRA_SITE (preferred) or JIRA_BASE_URL
- JIRA_USER (preferred) or JIRA_EMAIL
- JIRA_API_TOKEN

BQ env vars:
- GCP_PROJECT_ID
- BQ_DATASET_ID (default qa_metrics)
- BQ_TABLE_ID (default jira_issues)

Optional:
- TARGET_PROJECT_KEY (default PC)
- TARGET_TEAM_FIELD (default customfield_10001)
- TARGET_SPRINT_FIELD (default customfield_10020)
- PAGE_SIZE (default 100)
- DEFAULT_LOOKBACK_DAYS (default 730)
- MAX_LOOKBACK_DAYS (default 730)
- BQ_INSERT_MAX_ROWS (default 200)
- BQ_INSERT_MAX_BYTES (default 8_000_000)
- STORE_PAYLOAD (default 0)
- STORE_DESCRIPTION (default 0)
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

JIRA_SITE = os.getenv("JIRA_SITE") or os.getenv("JIRA_BASE_URL")
JIRA_USER = os.getenv("JIRA_USER") or os.getenv("JIRA_EMAIL")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")

TARGET_PROJECT_KEY = os.getenv("TARGET_PROJECT_KEY", "PC")
TARGET_TEAM_FIELD = os.getenv("TARGET_TEAM_FIELD", "customfield_10001")
TARGET_SPRINT_FIELD = os.getenv("TARGET_SPRINT_FIELD", "customfield_10020")

PAGE_SIZE = int(os.getenv("PAGE_SIZE", "100"))
DEFAULT_LOOKBACK_DAYS = int(os.getenv("DEFAULT_LOOKBACK_DAYS", "730"))  # 2 years
MAX_LOOKBACK_DAYS = int(os.getenv("MAX_LOOKBACK_DAYS", "730"))

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
    }


def _require_env() -> None:
    missing = []
    if not GCP_PROJECT_ID:
        missing.append("GCP_PROJECT_ID")
    if not (JIRA_SITE and JIRA_USER and JIRA_API_TOKEN):
        missing.append("JIRA_SITE/JIRA_USER/JIRA_API_TOKEN (or legacy JIRA_BASE_URL/JIRA_EMAIL)")
    if missing:
        raise RuntimeError("Missing env vars: " + ", ".join(missing))


# ------------------------
# BigQuery
# ------------------------

def _bq_client() -> bigquery.Client:
    _require_env()
    return bigquery.Client(project=GCP_PROJECT_ID)


def _desired_schema() -> List[bigquery.SchemaField]:
    # Keep BOTH "id" and "issue_id" to avoid breaking old SQL/Looker.
    return [
        bigquery.SchemaField("issue_key", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("id", "STRING"),
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
        # keep in schema for future, but we won't populate now
        bigquery.SchemaField("story_points", "FLOAT"),
        bigquery.SchemaField("description_plain", "STRING"),
        bigquery.SchemaField("payload", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]


def ensure_table_and_latest_view() -> None:
    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"

    try:
        table = bq.get_table(table_fq)
        # Patch schema (only ADD columns; never drops/renames)
        existing = {f.name for f in table.schema}
        desired = _desired_schema()
        to_add = [f for f in desired if f.name not in existing]
        if to_add:
            table.schema = list(table.schema) + to_add
            bq.update_table(table, ["schema"])
            print(f"[bq] added columns: {[f.name for f in to_add]}")
    except Exception:
        # Create table if missing
        table = bigquery.Table(table_fq, schema=_desired_schema())
        table.time_partitioning = bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY, field="updated")
        table.clustering_fields = ["project_key", "issue_type", "status", "team"]
        bq.create_table(table, exists_ok=True)
        print("[bq] created table")

    # Ensure latest view exists
    latest_view_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.jira_issues_latest"
    view_sql = f"""
    CREATE OR REPLACE VIEW `{latest_view_fq}` AS
    SELECT * EXCEPT(rn)
    FROM (
      SELECT
        t.*,
        ROW_NUMBER() OVER (
          PARTITION BY t.issue_key
          ORDER BY t.updated DESC, t._ingested_at DESC
        ) AS rn
      FROM `{table_fq}` t
    )
    WHERE rn = 1
    """
    bq.query(view_sql).result()
    print("[bq] ensured view jira_issues_latest")


def get_last_updated_ts(project_key: str) -> Optional[datetime.datetime]:
    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"
    query = f"""
      SELECT MAX(updated) AS max_updated
      FROM `{table_fq}`
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
# Jira fetch
# ------------------------

def fetch_jira_pages(project_key: str, jql: str, fields_csv: str, max_pages: int = 0) -> Iterable[Dict[str, Any]]:
    url = f"{JIRA_SITE.rstrip('/')}/rest/api/3/search/jql"
    headers = _jira_headers()

    next_page_token = None
    seen_tokens = set()
    page_num = 0

    # Reuse connections
    with requests.Session() as sess:
        while True:
            page_num += 1
            if max_pages and page_num > max_pages:
                print(f"[jira] max_pages reached ({max_pages}), stopping")
                break

            params = {"jql": jql, "maxResults": PAGE_SIZE, "fields": fields_csv}
            if next_page_token:
                params["nextPageToken"] = next_page_token

            resp = sess.get(url, headers=headers, params=params, timeout=REQUEST_TIMEOUT)
            if resp.status_code >= 400:
                raise RuntimeError(f"Jira API error {resp.status_code}: {resp.text[:800]}")

            data = resp.json()
            issues = data.get("issues", []) or []
            is_last = bool(data.get("isLast", False))
            new_token = data.get("nextPageToken")

            print(f"[jira] page={page_num} issues={len(issues)} is_last={is_last}")

            yield {"issues": issues, "is_last": is_last, "next_page_token": new_token}

            if is_last or not issues:
                break

            if not new_token:
                raise RuntimeError("Jira search/jql: isLast=false but nextPageToken missing")
            if new_token in seen_tokens:
                raise RuntimeError("Jira pagination loop detected (nextPageToken repeated)")
            seen_tokens.add(new_token)
            next_page_token = new_token

            time.sleep(0.1)


def transform_issues_to_rows(issues: List[Dict[str, Any]], project_key: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    ingested_at = datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

    for issue in issues:
        fields = issue.get("fields", {}) or {}

        # Safety filter
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

        description_plain = None
        if STORE_DESCRIPTION:
            desc = fields.get("description")
            if desc is not None:
                description_plain = json.dumps(desc, ensure_ascii=False)[:5000]

        payload = None
        if STORE_PAYLOAD:
            payload = json.dumps(issue, ensure_ascii=False)[:50000]

        issue_id_val = issue.get("id")
        row = {
            "issue_key": issue.get("key"),
            "id": issue_id_val,
            "issue_id": issue_id_val,  # keep both
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
            "story_points": None,  # intentionally off for now
            "description_plain": description_plain,
            "payload": payload,
            "_ingested_at": ingested_at,
        }
        rows.append(row)

    return rows


# ------------------------
# Cloud Run entrypoint
# ------------------------

def hello_http(request):
    try:
        _require_env()

        body = request.get_json(silent=True) or {}

        # accept both keys (people keep sending {"project":"PC"})
        project_key = body.get("project_key") or body.get("project") or TARGET_PROJECT_KEY
        if not isinstance(project_key, str) or not project_key.strip():
            raise RuntimeError("Pass a string for project_key/project")

        debug = bool(body.get("debug", False))
        dry_run = bool(body.get("dry_run", False))
        max_pages = int(body.get("max_pages", 0))  # 0 = unlimited

        # Hard cap for safety (2 years by default)
        lookback_days = int(body.get("lookback_days", DEFAULT_LOOKBACK_DAYS))
        lookback_days = min(lookback_days, MAX_LOOKBACK_DAYS)

        ensure_table_and_latest_view()

        now = datetime.datetime.now(datetime.timezone.utc)

        # explicit since/until override
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

        if since_ts is None:
            last_updated = get_last_updated_ts(project_key)
            if last_updated is not None:
                since_ts = last_updated - datetime.timedelta(days=2)  # overlap for safety
            else:
                since_ts = now - datetime.timedelta(days=lookback_days)

            min_since = now - datetime.timedelta(days=lookback_days)
            if since_ts < min_since:
                since_ts = min_since

        if until_ts is None:
            until_ts = now

        # DEBUG mode: quick probes only, no BigQuery inserts
        if debug:
            base = JIRA_SITE.rstrip("/")
            probe: Dict[str, Any] = {"project_key": project_key}

            r_proj = requests.get(
                f"{base}/rest/api/3/project/{project_key}",
                headers=_jira_headers(),
                timeout=REQUEST_TIMEOUT,
            )
            probe["project_status_code"] = r_proj.status_code
            probe["project_response_snippet"] = (r_proj.text or "")[:500]

            # One-result search probe
            jql_probe = f'project = "{project_key}" ORDER BY updated DESC'
            r_search = requests.get(
                f"{base}/rest/api/3/search/jql",
                headers=_jira_headers(),
                params={"jql": jql_probe, "maxResults": 1, "fields": "updated"},
                timeout=REQUEST_TIMEOUT,
            )
            probe["search_status_code"] = r_search.status_code
            probe["search_response_snippet"] = (r_search.text or "")[:800]

            js = r_search.json() if r_search.headers.get("content-type", "").startswith("application/json") else {}
            issues = js.get("issues") or []
            probe["latest_issue_key"] = issues[0].get("key") if issues else None
            probe["is_last"] = js.get("isLast")
            probe["nextPageToken"] = js.get("nextPageToken")

            return jsonify({"status": "DEBUG", **probe}), 200

        # Build JQL
        since_s = since_ts.strftime("%Y/%m/%d %H:%M")
        until_s = until_ts.strftime("%Y/%m/%d %H:%M")
        jql = (
            f'project = "{project_key}" '
            f'AND updated >= "{since_s}" '
            f'AND updated <= "{until_s}" '
            f'ORDER BY updated ASC'
        )

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
        ]
        if STORE_DESCRIPTION:
            fields_to_fetch.append("description")
        fields_csv = ",".join(fields_to_fetch)

        total_rows = 0
        inserted_rows = 0
        page_count = 0
        all_errors: List[Any] = []

        for page in fetch_jira_pages(project_key, jql=jql, fields_csv=fields_csv, max_pages=max_pages):
            page_count += 1
            issues = page["issues"]
            rows = transform_issues_to_rows(issues, project_key)

            total_rows += len(rows)

            if not dry_run and rows:
                ins, errs = insert_rows(rows)
                inserted_rows += ins
                if errs:
                    all_errors.extend(errs)

        status = "OK" if not all_errors else "PARTIAL"
        resp = {
            "status": status,
            "project_key": project_key,
            "since_ts": since_ts.isoformat(),
            "until_ts": until_ts.isoformat(),
            "lookback_days_effective": lookback_days,
            "pages_processed": page_count,
            "rows_fetched": total_rows,
            "rows_inserted": inserted_rows,
            "errors": all_errors[:50],
        }
        return jsonify(resp), (200 if status == "OK" else 207)

    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500
