"""
TestRail users ingestion -> BigQuery (Cloud Run / Functions Framework)

Why:
- Looker filters/graphs currently show QA User IDs (numeric). This ingests TestRail users so we can map IDs -> email/name.

Secrets (GCP Secret Manager) - keep aligned with the other TestRail ingestion services:
- TESTRAIL_BASE_URL       e.g. https://<company>.testrail.io
- TESTRAIL_USER           (email/username)
- TESTRAIL_API_KEY
- TESTRAIL_PROJECT_ID     (single project) OR
- TESTRAIL_PROJECT_IDS    (comma-separated list)

Required env vars:
- GCP_PROJECT_ID
Optional env vars:
- BQ_DATASET_ID (default: qa_metrics)
- BQ_TABLE_ID   (default: testrail_users)
- BQ_INSERT_MAX_ROWS (default: 500)
- BQ_INSERT_MAX_BYTES (default: 8_000_000)
- REQUEST_TIMEOUT (default: 60)

Notes:
- Some TestRail instances restrict GET /get_users to administrators. For non-admins, the API typically requires a project scope.
  This ingester tries:
    1) /get_users/{project_id}
    2) /get_users&project_id={project_id}
  and merges/dedupes users across the provided project id(s).
"""

import os
import json
import datetime
import time
from typing import Any, Dict, Iterable, List, Tuple

import requests
from flask import jsonify
from google.cloud import bigquery
from google.cloud import secretmanager


# ---------------------------
# Config
# ---------------------------
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET_ID = os.getenv("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.getenv("BQ_TABLE_ID", "testrail_users")

BQ_INSERT_MAX_ROWS = int(os.getenv("BQ_INSERT_MAX_ROWS", "500"))
BQ_INSERT_MAX_BYTES = int(os.getenv("BQ_INSERT_MAX_BYTES", "8000000"))
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "60"))

# retries for TestRail API calls
HTTP_MAX_RETRIES = int(os.getenv("HTTP_MAX_RETRIES", "4"))
HTTP_RETRY_BACKOFF_SECS = float(os.getenv("HTTP_RETRY_BACKOFF_SECS", "1.2"))


# ---------------------------
# Secrets helper (same idea as other ingesters)
# ---------------------------
def get_secret(name: str) -> str:
    if not GCP_PROJECT_ID:
        raise RuntimeError("Missing env var: GCP_PROJECT_ID")

    client = secretmanager.SecretManagerServiceClient()
    secret_path = f"projects/{GCP_PROJECT_ID}/secrets/{name}/versions/latest"
    resp = client.access_secret_version(request={"name": secret_path})
    return resp.payload.data.decode("utf-8").strip()


def _testrail_base_url() -> str:
    base = get_secret("TESTRAIL_BASE_URL").rstrip("/")
    # standardize to API root
    if not base.endswith("/index.php?/api/v2"):
        base = base + "/index.php?/api/v2"
    return base


def _testrail_auth():
    return (get_secret("TESTRAIL_USER"), get_secret("TESTRAIL_API_KEY"))


def _project_ids() -> List[int]:
    # prefer explicit list, else single id
    ids_raw = None
    try:
        ids_raw = get_secret("TESTRAIL_PROJECT_IDS")
    except Exception:
        ids_raw = None

    if ids_raw:
        ids = []
        for part in ids_raw.split(","):
            part = part.strip()
            if part:
                ids.append(int(part))
        if ids:
            return ids

    # fallback single
    pid = int(get_secret("TESTRAIL_PROJECT_ID"))
    return [pid]


# ---------------------------
# BigQuery helpers
# ---------------------------
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


# ---------------------------
# TestRail API
# ---------------------------
def _http_get(url: str) -> requests.Response:
    last = None
    for attempt in range(1, HTTP_MAX_RETRIES + 1):
        try:
            resp = requests.get(url, auth=_testrail_auth(), timeout=REQUEST_TIMEOUT)
            # retry on 5xx / timeouts / gateway
            if resp.status_code >= 500:
                raise RuntimeError(f"{resp.status_code} {resp.text[:300]}")
            return resp
        except Exception as e:
            last = e
            if attempt < HTTP_MAX_RETRIES:
                time.sleep(HTTP_RETRY_BACKOFF_SECS * attempt)
            else:
                raise RuntimeError(f"HTTP failed after retries: {last}") from last


def fetch_users_for_project(project_id: int) -> List[Dict[str, Any]]:
    base = _testrail_base_url()

    # 1) path variant (preferred, matches get_runs/<project_id> style)
    url1 = f"{base}/get_users/{project_id}"
    r1 = _http_get(url1)
    if r1.status_code == 200:
        return r1.json() or []

    # 2) query variant (some instances use &project_id=)
    url2 = f"{base}/get_users&project_id={project_id}"
    r2 = _http_get(url2)
    if r2.status_code == 200:
        return r2.json() or []

    # If forbidden / bad request, surface details
    msg = (r2.text or r1.text or "")[:800]
    raise RuntimeError(f"TestRail API error {r2.status_code}: {msg}")


def fetch_users() -> List[Dict[str, Any]]:
    users_by_id: Dict[int, Dict[str, Any]] = {}

    for pid in _project_ids():
        arr = fetch_users_for_project(pid)
        for u in arr:
            try:
                uid = int(u.get("id"))
            except Exception:
                continue

            # merge strategy: prefer non-empty fields
            cur = users_by_id.get(uid, {})
            merged = dict(cur)
            for k in ["name", "email", "is_active", "role_id"]:
                v = u.get(k)
                if v is not None and v != "":
                    merged[k] = v
            merged["id"] = uid
            users_by_id[uid] = merged

    # stable order by id
    out = [users_by_id[k] for k in sorted(users_by_id.keys())]
    return out


# ---------------------------
# Cloud Run entrypoint
# ---------------------------
def hello_http(request):
    try:
        ensure_table()

        users = fetch_users()
        ingested_at = datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat()

        rows = []
        for u in users:
            rows.append(
                {
                    "user_id": int(u.get("id")),
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
                    "projects": _project_ids(),
                    "rows_fetched": len(rows),
                    "rows_inserted": ins,
                    "errors": errs[:50],
                }
            ),
            (200 if status == "OK" else 207),
        )

    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500
