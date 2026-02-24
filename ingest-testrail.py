import json
import os
import time
import random
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Tuple

import google.auth
import requests
from flask import jsonify
from google.cloud import bigquery, secretmanager

# ----------------- GCP / BigQuery -----------------
_, PROJECT_ID = google.auth.default()

DATASET_ID = os.environ.get("BQ_DATASET", "qa_metrics")
TABLE_NAME = os.environ.get("BQ_TABLE", "testrail_runs")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

# Config
OVERLAP_DAYS = int(os.environ.get("OVERLAP_DAYS", "14"))
HTTP_TIMEOUT = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "30"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
BASE_BACKOFF = float(os.environ.get("BASE_BACKOFF_SECONDS", "1.0"))
MAX_BACKOFF = float(os.environ.get("MAX_BACKOFF_SECONDS", "30.0"))

# ----------------- Secrets -----------------
def get_secret(name: str) -> str:
    secret_name = f"projects/{PROJECT_ID}/secrets/{name}/versions/latest"
    resp = sm.access_secret_version(request={"name": secret_name})
    return resp.payload.data.decode("utf-8").strip()

def testrail_auth() -> Tuple[str, str]:
    return (get_secret("TESTRAIL_USER"), get_secret("TESTRAIL_API_KEY"))

def testrail_base_url() -> str:
    base = get_secret("TESTRAIL_BASE_URL").rstrip("/")
    if not base.endswith("index.php?/api/v2"):
        base = base + "/index.php?/api/v2"
    return base

def testrail_project_ids() -> List[int]:
    # Prefer plural secret if present, fallback to single
    try:
        s = get_secret("TESTRAIL_PROJECT_IDS")
        ids = [int(x.strip()) for x in s.split(",") if x.strip()]
        if ids:
            return ids
    except Exception:
        pass

    try:
        return [int(get_secret("TESTRAIL_PROJECT_ID"))]
    except Exception:
        return [int(os.environ.get("TESTRAIL_PROJECT_ID", "0"))] if os.environ.get("TESTRAIL_PROJECT_ID") else []

def as_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None

def as_timestamp_iso(value: Any) -> Optional[str]:
    ts = as_int(value)
    if ts is None or ts <= 0:
        return None
    return datetime.fromtimestamp(ts, timezone.utc).isoformat().replace("+00:00", "Z")

# ----------------- BigQuery -----------------
def ensure_table() -> None:
    schema = [
        bigquery.SchemaField("project_id", "INT64"),
        bigquery.SchemaField("run_id", "INT64"),
        bigquery.SchemaField("suite_id", "INT64"),
        bigquery.SchemaField("plan_id", "INT64"),
        bigquery.SchemaField("name", "STRING"),
        bigquery.SchemaField("is_completed", "BOOL"),
        bigquery.SchemaField("created_on", "TIMESTAMP"),
        bigquery.SchemaField("completed_on", "TIMESTAMP"),
        bigquery.SchemaField("assignedto_id", "INT64"),
        bigquery.SchemaField("created_by", "INT64"),
        bigquery.SchemaField("passed_count", "INT64"),
        bigquery.SchemaField("failed_count", "INT64"),
        bigquery.SchemaField("blocked_count", "INT64"),
        bigquery.SchemaField("retest_count", "INT64"),
        bigquery.SchemaField("untested_count", "INT64"),
        bigquery.SchemaField("url", "STRING"),
        bigquery.SchemaField("milestone_id", "INT64"),
        bigquery.SchemaField("config", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
        bigquery.SchemaField("payload", "STRING"),
    ]

    table = bigquery.Table(TABLE_ID, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY, field="created_on"
    )
    table.clustering_fields = ["project_id", "run_id", "is_completed"]
    bq.create_table(table, exists_ok=True)

def get_last_created_on() -> datetime:
    sql = f"""
      SELECT COALESCE(MAX(created_on), TIMESTAMP('1970-01-01')) AS last_created
      FROM `{TABLE_ID}`
    """
    rows = list(bq.query(sql))
    ts = rows[0]["last_created"]
    if ts is None or getattr(ts, "year", 1970) == 1970:
        return datetime.now(timezone.utc) - timedelta(days=30)

    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    else:
        ts = ts.astimezone(timezone.utc)

    return ts - timedelta(days=OVERLAP_DAYS)

# ----------------- HTTP -----------------
def request_with_retries(method: str, url: str, *, auth: Tuple[str,str]) -> requests.Response:
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

# ----------------- Fetch -----------------
def fetch_runs(project_id: int, since_ts: datetime, *, auth: Tuple[str, str], base: str) -> List[Dict[str, Any]]:
    created_after = int(since_ts.timestamp())
    limit = 250
    offset = 0

    runs: List[Dict[str, Any]] = []
    while True:
        url = (
            f"{base}/get_runs/{project_id}&created_after={created_after}&include_all=1"
            f"&limit={limit}&offset={offset}"
        )

        resp = request_with_retries("GET", url, auth=auth)
        data = resp.json()

        # API can return list directly or dict with 'runs'
        if isinstance(data, dict):
            if data.get("error"):
                raise RuntimeError(f"TestRail get_runs error for project {project_id}: {data.get('error')}")
            page_runs = data.get("runs") if "runs" in data else []
            if page_runs is None:
                page_runs = []
            runs.extend([r for r in page_runs if isinstance(r, dict)])

            size = data.get("size")
            page_limit = data.get("limit", limit)
            page_offset = data.get("offset", offset)

            if size is not None and page_limit is not None and page_offset is not None:
                if int(page_offset) + int(page_limit) >= int(size):
                    break
                offset = int(page_offset) + int(page_limit)
                continue
            if len(page_runs) < limit:
                break
            offset += limit
            continue

        if isinstance(data, list):
            page_runs = [r for r in data if isinstance(r, dict)]
            runs.extend(page_runs)
            if len(page_runs) < limit:
                break
            offset += limit
            continue

        raise RuntimeError(
            f"Unexpected TestRail get_runs response type for project {project_id}: {type(data).__name__}: {str(data)[:200]}"
        )

    rows: List[Dict[str, Any]] = []
    ingested_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    for r in runs:
        run_id = as_int(r.get("id"))
        if run_id is None:
            continue

        rows.append({
            "project_id": int(project_id),
            "run_id": run_id,
            "suite_id": as_int(r.get("suite_id")),
            "plan_id": as_int(r.get("plan_id")),
            "name": r.get("name"),
            "is_completed": bool(r.get("is_completed")),
            "created_on": as_timestamp_iso(r.get("created_on")),
            "completed_on": as_timestamp_iso(r.get("completed_on")),
            "assignedto_id": as_int(r.get("assignedto_id")),
            "created_by": as_int(r.get("created_by")),
            "passed_count": as_int(r.get("passed_count")) or 0,
            "failed_count": as_int(r.get("failed_count")) or 0,
            "blocked_count": as_int(r.get("blocked_count")) or 0,
            "retest_count": as_int(r.get("retest_count")) or 0,
            "untested_count": as_int(r.get("untested_count")) or 0,
            "url": r.get("url"),
            "milestone_id": as_int(r.get("milestone_id")),
            "config": json.dumps(r.get("config") or {}),
            "_ingested_at": ingested_at,
            "payload": json.dumps(r),
        })

    return rows


def insert_rows(rows: List[Dict[str, Any]]) -> None:
    if not rows:
        return

    # InsertId designed to allow run updates to be captured (completion / counts changes)
    row_ids = []
    for r in rows:
        rid = r.get("run_id")
        completed_on = r.get("completed_on")
        passed = r.get("passed_count")
        failed = r.get("failed_count")
        blocked = r.get("blocked_count")
        retest = r.get("retest_count")
        untested = r.get("untested_count")
        if rid:
            row_ids.append(f"{rid}:{completed_on}:{passed}:{failed}:{blocked}:{retest}:{untested}")
        else:
            row_ids.append(None)

    errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
    if errors:
        raise RuntimeError(errors)

# ----------------- Entry -----------------
def hello_http(request):
    if request.path.endswith("/healthz") or request.method == "GET":
        return (jsonify({"status": "OK", "service": "ingest-testrail", "ready": True}), 200)

    try:
        ensure_table()
        auth = testrail_auth()
        base = testrail_base_url()

        since_ts = get_last_created_on()
        pids = testrail_project_ids()
        if not pids:
            return (jsonify({"status":"ERROR","message":"No TESTRAIL_PROJECT_IDS/TESTRAIL_PROJECT_ID configured"}), 500)

        all_rows: List[Dict[str, Any]] = []
        for pid in pids:
            all_rows.extend(fetch_runs(pid, since_ts, auth=auth, base=base))

        insert_rows(all_rows)
        return (jsonify({"status":"OK","rows":len(all_rows), "since": since_ts.isoformat()}), 200)
    except Exception as e:
        return (jsonify({"status":"ERROR","message":str(e)}), 500)
