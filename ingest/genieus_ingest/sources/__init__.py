from __future__ import annotations

from .base import Source

# Register scrapers here as they are built (Phase 2+).
SOURCES: list[type[Source]] = []
