// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  buildStagingRecipeHistorySql,
  recipeHistoryContentChecksum,
  runStagingRecipeHistory,
} from "./import-atlas-staging-recipe-history.mjs";

const target = "rnzxmxiiqgtdevzregff";
const sha = "a".repeat(40);
const snapshot = () => {
  const value = {
    contract_version: "OPS-V1-RECIPE-HISTORY.v1",
    source_system: "OPS_V1_RECIPE_HISTORY",
    source_project_ref: "qnthofvccilhnefdcxnz",
    snapshot_id: "test-history",
    exported_at: "2026-11-05T00:00:00Z",
    extractor_version: sha,
    source_counts: { system_bom_change_orders: 1 },
    records: [
      { legacy_id: "1", note: "Original evidence", source_active: false },
    ],
  };
  return { ...value, snapshot_checksum: checksumOpsV1MasterSnapshot(value) };
};
const environment = {
  ATLAS_STAGING_PROJECT_REF: target,
  VITE_SUPABASE_URL: `https://${target}.supabase.co`,
  VITE_ATLAS_ENVIRONMENT: "staging",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_12345678901234567890",
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "private-token",
  ATLAS_STAGING_DB_PASSWORD: "private-db-password",
  ATLAS_STAGING_TEST_EMAIL: "operator@example.invalid",
  ATLAS_STAGING_TEST_PASSWORD: "private-test-password",
};

describe("guarded Staging recipe source history", () => {
  it("gates checkout before setup or secrets and rechecks after extraction", async () => {
    const workflow = readFileSync(
      ".github/workflows/atlas-staging-recipe-history.yml",
      "utf8",
    );
    const gate = workflow.indexOf("- name: Verify exact current main");
    expect(gate).toBeGreaterThan(workflow.indexOf("actions/checkout@v4"));
    expect(gate).toBeLessThan(workflow.indexOf("pnpm/action-setup"));
    expect(workflow.slice(0, gate)).not.toContain("secrets.");
    for (const step of workflow.split(/(?=      - (?:name:|uses:|run:))/)) {
      if (step.includes("secrets."))
        expect(step).toMatch(
          /- name: (Prepare verified exact Staging transport|Extract once, preview and optionally import the reviewed content)/,
        );
    }

    expect(workflow).toContain('test "$GITHUB_REF" = "refs/heads/main"');
    expect(workflow).toContain('[[ "$REQUESTED_SHA" =~ ^[0-9a-f]{40}$ ]]');
    expect(workflow).toContain(
      'test "$(git rev-parse HEAD)" = "$REQUESTED_SHA"',
    );
    expect(workflow).toContain(
      'test "$(git rev-parse origin/main)" = "$REQUESTED_SHA"',
    );
    expect(workflow).toContain('test -z "$(git status --porcelain)"');
    const executeTarget = vi.fn();
    const verifyCheckout = vi
      .fn()
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(Error("STALE_AFTER_EXTRACT"));
    await expect(
      runStagingRecipeHistory({
        commitSha: sha,
        environment,
        verifyCheckout,
        verifyCertification: vi.fn(),
        extractSnapshot: async () => snapshot(),
        executeTarget,
      }),
    ).rejects.toThrow("STALE_AFTER_EXTRACT");
    expect(executeTarget).not.toHaveBeenCalled();
  });

  it("binds source content while allowing a fresh technical extraction", () => {
    const a = snapshot();
    const b = {
      ...a,
      snapshot_id: "fresh",
      exported_at: "2026-11-05T01:00:00Z",
    };
    b.snapshot_checksum = checksumOpsV1MasterSnapshot(b);
    expect(recipeHistoryContentChecksum(a)).toBe(
      recipeHistoryContentChecksum(b),
    );
    b.records = [{ ...a.records[0], note: "Changed evidence" }];
    b.snapshot_checksum = checksumOpsV1MasterSnapshot(b);
    expect(recipeHistoryContentChecksum(a)).not.toBe(
      recipeHistoryContentChecksum(b),
    );
  });

  it("rejects tampering and the live source as a target", () => {
    expect(() =>
      recipeHistoryContentChecksum({ ...snapshot(), records: [] }),
    ).toThrow("SNAPSHOT_CHECKSUM");
    expect(() =>
      buildStagingRecipeHistorySql(snapshot(), {
        targetProjectRef: "qnthofvccilhnefdcxnz",
        migrationVersions: ["20261105032000"],
      }),
    ).toThrow("STAGING_TARGET");
  });

  it("preview is database read-only; apply is Actor-bound with preservation and replay", () => {
    const options = {
      targetProjectRef: target,
      migrationVersions: ["20261105032000"],
    };
    const preview = buildStagingRecipeHistorySql(snapshot(), options);
    expect(preview).toContain("begin read only;");
    expect(preview).toContain("MIGRATION_HISTORY_MISMATCH");
    expect(preview).toContain("NATIVE_OR_OPERATIONAL_FACTS_CHANGED");
    expect(preview).toContain("a217bdd5-2858-58c2-8964-45c465225a59");
    const apply = buildStagingRecipeHistorySql(snapshot(), {
      ...options,
      apply: true,
    });
    expect(apply).toContain("begin;");
    expect(apply).toContain("REPLAY_FAILED");
    expect(apply).not.toContain("create role");
    expect(apply).not.toContain("update atlas_admin");
  });

  it("runs only preview without explicit apply and emits no raw source", async () => {
    const executeTarget = vi.fn(async () =>
      JSON.stringify([
        { result: { status: "PREVIEW", records: 1, preserved: true } },
      ]),
    );
    const result = await runStagingRecipeHistory({
      commitSha: sha,
      environment,
      verifyCheckout: vi.fn(),
      verifyCertification: vi.fn(),
      extractSnapshot: async () => snapshot(),
      migrationVersions: ["20261105032000"],
      executeTarget,
    });
    expect(executeTarget).toHaveBeenCalledTimes(1);
    expect(result.content_checksum).toBe(
      recipeHistoryContentChecksum(snapshot()),
    );
    expect(result.status).toBe("PREVIEW");
    expect(JSON.stringify(result)).not.toContain("Original evidence");
    expect(JSON.stringify(result)).not.toContain("private-token");
  });

  it("rejects unreviewed content, credentials and target before any apply", async () => {
    const executeTarget = vi.fn();
    const base = {
      commitSha: sha,
      environment,
      apply: true,
      targetConfirmation: target,
      reviewedContentChecksum: "0".repeat(64),
      verifyCheckout: vi.fn(),
      verifyCertification: vi.fn(),
      extractSnapshot: async () => snapshot(),
      migrationVersions: ["20261105032000"],
      executeTarget,
    };
    await expect(runStagingRecipeHistory(base)).rejects.toThrow(
      "REVIEWED_CONTENT_MISMATCH",
    );
    await expect(
      runStagingRecipeHistory({
        ...base,
        environment: { ...environment, ATLAS_STAGING_TEST_PASSWORD: "" },
      }),
    ).rejects.toThrow("protected values");
    await expect(
      runStagingRecipeHistory({ ...base, targetConfirmation: "wrong" }),
    ).rejects.toThrow("target confirmation");
    expect(executeTarget).not.toHaveBeenCalled();
  });

  it("propagates exact-main and certification failures without target calls", async () => {
    const executeTarget = vi.fn();
    const base = {
      commitSha: sha,
      environment,
      executeTarget,
      extractSnapshot: async () => snapshot(),
    };
    await expect(
      runStagingRecipeHistory({
        ...base,
        verifyCheckout: () => {
          throw Error("STALE_MAIN");
        },
      }),
    ).rejects.toThrow("STALE_MAIN");
    await expect(
      runStagingRecipeHistory({
        ...base,
        verifyCheckout: vi.fn(),
        verifyCertification: () => {
          throw Error("CI_FAILED");
        },
      }),
    ).rejects.toThrow("CI_FAILED");
    expect(executeTarget).not.toHaveBeenCalled();
  });
});
