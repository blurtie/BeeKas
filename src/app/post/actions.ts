"use server";

import { redirect } from "next/navigation";
import { listingSchema } from "@/lib/domain/listing";
import { createClient, getUserId } from "@/lib/supabase/server";

export type PostFormValues = {
  type: string;
  title: string;
  category: string;
  condition: string;
  description: string;
  price: string;
  campus: string;
  meetup_note: string;
  image_path: string;
};

export type PostFormState = {
  values?: PostFormValues;
  fieldErrors?: Partial<Record<keyof PostFormValues | "agree", string>>;
  formError?: string;
  publishedId?: string;
  attempt: number;
};

const RPC_ERRORS = ["no_credits", "profile_incomplete", "photo_missing"];
const FIELDS: (keyof PostFormValues)[] = [
  "type", "title", "category", "condition", "description", "price", "campus", "meetup_note", "image_path",
];

// Thin wrapper: rules live in listingSchema (domain) and in publish_listing (Postgres).
export async function publishListing(prev: PostFormState, formData: FormData): Promise<PostFormState> {
  const attempt = prev.attempt + 1;
  const supabase = await createClient();
  if (!(await getUserId(supabase))) redirect("/sign-in?next=%2Fpost");

  const values = Object.fromEntries(FIELDS.map((k) => [k, String(formData.get(k) ?? "")])) as PostFormValues;
  const parsed = listingSchema.safeParse({ ...values, agree: formData.get("agree") === "on" });
  if (!parsed.success) {
    const fieldErrors: PostFormState["fieldErrors"] = {};
    for (const issue of parsed.error.issues) {
      const key = issue.path[0] as keyof NonNullable<PostFormState["fieldErrors"]>;
      fieldErrors[key] ??= issue.message;
    }
    return { values, fieldErrors, attempt };
  }

  const l = parsed.data;
  const { data, error } = await supabase.rpc("publish_listing", {
    p_type: l.type,
    p_title: l.title,
    p_category: l.category,
    p_condition: l.condition,
    p_description: l.description,
    p_price: l.price,
    p_campus: l.campus,
    p_meetup_note: l.meetup_note,
    p_image_path: l.image_path,
  });
  if (error) {
    const code = RPC_ERRORS.find((c) => error.message.includes(c)) ?? "generic";
    return { values: code === "photo_missing" ? { ...values, image_path: "" } : values, formError: code, attempt };
  }
  return { publishedId: data as string, attempt };
}
