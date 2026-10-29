import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { repositorySupabaseCliInvocation } from "./atlas-staging-contract.mjs";
import {
  buildIngredientNameCorrectionPayload,
  INGREDIENT_NAME_CORRECTIONS,
} from "./correct-atlas-staging-ingredient-names.mjs";

const records = INGREDIENT_NAME_CORRECTIONS.map(
  ([legacy_id, , ingredient_name]) => ({
    legacy_id,
    ingredient_code: `v1-ingredient-${legacy_id}`,
    ingredient_name,
    ingredient_type_legacy_id: "1",
    ingredient_order_group_legacy_id: "1",
    purchase_unit_legacy_id: "kg",
    order_step: "1",
    ingredient_status: "ACTIVE",
  }),
);
const snapshot = {
  source_project_ref: "qnthofvccilhnefdcxnz",
  snapshot_checksum: createHash("sha256")
    .update(JSON.stringify(records), "utf8")
    .digest("hex"),
  records: { ingredients: records },
};
const payload = buildIngredientNameCorrectionPayload(snapshot);
const work = mkdtempSync(
  join(tmpdir(), "atlas-ingredient-name-correction-test-"),
);
try {
  const file = join(
    work,
    "atlas_staging_ingredient_name_forward_correction.sql",
  );
  const test = readFileSync(
    "supabase/tests/atlas_staging_ingredient_name_forward_correction.sql",
    "utf8",
  );
  const packagePath =
    "supabase/packages/atlas-staging-ingredient-name-forward-correction.sql";
  const sql = readFileSync(packagePath, "utf8");
  const include =
    "\\ir ../packages/atlas-staging-ingredient-name-forward-correction.sql";
  if (test.split(include).length !== 2 || test.split("-- FIXTURE").length !== 2)
    throw new Error("INGREDIENT_NAME_TEST_INCLUDE_MISMATCH");
  writeFileSync(
    file,
    test
      .replace(
        "-- FIXTURE",
        `create temp table fixture(value jsonb); insert into fixture values ($fixture$${JSON.stringify(payload)}$fixture$::jsonb);`,
      )
      .replace(include, () => sql),
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
