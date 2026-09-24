import { z } from "zod";

export const OTP_LENGTH = 6;

// Exactly six ASCII digits; surrounding whitespace is trimmed.
export const otpCodeSchema = z
  .string()
  .trim()
  .regex(/^[0-9]{6}$/, { error: "invalid_otp" });
