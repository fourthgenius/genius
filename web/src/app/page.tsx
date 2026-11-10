import { cookies } from "next/headers";
import { CITIES, DEFAULT_CITY, cityBySlug } from "@/lib/cities";

export default async function Home() {
  const jar = await cookies();
  const city = cityBySlug(jar.get("genieus_city")?.value) ?? cityBySlug(DEFAULT_CITY)!;

  return (
    <main className="mx-auto max-w-5xl px-4 py-16">
      <h1 className="text-4xl font-bold tracking-tight">GenieUs</h1>
      <p className="mt-2 text-neutral-400">
        Electronic music events across India. Showing: <span className="text-neutral-100">{city.name}</span>
      </p>
      <ul className="mt-8 flex flex-wrap gap-2 text-sm">
        {CITIES.map((c) => (
          <li key={c.slug} className="rounded-full border border-neutral-800 px-3 py-1 text-neutral-300">
            {c.name}
          </li>
        ))}
      </ul>
    </main>
  );
}
