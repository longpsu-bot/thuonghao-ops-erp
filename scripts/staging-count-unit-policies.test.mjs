import { test } from "vitest";
import assert from "node:assert/strict";
import {
  buildCountPolicySql,
  installCountPolicies,
} from "./install-staging-count-unit-policies.mjs";

test("dry-run executes the same exact package but rolls back", () => {
  const query = buildCountPolicySql({ dryRun: true });
  assert.match(query, /begin;/);
  assert.match(query, /rollback;$/);
  assert.doesNotMatch(query, /commit;/);
  assert.match(query, /2026-09-14/);
  assert.equal((query.match(/\('v1-unit-/g) ?? []).length, 14);
});
test("installation commits only the approved package, never a dimension fallback", () => {
  const query = buildCountPolicySql();
  assert.match(query, /commit;$/);
  assert.match(query, /STAGING_COUNT_POLICY_CONFLICT/);
  assert.match(query, /STAGING_COUNT_POLICY_LIVE_SENTINEL/);
  assert.doesNotMatch(
    query,
    /insert into atlas_admin.units|create table|create or replace function|alter role/i,
  );
});
test("unknown deployment targets fail before executing SQL", async () => {
  let calls = 0;
  await assert.rejects(() =>
    installCountPolicies({
      environment: { ATLAS_STAGING_PROJECT_REF: "qnthofvccilhnefdcxnz" },
      executeSql: async () => {
        calls++;
      },
    }),
  );
  assert.equal(calls, 0);
});
