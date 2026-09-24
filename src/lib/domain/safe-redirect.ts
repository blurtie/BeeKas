// Validates a user-supplied "next" value so redirects stay on this origin.
// Only absolute paths like "/post" or "/profile?x=1" are accepted; protocol-
// relative ("//evil.com"), backslash tricks ("/\evil.com"), schemes and
// control characters fall back to the default.
export function safeNextPath(next: string | null | undefined, fallback = "/profile"): string {
  if (typeof next !== "string" || next.length === 0 || next.length > 2048) return fallback;
  if (!next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return fallback;
  if (/[\u0000-\u001f\u007f\\]/.test(next)) return fallback;
  try {
    const base = "http://beekas.invalid";
    const url = new URL(next, base);
    if (url.origin !== base) return fallback;
    return `${url.pathname}${url.search}${url.hash}`;
  } catch {
    return fallback;
  }
}
