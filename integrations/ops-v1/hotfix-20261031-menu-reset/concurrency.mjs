import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";

const container = "supabase_db_thuonghao-ops-erp";
const database =
  "ops_v1_hotfix_test_" + randomUUID().replaceAll("-", "").slice(0, 12);
const read = (name) => readFileSync(new URL(name, import.meta.url), "utf8");
const docker = (args, input) =>
  spawnSync("docker", ["exec", "-i", container, ...args], {
    input,
    encoding: "utf8",
    timeout: 15_000,
  });
const args = [
  "psql",
  "-X",
  "-qAt",
  "-v",
  "ON_ERROR_STOP=1",
  "-U",
  "postgres",
  "-d",
  database,
];
const sql = (input) => {
  const result = docker(args, input);
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
};
const sessions = [];
const session = (input, keepOpen = false) => {
  const child = spawn("docker", ["exec", "-i", container, ...args], {
    stdio: "pipe",
  });
  const result = { child, output: "", errors: "" };
  child.stdout.on("data", (data) => {
    result.output += data;
  });
  child.stderr.on("data", (data) => {
    result.errors += data;
  });
  result.done = new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("close", (status) => resolve(status));
  });
  child.stdin.write(input);
  if (!keepOpen) child.stdin.end();
  sessions.push(result);
  return result;
};
const waitFor = async (condition) => {
  const deadline = Date.now() + 8_000;
  while (!condition()) {
    assert.ok(Date.now() < deadline, "concurrency barrier timed out");
    await delay(25);
  }
};

assert.match(database, /^ops_v1_hotfix_test_[a-f0-9]{12}$/);
const created = docker(["createdb", "-U", "postgres", database]);
assert.ifError(created.error);
assert.equal(created.status, 0, created.stderr);
try {
  const fixture = read("fixture.sql")
    .replaceAll("create temp ", "create ")
    .replaceAll("pg_temp.", "public.");
  const functions = read("apply.sql")
    .match(/CREATE OR REPLACE FUNCTION[\s\S]*?\$function\$;/g)
    .join("\n")
    .replaceAll("auth.uid()", "public.uid()");
  sql(
    fixture +
      "\n" +
      functions +
      `
create function public.pause_manual_save() returns trigger language plpgsql as $$
begin
  if new.id=2 then
    perform pg_advisory_xact_lock(81501);
    perform pg_advisory_xact_lock(81502);
  end if;
  return new;
end $$;
create trigger pause_manual after update on daily_orders
for each row execute function public.pause_manual_save();
`,
  );

  const coordinator = session(
    "select pg_advisory_lock(81502);\n\\echo LOCK_HELD\n",
    true,
  );
  await waitFor(() => coordinator.output.includes("LOCK_HELD"));
  const manual = session(`
set statement_timeout='8s';
set deadlock_timeout='100ms';
select fn_save_daily_menus(
  '[{"school_id":2,"service_date":"2026-11-02","mon_canh":11},
    {"school_id":1,"service_date":"2026-11-02","mon_canh":11,"mon_man":12}]');
`);
  await waitFor(
    () =>
      sql(
        "select exists(select 1 from pg_locks where locktype='advisory' and database=(select oid from pg_database where datname=current_database()) and objid=81501 and granted);",
      ) === "t",
  );
  const weekly = session(`
set application_name='ops-v1-hotfix-weekly';
set statement_timeout='8s';
set deadlock_timeout='100ms';
select fn_upsert_weekly_menu('2026-11-02','fixture','new-sig',
  '[{"school_id":1,"service_date":"2026-11-02","dish_id":12},
    {"school_id":1,"service_date":"2026-11-02","dish_id":13},
    {"school_id":2,"service_date":"2026-11-02","dish_id":null}]');
`);
  await waitFor(
    () =>
      sql(
        "select exists(select 1 from pg_stat_activity where datname=current_database() and application_name='ops-v1-hotfix-weekly' and wait_event_type='Lock');",
      ) === "t",
  );
  coordinator.child.stdin.end("select pg_advisory_unlock(81502);\n\\quit\n");
  const statuses = await Promise.all([
    manual.done,
    weekly.done,
    coordinator.done,
  ]);
  assert.deepEqual(
    statuses,
    [0, 0, 0],
    manual.errors + weekly.errors + coordinator.errors,
  );
  sql("select assert_override(1,102);");
  console.log(
    "PASS reversed manual save and weekly sync serialize without deadlock",
  );
} finally {
  for (const { child } of sessions) child.stdin.destroy();
  const dropped = docker(["dropdb", "--force", "-U", "postgres", database]);
  assert.ifError(dropped.error);
  assert.equal(dropped.status, 0, dropped.stderr);
}
