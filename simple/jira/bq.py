from __future__ import annotations

import logging
import os
import re
from typing import Any, Dict, List, Optional

from google.api_core.exceptions import BadRequest, NotFound
from google.cloud import bigquery

LOGGER = logging.getLogger(__name__)


def get_bq_project() -> str:
    for key in ("BQ_PROJECT", "GOOGLE_CLOUD_PROJECT", "GCP_PROJECT", "GCLOUD_PROJECT"):
        v = os.environ.get(key)
        if v and str(v).strip():
            return str(v).strip()
    return ""


def get_bq_dataset() -> str:
    return os.environ.get("BQ_DATASET", "qa_metrics_simple").strip()


def get_bq_dataset_fallback() -> Optional[str]:
    primary = get_bq_dataset()
    raw = os.environ.get("BQ_DATASET_FALLBACK")
    if raw is None:
        fallback = f"{primary}_mirror"
    else:
        fallback = str(raw).strip()
        if not fallback:
            return None
    return None if fallback == primary else fallback


def get_bq_location() -> Optional[str]:
    v = os.environ.get("BQ_LOCATION", "EU")
    v = str(v).strip() if v is not None else ""
    return v or None


def table_ref(table: str, dataset: Optional[str] = None) -> str:
    project = get_bq_project()
    dataset_name = dataset or get_bq_dataset()
    if not project:
        raise RuntimeError("Missing project env var (BQ_PROJECT/GOOGLE_CLOUD_PROJECT/GCP_PROJECT/GCLOUD_PROJECT).")
    return f"{project}.{dataset_name}.{table}"


def get_client() -> bigquery.Client:
    project = get_bq_project() or None
    return bigquery.Client(project=project)


def resolve_query_location(client: bigquery.Client) -> Optional[str]:
    """Resolve the location to use for query jobs.

    Priority:
    1) Explicit BQ_LOCATION env var.
    2) Dataset location from BigQuery metadata.
    3) None (let BigQuery determine it).
    """
    configured = get_bq_location()
    if configured:
        return configured

    project = get_bq_project()
    dataset = get_bq_dataset()
    if not project or not dataset:
        return None

    try:
        dataset_obj = client.get_dataset(f"{project}.{dataset}")
        return dataset_obj.location
    except Exception as exc:  # best-effort lookup; downstream calls handle typed errors
        LOGGER.warning("Unable to resolve dataset location from metadata: %s", exc)
        return None


def _is_dataset_not_found_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return (
        "dataset" in msg
        and "not found" in msg
        and ("location" in msg or "notfound" in exc.__class__.__name__.lower())
    )


def _rewrite_query_dataset(sql: str, source_dataset: str, target_dataset: str) -> str:
    if source_dataset == target_dataset:
        return sql
    return re.sub(rf"(?<=\.){re.escape(source_dataset)}(?=\.)", target_dataset, sql)


def _log_dataset_not_found_alert(exc: Exception) -> None:
    LOGGER.error(
        "BQ_DATASET_NOT_FOUND_ALERT project=%s dataset=%s location=%s error=%s",
        get_bq_project() or "<unknown>",
        get_bq_dataset() or "<unknown>",
        get_bq_location() or "<unset>",
        exc,
    )


def _log_fallback_used(operation: str, primary_error: Exception, fallback_dataset: str) -> None:
    LOGGER.warning(
        "BQ_DATASET_FALLBACK_USED operation=%s project=%s primary_dataset=%s fallback_dataset=%s location=%s primary_error=%s",
        operation,
        get_bq_project() or "<unknown>",
        get_bq_dataset() or "<unknown>",
        fallback_dataset,
        get_bq_location() or "<unset>",
        primary_error,
    )


def _raise_dataset_error(exc: Exception, *, operation: str, fallback_attempted: bool, failure_reason: str) -> None:
    if _is_dataset_not_found_error(exc):
        _log_dataset_not_found_alert(exc)
        raise RuntimeError(
            f"BigQuery {operation} blocked by dataset availability/location mismatch; "
            f"fallback_attempted={fallback_attempted}; reason={failure_reason}. "
            "Verify BQ_PROJECT/BQ_DATASET/BQ_LOCATION and BQ_DATASET_FALLBACK."
        ) from exc
    raise exc


def insert_rows(client: bigquery.Client, table: str, rows: List[Dict[str, Any]], *, ignore_unknown_values: bool = True) -> int:
    if not rows:
        return 0
    try:
        errors = client.insert_rows_json(table_ref(table), rows, ignore_unknown_values=ignore_unknown_values)
    except (NotFound, BadRequest) as exc:
        if not _is_dataset_not_found_error(exc):
            raise exc
        fallback_dataset = get_bq_dataset_fallback()
        if not fallback_dataset:
            _raise_dataset_error(exc, operation="insert", fallback_attempted=False, failure_reason="fallback_disabled_or_same_as_primary")
        _log_fallback_used("insert", exc, fallback_dataset)
        try:
            errors = client.insert_rows_json(table_ref(table, dataset=fallback_dataset), rows, ignore_unknown_values=ignore_unknown_values)
        except (NotFound, BadRequest) as fallback_exc:
            _raise_dataset_error(
                fallback_exc,
                operation="insert",
                fallback_attempted=True,
                failure_reason=f"fallback_dataset_failed fallback_dataset={fallback_dataset} primary_error={exc}",
            )

    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors[:3]}{' ...' if len(errors) > 3 else ''}")
    return len(rows)


def run_query(client: bigquery.Client, sql: str, job_labels: Optional[Dict[str, str]] = None) -> None:
    job_config = bigquery.QueryJobConfig()
    if job_labels:
        job_config.labels = job_labels
    try:
        job = client.query(sql, job_config=job_config, location=get_bq_location())
        job.result()
    except (NotFound, BadRequest) as exc:
        if not _is_dataset_not_found_error(exc):
            raise exc
        fallback_dataset = get_bq_dataset_fallback()
        if not fallback_dataset:
            _raise_dataset_error(exc, operation="query", fallback_attempted=False, failure_reason="fallback_disabled_or_same_as_primary")
        _log_fallback_used("query", exc, fallback_dataset)
        fallback_sql = _rewrite_query_dataset(sql, get_bq_dataset(), fallback_dataset)
        try:
            job = client.query(fallback_sql, job_config=job_config, location=get_bq_location())
            job.result()
        except (NotFound, BadRequest) as fallback_exc:
            _raise_dataset_error(
                fallback_exc,
                operation="query",
                fallback_attempted=True,
                failure_reason=f"fallback_dataset_failed fallback_dataset={fallback_dataset} primary_error={exc}",
            )


def fetch_scalar(client: bigquery.Client, sql: str) -> Any:
    try:
        rows = list(client.query(sql, location=resolve_query_location(client)).result())
    except (NotFound, BadRequest) as exc:
        if not _is_dataset_not_found_error(exc):
            raise exc
        fallback_dataset = get_bq_dataset_fallback()
        if not fallback_dataset:
            _raise_dataset_error(exc, operation="query", fallback_attempted=False, failure_reason="fallback_disabled_or_same_as_primary")
        _log_fallback_used("query", exc, fallback_dataset)
        fallback_sql = _rewrite_query_dataset(sql, get_bq_dataset(), fallback_dataset)
        try:
            rows = list(client.query(fallback_sql, location=get_bq_location()).result())
        except (NotFound, BadRequest) as fallback_exc:
            _raise_dataset_error(
                fallback_exc,
                operation="query",
                fallback_attempted=True,
                failure_reason=f"fallback_dataset_failed fallback_dataset={fallback_dataset} primary_error={exc}",
            )
    if not rows:
        return None
    return rows[0][0]
