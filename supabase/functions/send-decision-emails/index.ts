// #33: drains public.decision_emails. Called every minute by pg_cron. Delivery is
// at-least-once (see the migration). Sends over HTTP with fetch: Edge Functions block
// outgoing ports 25 and 587, so no SMTP.

type Email = { id: number; recipient: string; subject: string; body: string };
type Send = (e: Email) => Promise<void>;

const env = (k: string) => Deno.env.get(k) ?? "";

// One sender per EMAIL_API mode. The cloud provider is added once it is chosen.
const senders: Record<string, Send> = {
  mailpit: async (e) => {
    const from = parseFrom(env("EMAIL_FROM"));
    const res = await fetch(`${env("MAILPIT_URL")}/api/v1/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ From: from, To: [{ Email: e.recipient }], Subject: e.subject, Text: e.body }),
    });
    if (!res.ok) throw new Error(`mailpit ${res.status}: ${await res.text()}`);
  },
};

// "Name <a@b>" -> { Name, Email }
function parseFrom(s: string) {
  const m = s.match(/^(.*)<(.+)>$/);
  return m ? { Name: m[1].trim(), Email: m[2].trim() } : { Email: s.trim() };
}

async function rpc(name: string, args: unknown) {
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

Deno.serve(async (req) => {
  // Only pg_cron may run it: the shared secret from Vault must match the header.
  const expected: string | null = await rpc("decision_emails_cron_secret", {});
  const given = req.headers.get("x-cron-secret");
  if (!expected || given === null || !(await sameSecret(given, expected))) {
    return new Response("unauthorized", { status: 401 });
  }
  const mode = env("EMAIL_API");
  const send = senders[mode];
  // Not configured is not a send failure: claim nothing, rows stay pending with attempts as is.
  if (!send) {
    console.warn(`send-decision-emails: EMAIL_API "${mode}" is not configured or not implemented; nothing sent`);
    return Response.json({ sent: 0, skipped: true });
  }
  const emails: Email[] = await rpc("claim_decision_emails", {});
  let sent = 0;
  for (const e of emails) {
    let error: string | null = null;
    try {
      await send(e);
      sent++;
    } catch (err) {
      error = String(err).slice(0, 500);
      console.error(`send-decision-emails: row ${e.id} failed: ${error}`);
    }
    // A failed bookkeeping call must not stop the loop or turn a sent email into a failure;
    // the row stays 'sending' and is retried after 10 minutes (at-least-once).
    try {
      await rpc("finish_decision_email", { p_id: e.id, p_error: error });
    } catch (err) {
      console.error(`send-decision-emails: row ${e.id} not recorded: ${err}`);
    }
  }
  return Response.json({ sent, claimed: emails.length });
});
