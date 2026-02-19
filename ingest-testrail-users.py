"""
TestRail users ingestion -> BigQuery (Cloud Run / Functions Framework)

Why:
- Looker filters/graphs currently show QA User IDs (numeric). This ingests TestRail users so we can map IDs -> email/name.

Required env vars:
- GCP_PROJECT_ID
- BQ_DATASET_ID (default: qa_metrics)
- BQ_TABLE_ID   (default: testrail_users)

TestRail auth:
- TESTRAIL_BASE_URL or TESTRAIL_URL   e.g. https://<company>.testrail.io
- TESTRAIL_USER                       (email/username)
- TESTRAIL_API_KEY

Non-admin support (recommended):
- TESTRAIL_PROJECT_ID (single) OR TESTRAIL_PROJECT_IDS (comma-separated)
  If the TestRail user is not an administrator, TestRail commonly requires project_id to list users.

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


# --------------------------
# ENV
# --------------------------
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET_ID = os.getenv("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.getenv("BQ_TABLE_ID", "testrail_users")

# Support both names (your secrets use TESTRAIL_BASE_URL)
TESTRAIL_URL = os.getenv("TESTRAIL_URL") or os.getenv("TESTRAIL_BASE_URL")
TESTRAIL_USER = os.getenv("TESTRAIL_USER")
TESTRAIL_API_KEY = os.getenv("TESTRAIL_API_KEY")

_RAW_PIDS = os.getenv("TESTRAIL_PROJECT_IDS") or os.getenv("TESTRAIL_PROJECT_ID") or ""
TESTRAIL_PROJECT_IDS = [p.strip() for p in _RAW_PIDS.split(",") if p.strip()]

BQ_INSERT_MAX_ROWS = int(os.getenv("BQ_INSERT_MAX_ROWS", "500"))
BQ_INSERT_MAX_BYTES = int(os.getenv("BQ_INSERT_MAX_BYTES", "8000000"))
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "60"))


# --------------------------
# HELPERS
# --------------------------
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


def _testrail_auth():
    return (TESTRAIL_USER, TESTRAIL_API_KEY)


def _require_testrail_env() -> None:
    if not (TESTRAIL_URL and TESTRAIL_USER and TESTRAIL_API_KEY):
        raise RuntimeError(
            "Missing TestRail env vars: TESTRAIL_URL/TESTRAIL_BASE_URL / TESTRAIL_USER / TESTRAIL_API_KEY"
        )


# --------------------------
# BIGQUERY
# --------------------------
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
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY,
        field="_ingested_at",
    )
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
        # Stable row_ids = user_id to reduce duplicates if retried
        row_ids = [str(r.get("user_id")) for r in chunk]
        errors = bq.insert_rows_json(table_fq, chunk, row_ids=row_ids)
        if errors:
            all_errors.extend(errors)
        else:
            inserted += len(chunk)

    return inserted, all_errors


# --------------------------
# TESTRAIL API
# --------------------------
def _get_json(url: str) -> Any:
    resp = requests.get(url, auth=_testrail_auth(), timeout=REQUEST_TIMEOUT)
    if resp.status_code >= 400:
        raise RuntimeError(f"TestRail API error {resp.status_code}: {resp.text[:800]}")
    return resp.json()


def fetch_users() -> List[Dict[str, Any]]:
    """
    Strategy:
    1) Try global get_users (works for admins in many setups)
    2) If 403 and mentions admin/project_id, fall back to per-project get_users&project_id=...
       using TESTRAIL_PROJECT_ID(S) and dedupe by user id.
    """
    _require_testrail_env()

    base = TESTRAIL_URL.rstrip("/")

    # 1) Try admin/global endpoint
    url_all = f"{base}/index.php?/api/v2/get_users"
    resp = requests.get(url_all, auth=_testrail_auth(), timeout=REQUEST_TIMEOUT)

    if resp.status_code < 400:
        return resp.json() or []

    # 2) Non-admin fallback: must use project_id
    body_lower = (resp.text or "").lower()
    if resp.status_code == 403 and ("project_id" in body_lower or "administrator" in body_lower):
        if not TESTRAIL_PROJECT_IDS:
            raise RuntimeError(
                "TestRail user is not admin and server requires project_id. "
                "Provide TESTRAIL_PROJECT_ID or TESTRAIL_PROJECT_IDS (comma-separated). "
                f"Original response: {resp.text[:300]}"
            )

        users_by_id: Dict[int, Dict[str, Any]] = {}

        for pid in TESTRAIL_PROJECT_IDS:
            # TestRail query params are embedded after & (their API style)
            url_proj = f"{base}/index.php?/api/v2/get_users&project_id={pid}"
            proj_users = _get_json(url_proj) or []
            for u in proj_users:
                if not u:
                    continue
                uid = u.get("id")
                if uid is None:
                    continue
                users_by_id[int(uid)] = u

        return list(users_by_id.values())

    # Otherwise propagate original error
    raise RuntimeError(f"TestRail API error {resp.status_code}: {resp.text[:800]}")


# --------------------------
# HTTP HANDLER
# --------------------------
def hello_http(request):
    """
    Cloud Run (Functions Framework) handler.
    Trigger via POST {} from Workflows.
    """
    try:
        ensure_table()

        users = fetch_users()
        ingested_at = datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

        rows: List[Dict[str, Any]] = []
        for u in users:
            # Defensive conversions
            uid = u.get("id")
            if uid is None:
                continue

            rows.append(
                {
                    "user_id": int(uid),
                    "name": u.get("name"),
                    "email": u.get("email"),
                    "is_active": bool(u.get("is_active")) if u.get("is_active") is not None else None,
                    "role_id": int(u.get("role_id")) if u.get("role_id") is not None else None,
                    "_ingested_at": ingested_at,
                }
            )

        ins, errs = insert_rows(rows)
        status = "OK" if not errs else "PARTIAL"

        return (
            jsonify(
                {
                    "status": status,
                    "rows_fetched": len(rows),
                    "rows_inserted": ins,
                    "projects_used": TESTRAIL_PROJECT_IDS,
                    "errors": errs[:50],
                }
            ),
            (200 if status == "OK" else 207),
        )

    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500
