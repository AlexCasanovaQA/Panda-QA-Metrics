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
TABLE_NAME = os.environ.get("BQ_TABLE", "testrail_users")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

# Runtime knobs (mismo estilo que los otros scripts)
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
    # env fallback (por si acaso)
    return [int(os.environ.get("TESTRAIL_PROJECT_ID", "0"))] if os.environ.get("TESTRAIL_PROJECT_ID") else []

# ----------------- BigQuery -----------------
def ensure_table() -> None:
    schema = [
        bigquery.SchemaField("user_id", "INT64", mode="REQUIRED"),
        bigquery.SchemaField("name", "STRING"),
        bigquery.SchemaField("email", "STRING"),
        bigquery.SchemaField("is_active", "BOOL"),
        bigquery.SchemaField("role_id", "INT64"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
        bigquery.SchemaField("payload", "STRING"),
    ]

    table = bigquery.Table(TABLE_ID, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY,
        field="_ingested_at",
    )
    table.clustering_fields = ["user_id"]
    bq.create_table(table, exists_ok=True)

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

# ----------------- Fetch -----------------
def fetch_users_for_project(project_id: int) -> List[Dict[str, Any]]:
    base = testrail_base_url()
    # Importante: este endpoint con project_id evita el requisito de "TestRail administrator"
    url = f"{base}/get_users&project_id={project_id}"

    resp = request_with_retries("GET", url, auth=testrail_auth())
    data = resp.json()

    # Puede venir como lista o como dict con "users"
    if isinstance(data, list):
        return [u for u in data if isinstance(u, dict)]
    if isinstance(data, dict) and "users" in data:
        users = data.get("users") or []
        return [u for u in users if isinstance(u, dict)]
    if isinstance(data, dict) and data.get("error"):
        raise RuntimeError(f"TestRail get_users error for project {project_id}: {data.get('error')}")
    raise RuntimeError(f"Unexpected TestRail get_users response type for project {project_id}: {type(data).__name__}")

def fetch_all_users(project_ids: List[int]) -> List[Dict[str, Any]]:
    users_by_id: Dict[int, Dict[str, Any]] = {}
    for pid in project_ids:
        for u in fetch_users_for_project(pid):
            uid = u.get("id")
            if uid is None:
                continue
            users_by_id[int(uid)] = u
    return list(users_by_id.values())

# ----------------- Insert -----------------
def insert_rows(rows: List[Dict[str, Any]], row_ids: List[Optional[str]]) -> None:
    if not rows:
        return
    errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
    if errors:
        raise RuntimeError(errors)

# ----------------- Entry -----------------
def hello_http(request):
    try:
        ensure_table()

        pids = testrail_project_ids()
        if not pids:
            return (jsonify({"status": "ERROR", "message": "No TESTRAIL_PROJECT_IDS/TESTRAIL_PROJECT_ID configured"}), 500)

        users = fetch_all_users(pids)
        ingested_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

        rows: List[Dict[str, Any]] = []
        row_ids: List[Optional[str]] = []

        for u in users:
            uid = u.get("id")
            if uid is None:
                continue

            rows.append({
                "user_id": int(uid),
                "name": u.get("name"),
                "email": u.get("email"),
                "is_active": bool(u.get("is_active")) if u.get("is_active") is not None else None,
                "role_id": int(u.get("role_id")) if u.get("role_id") is not None else None,
                "_ingested_at": ingested_at,
                "payload": json.dumps(u),
            })
            # insertId estable por usuario (minimiza duplicados por retries)
            row_ids.append(str(uid))

        insert_rows(rows, row_ids)

        return (jsonify({
            "status": "OK",
            "projects_used": pids,
            "users_fetched": len(users),
            "rows_inserted": len(rows),
        }), 200)

    except Exception as e:
        return (jsonify({"status": "ERROR", "message": str(e)}), 500)
