import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { repositorySupabaseCliInvocation } from "./atlas-staging-contract.mjs";

const work = mkdtempSync(join(tmpdir(), "atlas-school-order-correction-test-"));
try {
  const file = join(work, "atlas_staging_school_order_forward_correction.sql");
  const test = readFileSync(
    "supabase/tests/atlas_staging_school_order_forward_correction.sql",
    "utf8",
  );
  const fixture = JSON.parse(
    readFileSync(
      "scripts/fixtures/atlas-school-order-forward-correction.json",
      "utf8",
    ),
  );
  const packagePath =
    "supabase/packages/atlas-staging-school-order-forward-correction.sql";
  const sql = readFileSync(packagePath, "utf8");
  const include =
    "\\ir ../packages/atlas-staging-school-order-forward-correction.sql";
  if (test.split(include).length !== 2 || test.split("-- FIXTURE").length !== 2)
    throw new Error("SCHOOL_ORDER_TEST_INCLUDE_MISMATCH");
  writeFileSync(
    file,
    test
      .replace(
        "-- FIXTURE",
        () =>
          `create temp table fixture(value jsonb); insert into fixture values ($fixture$${JSON.stringify(fixture)}$fixture$::jsonb);`,
      )
      .replace(
        "\\ir ../packages/atlas-staging-school-order-forward-correction.sql",
        () => sql,
      ),
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
