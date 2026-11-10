from __future__ import annotations

import re
import unicodedata
from datetime import date, datetime
from zoneinfo import ZoneInfo

from .config import LOCAL_TZ

_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def normalize_name(value: str) -> str:
    """Lowercase, strip accents/punctuation, '&' -> 'and'. Used for matching keys."""
    value = unicodedata.normalize("NFKD", value)
    value = "".join(c for c in value if not unicodedata.combining(c))
    value = value.lower().replace("&", " and ")
    return _NON_ALNUM.sub(" ", value).strip()


def slugify(value: str) -> str:
    return normalize_name(value).replace(" ", "-")


def local_event_date(dt: datetime) -> date:
    """Calendar date in Asia/Kolkata; the dedup blocking key."""
    return dt.astimezone(ZoneInfo(LOCAL_TZ)).date()
