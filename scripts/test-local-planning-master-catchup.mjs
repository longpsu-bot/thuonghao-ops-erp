import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, sep } from "node:path";
import { spawnSync } from "node:child_process";
import { repositorySupabaseCliInvocation } from "./atlas-staging-contract.mjs";

let test = readFileSync(
  "supabase/tests/atlas_planning_master_catchup.sql",
  "utf8",
);
for (const name of [
  "atlas-planning-master-catchup.sql",
  "atlas-planning-catalog-sync.sql",
]) {
  const include = `\\ir ../packages/${name}`;
  if (test.split(include).length !== 2)
    throw new Error("PLANNING_CATCHUP_TEST_PACKAGE_INCLUDE_MISMATCH");
  test = test.replace(include, () =>
    readFileSync(`supabase/packages/${name}`, "utf8"),
  );
}
const tempRoot = resolve(tmpdir());
const work = mkdtempSync(join(tempRoot, "atlas-planning-catchup-test-"));
try {
  const file = join(work, "atlas_planning_master_catchup.sql");
  writeFileSync(file, test, "utf8");
  const invocation = repositorySupabaseCliInvocation([
    "test",
    "db",
    file,
    "--local",
  ]);
  const result = spawnSync(invocation.command, invocation.args, {
    stdio: "inherit",
    shell: invocation.shell,
  });
  process.exitCode = result.status ?? 1;
} finally {
  const resolvedWork = resolve(work);
  if (!resolvedWork.startsWith(tempRoot + sep))
    throw new Error("PLANNING_CATCHUP_TEMP_PATH_MISMATCH");
  rmSync(resolvedWork, { recursive: true, force: true });
}
