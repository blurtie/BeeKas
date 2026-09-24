import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { supabaseEnv } from "./env";

// Creates a Supabase client bound to the proxy request/response so refreshed
// auth cookies reach both the rendered page and the browser.
export function createProxyClient(request: NextRequest) {
  let response = NextResponse.next({ request });
  const { url, key } = supabaseEnv();
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        for (const { name, value } of cookiesToSet) request.cookies.set(name, value);
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) response.cookies.set(name, value, options);
        for (const [h, v] of Object.entries(headers ?? {})) response.headers.set(h, v);
      },
    },
  });
  return { supabase, getResponse: () => response };
}

// Redirect that keeps any refreshed auth cookies and no-cache headers.
export function redirectWithCookies(target: URL, from: NextResponse) {
  const res = NextResponse.redirect(target);
  for (const cookie of from.cookies.getAll()) res.cookies.set(cookie);
  for (const h of ["cache-control", "expires", "pragma"]) {
    const v = from.headers.get(h);
    if (v) res.headers.set(h, v);
  }
  return res;
}
