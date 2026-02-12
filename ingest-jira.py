import json
import os
import time
import random
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import google.auth
import requests
from flask import jsonify
from google.cloud import bigquery, secretmanager

# ----------------- GCP / BigQuery -----------------
_, PROJECT_ID = google.auth.default()

DATASET_ID = os.environ.get("BQ_DATASET", "qa_metrics")
TABLE_NAME = os.environ.get("BQ_TABLE", "jira_issues")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

# ----------------- Jira config -----------------
TARGET_PROJECT_KEY = os.environ.get("JIRA_PROJECT_KEY", "PC")

MAX_PAGES = int(os.environ.get("JIRA_MAX_PAGES", "50"))
PAGE_SIZE = int(os.environ.get("JIRA_PAGE_SIZE", "100"))  # max 100 for Jira Cloud

# Custom fields (configurable)
STORY_POINTS_FIELD = os.environ.get("JIRA_STORY_POINTS_FIELD_ID", "customfield_10016")
SPRINT_FIELD = os.environ.get("JIRA_SPRINT_FIELD_ID", "customfield_10020")
TEAM_FIELD = os.environ.get("JIRA_TEAM_FIELD_ID", "")          # e.g. customfield_12345
DISCIPLINE_FIELD = os.environ.get("JIRA_DISCIPLINE_FIELD_ID", "")  # e.g. customfield_54321

# Optional: restrict ingestion to a set of issue types (comma-separated). Empty => all.
ISSUE_TYPES = [t.strip() for t in os.environ.get("JIRA_ISSUE_TYPES", "Bug,Story,Task").split(",") if t.strip()]

# HTTP knobs
HTTP_TIMEOUT = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "30"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
BASE_BACKOFF = float(os.environ.get("BASE_BACKOFF_SECONDS", "1.0"))
MAX_BACKOFF = float(os.environ.get("MAX_BACKOFF_SECONDS", "30.0"))


# ----------------- Secrets -----------------
def get_secret(name: str) -> str:
    secret_name = f"projects/{PROJECT_ID}/secrets/{name}/versions/latest"
    resp = sm.access_secret_version(request={"name": secret_name})
    return resp.payload.data.decode("utf-8").strip()


def jira_site() -> str:
    site = get_secret("JIRA_SITE").rstrip("/")
    if site.endswith("/rest/api/3"):
        site = site[: -len("/rest/api/3")]
    return site


def jira_auth() -> Tuple[str, str]:
    return (get_secret("JIRA_USER"), get_secret("JIRA_API_TOKEN"))


# ----------------- Time helpers -----------------
def jira_ts_to_rfc3339(ts: Optional[str]) -> Optional[str]:
    """
    Jira Cloud timestamp example: 2026-01-21T08:46:18.478+0000
    BigQuery TIMESTAMP accepts RFC3339: 2026-01-21T08:46:18.478Z
    """
    if not ts:
        return None

    # Convert timezone like +0000 / -0700 -> +00:00 / -07:00
    if len(ts) >= 5 and ts[-5] in {"+", "-"} and ts[-4:].isdigit():
        ts = ts[:-5] + ts[-5:-2] + ":" + ts[-2:]

    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


# ----------------- ADF description extraction -----------------
def _adf_text(node: Any, out: List[str]) -> None:
    if node is None:
        return
    if isinstance(node, dict):
        if node.get("type") == "text" and isinstance(node.get("text"), str):
            out.append(node["text"])
        # recurse into content arrays
        content = node.get("content")
        if isinstance(content, list):
            for c in content:
                _adf_text(c, out)
    elif isinstance(node, list):
        for c in node:
            _adf_text(c, out)


def adf_to_text(adf: Any, max_len: int = 4000) -> Optional[str]:
    """
    Jira Cloud returns description in Atlassian Document Format (ADF) JSON.
    We extract plain text for KPI heuristics (completeness).
    """
    if adf is None:
        return None
    try:
        out: List[str] = []
        _adf_text(adf, out)
        text = " ".join([t.strip() for t in out if t and t.strip()])
        text = re.sub(r"\s+", " ", text).strip()  # type: ignore[name-defined]
        if not text:
            return None
        return text[:max_len]
    except Exception:
        # As fallback, store compact JSON (still useful to see non-null)
        try:
            s = json.dumps(adf)
            return s[:max_len]
        except Exception:
            return None


# Need regex for whitespace collapse
import re  # noqa: E402


# ----------------- Value extractors -----------------
def _extract_simple(val: Any) -> Optional[str]:
    """
    Accepts Jira field values that can be:
      - None
      - dict with keys like 'name'/'value'
      - list of dicts/strings
      - string/number
    Returns a comma-separated string for lists.
    """
    if val is None:
        return None

    if isinstance(val, str):
        s = val.strip()
        return s if s else None

    if isinstance(val, (int, float, bool)):
        return str(val)

    if isinstance(val, dict):
        for k in ("name", "value", "key", "displayName"):
            v = val.get(k)
            if isinstance(v, str) and v.strip():
                return v.strip()
        # last resort: json
        return json.dumps(val)[:2000]

    if isinstance(val, list):
        parts: List[str] = []
        for it in val:
            s = _extract_simple(it)
            if s:
                parts.append(s)
        return ", ".join(parts) if parts else None

    # unknown type
    try:
        return str(val)
    except Exception:
        return None


def _extract_components(components: Any) -> Optional[str]:
    if not components:
        return None
    if isinstance(components, list):
        names = []
        for c in components:
            if isinstance(c, dict) and c.get("name"):
                names.append(str(c["name"]))
        return ", ".join(names) if names else None
    return _extract_simple(components)


def _extract_fix_versions(fix_versions: Any) -> Optional[str]:
    if not fix_versions:
        return None
    if isinstance(fix_versions, list):
        names = []
        for v in fix_versions:
            if isinstance(v, dict) and v.get("name"):
                names.append(str(v["name"]))
        return ", ".join(names) if names else None
    return _extract_simple(fix_versions)


def _extract_sprints(sprints: Any) -> Optional[str]:
    """
    Sprint custom field can return:
      - list of dicts with 'name'
      - list of legacy strings like "...,name=Sprint 12,..."
    """
    if not sprints:
        return None

    out: List[str] = []
    if isinstance(sprints, list):
        for s in sprints:
            if isinstance(s, dict) and s.get("name"):
                out.append(str(s["name"]))
            elif isinstance(s, str):
                m = re.search(r"name=([^,]+)", s)
                if m:
                    out.append(m.group(1))
                else:
                    out.append(s)
    elif isinstance(sprints, dict):
        if sprints.get("name"):
            out.append(str(sprints["name"]))
    elif isinstance(sprints, str):
        m = re.search(r"name=([^,]+)", sprints)
        out.append(m.group(1) if m else sprints)

    out = [x.strip() for x in out if x and x.strip()]
    if not out:
        return None
    # de-dupe preserving order
    seen = set()
    deduped = []
    for x in out:
        if x not in seen:
            seen.add(x)
            deduped.append(x)
    return ", ".join(deduped)


# ----------------- BigQuery -----------------
def ensure_table() -> None:
    schema = [
        bigquery.SchemaField("id", "STRING"),
        bigquery.SchemaField("issue_key", "STRING"),
        bigquery.SchemaField("project_key", "STRING"),
        bigquery.SchemaField("summary", "STRING"),
        bigquery.SchemaField("description_plain", "STRING"),

        bigquery.SchemaField("issue_type", "STRING"),
        bigquery.SchemaField("status", "STRING"),
        bigquery.SchemaField("status_category", "STRING"),
        bigquery.SchemaField("priority", "STRING"),

        bigquery.SchemaField("assignee", "STRING"),
        bigquery.SchemaField("assignee_account_id", "STRING"),
        bigquery.SchemaField("reporter", "STRING"),
        bigquery.SchemaField("reporter_account_id", "STRING"),

        bigquery.SchemaField("team", "STRING"),       # POD = Team
        bigquery.SchemaField("sprint", "STRING"),
        bigquery.SchemaField("fix_versions", "STRING"),
        bigquery.SchemaField("components", "STRING"),
        bigquery.SchemaField("labels", "STRING"),
        bigquery.SchemaField("discipline", "STRING"),

        bigquery.SchemaField("story_points", "FLOAT"),

        bigquery.SchemaField("created", "TIMESTAMP"),
        bigquery.SchemaField("updated", "TIMESTAMP"),
        bigquery.SchemaField("resolutiondate", "TIMESTAMP"),
        bigquery.SchemaField("resolution", "STRING"),

        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
        bigquery.SchemaField("payload", "STRING"),
    ]

    table = bigquery.Table(TABLE_ID, schema=schema)
    # Partition by updated for incremental append table
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY, field="updated"
    )
    table.clustering_fields = ["project_key", "issue_type", "status", "team"]
    bq.create_table(table, exists_ok=True)


def get_last_updated() -> datetime:
    sql = f"""
      SELECT COALESCE(MAX(updated), TIMESTAMP('2000-01-01')) AS last_updated
      FROM `{TABLE_ID}`
    """
    rows = list(bq.query(sql))
    ts = rows[0]["last_updated"]
    # Ensure tz-aware UTC
    if ts is None:
        return datetime(2000, 1, 1, tzinfo=timezone.utc)
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    else:
        ts = ts.astimezone(timezone.utc)
    return ts


# ----------------- Jira fetching -----------------
def build_jql(since_ts: datetime) -> str:
    # Allow overriding the entire JQL (optional)
    env_jql = os.environ.get("JIRA_JQL", "").strip()
    since_str = since_ts.strftime("%Y/%m/%d %H:%M")

    if env_jql:
        # Support simple templating
        return (
            env_jql.replace("{project}", TARGET_PROJECT_KEY)
            .replace("{since}", since_str)
        )

    base = f'project = "{TARGET_PROJECT_KEY}" AND updated > "{since_str}"'
    if ISSUE_TYPES:
        quoted = ", ".join([f'"{t}"' for t in ISSUE_TYPES])
        base += f" AND issuetype IN ({quoted})"
    base += " ORDER BY updated ASC"
    return base


def request_with_retries(
    session: requests.Session,
    method: str,
    url: str,
    *,
    params: Optional[Dict[str, Any]] = None,
    auth: Optional[Tuple[str, str]] = None,
) -> requests.Response:
    last_exc: Optional[Exception] = None
    for attempt in range(MAX_RETRIES):
        try:
            r = session.request(
                method,
                url,
                params=params,
                auth=auth,
                headers={"Accept": "application/json"},
                timeout=HTTP_TIMEOUT,
            )

            if r.status_code in (429, 500, 502, 503, 504):
                ra = r.headers.get("Retry-After")
                if ra and ra.isdigit():
                    sleep_s = min(float(ra), MAX_BACKOFF)
                else:
                    backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
                    jitter = random.uniform(0, 0.25 * backoff)
                    sleep_s = backoff + jitter
                time.sleep(sleep_s)
                continue

            r.raise_for_status()
            return r

        except requests.RequestException as e:
            last_exc = e
            backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
            jitter = random.uniform(0, 0.25 * backoff)
            time.sleep(backoff + jitter)

    raise RuntimeError(f"HTTP failed after retries: {last_exc}")


def fetch_jira_issues(since_ts: datetime) -> List[Dict[str, Any]]:
    site = jira_site()
    auth = jira_auth()

    url = f"{site}/rest/api/3/search/jql"
    jql = build_jql(since_ts)

    fields_to_fetch: List[str] = [
        "summary",
        "description",
        "project",
        "issuetype",
        "status",
        "priority",
        "assignee",
        "reporter",
        "created",
        "updated",
        "resolutiondate",
        "resolution",
        "labels",
        "components",
        "fixVersions",
        STORY_POINTS_FIELD,
        SPRINT_FIELD,
    ]

    if TEAM_FIELD:
        fields_to_fetch.append(TEAM_FIELD)
    if DISCIPLINE_FIELD:
        fields_to_fetch.append(DISCIPLINE_FIELD)

    all_rows: List[Dict[str, Any]] = []
    next_page_token: Optional[str] = None
    page = 0

    with requests.Session() as session:
        while True:
            if page >= MAX_PAGES:
                break

            params: Dict[str, Any] = {
                "jql": jql,
                "maxResults": PAGE_SIZE,
                "fields": fields_to_fetch,
            }
            if next_page_token:
                params["nextPageToken"] = next_page_token

            data = request_with_retries(session, "GET", url, params=params, auth=auth).json()
            issues = data.get("issues", []) or []
            if not issues:
                break

            now_iso = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

            for issue in issues:
                fields = issue.get("fields", {}) or {}
                project = fields.get("project") or {}
                project_key = project.get("key")

                if project_key != TARGET_PROJECT_KEY:
                    continue

                labels = fields.get("labels") or []
                components = fields.get("components") or []
                fix_versions = fields.get("fixVersions") or []

                assignee = fields.get("assignee") or {}
                reporter = fields.get("reporter") or {}
                status = fields.get("status") or {}
                status_cat = (status.get("statusCategory") or {}).get("name")

                description_plain = adf_to_text(fields.get("description"))

                row = {
                    "id": issue.get("id"),
                    "issue_key": issue.get("key"),
                    "project_key": project_key,
                    "summary": fields.get("summary"),
                    "description_plain": description_plain,

                    "issue_type": (fields.get("issuetype") or {}).get("name"),
                    "status": status.get("name"),
                    "status_category": status_cat,
                    "priority": (fields.get("priority") or {}).get("name"),

                    "assignee": assignee.get("displayName"),
                    "assignee_account_id": assignee.get("accountId"),
                    "reporter": reporter.get("displayName"),
                    "reporter_account_id": reporter.get("accountId"),

                    "team": _extract_simple(fields.get(TEAM_FIELD)) if TEAM_FIELD else None,
                    "sprint": _extract_sprints(fields.get(SPRINT_FIELD)),
                    "fix_versions": _extract_fix_versions(fix_versions),
                    "components": _extract_components(components),
                    "labels": ", ".join(labels) if labels else None,
                    "discipline": _extract_simple(fields.get(DISCIPLINE_FIELD)) if DISCIPLINE_FIELD else None,

                    "story_points": fields.get(STORY_POINTS_FIELD),

                    "created": jira_ts_to_rfc3339(fields.get("created")),
                    "updated": jira_ts_to_rfc3339(fields.get("updated")),
                    "resolutiondate": jira_ts_to_rfc3339(fields.get("resolutiondate")),
                    "resolution": (fields.get("resolution") or {}).get("name"),

                    "_ingested_at": now_iso,
                    "payload": json.dumps(issue),
                }
                all_rows.append(row)

            if data.get("isLast") is True:
                break

            next_page_token = data.get("nextPageToken")
            if not next_page_token:
                break

            page += 1

    return all_rows


def insert_rows(rows: List[Dict[str, Any]]) -> None:
    if not rows:
        return

    # Streaming dedupe: insertId = issue_key:updated (avoid exact duplicates)
    row_ids = [
        (f'{r.get("issue_key")}:{r.get("updated")}' if r.get("issue_key") and r.get("updated") else None)
        for r in rows
    ]
    errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors[:3]}{'...' if len(errors) > 3 else ''}")


# ----------------- Cloud Function entrypoint -----------------
def hello_http(request):
    try:
        ensure_table()
        last_updated = get_last_updated()
        rows = fetch_jira_issues(last_updated)
        insert_rows(rows)
        return (jsonify({"status": "OK", "rows": len(rows), "since": last_updated.isoformat()}), 200)
    except Exception as e:
        return (jsonify({"status": "ERROR", "message": str(e)}), 500)
