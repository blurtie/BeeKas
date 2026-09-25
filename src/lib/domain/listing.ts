import { z } from "zod";
import { CAMPUSES } from "./profile";

// Each list must match its BEGIN/END block in supabase/migrations/0005_listings.sql.
export const LISTING_TYPES = ["sale", "donation"] as const;
export const LISTING_CATEGORIES = ["books", "lab", "electronics", "dorm", "other"] as const;
export const LISTING_CONDITIONS = ["like_new", "good", "used"] as const;
export type ListingType = (typeof LISTING_TYPES)[number];
export type ListingCategory = (typeof LISTING_CATEGORIES)[number];
export type ListingCondition = (typeof LISTING_CONDITIONS)[number];

// D-17.8 (provisional): whole rupiah, Rp1.000 to Rp100.000.000.
export const PRICE_MIN = 1_000;
export const PRICE_MAX = 100_000_000;
export const TITLE_MIN = 3;
export const TITLE_MAX = 80;
export const DESCRIPTION_MAX = 1000;
export const MEETUP_NOTE_MAX = 100;

// "150.000", "150 000" and "150000" all mean 150000. Anything else (e.g. "1,5") stays invalid.
export const parsePrice = (raw: string) => {
  const digits = raw.replace(/[.\s]/g, "");
  return /^\d+$/.test(digits) ? Number(digits) : NaN;
};

const base = {
  title: z.string().trim().min(TITLE_MIN, "title_too_short").max(TITLE_MAX, "title_too_long"),
  category: z.enum(LISTING_CATEGORIES, "invalid_category"),
  condition: z.enum(LISTING_CONDITIONS, "invalid_condition"),
  description: z.string().trim().min(1, "description_required").max(DESCRIPTION_MAX, "description_too_long"),
  campus: z.enum(CAMPUSES, "invalid_campus"),
  meetup_note: z
    .string()
    .trim()
    .max(MEETUP_NOTE_MAX, "meetup_note_too_long")
    .transform((s) => s || null),
  image_path: z.string().min(1, "photo_required"),
  agree: z.literal(true, "agree_required"),
};

export const listingSchema = z.discriminatedUnion(
  "type",
  [
    z.object({
      ...base,
      type: z.literal("sale"),
      price: z
        .string()
        .transform(parsePrice)
        .pipe(
          z
            .number("invalid_price")
            .int("invalid_price")
            .min(PRICE_MIN, "price_out_of_range")
            .max(PRICE_MAX, "price_out_of_range"),
        ),
    }),
    // F4.1: a Donation listing has no price, whatever the form sent.
    z.object({ ...base, type: z.literal("donation"), price: z.any().transform(() => null) }),
  ],
  "invalid_type",
);

export type ListingInput = z.infer<typeof listingSchema>;
