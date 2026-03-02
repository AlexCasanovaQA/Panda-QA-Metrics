from __future__ import annotations

import logging
import os
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
    return (os.environ.get("BQ_DATASET") or "").strip()


def get_bq_location() -> Optional[str]:
    """BigQuery location (e.g. EU, US)."""
    v = os.environ.get("BQ_LOCATION")
    v = str(v).strip() if v is not None else ""
    return v or None


def validate_bq_env() -> Dict[str, str]:
    """Log effective BQ env vars and fail fast when required vars are missing."""
    project = get_bq_project()
    dataset = get_bq_dataset()
    location = get_bq_location() or ""

    LOGGER.info(
        "BQ_STARTUP_CONFIG project=%s dataset=%s location=%s",
        project or "<unset>",
        dataset or "<unset>",
        location or "<unset>",
    )

    missing: List[str] = []
    if not project:
        missing.append("BQ_PROJECT (or GOOGLE_CLOUD_PROJECT/GCP_PROJECT/GCLOUD_PROJECT)")
    if not dataset:
        missing.append("BQ_DATASET")
    if not location:
        missing.append("BQ_LOCATION")
    if missing:
        raise RuntimeError(
            "Missing required BigQuery configuration: "
            + ", ".join(missing)
            + ". Set all of BQ_PROJECT, BQ_DATASET and BQ_LOCATION in Cloud Run env vars."
        )

    return {"project": project, "dataset": dataset, "location": location}


def table_ref(table: str) -> str:
    project = get_bq_project()
    dataset = get_bq_dataset()
    if not project:
        raise RuntimeError("Missing project env var (BQ_PROJECT/GOOGLE_CLOUD_PROJECT/GCP_PROJECT/GCLOUD_PROJECT).")
    return f"{project}.{dataset}.{table}"


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

    try:
        errors = client.insert_rows_json(
            table_ref(table),
            rows,
            ignore_unknown_values=ignore_unknown_values,
        )
    except (NotFound, BadRequest) as exc:
        _raise_with_dataset_alert(exc)

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
    try:
        job = client.query(sql, job_config=job_config, location=get_bq_location())
        job.result()  # wait
    except (NotFound, BadRequest) as exc:
        _raise_with_dataset_alert(exc)


def fetch_scalar(client: bigquery.Client, sql: str) -> Any:
    rows = fetch_rows(client, sql)
    if not rows:
        return None
    return rows[0][0]


def fetch_rows(client: bigquery.Client, sql: str) -> List[Any]:
    try:
        return list(client.query(sql, location=get_bq_location()).result())
    except (NotFound, BadRequest) as exc:
        _raise_with_dataset_alert(exc)
