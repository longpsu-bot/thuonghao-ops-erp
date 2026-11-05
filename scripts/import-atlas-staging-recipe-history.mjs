import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
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
const ACTOR = "a217bdd5-2858-58c2-8964-45c465225a59";

export function recipeHistoryContentChecksum(snapshot) {
  if (
    snapshot?.contract_version !== "OPS-V1-RECIPE-HISTORY.v1" ||
    snapshot.source_system !== "OPS_V1_RECIPE_HISTORY" ||
    snapshot.source_project_ref !== "qnthofvccilhnefdcxnz" ||
    snapshot.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot)
  )
    throw Error("SNAPSHOT_CHECKSUM_OR_CONTRACT_INVALID");
  return checksumOpsV1MasterSnapshot({
    contract_version: snapshot.contract_version,
    source_system: snapshot.source_system,
    source_project_ref: snapshot.source_project_ref,
    mode: "ARCHIVE_ONLY",
    source_counts: snapshot.source_counts,
    records: snapshot.records,
  });
}

export function buildStagingRecipeHistorySql(
  snapshot,
  { targetProjectRef, apply = false, migrationVersions } = {},
) {
  if (targetProjectRef !== STAGING)
    throw Error("EXACT_STAGING_TARGET_REQUIRED");
  recipeHistoryContentChecksum(snapshot);
  if (
    !Array.isArray(migrationVersions) ||
    !migrationVersions.length ||
    migrationVersions.some((v) => !/^\d{14}$/.test(v)) ||
    new Set(migrationVersions).size !== migrationVersions.length
  )
    throw Error("MIGRATION_VERSIONS_INVALID");
  const encode = (value) =>
    `convert_from(decode('${Buffer.from(JSON.stringify(value)).toString("base64")}','base64'),'UTF8')::jsonb`;
  const helper = readFileSync(
    new URL(
      "../supabase/packages/atlas-staging-recipe-history.sql",
      import.meta.url,
    ),
    "utf8",
  );
  return `${helper}\n${apply ? "begin;" : "begin read only;"}
set local statement_timeout='2min'; set local lock_timeout='15s';
select pg_temp.run_recipe_history_archive(${encode(snapshot)},${encode(migrationVersions)},${apply ? "true" : "false"}) as result;
commit;`;
}

export async function runStagingRecipeHistory({
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
  await verifyCheckout({ commitSha, cwd });
  await verifyCertification({
    commitSha,
    certificationMode: "github",
    environment,
    cwd,
  });
  const snapshot = await extractSnapshot({
    accessToken: authority.targetAccessToken,
    snapshotId: `ops-v1-history-${environment.GITHUB_RUN_ID ?? Date.now()}-${environment.GITHUB_RUN_ATTEMPT ?? "1"}`,
    extractorVersion: commitSha,
  });
  const contentChecksum = recipeHistoryContentChecksum(snapshot);
  if (
    apply &&
    (!/^[a-f0-9]{64}$/.test(reviewedContentChecksum ?? "") ||
      reviewedContentChecksum !== contentChecksum)
  )
    throw Error("REVIEWED_CONTENT_MISMATCH");
  const target = {
    projectRef: STAGING,
    supabaseUrl: authority.targetSupabaseUrl,
  };
  const execute =
    executeTarget ??
    ((t, sql) => executeAtlasStagingPostgres(t, sql, { environment, cwd }));
  await verifyCheckout({ commitSha, cwd });
  const result = parseStagingMasterResult(
    await execute(
      target,
      buildStagingRecipeHistorySql(snapshot, {
        targetProjectRef: target.projectRef,
        apply,
        migrationVersions,
      }),
    ),
  );
  if (
    !result.preserved ||
    result.records !== snapshot.records.length ||
    ![apply ? "IMPORTED" : "PREVIEW", ...(apply ? ["REPLAYED"] : [])].includes(
      result.status,
    )
  )
    throw Error("HISTORY_RECONCILIATION_FAILED");
  return {
    ...result,
    content_checksum: contentChecksum,
    snapshot_checksum: snapshot.snapshot_checksum,
    snapshot_id: snapshot.snapshot_id,
    source_counts: snapshot.source_counts,
    source_inactive: snapshot.records.filter((r) => !r.source_active).length,
    importing_actor: ACTOR,
  };
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
    const result = await runStagingRecipeHistory({
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
