import { describe, expect, it, vi } from "vitest";
import {
  assertSchoolFulfilmentScenarios,
  verifyAtlasStagingSchoolFulfilment,
} from "./verify-atlas-staging-school-fulfilment.mjs";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";

const dates = ["2046-09-17", "2046-09-18", "2046-09-19"];
function releasedAllocationHarness() {
  const id = (kind, value) =>
    `a${kind}000000-0000-4000-8000-${String(value).padStart(12, "0")}`;
  const body = {
    success: true,
    contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
    date_start: "2026-10-12",
    date_end: "2026-10-12",
    preparation: {
      ready: true,
      allowed: true,
      blockers: [],
      service_date: "2026-10-12",
      expected_version: 5,
      confirmed_need_batch_id: "69661e86-abb3-4bf4-88a5-4717fe18c472",
    },
    rows: Array.from({ length: 236 }, (_, i) => ({
      service_date: "2026-10-12",
      state: "BALANCED",
      complete: true,
      ingredient_id: id("1", i + 1),
      unit_id: id("2", 1),
      delivery_location_id: id("3", 1),
      source_kind: "PURCHASE_HANDOFF",
      source_purchase_handoff_revision_id: id("4", 1),
      source_fingerprint: "a".repeat(64),
      family_quantity: "10.000000",
      family: {
        family_id: id("5", i + 1),
        source_kind: "PURCHASE_HANDOFF",
        source_fingerprint: "a".repeat(64),
        source_confirmed_need_batch_id: "69661e86-abb3-4bf4-88a5-4717fe18c472",
        source_confirmed_need_batch_version: 5,
      },
      splits: [
        {
          supplier_id: id("6", (i % 17) + 1),
          allocated_quantity: "10.000000",
          split_ratio: "1.000000000000",
        },
      ],
      contributions: [
        {
          purchase_handoff_line_revision_id: id("7", i + 1),
          contribution_quantity: "10.000000",
        },
      ],
      blockers: [],
    })),
  };
  const state = {
    batch: { state: "RELEASED_FOR_PURCHASE_HANDOFF", version: 5 },
    allocations: 236,
    allocation_revisions: 472,
    priority_defaults: 236,
    manual_defaults: 0,
    promoted_families: 236,
    handoffs: 1,
    released_handoffs: 1,
    po_roots: 17,
    draft_pos: 17,
    po_lines: 236,
    po_suppliers: 17,
    invalid_lineage: 0,
    invalid_quantities: 0,
    invalid_po_lines: 0,
    receipt: { outcome: "COMPLETED", response_payload: { success: true } },
    fact_digest: "b".repeat(32),
    fact_count: 1500,
    current_allocations: body.rows.map((row) => ({
      ingredient_id: row.ingredient_id,
      unit_id: row.unit_id,
      delivery_location_id: row.delivery_location_id,
      quantity: row.family_quantity,
      supplier_id: row.splits[0].supplier_id,
    })),
    migration_count: 109,
    migration_tip: "20261014120320",
    migration_106_present: true,
  };
  const rpcCalls = [];
  const retry = vi.fn(async () => ({ data: body, error: null }));
  const abortSignal = vi.fn(() => ({ retry }));
  const signOut = vi.fn(async () => ({ error: null }));
  const client = {
    auth: {
      signInWithPassword: vi.fn(async () => ({
        data: {
          session: { user: { id: "a1010000-0000-4000-8000-000000000101" } },
        },
        error: null,
      })),
      signOut,
    },
    schema: vi.fn((schema) => ({
      rpc: (name, { request }) => {
        rpcCalls.push({ schema, name, request });
        return { abortSignal, retry };
      },
    })),
  };
  let after;
  let digest = "48e433c45fac665d873103542408a484";
  const executeSql = vi.fn(async (_target, query) => {
    if (query.includes("decode("))
      return JSON.stringify([{ assignment_quantity_lineage_md5: digest }]);
    return JSON.stringify([
      {
        evidence: structuredClone(
          executeSql.mock.calls.length === 1 ? state : (after ?? state),
        ),
      },
    ]);
  });
  const createClientFactory = vi.fn(() => client);
  const options = {
    environment,
    createClientFactory,
    executeSql,
    releasedAllocationRead: true,
    now: vi.fn().mockReturnValueOnce(100).mockReturnValueOnce(200),
  };
  return {
    body,
    state,
    client,
    rpcCalls,
    retry,
    abortSignal,
    signOut,
    executeSql,
    createClientFactory,
    options,
    setAfter(value) {
      after = value;
    },
    setDigest(value) {
      digest = value;
    },
  };
}
describe("released allocation read-only acceptance", () => {
  it("performs exactly one actual GET RPC with closed payload and consumes that body for SQL digest", async () => {
    const h = releasedAllocationHarness();
    await expect(
      verifyAtlasStagingSchoolFulfilment(h.options),
    ).resolves.toEqual(
      expect.objectContaining({
        status: "verified",
        mode: "released-allocation-read",
        rows: 236,
        elapsed_ms: 100,
        assignment_quantity_lineage_md5: "48e433c45fac665d873103542408a484",
      }),
    );
    expect(h.rpcCalls).toEqual([
      {
        schema: "atlas_api",
        name: "get_confirmed_supplier_allocation_workbench",
        request: expect.objectContaining({
          contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
          payload: {
            date_start: "2026-10-12",
            date_end: "2026-10-12",
            school_ids: [],
            states: [],
            search: null,
          },
        }),
      },
    ]);
    expect(h.retry).toHaveBeenCalledExactlyOnceWith(false);
    expect(h.abortSignal).toHaveBeenCalledWith(expect.any(AbortSignal));
    const queries = h.executeSql.mock.calls.map(([, query]) => query);
    expect(queries).toHaveLength(3);
    for (const query of queries) {
      expect(query).toMatch(/^begin read only;/i);
      expect(query).toContain("statement_timeout='8s'");
      expect(query).toContain("lock_timeout='1s'");
      expect(query).not.toMatch(
        /atlas_api\.|prepare_school|executeAcceptance|app_confirm/i,
      );
    }
    const encoded = queries[1].match(
      /decode\('([0-9a-f]+)'\s*,\s*'hex'\)/i,
    )?.[1];
    expect(encoded).toBeTruthy();
    expect(JSON.parse(Buffer.from(encoded, "hex").toString("utf8"))).toEqual(
      h.body,
    );
    expect(h.signOut).toHaveBeenCalledExactlyOnceWith({ scope: "local" });
  });
  it("keeps opt-in dry-run network-free and names its single route", async () => {
    const h = releasedAllocationHarness();
    const plan = await verifyAtlasStagingSchoolFulfilment({
      ...h.options,
      dryRun: true,
    });
    expect(plan.routes).toEqual([
      "get_confirmed_supplier_allocation_workbench",
    ]);
    expect(h.createClientFactory).not.toHaveBeenCalled();
    expect(h.executeSql).not.toHaveBeenCalled();
  });
  it("rejects a wrong target before management SQL or client construction", async () => {
    const h = releasedAllocationHarness();
    await expect(
      verifyAtlasStagingSchoolFulfilment({
        ...h.options,
        environment: {
          ...environment,
          ATLAS_STAGING_PROJECT_REF: "qnthofvccilhnefdcxnz",
          VITE_SUPABASE_URL: "https://qnthofvccilhnefdcxnz.supabase.co",
        },
      }),
    ).rejects.toThrow(/forbidden/i);
    expect(h.createClientFactory).not.toHaveBeenCalled();
    expect(h.executeSql).not.toHaveBeenCalled();
  });
  it.each([
    [
      "migration",
      (h) => {
        h.state.migration_tip = "20261013102219";
      },
    ],
    [
      "released batch",
      (h) => {
        h.state.batch.state = "DRAFT_REVIEW";
      },
    ],
    [
      "batch version",
      (h) => {
        h.state.batch.version = 4;
      },
    ],
    [
      "invalid lineage",
      (h) => {
        h.state.invalid_lineage = 1;
      },
    ],
    [
      "invalid quantities",
      (h) => {
        h.state.invalid_quantities = 1;
      },
    ],
    [
      "missing PO",
      (h) => {
        h.state.po_roots = 16;
      },
    ],
  ])(
    "rejects bad %s preflight before constructing a client",
    async (_name, mutate) => {
      const h = releasedAllocationHarness();
      mutate(h);
      await expect(
        verifyAtlasStagingSchoolFulfilment(h.options),
      ).rejects.toThrow();
      expect(h.createClientFactory).not.toHaveBeenCalled();
      expect(h.rpcCalls).toHaveLength(0);
      expect(h.executeSql).toHaveBeenCalledTimes(2);
    },
  );
  it.each([
    [
      "duplicate family",
      (h) => {
        h.body.rows[1].family.family_id = h.body.rows[0].family.family_id;
      },
    ],
    [
      "response contract",
      (h) => {
        h.body.contract_version = "UNKNOWN.v1";
      },
    ],
    [
      "response start date",
      (h) => {
        h.body.date_start = "2026-10-11";
      },
    ],
    [
      "response end date",
      (h) => {
        h.body.date_end = "2026-10-13";
      },
    ],
    [
      "source fingerprint",
      (h) => {
        h.body.rows[0].source_fingerprint = "not-a-sha256";
      },
    ],
    [
      "family batch lineage",
      (h) => {
        h.body.rows[0].family.source_confirmed_need_batch_id = null;
      },
    ],
    [
      "236 rows",
      (h) => {
        h.body.rows.pop();
      },
    ],
    [
      "corrupt quantity",
      (h) => {
        h.body.rows[0].splits[0].allocated_quantity = "9.999999";
      },
    ],
    [
      "stale source",
      (h) => {
        h.body.rows[0].source_kind = "CONFIRMED_NEED";
      },
    ],
    [
      "missing Handoff",
      (h) => {
        h.body.rows[0].source_purchase_handoff_revision_id = null;
      },
    ],
    [
      "unbalanced state",
      (h) => {
        h.body.rows[0].state = "NEEDS_REALLOCATION";
      },
    ],
    [
      "Preparation version",
      (h) => {
        h.body.preparation.expected_version = 4;
      },
    ],
    [
      "Preparation batch",
      (h) => {
        h.body.preparation.confirmed_need_batch_id = null;
      },
    ],
    [
      "SQL digest",
      (h) => {
        h.setDigest("0".repeat(32));
      },
    ],
    [
      "8s completion",
      (h) => {
        h.options.now = vi
          .fn()
          .mockReturnValueOnce(100)
          .mockReturnValueOnce(8100);
      },
    ],
    [
      "changed source facts",
      (h) => {
        h.setAfter({
          ...structuredClone(h.state),
          fact_digest: "c".repeat(32),
        });
      },
    ],
    [
      "changed receipt",
      (h) => {
        h.setAfter({
          ...structuredClone(h.state),
          receipt: {
            outcome: "COMPLETED",
            response_payload: { success: false },
          },
        });
      },
    ],
  ])(
    "fails closed on %s, performs readonly postflight and signs out",
    async (_name, mutate) => {
      const h = releasedAllocationHarness();
      mutate(h);
      await expect(
        verifyAtlasStagingSchoolFulfilment(h.options),
      ).rejects.toThrow();
      expect(h.rpcCalls).toHaveLength(1);
      expect(h.signOut).toHaveBeenCalledExactlyOnceWith({ scope: "local" });
      expect(h.executeSql.mock.calls.at(-1)[1]).toContain("fact_digest");
    },
  );
  it("encodes apostrophe, backslash, Unicode and dollar quote content as data", async () => {
    const h = releasedAllocationHarness();
    h.body.rows[0].ingredient_name = "O'Brien \\ đường $data$; rollback; --";
    await verifyAtlasStagingSchoolFulfilment(h.options);
    const query = h.executeSql.mock.calls.find(([, sql]) =>
      sql.includes("decode("),
    )[1];
    const hex = query.match(/decode\('([0-9a-f]+)'\s*,\s*'hex'\)/i)[1];
    expect(JSON.parse(Buffer.from(hex, "hex").toString("utf8"))).toEqual(
      h.body,
    );
    expect(query).not.toContain("O'Brien");
    expect(query).not.toContain("$data$");
  });
  it("does not substitute a SQL RPC after HTTP transport failure", async () => {
    const h = releasedAllocationHarness();
    h.retry.mockRejectedValueOnce(new Error("transport unavailable"));
    await expect(
      verifyAtlasStagingSchoolFulfilment(h.options),
    ).rejects.toThrow();
    expect(h.rpcCalls).toHaveLength(1);
    expect(h.executeSql).toHaveBeenCalledTimes(2);
    expect(
      h.executeSql.mock.calls.every(
        ([, query]) => !query.includes("atlas_api."),
      ),
    ).toBe(true);
    expect(h.signOut).toHaveBeenCalledExactlyOnceWith({ scope: "local" });
  });
  it("rejects malformed management evidence without exposing response text", async () => {
    const h = releasedAllocationHarness();
    h.executeSql.mockResolvedValueOnce("untrusted row and token details");
    const failure = await verifyAtlasStagingSchoolFulfilment(h.options).catch(
      (error) => error,
    );
    expect(failure).toBeInstanceOf(Error);
    expect(failure.message).not.toContain("token details");
    expect(h.createClientFactory).not.toHaveBeenCalled();
    expect(h.executeSql).toHaveBeenCalledTimes(2);
  });
  it("attempts postflight and signout after unsuccessful sign-in", async () => {
    const h = releasedAllocationHarness();
    h.client.auth.signInWithPassword.mockResolvedValueOnce({
      data: { session: null },
      error: { message: "private details" },
    });
    await expect(verifyAtlasStagingSchoolFulfilment(h.options)).rejects.toThrow(
      /sign-in failed safely/,
    );
    expect(h.rpcCalls).toHaveLength(0);
    expect(h.executeSql).toHaveBeenCalledTimes(2);
    expect(h.signOut).toHaveBeenCalledExactlyOnceWith({ scope: "local" });
  });
  it("rejects a signout failure without reporting a passing gate", async () => {
    const h = releasedAllocationHarness();
    h.signOut.mockResolvedValueOnce({ error: { message: "private details" } });
    await expect(verifyAtlasStagingSchoolFulfilment(h.options)).rejects.toThrow(
      /session was not cleared/,
    );
    expect(h.executeSql).toHaveBeenCalledTimes(3);
  });
});
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
