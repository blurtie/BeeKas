import { redirect } from "next/navigation";
import { copy } from "@/config/copy";
import { createClient, getUserId } from "@/lib/supabase/server";
import { PostListingForm } from "./post-listing-form";

export default async function PostPage() {
  // Proxy already guards this route (sign-in and complete profile); re-check sign-in here.
  const supabase = await createClient();
  const userId = await getUserId(supabase);
  if (!userId) redirect(`/sign-in?next=${encodeURIComponent("/post")}`);

  const [{ data: credits }, { data: profile }] = await Promise.all([
    supabase.rpc("get_my_credits"),
    supabase.from("profiles").select("campus").eq("id", userId).maybeSingle(),
  ]);

  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold text-ink">{copy.pages.post.title}</h1>
      <PostListingForm userId={userId} credits={credits ?? 0} profileCampus={profile?.campus ?? ""} />
    </section>
  );
}
