import { spawn, spawnSync, execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { createHash } from "node:crypto";
import {
  expand,
  completePurchaseReviewTap,
} from "./test-local-purchase-review.mjs";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";

const container = "supabase_db_thuonghao-ops-erp";
const correction =
  "supabase/migrations/20261015065552_operator_confirmed_need_correction.sql";
const fixture = "supabase/local/confirmed_need_correction_scale_fixture.sql";
const hash = (value) => createHash("sha256").update(value).digest("hex");

// Separate Tier 2 derivative; the original eight-cycle file is never edited.
export function buildOperationalAcceptance() {
  let sql = expand("supabase/tests/confirmed_need_correction_scale.sql");
  const originalSha256 = hash(sql);
  const replacements = [
    ["from generate_series(1,8)depth", "from generate_series(1,1)depth"],
    [
      "9::bigint,\n 'eight public correction cycles append nine consecutive Handoff revisions'",
      "2::bigint,\n 'one operational correction appends a second Handoff revision'",
    ],
    [
      "8::bigint,\n 'all eight measured history depths completed'",
      "1::bigint,\n 'one operational history depth completed'",
    ],
    [
      "80::bigint,\n 'each history edge completed ten explicit public operations'",
      "10::bigint,\n 'one operational edge completed all ten explicit public operations'",
    ],
    [
      "13::bigint,\n 'five original complete Supplier POs plus eight explicit complete replacements are preserved'",
      "6::bigint,\n 'five original complete Supplier POs plus one explicit complete replacement are preserved'",
    ],
    [
      "9::bigint,\n 'only the selected School has one initial PXK and eight explicit successors'",
      "2::bigint,\n 'only the selected School has one initial PXK and one explicit successor'",
    ],
    [
      "108::numeric,\n 'eight selected-line corrections preserve exact final quantity108'",
      "101::numeric,\n 'one selected-line correction preserves exact final quantity101'",
    ],
    [
      "one selected School PXK; eight history edges",
      "one selected School PXK; one operational history edge",
    ],
  ];
  for (const [before, after] of replacements) {
    if (sql.split(before).length !== 2)
      throw new Error(
        "Original scale oracle changed; review Tier 2 derivative.",
      );
    sql = sql.replace(before, after);
  }
  return { sql, originalSha256, operationalSha256: hash(sql) };
}

export function buildDualOperationalAcceptance() {
  let { sql: text, originalSha256 } = buildOperationalAcceptance();
  const replacements = [
    ["from generate_series(1,1)depth", "from generate_series(1,2)depth"],
    [
      "2::bigint,\n 'one operational correction appends a second Handoff revision'",
      "3::bigint,\n 'two operational corrections append two Handoff revisions'",
    ],
    [
      "1::bigint,\n 'one operational history depth completed'",
      "2::bigint,\n 'two operational history depths completed'",
    ],
    [
      "10::bigint,\n 'one operational edge completed all ten explicit public operations'",
      "20::bigint,\n 'two operational edges completed all twenty explicit public operations'",
    ],
    [
      "6::bigint,\n 'five original complete Supplier POs plus one explicit complete replacement are preserved'",
      "7::bigint,\n 'five original complete Supplier POs plus two explicit complete replacements are preserved'",
    ],
    [
      "2::bigint,\n 'only the selected School has one initial PXK and one explicit successor'",
      "3::bigint,\n 'only the selected School has one initial PXK and two explicit successors'",
    ],
    [
      "101::numeric,\n 'one selected-line correction preserves exact final quantity101'",
      "102::numeric,\n 'two selected-line corrections preserve exact final quantity102'",
    ],
  ];
  for (const [before, after] of replacements) {
    if (text.split(before).length !== 2)
      throw new Error("Original operational derivative drifted.");
    text = text.replace(before, after);
  }
  // Per-depth quantities and identities are checked before the next correction.
  const marker =
    "select format('set local statement_timeout=%L;select pg_temp.c_scale_history(%L,%s);',";
  if (text.split(marker).length !== 2)
    throw new Error("History boundary drifted.");
  text = text.replace("select plan(20);", "select plan(36);");
  text = text.replace(
    marker,
    `create function pg_temp.c395_depth_gate(depth integer) returns setof text language plpgsql as $c395$
begin
 return next is((select count(*) from c_scale_results where history_depth=depth),10::bigint,'depth '||depth||': all ten complete public operations');
 return next is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where is_current and school_id='b6500000-0000-0000-0000-000000000004' and ingredient_id='b6500000-0000-0000-000000000006'),(100+depth)::numeric,'depth '||depth||': exact quantity');
 return next is((select count(*) from atlas_planning.purchase_handoff_revisions),(depth+1)::bigint,'depth '||depth||': complete Handoff history');
 return next is((select count(*) from atlas_procurement.purchase_orders),(5+depth)::bigint,'depth '||depth||': complete supplier PO replacements');
 return next is((select count(*) from atlas_dispatch.school_dispatch_releases),(1+depth)::bigint,'depth '||depth||': explicit PXK successors');
 return next is((select count(*) from c_scale_preserved),249::bigint,'depth '||depth||': retained families checked by Preparation');
 return next is((select count(*) from c_scale_other_pos old join atlas_procurement.purchase_orders p using(purchase_order_id) join atlas_procurement.purchase_order_revisions r using(purchase_order_id) where r.is_current and to_jsonb(p)=old.root and to_jsonb(r)=old.revision),4::bigint,'depth '||depth||': four unrelated POs exact');
 return next ok((select bool_and(invoked_as='authenticated' and response->>'success'='true' and elapsed_ms<case when api='prepare_school_catering_purchase_orders' then 20000 else 8000 end) from c_scale_results where history_depth=depth),'depth '||depth||': unchanged complete command budgets');
end;$c395$;
select format('set local statement_timeout=%L;select pg_temp.c_scale_history(%L,%s);',`,
  );
  text = text.replace(
    "case when stage='preparation'then'20s'else'8s'end,stage,depth)",
    "case when stage='preparation'then'20s'else'8s'end,stage,depth)||case when stage='pxk-release' then format('select * from pg_temp.c395_depth_gate(%s);',depth) else '' end",
  );
  return { sql: text, originalSha256, operationalSha256: hash(text) };
}

export function buildPreparationProbe(mode) {
  if (!["baseline", "profile"].includes(mode))
    throw new Error("Use baseline or profile.");
  const original = expand(fixture);
  const marker =
    "\nselect format('set local statement_timeout=%L;select pg_temp.c_scale_history(%L,%s);',";
  const end = original.indexOf(marker);
  if (
    end < 0 ||
    original.indexOf(marker, end + 1) >= 0 ||
    !original.slice(end).includes("generate_series(1,8)")
  )
    throw new Error(
      "Original scale fixture boundary changed; review before probing.",
    );
  const stages = ["preview", "correct", "allocation-read", "allocation-save"]
    .map(
      (stage) =>
        `set local statement_timeout='8s';\nselect pg_temp.c_scale_history('${stage}',1);`,
    )
    .join("\n");
  const tracking =
    mode === "profile"
      ? `
reset session authorization;
load 'auto_explain';
set local track_functions='all';
set local pg_stat_statements.track='all';
set local auto_explain.log_min_duration='10ms';
set local auto_explain.log_analyze=on;
set local auto_explain.log_timing=off;
set local auto_explain.log_buffers=on;
set local auto_explain.log_nested_statements=on;
set local auto_explain.log_parameter_max_length=0;
set local auto_explain.log_format='json';
select jsonb_build_object('C388_STATS_BEFORE',coalesce(jsonb_agg(to_jsonb(s)),'[]'))
from extensions.pg_stat_statements s where dbid=(select oid from pg_database where datname=current_database());
set session authorization postgres;
`
      : "";
  return {
    fixtureSha256: hash(original),
    sql: `${mode === "profile" ? "set session authorization postgres;\n" : ""}begin;\nset search_path=extensions,public,pg_catalog;\n${original.slice(0, end)}\n${stages}\n${tracking}
select jsonb_build_object('C388_TARGET_CALLER',current_user,'session_user',session_user);
set local application_name='atlas_c388_target';
set local statement_timeout='20s';
\\timing on
select pg_temp.c_scale_history('preparation',1);
\\timing off
select jsonb_build_object('C388_COMPLETED_MEASUREMENTS',jsonb_agg(to_jsonb(r)-'response' order by history_depth,name)) from c_scale_results r;
rollback;\n`,
  };
}

export function classifyPreparationProbe(status, output, invariant) {
  if (!invariant) return "FAIL_RESIDUE_OR_INTEGRITY";
  if (
    !output.includes(
      "C_SCALE_START history-1-preparation prepare_school_catering_purchase_orders depth 1",
    )
  )
    return "INVALID_PREFIX";
  if (status === 0 && output.includes("C_SCALE_END history-1-preparation ms"))
    return "TARGET_COMPLETED";
  if (
    status !== 0 &&
    output.includes("canceling statement due to statement timeout")
  )
    return "TARGET_TIMEOUT";
  return "INCOMPLETE_TARGET";
}

// Metadata, source bodies and business row images are hashed; no credentials or rows are exported.
export const snapshotSql = `
create function pg_temp.c388_rows() returns jsonb language plpgsql as $$
declare r record; image jsonb; result jsonb:='[]'; begin
 for r in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname like 'atlas\\_%' escape '\\' and c.relkind in('r','p') order by 1,2 loop
 execute format('select jsonb_build_object(''relation'',%L,''count'',count(*),''rows_md5'',md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,''[]''))) from %I.%I t',r.nspname||'.'||r.relname,r.nspname,r.relname) into image;
 result:=result||jsonb_build_array(image); end loop; return result; end; $$;
select jsonb_build_object(
 'roles',(select jsonb_agg(jsonb_build_object('name',rolname,'super',rolsuper,'inherit',rolinherit,'create_role',rolcreaterole,'create_db',rolcreatedb,'login',rolcanlogin,'replication',rolreplication,'bypass',rolbypassrls,'limit',rolconnlimit,'config',rolconfig) order by rolname) from pg_roles),
 'memberships',(select jsonb_agg(jsonb_build_object('role',pg_get_userbyid(roleid),'member',pg_get_userbyid(member),'grantor',pg_get_userbyid(grantor),'admin',admin_option,'inherit',inherit_option,'set',set_option) order by roleid,member,grantor) from pg_auth_members),
 'schemas',(select jsonb_agg(jsonb_build_object('name',nspname,'owner',pg_get_userbyid(nspowner),'acl',nspacl::text) order by nspname) from pg_namespace where nspname like 'atlas\\_%' escape '\\'),
 'functions',(select jsonb_agg(jsonb_build_object('identity',p.oid::regprocedure::text,'owner',pg_get_userbyid(proowner),'acl',proacl::text,'config',proconfig,'definer',prosecdef,'volatile',provolatile,'source_md5',md5(pg_get_functiondef(p.oid))) order by p.oid::regprocedure::text) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname like 'atlas\\_%' escape '\\'),
 'rows',pg_temp.c388_rows(),
 'physical',(select jsonb_agg(to_jsonb(s) order by schemaname,relname) from pg_stat_user_tables s where schemaname like 'atlas\\_%' escape '\\'));
`;

async function main() {
  const mode = process.argv[2];
  const probe = buildPreparationProbe(
    ["certification", "option-a"].includes(mode) ? "baseline" : mode,
  );
  const directory = process.env.C388_EVIDENCE_DIR;
  if (
    process.env.GITHUB_ACTIONS !== "true" ||
    process.env.GITHUB_REPOSITORY !== "longpsu-bot/thuonghao-ops-erp" ||
    process.env.GITHUB_EVENT_NAME !== "workflow_dispatch" ||
    process.env.GITHUB_RUN_ATTEMPT !== "1" ||
    !directory
  )
    throw new Error(
      "This disposable bootstrap is restricted to a first-attempt manual repository Actions run.",
    );
  mkdirSync(directory, { recursive: true });
  const save = (name, value) =>
    writeFileSync(
      path.join(directory, name),
      redactAtlasStagingDiagnostic(
        typeof value === "string" ? value : JSON.stringify(value, null, 2),
      ),
    );
  const command = (program, args, input, timeout = 180000) =>
    spawnSync(program, args, {
      input,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
      timeout,
    });
  const psqlArgs = (database, user = "postgres") => [
    "exec",
    "-i",
    container,
    "psql",
    "-X",
    "-qAt",
    "-v",
    "ON_ERROR_STOP=1",
    "-v",
    "VERBOSITY=verbose",
    "-U",
    user,
    "-d",
    database,
  ];
  const sql = (
    text,
    database = "postgres",
    name = "sql",
    user = "postgres",
  ) => {
    const result = command("docker", psqlArgs(database, user), text);
    save(`${name}.log`, (result.stdout ?? "") + (result.stderr ?? ""));
    if (result.status !== 0)
      throw new Error(`${name} failed; see sanitized artifact.`);
    return result.stdout.trim();
  };
  const snapshot = (database, name) => {
    const value = JSON.parse(sql(snapshotSql, database, name));
    save(`${name}.json`, value);
    return value;
  };
  const summary = {
    mode,
    head: process.env.GITHUB_SHA,
    accepted: false,
    outcome: "BLOCKED_SETUP",
    targetRuns: 0,
    limits:
      "8s public / 20s Preparation / 1s entry / unchanged disclosed nested5s; one13-relation ANALYZE",
    limitations:
      "SQL-local synthetic fixture; no HTTP/integration certification. Fresh runner cache/physical state differs from preserved host. Completed inclusive counters overlap and omit canceled/inlined work. Profile adds overhead; it is not acceptance.",
    controlConnection:
      "Built-in supabase_admin for owned database clone/control and read-only observer/statistics. No role/grant changes.",
    probeConnection:
      mode === "profile"
        ? "Admin transport with postgres session/current identity throughout original fixture/public calls; administrator identity only while configuring/collecting session instrumentation outside target timing."
        : "postgres transport/session; original public calls authenticated.",
  };
  try {
    const existing = command("docker", [
      "ps",
      "-aq",
      "--filter",
      "name=^/supabase_",
    ]);
    if (existing.status !== 0 || existing.stdout.trim())
      throw new Error(
        "Require a fresh runner with no existing Supabase containers.",
      );
    const entries = execFileSync(
      "git",
      ["ls-tree", "-r", "HEAD", "supabase/migrations"],
      { encoding: "utf8" },
    )
      .trim()
      .split("\n");
    const base = entries.filter((entry) => !entry.endsWith(correction));
    const mainEntries = execFileSync(
      "git",
      ["ls-tree", "-r", "origin/main", "supabase/migrations"],
      { encoding: "utf8" },
    )
      .trim()
      .split("\n");
    if (
      base.length !== 109 ||
      JSON.stringify(base) !== JSON.stringify(mainEntries)
    )
      throw new Error("109-file exact main baseline manifest mismatch.");
    const correctionBytes = execFileSync("git", ["show", `HEAD:${correction}`]);
    if (hash(correctionBytes) !== hash(readFileSync(correction)))
      throw new Error("Working C bytes differ from exact Git source.");
    save("source-manifest.json", {
      head: summary.head,
      baseline: base,
      correctionSha256: hash(correctionBytes),
      fixtureSha256: probe.fixtureSha256,
    });
    const held = path.join(directory, "held-correction.sql");
    save(
      "owns-stack",
      "Fresh runner checked; this run owns the local Supabase startup.\n",
    );
    renameSync(correction, held);
    try {
      const start = command(
        "pnpm",
        [
          "exec",
          "supabase",
          "start",
          "--exclude",
          "edge-runtime,imgproxy,logflare,mailpit,postgres-meta,realtime,storage-api,studio,supavisor,vector",
        ],
        undefined,
        600000,
      );
      save("supabase-start.log", (start.stdout ?? "") + (start.stderr ?? ""));
      if (start.status !== 0)
        throw new Error("Standard Supabase109 startup failed; no target run.");
    } finally {
      renameSync(held, correction);
    }
    const baselineTest = execFileSync(
      "git",
      [
        "show",
        "origin/main:supabase/tests/atlas_current_platform_security_catalog.sql",
      ],
      { encoding: "utf8" },
    );
    const baselineTap = sql(baselineTest, "postgres", "baseline-catalog");
    if (!completePurchaseReviewTap(baselineTap, 0))
      throw new Error("Baseline catalog incomplete or failing.");
    const before = snapshot("postgres", "before-correction");
    if (mode === "option-a") {
      const pinned = execFileSync("git", [
        "show",
        "a443daf15dd9891611b387349268795efbce7d5c:" + correction,
      ]);
      if (
        hash(pinned) !==
        "7d5a0a96f141c23adad51781827051df04a1a545fc513617abf9eccd7f6302c3"
      )
        throw new Error("Pinned C evidence hash mismatch.");
      sql(pinned, "postgres", "apply-pinned-c-once");
      const original = snapshot("postgres", "pinned-c-before-option-a");
      const source = correctionBytes.toString("utf8");
      const marker =
        "CREATE OR REPLACE FUNCTION atlas_core.purchase_review_continuity_context(p_batch uuid)";
      const start = source.lastIndexOf(marker);
      const end = source.indexOf("$function$;", start);
      if (start < 0 || end < 0)
        throw new Error("Exact allowlisted body boundary missing.");
      sql(
        source.slice(start, end + "$function$;".length),
        "postgres",
        "apply-option-a-body",
        "supabase_admin",
      );
      const candidate = snapshot("postgres", "pinned-c-after-option-a");
      const changed = candidate.functions.filter(
        (value, index) =>
          JSON.stringify(value) !== JSON.stringify(original.functions[index]),
      );
      const metadata = (functions) =>
        functions.map(({ source_md5, ...value }) => value);
      const exactParity =
        ["roles", "memberships", "schemas", "rows"].every(
          (key) =>
            JSON.stringify(original[key]) === JSON.stringify(candidate[key]),
        ) &&
        original.functions.length === 497 &&
        candidate.functions.length === 497 &&
        JSON.stringify(metadata(original.functions)) ===
          JSON.stringify(metadata(candidate.functions)) &&
        changed.length === 1 &&
        changed[0].identity ===
          "atlas_core.purchase_review_continuity_context(uuid)";
      save("option-a-allowlist-parity.json", {
        exactParity,
        changed,
        functions: candidate.functions.length,
        roles: candidate.roles.length,
        memberships: candidate.memberships.length,
        schemas: candidate.schemas.length,
        relations: candidate.rows.length,
      });
      if (!exactParity)
        throw new Error(
          "Option A changed an unapproved definition, metadata or protected image.",
        );
    } else {
      sql(correctionBytes, "postgres", "apply-whole-correction-once");
    }
    const after = snapshot("postgres", "after-correction");
    for (const key of ["roles", "memberships", "schemas", "rows"]) {
      if (JSON.stringify(before[key]) !== JSON.stringify(after[key]))
        throw new Error(`C application changed protected ${key} image.`);
    }
    // Clone before catalog fixtures; quiesce only this new runner's disposable source DB.
    const database = "atlas_c388_probe";
    try {
      sql(
        "alter database postgres allow_connections false; select pg_terminate_backend(pid) from pg_stat_activity where datname='postgres';",
        "template1",
        "quiesce-owned-source",
        "supabase_admin",
      );
      sql(
        `create database ${database} template postgres;`,
        "template1",
        "clone-owned-baseline",
        "supabase_admin",
      );
      if (["certification", "option-a"].includes(mode))
        sql(
          "create database atlas_c388_stress template postgres;",
          "template1",
          "clone-pristine-stress",
          "supabase_admin",
        );
    } finally {
      sql(
        "alter database postgres allow_connections true;",
        "template1",
        "restore-owned-source-connectivity",
        "supabase_admin",
      );
    }
    const tap = sql(
      expand("supabase/tests/atlas_current_platform_security_catalog.sql"),
      "postgres",
      "current-catalog",
    );
    if (!completePurchaseReviewTap(tap, 0))
      throw new Error("Current exact catalog incomplete or failing.");
    if (["certification", "option-a"].includes(mode)) {
      delete summary.targetRuns;
      summary.limitations =
        "Bounded SQL-local synthetic acceptance only. Separate one-cycle operational and original eight-cycle stress oracles; neither proves hosted HTTP/browser, live competing-session waits, or combined UI integration.";
      summary.fullIntegration =
        "SKIPPED: bounded SQL acceptance only; no HTTP/browser/full integration certification.";
      summary.suites = [];
      const runSuite = (name, text, db) => {
        const before = snapshot(db, `${name}-preflight`);
        const began = performance.now();
        const result = command("docker", psqlArgs(db), text, 600000);
        save(`${name}.log`, (result.stdout ?? "") + (result.stderr ?? ""));
        const after = snapshot(db, `${name}-postflight`);
        const invariant = [
          "roles",
          "memberships",
          "schemas",
          "functions",
          "rows",
        ].every(
          (key) => JSON.stringify(before[key]) === JSON.stringify(after[key]),
        );
        const complete = completePurchaseReviewTap(
          result.stdout ?? "",
          result.status,
        );
        const item = {
          name,
          sqlSha256: hash(text),
          exitCode: result.status,
          error: result.error?.message,
          wallMs: performance.now() - began,
          assertions: (result.stdout ?? "")
            .split(/\r?\n/)
            .filter((line) => /^ok\s+\d+\b/.test(line)).length,
          completeSequentialTap: complete,
          rollbackAndIntegrityVerified: invariant,
          pass: complete && invariant,
        };
        summary.suites.push(item);
        if (!item.pass)
          throw new Error(`${name} failed or incomplete; no automatic retry.`);
      };
      summary.outcome = "FOCUSED_CHECKS_IN_PROGRESS";
      for (const file of [
        "confirmed_need_correction.sql",
        "confirmed_need_correction_continuity.sql",
        "confirmed_need_correction_consumers.sql",
        "atlas_current_platform_security_catalog.sql",
        "school_catering_purchase_orders.sql",
        "rmvp_07_connected_confirmed_need_approval_release.sql",
        "d037_confirmed_need_save_release_boundary.sql",
        ...(mode === "option-a" ? ["issue_395_phase_context_parity.sql"] : []),
      ]) {
        let text = expand(`supabase/tests/${file}`);
        if (
          [
            "rmvp_07_connected_confirmed_need_approval_release.sql",
            "d037_confirmed_need_save_release_boundary.sql",
          ].includes(file)
        )
          text = text.replace(
            /^begin;/m,
            `begin;\n${expand("supabase/local/pa_06b_synthetic_identity.sql")}\n${expand("supabase/local/rmvp_05_browser_fixture.sql")}\nset constraints all deferred;`,
          );
        runSuite(file.replace(".sql", ""), text, "postgres");
      }
      summary.focusedAssertions = summary.suites.reduce(
        (sum, suite) => sum + suite.assertions,
        0,
      );
      const operational =
        mode === "option-a"
          ? buildDualOperationalAcceptance()
          : buildOperationalAcceptance();
      save("operational.sql", operational.sql);
      summary.originalStressSqlSha256 = operational.originalSha256;
      summary.outcome = "OPERATIONAL_ACCEPTANCE_IN_PROGRESS";
      summary.operationalRuns = 1;
      summary.operationalCorrectionsRequired = mode === "option-a" ? 2 : 1;
      runSuite("operational", operational.sql, database);
      summary.operationalAcceptance = true;
      summary.outcome = "HISTORICAL_STRESS_IN_PROGRESS";
      summary.historicalStressRuns = 1;
      // One deliberate Tier 3 attempt, exact original source and all 20 assertions.
      const stress = expand(
        "supabase/tests/confirmed_need_correction_scale.sql",
      );
      if (hash(stress) !== operational.originalSha256)
        throw new Error("Original stress oracle changed during run.");
      runSuite("historical-stress", stress, "atlas_c388_stress");
      summary.historicalStress = true;
      summary.outcome = "BOUNDED_SQL_ACCEPTANCE_PASS";
      return;
    }
    const preflight = snapshot(database, "probe-preflight");
    save("probe.sql", probe.sql);
    const started = new Date().toISOString();
    const began = performance.now();
    let stdout = "",
      stderr = "",
      waits = "";
    const observer = spawn("docker", psqlArgs("postgres", "supabase_admin"), {
      stdio: ["pipe", "pipe", "pipe"],
    });
    observer.stdout.on("data", (chunk) => {
      waits += chunk;
    });
    observer.stderr.on("data", (chunk) => {
      waits += chunk;
    });
    observer.stdin.on("error", () => {});
    let observerError;
    const observerExit = new Promise((resolve) => {
      observer.once("error", (error) => {
        observerError = error.message;
        resolve(null);
      });
      observer.once("close", resolve);
    });
    const interval = setInterval(() => {
      if (observer.stdin.destroyed || observer.stdin.writableEnded) return;
      observer.stdin.write(
        "select jsonb_build_object('at',clock_timestamp(),'pid',pid,'state',state,'wait_type',wait_event_type,'wait',wait_event,'blockers',pg_blocking_pids(pid)) from pg_stat_activity where datname='atlas_c388_probe' and application_name='atlas_c388_target';\n",
      );
    }, 200);
    const child = spawn(
      "docker",
      psqlArgs(database, mode === "profile" ? "supabase_admin" : "postgres"),
      {
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.stdin.on("error", () => {});
    let result;
    try {
      result = await new Promise((resolve, reject) => {
        child.on("error", reject);
        child.on("close", resolve);
        child.stdin.end(probe.sql);
      });
      summary.totalPrefixAndTargetWallMs = performance.now() - began;
    } finally {
      clearInterval(interval);
      observer.stdin.end();
      summary.observerExitCode = await observerExit;
      save("probe.log", stdout + stderr);
      save("wait-samples.jsonl", waits);
    }
    summary.targetPsqlStatementMs =
      Number(/Time:\s+([\d.]+)\s+ms/.exec(stdout)?.[1]) || null;
    summary.targetRuns = stderr.includes("C_SCALE_START history-1-preparation")
      ? 1
      : 0;
    const postflight = snapshot(database, "probe-postflight");
    const invariant = [
      "roles",
      "memberships",
      "schemas",
      "functions",
      "rows",
    ].every(
      (key) =>
        JSON.stringify(preflight[key]) === JSON.stringify(postflight[key]),
    );
    summary.outcome = classifyPreparationProbe(
      result,
      stdout + stderr,
      invariant,
    );
    summary.rollbackAndIntegrityVerified = invariant;
    summary.waitSampleCount = waits
      .split(/\r?\n/)
      .filter((line) => line.startsWith('{"at"')).length;
    summary.waitSamplingAvailable =
      summary.observerExitCode === 0 &&
      !observerError &&
      summary.waitSampleCount > 0;
    summary.observerError = observerError;
    summary.observer =
      "External 200ms samples; waitSamplingAvailable=false means sampling failed or no target samples were observed, never proof of no waits. Scheduling/startup can miss short waits. Observer overhead is not subtracted.";
    if (mode === "profile") {
      sql(
        "select jsonb_agg(to_jsonb(f)) from pg_stat_user_functions f where schemaname like 'atlas%'; select jsonb_agg(to_jsonb(s)) from extensions.pg_stat_statements s where dbid=(select oid from pg_database where datname=current_database());",
        database,
        "completed-function-and-statement-statistics",
        "supabase_admin",
      );
      const plans = command("docker", ["logs", "--since", started, container]);
      save("server-plans.log", (plans.stdout ?? "") + (plans.stderr ?? ""));
      summary.planCaptureExitCode = plans.status;
      summary.planCaptureError = plans.error?.message;
    }
    if (summary.outcome !== "TARGET_COMPLETED") process.exitCode = 1;
  } catch (error) {
    if (summary.outcome.endsWith("_IN_PROGRESS"))
      summary.outcome = summary.outcome.replace("_IN_PROGRESS", "_FAIL");
    summary.error = redactAtlasStagingDiagnostic(error.message);
    process.exitCode = 1;
  } finally {
    save("summary.json", summary);
    console.log(JSON.stringify(summary));
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
)
  await main();
