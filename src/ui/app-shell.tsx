import Link from "next/link";
import type { ReactNode } from "react";
import type { Tab } from "@/config/navigation";
import { BottomNav } from "@/ui/bottom-nav";

type Props = { children: ReactNode; tabs: readonly Tab[]; navLabel: string; appName: string };

// Figma "Home" header (299:412): logo tile + two-tone wordmark.
function Header({ appName }: { appName: string }) {
  return (
    <header className="mx-auto w-full max-w-[480px] px-6 pt-4">
      <Link href="/" className="inline-flex items-center gap-1.5 rounded-md outline-none focus-visible:ring-2 focus-visible:ring-primary">
        <span aria-hidden className="relative size-7 overflow-hidden rounded-[5px] bg-honey">
          {/* Figma exports the logo as a sprite; the crop below matches the design's layer geometry. */}
          <span className="absolute top-[4px] left-[3px] h-[19px] w-[23px] overflow-hidden">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/ui/logo-sprite.png" alt="" className="absolute top-[-98.34%] left-[-171.62%] h-[299.17%] w-[432.43%] max-w-none" />
          </span>
        </span>
        <span className="text-xl font-semibold text-ink">
          <span className="text-accent">{appName.slice(0, 3)}</span>
          {appName.slice(3).toLowerCase()}
        </span>
      </Link>
    </header>
  );
}

export function AppShell({ children, tabs, navLabel, appName }: Props) {
  return (
    <>
      <Header appName={appName} />
      <main className="mx-auto w-full max-w-[480px] flex-1 px-6 pt-6 pb-[calc(6rem+env(safe-area-inset-bottom))]">
        {children}
      </main>
      <BottomNav
        tabs={tabs.map(({ href, label, icon: Icon, prominent }) => ({ href, label, icon: <Icon />, prominent }))}
        label={navLabel} />
    </>
  );
}
