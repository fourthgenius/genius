export type CitySlug =
  | "delhi-ncr"
  | "mumbai"
  | "bangalore"
  | "goa"
  | "pune"
  | "hyderabad";

export interface City {
  slug: CitySlug;
  name: string;
  lat: number;
  lng: number;
  /** [minLng, minLat, maxLng, maxLat] */
  bbox: [number, number, number, number];
}

// Mirrors supabase/migrations/..._seed_cities.sql. Kept static so the edge
// middleware can resolve the nearest city without a DB call.
export const CITIES: City[] = [
  { slug: "delhi-ncr", name: "Delhi NCR", lat: 28.6139, lng: 77.209, bbox: [76.84, 28.2, 77.65, 28.95] },
  { slug: "mumbai", name: "Mumbai", lat: 19.076, lng: 72.8777, bbox: [72.75, 18.85, 73.15, 19.35] },
  { slug: "bangalore", name: "Bangalore", lat: 12.9716, lng: 77.5946, bbox: [77.4, 12.8, 77.8, 13.2] },
  { slug: "goa", name: "Goa", lat: 15.4909, lng: 73.8278, bbox: [73.65, 14.9, 74.35, 15.8] },
  { slug: "pune", name: "Pune", lat: 18.5204, lng: 73.8567, bbox: [73.7, 18.4, 74.0, 18.7] },
  { slug: "hyderabad", name: "Hyderabad", lat: 17.385, lng: 78.4867, bbox: [78.25, 17.25, 78.65, 17.6] },
];

export const DEFAULT_CITY: CitySlug = "mumbai";

function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const rad = Math.PI / 180;
  const dLat = (bLat - aLat) * rad;
  const dLng = (bLng - aLng) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(aLat * rad) * Math.cos(bLat * rad) * Math.sin(dLng / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(h));
}

export function nearestCity(lat: number, lng: number): City {
  return CITIES.reduce((best, c) =>
    haversineKm(lat, lng, c.lat, c.lng) < haversineKm(lat, lng, best.lat, best.lng) ? c : best,
  );
}

export function cityBySlug(slug: string | undefined): City | undefined {
  return CITIES.find((c) => c.slug === slug);
}
