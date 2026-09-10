import { describe, expect, it, vi } from "vitest";
import {
  assertSchoolFulfilmentScenarios,
  verifyAtlasStagingSchoolFulfilment,
} from "./verify-atlas-staging-school-fulfilment.mjs";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";

const dates = ["2046-09-17", "2046-09-18", "2046-09-19"];
const environment = {
  VITE_ATLAS_ENVIRONMENT: "staging",
  ATLAS_STAGING_PROJECT_REF: "rnzxmxiiqgtdevzregff",
  VITE_SUPABASE_URL: "https://rnzxmxiiqgtdevzregff.supabase.co",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_atlas_staging_test_value",
  ATLAS_STAGING_TEST_EMAIL: "operator@example.test",
  ATLAS_STAGING_TEST_PASSWORD: "a-secure-test-password",
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "test-access-token",
};

function groupedRequirement(serviceDate, suffix, quantities) {
  return {
    service_date: serviceDate,
    customer_id: `customer-${suffix}`,
    school_id: `school-${suffix}`,
    school_name: `School ${suffix.toUpperCase()}`,
    delivery_location_id: `location-${suffix}`,
    delivery_location_name: `Location ${suffix.toUpperCase()}`,
    ingredient_id: `ingredient-${suffix}`,
    ingredient_name: `Ingredient ${suffix.toUpperCase()}`,
    unit_id: "unit-kg",
    unit_name: "kg",
    total_theoretical_quantity: quantities.total,
    recipe_derived_quantity: quantities.recipe,
    pantry_direct_quantity: quantities.pantry,
    active_contribution_count: quantities.active,
    removed_contribution_count: 0,
    warning_count: 0,
  };
}

function needEvidence() {
  return {
    daily: [
      {
        service_date: dates[0],
        workbench: {
          period: { period_start: dates[0], period_end: dates[0] },
          selected_run: {
            need_generation_run_id: "need-run-a",
            status: "RELEASED_FOR_CONFIRMATION",
          },
          grouped_requirements: [
            groupedRequirement(dates[0], "a", {
              total: "12.3",
              recipe: "11",
              pantry: "1.3",
              active: 2,
            }),
          ],
          atomic_detail: [],
          source_evidence: {
            weekly_menu: { weekly_menu_id: "menu-a" },
            attendance: { attendance_batch_id: "attendance-a" },
            pantry: { pantry_need_batch_id: "pantry-a" },
          },
        },
        atomic_detail: [
          {
            theoretical_need_line_id: "need-line-a-recipe",
            contribution_family: "RECIPE_DERIVED",
            theoretical_quantity: "11",
            unit_id: "unit-kg",
            unit_name: "kg",
            disposition: "ACTIVE",
            dish_name: "Dish A",
            recipe_id: "recipe-a",
            warning_references: [],
          },
          {
            theoretical_need_line_id: "need-line-a-pantry",
            contribution_family: "PANTRY_DIRECT",
            theoretical_quantity: "1.3",
            unit_id: "unit-kg",
            unit_name: "kg",
            disposition: "ACTIVE",
            pantry_purpose: "Bổ sung",
            pantry_source_reference: "PANTRY-A",
            warning_references: [],
          },
        ],
      },
      {
        service_date: dates[1],
        workbench: {
          period: { period_start: dates[1], period_end: dates[1] },
          selected_run: {
            need_generation_run_id: "need-run-b",
            status: "RELEASED_FOR_CONFIRMATION",
          },
          grouped_requirements: [
            groupedRequirement(dates[1], "b", {
              total: "7.75",
              recipe: "0",
              pantry: "7.75",
              active: 1,
            }),
          ],
          atomic_detail: [],
          source_evidence: {
            weekly_menu: { weekly_menu_id: "menu-parent-b" },
            attendance: { attendance_batch_id: "attendance-parent-b" },
            pantry: { pantry_need_batch_id: "pantry-b" },
          },
        },
        atomic_detail: [
          {
            theoretical_need_line_id: "need-line-b-pantry",
            contribution_family: "PANTRY_DIRECT",
            theoretical_quantity: "7.75",
            unit_id: "unit-kg",
            unit_name: "kg",
            disposition: "ACTIVE",
            pantry_purpose: "Đặt riêng",
            pantry_source_reference: "PANTRY-B",
            warning_references: [],
          },
        ],
      },
      {
        service_date: dates[2],
        workbench: {
          period: { period_start: dates[2], period_end: dates[2] },
          selected_run: {
            need_generation_run_id: "need-run-c",
            status: "RELEASED_FOR_CONFIRMATION",
          },
          grouped_requirements: [
            groupedRequirement(dates[2], "c", {
              total: "9",
              recipe: "9",
              pantry: "0",
              active: 1,
            }),
          ],
          atomic_detail: [],
          source_evidence: {
            weekly_menu: { weekly_menu_id: "menu-c" },
            attendance: { attendance_batch_id: "attendance-c" },
            pantry: { pantry_need_batch_id: "pantry-c" },
          },
        },
        atomic_detail: [
          {
            theoretical_need_line_id: "need-line-c-recipe",
            contribution_family: "RECIPE_DERIVED",
            theoretical_quantity: "9",
            unit_id: "unit-kg",
            unit_name: "kg",
            disposition: "ACTIVE",
            dish_name: "Dish C",
            recipe_id: "recipe-c",
            warning_references: [],
          },
        ],
      },
    ],
  };
}

function evidence() {
  return {
    needEvidence: needEvidence(),
    confirmedNeeds: {
      rows: [
        {
          workbench: {
            lines: [
              {
                service_date: dates[2],
                current_revision_id: "need-revision-new",
                current_decision_id: "need-decision-new",
                decision_history: [
                  {
                    decision_id: "need-decision-new",
                    decision_number: 2,
                    predecessor_decision_id: "need-decision-old",
                    revision_id: "need-revision-new",
                  },
                  {
                    decision_id: "need-decision-old",
                    decision_number: 1,
                    predecessor_decision_id: null,
                    revision_id: "need-revision-old",
                  },
                ],
              },
            ],
          },
        },
      ],
    },
    purchaseOrders: {
      purchase_orders: [
        {
          service_date: dates[2],
          purchase_order_id: "po-old",
          purchase_order_status: "SUPERSEDED",
        },
        {
          service_date: dates[2],
          purchase_order_id: "po-new",
          purchase_order_status: "RELEASED_TO_SUPPLIER",
          replaces_purchase_order_id: "po-old",
        },
      ],
    },
    reconciliation: {
      rows: dates.map((service_date, index) => ({
        service_date,
        comparison_status: "OK",
        pxk_state: "CURRENT",
        blockers: [],
        quantity_totals_by_unit: [
          {
            unit_code: "kg",
            po_quantity: "10",
            pxk_quantity: "10",
            delta_quantity: "0",
          },
        ],
        purchase_order_ids: index === 2 ? ["po-new"] : ["po-current"],
        school_dispatch_release_id: index === 2 ? "pxk-new" : "pxk-current",
        history:
          index === 2
            ? [
                {
                  school_dispatch_release_id: "pxk-new",
                  status: "RELEASED",
                  predecessor_release_id: "pxk-old",
                },
                {
                  school_dispatch_release_id: "pxk-old",
                  status: "SUPERSEDED",
                  predecessor_release_id: null,
                },
              ]
            : [
                {
                  school_dispatch_release_id: "pxk-current",
                  status: "RELEASED",
                  predecessor_release_id: null,
                },
              ],
      })),
    },
  };
}

function createRpcHarness(fixture = evidence()) {
  const rpcCalls = [];
  const signInWithPassword = vi.fn(async () => ({
    data: { session: { user: { id: "atlas-staging-operator" } } },
    error: null,
  }));
  const signOut = vi.fn(async () => ({ error: null }));
  const dailyByDate = new Map(
    fixture.needEvidence.daily.map((day) => [day.service_date, day]),
  );
  const client = {
    auth: { signInWithPassword, signOut },
    schema: vi.fn(() => ({
      rpc: (name, { request }) => {
        rpcCalls.push({ name, request });
        let response;
        if (name === "get_need_generation_workbench") {
          const payload = request.payload;
          const day =
            payload.period_start === payload.period_end
              ? dailyByDate.get(payload.period_start)
              : undefined;
          response = day
            ? {
                workbench: {
                  ...day.workbench,
                  atomic_detail: payload.detail_group
                    ? day.atomic_detail
                    : day.workbench.atomic_detail,
                },
              }
            : {
                workbench: {
                  grouped_requirements: [],
                  atomic_detail: [],
                  source_evidence: {},
                },
              };
        } else if (name === "get_confirmed_supplier_allocation_workbench") {
          response = {
            rows: [
              {
                service_date: dates[2],
                source_confirmed_need_batch_id: "confirmed-need-batch",
              },
            ],
          };
        } else if (name === "get_school_catering_purchase_orders") {
          response = fixture.purchaseOrders;
        } else if (name === "get_school_dispatch_release_workbench") {
          response = { rows: [] };
        } else if (name === "get_school_fulfilment_reconciliation_workbench") {
          response = fixture.reconciliation;
        } else if (name === "get_confirmed_need_review") {
          response = fixture.confirmedNeeds.rows[0];
        }
        return {
          retry: async () => ({
            data: { success: true, ...response },
            error: null,
          }),
        };
      },
    })),
  };
  return { client, rpcCalls, signInWithPassword, signOut };
}

describe("School fulfilment Staging verifier", () => {
  it("T1 reads Need Generation separately for all three daily authorities and never as one range", async () => {
    const harness = createRpcHarness();
    await verifyAtlasStagingSchoolFulfilment({
      environment,
      createClientFactory: () => harness.client,
    }).catch(() => undefined);

    const baseNeedPeriods = harness.rpcCalls
      .filter(
        ({ name, request }) =>
          name === "get_need_generation_workbench" &&
          !request.payload.detail_group,
      )
      .map(({ request }) => [
        request.payload.period_start,
        request.payload.period_end,
      ]);
    expect(baseNeedPeriods).toEqual(dates.map((date) => [date, date]));
    expect(baseNeedPeriods).not.toContainEqual([dates[0], dates[2]]);
  });

  it("T2 uses the public maximum group limit for every daily Need base read", async () => {
    const harness = createRpcHarness();
    await verifyAtlasStagingSchoolFulfilment({
      environment,
      createClientFactory: () => harness.client,
    }).catch(() => undefined);

    const limits = harness.rpcCalls
      .filter(
        ({ name, request }) =>
          name === "get_need_generation_workbench" &&
          !request.payload.detail_group,
      )
      .map(({ request }) => request.payload.group_limit);
    expect(limits).toEqual([250, 250, 250]);
  });

  it("deduplicates full-grain detail groups before reading atomic Need evidence", async () => {
    const fixture = evidence();
    fixture.needEvidence.daily[0].workbench.grouped_requirements.push(
      structuredClone(
        fixture.needEvidence.daily[0].workbench.grouped_requirements[0],
      ),
    );
    const harness = createRpcHarness(fixture);
    await verifyAtlasStagingSchoolFulfilment({
      environment,
      createClientFactory: () => harness.client,
    }).catch(() => undefined);

    const detailCalls = harness.rpcCalls.filter(
      ({ name, request }) =>
        name === "get_need_generation_workbench" &&
        request.payload.detail_group,
    );
    expect(detailCalls.map(({ request }) => request.payload)).toEqual([
      expect.objectContaining({
        period_start: dates[0],
        period_end: dates[0],
        group_limit: 250,
        detail_group: {
          service_date: dates[0],
          school_id: "school-a",
          delivery_location_id: "location-a",
          ingredient_id: "ingredient-a",
          unit_id: "unit-kg",
        },
      }),
      expect.objectContaining({
        period_start: dates[1],
        period_end: dates[1],
        group_limit: 250,
        detail_group: {
          service_date: dates[1],
          school_id: "school-b",
          delivery_location_id: "location-b",
          ingredient_id: "ingredient-b",
          unit_id: "unit-kg",
        },
      }),
    ]);
  });

  it("T3 accepts Scenario A grouped Recipe 11 kg plus Pantry 1.3 kg as total 12.3 kg", () => {
    expect(assertSchoolFulfilmentScenarios(evidence())).toEqual({
      status: "verified",
      scenarios: 3,
    });
  });

  it("T4 requires both Scenario A atomic contribution families", () => {
    const value = evidence();
    value.needEvidence.daily[0].atomic_detail.splice(0, 1);
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /Scenario A.*Recipe and Pantry/i,
    );
  });

  it("T5 accepts Scenario B grouped COMPLETE Pantry-only 7.75 kg evidence", () => {
    expect(assertSchoolFulfilmentScenarios(evidence())).toEqual({
      status: "verified",
      scenarios: 3,
    });
  });

  it("T6 rejects Recipe-owned evidence on Scenario B Pantry atomic detail", () => {
    const value = evidence();
    value.needEvidence.daily[1].atomic_detail[0].recipe_id =
      "fabricated-recipe";
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /Scenario B.*without fabricated bindings/i,
    );
  });

  it("T7 rejects wrong Scenario A atomic family membership", () => {
    const value = evidence();
    value.needEvidence.daily[0].atomic_detail[0].contribution_family =
      "PANTRY_DIRECT";
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /Scenario A.*Recipe and Pantry/i,
    );
  });

  it("T8 rejects a Recipe contribution in Scenario B", () => {
    const value = evidence();
    value.needEvidence.daily[1].atomic_detail.push({
      contribution_family: "RECIPE_DERIVED",
      theoretical_quantity: "1",
      unit_id: "unit-kg",
      disposition: "ACTIVE",
      recipe_id: "recipe-b",
    });
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /Scenario B.*without fabricated bindings/i,
    );
  });

  it("T9 rejects a missing daily Need workbench", () => {
    const value = evidence();
    value.needEvidence.daily.pop();
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /Need workbench.*2046-09-19/i,
    );
  });

  it("T10 retains the Confirmed Need predecessor-history assertion", () => {
    const value = evidence();
    value.confirmedNeeds.rows[0].workbench.lines[0].decision_history = [];
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /predecessor Confirmed Need decision and revision/i,
    );
  });

  it("T11 retains the PO replacement-lineage assertion", () => {
    const value = evidence();
    value.purchaseOrders.purchase_orders = [];
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /superseded PO evidence/i,
    );
  });

  it("T12 retains the PXK predecessor-lineage assertion", () => {
    const value = evidence();
    value.reconciliation.rows[2].history[0].predecessor_release_id = null;
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow(
      /superseded PXK evidence/i,
    );
  });

  it.each([
    [
      "comparison status",
      (value) => {
        value.reconciliation.rows[0].comparison_status = "MISMATCH";
      },
    ],
    [
      "PXK currentness",
      (value) => {
        value.reconciliation.rows[0].pxk_state = "REPLACEMENT_REQUIRED";
      },
    ],
    [
      "unit-safe totals",
      (value) => {
        value.reconciliation.rows[0].quantity_totals_by_unit = [];
      },
    ],
  ])("T13 retains reconciliation %s assertion", (_label, mutate) => {
    const value = evidence();
    mutate(value);
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow();
  });

  it("T14 signs in, performs only read RPCs, signs out, and returns verified evidence", async () => {
    const harness = createRpcHarness();
    await expect(
      verifyAtlasStagingSchoolFulfilment({
        environment,
        createClientFactory: () => harness.client,
      }),
    ).resolves.toEqual({ status: "verified", scenarios: 3 });

    expect(harness.rpcCalls.every(({ name }) => name.startsWith("get_"))).toBe(
      true,
    );
    expect(harness.signInWithPassword).toHaveBeenCalledWith({
      email: environment.ATLAS_STAGING_TEST_EMAIL,
      password: environment.ATLAS_STAGING_TEST_PASSWORD,
    });
    expect(harness.signOut).toHaveBeenCalledWith({ scope: "local" });
  });

  it("does not create a client during dry-run", async () => {
    const createClientFactory = vi.fn();
    const result = await verifyAtlasStagingSchoolFulfilment({
      environment,
      createClientFactory,
      dryRun: true,
    });
    expect(result.networkWrites).toBe(false);
    expect(createClientFactory).not.toHaveBeenCalled();
  });

  it("rejects missing values, a wrong project, and live OPS before client creation", async () => {
    const createClientFactory = vi.fn();
    await expect(
      verifyAtlasStagingSchoolFulfilment({
        environment: {},
        createClientFactory,
        dryRun: true,
      }),
    ).rejects.toThrow(/missing/i);
    await expect(
      verifyAtlasStagingSchoolFulfilment({
        environment: {
          VITE_ATLAS_ENVIRONMENT: "staging",
          ATLAS_STAGING_PROJECT_REF: "aaaaaaaaaaaaaaaaaaaa",
          VITE_SUPABASE_URL: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co",
          VITE_SUPABASE_PUBLISHABLE_KEY:
            "sb_publishable_atlas_staging_test_value",
          ATLAS_STAGING_TEST_EMAIL: "operator@example.test",
          ATLAS_STAGING_TEST_PASSWORD: "a-secure-test-password",
          ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "test-access-token",
        },
        createClientFactory,
        dryRun: true,
      }),
    ).rejects.toThrow(/not the approved Atlas Staging project/i);
    await expect(
      verifyAtlasStagingSchoolFulfilment({
        environment: {
          VITE_ATLAS_ENVIRONMENT: "staging",
          ATLAS_STAGING_PROJECT_REF: "qnthofvccilhnefdcxnz",
          VITE_SUPABASE_URL: "https://qnthofvccilhnefdcxnz.supabase.co",
          VITE_SUPABASE_PUBLISHABLE_KEY:
            "sb_publishable_atlas_staging_test_value",
          ATLAS_STAGING_TEST_EMAIL: "operator@example.test",
          ATLAS_STAGING_TEST_PASSWORD: "a-secure-test-password",
          ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "test-access-token",
        },
        createClientFactory,
        dryRun: true,
      }),
    ).rejects.toThrow(/forbidden/i);
    expect(createClientFactory).not.toHaveBeenCalled();
  });

  it("redacts supplied protected diagnostics", () => {
    const secret = "school-fulfilment-secret";
    expect(
      redactAtlasStagingDiagnostic(`Bearer ${secret}`, [secret]),
    ).not.toContain(secret);
  });
});
