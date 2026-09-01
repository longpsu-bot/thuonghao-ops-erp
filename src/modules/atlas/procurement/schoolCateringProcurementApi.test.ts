import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import {
  confirmSupplierRecommendationsRequest,
  createPurchaseOrderDraftsRequest,
  createSchoolCateringProcurementApi,
  purchaseOrdersReadRequest,
  procurementWorkbenchReadRequest,
  releasePurchaseOrderRequest,
  saveSupplierAllocationRequest,
} from "./schoolCateringProcurementApi";
import { createReviewSchoolCateringProcurementApi } from "./reviewSchoolCateringProcurementApi";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("school-catering Procurement API adapter", () => {
  it("builds the exact allocation workbench read envelope", () => {
    expect(
      procurementWorkbenchReadRequest("subject", "correlation", {
        date_start: "2026-09-01",
        date_end: "2026-09-07",
        school_ids: ["school-1", "school-2"],
        states: ["UNALLOCATED", "NEEDS_REALLOCATION"],
        search: "gạo",
      }),
    ).toEqual({
      contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
      requested_by_auth_subject: "subject",
      correlation_id: "correlation",
      payload: {
        date_start: "2026-09-01",
        date_end: "2026-09-07",
        school_ids: ["school-1", "school-2"],
        states: ["UNALLOCATED", "NEEDS_REALLOCATION"],
        search: "gạo",
      },
    });
  });

  it("sends a complete exact-string family split snapshot without client-authored ratios", () => {
    const request = saveSupplierAllocationRequest(
      "subject",
      "correlation",
      4,
      {
        service_date: "2026-09-02",
        delivery_location_id: "location-1",
        ingredient_id: "ingredient-1",
        unit_id: "unit-kg",
        expected_source_fingerprint: "fingerprint-4",
      },
      [
        { supplier_id: "supplier-a", allocated_quantity: "60.000000" },
        { supplier_id: "supplier-b", allocated_quantity: "40.000000" },
      ],
    );

    expect(request).toMatchObject({
      contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
      expected_version: 4,
      reason_code: "SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED",
      reason_note: null,
      payload: {
        family: {
          service_date: "2026-09-02",
          delivery_location_id: "location-1",
          ingredient_id: "ingredient-1",
          unit_id: "unit-kg",
          expected_source_fingerprint: "fingerprint-4",
        },
        splits: [
          { supplier_id: "supplier-a", allocated_quantity: "60.000000" },
          { supplier_id: "supplier-b", allocated_quantity: "40.000000" },
        ],
      },
    });
    expect(request.payload).not.toHaveProperty("split_ratio");
    expect(request.payload.splits).toHaveLength(2);
    expect(request.idempotency_key).toBe(
      `school-catering-allocation:${request.command_id}`,
    );
  });

  it("confirms only the explicit current recommendation candidates", () => {
    const request = confirmSupplierRecommendationsRequest(
      "subject",
      "correlation",
      [
        {
          service_date: "2026-09-02",
          delivery_location_id: "location-1",
          ingredient_id: "ingredient-1",
          unit_id: "unit-kg",
          expected_family_version: 0,
          expected_source_fingerprint: "fingerprint-1",
        },
      ],
    );

    expect(request).toMatchObject({
      expected_version: 1,
      reason_code: "SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED",
      payload: {
        candidates: [
          {
            service_date: "2026-09-02",
            delivery_location_id: "location-1",
            ingredient_id: "ingredient-1",
            unit_id: "unit-kg",
            expected_family_version: 0,
            expected_source_fingerprint: "fingerprint-1",
          },
        ],
      },
    });
  });

  it("builds the exact PO read, draft materialization, and release envelopes", () => {
    expect(
      purchaseOrdersReadRequest("subject", "correlation-read", {
        date_start: "2026-09-01",
        date_end: "2026-09-07",
        supplier_ids: ["supplier-a"],
        statuses: ["DRAFT"],
        search: null,
      }),
    ).toEqual({
      contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
      requested_by_auth_subject: "subject",
      correlation_id: "correlation-read",
      payload: {
        date_start: "2026-09-01",
        date_end: "2026-09-07",
        supplier_ids: ["supplier-a"],
        statuses: ["DRAFT"],
        search: null,
      },
    });

    const drafts = createPurchaseOrderDraftsRequest(
      "subject",
      "correlation-drafts",
      "2026-09-01",
      "2026-09-07",
    );
    expect(drafts).toMatchObject({
      expected_version: 1,
      reason_code: "SCHOOL_CATERING_PO_DRAFTS_CREATED",
      payload: { date_start: "2026-09-01", date_end: "2026-09-07" },
    });

    const release = releasePurchaseOrderRequest(
      "subject",
      "correlation-release",
      3,
      "po-1",
      "po-revision-3",
    );
    expect(release).toMatchObject({
      expected_version: 3,
      reason_code: "SCHOOL_CATERING_PO_RELEASED",
      payload: {
        purchase_order_id: "po-1",
        expected_purchase_order_revision_id: "po-revision-3",
      },
    });
    expect(release.payload).not.toHaveProperty("document_number");
    expect(release.payload).not.toHaveProperty("supplier_id");
    expect(release.payload).not.toHaveProperty("status");
    expect(release.payload).not.toHaveProperty("requested_by_auth_subject");
    expect(Object.keys(release.payload)).toEqual([
      "purchase_order_id",
      "expected_purchase_order_revision_id",
    ]);
  });

  it("routes exactly the six Procurement operations through the reviewed RPC names", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createSchoolCateringProcurementApi({ invoke });
    const allocationRead = procurementWorkbenchReadRequest(
      "subject",
      "read-allocation",
      {
        date_start: "2026-09-01",
        date_end: "2026-09-07",
        school_ids: [],
        states: [],
        search: null,
      },
    );
    const allocation = saveSupplierAllocationRequest(
      "subject",
      "save-allocation",
      0,
      {
        service_date: "2026-09-02",
        delivery_location_id: "location-1",
        ingredient_id: "ingredient-1",
        unit_id: "unit-kg",
        expected_source_fingerprint: "fingerprint-1",
      },
      [{ supplier_id: "supplier-a", allocated_quantity: "100" }],
    );
    const recommendations = confirmSupplierRecommendationsRequest(
      "subject",
      "confirm-recommendations",
      [
        {
          service_date: "2026-09-02",
          delivery_location_id: "location-1",
          ingredient_id: "ingredient-1",
          unit_id: "unit-kg",
          expected_family_version: 0,
          expected_source_fingerprint: "fingerprint-1",
        },
      ],
    );
    const ordersRead = purchaseOrdersReadRequest("subject", "read-orders", {
      date_start: "2026-09-01",
      date_end: "2026-09-07",
      supplier_ids: [],
      statuses: [],
      search: null,
    });
    const drafts = createPurchaseOrderDraftsRequest(
      "subject",
      "create-drafts",
      "2026-09-01",
      "2026-09-07",
    );
    const release = releasePurchaseOrderRequest(
      "subject",
      "release-po",
      1,
      "po-1",
      "revision-1",
    );

    await api.getWorkbench(allocationRead);
    await api.saveAllocation(allocation);
    await api.confirmRecommendations(recommendations);
    await api.getPurchaseOrders(ordersRead);
    await api.createPurchaseOrderDrafts(drafts);
    await api.releasePurchaseOrder(release);

    expect(invoke.mock.calls).toEqual([
      ["atlas_api.get_school_catering_procurement_workbench", allocationRead],
      ["atlas_api.save_school_catering_supplier_allocation", allocation],
      [
        "atlas_api.confirm_school_catering_supplier_recommendations",
        recommendations,
      ],
      ["atlas_api.get_school_catering_purchase_orders", ordersRead],
      ["atlas_api.create_school_catering_purchase_order_drafts", drafts],
      ["atlas_api.release_school_catering_purchase_order", release],
    ]);
  });
});

describe("school-catering Procurement review API", () => {
  it.each([
    ["default", "UNALLOCATED"],
    ["manual_split", "BALANCED"],
    ["unallocated", "UNALLOCATED"],
    ["rebalance", "STALE_REBALANCE_AVAILABLE"],
    ["needs_reallocation", "NEEDS_REALLOCATION"],
  ] as const)(
    "returns the deterministic %s allocation state",
    async (scenario, state) => {
      const api = createReviewSchoolCateringProcurementApi(scenario);
      const result = await api.getWorkbench(
        procurementWorkbenchReadRequest("subject", "correlation", {
          date_start: "2026-09-01",
          date_end: "2026-09-07",
          school_ids: [],
          states: [],
          search: null,
        }),
      );
      expect(result.kind).toBe("success");
      if (result.kind === "success") {
        expect(result.response.rows).toEqual([
          expect.objectContaining({ state }),
        ]);
      }
    },
  );

  it.each([
    ["po_draft", "DRAFT", false],
    ["stale_po", "DRAFT", true],
    ["released_po", "RELEASED_TO_SUPPLIER", false],
  ] as const)(
    "returns the deterministic %s purchase-order state",
    async (scenario, status, stale) => {
      const api = createReviewSchoolCateringProcurementApi(scenario);
      const result = await api.getPurchaseOrders(
        purchaseOrdersReadRequest("subject", "correlation", {
          date_start: "2026-09-01",
          date_end: "2026-09-07",
          supplier_ids: [],
          statuses: [],
          search: null,
        }),
      );
      expect(result.kind).toBe("success");
      if (result.kind === "success") {
        expect(result.response.purchase_orders).toEqual([
          expect.objectContaining({ status, stale }),
        ]);
      }
    },
  );

  it("provides denied, retryable, stale-version, replay, and empty review evidence", async () => {
    const read = procurementWorkbenchReadRequest("subject", "correlation", {
      date_start: "2026-09-01",
      date_end: "2026-09-07",
      school_ids: [],
      states: [],
      search: null,
    });
    await expect(
      createReviewSchoolCateringProcurementApi(
        "permission_denied",
      ).getWorkbench(read),
    ).resolves.toMatchObject({
      kind: "backend_error",
      error: { error_code: "CAPABILITY_DENIED" },
    });
    await expect(
      createReviewSchoolCateringProcurementApi(
        "retryable_failure",
      ).getWorkbench(read),
    ).resolves.toMatchObject({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE" },
    });

    const staleApi = createReviewSchoolCateringProcurementApi("stale_version");
    const save = saveSupplierAllocationRequest(
      "subject",
      "correlation",
      0,
      {
        service_date: "2026-09-02",
        delivery_location_id: "location-1",
        ingredient_id: "ingredient-1",
        unit_id: "unit-kg",
        expected_source_fingerprint: "fingerprint-1",
      },
      [{ supplier_id: "supplier-a", allocated_quantity: "100" }],
    );
    await expect(staleApi.saveAllocation(save)).resolves.toMatchObject({
      kind: "backend_error",
      error: { error_code: "STALE_VERSION" },
    });

    await expect(
      createReviewSchoolCateringProcurementApi("replay_success").saveAllocation(
        save,
      ),
    ).resolves.toMatchObject({
      kind: "success",
      response: { idempotency_status: "REPLAY" },
    });

    const empty =
      await createReviewSchoolCateringProcurementApi("empty").getWorkbench(
        read,
      );
    expect(empty).toMatchObject({
      kind: "success",
      response: { rows: [] },
    });
  });
});
