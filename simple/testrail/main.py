from __future__ import annotations

import os
import time
from typing import Any, Dict, List, Optional, Tuple

import requests
from flask import jsonify

from bq import get_client, insert_rows, run_query, fetch_scalar, table_ref
from time_utils import unix_to_utc_ts, utc_now


STATUS_ID_TO_NAME = {
    1: "Passed",
    2: "Blocked",
    3: "Untested",
    4: "Retest",
    5: "Failed",
}

EXECUTED_STATUS_IDS = (1, 2, 4, 5)


class ConfigError(ValueError):
    """Raised when required service configuration is missing/invalid."""


def _env_any(*names: str, default: Optional[str] = None) -> str:
    """Return the first non-empty env var from *names, with optional default."""
    for name in names:
        value = os.environ.get(name)
        if value is not None and str(value).strip() != "":
            return str(value).strip()

    if default is not None and str(default).strip() != "":
        return str(default).strip()

    raise RuntimeError(f"Missing required env var: {'/'.join(names)}")


def _split_csv(s: str) -> List[str]:
    return [x.strip() for x in s.split(",") if x.strip()]


def _validate_testrail_config() -> Dict[str, str]:
    required_groups = {
        "TestRail base URL": ("TESTRAIL_BASE_URL", "TESTRAIL_URL"),
        "TestRail user/email": ("TESTRAIL_EMAIL", "TESTRAIL_USER", "TESTRAIL_USERNAME"),
        "TestRail API key": ("TESTRAIL_API_KEY", "TESTRAIL_TOKEN", "TESTRAIL_API_TOKEN"),
        "TestRail project ids": ("TESTRAIL_PROJECT_IDS", "TESTRAIL_PROJECTS", "TESTRAIL_PROJECT_ID", "TESTRAIL_PROJECT"),
    }

    missing = []
    for label, names in required_groups.items():
        if not any(os.environ.get(name, "").strip() for name in names):
            missing.append(f"{label}: {' | '.join(names)}")

    if missing:
        raise ConfigError("Missing TestRail configuration: " + "; ".join(missing))

    return {
        "base_url": _env_any("TESTRAIL_BASE_URL", "TESTRAIL_URL"),
        "email": _env_any("TESTRAIL_EMAIL", "TESTRAIL_USER", "TESTRAIL_USERNAME"),
        "api_key": _env_any("TESTRAIL_API_KEY", "TESTRAIL_TOKEN", "TESTRAIL_API_TOKEN"),
    }


def _get_project_ids() -> List[int]:
    """Accept common project-id env names in both CSV and single-id forms."""
    ids_csv = _env_any("TESTRAIL_PROJECT_IDS", "TESTRAIL_PROJECTS", default="")
    legacy_id = _env_any("TESTRAIL_PROJECT_ID", "TESTRAIL_PROJECT", default="")

    if ids_csv:
        return [int(x) for x in _split_csv(ids_csv)]

    if legacy_id:
        return [int(legacy_id)]

    raise RuntimeError(
        "Missing required env var: TESTRAIL_PROJECT_IDS/TESTRAIL_PROJECTS/TESTRAIL_PROJECT_ID/TESTRAIL_PROJECT"
    )


def _api_base(base_url: str) -> str:
    b = base_url.rstrip("/")
    if "index.php?/api/v2" in b:
        return b
    return f"{b}/index.php?/api/v2"


class TestRailClient:
    def __init__(self, base_url: str, user: str, api_key: str) -> None:
        self.base_url = _api_base(base_url)
        self.auth = (user, api_key)

    def get_json(self, path: str) -> Any:
        url = f"{self.base_url}/{path.lstrip('/')}"
        resp = requests.get(url, auth=self.auth, timeout=60)
        if not resp.ok:
            raise RuntimeError(f"TestRail API request to {path} failed: {resp.status_code} {resp.text}")
        return resp.json()

    def get_suites(self, project_id: int) -> Dict[int, str]:
        data = self.get_json(f"get_suites/{project_id}")
        suites = data.get("suites", []) if isinstance(data, dict) else data
        out: Dict[int, str] = {}
        for s in suites or []:
            sid = s.get("id")
            name = s.get("name")
            if sid is not None and name:
                out[int(sid)] = str(name)
        return out

    def get_runs(self, project_id: int, created_after: int) -> List[Dict[str, Any]]:
        # get_runs supports created_after, but not pagination in the same way; limit to recent window.
        data = self.get_json(f"get_runs/{project_id}&created_after={created_after}")
        runs = data.get("runs", []) if isinstance(data, dict) else data
        return list(runs or [])

    def get_results_for_run(self, run_id: int, created_after: int) -> List[Dict[str, Any]]:
        out: List[Dict[str, Any]] = []
        limit = 250
        offset = 0
        while True:
            data = self.get_json(
                f"get_results_for_run/{run_id}&created_after={created_after}&limit={limit}&offset={offset}"
            )
            results = data.get("results") if isinstance(data, dict) else data
            if not results:
                break
            out.extend(results)
            if len(results) < limit:
                break
            offset += limit
        return out


def _get_state_key(project_id: int) -> str:
    return f"last_result_created_on_{project_id}"


def _get_last_created_on(client, project_id: int, default_ts: int) -> int:
    """Read cursor from ingestion_state (current schema):

    ingestion_state(source STRING, last_run TIMESTAMP, state_key STRING)
    """
    state_table = table_ref("ingestion_state")
    sql = f"""
      SELECT UNIX_SECONDS(last_run)
      FROM `{state_table}`
      WHERE source = "testrail" AND state_key = "{_get_state_key(project_id)}"
      ORDER BY last_run DESC
      LIMIT 1
    """
    v = fetch_scalar(client, sql)
    try:
        return int(v) if v is not None else default_ts
    except Exception:
        return default_ts


def _set_last_created_on(client, project_id: int, ts: int) -> None:
    insert_rows(
        client,
        "ingestion_state",
        [
            {
                "source": "testrail",
                "state_key": _get_state_key(project_id),
                "last_run": unix_to_utc_ts(ts),
            }
        ],
    )


def _parse_result(
    project_id: int,
    run: Dict[str, Any],
    suite_name: Optional[str],
    ingest_ts: str,
    r: Dict[str, Any],
) -> Dict[str, Any]:
    rid = r.get("id")
    status_id = r.get("status_id")
    created_on = r.get("created_on")

    return {
        "ingest_timestamp": ingest_ts,
        "result_id": int(rid) if rid is not None else None,
        "project_id": project_id,
        "run_id": int(run.get("id")) if run.get("id") is not None else None,
        "run_name": run.get("name"),
        "suite_id": int(run.get("suite_id")) if run.get("suite_id") is not None else None,
        "suite_name": suite_name,
        "test_id": int(r.get("test_id")) if r.get("test_id") is not None else None,
        "case_id": int(r.get("case_id")) if r.get("case_id") is not None else None,
        "status_id": int(status_id) if status_id is not None else None,
        "status": STATUS_ID_TO_NAME.get(int(status_id)) if status_id is not None else None,
        "created_on": unix_to_utc_ts(created_on),
        "assignedto_id": int(r.get("assignedto_id")) if r.get("assignedto_id") is not None else None,
        "comment": r.get("comment"),
    }


def _ensure_testrail_schema() -> None:
    """Make the service resilient if the table was created without created_on."""
    project = (os.environ.get("BQ_PROJECT") or os.environ.get("GOOGLE_CLOUD_PROJECT") or "").strip()
    dataset = (os.environ.get("BQ_DATASET") or "qa_metrics_simple").strip()
    if not project:
        # If project is missing we can't fix schema here.
        return

    client = get_client()
    sql = f"""
DECLARE tbl_exists BOOL;
DECLARE col_exists BOOL;

SET tbl_exists = (
  SELECT COUNT(1) > 0
  FROM `{project}.{dataset}.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'testrail_results'
);

IF tbl_exists THEN
  SET col_exists = (
    SELECT COUNT(1) > 0
    FROM `{project}.{dataset}.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = 'testrail_results' AND column_name = 'created_on'
  );

  IF NOT col_exists THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `{project}.{dataset}.testrail_results` ADD COLUMN created_on TIMESTAMP';
  END IF;

  EXECUTE IMMEDIATE 'UPDATE `{project}.{dataset}.testrail_results` SET created_on = ingest_timestamp WHERE created_on IS NULL AND ingest_timestamp IS NOT NULL';
END IF;
"""
    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "testrail", "step": "schema"})


def _compute_testrail_kpis(bvt_suite_name: str, lookback_days: int) -> None:
    client = get_client()
    tr_table = table_ref("testrail_results")
    kpi_table = table_ref("qa_executive_kpis")

    suite_lit = bvt_suite_name.replace('"', '\"')

    sql = f"""
DECLARE today DATE DEFAULT CURRENT_DATE("UTC");
DECLARE start7 DATE DEFAULT DATE_SUB(today, INTERVAL 6 DAY);

-- EXEC-15: test cases executed by day (last 7d, UTC)
INSERT INTO `{kpi_table}`
  (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-15",
  "Test cases executed by day (last 7d, UTC)",
  d AS metric_date,
  start7,
  today,
  "{{}}",
  executed_cnt * 1.0,
  NULL,
  NULL,
  "TestRail"
FROM (
  SELECT
    DATE(created_on, "UTC") AS d,
    COUNT(DISTINCT IF(status_id IN ({",".join(map(str, EXECUTED_STATUS_IDS))}), result_id, NULL)) AS executed_cnt
  FROM `{tr_table}`
  WHERE created_on IS NOT NULL
    AND DATE(created_on, "UTC") BETWEEN start7 AND today
  GROUP BY d
);

-- EXEC-16: pass rate (last 7d, UTC)
INSERT INTO `{kpi_table}`
  (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
WITH agg AS (
  SELECT
    COUNT(DISTINCT IF(status_id = 1, result_id, NULL)) AS passed,
    COUNT(DISTINCT IF(status_id IN ({",".join(map(str, EXECUTED_STATUS_IDS))}), result_id, NULL)) AS executed
  FROM `{tr_table}`
  WHERE created_on IS NOT NULL
    AND DATE(created_on, "UTC") BETWEEN start7 AND today
)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-16",
  "Pass rate (last 7d, UTC)",
  today,
  start7,
  today,
  "{{}}",
  SAFE_DIVIDE(passed, executed),
  passed * 1.0,
  executed * 1.0,
  "TestRail"
FROM agg;

-- EXEC-17: BVT pass rate (latest Basic BVT run)
INSERT INTO `{kpi_table}`
  (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
WITH candidates AS (
  SELECT
    run_id,
    ANY_VALUE(run_name) AS run_name,
    ANY_VALUE(suite_name) AS suite_name,
    MAX(created_on) AS last_result_ts,
    LOGICAL_OR(LOWER(IFNULL(suite_name, "")) = LOWER("{suite_lit}")) AS is_exact_suite
  FROM `{tr_table}`
  WHERE created_on IS NOT NULL
    AND created_on >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {lookback_days} DAY)
    AND (
      LOWER(IFNULL(suite_name, "")) = LOWER("{suite_lit}")
      OR LOWER(IFNULL(run_name, "")) LIKE "%bvt%"
    )
  GROUP BY run_id
),
selected_candidates AS (
  SELECT *
  FROM candidates
  WHERE is_exact_suite

  UNION ALL

  SELECT *
  FROM candidates
  WHERE NOT EXISTS (SELECT 1 FROM candidates WHERE is_exact_suite)
),
latest_run AS (
  SELECT * FROM selected_candidates ORDER BY last_result_ts DESC LIMIT 1
),
agg AS (
  SELECT
    COUNT(DISTINCT IF(status_id = 1, result_id, NULL)) AS passed,
    COUNT(DISTINCT IF(status_id IN ({",".join(map(str, EXECUTED_STATUS_IDS))}), result_id, NULL)) AS executed
  FROM `{tr_table}`
  WHERE run_id = (SELECT run_id FROM latest_run)
)
SELECT
  CURRENT_TIMESTAMP(),
  "EXEC-17",
  "BVT pass rate (latest Basic BVT run)",
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(
    (SELECT run_id FROM latest_run) AS run_id,
    (SELECT run_name FROM latest_run) AS run_name,
    (SELECT suite_name FROM latest_run) AS suite_name
  )),
  SAFE_DIVIDE(passed, executed),
  passed * 1.0,
  executed * 1.0,
  "TestRail"
FROM agg;
"""

    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "testrail"})


def hello_http(request):
    if request.method not in ("POST", "GET"):
        return ("Method not allowed", 405)

    try:
        config = _validate_testrail_config()

        # Make schema resilient for older tables.
        _ensure_testrail_schema()

        base_url = config["base_url"]
        email = config["email"]
        api_key = config["api_key"]
        project_ids = _get_project_ids()

        lookback_days = int(os.environ.get("TESTRAIL_LOOKBACK_DAYS", "30").strip() or "30")
        lookback_days = max(1, min(lookback_days, 365))
        bvt_suite = os.environ.get("TESTRAIL_BVT_SUITE_NAME", "Basic BVT").strip() or "Basic BVT"

        client = get_client()
        tr = TestRailClient(base_url, email, api_key)

        now = utc_now()
        default_since = int(now.timestamp()) - (lookback_days * 86400)
        ingest_ts = now.isoformat().replace("+00:00", "Z")

        total_inserted = 0

        for pid in project_ids:
            suites = tr.get_suites(pid)
            since_ts = _get_last_created_on(client, pid, default_since)

            runs = tr.get_runs(pid, default_since)

            max_seen_created_on = since_ts
            batch: List[Dict[str, Any]] = []

            for run in runs:
                suite_id = run.get("suite_id")
                suite_name = suites.get(int(suite_id)) if suite_id is not None else None

                results = tr.get_results_for_run(int(run["id"]), created_after=since_ts)
                for r in results:
                    row = _parse_result(pid, run, suite_name, ingest_ts, r)
                    batch.append(row)
                    try:
                        created_on = int(r.get("created_on") or 0)
                        if created_on > max_seen_created_on:
                            max_seen_created_on = created_on
                    except Exception:
                        pass

                if len(batch) >= 500:
                    total_inserted += insert_rows(client, "testrail_results", batch)
                    batch = []

            if batch:
                total_inserted += insert_rows(client, "testrail_results", batch)

            if max_seen_created_on > since_ts:
                _set_last_created_on(client, pid, max_seen_created_on)

        _compute_testrail_kpis(bvt_suite, lookback_days)

        return jsonify({"status": "ok", "inserted_rows": total_inserted})

    except ConfigError as e:
        return jsonify({"status": "error", "error": str(e)}), 400
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500
