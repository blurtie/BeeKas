import type { ComponentType } from "react";
import { copy } from "@/config/copy";

type Icon = ComponentType;

// Figma nav icons (public/ui/*.svg) used as masks so they take the tab's text color.
function maskIcon(src: string): Icon {
  function NavIcon() {
    const mask = `url(${src}) center / contain no-repeat`;
    return <span aria-hidden className="block size-9 bg-current" style={{ mask, WebkitMask: mask }} />;
  }
  return NavIcon;
}

function PlusIcon() {
  return (
    <svg viewBox="0 0 24 24" width={24} height={24} fill="none" stroke="currentColor" strokeWidth={2.5}
      strokeLinecap="round" aria-hidden>
      <path d="M12 5v14M5 12h14" />
    </svg>
  );
}

// prominent: raised round button in the middle of the bar (Figma "Jual").
export type Tab = { label: string; href: string; icon: Icon; prominent?: boolean };

export const TABS: readonly Tab[] = [
  { label: copy.nav.catalog, href: "/catalog", icon: maskIcon("/ui/house.svg") },
  { label: copy.nav.post, href: "/post", icon: PlusIcon, prominent: true },
  { label: copy.nav.myListings, href: "/my-listings", icon: maskIcon("/ui/items.svg") },
  { label: copy.nav.profile, href: "/profile", icon: maskIcon("/ui/account.svg") },
];
