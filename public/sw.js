// BeeKas service worker: offline app shell only.
// Only pages listed in PUBLIC_SHELL are cached. Every other page is treated as
// private (account data) by default: never precached, never written to cache,
// and served /offline when the network is down.
const VERSION = new URL(self.location).searchParams.get("v") || "dev";
const SHELL_CACHE = `beekas-shell-${VERSION}`;
const STATIC_CACHE = `beekas-static-${VERSION}`;
const PUBLIC_SHELL = ["/catalog", "/offline", "/manifest.webmanifest"];

const cacheable = (res) => res && res.ok && !res.redirected && res.type === "basic";

async function precache() {
  const shell = await caches.open(SHELL_CACHE);
  const assets = new Set();
  await Promise.allSettled(
    PUBLIC_SHELL.map(async (path) => {
      const res = await fetch(path, { cache: "no-store" });
      if (!cacheable(res)) return;
      await shell.put(path, res.clone());
      if ((res.headers.get("content-type") || "").includes("text/html")) {
        const html = await res.text();
        for (const m of html.matchAll(/(?:src|href)="(\/_next\/static\/[^"]+)"/g)) assets.add(m[1]);
      }
    }),
  );
  const statics = await caches.open(STATIC_CACHE);
  await Promise.allSettled(
    [...assets].map(async (url) => {
      const res = await fetch(url);
      if (cacheable(res)) await statics.put(url, res);
    }),
  );
}

self.addEventListener("install", (event) => {
  event.waitUntil(precache().then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  const keep = [SHELL_CACHE, STATIC_CACHE];
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => !keep.includes(k)).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  if (req.mode === "navigate") {
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (cacheable(res) && PUBLIC_SHELL.includes(url.pathname)) {
            const copy = res.clone();
            caches.open(SHELL_CACHE).then((c) => c.put(url.pathname, copy));
          }
          return res;
        })
        .catch(async () =>
          (PUBLIC_SHELL.includes(url.pathname) &&
            (await caches.match(url.pathname, { cacheName: SHELL_CACHE }))) ||
          (await caches.match("/offline", { cacheName: SHELL_CACHE })) ||
          Response.error()),
    );
    return;
  }

  if (url.pathname.startsWith("/_next/static/")) {
    event.respondWith(
      caches.match(req, { cacheName: STATIC_CACHE }).then(
        (hit) => hit || fetch(req).then((res) => {
          if (cacheable(res)) {
            const copy = res.clone();
            caches.open(STATIC_CACHE).then((c) => c.put(req, copy));
          }
          return res;
        }),
      ),
    );
  }
  // Everything else goes to the network, including RSC requests (?_rsc / RSC header).
  // Offline, a failed RSC fetch makes Next fall back to a full navigation, which is
  // served from the shell cache above (or /offline) — needs manual browser verification.
});
