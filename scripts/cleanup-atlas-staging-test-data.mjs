import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import { migrationVersionsFromFilenames } from "./verify-atlas-staging.mjs";
import {
  redactAtlasStagingDiagnostic,
  validateAtlasStagingProtectedValues,
  verifyExactHeadCertification,
} from "./atlas-staging-contract.mjs";

export const CLEANUP_TARGET = "rnzxmxiiqgtdevzregff";
export const CLEANUP_SCHEMA_SHA256 =
  "08fc31ff1cd527b348767e61ab2fcde2783d1e6b8a419ddd166a23d407100708";
export const CLEANUP_RESTORE_GUARDS_SHA256 =
  "1a8e1eae8563655ac81db71170e67a346931d56881954aaf29eb8c53328fde18";
export const CLEANUP_RECOVERY_SHA256 =
  "6a11d91dfb3f7715bbc120f3f1deabd0b2fe9a125f327b727685d50cb2f8b29a";
export const sha256 = (value) =>
  createHash("sha256").update(value).digest("hex");
const encode = (value) =>
  `convert_from(decode('${Buffer.from(JSON.stringify(value)).toString("base64")}','base64'),'UTF8')::jsonb`;
export function cleanupCodeHashes() {
  return Object.fromEntries(
    [
      "../supabase/packages/atlas-staging-test-cleanup.sql",
      "./cleanup-atlas-staging-test-data.mjs",
      "./rehearse-local-staging-test-cleanup.mjs",
    ].map((path) => [
      path,
      sha256(readFileSync(new URL(path, import.meta.url))),
    ]),
  );
}

export function readCleanupRecovery(directory) {
  const manifestBytes = readFileSync(
    resolve(directory, "staging-cleanup-recovery-manifest.private.json"),
  );
  if (sha256(manifestBytes) !== CLEANUP_RECOVERY_SHA256)
    throw Error("RECOVERY_MANIFEST_MISMATCH");
  const manifest = JSON.parse(manifestBytes);
  if (
    manifest.length !== 67 ||
    new Set(manifest.map((e) => e.file)).size !== 67
  )
    throw Error("RECOVERY_MANIFEST_INVALID");
  const recovery = manifest.map((entry) => {
    if (!/^atlas_[a-z_]+__[a-z_]+\.json$/.test(entry.file))
      throw Error("RECOVERY_PATH_INVALID");
    const bytes = readFileSync(
      resolve(directory, "staging-operational-recovery", entry.file),
    );
    if (
      bytes.length !== entry.bytes ||
      sha256(bytes) !== entry.sha256.toLowerCase()
    )
      throw Error("RECOVERY_FILE_MISMATCH");
    const table = JSON.parse(bytes);
    if (
      table.project_id !== CLEANUP_TARGET ||
      table.table.replace(".", "__") + ".json" !== entry.file ||
      !Array.isArray(table.row_texts) ||
      table.row_texts.length !== table.row_count ||
      sha256(table.row_texts.join("\n")) !== table.sha256
    )
      throw Error("RECOVERY_CONTENT_MISMATCH");
    return table;
  });
  if (recovery.reduce((sum, t) => sum + t.row_count, 0) !== 27431)
    throw Error("RECOVERY_ROW_COUNT_MISMATCH");
  return recovery;
}

export function buildStagingTestCleanupSql({
  targetProjectRef,
  apply = false,
  reviewedContentChecksum,
  migrationVersions,
  recovery = null,
  recoveryProof = null,
  reviewedRecoveryProofChecksum,
  commitSha = null,
} = {}) {
  if (targetProjectRef !== CLEANUP_TARGET)
    throw Error("EXACT_STAGING_TARGET_REQUIRED");
  if (apply && !/^[a-f0-9]{64}$/.test(reviewedContentChecksum ?? ""))
    throw Error("REVIEWED_CONTENT_REQUIRED");
  if (
    !Array.isArray(migrationVersions) ||
    !migrationVersions.length ||
    migrationVersions.some((v) => !/^\d{14}$/.test(v)) ||
    new Set(migrationVersions).size !== migrationVersions.length
  )
    throw Error("MIGRATION_VERSIONS_INVALID");
  if (
    apply &&
    (!/^[a-f0-9]{64}$/.test(reviewedRecoveryProofChecksum ?? "") ||
      sha256(JSON.stringify(recoveryProof)) !== reviewedRecoveryProofChecksum ||
      recoveryProof?.status !== "RESTORED_EXACTLY" ||
      recoveryProof.recovery_manifest_sha256 !== CLEANUP_RECOVERY_SHA256 ||
      recoveryProof.deleted_rows !== 27431 ||
      recoveryProof.restored_rows !== 27431 ||
      recoveryProof.commit_sha !== commitSha ||
      recoveryProof.atlas_schema_checksum !== CLEANUP_SCHEMA_SHA256 ||
      recoveryProof.purge_constraints_checked_before_restore !== true ||
      recoveryProof.restore_guards_sha256 !== CLEANUP_RESTORE_GUARDS_SHA256 ||
      recoveryProof.all_foreign_keys_validated !== true ||
      recoveryProof.in_place_catalog_and_all_rows_equal !== true ||
      recoveryProof.external_reconstruction_catalog_and_all_rows_equal !==
        true ||
      JSON.stringify(recoveryProof.source_hashes) !==
        JSON.stringify(cleanupCodeHashes()))
  )
    throw Error("EXACT_SCHEMA_RECOVERY_PROOF_REQUIRED");
  return `${readFileSync(new URL("../supabase/packages/atlas-staging-test-cleanup.sql", import.meta.url), "utf8")}\nBEGIN;
SET LOCAL statement_timeout='15min'; SET LOCAL lock_timeout='15s'; SET LOCAL timezone='UTC';
SELECT pg_temp.run_staging_test_cleanup(${encode(recovery)},${encode(migrationVersions)},${apply},${encode(reviewedContentChecksum ?? null)},${encode(recoveryProof)},${encode(commitSha)},${encode(cleanupCodeHashes())}) AS result;
COMMIT;`;
}

export async function runStagingTestCleanup({
  commitSha,
  apply = false,
  reviewedContentChecksum,
  targetConfirmation,
  recoveryDirectory,
  recoveryProof,
  reviewedRecoveryProofChecksum,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  verifyCertification = verifyExactHeadCertification,
  executeTarget,
} = {}) {
  // Certification precedes credentials, private backups and any database access.
  await verifyCheckout({ commitSha, cwd });
  await verifyCertification({
    commitSha,
    certificationMode: "github",
    environment,
    cwd,
  });
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  validateAtlasStagingProtectedValues(environment);
  const recovery = recoveryDirectory
    ? readCleanupRecovery(recoveryDirectory)
    : null;
  const sql = buildStagingTestCleanupSql({
    targetProjectRef: CLEANUP_TARGET,
    apply,
    reviewedContentChecksum,
    recovery,
    recoveryProof,
    reviewedRecoveryProofChecksum,
    commitSha,
    migrationVersions: migrationVersionsFromFilenames(
      readdirSync(resolve(cwd, "supabase/migrations")),
    ),
  });
  await verifyCheckout({ commitSha, cwd });
  const execute =
    executeTarget ??
    ((target, statement) =>
      executeAtlasStagingPostgres(target, statement, { environment, cwd }));
  // Unknown transport outcomes stop here. A retry needs a fresh read and review.
  const result = parseStagingMasterResult(
    await execute(
      { projectRef: CLEANUP_TARGET, supabaseUrl: authority.targetSupabaseUrl },
      sql,
    ),
  );
  if (
    result.status !== (apply ? "APPLIED" : "PREVIEW") ||
    result.deleted_rows !== 27431 ||
    result.protected_facts_preserved !== true ||
    result.catalog_restored !== true ||
    (!apply && result.rolled_back !== true)
  )
    throw Error("CLEANUP_RECONCILIATION_FAILED");
  return result;
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const args = process.argv.slice(2),
      values = new Map();
    for (let i = 0; i < args.length; i++) {
      const key = args[i];
      if (
        values.has(key) ||
        ![
          "--commit-sha",
          "--apply",
          "--target-project-ref",
          "--reviewed-content-checksum",
          "--recovery-directory",
          "--recovery-proof",
          "--reviewed-recovery-proof-checksum",
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
    const result = await runStagingTestCleanup({
      commitSha: values.get("--commit-sha"),
      apply: values.has("--apply"),
      targetConfirmation: values.get("--target-project-ref"),
      reviewedContentChecksum: values.get("--reviewed-content-checksum"),
      reviewedRecoveryProofChecksum: values.get(
        "--reviewed-recovery-proof-checksum",
      ),
      recoveryDirectory: values.get("--recovery-directory"),
      recoveryProof: values.has("--recovery-proof")
        ? JSON.parse(readFileSync(values.get("--recovery-proof")))
        : null,
    });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(
      `${redactAtlasStagingDiagnostic(
        error.message,
        Object.entries(process.env)
          .filter(([k]) => /PASSWORD|TOKEN|SECRET/.test(k))
          .map(([, v]) => v),
      )}\n`,
    );
    process.exitCode = 1;
  }
}
