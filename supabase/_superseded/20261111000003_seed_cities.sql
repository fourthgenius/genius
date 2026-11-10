-- GenieUs Phase 0: Tier-1 city seed. Bounding boxes are approximate and include
-- adjacent party/suburb areas (e.g. Gurgaon/Noida, Navi Mumbai, North Goa).

insert into public.cities (slug, name, lat, lng, bbox_min_lng, bbox_min_lat, bbox_max_lng, bbox_max_lat) values
  ('delhi-ncr',  'Delhi NCR', 28.6139, 77.2090, 76.85, 28.30, 77.55, 28.88),
  ('mumbai',     'Mumbai',    19.0760, 72.8777, 72.75, 18.85, 73.10, 19.35),
  ('bangalore',  'Bangalore', 12.9716, 77.5946, 77.40, 12.80, 77.80, 13.15),
  ('goa',        'Goa',       15.4909, 73.8278, 73.65, 14.85, 74.35, 15.80),
  ('pune',       'Pune',      18.5204, 73.8567, 73.70, 18.40, 74.00, 18.65),
  ('hyderabad',  'Hyderabad', 17.3850, 78.4867, 78.25, 17.25, 78.65, 17.60)
on conflict (slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  bbox_min_lng = excluded.bbox_min_lng, bbox_min_lat = excluded.bbox_min_lat,
  bbox_max_lng = excluded.bbox_max_lng, bbox_max_lat = excluded.bbox_max_lat;
