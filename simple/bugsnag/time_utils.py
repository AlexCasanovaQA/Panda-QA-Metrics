from __future__ import annotations

import datetime as dt
import re
from typing import Optional


def utc_now() -> dt.datetime:
    """Timezone-aware UTC 'now'."""
    return dt.datetime.now(dt.timezone.utc)


def to_rfc3339(ts: dt.datetime) -> str:
    """Convert a datetime to RFC3339 string with Z suffix."""
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=dt.timezone.utc)
    return ts.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def unix_to_utc_ts(seconds: Optional[int]) -> Optional[str]:
    """Unix seconds -> RFC3339 UTC timestamp string."""
    if seconds is None:
        return None
    return dt.datetime.fromtimestamp(int(seconds), tz=dt.timezone.utc).isoformat().replace("+00:00", "Z")


_JIRA_TZ_RE = re.compile(r"([+-])(\d{2})(\d{2})$")


def jira_to_rfc3339(ts: Optional[str]) -> Optional[str]:
    """Convert Jira timestamps like 2026-02-26T16:57:11.469+0000 to RFC3339 (UTC)."""
    if not ts:
        return None

    ts = ts.strip()

    # If already has Z or +HH:MM, return as-is (BigQuery accepts it).
    if ts.endswith("Z") or re.search(r"[+-]\d{2}:\d{2}$", ts):
        return ts

    # Convert +0000 to +00:00
    m = _JIRA_TZ_RE.search(ts)
    if m:
        sign, hh, mm = m.group(1), m.group(2), m.group(3)
        ts = _JIRA_TZ_RE.sub(f"{sign}{hh}:{mm}", ts)

    try:
        d = dt.datetime.fromisoformat(ts)
    except ValueError:
        # Last resort: return raw string and let BQ attempt parsing.
        return ts

    return d.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")
