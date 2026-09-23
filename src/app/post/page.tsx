import { copy } from "@/config/copy";
import { EmptyState } from "@/ui/empty-state";

export default function PostPage() {
  const { title, empty } = copy.pages.post;
  return <EmptyState title={title} message={empty} />;
}
