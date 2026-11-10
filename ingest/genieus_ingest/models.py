from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class RawEvent:
    """Source-agnostic event as emitted by a scraper, before dedup."""

    source: str
    source_event_id: str
    source_url: str
    title: str
    starts_at: datetime  # timezone-aware
    city: str  # raw city text; resolved against cities.slug/aliases
    venue_name: str | None = None
    venue_address: str | None = None
    artists: list[str] = field(default_factory=list)  # headliner first
    ends_at: datetime | None = None
    poster_url: str | None = None
    min_price: float | None = None
    ticket_url: str | None = None
    description: str | None = None
