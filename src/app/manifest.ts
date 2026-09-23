import type { MetadataRoute } from "next";
import { copy } from "@/config/copy";
import { colors } from "@/styles/tokens";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: copy.app.name,
    short_name: copy.app.name,
    description: copy.app.description,
    start_url: "/catalog",
    scope: "/",
    display: "standalone",
    background_color: colors.background,
    theme_color: colors.honey,
    icons: [
      { src: "/icon/192", sizes: "192x192", type: "image/png" },
      { src: "/icon/512", sizes: "512x512", type: "image/png" },
      { src: "/icon/maskable", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
