"use client";

import { useSyncExternalStore } from "react";
import { copy } from "@/config/copy";
import { OfflineBanner } from "@/ui/offline-banner";

function subscribe(onChange: () => void) {
  window.addEventListener("online", onChange);
  window.addEventListener("offline", onChange);
  return () => {
    window.removeEventListener("online", onChange);
    window.removeEventListener("offline", onChange);
  };
}

export function OfflineIndicator() {
  const isOffline = useSyncExternalStore(
    subscribe,
    () => !navigator.onLine,
    () => false,
  );
  return isOffline ? <OfflineBanner message={copy.offline.banner} /> : null;
}
