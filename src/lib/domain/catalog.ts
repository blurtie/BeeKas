import { LISTING_CATEGORIES, LISTING_TYPES, type ListingCategory, type ListingType } from "./listing";
import { CAMPUSES, type CampusCode } from "./profile";

export const SEARCH_MAX = 100;

export type CatalogQuery = {
  q?: string;
  type?: ListingType;
  category?: ListingCategory;
  campus?: CampusCode;
};

type Params = Record<string, string | string[] | undefined>;

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);
const pick = <T extends string>(list: readonly T[], v: string | undefined) =>
  list.includes(v as T) ? (v as T) : undefined;

// URL search params -> a valid catalog query. Unknown values are dropped, not errors.
export function parseCatalogQuery(params: Params): CatalogQuery {
  // Characters that would break the PostgREST or-filter / ilike pattern become spaces.
  const q = first(params.q)?.replace(/[,()*%_\\]/g, " ").replace(/\s+/g, " ").trim().slice(0, SEARCH_MAX);
  const out: CatalogQuery = {
    q: q || undefined,
    type: pick(LISTING_TYPES, first(params.type)),
    category: pick(LISTING_CATEGORIES, first(params.category)),
    campus: pick(CAMPUSES, first(params.campus)),
  };
  return Object.fromEntries(Object.entries(out).filter(([, v]) => v !== undefined)) as CatalogQuery;
}

export const hasFilters = (q: CatalogQuery) => Object.keys(q).length > 0;

// 150000 -> "Rp150.000" (Indonesian grouping, whole rupiah).
export const formatRupiah = (n: number) => `Rp${new Intl.NumberFormat("id-ID", { maximumFractionDigits: 0 }).format(n)}`;
