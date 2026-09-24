import type { NextRequest } from "next/server";
import { isProfileComplete } from "@/lib/domain/profile-completeness";
import { safeNextPath } from "@/lib/domain/safe-redirect";
import { PROFILE_COLUMNS, type OwnProfileRow } from "@/lib/supabase/profile-row";
import { createProxyClient, redirectWithCookies } from "@/lib/supabase/proxy";

// Pages that need a signed-in user.
const PROTECTED = ["/post", "/my-listings", "/profile", "/admin"];
// Pages that also need a complete profile.
const NEEDS_PROFILE = ["/post", "/my-listings"];

const matches = (path: string, prefixes: readonly string[]) =>
  prefixes.some((p) => path === p || path.startsWith(`${p}/`));

export async function proxy(request: NextRequest) {
  const { supabase, getResponse } = createProxyClient(request);

  // Must run right after creating the client: verifies the JWT and refreshes
  // the session cookies when needed. Do not use getSession() here.
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub ?? null;

  const { pathname, search } = request.nextUrl;

  if (!userId && matches(pathname, PROTECTED)) {
    const target = new URL("/sign-in", request.url);
    target.searchParams.set("next", safeNextPath(`${pathname}${search}`));
    return redirectWithCookies(target, getResponse());
  }

  if (userId && pathname === "/sign-in") {
    const next = safeNextPath(request.nextUrl.searchParams.get("next"));
    return redirectWithCookies(new URL(next, request.url), getResponse());
  }

  if (userId && matches(pathname, NEEDS_PROFILE)) {
    const { data: profile } = await supabase
      .from("profiles")
      .select(PROFILE_COLUMNS)
      .eq("id", userId)
      .maybeSingle<OwnProfileRow>();
    if (!isProfileComplete(profile)) {
      const target = new URL("/profile/complete", request.url);
      target.searchParams.set("next", safeNextPath(`${pathname}${search}`));
      return redirectWithCookies(target, getResponse());
    }
  }

  return getResponse();
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|sw.js|manifest.webmanifest|icon|apple-icon|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
