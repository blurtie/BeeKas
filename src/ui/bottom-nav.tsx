"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

export type NavItem = { href: string; label: string; icon: ReactNode; prominent?: boolean };

type Props = { tabs: readonly NavItem[]; label: string };

export function BottomNav({ tabs, label }: Props) {
  const pathname = usePathname();
  return (
    <nav
      aria-label={label}
      className="fixed inset-x-0 bottom-0 z-10 border-t border-border bg-surface pb-[env(safe-area-inset-bottom)]"
    >
      <ul className="mx-auto flex max-w-[480px]">
        {tabs.map(({ href, label: tabLabel, icon, prominent }) => {
          const active = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <li key={href} className="flex-1">
              <Link
                href={href}
                aria-current={active ? "page" : undefined}
                className={`flex min-h-16 min-w-11 flex-col items-center justify-end gap-0.5 pb-2 text-[11px] font-bold outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-inset ${
                  active ? "text-ink" : "text-muted"
                }`}
              >
                {prominent ? (
                  <span className="-mt-5 flex size-13 items-center justify-center rounded-full bg-accent text-ink">
                    {icon}
                  </span>
                ) : (
                  icon
                )}
                {tabLabel}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
