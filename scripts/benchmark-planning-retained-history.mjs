import assert from "node:assert/strict";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { performance } from "node:perf_hooks";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";

// Only the task's disposable local stack is allowed, never a linked project.
const project = "atlas-retained-history-01";
const container = `supabase_db_${project}`;
assert.equal(process.env.ATLAS_LOCAL_DB_CONTAINER, container);
assert.match(
  readFileSync(
    path.join(process.env.SUPABASE_WORKDIR, "supabase/config.toml"),
    "utf8",
  ),
  new RegExp(`^project_id = "${project}"$`, "m"),
);
const root = fileURLToPath(new URL("../", import.meta.url));
const output = path.join(
  root,
  "docs/testing/artifacts/planning-retained-history",
);
mkdirSync(output, { recursive: true });
function docker(args, input) {
  const result = spawnSync("docker", args, {
    input,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}
function sql(source, database = "postgres", user = "postgres") {
  return docker(
    [
      "exec",
      "-i",
      container,
      "psql",
      "-XqAt",
      "-v",
      "ON_ERROR_STOP=1",
      "-U",
      user,
      "-d",
      database,
    ],
    source,
  );
}
function expand(file) {
  return readFileSync(path.join(root, file), "utf8").replace(
    /^\\ir\s+(.+)$/gm,
    (_, include) => expand(path.join(path.dirname(file), include.trim())),
  );
}
function copyCatalog(source, target) {
  const catalog = [
    ["customers", "customer_code like 'retained-catalog%'"],
    ["delivery_locations", "location_code like 'retained-catalog%'"],
    ["schools", "school_code like 'retained-catalog%'"],
    ["ingredients", "ingredient_code like 'retained-catalog%'"],
    ["suppliers", "supplier_code like 'retained-catalog%'"],
    [
      "supplier_eligibilities",
      "ingredient_id in (select ingredient_id from atlas_admin.ingredients where ingredient_code like 'retained-catalog%')",
    ],
  ];
  const inserts = catalog.map(([table, predicate]) =>
    sql(
      `select format(
    'insert into atlas_admin.${table} select (jsonb_populate_record(null::atlas_admin.${table},value)).* from jsonb_array_elements(%L::jsonb);',
    (select jsonb_agg(to_jsonb(r)) from atlas_admin.${table} r where ${predicate}));`,
      source,
    ),
  );
  sql(
    `begin; ${inserts.join("\n")} set constraints all immediate; commit;`,
    target,
  );
}
const fixture = "supabase/local/purchase_preparation_scale_fixture.sql";
const helpers = readFileSync(path.join(root, fixture), "utf8").replace(
  /^\\ir.*$/gm,
  "",
);
const subject = "b6000000-0000-0000-0000-000000000101";
function observation(call) {
  if (!call) return null;
  return {
    elapsed_ms: call.elapsed_ms,
    http_status: call.http_status,
    success: call.response.success ?? false,
    error_code: call.response.error_code ?? call.response.code ?? null,
    response_sha256: createHash("sha256")
      .update(JSON.stringify(call.response))
      .digest("hex"),
  };
}
const auth = readLocalSupabaseStatus({ requireAdminKey: true });
const options = {
  db: { retry: false },
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
};
const admin = createClient(auth.apiUrl, auth.serviceRoleKey, options);
const attributes = {
  id: subject,
  email: "atlas.pa06b.operator@local.test",
  password: "Atlas-PA06B-local-only!",
  email_confirm: true,
};
const [phase, rawDepth] = process.argv.slice(2);
assert.ok(["init", "seed", "before", "after"].includes(phase));
if (phase === "init") {
  const users = await admin.auth.admin.listUsers();
  assert.equal(users.error, null);
  if (!users.data.users.some((user) => user.id === subject)) {
    const created = await admin.auth.admin.createUser(attributes);
    assert.equal(created.error, null);
    assert.equal(created.data.user.id, subject);
  }
  if (
    sql(
      "select count(*) from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'",
    ) === "0"
  )
    sql(`begin; ${expand(fixture)} set constraints all immediate; commit;`);
  assert.equal(
    sql(`select (select count(*) from atlas_planning.confirmed_need_batches)=1
    and (select count(*) from atlas_planning.confirmed_need_line_revisions)=2
    and not exists(select 1 from atlas_planning.confirmed_need_line_decisions)
    and not exists(select 1 from atlas_planning.confirmed_need_validation_attempts)
    and not exists(select 1 from atlas_planning.confirmed_need_approval_snapshots)
    and not exists(select 1 from atlas_procurement.school_catering_allocation_families)
    and not exists(select 1 from atlas_procurement.purchase_orders);`),
    "t",
    "Template contains extra operational artifacts.",
  );
  // A clean migrated template has no previous scale days or leftover TEMP objects.
  const services = [`supabase_rest_${project}`, `supabase_auth_${project}`];
  docker(["stop", ...services]);
  try {
    sql(
      "select pg_terminate_backend(pid) from pg_stat_activity where datname='postgres' and pid<>pg_backend_pid();",
      "template1",
      "supabase_admin",
    );
    sql("create database atlas_history_clean template postgres;", "template1");
  } finally {
    docker(["start", ...services]);
    docker(["restart", `supabase_kong_${project}`]);
  }
  console.log("Clean migrated fixture template created.");
  process.exit(0);
}
const depth = Number(rawDepth);
assert.ok([0, 1, 3, 7, 14].includes(depth));
const database =
  phase === "seed"
    ? "atlas_history_seed_work"
    : `atlas_history_${phase}_${depth}`;
sql(
  `drop database if exists ${database} with (force);`,
  "template1",
  "supabase_admin",
);
sql(
  `create database ${database} template ${phase === "seed" ? "atlas_history_clean" : `atlas_history_seed_${depth}`};`,
  "template1",
);
if (phase === "after") {
  const migrations = JSON.parse(process.env.ATLAS_BENCHMARK_MIGRATIONS ?? "[]");
  assert.ok(migrations.length > 0);
  for (const file of migrations) {
    assert.match(file, /^supabase\/migrations\/\d{14}_[a-z0-9_]+\.sql$/);
    sql(readFileSync(path.join(root, file), "utf8"), database);
  }
}
const authority = JSON.parse(
  sql(
    `select jsonb_build_object(
  'roles',(select jsonb_object_agg(r.rolname,split_part(setting,'=',2)) from pg_db_role_setting s
    join pg_roles r on r.oid=s.setrole cross join lateral unnest(s.setconfig) setting
    where r.rolname in ('anon','authenticated','authenticator') and setting like 'statement_timeout=%'),
  'preparation_config',(select proconfig from pg_proc where oid='atlas_api.prepare_school_catering_purchase_orders(jsonb)'::regprocedure),
  'function_catalog_hash',encode(extensions.digest(convert_to((select jsonb_agg(jsonb_build_object(
    'signature',p.oid::regprocedure::text,'definition',pg_get_functiondef(p.oid),'acl',p.proacl)
    order by p.oid::regprocedure::text)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname like 'atlas_%'),'UTF8'),'sha256'),'hex'))`,
    database,
  ),
);
assert.deepEqual(authority.roles, {
  anon: "3s",
  authenticated: "8s",
  authenticator: "8s",
});
assert.ok(authority.preparation_config.includes("statement_timeout=20s"));
function seedDay(day, database) {
  const seed = day ? `retained-day-${day}` : "retained-target";
  // Separate Monday source windows keep approved weekly roots valid at each depth.
  const date = new Date(Date.UTC(2027, 3, 26) - day * 7 * 86400000)
    .toISOString()
    .slice(0, 10);
  const setup = sql(
    `begin; ${helpers}
    select pg_temp.seed_purchase_preparation_scale('${seed}','${seed}',date '${date}',null,'retained-catalog');
    select pg_temp.scale_confirmed_need_save_command('${seed}',md5('${seed}:confirmed-need-batch')::uuid);
    ${
      day
        ? `do $$ declare response jsonb; request jsonb; begin
      request:=pg_temp.scale_confirmed_need_save_command('${seed}',md5('${seed}:confirmed-need-batch')::uuid);
      execute 'set local role authenticated';
      perform set_config('request.jwt.claim.sub','${subject}',true);
      response:=atlas_api.save_confirmed_needs(request);
      if response->>'success' is distinct from 'true' then raise exception 'History Save failed: %',response; end if;
      set constraints all immediate; set constraints all deferred;
      execute 'reset role';
      request:=pg_temp.scale_command('${seed}:prepare','PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
        (select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=md5('${seed}:confirmed-need-batch')::uuid),
        jsonb_build_object('confirmed_need_batch_id',md5('${seed}:confirmed-need-batch')::uuid,'service_date','${date}'));
      execute 'set local role authenticated';
      response:=atlas_api.prepare_school_catering_purchase_orders(request);
      if response->>'success' is distinct from 'true' then raise exception 'History preparation failed: %',response; end if;
      execute 'reset role';
    end $$;`
        : ""
    }
    set constraints all immediate; commit;`,
    database,
  );
  console.log(`Seeded ${seed} with every integrity trigger enabled.`);
  return day
    ? null
    : JSON.parse(setup.split("\n").find((line) => line.startsWith('{"')));
}
if (phase === "seed") {
  assert.ok(
    depth >= 1,
    "Seed at least one prior day to share the exact catalog with depth zero.",
  );
  for (let day = 0; day <= depth; day++) {
    if (day) seedDay(day, database);
    if (day === 1) copyCatalog(database, "atlas_history_seed_0");
    if ([0, 1, 3, 7, 14].includes(day)) {
      sql(
        `drop database if exists atlas_history_seed_${day} with (force);`,
        "template1",
        "supabase_admin",
      );
      sql(
        `create database atlas_history_seed_${day} template ${database};`,
        "template1",
      );
    }
  }
  console.log(
    "Equivalent committed history snapshots created; each measured target uses a fresh clone.",
  );
  process.exit(0);
}
const saveRequest = seedDay(0, database);
const browser = createClient(auth.apiUrl, auth.browserKey, options);
const session = await browser.auth.signInWithPassword({
  email: attributes.email,
  password: attributes.password,
});
assert.equal(session.error, null);
assert.equal(session.data.user.id, subject);
const restName = `atlas_history_rest_${phase}_${depth}`;
const restConfig = JSON.parse(
  docker(["inspect", `supabase_rest_${project}`]),
)[0];
const network = Object.keys(restConfig.NetworkSettings.Networks)[0];
const restEnvironment = restConfig.Config.Env.filter((value) =>
  value.startsWith("PGRST_"),
);
const uri = restEnvironment.find((value) => value.startsWith("PGRST_DB_URI="));
assert.ok(uri);
const databaseUri = new URL(uri.slice("PGRST_DB_URI=".length));
databaseUri.pathname = `/${database}`;
const args = [
  "run",
  "--detach",
  "--name",
  restName,
  "--network",
  network,
  "-p",
  "127.0.0.1:56531:3000",
];
for (const value of restEnvironment)
  args.push(
    "-e",
    value.startsWith("PGRST_DB_URI=") ? `PGRST_DB_URI=${databaseUri}` : value,
  );
args.push(restConfig.Config.Image);
docker(args);
async function invoke(name, request) {
  const start = performance.now();
  const response = await fetch(`http://127.0.0.1:56531/rpc/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Profile": "atlas_api",
      Authorization: `Bearer ${session.data.session.access_token}`,
    },
    body: JSON.stringify({ request }),
    signal: AbortSignal.timeout(45000),
  });
  const data = await response.json();
  return {
    elapsed_ms: Number((performance.now() - start).toFixed(3)),
    http_status: response.status,
    response: data,
  };
}
try {
  for (let attempt = 0; attempt < 30; attempt++) {
    try {
      const response = await fetch("http://127.0.0.1:56531/");
      if (response.ok) break;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.ok(attempt < 29, "Disposable PostgREST did not become ready.");
  }
  const saved = await invoke("save_confirmed_needs", saveRequest);
  assert.equal(saved.response.success, true, JSON.stringify(saved));
  const setupCounts = JSON.parse(
    sql(
      `select jsonb_build_object(
    'prepared_days',(select count(*) from atlas_planning.confirmed_need_batches where batch_status='RELEASED_FOR_PURCHASE_HANDOFF'),
    'batches',(select count(*) from atlas_planning.confirmed_need_batches),
    'decisions',(select count(*) from atlas_planning.confirmed_need_line_decisions),
    'historical_po_drafts',(select count(*) from atlas_procurement.purchase_orders),
    'historical_po_lines',(select count(*) from atlas_procurement.purchase_order_lines),
    'historical_validation_lines',(select count(*) from atlas_planning.confirmed_need_validation_lines),
    'historical_snapshot_lines',(select count(*) from atlas_planning.confirmed_need_snapshot_lines),
    'catalog_hash',encode(extensions.digest(convert_to((select jsonb_agg(value order by value::text)::text from (
      select to_jsonb(r) value from atlas_admin.schools r where school_code like 'retained-catalog%'
      union all select to_jsonb(r) from atlas_admin.ingredients r where ingredient_code like 'retained-catalog%'
      union all select to_jsonb(r) from atlas_admin.suppliers r where supplier_code like 'retained-catalog%'
      union all select to_jsonb(r) from atlas_admin.customers r where customer_code like 'retained-catalog%'
      union all select to_jsonb(r) from atlas_admin.delivery_locations r where location_code like 'retained-catalog%'
      union all select to_jsonb(r) from atlas_admin.supplier_eligibilities r where ingredient_id in(
        select ingredient_id from atlas_admin.ingredients where ingredient_code like 'retained-catalog%')) catalog),'UTF8'),'sha256'),'hex'))`,
      database,
    ),
  );
  assert.equal(setupCounts.prepared_days, depth);
  assert.equal(setupCounts.batches, depth + 2);
  assert.equal(setupCounts.decisions, (depth + 1) * 236);
  assert.equal(setupCounts.historical_po_drafts, depth * 12);
  assert.equal(setupCounts.historical_po_lines, depth * 236);
  assert.equal(setupCounts.historical_validation_lines, depth * 236);
  assert.equal(setupCounts.historical_snapshot_lines, depth * 236);
  sql(
    `do $$ declare r record; begin for r in select schemaname,relname from pg_stat_user_tables where schemaname like 'atlas_%' loop execute format('analyze %I.%I',r.schemaname,r.relname); end loop; end $$;`,
    database,
  );
  const request = JSON.parse(
    sql(
      `begin; ${helpers} select pg_temp.scale_command('retained-target:prepare','PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
    (select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=md5('retained-target:confirmed-need-batch')::uuid),
    jsonb_build_object('confirmed_need_batch_id',md5('retained-target:confirmed-need-batch')::uuid,'service_date','2027-04-26')); rollback;`,
      database,
    ),
  );
  // Built-in function statistics measure stages without replacing production bodies.
  sql(
    `alter database ${database} set track_functions='all'; select pg_stat_reset();`,
    database,
    "supabase_admin",
  );
  docker(["restart", restName]);
  await new Promise((resolve) => setTimeout(resolve, 1000));
  const prepared = await invoke(
    "prepare_school_catering_purchase_orders",
    request,
  );
  await new Promise((resolve) => setTimeout(resolve, 1000));
  const functions = JSON.parse(
    sql(
      "select coalesce(jsonb_agg(to_jsonb(f) order by total_time desc),'[]') from pg_stat_user_functions f where calls>0;",
      database,
    ),
  );
  writeFileSync(
    path.join(output, `${phase}-${depth}.json`),
    JSON.stringify(
      { phase, depth, database, prepared: observation(prepared), functions },
      null,
      2,
    ) + "\n",
  );
  const counts = JSON.parse(
    sql(
      `select jsonb_build_object(
    'prior_days',${depth},'schools',(select count(*) from atlas_admin.schools),'ingredients',(select count(*) from atlas_admin.ingredients),'suppliers',(select count(*) from atlas_admin.suppliers),
    'batches',(select count(*) from atlas_planning.confirmed_need_batches),
    'revisions',(select count(*) from atlas_planning.confirmed_need_line_revisions),
    'theoretical_lines',(select count(*) from atlas_planning.theoretical_need_lines),
    'source_memberships',(select count(*) from atlas_planning.confirmed_need_line_revision_contributions),
    'need_runs',(select count(*) from atlas_planning.need_generation_runs),
    'decisions',(select count(*) from atlas_planning.confirmed_need_line_decisions),
    'validation_lines',(select count(*) from atlas_planning.confirmed_need_validation_lines),
    'snapshot_lines',(select count(*) from atlas_planning.confirmed_need_snapshot_lines),
    'defaults',(select count(*) from atlas_procurement.school_catering_allocation_family_revisions where command_id='${request.command_id}' and source_kind='CONFIRMED_NEED' and decision_origin='PRIORITY_RECOMMENDATION'),
    'manual_defaults',(select count(*) from atlas_procurement.school_catering_allocation_family_revisions where command_id='${request.command_id}' and source_kind='CONFIRMED_NEED' and decision_origin='MANUAL'),
    'promoted',(select count(*) from atlas_procurement.school_catering_allocation_family_revisions r join atlas_procurement.school_catering_allocation_families f using(family_id) where f.service_date='2027-04-26' and r.is_current and r.source_kind='PURCHASE_HANDOFF'),
    'po_drafts',(select count(*) from atlas_procurement.purchase_orders where school_catering_service_date='2027-04-26'),
    'po_lines',(select count(*) from atlas_procurement.purchase_order_lines l join atlas_procurement.purchase_orders p using(purchase_order_id) where p.school_catering_service_date='2027-04-26'))`,
      database,
    ),
  );
  const replay = prepared.response.success
    ? await invoke("prepare_school_catering_purchase_orders", request)
    : null;
  const result = {
    phase,
    depth,
    database,
    setupCounts,
    authority,
    prepared: observation(prepared),
    counts,
    functions,
    replay: observation(replay),
  };
  writeFileSync(
    path.join(output, `${phase}-${depth}.json`),
    JSON.stringify(result, null, 2) + "\n",
  );
  console.log(
    JSON.stringify({
      phase,
      depth,
      elapsed_ms: prepared.elapsed_ms,
      success: prepared.response.success,
      counts,
    }),
  );
  if (prepared.response.success) {
    assert.equal(counts.defaults, 236);
    assert.equal(counts.manual_defaults, 0);
    assert.equal(counts.promoted, 236);
    assert.equal(counts.po_drafts, 12);
    assert.equal(counts.po_lines, 236);
    assert.deepEqual(replay.response, prepared.response);
  }
  if (phase === "after")
    assert.equal(
      prepared.response.success,
      true,
      "After preparation failed; see saved diagnostic.",
    );
} finally {
  docker(["rm", "--force", restName]);
}
