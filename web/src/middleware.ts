import { NextResponse, type NextRequest } from "next/server";
import { DEFAULT_CITY, nearestCity } from "@/lib/cities";

export const CITY_COOKIE = "genieus_city";

// Resolves the visitor's nearest Tier-1 city from Vercel's free edge geo headers
// and stores it in a cookie. A user-chosen city (cookie already set) is never overwritten.
export function middleware(req: NextRequest) {
  const res = NextResponse.next();
  if (req.cookies.has(CITY_COOKIE)) return res;

  const lat = Number(req.headers.get("x-vercel-ip-latitude"));
  const lng = Number(req.headers.get("x-vercel-ip-longitude"));
  const slug =
    Number.isFinite(lat) && Number.isFinite(lng) && (lat !== 0 || lng !== 0)
      ? nearestCity(lat, lng).slug
      : DEFAULT_CITY;

  res.cookies.set(CITY_COOKIE, slug, { path: "/", maxAge: 60 * 60 * 24 * 30, sameSite: "lax" });
  return res;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\..*).*)"],
};
