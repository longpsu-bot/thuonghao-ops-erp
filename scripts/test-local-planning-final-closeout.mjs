import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { randomUUID } from "node:crypto";
import {
  planningCloseoutLocalFixtureSql,
  localSql,
} from "./planning-closeout-local-fixture.mjs";
import {
  correctionRollbackSql,
  summarizeCorrectionPerformance,
} from "./staging-planning-correction-performance.mjs";
import { planningCloseoutSnapshotSql } from "./verify-staging-planning-closeout.mjs";
import { repositorySupabaseCliInvocation } from "./atlas-staging-contract.mjs";

// No target argument, network credential, or hosted transport. This harness
// owns the disposable CLI database and always restores the current empty schema.
const container = "supabase_db_thuonghao-ops-erp";
const subject = "a7400000-0000-4000-8000-000000000101";
function cli(...args) {
  const invocation = repositorySupabaseCliInvocation(args);
  const r = spawnSync(invocation.command, invocation.args, {
    encoding: "utf8",
    shell: invocation.shell,
    maxBuffer: 8 * 1024 * 1024,
  });
  if (r.status !== 0) throw new Error(r.stderr || "LOCAL_CLI_FAILED");
}
export async function certifyLocalFinalCloseout({
  seed = true,
  restore = true,
} = {}) {
  try {
    if (seed) {
      cli("db", "reset", "--local", "--no-seed", "--version", "20260920154302");
      localSql(planningCloseoutLocalFixtureSql());
      cli("migration", "up", "--local");
      // The retained hosted checkpoint is populated, while a reset database
      // has no statistics until autovacuum eventually visits it. Establish
      // ordinary statistics once after bulk loading, before the FIRST public
      // correction. No warm-up command or sample is discarded; the hosted
      // verifier never performs this fixture-only maintenance.
      localSql(`do $analyze$ declare r record; populated boolean; begin
        for r in select schemaname,relname from pg_stat_user_tables
          where schemaname in ('atlas_admin','atlas_planning','atlas_core','atlas_legacy') loop
          execute format('select exists(select 1 from %I.%I)',r.schemaname,r.relname) into populated;
          if populated then execute format('analyze %I.%I',r.schemaname,r.relname); end if;
        end loop;
      end $analyze$;`);
    }
    const identity = localSql(
      "select jsonb_build_object('run',need_generation_run_id,'batch',(select confirmed_need_batch_id from atlas_planning.confirmed_need_batches)) from atlas_planning.need_generation_runs where period_start='2050-09-19' and predecessor_need_generation_run_id is null;",
    )[0];
    assert.ok(identity?.run);
    const adapt = (sql) =>
      sql
        .replaceAll("2026-09-14", "2050-09-19")
        .replaceAll("2026-09-20", "2050-09-25")
        .replaceAll("2026-09-17", "2050-09-19")
        .replaceAll("0c83b440-8fb2-4a77-9735-804ef4c89ea0", identity.run)
        .replaceAll("a1010000-0000-4000-8000-000000000101", subject);
    const snapshot = () => localSql(adapt(planningCloseoutSnapshotSql()))[0];
    const before = snapshot();
    assert.equal(before.receipts.length, 3);
    assert.equal(
      before.receipts.filter((r) => r.idempotency_status === "NO_CHANGE")
        .length,
      1,
    );
    assert.equal(
      before.receipts.filter(
        (r) =>
          r.outcome === "FAILED_NON_RETRYABLE" &&
          r.retryable === true &&
          r.error_code === "RETRYABLE_CONCURRENCY_FAILURE",
      ).length,
      1,
    );
    const samples = [];
    let timeout;
    for (let i = 0; i < 3; i++) {
      const id = randomUUID();
      const request = {
        contract_version: "RMVP-04.v3",
        command_id: id,
        correlation_id: randomUUID(),
        idempotency_key: `planning-d046-correction:${id}`,
        expected_version: 3,
        requested_by_auth_subject: subject,
        requested_at: new Date().toISOString(),
        reason_code: "NEED_GENERATION_EXECUTED",
        reason_note: "Disposable local correction certification",
        payload: {
          service_date: "2050-09-19",
          expected_current_need_generation_run_id: identity.run,
        },
      };
      const started = performance.now();
      const probe = localSql(adapt(correctionRollbackSql(request)))[0];
      assert.equal(
        probe.response.success,
        true,
        JSON.stringify(probe.response),
      );
      assert.deepEqual(
        snapshot(),
        before,
        "rollback must preserve every captured fact",
      );
      const c = probe.checkpoint;
      assert.equal(c.receipts.length, 4);
      assert.equal(c.runs.length, 2);
      assert.equal(c.runs[0].status, "INVALIDATED");
      assert.equal(c.runs[0].version, 4);
      assert.equal(c.runs[1].predecessor_run_id, identity.run);
      assert.equal(c.runs[1].status, "RELEASED_FOR_CONFIRMATION");
      assert.equal(c.runs[1].version, 3);
      assert.equal(c.runs[1].generated_line_count, 304);
      assert.equal(c.batches[0].id, identity.batch);
      assert.equal(c.batches[0].version, 2);
      assert.equal(c.batches[0].line_count, 248);
      assert.equal(
        c.batches[0].stable_line_count,
        249,
        "changed Unit retires one immutable identity",
      );
      assert.equal(c.batches[0].decision_count, 0);
      assert.equal(c.save_receipt_count, 0);
      assert.equal(c.handoffs, 0);
      assert.deepEqual(
        c.preflight.source_date_fingerprints,
        before.preflight.source_date_fingerprints,
      );
      assert.deepEqual(c.d046, {
        predecessor_release_contribution_count: 304,
        successor_release_contribution_count: 304,
        current_snapshot_pair_count: 248,
        exact_proposal_count: 248,
        invalid_proposal_count: 0,
        retained_pre_d046_null_pair_count: 248,
        allowed_unit_transition_count: 1,
        invalid_unit_transition_count: 0,
        current_raw_membership_count: 304,
      });
      samples.push(probe.server_ms);
      timeout = probe.effective_statement_timeout_ms;
      console.log(
        JSON.stringify({
          local_correction_probe: i + 1,
          server_ms: probe.server_ms,
          end_to_end_ms: performance.now() - started,
        }),
      );
    }
    const report = {
      status: "LOCAL_D046_CORRECTION_ROLLBACK_PASS",
      ...summarizeCorrectionPerformance(samples, timeout),
      checkpointPreserved: true,
      correctionBusinessProof: true,
    };
    console.log(JSON.stringify(report));
    const normal = [];
    for (const date of [
      "2050-09-20",
      "2050-09-20",
      "2050-09-21",
      "2050-09-22",
      "2050-09-23",
    ]) {
      const id = randomUUID();
      const request = {
        contract_version: "RMVP-04.v3",
        command_id: id,
        correlation_id: randomUUID(),
        idempotency_key: `local-normal:${id}`,
        expected_version: 1,
        requested_by_auth_subject: subject,
        requested_at: new Date().toISOString(),
        reason_code: "NEED_GENERATION_EXECUTED",
        reason_note: "Disposable fresh-generation regression",
        payload: {
          service_date: date,
          expected_current_need_generation_run_id: null,
        },
      };
      const probe = localSql(adapt(correctionRollbackSql(request)))[0];
      assert.equal(probe.response.success, true);
      assert.deepEqual(snapshot(), before);
      const batch = probe.checkpoint.batches.find(
        (b) => b.period_start === date,
      );
      const run = probe.checkpoint.runs.find((r) => r.period_start === date);
      assert.equal(batch.line_count, 248);
      assert.equal(batch.decision_count, 0);
      assert.equal(run.generated_line_count, 304);
      assert.equal(run.release_snapshot_line_count, 304);
      assert.equal(probe.checkpoint.handoffs, 0);
      assert.ok(
        probe.server_ms < 7000,
        "preserve existing normal-generation performance contract",
      );
      normal.push(probe.server_ms);
    }
    const sorted = [...normal].sort((a, b) => a - b);
    const normalReport = {
      status: "LOCAL_GENERATION_PERFORMANCE_PASS",
      samples_server_ms: normal,
      p50_server_ms: sorted[2],
      p95_server_ms: sorted[4],
      operator_target_ms: 4000,
      operator_target_met: sorted[4] <= 4000,
      geometry:
        "304 contributions / 248 groups on five fresh rollback probes; hosted 24/8/3 workload separately guarded",
    };
    console.log(JSON.stringify(normalReport));
    const tap = spawnSync(
      "docker",
      [
        "exec",
        "-i",
        container,
        "psql",
        "-X",
        "-U",
        "postgres",
        "-d",
        "postgres",
        "-v",
        "ON_ERROR_STOP=1",
        "-qAt",
      ],
      {
        input: readFileSync(
          "supabase/tests/planning_final_closeout.sql",
          "utf8",
        ),
        encoding: "utf8",
        maxBuffer: 8 * 1024 * 1024,
      },
    );
    if (tap.status !== 0 || /(^|\n)not ok/.test(tap.stdout))
      throw new Error(tap.stderr + tap.stdout);
    console.log(tap.stdout);
    let browser;
    if (!process.argv.includes("--skip-browser")) {
      const { certifyLocalCloseoutBrowser } =
        await import("./test-local-planning-closeout-browser.mjs");
      browser = await certifyLocalCloseoutBrowser();
    }
    writeFileSync(
      join(
        process.env.RUNNER_TEMP ?? tmpdir(),
        "atlas-planning-final-closeout.json",
      ),
      JSON.stringify(
        { correction: report, normal: normalReport, browser },
        null,
        2,
      ),
    );
    return report;
  } finally {
    if (restore) cli("db", "reset", "--local", "--no-seed");
  }
}
if (process.argv[1] === fileURLToPath(import.meta.url))
  await certifyLocalFinalCloseout({
    seed: !process.argv.includes("--existing-fixture"),
    restore: !process.argv.includes("--keep-fixture"),
  });
