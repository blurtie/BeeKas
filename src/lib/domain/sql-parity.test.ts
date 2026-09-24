import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { expect, it } from "vitest";
import { ALLOWED_EMAIL_DOMAINS } from "./campus-email";
import { CAMPUSES, MAJOR_GROUPS, majorCodes } from "./profile";

const readSql = (file: string) => readFileSync(resolve(__dirname, "../../../supabase/migrations", file), "utf8");

// Quoted codes between "-- BEGIN <name>" and "-- END <name>".
const quotedCodes = (sql: string, name: string) => {
  const block = sql.match(new RegExp(`-- BEGIN ${name}([\\s\\S]*?)-- END ${name}`));
  expect(block).not.toBeNull();
  return [...block![1].matchAll(/'([^']+)'/g)].map((m) => m[1]);
};

it("SQL domain map matches ALLOWED_EMAIL_DOMAINS", () => {
  const block = readSql("0001_profiles.sql").match(/-- BEGIN ALLOWED_EMAIL_DOMAINS([\s\S]*?)-- END ALLOWED_EMAIL_DOMAINS/);
  expect(block).not.toBeNull();
  const pairs = Object.fromEntries(
    [...block![1].matchAll(/when '([^']+)' then '([^']+)'/g)].map((m) => [m[1], m[2]]),
  );
  expect(pairs).toEqual(ALLOWED_EMAIL_DOMAINS);
});

// 0002 replaced the campus check from 0001, so it is the source of truth.
it("SQL campus check matches CAMPUSES", () => {
  expect(quotedCodes(readSql("0002_majors_campuses.sql"), "CAMPUSES")).toEqual([...CAMPUSES]);
});

it("SQL major check matches MAJOR_GROUPS plus OTHER_MAJOR", () => {
  expect(quotedCodes(readSql("0002_majors_campuses.sql"), "MAJORS")).toEqual(majorCodes(MAJOR_GROUPS));
});
