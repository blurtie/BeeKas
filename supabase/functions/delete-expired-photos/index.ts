// #41 (D-07): deletes card and selfie photos 30 days after their attempt was decided.
// Called daily by pg_cron. Files go through the Storage API; a SQL DELETE on
// storage.objects would orphan them in the bucket. Each deletion is logged in
// public.photo_deletions (attempt, count, time).
import { fromCron, rpc } from "../_shared/cron.ts";

type Due = { profile_id: string; attempt: string; names: string[] };

const env = (k: string) => Deno.env.get(k) ?? "";

Deno.serve(async (req) => {
  if (!(await fromCron(req, "photo_retention_cron_secret"))) {
    return new Response("unauthorized", { status: 401 });
  }
  const due: Due[] = await rpc("expired_verification_photos", {});
  let deleted = 0;
  for (const d of due) {
    // One attempt failing must not stop the rest; it is due again on the next run.
    try {
      const res = await fetch(`${env("SUPABASE_URL")}/storage/v1/object/verification`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          apikey: env("SUPABASE_SERVICE_ROLE_KEY"),
          Authorization: `Bearer ${env("SUPABASE_SERVICE_ROLE_KEY")}`,
        },
        body: JSON.stringify({ prefixes: d.names }),
      });
      if (!res.ok) throw new Error(`storage ${res.status}: ${await res.text()}`);
      const objects = (await res.json()).length;
      if (objects > 0) {
        await rpc("record_photo_deletion", { p_profile: d.profile_id, p_attempt: d.attempt, p_objects: objects });
        deleted += objects;
      }
    } catch (err) {
      console.error(`delete-expired-photos: ${d.profile_id}/${d.attempt} failed: ${err}`);
    }
  }
  return Response.json({ attempts: due.length, deleted });
});
