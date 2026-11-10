from __future__ import annotations

from datetime import datetime, timezone
from functools import lru_cache

from supabase import Client, create_client

from .config import SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL


@lru_cache(maxsize=1)
def client() -> Client:
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def start_run(source: str) -> str:
    res = client().table("ingest_runs").insert({"source": source}).execute()
    return res.data[0]["id"]


def finish_run(
    run_id: str,
    *,
    ok: bool,
    fetched: int = 0,
    upserted: int = 0,
    error: str | None = None,
) -> None:
    client().table("ingest_runs").update(
        {
            "status": "success" if ok else "failed",
            "finished_at": datetime.now(timezone.utc).isoformat(),
            "fetched": fetched,
            "upserted": upserted,
            "error": error[:2000] if error else None,
        }
    ).eq("id", run_id).execute()
