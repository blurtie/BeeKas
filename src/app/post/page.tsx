import { redirect } from "next/navigation";
import { copy } from "@/config/copy";
import { createClient, getUserId } from "@/lib/supabase/server";
import { EmptyState } from "@/ui/empty-state";

export default async function PostPage() {
  // Proxy already guards this route; re-check here so the page never renders signed out.
  const userId = await getUserId(await createClient());
  if (!userId) redirect(`/sign-in?next=${encodeURIComponent("/post")}`);

  const { title, empty } = copy.pages.post;
  return <EmptyState title={title} message={empty} />;
}
