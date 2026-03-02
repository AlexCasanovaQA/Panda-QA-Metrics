from __future__ import annotations

import logging
import os
import re
from typing import Any, Dict, List, Optional

from google.api_core.exceptions import BadRequest, NotFound
from google.cloud import bigquery

LOGGER = logging.getLogger(__name__)


def get_bq_project() -> str:
    """Return the GCP project used for BigQuery operations.

    Cloud Run/Functions typically set GOOGLE_CLOUD_PROJECT, but some environments may use
    GCP_PROJECT / GCLOUD_PROJECT instead.
    """
    for key in ("BQ_PROJECT", "GOOGLE_CLOUD_PROJECT", "GCP_PROJECT", "GCLOUD_PROJECT"):
        v = os.environ.get(key)
        if v and str(v).strip():
            return str(v).strip()
    return ""


def get_bq_dataset() -> str:
    """Return the BigQuery dataset name."""
    return os.environ.get("BQ_DATASET", "qa_metrics_simple").strip()


def get_bq_dataset_fallback() -> Optional[str]:
    """Return optional fallback dataset name.

    Behavior:
    - If BQ_DATASET_FALLBACK is explicitly set to empty => disabled.
    - If not set => auto-use <BQ_DATASET>_mirror.
    - If fallback equals primary => disabled.
    """
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
    """BigQuery location (e.g. EU, US). Defaults to EU for qa_metrics_simple."""
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


def _is_dataset_not_found_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return (
        "dataset" in msg
        and "not found" in msg
        and ("location" in msg or "notfound" in exc.__class__.__name__.lower())
    )


def _raise_with_dataset_alert(exc: Exception) -> None:
    if _is_dataset_not_found_error(exc):
        LOGGER.error(
            "BQ_DATASET_NOT_FOUND_ALERT project=%s dataset=%s location=%s error=%s",
            get_bq_project() or "<unknown>",
            get_bq_dataset() or "<unknown>",
            get_bq_location() or "<unset>",
            exc,
        )
        raise RuntimeError(
            "Data not available right now (dataset missing or region mismatch). "
            "Please verify BQ_PROJECT/BQ_DATASET/BQ_LOCATION or switch to the stable mirror table."
        ) from exc
    raise exc


def _rewrite_query_dataset(sql: str, source_dataset: str, target_dataset: str) -> str:
    """Replace references to source dataset with target dataset in a SQL string."""
    if source_dataset == target_dataset:
        return sql
    rewritten = re.sub(
        rf"(?<=\.){re.escape(source_dataset)}(?=\.)",
        target_dataset,
        sql,
    )
    return rewritten


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


def insert_rows(
    client: bigquery.Client,
    table: str,
    rows: List[Dict[str, Any]],
    *,
    ignore_unknown_values: bool = True,
) -> int:
    """Stream JSON rows into BigQuery.

    ignore_unknown_values=True makes the pipeline resilient if the table schema lags behind
    the code (unknown fields are dropped instead of failing the whole request).
    """
    if not rows:
        return 0

    primary_exc: Optional[Exception] = None
    try:
        errors = client.insert_rows_json(
            table_ref(table),
            rows,
            ignore_unknown_values=ignore_unknown_values,
        )
    except (NotFound, BadRequest) as exc:
        if not _is_dataset_not_found_error(exc):
            _raise_with_dataset_alert(exc)
        primary_exc = exc
        fallback_dataset = get_bq_dataset_fallback()
        if not fallback_dataset:
            _raise_with_dataset_alert(exc)
        _log_fallback_used("insert", exc, fallback_dataset)
        try:
            errors = client.insert_rows_json(
                table_ref(table, dataset=fallback_dataset),
                rows,
                ignore_unknown_values=ignore_unknown_values,
            )
        except (NotFound, BadRequest) as fallback_exc:
            raise RuntimeError(
                "BigQuery insert failed in primary and fallback datasets. "
                f"primary_error={primary_exc}; fallback_error={fallback_exc}"
            ) from fallback_exc

    if errors:
        raise RuntimeError(
            f"BigQuery insert errors: {errors[:3]}{' ...' if len(errors) > 3 else ''}"
        )
    return len(rows)


def run_query(
    client: bigquery.Client,
    sql: str,
    job_labels: Optional[Dict[str, str]] = None,
) -> None:
    job_config = bigquery.QueryJobConfig()
    if job_labels:
        job_config.labels = job_labels
    primary_exc: Optional[Exception] = None
    try:
        job = client.query(sql, job_config=job_config, location=get_bq_location())
        job.result()  # wait
    except (NotFound, BadRequest) as exc:
        if not _is_dataset_not_found_error(exc):
            _raise_with_dataset_alert(exc)
        primary_exc = exc
        fallback_dataset = get_bq_dataset_fallback()
        if not fallback_dataset:
            _raise_with_dataset_alert(exc)
        _log_fallback_used("query", exc, fallback_dataset)
        fallback_sql = _rewrite_query_dataset(sql, get_bq_dataset(), fallback_dataset)
        try:
            job = client.query(fallback_sql, job_config=job_config, location=get_bq_location())
            job.result()  # wait
        except (NotFound, BadRequest) as fallback_exc:
            raise RuntimeError(
                "BigQuery query failed in primary and fallback datasets. "
                f"primary_error={primary_exc}; fallback_error={fallback_exc}"
            ) from fallback_exc


def fetch_scalar(client: bigquery.Client, sql: str) -> Any:
    primary_exc: Optional[Exception] = None
    try:
        rows = list(client.query(sql, location=get_bq_location()).result())
    except (NotFound, BadRequest) as exc:
        if not _is_dataset_not_found_error(exc):
            _raise_with_dataset_alert(exc)
        primary_exc = exc
        fallback_dataset = get_bq_dataset_fallback()
        if not fallback_dataset:
            _raise_with_dataset_alert(exc)
        _log_fallback_used("query", exc, fallback_dataset)
        fallback_sql = _rewrite_query_dataset(sql, get_bq_dataset(), fallback_dataset)
        try:
            rows = list(client.query(fallback_sql, location=get_bq_location()).result())
        except (NotFound, BadRequest) as fallback_exc:
            raise RuntimeError(
                "BigQuery query failed in primary and fallback datasets. "
                f"primary_error={primary_exc}; fallback_error={fallback_exc}"
            ) from fallback_exc
    if not rows:
        return None
    return rows[0][0]
