import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { expect, it } from "vitest";
import { ALLOWED_EMAIL_DOMAINS } from "./campus-email";
import { CAMPUSES } from "./profile";

it("SQL domain map matches ALLOWED_EMAIL_DOMAINS", () => {
  const sql = readFileSync(resolve(__dirname, "../../../supabase/migrations/0001_profiles.sql"), "utf8");
  const block = sql.match(/-- BEGIN ALLOWED_EMAIL_DOMAINS([\s\S]*?)-- END ALLOWED_EMAIL_DOMAINS/);
  expect(block).not.toBeNull();
  const pairs = Object.fromEntries(
    [...block![1].matchAll(/when '([^']+)' then '([^']+)'/g)].map((m) => [m[1], m[2]]),
  );
  expect(pairs).toEqual(ALLOWED_EMAIL_DOMAINS);
});

it("SQL campus check matches CAMPUSES", () => {
  const sql = readFileSync(resolve(__dirname, "../../../supabase/migrations/0001_profiles.sql"), "utf8");
  const block = sql.match(/-- BEGIN CAMPUSES([\s\S]*?)-- END CAMPUSES/);
  expect(block).not.toBeNull();
  const codes = [...block![1].matchAll(/'([^']+)'/g)].map((m) => m[1]);
  expect(codes).toEqual([...CAMPUSES]);
});
