"""Ingest Jira issue changelog (status transitions, etc.) into BigQuery.

Key improvements:
- Processes most recently updated issues first (ORDER BY updated DESC) so partial runs still capture newest data.
- Supports incremental ingestion by looking at the latest `history_created` in BigQuery and using an overlap window.
- Uses Jira changelog bulk fetch endpoint to ingest status transitions for many issues per call.

Env vars:
- JIRA_BASE_URL / JIRA_EMAIL / JIRA_API_TOKEN
- JIRA_PROJECT_KEYS (comma-separated)
- LOOKBACK_DAYS (default 14)   # used if BigQuery table is empty
- OVERLAP_DAYS (default 7)     # safety overlap for incremental pulls

BQ:
- BQ_DATASET_ID (default qa_metrics)
- BQ_TABLE_ID (default jira_changelog_v2)

HTTP body overrides:
- lookback_days
- overlap_days
- project_keys
"""

import json
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

import functions_framework
import requests
from google.api_core.exceptions import NotFound
from google.cloud import bigquery


DEFAULT_LOOKBACK_DAYS = int(os.environ.get("LOOKBACK_DAYS", "14"))
DEFAULT_OVERLAP_DAYS = int(os.environ.get("OVERLAP_DAYS", "7"))

BQ_DATASET_ID = os.environ.get("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.environ.get("BQ_TABLE_ID", "jira_changelog_v2")

JIRA_BASE_URL = os.environ.get("JIRA_BASE_URL")
JIRA_EMAIL = os.environ.get("JIRA_EMAIL")
JIRA_API_TOKEN = os.environ.get("JIRA_API_TOKEN")
JIRA_PROJECT_KEYS = os.environ.get("JIRA_PROJECT_KEYS", "").strip()

JIRA_CALLS = 0
JIRA_CHANGELOG_BULK_ISSUE_BATCH = 1000
JIRA_CHANGELOG_BULK_PAGE_SIZE = 1000


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


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(ts: Optional[datetime]) -> Optional[str]:
    return ts.isoformat().replace("+00:00", "Z") if ts else None


def _get_project_id() -> str:
    pid = os.environ.get("GCP_PROJECT_ID")
    if pid:
        return pid
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
    attempt = 0

    global JIRA_CALLS

    while True:
        attempt += 1
        JIRA_CALLS += 1
        r = requests.get(url, headers=_jira_headers(), auth=_jira_auth(), params=params, timeout=60)
        if r.status_code != 429:
            r.raise_for_status()
            return r.json()

        if attempt >= max_attempts:
            r.raise_for_status()

        retry_after = r.headers.get("Retry-After")
        if retry_after and retry_after.isdigit():
            sleep_s = max(1, int(retry_after))
        else:
            sleep_s = min(16, 2 ** (attempt - 1))
        print(f"Jira rate-limited on {path}; sleeping {sleep_s}s before retry {attempt + 1}/{max_attempts}")
        time.sleep(sleep_s)


def _jira_post(path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    if not JIRA_BASE_URL:
        raise RuntimeError("Missing JIRA_BASE_URL env var")
    url = JIRA_BASE_URL.rstrip("/") + path
    max_attempts = 5
    attempt = 0

    global JIRA_CALLS

    while True:
        attempt += 1
        JIRA_CALLS += 1
        r = requests.post(url, headers=_jira_headers(), auth=_jira_auth(), json=payload, timeout=60)
        if r.status_code != 429:
            r.raise_for_status()
            return r.json()

        if attempt >= max_attempts:
            r.raise_for_status()

        retry_after = r.headers.get("Retry-After")
        if retry_after and retry_after.isdigit():
            sleep_s = max(1, int(retry_after))
        else:
            sleep_s = min(16, 2 ** (attempt - 1))
        print(f"Jira rate-limited on {path}; sleeping {sleep_s}s before retry {attempt + 1}/{max_attempts}")
        time.sleep(sleep_s)


def _ensure_table(bq: bigquery.Client, table_ref: bigquery.TableReference) -> None:
    desired_schema = [
        bigquery.SchemaField("issue_key", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("project_key", "STRING"),
        bigquery.SchemaField("history_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("history_created", "TIMESTAMP"),
        bigquery.SchemaField("author", "STRING"),
        bigquery.SchemaField("items_json", "STRING"),
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
        table = bigquery.Table(table_ref, schema=desired_schema)
        table.time_partitioning = bigquery.TimePartitioning(field="_ingested_at")
        bq.create_table(table)
        print(f"Created table {table_ref}")


def _parse_jira_ts(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        if value.endswith("+0000"):
            value = value[:-5] + "+00:00"
        if value.endswith("Z"):
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        return datetime.fromisoformat(value)
    except Exception:
        return None


def _get_latest_history_ts(bq: bigquery.Client, table_ref: bigquery.TableReference) -> Optional[datetime]:
    """Return max(history_created) from the changelog table."""
    sql = f"""
      SELECT MAX(history_created) AS max_ts
      FROM `{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}`
    """
    try:
        rows = list(bq.query(sql).result())
        if not rows:
            return None
        latest = rows[0].get("max_ts")
        if latest and latest.tzinfo is None:
            latest = latest.replace(tzinfo=timezone.utc)
        return latest
    except Exception as e:
        print("Warning: could not query latest history_created:", e)
        return None


def _get_existing_history_ids_batch(
    bq: bigquery.Client,
    table_ref: bigquery.TableReference,
    page_histories: Dict[str, List[str]],
) -> Dict[str, Set[str]]:
    """Fetch existing history ids for issues in one page to keep ingestion idempotent across reruns."""
    issue_keys = [k for k, ids in page_histories.items() if ids]
    if not issue_keys:
        return {}

    all_history_ids = sorted({hid for ids in page_histories.values() for hid in ids})
    if not all_history_ids:
        return {}

    sql = f"""
      SELECT issue_key, history_id
      FROM `{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}`
      WHERE issue_key IN UNNEST(@issue_keys)
        AND history_id IN UNNEST(@history_ids)
    """
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ArrayQueryParameter("issue_keys", "STRING", issue_keys),
            bigquery.ArrayQueryParameter("history_ids", "STRING", all_history_ids),
        ]
    )
    rows = bq.query(sql, job_config=job_config).result()
    existing: Dict[str, Set[str]] = {}
    for row in rows:
        issue_key = row.get("issue_key")
        history_id = row.get("history_id")
        if issue_key is None or history_id is None:
            continue
        existing.setdefault(str(issue_key), set()).add(str(history_id))
    return existing


def _search_issue_keys(
    project_key: str,
    since: datetime,
    until: datetime,
    start_at: int,
    max_results: int = 100,
) -> Tuple[List[Tuple[str, Optional[datetime]]], Optional[int]]:
    """Return ((issue_key, updated_ts), total) for a page."""
    jql = (
        f'project = "{project_key}" '
        f'AND updated >= "{since.strftime("%Y/%m/%d %H:%M")}" '
        f'AND updated <= "{until.strftime("%Y/%m/%d %H:%M")}" '
        f'ORDER BY updated DESC'
    )

    data = _jira_get(
        "/rest/api/3/search",
        params={
            "jql": jql,
            "startAt": start_at,
            "maxResults": max_results,
            "fields": "key,updated",
        },
    )

    issues = data.get("issues") or []
    keys: List[Tuple[str, Optional[datetime]]] = []
    for issue in issues:
        key = issue.get("key")
        if not key:
            continue
        fields = issue.get("fields") if isinstance(issue.get("fields"), dict) else {}
        updated_ts = _parse_jira_ts(fields.get("updated"))
        keys.append((key, updated_ts))
    total = data.get("total")
    return keys, total


def _extract_bulkfetch_issue_histories(entry: Dict[str, Any]) -> Tuple[Optional[str], List[Dict[str, Any]]]:
    issue_key = entry.get("issueKey") or entry.get("issue_key")
    histories = (
        entry.get("changeHistories")
        or entry.get("histories")
        or entry.get("values")
        or []
    )
    if not isinstance(histories, list):
        histories = []
    return issue_key, [h for h in histories if isinstance(h, dict)]


def _fetch_changelog_bulk(issue_keys: List[str]) -> Dict[str, List[Dict[str, Any]]]:
    """Fetch changelog for many issues using Jira bulkfetch endpoint, filtered to status field."""
    issue_histories: Dict[str, List[Dict[str, Any]]] = {k: [] for k in issue_keys}
    next_page_token: Optional[str] = None

    while True:
        payload: Dict[str, Any] = {
            "issueIdsOrKeys": issue_keys,
            "fieldIds": ["status"],
            "maxResults": JIRA_CHANGELOG_BULK_PAGE_SIZE,
        }
        if next_page_token:
            payload["nextPageToken"] = next_page_token

        data = _jira_post("/rest/api/3/changelog/bulkfetch", payload=payload)
        issue_change_logs = data.get("issueChangeLogs") or []

        for entry in issue_change_logs:
            if not isinstance(entry, dict):
                continue
            issue_key, histories = _extract_bulkfetch_issue_histories(entry)
            if not issue_key:
                continue
            issue_histories.setdefault(issue_key, []).extend(histories)

        next_page_token = data.get("nextPageToken")
        if not next_page_token:
            break

    return issue_histories


def _history_to_rows(issue_key: str, project_key: str, history: Dict[str, Any], ingested_at: datetime) -> Dict[str, Any]:
    created_ts = _parse_jira_ts(history.get("created"))
    author = None
    if isinstance(history.get("author"), dict):
        author = history["author"].get("displayName") or history["author"].get("accountId")

    return {
        "issue_key": issue_key,
        "project_key": project_key,
        "history_id": str(history.get("id")),
        "history_created": _iso(created_ts),
        "author": author,
        "items_json": json.dumps(history.get("items") or [], ensure_ascii=False),
        "raw_json": json.dumps(history, ensure_ascii=False),
        "_ingested_at": _iso(ingested_at),
    }


@functions_framework.http
def ingest_jira_changelog(request):
    global JIRA_CALLS
    JIRA_CALLS = 0

    req_json = request.get_json(silent=True) or {}

    lookback_days = int(req_json.get("lookback_days") or DEFAULT_LOOKBACK_DAYS)
    overlap_days = int(req_json.get("overlap_days") or DEFAULT_OVERLAP_DAYS)

    project_keys_raw = (req_json.get("project_keys") or JIRA_PROJECT_KEYS)
    project_keys = [p.strip() for p in project_keys_raw.split(",") if p.strip()]
    if not project_keys:
        return _error_response(
            "config_error",
            "missing_project_keys",
            "No Jira projects provided. Set JIRA_PROJECT_KEYS or pass project_keys",
            400,
        )

    until = _utc_now()

    bq = bigquery.Client(project=_get_project_id())
    table_ref = bq.dataset(BQ_DATASET_ID).table(BQ_TABLE_ID)
    _ensure_table(bq, table_ref)

    latest_ts = _get_latest_history_ts(bq, table_ref)

    if latest_ts:
        since = latest_ts - timedelta(days=overlap_days)
        # don't go too far back accidentally
        hard_floor = until - timedelta(days=3650)
        since = max(since, hard_floor)
        mode = "incremental"
    else:
        since = until - timedelta(days=lookback_days)
        mode = "bootstrap"

    print(f"Changelog ingest mode={mode} since={since} until={until} overlap_days={overlap_days}")

    ingested_at = _utc_now()

    inserted = 0
    issue_count = 0
    skipped_unchanged = 0
    processed_issue_keys: Dict[str, Optional[datetime]] = {}
    overlap_since = latest_ts - timedelta(days=overlap_days) if latest_ts else since

    for project_key in project_keys:
        print(f"Processing project {project_key}")
        start_at = 0
        page_size = 100

        while True:
            keys, total = _search_issue_keys(project_key, since, until, start_at, page_size)
            if not keys:
                break

            print(f"Project {project_key}: issues page startAt={start_at} got={len(keys)} total={total}")

            page_histories: Dict[str, List[Dict[str, Any]]] = {}
            page_history_ids: Dict[str, List[str]] = {}
            keys_to_fetch: List[str] = []

            for issue_key, updated_ts in keys:
                issue_count += 1
                if issue_key in processed_issue_keys:
                    already_updated = processed_issue_keys[issue_key]
                    if (
                        updated_ts is not None
                        and already_updated is not None
                        and updated_ts <= overlap_since
                        and already_updated >= updated_ts
                    ):
                        skipped_unchanged += 1
                        continue
                keys_to_fetch.append(issue_key)
                prev_updated = processed_issue_keys.get(issue_key)
                if prev_updated is None or (updated_ts and updated_ts > prev_updated):
                    processed_issue_keys[issue_key] = updated_ts

            for i in range(0, len(keys_to_fetch), JIRA_CHANGELOG_BULK_ISSUE_BATCH):
                chunk = keys_to_fetch[i : i + JIRA_CHANGELOG_BULK_ISSUE_BATCH]
                try:
                    chunk_histories = _fetch_changelog_bulk(chunk)
                except Exception as e:
                    print(f"Failed bulk changelog fetch for project {project_key} ({len(chunk)} issues): {e}")
                    continue

                for issue_key in chunk:
                    histories = chunk_histories.get(issue_key, [])
                    page_histories[issue_key] = histories
                    page_history_ids[issue_key] = [str(h.get("id")) for h in histories if h.get("id") is not None]

            existing_by_issue = _get_existing_history_ids_batch(bq, table_ref, page_history_ids)

            rows = []
            for issue_key, histories in page_histories.items():
                existing_ids = existing_by_issue.get(issue_key, set())
                for h in histories:
                    hid = h.get("id")
                    if hid is None:
                        continue
                    hid = str(hid)
                    if hid in existing_ids:
                        continue
                    created_ts = _parse_jira_ts(h.get("created"))
                    if created_ts and created_ts < since:
                        continue
                    rows.append(_history_to_rows(issue_key, project_key, h, ingested_at))

            if rows:
                errors = bq.insert_rows_json(table_ref, rows)
                if errors:
                    print("BigQuery insert errors (first 3):", errors[:3])
                    return _error_response("runtime_error", "bigquery_insert_failed", "BigQuery insert failed", 500, errors[:3])
                inserted += len(rows)

            start_at += len(keys)
            if total is not None and start_at >= total:
                break

    return (
        json.dumps(
            {
                "ok": True,
                "mode": mode,
                "projects": project_keys,
                "since": _iso(since),
                "until": _iso(until),
                "issues_processed": issue_count,
                "rows_inserted": inserted,
                "issues_scanned": issue_count,
                "issues_skipped_unchanged": skipped_unchanged,
                "histories_inserted": inserted,
                "jira_calls": JIRA_CALLS,
                "bq_table": f"{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}",
            }
        ),
        200,
        {"Content-Type": "application/json"},
    )


def hello_http(request):
    if request.path.endswith("/healthz") or request.method == "GET":
        return (json.dumps({"ok": True, "service": "ingest-jira-changelog", "ready": True}), 200, {"Content-Type": "application/json"})
    return ingest_jira_changelog(request)
