"""Ingest Jira issue changelog (status transitions, etc.) into BigQuery.

Key improvements:
- Processes most recently updated issues first (ORDER BY updated DESC) so partial runs still capture newest data.
- Supports incremental ingestion by looking at the latest `history_created` in BigQuery and using an overlap window.
- Streams page-by-page instead of collecting all issue keys first.

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
    r = requests.get(url, headers=_jira_headers(), auth=_jira_auth(), params=params, timeout=60)
    r.raise_for_status()
    return r.json()


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


def _get_existing_history_ids(
    bq: bigquery.Client,
    table_ref: bigquery.TableReference,
    issue_key: str,
    history_ids: List[str],
) -> Set[str]:
    """Fetch existing history ids for an issue to keep ingestion idempotent across reruns."""
    if not history_ids:
        return set()

    sql = f"""
      SELECT history_id
      FROM `{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}`
      WHERE issue_key = @issue_key
        AND history_id IN UNNEST(@history_ids)
    """
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("issue_key", "STRING", issue_key),
            bigquery.ArrayQueryParameter("history_ids", "STRING", history_ids),
        ]
    )
    rows = bq.query(sql, job_config=job_config).result()
    return {str(row["history_id"]) for row in rows if row.get("history_id") is not None}


def _search_issue_keys(project_key: str, since: datetime, until: datetime, start_at: int, max_results: int = 100) -> Tuple[List[str], Optional[int]]:
    """Return (issue_keys, total) for a page."""
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
            "fields": "key",
        },
    )

    issues = data.get("issues") or []
    keys = [i.get("key") for i in issues if i.get("key")]
    total = data.get("total")
    return keys, total


def _fetch_changelog(issue_key: str) -> List[Dict[str, Any]]:
    """Fetch full changelog for a single issue (handles pagination)."""
    start_at = 0
    max_results = 100
    histories: List[Dict[str, Any]] = []

    while True:
        data = _jira_get(
            f"/rest/api/3/issue/{issue_key}/changelog",
            params={"startAt": start_at, "maxResults": max_results},
        )
        hs = data.get("values") or []
        histories.extend(hs)
        start_at += len(hs)
        total = data.get("total")
        if total is None or start_at >= total or not hs:
            break

        # be nice to Jira
        time.sleep(0.05)

    return histories


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

    for project_key in project_keys:
        print(f"Processing project {project_key}")
        start_at = 0
        page_size = 100

        while True:
            keys, total = _search_issue_keys(project_key, since, until, start_at, page_size)
            if not keys:
                break

            print(f"Project {project_key}: issues page startAt={start_at} got={len(keys)} total={total}")

            for issue_key in keys:
                issue_count += 1
                try:
                    histories = _fetch_changelog(issue_key)
                except Exception as e:
                    print(f"Failed to fetch changelog for {issue_key}: {e}")
                    continue

                history_ids = [str(h.get("id")) for h in histories if h.get("id") is not None]
                existing_ids = _get_existing_history_ids(bq, table_ref, issue_key, history_ids)

                rows = []
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

                # small sleep to avoid hammering
                time.sleep(0.05)

            start_at += len(keys)
            if total is not None and start_at >= total:
                break

            # if Jira throttles, slow down
            time.sleep(0.2)

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
                "bq_table": f"{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}",
            }
        ),
        200,
        {"Content-Type": "application/json"},
    )
