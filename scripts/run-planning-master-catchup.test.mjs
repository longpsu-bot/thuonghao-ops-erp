// @vitest-environment node
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  readFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runPlanningMasterCatchup } from "./run-planning-master-catchup.mjs";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";

const staging = "rnzxmxiiqgtdevzregff";
const commitSha = "a".repeat(40);
const planChecksum = "b".repeat(64);
const actorId = "00000000-0000-4000-8000-000000000001";
const roots = [];
afterEach(() => {
  for (const root of roots.splice(0))
    rmSync(root, { recursive: true, force: true });
});
function fixture() {
  const cwd = mkdtempSync(join(tmpdir(), "atlas-planning-catchup-test-"));
  roots.push(cwd);
  mkdirSync(join(cwd, "supabase", "migrations"), { recursive: true });
  for (const name of ["20260101000000_first.sql", "20260102000000_second.sql"])
    writeFileSync(join(cwd, "supabase", "migrations", name), "-- fixture");
  const records = Object.fromEntries(
    [
      "customers",
      "delivery_locations",
      "dish_types",
      "dishes",
      "ingredient_order_groups",
      "ingredient_types",
      "ingredients",
      "recipe_lines",
      "recipes",
      "school_types",
      "schools",
      "supplier_eligibilities",
      "suppliers",
      "units",
    ].map((k) => [k, []]),
  );
  const source = {
    contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
    source_system: "OPS_V1",
    source_project_ref: "qnthofvccilhnefdcxnz",
    snapshot_id: "runner-test",
    exported_at: "2026-10-11T00:00:00Z",
    records,
    source_counts: {},
    source_diagnostics: [],
    source_access: {
      role_name: "supabase_read_only_user",
      has_required_select: true,
      has_non_select_privilege: false,
      bypass_rls: true,
      superuser: false,
      create_role: false,
      create_db: false,
    },
  };
  const snapshot = {
    ...source,
    snapshot_checksum: checksumOpsV1MasterSnapshot(source),
  };
  const snapshotFile = join(cwd, "snapshot.json");
  const persist = () => writeFileSync(snapshotFile, JSON.stringify(snapshot));
  persist();
  const response = (result) => [{ result }];
  const executeTarget = vi
    .fn()
    .mockResolvedValueOnce(response({ migrations: ["20260101000000"] }))
    .mockResolvedValueOnce(
      response({
        success: true,
        status: "PREVIEW",
        snapshot_checksum: snapshot.snapshot_checksum,
        plan_checksum: planChecksum,
      }),
    );
  const options = {
    commitSha,
    cwd,
    environment: {
      ATLAS_STAGING_PROJECT_REF: staging,
      VITE_SUPABASE_URL: `https://${staging}.supabase.co`,
      ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "fixture-only-token",
    },
    verifyPreview: vi.fn(),
    verifyApply: vi.fn(),
    extractSnapshot: vi.fn().mockResolvedValue(snapshot),
    executeTarget,
  };
  return {
    options,
    snapshot,
    snapshotFile,
    persist,
    response,
    apply: {
      ...options,
      apply: true,
      targetConfirmation: staging,
      snapshotFile,
      planChecksum,
      actorId,
    },
  };
}
describe("Planning catch-up runner safety", () => {
  it("retains a private immutable snapshot only when explicitly requested for preview", async () => {
    const f = fixture();
    const snapshotOutput = join(
      f.options.cwd,
      "reviewed-private-snapshot.json",
    );
    await runPlanningMasterCatchup({ ...f.options, snapshotOutput });
    expect(JSON.parse(readFileSync(snapshotOutput, "utf8"))).toEqual(
      f.snapshot,
    );
    await expect(
      runPlanningMasterCatchup({ ...f.options, snapshotOutput }),
    ).rejects.toThrow(/EEXIST/);
    expect(f.options.executeTarget).toHaveBeenCalledTimes(2);
  });
  it("rejects apply until the complete repository migration sequence is installed", async () => {
    const f = fixture();
    await expect(runPlanningMasterCatchup(f.apply)).rejects.toThrow(
      "STAGING_FULL_MIGRATION_PARITY_REQUIRED",
    );
    expect(f.options.executeTarget).toHaveBeenCalledTimes(1);
    expect(f.options.extractSnapshot).not.toHaveBeenCalled();
  });
  it("previews a fresh read-only snapshot without applying or replaying", async () => {
    const f = fixture();
    const result = await runPlanningMasterCatchup(f.options);
    expect(f.options.verifyPreview).toHaveBeenCalledWith(
      commitSha,
      f.options.cwd,
    );
    expect(f.options.verifyApply).not.toHaveBeenCalled();
    expect(f.options.extractSnapshot).toHaveBeenCalledTimes(1);
    expect(f.options.executeTarget).toHaveBeenCalledTimes(2);
    const [target, sql] = f.options.executeTarget.mock.calls[1];
    expect(target.projectRef).toBe(staging);
    expect(sql).toMatch(/::jsonb,false,null,null\) as result;/);
    expect(result).toMatchObject({
      success: true,
      status: "PREVIEW",
      migration_count: 1,
      migration_tip: "20260101000000",
      source: { snapshot_checksum: f.snapshot.snapshot_checksum },
    });
  });
  it.each(["snapshotFile", "planChecksum", "actorId"])(
    "rejects apply without reviewed %s before target execution",
    async (field) => {
      const f = fixture();
      delete f.apply[field];
      await expect(runPlanningMasterCatchup(f.apply)).rejects.toThrow(
        "REVIEWED_IMMUTABLE_SNAPSHOT_PLAN_AND_ACTOR_REQUIRED",
      );
      expect(f.options.executeTarget).not.toHaveBeenCalled();
      expect(f.options.extractSnapshot).not.toHaveBeenCalled();
    },
  );
  it.each([{ planChecksum: "not-a-checksum" }, { actorId: "not-an-actor" }])(
    "rejects malformed checksum or Actor before catch-up execution: %o",
    async (invalid) => {
      const f = fixture();
      await expect(
        runPlanningMasterCatchup({ ...f.apply, ...invalid }),
      ).rejects.toThrow("REVIEWED_PLAN_AND_ACTOR_REQUIRED");
      expect(
        f.options.executeTarget.mock.calls.every(
          ([, sql]) => !sql.includes("run_planning_master_catchup"),
        ),
      ).toBe(true);
    },
  );
  it.each([
    { migrations: [] },
    { migrations: ["20260102000000"] },
    { migrations: ["20260101000000", "20260103000000"] },
  ])("rejects a mismatched migration prefix %j", async ({ migrations }) => {
    const f = fixture();
    f.options.executeTarget
      .mockReset()
      .mockResolvedValue(f.response({ migrations }));
    await expect(runPlanningMasterCatchup(f.options)).rejects.toThrow(
      "STAGING_MIGRATION_PREFIX_MISMATCH",
    );
    expect(f.options.executeTarget).toHaveBeenCalledTimes(1);
  });
  it("uses the immutable reviewed snapshot and proves exact replay after apply", async () => {
    const f = fixture();
    f.options.executeTarget
      .mockReset()
      .mockResolvedValueOnce(
        f.response({ migrations: ["20260101000000", "20260102000000"] }),
      )
      .mockResolvedValueOnce(
        f.response({
          success: true,
          status: "APPLIED",
          snapshot_checksum: f.snapshot.snapshot_checksum,
          plan_checksum: planChecksum,
        }),
      )
      .mockResolvedValueOnce(
        f.response({
          success: true,
          status: "REPLAYED",
          plan_checksum: planChecksum,
        }),
      );
    const result = await runPlanningMasterCatchup(f.apply);
    expect(f.options.verifyApply).toHaveBeenCalledWith({
      commitSha,
      cwd: f.options.cwd,
    });
    expect(f.options.verifyPreview).not.toHaveBeenCalled();
    expect(f.options.extractSnapshot).not.toHaveBeenCalled();
    expect(f.options.executeTarget).toHaveBeenCalledTimes(3);
    expect(f.options.executeTarget.mock.calls[1][1]).toBe(
      f.options.executeTarget.mock.calls[2][1],
    );
    expect(result.replay_status).toBe("REPLAYED");
  });
  it("rejects replay checksum drift", async () => {
    const f = fixture();
    f.options.executeTarget
      .mockReset()
      .mockResolvedValueOnce(
        f.response({ migrations: ["20260101000000", "20260102000000"] }),
      )
      .mockResolvedValueOnce(
        f.response({
          success: true,
          status: "APPLIED",
          plan_checksum: planChecksum,
        }),
      )
      .mockResolvedValueOnce(
        f.response({
          success: true,
          status: "REPLAYED",
          plan_checksum: "c".repeat(64),
        }),
      );
    await expect(runPlanningMasterCatchup(f.apply)).rejects.toThrow(
      "CATCHUP_REPLAY_FAILED",
    );
  });
  it("rejects source drift before any target execution", async () => {
    const f = fixture();
    f.snapshot.records.schools.push({ legacy_id: "33", school_name: "drift" });
    f.persist();
    await expect(runPlanningMasterCatchup(f.apply)).rejects.toThrow(
      "SNAPSHOT_CHECKSUM_MISMATCH",
    );
    expect(f.options.executeTarget).not.toHaveBeenCalled();
  });
  it("requires read-only source evidence even for a checksum-valid snapshot", async () => {
    const f = fixture();
    f.snapshot.source_access.has_non_select_privilege = true;
    f.snapshot.snapshot_checksum = checksumOpsV1MasterSnapshot(f.snapshot);
    f.persist();
    await expect(runPlanningMasterCatchup(f.apply)).rejects.toThrow(
      "SOURCE_NOT_PROVEN_READ_ONLY",
    );
    expect(f.options.executeTarget).not.toHaveBeenCalled();
  });
});
