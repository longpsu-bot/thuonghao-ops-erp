import { test, vi } from "vitest";
import assert from "node:assert/strict";
import {
  buildCountPolicySql,
  installCountPolicies,
} from "./install-staging-count-unit-policies.mjs";

vi.mock("./install-atlas-staging-package.mjs", () => ({
  verifyPackageCheckout: vi.fn(),
}));

const environment = {
  ATLAS_STAGING_PROJECT_REF: "rnzxmxiiqgtdevzregff",
  VITE_ATLAS_ENVIRONMENT: "staging",
  VITE_SUPABASE_URL: "https://rnzxmxiiqgtdevzregff.supabase.co",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic_test_key",
  ATLAS_STAGING_TEST_EMAIL: "operator@example.test",
  ATLAS_STAGING_TEST_PASSWORD: "synthetic-test-password",
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-access-token",
};

test.each([false, true])(
  "accepts all fifteen approved Unit policies (rollback=%s)",
  async (dryRun) => {
    const executeSql = vi.fn(async (_target, query) => {
      assert.match(query, dryRun ? /rollback;$/ : /commit;$/);
      return JSON.stringify([{ count_policy_result: { policy_count: 15 } }]);
    });
    assert.deepEqual(
      await installCountPolicies({
        commitSha: "a".repeat(40),
        environment,
        dryRun,
        executeSql,
      }),
      {
        status: dryRun ? "verified-rollback" : "installed",
        policies: 15,
        effectiveFrom: "2026-09-14",
      },
    );
    assert.equal(executeSql.mock.calls.length, 1);
  },
);

test("rejects the old fourteen-policy readback", async () => {
  await assert.rejects(
    () =>
      installCountPolicies({
        commitSha: "a".repeat(40),
        environment,
        executeSql: async () =>
          JSON.stringify([{ count_policy_result: { policy_count: 14 } }]),
      }),
    /STAGING_COUNT_POLICY_READBACK_MISMATCH/,
  );
});

test("dry-run executes the same exact package but rolls back", () => {
  const query = buildCountPolicySql({ dryRun: true });
  assert.match(query, /begin;/);
  assert.match(query, /rollback;$/);
  assert.doesNotMatch(query, /commit;/);
  assert.match(query, /2026-09-14/);
  assert.equal((query.match(/\('v1-unit-/g) ?? []).length, 15);
  assert.match(query, /\('v1-unit-67df33ade68a','Túi'\)/);
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
