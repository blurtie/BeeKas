import type { ReactNode } from "react";
import type { Tab } from "@/config/navigation";
import { BottomNav } from "@/ui/bottom-nav";

type Props = { children: ReactNode; tabs: readonly Tab[]; navLabel: string };

export function AppShell({ children, tabs, navLabel }: Props) {
  return (
    <>
      <main className="mx-auto w-full max-w-[480px] flex-1 px-4 pt-6 pb-[calc(5rem+env(safe-area-inset-bottom))]">
        {children}
      </main>
      <BottomNav
        tabs={tabs.map(({ href, label, icon: Icon }) => ({ href, label, icon: <Icon /> }))}
        label={navLabel} />
    </>
  );
}
