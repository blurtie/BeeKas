import type { Metadata, Viewport } from "next";
import { Poppins } from "next/font/google";
import { copy } from "@/config/copy";
import { TABS } from "@/config/navigation";
import { colors, cssVariables } from "@/styles/tokens";
import { AppShell } from "@/ui/app-shell";
import { OfflineIndicator } from "./offline-indicator";
import { SwRegister } from "./sw-register";
import "./globals.css";

const poppins = Poppins({ variable: "--font-poppins", subsets: ["latin"], weight: ["400", "500", "600", "700"] });

export const metadata: Metadata = {
  title: copy.app.name,
  description: copy.app.description,
  applicationName: copy.app.name,
  appleWebApp: { title: copy.app.name, statusBarStyle: "default" },
};

export const viewport: Viewport = {
  themeColor: colors.honey,
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${poppins.variable} h-full antialiased`}>
      <head>
        <style>{cssVariables}</style>
      </head>
      <body className="flex min-h-full flex-col bg-background text-ink">
        <SwRegister />
        <OfflineIndicator />
        <AppShell tabs={TABS} navLabel={copy.nav.label} appName={copy.app.name}>
          {children}
        </AppShell>
      </body>
    </html>
  );
}
