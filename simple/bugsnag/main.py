from __future__ import annotations

import os
import time
import logging
from typing import Any, Dict, List, Optional

import requests
from flask import jsonify

from bq import get_client, insert_rows, run_query, table_ref

try:
    from bq import validate_bq_env as _validate_bq_env
except ImportError:
    _validate_bq_env = None
from time_utils import to_rfc3339, utc_now


logger = logging.getLogger(__name__)


class ConfigError(ValueError):
    """Raised when required service configuration is missing/invalid."""


def validate_bq_env() -> Dict[str, str]:
    """Backward-compatible BQ config validation when older bq.py is deployed."""
    if _validate_bq_env is not None:
        return _validate_bq_env()

    project = os.environ.get("BQ_PROJECT") or os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get("GCP_PROJECT") or os.environ.get("GCLOUD_PROJECT")
    project = str(project).strip() if project is not None else ""
    dataset = str(os.environ.get("BQ_DATASET", "qa_metrics_simple")).strip()
    location = str(os.environ.get("BQ_LOCATION", "EU")).strip()

    logger.warning("validate_bq_env missing in bq.py; using legacy fallback validation")
    missing = []
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


def _env(name: str, default: Optional[str] = None) -> str:
    v = os.environ.get(name, default)
    if v is None or str(v).strip() == "":
        raise RuntimeError(f"Missing required env var: {name}")
    return str(v).strip()


def _split_csv(s: str) -> List[str]:
    return [x.strip() for x in s.split(",") if x.strip()]


def _validate_bugsnag_config() -> Dict[str, Any]:
    required_groups = {
        "BugSnag base URL": ("BUGSNAG_BASE_URL",),
        "BugSnag token": ("BUGSNAG_TOKEN",),
        "BugSnag project ids": ("BUGSNAG_PROJECT_IDS",),
    }
    missing = []
    for label, names in required_groups.items():
        if not any(os.environ.get(name, "").strip() for name in names):
            missing.append(f"{label}: {' | '.join(names)}")

    if missing:
        raise ConfigError("Missing BugSnag configuration: " + "; ".join(missing))

    return {
        "base_url": _env("BUGSNAG_BASE_URL"),
        "token": _env("BUGSNAG_TOKEN"),
        "project_ids": _split_csv(_env("BUGSNAG_PROJECT_IDS")),
    }


def _request_with_backoff(
    method: str,
    url: str,
    *,
    headers: Dict[str, str],
    params: Dict[str, Any] | None = None,
    timeout: int = 20,
    max_retries: int = 5,
    max_sleep_s: int = 15,
    deadline_epoch: float | None = None,
) -> requests.Response:
    backoff = 2
    for _ in range(max_retries):
        if deadline_epoch is not None:
            remaining_s = int(deadline_epoch - time.time())
            if remaining_s <= 1:
                raise TimeoutError("Deadline reached before BugSnag request")
            timeout = max(1, min(timeout, remaining_s - 1))

        resp = requests.request(method=method, url=url, headers=headers, params=params, timeout=timeout)
        if resp.status_code != 429:
            return resp

        retry_after = resp.headers.get("Retry-After")
        sleep_s = None
        if retry_after and retry_after.isdigit():
            sleep_s = int(retry_after)
        if sleep_s is None:
            sleep_s = backoff

        sleep_budget = min(sleep_s, max_sleep_s)
        if deadline_epoch is not None:
            remaining_s = int(deadline_epoch - time.time())
            if remaining_s <= 1:
                raise TimeoutError("Deadline reached during BugSnag backoff")
            sleep_budget = min(sleep_budget, max(0, remaining_s - 1))

        if sleep_budget > 0:
            time.sleep(sleep_budget)
        backoff = min(backoff * 2, max_sleep_s)

    return resp


def _list_errors(
    base_url: str,
    project_id: str,
    token: str,
    *,
    deadline_epoch: float,
) -> tuple[list[dict[str, Any]], bool, bool]:
    """Return (errors, was_rate_limited, hit_deadline)."""
    base = base_url.rstrip("/")
    url = f"{base}/projects/{project_id}/errors"
    headers = {"Authorization": f"token {token}", "Accept": "application/json"}

    out: List[Dict[str, Any]] = []
    page = 1
    was_rate_limited = False
    hit_deadline = False

    while True:
        if time.time() >= deadline_epoch:
            hit_deadline = True
            break

        params = {"sort": "unsorted", "per_page": 100, "page": page}
        try:
            resp = _request_with_backoff(
                "GET",
                url,
                headers=headers,
                params=params,
                timeout=20,
                deadline_epoch=deadline_epoch,
            )
        except TimeoutError:
            hit_deadline = True
            break

        if resp.status_code == 429:
            was_rate_limited = True
            break

        if resp.status_code >= 400:
            raise RuntimeError(f"BugSnag API request failed for project {project_id}: {resp.status_code} {resp.text}")

        data = resp.json()
        items = data.get("errors") if isinstance(data, dict) else data
        if not items:
            break

        out.extend(items)
        page += 1

        if page > 200:
            break

    return out, was_rate_limited, hit_deadline


def _parse_error(e: Dict[str, Any], ingest_ts: str, project_id: str) -> Dict[str, Any]:
    def _get(*keys: str) -> Any:
        for k in keys:
            if k in e and e[k] is not None:
                return e[k]
        return None

    rs = _get("releaseStages", "release_stages") or []
    release_stages: List[str] = []
    if isinstance(rs, list):
        for x in rs:
            if isinstance(x, str):
                release_stages.append(x)
            elif isinstance(x, dict):
                name = x.get("name") or x.get("value") or x.get("stage")
                if name:
                    release_stages.append(str(name))

    return {
        "ingest_timestamp": ingest_ts,
        "project_id": str(project_id),
        "error_id": str(_get("id")) if _get("id") is not None else None,
        "error_class": _get("errorClass", "error_class"),
        "message": _get("message", "errorMessage", "error_message"),
        "severity": _get("severity"),
        "status": _get("status"),
        "first_seen": _get("firstSeen", "first_seen"),
        "last_seen": _get("lastSeen", "last_seen"),
        "events": _get("events", "eventCount", "event_count"),
        "users": _get("users", "userCount", "user_count"),
        "release_stages": release_stages,
    }


def _empty_project_snapshot(ingest_ts: str, project_id: str) -> Dict[str, Any]:
    """Placeholder row to persist a refresh run with no current errors for a project."""
    return {
        "ingest_timestamp": ingest_ts,
        "project_id": str(project_id),
        "error_id": None,
        "error_class": None,
        "message": None,
        "severity": None,
        "status": None,
        "first_seen": None,
        "last_seen": None,
        "events": None,
        "users": None,
        "release_stages": [],
    }


def _compute_bugsnag_kpis() -> None:
    client = get_client()
    bugsnag_table = table_ref("bugsnag_errors")
    runs_table = table_ref("bugsnag_ingest_runs")
    kpi_table = table_ref("qa_executive_kpis")

    sql = f"""
DECLARE today DATE DEFAULT CURRENT_DATE("UTC");
DECLARE start7 DATE DEFAULT DATE_SUB(today, INTERVAL 6 DAY);
DECLARE latest_run_ts TIMESTAMP DEFAULT (
  SELECT MAX(run_ts) FROM `{runs_table}` WHERE source = "bugsnag"
);

CREATE TEMP TABLE snap AS
SELECT *
FROM `{bugsnag_table}`
WHERE latest_run_ts IS NOT NULL
  AND TIMESTAMP(ingest_timestamp) = latest_run_ts;

-- EXEC-18: Active production errors (overall)
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-18",
  "Active production errors",
  today,
  today,
  today,
  "{{}}",
  COUNT(*) * 1.0,
  NULL,
  NULL,
  "BugSnag"
FROM snap
WHERE LOWER(status) = "open"
  AND "Production" IN UNNEST(IFNULL(release_stages, []));

-- EXEC-18: Breakdown by severity
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-18",
  "Active production errors",
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(severity, "unknown") AS severity)),
  COUNT(*) * 1.0,
  NULL,
  NULL,
  "BugSnag"
FROM snap
WHERE LOWER(status) = "open"
  AND "Production" IN UNNEST(IFNULL(release_stages, []))
GROUP BY severity;

-- EXEC-19: High/Critical active errors (overall, open)
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-19",
  "High/Critical active errors",
  today,
  today,
  today,
  "{{}}",
  COUNT(*) * 1.0,
  NULL,
  NULL,
  "BugSnag"
FROM snap
WHERE LOWER(status) = "open"
  AND LOWER(COALESCE(severity, "")) IN ("critical","error");

-- EXEC-20: Active errors by severity (open)
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-20",
  "Active errors by severity",
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(severity, "unknown") AS severity)),
  COUNT(*) * 1.0,
  NULL,
  NULL,
  "BugSnag"
FROM snap
WHERE LOWER(status) = "open"
GROUP BY severity;

-- EXEC-21: New errors (last 7d, UTC) by first_seen
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-21",
  "New errors (last 7d, UTC)",
  today,
  start7,
  today,
  "{{}}",
  COUNT(DISTINCT error_id) * 1.0,
  NULL,
  NULL,
  "BugSnag"
FROM snap
WHERE DATE(first_seen, "UTC") BETWEEN start7 AND today;
"""

    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "bugsnag"})


def _ensure_bugsnag_run_table() -> None:
    client = get_client()
    runs_table = table_ref("bugsnag_ingest_runs")
    sql = f"""
CREATE TABLE IF NOT EXISTS `{runs_table}` (
  run_ts TIMESTAMP,
  source STRING,
  status STRING,
  inserted_rows INT64,
  rate_limited_projects ARRAY<STRING>,
  deadline_projects ARRAY<STRING>
);
"""
    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "bugsnag"})


def _insert_bugsnag_run_marker(
    client,
    *,
    run_ts: str,
    status: str,
    inserted_rows: int,
    rate_limited_projects: List[str],
    deadline_projects: List[str],
) -> None:
    insert_rows(
        client,
        "bugsnag_ingest_runs",
        [
            {
                "run_ts": run_ts,
                "source": "bugsnag",
                "status": status,
                "inserted_rows": inserted_rows,
                "rate_limited_projects": sorted(set(rate_limited_projects)),
                "deadline_projects": sorted(set(deadline_projects)),
            }
        ],
    )


def hello_http(request):
    if request.method not in ("POST", "GET"):
        return ("Method not allowed", 405)

    current_phase = "config"
    current_project_id: Optional[str] = None
    bq_dataset = (os.environ.get("BQ_DATASET") or "qa_metrics_simple").strip()
    bq_location = (os.environ.get("BQ_LOCATION") or "EU").strip()

    try:
        validate_bq_env()
        config = _validate_bugsnag_config()

        base_url = config["base_url"]
        token = config["token"]
        project_ids = config["project_ids"]

        # Cloud Scheduler HTTP jobs often default to a 3-minute attempt deadline.
        # Keep a safety buffer so the function can serialize and return before
        # Scheduler marks the attempt as DEADLINE_EXCEEDED.
        max_runtime_s = int(os.environ.get("BUGSNAG_MAX_RUNTIME_S", "150"))
        deadline = time.time() + max(30, min(max_runtime_s, 160))

        ingest_ts = to_rfc3339(utc_now())
        current_phase = "bq_setup"
        client = get_client()
        _ensure_bugsnag_run_table()

        total_inserted = 0
        total_source_errors = 0
        rate_limited_projects: List[str] = []
        deadline_projects: List[str] = []
        failed_projects: List[Dict[str, str]] = []

        current_phase = "api_bugsnag"
        for project_id in project_ids:
            current_project_id = str(project_id)
            if time.time() >= deadline:
                deadline_projects.append(str(project_id))
                continue

            try:
                errors, was_rl, hit_deadline = _list_errors(base_url, project_id, token, deadline_epoch=deadline)
                if was_rl:
                    rate_limited_projects.append(project_id)
                if hit_deadline:
                    deadline_projects.append(project_id)

                total_source_errors += len(errors)
                rows: List[Dict[str, Any]] = [_parse_error(e, ingest_ts, project_id) for e in errors]
                if not rows and not was_rl and not hit_deadline:
                    rows = [_empty_project_snapshot(ingest_ts, project_id)]

                current_phase = "bq_write"
                for i in range(0, len(rows), 500):
                    if time.time() >= deadline:
                        deadline_projects.append(project_id)
                        break
                    total_inserted += insert_rows(client, "bugsnag_errors", rows[i : i + 500])
                current_phase = "api_bugsnag"

            except Exception as e:
                failed_projects.append({"project_id": str(project_id), "error": str(e)})

        if not failed_projects:
            status = "ok"
        elif len(failed_projects) == len(project_ids):
            status = "error"
        else:
            status = "partial"

        current_phase = "bq_run_marker"
        _insert_bugsnag_run_marker(
            client,
            run_ts=ingest_ts,
            status=status,
            inserted_rows=total_inserted,
            rate_limited_projects=rate_limited_projects,
            deadline_projects=deadline_projects,
        )

        kpi_computed = False
        kpi_refresh_without_changes = False
        ingest_completed = not failed_projects and not rate_limited_projects and not deadline_projects
        if ingest_completed and time.time() < deadline - 10:
            current_phase = "kpis"
            _compute_bugsnag_kpis()
            kpi_computed = True
            kpi_refresh_without_changes = total_source_errors == 0

        status = "ok" if ingest_completed else "partial"

        return jsonify(
            {
                "status": status,
                "inserted_rows": total_inserted,
                "kpi_computed": kpi_computed,
                "kpi_refresh_without_changes": kpi_refresh_without_changes,
                "source_errors_seen": total_source_errors,
                "rate_limited_projects": rate_limited_projects,
                "deadline_projects": deadline_projects,
                "failed_projects": failed_projects,
            }
        )
    except ConfigError as e:
        logger.warning(
            "bugsnag config error",
            extra={
                "phase": current_phase,
                "project_id": current_project_id,
                "bq_dataset": bq_dataset,
                "bq_location": bq_location,
            },
        )
        return jsonify({"status": "error", "error": str(e)}), 400
    except Exception as e:
        logger.exception(
            "bugsnag ingest failed",
            extra={
                "phase": current_phase,
                "project_id": current_project_id,
                "bq_dataset": bq_dataset,
                "bq_location": bq_location,
            },
        )
        return jsonify({"status": "error", "error": str(e)}), 500
