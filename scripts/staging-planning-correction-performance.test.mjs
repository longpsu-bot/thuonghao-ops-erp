import assert from "node:assert/strict";
import { test } from "vitest";
import * as certification from "./staging-planning-correction-performance.mjs";

test("protected correction accepts each statement below 60s without a percentage gate", () => {
  const report = certification.summarizeCorrectionPerformance(
    [5567, 7141, 59000],
    [2, 3, 5000],
    60000,
    8000,
  );
  assert.equal(report.rpc_p50_ms, 7141);
  assert.equal(report.rpc_max_ms, 59000);
  assert.equal(report.rpc_min_ms, 5567);
  assert.equal(report.constraint_flush_p50_ms, 3);
  assert.equal(report.constraint_flush_max_ms, 5000);
  assert.equal(report.execution_policy, "PROTECTED_MAINTENANCE");
  assert.equal(report.effective_protected_statement_timeout_ms, 60000);
  assert.equal(report.normal_authenticated_statement_timeout_ms, 8000);
});
test("correction rejects invalid timing and deviations from approved policies", () => {
  for (const timeout of [0, null, 8000, 120000])
    assert.throws(
      () =>
        certification.summarizeCorrectionPerformance(
          [1, 2, 3],
          [1, 2, 3],
          timeout,
          8000,
        ),
      /TIMEOUT/,
    );
  assert.throws(
    () =>
      certification.summarizeCorrectionPerformance(
        [1, 2, 3],
        [1, 2, 3],
        60000,
        60000,
      ),
    /TIMEOUT/,
  );
  for (const samples of [[], [1, 2], [1, NaN, 3], [1, -1, 3], [1, 2, 60000]])
    assert.throws(
      () =>
        certification.summarizeCorrectionPerformance(
          samples,
          [1, 2, 3],
          60000,
          8000,
        ),
      /SAMPLES|TIMEOUT/,
    );
  assert.throws(
    () =>
      certification.summarizeCorrectionPerformance(
        [1, 2, 3],
        [1, 2, 60000],
        60000,
        8000,
      ),
    /TIMEOUT/,
  );
});
test("rollback and persistence share the authenticated transaction-local SQL envelope", () => {
  for (const [build, ending] of [
    [certification.correctionRollbackSql, "rollback"],
    [certification.correctionPersistenceSql, "commit"],
  ]) {
    assert.equal(typeof build, "function");
    const sql = build({
      command_id: "probe",
      requested_by_auth_subject: "a1010000-0000-4000-8000-000000000101",
    });
    assert.match(sql, /set local statement_timeout\s*=\s*'60s'/i);
    assert.match(sql, /set local role authenticated/);
    assert.match(
      sql,
      /set local request.jwt.claims=.*a1010000-0000-4000-8000-000000000101/,
    );
    assert.equal(
      (sql.match(/atlas_api\.execute_need_generation\(/g) ?? []).length,
      1,
    );
    assert.match(sql, /pg_db_role_setting/);
    assert.match(sql, /set constraints all immediate/);
    assert.match(sql, /rpc_ms/);
    assert.match(sql, /constraint_flush_ms/);
    assert.match(sql, new RegExp(`${ending};\\s*$`));
    assert.doesNotMatch(
      sql,
      /alter role|service_role|insert into atlas_|update atlas_/i,
    );
  }
});
