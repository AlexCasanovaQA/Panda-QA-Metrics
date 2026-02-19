"""
TestRail users ingestion -> BigQuery (Cloud Run / Functions Framework)

Why:
- Looker filters/graphs currently show QA User IDs (numeric). This ingests TestRail users so we can map IDs -> email/name.

Required env vars:
- GCP_PROJECT_ID
- BQ_DATASET_ID (default: qa_metrics)
- BQ_TABLE_ID   (default: testrail_users)

TestRail auth (matches the other TestRail ingestion services):
- TESTRAIL_URL           e.g. https://<company>.testrail.io
- TESTRAIL_USER          (email/username)
- TESTRAIL_API_KEY

Optional:
- BQ_INSERT_MAX_ROWS (default: 500)
- BQ_INSERT_MAX_BYTES (default: 8_000_000)
- REQUEST_TIMEOUT (default: 60)
"""

import os
import json
import datetime
from typing import Any, Dict, Iterable, List, Tuple

import requests
from flask import jsonify
from google.cloud import bigquery


GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET_ID = os.getenv("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.getenv("BQ_TABLE_ID", "testrail_users")

TESTRAIL_URL = os.getenv("TESTRAIL_URL")
TESTRAIL_USER = os.getenv("TESTRAIL_USER")
TESTRAIL_API_KEY = os.getenv("TESTRAIL_API_KEY")

BQ_INSERT_MAX_ROWS = int(os.getenv("BQ_INSERT_MAX_ROWS", "500"))
BQ_INSERT_MAX_BYTES = int(os.getenv("BQ_INSERT_MAX_BYTES", "8000000"))
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "60"))


def _safe_json_size(obj: Any) -> int:
    return len(json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


def _chunk_rows(rows: List[Dict[str, Any]], max_rows: int, max_bytes: int) -> Iterable[List[Dict[str, Any]]]:
    batch: List[Dict[str, Any]] = []
    batch_bytes = 0

    for r in rows:
        r_bytes = _safe_json_size(r)

        if batch and (len(batch) >= max_rows or batch_bytes + r_bytes > max_bytes):
            yield batch
            batch = []
            batch_bytes = 0

        batch.append(r)
        batch_bytes += r_bytes

        if len(batch) >= max_rows:
            yield batch
            batch = []
            batch_bytes = 0

    if batch:
        yield batch


def _bq_client() -> bigquery.Client:
    if not GCP_PROJECT_ID:
        raise RuntimeError("Missing env var: GCP_PROJECT_ID")
    return bigquery.Client(project=GCP_PROJECT_ID)


def ensure_table() -> None:
    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"

    schema = [
        bigquery.SchemaField("user_id", "INT64", mode="REQUIRED"),
        bigquery.SchemaField("name", "STRING"),
        bigquery.SchemaField("email", "STRING"),
        bigquery.SchemaField("is_active", "BOOL"),
        bigquery.SchemaField("role_id", "INT64"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    table = bigquery.Table(table_fq, schema=schema)
    table.time_partitioning = bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY, field="_ingested_at")
    table.clustering_fields = ["user_id"]

    bq.create_table(table, exists_ok=True)


def insert_rows(rows: List[Dict[str, Any]]) -> Tuple[int, List[Any]]:
    if not rows:
        return 0, []

    bq = _bq_client()
    table_fq = f"{GCP_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"

    inserted = 0
    all_errors: List[Any] = []

    for chunk in _chunk_rows(rows, max_rows=BQ_INSERT_MAX_ROWS, max_bytes=BQ_INSERT_MAX_BYTES):
        row_ids = [str(r.get("user_id")) for r in chunk]
        errors = bq.insert_rows_json(table_fq, chunk, row_ids=row_ids)
        if errors:
            all_errors.extend(errors)
        else:
            inserted += len(chunk)

    return inserted, all_errors


def _testrail_auth():
    return (TESTRAIL_USER, TESTRAIL_API_KEY)


def fetch_users() -> List[Dict[str, Any]]:
    if not (TESTRAIL_URL and TESTRAIL_USER and TESTRAIL_API_KEY):
        raise RuntimeError("Missing TestRail env vars: TESTRAIL_URL / TESTRAIL_USER / TESTRAIL_API_KEY")

    url = f"{TESTRAIL_URL.rstrip('/')}/index.php?/api/v2/get_users"
    resp = requests.get(url, auth=_testrail_auth(), timeout=REQUEST_TIMEOUT)
    if resp.status_code >= 400:
        raise RuntimeError(f"TestRail API error {resp.status_code}: {resp.text[:800]}")

    return resp.json() or []


def hello_http(request):
    try:
        ensure_table()

        users = fetch_users()
        ingested_at = datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

        rows = []
        for u in users:
            rows.append({
                "user_id": int(u.get("id")),
                "name": u.get("name"),
                "email": u.get("email"),
                "is_active": bool(u.get("is_active")) if u.get("is_active") is not None else None,
                "role_id": int(u.get("role_id")) if u.get("role_id") is not None else None,
                "_ingested_at": ingested_at,
            })

        ins, errs = insert_rows(rows)
        status = "OK" if not errs else "PARTIAL"
        return jsonify({
            "status": status,
            "rows_fetched": len(rows),
            "rows_inserted": ins,
            "errors": errs[:50],
        }), (200 if status == "OK" else 207)

    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500
