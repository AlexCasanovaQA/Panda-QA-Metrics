import json
import os
import time
import random
from datetime import datetime, timezone, timedelta
from functools import lru_cache
from typing import Any, Dict, List, Optional, Tuple

import google.auth
import requests
from flask import jsonify
from google.cloud import bigquery, secretmanager

# ----------------- GCP / BigQuery -----------------
_, PROJECT_ID = google.auth.default()

DATASET_ID = os.environ.get("BQ_DATASET", "qa_metrics")
TABLE_NAME = os.environ.get("BQ_TABLE", "testrail_results")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"
STATE_TABLE_NAME = os.environ.get("BQ_STATE_TABLE", "testrail_results_state")
STATE_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{STATE_TABLE_NAME}"

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

# Runtime knobs
MAX_RUNTIME_SECONDS = int(os.environ.get("MAX_RUNTIME_SECONDS", "480"))
MAX_RUNS_PER_INVOCATION = int(os.environ.get("MAX_RUNS_PER_INVOCATION", "25"))
OVERLAP_DAYS = int(os.environ.get("OVERLAP_DAYS", "1"))
MAX_RESULT_PAGES_PER_RUN = int(os.environ.get("MAX_RESULT_PAGES_PER_RUN", "5"))

HTTP_TIMEOUT = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "30"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
BASE_BACKOFF = float(os.environ.get("BASE_BACKOFF_SECONDS", "1.0"))
MAX_BACKOFF = float(os.environ.get("MAX_BACKOFF_SECONDS", "30.0"))

# ----------------- Secrets -----------------
@lru_cache(maxsize=None)
def get_secret(name: str) -> str:
    secret_name = f"projects/{PROJECT_ID}/secrets/{name}/versions/latest"
    resp = sm.access_secret_version(request={"name": secret_name})
    return resp.payload.data.decode("utf-8").strip()

@lru_cache(maxsize=1)
def testrail_auth() -> Tuple[str, str]:
    return (get_secret("TESTRAIL_USER"), get_secret("TESTRAIL_API_KEY"))

@lru_cache(maxsize=1)
def testrail_base_url() -> str:
    base = get_secret("TESTRAIL_BASE_URL").rstrip("/")
    if not base.endswith("index.php?/api/v2"):
        base = base + "/index.php?/api/v2"
    return base

def testrail_project_ids() -> List[int]:
    for key in ("TESTRAIL_PROJECT_IDS", "TESTRAIL_PROJECT_ID"):
        try:
            s = get_secret(key)
            if key == "TESTRAIL_PROJECT_ID":
                return [int(s)]
            ids = [int(x.strip()) for x in s.split(",") if x.strip()]
            if ids:
                return ids
        except Exception:
            continue
    return [int(os.environ.get("TESTRAIL_PROJECT_ID", "0"))] if os.environ.get("TESTRAIL_PROJECT_ID") else []

# ----------------- BigQuery -----------------
def ensure_table() -> None:
    schema = [
        bigquery.SchemaField("project_id", "INT64"),
        bigquery.SchemaField("run_id", "INT64"),
        bigquery.SchemaField("run_name", "STRING"),
        bigquery.SchemaField("suite_id", "INT64"),
        bigquery.SchemaField("plan_id", "INT64"),
        bigquery.SchemaField("milestone_id", "INT64"),
        bigquery.SchemaField("url", "STRING"),

        bigquery.SchemaField("test_id", "INT64"),
        bigquery.SchemaField("case_id", "INT64"),
        bigquery.SchemaField("result_id", "INT64"),

        bigquery.SchemaField("status_id", "INT64"),
        bigquery.SchemaField("created_on", "TIMESTAMP"),
        bigquery.SchemaField("created_by", "INT64"),
        bigquery.SchemaField("assignedto_id", "INT64"),

        bigquery.SchemaField("comment", "STRING"),
        bigquery.SchemaField("defects", "STRING"),
        bigquery.SchemaField("elapsed", "STRING"),
        bigquery.SchemaField("version", "STRING"),

        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
        bigquery.SchemaField("payload", "STRING"),
    ]

    table = bigquery.Table(TABLE_ID, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY, field="created_on"
    )
    table.clustering_fields = ["project_id", "run_id", "created_by", "status_id"]
    bq.create_table(table, exists_ok=True)


def ensure_state_table() -> None:
    schema = [
        bigquery.SchemaField("project_id", "INT64", mode="REQUIRED"),
        bigquery.SchemaField("cursor_result_id", "INT64"),
        bigquery.SchemaField("cursor_created_on", "TIMESTAMP"),
        bigquery.SchemaField("last_success_at", "TIMESTAMP"),
        bigquery.SchemaField("last_invocation_status", "STRING"),
        bigquery.SchemaField("continuation_token", "STRING"),
        bigquery.SchemaField("updated_at", "TIMESTAMP"),
    ]
    table = bigquery.Table(STATE_TABLE_ID, schema=schema)
    bq.create_table(table, exists_ok=True)

def _normalize_ts(ts: Optional[datetime]) -> Optional[datetime]:
    if ts is None:
        return None
    if ts.tzinfo is None:
        return ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc)


def load_project_state(project_ids: List[int]) -> Dict[int, Dict[str, Any]]:
    if not project_ids:
        return {}
    sql = f"""
      SELECT project_id, cursor_result_id, cursor_created_on
      FROM `{STATE_TABLE_ID}`
      WHERE project_id IN UNNEST(@project_ids)
    """
    job_config = bigquery.QueryJobConfig(
        query_parameters=[bigquery.ArrayQueryParameter("project_ids", "INT64", project_ids)]
    )
    out: Dict[int, Dict[str, Any]] = {}
    for row in bq.query(sql, job_config=job_config):
        out[int(row["project_id"])] = {
            "cursor_result_id": _safe_int(row["cursor_result_id"]),
            "cursor_created_on": _normalize_ts(row["cursor_created_on"]),
        }
    return out


def upsert_project_state(
    *,
    project_id: int,
    cursor_result_id: Optional[int],
    cursor_created_on: Optional[datetime],
    status: str,
    continuation_token: Optional[str],
) -> None:
    sql = f"""
    MERGE `{STATE_TABLE_ID}` T
    USING (
      SELECT
        @project_id AS project_id,
        @cursor_result_id AS cursor_result_id,
        @cursor_created_on AS cursor_created_on,
        @status AS status,
        @continuation_token AS continuation_token
    ) S
    ON T.project_id = S.project_id
    WHEN MATCHED THEN UPDATE SET
      cursor_result_id = S.cursor_result_id,
      cursor_created_on = S.cursor_created_on,
      last_success_at = IF(S.status = 'SUCCESS', CURRENT_TIMESTAMP(), T.last_success_at),
      last_invocation_status = S.status,
      continuation_token = S.continuation_token,
      updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
      project_id, cursor_result_id, cursor_created_on, last_success_at, last_invocation_status, continuation_token, updated_at
    ) VALUES (
      S.project_id,
      S.cursor_result_id,
      S.cursor_created_on,
      IF(S.status = 'SUCCESS', CURRENT_TIMESTAMP(), NULL),
      S.status,
      S.continuation_token,
      CURRENT_TIMESTAMP()
    )
    """
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("project_id", "INT64", project_id),
            bigquery.ScalarQueryParameter("cursor_result_id", "INT64", cursor_result_id),
            bigquery.ScalarQueryParameter("cursor_created_on", "TIMESTAMP", _normalize_ts(cursor_created_on)),
            bigquery.ScalarQueryParameter("status", "STRING", status),
            bigquery.ScalarQueryParameter("continuation_token", "STRING", continuation_token),
        ]
    )
    bq.query(sql, job_config=job_config).result()

# ----------------- HTTP -----------------
def request_with_retries(method: str, url: str, *, auth: Tuple[str, str]) -> requests.Response:
    last_exc: Optional[Exception] = None
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.request(method, url, auth=auth, timeout=HTTP_TIMEOUT)
            if r.status_code in (429, 500, 502, 503, 504):
                backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
                jitter = random.uniform(0, 0.25 * backoff)
                time.sleep(backoff + jitter)
                continue
            r.raise_for_status()
            return r
        except requests.RequestException as e:
            last_exc = e
            backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
            jitter = random.uniform(0, 0.25 * backoff)
            time.sleep(backoff + jitter)
    raise RuntimeError(f"HTTP failed after retries: {last_exc}")


def _iter_paginated(path: str, *, auth: Tuple[str, str], start_offset: int = 0, max_pages: Optional[int] = None) -> Tuple[List[Dict[str, Any]], Optional[int]]:
    """Collect paginated TestRail v2 API responses.

    Supports both legacy list responses and the object style with
    {_links, offset, limit, size, <entity_plural>}.
    """
    base = testrail_base_url()
    page_size = int(os.environ.get("TESTRAIL_PAGE_SIZE", "250"))
    offset = max(0, int(start_offset or 0))
    aggregated: List[Dict[str, Any]] = []
    pages = 0

    while True:
        url = f"{base}/{path}&limit={page_size}&offset={offset}"
        resp = request_with_retries("GET", url, auth=auth)
        data = resp.json()

        if isinstance(data, dict) and data.get("error"):
            raise RuntimeError(f"TestRail API error on {path}: {data.get('error')}")

        if isinstance(data, list):
            aggregated.extend(item for item in data if isinstance(item, dict))
            return aggregated, None

        if not isinstance(data, dict):
            raise RuntimeError(
                f"Unexpected TestRail response type for {path}: {type(data).__name__}: {str(data)[:200]}"
            )

        entity_list = None
        for key in ("runs", "results"):
            if key in data:
                entity_list = data.get(key) or []
                break
        if entity_list is None:
            # Fallback for unknown object formats.
            entity_list = []

        aggregated.extend(item for item in entity_list if isinstance(item, dict))

        size = data.get("size")
        limit = data.get("limit")
        current_offset = data.get("offset", offset)
        links = data.get("_links") if isinstance(data.get("_links"), dict) else {}
        next_link = links.get("next") if isinstance(links, dict) else None

        if next_link:
            pages += 1
            if max_pages is not None and pages >= max_pages:
                return aggregated, current_offset + (limit or page_size)
            offset = current_offset + (limit or page_size)
            continue

        if isinstance(size, int) and isinstance(current_offset, int):
            if current_offset + (limit or page_size) >= size:
                break
            pages += 1
            if max_pages is not None and pages >= max_pages:
                return aggregated, current_offset + (limit or page_size)
            offset = current_offset + (limit or page_size)
            continue

        if len(entity_list) < page_size:
            break
        pages += 1
        if max_pages is not None and pages >= max_pages:
            return aggregated, offset + page_size
        offset += page_size

    return aggregated, None

# ----------------- Fetch -----------------
def fetch_runs(project_id: int, since_ts: datetime) -> List[Dict[str, Any]]:
    updated_after = int(since_ts.timestamp())
    path = f"get_runs/{project_id}&updated_after={updated_after}&include_all=1"
    runs, _ = _iter_paginated(path, auth=testrail_auth())
    return [r for r in runs if isinstance(r, dict)]


def fetch_results_for_run(run_id: int, *, start_offset: int = 0, max_pages: Optional[int] = None) -> Tuple[List[Dict[str, Any]], Optional[int]]:
    path = f"get_results_for_run/{run_id}"
    return _iter_paginated(path, auth=testrail_auth(), start_offset=start_offset, max_pages=max_pages)


def _safe_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None

# ----------------- Entry -----------------
def hello_http(request):
    if request.path.endswith("/healthz") or request.method == "GET":
        return (jsonify({"status": "OK", "service": "ingest-testrail-results", "ready": True}), 200)

    started = time.monotonic()
    try:
        ensure_table()
        ensure_state_table()

        body = request.get_json(silent=True) or {}
        recovery_mode = str(body.get("recovery_mode", "false")).lower() == "true"
        continuation_token_raw = body.get("continuation_token")
        if isinstance(continuation_token_raw, dict):
            continuation_token = continuation_token_raw
        elif continuation_token_raw:
            continuation_token = json.loads(continuation_token_raw)
        else:
            continuation_token = None

        pids = testrail_project_ids()
        if not pids:
            return (jsonify({"status":"ERROR","message":"No TESTRAIL_PROJECT_IDS/TESTRAIL_PROJECT_ID configured"}), 500)
        state = load_project_state(pids)

        rows: List[Dict[str, Any]] = []
        row_ids: List[Optional[str]] = []
        ingested_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        project_watermarks: Dict[int, Dict[str, Any]] = {}

        runs_scanned = 0
        next_token: Optional[Dict[str, Any]] = None
        default_start = datetime.now(timezone.utc) - timedelta(days=30)

        for pid in pids:
            pid_state = state.get(pid, {})
            state_ts = pid_state.get("cursor_created_on") or default_start
            cursor_result_id = _safe_int(pid_state.get("cursor_result_id"))
            since_ts = state_ts - timedelta(days=OVERLAP_DAYS) if recovery_mode else state_ts
            runs = fetch_runs(pid, since_ts)

            # Prefer newest runs first so we get freshest data within runtime
            runs_sorted = sorted(runs, key=lambda r: r.get("created_on", 0), reverse=True)

            if continuation_token and _safe_int(continuation_token.get("project_id")) == pid:
                run_id_filter = _safe_int(continuation_token.get("run_id"))
                if run_id_filter:
                    runs_sorted = [r for r in runs_sorted if _safe_int(r.get("id")) == run_id_filter]

            for run in runs_sorted:
                if runs_scanned >= MAX_RUNS_PER_INVOCATION:
                    break
                if (time.monotonic() - started) > (MAX_RUNTIME_SECONDS - 10):
                    break

                run_id = _safe_int(run.get("id"))
                if run_id is None:
                    continue
                run_name = run.get("name")
                suite_id = _safe_int(run.get("suite_id"))
                plan_id = _safe_int(run.get("plan_id"))
                milestone_id = _safe_int(run.get("milestone_id"))
                url = run.get("url")

                start_offset = 0
                if continuation_token and _safe_int(continuation_token.get("project_id")) == pid and _safe_int(continuation_token.get("run_id")) == run_id:
                    start_offset = int(continuation_token.get("results_offset") or 0)

                results, next_offset = fetch_results_for_run(
                    run_id,
                    start_offset=start_offset,
                    max_pages=MAX_RESULT_PAGES_PER_RUN,
                )

                for res in results:
                    created_on = res.get("created_on")
                    result_id = res.get("id")
                    stable_result_id = _safe_int(result_id)
                    created_on_ts = datetime.fromtimestamp(int(created_on), timezone.utc) if created_on else None

                    if cursor_result_id and stable_result_id and stable_result_id <= cursor_result_id:
                        continue
                    if (not cursor_result_id) and created_on_ts and created_on_ts <= state_ts:
                        continue
                    test_id = res.get("test_id")
                    case_id = res.get("case_id")

                    rows.append({
                        "project_id": int(pid),
                        "run_id": run_id,
                        "run_name": run_name,
                        "suite_id": suite_id,
                        "plan_id": plan_id,
                        "milestone_id": milestone_id,
                        "url": url,

                        "test_id": _safe_int(test_id),
                        "case_id": _safe_int(case_id),
                        "result_id": stable_result_id,

                        "status_id": _safe_int(res.get("status_id")),
                        "created_on": created_on_ts.isoformat().replace("+00:00", "Z") if created_on_ts else None,
                        "created_by": _safe_int(res.get("created_by")),
                        "assignedto_id": _safe_int(res.get("assignedto_id")),

                        "comment": res.get("comment"),
                        "defects": ",".join(res.get("defects") or []) if isinstance(res.get("defects"), list) else res.get("defects"),
                        "elapsed": res.get("elapsed"),
                        "version": res.get("version"),

                        "_ingested_at": ingested_at,
                        "payload": json.dumps(res),
                    })

                    # insertId: unique result
                    row_ids.append(f"{pid}:{run_id}:{stable_result_id}" if stable_result_id else None)

                    wm = project_watermarks.setdefault(pid, {"result_id": None, "created_on": None})
                    if stable_result_id and (wm["result_id"] is None or stable_result_id > wm["result_id"]):
                        wm["result_id"] = stable_result_id
                    if created_on_ts and (wm["created_on"] is None or created_on_ts > wm["created_on"]):
                        wm["created_on"] = created_on_ts

                runs_scanned += 1
                if next_offset is not None:
                    next_token = {
                        "project_id": pid,
                        "run_id": run_id,
                        "results_offset": next_offset,
                        "recovery_mode": recovery_mode,
                    }
                    break

            if next_token or runs_scanned >= MAX_RUNS_PER_INVOCATION or (time.monotonic() - started) > (MAX_RUNTIME_SECONDS - 10):
                break

        if rows:
            errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
            if errors:
                raise RuntimeError(errors)

        if next_token:
            for pid in pids:
                upsert_project_state(
                    project_id=pid,
                    cursor_result_id=state.get(pid, {}).get("cursor_result_id"),
                    cursor_created_on=state.get(pid, {}).get("cursor_created_on"),
                    status="PARTIAL",
                    continuation_token=json.dumps(next_token) if pid == next_token.get("project_id") else None,
                )
        else:
            for pid in pids:
                wm = project_watermarks.get(pid, {})
                upsert_project_state(
                    project_id=pid,
                    cursor_result_id=wm.get("result_id") or state.get(pid, {}).get("cursor_result_id"),
                    cursor_created_on=wm.get("created_on") or state.get(pid, {}).get("cursor_created_on"),
                    status="SUCCESS",
                    continuation_token=None,
                )

        return (jsonify({
            "status":"OK",
            "recovery_mode": recovery_mode,
            "runs_scanned": runs_scanned,
            "rows_inserted": len(rows),
            "continuation_token": json.dumps(next_token) if next_token else None,
            "runtime_seconds": round(time.monotonic() - started, 2),
        }), 200)

    except Exception as e:
        return (jsonify({"status":"ERROR","message":str(e), "runtime_seconds": round(time.monotonic() - started, 2)}), 500)
