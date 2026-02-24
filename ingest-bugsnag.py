import json
import os
import time
import random
from datetime import datetime, timezone, timedelta
from email.utils import parsedate_to_datetime
from typing import Any, Dict, List, Optional

import google.auth
import requests
from flask import jsonify
from google.cloud import bigquery, secretmanager

_, PROJECT_ID = google.auth.default()

DATASET_ID = os.environ.get("BQ_DATASET", "qa_metrics")
TABLE_NAME = os.environ.get("BQ_TABLE", "bugsnag_errors")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_NAME}"

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

HTTP_TIMEOUT = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "30"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
BASE_BACKOFF = float(os.environ.get("BASE_BACKOFF_SECONDS", "1.0"))
MAX_BACKOFF = float(os.environ.get("MAX_BACKOFF_SECONDS", "30.0"))

OVERLAP_DAYS = int(os.environ.get("OVERLAP_DAYS", "7"))

# NUEVO: límites para que nunca se eternice
LOOKBACK_DAYS = int(os.environ.get("BUGSNAG_LOOKBACK_DAYS", "30"))     # <- último mes
MAX_RUNTIME_SECONDS = int(os.environ.get("MAX_RUNTIME_SECONDS", "240")) # <- 4 min por run
MAX_ERRORS_PER_RUN = int(os.environ.get("MAX_ERRORS_PER_RUN", "5000")) # <- corta si hay muchísimo
PER_PAGE = int(os.environ.get("BUGSNAG_PER_PAGE", "100"))              # <= 100 según docs
BQ_INSERT_CHUNK_SIZE = int(os.environ.get("BQ_INSERT_CHUNK_SIZE", "500"))

def get_secret(name: str) -> str:
    secret_name = f"projects/{PROJECT_ID}/secrets/{name}/versions/latest"
    response = sm.access_secret_version(request={"name": secret_name})
    return response.payload.data.decode("utf-8").strip()

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
    if last is None or getattr(last, "year", 1970) == 1970:
        last = datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)

    if last.tzinfo is None:
        last = last.replace(tzinfo=timezone.utc)
    else:
        last = last.astimezone(timezone.utc)

    # overlap para no perder bordes
    last = last - timedelta(days=OVERLAP_DAYS)

    # CLAMP: nunca más antiguo que último mes
    clamp = datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)
    return max(last, clamp)

def _parse_retry_after(header_value: Optional[str]) -> Optional[float]:
    if not header_value:
        return None

    if header_value.isdigit():
        return float(header_value)

    try:
        retry_at = parsedate_to_datetime(header_value)
    except (TypeError, ValueError):
        return None

    if retry_at.tzinfo is None:
        retry_at = retry_at.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    return max(0.0, (retry_at - now).total_seconds())


def request_with_retries(method: str, url: str, *, headers: Dict[str, str], params: Optional[Dict[str, Any]] = None) -> requests.Response:
    last_exc: Optional[Exception] = None
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.request(method, url, headers=headers, params=params, timeout=HTTP_TIMEOUT)

            if r.status_code in (429, 500, 502, 503, 504):
                retry_after_seconds = _parse_retry_after(r.headers.get("Retry-After"))
                if retry_after_seconds is not None:
                    sleep_s = min(retry_after_seconds, MAX_BACKOFF)
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

def insert_rows(rows: List[Dict[str, Any]]) -> None:
    if not rows:
        return
    row_ids = []
    for r in rows:
        if r.get("error_id") and r.get("last_seen"):
            row_ids.append(f'{r.get("project_id")}:{r.get("error_id")}:{r.get("last_seen")}')
        else:
            row_ids.append(None)

    errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
    if errors:
        raise RuntimeError(errors)

def fetch_and_insert_bugsnag_errors(since_ts: datetime, started_monotonic: float) -> int:
    base_url = get_secret("BUGSNAG_BASE_URL").rstrip("/")
    api_token = get_secret("BUGSNAG_TOKEN")
    project_ids = [p.strip() for p in get_secret("BUGSNAG_PROJECT_IDS").split(",") if p.strip()]

    headers = {"Authorization": f"token {api_token}", "Accept": "application/json"}

    ingested_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    total_inserted = 0
    buffer: List[Dict[str, Any]] = []

    # opción A (simple): usar filtro “dashboard style” del último mes
    # since_filter = f"{LOOKBACK_DAYS}d"
    # opción B (más exacta): ISO UTC desde since_ts
    since_filter = since_ts.replace(microsecond=0).isoformat().replace("+00:00", "Z")

    for project_id in project_ids:
        # IMPORTANTE: paginar con Link header (next), no con page++
        url = f"{base_url}/projects/{project_id}/errors"
        params = {
            "per_page": PER_PAGE,
            "sort": "last_seen",
            "direction": "asc",
            "filters[event.since]": since_filter,
        }

        while True:
            if (time.monotonic() - started_monotonic) > (MAX_RUNTIME_SECONDS - 5):
                # flush lo que tengamos y cortar
                if buffer:
                    insert_rows(buffer)
                    total_inserted += len(buffer)
                return total_inserted

            resp = request_with_retries("GET", url, headers=headers, params=params)
            data = resp.json() or []
            if isinstance(data, dict):
                data = data.get("errors", [])
            if not isinstance(data, list):
                raise RuntimeError(f"Unexpected BugSnag payload type: {type(data).__name__}")
            if not data:
                break

            for e in data:
                in_flight = total_inserted + len(buffer)
                if in_flight >= MAX_ERRORS_PER_RUN:
                    if buffer:
                        insert_rows(buffer)
                        total_inserted += len(buffer)
                    return total_inserted

                buffer.append({
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
                    "payload": json.dumps(e, separators=(",", ":")),
                })

                if len(buffer) >= BQ_INSERT_CHUNK_SIZE:
                    insert_rows(buffer)
                    total_inserted += len(buffer)
                    buffer = []

            # siguiente página (si existe)
            next_url = resp.links.get("next", {}).get("url")
            if not next_url:
                break

            url = next_url
            params = {}  # next_url ya trae sus query params

    if buffer:
        insert_rows(buffer)
        total_inserted += len(buffer)

    return total_inserted

def hello_http(request):
    if request.path.endswith("/healthz") or request.method == "GET":
        return (jsonify({"status": "OK", "service": "ingest-bugsnag", "ready": True}), 200)

    started = time.monotonic()
    try:
        ensure_table()
        since_ts = get_last_seen()
        inserted = fetch_and_insert_bugsnag_errors(since_ts, started_monotonic=started)
        return (jsonify({
            "status": "OK",
            "rows_inserted": inserted,
            "since": since_ts.isoformat(),
            "runtime_seconds": round(time.monotonic() - started, 2),
        }), 200)
    except Exception as e:
        return (jsonify({
            "status": "ERROR",
            "message": str(e),
            "runtime_seconds": round(time.monotonic() - started, 2),
        }), 500)
