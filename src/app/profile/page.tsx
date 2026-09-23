import { copy } from "@/config/copy";
import { EmptyState } from "@/ui/empty-state";

export default function ProfilePage() {
  const { title, empty } = copy.pages.profile;
  return <EmptyState title={title} message={empty} />;
}
