import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

// POST only, so a link or prefetch can never sign the user out.
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  // 303 turns the form POST into a GET of the sign-in page.
  return NextResponse.redirect(new URL("/sign-in", request.url), { status: 303 });
}
