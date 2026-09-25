// Must match supabase/migrations/0004_listing_photos.sql.
export const LISTING_PHOTO_BUCKET = "listing-photos";
export const PHOTO_MAX_BYTES = 2 * 1024 * 1024;

// PRD F4.2: longest side at most 1024 px after client-side compression.
export const PHOTO_MAX_SIDE = 1024;

// Scales (width, height) down to fit maxSide on the longest side; never scales up.
export function fitWithin(width: number, height: number, maxSide = PHOTO_MAX_SIDE) {
  const scale = Math.min(1, maxSide / Math.max(width, height));
  return { width: Math.round(width * scale), height: Math.round(height * scale) };
}

// "<user_id>/<random>.jpg": the folder is what Storage RLS checks (D-17.3).
export const photoPath = (userId: string, randomId: string) => `${userId}/${randomId}.jpg`;
