// Shared by the pg_cron-called functions (#33, #41): service-role RPC and the
// x-cron-secret check. They run with verify_jwt = false, so the secret is the lock.

const env = (k: string) => Deno.env.get(k) ?? "";

export async function rpc(name: string, args: unknown) {
  const res = await fetch(`${env("SUPABASE_URL")}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: env("SUPABASE_SERVICE_ROLE_KEY"),
      Authorization: `Bearer ${env("SUPABASE_SERVICE_ROLE_KEY")}`,
    },
    body: JSON.stringify(args),
  });
  if (!res.ok) throw new Error(`${name} ${res.status}: ${await res.text()}`);
  return res.status === 204 ? null : res.json();
}

// Constant-time: compares SHA-256 digests byte by byte without stopping early.
async function sameSecret(a: string, b: string) {
  const hash = async (s: string) => new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
  const [x, y] = await Promise.all([hash(a), hash(b)]);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

// Only pg_cron may run it: the Vault secret behind secretRpc must match the header.
export async function fromCron(req: Request, secretRpc: string) {
  const expected: string | null = await rpc(secretRpc, {});
  const given = req.headers.get("x-cron-secret");
  return !!expected && given !== null && (await sameSecret(given, expected));
}
