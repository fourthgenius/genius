# GenieUs

Free electronic-music event discovery for India's Tier-1 cities. Discovery and redirection only.

```
/web        Next.js (App Router) + Tailwind + MapLibre
/ingest     Python scrapers, fuzzy dedup, Spotify enrichment
/supabase   SQL migrations (source of truth for the schema)
```

## Setup
1. Create/choose a Supabase project; run the files in `supabase/migrations` in order.
2. Copy `.env.example` to `web/.env.local` and `ingest/.env`; fill in values.
3. Web: `cd web && npm install && npm run dev`
4. Ingest: `cd ingest && pip install -r requirements.txt && python -m genieus_ingest.run`
5. GitHub Actions secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`.
