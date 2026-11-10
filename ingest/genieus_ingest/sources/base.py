from __future__ import annotations

import time
from abc import ABC, abstractmethod
from collections.abc import Iterable
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

import requests

from ..config import REQUEST_DELAY_SECONDS, REQUEST_TIMEOUT_SECONDS, USER_AGENT
from ..models import RawEvent


class Source(ABC):
    """One scraper per source. A failure here must not stop other sources."""

    name: str  # stable id stored in event_sources.source

    def __init__(self) -> None:
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT})
        self._robots: dict[str, RobotFileParser] = {}
        self._last_request = 0.0

    def _allowed(self, url: str) -> bool:
        parts = urlparse(url)
        origin = f"{parts.scheme}://{parts.netloc}"
        if origin not in self._robots:
            rp = RobotFileParser()
            rp.set_url(f"{origin}/robots.txt")
            try:
                rp.read()
            except Exception:
                # robots.txt unreachable: be conservative and treat as allowed
                # only for the homepage-level politeness; scrapers may override.
                rp.allow_all = True
            self._robots[origin] = rp
        return self._robots[origin].can_fetch(USER_AGENT, url)

    def get(self, url: str, **kwargs) -> requests.Response:
        """Polite GET: honours robots.txt and a fixed delay between requests."""
        if not self._allowed(url):
            raise PermissionError(f"robots.txt disallows {url}")
        wait = REQUEST_DELAY_SECONDS - (time.monotonic() - self._last_request)
        if wait > 0:
            time.sleep(wait)
        resp = self.session.get(url, timeout=REQUEST_TIMEOUT_SECONDS, **kwargs)
        self._last_request = time.monotonic()
        resp.raise_for_status()
        return resp

    @abstractmethod
    def fetch(self) -> Iterable[RawEvent]:
        """Yield upcoming electronic events for the six launch cities."""
