import { copy } from "@/config/copy";
import { EmptyState } from "@/ui/empty-state";

export default function CatalogPage() {
  const { title, empty } = copy.pages.catalog;
  return <EmptyState title={title} message={empty} />;
}
