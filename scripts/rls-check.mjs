// scripts/rls-check.mjs
// Proves profile RLS, campus-domain rejection and 0002 value lists against the real Supabase project.
// Run: node --env-file=.env.local scripts/rls-check.mjs
// service_role is used ONLY to create/delete test accounts and mint sign-in OTPs.
// Every RLS check runs as a test account via an ANON-key client + that account's session.
// Never imported from src/.

import { createClient } from "@supabase/supabase-js";

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY;
for (const [name, v] of [
  ["NEXT_PUBLIC_SUPABASE_URL", URL],
  ["NEXT_PUBLIC_SUPABASE_ANON_KEY", ANON],
  ["SUPABASE_SERVICE_ROLE_KEY", SERVICE],
]) {
  if (!v) {
    console.error(`Missing env var ${name}`);
    process.exit(2);
  }
}

const opts = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };
const admin = createClient(URL, SERVICE, opts);
const newAnon = () => createClient(URL, ANON, opts);

const EMAIL_A = "rls-a@binus.ac.id";
const EMAIL_B = "rls-b@binus.ac.id";
const EMAIL_C = "rls-c@binus.edu";
const BAD_EMAILS = ["rls-x@gmail.com", "rls-y@binus.ac.id.evil.com"];
const EXTRA_CLEANUP = ["rls-other@binus.ac.id", "rls-z@gmail.com"];
const ALL_TEST_EMAILS = [EMAIL_A, EMAIL_B, EMAIL_C, ...BAD_EMAILS, ...EXTRA_CLEANUP];

let failures = 0;
function result(name, ok, reason) {
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${reason ? ` -- ${reason}` : ""}`);
}
const errMsg = (e) => (e ? `${e.code ?? ""} ${e.message ?? String(e)}`.trim() : "no error");

// ---------- admin helpers (account lifecycle only) ----------
async function findUsersByEmails(emails) {
  const wanted = new Set(emails.map((e) => e.toLowerCase()));
  const found = [];
  for (let page = 1; page <= 50; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw new Error(`listUsers: ${error.message}`);
    for (const u of data.users) if (u.email && wanted.has(u.email.toLowerCase())) found.push(u);
    if (data.users.length < 1000) break;
  }
  return found;
}

async function deleteUsersByEmails(emails, label) {
  const users = await findUsersByEmails(emails);
  for (const u of users) {
    const { error } = await admin.auth.admin.deleteUser(u.id);
    console.log(`${label}: delete ${u.email} ${error ? `FAILED (${error.message})` : "ok"}`);
  }
}

async function createUser(email) {
  const { data, error } = await admin.auth.admin.createUser({ email, email_confirm: true });
  if (error) throw new Error(`createUser ${email}: ${error.message}`);
  return data.user;
}

// Signs in with an ANON client using an OTP minted by admin.generateLink.
async function signIn(email) {
  const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email });
  if (error) throw new Error(`generateLink ${email}: ${error.message}`);
  const client = newAnon();
  const otp = data.properties?.email_otp;
  let res = otp ? await client.auth.verifyOtp({ email, token: otp, type: "email" }) : null;
  if (!res || res.error) {
    // Fallback: hashed token. Need a fresh link since the OTP may be consumed.
    const { data: d2, error: e2 } = await admin.auth.admin.generateLink({ type: "magiclink", email });
    if (e2) throw new Error(`generateLink(2) ${email}: ${e2.message}`);
    res = await client.auth.verifyOtp({ token_hash: d2.properties.hashed_token, type: "magiclink" });
  }
  if (res.error || !res.data.session) throw new Error(`verifyOtp ${email}: ${errMsg(res.error)}`);
  return client;
}

// Runs a check; exceptions become FAIL instead of aborting the suite.
async function check(name, fn) {
  try {
    await fn();
  } catch (e) {
    result(name, false, `threw: ${e.message}`);
  }
}

// ---------- main ----------
async function main() {
  await deleteUsersByEmails(ALL_TEST_EMAILS, "pre-clean");

  const userA = await createUser(EMAIL_A);
  const userB = await createUser(EMAIL_B);
  const userC = await createUser(EMAIL_C);
  const A = await signIn(EMAIL_A);
  const B = await signIn(EMAIL_B);
  const C = await signIn(EMAIL_C);

  // 1
  await check("1 A reads own profile", async () => {
    const { data, error } = await A.from("profiles").select("*").eq("id", userA.id);
    const ok = !error && data?.length === 1 && data[0].user_type === "student" && data[0].email === EMAIL_A;
    result("1 A reads own profile (student)", ok, error ? errMsg(error) : `rows=${data?.length} user_type=${data?.[0]?.user_type}`);
  });
  await check("1b C is staff", async () => {
    const { data, error } = await C.from("profiles").select("user_type").eq("id", userC.id);
    result("1b binus.edu account is staff", !error && data?.[0]?.user_type === "staff", error ? errMsg(error) : `user_type=${data?.[0]?.user_type}`);
  });

  // 2
  await check("2 A cannot read B", async () => {
    const r1 = await A.from("profiles").select("id").eq("id", userB.id);
    result("2a A select B's row -> 0 rows", !r1.error && r1.data.length === 0, r1.error ? errMsg(r1.error) : `rows=${r1.data.length}`);
    const r2 = await A.from("profiles").select("id");
    const ok = !r2.error && r2.data.length === 1 && r2.data[0].id === userA.id;
    result("2b A select * -> only own row", ok, r2.error ? errMsg(r2.error) : `rows=${r2.data.length}`);
  });

  // 3
  await check("3 A cannot update B", async () => {
    const before = await B.from("profiles").select("nickname").eq("id", userB.id).single();
    const r = await A.from("profiles").update({ nickname: "Hacked" }).eq("id", userB.id).select();
    result("3a A update B's nickname -> 0 rows", !!r.error || r.data.length === 0, r.error ? errMsg(r.error) : `rows=${r.data.length}`);
    const after = await B.from("profiles").select("nickname").eq("id", userB.id).single();
    const ok = !after.error && after.data.nickname === before.data?.nickname && after.data.nickname !== "Hacked";
    result("3b B's row unchanged (read as B)", ok, after.error ? errMsg(after.error) : `nickname=${after.data.nickname}`);
  });

  // 4
  for (const [label, patch] of [
    ["is_admin=true", { is_admin: true }],
    ["user_type='staff'", { user_type: "staff" }],
    ["email change", { email: "rls-other@binus.ac.id" }],
  ]) {
    await check(`4 A update own ${label}`, async () => {
      const r = await A.from("profiles").update(patch).eq("id", userA.id).select();
      result(`4 A update own ${label} -> error`, !!r.error, r.error ? errMsg(r.error) : `unexpected success rows=${r.data?.length}`);
    });
  }
  await check("4d own row still intact", async () => {
    const { data, error } = await A.from("profiles").select("is_admin,user_type,email").eq("id", userA.id).single();
    const ok = !error && data.is_admin === false && data.user_type === "student" && data.email === EMAIL_A;
    result("4d A's is_admin/user_type/email unchanged", ok, error ? errMsg(error) : JSON.stringify(data));
  });

  // 5
  await check("5 A insert/delete", async () => {
    const ins = await A.from("profiles").insert({ id: crypto.randomUUID(), email: "rls-fake@binus.ac.id", user_type: "student" }).select();
    result("5a A insert profile -> error", !!ins.error || ins.data?.length === 0, ins.error ? errMsg(ins.error) : `rows=${ins.data?.length}`);
    const del = await A.from("profiles").delete().eq("id", userA.id).select();
    result("5b A delete own row -> error or 0 rows", !!del.error || del.data?.length === 0, del.error ? errMsg(del.error) : `rows=${del.data?.length}`);
    const still = await A.from("profiles").select("id").eq("id", userA.id);
    result("5c A's row still exists", !still.error && still.data.length === 1, still.error ? errMsg(still.error) : `rows=${still.data.length}`);
  });

  // 6
  await check("6 A updates own nickname", async () => {
    const ok1 = await A.from("profiles").update({ nickname: "RLS Tester" }).eq("id", userA.id).select("nickname");
    result("6a valid nickname update succeeds", !ok1.error && ok1.data?.[0]?.nickname === "RLS Tester", ok1.error ? errMsg(ok1.error) : `rows=${ok1.data?.length}`);
    const bad = await A.from("profiles").update({ nickname: "x" }).eq("id", userA.id).select();
    result("6b 1-char nickname -> check violation (23514)", bad.error?.code === "23514", errMsg(bad.error));
  });

  // 7
  await check("7 get_public_profile", async () => {
    const r = await A.rpc("get_public_profile", { profile_id: userB.id });
    const row = Array.isArray(r.data) ? r.data[0] : r.data;
    const keys = row ? Object.keys(row).sort() : [];
    const expected = ["binusian", "campus", "id", "major", "nickname", "user_type"];
    const ok = !r.error && row && JSON.stringify(keys) === JSON.stringify(expected);
    result("7a A rpc(B) -> only public fields", ok, r.error ? errMsg(r.error) : `keys=${keys.join(",")}`);
    const anon = newAnon();
    const ra = await anon.rpc("get_public_profile", { profile_id: userB.id });
    result("7b anon rpc -> error", !!ra.error, ra.error ? errMsg(ra.error) : "anon call succeeded (anon still has EXECUTE)");
  });

  // 8
  await check("8 anon select profiles", async () => {
    const r = await newAnon().from("profiles").select("*");
    result("8 anon select -> error or 0 rows", !!r.error || r.data.length === 0, r.error ? errMsg(r.error) : `rows=${r.data.length}`);
  });

  // 9 (admin used for creation attempts only)
  for (const email of BAD_EMAILS) {
    await check(`9 reject ${email}`, async () => {
      const { data, error } = await admin.auth.admin.createUser({ email, email_confirm: true });
      result(`9 createUser ${email} -> rejected`, !!error, error ? errMsg(error) : `unexpectedly created ${data.user?.id}`);
    });
  }
  await check("9c anon signInWithOtp gmail", async () => {
    const { error } = await newAnon().auth.signInWithOtp({ email: "rls-z@gmail.com" });
    result("9c anon signInWithOtp(gmail) -> error", !!error, error ? errMsg(error) : "no error returned");
  });

  // 10 (admin used only to attempt the change; the DB trigger must reject it)
  await check("10 email change blocked", async () => {
    const { error } = await admin.auth.admin.updateUserById(userA.id, { email: "rls-other@binus.ac.id", email_confirm: true });
    result("10a admin email change -> error (beekas_block_email_change)", !!error, error ? errMsg(error) : "email change unexpectedly succeeded");
    const { data, error: e2 } = await A.from("profiles").select("email").eq("id", userA.id).single();
    result("10b A's profile email unchanged", !e2 && data.email === EMAIL_A, e2 ? errMsg(e2) : `email=${data.email}`);
  });

  // 11 (0002: campus list, student major+binusian pairing, staff without major)
  await check("11 profile value lists", async () => {
    const campus = await A.from("profiles").update({ campus: "anggrek" }).eq("id", userA.id).select();
    result("11a campus outside list -> check violation (23514)", campus.error?.code === "23514", errMsg(campus.error));
    const noMajor = await A.from("profiles").update({ binusian: "B28", major: null }).eq("id", userA.id).select();
    result("11b student with binusian but no major -> 23514", noMajor.error?.code === "23514", errMsg(noMajor.error));
    const staffMajor = await C.from("profiles").update({ major: "computer_science" }).eq("id", userC.id).select();
    result("11c staff with major -> 23514", staffMajor.error?.code === "23514", errMsg(staffMajor.error));
  });

  await Promise.all([A, B, C].map((c) => c.auth.signOut().catch(() => {})));
}

try {
  await main();
} catch (e) {
  failures++;
  console.error(`FATAL: ${e.message}`);
} finally {
  try {
    await deleteUsersByEmails(ALL_TEST_EMAILS, "cleanup");
    const left = await findUsersByEmails(ALL_TEST_EMAILS);
    if (left.length) {
      failures++;
      console.error(`FAIL  cleanup: ${left.length} test account(s) remain`);
    }
  } catch (e) {
    failures++;
    console.error(`FAIL  cleanup threw: ${e.message}`);
  }
  console.log(failures ? `\n${failures} check(s) failed` : "\nAll checks passed");
  process.exit(failures ? 1 : 0);
}
