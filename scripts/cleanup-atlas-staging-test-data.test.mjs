// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  buildStagingTestCleanupSql,
  runStagingTestCleanup,
  cleanupCodeHashes,
  sha256,
  CLEANUP_RECOVERY_SHA256,
  CLEANUP_SCHEMA_SHA256,
  CLEANUP_RESTORE_GUARDS_SHA256,
} from "./cleanup-atlas-staging-test-data.mjs";
import { readCleanupRecovery } from "./cleanup-atlas-staging-test-data.mjs";

describe("one-off Staging test cleanup", () => {
  const commitSha = "a".repeat(40);
  const proof = () => ({
    status: "RESTORED_EXACTLY",
    commit_sha: commitSha,
    recovery_manifest_sha256: CLEANUP_RECOVERY_SHA256,
    atlas_schema_checksum: CLEANUP_SCHEMA_SHA256,
    deleted_rows: 27431,
    restored_rows: 27431,
    purge_constraints_checked_before_restore: true,
    all_foreign_keys_validated: true,
    in_place_catalog_and_all_rows_equal: true,
    external_reconstruction_catalog_and_all_rows_equal: true,
    restore_guards_sha256: CLEANUP_RESTORE_GUARDS_SHA256,
    source_hashes: cleanupCodeHashes(),
  });
  it("refuses other targets and unreviewed destructive requests", () => {
    expect(() =>
      buildStagingTestCleanupSql({ targetProjectRef: "production" }),
    ).toThrow("EXACT_STAGING_TARGET_REQUIRED");
    expect(() =>
      buildStagingTestCleanupSql({
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply: true,
      }),
    ).toThrow("REVIEWED_CONTENT_REQUIRED");
  });
  it("certifies before any database access and never retries unknown outcomes", async () => {
    const executeTarget = vi.fn();
    await expect(
      runStagingTestCleanup({
        verifyCheckout: vi.fn(),
        verifyCertification: async () => {
          throw Error("UNCERTIFIED");
        },
        executeTarget,
        environment: {},
      }),
    ).rejects.toThrow();
    expect(executeTarget).not.toHaveBeenCalled();
  });
  it("stops after one unknown database outcome without retrying", async () => {
    const executeTarget = vi.fn().mockRejectedValue(Error("UNKNOWN_OUTCOME"));
    const target = "rnzxmxiiqgtdevzregff";
    await expect(
      runStagingTestCleanup({
        commitSha,
        verifyCheckout: vi.fn(),
        verifyCertification: vi.fn(),
        executeTarget,
        environment: {
          ATLAS_STAGING_PROJECT_REF: target,
          VITE_SUPABASE_URL: `https://${target}.supabase.co`,
          VITE_ATLAS_ENVIRONMENT: "staging",
          VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_12345678901234567890",
          ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "private-token",
          ATLAS_STAGING_DB_PASSWORD: "private-db-password",
          ATLAS_STAGING_TEST_EMAIL: "operator@example.invalid",
          ATLAS_STAGING_TEST_PASSWORD: "private-test-password",
        },
      }),
    ).rejects.toThrow("UNKNOWN_OUTCOME");
    expect(executeTarget).toHaveBeenCalledTimes(1);
  });
  it.each([
    "purge_constraints_checked_before_restore",
    "all_foreign_keys_validated",
    "in_place_catalog_and_all_rows_equal",
    "external_reconstruction_catalog_and_all_rows_equal",
    "restore_guards_sha256",
    "source_hashes",
  ])("rejects a rehashed proof with invalid final %s", (field) => {
    const receipt = proof();
    receipt[field] = field.endsWith("sha256")
      ? "0".repeat(64)
      : field === "source_hashes"
        ? {}
        : false;
    expect(() =>
      buildStagingTestCleanupSql({
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply: true,
        reviewedContentChecksum: "a".repeat(64),
        migrationVersions: ["20261105090000"],
        commitSha,
        recoveryProof: receipt,
        reviewedRecoveryProofChecksum: sha256(JSON.stringify(receipt)),
      }),
    ).toThrow("EXACT_SCHEMA_RECOVERY_PROOF_REQUIRED");
  });
  it("accepts only the completed exact-source receipt and keeps provisional use local", () => {
    const receipt = proof();
    const sql = buildStagingTestCleanupSql({
      targetProjectRef: "rnzxmxiiqgtdevzregff",
      apply: true,
      reviewedContentChecksum: "a".repeat(64),
      migrationVersions: ["20261105090000"],
      commitSha,
      recoveryProof: receipt,
      reviewedRecoveryProofChecksum: sha256(JSON.stringify(receipt)),
    });
    expect(sql).toContain("inet_server_addr() IS NULL");
    receipt.status = "LOCAL_REHEARSAL_PROVISIONAL";
    expect(() =>
      buildStagingTestCleanupSql({
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply: true,
        reviewedContentChecksum: "a".repeat(64),
        migrationVersions: ["20261105090000"],
        commitSha,
        recoveryProof: receipt,
        reviewedRecoveryProofChecksum: sha256(JSON.stringify(receipt)),
      }),
    ).toThrow("EXACT_SCHEMA_RECOVERY_PROOF_REQUIRED");
  });
  it("keeps security enforcement and rollback rehearsal in the generated SQL", () => {
    const sql = buildStagingTestCleanupSql({
      targetProjectRef: "rnzxmxiiqgtdevzregff",
      migrationVersions: ["20261105090000"],
    });
    expect(sql).toContain("run_staging_test_cleanup");
    expect(sql).not.toMatch(
      /session_replication_role|disable trigger (all|user)|truncate\s/i,
    );
    expect(sql).toContain("SET CONSTRAINTS ALL IMMEDIATE");
    expect(sql).toContain("ACCESS EXCLUSIVE");
    expect(sql).toContain(
      "IF item.nspname='auth' AND item.relname='schema_migrations' THEN",
    );
    expect(sql).toContain(
      "LOCK TABLE auth.schema_migrations IN ACCESS SHARE MODE",
    );
    expect(sql).toContain("DELETE_RETURNING_MEMBERSHIP_MISMATCH");
    expect(sql).toContain("OUTSIDE_MANIFEST_FACTS_CHANGED");
    expect(sql).toContain("MAPPED_CANONICAL_COMPOSITION_CHANGED");
    expect(sql.indexOf("SET CONSTRAINTS ALL IMMEDIATE")).toBeLessThan(
      sql.indexOf("IF deleted_count<>27431"),
    );
    expect(sql).not.toMatch(
      /disable\s+(?:row level security|rule)|drop\s+(?:constraint|trigger)|alter\s+role/i,
    );
  });
  it("requires the independently reviewed exact-head recovery proof before Apply", () => {
    expect(() =>
      buildStagingTestCleanupSql({
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply: true,
        reviewedContentChecksum: "a".repeat(64),
        migrationVersions: ["20261105090000"],
        recoveryProof: { status: "RESTORED_EXACTLY" },
      }),
    ).toThrow("EXACT_SCHEMA_RECOVERY_PROOF_REQUIRED");
    expect(() =>
      buildStagingTestCleanupSql({
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        migrationVersions: ["20261105090000", "20261105090000"],
      }),
    ).toThrow("MIGRATION_VERSIONS_INVALID");
  });
  it("rejects altered external manifests before reading recovery rows", () => {
    const directory = mkdtempSync(join(tmpdir(), "cleanup-manifest-test-"));
    try {
      writeFileSync(
        join(directory, "staging-cleanup-recovery-manifest.private.json"),
        "[]",
      );
      expect(() => readCleanupRecovery(directory)).toThrow(
        "RECOVERY_MANIFEST_MISMATCH",
      );
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
  it("registers one additional full-integration command and guarded private workflow", async () => {
    const workflow = readFileSync(
      ".github/workflows/atlas-staging-test-cleanup.yml",
      "utf8",
    );
    expect(workflow).toContain("cancel-in-progress: false");
    expect(
      workflow.indexOf("Verify Frontend and Full Integration certificates"),
    ).toBeLessThan(
      workflow.indexOf("Prepare verified exact Staging transport"),
    );
    expect(workflow).not.toContain("recovery_artifact_id");
    expect(workflow).not.toContain("--recovery-directory");
    expect(workflow).toContain("reviewed_recovery_proof_checksum");
    expect(workflow).not.toContain("continue-on-error");
  });
});
