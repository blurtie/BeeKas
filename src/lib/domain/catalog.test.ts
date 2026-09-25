import { describe, expect, it } from "vitest";
import { formatRupiah, hasFilters, parseCatalogQuery } from "./catalog";

describe("parseCatalogQuery", () => {
  it("keeps valid values", () => {
    expect(parseCatalogQuery({ q: " lab coat ", type: "donation", category: "lab", campus: "online" })).toEqual({
      q: "lab coat",
      type: "donation",
      category: "lab",
      campus: "online",
    });
  });

  it("drops unknown or empty values", () => {
    expect(parseCatalogQuery({ q: "  ", type: "rent", category: "food", campus: "anggrek" })).toEqual({});
    expect(parseCatalogQuery({})).toEqual({});
  });

  it("uses the first value of a repeated param", () => {
    expect(parseCatalogQuery({ type: ["sale", "donation"] })).toEqual({ type: "sale" });
  });

  it("strips characters that would break the search filter", () => {
    expect(parseCatalogQuery({ q: "a,b(c)*d%e_f\\g" })).toEqual({ q: "a b c d e f g" });
  });

  it("caps the search text at 100 characters", () => {
    expect(parseCatalogQuery({ q: "x".repeat(150) }).q).toHaveLength(100);
  });
});

it("hasFilters is false only for an empty query", () => {
  expect(hasFilters({})).toBe(false);
  expect(hasFilters({ q: "book" })).toBe(true);
});

it("formats whole rupiah with Indonesian grouping", () => {
  expect(formatRupiah(150000)).toBe("Rp150.000");
  expect(formatRupiah(1000)).toBe("Rp1.000");
  expect(formatRupiah(100000000)).toBe("Rp100.000.000");
});
