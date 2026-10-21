// @vitest-environment node
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  readFileSync,
  existsSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  planningCatchupFailureCode,
  runPlanningMasterCatchup,
  writePlanningCatchupReports,
} from "./run-planning-master-catchup.mjs";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";

const staging = "rnzxmxiiqgtdevzregff";
const commitSha = "a".repeat(40);
const planChecksum = "b".repeat(64);
const actorId = "00000000-0000-4000-8000-000000000001";
const roots = [];
it("retains safe transport SQLSTATE diagnostics and withholds raw failure prose", () => {
  expect(
    planningCatchupFailureCode(new Error("STAGING_POSTGRES_SQLSTATE_53300")),
  ).toBe("STAGING_POSTGRES_SQLSTATE_53300");
  expect(
    planningCatchupFailureCode(
      new Error("STAGING_POSTGRES_EXECUTION_TIMED_OUT"),
    ),
  ).toBe("STAGING_POSTGRES_EXECUTION_TIMED_OUT");
  for (const message of [
    "STAGING_POSTGRES_SQLSTATE_533000",
    "STAGING_POSTGRES_SQLSTATE_ABCDEF",
    "STAGING_POSTGRES_SQLSTATE_ABCD_EXTRA",
    "select private_source from facts",
    "password=synthetic-secret",
  ])
    expect(planningCatchupFailureCode(new Error(message))).toBe(
      "PLANNING_CATCHUP_FAILED",
    );
});
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
  it.each([false, true])(
    "writes an unmistakable detached TSV name for diagnostic mode %s",
    (diagnostic) => {
      const f = fixture();
      const result = {
        diagnostic_boundary: diagnostic,
        status: diagnostic ? "DIAGNOSTIC_PREVIEW" : "PREVIEW",
        report: [],
      };
      writePlanningCatchupReports(result, f.options.cwd);
      const name = diagnostic
        ? "planning-master-diagnostic-report.tsv"
        : "planning-master-report.tsv";
      const other = diagnostic
        ? "planning-master-report.tsv"
        : "planning-master-diagnostic-report.tsv";
      expect(existsSync(join(f.options.cwd, name))).toBe(true);
      expect(existsSync(join(f.options.cwd, other))).toBe(false);
      expect(
        readFileSync(join(f.options.cwd, name), "utf8").trim().split("\t"),
      ).toHaveLength(9);
      expect(
        JSON.parse(
          readFileSync(
            join(f.options.cwd, "planning-master-plan.json"),
            "utf8",
          ),
        ).status,
      ).toBe(result.status);
    },
  );
  it("rejects diagnostic apply before authorization, checkout, source or SQL", async () => {
    const f = fixture();
    await expect(
      runPlanningMasterCatchup({
        ...f.apply,
        diagnosticBoundary: true,
        environment: {},
      }),
    ).rejects.toThrow("DIAGNOSTIC_BOUNDARY_PREVIEW_ONLY");
    expect(f.options.verifyApply).not.toHaveBeenCalled();
    expect(f.options.extractSnapshot).not.toHaveBeenCalled();
    expect(f.options.executeTarget).not.toHaveBeenCalled();
  });
  it("bounds diagnostic preview to 60 seconds and labels its result separately", async () => {
    const f = fixture();
    const phases = [];
    const result = await runPlanningMasterCatchup({
      ...f.options,
      diagnosticBoundary: true,
      onPhase: (phase) => phases.push(phase),
    });
    const [migration, plan] = f.options.executeTarget.mock.calls;
    expect(migration[2].timeoutMs).toBe(45000);
    expect(plan[2].timeoutMs).toBe(60000);
    expect(plan[1]).toContain("set client_connection_check_interval='2s'");
    expect(plan[1]).toContain("set statement_timeout='15min'");
    expect(result).toMatchObject({
      diagnostic_boundary: true,
      execution_mode: "DIAGNOSTIC_PREVIEW",
      status: "DIAGNOSTIC_PREVIEW",
      backend_status: "PREVIEW",
    });
    expect(phases[0]).toBe("PLANNING_CATCHUP_DIAGNOSTIC_BOUNDARY_MODE");
    expect(f.options.executeTarget).toHaveBeenCalledTimes(2);
  });
  it("forwards sanitized transport phases before a plan execution timeout", async () => {
    const f = fixture();
    const phases = [];
    f.options.executeTarget
      .mockReset()
      .mockResolvedValueOnce(f.response({ migrations: ["20260101000000"] }))
      .mockImplementationOnce(async (_target, _sql, transportOptions) => {
        transportOptions.onPhase("CATCHUP_CLIENT_SCRIPT_BEGIN");
        transportOptions.onPhase("CATCHUP_SERVER_SOURCE_CHECKED");
        throw new Error("STAGING_POSTGRES_EXECUTION_TIMED_OUT");
      });
    await expect(
      runPlanningMasterCatchup({
        ...f.options,
        diagnosticBoundary: true,
        onPhase: (marker) => phases.push(marker),
      }),
    ).rejects.toThrow("STAGING_POSTGRES_EXECUTION_TIMED_OUT");
    expect(phases.slice(-3)).toEqual([
      "PLANNING_CATCHUP_PLAN_EXECUTION_START",
      "CATCHUP_CLIENT_SCRIPT_BEGIN",
      "CATCHUP_SERVER_SOURCE_CHECKED",
    ]);
    expect(phases).not.toContain("PLANNING_CATCHUP_PLAN_EXECUTION_DONE");
    expect(phases[0]).toBe("PLANNING_CATCHUP_DIAGNOSTIC_BOUNDARY_MODE");
    expect(f.options.executeTarget.mock.calls[1][2].timeoutMs).toBe(60000);
    expect(f.options.executeTarget).toHaveBeenCalledTimes(2);
  });
  it("emits fixed phase markers in order and bounds only migration preflight", async () => {
    const f = fixture();
    const phases = [];
    await runPlanningMasterCatchup({
      ...f.options,
      onPhase: (phase) => phases.push(phase),
    });
    expect(phases).toEqual([
      "PLANNING_CATCHUP_CHECKOUT_START",
      "PLANNING_CATCHUP_CHECKOUT_DONE",
      "PLANNING_CATCHUP_SOURCE_SNAPSHOT_START",
      "PLANNING_CATCHUP_SOURCE_SNAPSHOT_DONE",
      "PLANNING_CATCHUP_SOURCE_VALIDATION_START",
      "PLANNING_CATCHUP_SOURCE_VALIDATION_DONE",
      "PLANNING_CATCHUP_TARGET_MIGRATION_PREFLIGHT_START",
      "PLANNING_CATCHUP_TARGET_MIGRATION_PREFLIGHT_DONE",
      "PLANNING_CATCHUP_PLAN_BUILD_START",
      "PLANNING_CATCHUP_PLAN_BUILD_DONE",
      "PLANNING_CATCHUP_PLAN_EXECUTION_START",
      "PLANNING_CATCHUP_PLAN_EXECUTION_DONE",
    ]);
    expect(f.options.executeTarget).toHaveBeenCalledTimes(2);
    const [migration, plan] = f.options.executeTarget.mock.calls;
    expect(migration[2].timeoutMs).toBe(45000);
    expect(plan[2]).not.toHaveProperty("timeoutMs");
    expect(plan[1]).not.toContain("client_connection_check_interval");
    expect(plan[1]).toContain("set statement_timeout='15min'");
    expect(phases.join(" ")).not.toMatch(
      /fixture-only-token|select|runner-test|snapshot_checksum/,
    );
  });
  it("leaves the failed preflight phase visible without retrying or exposing error data", async () => {
    const f = fixture();
    const phases = [];
    f.options.executeTarget
      .mockReset()
      .mockRejectedValue(new Error("private SQL fixture-only-token"));
    await expect(
      runPlanningMasterCatchup({
        ...f.options,
        onPhase: (phase) => phases.push(phase),
      }),
    ).rejects.toThrow("private SQL fixture-only-token");
    expect(phases.at(-1)).toBe(
      "PLANNING_CATCHUP_TARGET_MIGRATION_PREFLIGHT_START",
    );
    expect(phases.join(" ")).not.toMatch(
      /private|fixture-only-token|PLAN_EXECUTION/,
    );
    expect(f.options.executeTarget).toHaveBeenCalledTimes(1);
  });
  it("reports exact source blockers without inventing target identities or applying", async () => {
    const f = fixture();
    f.options.executeTarget
      .mockReset()
      .mockResolvedValueOnce(f.response({ migrations: ["20260101000000"] }))
      .mockResolvedValueOnce(
        f.response({
          success: false,
          status: "BLOCKED",
          error_code: "SOURCE_DEPENDENCY_BLOCKED",
          issues: [
            {
              entity: "ingredients",
              legacy_id: "1215",
              code: "UNSUPPORTED_UNIT",
              field: "purchase_unit",
              detail: "Bao",
            },
          ],
        }),
      );
    const result = await runPlanningMasterCatchup(f.options);
    expect(result.report).toEqual([
      {
        SOURCE_SYSTEM: "OPS_V1",
        OBJECT_TYPE: "INGREDIENT",
        LEGACY_ID: "1215",
        SOURCE_NAME: "1215",
        CURRENT_ATLAS_ID: null,
        CURRENT_ATLAS_VALUE: null,
        PROPOSED_ATLAS_ID: null,
        ACTION: "BLOCKED",
        DEPENDENCY_REASON:
          "UNSUPPORTED_UNIT: purchase_unit=Bao; target plan withheld until source resolution",
      },
    ]);
    expect(f.options.executeTarget).toHaveBeenCalledTimes(2);
    expect(result.plan_checksum).toBeUndefined();
  });
  it("retains empty Recipe identity and source evidence in the immutable preview and report without rewriting composition", async () => {
    const f = fixture();
    const recipe = {
      legacy_id: "dish:2034:school-type:1",
      source_record_id: "3456",
      dish_legacy_id: "2034",
      school_type_legacy_id: "1",
      recipe_status: "ACTIVE",
      basis_portions: 100,
    };
    const diagnostic = {
      severity: "INFO",
      code: "SOURCE_RECIPE_EMPTY",
      entity: "recipes",
      legacy_id: recipe.legacy_id,
      field: "composition",
      detail: "3456",
    };
    f.snapshot.records.recipes.push(recipe);
    f.snapshot.source_diagnostics.push(diagnostic);
    f.snapshot.snapshot_checksum = checksumOpsV1MasterSnapshot(f.snapshot);
    const report = [
      {
        SOURCE_SYSTEM: "OPS_V1",
        OBJECT_TYPE: "RECIPE",
        LEGACY_ID: recipe.legacy_id,
        SOURCE_RECIPE_ID: "3456",
        ACTION: "CREATE",
        DEPENDENCY_REASON:
          "SOURCE_RECIPE_EMPTY: source_recipe_id=3456; root only; RECIPE_NOT_READY; no released composition",
      },
    ];
    f.options.executeTarget
      .mockReset()
      .mockResolvedValueOnce(f.response({ migrations: ["20260101000000"] }))
      .mockResolvedValueOnce(
        f.response({
          success: true,
          status: "PREVIEW",
          snapshot_checksum: f.snapshot.snapshot_checksum,
          report,
        }),
      );
    const snapshotOutput = join(f.options.cwd, "empty-recipe-snapshot.json");
    const result = await runPlanningMasterCatchup({
      ...f.options,
      snapshotOutput,
    });
    expect(JSON.parse(readFileSync(snapshotOutput, "utf8"))).toEqual(
      f.snapshot,
    );
    expect(result.source.empty_recipe_evidence).toEqual([
      {
        legacy_id: "dish:2034:school-type:1",
        source_record_id: "3456",
        code: "SOURCE_RECIPE_EMPTY",
      },
    ]);
    expect(result.report).toEqual(report);
    const sql = f.options.executeTarget.mock.calls[1][1];
    const encoded = sql.match(/convert_from\(decode\('([^']+)','base64'\)/)[1];
    const payload = JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
    expect(payload.records.recipes).toEqual([recipe]);
    expect(payload.records.recipe_lines).toEqual([]);
    expect(sql).toMatch(/::jsonb,false,null,null,null\) as result;/);
    expect(f.options.executeTarget).toHaveBeenCalledTimes(2);
  });
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
    expect(sql).toMatch(/::jsonb,false,null,null,null\) as result;/);
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
    f.snapshot.records.dishes = [{ legacy_id: "9", dish_status: "ACTIVE" }];
    f.snapshot.snapshot_checksum = checksumOpsV1MasterSnapshot(f.snapshot);
    f.persist();
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
    const result = await runPlanningMasterCatchup({
      ...f.apply,
      dishLegacyIds: ["9"],
    });
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
    expect(f.options.executeTarget.mock.calls[1][1]).toContain(
      "'[\"9\"]'::jsonb",
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
