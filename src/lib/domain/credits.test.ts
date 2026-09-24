import { expect, it } from "vitest";
import { adjustmentSchema } from "./credits";

const target = "7c9e6679-7425-40de-944b-e07fc1f90ae7";
const codes = (input: unknown) => adjustmentSchema.safeParse(input).error?.issues.map((i) => i.message) ?? [];

it("accepts a positive or negative whole delta with a note", () => {
  expect(adjustmentSchema.parse({ target, delta: "3", note: " Tester " })).toEqual({ target, delta: 3, note: "Tester" });
  expect(adjustmentSchema.parse({ target, delta: "-2", note: "Fix" }).delta).toBe(-2);
});

it("rejects zero, fractional and non-numeric deltas", () => {
  for (const delta of ["0", "1.5", "abc"]) expect(codes({ target, delta, note: "x" })).toContain("invalid_delta");
});

it("requires a note of at most 200 characters", () => {
  expect(codes({ target, delta: "1", note: "   " })).toContain("note_required");
  expect(codes({ target, delta: "1", note: "a".repeat(201) })).toContain("note_too_long");
});

it("requires a member id", () => {
  expect(codes({ target: "", delta: "1", note: "x" })).toContain("member_required");
});
