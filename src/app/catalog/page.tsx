import Link from "next/link";
import { copy } from "@/config/copy";
import { formatRupiah, hasFilters, parseCatalogQuery, SEARCH_MAX } from "@/lib/domain/catalog";
import { LISTING_CATEGORIES, LISTING_TYPES } from "@/lib/domain/listing";
import { LISTING_PHOTO_BUCKET } from "@/lib/domain/listing-photo";
import { CAMPUSES } from "@/lib/domain/profile";
import { createClient } from "@/lib/supabase/server";
import { CatalogFilters } from "@/ui/catalog-filters";
import { ListingCard } from "@/ui/listing-card";

// Only columns anon may read (0005): never seller_id or meetup_note.
const CARD_COLUMNS = "id, type, title, price, image_path, campus, status, created_at";

type Row = {
  id: string;
  type: "sale" | "donation";
  title: string;
  price: number | null;
  image_path: string;
  campus: keyof typeof copy.profile.campuses;
  status: string;
};

export default async function CatalogPage({ searchParams }: PageProps<"/catalog">) {
  const t = copy.catalog;
  const query = parseCatalogQuery(await searchParams);
  const supabase = await createClient();

  // F5.1: Available and Booked, newest first; F5.6: everything at once for now.
  let request = supabase.from("listings").select(CARD_COLUMNS).neq("status", "sold").order("created_at", { ascending: false });
  if (query.type) request = request.eq("type", query.type);
  if (query.category) request = request.eq("category", query.category);
  if (query.campus) request = request.eq("campus", query.campus);
  if (query.q) request = request.or(`title.ilike.*${query.q}*,description.ilike.*${query.q}*`);
  const { data, error } = await request.returns<Row[]>();
  if (error) throw new Error(`catalog: ${error.message}`);

  const storage = supabase.storage.from(LISTING_PHOTO_BUCKET);
  const filtered = hasFilters(query);

  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold text-ink">{copy.pages.catalog.title}</h1>
      <CatalogFilters
        values={query}
        types={LISTING_TYPES.map((code) => ({ code, name: t.types[code] }))}
        categories={LISTING_CATEGORIES.map((code) => ({ code, name: copy.listing.categories[code] }))}
        campuses={CAMPUSES.map((code) => ({ code, name: copy.profile.campuses[code] }))}
        maxSearch={SEARCH_MAX}
        showClear={filtered}
        text={t}
      />

      {data.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-2xl border border-border bg-surface p-8 text-center">
          {filtered ? (
            <>
              <p className="font-semibold text-ink">{t.emptyResults}</p>
              <p className="text-sm text-muted">{t.emptyResultsHint}</p>
            </>
          ) : (
            <>
              <p className="text-muted">{t.emptyAll}</p>
              <Link href="/post" className="flex min-h-11 items-center rounded-full bg-honey px-5 font-bold text-ink">
                {t.postCta}
              </Link>
            </>
          )}
        </div>
      ) : (
        <ul className="grid grid-cols-2 gap-3">
          {data.map((l) => (
            <li key={l.id}>
              <ListingCard
                href={`/listings/${l.id}`}
                imageUrl={storage.getPublicUrl(l.image_path).data.publicUrl}
                title={l.title}
                price={l.type === "donation" || l.price === null ? copy.listing.free : formatRupiah(l.price)}
                campus={copy.profile.campuses[l.campus] ?? l.campus}
                badge={l.status === "booked" ? t.booked : undefined}
              />
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
