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
TABLE_NAME = os.environ.get("BQ_TABLE", "testrail_results")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

# Runtime knobs
MAX_RUNTIME_SECONDS = int(os.environ.get("MAX_RUNTIME_SECONDS", "480"))
MAX_RUNS_PER_INVOCATION = int(os.environ.get("MAX_RUNS_PER_INVOCATION", "25"))
OVERLAP_DAYS = int(os.environ.get("OVERLAP_DAYS", "7"))

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

def get_last_created_on() -> datetime:
    sql = f"""
      SELECT COALESCE(MAX(created_on), TIMESTAMP('1970-01-01')) AS last_created
      FROM `{TABLE_ID}`
    """
    ts = list(bq.query(sql))[0]["last_created"]
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
def fetch_runs(project_id: int, since_ts: datetime) -> List[Dict[str, Any]]:
    base = testrail_base_url()
    created_after = int(since_ts.timestamp())
    url = f"{base}/get_runs/{project_id}&created_after={created_after}&include_all=1"
    resp = request_with_retries("GET", url, auth=testrail_auth())
    data = resp.json()
    if isinstance(data, dict) and "runs" in data:
        return data.get("runs") or []
    return data or []

def fetch_results_for_run(run_id: int) -> List[Dict[str, Any]]:
    base = testrail_base_url()
    # NOTE: get_results_for_run returns results for tests in a run
    url = f"{base}/get_results_for_run/{run_id}"
    resp = request_with_retries("GET", url, auth=testrail_auth())
    data = resp.json()
    return data or []

# ----------------- Entry -----------------
def hello_http(request):
    started = time.monotonic()
    try:
        ensure_table()

        since_ts = get_last_created_on()
        pids = testrail_project_ids()
        if not pids:
            return (jsonify({"status":"ERROR","message":"No TESTRAIL_PROJECT_IDS/TESTRAIL_PROJECT_ID configured"}), 500)

        rows: List[Dict[str, Any]] = []
        row_ids: List[Optional[str]] = []
        ingested_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

        runs_scanned = 0
        for pid in pids:
            runs = fetch_runs(pid, since_ts)

            # Prefer newest runs first so we get freshest data within runtime
            runs_sorted = sorted(runs, key=lambda r: r.get("created_on", 0), reverse=True)

            for run in runs_sorted:
                if runs_scanned >= MAX_RUNS_PER_INVOCATION:
                    break
                if (time.monotonic() - started) > (MAX_RUNTIME_SECONDS - 10):
                    break

                run_id = int(run.get("id"))
                run_name = run.get("name")
                suite_id = run.get("suite_id")
                plan_id = run.get("plan_id")
                milestone_id = run.get("milestone_id")
                url = run.get("url")

                results = fetch_results_for_run(run_id)

                for res in results:
                    created_on = res.get("created_on")
                    result_id = res.get("id")
                    test_id = res.get("test_id")
                    case_id = res.get("case_id")

                    rows.append({
                        "project_id": int(pid),
                        "run_id": int(run_id),
                        "run_name": run_name,
                        "suite_id": suite_id,
                        "plan_id": plan_id,
                        "milestone_id": milestone_id,
                        "url": url,

                        "test_id": test_id,
                        "case_id": case_id,
                        "result_id": result_id,

                        "status_id": res.get("status_id"),
                        "created_on": datetime.fromtimestamp(created_on, timezone.utc).isoformat().replace("+00:00", "Z") if created_on else None,
                        "created_by": res.get("created_by"),
                        "assignedto_id": res.get("assignedto_id"),

                        "comment": res.get("comment"),
                        "defects": ",".join(res.get("defects") or []) if isinstance(res.get("defects"), list) else res.get("defects"),
                        "elapsed": res.get("elapsed"),
                        "version": res.get("version"),

                        "_ingested_at": ingested_at,
                        "payload": json.dumps(res),
                    })

                    # insertId: unique result
                    row_ids.append(f"{pid}:{run_id}:{result_id}" if result_id else None)

                runs_scanned += 1

            if runs_scanned >= MAX_RUNS_PER_INVOCATION or (time.monotonic() - started) > (MAX_RUNTIME_SECONDS - 10):
                break

        if rows:
            errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
            if errors:
                raise RuntimeError(errors)

        return (jsonify({
            "status":"OK",
            "since": since_ts.isoformat(),
            "runs_scanned": runs_scanned,
            "rows_inserted": len(rows),
            "runtime_seconds": round(time.monotonic() - started, 2),
        }), 200)

    except Exception as e:
        return (jsonify({"status":"ERROR","message":str(e), "runtime_seconds": round(time.monotonic() - started, 2)}), 500)
