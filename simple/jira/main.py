"""Jira → BigQuery ingestion + KPI computation (QA Executive).

This Cloud Run/Cloud Function (2nd gen) service:
1) Pulls Bug issues from Jira Cloud using the new JQL Search API: GET /rest/api/3/search/jql
2) Writes a point-in-time snapshot to BigQuery table `jira_issues_snapshot`.
3) Extracts status change events (changelog) and writes to `jira_changelog`.
4) Computes Jira-driven executive KPIs EXEC-01..EXEC-14 into `qa_executive_kpis`.

Required env vars / secrets:
- JIRA_SITE            (e.g. https://yourcompany.atlassian.net)
- JIRA_USER            (email)
- JIRA_API_TOKEN       (API token)
- JIRA_PROJECT_KEYS    CSV, e.g. "PC" or "PC,XYZ"

Optional env vars:
- JIRA_SEVERITY_FIELD  default customfield_10074
- JIRA_POD_FIELD       default customfield_10001
- JIRA_LOOKBACK_DAYS   default 30

BigQuery dataset defaults:
- BQ_PROJECT = GOOGLE_CLOUD_PROJECT
- BQ_DATASET = qa_metrics_simple

Deploy settings:
- Function target (entrypoint): hello_http
"""

from __future__ import annotations

import base64
import logging
import os
from typing import Any, Dict, Iterable, List, Optional, Tuple

import requests
from flask import jsonify

from bq import get_bq_dataset, get_bq_location, get_bq_project, get_client, insert_rows, run_query, table_ref, validate_bq_env
from time_utils import jira_to_rfc3339, to_rfc3339, utc_now


LOGGER = logging.getLogger(__name__)


class JiraAPIError(RuntimeError):
    """Raised when Jira API responds with a non-success status."""

    def __init__(self, status_code: int, response_text: str):
        super().__init__(f"Jira API request failed: {status_code} {response_text}")
        self.status_code = status_code


class ConfigError(ValueError):
    """Raised when required service configuration is missing/invalid."""


# -----------------------------
# Helpers
# -----------------------------

def _env(name: str, default: Optional[str] = None) -> str:
    v = os.environ.get(name, default)
    if v is None or str(v).strip() == "":
        raise KeyError(name)
    return str(v).strip()


def _env_any(*names: str, default: Optional[str] = None) -> str:
    for name in names:
        v = os.environ.get(name)
        if v is not None and str(v).strip() != "":
            return str(v).strip()
    if default is not None and str(default).strip() != "":
        return str(default).strip()
    raise KeyError(" | ".join(names))


def _split_csv(value: str) -> List[str]:
    return [x.strip() for x in value.split(",") if x.strip()]


def _first_non_empty(*names: str) -> Optional[str]:
    for name in names:
        value = os.environ.get(name)
        if value is not None and str(value).strip() != "":
            return str(value).strip()
    return None


def _validate_jira_config() -> Dict[str, str]:
    """Fail fast with a precise configuration error before hitting integrations."""
    required_groups = {
        "JIRA site/base URL": ("JIRA_SITE", "JIRA_BASE_URL"),
        "JIRA user/email": ("JIRA_USER", "JIRA_EMAIL"),
        "JIRA API token": ("JIRA_API_TOKEN",),
        "JIRA project keys": ("JIRA_PROJECT_KEYS", "JIRA_PROJECT_KEYS_CSV", "JIRA_PROJECT_KEY"),
    }

    missing = [f"{label}: {' | '.join(names)}" for label, names in required_groups.items() if _first_non_empty(*names) is None]
    if missing:
        raise ConfigError("Missing Jira configuration: " + "; ".join(missing))

    return {
        "site": _first_non_empty("JIRA_SITE", "JIRA_BASE_URL") or "",
        "user": _first_non_empty("JIRA_USER", "JIRA_EMAIL") or "",
        "api_token": _first_non_empty("JIRA_API_TOKEN") or "",
        "project_keys": _first_non_empty("JIRA_PROJECT_KEYS", "JIRA_PROJECT_KEYS_CSV", "JIRA_PROJECT_KEY") or "",
    }


def _jira_base_url(site: str) -> str:
    site = site.strip().rstrip("/")
    if site.startswith("http://") or site.startswith("https://"):
        return site
    return "https://" + site


def _jira_headers(user: str, api_token: str) -> Dict[str, str]:
    b64 = base64.b64encode(f"{user}:{api_token}".encode("utf-8")).decode("utf-8")
    return {
        "Authorization": f"Basic {b64}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def _pick_field_value(v: Any) -> Optional[str]:
    """Normalise Jira field values (custom fields often return dicts)."""
    if v is None:
        return None
    if isinstance(v, str):
        return v
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, dict):
        for k in ("value", "name", "key"):
            if k in v and v[k] is not None:
                return str(v[k])
    return str(v)


# -----------------------------
# Jira API
# -----------------------------

def _search_issues(
    base_url: str,
    headers: Dict[str, str],
    jql: str,
    fields: List[str],
    max_results: int = 100,
    timeout: int = 60,
) -> Iterable[Dict[str, Any]]:
    """Generator over Jira issues (handles both nextPageToken and startAt pagination)."""

    url = f"{base_url}/rest/api/3/search/jql"

    next_page_token: Optional[str] = None
    start_at: int = 0

    while True:
        params: Dict[str, Any] = {
            "jql": jql,
            "maxResults": max_results,
            "fields": ",".join(fields),
            "expand": "changelog",
            "validateQuery": "none",
        }

        # Prefer the enhanced pagination if available
        if next_page_token:
            params["nextPageToken"] = next_page_token
        else:
            params["startAt"] = start_at

        resp = requests.get(url, headers=headers, params=params, timeout=timeout)
        if not resp.ok:
            raise JiraAPIError(resp.status_code, resp.text)

        data = resp.json() or {}
        issues = data.get("issues", []) or []
        for issue in issues:
            yield issue

        # Enhanced pagination
        if data.get("isLast") is True:
            break
        if data.get("nextPageToken"):
            next_page_token = data.get("nextPageToken")
            continue

        # Legacy pagination fallback
        total = int(data.get("total", 0) or 0)
        start_at = int(data.get("startAt", start_at) or 0) + int(data.get("maxResults", max_results) or max_results)
        if start_at >= total:
            break


# -----------------------------
# Ingestion
# -----------------------------

def _parse_issue_snapshot(
    issue: Dict[str, Any],
    snapshot_ts: str,
    *,
    severity_field: str,
    pod_field: str,
) -> Dict[str, Any]:
    fields = issue.get("fields", {}) or {}

    issue_type = _pick_field_value((fields.get("issuetype") or {}).get("name"))
    status_obj = fields.get("status") or {}
    status = _pick_field_value(status_obj.get("name"))
    status_category = _pick_field_value((status_obj.get("statusCategory") or {}).get("name"))

    fix_versions: List[str] = []
    for fv in (fields.get("fixVersions") or []):
        name = _pick_field_value((fv or {}).get("name"))
        if name:
            fix_versions.append(name)

    assignee = fields.get("assignee") or {}
    reporter = fields.get("reporter") or {}

    return {
        "snapshot_timestamp": snapshot_ts,
        "issue_id": str(issue.get("id")) if issue.get("id") is not None else None,
        "issue_key": issue.get("key"),
        "issue_type": issue_type,
        "summary": fields.get("summary"),
        "status": status,
        "status_category": status_category,
        "priority": _pick_field_value((fields.get("priority") or {}).get("name")),
        "severity": _pick_field_value(fields.get(severity_field)),
        "pod_team": _pick_field_value(fields.get(pod_field)),
        "fix_versions": fix_versions,
        "assignee_email": assignee.get("emailAddress"),
        "reporter_email": reporter.get("emailAddress"),
        "created": jira_to_rfc3339(fields.get("created")),
        "updated": jira_to_rfc3339(fields.get("updated")),
    }


def _parse_changelog(issue: Dict[str, Any]) -> List[Dict[str, Any]]:
    issue_key = issue.get("key")
    issue_id = issue.get("id")
    changelog = issue.get("changelog") or {}
    histories = changelog.get("histories") or []

    out: List[Dict[str, Any]] = []
    for h in histories:
        created = jira_to_rfc3339(h.get("created"))
        author = (h.get("author") or {})
        author_email = author.get("emailAddress")

        for item in (h.get("items") or []):
            # Only status transitions
            if (item.get("field") or "").lower() != "status":
                continue

            out.append(
                {
                    "change_timestamp": created,
                    "issue_id": str(issue_id) if issue_id is not None else None,
                    "issue_key": issue_key,
                    "field": "status",
                    "from_value": item.get("fromString"),
                    "to_value": item.get("toString"),
                    "author_email": author_email,
                }
            )
    return out


def ingest_jira() -> Tuple[int, int]:
    """Fetch issues + status changelog and insert into BigQuery.

    Returns: (snapshot_rows_inserted, changelog_rows_inserted)
    """

    config = _validate_jira_config()
    site = _jira_base_url(config["site"])
    user = config["user"]
    api_token = config["api_token"]

    project_keys = _split_csv(config["project_keys"])
    lookback_days = int(os.environ.get("JIRA_LOOKBACK_DAYS", "30"))

    severity_field = _first_non_empty("JIRA_SEVERITY_FIELD_ID", "JIRA_SEVERITY_FIELD") or "customfield_10074"
    pod_field = os.environ.get("JIRA_POD_FIELD", "customfield_10001").strip() or "customfield_10001"

    # Only Bugs; include all active + anything updated recently to catch fixes.
    projects_jql = ",".join(project_keys)
    jql = (
        f"project in ({projects_jql}) AND issuetype = Bug AND "
        f"(statusCategory != Done OR updated >= -{lookback_days}d) "
        f"ORDER BY updated DESC"
    )

    fields = [
        "summary",
        "issuetype",
        "status",
        "priority",
        "created",
        "updated",
        "fixVersions",
        severity_field,
        pod_field,
        "assignee",
        "reporter",
    ]

    headers = _jira_headers(user, api_token)

    snapshot_ts = to_rfc3339(utc_now())
    client = get_client()

    snap_rows: List[Dict[str, Any]] = []
    chg_rows: List[Dict[str, Any]] = []

    inserted_snap = 0
    inserted_chg = 0

    for issue in _search_issues(site, headers, jql, fields=fields, max_results=100):
        snap_rows.append(_parse_issue_snapshot(issue, snapshot_ts, severity_field=severity_field, pod_field=pod_field))
        chg_rows.extend(_parse_changelog(issue))

        # Flush periodically to reduce memory.
        if len(snap_rows) >= 500:
            inserted_snap += insert_rows(client, "jira_issues_snapshot", snap_rows)
            snap_rows = []
        if len(chg_rows) >= 1000:
            inserted_chg += insert_rows(client, "jira_changelog", chg_rows)
            chg_rows = []

    if snap_rows:
        inserted_snap += insert_rows(client, "jira_issues_snapshot", snap_rows)
    if chg_rows:
        inserted_chg += insert_rows(client, "jira_changelog", chg_rows)

    return inserted_snap, inserted_chg


# -----------------------------
# KPI Computation (EXEC-01..EXEC-14)
# -----------------------------

def _compute_jira_kpis() -> None:
    client = get_client()

    snap_table = table_ref("jira_issues_snapshot")
    chlog_table = table_ref("jira_changelog")
    kpi_table = table_ref("qa_executive_kpis")

    sql = f"""
DECLARE today DATE DEFAULT CURRENT_DATE("UTC");
DECLARE start7 DATE DEFAULT DATE_SUB(today, INTERVAL 6 DAY);
DECLARE start30 DATE DEFAULT DATE_SUB(today, INTERVAL 29 DAY);
DECLARE start180 DATE DEFAULT DATE_SUB(today, INTERVAL 179 DAY);

-- Latest snapshot (one run)
CREATE TEMP TABLE snap AS
SELECT *
FROM `{snap_table}`
WHERE snapshot_timestamp = (SELECT MAX(snapshot_timestamp) FROM `{snap_table}`);

-- Status changelog for the last 30d in UTC (status changes only)
CREATE TEMP TABLE chlog AS
SELECT
  change_timestamp,
  issue_key,
  from_value,
  to_value
FROM `{chlog_table}`
WHERE field = 'status'
  AND DATE(change_timestamp, "UTC") BETWEEN start30 AND today;

-- EXEC-01 Bugs entered today in UTC (overall)
INSERT INTO `{kpi_table}`
  (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-01',
  'Bugs entered today (UTC)',
  today,
  today,
  today,
  '{{}}',
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM snap
WHERE issue_type = 'Bug'
  AND DATE(created, "UTC") = today;

-- EXEC-01 Breakdown by priority
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-01',
  'Bugs entered today (UTC)',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(priority, 'Unknown') AS priority)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM snap
WHERE issue_type = 'Bug'
  AND DATE(created, "UTC") = today
GROUP BY priority;

-- EXEC-01 Breakdown by severity
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-01',
  'Bugs entered today (UTC)',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(severity, 'Unknown') AS severity)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM snap
WHERE issue_type = 'Bug'
  AND DATE(created, "UTC") = today
GROUP BY severity;

-- EXEC-02 Fixes today (Closed, UTC)
CREATE TEMP TABLE fixes_today AS
SELECT DISTINCT issue_key
FROM chlog
WHERE to_value = 'Closed'
  AND DATE(change_timestamp, "UTC") = today;

INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-02',
  'Fixes today (Closed, UTC)',
  today,
  today,
  today,
  '{{}}',
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM fixes_today;

-- EXEC-02 Breakdown by priority
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-02',
  'Fixes today (Closed, UTC)',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(s.priority, 'Unknown') AS priority)),
  COUNT(DISTINCT f.issue_key) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM fixes_today f
LEFT JOIN snap s USING(issue_key)
GROUP BY s.priority;

-- EXEC-03 Active bugs now (statusCategory != Done)
CREATE TEMP TABLE active_now AS
SELECT *
FROM snap
WHERE issue_type = 'Bug'
  AND LOWER(COALESCE(status_category, '')) != 'done';

INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-03',
  'Active bugs now (statusCategory != Done)',
  today,
  today,
  today,
  '{{}}',
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM active_now;

-- EXEC-03 Active by POD
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-03',
  'Active bugs now (statusCategory != Done)',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(pod_team, 'Unknown') AS pod_team)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM active_now
GROUP BY pod_team;

-- EXEC-03 Active by priority
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-03',
  'Active bugs now (statusCategory != Done)',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(priority, 'Unknown') AS priority)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM active_now
GROUP BY priority;

-- EXEC-04 Awaiting QA verification (Resolved)
CREATE TEMP TABLE awaiting_qa AS
SELECT *
FROM snap
WHERE issue_type = 'Bug'
  AND status = 'Resolved';

INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-04',
  'Awaiting QA verification (Resolved)',
  today,
  today,
  today,
  '{{}}',
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM awaiting_qa;

-- EXEC-05 Bugs entered (last 7d, UTC) by Severity
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-05',
  'Bugs entered (last 7d, UTC) by Severity',
  today,
  start7,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(severity, 'Unknown') AS severity)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM snap
WHERE issue_type = 'Bug'
  AND DATE(created, "UTC") BETWEEN start7 AND today
GROUP BY severity;

-- EXEC-06 Bugs entered (last 30d, UTC) by Severity
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-06',
  'Bugs entered (last 30d, UTC) by Severity',
  today,
  start30,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(severity, 'Unknown') AS severity)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM snap
WHERE issue_type = 'Bug'
  AND DATE(created, "UTC") BETWEEN start30 AND today
GROUP BY severity;

-- EXEC-07 Bugs fixed (last 7d, UTC) by Priority
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-07',
  'Bugs fixed (last 7d, UTC) by Priority',
  today,
  start7,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(s.priority, 'Unknown') AS priority)),
  COUNT(DISTINCT c.issue_key) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM chlog c
LEFT JOIN snap s USING(issue_key)
WHERE c.to_value = 'Closed'
  AND DATE(c.change_timestamp, "UTC") BETWEEN start7 AND today
GROUP BY s.priority;

-- EXEC-08 Bugs entered by day (last 7d, UTC) — Priority
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-08',
  'Bugs entered by day (last 7d, UTC) — Priority',
  DATE(created, "UTC") AS metric_date,
  start7,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(priority, 'Unknown') AS priority)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM snap
WHERE issue_type = 'Bug'
  AND DATE(created, "UTC") BETWEEN start7 AND today
GROUP BY metric_date, priority;

-- EXEC-09 Active bugs by POD
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-09',
  'Active bugs by POD',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(pod_team, 'Unknown') AS pod_team)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM active_now
GROUP BY pod_team;

-- EXEC-10 Active bugs by status
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-10',
  'Active bugs by status',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(COALESCE(status, 'Unknown') AS status)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM active_now
GROUP BY status;

-- EXEC-11 Active bug count over time (last 180d)
CREATE TEMP TABLE daily_latest AS
SELECT
  DATE(snapshot_timestamp, "UTC") AS d,
  MAX(snapshot_timestamp) AS ts
FROM `{snap_table}`
WHERE DATE(snapshot_timestamp, "UTC") BETWEEN start180 AND today
GROUP BY d;

INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-11',
  'Active bug count over time',
  dl.d AS metric_date,
  start180,
  today,
  '{{}}',
  COUNTIF(s.issue_type = 'Bug' AND LOWER(COALESCE(s.status_category, '')) != 'done') * 1.0,
  NULL,
  NULL,
  'Jira'
FROM daily_latest dl
JOIN `{snap_table}` s
  ON s.snapshot_timestamp = dl.ts
GROUP BY metric_date;

-- EXEC-12 Reopened over time (30d, UTC)
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-12',
  'Reopened over time (30d, UTC)',
  DATE(change_timestamp, "UTC") AS metric_date,
  start30,
  today,
  '{{}}',
  COUNT(DISTINCT issue_key) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM chlog
WHERE to_value = 'Reopened'
GROUP BY metric_date;

-- EXEC-13 Fix fail rate over time (30d, UTC)
CREATE TEMP TABLE closed_by_day AS
SELECT
  DATE(change_timestamp, "UTC") AS d,
  COUNT(DISTINCT issue_key) AS closed_count
FROM chlog
WHERE to_value IN ('Closed', 'Resolved', 'Verified')
GROUP BY d;

CREATE TEMP TABLE reopened_by_day AS
SELECT
  DATE(change_timestamp, "UTC") AS d,
  COUNT(DISTINCT issue_key) AS reopened_count
FROM chlog
WHERE from_value IN ('Closed', 'Resolved', 'Verified')
  AND to_value = 'Reopened'
GROUP BY d;

INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-13',
  'Fix fail rate over time (30d, UTC)',
  d,
  start30,
  today,
  '{{}}',
  SAFE_DIVIDE(COALESCE(r.reopened_count, 0), NULLIF(COALESCE(c.closed_count, 0), 0)) * 1.0,
  COALESCE(r.reopened_count, 0),
  COALESCE(c.closed_count, 0),
  'Jira'
FROM UNNEST(GENERATE_DATE_ARRAY(start30, today)) AS d
LEFT JOIN reopened_by_day r
  ON r.d = d
LEFT JOIN closed_by_day c
  ON c.d = d;

-- EXEC-14 Active bugs by milestone (fixVersion)
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-14',
  'Active bugs by milestone (fixVersion)',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(fixv AS fixVersion)),
  COUNT(1) * 1.0,
  NULL,
  NULL,
  'Jira'
FROM active_now,
UNNEST(
  CASE
    WHEN fix_versions IS NULL OR ARRAY_LENGTH(fix_versions) = 0 THEN ['None']
    ELSE fix_versions
  END
) AS fixv
GROUP BY fixv;
"""

    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "jira"})


# -----------------------------
# HTTP entrypoint
# -----------------------------

def hello_http(request):
    validate_bq_env()

    LOGGER.info(
        "hello_http_start",
        extra={
            "json_fields": {
                "bq_project": get_bq_project() or "<unset>",
                "bq_dataset": get_bq_dataset() or "<unset>",
                "bq_location": get_bq_location() or "<unset>",
            }
        },
    )

    try:
        inserted_snap, inserted_chg = ingest_jira()
        _compute_jira_kpis()
        return jsonify(
            {
                "status": "ok",
                "inserted_snapshot_rows": inserted_snap,
                "inserted_changelog_rows": inserted_chg,
            }
        )
    except ConfigError as e:
        return jsonify({"status": "error", "error": str(e)}), 400
    except KeyError as e:
        return jsonify({"status": "error", "error": f"Missing required env var: {e}"}), 400
    except ValueError as e:
        return jsonify({"status": "error", "error": str(e)}), 400
    except JiraAPIError as e:
        # Jira 4xx means our request/config is invalid; treat as client/config error.
        # Jira 5xx is an upstream outage, so expose as bad gateway.
        status_code = 400 if 400 <= e.status_code < 500 else 502
        return jsonify({"status": "error", "error": str(e)}), status_code
    except RuntimeError as e:
        if "Data not available right now" in str(e):
            return (
                jsonify(
                    {
                        "status": "error",
                        "error": (
                            "Configuration issue detected for BigQuery. "
                            "Please verify BQ_PROJECT, BQ_DATASET, and BQ_LOCATION."
                        ),
                        "details": str(e),
                    }
                ),
                503,
            )
        return jsonify({"status": "error", "error": str(e)}), 500
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500
