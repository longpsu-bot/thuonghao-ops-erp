import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import { recipeHistoryContentChecksum } from "./import-atlas-staging-recipe-history.mjs";
import { extractRecipeHistorySnapshot } from "./recipe-change-order-history.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import { migrationVersionsFromFilenames } from "./verify-atlas-staging.mjs";
import {
  redactAtlasStagingDiagnostic,
  validateAtlasStagingProtectedValues,
  verifyExactHeadCertification,
} from "./atlas-staging-contract.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
const PINNED = {
  7: ["1043", "1039", "2025-12-15"],
  11: ["1029", "1067", "2026-03-03"],
  12: ["836", "904", "2026-04-03"],
  13: ["1042", "1041"],
  14: ["1040", "1208", "2026-10-09"],
};

export function globalReplacementContentChecksum(snapshot) {
  recipeHistoryContentChecksum(snapshot);
  const rows = snapshot.records.filter(
    (r) => r.source_table === "ingredient_change_orders",
  );
  if (
    rows.length !== 5 ||
    new Set(rows.map((r) => r.legacy_id)).size !== 5 ||
    rows.some((r) => {
      const pin = PINNED[r.legacy_id],
        raw = r.source_record;
      return (
        !pin ||
        r.scope_kind !== "SYSTEM_INGREDIENT" ||
        r.action !== "REPLACE" ||
        r.source_active !== true ||
        raw?.is_active !== true ||
        raw.id !== r.legacy_id ||
        raw.old_ingredient_id !== pin[0] ||
        raw.new_ingredient_id !== pin[1] ||
        (pin[2] &&
          (r.effective_from !== pin[2] || raw.effective_date !== pin[2]))
      );
    })
  )
    throw Error("GLOBAL_SOURCE_DRIFT");
  return checksumOpsV1MasterSnapshot({
    source_project_ref: snapshot.source_project_ref,
    adoption_date: "2026-11-09",
    records: rows,
  });
}

export function buildStagingGlobalReplacementSql(
  snapshot,
  {
    targetProjectRef,
    apply = false,
    reviewedContentChecksum = null,
    migrationVersions,
  } = {},
) {
  if (targetProjectRef !== STAGING)
    throw Error("EXACT_STAGING_TARGET_REQUIRED");
  const sourceChecksum = globalReplacementContentChecksum(snapshot);
  if (
    !Array.isArray(migrationVersions) ||
    !migrationVersions.length ||
    migrationVersions.some((v) => !/^\d{14}$/.test(v)) ||
    new Set(migrationVersions).size !== migrationVersions.length
  )
    throw Error("MIGRATION_VERSIONS_INVALID");
  if (apply && !/^[a-f0-9]{64}$/.test(reviewedContentChecksum ?? ""))
    throw Error("REVIEWED_CONTENT_REQUIRED");
  const encode = (value) =>
    `convert_from(decode('${Buffer.from(JSON.stringify(value)).toString("base64")}','base64'),'UTF8')::jsonb`;
  return `${readFileSync(new URL("../supabase/packages/atlas-staging-global-replacements.sql", import.meta.url), "utf8")}\nbegin;
set local statement_timeout='10min'; set local lock_timeout='15s';
select pg_temp.run_global_replacements(${encode(snapshot)},${encode(migrationVersions)},'${sourceChecksum}',${apply ? "true" : "false"},${encode(reviewedContentChecksum)}) as result;
commit;`;
}

export async function runStagingGlobalReplacements({
  commitSha,
  apply = false,
  reviewedContentChecksum,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  verifyCertification = verifyExactHeadCertification,
  extractSnapshot = extractRecipeHistorySnapshot,
  migrationVersions = migrationVersionsFromFilenames(
    readdirSync(resolve(cwd, "supabase/migrations")),
  ),
  executeTarget,
} = {}) {
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  validateAtlasStagingProtectedValues(environment);
  if (apply && !/^[a-f0-9]{64}$/.test(reviewedContentChecksum ?? ""))
    throw Error("REVIEWED_CONTENT_REQUIRED");
  await verifyCheckout({ commitSha, cwd });
  await verifyCertification({
    commitSha,
    certificationMode: "github",
    environment,
    cwd,
  });
  const snapshot = await extractSnapshot({
    accessToken: authority.targetAccessToken,
    snapshotId: `ops-v1-globals-${environment.GITHUB_RUN_ID ?? Date.now()}-${environment.GITHUB_RUN_ATTEMPT ?? "1"}`,
    extractorVersion: commitSha,
  });
  globalReplacementContentChecksum(snapshot);
  await verifyCheckout({ commitSha, cwd });
  const execute =
    executeTarget ??
    ((target, sql) =>
      executeAtlasStagingPostgres(target, sql, { environment, cwd }));
  const result = parseStagingMasterResult(
    await execute(
      { projectRef: STAGING, supabaseUrl: authority.targetSupabaseUrl },
      buildStagingGlobalReplacementSql(snapshot, {
        targetProjectRef: STAGING,
        apply,
        reviewedContentChecksum,
        migrationVersions,
      }),
    ),
  );
  if (
    !result.preserved ||
    result.roots !== 4 ||
    result.revisions !== 4 ||
    result.receipts !== 1 ||
    result.status !== (apply ? "APPLIED" : "PREVIEW") ||
    result.replay_status !== "REPLAYED"
  )
    throw Error("GLOBAL_RECONCILIATION_FAILED");
  return result;
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const values = new Map(),
      args = process.argv.slice(2);
    for (let i = 0; i < args.length; i++) {
      const key = args[i];
      if (
        values.has(key) ||
        ![
          "--commit-sha",
          "--apply",
          "--target-project-ref",
          "--reviewed-content-checksum",
        ].includes(key)
      )
        throw Error("INVALID_ARGUMENT");
      if (key === "--apply") values.set(key, true);
      else {
        if (!args[i + 1] || args[i + 1].startsWith("--"))
          throw Error("INVALID_ARGUMENT");
        values.set(key, args[++i]);
      }
    }
    const result = await runStagingGlobalReplacements({
      commitSha: values.get("--commit-sha"),
      apply: values.has("--apply"),
      targetConfirmation: values.get("--target-project-ref"),
      reviewedContentChecksum: values.get("--reviewed-content-checksum"),
    });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(
      `${redactAtlasStagingDiagnostic(error.message, [process.env.ATLAS_STAGING_DB_PASSWORD, process.env.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN, process.env.ATLAS_STAGING_TEST_PASSWORD].filter(Boolean))}\n`,
    );
    process.exitCode = 1;
  }
}
