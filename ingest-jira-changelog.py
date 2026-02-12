import json
import os
import time
import random
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional, Tuple

import google.auth
import requests
from flask import jsonify
from google.cloud import bigquery, secretmanager

# -------------------- CONFIG --------------------
_, PROJECT_ID = google.auth.default()

DATASET_ID = os.environ.get("BQ_DATASET", "qa_metrics")
TABLE_NAME = os.environ.get("BQ_TABLE", "jira_changelog")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"

TARGET_PROJECT_KEY = os.environ.get("JIRA_PROJECT_KEY", "PC")

# To avoid upstream timeouts
MAX_ISSUES_PER_RUN = int(os.environ.get("MAX_ISSUES_PER_RUN", "50"))
MAX_RUNTIME_SECONDS = int(os.environ.get("MAX_RUNTIME_SECONDS", "240"))  # keep < scheduler timeout
HTTP_TIMEOUT_SECONDS = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "20"))
OVERLAP_MINUTES = int(os.environ.get("OVERLAP_MINUTES", "180"))  # re-scan 3h for borders

SEARCH_PAGE_SIZE = int(os.environ.get("SEARCH_PAGE_SIZE", "100"))
CHANGELOG_PAGE_SIZE = int(os.environ.get("CHANGELOG_PAGE_SIZE", "100"))

MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
BASE_BACKOFF_SECONDS = float(os.environ.get("BASE_BACKOFF_SECONDS", "1.0"))
MAX_BACKOFF_SECONDS = float(os.environ.get("MAX_BACKOFF_SECONDS", "30.0"))

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

# -------------------- SECRETS --------------------
def get_secret(name: str) -> str:
    secret_name = f"projects/{PROJECT_ID}/secrets/{name}/versions/latest"
    resp = sm.access_secret_version(request={"name": secret_name})
    return resp.payload.data.decode("utf-8").strip()

def jira_auth() -> Tuple[str, str]:
    return (get_secret("JIRA_USER"), get_secret("JIRA_API_TOKEN"))

def jira_site() -> str:
    site = get_secret("JIRA_SITE").rstrip("/")
    if site.endswith("/rest/api/3"):
        site = site[:-len("/rest/api/3")]
    return site

# -------------------- TIME HELPERS --------------------
def jira_ts_to_bq(ts: Optional[str]) -> Optional[str]:
    """
    Jira: 2026-01-21T08:46:18.478+0000  -> RFC3339: 2026-01-21T08:46:18.478Z
    """
    if not ts:
        return None

    # Convert timezone like +0000 / -0700 -> +00:00 / -07:00
    if len(ts) >= 5 and ts[-5] in {"+", "-"} and ts[-4:].isdigit():
        ts = ts[:-5] + ts[-5:-2] + ":" + ts[-2:]

    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# -------------------- HTTP WITH RETRIES --------------------
def request_with_retries(session: requests.Session, method: str, url: str, **kwargs) -> requests.Response:
    last_exc = None
    for attempt in range(MAX_RETRIES):
        try:
            r = session.request(method, url, timeout=HTTP_TIMEOUT_SECONDS, **kwargs)

            if r.status_code in (429, 500, 502, 503, 504):
                ra = r.headers.get("Retry-After")
                if ra and ra.isdigit():
                    sleep_s = min(float(ra), MAX_BACKOFF_SECONDS)
                else:
                    backoff = min(MAX_BACKOFF_SECONDS, BASE_BACKOFF_SECONDS * (2 ** attempt))
                    jitter = random.uniform(0, 0.25 * backoff)
                    sleep_s = backoff + jitter
                time.sleep(sleep_s)
                continue

            r.raise_for_status()
            return r

        except requests.RequestException as e:
            last_exc = e
            backoff = min(MAX_BACKOFF_SECONDS, BASE_BACKOFF_SECONDS * (2 ** attempt))
            jitter = random.uniform(0, 0.25 * backoff)
            time.sleep(backoff + jitter)

    raise RuntimeError(f"HTTP failed after retries: {last_exc}")

# -------------------- BQ --------------------
def ensure_table():
    schema = [
        bigquery.SchemaField("issue_id", "STRING"),
        bigquery.SchemaField("issue_key", "STRING"),
        bigquery.SchemaField("issue_updated", "TIMESTAMP"),
        bigquery.SchemaField("history_id", "STRING"),
        bigquery.SchemaField("history_created", "TIMESTAMP"),
        bigquery.SchemaField("author_account_id", "STRING"),
        bigquery.SchemaField("items_json", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
        bigquery.SchemaField("payload", "STRING"),
    ]

    table = bigquery.Table(TABLE_ID, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY, field="history_created"
    )
    table.clustering_fields = ["issue_key", "history_id"]
    bq.create_table(table, exists_ok=True)

def get_last_issue_updated() -> datetime:
    q = f"""
    SELECT COALESCE(MAX(issue_updated), TIMESTAMP('2000-01-01')) AS ts
    FROM `{TABLE_ID}`
    """
    ts = list(bq.query(q))[0]["ts"]
    if ts is None:
        return datetime(2000, 1, 1, tzinfo=timezone.utc)
    if ts.tzinfo is None:
        return ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc)

# -------------------- JIRA FETCH --------------------
def search_updated_issues(
    session: requests.Session,
    since_ts: datetime,
    hard_limit: int,
    started_monotonic: float,
) -> List[Dict[str, Any]]:
    site = jira_site()
    url = f"{site}/rest/api/3/search/jql"

    since_str = since_ts.strftime("%Y/%m/%d %H:%M")
    jql = f'project = "{TARGET_PROJECT_KEY}" AND updated >= "{since_str}" ORDER BY updated ASC'

    issues: List[Dict[str, Any]] = []
    next_page_token: Optional[str] = None

    while True:
        if len(issues) >= hard_limit:
            break
        if (time.monotonic() - started_monotonic) > (MAX_RUNTIME_SECONDS - 10):
            break

        params: Dict[str, Any] = {
            "jql": jql,
            "maxResults": SEARCH_PAGE_SIZE,
            "fields": ["updated", "project"],
        }
        if next_page_token:
            params["nextPageToken"] = next_page_token

        r = request_with_retries(
            session,
            "GET",
            url,
            params=params,
            auth=jira_auth(),
            headers={"Accept": "application/json"},
        )

        data = r.json()
        batch = data.get("issues", []) or []
        if not batch:
            break

        for it in batch:
            fields = it.get("fields") or {}
            project = fields.get("project") or {}
            if project.get("key") != TARGET_PROJECT_KEY:
                continue
            issues.append(it)
            if len(issues) >= hard_limit:
                break

        if data.get("isLast") is True:
            break

        next_page_token = data.get("nextPageToken")
        if not next_page_token:
            break

    return issues

def fetch_changelog(
    session: requests.Session,
    issue_key: str,
    started_monotonic: float,
) -> List[Dict[str, Any]]:
    site = jira_site()
    histories_all: List[Dict[str, Any]] = []
    start_at = 0

    while True:
        if (time.monotonic() - started_monotonic) > (MAX_RUNTIME_SECONDS - 10):
            break

        url = f"{site}/rest/api/3/issue/{issue_key}/changelog"
        params = {"startAt": start_at, "maxResults": CHANGELOG_PAGE_SIZE}

        r = request_with_retries(
            session,
            "GET",
            url,
            params=params,
            auth=jira_auth(),
            headers={"Accept": "application/json"},
        )

        data = r.json()
        histories = data.get("values", []) or []
        if not histories:
            break

        histories_all.extend(histories)
        start_at += len(histories)
        if start_at >= (data.get("total") or 0):
            break

    return histories_all

# -------------------- ENTRYPOINT --------------------
def hello_http(request):
    started = time.monotonic()
    try:
        ensure_table()

        # Overlap so we don't miss borders
        since = get_last_issue_updated() - timedelta(minutes=OVERLAP_MINUTES)

        with requests.Session() as session:
            issues = search_updated_issues(
                session=session,
                since_ts=since,
                hard_limit=MAX_ISSUES_PER_RUN,
                started_monotonic=started,
            )

            ingested_at = utc_now_iso()
            rows: List[Dict[str, Any]] = []
            row_ids: List[Optional[str]] = []

            for issue in issues:
                if (time.monotonic() - started) > (MAX_RUNTIME_SECONDS - 10):
                    break

                issue_id = issue.get("id")
                issue_key = issue.get("key")
                issue_updated_raw = (issue.get("fields") or {}).get("updated")

                histories = fetch_changelog(session, issue_key, started_monotonic=started)

                issue_updated = jira_ts_to_bq(issue_updated_raw)

                for h in histories:
                    hid = h.get("id")
                    h_created = jira_ts_to_bq(h.get("created"))

                    rows.append({
                        "issue_id": issue_id,
                        "issue_key": issue_key,
                        "issue_updated": issue_updated,
                        "history_id": hid,
                        "history_created": h_created,
                        "author_account_id": (h.get("author") or {}).get("accountId"),
                        "items_json": json.dumps(h.get("items") or []),
                        "_ingested_at": ingested_at,
                        "payload": json.dumps(h),
                    })

                    # insertId for best-effort streaming dedupe (useful with overlap/retries)
                    row_ids.append(f"{issue_id}:{hid}" if issue_id and hid else None)

            if rows:
                errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
                if errors:
                    raise RuntimeError(errors)

        return (jsonify({
            "status": "OK",
            "issues_scanned": len(issues),
            "rows_inserted": len(rows),
            "since": since.isoformat(),
            "runtime_seconds": round(time.monotonic() - started, 2),
        }), 200)

    except Exception as e:
        return (jsonify({
            "status": "ERROR",
            "message": str(e),
            "runtime_seconds": round(time.monotonic() - started, 2),
        }), 500)
