"""Ingest TestRail users into BigQuery.

Important: many TestRail instances restrict `get_users` to site admins.
For non-admin API keys, TestRail supports `get_users/{project_id}`.

Env vars:
- TESTRAIL_URL (e.g. https://<company>.testrail.io)
- TESTRAIL_EMAIL (or TESTRAIL_USER)
- TESTRAIL_API_KEY
- TESTRAIL_PROJECT_IDS (comma-separated) OR TESTRAIL_PROJECT_ID

BQ env vars:
- BQ_DATASET_ID (default qa_metrics)
- BQ_TABLE_ID (default testrail_users)

HTTP body overrides:
- project_ids
"""

import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Set, Tuple

import functions_framework
import requests
from google.cloud import bigquery


BQ_DATASET_ID = os.environ.get("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.environ.get("BQ_TABLE_ID", "testrail_users")

TESTRAIL_URL = os.environ.get("TESTRAIL_URL")
TESTRAIL_EMAIL = os.environ.get("TESTRAIL_EMAIL") or os.environ.get("TESTRAIL_USER")
TESTRAIL_API_KEY = os.environ.get("TESTRAIL_API_KEY")
TESTRAIL_PROJECT_IDS = os.environ.get("TESTRAIL_PROJECT_IDS") or os.environ.get("TESTRAIL_PROJECT_ID") or ""


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


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _get_project_id() -> str:
    pid = os.environ.get("GCP_PROJECT_ID")
    if pid:
        return pid
    return bigquery.Client().project


def _auth() -> requests.auth.HTTPBasicAuth:
    if not (TESTRAIL_EMAIL and TESTRAIL_API_KEY):
        raise RuntimeError("Missing TESTRAIL_EMAIL/TESTRAIL_USER or TESTRAIL_API_KEY")
    return requests.auth.HTTPBasicAuth(TESTRAIL_EMAIL, TESTRAIL_API_KEY)


def _get(path: str) -> Any:
    if not TESTRAIL_URL:
        raise RuntimeError("Missing TESTRAIL_URL")
    url = TESTRAIL_URL.rstrip("/") + path
    r = requests.get(url, auth=_auth(), timeout=60)
    r.raise_for_status()
    return r.json()


def _ensure_table(bq: bigquery.Client, table_ref: bigquery.TableReference) -> None:
    desired_schema = [
        bigquery.SchemaField("user_id", "INT64", mode="REQUIRED"),
        bigquery.SchemaField("name", "STRING"),
        bigquery.SchemaField("email", "STRING"),
        bigquery.SchemaField("is_active", "BOOL"),
        bigquery.SchemaField("is_admin", "BOOL"),
        bigquery.SchemaField("role_id", "INT64"),
        bigquery.SchemaField("project_id", "INT64"),
        bigquery.SchemaField("raw_json", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    try:
        table = bq.get_table(table_ref)
        existing = {f.name for f in table.schema}
        to_add = [f for f in desired_schema if f.name not in existing]
        if to_add:
            table.schema = list(table.schema) + to_add
            bq.update_table(table, ["schema"])
            print(f"Added {len(to_add)} columns to {table_ref}")
    except Exception:
        table = bigquery.Table(table_ref, schema=desired_schema)
        table.time_partitioning = bigquery.TimePartitioning(field="_ingested_at")
        bq.create_table(table)
        print(f"Created table {table_ref}")


def _normalize_project_ids(raw: Any) -> List[str]:
    """Normalize project id input from env/http into a clean string list."""
    if raw is None:
        return []

    values: Iterable[Any]
    if isinstance(raw, (list, tuple, set)):
        values = raw
    else:
        values = str(raw).split(",")

    return [str(v).strip() for v in values if str(v).strip()]


def _to_bool_or_none(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"1", "true", "yes", "y"}:
            return True
        if normalized in {"0", "false", "no", "n", ""}:
            return False
    return bool(value)


@functions_framework.http
def ingest_testrail_users(request):
    req = request.get_json(silent=True) or {}

    proj_raw = req.get("project_ids") or TESTRAIL_PROJECT_IDS
    project_ids = _normalize_project_ids(proj_raw)
    if not project_ids:
        return _error_response(
            "config_error",
            "missing_project_ids",
            "No project ids provided. Set TESTRAIL_PROJECT_IDS or pass project_ids",
            400,
        )

    bq = bigquery.Client(project=_get_project_id())
    table_ref = bq.dataset(BQ_DATASET_ID).table(BQ_TABLE_ID)
    _ensure_table(bq, table_ref)

    ingested_at = _utc_now_iso()

    rows: List[Dict[str, Any]] = []
    seen: Set[Tuple[int, int]] = set()
    failures: List[str] = []

    for pid in project_ids:
        try:
            pid_int = int(pid)
        except (TypeError, ValueError):
            failures.append(f"Invalid project id '{pid}'")
            continue

        try:
            users = _get(f"/index.php?/api/v2/get_users/{pid_int}")
        except Exception as e:
            failures.append(f"Failed get_users/{pid_int}: {e}")
            continue

        if isinstance(users, dict) and "users" in users:
            users = users["users"]

        if not isinstance(users, list):
            failures.append(f"Unexpected response type for project {pid_int}: {type(users)}")
            continue

        for u in users:
            if not isinstance(u, dict):
                continue
            uid = u.get("id")
            if uid is None:
                continue
            try:
                uid_int = int(uid)
            except Exception:
                continue

            key = (uid_int, pid_int)
            if key in seen:
                continue
            seen.add(key)

            # Keep one row per (user_id, project_id) so we preserve project scoping
            row = {
                "user_id": uid_int,
                "name": u.get("name"),
                "email": u.get("email"),
                "is_active": _to_bool_or_none(u.get("is_active")),
                "is_admin": _to_bool_or_none(u.get("is_admin")),
                "role_id": int(u["role_id"]) if u.get("role_id") is not None else None,
                "project_id": pid_int,
                "raw_json": json.dumps(u, ensure_ascii=False),
                "_ingested_at": ingested_at,
            }
            rows.append(row)

    if not rows and failures:
        print("; ".join(failures))
        return _error_response("runtime_error", "testrail_users_ingest_failed", "No users ingested", 502, failures[:5])

    if rows:
        errors = bq.insert_rows_json(table_ref, rows)
        if errors:
            print("BigQuery insert errors (first 3):", errors[:3])
            return _error_response("runtime_error", "bigquery_insert_failed", "BigQuery insert failed", 500, errors[:3])

    return (
        json.dumps(
            {
                "ok": True,
                "projects": project_ids,
                "rows_inserted": len(rows),
                "warnings": failures[:5],
                "bq_table": f"{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}",
            }
        ),
        200,
        {"Content-Type": "application/json"},
    )


def hello_http(request):
    if request.path.endswith("/healthz") or request.method == "GET":
        return (json.dumps({"ok": True, "service": "ingest-testrail-users", "ready": True}), 200, {"Content-Type": "application/json"})
    return ingest_testrail_users(request)
