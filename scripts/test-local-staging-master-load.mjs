import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { repositorySupabaseCliInvocation } from "./atlas-staging-contract.mjs";

// The Supabase CLI copies test files into its container, not sibling package files.
// Inline the exact repository package into a disposable self-contained SQL test.
const include = "\\ir ../packages/atlas-staging-master-load.sql";
const test = readFileSync(
  "supabase/tests/atlas_staging_master_load.sql",
  "utf8",
);
if (test.split(include).length !== 2)
  throw new Error("STAGING_TEST_PACKAGE_INCLUDE_MISMATCH");
const work = mkdtempSync(join(tmpdir(), "atlas-staging-master-test-"));
try {
  const file = join(work, "atlas_staging_master_load.sql");
  writeFileSync(
    file,
    test.replace(include, () =>
      readFileSync("supabase/packages/atlas-staging-master-load.sql", "utf8"),
    ),
    "utf8",
  );
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
  rmSync(work, { recursive: true, force: true });
}
