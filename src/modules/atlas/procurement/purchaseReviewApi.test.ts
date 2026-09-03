import { describe, expect, it, vi } from "vitest";
import {
  createPurchaseReviewApi,
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
