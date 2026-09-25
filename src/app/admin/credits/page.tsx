import { redirect } from "next/navigation";
import { copy } from "@/config/copy";
import { createClient, getUserId } from "@/lib/supabase/server";
import { AdminCredits } from "@/ui/admin-credits";
import { EmptyState } from "@/ui/empty-state";
import { adjustCredits } from "./actions";

type ErrorCode = keyof typeof copy.admin.credits.errors;

export default async function AdminCreditsPage({ searchParams }: PageProps<"/admin/credits">) {
  const t = copy.admin.credits;
  const supabase = await createClient();
  const userId = await getUserId(supabase);
  if (!userId) redirect(`/sign-in?next=${encodeURIComponent("/admin/credits")}`);

  // UI gate only; admin_find_members and admin_adjust_credits check is_admin themselves.
  const { data: me } = await supabase.from("profiles").select("is_admin").eq("id", userId).maybeSingle();
  if (!me?.is_admin) return <EmptyState title={t.title} message={t.notAdmin} />;

  const params = await searchParams;
  const q = typeof params.q === "string" ? params.q.trim() : "";
  const msg = typeof params.msg === "string" ? params.msg : "";

  const members = q.length >= 2 ? ((await supabase.rpc("admin_find_members", { search: q })).data ?? []) : null;
  const message =
    msg === "done"
      ? { tone: "info" as const, text: t.done }
      : msg
        ? { tone: "error" as const, text: t.errors[(msg in t.errors ? msg : "generic") as ErrorCode] }
        : undefined;

  return (
    <AdminCredits
      title={t.title}
      q={q}
      members={members}
      message={message}
      action={adjustCredits}
      text={{ ...t, count: copy.credits.count }}
    />
  );
}
