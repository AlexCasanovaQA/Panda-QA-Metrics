from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from google.cloud import bigquery


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


def get_bq_location() -> Optional[str]:
    """BigQuery location (e.g. EU, US). Defaults to EU for qa_metrics_simple."""
    v = os.environ.get("BQ_LOCATION", "EU")
    v = str(v).strip() if v is not None else ""
    return v or None


def table_ref(table: str) -> str:
    project = get_bq_project()
    dataset = get_bq_dataset()
    if not project:
        raise RuntimeError(
            "Missing project env var (BQ_PROJECT/GOOGLE_CLOUD_PROJECT/GCP_PROJECT/GCLOUD_PROJECT)."
        )
    return f"{project}.{dataset}.{table}"


def get_client() -> bigquery.Client:
    project = get_bq_project() or None
    return bigquery.Client(project=project)


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

    errors = client.insert_rows_json(
        table_ref(table),
        rows,
        ignore_unknown_values=ignore_unknown_values,
    )
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
    """Run a (possibly multi-statement) Standard SQL query/script."""
    job_config = bigquery.QueryJobConfig()
    job_config.use_legacy_sql = False
    if job_labels:
        job_config.labels = job_labels

    job = client.query(sql, job_config=job_config, location=get_bq_location())
    job.result()  # wait


def fetch_scalar(client: bigquery.Client, sql: str) -> Any:
    job_config = bigquery.QueryJobConfig()
    job_config.use_legacy_sql = False
    rows = list(client.query(sql, job_config=job_config, location=get_bq_location()).result())
    if not rows:
        return None
    return rows[0][0]
