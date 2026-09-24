import { describe, expect, it } from "vitest";
import { authErrorKey } from "./auth-errors";

describe("authErrorKey", () => {
  it("maps the generic trigger error to generic", () => {
    expect(authErrorKey({ status: 500, code: "unexpected_failure", message: "Database error saving new user" }))
      .toBe("generic");
  });

  it("maps rate limits", () => {
    expect(authErrorKey({ status: 429, code: "over_email_send_rate_limit", message: "x" })).toBe("rate_limited");
    expect(authErrorKey({ status: 400, code: "over_request_rate_limit" })).toBe("rate_limited");
  });

  it("maps invalid or expired codes", () => {
    expect(authErrorKey({ status: 403, code: "otp_expired", message: "Token has expired or is invalid" }))
      .toBe("invalid_otp");
  });

  it("falls back to generic", () => {
    expect(authErrorKey(null)).toBe("generic");
    expect(authErrorKey({ status: 500, message: "boom" })).toBe("generic");
  });
});
