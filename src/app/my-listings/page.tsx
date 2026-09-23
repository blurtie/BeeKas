import { copy } from "@/config/copy";
import { EmptyState } from "@/ui/empty-state";

export default function MyListingsPage() {
  const { title, empty } = copy.pages.myListings;
  return <EmptyState title={title} message={empty} />;
}
