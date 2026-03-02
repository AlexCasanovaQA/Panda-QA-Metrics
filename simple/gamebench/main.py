"""GameBench → BigQuery ingestion + KPI computation (QA Executive).

This Cloud Run/Cloud Function (2nd gen) service:
1) Uses the GameBench Web Dashboard API to search sessions for the authenticated user:
     POST /v1/advanced-search/sessions
   Filtering by `appInfo.package` and date range.
2) For each new session, fetches:
     GET /v1/sessions/{sessionId}/fps
     GET /v1/sessions/{sessionId}/fpsStability
   and computes median FPS & median FPS stability %.
3) Inserts rows into BigQuery table `gamebench_sessions`.
4) Computes GameBench-driven executive KPIs:
   - EXEC-22 Median FPS over time (last 7d, UTC) by platform (dev/prod inferred from package)
   - EXEC-23 FPS stability % over time (last 7d, UTC) by platform
   - EXEC-24 Current build size by platform (manual table)

Required env vars / secrets:
- GAMEBENCH_USER         (email)
- GAMEBENCH_TOKEN        (API token)

Optional:
- GAMEBENCH_COMPANY_ID       defaults to AWGaWNjXBxsUazsJuoUp
- GAMEBENCH_COLLECTION_ID    defaults to 7cf80f11-6915-4e6c-b70c-4ad7ed44aaf9
- GAMEBENCH_APP_PACKAGES     CSV defaults to
                              com.scopely.internal.wwedomination,
                              com.scopely.wwedomination
- GAMEBENCH_LOOKBACK_DAYS    default 7
- GAMEBENCH_AUTH_MODE        'basic' (default) or 'bearer'

Package/environment filtering:
- Searches are split by inferred environment to match `_infer_platform_from_package`:
  `*.internal.*` -> `dev`, otherwise `prod`.

BigQuery dataset defaults:
- BQ_PROJECT = GOOGLE_CLOUD_PROJECT
- BQ_DATASET = qa_metrics_simple

Deploy settings:
- Function target (entrypoint): hello_http
"""

from __future__ import annotations

import datetime
import logging
import os
import statistics
import time
from typing import Any, Dict, Iterable, List, Optional, Tuple

import requests
from flask import jsonify

import bq
from time_utils import to_rfc3339, utc_now


fetch_rows = bq.fetch_rows
get_client = bq.get_client
insert_rows = bq.insert_rows
run_query = bq.run_query
table_ref = bq.table_ref


def _validate_bq_env_compat() -> Dict[str, str]:
    """Run startup BQ validation when available.

    Older deployments may still load a `bq.py` variant without `validate_bq_env`.
    In that case we keep the service bootable and preserve backward-compatible behavior.
    """
    validator = getattr(bq, "validate_bq_env", None)
    if callable(validator):
        return validator()
    logger.warning("BQ_STARTUP_CONFIG validation helper not found in bq.py; skipping strict env validation")
    return {}


logger = logging.getLogger(__name__)


# -----------------------------
# Helpers
# -----------------------------

def _env(name: str, default: Optional[str] = None) -> str:
    v = os.environ.get(name, default)
    if v is None or str(v).strip() == "":
        raise KeyError(name)
    return str(v).strip()


def _split_csv(value: str) -> List[str]:
    return [x.strip() for x in value.split(",") if x.strip()]


def _chunked(items: List[Dict[str, Any]], size: int) -> Iterable[List[Dict[str, Any]]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def _parse_ts(v: Any) -> Optional[datetime.datetime]:
    if v is None:
        return None
    if isinstance(v, (int, float)):
        # Unix seconds / ms
        vv = float(v)
        if vv > 10_000_000_000:  # ms
            vv = vv / 1000.0
        return datetime.datetime.fromtimestamp(vv, tz=datetime.timezone.utc)
    if isinstance(v, str):
        s = v.strip()
        try:
            if s.endswith("Z"):
                return datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
            return datetime.datetime.fromisoformat(s)
        except Exception:
            return None
    return None


def _numbers_from_payload(payload: Any) -> List[float]:
    out: List[float] = []
    if payload is None:
        return out
    if isinstance(payload, list):
        for x in payload:
            if isinstance(x, (int, float)):
                out.append(float(x))
            elif isinstance(x, str):
                try:
                    out.append(float(x))
                except Exception:
                    continue
            elif isinstance(x, dict):
                for k in ("value", "fps", "y"):
                    if k in x:
                        try:
                            out.append(float(x[k]))
                        except Exception:
                            pass
                        break
    return out


def _request_with_backoff(
    method: str,
    url: str,
    *,
    auth_mode: str,
    user: str,
    token: str,
    params: Optional[Dict[str, Any]] = None,
    json_body: Optional[Dict[str, Any]] = None,
    timeout: int = 30,
    max_retries: int = 5,
) -> requests.Response:
    delay = 2
    for _ in range(max_retries):
        headers = {"accept": "application/json", "content-type": "application/json"}
        kwargs: Dict[str, Any] = {}

        if auth_mode == "bearer":
            headers["Authorization"] = f"Bearer {token}"
        else:
            kwargs["auth"] = (user, token)

        resp = requests.request(
            method=method,
            url=url,
            params=params,
            json=json_body,
            timeout=timeout,
            headers=headers,
            **kwargs,
        )

        if resp.status_code != 429:
            return resp

        retry_after = resp.headers.get("Retry-After")
        if retry_after:
            try:
                delay = max(delay, int(retry_after))
            except Exception:
                pass

        time.sleep(min(delay, 15))
        delay = min(delay * 2, 15)

    return resp


# -----------------------------
# GameBench API
# -----------------------------

class GameBenchClient:
    BASE_URL = "https://web.gamebench.net/v1"

    def __init__(
        self,
        user: str,
        token: str,
        *,
        auth_mode: str = "basic",
        company_id: Optional[str] = None,
    ) -> None:
        self.user = user
        self.token = token
        self.auth_mode = (auth_mode or "basic").lower().strip()
        self.company_id = company_id

    def advanced_search_sessions(
        self,
        *,
        packages: List[str],
        environment: Optional[str],
        start_ms: int,
        end_ms: int,
        collection_id: Optional[str] = None,
        page_size: int = 50,
        max_pages: int = 10,
    ) -> List[Dict[str, Any]]:
        url = f"{self.BASE_URL}/advanced-search/sessions"
        all_results: List[Dict[str, Any]] = []

        # We'll try with company scope if provided, but fall back to user-scope on 401/403.
        for attempt_company in (True, False):
            scoped_company = self.company_id if attempt_company else None

            all_results = []
            for page in range(max_pages):
                params: Dict[str, Any] = {
                    "page": page,
                    "pageSize": page_size,
                    "sort": "timePushed:desc",
                }
                if scoped_company:
                    params["company"] = scoped_company

                env_filters = [environment]
                if environment:
                    # Some GameBench tenants fail on strict `environment` filtering.
                    # Fallback without environment to avoid full-ingestion failures.
                    env_filters.append(None)

                resp: Optional[requests.Response] = None
                for env_filter in env_filters:
                    body: Dict[str, Any] = {
                        "sessionInfo": {
                            "dateStart": start_ms,
                            "dateEnd": end_ms,
                        },
                        "appInfo": {
                            "package": packages,
                        },
                    }
                    if env_filter:
                        body["appInfo"]["environment"] = env_filter
                    if collection_id:
                        body["appInfo"]["collectionId"] = collection_id

                    resp = _request_with_backoff(
                        "POST",
                        url,
                        auth_mode=self.auth_mode,
                        user=self.user,
                        token=self.token,
                        params=params,
                        json_body=body,
                        timeout=30,
                    )

                    # Fallback for invalid/unsupported environment filter.
                    if resp.ok or env_filter is None or resp.status_code not in (400, 422, 500):
                        break

                if resp is None:
                    raise RuntimeError("GameBench session search did not return a response")

                if resp.status_code in (401, 403) and scoped_company and attempt_company:
                    # Retry whole search without company scope.
                    break

                if not resp.ok:
                    raise RuntimeError(
                        f"GameBench session search failed: {resp.status_code} {resp.text}"
                    )

                data = resp.json()
                results = []
                if isinstance(data, dict):
                    results = data.get("results") or data.get("sessions") or []
                elif isinstance(data, list):
                    results = data

                if not results:
                    break

                all_results.extend(results)

                if isinstance(data, dict) and data.get("totalPages") is not None:
                    try:
                        if page >= int(data.get("totalPages")) - 1:
                            break
                    except Exception:
                        pass

                if len(results) < page_size:
                    break

            # If we broke due to 401/403 with company scope, retry without company.
            if scoped_company and attempt_company and all_results == []:
                continue

            return all_results

        return all_results

    def get_fps(self, session_id: str) -> List[float]:
        url = f"{self.BASE_URL}/sessions/{session_id}/fps"
        resp = _request_with_backoff("GET", url, auth_mode=self.auth_mode, user=self.user, token=self.token, timeout=30)
        if not resp.ok:
            raise RuntimeError(
                f"GameBench FPS retrieval failed for session {session_id}: {resp.status_code} {resp.text}"
            )
        return _numbers_from_payload(resp.json())

    def get_fps_stability(self, session_id: str) -> List[float]:
        url = f"{self.BASE_URL}/sessions/{session_id}/fpsStability"
        resp = _request_with_backoff("GET", url, auth_mode=self.auth_mode, user=self.user, token=self.token, timeout=30)
        if not resp.ok:
            raise RuntimeError(
                f"GameBench FPS stability retrieval failed for session {session_id}: {resp.status_code} {resp.text}"
            )
        return _numbers_from_payload(resp.json())


# -----------------------------
# Ingestion
# -----------------------------

def _infer_platform_from_package(pkg: Optional[str]) -> str:
    if not pkg:
        return "unknown"
    if ".internal." in pkg or pkg.endswith(".internal"):
        return "dev"
    return "prod"


def _existing_session_ids(client, lookback_days: int) -> set:
    table = table_ref("gamebench_sessions")
    sql = f"""
      SELECT DISTINCT session_id
      FROM `{table}`
      WHERE time_pushed >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {lookback_days + 1} DAY)
    """
    existing = set()
    for row in fetch_rows(client, sql):
        existing.add(row[0])
    return existing


def ingest_gamebench() -> Tuple[int, int]:
    user = _env("GAMEBENCH_USER")
    token = _env("GAMEBENCH_TOKEN")

    auth_mode = os.environ.get("GAMEBENCH_AUTH_MODE", "basic").strip().lower() or "basic"
    packages_default = "com.scopely.internal.wwedomination,com.scopely.wwedomination"
    packages = _split_csv(_env("GAMEBENCH_APP_PACKAGES", packages_default))
    if not packages:
        raise ValueError("GAMEBENCH_APP_PACKAGES must contain at least one package")

    company_id = os.environ.get("GAMEBENCH_COMPANY_ID", "AWGaWNjXBxsUazsJuoUp") or None
    collection_id = os.environ.get("GAMEBENCH_COLLECTION_ID", "7cf80f11-6915-4e6c-b70c-4ad7ed44aaf9") or None
    lookback_days = int(os.environ.get("GAMEBENCH_LOOKBACK_DAYS", "7"))

    end_dt = utc_now()
    start_dt = end_dt - datetime.timedelta(days=lookback_days)

    # API commonly uses milliseconds in dashboard endpoints.
    start_ms = int(start_dt.timestamp() * 1000)
    end_ms = int(end_dt.timestamp() * 1000)

    gb = GameBenchClient(user, token, auth_mode=auth_mode, company_id=company_id)
    client = get_client()

    existing = _existing_session_ids(client, lookback_days=lookback_days)
    package_groups: Dict[str, List[str]] = {"dev": [], "prod": []}
    for pkg in packages:
        package_groups.setdefault(_infer_platform_from_package(pkg), []).append(pkg)

    sessions_by_id: Dict[str, Dict[str, Any]] = {}
    for environment, grouped_packages in package_groups.items():
        if not grouped_packages:
            continue
        grouped_sessions = gb.advanced_search_sessions(
            packages=grouped_packages,
            environment=environment,
            start_ms=start_ms,
            end_ms=end_ms,
            collection_id=collection_id,
            page_size=50,
            max_pages=10,
        )
        for session in grouped_sessions:
            session_id = session.get("sessionId") or session.get("id")
            if session_id:
                sessions_by_id[session_id] = session

    sessions = list(sessions_by_id.values())

    ingest_ts = to_rfc3339(end_dt)

    rows: List[Dict[str, Any]] = []
    inserted = 0
    skipped_sessions = 0

    for s in sessions:
        session_id = s.get("sessionId") or s.get("id")
        if not session_id or session_id in existing:
            continue

        user_email = s.get("userEmail") or s.get("user") or s.get("email")

        app = s.get("app") or s.get("appInfo") or {}
        device = s.get("device") or s.get("deviceInfo") or {}

        app_name = app.get("name")
        app_package = app.get("package") or app.get("packageName") or s.get("appPackage")
        device_model = device.get("model")

        platform = _infer_platform_from_package(app_package)

        time_pushed_dt = _parse_ts(s.get("timePushed") or s.get("time_pushed") or s.get("timePushedMs"))
        if not time_pushed_dt:
            time_pushed_dt = end_dt

        try:
            fps_values = gb.get_fps(session_id)
            median_fps = statistics.median(fps_values) if fps_values else None

            stab_values = gb.get_fps_stability(session_id)
            fps_stability = statistics.median(stab_values) if stab_values else None
        except Exception as e:
            skipped_sessions += 1
            logger.warning("Skipping session %s due to metric fetch failure: %s", session_id, e)
            continue

        rows.append(
            {
                "ingest_timestamp": ingest_ts,
                "session_id": session_id,
                "user_email": user_email,
                "app_name": app_name,
                "app_package": app_package,
                "device_model": device_model,
                "platform": platform,
                "time_pushed": to_rfc3339(time_pushed_dt),
                "median_fps": float(median_fps) if median_fps is not None else None,
                "fps_stability_pct": float(fps_stability) if fps_stability is not None else None,
            }
        )

        if len(rows) >= 250:
            inserted += insert_rows(client, "gamebench_sessions", rows)
            rows = []

    if rows:
        inserted += insert_rows(client, "gamebench_sessions", rows)

    return inserted, skipped_sessions


# -----------------------------
# KPI Computation (EXEC-22..EXEC-24)
# -----------------------------

def _compute_gamebench_kpis() -> None:
    client = get_client()

    gb_table = table_ref("gamebench_sessions")
    manual_table = table_ref("manual_build_size")
    kpi_table = table_ref("qa_executive_kpis")

    sql = f"""
DECLARE today DATE DEFAULT CURRENT_DATE("UTC");
DECLARE start7 DATE DEFAULT DATE_SUB(today, INTERVAL 6 DAY);

-- EXEC-22 Median FPS over time (last 7d, UTC) by platform
INSERT INTO `{kpi_table}`
  (computed_at, metric_id, metric_name, metric_date, window_start, window_end, dimensions, value, numerator, denominator, source)
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-22',
  'Median FPS over time (last 7d, UTC) by platform',
  d AS metric_date,
  start7,
  today,
  TO_JSON_STRING(STRUCT(platform AS platform)),
  APPROX_QUANTILES(median_fps, 2)[OFFSET(1)] * 1.0,
  NULL,
  NULL,
  'GameBench'
FROM (
  SELECT DATE(time_pushed, "UTC") AS d, platform, median_fps
  FROM `{gb_table}`
  WHERE DATE(time_pushed, "UTC") BETWEEN start7 AND today
    AND median_fps IS NOT NULL
)
GROUP BY d, platform;

-- EXEC-23 FPS stability % over time (last 7d, UTC) by platform
INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-23',
  'FPS stability % over time (last 7d, UTC) by platform',
  d AS metric_date,
  start7,
  today,
  TO_JSON_STRING(STRUCT(platform AS platform)),
  APPROX_QUANTILES(fps_stability_pct, 2)[OFFSET(1)] * 1.0,
  NULL,
  NULL,
  'GameBench'
FROM (
  SELECT DATE(time_pushed, "UTC") AS d, platform, fps_stability_pct
  FROM `{gb_table}`
  WHERE DATE(time_pushed, "UTC") BETWEEN start7 AND today
    AND fps_stability_pct IS NOT NULL
)
GROUP BY d, platform;

-- EXEC-24 Current build size by platform (manual)
CREATE TEMP TABLE latest_build AS
SELECT platform, build_size_mb
FROM `{manual_table}`
QUALIFY ROW_NUMBER() OVER (PARTITION BY platform ORDER BY metric_date DESC, updated_at DESC) = 1;

INSERT INTO `{kpi_table}`
SELECT
  CURRENT_TIMESTAMP(),
  'EXEC-24',
  'Current build size by platform (manual)',
  today,
  today,
  today,
  TO_JSON_STRING(STRUCT(platform AS platform)),
  build_size_mb * 1.0,
  NULL,
  NULL,
  'Manual'
FROM latest_build;
"""

    run_query(client, sql, job_labels={"pipeline": "qa-metrics", "source": "gamebench"})


# -----------------------------
# HTTP entrypoint
# -----------------------------

def hello_http(request):
    try:
        _validate_bq_env_compat()
        inserted, skipped_sessions = ingest_gamebench()
        kpi_status = "ok"
        try:
            _compute_gamebench_kpis()
        except Exception as e:
            kpi_status = f"error: {e}"
            logger.exception("GameBench KPI computation failed")

        return jsonify(
            {
                "status": "ok" if kpi_status == "ok" else "partial_ok",
                "inserted_session_rows": inserted,
                "skipped_sessions": skipped_sessions,
                "kpi_status": kpi_status,
            }
        )
    except Exception as e:
        logger.exception("GameBench ingestion failed")
        return jsonify({"status": "error", "error": str(e)}), 500
