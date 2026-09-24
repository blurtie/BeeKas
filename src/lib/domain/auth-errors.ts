// Maps Supabase Auth errors to copy keys in copy.auth.errors.
// Kept free of Supabase imports: callers pass { status, code, message }.
export type AuthErrorKey = "rate_limited" | "invalid_otp" | "generic";

type AuthErrorLike = { status?: number; code?: string; message?: string } | null | undefined;

export function authErrorKey(error: AuthErrorLike): AuthErrorKey {
  if (!error) return "generic";
  const code = error.code ?? "";
  const message = (error.message ?? "").toLowerCase();
  if (error.status === 429 || code.startsWith("over_") || message.includes("rate limit")) return "rate_limited";
  // "Database error saving new user" (trigger rejection) is left as generic:
  // the email already passed campusEmailSchema client-side, so the campus
  // message comes only from that check.
  if (code === "otp_expired" || code === "otp_disabled" || error.status === 403) return "invalid_otp";
  return "generic";
}
