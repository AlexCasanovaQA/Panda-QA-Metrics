from __future__ import annotations

import os
from typing import Any, Dict, Iterable, List, Optional

from google.cloud import bigquery


def get_bq_project() -> str:
    # Cloud Run sets GOOGLE_CLOUD_PROJECT automatically.
    return os.environ.get("BQ_PROJECT", os.environ.get("GOOGLE_CLOUD_PROJECT", "")).strip()


def get_bq_dataset() -> str:
    return os.environ.get("BQ_DATASET", "qa_metrics_simple").strip()


def table_ref(table: str) -> str:
    project = get_bq_project()
    dataset = get_bq_dataset()
    if not project:
        raise RuntimeError("Missing GOOGLE_CLOUD_PROJECT/BQ_PROJECT env var.")
    return f"{project}.{dataset}.{table}"


def get_client() -> bigquery.Client:
    return bigquery.Client(project=get_bq_project() or None)


def insert_rows(client: bigquery.Client, table: str, rows: List[Dict[str, Any]]) -> int:
    if not rows:
        return 0
    errors = client.insert_rows_json(table_ref(table), rows)
    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors[:3]}{' ...' if len(errors) > 3 else ''}")
    return len(rows)


def run_query(client: bigquery.Client, sql: str, job_labels: Optional[Dict[str, str]] = None) -> None:
    job_config = bigquery.QueryJobConfig()
    if job_labels:
        job_config.labels = job_labels
    job = client.query(sql, job_config=job_config)
    job.result()  # wait


def fetch_scalar(client: bigquery.Client, sql: str) -> Any:
    rows = list(client.query(sql).result())
    if not rows:
        return None
    return rows[0][0]
