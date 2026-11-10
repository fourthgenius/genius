-- GenieUs Phase 1: RLS. Public read-only on display tables; writes only via service role
-- (service role bypasses RLS). Internal tables have RLS on and no policies => no public access.

alter table public.cities        enable row level security;
alter table public.venues        enable row level security;
alter table public.artists       enable row level security;
alter table public.events        enable row level security;
alter table public.event_artists enable row level security;
alter table public.event_sources enable row level security;
alter table public.dedup_review  enable row level security;
alter table public.ingest_runs   enable row level security;

create policy "public read cities"        on public.cities        for select to anon, authenticated using (true);
create policy "public read venues"        on public.venues        for select to anon, authenticated using (true);
create policy "public read artists"       on public.artists       for select to anon, authenticated using (true);
create policy "public read events"        on public.events        for select to anon, authenticated using (true);
create policy "public read event_artists" on public.event_artists for select to anon, authenticated using (true);

-- Defense in depth: no write privileges for public roles at all
revoke insert, update, delete, truncate on
  public.cities, public.venues, public.artists, public.events, public.event_artists
  from anon, authenticated;

-- Internal tables: no access for public roles
revoke all on public.event_sources, public.dedup_review, public.ingest_runs
  from anon, authenticated;
