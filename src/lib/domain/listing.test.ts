import { describe, expect, it } from "vitest";
import { listingSchema, parsePrice } from "./listing";

const sale = {
  type: "sale",
  title: " Calculus textbook ",
  category: "books",
  condition: "good",
  description: "Some notes inside.",
  campus: "kemanggisan",
  meetup_note: "",
  image_path: "user-1/abc.jpg",
  agree: true,
  price: "150.000",
};
const codes = (input: unknown) => listingSchema.safeParse(input).error?.issues.map((i) => i.message) ?? [];

describe("parsePrice", () => {
  it("accepts dot and space thousands separators", () => {
    expect(parsePrice("150.000")).toBe(150000);
    expect(parsePrice("150 000")).toBe(150000);
  });
  it("rejects decimals and text", () => {
    expect(parsePrice("1,5")).toBeNaN();
    expect(parsePrice("abc")).toBeNaN();
    expect(parsePrice("")).toBeNaN();
  });
});

describe("listingSchema", () => {
  it("parses a sale listing, trimming text and emptying a blank meetup note", () => {
    const out = listingSchema.parse(sale);
    expect(out).toMatchObject({ title: "Calculus textbook", price: 150000, meetup_note: null });
  });

  it("drops the price of a donation listing", () => {
    expect(listingSchema.parse({ ...sale, type: "donation", price: "999" }).price).toBeNull();
    expect(listingSchema.parse({ ...sale, type: "donation", price: undefined }).price).toBeNull();
  });

  it("keeps the price within Rp1.000 to Rp100.000.000", () => {
    expect(codes({ ...sale, price: "999" })).toContain("price_out_of_range");
    expect(codes({ ...sale, price: "100.000.001" })).toContain("price_out_of_range");
    expect(codes({ ...sale, price: "1.000" })).toEqual([]);
    expect(codes({ ...sale, price: "100.000.000" })).toEqual([]);
  });

  it("requires a whole-number price for a sale", () => {
    expect(codes({ ...sale, price: "1,5" })).toContain("invalid_price");
    expect(codes({ ...sale, price: "" })).toContain("invalid_price");
  });

  it("limits the meetup note to 100 characters", () => {
    expect(codes({ ...sale, meetup_note: "a".repeat(101) })).toContain("meetup_note_too_long");
    expect(codes({ ...sale, meetup_note: "a".repeat(100) })).toEqual([]);
  });

  it("only accepts listed types, categories, conditions and campuses", () => {
    expect(codes({ ...sale, type: "rent" })).toContain("invalid_type");
    expect(codes({ ...sale, category: "food" })).toContain("invalid_category");
    expect(codes({ ...sale, condition: "broken" })).toContain("invalid_condition");
    expect(codes({ ...sale, campus: "anggrek" })).toContain("invalid_campus");
  });

  it("requires a photo, a title, a description and the statement", () => {
    expect(codes({ ...sale, image_path: "" })).toContain("photo_required");
    expect(codes({ ...sale, title: "ab" })).toContain("title_too_short");
    expect(codes({ ...sale, description: " " })).toContain("description_required");
    expect(codes({ ...sale, agree: false })).toContain("agree_required");
  });
});
