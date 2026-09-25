import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { expect, it } from "vitest";
import { ALLOWED_EMAIL_DOMAINS } from "./campus-email";
import { CAMPUSES, MAJOR_GROUPS, majorCodes } from "./profile";
import { CREDIT_REASONS } from "./credits";
import {
  DESCRIPTION_MAX,
  LISTING_CATEGORIES,
  LISTING_CONDITIONS,
  LISTING_TYPES,
  MEETUP_NOTE_MAX,
  PRICE_MAX,
  PRICE_MIN,
  TITLE_MAX,
  TITLE_MIN,
} from "./listing";
import { LISTING_PHOTO_BUCKET, PHOTO_MAX_BYTES } from "./listing-photo";

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

it("SQL ledger reason check matches CREDIT_REASONS", () => {
  expect(quotedCodes(readSql("0003_credit_ledger.sql"), "CREDIT_REASONS")).toEqual([...CREDIT_REASONS]);
});

it("SQL listing photo bucket matches LISTING_PHOTO_BUCKET and PHOTO_MAX_BYTES", () => {
  const sql = readSql("0004_listing_photos.sql");
  expect(sql).toContain(`values ('${LISTING_PHOTO_BUCKET}', '${LISTING_PHOTO_BUCKET}', true, ${PHOTO_MAX_BYTES},`);
});

it("SQL listing value lists match listing.ts and CAMPUSES", () => {
  const sql = readSql("0005_listings.sql");
  expect(quotedCodes(sql, "LISTING_TYPES")).toEqual([...LISTING_TYPES]);
  expect(quotedCodes(sql, "LISTING_CATEGORIES")).toEqual([...LISTING_CATEGORIES]);
  expect(quotedCodes(sql, "LISTING_CONDITIONS")).toEqual([...LISTING_CONDITIONS]);
  expect(quotedCodes(sql, "LISTING_CAMPUSES")).toEqual([...CAMPUSES]);
});

it("SQL listing limits match listing.ts", () => {
  const sql = readSql("0005_listings.sql");
  expect(sql).toContain(`price between ${PRICE_MIN} and ${PRICE_MAX}`);
  expect(sql).toContain(`char_length(title) between ${TITLE_MIN} and ${TITLE_MAX}`);
  expect(sql).toContain(`char_length(description) between 1 and ${DESCRIPTION_MAX}`);
  expect(sql).toContain(`char_length(meetup_note) between 1 and ${MEETUP_NOTE_MAX}`);
});
