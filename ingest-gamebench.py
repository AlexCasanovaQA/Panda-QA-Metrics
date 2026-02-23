"""Ingest GameBench sessions into BigQuery.

This script is designed for Cloud Run (Functions Framework) like the other QA metrics ingestors.

Auth
- Preferred: Basic auth using GAMEBENCH_USER + GAMEBENCH_TOKEN (API token)
- Optional: Bearer auth using GAMEBENCH_BEARER_TOKEN

Config
- GAMEBENCH_COMPANY_ID (required)
- GAMEBENCH_APP_PACKAGES (comma-separated). Example:
    com.scopely.wwedomination,com.scopely.internal.wwedomination

BQ
- BQ_DATASET_ID (default qa_metrics)
- BQ_TABLE_ID (default gamebench_sessions_v1)

Incremental
- If the table already has rows, we query MAX(time_pushed) and re-fetch with an overlap.

Notes
- GameBench APIs can vary slightly across tenants; we store raw_json for future-proofing.
- The metric extraction uses a robust "flatten + fuzzy match" strategy.
"""

import base64
import json
import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

import functions_framework
import requests
from google.cloud import bigquery


GB_BASE_URL = os.environ.get("GAMEBENCH_BASE_URL", "https://api.gamebench.net").rstrip("/")
GB_COMPANY_ID = os.environ.get("GAMEBENCH_COMPANY_ID")
GB_USER = os.environ.get("GAMEBENCH_USER") or os.environ.get("GAMEBENCH_USERNAME")
GB_TOKEN = os.environ.get("GAMEBENCH_TOKEN")
GB_BEARER = os.environ.get("GAMEBENCH_BEARER_TOKEN")
GB_APP_PACKAGES = os.environ.get(
    "GAMEBENCH_APP_PACKAGES",
    "com.scopely.wwedomination,com.scopely.internal.wwedomination",
)

DEFAULT_LOOKBACK_DAYS = int(os.environ.get("LOOKBACK_DAYS", "30"))
DEFAULT_OVERLAP_DAYS = int(os.environ.get("OVERLAP_DAYS", "3"))
MAX_SESSIONS_PER_RUN = int(os.environ.get("MAX_SESSIONS_PER_RUN", "500"))

BQ_DATASET_ID = os.environ.get("BQ_DATASET_ID", "qa_metrics")
BQ_TABLE_ID = os.environ.get("BQ_TABLE_ID", "gamebench_sessions_v1")


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(ts: Optional[datetime]) -> Optional[str]:
    return ts.isoformat().replace("+00:00", "Z") if ts else None


def _get_project_id() -> str:
    pid = os.environ.get("GCP_PROJECT_ID")
    if pid:
        return pid
    return bigquery.Client().project


def _headers() -> Dict[str, str]:
    h = {"Accept": "application/json"}
    if GB_BEARER:
        h["Authorization"] = f"Bearer {GB_BEARER}"
        return h

    # Basic auth header
    if GB_USER and GB_TOKEN:
        token = base64.b64encode(f"{GB_USER}:{GB_TOKEN}".encode("utf-8")).decode("ascii")
        h["Authorization"] = f"Basic {token}"
    return h


def _request(method: str, path: str, *, params: Optional[Dict[str, Any]] = None, json_body: Any = None) -> Any:
    url = f"{GB_BASE_URL}{path}"
    r = requests.request(method, url, headers=_headers(), params=params, json=json_body, timeout=60)
    if r.status_code >= 400:
        # Helpful debug
        try:
            body = r.json()
        except Exception:
            body = r.text
        raise RuntimeError(f"GameBench API error {r.status_code} {url}: {body}")
    return r.json()


def _ensure_table(bq: bigquery.Client, table_ref: bigquery.TableReference) -> None:
    schema = [
        bigquery.SchemaField("session_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("company_id", "STRING"),
        bigquery.SchemaField("time_pushed", "TIMESTAMP"),
        bigquery.SchemaField("time_started", "TIMESTAMP"),
        bigquery.SchemaField("duration_seconds", "INT64"),
        bigquery.SchemaField("account", "STRING"),
        bigquery.SchemaField("app_package", "STRING"),
        bigquery.SchemaField("app_name", "STRING"),
        bigquery.SchemaField("app_version", "STRING"),
        bigquery.SchemaField("environment", "STRING"),
        bigquery.SchemaField("platform", "STRING"),
        bigquery.SchemaField("device_model", "STRING"),
        bigquery.SchemaField("device_manufacturer", "STRING"),
        bigquery.SchemaField("os_version", "STRING"),
        bigquery.SchemaField("gpu_model", "STRING"),
        bigquery.SchemaField("seconds_played", "FLOAT64"),
        bigquery.SchemaField("median_fps", "FLOAT64"),
        bigquery.SchemaField("fps_stability_pct", "FLOAT64"),
        bigquery.SchemaField("fps_stability_index", "FLOAT64"),
        bigquery.SchemaField("cpu_avg_pct", "FLOAT64"),
        bigquery.SchemaField("cpu_max_pct", "FLOAT64"),
        bigquery.SchemaField("memory_avg_mb", "FLOAT64"),
        bigquery.SchemaField("memory_max_mb", "FLOAT64"),
        bigquery.SchemaField("power_avg_mw", "FLOAT64"),
        bigquery.SchemaField("current_avg_ma", "FLOAT64"),
        bigquery.SchemaField("battery_mah", "FLOAT64"),
        bigquery.SchemaField("download_mb", "FLOAT64"),
        bigquery.SchemaField("upload_mb", "FLOAT64"),
        bigquery.SchemaField("raw_json", "STRING"),
        bigquery.SchemaField("_ingested_at", "TIMESTAMP"),
    ]

    try:
        table = bq.get_table(table_ref)
        existing = {f.name for f in table.schema}
        to_add = [f for f in schema if f.name not in existing]
        if to_add:
            table.schema = list(table.schema) + to_add
            bq.update_table(table, ["schema"])
            print(f"Added {len(to_add)} columns to {table_ref}")
    except Exception:
        table = bigquery.Table(table_ref, schema=schema)
        table.time_partitioning = bigquery.TimePartitioning(field="_ingested_at")
        bq.create_table(table)
        print(f"Created table {table_ref}")


def _get_latest_time_pushed(bq: bigquery.Client, table_ref: bigquery.TableReference) -> Optional[datetime]:
    sql = f"SELECT MAX(time_pushed) AS max_ts FROM `{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}`"
    try:
        rows = list(bq.query(sql).result())
        if not rows:
            return None
        return rows[0].get("max_ts")
    except Exception as e:
        print("Warning: could not query latest time_pushed:", e)
        return None


def _flatten(obj: Any, prefix: str = "") -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}.{k}" if prefix else str(k)
            out.update(_flatten(v, key))
    elif isinstance(obj, list):
        for i, v in enumerate(obj[:200]):
            key = f"{prefix}[{i}]"
            out.update(_flatten(v, key))
    else:
        out[prefix] = obj
    return out


def _pick_number(flat: Dict[str, Any], patterns: List[str]) -> Optional[float]:
    """Find the first numeric value whose key path matches one of the regex patterns."""
    for pat in patterns:
        rx = re.compile(pat, re.IGNORECASE)
        for k, v in flat.items():
            if v is None:
                continue
            if rx.search(k):
                try:
                    return float(v)
                except Exception:
                    continue
    return None


def _pick_string(flat: Dict[str, Any], patterns: List[str]) -> Optional[str]:
    for pat in patterns:
        rx = re.compile(pat, re.IGNORECASE)
        for k, v in flat.items():
            if v is None:
                continue
            if rx.search(k):
                if isinstance(v, (str, int, float, bool)):
                    return str(v)
    return None


def _parse_ts(value: Any) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, str):
        # try ISO
        try:
            if value.endswith("Z"):
                return datetime.fromisoformat(value.replace("Z", "+00:00"))
            return datetime.fromisoformat(value)
        except Exception:
            pass
    if isinstance(value, (int, float)):
        # seconds vs ms heuristic
        v = float(value)
        if v > 1e12:
            v = v / 1000.0
        return datetime.fromtimestamp(v, tz=timezone.utc)
    return None


def _search_sessions(company_id: str, app_packages: List[str], since: datetime, until: datetime, page: int, page_size: int) -> Any:
    """Call advanced-search/sessions and return raw JSON."""
    body = {
        "sessionInfo": {
            "dateStart": int(since.timestamp()),
            "dateEnd": int(until.timestamp()),
        },
        "appInfo": {
            "package": app_packages,
        },
    }

    params = {
        "company": company_id,
        "page": page,
        "pageSize": page_size,
        "sort": "timePushed:desc",
    }

    return _request("POST", "/v1/advanced-search/sessions", params=params, json_body=body)


def _extract_sessions_list(resp: Any) -> List[Dict[str, Any]]:
    if isinstance(resp, list):
        return [x for x in resp if isinstance(x, dict)]
    if isinstance(resp, dict):
        for key in ["sessions", "results", "items", "data"]:
            val = resp.get(key)
            if isinstance(val, list):
                return [x for x in val if isinstance(x, dict)]
    return []


def _get_session_details(session_id: str, company_id: str) -> Dict[str, Any]:
    return _request("GET", f"/v1/sessions/{session_id}", params={"company": company_id})


def _build_row(details: Dict[str, Any], company_id: str) -> Dict[str, Any]:
    flat = _flatten(details)

    session_id = (
        _pick_string(flat, [r"^sessionId$", r"sessionId$", r"^id$", r"\.sessionId$"]) or ""
    )

    time_pushed = _parse_ts(_pick_number(flat, [r"timePushed$", r"\.timePushed$"])) or _parse_ts(
        _pick_string(flat, [r"timePushed$", r"\.timePushed$"])
    )
    time_started = _parse_ts(_pick_number(flat, [r"timeStarted$", r"dateStart$", r"\.timeStarted$"])) or _parse_ts(
        _pick_string(flat, [r"timeStarted$", r"dateStart$", r"\.timeStarted$"])
    )

    app_package = _pick_string(flat, [r"appInfo\.package$", r"app\.package$", r"packageName$", r"package$"]) 
    app_name = _pick_string(flat, [r"appInfo\.name$", r"app\.name$", r"appName$"]) 
    app_version = _pick_string(flat, [r"appVersion$", r"appInfo\.version$", r"versionName$", r"app\.version$"]) 

    environment = None
    if app_package:
        environment = "dev" if ".internal." in app_package else "prod"

    # Platform heuristic: OS / device type
    os_version = _pick_string(flat, [r"osVersion$", r"deviceInfo\.osVersion$", r"os\.version$"]) 
    platform = None
    if os_version and re.search(r"^iOS", os_version, re.IGNORECASE):
        platform = "iOS"
    elif os_version and re.search(r"android", os_version, re.IGNORECASE):
        platform = "Android"
    else:
        # fallback: device manufacturer sometimes indicates Apple
        manu = _pick_string(flat, [r"manufacturer$", r"deviceInfo\.manufacturer$"]) 
        if manu and manu.lower() == "apple":
            platform = "iOS"

    device_model = _pick_string(flat, [r"deviceInfo\.model$", r"device\.model$", r"deviceModel$"]) 
    device_manufacturer = _pick_string(flat, [r"deviceInfo\.manufacturer$", r"device\.manufacturer$", r"manufacturer$"]) 
    gpu_model = _pick_string(flat, [r"gpu.*model", r"gpuModel"]) 

    # Duration / playtime
    seconds_played = _pick_number(flat, [r"secondsPlayed$", r"durationSeconds$", r"playTimeSeconds$"]) 
    duration_seconds = None
    if seconds_played is not None:
        duration_seconds = int(seconds_played)

    # Key performance metrics (fuzzy match)
    median_fps = _pick_number(flat, [r"median.*fps", r"fps.*median", r"fpsMedian"]) 
    fps_stability_pct = _pick_number(flat, [r"stability.*%", r"fpsStability.*percent", r"fpsStabilityPct", r"stabilityPercent"]) 
    fps_stability_index = _pick_number(flat, [r"stability.*index", r"fpsStabilityIndex"]) 

    cpu_avg_pct = _pick_number(flat, [r"cpu.*avg", r"avgCpu", r"cpuAvg"]) 
    cpu_max_pct = _pick_number(flat, [r"cpu.*max", r"maxCpu", r"cpuMax"]) 

    memory_avg_mb = _pick_number(flat, [r"memory.*avg", r"avgMemory", r"memoryAvg"]) 
    memory_max_mb = _pick_number(flat, [r"memory.*max", r"maxMemory", r"memoryMax"]) 

    power_avg_mw = _pick_number(flat, [r"mWatt", r"power.*avg", r"avgPower", r"powerAvg"]) 
    current_avg_ma = _pick_number(flat, [r"mAmp", r"current.*avg", r"avgCurrent", r"currentAvg"]) 
    battery_mah = _pick_number(flat, [r"mAh", r"battery.*mah", r"mahConsumed", r"batteryMah"]) 

    download_mb = _pick_number(flat, [r"download", r"mbDownloaded", r"downloadMb"]) 
    upload_mb = _pick_number(flat, [r"upload", r"mbUploaded", r"uploadMb"]) 

    row = {
        "session_id": session_id,
        "company_id": company_id,
        "time_pushed": _iso(time_pushed),
        "time_started": _iso(time_started),
        "duration_seconds": duration_seconds,
        "account": _pick_string(flat, [r"account$", r"user$", r"tester$"]),
        "app_package": app_package,
        "app_name": app_name,
        "app_version": app_version,
        "environment": environment,
        "platform": platform,
        "device_model": device_model,
        "device_manufacturer": device_manufacturer,
        "os_version": os_version,
        "gpu_model": gpu_model,
        "seconds_played": seconds_played,
        "median_fps": median_fps,
        "fps_stability_pct": fps_stability_pct,
        "fps_stability_index": fps_stability_index,
        "cpu_avg_pct": cpu_avg_pct,
        "cpu_max_pct": cpu_max_pct,
        "memory_avg_mb": memory_avg_mb,
        "memory_max_mb": memory_max_mb,
        "power_avg_mw": power_avg_mw,
        "current_avg_ma": current_avg_ma,
        "battery_mah": battery_mah,
        "download_mb": download_mb,
        "upload_mb": upload_mb,
        "raw_json": json.dumps(details, ensure_ascii=False),
        "_ingested_at": _iso(_utc_now()),
    }

    return row


@functions_framework.http
def ingest_gamebench(request):
    req = request.get_json(silent=True) or {}

    company_id = req.get("company_id") or GB_COMPANY_ID
    if not company_id:
        return (
            json.dumps({"error": "Missing company_id. Set GAMEBENCH_COMPANY_ID or pass company_id"}),
            400,
            {"Content-Type": "application/json"},
        )

    app_packages_raw = req.get("app_packages") or GB_APP_PACKAGES
    app_packages = [p.strip() for p in str(app_packages_raw).split(",") if p.strip()]

    lookback_days = int(req.get("lookback_days") or DEFAULT_LOOKBACK_DAYS)
    overlap_days = int(req.get("overlap_days") or DEFAULT_OVERLAP_DAYS)

    if not (_headers().get("Authorization")):
        return (
            json.dumps({"error": "Missing auth. Set GAMEBENCH_USER+GAMEBENCH_TOKEN or GAMEBENCH_BEARER_TOKEN"}),
            400,
            {"Content-Type": "application/json"},
        )

    bq = bigquery.Client(project=_get_project_id())
    table_ref = bq.dataset(BQ_DATASET_ID).table(BQ_TABLE_ID)
    _ensure_table(bq, table_ref)

    until = _utc_now()
    latest = _get_latest_time_pushed(bq, table_ref)
    if latest:
        since = latest - timedelta(days=overlap_days)
        mode = "incremental"
    else:
        since = until - timedelta(days=lookback_days)
        mode = "bootstrap"

    print(f"GameBench ingest mode={mode} since={since} until={until} apps={app_packages}")

    inserted = 0
    fetched_sessions = 0

    page = 0
    page_size = 100

    while True:
        resp = _search_sessions(company_id, app_packages, since, until, page, page_size)
        sessions = _extract_sessions_list(resp)
        if not sessions:
            break

        # Extract session IDs
        ids: List[str] = []
        for s in sessions:
            sid = s.get("sessionId") or s.get("id") or s.get("session_id")
            if sid:
                ids.append(str(sid))

        if not ids:
            break

        for sid in ids:
            fetched_sessions += 1
            if fetched_sessions > MAX_SESSIONS_PER_RUN:
                print(f"Reached MAX_SESSIONS_PER_RUN={MAX_SESSIONS_PER_RUN}, stopping.")
                break

            try:
                details = _get_session_details(sid, company_id)
            except Exception as e:
                print(f"Failed session details {sid}: {e}")
                continue

            row = _build_row(details, company_id)
            if not row.get("session_id"):
                # fallback to sid
                row["session_id"] = sid

            # Use insertId for best-effort de-dup
            errors = bq.insert_rows_json(table_ref, [row], row_ids=[row["session_id"]])
            if errors:
                print("BigQuery insert error (first):", errors[:1])
            else:
                inserted += 1

        if fetched_sessions > MAX_SESSIONS_PER_RUN:
            break

        # If response has paging metadata, we can stop when we reach the end.
        # Otherwise, stop when page returns fewer than page_size.
        if len(sessions) < page_size:
            break

        page += 1

    return (
        json.dumps(
            {
                "ok": True,
                "mode": mode,
                "company_id": company_id,
                "apps": app_packages,
                "since": _iso(since),
                "until": _iso(until),
                "sessions_fetched": fetched_sessions,
                "rows_inserted": inserted,
                "bq_table": f"{table_ref.project}.{table_ref.dataset_id}.{table_ref.table_id}",
            }
        ),
        200,
        {"Content-Type": "application/json"},
    )
