import { describe, expect, it } from "vitest";
import { safeNextPath } from "./safe-redirect";

describe("safeNextPath", () => {
  it("keeps same-origin relative paths", () => {
    expect(safeNextPath("/post")).toBe("/post");
    expect(safeNextPath("/profile/complete?next=%2Fpost")).toBe("/profile/complete?next=%2Fpost");
  });

  it.each([
    null,
    undefined,
    "",
    "post",
    "//evil.com",
    "/\\evil.com",
    "/\tevil",
    "https://evil.com",
    "javascript:alert(1)",
    "/a\\b",
  ])("falls back for %s", (value) => {
    expect(safeNextPath(value)).toBe("/profile");
    expect(safeNextPath(value, "/catalog")).toBe("/catalog");
  });
});
