// @vitest-environment node
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";

const fixture = JSON.parse(
  readFileSync(
    new URL(
      "./fixtures/atlas-school-order-forward-correction.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
const runner = await import("./correct-atlas-staging-school-order.mjs").catch(
  () => null,
);
const target = "rnzxmxiiqgtdevzregff";
const correctionId = "ops-v1-school-order-forward-correction-38071834975-1-v1";
const review = "SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW";
const environment = {
  ATLAS_STAGING_PROJECT_REF: target,
  VITE_SUPABASE_URL: `https://${target}.supabase.co`,
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-protected-token",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic",
  ATLAS_STAGING_TEST_EMAIL: "synthetic@example.test",
  ATLAS_STAGING_TEST_PASSWORD: "synthetic-password",
};
const clone = (value) => structuredClone(value);
function preview() {
  const old = fixture.receipt.result_payload.current_schools;
  const current = fixture.current_schools;
  return {
    success: true,
    status: "PREVIEW",
    snapshot_id: correctionId,
    original_receipt_hash: runner?.ORIGINAL_RECEIPT_HASH,
    original_snapshot_id: fixture.receipt.snapshot_id,
    original_snapshot_checksum: fixture.receipt.snapshot_checksum,
    original_plan_checksum: fixture.receipt.plan_checksum,
    plan_checksum: "b".repeat(64),
    correction_already_applied: false,
    protected_fingerprints: {
      "synthetic.protected": { rows: 3, sha256: "a".repeat(64) },
    },
    target_school_order_ids: clone(
      fixture.receipt.result_payload.target_school_order_ids,
    ),
    target_school_display_orders: clone(fixture.expected_corrected_orders),
    report: fixture.expected_corrected_orders.map((order) => {
      const school = current.find((s) => s.school_id === order.school_id);
      const legacy = fixture.current_mappings.find(
        (m) => m.school_id === order.school_id,
      )?.legacy_id;
      return {
        school_id: school.school_id,
        school_code: school.school_code,
        school_name: school.school_name,
        pre_reconciliation_order:
          old.find((s) => s.school_id === order.school_id)?.display_order ??
          null,
        current_dense_order: school.display_order,
        corrected_order: order.display_order,
        changed_by_forward_correction:
          school.display_order !== order.display_order,
        block: ["52", "10"].includes(legacy)
          ? "BINH_QUOI"
          : ["47", "48", "49", "50", "53"].includes(legacy)
            ? "HUNG_VUONG"
            : null,
        reason: "RESTORE_PRE_RECONCILIATION",
      };
    }),
  };
}
function apiSchools(corrected = false) {
  return fixture.expected_corrected_orders.map((order) => {
    const school = fixture.current_schools.find(
      (s) => s.school_id === order.school_id,
    );
    const scope = fixture.school_scope.find(
      (s) => s.school_id === order.school_id,
    );
    return {
      ...school,
      ...scope,
      operational_notes: null,
      default_student_portions: 17,
      created_at: "2026-10-10T00:00:00Z",
      updated_at: corrected ? "2026-10-11T00:00:00Z" : "2026-10-10T00:00:00Z",
      version:
        school.version +
        Number(corrected && school.display_order !== order.display_order),
      display_order: corrected ? order.display_order : school.display_order,
    };
  });
}
async function run(overrides = {}) {
  expect(runner?.runSchoolOrderForwardCorrection).toBeTypeOf("function");
  const statements = [],
    reports = [],
    fetches = [];
  let calls = 0,
    reads = 0;
  const plan = preview();
  const result = await runner.runSchoolOrderForwardCorrection({
    commitSha: "c".repeat(40),
    environment,
    verifyCheckout: async () => {},
    onReport: (report) => reports.push(clone(report)),
    executeTarget: async (_target, sql) => {
      statements.push(sql);
      if (sql.includes("migration_count"))
        return JSON.stringify([
          { result: { migration_count: 97, tip: "20261010034834" } },
        ]);
      calls++;
      return JSON.stringify([
        {
          result: {
            ...clone(plan),
            reconciled: true,
            operational_data_unchanged: true,
            unrelated_master_facts_unchanged: true,
            original_receipt_unchanged: true,
            status:
              calls === 1 ? "PREVIEW" : calls === 2 ? "APPLIED" : "REPLAYED",
          },
        },
      ]);
    },
    fetchImpl: async (url, options) => {
      fetches.push({ url, options });
      return {
        ok: true,
        json: async () =>
          url.includes("/auth/")
            ? {
                access_token: "synthetic-real-auth-response",
                user: { id: "aa000000-0000-4000-8000-000000000001" },
              }
            : { success: true, schools: apiSchools(reads++ > 0) },
      };
    },
    ...overrides,
  });
  return { result, statements, reports, fetches };
}
describe("protected School order forward correction", () => {
  it("defaults to preview with the complete reviewed fifty-row report and no Auth or apply", async () => {
    const output = await run();
    expect(output.result.status).toBe(
      "SCHOOL_ORDER_FORWARD_CORRECTION_PREVIEW",
    );
    expect(output.statements).toHaveLength(2);
    expect(output.statements[1]).toContain(
      "run_school_order_forward_correction(false, null)",
    );
    expect(output.reports[0]).toEqual({
      plan_checksum: "b".repeat(64),
      report: preview().report,
    });
    expect(output.fetches).toHaveLength(0);
  });
  it("binds apply and replay to the exact preview checksum and validates full Auth reads", async () => {
    const output = await run({ apply: true, targetConfirmation: target });
    expect(output.result.status).toBe("SCHOOL_ORDER_FORWARD_CORRECTION_PASS");
    expect(output.result.replay_status).toBe("REPLAYED");
    expect(output.statements).toHaveLength(4);
    expect(output.statements[2]).toBe(output.statements[3]);
    expect(output.statements[2]).toContain(
      "run_school_order_forward_correction(true, '" + "b".repeat(64) + "')",
    );
    expect(output.fetches).toHaveLength(3);
    expect(output.fetches[0].options.body).toContain("synthetic-password");
    expect(output.fetches[1].options.headers["Content-Profile"]).toBe(
      "atlas_api",
    );
    expect(output.fetches[1].options.headers.Authorization).toBe(
      "Bearer synthetic-real-auth-response",
    );
    expect(output.result.authenticated_readback.school_count).toBe(50);
  });
  it("blocks invalid targets, confirmation, credentials and exact-main mismatch before SQL", async () => {
    const denied = () => {
      throw new Error("must not execute SQL");
    };
    for (const options of [
      { apply: true },
      {
        environment: {
          ...environment,
          ATLAS_STAGING_PROJECT_REF: "qnthofvccilhnefdcxnz",
        },
      },
      {
        apply: true,
        targetConfirmation: target,
        environment: { ...environment, ATLAS_STAGING_TEST_PASSWORD: undefined },
      },
      {
        verifyCheckout: () => {
          throw new Error("not exact main");
        },
      },
    ])
      await expect(
        run({ ...options, executeTarget: denied }),
      ).rejects.toThrow();
    expect(() =>
      verifyExactMainCheckout({
        commitSha: "c".repeat(40),
        runCommand: (_cmd, args) => ({
          status: 0,
          stdout:
            args[0] === "rev-parse"
              ? (args[1] === "HEAD" ? "c" : "d").repeat(40)
              : "",
        }),
      }),
    ).toThrow(/current origin\/main/);
  });
  it("blocks migration drift before preparing the correction package", async () => {
    let count = 0;
    await expect(
      run({
        executeTarget: async () => {
          count++;
          return JSON.stringify([
            { result: { migration_count: 98, tip: "20261010102603" } },
          ]);
        },
      }),
    ).rejects.toThrow(review);
    expect(count).toBe(1);
  });
  it.each([
    [
      "receipt checksum",
      (p) => {
        p.original_snapshot_checksum = "a".repeat(64);
      },
    ],
    [
      "receipt hash",
      (p) => {
        p.original_receipt_hash = "a".repeat(64);
      },
    ],
    [
      "old baseline",
      (p) => {
        p.report[0].pre_reconciliation_order++;
      },
    ],
    [
      "current dense baseline",
      (p) => {
        p.report[1].current_dense_order++;
      },
    ],
    [
      "incomplete report",
      (p) => {
        p.report.pop();
      },
    ],
    [
      "wrong identity",
      (p) => {
        p.report[2].school_name = "drift";
      },
    ],
    [
      "dense renumber",
      (p) => {
        p.report.forEach((s, i) => {
          s.corrected_order = i;
        });
      },
    ],
    [
      "wrong secondary order",
      (p) => {
        [p.target_school_order_ids[0], p.target_school_order_ids[1]] = [
          p.target_school_order_ids[1],
          p.target_school_order_ids[0],
        ];
      },
    ],
  ])("rejects %s in preview before write", async (_name, change) => {
    const p = preview();
    change(p);
    expect(() => runner.validateSchoolOrderCorrectionPlan(p)).toThrow(review);
  });
  it("stops on uncertain apply and names the stable receipt without retrying", async () => {
    let count = 0;
    await expect(
      run({
        apply: true,
        targetConfirmation: target,
        executeTarget: async (_target, sql) => {
          count++;
          if (count === 1)
            return JSON.stringify([
              { result: { migration_count: 97, tip: "20261010034834" } },
            ]);
          if (count === 2) return JSON.stringify([{ result: preview() }]);
          throw new Error("transport-secret");
        },
      }),
    ).rejects.toThrow(new RegExp(`UNCERTAIN.*${correctionId}`));
    expect(count).toBe(3);
  });
  it("rejects drift in applied report/checksum and does not replay it", async () => {
    let count = 0;
    await expect(
      run({
        apply: true,
        targetConfirmation: target,
        executeTarget: async () => {
          count++;
          if (count === 1)
            return JSON.stringify([
              { result: { migration_count: 97, tip: "20261010034834" } },
            ]);
          return JSON.stringify([
            {
              result: {
                ...preview(),
                status: count === 2 ? "PREVIEW" : "APPLIED",
                plan_checksum: (count === 2 ? "b" : "a").repeat(64),
              },
            },
          ]);
        },
      }),
    ).rejects.toThrow(review);
    expect(count).toBe(3);
  });
  it("accepts an already applied correction only with a verified corrected Auth baseline", async () => {
    let count = 0;
    const p = { ...preview(), correction_already_applied: true };
    const output = await run({
      apply: true,
      targetConfirmation: target,
      executeTarget: async () => {
        count++;
        return JSON.stringify([
          {
            result:
              count === 1
                ? { migration_count: 97, tip: "20261010034834" }
                : {
                    ...p,
                    status: count === 2 ? "PREVIEW" : "REPLAYED",
                    reconciled: true,
                    operational_data_unchanged: true,
                    unrelated_master_facts_unchanged: true,
                    original_receipt_unchanged: true,
                  },
          },
        ]);
      },
      fetchImpl: async (url) => ({
        ok: true,
        json: async () =>
          url.includes("/auth/")
            ? {
                access_token: "synthetic-auth-response",
                user: { id: "aa000000-0000-4000-8000-000000000001" },
              }
            : { success: true, schools: apiSchools(true) },
      }),
    });
    expect(output.result.status).toBe("SCHOOL_ORDER_FORWARD_CORRECTION_PASS");
    expect(output.result.replay_status).toBe("REPLAYED");
    expect(count).toBe(4);
  });
  it.each(["signin", "before-order"])(
    "blocks failed %s before the first write",
    async (failure) => {
      let calls = 0;
      await expect(
        run({
          apply: true,
          targetConfirmation: target,
          executeTarget: async () =>
            JSON.stringify([
              {
                result:
                  ++calls === 1
                    ? { migration_count: 97, tip: "20261010034834" }
                    : preview(),
              },
            ]),
          fetchImpl: async (url) => ({
            ok: failure !== "signin",
            json: async () => {
              if (url.includes("/auth/"))
                return {
                  access_token: "synthetic-auth-response",
                  user: { id: "aa000000-0000-4000-8000-000000000001" },
                };
              const schools = apiSchools();
              [schools[0], schools[1]] = [schools[1], schools[0]];
              return { success: true, schools };
            },
          }),
        }),
      ).rejects.toThrow(review);
      expect(calls).toBe(2);
    },
  );
  it("returns a safe review error on Auth transport failure before any write", async () => {
    let calls = 0;
    await expect(
      run({
        apply: true,
        targetConfirmation: target,
        executeTarget: async () =>
          JSON.stringify([
            {
              result:
                ++calls === 1
                  ? { migration_count: 97, tip: "20261010034834" }
                  : preview(),
            },
          ]),
        fetchImpl: async () => {
          throw new Error("secret-auth-transport-details");
        },
      }),
    ).rejects.toThrow(review);
    expect(calls).toBe(2);
  });
  it.each([
    "known SQL rejection",
    "report change",
    "protected fingerprint change",
    "replay status",
  ])(
    "rejects %s without treating drift as uncertain transport",
    async (failure) => {
      let count = 0;
      await expect(
        run({
          apply: true,
          targetConfirmation: target,
          executeTarget: async () => {
            count++;
            if (count === 1)
              return JSON.stringify([
                { result: { migration_count: 97, tip: "20261010034834" } },
              ]);
            const result = {
              ...preview(),
              status:
                count === 2 ? "PREVIEW" : count === 3 ? "APPLIED" : "REPLAYED",
              reconciled: true,
              operational_data_unchanged: true,
              unrelated_master_facts_unchanged: true,
              original_receipt_unchanged: true,
            };
            if (count === 3) {
              if (failure === "known SQL rejection")
                return JSON.stringify([
                  { result: { success: false, error_code: review } },
                ]);
              if (failure === "report change")
                result.report[0].reason = "UNCHANGED";
              if (failure === "protected fingerprint change")
                result.protected_fingerprints["synthetic.protected"].rows++;
            }
            if (count === 4 && failure === "replay status")
              result.status = "APPLIED";
            return JSON.stringify([{ result }]);
          },
        }),
      ).rejects.toThrow(review);
      expect(count).toBe(failure === "replay status" ? 4 : 3);
    },
  );
  it.each([
    "raw secondary order",
    "non-order fact",
    "missing School",
    "wrong code",
  ])("rejects %s on authenticated full readback", async (drift) => {
    let reads = 0;
    await expect(
      run({
        apply: true,
        targetConfirmation: target,
        fetchImpl: async (url) => ({
          ok: true,
          json: async () => {
            if (url.includes("/auth/"))
              return {
                access_token: "synthetic-auth-response",
                user: { id: "aa000000-0000-4000-8000-000000000001" },
              };
            const schools = apiSchools(reads++ > 0);
            if (reads === 2) {
              if (drift === "raw secondary order")
                [schools[0], schools[1]] = [schools[1], schools[0]];
              if (drift === "non-order fact")
                schools[0].default_student_portions++;
              if (drift === "missing School") schools.pop();
              if (drift === "wrong code") schools[0].school_code = "wrong";
            }
            return { success: true, schools };
          },
        }),
      }),
    ).rejects.toThrow(review);
  });
  it("adds the protected manual correct-order choice and full-integration path filters", () => {
    const workflow = readFileSync(
      new URL(
        "../.github/workflows/atlas-staging-school-reconciliation.yml",
        import.meta.url,
      ),
      "utf8",
    );
    expect(workflow).toContain("- correct-order");
    expect(workflow).toContain(
      "correct-order) node scripts/correct-atlas-staging-school-order.mjs",
    );
    expect(workflow).toContain("environment: atlas-staging");
    expect(workflow).toContain("group: atlas-staging-master-data-load");
    expect(workflow).toContain("default: false");
    const integration = readFileSync(
      new URL("../.github/workflows/supabase-integration.yml", import.meta.url),
      "utf8",
    );
    expect(
      integration.match(/scripts\/correct-atlas-staging-school-order\*/g),
    ).toHaveLength(2);
    expect(
      integration.match(
        /scripts\/fixtures\/atlas-school-order-forward-correction\.json/g,
      ),
    ).toHaveLength(2);
    expect(
      integration.match(
        /scripts\/test-local-school-order-forward-correction\.mjs/g,
      ),
    ).toHaveLength(2);
  });
});
