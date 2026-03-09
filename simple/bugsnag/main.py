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
    """Compute BugSnag KPIs using the latest ingested snapshot (best effort)."""
    client = get_client()
    bugsnag_table = table_ref("bugsnag_errors")
    kpi_table = table_ref("qa_executive_kpis")

    sql = f"""
DECLARE today DATE DEFAULT CURRENT_DATE("UTC");
DECLARE ingest_lookback_days INT64 DEFAULT 90;
DECLARE start90 DATE DEFAULT DATE_SUB(today, INTERVAL 89 DAY);
DECLARE ingest_start DATE DEFAULT start90;
DECLARE latest_run_ts TIMESTAMP DEFAULT (
  SELECT MAX(TIMESTAMP(ingest_timestamp)) FROM `{bugsnag_table}`
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
  -- Avoid exact match because release stage casing can vary across projects/sources.
  AND EXISTS (
    SELECT 1
    FROM UNNEST(IFNULL(release_stages, [])) AS stage
    WHERE LOWER(stage) IN ("production", "prod")
  );

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
  -- Avoid exact match because release stage casing can vary across projects/sources.
  AND EXISTS (
    SELECT 1
    FROM UNNEST(IFNULL(release_stages, [])) AS stage
    WHERE LOWER(stage) IN ("production", "prod")
  )
GROUP BY severity;

-- Ensure Looker always has an EXEC-18 row even when there are no active production errors.
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-18",
  "Active production errors",
  today,
  today,
  today,
  "{{}}",
  0.0,
  NULL,
  NULL,
  "BugSnag"
WHERE NOT EXISTS (
  SELECT 1
  FROM snap
  WHERE LOWER(status) = "open"
    AND EXISTS (
      SELECT 1
      FROM UNNEST(IFNULL(release_stages, [])) AS stage
      WHERE LOWER(stage) IN ("production", "prod")
    )
);

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

-- Ensure Looker always has an EXEC-19 row even when there are no high/critical active errors.
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-19",
  "High/Critical active errors",
  today,
  today,
  today,
  "{{}}",
  0.0,
  NULL,
  NULL,
  "BugSnag"
WHERE NOT EXISTS (
  SELECT 1
  FROM snap
  WHERE LOWER(status) = "open"
    AND LOWER(COALESCE(severity, "")) IN ("critical","error")
);

-- EXEC-20: Active errors by severity (open)
CREATE TEMP TABLE exec20_by_severity AS
SELECT
  COALESCE(severity, "unknown") AS severity,
  COUNT(*) * 1.0 AS value
FROM snap
WHERE LOWER(status) = "open"
GROUP BY severity;

INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-20",
  "Active errors by severity",
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(severity AS severity)),
  value,
  NULL,
  NULL,
  "BugSnag"
FROM exec20_by_severity;

-- Ensure Looker always has one row to render when there are no active errors.
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-20",
  "Active errors by severity",
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT("unknown" AS severity)),
  0.0,
  NULL,
  NULL,
  "BugSnag"
WHERE NOT EXISTS (SELECT 1 FROM exec20_by_severity);

-- EXEC-21: New errors detected in 90d (UTC), deduplicated across recent ingests.
-- Uses a lookback ingest window to avoid depending only on the latest snapshot.
CREATE TEMP TABLE exec21_recent_errors AS
SELECT
  error_id,
  SAFE.TIMESTAMP(first_seen) AS first_seen_ts
FROM `{bugsnag_table}`
WHERE DATE(TIMESTAMP(ingest_timestamp), "UTC") BETWEEN ingest_start AND today
  AND error_id IS NOT NULL;

CREATE TEMP TABLE exec21_dedup AS
SELECT
  error_id,
  MIN(first_seen_ts) AS first_seen_ts
FROM exec21_recent_errors
WHERE first_seen_ts IS NOT NULL
GROUP BY error_id;

INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-21",
  "New errors detected (last 90d, UTC)",
  today,
  start90,
  today,
  "{{}}",
  COUNT(*) * 1.0,
  NULL,
  NULL,
  "BugSnag"
FROM exec21_dedup
WHERE DATE(first_seen_ts, "UTC") BETWEEN start90 AND today;
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
  api_ingest_status STRING,
  kpi_refresh_status STRING,
  kpi_skipped_due_to_deadline BOOL,
  kpi_missing_metric_ids ARRAY<STRING>,
  inserted_rows INT64,
  rate_limited_projects ARRAY<STRING>,
  deadline_projects ARRAY<STRING>
);

ALTER TABLE `{runs_table}` ADD COLUMN IF NOT EXISTS api_ingest_status STRING;
ALTER TABLE `{runs_table}` ADD COLUMN IF NOT EXISTS kpi_refresh_status STRING;
ALTER TABLE `{runs_table}` ADD COLUMN IF NOT EXISTS kpi_skipped_due_to_deadline BOOL;
ALTER TABLE `{runs_table}` ADD COLUMN IF NOT EXISTS kpi_missing_metric_ids ARRAY<STRING>;
"""
    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "bugsnag"})


def _insert_bugsnag_run_marker(
    client,
    *,
    run_ts: str,
    status: str,
    api_ingest_status: str,
    kpi_refresh_status: str,
    kpi_skipped_due_to_deadline: bool,
    kpi_missing_metric_ids: List[str],
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
                "api_ingest_status": api_ingest_status,
                "kpi_refresh_status": kpi_refresh_status,
                "kpi_skipped_due_to_deadline": kpi_skipped_due_to_deadline,
                "kpi_missing_metric_ids": sorted(set(kpi_missing_metric_ids)),
                "inserted_rows": inserted_rows,
                "rate_limited_projects": sorted(set(rate_limited_projects)),
                "deadline_projects": sorted(set(deadline_projects)),
            }
        ],
    )


def _verify_bugsnag_daily_kpis(client) -> List[str]:
    """Return missing EXEC metric IDs that should exist for BugSnag today."""
    kpi_table = table_ref("qa_executive_kpis")
    sql = f"""
WITH expected AS (
  SELECT metric_id
  FROM UNNEST(["EXEC-18", "EXEC-19", "EXEC-20", "EXEC-21"]) AS metric_id
),
present AS (
  SELECT DISTINCT metric_id
  FROM `{kpi_table}`
  WHERE source = "BugSnag"
    AND metric_date = CURRENT_DATE("UTC")
)
SELECT e.metric_id
FROM expected e
LEFT JOIN present p USING(metric_id)
WHERE p.metric_id IS NULL
ORDER BY e.metric_id
"""
    rows = list(run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "bugsnag"}).result())
    return [str(r["metric_id"]) for r in rows]


def hello_http(request):
    if request.method not in ("POST", "GET"):
        return ("Method not allowed", 405)

    source = "bugsnag/main.py"
    service = (os.environ.get("K_SERVICE") or "unknown").strip() or "unknown"
    current_phase = "config"
    current_project_id: Optional[str] = None
    bq_dataset = (os.environ.get("BQ_DATASET") or "qa_metrics_simple").strip()
    bq_location = (os.environ.get("BQ_LOCATION") or "EU").strip()
    logger.info(
        "bugsnag_ingest_start",
        extra={
            "source": source,
            "service": service,
            "method": request.method,
            "phase": current_phase,
            "bq_dataset": bq_dataset,
            "bq_location": bq_location,
        },
    )

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
        # Reserve time for KPI refresh so EXEC-18/19/20/21 stay fresh even if API ingest is partial.
        kpi_reserve_s = int(os.environ.get("BUGSNAG_KPI_RESERVE_S", "25"))
        kpi_reserve_s = max(10, min(kpi_reserve_s, 60))
        ingest_deadline = deadline - kpi_reserve_s

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
            if time.time() >= ingest_deadline:
                deadline_projects.append(str(project_id))
                continue

            try:
                errors, was_rl, hit_deadline = _list_errors(base_url, project_id, token, deadline_epoch=ingest_deadline)
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
                    if time.time() >= ingest_deadline:
                        deadline_projects.append(project_id)
                        break
                    total_inserted += insert_rows(client, "bugsnag_errors", rows[i : i + 500])
                current_phase = "api_bugsnag"

            except Exception as e:
                failed_projects.append({"project_id": str(project_id), "error": str(e)})

        if not failed_projects and not rate_limited_projects and not deadline_projects:
            api_ingest_status = "ok"
        elif len(failed_projects) == len(project_ids):
            api_ingest_status = "error"
        else:
            api_ingest_status = "partial"

        kpi_computed = False
        kpi_refresh_without_changes = False
        # KPI policy: best effort. Always attempt KPI refresh (time permitting),
        # even when the current API ingest run is partial/failed.
        #
        # Why: dashboard filter suggestions for qa_executive_kpis.metric_id depend on
        # rows present in qa_executive_kpis_latest. If a run fails before KPI refresh,
        # EXEC-18/19/20 can disappear from suggestions for current windows.
        #
        # _compute_bugsnag_kpis() is resilient: it reads latest available snapshot from
        # bugsnag_errors and inserts fallback 0-rows for EXEC-18/19/20 when needed.
        ingest_completed = not failed_projects and not rate_limited_projects and not deadline_projects
        has_usable_subset = total_inserted > 0
        kpi_partial_coverage = has_usable_subset and not ingest_completed
        kpi_skipped_due_to_deadline = False
        if time.time() < deadline - 5:
            current_phase = "kpis"
            _compute_bugsnag_kpis()
            kpi_computed = True
            kpi_refresh_without_changes = total_source_errors == 0
        else:
            kpi_skipped_due_to_deadline = True
            logger.warning(
                "bugsnag_kpi_refresh_skipped",
                extra={
                    "source": source,
                    "service": service,
                    "phase": current_phase,
                    "kpi_skipped_due_to_deadline": True,
                    "seconds_until_deadline": max(0, int(deadline - time.time())),
                },
            )

        kpi_missing_metric_ids: List[str] = []
        if kpi_computed:
            kpi_missing_metric_ids = _verify_bugsnag_daily_kpis(client)

        if kpi_computed and not kpi_missing_metric_ids:
            kpi_refresh_status = "ok"
        elif kpi_computed:
            kpi_refresh_status = "partial"
        elif kpi_skipped_due_to_deadline:
            kpi_refresh_status = "skipped_deadline"
        else:
            kpi_refresh_status = "error"

        if api_ingest_status == "ok" and kpi_refresh_status == "ok":
            run_status = "ok"
        elif api_ingest_status == "error" and kpi_refresh_status in ("error", "skipped_deadline"):
            run_status = "error"
        else:
            run_status = "partial"

        current_phase = "bq_run_marker"
        _insert_bugsnag_run_marker(
            client,
            run_ts=ingest_ts,
            status=run_status,
            api_ingest_status=api_ingest_status,
            kpi_refresh_status=kpi_refresh_status,
            kpi_skipped_due_to_deadline=kpi_skipped_due_to_deadline,
            kpi_missing_metric_ids=kpi_missing_metric_ids,
            inserted_rows=total_inserted,
            rate_limited_projects=rate_limited_projects,
            deadline_projects=deadline_projects,
        )

        logger.info(
            "bugsnag_ingest_success",
            extra={
                "source": source,
                "service": service,
                "phase": current_phase,
                "status": run_status,
                "api_ingest_status": api_ingest_status,
                "kpi_refresh_status": kpi_refresh_status,
                "inserted_rows": total_inserted,
                "source_errors_seen": total_source_errors,
                "failed_projects_count": len(failed_projects),
                "kpi_missing_metric_ids": kpi_missing_metric_ids,
            },
        )

        return jsonify(
            {
                "status": run_status,
                "api_ingest_status": api_ingest_status,
                "kpi_refresh_status": kpi_refresh_status,
                "inserted_rows": total_inserted,
                "kpi_computed": kpi_computed,
                "kpi_partial_coverage": kpi_partial_coverage,
                "kpi_refresh_without_changes": kpi_refresh_without_changes,
                "kpi_skipped_due_to_deadline": kpi_skipped_due_to_deadline,
                "kpi_missing_metric_ids": kpi_missing_metric_ids,
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
                "source": source,
                "service": service,
                "phase": current_phase,
                "project_id": current_project_id,
                "bq_dataset": bq_dataset,
                "bq_location": bq_location,
                "error": str(e),
            },
        )
        return jsonify({"status": "error", "error": str(e)}), 400
    except Exception as e:
        logger.exception(
            "bugsnag ingest failed",
            extra={
                "source": source,
                "service": service,
                "phase": current_phase,
                "project_id": current_project_id,
                "bq_dataset": bq_dataset,
                "bq_location": bq_location,
                "error": str(e),
            },
        )
        return jsonify({"status": "error", "error": str(e)}), 500
