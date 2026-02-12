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
TABLE_NAME = os.environ.get("BQ_TABLE", "bugsnag_errors")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"

STORE_PAYLOAD = os.environ.get("STORE_PAYLOAD", "false").lower() in ("1","true","yes")
PAYLOAD_MAX_CHARS = int(os.environ.get("PAYLOAD_MAX_CHARS", "50000"))


bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

# HTTP knobs
HTTP_TIMEOUT = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "30"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
BASE_BACKOFF = float(os.environ.get("BASE_BACKOFF_SECONDS", "1.0"))
MAX_BACKOFF = float(os.environ.get("MAX_BACKOFF_SECONDS", "30.0"))

OVERLAP_DAYS = int(os.environ.get("OVERLAP_DAYS", "7"))


# ----------------- Secrets -----------------
def get_secret(name: str) -> str:
    secret_name = f"projects/{PROJECT_ID}/secrets/{name}/versions/latest"
    response = sm.access_secret_version(request={"name": secret_name})
    return response.payload.data.decode("utf-8").strip()


# ----------------- BigQuery -----------------
def ensure_table():
    schema = [
        bigquery.SchemaField("project_id","STRING"),
        bigquery.SchemaField("error_id","STRING"),
        bigquery.SchemaField("error_class","STRING"),
        bigquery.SchemaField("message","STRING"),
        bigquery.SchemaField("severity","STRING"),
        bigquery.SchemaField("status","STRING"),
        bigquery.SchemaField("first_seen","TIMESTAMP"),
        bigquery.SchemaField("last_seen","TIMESTAMP"),
        bigquery.SchemaField("events","INT64"),
        bigquery.SchemaField("users","INT64"),
        bigquery.SchemaField("url","STRING"),
        bigquery.SchemaField("_ingested_at","TIMESTAMP"),
        bigquery.SchemaField("payload","STRING"),
    ]

    table = bigquery.Table(TABLE_ID, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY, field="last_seen"
    )
    table.clustering_fields = ["project_id", "error_id", "status", "severity"]
    bq.create_table(table, exists_ok=True)


def get_last_seen() -> datetime:
    sql = f"""
      SELECT COALESCE(MAX(last_seen), TIMESTAMP('1970-01-01')) AS last_seen_max
      FROM `{TABLE_ID}`
    """
    rows = list(bq.query(sql))
    last = rows[0]["last_seen_max"]

    now = datetime.now(timezone.utc)
    floor_30d = now - timedelta(days=30)

    # Si no hay datos, empieza en 30 días atrás
    if last is None or getattr(last, "year", 1970) == 1970:
        return floor_30d

    # Normaliza tz
    if last.tzinfo is None:
        last = last.replace(tzinfo=timezone.utc)
    else:
        last = last.astimezone(timezone.utc)

    # tu lógica normal (overlap)
    since = last - timedelta(days=OVERLAP_DAYS)

    # ✅ Clamp: nunca más antiguo que 30 días
    return max(since, floor_30d)


# ----------------- HTTP -----------------
def request_with_retries(method: str, url: str, *, headers: Dict[str, str], params: Dict[str, Any]) -> requests.Response:
    last_exc: Optional[Exception] = None
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.request(method, url, headers=headers, params=params, timeout=HTTP_TIMEOUT)

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


# ----------------- Bugsnag fetch -----------------
def fetch_bugsnag_errors(since_ts: datetime) -> List[Dict[str, Any]]:
    base_url = get_secret("BUGSNAG_BASE_URL").rstrip("/")
    api_token = get_secret("BUGSNAG_TOKEN")
    project_ids = [p.strip() for p in get_secret("BUGSNAG_PROJECT_IDS").split(",") if p.strip()]

    headers = {"Authorization": f"token {api_token}", "Accept": "application/json"}

    rows: List[Dict[str, Any]] = []
    ingested_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    for project_id in project_ids:
        page = 1
        while True:
            params = {
                "per_page": 100,
                "page": page,
                "sort": "last_seen",
                "direction": "asc",
                "last_seen_after": since_ts.isoformat(),
            }
            url = f"{base_url}/projects/{project_id}/errors"
            resp = request_with_retries("GET", url, headers=headers, params=params)

            data = resp.json()
            if not data:
                break

            for e in data:
                rows.append({
                    "project_id": str(project_id),
                    "error_id": e.get("id"),
                    "error_class": e.get("error_class"),
                    "message": e.get("message"),
                    "severity": e.get("severity"),
                    "status": e.get("status"),
                    "first_seen": e.get("first_seen"),
                    "last_seen": e.get("last_seen"),
                    "events": int(e.get("events", 0) or 0),
                    "users": int(e.get("users", 0) or 0),
                    "url": e.get("events_url") or e.get("url"),
                    "_ingested_at": ingested_at,
                    "payload": (json.dumps(e)[:PAYLOAD_MAX_CHARS] if STORE_PAYLOAD else None),
                })

            if len(data) < 100:
                break
            page += 1

    return rows


def insert_rows(rows: List[Dict[str, Any]]) -> None:
    if not rows:
        return

    CHUNK_SIZE = int(os.environ.get("BQ_INSERT_CHUNK_SIZE", "500"))

    row_ids_all = []
    for r in rows:
        if r.get("error_id") and r.get("last_seen"):
            row_ids_all.append(f'{r.get("project_id")}:{r.get("error_id")}:{r.get("last_seen")}')
        else:
            row_ids_all.append(None)

    for i in range(0, len(rows), CHUNK_SIZE):
        batch = rows[i:i+CHUNK_SIZE]
        batch_ids = row_ids_all[i:i+CHUNK_SIZE]
        errors = bq.insert_rows_json(TABLE_ID, batch, row_ids=batch_ids)
        if errors:
            raise RuntimeError(errors)



# ----------------- Cloud Function entrypoint -----------------
def hello_http(request):
    try:
        ensure_table()
        since_ts = get_last_seen()
        rows = fetch_bugsnag_errors(since_ts)
        insert_rows(rows)
        return (jsonify({"status":"OK","rows":len(rows), "since": since_ts.isoformat()}), 200)
    except Exception as e:
        return (jsonify({"status":"ERROR","message":str(e)}), 500)
