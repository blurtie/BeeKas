import { copy } from "@/config/copy";
import { EmptyState } from "@/ui/empty-state";

export default function OfflinePage() {
  const { title, empty } = copy.pages.offline;
  return <EmptyState title={title} message={empty} />;
}
