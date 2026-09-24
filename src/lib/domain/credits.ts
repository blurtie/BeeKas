import { z } from "zod";

// Must match the CREDIT_REASONS block in supabase/migrations/0003_credit_ledger.sql.
export const CREDIT_REASONS = ["purchase", "listing_publish", "signup_bonus", "admin_adjustment"] as const;
export type CreditReason = (typeof CREDIT_REASONS)[number];

export const ADJUSTMENT_NOTE_MAX = 200;

// Client-side mirror of admin_adjust_credits' input rules; Postgres stays the authority.
export const adjustmentSchema = z.object({
  target: z.uuid("member_required"),
  delta: z.coerce
    .number("invalid_delta")
    .int("invalid_delta")
    .refine((n) => n !== 0, "invalid_delta"),
  note: z
    .string()
    .trim()
    .min(1, "note_required")
    .max(ADJUSTMENT_NOTE_MAX, "note_too_long"),
});
