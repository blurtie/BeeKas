"use server";

import { redirect } from "next/navigation";
import { safeNextPath } from "@/lib/domain/safe-redirect";
import { profileSchema } from "@/lib/domain/profile";
import { createClient, getUserId } from "@/lib/supabase/server";

export type ProfileFormValues = {
  nickname: string;
  whatsapp: string;
  campus: string;
  major: string;
  binusian: string;
};

export type ProfileFormState = {
  values?: ProfileFormValues;
  fieldErrors?: Partial<Record<keyof ProfileFormValues, string>>;
  formError?: string;
  attempt: number;
};

const text = (fd: FormData, k: string) => {
  const v = fd.get(k);
  return typeof v === "string" ? v : "";
};

// Thin wrapper: rules live in profileSchema (domain) and in Postgres
// (RLS own-row policy, column grants, check constraints).
export async function saveProfile(prev: ProfileFormState, formData: FormData): Promise<ProfileFormState> {
  const attempt = prev.attempt + 1;
  const supabase = await createClient();
  const userId = await getUserId(supabase);
  if (!userId) redirect("/sign-in?next=%2Fprofile%2Fcomplete");

  const values: ProfileFormValues = {
    nickname: text(formData, "nickname"),
    whatsapp: text(formData, "whatsapp"),
    campus: text(formData, "campus"),
    major: text(formData, "major"),
    binusian: text(formData, "binusian"),
  };

  // email (and so user_type) come from the DB row, never from the form.
  const { data: row } = await supabase.from("profiles").select("email, user_type").eq("id", userId).maybeSingle();
  if (!row) return { values, formError: "save_failed", attempt };

  const staff = row.user_type === "staff";
  const parsed = profileSchema.safeParse({
    nickname: values.nickname,
    email: row.email,
    whatsapp: values.whatsapp,
    campus: values.campus,
    major: staff ? null : values.major || null,
    binusian: staff ? null : values.binusian || null,
  });
  if (!parsed.success) {
    const fieldErrors: ProfileFormState["fieldErrors"] = {};
    for (const issue of parsed.error.issues) {
      const key = issue.path[0] as keyof ProfileFormValues;
      if (key in values && !fieldErrors[key]) fieldErrors[key] = issue.message;
    }
    return { values, fieldErrors, attempt };
  }

  const { nickname, whatsapp, campus, major, binusian } = parsed.data;
  const { error } = await supabase
    .from("profiles")
    .update({ nickname, whatsapp, campus, major, binusian })
    .eq("id", userId);
  if (error) return { values, formError: "save_failed", attempt };

  redirect(safeNextPath(text(formData, "next")));
}
