// Disposable PostgreSQL only: template must contain the applied K1 migration.
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const [container, template, output] = process.argv.slice(2);
assert(
  container && template && output,
  "Usage: node scripts/test-local-atlas-c-k1-concurrency.mjs <container> <template-db> <result.json>",
);
const prefix = `k1_source_${process.pid}`;
const root = path.resolve(import.meta.dirname, "..");
const results = [];
const args = (db) => [
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
function run(db, sql) {
  const r = spawnSync("docker", args(db), {
    input: sql,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
  });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function clone(db, source) {
  const r = spawnSync(
    "docker",
    ["exec", container, "createdb", "-U", "postgres", "-T", source, db],
    { encoding: "utf8" },
  );
  assert.equal(r.status, 0, r.stderr);
}
function expand(file) {
  return readFileSync(file, "utf8").replace(/^\\ir\s+(.+)$/gm, (_, name) =>
    expand(path.resolve(path.dirname(file), name.trim())),
  );
}
async function until(predicate, label) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw Error(`Missing observed boundary: ${label}`);
}
function session(db, name) {
  const p = spawn("docker", args(db));
  const s = { p, name, out: "", err: "" };
  p.stdout.on("data", (d) => (s.out += d));
  p.stderr.on("data", (d) => (s.err += d));
  s.done = new Promise((resolve) => p.on("close", resolve));
  p.stdin.write(
    `set application_name='${name}'; begin; set local statement_timeout='8s';\n`,
  );
  return s;
}
function blockers(db, name) {
  return JSON.parse(
    run(
      db,
      `select coalesce(jsonb_agg(b.application_name),'[]') from pg_stat_activity a join pg_stat_activity b on b.pid=any(pg_blocking_pids(a.pid)) where a.datname=current_database() and a.application_name='${name}';`,
    ),
  );
}
const actor = (subject) =>
  `set local role authenticated; select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-${subject}',true);`;
const save = `${actor("000000000101")} insert into k1_results select 'race_need',atlas_api.save_confirmed_needs(request) from k1_requests where name='correction110'; select 'NEED_RETURNED';\n`;
const sources = [
  ["menu", "weekly_menus", "weekly_menu_id", "reopen_weekly_menu", "null"],
  [
    "attendance",
    "attendance_batches",
    "attendance_batch_id",
    "reopen_attendance",
    "null",
  ],
  [
    "pantry",
    "pantry_need_batches",
    "pantry_need_batch_id",
    "reopen_pantry",
    "source_signature",
  ],
];

try {
  clone(prefix, template);
  const fixture = expand(
    path.join(root, "supabase/tests/atlas_c_need_correction_authority.sql"),
  );
  const marker = "create function pg_temp.k1_reject_case";
  assert.equal(fixture.split(marker).length, 2);
  let setup = fixture
    .split(marker)[0]
    .replaceAll("create temporary table", "create table");
  setup += `
insert into atlas_core.actors(actor_id,actor_type,display_name) values('b6000000-0000-0000-0000-000000000011','HUMAN','K1 source race operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values('b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000111');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values('b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes(actor_id,scope_kind,reason_note) values('b6000000-0000-0000-0000-000000000011','GLOBAL','K1 disposable source race');
insert into atlas_core.role_capabilities(role_id,capability_id) select 'b6000000-0000-0000-0000-000000000003',capability_id from atlas_core.capabilities where capability_code='planning.inputs.approve' on conflict do nothing;
create table k1_race_baseline as select pg_temp.k1_snapshot() history,
pg_temp.k1_snapshot(true)-array['atlas_core.command_receipts','atlas_audit.domain_events','atlas_audit.audit_events'] working;
`;
  for (const [source, table, , , signature] of sources) {
    setup += `insert into k1_requests select '${source}_reopen',pg_temp.k1_command('RMVP-03A.v1','SOURCE_CORRECTION',version,jsonb_build_object('week_start','2026-11-02','expected_source_signature',${signature}))||jsonb_build_object('requested_by_auth_subject','b6000000-0000-0000-0000-000000000111','reason_note','Disposable concurrent source correction') from atlas_planning.${table} where ${source === "attendance" ? "period_start" : "week_start"}='2026-11-02';\n`;
  }
  // Pantry has its own retained command envelope contract.
  setup +=
    "update k1_requests set request=jsonb_set(request,'{contract_version}','\"PANTRY-02.v1\"') where name='pantry_reopen'; commit;";
  const setupLog = run(prefix, setup);
  assert(!/^not ok\b/m.test(setupLog), setupLog);
  writeFileSync(output + ".setup.log", setupLog);

  for (const [source, , , rpc] of sources) {
    for (const winner of ["source", "correction"]) {
      const db = `${prefix}_${source}_${winner}`;
      clone(db, prefix);
      const held = session(db, "k1_revision_holder");
      const need = session(db, "k1_need_actor");
      const upstream = session(db, "k1_source_actor");
      const sessions = [held, need, upstream];
      const evidence = { source, winner };
      try {
        evidence.advisoryCorrectionEligible = run(
          db,
          "select response#>>'{workbench,allowed_actions,correct_released_confirmed_needs}' from k3_released_read;",
        );
        assert.equal(evidence.advisoryCorrectionEligible, "true");
        held.p.stdin.write(
          "select r.confirmed_need_line_revision_id from atlas_planning.confirmed_need_line_revisions r join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id) where l.ingredient_id='b6500000-0000-0000-0000-000000000006' and r.is_current for update of r; select 'REVISION_HELD';\n",
        );
        await until(() => held.out.includes("REVISION_HELD"), "revision held");
        const reopen = `${actor("000000000111")} insert into k1_results select 'race_source',atlas_api.${rpc}(request) from k1_requests where name='${source}_reopen'; select 'SOURCE_RETURNED';\n`;
        if (winner === "source") {
          upstream.p.stdin.write(reopen);
          await until(
            () => upstream.out.includes("SOURCE_RETURNED"),
            "source returned uncommitted",
          );
          need.p.stdin.write(save);
          await until(() => blockers(db, need.name).length > 0, "Save waits");
          evidence.saveBlockers = blockers(db, need.name);
          assert(
            evidence.saveBlockers.includes(upstream.name),
            JSON.stringify(evidence),
          );
          upstream.p.stdin.end("commit;\n");
          assert.equal(await upstream.done, 0, upstream.err);
          // The held revision must not be needed to reject stale authority.
          await until(
            () => need.out.includes("NEED_RETURNED"),
            "Save rejected before revision wait",
          );
          need.p.stdin.end("commit;\n");
          held.p.stdin.end("commit;\n");
        } else {
          need.p.stdin.write(save);
          await until(
            () => blockers(db, need.name).includes(held.name),
            "Save reached revision wait",
          );
          upstream.p.stdin.write(reopen);
          await until(
            () =>
              blockers(db, upstream.name).length > 0 ||
              upstream.out.includes("SOURCE_RETURNED"),
            "source waits",
          );
          evidence.sourceBlockersDuringRevisionWait = blockers(
            db,
            upstream.name,
          );
          assert(
            evidence.sourceBlockersDuringRevisionWait.includes(need.name),
            JSON.stringify(evidence),
          );
          held.p.stdin.end("commit;\n");
          assert.equal(await held.done, 0, held.err);
          await until(
            () => need.out.includes("NEED_RETURNED"),
            "Save returned uncommitted",
          );
          evidence.sourceBlockersAfterSaveReturned = blockers(
            db,
            upstream.name,
          );
          assert(
            evidence.sourceBlockersAfterSaveReturned.includes(need.name),
            "Source locks must survive function return until commit",
          );
          need.p.stdin.end("commit;\n");
          assert.equal(await need.done, 0, need.err);
          await until(
            () => upstream.out.includes("SOURCE_RETURNED"),
            "source returns after Save commit",
          );
          upstream.p.stdin.end("commit;\n");
        }
        for (const s of sessions) assert.equal(await s.done, 0, s.err);
        // Recreate only the snapshot function in this observer's temporary schema.
        const snapshot = fixture.slice(
          fixture.indexOf("create function pg_temp.k1_snapshot"),
          fixture.indexOf("create temporary table k1_original_history"),
        );
        assert(snapshot.includes("returns jsonb"));
        const facts = JSON.parse(
          run(
            db,
            snapshot +
              `select jsonb_build_object(
          'need',(select jsonb_build_object('success',response->'success','error_code',response->'error_code') from k1_results where name='race_need'),
          'source_response',(select jsonb_build_object('success',response->'success','error_code',response->'error_code') from k1_results where name='race_source'),
          'currentness',atlas_core.planning_contract_01_preflight_payload('2026-11-02','2026-11-02',null)->>'downstream_currentness',
          'quantity',(select r.confirmed_quantity from atlas_planning.confirmed_need_line_revisions r join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id) where l.ingredient_id='b6500000-0000-0000-0000-000000000006' and r.is_current),
          'new_decisions',(select count(*)-(select decision_count from k1_original_source) from atlas_planning.confirmed_need_line_decisions),
          'new_revisions',(select count(*)-(select revision_count from k1_original_source) from atlas_planning.confirmed_need_line_revisions),
          'history_unchanged',pg_temp.k1_snapshot()=(select history from k1_race_baseline),
          'working_unchanged',(pg_temp.k1_snapshot(true)-array['atlas_core.command_receipts','atlas_audit.domain_events','atlas_audit.audit_events'])=(select working from k1_race_baseline));`,
          ),
        );
        assert.equal(
          facts.source_response.success,
          true,
          JSON.stringify(facts),
        );
        assert.equal(
          facts.need.success,
          winner === "correction",
          JSON.stringify(facts),
        );
        assert.equal(facts.currentness, "OUTDATED");
        assert.equal(facts.quantity, winner === "correction" ? 110 : 100);
        assert.equal(facts.new_decisions, winner === "correction" ? 1 : 0);
        assert.equal(facts.new_revisions, winner === "correction" ? 1 : 0);
        assert.equal(facts.history_unchanged, true);
        if (winner === "source") {
          assert.equal(facts.need.error_code, "CORRECTION_SOURCE_NOT_CURRENT");
          assert.equal(facts.working_unchanged, true);
        }
        results.push({ ...evidence, ...facts, passed: true });
        console.log(`${source}: ${winner} commits first PASS`);
      } catch (error) {
        results.push({ ...evidence, passed: false, error: error.message });
        throw error;
      } finally {
        for (const s of sessions)
          if (!s.p.stdin.writableEnded) s.p.stdin.end("rollback;\n");
        await Promise.all(sessions.map((s) => s.done));
      }
    }
  }
} finally {
  writeFileSync(output, JSON.stringify({ results }, null, 2) + "\n");
}
