import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const read = (name) => readFileSync(new URL(name, import.meta.url), "utf8");
const sourceName = process.argv[2] ?? "apply.sql";
assert.ok(["apply.sql", "rollback.sql"].includes(sourceName));
const definitions = read(sourceName).match(
  /CREATE OR REPLACE FUNCTION[\s\S]*?\$function\$;/g,
);
assert.equal(definitions?.length, 4, "expected four existing menu functions");
const fixture = read("fixture.sql");
const source = definitions
  .join("\n")
  .replaceAll("public.", "pg_temp.")
  .replaceAll("auth.uid()", "pg_temp.uid()");
const declarations = (name) =>
  read(name)
    .match(/CREATE OR REPLACE FUNCTION[\s\S]*?\$function\$;/g)
    .join("\n")
    .replaceAll("FUNCTION public.", "FUNCTION pg_temp.");
const guard = (name) =>
  read(name)
    .match(/do \$guard\$[\s\S]*?\$guard\$;/)[0]
    .replaceAll("'public.", "'pg_temp.");
const rollbackGuardBody = guard("rollback.sql")
  .replace(/^do \$guard\$/, "")
  .replace(/\$guard\$;$/, "");
const guardProbe = `begin;
create temp table guard_namespace(id integer);
${declarations("rollback.sql")}
${guard("apply.sql")}
${declarations("apply.sql")}
${guard("rollback.sql")}
create or replace function pg_temp.fn_update_order_dishes(p_body jsonb)
returns void language plpgsql as $$ begin return; end $$;
do $verify_guard$
declare rejected boolean := false;
begin
  begin
    ${rollbackGuardBody}
  exception when object_not_in_prerequisite_state then
    rejected := sqlerrm like 'OPS_V1_MENU_HOTFIX_SOURCE_MISMATCH:%';
  end;
  if not rejected then raise exception 'unknown source accepted'; end if;
end;
$verify_guard$;
\\echo PASS apply/rollback source guards and drift rejection
rollback;
`;
const result = spawnSync(
  "docker",
  [
    "exec",
    "-i",
    "supabase_db_thuonghao-ops-erp",
    "psql",
    "-X",
    "-v",
    "ON_ERROR_STOP=1",
    "-U",
    "postgres",
    "-d",
    "postgres",
  ],
  {
    input:
      guardProbe +
      "begin;\nset local search_path=pg_temp,public;\n" +
      fixture +
      "\n" +
      source +
      "\n" +
      read("regression.sql") +
      "\nrollback;\n",
    encoding: "utf8",
    timeout: 60_000,
  },
);
process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");
assert.ifError(result.error);
assert.equal(result.status, 0, "isolated OPS v1 regression failed");
