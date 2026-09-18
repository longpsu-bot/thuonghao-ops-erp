import { test } from "vitest";
import assert from "node:assert/strict";
import {
  nextCent,
  rollbackProbeSql,
} from "./verify-staging-planning-closeout.mjs";
test("staged verification edit uses an exact next-cent value", () => {
  assert.equal(nextCent("1.234567"), "1.24");
  assert.equal(nextCent("1.230000"), "1.24");
  assert.equal(nextCent("90071992547409.910000"), "90071992547409.92");
  assert.throws(() => nextCent("1e4"));
  assert.throws(() => nextCent("-1"));
});
test("rollback probes keep the operator timeout and restrict approved dates", () => {
  const sql = rollbackProbeSql("2026-09-17");
  assert.match(sql, /statement_timeout='8s'/);
  assert.match(sql, /rollback;$/);
  assert.doesNotMatch(sql, /commit;/);
  assert.throws(() => rollbackProbeSql("2026-09-21"));
});
