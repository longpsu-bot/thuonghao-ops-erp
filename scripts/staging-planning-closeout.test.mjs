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

test("rollback review starts a new statement after materializing generation", () => {
  const sql = rollbackProbeSql("2026-09-17");
  // A STABLE review in the generation statement cannot see its new batch.
  // Preserve atomic rollback, but mirror the browser's separate read request.
  const generationEnd = sql.indexOf("from generated;");
  const reviewCall = sql.indexOf("atlas_api.get_confirmed_need_review");
  assert.ok(generationEnd >= 0 && generationEnd < reviewCall);
  assert.match(sql, /create temp table planning_closeout_probe_result/);
  assert.match(sql, /insert into planning_closeout_probe_result/);
  assert.match(sql, /'review_error_code',review->>'error_code'/);
  assert.match(sql, /rollback;$/);
  assert.doesNotMatch(sql, /commit;/);
});
