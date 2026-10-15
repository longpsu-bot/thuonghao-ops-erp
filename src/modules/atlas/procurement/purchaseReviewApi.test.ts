import { describe, expect, it, vi } from "vitest";
import {
  createPurchaseReviewApi,
  supplierAllocationBatchRequest,
  confirmedAllocationReadRequest,
  generatedPurchaseReviewRequest,
  confirmedAllocationRequest,
  preparePurchaseOrdersRequest,
} from "./purchaseReviewApi";

describe("purchase review authority boundaries", () => {
  it("uses a read-only generated request with one service date", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: { success: true } });
    const request = generatedPurchaseReviewRequest(
      "actor",
      "trace",
      "2026-11-02",
    );
    await createPurchaseReviewApi({ invoke }).getGeneratedReview(request);
    expect(invoke).toHaveBeenCalledWith(
      "atlas_api.get_generated_purchase_review",
      request,
    );
    expect(request).toEqual({
      contract_version: "PURCHASE-REVIEW.v1",
      requested_by_auth_subject: "actor",
      correlation_id: "trace",
      payload: { service_date: "2026-11-02" },
    });
    expect(request).not.toHaveProperty("command_id");
  });
  it("preserves exact confirmed source lineage and split strings", () => {
    const request = confirmedAllocationRequest(
      "actor",
      "trace",
      2,
      {
        service_date: "2026-11-02",
        delivery_location_id: "location",
        ingredient_id: "rice",
        unit_id: "kg",
        expected_source_fingerprint: "saved-120",
        expected_source_batch_id: "batch",
        expected_source_batch_version: 3,
      },
      [
        { supplier_id: "A", allocated_quantity: "72.000000" },
        { supplier_id: "B", allocated_quantity: "48.000000" },
      ],
    );
    expect(request).toMatchObject({
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      expected_version: 2,
      reason_code: "CONFIRMED_SUPPLIER_ALLOCATION_SAVED",
      payload: {
        family: {
          expected_source_batch_id: "batch",
          expected_source_batch_version: 3,
        },
        splits: [
          { allocated_quantity: "72.000000" },
          { allocated_quantity: "48.000000" },
        ],
      },
    });
    expect(request.payload).not.toHaveProperty("split_ratio");
  });
  it("prepares only the saved batch/date/version without client-authored lifecycle", () => {
    const request = preparePurchaseOrdersRequest("actor", "trace", {
      service_date: "2026-11-02",
      confirmed_need_batch_id: "batch",
      expected_version: 3,
    });
    expect(request).toMatchObject({
      contract_version: "PURCHASE-COMMITMENT.v1",
      expected_version: 3,
      payload: { service_date: "2026-11-02", confirmed_need_batch_id: "batch" },
    });
    expect(Object.keys(request.payload)).toEqual([
      "service_date",
      "confirmed_need_batch_id",
    ]);
  });
});

describe("optional bulk Allocation", () => {
  it("opts into read-only preview without a command envelope or presentation filters", () => {
    const scope = {
      date_start: "2026-11-02",
      date_end: "2026-11-03",
      school_ids: ["school-a"],
      states: [],
      search: null,
    };
    const request = confirmedAllocationReadRequest(
      "actor",
      "trace",
      scope,
      true,
    );
    expect(request.payload).toEqual({ ...scope, include_bulk_preview: true });
    expect(request).not.toHaveProperty("command_id");
    expect(
      confirmedAllocationReadRequest("actor", "trace", scope).payload,
    ).toEqual(scope);
  });
  it("sends the exact reviewed source/proposal without client arithmetic to one batch RPC", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: { success: true } });
    const candidate = {
      family: {
        service_date: "2026-11-02",
        delivery_location_id: "location",
        ingredient_id: "rice",
        unit_id: "unit",
        source_kind: "CONFIRMED_NEED" as const,
        expected_family_version: 2,
        expected_source_fingerprint: "source",
        expected_source_batch_id: "batch",
        expected_source_batch_version: 3,
      },
      proposal_kind: "REBALANCE" as const,
      proposal_fingerprint: "reviewed",
      proposed_splits: [
        {
          supplier_id: "A",
          allocated_quantity: "72.006001",
          supplier_note: "Keep",
        },
        {
          supplier_id: "B",
          allocated_quantity: "48.003999",
          supplier_note: null,
        },
      ],
    };
    const scope = {
      date_start: "2026-11-02",
      date_end: "2026-11-02",
      school_ids: ["school-a"],
    };
    const request = supplierAllocationBatchRequest("actor", "trace", scope, [
      candidate,
    ]);
    expect(request.payload).toEqual({ scope, candidates: [candidate] });
    expect(request).toMatchObject({
      contract_version: "SUPPLIER-ALLOCATION-BATCH.v1",
      expected_version: 1,
      reason_code: "SUPPLIER_ALLOCATION_BATCH_APPLIED",
    });
    await createPurchaseReviewApi({ invoke }).applyAllocationBatch(request);
    expect(invoke).toHaveBeenCalledExactlyOnceWith(
      "atlas_api.apply_supplier_allocation_batch",
      request,
    );
  });
});
