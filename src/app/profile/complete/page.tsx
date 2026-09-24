import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { copy } from "@/config/copy";
import { safeNextPath } from "@/lib/domain/safe-redirect";
import { PROFILE_COLUMNS, type OwnProfileRow } from "@/lib/supabase/profile-row";
import { createClient, getUserId } from "@/lib/supabase/server";
import { EmptyState } from "@/ui/empty-state";
import { ProfileCompleteForm } from "./profile-complete-form";

export const metadata: Metadata = { title: copy.profile.completeTitle };

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);

export default async function ProfileCompletePage({ searchParams }: PageProps<"/profile/complete">) {
  const next = safeNextPath(first((await searchParams).next));
  const supabase = await createClient();
  const userId = await getUserId(supabase);
  if (!userId) redirect(`/sign-in?next=${encodeURIComponent("/profile/complete")}`);

  const { data: row } = await supabase
    .from("profiles")
    .select(PROFILE_COLUMNS)
    .eq("id", userId)
    .maybeSingle<OwnProfileRow>();
  if (!row || (row.user_type !== "student" && row.user_type !== "staff")) {
    return <EmptyState title={copy.profile.completeTitle} message={copy.profile.errors.save_failed} />;
  }

  return (
    <ProfileCompleteForm
      email={row.email}
      userType={row.user_type}
      next={next}
      initial={{
        nickname: row.nickname ?? "",
        whatsapp: row.whatsapp ?? "",
        campus: row.campus ?? "",
        major: row.major ?? "",
        binusian: row.binusian ?? "",
      }}
    />
  );
}
