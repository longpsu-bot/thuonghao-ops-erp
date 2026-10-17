import { spawn, spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { writeFileSync, readFileSync } from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { expand } from "./test-local-purchase-review.mjs";
import { snapshotSql } from "./diagnose-confirmed-need-preparation.mjs";

// A separately created, task-owned disposable database; never the shared stack.
const verifyRecovery = process.argv[2] === "--verify-recovery";
const recoveryOnly = process.argv[2] === "--recovery-only" || verifyRecovery;
const container = "atlas-c395-option-a",
  db = recoveryOnly ? "c395_recovery" : "c395_concurrency";
const directory = process.env.C395_EVIDENCE_DIR;
if (!directory) throw new Error("Set C395_EVIDENCE_DIR.");
const args = [
  "exec",
  "-i",
  container,
  "psql",
  "-X",
  "-qAt",
  "-v",
  "ON_ERROR_STOP=1",
  "-U",
  "postgres",
  "-d",
  db,
];
const quote = (value) =>
  "'" + JSON.stringify(value).replaceAll("'", "''") + "'::jsonb";
function sql(text) {
  const r = spawnSync("docker", args, {
    input: text,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
    timeout: 30000,
  });
  if (r.status !== 0) throw new Error(r.stderr);
  return r.stdout.trim();
}
const actor = "c0150000-0000-4000-8000-000000000101";
const auth = `set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);`;
const command = (contract, reason, version, payload) => ({
  contract_version: contract,
  command_id: randomUUID(),
  correlation_id: randomUUID(),
  idempotency_key: randomUUID(),
  expected_version: version,
  requested_by_auth_subject: actor,
  requested_at: new Date().toISOString(),
  reason_code: reason,
  reason_note: "Issue395 actual competing-session probe",
  payload,
});
const read = (contract, payload) => ({
  contract_version: contract,
  correlation_id: randomUUID(),
  requested_by_auth_subject: actor,
  payload,
});
const invoke = (api, request, commit = false) => {
  const out = sql(
    `begin;set local statement_timeout='8s';set local lock_timeout='1s';${auth}select atlas_api.${api}(${quote(request)});reset role;set constraints all immediate;${commit ? "commit" : "rollback"};`,
  );
  return JSON.parse(out.split(/\r?\n/).find((line) => line.startsWith("{")));
};
const image = () => {
  const v = JSON.parse(sql(snapshotSql));
  delete v.physical;
  return JSON.stringify(v);
};
const children = new Set();
function child(text) {
  const p = spawn("docker", args, { stdio: ["pipe", "pipe", "pipe"] });
  children.add(p);
  p.output = "";
  p.error = "";
  p.stdout.on("data", (v) => (p.output += v));
  p.stderr.on("data", (v) => (p.error += v));
  p.done = new Promise((resolve) =>
    p.on("close", (code) => {
      children.delete(p);
      resolve(code);
    }),
  );
  p.stdin.on("error", () => {});
  p.stdin.write(text);
  return p;
}
async function until(test, message) {
  const start = Date.now();
  while (Date.now() - start < 12000) {
    if (test()) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(message);
}

const summary = {
  cases: [],
  unknownRecovery: false,
  limitation:
    "Small shared-location fixture; lock/retry/rollback evidence, not a 250-family concurrency benchmark or proof of every possible deadlock schedule.",
};
try {
  if (verifyRecovery) {
    const request = JSON.parse(
      readFileSync(path.join(directory, "unknown-original-request.json")),
    );
    const original = JSON.parse(
      sql(
        `select response_payload from atlas_core.command_receipts where command_id='${request.command_id}' and outcome='COMPLETED';`,
      ),
    );
    const before = image();
    const recovered = invoke("correct_confirmed_need", request, true);
    assert.deepEqual(recovered, original);
    assert.equal(recovered.command_id, request.command_id);
    assert.equal(image(), before);
    summary.unknownRecovery = true;
    summary.exactStoredResponseReplay = true;
    summary.recoveredReceiptId = recovered.receipt_id;
    summary.retainedOriginalCommandId = request.command_id;
    summary.pass = true;
  } else {
    assert.equal(
      sql("select count(*) from atlas_planning.confirmed_need_lines;"),
      "0",
      "Require a new empty task-owned clone",
    );
    sql(
      `begin;${expand("supabase/local/confirmed_need_correction_fixture.sql")}commit;`,
    );
    const payload = JSON.parse(
      sql(`select jsonb_build_object('need_generation_run_id',run.need_generation_run_id,'expected_need_generation_run_version',run.version,
   'confirmed_need_batch_id',b.confirmed_need_batch_id,'expected_confirmed_need_batch_version',b.version,
   'confirmed_need_line_id',l.confirmed_need_line_id,'expected_current_revision_id',r.confirmed_need_line_revision_id,
   'expected_current_decision_id',l.current_confirmed_need_line_decision_id,'proposed_confirmed_quantity',(r.confirmed_quantity+1)::text,
   'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Issue395 two-session correction')
   from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
   join atlas_planning.confirmed_need_batches b on b.confirmed_need_batch_id=l.confirmed_need_batch_id
   join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
   where r.school_id='b6500000-0000-0000-0000-000000000004' and r.ingredient_id='b6500000-0000-0000-0000-000000000006' and r.service_date='2026-11-02';`),
    );
    const preview = invoke(
      "get_confirmed_need_correction_preview",
      read("CONFIRMED-NEED-CORRECTION.v1", payload),
    );
    assert.equal(preview.success, true);
    const request = command(
      "CONFIRMED-NEED-CORRECTION.v1",
      "CONFIRMED_NEED_CORRECTION_SAVED",
      payload.expected_confirmed_need_batch_version,
      { ...payload, proposal_fingerprint: preview.proposal_fingerprint },
    );
    const family = JSON.parse(
      sql(`select jsonb_build_object('version',f.version,'family',jsonb_build_object('service_date',f.service_date,'delivery_location_id',f.delivery_location_id,'ingredient_id',f.ingredient_id,'unit_id',f.unit_id,'expected_source_fingerprint',atlas_core.school_catering_family_projection(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->>'source_fingerprint'),
   'splits',(select jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,'allocated_quantity',s.allocated_quantity::text,'supplier_note','Issue395 competing PH Save')) from atlas_procurement.school_catering_allocation_supplier_splits s where s.family_revision_id=r.family_revision_id))
   from atlas_procurement.school_catering_allocation_families f join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
   where r.is_current and f.service_date='2026-11-02' and f.delivery_location_id='b6500000-0000-0000-0000-000000000002' and f.ingredient_id='b6500000-0000-0000-0000-000000000006';`),
    );
    const holders = [
      [
        "public PH allocation Save",
        "save_school_catering_supplier_allocation",
        command(
          "SCHOOL-CATERING-PROCUREMENT.v1",
          "SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED",
          family.version,
          { family: family.family, splits: family.splits },
        ),
      ],
      [
        "public correction including contributing CN Save",
        "correct_confirmed_need",
        { ...request, command_id: randomUUID(), idempotency_key: randomUUID() },
      ],
      [
        "overlapping public Preparation",
        "prepare_school_catering_purchase_orders",
        command(
          "PURCHASE-COMMITMENT.v1",
          "PURCHASE_ORDERS_PREPARED",
          payload.expected_confirmed_need_batch_version,
          {
            confirmed_need_batch_id: payload.confirmed_need_batch_id,
            service_date: "2026-11-02",
          },
        ),
      ],
    ];
    for (const [name, api, holderRequest] of recoveryOnly ? [] : holders) {
      const before = image();
      const holder = child(
        `begin;set local application_name='c395_holder';set local statement_timeout='20s';set local lock_timeout='1s';${auth}select atlas_api.${api}(${quote(holderRequest)});\n\\echo HOLDER_READY\n`,
      );
      await until(
        () => holder.output.includes("HOLDER_READY"),
        "Holder did not acquire command locks: " + holder.error,
      );
      const holderResult = JSON.parse(
        holder.output.split(/\r?\n/).find((line) => line.startsWith("{")),
      );
      assert.equal(holderResult.success, true, JSON.stringify(holderResult));
      const contender = child(
        `begin;set local application_name='c395_contender';set local statement_timeout='8s';set local lock_timeout='1s';${auth}select atlas_api.correct_confirmed_need(${quote(request)});reset role;commit;\n`,
      );
      contender.stdin.end();
      await until(
        () =>
          sql(
            "select exists(select 1 from pg_stat_activity where application_name='c395_contender' and wait_event_type='Lock' and cardinality(pg_blocking_pids(pid))>0);",
          ) === "t",
        "No actual blocking wait observed",
      );
      const exit = await contender.done;
      holder.stdin.end("rollback;\n");
      assert.equal(await holder.done, 0);
      assert.equal(exit, 0);
      const response = JSON.parse(
        contender.output.split(/\r?\n/).find((line) => line.startsWith("{")),
      );
      assert.equal(response.error_code, "RETRYABLE_CONCURRENCY_FAILURE");
      assert.equal(
        image(),
        before,
        "Failed contender or rolled-back holder left residue",
      );
      const retry = invoke("correct_confirmed_need", request);
      assert.equal(retry.success, true, JSON.stringify(retry));
      assert.equal(image(), before, "Rolled-back exact retry left residue");
      summary.cases.push({
        name,
        actualLockWaitObserved: true,
        retryableRejection: response.error_code,
        exactRetrySuccess: true,
        rollbackParity: true,
        deadlockObserved: false,
      });
    }
    // Lose the actual transport after the server commits, before reading its response.
    writeFileSync(
      path.join(directory, "unknown-original-request.json"),
      JSON.stringify(request, null, 2),
    );
    const lost = child(
      `set application_name='c395_lost';\\o /dev/null\nbegin;set local statement_timeout='8s';${auth}select atlas_api.correct_confirmed_need(${quote(request)});reset role;set constraints all immediate;commit;select pg_sleep(30);\n`,
    );
    lost.stdin.end();
    await until(
      () =>
        sql(
          `select exists(select 1 from atlas_core.command_receipts where command_id='${request.command_id}' and outcome='COMPLETED');`,
        ) === "t",
      "Lost-response command did not commit",
    );
    sql(
      "select pg_terminate_backend(pid) from pg_stat_activity where datname=current_database() and application_name='c395_lost';",
    );
    assert.notEqual(
      await lost.done,
      0,
      "Expected a disconnected command transport",
    );
    const committed = image();
    const recovered = invoke("correct_confirmed_need", request, true);
    const original = JSON.parse(
      sql(
        `select response_payload from atlas_core.command_receipts where command_id='${request.command_id}' and outcome='COMPLETED';`,
      ),
    );
    assert.deepEqual(recovered, original);
    assert.equal(recovered.command_id, request.command_id);
    assert.equal(recovered.success, true);
    assert.equal(
      image(),
      committed,
      "Recovery appended effects instead of receipt replay",
    );
    summary.unknownRecovery = true;
    summary.recoveredReceiptId = recovered.receipt_id;
    summary.retainedOriginalCommandId = request.command_id;
    summary.pass = true;
  }
} catch (error) {
  summary.pass = false;
  summary.error = error.message;
  process.exitCode = 1;
} finally {
  if (children.size) {
    try {
      sql(
        "select pg_terminate_backend(pid) from pg_stat_activity where datname=current_database() and application_name in ('c395_holder','c395_contender','c395_lost');",
      );
    } catch {}
    for (const p of children) {
      p.stdin.destroy();
      p.kill();
    }
    await Promise.race([
      Promise.all([...children].map((p) => p.done)),
      new Promise((resolve) => setTimeout(resolve, 2000)),
    ]);
    for (const p of children) {
      p.stdout.destroy();
      p.stderr.destroy();
      p.unref();
    }
  }
  writeFileSync(
    path.join(
      directory,
      verifyRecovery
        ? "unknown-recovery-exact-replay.json"
        : recoveryOnly
          ? "unknown-recovery-summary.json"
          : "concurrency-summary.json",
    ),
    JSON.stringify(summary, null, 2),
  );
  console.log(JSON.stringify(summary));
}
