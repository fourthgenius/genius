"""Probe a source URL to see what a scraper can actually extract.

Usage (from /ingest):  python tools/probe_source.py <url> [<url> ...]

Honours robots.txt and sends the GenieUs user agent. Saves the raw HTML to
tools/probe_out/ and prints a short report: status, size, whether
__NEXT_DATA__ / JSON-LD / an Apollo state is present, top-level keys, and
how many event-looking objects were found. Paste the output back to Claude.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

import requests
from bs4 import BeautifulSoup

UA = "GenieUsBot/0.1 (+free community event discovery; non-commercial)"
OUT = Path(__file__).parent / "probe_out"


def allowed(url: str) -> bool | None:
    """True/False from robots.txt; None if robots.txt itself is blocked (401/403).

    Fetched with our own user agent: urllib's default agent is often blocked,
    and RobotFileParser.read() treats any 403 as "disallow everything".
    """
    p = urlparse(url)
    robots_url = f"{p.scheme}://{p.netloc}/robots.txt"
    resp = requests.get(robots_url, headers={"User-Agent": UA}, timeout=15)
    print(f"robots.txt status={resp.status_code}")
    if resp.status_code in (401, 403):
        return None
    if resp.status_code != 200:
        return True  # no robots.txt => nothing disallowed
    rp = RobotFileParser()
    rp.parse(resp.text.splitlines())
    return rp.can_fetch(UA, url)


def count_events(node, hits=None):
    """Count dicts that look like events (have a title/name plus a date field)."""
    hits = [] if hits is None else hits
    if isinstance(node, dict):
        keys = {k.lower() for k in node}
        has_name = {"title", "name"} & keys
        has_date = {"date", "startdate", "startsat", "starttime", "start", "datetime"} & keys
        if has_name and has_date:
            hits.append(node)
        for v in node.values():
            count_events(v, hits)
    elif isinstance(node, list):
        for v in node:
            count_events(v, hits)
    return hits


def probe(url: str) -> None:
    print(f"\n=== {url}")
    ok = allowed(url)
    if ok is None:
        print("robots.txt is blocked for our user agent (likely bot protection); skipping")
        return
    if not ok:
        print("robots.txt DISALLOWS this URL; skipping")
        return
    r = requests.get(url, headers={"User-Agent": UA}, timeout=25)
    print(f"status={r.status_code} bytes={len(r.content)} final_url={r.url}")
    OUT.mkdir(exist_ok=True)
    name = re.sub(r"[^a-z0-9]+", "_", url.lower()).strip("_")[:80]
    (OUT / f"{name}.html").write_text(r.text, encoding="utf-8")

    soup = BeautifulSoup(r.text, "lxml")
    nd = soup.find("script", id="__NEXT_DATA__")
    print(f"__NEXT_DATA__: {'yes' if nd else 'no'}")
    if nd and nd.string:
        data = json.loads(nd.string)
        print("  top-level keys:", list(data)[:10])
        print("  pageProps keys:", list(data.get("props", {}).get("pageProps", {}))[:15])
        hits = count_events(data)
        print(f"  event-like objects: {len(hits)}")
        if hits:
            print("  sample:", json.dumps(hits[0], default=str)[:600])

    ld = soup.find_all("script", type="application/ld+json")
    print(f"JSON-LD blocks: {len(ld)}")
    for block in ld[:3]:
        try:
            d = json.loads(block.string or "{}")
            print("  @type:", d.get("@type") if isinstance(d, dict) else f"list[{len(d)}]")
        except json.JSONDecodeError:
            print("  (unparseable block)")

    print("Apollo state:", "yes" if "__APOLLO_STATE__" in r.text else "no")
    print("Sitemap hint:", "yes" if "sitemap" in r.text.lower() else "no")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for u in sys.argv[1:]:
        try:
            probe(u)
        except Exception as e:  # report, keep going
            print(f"ERROR {type(e).__name__}: {e}")
