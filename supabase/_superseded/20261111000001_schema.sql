-- GenieUs Phase 1: core schema
-- Idempotent ingestion is driven by event_sources (source + source_event_id).

create extension if not exists pg_trgm with schema extensions;

-- Shared updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Cities ---------------------------------------------------------------
create table public.cities (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  lat         double precision not null,
  lng         double precision not null,
  bbox_min_lng double precision not null,
  bbox_min_lat double precision not null,
  bbox_max_lng double precision not null,
  bbox_max_lat double precision not null,
  created_at  timestamptz not null default now()
);

-- Venues ---------------------------------------------------------------
create table public.venues (
  id               uuid primary key default gen_random_uuid(),
  city_id          uuid not null references public.cities(id) on delete restrict,
  name             text not null,
  normalized_name  text not null,
  address          text,
  lat              double precision,
  lng              double precision,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (city_id, normalized_name)
);
create index venues_city_idx on public.venues (city_id);
create index venues_name_trgm_idx on public.venues using gin (normalized_name extensions.gin_trgm_ops);
create trigger venues_set_updated_at before update on public.venues
  for each row execute function public.set_updated_at();

-- Artists --------------------------------------------------------------
create table public.artists (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  normalized_name     text not null unique,
  spotify_id          text unique,
  popularity          smallint check (popularity between 0 and 100),
  image_url           text,
  spotify_checked_at  timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index artists_name_trgm_idx on public.artists using gin (normalized_name extensions.gin_trgm_ops);
create index artists_spotify_stale_idx on public.artists (spotify_checked_at nulls first);
create trigger artists_set_updated_at before update on public.artists
  for each row execute function public.set_updated_at();

-- Events ---------------------------------------------------------------
create table public.events (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  starts_at    timestamptz not null,
  ends_at      timestamptz,
  city_id      uuid not null references public.cities(id) on delete restrict,
  venue_id     uuid references public.venues(id) on delete set null,
  poster_url   text,                 -- scraped official poster (cascade step 1)
  image_url    text,                 -- resolved cascade: poster -> spotify artist image; null => UI gradient tile
  min_price    numeric(10,2),        -- INR, lowest ticket price; null = unknown/free
  ticket_url   text not null,
  hype_score   smallint check (hype_score between 0 and 100),  -- null when Spotify has no match
  status       text not null default 'scheduled'
               check (status in ('scheduled', 'cancelled', 'sold_out')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index events_city_starts_idx on public.events (city_id, starts_at);
create index events_starts_idx on public.events (starts_at);
create index events_hype_idx on public.events (hype_score desc nulls last);
create index events_venue_idx on public.events (venue_id);
create trigger events_set_updated_at before update on public.events
  for each row execute function public.set_updated_at();

-- Event <-> artist -----------------------------------------------------
create table public.event_artists (
  event_id    uuid not null references public.events(id) on delete cascade,
  artist_id   uuid not null references public.artists(id) on delete cascade,
  is_primary  boolean not null default false,
  position    smallint not null default 0,
  primary key (event_id, artist_id)
);
create index event_artists_artist_idx on public.event_artists (artist_id);
create unique index event_artists_one_primary_idx
  on public.event_artists (event_id) where is_primary;

-- Event sources (dedup + idempotent re-ingestion) -----------------------
create table public.event_sources (
  id               uuid primary key default gen_random_uuid(),
  event_id         uuid not null references public.events(id) on delete cascade,
  source           text not null,            -- 'resident_advisor' | 'sortmyscene' | 'skillbox' | ...
  source_event_id  text not null,
  source_url       text not null,
  raw_hash         text not null,            -- hash of normalized payload; skip upsert when unchanged
  last_seen_at     timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  unique (source, source_event_id)
);
create index event_sources_event_idx on public.event_sources (event_id);
create index event_sources_last_seen_idx on public.event_sources (source, last_seen_at);

-- Ambiguous dedup matches awaiting review --------------------------------
create table public.dedup_review (
  id                uuid primary key default gen_random_uuid(),
  source            text not null,
  source_event_id   text not null,
  existing_event_id uuid not null references public.events(id) on delete cascade,
  score             smallint not null check (score between 0 and 100),
  payload           jsonb not null,
  status            text not null default 'pending'
                    check (status in ('pending', 'merged', 'rejected')),
  created_at        timestamptz not null default now(),
  unique (source, source_event_id, existing_event_id)
);
create index dedup_review_status_idx on public.dedup_review (status);

-- Ingestion run log (health checks, Phase 8) -----------------------------
create table public.ingest_runs (
  id                uuid primary key default gen_random_uuid(),
  source            text not null,
  started_at        timestamptz not null default now(),
  finished_at       timestamptz,
  status            text not null default 'running'
                    check (status in ('running', 'success', 'partial', 'failed')),
  events_seen       integer not null default 0,
  events_upserted   integer not null default 0,
  error             text
);
create index ingest_runs_source_started_idx on public.ingest_runs (source, started_at desc);
