-- GenieUs: initial schema
-- Public read-only via RLS; all writes go through the service role (ingestion).

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- cities
-- ---------------------------------------------------------------------------
create table public.cities (
  id        smallint generated always as identity primary key,
  slug      text not null unique,
  name      text not null,
  state     text,
  lat       double precision not null,
  lng       double precision not null,
  -- bounding box used by the map to fit the camera
  min_lng   double precision not null,
  min_lat   double precision not null,
  max_lng   double precision not null,
  max_lat   double precision not null,
  -- alternate names scrapers may emit (e.g. Gurgaon, Navi Mumbai, Bengaluru)
  aliases   text[] not null default '{}',
  is_active boolean not null default true
);

-- ---------------------------------------------------------------------------
-- venues
-- ---------------------------------------------------------------------------
create table public.venues (
  id              uuid primary key default gen_random_uuid(),
  city_id         smallint not null references public.cities (id),
  name            text not null,
  normalized_name text not null,
  address         text,
  lat             double precision,
  lng             double precision,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (city_id, normalized_name)
);
create index venues_name_trgm_idx
  on public.venues using gin (normalized_name extensions.gin_trgm_ops);
create trigger venues_set_updated_at
  before update on public.venues
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- artists
-- ---------------------------------------------------------------------------
create table public.artists (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  normalized_name    text not null unique,
  spotify_id         text unique,
  popularity         smallint check (popularity between 0 and 100),
  image_url          text,
  genres             text[] not null default '{}',
  spotify_checked_at timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index artists_name_trgm_idx
  on public.artists using gin (normalized_name extensions.gin_trgm_ops);
create index artists_spotify_checked_idx
  on public.artists (spotify_checked_at nulls first);
create trigger artists_set_updated_at
  before update on public.artists
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------
create table public.events (
  id                uuid primary key default gen_random_uuid(),
  slug              text not null unique,
  title             text not null,
  description       text,
  starts_at         timestamptz not null,
  ends_at           timestamptz,
  -- local calendar date in Asia/Kolkata; set by ingestion, used as dedup blocking key
  event_date        date not null,
  city_id           smallint not null references public.cities (id),
  venue_id          uuid references public.venues (id),
  primary_artist_id uuid references public.artists (id),
  poster_url        text,
  -- resolved image per cascade: poster -> spotify -> none (UI renders gradient)
  image_url         text,
  image_source      text not null default 'none'
                      check (image_source in ('poster', 'spotify', 'none')),
  min_price         numeric(10, 2) check (min_price >= 0),
  currency          text not null default 'INR',
  ticket_url        text,
  -- exact Spotify popularity of the primary artist (0-100); null when unmatched
  hype_score        smallint check (hype_score between 0 and 100),
  status            text not null default 'scheduled'
                      check (status in ('scheduled', 'cancelled', 'sold_out')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index events_city_starts_idx on public.events (city_id, starts_at);
create index events_date_idx        on public.events (event_date);
create index events_starts_idx      on public.events (starts_at);
create index events_hype_idx        on public.events (hype_score desc nulls last);
create index events_venue_idx       on public.events (venue_id);
create index events_primary_artist_idx on public.events (primary_artist_id);
create index events_title_trgm_idx
  on public.events using gin (title extensions.gin_trgm_ops);
create trigger events_set_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- event_artists
-- ---------------------------------------------------------------------------
create table public.event_artists (
  event_id   uuid not null references public.events (id) on delete cascade,
  artist_id  uuid not null references public.artists (id) on delete cascade,
  is_primary boolean not null default false,
  position   smallint not null default 0,
  primary key (event_id, artist_id)
);
create index event_artists_artist_idx on public.event_artists (artist_id);
-- at most one primary artist per event
create unique index event_artists_one_primary_idx
  on public.event_artists (event_id) where is_primary;

-- ---------------------------------------------------------------------------
-- event_sources: one row per (source, source_event_id); links many sources
-- to one canonical event. Makes re-ingestion idempotent.
-- ---------------------------------------------------------------------------
create table public.event_sources (
  id              uuid primary key default gen_random_uuid(),
  event_id        uuid not null references public.events (id) on delete cascade,
  source          text not null,
  source_event_id text not null,
  source_url      text not null,
  raw_hash        text,
  first_seen_at   timestamptz not null default now(),
  last_seen_at    timestamptz not null default now(),
  unique (source, source_event_id)
);
create index event_sources_event_idx on public.event_sources (event_id);

-- ---------------------------------------------------------------------------
-- dedup_candidates: ambiguous fuzzy matches held for review instead of guessing
-- ---------------------------------------------------------------------------
create table public.dedup_candidates (
  id         uuid primary key default gen_random_uuid(),
  event_a_id uuid not null references public.events (id) on delete cascade,
  event_b_id uuid not null references public.events (id) on delete cascade,
  score      smallint not null check (score between 0 and 100),
  status     text not null default 'pending'
               check (status in ('pending', 'merged', 'rejected')),
  created_at timestamptz not null default now(),
  check (event_a_id <> event_b_id),
  unique (event_a_id, event_b_id)
);
create index dedup_candidates_b_idx on public.dedup_candidates (event_b_id);

-- ---------------------------------------------------------------------------
-- ingest_runs: per-source health log
-- ---------------------------------------------------------------------------
create table public.ingest_runs (
  id          uuid primary key default gen_random_uuid(),
  source      text not null,
  started_at  timestamptz not null default now(),
  finished_at timestamptz,
  status      text not null default 'running'
                check (status in ('running', 'success', 'failed')),
  fetched     integer not null default 0,
  upserted    integer not null default 0,
  error       text
);
create index ingest_runs_source_started_idx
  on public.ingest_runs (source, started_at desc);

-- ---------------------------------------------------------------------------
-- Row Level Security: public read on catalogue tables, nothing else.
-- dedup_candidates and ingest_runs have RLS on and no policies (service role only).
-- ---------------------------------------------------------------------------
alter table public.cities           enable row level security;
alter table public.venues           enable row level security;
alter table public.artists          enable row level security;
alter table public.events           enable row level security;
alter table public.event_artists    enable row level security;
alter table public.event_sources    enable row level security;
alter table public.dedup_candidates enable row level security;
alter table public.ingest_runs      enable row level security;

create policy "public read cities"        on public.cities        for select to anon, authenticated using (true);
create policy "public read venues"        on public.venues        for select to anon, authenticated using (true);
create policy "public read artists"       on public.artists       for select to anon, authenticated using (true);
create policy "public read events"        on public.events        for select to anon, authenticated using (true);
create policy "public read event_artists" on public.event_artists for select to anon, authenticated using (true);
create policy "public read event_sources" on public.event_sources for select to anon, authenticated using (true);

-- Defense in depth: strip write privileges from API roles.
revoke insert, update, delete, truncate on
  public.cities, public.venues, public.artists, public.events,
  public.event_artists, public.event_sources
  from anon, authenticated;
revoke all on public.dedup_candidates, public.ingest_runs from anon, authenticated;

-- ---------------------------------------------------------------------------
-- upcoming_events: denormalised read view for the frontend (respects RLS)
-- ---------------------------------------------------------------------------
create view public.upcoming_events
with (security_invoker = true) as
select
  e.id,
  e.slug,
  e.title,
  e.description,
  e.starts_at,
  e.ends_at,
  e.event_date,
  e.poster_url,
  e.image_url,
  e.image_source,
  e.min_price,
  e.currency,
  e.ticket_url,
  e.hype_score,
  e.status,
  c.slug  as city_slug,
  c.name  as city_name,
  v.name  as venue_name,
  v.address as venue_address,
  v.lat   as venue_lat,
  v.lng   as venue_lng,
  coalesce(
    (select jsonb_agg(
              jsonb_build_object('id', a.id, 'name', a.name, 'is_primary', ea.is_primary)
              order by ea.position)
       from public.event_artists ea
       join public.artists a on a.id = ea.artist_id
      where ea.event_id = e.id),
    '[]'::jsonb
  ) as artists
from public.events e
join public.cities c on c.id = e.city_id
left join public.venues v on v.id = e.venue_id
where e.status <> 'cancelled'
  and coalesce(e.ends_at, e.starts_at + interval '6 hours') >= now();

grant select on public.upcoming_events to anon, authenticated;
