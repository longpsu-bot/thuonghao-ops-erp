import assert from "node:assert/strict";
import { test } from "vitest";
import * as certification from "./staging-planning-correction-performance.mjs";

test("correction safety ceiling derives from the verified runtime timeout", () => {
  assert.equal(typeof certification.summarizeCorrectionPerformance, "function");
  const report = certification.summarizeCorrectionPerformance(
    [3900, 4200, 4500],
    8000,
  );
  assert.equal(report.derived_ceiling_ms, 6000);
  assert.equal(report.p50_server_ms, 4200);
  assert.equal(report.timeout_utilization_max, 0.5625);
  assert.equal(report.timeout_headroom_ms, 3500);
  assert.equal(report.timeout_headroom_percent, 43.75);
  assert.equal(report.operator_target_met, false);
  assert.equal(
    certification.summarizeCorrectionPerformance([1000, 1800, 2000], 4000)
      .derived_ceiling_ms,
    3000,
  );
  assert.throws(
    () =>
      certification.summarizeCorrectionPerformance(
        [5000, 6000, 6000.001],
        8000,
      ),
    /HEADROOM/,
  );
  for (const timeout of [0, null, -1, Infinity, "8000"])
    assert.throws(
      () => certification.summarizeCorrectionPerformance([1, 2, 3], timeout),
      /TIMEOUT/,
    );
  for (const samples of [[], [1, 2], [1, NaN, 3], [1, -1, 3]])
    assert.throws(
      () => certification.summarizeCorrectionPerformance(samples, 8000),
      /SAMPLES/,
    );
});

test("rollback SQL executes the public command, flushes guards and never commits", () => {
  assert.equal(typeof certification.correctionRollbackSql, "function");
  const sql = certification.correctionRollbackSql({
    command_id: "probe",
    payload: { service_date: "2026-09-17" },
  });
  assert.match(sql, /atlas_api\.execute_need_generation/);
  assert.match(sql, /set local role authenticated/);
  assert.match(sql, /pg_db_role_setting/);
  assert.match(sql, /set constraints all immediate/);
  assert.match(sql, /rollback;\s*$/);
  assert.equal((sql.match(/rollback;/g) ?? []).length, 1);
  assert.doesNotMatch(sql, /as begin read only/);
  assert.doesNotMatch(sql, /statement_timeout\s*=\s*'8s'|\bcommit;/i);
});
