import { redirect } from "next/navigation";
import { copy } from "@/config/copy";
import { CAMPUSES, MAJOR_GROUPS, OTHER_MAJOR, type CampusCode } from "@/lib/domain/profile";
import { isProfileComplete } from "@/lib/domain/profile-completeness";
import { PROFILE_COLUMNS, type OwnProfileRow } from "@/lib/supabase/profile-row";
import { createClient, getUserId } from "@/lib/supabase/server";
import { EmptyState } from "@/ui/empty-state";
import { ProfileSummary } from "@/ui/profile-summary";

function majorName(code: string | null) {
  if (code === null) return null;
  if (code === OTHER_MAJOR) return copy.profile.fields.majorOther;
  return MAJOR_GROUPS.flatMap((g) => g.majors).find((m) => m.code === code)?.name ?? code;
}

const isCampus = (code: string): code is CampusCode => (CAMPUSES as readonly string[]).includes(code);
const campusName = (code: string | null) =>
  code === null ? null : isCampus(code) ? copy.profile.campuses[code] : code;

export default async function ProfilePage() {
  const supabase = await createClient();
  const userId = await getUserId(supabase);
  if (!userId) redirect(`/sign-in?next=${encodeURIComponent("/profile")}`);

  const { data: row } = await supabase
    .from("profiles")
    .select(PROFILE_COLUMNS)
    .eq("id", userId)
    .maybeSingle<OwnProfileRow>();
  if (!row) return <EmptyState title={copy.pages.profile.title} message={copy.pages.profile.empty} />;

  const f = copy.profile.fields;
  const isStudent = row.user_type === "student";
  const userTypeLabel =
    row.user_type === "student" || row.user_type === "staff" ? copy.profile.userTypes[row.user_type] : row.user_type;
  const rows = [
    { label: f.nickname, value: row.nickname },
    { label: f.email, value: row.email },
    { label: f.userType, value: userTypeLabel },
    { label: f.whatsapp, value: row.whatsapp ? `+${row.whatsapp}` : null },
    { label: f.campus, value: campusName(row.campus) },
    ...(isStudent
      ? [
          { label: f.major, value: majorName(row.major) },
          { label: f.binusian, value: row.binusian },
        ]
      : []),
  ];

  return (
    <ProfileSummary
      title={copy.profile.summaryTitle}
      rows={rows}
      notSet={copy.profile.notSet}
      incompleteMessage={isProfileComplete(row) ? undefined : copy.profile.incomplete}
      editHref="/profile/complete"
      editLabel={copy.profile.edit}
      signOutAction="/auth/sign-out"
      signOutLabel={copy.auth.signOut}
    />
  );
}
