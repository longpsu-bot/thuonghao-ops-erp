// @vitest-environment node
import { describe, expect, it } from "vitest";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  ownerSchoolIdentityExpectations,
  buildSchoolDocumentConfiguration,
} from "./atlas-document-school-configuration.mjs";
const target = "rnzxmxiiqgtdevzregff";
const env = {
  ATLAS_STAGING_PROJECT_REF: target,
  VITE_SUPABASE_URL: `https://${target}.supabase.co`,
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-token",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic",
  ATLAS_STAGING_TEST_EMAIL: "synthetic@example.test",
  ATLAS_STAGING_TEST_PASSWORD: "synthetic-password",
};
const id = (s) => `aa000000-0000-4000-8000-${s.padStart(12, "0")}`;
const schools = ownerSchoolIdentityExpectations.map(([legacy, name], i) => ({
  school_id: id(legacy),
  school_code: `v1-school-${legacy}`,
  school_name: name,
  display_order: i,
}));
const mappings = ownerSchoolIdentityExpectations.map(([legacy]) => ({
  source_system: "OPS_V1",
  object_type: "SCHOOL",
  legacy_id: legacy,
  school_id: id(legacy),
}));
function snapshot() {
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
  records.schools = ownerSchoolIdentityExpectations.map(
    ([legacy_id, school_name]) => ({ legacy_id, school_name }),
  );
  const s = {
    contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
    source_system: "OPS_V1",
    source_project_ref: "qnthofvccilhnefdcxnz",
    snapshot_id: "synthetic-schools",
    exported_at: "2026-10-10T00:00:00Z",
    extractor_version: "synthetic",
    complete_entities: Object.keys(records).sort(),
    records,
    source_counts: { schools: 15 },
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
  return { ...s, snapshot_checksum: checksumOpsV1MasterSnapshot(s) };
}
const module = await import("./reconcile-atlas-staging-schools.mjs").catch(
  () => null,
);
async function run(overrides = {}) {
  expect(module?.runSchoolReconciliation).toBeTypeOf("function");
  const statements = [],
    reports = [];
  let extracts = 0;
  const s = snapshot();
  const preview = {
    success: true,
    status: "PREVIEW",
    snapshot_checksum: s.snapshot_checksum,
    plan_checksum: "b".repeat(64),
    target_school_display_orders: schools.map((s) => ({
      school_id: s.school_id,
      display_order: s.display_order,
    })),
    current_schools: schools,
    current_mappings: mappings,
    projected_schools: schools,
    projected_mappings: mappings,
    target_school_order_ids: buildSchoolDocumentConfiguration({
      schools,
      mappings,
    }).target_school_order_ids,
  };
  const result = await module.runSchoolReconciliation({
    commitSha: "a".repeat(40),
    environment: env,
    verifyCheckout: async () => {},
    extractSnapshot: async () => {
      extracts++;
      return s;
    },
    onReport: (r) => reports.push(r),
    executeTarget: async (_target, sql) => {
      statements.push(sql);
      let result;
      if (sql.includes("migration_count"))
        result = { migration_count: 97, tip: "20261010034834" };
      else if (
        statements.filter((x) =>
          x.includes("run_staging_school_reconciliation"),
        ).length === 1
      )
        result = preview;
      else
        result = {
          success: true,
          status: statements.length === 3 ? "APPLIED" : "REPLAYED",
          reconciled: true,
          operational_data_unchanged: true,
          unrelated_master_facts_unchanged: true,
        };
      return JSON.stringify([{ result }]);
    },
    ...overrides,
  });
  return { result, statements, reports, extracts };
}
describe("protected School reconciliation runner", () => {
  it("defaults to preview and reports identities before any apply", async () => {
    const r = await run();
    expect(r.result.status).toBe("SCHOOL_RECONCILIATION_PREVIEW");
    expect(r.reports[0]).toHaveLength(15);
    expect(r.extracts).toBe(1);
    expect(r.statements).toHaveLength(2);
    expect(r.statements[1]).toContain(", false, null, null)");
  });
  it("applies and replays one immutable snapshot only after validated report/order", async () => {
    const r = await run({ apply: true, targetConfirmation: target });
    expect(r.result.status).toBe("SCHOOL_MASTER_RECONCILED");
    expect(r.extracts).toBe(1);
    expect(r.statements).toHaveLength(4);
    expect(r.statements[2]).toBe(r.statements[3]);
    expect(r.statements[2]).toContain("'" + "b".repeat(64) + "'");
    expect(r.reports).toHaveLength(1);
  });
  it("rejects Live OPS or missing apply confirmation before extraction/SQL", async () => {
    const deny = () => {
      throw new Error("must not run");
    };
    await expect(
      run({ apply: true, extractSnapshot: deny, executeTarget: deny }),
    ).rejects.toThrow(/target confirmation/i);
    await expect(
      run({
        environment: {
          ...env,
          ATLAS_STAGING_PROJECT_REF: "qnthofvccilhnefdcxnz",
        },
        extractSnapshot: deny,
        executeTarget: deny,
      }),
    ).rejects.toThrow(/live OPS/i);
  });
  it("rejects migration drift before extracting source", async () => {
    const deny = () => {
      throw new Error("must not run");
    };
    await expect(
      run({
        extractSnapshot: deny,
        executeTarget: async () =>
          JSON.stringify([
            { result: { migration_count: 98, tip: "20261010102603" } },
          ]),
      }),
    ).rejects.toThrow(/MIGRATION_GATE/);
  });
  it("does not expose raw names/addresses in SQL or accept a corrupt snapshot", async () => {
    expect(module?.buildSchoolReconciliationSql).toBeTypeOf("function");
    const s = snapshot();
    const sql = module.buildSchoolReconciliationSql(s, {
      targetProjectRef: target,
    });
    expect(sql).not.toContain('"source_counts"');
    const corrupted = { ...s, records: { ...s.records, schools: [] } };
    expect(() =>
      module.buildSchoolReconciliationSql(corrupted, {
        targetProjectRef: target,
      }),
    ).toThrow(/CHECKSUM/);
  });
});

it("verifies canonical IDs and complete order through real authenticated shaped headers", async () => {
  const r = await run({ apply: true, targetConfirmation: target });
  let calls = [];
  const body = {
    success: true,
    schools: r.result.canonical_school_identities
      .map((s) => ({ ...s, version: 1 }))
      .sort((a, b) => a.display_order - b.display_order),
  };
  const fetchImpl = async (url, opts) => {
    calls.push({ url, opts });
    return {
      ok: true,
      json: async () =>
        url.includes("/auth/")
          ? {
              access_token: "synthetic-jwt",
              user: { id: "aa000000-0000-4000-8000-000000000001" },
            }
          : body,
    };
  };
  const result = await module.verifyReconciledSchoolVisibility(r.result, {
    environment: env,
    fetchImpl,
  });
  expect(result.status).toBe("AUTHENTICATED_SCHOOL_READBACK_PASS");
  expect(calls).toHaveLength(2);
  expect(calls[1].opts.headers.Authorization).toBe("Bearer synthetic-jwt");
  expect(calls[1].opts.headers["Content-Profile"]).toBe("atlas_api");
  body.schools[0].school_name = "Wrong identity";
  await expect(
    module.verifyReconciledSchoolVisibility(r.result, {
      environment: env,
      fetchImpl,
    }),
  ).rejects.toThrow(/READBACK_FAILED/);
});
it("refuses apply without protected authenticated-read credentials before extraction", async () => {
  await expect(
    run({
      apply: true,
      targetConfirmation: target,
      environment: { ...env, ATLAS_STAGING_TEST_PASSWORD: undefined },
      extractSnapshot: () => {
        throw new Error("must not extract");
      },
    }),
  ).rejects.toThrow(/STAGING_READ_CREDENTIAL_MISSING/);
});
it("does not retry an uncertain apply outcome", async () => {
  let calls = 0;
  await expect(
    run({
      apply: true,
      targetConfirmation: target,
      executeTarget: async (_target, sql) => {
        calls++;
        if (sql.includes("migration_count"))
          return JSON.stringify([
            { result: { migration_count: 97, tip: "20261010034834" } },
          ]);
        if (calls === 2) {
          const s = snapshot();
          return JSON.stringify([
            {
              result: {
                success: true,
                snapshot_checksum: s.snapshot_checksum,
                plan_checksum: "b".repeat(64),
                current_schools: schools,
                current_mappings: mappings,
                projected_schools: schools,
                projected_mappings: mappings,
                target_school_display_orders: schools.map((s) => ({
                  school_id: s.school_id,
                  display_order: s.display_order,
                })),
                target_school_order_ids: buildSchoolDocumentConfiguration({
                  schools,
                  mappings,
                }).target_school_order_ids,
              },
            },
          ]);
        }
        throw new Error("transport secret must not expose");
      },
    }),
  ).rejects.toThrow(/SCHOOL_APPLY_OUTCOME_UNCERTAIN/);
  expect(calls).toBe(3);
});
