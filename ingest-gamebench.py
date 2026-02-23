import json
import os
import time
import random
import re
from functools import lru_cache
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Tuple

import google.auth
import requests
from flask import jsonify
from google.cloud import bigquery, secretmanager

# ----------------- GCP / BigQuery -----------------
_, PROJECT_ID = google.auth.default()
DATASET_ID = os.environ.get("BQ_DATASET", "qa_metrics")
TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.gamebench_sessions_v1"

bq = bigquery.Client(project=PROJECT_ID)
sm = secretmanager.SecretManagerServiceClient()

BASE_URL = os.environ.get("GAMEBENCH_BASE_URL", "https://web.gamebench.net")
DEFAULT_COMPANY_ID = os.environ.get("GAMEBENCH_COMPANY_ID", "AWGaWNjXBxsUazsJuoUp")
DEFAULT_COLLECTION_ID = os.environ.get("GAMEBENCH_COLLECTION_ID", "7cf80f11-6915-4e6c-b70c-4ad7ed44aaf9")

# Avoid commas in env var to keep gcloud happy; we accept | or comma in parsing.
DEFAULT_APP_PACKAGES = os.environ.get(
    "GAMEBENCH_APP_PACKAGES",
    "com.scopely.internal.wwedomination|com.scopely.wwedomination",
)

# If GAMEBENCH_USER isn't set, we fall back to this to keep it "ready".
DEFAULT_USER = os.environ.get("GAMEBENCH_USER", "alex.casanova@scopely.com")

HTTP_TIMEOUT = int(os.environ.get("HTTP_TIMEOUT_SECONDS", "30"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
BASE_BACKOFF = float(os.environ.get("BASE_BACKOFF_SECONDS", "1.0"))
MAX_BACKOFF = float(os.environ.get("MAX_BACKOFF_SECONDS", "30.0"))
PAGE_SIZE = int(os.environ.get("GAMEBENCH_PAGE_SIZE", "50"))
MAX_SESSIONS_PER_RUN = int(os.environ.get("MAX_SESSIONS_PER_RUN", "200"))

def _secret(name: str) -> str:
    sname = f"projects/{PROJECT_ID}/secrets/{name}/versions/latest"
    return sm.access_secret_version(request={"name": sname}).payload.data.decode("utf-8").strip()

@lru_cache(maxsize=1)
def _token() -> str:
    return _secret("GAMEBENCH_TOKEN")

def _auth() -> Tuple[str, str]:
    return (DEFAULT_USER, _token())

def _req(method: str, url: str, *, json_body: Optional[Dict[str, Any]] = None, params: Optional[Dict[str, Any]] = None) -> requests.Response:
    last_exc: Optional[Exception] = None
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.request(
                method,
                url,
                auth=_auth(),
                headers={"accept": "application/json", "Content-Type": "application/json"},
                params=params,
                json=json_body,
                timeout=HTTP_TIMEOUT,
            )
            if r.status_code in (429, 500, 502, 503, 504):
                backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
                jitter = random.uniform(0, 0.25 * backoff)
                time.sleep(backoff + jitter)
                continue
            r.raise_for_status()
            return r
        except Exception as e:
            last_exc = e
            backoff = min(MAX_BACKOFF, BASE_BACKOFF * (2 ** attempt))
            jitter = random.uniform(0, 0.25 * backoff)
            time.sleep(backoff + jitter)
    raise RuntimeError(f"HTTP failed after retries: {last_exc}")

def _parse_ts(v: Any) -> Optional[str]:
    if v is None:
        return None
    # timePushed may be epoch ms or iso string
    if isinstance(v, (int, float)):
        # assume ms if large
        sec = v / 1000.0 if v > 1e12 else v
        return datetime.fromtimestamp(sec, timezone.utc).isoformat().replace("+00:00", "Z")
    if isinstance(v, str):
        s = v.strip()
        if not s:
            return None
        # Keep as-is for unknown formats, but normalize common UTC suffix.
        return s.replace("+00:00", "Z")
    return None

def _to_dt(v: Any) -> Optional[datetime]:
    ts = _parse_ts(v)
    if not ts:
        return None
    try:
        parsed = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)

def _get(d: Dict[str, Any], *keys, default=None):
    cur: Any = d
    for k in keys:
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(k)
        else:
            return default
    return cur if cur is not None else default

def _f(v: Any) -> Optional[float]:
    try:
        if v is None or v == "":
            return None
        return float(v)
    except Exception:
        return None

def _environment(app_package: Optional[str]) -> str:
    if not app_package:
        return "unknown"
    return "dev" if ".internal." in app_package else "prod"

def _split_packages(s: str) -> List[str]:
    if not s:
        return []
    parts = re.split(r"[|,;\s]+", s.strip())
    return [p for p in parts if p]

def ensure_table_exists() -> None:
    # Table is created via SQL, but keep safe.
    pass

def search_sessions(company_id: str, collection_id: str, apps: List[str], page: int) -> List[Dict[str, Any]]:
    url = f"{BASE_URL.rstrip('/')}/v1/sessions"
    params = {"company": company_id, "pageSize": PAGE_SIZE, "page": page, "sort": "timePushed:desc"}
    body = {
        "apps": apps,
        "devices": [],
        "manufacturers": [],
        "collectionId": collection_id,
    }
    data = _req("POST", url, json_body=body, params=params).json()
    # Response is typically {sessions:[...], total:...} or a list; handle both
    if isinstance(data, dict):
        return data.get("sessions") or data.get("results") or data.get("items") or []
    if isinstance(data, list):
        return data
    return []

def get_session(session_id: str) -> Dict[str, Any]:
    url = f"{BASE_URL.rstrip('/')}/v1/sessions/{session_id}"
    return _req("GET", url).json()

def upsert_rows(rows: List[Dict[str, Any]]) -> int:
    if not rows:
        return 0
    # best-effort de-dupe using insertId=session_id
    row_ids = [r.get("session_id") for r in rows]
    errors = bq.insert_rows_json(TABLE_ID, rows, row_ids=row_ids)
    if errors:
        raise RuntimeError(str(errors)[:1200])
    return len(rows)

def _sanitize_days(v: Any) -> int:
    try:
        days = int(v)
    except Exception:
        return 7
    return min(max(days, 1), 365)

def _normalize_apps(app_packages: Any) -> List[str]:
    if isinstance(app_packages, list):
        return [str(x).strip() for x in app_packages if str(x).strip()]
    if isinstance(app_packages, str):
        return _split_packages(app_packages)
    return _split_packages(DEFAULT_APP_PACKAGES)

def ingest(days: int, platform: Optional[str], company_id: str, collection_id: str, app_packages: List[str]) -> Dict[str, Any]:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    ingested_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    if not app_packages:
        raise ValueError("No app packages provided. Set GAMEBENCH_APP_PACKAGES or pass app_packages.")

    fetched = 0
    inserted = 0
    pages = 0

    for page in range(0, 500):
        pages += 1
        sessions = search_sessions(company_id, collection_id, app_packages, page)
        if not sessions:
            break

        rows_to_insert: List[Dict[str, Any]] = []

        for s in sessions:
            sid = _get(s, "id") or _get(s, "sessionId") or _get(s, "_id")
            if not sid:
                continue

            dtp = _to_dt(_get(s, "timePushed") or _get(s, "time_pushed"))
            if dtp and dtp < since:
                if rows_to_insert:
                    inserted += upsert_rows(rows_to_insert)
                return {"pages": pages, "sessions_fetched": fetched, "rows_inserted": inserted}

            # Fetch details for metrics
            detail = get_session(str(sid))
            fetched += 1

            app_pkg = _get(detail, "app") or _get(detail, "appPackage") or _get(detail, "app_package") or _get(s, "app")
            plat = _get(detail, "platform") or _get(detail, "os") or _get(detail, "device", "platform")
            if platform and plat and str(plat).lower() != platform.lower():
                continue

            # Best-effort field mapping (API keys vary by account/setup)
            row = {
                "session_id": str(sid),
                "time_pushed": _parse_ts(_get(detail, "timePushed") or _get(detail, "time_pushed") or _get(s, "timePushed")),
                "company_id": company_id,
                "collection_id": collection_id,
                "environment": _environment(app_pkg),
                "platform": (str(plat).lower() if plat else None),
                "app_package": app_pkg,
                "app_version": _get(detail, "appVersion") or _get(detail, "app_version"),
                "user_email": _get(detail, "user") or _get(detail, "account") or DEFAULT_USER,
                "device_model": _get(detail, "device") or _get(detail, "deviceModel") or _get(detail, "device_model"),
                "device_manufacturer": _get(detail, "manufacturer") or _get(detail, "deviceManufacturer") or _get(detail, "device_manufacturer"),
                "os_version": _get(detail, "osVersion") or _get(detail, "os_version"),
                "gpu_model": _get(detail, "gpuModel") or _get(detail, "gpu_model"),
                "seconds_played": _f(_get(detail, "secondsPlayed") or _get(detail, "seconds_played")),
                "median_fps": _f(_get(detail, "medianFps") or _get(detail, "median_fps") or _get(detail, "fps", "median") or _get(detail, "fpsMedian")),
                "fps_1p_low": _f(_get(detail, "fps1pLow") or _get(detail, "fps_1p_low")),
                "fps_stability_pct": _f(_get(detail, "fpsStabilityPct") or _get(detail, "fps_stability_pct")),
                "fps_stability_index": _f(_get(detail, "fpsStabilityIndex") or _get(detail, "fps_stability_index")),
                "janks_per_10m": _f(_get(detail, "janksPer10m") or _get(detail, "janks_per_10m")),
                "big_janks_per_10m": _f(_get(detail, "bigJanksPer10m") or _get(detail, "big_janks_per_10m")),
                "small_janks_per_10m": _f(_get(detail, "smallJanksPer10m") or _get(detail, "small_janks_per_10m")),
                "cpu_avg_pct": _f(_get(detail, "cpuAvgPct") or _get(detail, "cpu_avg_pct")),
                "cpu_max_pct": _f(_get(detail, "cpuMaxPct") or _get(detail, "cpu_max_pct")),
                "memory_avg_mb": _f(_get(detail, "memoryAvgMb") or _get(detail, "memory_avg_mb")),
                "memory_max_mb": _f(_get(detail, "memoryMaxMb") or _get(detail, "memory_max_mb")),
                "power_avg_mw": _f(_get(detail, "powerAvgMw") or _get(detail, "power_avg_mw")),
                "current_avg_ma": _f(_get(detail, "currentAvgMa") or _get(detail, "current_avg_ma")),
                "battery_mah": _f(_get(detail, "batteryMah") or _get(detail, "battery_mah")),
                "download_mb": _f(_get(detail, "downloadMb") or _get(detail, "download_mb")),
                "upload_mb": _f(_get(detail, "uploadMb") or _get(detail, "upload_mb")),
                "session_url": _get(detail, "url") or f"{BASE_URL.rstrip('/')}/dashboard/sessions/{sid}/Summary?collectionId={collection_id}&companyId={company_id}",
                "raw_json": json.dumps(detail, ensure_ascii=False)[:500000],
                "_ingested_at": ingested_at,
            }

            rows_to_insert.append(row)

            if len(rows_to_insert) >= 100:
                inserted += upsert_rows(rows_to_insert)
                rows_to_insert = []

            if inserted >= MAX_SESSIONS_PER_RUN:
                if rows_to_insert:
                    inserted += upsert_rows(rows_to_insert)
                return {"pages": pages, "sessions_fetched": fetched, "rows_inserted": inserted, "stopped": "max_sessions"}

        if rows_to_insert:
            inserted += upsert_rows(rows_to_insert)

        if inserted >= MAX_SESSIONS_PER_RUN:
            return {"pages": pages, "sessions_fetched": fetched, "rows_inserted": inserted, "stopped": "max_sessions"}

        # continue pages

    return {"pages": pages, "sessions_fetched": fetched, "rows_inserted": inserted}

def ingest_gamebench(request):
    body = request.get_json(silent=True) or {}
    days = _sanitize_days(body.get("days", 7))
    platform = body.get("platform")  # android/ios or None
    company_id = body.get("company_id") or DEFAULT_COMPANY_ID
    collection_id = body.get("collection_id") or DEFAULT_COLLECTION_ID
    apps = _normalize_apps(body.get("app_packages"))

    try:
        result = ingest(days=days, platform=platform, company_id=company_id, collection_id=collection_id, app_packages=apps)
        return jsonify({"status": "OK", **result}), 200
    except Exception as e:
        return jsonify({"status": "ERROR", "error": str(e)}), 500

# Default Functions Framework target
def hello_http(request):
    return ingest_gamebench(request)
