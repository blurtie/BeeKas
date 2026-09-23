export const colors = {
  honey: "#FFC93C",
  ink: "#241B0E",
  primary: "#8A5A12",
  background: "#FBF8F2",
  surface: "#FFFFFF",
  border: "#E3DCCD",
  muted: "#6B6154",
} as const;

export type ColorToken = keyof typeof colors;

export const cssVariables = `:root{${Object.entries(colors)
  .map(([name, value]) => `--${name}:${value};`)
  .join("")}}`;
