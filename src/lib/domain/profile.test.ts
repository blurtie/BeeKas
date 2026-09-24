import { describe, expect, it } from "vitest";
import { CAMPUSES, createProfileSchema, majorCodes, normalizeWhatsapp, profileSchema, whatsappSchema } from "./profile";

// Fixture lists: the official majors and campuses are not available yet.
const schema = createProfileSchema({
  majorGroups: [{ school: "School A", majors: [{ code: "maj_a", name: "Major A" }] }],
  campuses: ["camp_a"],
});
const student = {
  nickname: " Bee ",
  email: "Bee@Binus.ac.id",
  whatsapp: "0812-3456-7890",
  campus: "camp_a",
  major: "maj_a",
  binusian: "B28",
};
const staff = { nickname: "Kas", email: "kas@binus.edu", whatsapp: "+62 812 3456 789", campus: "camp_a" };
const codes = (r: { error?: { issues: { message: string }[] } }) => r.error?.issues.map((i) => i.message) ?? [];

describe("normalizeWhatsapp", () => {
  it.each([
    ["081234567890", "6281234567890"],
    ["6281234567890", "6281234567890"],
    ["+62 812-3456-7890", "6281234567890"],
    ["0812345678", "62812345678"],
    ["0812345678901", "62812345678901"],
  ])("%s -> %s", (i, o) => expect(normalizeWhatsapp(i)).toBe(o));

  it.each(["081234567", "08123456789012", "0212345678", "12345678901", "0812a4567890", "", "+6208123456789"])(
    "rejects %j",
    (i) => expect(normalizeWhatsapp(i)).toBeNull(),
  );

  it("schema emits invalid_whatsapp", () => {
    expect(codes(whatsappSchema.safeParse("123"))).toEqual(["invalid_whatsapp"]);
  });
});

describe("profile schema", () => {
  it("parses a student and derives user_type", () => {
    expect(schema.parse(student)).toEqual({
      nickname: "Bee",
      email: "bee@binus.ac.id",
      user_type: "student",
      whatsapp: "6281234567890",
      campus: "camp_a",
      major: "maj_a",
      binusian: "B28",
    });
  });

  it("accepts the other major", () => {
    expect(schema.parse({ ...student, major: "other" }).major).toBe("other");
  });

  it("parses staff with null major and binusian", () => {
    const p = schema.parse(staff);
    expect(p.user_type).toBe("staff");
    expect(p.major).toBeNull();
    expect(p.binusian).toBeNull();
  });

  it("ignores a user_type supplied in input", () => {
    expect(schema.parse({ ...staff, user_type: "student" }).user_type).toBe("staff");
  });

  // TODO: PRD F2.3 requires major for students; make required again once MAJOR_GROUPS is filled.
  it("requires binusian but (temporarily) not major for students", () => {
    expect(codes(schema.safeParse({ ...student, major: undefined, binusian: null }))).toEqual([
      "binusian_required",
    ]);
    expect(schema.parse({ ...student, major: null }).major).toBeNull();
  });

  it("rejects unknown major, binusian and campus", () => {
    expect(codes(schema.safeParse({ ...student, major: "x", binusian: "B26" }))).toEqual([
      "invalid_major",
      "invalid_binusian",
    ]);
    expect(codes(schema.safeParse({ ...student, campus: "y" }))).toEqual(["invalid_campus"]);
  });

  it("rejects major and binusian for staff", () => {
    expect(codes(schema.safeParse({ ...staff, major: "other", binusian: "B27" }))).toEqual([
      "major_not_allowed",
      "binusian_not_allowed",
    ]);
  });

  it("validates nickname and email", () => {
    expect(codes(schema.safeParse({ ...student, nickname: " a " }))).toEqual(["nickname_too_short"]);
    expect(schema.parse({ ...student, nickname: " ab " }).nickname).toBe("ab");
    expect(codes(schema.safeParse({ ...student, nickname: "  " }))).toContain("nickname_required");
    expect(codes(schema.safeParse({ ...student, nickname: "x".repeat(31) }))).toContain("nickname_too_long");
    expect(codes(schema.safeParse({ ...student, email: "a@gmail.com" }))).toContain("not_campus_domain");
  });

  it("default lists: only the other major, campus codes in order", () => {
    expect(majorCodes([])).toEqual(["other"]);
    expect(CAMPUSES[0]).toBe("anggrek");
    expect(CAMPUSES).toHaveLength(11);
    expect(codes(profileSchema.safeParse(student))).toContain("invalid_campus");
    expect(profileSchema.parse({ ...student, campus: "alam_sutera", major: "other" }).campus).toBe("alam_sutera");
  });
});
