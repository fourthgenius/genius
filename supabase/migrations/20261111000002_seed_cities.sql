-- Tier-1 launch cities. Bounding boxes are approximate metro extents (lng/lat).
insert into public.cities
  (slug, name, state, lat, lng, min_lng, min_lat, max_lng, max_lat, aliases)
values
  ('delhi-ncr', 'Delhi NCR', 'Delhi',       28.6139, 77.2090, 76.84, 28.20, 77.65, 28.95,
     array['delhi','new delhi','gurgaon','gurugram','noida','greater noida','faridabad','ghaziabad']),
  ('mumbai',    'Mumbai',    'Maharashtra', 19.0760, 72.8777, 72.75, 18.85, 73.15, 19.35,
     array['bombay','navi mumbai','thane']),
  ('bangalore', 'Bangalore', 'Karnataka',   12.9716, 77.5946, 77.40, 12.80, 77.80, 13.20,
     array['bengaluru']),
  ('goa',       'Goa',       'Goa',         15.4909, 73.8278, 73.65, 14.90, 74.35, 15.80,
     array['panaji','panjim','north goa','south goa','vagator','anjuna','baga','candolim','morjim','arambol']),
  ('pune',      'Pune',      'Maharashtra', 18.5204, 73.8567, 73.70, 18.40, 74.00, 18.70,
     array['poona','pimpri-chinchwad']),
  ('hyderabad', 'Hyderabad', 'Telangana',   17.3850, 78.4867, 78.25, 17.25, 78.65, 17.60,
     array['secunderabad'])
on conflict (slug) do nothing;
