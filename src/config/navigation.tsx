import type { ComponentType, SVGProps } from "react";
import { copy } from "@/config/copy";

type Icon = ComponentType<SVGProps<SVGSVGElement>>;

function makeIcon(d: string): Icon {
  function NavIcon(props: SVGProps<SVGSVGElement>) {
    return (
      <svg
        viewBox="0 0 24 24"
        width={24}
        height={24}
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden
        {...props}
      >
        <path d={d} />
      </svg>
    );
  }
  return NavIcon;
}

export type Tab = { label: string; href: string; icon: Icon };

export const TABS: readonly Tab[] = [
  { label: copy.nav.catalog, href: "/catalog", icon: makeIcon("M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z") },
  { label: copy.nav.post, href: "/post", icon: makeIcon("M12 5v14M5 12h14") },
  { label: copy.nav.myListings, href: "/my-listings", icon: makeIcon("M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01") },
  { label: copy.nav.profile, href: "/profile", icon: makeIcon("M20 21a8 8 0 0 0-16 0M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z") },
];
