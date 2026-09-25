import { expect, it } from "vitest";
import { fitWithin, photoPath } from "./listing-photo";

it("scales the longest side down to 1024 and keeps the aspect ratio", () => {
  expect(fitWithin(4032, 3024)).toEqual({ width: 1024, height: 768 });
  expect(fitWithin(3000, 4000)).toEqual({ width: 768, height: 1024 });
});

it("never scales small images up", () => {
  expect(fitWithin(800, 600)).toEqual({ width: 800, height: 600 });
  expect(fitWithin(1024, 1024)).toEqual({ width: 1024, height: 1024 });
});

it("puts the photo in the uploader's own folder", () => {
  expect(photoPath("user-1", "abc")).toBe("user-1/abc.jpg");
});
