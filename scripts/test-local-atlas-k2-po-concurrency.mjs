// Disposable local/CI databases; public commands and actual waiting sessions.
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";

const container =
  process.env.ATLAS_LOCAL_DB_CONTAINER ?? "supabase_db_thuonghao-ops-erp";
const source = process.env.ATLAS_LOCAL_DB_NAME ?? "postgres";
assert(/^supabase_db_[a-zA-Z0-9_-]+$/.test(container));
assert(source === "postgres" || /^atlas_k2_[a-z0-9_]+$/.test(source));
const prefix = `k2_po_${process.pid}`;
const owned = [];
const args = (db, user = "postgres") => [
  "exec",
  "-i",
  container,
  "psql",
  "-X",
  "-qAt",
  "-v",
  "ON_ERROR_STOP=1",
  "-U",
  user,
  "-d",
  db,
];
function docker(command, input) {
  const result = spawnSync("docker", command, {
    input,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
}
const run = (db, sql) => docker(args(db), sql).trim();
function clone(db, template) {
  docker([
    "exec",
    container,
    "createdb",
    "-U",
    "supabase_admin",
    "-O",
    "postgres",
    "-T",
    template,
    db,
  ]);
  owned.push(db);
}
function expand(file) {
  return readFileSync(file, "utf8").replace(/^\\ir\s+(.+)$/gm, (_, name) =>
    expand(path.resolve(path.dirname(file), name.trim())),
  );
}
async function until(predicate, message) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw Error(`Missing observed boundary: ${message}`);
}
function session(db, name) {
  const process = spawn("docker", args(db));
  const state = { process, name, out: "", error: "" };
  process.stdout.on("data", (chunk) => (state.out += chunk));
  process.stderr.on("data", (chunk) => (state.error += chunk));
  state.done = new Promise((resolve) => process.on("close", resolve));
  process.stdin.write(
    `set application_name='${name}'; begin; set local statement_timeout='8s';\n`,
  );
  return state;
}
function blockers(db, name) {
  return JSON.parse(
    run(
      db,
      `select coalesce(jsonb_agg(b.application_name),'[]')
    from pg_stat_activity a join pg_stat_activity b on b.pid=any(pg_blocking_pids(a.pid))
    where a.datname=current_database() and a.application_name='${name}';`,
    ),
  );
}
const authenticate =
  "set local role authenticated; select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);";
const call = (name, rpc, request) => `${authenticate}
  insert into k2_race_results select '${name}',atlas_api.${rpc}(request)
  from k2_requests where name='${request}'; select '${name}_RETURNED';\n`;
const release = (name) =>
  call(name, "release_school_catering_purchase_order", "po002");
const writes = {
  menu: call("writer", "reopen_weekly_menu", "race_menu"),
  need: call("writer", "save_confirmed_needs", "race_need"),
  actor:
    "update atlas_core.actors set actor_status='INACTIVE',deactivated_at=transaction_timestamp() where actor_id='b6000000-0000-0000-0000-000000000001'; select 'writer_RETURNED';\n",
  supplier:
    "update atlas_admin.suppliers set supplier_status='INACTIVE' where supplier_id='c7100000-0000-4000-8000-000000000001'; select 'writer_RETURNED';\n",
};

try {
  if (source !== "postgres") {
    clone(prefix, source);
  } else {
    // PostgREST keeps postgres connected. Copy only local Atlas/auth evidence.
    const dump = docker([
      "exec",
      container,
      "pg_dump",
      "-U",
      "supabase_admin",
      "-d",
      source,
      "--schema=atlas_*",
      "--schema=auth",
      "--schema=extensions",
      "--schema=supabase_migrations",
    ]);
    docker([
      "exec",
      container,
      "createdb",
      "-U",
      "supabase_admin",
      "-O",
      "postgres",
      prefix,
    ]);
    owned.push(prefix);
    docker(
      args(prefix, "supabase_admin"),
      `create schema extensions;
      create extension pgcrypto with schema extensions;
      create extension "uuid-ossp" with schema extensions;
      create extension pgtap with schema extensions;\n${dump.replace("CREATE SCHEMA extensions;", "")}`,
    );
  }
  assert.equal(
    run(
      prefix,
      "select to_regprocedure('atlas_core.school_catering_lock_po_release_actor(uuid)') is not null;",
    ),
    "t",
  );
  const suite = expand(
    path.resolve(
      import.meta.dirname,
      "../supabase/tests/atlas_k2_corrected_need_purchase_orders.sql",
    ),
  );
  const boundary = suite.indexOf(
    "create function pg_temp.k2_commitment_state()",
  );
  assert(boundary > 0);
  let setup = suite
    .slice(0, boundary)
    .replace(
      /create (?:temporary|temp) table (?!k2_core_lock_results)/gi,
      "create table ",
    );
  setup += `
    create table k2_race_results(name text primary key,response jsonb not null);
    grant select,insert on k2_race_results to authenticated;
    insert into k2_requests select 'race_menu',pg_temp.k2_command('RMVP-03A.v1','WEEKLY_MENU_REOPENED',version,
      jsonb_build_object('week_start','2026-11-02'))||jsonb_build_object('reason_note','Disposable concurrent source correction')
      from atlas_planning.weekly_menus where week_start='2026-11-02';
    insert into k2_requests select 'race_need',pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
      jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
        'correction',(request#>'{payload,correction}')||jsonb_build_object('expected_source_fingerprint',
          encode(sha256(convert_to(atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
        'lines',jsonb_build_array((request#>'{payload,lines,0}')||jsonb_build_object(
          'expected_current_revision_id',r.confirmed_need_line_revision_id,
          'expected_current_decision_id',l.current_confirmed_need_line_decision_id,'proposed_confirmed_quantity','111.000000'))))
      from k2_requests cross join atlas_planning.confirmed_need_batches b
      join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
      join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
      where name='correction110' and b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'
        and l.ingredient_id='b6500000-0000-0000-0000-000000000006' and r.is_current;
    commit;`;
  const setupOutput = run(prefix, setup);
  assert(!/^not ok\b/m.test(setupOutput), setupOutput);

  for (const kind of Object.keys(writes)) {
    for (const winner of ["writer", "release"]) {
      const db = `${prefix}_${kind}_${winner}`;
      clone(db, prefix);
      const first = session(db, `k2_${kind}_release`);
      const writer = session(db, `k2_${kind}_writer`);
      try {
        const leading = winner === "writer" ? writer : first;
        const waiting = winner === "writer" ? first : writer;
        leading.process.stdin.write(
          winner === "writer" ? writes[kind] : release("release"),
        );
        await until(
          () =>
            leading.out.includes(
              `${winner === "writer" ? "writer" : "release"}_RETURNED`,
            ),
          "leader returned uncommitted",
        );
        waiting.process.stdin.write(
          winner === "writer" ? release("release") : writes[kind],
        );
        await until(
          () => blockers(db, waiting.name).includes(leading.name),
          "real competing transaction waits",
        );
        leading.process.stdin.end("commit;\n");
        assert.equal(await leading.done, 0, leading.error);
        await until(
          () =>
            waiting.out.includes(
              `${winner === "writer" ? "release" : "writer"}_RETURNED`,
            ),
          "waiter returned",
        );
        waiting.process.stdin.end("commit;\n");
        assert.equal(await waiting.done, 0, waiting.error);
        const facts = JSON.parse(
          run(
            db,
            `select jsonb_build_object(
          'release',(select response from k2_race_results where name='release'),
          'writer',(select response from k2_race_results where name='writer'),
          'released',(select count(*) from atlas_procurement.purchase_orders where purchase_order_status='RELEASED_TO_SUPPLIER'),
          'superseded',(select count(*) from atlas_procurement.purchase_orders where purchase_order_status='SUPERSEDED'));`,
          ),
        );
        assert.equal(
          facts.release.success,
          winner === "release",
          JSON.stringify(facts),
        );
        if (kind === "need" || kind === "menu")
          assert.equal(facts.writer.success, true, JSON.stringify(facts));
        assert.equal(facts.released, 1);
        assert.equal(facts.superseded, winner === "release" ? 1 : 0);
        console.log(`${kind}: ${winner} commits first PASS`);
      } finally {
        for (const state of [first, writer])
          if (!state.process.stdin.writableEnded)
            state.process.stdin.end("rollback;\n");
        await Promise.all([first.done, writer.done]);
      }
    }
  }

  for (const outcome of ["commit", "rollback"]) {
    const db = `${prefix}_replay_${outcome}`;
    clone(db, prefix);
    const first = session(db, "k2_first_release");
    const replay = session(db, "k2_replayed_release");
    try {
      first.process.stdin.write(release("first"));
      await until(
        () => first.out.includes("first_RETURNED"),
        "first release returned",
      );
      replay.process.stdin.write(release("replay"));
      await until(
        () => blockers(db, replay.name).includes(first.name),
        "duplicate request waits",
      );
      first.process.stdin.end(`${outcome};\n`);
      assert.equal(await first.done, 0, first.error);
      await until(
        () => replay.out.includes("replay_RETURNED"),
        "replay returned",
      );
      replay.process.stdin.end("commit;\n");
      assert.equal(await replay.done, 0, replay.error);
      const results = JSON.parse(
        run(db, "select jsonb_object_agg(name,response) from k2_race_results;"),
      );
      assert.equal(results.replay.success, true, JSON.stringify(results));
      if (outcome === "commit") assert.deepEqual(results.first, results.replay);
      else assert.equal(results.first, undefined);
      assert.equal(
        run(
          db,
          "select count(*) from atlas_procurement.purchase_orders where purchase_order_status='SUPERSEDED';",
        ),
        "1",
      );
      // Discarded transport response is recovered through an authenticated shaped read.
      const recovered = JSON.parse(
        run(
          db,
          `begin; ${authenticate}
        select atlas_api.get_school_catering_purchase_orders(jsonb_build_object(
          'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
          'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
          'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
            'date_start','2026-11-02','date_end','2026-11-02',
            'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null))); rollback;`,
        )
          .split("\n")
          .at(-1),
      );
      assert.equal(recovered.success, true, JSON.stringify(recovered));
      assert(
        recovered.purchase_orders.some(
          (po) =>
            po.status === "RELEASED_TO_SUPPLIER" &&
            po.document_number === results.replay.document_number,
        ),
      );
      console.log(`duplicate/UNKNOWN: first ${outcome} PASS`);
    } finally {
      for (const state of [first, replay])
        if (!state.process.stdin.writableEnded)
          state.process.stdin.end("rollback;\n");
      await Promise.all([first.done, replay.done]);
    }
  }
  console.log("K2: 10 actual concurrent-session cases PASS");
} finally {
  for (const db of owned.reverse()) {
    assert(db.startsWith(prefix));
    docker(["exec", container, "dropdb", "-U", "supabase_admin", db]);
  }
}
