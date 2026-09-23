import { ImageResponse } from "next/og";
import { colors } from "@/styles/tokens";

export const contentType = "image/png";

const SIZES = { small: 32, "192": 192, "512": 512, maskable: 512 } as const;
type Id = keyof typeof SIZES;

export function generateImageMetadata() {
  return (Object.keys(SIZES) as Id[]).map((id) => ({
    id,
    contentType,
    size: { width: SIZES[id], height: SIZES[id] },
  }));
}

export default async function Icon({ id }: { id: Promise<string> }) {
  const key = (await id) as Id;
  const size = SIZES[key];
  const maskable = key === "maskable";
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: colors.honey,
          color: colors.ink,
          fontSize: size * (maskable ? 0.4 : 0.6),
          fontWeight: 700,
          borderRadius: maskable ? 0 : size * 0.2,
        }}
      >
        B
      </div>
    ),
    { width: size, height: size },
  );
}
