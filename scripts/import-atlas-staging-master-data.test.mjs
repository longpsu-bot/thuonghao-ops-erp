// @vitest-environment node
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  buildStagingMasterLoadSql,
  parseStagingMasterResult,
  runAtlasStagingMasterLoad,
  verifyStagingMasterVisibility,
} from "./import-atlas-staging-master-data.mjs";

const target = "rnzxmxiiqgtdevzregff";
const env = {
  ATLAS_STAGING_PROJECT_REF: target,
  VITE_SUPABASE_URL: `https://${target}.supabase.co`,
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-token",
};
const fixtureText = readFileSync(
  new URL(
    "../supabase/tests/master_data_rehearsal_import.sql",
    import.meta.url,
  ),
  "utf8",
);
const fixture = () =>
  JSON.parse(fixtureText.match(/\$json\$([\s\S]*?)\$json\$/)[1]);
const preview = {
  success: true,
  status: "PREVIEW",
  plan_checksum: "b".repeat(64),
  snapshot_checksum: fixture().snapshot_checksum,
  planned_counts: { CREATE: 2 },
  adoption: { mappings: 4 },
  issues: [],
  target_counts: { schools: 1 },
};

describe("guarded hosted master-data load", () => {
  it("requires a checksum-valid source snapshot and exact target before constructing SQL", () => {
    expect(() =>
      buildStagingMasterLoadSql(fixture(), {
        targetProjectRef: "qnthofvccilhnefdcxnz",
      }),
    ).toThrow(/STAGING_TARGET/);
    const corrupted = fixture();
    corrupted.records.schools[0].school_name = "tampered";
    expect(() =>
      buildStagingMasterLoadSql(corrupted, { targetProjectRef: target }),
    ).toThrow(/CHECKSUM/);
  });
  it("defaults to rolled-back preview and requires an exact plan for apply", () => {
    const sql = buildStagingMasterLoadSql(fixture(), {
      targetProjectRef: target,
    });
    expect(sql).toContain("pg_temp.run_staging_master_load");
    expect(sql).toContain(", false, null)");
    expect(sql).not.toContain("Trường mẫu đầy đủ");
    expect(() =>
      buildStagingMasterLoadSql(fixture(), {
        targetProjectRef: target,
        apply: true,
      }),
    ).toThrow(/PLAN/);
    expect(
      buildStagingMasterLoadSql(fixture(), {
        targetProjectRef: target,
        apply: true,
        planChecksum: "b".repeat(64),
      }),
    ).toContain(", true, '" + "b".repeat(64) + "')");
  });
  it("fails closed for malformed target responses", () => {
    for (const s of ["html", "[]", '[{"other":{}}]', '[{"result":null}]'])
      expect(() => parseStagingMasterResult(s)).toThrow(/RESPONSE/);
    expect(
      parseStagingMasterResult(JSON.stringify([{ result: preview }])),
    ).toEqual(preview);
  });
  it("never calls the source or target when target/apply authority is absent", async () => {
    let calls = 0;
    const denied = async () => {
      calls += 1;
      throw new Error("must not run");
    };
    await expect(
      runAtlasStagingMasterLoad({
        commitSha: "a".repeat(40),
        apply: true,
        environment: env,
        verifyCheckout: denied,
        extractSnapshot: denied,
        executeTarget: denied,
      }),
    ).rejects.toThrow(/target confirmation/i);
    await expect(
      runAtlasStagingMasterLoad({
        commitSha: "a".repeat(40),
        environment: {
          ...env,
          ATLAS_STAGING_PROJECT_REF: "qnthofvccilhnefdcxnz",
        },
        verifyCheckout: denied,
        extractSnapshot: denied,
        executeTarget: denied,
      }),
    ).rejects.toThrow(/live OPS/i);
    expect(calls).toBe(0);
  });
  it("runs source extraction once and never applies a rejected preview", async () => {
    let extracted = 0;
    const statements = [];
    const result = await runAtlasStagingMasterLoad({
      commitSha: "a".repeat(40),
      apply: true,
      targetConfirmation: target,
      environment: env,
      verifyCheckout: () => "a".repeat(40),
      extractSnapshot: async () => {
        extracted += 1;
        return fixture();
      },
      executeTarget: async (_target, sql) => {
        statements.push(sql);
        return JSON.stringify([
          { result: { ...preview, success: false, status: "REJECTED" } },
        ]);
      },
    });
    expect(result.status).toBe("REJECTED");
    expect(extracted).toBe(1);
    expect(statements).toHaveLength(1);
    expect(statements[0]).toContain(", false, null)");
  });
  it("applies only the validated snapshot/plan and requires a reconciled replay", async () => {
    const statements = [];
    const result = await runAtlasStagingMasterLoad({
      commitSha: "a".repeat(40),
      apply: true,
      targetConfirmation: target,
      environment: env,
      verifyCheckout: () => "a".repeat(40),
      extractSnapshot: async () => fixture(),
      executeTarget: async (_target, sql) => {
        statements.push(sql);
        return JSON.stringify([
          {
            result:
              statements.length === 1
                ? preview
                : {
                    ...preview,
                    status: statements.length === 2 ? "APPLIED" : "REPLAYED",
                    reconciled: true,
                    operational_data_unchanged: true,
                    target_counts: { schools: 1 },
                  },
          },
        ]);
      },
    });
    expect(result.status).toBe("STAGING_MASTER_DATA_LOADED");
    expect(result.replay_status).toBe("REPLAYED");
    expect(statements).toHaveLength(3);
    expect(statements[1]).toContain(", true, '" + preview.plan_checksum + "')");
    expect(result).not.toHaveProperty("records");
    expect(JSON.stringify(result)).not.toContain("synthetic-token");
  });
  it("does not certify a non-reconciled or failed application", async () => {
    let count = 0;
    await expect(
      runAtlasStagingMasterLoad({
        commitSha: "a".repeat(40),
        apply: true,
        targetConfirmation: target,
        environment: env,
        verifyCheckout: () => "a".repeat(40),
        extractSnapshot: async () => fixture(),
        executeTarget: async () =>
          JSON.stringify([
            {
              result:
                ++count === 1
                  ? preview
                  : { success: false, error_code: "TEST_FAILURE" },
            },
          ]),
      }),
    ).rejects.toThrow(/STAGING_APPLY_FAILED/);
    expect(count).toBe(2);
  });
  it("keeps secrets out of source-derived SQL and preserves the exact snapshot checksum", () => {
    const s = fixture();
    s.snapshot_id = "test'; malicious text";
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    const sql = buildStagingMasterLoadSql(s, { targetProjectRef: target });
    expect(sql).not.toContain("test'; malicious text");
    expect(sql).toContain(
      Buffer.from(JSON.stringify(s), "utf8").toString("base64"),
    );
  });
});

describe("authenticated Atlas visibility", () => {
  it("checks the real read contract shapes without using a service key or issuing business commands", async () => {
    const paths = [];
    const result = await verifyStagingMasterVisibility(
      {
        source: {
          canonical_counts: {
            schools: 1,
            ingredients: 1,
            suppliers: 1,
            dishes: 1,
          },
        },
      },
      {
        environment: {
          ...env,
          VITE_SUPABASE_PUBLISHABLE_KEY: "public-browser-key",
          ATLAS_STAGING_TEST_EMAIL: "fixture@example.test",
          ATLAS_STAGING_TEST_PASSWORD: "synthetic-password",
        },
        fetchImpl: async (url, init) => {
          paths.push(url);
          if (url.endsWith("/auth/v1/token?grant_type=password"))
            return Response.json({
              access_token: "synthetic-jwt",
              user: { id: "fixture-subject" },
            });
          expect(init.headers.Authorization).toBe("Bearer synthetic-jwt");
          expect(init.headers.apikey).toBe("public-browser-key");
          let body = { success: true };
          if (url.endsWith("/get_school_master_data"))
            body.schools = [{ school_code: "v1-school-1" }];
          if (url.endsWith("/get_ingredient_supplier_master_data"))
            Object.assign(body, {
              ingredients: [{ ingredient_code: "v1-ingredient-1" }],
              suppliers: [{ supplier_code: "v1-supplier-1" }],
              units: [
                {
                  unit_code: "kg",
                  unit_status: "ACTIVE",
                  unit_name: "Kilogram",
                },
              ],
            });
          if (url.endsWith("/get_dish_recipe_workbench"))
            body.workbench = {
              dishes: [{ dish_id: "fixture-dish", dish_code: "v1-dish-1" }],
            };
          if (url.endsWith("/get_planning_inputs_workbench"))
            body.workbench = { schools: [], dishes: [] };
          return Response.json(body);
        },
      },
    );
    expect(result.status).toBe("AUTHENTICATED_MASTER_READS_PASS");
    expect(paths).toHaveLength(5);
    expect(
      paths.every((p) => p.includes("/get_") || p.includes("/auth/v1/token")),
    ).toBe(true);
  });
  it("does not hide a truncated catalogue behind a successful HTTP response", async () => {
    await expect(
      verifyStagingMasterVisibility(
        {
          source: {
            canonical_counts: {
              schools: 2,
              ingredients: 1,
              suppliers: 1,
              dishes: 1,
            },
          },
        },
        {
          environment: {
            ...env,
            VITE_SUPABASE_PUBLISHABLE_KEY: "public",
            ATLAS_STAGING_TEST_EMAIL: "fixture@example.test",
            ATLAS_STAGING_TEST_PASSWORD: "synthetic",
          },
          fetchImpl: async (url) =>
            Response.json(
              url.includes("/auth/")
                ? { access_token: "token", user: { id: "subject" } }
                : {
                    success: true,
                    schools: [],
                    ingredients: [],
                    suppliers: [],
                    workbench: { dishes: [] },
                  },
            ),
        },
      ),
    ).rejects.toThrow(/VISIBLE_MASTER_COUNT/);
  });
});

describe("safe apply failure diagnostics", () => {
  it("reports constraint metadata without upstream messages or retrying the write", async () => {
    let calls = 0;
    await expect(
      runAtlasStagingMasterLoad({
        commitSha: "a".repeat(40),
        apply: true,
        targetConfirmation: target,
        environment: env,
        verifyCheckout: () => "a".repeat(40),
        extractSnapshot: async () => fixture(),
        executeTarget: async () =>
          JSON.stringify([
            {
              result:
                ++calls === 1
                  ? preview
                  : {
                      success: false,
                      error_code: "APPLY_INVARIANT_FAILURE",
                      constraint_state: "23505",
                      constraint_schema: "atlas_admin",
                      constraint_table: "dishes",
                      constraint_name: "dishes_active_normalized_name_key",
                      apply_phase: "RECIPES",
                      message: "SECRET source values",
                      detail: "SECRET source values",
                    },
            },
          ]),
      }),
    ).rejects.toThrow(
      "STAGING_APPLY_FAILED:APPLY_INVARIANT_FAILURE:23505:RECIPES:atlas_admin:dishes:dishes_active_normalized_name_key",
    );
    expect(calls).toBe(2);
  });
});
