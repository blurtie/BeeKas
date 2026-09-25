"use server";

import { redirect } from "next/navigation";
import { adjustmentSchema } from "@/lib/domain/credits";
import { createClient } from "@/lib/supabase/server";

const KNOWN_ERRORS = ["not_admin", "note_required", "invalid_delta", "credits_below_zero", "member_not_found"];

// Thin wrapper: every rule is enforced again by admin_adjust_credits in Postgres.
export async function adjustCredits(formData: FormData) {
  const q = String(formData.get("q") ?? "");
  const back = (msg: string) => redirect(`/admin/credits?${new URLSearchParams({ q, msg })}`);

  const parsed = adjustmentSchema.safeParse({
    target: formData.get("target"),
    delta: formData.get("delta"),
    note: formData.get("note") ?? "",
  });
  if (!parsed.success) back(parsed.error.issues[0].message);

  const { target, delta, note } = parsed.data!;
  const { error } = await (await createClient()).rpc("admin_adjust_credits", { target, delta, note });
  if (error) back(KNOWN_ERRORS.find((code) => error.message.includes(code)) ?? "generic");
  back("done");
}
