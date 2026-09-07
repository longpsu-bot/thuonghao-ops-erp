import { describe, expect, it, vi } from "vitest";
import {
  assertSchoolFulfilmentScenarios,
  verifyAtlasStagingSchoolFulfilment,
} from "./verify-atlas-staging-school-fulfilment.mjs";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";

const dates = ["2046-09-17", "2046-09-18", "2046-09-19"];
function evidence() {
  return {
    need: {
      rows: [
        { service_date: dates[0], contribution_family: "RECIPE_DERIVED" },
        { service_date: dates[0], contribution_family: "PANTRY_DIRECT" },
        {
          service_date: dates[1],
          contribution_family: "PANTRY_DIRECT",
          complete: true,
        },
      ],
    },
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
      rows: [
        {
          service_date: dates[2],
          purchase_order_id: "po-old",
          status: "SUPERSEDED",
        },
        {
          service_date: dates[2],
          purchase_order_id: "po-new",
          status: "RELEASED_TO_SUPPLIER",
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
describe("School fulfilment Staging verifier", () => {
  it("accepts the exact three scenario evidence set", () =>
    expect(assertSchoolFulfilmentScenarios(evidence())).toEqual({
      status: "verified",
      scenarios: 3,
    }));
  it.each([
    ["missing scenario", (value) => value.reconciliation.rows.pop()],
    ["wrong additive family", (value) => value.need.rows.splice(0, 1)],
    [
      "fabricated complete binding",
      (value) => {
        value.need.rows[2].weekly_menu_id = "menu";
      },
    ],
    [
      "non-current reconciliation",
      (value) => {
        value.reconciliation.rows[0].pxk_state = "REPLACEMENT_REQUIRED";
      },
    ],
    [
      "missing PXK history",
      (value) => {
        value.reconciliation.rows[2].history = [];
      },
    ],
    [
      "missing PO history",
      (value) => {
        value.purchaseOrders.rows = [];
      },
    ],
    [
      "wrong PXK predecessor",
      (value) => {
        value.reconciliation.rows[2].history[0].predecessor_release_id = null;
      },
    ],
    [
      "missing Confirmed Need history",
      (value) => {
        value.confirmedNeeds.rows[0].workbench.lines[0].decision_history = [];
      },
    ],
    [
      "stale PO lineage",
      (value) => {
        value.reconciliation.rows[2].purchase_order_ids = ["po-old"];
      },
    ],
  ])("rejects %s", (_label, mutate) => {
    const value = evidence();
    mutate(value);
    expect(() => assertSchoolFulfilmentScenarios(value)).toThrow();
  });
  it("does not create a client during dry-run", async () => {
    const createClientFactory = vi.fn();
    const environment = {
      VITE_ATLAS_ENVIRONMENT: "staging",
      ATLAS_STAGING_PROJECT_REF: "rnzxmxiiqgtdevzregff",
      VITE_SUPABASE_URL: "https://rnzxmxiiqgtdevzregff.supabase.co",
      VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_atlas_staging_test_value",
      ATLAS_STAGING_TEST_EMAIL: "operator@example.test",
      ATLAS_STAGING_TEST_PASSWORD: "a-secure-test-password",
      ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "test-access-token",
    };
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
