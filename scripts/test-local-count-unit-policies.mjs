import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { repositorySupabaseCliInvocation } from "./atlas-staging-contract.mjs";
const body = readFileSync(
  "supabase/packages/staging-count-unit-policies.v1.sql",
  "utf8",
);
let test = readFileSync(
  "supabase/tests/staging_count_unit_policies.sql",
  "utf8",
);
if (
  test.split("-- PACKAGE_INSTALL").length !== 3 ||
  test.split("-- PACKAGE_TEST_FUNCTION").length !== 2
)
  throw new Error("POLICY_TEST_INCLUDE_MISMATCH");
const functionBody = body
  .split("do $count_policies$")[1]
  .split("$count_policies$;")[0];
test = test
  .replaceAll("-- PACKAGE_INSTALL", body)
  .replace(
    "-- PACKAGE_TEST_FUNCTION",
    `create function pg_temp.run_policy_package() returns void language plpgsql as $policy_test$${functionBody}$policy_test$;`,
  );
const work = mkdtempSync(join(tmpdir(), "atlas-count-policies-"));
try {
  const file = join(work, "staging_count_unit_policies.sql");
  writeFileSync(file, test, "utf8");
  const c = repositorySupabaseCliInvocation(["test", "db", file, "--local"]);
  const r = spawnSync(c.command, c.args, { stdio: "inherit", shell: c.shell });
  process.exitCode = r.status ?? 1;
} finally {
  rmSync(work, { recursive: true, force: true });
}
