import { z } from "zod";
import { campusEmailSchema, userTypeFromEmail, type UserType } from "./campus-email";

export type Option = { readonly code: string; readonly name: string };
export type MajorGroup = { readonly school: string; readonly majors: readonly Option[] };

// TODO: official list pending from team
export const MAJOR_GROUPS: readonly MajorGroup[] = [];
export const OTHER_MAJOR = "other";

// Stable campus codes; display labels live in src/config/copy.ts.
// verify with team
export const CAMPUSES = [
  "anggrek",
  "syahdan",
  "kijang",
  "jwc",
  "fx",
  "alam_sutera",
  "base",
  "bekasi",
  "bandung",
  "malang",
  "semarang",
] as const;
export type CampusCode = (typeof CAMPUSES)[number];

// BINUSIAN cohort label = graduation year.
export const BINUSIANS = ["B27", "B28", "B29", "B30"] as const;
export type Binusian = (typeof BINUSIANS)[number];

export const NICKNAME_MIN = 2;
export const NICKNAME_MAX = 30;

// Accepts 08..., 62..., +62... with spaces/dashes; returns "62..." or null.
// Indonesian mobile numbers are 08 + 8..11 digits (10-13 digits total),
// so after "62" we require "8" followed by 8..11 digits (9-12 digits).
export function normalizeWhatsapp(input: string): string | null {
  const s = input.replace(/[\s-]/g, "");
  let national: string;
  if (s.startsWith("+62")) national = s.slice(3);
  else if (s.startsWith("62")) national = s.slice(2);
  else if (s.startsWith("0")) national = s.slice(1);
  else return null;
  return /^8[0-9]{8,11}$/.test(national) ? `62${national}` : null;
}

export const whatsappSchema = z.string().transform((v, ctx) => {
  const n = normalizeWhatsapp(v);
  if (n === null) {
    ctx.addIssue({ code: "custom", message: "invalid_whatsapp" });
    return z.NEVER;
  }
  return n;
});

// All selectable major codes, always including "other".
export function majorCodes(groups: readonly MajorGroup[]): string[] {
  return [...groups.flatMap((g) => g.majors.map((m) => m.code)), OTHER_MAJOR];
}

export type ProfileLists = { majorGroups: readonly MajorGroup[]; campuses: readonly string[] };

export type Profile = {
  nickname: string;
  email: string;
  user_type: UserType;
  whatsapp: string;
  campus: string;
  major: string | null;
  binusian: Binusian | null;
};

// user_type is derived from email, never read from input (PRD F2).
// Students must give major + binusian; staff must give neither.
export function createProfileSchema(lists: ProfileLists) {
  const majors = new Set(majorCodes(lists.majorGroups));
  const campuses = new Set(lists.campuses);
  return z
    .object({
      nickname: z
        .string()
        .trim()
        .min(1, { error: "nickname_required" })
        .min(NICKNAME_MIN, { error: "nickname_too_short" })
        .max(NICKNAME_MAX, { error: "nickname_too_long" }),
      email: campusEmailSchema,
      whatsapp: whatsappSchema,
      campus: z.string().refine((c) => campuses.has(c), { error: "invalid_campus" }),
      major: z.string().nullish(),
      binusian: z.string().nullish(),
    })
    .transform((v, ctx): Profile => {
      const user_type = userTypeFromEmail(v.email) as UserType;
      const major = v.major ?? null;
      const binusian = v.binusian ?? null;
      const issue = (path: string, message: string) =>
        ctx.addIssue({ code: "custom", path: [path], message });
      if (user_type === "student") {
        // TODO: PRD F2.3 requires major for students; make required again once MAJOR_GROUPS is filled.
        // Until then major is optional for students (major_required is not raised).
        if (major !== null && !majors.has(major)) issue("major", "invalid_major");
        if (binusian === null) issue("binusian", "binusian_required");
        else if (!(BINUSIANS as readonly string[]).includes(binusian)) issue("binusian", "invalid_binusian");
      } else {
        if (major !== null) issue("major", "major_not_allowed");
        if (binusian !== null) issue("binusian", "binusian_not_allowed");
      }
      return {
        nickname: v.nickname,
        email: v.email,
        user_type,
        whatsapp: v.whatsapp,
        campus: v.campus,
        major,
        binusian: binusian as Binusian | null,
      };
    });
}

export const profileSchema = createProfileSchema({ majorGroups: MAJOR_GROUPS, campuses: CAMPUSES });
