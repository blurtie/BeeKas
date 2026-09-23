import { z } from "zod";

// Single source of truth for accepted sign-up domains (PRD F1.2).
// The user type is derived from the domain, never chosen by the user (PRD F2.2).
export const ALLOWED_EMAIL_DOMAINS = {
  "binus.ac.id": "student",
  "binus.edu": "staff",
} as const;

export type CampusDomain = keyof typeof ALLOWED_EMAIL_DOMAINS;
export type UserType = (typeof ALLOWED_EMAIL_DOMAINS)[CampusDomain];

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

// Exact match on the part after the last "@": subdomains and look-alike
// domains (evilbinus.ac.id, binus.ac.id.evil.com) are rejected.
export function userTypeFromEmail(email: string): UserType | null {
  const normalized = normalizeEmail(email);
  const at = normalized.lastIndexOf("@");
  if (at <= 0) return null;
  const domain = normalized.slice(at + 1);
  return Object.hasOwn(ALLOWED_EMAIL_DOMAINS, domain)
    ? ALLOWED_EMAIL_DOMAINS[domain as CampusDomain]
    : null;
}

export const campusEmailSchema = z
  .string()
  .transform(normalizeEmail)
  .pipe(z.email())
  .refine((email) => userTypeFromEmail(email) !== null, { error: "not_campus_domain" });
