from __future__ import annotations

import os
import time
from typing import Any, Dict, List, Optional

import requests
from flask import jsonify

from bq import get_client, insert_rows, run_query, table_ref
from time_utils import to_rfc3339, utc_now


def _env(name: str, default: Optional[str] = None) -> str:
    v = os.environ.get(name, default)
    if v is None or str(v).strip() == "":
        raise RuntimeError(f"Missing required env var: {name}")
    return str(v).strip()


def _split_csv(s: str) -> List[str]:
    return [x.strip() for x in s.split(",") if x.strip()]


def _request_with_backoff(
    method: str,
    url: str,
    *,
    headers: Dict[str, str],
    params: Dict[str, Any] | None = None,
    timeout: int = 20,
    max_retries: int = 5,
    max_sleep_s: int = 15,
) -> requests.Response:
    backoff = 2
    for _ in range(max_retries):
        resp = requests.request(method=method, url=url, headers=headers, params=params, timeout=timeout)
        if resp.status_code != 429:
            return resp

        retry_after = resp.headers.get("Retry-After")
        sleep_s = None
        if retry_after and retry_after.isdigit():
            sleep_s = int(retry_after)
        if sleep_s is None:
            sleep_s = backoff

        time.sleep(min(sleep_s, max_sleep_s))
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
        resp = _request_with_backoff("GET", url, headers=headers, params=params, timeout=20)

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


def _compute_bugsnag_kpis() -> None:
    client = get_client()
    bugsnag_table = table_ref("bugsnag_errors")
    kpi_table = table_ref("qa_executive_kpis")

    sql = f"""
DECLARE today DATE DEFAULT CURRENT_DATE("Europe/Madrid");
DECLARE start7 DATE DEFAULT DATE_SUB(today, INTERVAL 6 DAY);

CREATE TEMP TABLE snap AS
SELECT *
FROM `{bugsnag_table}`
WHERE ingest_timestamp = (SELECT MAX(ingest_timestamp) FROM `{bugsnag_table}`);

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

-- EXEC-21: New errors (last 7d) by first_seen
INSERT INTO `{kpi_table}` (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-21",
  "New errors (last 7d)",
  today,
  start7,
  today,
  "{{}}",
  COUNT(DISTINCT error_id) * 1.0,
  NULL,
  NULL,
  "BugSnag"
FROM snap
WHERE DATE(first_seen, "Europe/Madrid") BETWEEN start7 AND today;
"""

    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "bugsnag"})


def hello_http(request):
    if request.method not in ("POST", "GET"):
        return ("Method not allowed", 405)

    base_url = _env("BUGSNAG_BASE_URL")
    token = _env("BUGSNAG_TOKEN")
    project_ids = _split_csv(_env("BUGSNAG_PROJECT_IDS"))

    # Keep the function under the Cloud Run timeout (default 300s).
    max_runtime_s = int(os.environ.get("BUGSNAG_MAX_RUNTIME_S", "250"))
    deadline = time.time() + max(30, min(max_runtime_s, 290))

    ingest_ts = to_rfc3339(utc_now())
    client = get_client()

    total_inserted = 0
    rate_limited_projects: List[str] = []
    deadline_projects: List[str] = []
    failed_projects: List[Dict[str, str]] = []

    for project_id in project_ids:
        if time.time() >= deadline:
            deadline_projects.append(str(project_id))
            continue

        try:
            errors, was_rl, hit_deadline = _list_errors(base_url, project_id, token, deadline_epoch=deadline)
            if was_rl:
                rate_limited_projects.append(project_id)
            if hit_deadline:
                deadline_projects.append(project_id)

            rows: List[Dict[str, Any]] = [_parse_error(e, ingest_ts, project_id) for e in errors]

            for i in range(0, len(rows), 500):
                if time.time() >= deadline:
                    deadline_projects.append(project_id)
                    break
                total_inserted += insert_rows(client, "bugsnag_errors", rows[i : i + 500])

        except Exception as e:
            failed_projects.append({"project_id": str(project_id), "error": str(e)})

    if total_inserted > 0:
        _compute_bugsnag_kpis()

    status = "ok" if not failed_projects else "partial"

    return jsonify(
        {
            "status": status,
            "inserted_rows": total_inserted,
            "rate_limited_projects": rate_limited_projects,
            "deadline_projects": deadline_projects,
            "failed_projects": failed_projects,
        }
    )
