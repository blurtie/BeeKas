import { describe, expect, it } from "vitest";
import { campusEmailSchema, userTypeFromEmail } from "./campus-email";

describe("campus email", () => {
  it("accepts both campus domains and derives the user type", () => {
    expect(userTypeFromEmail("budi@binus.ac.id")).toBe("student");
    expect(userTypeFromEmail("sari@binus.edu")).toBe("staff");
    expect(campusEmailSchema.safeParse("budi@binus.ac.id").success).toBe(true);
    expect(campusEmailSchema.safeParse("sari@binus.edu").success).toBe(true);
  });

  it("normalizes case and surrounding whitespace", () => {
    expect(campusEmailSchema.parse("  Budi.Santoso@BINUS.AC.ID ")).toBe("budi.santoso@binus.ac.id");
    expect(userTypeFromEmail(" Sari@Binus.Edu")).toBe("staff");
  });

  it.each([
    "x@evilbinus.ac.id",
    "x@binus.ac.id.evil.com",
    "x@mail.binus.ac.id",
    "x@binus.edu.id",
    "x@gmail.com",
    "binus.ac.id",
    "x",
    "@binus.ac.id",
    "",
  ])("rejects %j", (email) => {
    expect(userTypeFromEmail(email)).toBeNull();
    expect(campusEmailSchema.safeParse(email).success).toBe(false);
  });
});
