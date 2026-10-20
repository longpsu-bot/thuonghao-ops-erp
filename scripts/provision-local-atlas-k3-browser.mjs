// Disposable K3 browser rehearsal only. Never selects the repository's default local project.
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";
import { parseLocalSupabaseStatus } from "./local-supabase-status.mjs";

const [runtime, evidenceDirectory] = process.argv.slice(2);
assert(
  runtime && evidenceDirectory,
  "Usage: node scripts/provision-local-atlas-k3-browser.mjs <task-runtime> <evidence-directory>",
);
const root = path.resolve(import.meta.dirname, "..");
const config = readFileSync(path.join(runtime, "supabase/config.toml"), "utf8");
assert(
  /^project_id = "atlas-k3-local-01"$/m.test(config),
  "Only the task-owned disposable project is allowed.",
);
assert(/^port = 56321$/m.test(config), "Unexpected disposable API port.");
const container = "supabase_db_atlas-k3-local-01";
function sql(statement) {
  const result = spawnSync(
    "docker",
    [
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
      "postgres",
    ],
    { input: statement, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}
assert.equal(
  sql("select to_regclass('public.k1_original_history') is null;"),
  "t",
  "A browser fixture already exists. Preserve its evidence; do not overwrite it.",
);
function expand(file) {
  return readFileSync(file, "utf8").replace(/^\\ir\s+(.+)$/gm, (_, name) =>
    expand(path.resolve(path.dirname(file), name.trim())),
  );
}
const fixture = expand(
  path.join(root, "supabase/tests/atlas_c_need_correction_authority.sql"),
);
const marker = "create function pg_temp.k1_reject_case";
assert.equal(fixture.split(marker).length, 2);
const k2 = expand(
  path.join(root, "supabase/tests/atlas_k2_corrected_need_purchase_orders.sql"),
);
const b1Start = k2.indexOf(
  "-- Real R20/B5/H3 generation, two Schools sharing one location, two Suppliers.",
);
const b1End = k2.indexOf("insert into k2_issued_history select name", b1Start);
assert(
  b1Start > 0 && b1End > b1Start,
  "B1 baseline markers changed; review before provisioning.",
);
const b1Setup =
  `
create table public.k2_results(name text primary key,response jsonb not null);
create table public.k2_requests(name text primary key,request jsonb not null);
grant select,insert on k2_results,k2_requests to authenticated;
` +
  k2
    .slice(b1Start, b1End)
    .replaceAll("create temporary table ", "create table public.") +
  `
update atlas_admin.schools set dispatch_document_issuer_name='K3 disposable B1 issuer',dispatch_document_issuer_address='K3 disposable address' where school_id in('a7400000-0000-4000-8000-000000005001','a7400000-0000-4000-8000-000000005002');
`;
const setup =
  fixture
    .split(marker)[0]
    .replaceAll("create temporary table ", "create table public.") +
  b1Setup +
  `
insert into atlas_core.actors(actor_id,actor_type,display_name) values('b6000000-0000-0000-0000-000000000011','HUMAN','K3 second disposable operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values('b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000111');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values('b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes(actor_id,scope_kind,reason_note) values('b6000000-0000-0000-0000-000000000011','GLOBAL','K3 disposable browser rehearsal');
set constraints all immediate;
commit;
`;
const setupLog = sql(setup);
writeFileSync(path.join(evidenceDirectory, "browser-fixture.log"), setupLog);
assert(
  !/^not ok\b/m.test(setupLog),
  "Browser prerequisite assertions failed; inspect browser-fixture.log.",
);
const status = parseLocalSupabaseStatus(
  execFileSync(
    process.execPath,
    [
      path.join(root, "node_modules/supabase/dist/supabase.js"),
      "status",
      "--workdir",
      runtime,
      "-o",
      "json",
    ],
    { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
  ),
  { requireAdminKey: true },
);
assert.equal(status.apiUrl, "http://127.0.0.1:56321");
const admin = createClient(status.apiUrl, status.serviceRoleKey, {
  db: { retry: false },
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
});
for (const [id, email] of [
  ["b6000000-0000-0000-0000-000000000101", "atlas.pa06b.operator@local.test"],
  ["b6000000-0000-0000-0000-000000000111", "atlas.k3.second@local.test"],
  ["a7400000-0000-4000-8000-000000000101", "atlas.k3.b1@local.test"],
]) {
  const result = await admin.auth.admin.createUser({
    id,
    email,
    password: "Atlas-PA06B-local-only!",
    email_confirm: true,
    user_metadata: { display_name: "K3 disposable operator" },
    app_metadata: { environment: "atlas-k3-local-01" },
  });
  assert(
    !result.error && result.data.user?.id === id,
    "Disposable authentication provisioning failed.",
  );
}
console.log(
  "K3 disposable fixture ready: 2026-11-02, authenticated operators 101 and 111. Issued PO/PXK baseline retained.",
);
