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
  from k2_requests where name='${request}' returning response; select '${name}_RETURNED';\n`;
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
  const empty = `${prefix}_empty`;
  clone(empty, prefix);
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

  // The same source roots must remain stable through the PXK writer's insert.
  run(
    prefix,
    `begin;
    update atlas_admin.schools set dispatch_document_issuer_name='K3 test issuer',
      dispatch_document_issuer_address='Disposable concurrency fixture';
    insert into atlas_core.role_capabilities(role_id,capability_id)
    select 'b6000000-0000-0000-0000-000000000003',capability_id
    from atlas_core.capabilities where capability_code in
      ('dispatch.school_release.read','dispatch.school_release.release') on conflict do nothing;
    ${call("k3_setup_po", "release_school_catering_purchase_order", "po002")}
    commit;`,
  );
  assert.equal(
    JSON.parse(
      run(
        prefix,
        "select response from k2_race_results where name='k3_setup_po'",
      ),
    ).success,
    true,
  );
  const scope = JSON.parse(
    run(
      prefix,
      `select jsonb_build_object(
    'school',school_id,'location',delivery_location_id)
    from atlas_planning.confirmed_need_lines
    where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'
      and ingredient_id='b6500000-0000-0000-0000-000000000006';`,
    ),
  );
  const preview = `atlas_core.school_dispatch_release_preview('2026-11-02','${scope.school}','${scope.location}')`;
  assert.equal(JSON.parse(run(prefix, `select ${preview};`)).ready, true);
  run(
    prefix,
    `insert into k2_requests
    select 'k3_pxk',request||jsonb_build_object(
      'contract_version','SCHOOL-DISPATCH-RELEASE.v1','command_id',id,
      'idempotency_key','k3-pxk:'||id,'expected_version',0,
      'reason_code','SCHOOL_DISPATCH_DOCUMENT_RELEASED','payload',jsonb_build_object(
        'service_date','2026-11-02','school_id','${scope.school}',
        'delivery_location_id','${scope.location}',
        'expected_source_fingerprint',${preview}->>'source_fingerprint',
        'predecessor_release_id',null))
    from k2_requests cross join (select gen_random_uuid() id) command where name='po002';`,
  );
  const pxk = (name) =>
    call(name, "release_school_dispatch_document", "k3_pxk");
  for (const kind of ["need", "menu"]) {
    for (const winner of ["writer", "release"]) {
      const db = `${prefix}_pxk_${kind}_${winner}`;
      clone(db, prefix);
      const first = session(db, `k3_${kind}_pxk`),
        writer = session(db, `k3_${kind}_source`);
      const leading = winner === "release" ? first : writer;
      const waiting = winner === "release" ? writer : first;
      try {
        leading.process.stdin.write(
          winner === "release" ? pxk("release") : writes[kind],
        );
        await until(
          () =>
            leading.out.includes(
              `${winner === "release" ? "release" : "writer"}_RETURNED`,
            ),
          "PXK/source leader returned uncommitted",
        );
        const leaderResponse = JSON.parse(
          leading.out
            .split("\n")
            .filter((line) => line.startsWith("{"))
            .at(-1) ?? "null",
        );
        if (leaderResponse)
          assert.equal(
            leaderResponse.success,
            true,
            JSON.stringify(leaderResponse),
          );
        waiting.process.stdin.write(
          winner === "release" ? writes[kind] : pxk("release"),
        );
        await until(
          () => blockers(db, waiting.name).includes(leading.name),
          `PXK and source genuinely serialize: ${kind}/${winner}; leader=${leading.out}; waiter=${waiting.out}; error=${waiting.error}`,
        );
        leading.process.stdin.end("commit;\n");
        assert.equal(await leading.done, 0, leading.error);
        await until(
          () =>
            waiting.out.includes(
              `${winner === "release" ? "writer" : "release"}_RETURNED`,
            ),
          "PXK/source waiter returned",
        );
        waiting.process.stdin.end("commit;\n");
        assert.equal(await waiting.done, 0, waiting.error);
        const facts = JSON.parse(
          run(
            db,
            `select jsonb_build_object(
          'release',(select response from k2_race_results where name='release'),
          'writer',(select response from k2_race_results where name='writer'),
          'count',(select count(*) from atlas_dispatch.school_dispatch_releases),
          'quantity',(select line.quantity from atlas_dispatch.school_dispatch_release_lines line
            where line.ingredient_id='b6500000-0000-0000-0000-000000000006'),
          'ready',${preview}->'ready');`,
          ),
        );
        assert.equal(
          facts.release.success,
          winner === "release",
          JSON.stringify(facts),
        );
        assert.equal(facts.writer.success, true, JSON.stringify(facts));
        assert.equal(facts.count, winner === "release" ? 1 : 0);
        if (winner === "release") assert.equal(facts.quantity, 110);
        else assert.equal(facts.release.error_code, "PXK_NOT_READY");
        assert.equal(facts.ready, false);
        console.log(`K3 PXK/${kind}: ${winner} commits first PASS`);
      } finally {
        for (const state of [first, writer])
          if (!state.process.stdin.writableEnded)
            state.process.stdin.end("rollback;\n");
        await Promise.all([first.done, writer.done]);
      }
    }
  }
  for (const outcome of ["commit", "rollback"]) {
    const db = `${prefix}_pxk_replay_${outcome}`;
    clone(db, prefix);
    const first = session(db, "k3_pxk_first"),
      replay = session(db, "k3_pxk_replay");
    try {
      first.process.stdin.write(pxk("first"));
      await until(
        () => first.out.includes("first_RETURNED"),
        "PXK returned before transport loss",
      );
      replay.process.stdin.write(pxk("replay"));
      await until(
        () => blockers(db, replay.name).includes(first.name),
        "duplicate PXK waits",
      );
      first.process.stdin.end(`${outcome};\n`);
      assert.equal(await first.done, 0, first.error);
      await until(
        () => replay.out.includes("replay_RETURNED"),
        "PXK replay recovers",
      );
      replay.process.stdin.end("commit;\n");
      assert.equal(await replay.done, 0, replay.error);
      const facts = JSON.parse(
        run(db, "select jsonb_object_agg(name,response) from k2_race_results"),
      );
      assert.equal(facts.replay.success, true, JSON.stringify(facts));
      if (outcome === "commit") assert.deepEqual(facts.first, facts.replay);
      else assert.equal(facts.first, undefined);
      assert.equal(
        run(db, "select count(*) from atlas_dispatch.school_dispatch_releases"),
        "1",
      );
      const recovered = JSON.parse(
        run(
          db,
          `begin; ${authenticate}
        select atlas_api.get_school_dispatch_release_workbench(jsonb_build_object(
          'contract_version','SCHOOL-DISPATCH-RELEASE.v1',
          'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
          'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
            'date_start','2026-11-02','date_end','2026-11-02','school_ids','[]'::jsonb,'search',null)));
        rollback;`,
        )
          .split("\n")
          .at(-1),
      );
      assert.equal(recovered.success, true);
      assert(
        recovered.rows.some(
          (row) =>
            row.state === "CURRENT" &&
            row.current_release.document_number ===
              facts.replay.document_number,
        ),
      );
      console.log(`K3 PXK duplicate/UNKNOWN: first ${outcome} PASS`);
    } finally {
      for (const state of [first, replay])
        if (!state.process.stdin.writableEnded)
          state.process.stdin.end("rollback;\n");
      await Promise.all([first.done, replay.done]);
    }
  }
  console.log(
    "K3: 6 PXK/source and duplicate/UNKNOWN concurrent-session cases PASS",
  );

  // Start ordinary PH, let K1 change status while the source locker waits.
  const transitionDb = `${prefix}_first_correction`;
  clone(transitionDb, empty);
  const ordinaryEnd = suite.indexOf("-- A valid receipt lifecycle");
  assert(ordinaryEnd > 0);
  const correction = suite.match(
    /insert into k2_requests\r?\nselect 'correction110'[\s\S]*?;\r?\nset local role authenticated;/,
  )?.[0];
  assert(correction);
  const ordinarySetup = suite
    .slice(0, ordinaryEnd)
    .replace(
      /create (?:temporary|temp) table (?!k2_core_lock_results)/gi,
      "create table ",
    );
  run(
    transitionDb,
    ordinarySetup +
      correction.replace(/set local role authenticated;$/, "") +
      `
    insert into k2_requests select 'race_menu',pg_temp.k2_command('RMVP-03A.v1','WEEKLY_MENU_REOPENED',version,
      jsonb_build_object('week_start','2026-11-02'))||jsonb_build_object('reason_note','K3 first correction race')
      from atlas_planning.weekly_menus where week_start='2026-11-02';
    create table k2_race_results(name text primary key,response jsonb not null);
    grant select,insert on k2_race_results to authenticated; commit;`,
  );
  const correctionSession = session(transitionDb, "k3_first_correction");
  const lockSession = session(transitionDb, "k3_transition_lock");
  const menuSession = session(transitionDb, "k3_transition_menu");
  try {
    correctionSession.process.stdin.write(
      call("correction", "save_confirmed_needs", "correction110"),
    );
    await until(
      () => correctionSession.out.includes("correction_RETURNED"),
      "first correction held",
    );
    lockSession.process.stdin
      .write(`select atlas_core.purchase_review_lock_confirmed_source(
      'b6500000-0000-0000-0000-000000000050');select 'SOURCE_LOCKED';\n`);
    await until(
      () =>
        blockers(transitionDb, lockSession.name).includes(
          correctionSession.name,
        ),
      "source locker waits behind first correction",
    );
    correctionSession.process.stdin.end("commit;\n");
    assert.equal(await correctionSession.done, 0, correctionSession.error);
    await until(
      () => lockSession.out.includes("SOURCE_LOCKED"),
      "source locks refreshed after status transition",
    );
    menuSession.process.stdin.write(writes.menu);
    await until(
      () => blockers(transitionDb, menuSession.name).includes(lockSession.name),
      "newly corrected branch holds Menu source root",
    );
    lockSession.process.stdin.end("rollback;\n");
    assert.equal(await lockSession.done, 0, lockSession.error);
    await until(
      () => menuSession.out.includes("writer_RETURNED"),
      "rollback releases source roots",
    );
    menuSession.process.stdin.end("commit;\n");
    assert.equal(await menuSession.done, 0, menuSession.error);
    assert.equal(
      JSON.parse(
        run(
          transitionDb,
          "select response from k2_race_results where name='writer'",
        ),
      ).success,
      true,
    );
    console.log("K3 PH→REOPENED wait, Menu root and source-lock rollback PASS");
  } finally {
    for (const state of [correctionSession, lockSession, menuSession])
      if (!state.process.stdin.writableEnded)
        state.process.stdin.end("rollback;\n");
    await Promise.all([
      correctionSession.done,
      lockSession.done,
      menuSession.done,
    ]);
  }

  // Real Pantry Save + Need Generation advances the run while the locker waits.
  const pointerDb = `${prefix}_run_pointer`;
  clone(pointerDb, empty);
  const generateStart = suite.indexOf("select 'b1_carry_generate',");
  assert(generateStart > 0);
  const generateCall = suite.indexOf(
    "insert into k2_results select name,atlas_api.execute_need_generation(request)",
    generateStart,
  );
  assert(generateCall > generateStart);
  const pointerSetup = suite.slice(0, generateCall);
  const pointerOutput = run(
    pointerDb,
    pointerSetup +
      `reset role;
    create table public.k2_requests as select * from pg_temp.k2_requests;
    create table public.k2_b1_batch as select * from pg_temp.k2_b1_batch;
    grant select on public.k2_requests to authenticated; commit;`,
  );
  assert(!/^not ok\b/m.test(pointerOutput), pointerOutput);
  const batch = run(
    pointerDb,
    "select confirmed_need_batch_id from k2_b1_batch",
  );
  const generator = session(pointerDb, "k3_run_generator"),
    locker = session(pointerDb, "k3_run_locker");
  try {
    generator.process.stdin.write(`set local role authenticated;
      select set_config('request.jwt.claim.sub','a7400000-0000-4000-8000-000000000101',true);
      select atlas_api.execute_need_generation(request) from k2_requests where name='b1_carry_generate';
      select 'RUN_ADVANCED';\n`);
    await until(
      () => generator.out.includes("RUN_ADVANCED"),
      "real generation advances run before commit",
    );
    assert.equal(
      JSON.parse(
        generator.out
          .split("\n")
          .filter((line) => line.startsWith("{"))
          .at(-1),
      ).success,
      true,
    );
    locker.process.stdin.end(`\\set VERBOSITY verbose
      select atlas_core.purchase_review_lock_confirmed_source('${batch}');commit;\n`);
    await until(
      () => blockers(pointerDb, locker.name).includes(generator.name),
      "run locker waits on old run",
    );
    generator.process.stdin.end("commit;\n");
    assert.equal(await generator.done, 0, generator.error);
    assert.notEqual(
      await locker.done,
      0,
      "changed run identity must fail before further locks",
    );
    assert.match(locker.error, /40001/);
    console.log(
      "K3 real run-pointer advancement fails retryably without reversing locks PASS",
    );
  } finally {
    for (const state of [generator, locker])
      if (!state.process.stdin.writableEnded)
        state.process.stdin.end("rollback;\n");
    await Promise.all([generator.done, locker.done]);
  }
} finally {
  for (const db of owned) assert(db.startsWith(prefix));
  if (owned.length)
    docker(
      args("postgres", "supabase_admin"),
      owned
        .reverse()
        .map((db) => `drop database "${db}";`)
        .join("\n"),
    );
}
