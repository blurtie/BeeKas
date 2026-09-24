import { describe, expect, it } from "vitest";
import { otpCodeSchema } from "./otp";

describe("otpCodeSchema", () => {
  it("accepts six digits", () => {
    expect(otpCodeSchema.parse(" 012345 ")).toBe("012345");
  });

  it.each(["12345", "1234567", "12a456", "", "１２３４５６"])("rejects %j", (v) => {
    const r = otpCodeSchema.safeParse(v);
    expect(r.success).toBe(false);
    expect(r.error?.issues[0].message).toBe("invalid_otp");
  });
});
