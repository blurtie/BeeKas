import { describe, expect, it } from "vitest";
import { isProfileComplete, type ProfileCompletenessInput } from "./profile-completeness";

const student: ProfileCompletenessInput = {
  user_type: "student",
  nickname: "Budi",
  whatsapp: "6281234567890",
  campus: "alam_sutera",
  major: "other",
  binusian: "B28",
};
const staff: ProfileCompletenessInput = { ...student, user_type: "staff", major: null, binusian: null };

describe("isProfileComplete", () => {
  it("accepts complete student and staff profiles", () => {
    expect(isProfileComplete(student)).toBe(true);
    expect(isProfileComplete(staff)).toBe(true);
  });

  it("rejects missing rows", () => {
    expect(isProfileComplete(null)).toBe(false);
    expect(isProfileComplete(undefined)).toBe(false);
  });

  it.each(["nickname", "whatsapp", "campus"] as const)("requires %s for everyone", (field) => {
    expect(isProfileComplete({ ...student, [field]: null })).toBe(false);
    expect(isProfileComplete({ ...staff, [field]: null })).toBe(false);
    expect(isProfileComplete({ ...staff, [field]: "   " })).toBe(false);
  });

  it.each(["major", "binusian"] as const)("requires %s for students only", (field) => {
    expect(isProfileComplete({ ...student, [field]: null })).toBe(false);
    expect(isProfileComplete({ ...student, [field]: "" })).toBe(false);
    expect(isProfileComplete(staff)).toBe(true);
  });

  it("rejects an unknown user type", () => {
    expect(isProfileComplete({ ...staff, user_type: "admin" })).toBe(false);
  });
});
