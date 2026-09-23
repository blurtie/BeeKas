export const copy = {
  app: {
    name: "BeeKas",
    description: "Buy and sell pre-loved items with people nearby.",
  },
  nav: {
    label: "Main navigation",
    catalog: "Catalog",
    post: "Post",
    myListings: "My listings",
    profile: "Profile",
  },
  offline: {
    banner: "You're offline. Some content may be out of date.",
  },
  pages: {
    catalog: { title: "Catalog", empty: "No listings yet. Check back soon." },
    post: { title: "Post an item", empty: "Posting will be available soon." },
    myListings: { title: "My listings", empty: "You haven't posted anything yet." },
    profile: { title: "Profile", empty: "Your profile will appear here." },
    offline: { title: "You're offline", empty: "This page isn't available offline. Reconnect and try again." },
  },
} as const;
