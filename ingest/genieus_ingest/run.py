"""Entry point: python -m genieus_ingest.run

Runs every registered source in isolation. Each run is logged to ingest_runs,
which also keeps the Supabase free-tier project from pausing.
"""
from __future__ import annotations

import logging
import sys
import traceback

from . import db
from .sources import SOURCES

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("genieus.ingest")


def main() -> int:
    if not SOURCES:
        log.info("No sources registered yet; pinging database only.")
        db.client().table("cities").select("id").limit(1).execute()
        return 0

    failures = 0
    for source_cls in SOURCES:
        source = source_cls()
        run_id = db.start_run(source.name)
        try:
            events = list(source.fetch())
            # TODO (Phase 2/3): normalize -> dedup -> enrich -> upsert
            db.finish_run(run_id, ok=True, fetched=len(events), upserted=0)
            log.info("%s: fetched %d events", source.name, len(events))
        except Exception:
            failures += 1
            err = traceback.format_exc()
            log.error("%s failed:\n%s", source.name, err)
            db.finish_run(run_id, ok=False, error=err)

    # Fail the job only if every source failed.
    return 1 if failures == len(SOURCES) else 0


if __name__ == "__main__":
    sys.exit(main())
