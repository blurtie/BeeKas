import type { UserType } from "./campus-email";

// Shape of the fields read from the profiles row. Values may be null because
// the row is created empty at sign-up (supabase/migrations/0001_profiles.sql).
export type ProfileCompletenessInput = {
  user_type: UserType | string;
  nickname: string | null;
  whatsapp: string | null;
  campus: string | null;
  major: string | null;
  binusian: string | null;
};

const filled = (v: string | null | undefined) => typeof v === "string" && v.trim() !== "";

// Everyone needs nickname, WhatsApp and campus; students also need a BINUSIAN
// year (and major, once required again). Staff never have major/binusian.
export function isProfileComplete(p: ProfileCompletenessInput | null | undefined): boolean {
  if (!p) return false;
  if (!filled(p.nickname) || !filled(p.whatsapp) || !filled(p.campus)) return false;
  // TODO: PRD F2.3 requires major for students; make required again once MAJOR_GROUPS is filled.
  if (p.user_type === "student") return filled(p.binusian);
  return p.user_type === "staff";
}
