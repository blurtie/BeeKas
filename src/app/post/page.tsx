import { redirect } from "next/navigation";
import { copy } from "@/config/copy";
import { createClient, getUserId } from "@/lib/supabase/server";
import { FormMessage } from "@/ui/form-controls";
import { PhotoUpload } from "./photo-upload";

export default async function PostPage() {
  // Proxy already guards this route; re-check here so the page never renders signed out.
  const userId = await getUserId(await createClient());
  if (!userId) redirect(`/sign-in?next=${encodeURIComponent("/post")}`);

  const { title, publishSoon } = copy.pages.post;
  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold text-ink">{title}</h1>
      <PhotoUpload userId={userId} />
      <FormMessage tone="info">{publishSoon}</FormMessage>
    </section>
  );
}
