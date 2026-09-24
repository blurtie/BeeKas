// Mapped from the Figma "Color Pallete" frame (5:27) and screen colors.
export const colors = {
  honey: "#FFB81C", // palette 400: buttons, logo tile, active states
  accent: "#FE9402", // palette 500: wordmark, OTP boxes, post button
  primary: "#BB4902", // palette 700: accent text and focus rings (4.5:1 on white)
  ink: "#241B0E",
  background: "#FBF8F2",
  surface: "#FFFFFF",
  border: "#CACACA",
  muted: "#6B6154",
  danger: "#F40000", // required-field asterisk
} as const;

export type ColorToken = keyof typeof colors;

export const cssVariables = `:root{${Object.entries(colors)
  .map(([name, value]) => `--${name}:${value};`)
  .join("")}}`;
