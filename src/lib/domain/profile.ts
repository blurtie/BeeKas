import { z } from "zod";
import { campusEmailSchema, userTypeFromEmail, type UserType } from "./campus-email";

export type Option = { readonly code: string; readonly name: string };
export type MajorGroup = { readonly school: string; readonly majors: readonly Option[] };

// Source: BINUS curriculum site, 24 Sep 2026 (open points in docs/decisions.md).
// Codes must match the MAJORS block in supabase/migrations/0002_majors_campuses.sql.
export const MAJOR_GROUPS: readonly MajorGroup[] = [
  {
    school: "School of Computer Science",
    majors: [
      { code: "computer_science", name: "Computer Science" },
      { code: "mobile_application_technology", name: "Mobile Application and Technology" },
      { code: "mathematics_computer_science", name: "Mathematics & Computer Science" },
      { code: "statistics_computer_science", name: "Statistics & Computer Science" },
      { code: "game_application_technology", name: "Game Application and Technology" },
      { code: "cyber_security", name: "Cyber Security" },
      { code: "data_science", name: "Data Science" },
      { code: "software_engineering", name: "Software Engineering" },
      { code: "artificial_intelligence", name: "Artificial Intelligence" },
    ],
  },
  {
    school: "School of Information Systems",
    majors: [
      { code: "information_systems", name: "Information Systems" },
      { code: "business_information_technology", name: "Business Information Technology" },
      { code: "business_analytics", name: "Business Analytics" },
      { code: "digital_business_innovation", name: "Digital Business Innovation" },
    ],
  },
  {
    school: "School of Design",
    majors: [
      { code: "visual_communication_design", name: "Visual Communication Design" },
      { code: "interior_design", name: "Interior Design" },
      { code: "film", name: "Film" },
      { code: "fashion", name: "Fashion" },
    ],
  },
  {
    school: "Faculty of Engineering",
    majors: [
      { code: "architecture", name: "Architecture" },
      { code: "civil_engineering", name: "Civil Engineering" },
      { code: "industrial_engineering", name: "Industrial Engineering" },
      { code: "computer_engineering", name: "Computer Engineering" },
      { code: "food_technology", name: "Food Technology" },
      { code: "biotechnology", name: "Biotechnology" },
    ],
  },
  {
    school: "BINUS ASO School of Engineering",
    majors: [
      { code: "automotive_robotics_engineering", name: "Automotive & Robotics Engineering" },
      { code: "product_design_engineering", name: "Product Design Engineering" },
      { code: "business_engineering", name: "Business Engineering" },
    ],
  },
  {
    school: "Faculty of Humanities",
    majors: [
      { code: "global_business_chinese", name: "Global Business Chinese" },
      { code: "creative_digital_english", name: "Creative Digital English" },
      { code: "japanese_popular_culture", name: "Japanese Popular Culture" },
      { code: "psychology", name: "Psychology" },
      { code: "digital_psychology", name: "Digital Psychology" },
      { code: "business_law", name: "Business Law" },
      { code: "international_relations", name: "International Relations" },
      { code: "primary_teacher_education", name: "Primary Teacher Education" },
    ],
  },
  {
    school: "School of Accounting",
    majors: [
      { code: "accounting", name: "Accounting" },
      { code: "finance", name: "Finance" },
      { code: "taxation", name: "Taxation" },
    ],
  },
  {
    school: "Faculty of Digital Communication and Hotel & Tourism",
    majors: [
      { code: "hotel_management", name: "Hotel Management" },
      { code: "business_hotel_management", name: "Business Hotel Management" },
      { code: "tourism", name: "Tourism" },
      { code: "marketing_communication", name: "Marketing Communication" },
      { code: "mass_communication", name: "Mass Communication" },
      { code: "creative_communication", name: "Creative Communication" },
    ],
  },
  {
    school: "BINUS Business School",
    majors: [
      { code: "management", name: "Management" },
      { code: "global_business_marketing", name: "Global Business Marketing" },
      { code: "international_business_management", name: "International Business Management" },
      { code: "business_creation", name: "Business Creation" },
      { code: "business_management", name: "Business Management" },
      { code: "international_business", name: "International Business" },
      { code: "business_management_marketing", name: "Business Management & Marketing" },
      { code: "digital_business", name: "Digital Business" },
      { code: "creativepreneurship", name: "Creativepreneurship" },
      { code: "entrepreneurship_business_creation", name: "Entrepreneurship Business Creation" },
      { code: "international_trade", name: "International Trade" },
    ],
  },
  {
    school: "BINUS International",
    majors: [
      { code: "intl_computer_science", name: "Computer Science (International)" },
      { code: "intl_business_information_systems", name: "Business Information Systems (International)" },
      { code: "intl_graphic_design_new_media", name: "Graphic Design & New Media (International)" },
      { code: "intl_communication", name: "Communication (International)" },
      { code: "intl_creative_digital_communication", name: "Creative Digital Communication (International)" },
    ],
  },
  {
    school: "BINUS Online",
    majors: [
      { code: "online_computer_science", name: "Computer Science (Online)" },
      { code: "online_information_systems", name: "Information Systems (Online)" },
      { code: "online_business_management", name: "Business Management (Online)" },
      { code: "online_finance", name: "Finance (Online)" },
      { code: "online_industrial_engineering", name: "Industrial Engineering (Online)" },
      { code: "online_data_science", name: "Data Science (Online)" },
      { code: "online_business_analytics", name: "Business Analytics (Online)" },
      { code: "online_digital_business_management", name: "Digital Business Management (Online)" },
    ],
  },
];
export const OTHER_MAJOR = "other";

// Stable campus codes; display labels live in src/config/copy.ts.
// Must match the CAMPUSES block in supabase/migrations/0002_majors_campuses.sql.
export const CAMPUSES = [
  "kemanggisan",
  "senayan",
  "alam_sutera",
  "base",
  "bekasi",
  "bandung",
  "malang",
  "semarang",
  "online",
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
        if (major === null) issue("major", "major_required");
        else if (!majors.has(major)) issue("major", "invalid_major");
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
