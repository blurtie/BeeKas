import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { safeNextPath } from "@/lib/domain/safe-redirect";
import { createClient } from "@/lib/supabase/server";

// DEVELOPMENT-ONLY FALLBACK (D-14): link sign-in.
// On the Free project with built-in SMTP the default email template (not
// editable since 3 June 2026) sends a magic link instead of the 6-digit code.
// This handler lets that link work during development. The code-entry screen
// at /sign-in remains the intended sign-in flow.
// Two link shapes are handled:
// - ?token_hash=...&type=... (templates using {{ .TokenHash }}), verified here;
// - ?code=... (default template: Supabase verifies, then redirects here with a
//   PKCE code), exchanged here. Works only in the browser that requested it.
const ALLOWED_TYPES: readonly EmailOtpType[] = ["email", "magiclink", "signup"];

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const next = safeNextPath(searchParams.get("next"));

  const code = searchParams.get("code");
  const supabase = await createClient();

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(new URL(next, request.url));
  } else if (tokenHash && type && ALLOWED_TYPES.includes(type)) {
    const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type });
    if (!error) return NextResponse.redirect(new URL(next, request.url));
  }

  const failed = new URL("/sign-in", request.url);
  failed.searchParams.set("error", "link_failed");
  return NextResponse.redirect(failed);
}
