// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  globalReplacementContentChecksum,
  buildStagingGlobalReplacementSql,
  runStagingGlobalReplacements,
} from "./adopt-atlas-staging-global-replacements.mjs";

const dates = [
  "2025-12-15",
  "2026-03-03",
  "2026-04-03",
  "2026-10-09",
  "2026-10-09",
];
const ids = ["7", "11", "12", "13", "14"];
const edges = [
  ["1043", "1039"],
  ["1029", "1067"],
  ["836", "904"],
  ["1042", "1041"],
  ["1040", "1208"],
];
const target = "rnzxmxiiqgtdevzregff";
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
function fixture() {
  const snapshot = {
    contract_version: "OPS-V1-RECIPE-HISTORY.v1",
    source_system: "OPS_V1_RECIPE_HISTORY",
    source_project_ref: "qnthofvccilhnefdcxnz",
    snapshot_id: "test",
    exported_at: "2026-11-09T00:00:00Z",
    source_counts: { ingredient_change_orders: 5 },
    records: ids.map((id, i) => ({
      source_table: "ingredient_change_orders",
      legacy_id: id,
      scope_kind: "SYSTEM_INGREDIENT",
      action: "REPLACE",
      source_active: true,
      effective_from: dates[i],
      source_record: {
        id,
        old_ingredient_id: edges[i][0],
        new_ingredient_id: edges[i][1],
        is_active: true,
        effective_date: dates[i],
      },
    })),
  };
  return {
    ...snapshot,
    snapshot_checksum: checksumOpsV1MasterSnapshot(snapshot),
  };
}
describe("four faithful global replacement adoption", () => {
  it("pins exact actual orders and preserves original rows and dates in content", () => {
    const snapshot = fixture();
    expect(globalReplacementContentChecksum(snapshot)).toMatch(
      /^[a-f0-9]{64}$/,
    );
    const changed = fixture();
    changed.records[0].source_record.note = "changed";
    changed.snapshot_checksum = checksumOpsV1MasterSnapshot(changed);
    expect(globalReplacementContentChecksum(changed)).not.toBe(
      globalReplacementContentChecksum(snapshot),
    );
    const fresh = {
      ...snapshot,
      snapshot_id: "fresh",
      exported_at: "2026-11-09T01:00:00Z",
    };
    fresh.snapshot_checksum = checksumOpsV1MasterSnapshot(fresh);
    expect(globalReplacementContentChecksum(fresh)).toBe(
      globalReplacementContentChecksum(snapshot),
    );
  });
  it.each(["missing", "extra", "duplicate", "inactive", "edge", "date"])(
    "blocks %s source drift",
    (kind) => {
      const s = fixture();
      if (kind === "missing") s.records.pop();
      if (kind === "extra")
        s.records.push({ ...s.records[0], legacy_id: "99" });
      if (kind === "duplicate") s.records.push(s.records[0]);
      if (kind === "inactive") s.records[0].source_active = false;
      if (kind === "edge")
        s.records[0].source_record.new_ingredient_id = "1041";
      if (kind === "date") s.records[0].effective_from = "2026-11-08";
      s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
      expect(() => globalReplacementContentChecksum(s)).toThrow(
        "GLOBAL_SOURCE_DRIFT",
      );
    },
  );
  it("wraps the actual importer in rollback preview and rejects other targets", () => {
    const options = {
      targetProjectRef: "rnzxmxiiqgtdevzregff",
      migrationVersions: ["20261105090000"],
    };
    expect(() =>
      buildStagingGlobalReplacementSql(fixture(), {
        ...options,
        targetProjectRef: "qnthofvccilhnefdcxnz",
      }),
    ).toThrow("EXACT_STAGING_TARGET_REQUIRED");
    const sql = buildStagingGlobalReplacementSql(fixture(), options);
    expect(sql).toContain("atlas_legacy.import_recipe_adjustment_snapshot");
    expect(sql).toContain("PREVIEW_ROLLBACK");
    expect(sql).toContain("NATIVE_INTERACTION_BLOCKED");
    expect(sql).toContain("TARGET_OR_SOURCE_DRIFT");
    expect(sql).not.toContain("create or replace function atlas_");
  });
  it("keeps the exact-main gate before setup or protected secrets", () => {
    const workflow = readFileSync(
      ".github/workflows/atlas-staging-global-replacements.yml",
      "utf8",
    );
    const gate = workflow.indexOf("- name: Verify exact current main");
    expect(gate).toBeGreaterThan(workflow.indexOf("actions/checkout@v4"));
    expect(gate).toBeLessThan(workflow.indexOf("pnpm/action-setup"));
    expect(workflow.slice(0, gate)).not.toContain("secrets.");
    expect(workflow).toContain(
      'test "$(git rev-parse origin/main)" = "$REQUESTED_SHA"',
    );
    expect(workflow).toContain('test -z "$(git status --porcelain)"');
    expect(workflow).toContain(
      'test "$CONFIRMED_TARGET" = "$ATLAS_STAGING_PROJECT_REF"',
    );
    expect(workflow).toContain("cancel-in-progress: false");
    expect(workflow).toContain(
      "node scripts/adopt-atlas-staging-global-replacements.mjs",
    );
    const certification = workflow.indexOf(
      "- name: Verify certified exact head",
    );
    expect(certification).toBeGreaterThan(
      workflow.indexOf("actions/setup-node@v4"),
    );
    expect(certification).toBeLessThan(
      workflow.indexOf("pnpm install --frozen-lockfile"),
    );
    expect(certification).toBeLessThan(
      workflow.indexOf("- name: Prepare verified exact Staging transport"),
    );
    const certificationStep = workflow.slice(
      certification,
      workflow.indexOf("      - run: pnpm install", certification),
    );
    expect(certificationStep).toContain("await verifyExactHeadCertification");
    expect(certificationStep).toContain('certificationMode: "github"');
    expect(certificationStep).not.toContain("ATLAS_STAGING_");
  });
  it("requires exact main and full certification, including a second checkout check after extraction", async () => {
    const executeTarget = vi.fn();
    const base = {
      commitSha: "a".repeat(40),
      environment,
      executeTarget,
      extractSnapshot: async () => fixture(),
    };
    await expect(
      runStagingGlobalReplacements({
        ...base,
        verifyCheckout: async () => {
          throw Error("STALE_MAIN");
        },
      }),
    ).rejects.toThrow("STALE_MAIN");
    await expect(
      runStagingGlobalReplacements({
        ...base,
        verifyCheckout: vi.fn(),
        verifyCertification: async () => {
          throw Error("CI_FAILED");
        },
      }),
    ).rejects.toThrow("CI_FAILED");
    const verifyCheckout = vi
      .fn()
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(Error("STALE_AFTER_EXTRACT"));
    await expect(
      runStagingGlobalReplacements({
        ...base,
        verifyCheckout,
        verifyCertification: vi.fn(),
      }),
    ).rejects.toThrow("STALE_AFTER_EXTRACT");
    expect(executeTarget).not.toHaveBeenCalled();
  });
  it("requires protected values, reviewed plan and exact target before any apply", async () => {
    const executeTarget = vi.fn(),
      extractSnapshot = vi.fn(async () => fixture());
    const base = {
      environment,
      apply: true,
      targetConfirmation: target,
      executeTarget,
      extractSnapshot,
      verifyCheckout: vi.fn(),
      verifyCertification: vi.fn(),
    };
    await expect(runStagingGlobalReplacements(base)).rejects.toThrow(
      "REVIEWED_CONTENT_REQUIRED",
    );
    await expect(
      runStagingGlobalReplacements({
        ...base,
        reviewedContentChecksum: "a".repeat(64),
        targetConfirmation: "wrong",
      }),
    ).rejects.toThrow("target confirmation");
    await expect(
      runStagingGlobalReplacements({
        ...base,
        environment: { ...environment, ATLAS_STAGING_TEST_PASSWORD: "" },
      }),
    ).rejects.toThrow("protected values");
    expect(extractSnapshot).not.toHaveBeenCalled();
    expect(executeTarget).not.toHaveBeenCalled();
  });
  it("executes once and propagates uncertain transport outcomes without retry", async () => {
    const executeTarget = vi.fn(async () => {
      throw Error("OUTCOME_UNKNOWN");
    });
    await expect(
      runStagingGlobalReplacements({
        environment,
        verifyCheckout: vi.fn(),
        verifyCertification: vi.fn(),
        extractSnapshot: async () => fixture(),
        executeTarget,
        migrationVersions: ["20261105090000"],
      }),
    ).rejects.toThrow("OUTCOME_UNKNOWN");
    expect(executeTarget).toHaveBeenCalledTimes(1);
  });
  it.each([false, true])(
    "returns only bounded proof metadata (apply %s)",
    async (apply) => {
      const result = {
        status: apply ? "APPLIED" : "PREVIEW",
        preserved: true,
        roots: 4,
        revisions: 4,
        receipts: 1,
        replay_status: "REPLAYED",
        content_checksum: "f".repeat(64),
      };
      const executeTarget = vi.fn(async () => JSON.stringify([{ result }]));
      expect(
        await runStagingGlobalReplacements({
          environment,
          apply,
          targetConfirmation: apply ? target : undefined,
          reviewedContentChecksum: apply ? "f".repeat(64) : undefined,
          verifyCheckout: vi.fn(),
          verifyCertification: vi.fn(),
          extractSnapshot: async () => fixture(),
          executeTarget,
          migrationVersions: ["20261105090000"],
        }),
      ).toEqual(result);
      expect(executeTarget).toHaveBeenCalledTimes(1);
      expect(JSON.stringify(result)).not.toContain("private-");
    },
  );
});
