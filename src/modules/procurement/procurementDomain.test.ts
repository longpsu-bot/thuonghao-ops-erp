import { describe, expect, it } from "vitest";
import { preparedPurchaseHandoffFixture } from "../purchase-handoff/purchaseHandoffFixtures";
import {
  ApprovePurchaseAllocation,
  AssignSupplierToDemandLine,
  CancelPurchaseOrder,
  CreatePurchaseAllocationFromHandoff,
  CreatePurchaseOrderDrafts,
  RecordSupplierConfirmation,
  ReleasePurchaseOrderToSupplier,
  ReopenPurchaseOrder,
  ReplaceSupplier,
  ValidatePurchaseAllocation,
  ValidatePurchaseOrder,
} from "./procurementDomain";
import {
  approvedPurchaseAllocationFixture,
  blockerPurchaseAllocationFixture,
  preparedPurchaseAllocationFixture,
  purchaseOrderDraftFixtures,
  releasedPurchaseHandoffFixture,
  releasedPurchaseOrderFixture,
  successfulPurchaseAllocationFixture,
  supplierFixtures,
  supplierReplacementFixture,
} from "./procurementFixtures";

const actor = "buyer-minh";
const at = "2026-07-14T03:00:00.000Z";

describe("Procurement foundation", () => {
  it("creates allocation only from released Purchase Handoff", () => {
    expect(
      CreatePurchaseAllocationFromHandoff({
        purchaseAllocationBatchId: "rejected-allocation",
        purchaseHandoffBatch: preparedPurchaseHandoffFixture,
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
    const accepted = CreatePurchaseAllocationFromHandoff({
      purchaseAllocationBatchId: "accepted-allocation",
      purchaseHandoffBatch: releasedPurchaseHandoffFixture,
      actorId: actor,
      at,
    });
    expect(accepted.accepted).toBe(true);
    expect(accepted.batch?.purchaseHandoffReference).toMatchObject({
      purchaseHandoffBatchId:
        releasedPurchaseHandoffFixture.purchaseHandoffBatchId,
      releasedVersion: 1,
    });
  });

  it("preserves Planning demand references during supplier assignment", () => {
    const source = preparedPurchaseAllocationFixture.lines[0];
    const result = AssignSupplierToDemandLine(
      preparedPurchaseAllocationFixture,
      {
        purchaseAllocationLineId: source.purchaseAllocationLineId,
        supplier: supplierFixtures[0],
        assignedQuantity: source.demandQuantity,
        expectedDemandQuantity: source.demandQuantity,
        actorId: actor,
        at,
        reasonCode: "preferred_supplier",
      },
    );
    const assigned = result.batch!.lines[0];
    expect(assigned.demandQuantity).toBe(source.demandQuantity);
    expect(assigned.purchaseDemandReference).toEqual(
      source.purchaseDemandReference,
    );
    expect(assigned).toMatchObject({
      purchaseHandoffLineId: source.purchaseHandoffLineId,
      confirmedNeedLineId: source.confirmedNeedLineId,
      sourceTraceId: source.sourceTraceId,
      supplierId: supplierFixtures[0].supplierId,
    });
  });

  it("does not let supplier assignment change Planning-approved demand", () => {
    const line = preparedPurchaseAllocationFixture.lines[0];
    expect(
      AssignSupplierToDemandLine(preparedPurchaseAllocationFixture, {
        purchaseAllocationLineId: line.purchaseAllocationLineId,
        supplier: supplierFixtures[0],
        assignedQuantity: line.demandQuantity,
        expectedDemandQuantity: line.demandQuantity + 1,
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
    expect(
      AssignSupplierToDemandLine(preparedPurchaseAllocationFixture, {
        purchaseAllocationLineId: line.purchaseAllocationLineId,
        supplier: supplierFixtures[0],
        assignedQuantity: line.demandQuantity + 1,
        expectedDemandQuantity: line.demandQuantity,
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
  });

  it("blocks missing, inactive, and ineligible suppliers", () => {
    const missing = ValidatePurchaseAllocation(
      preparedPurchaseAllocationFixture,
      supplierFixtures,
      actor,
      at,
    );
    expect(missing.accepted).toBe(false);
    expect(missing.batch?.issues.map((issue) => issue.issueCode)).toContain(
      "SUPPLIER_MISSING",
    );
    const blocked = ValidatePurchaseAllocation(
      blockerPurchaseAllocationFixture,
      supplierFixtures,
      actor,
      at,
    );
    expect(blocked.accepted).toBe(false);
    expect(blocked.batch?.issues.map((issue) => issue.issueCode)).toEqual(
      expect.arrayContaining(["SUPPLIER_INACTIVE", "SUPPLIER_INELIGIBLE"]),
    );
  });

  it("approves allocation only after successful validation and snapshots it", () => {
    expect(
      ApprovePurchaseAllocation(successfulPurchaseAllocationFixture, actor, at)
        .accepted,
    ).toBe(false);
    const validated = ValidatePurchaseAllocation(
      successfulPurchaseAllocationFixture,
      supplierFixtures,
      actor,
      at,
    ).batch!;
    const approved = ApprovePurchaseAllocation(validated, actor, at).batch!;
    expect(approved.status).toBe("APPROVED");
    expect(approved.approvedSnapshots).toHaveLength(1);
    expect(approved.approvedSnapshots[0].lines[0]).toMatchObject({
      purchaseHandoffLineId: approved.lines[0].purchaseHandoffLineId,
      confirmedNeedLineId: approved.lines[0].confirmedNeedLineId,
      demandQuantity: approved.lines[0].demandQuantity,
    });
  });

  it("creates supplier-grouped PO drafts only from approved allocation", () => {
    expect(
      CreatePurchaseOrderDrafts(
        successfulPurchaseAllocationFixture,
        supplierFixtures,
        actor,
        at,
      ).accepted,
    ).toBe(false);
    const result = CreatePurchaseOrderDrafts(
      approvedPurchaseAllocationFixture,
      supplierFixtures,
      actor,
      at,
    );
    expect(result.accepted).toBe(true);
    expect(result.allocationBatch?.status).toBe("RELEASED_TO_PO_DRAFTING");
    expect(result.drafts).toHaveLength(1);
    expect(result.drafts[0].lines[0]).toMatchObject({
      purchaseAllocationLineId:
        approvedPurchaseAllocationFixture.lines[0].purchaseAllocationLineId,
      purchaseHandoffLineId:
        approvedPurchaseAllocationFixture.lines[0].purchaseHandoffLineId,
      confirmedNeedLineId:
        approvedPurchaseAllocationFixture.lines[0].confirmedNeedLineId,
    });
  });

  it("requires PO validation before release and release before confirmation", () => {
    const draft = purchaseOrderDraftFixtures[0];
    expect(ReleasePurchaseOrderToSupplier(draft, actor, at).accepted).toBe(
      false,
    );
    expect(
      RecordSupplierConfirmation(draft, {
        confirmationStatus: "ACCEPTED",
        confirmedBy: "supplier-contact",
        at,
        confirmedLineIds: draft.lines.map((line) => line.purchaseOrderLineId),
      }).accepted,
    ).toBe(false);
    const validated = ValidatePurchaseOrder(
      draft,
      supplierFixtures,
      actor,
      at,
    ).purchaseOrder!;
    const released = ReleasePurchaseOrderToSupplier(
      validated,
      actor,
      at,
    ).purchaseOrder!;
    const confirmed = RecordSupplierConfirmation(released, {
      confirmationStatus: "ACCEPTED",
      confirmedBy: "supplier-contact",
      at,
      confirmedLineIds: released.lines.map((line) => line.purchaseOrderLineId),
    }).purchaseOrder!;
    expect(confirmed.status).toBe("READY_FOR_WAREHOUSE_RECEIVING");
    expect(confirmed.confirmationHistory).toHaveLength(1);
  });

  it("requires a reason for replacement and preserves released history", () => {
    expect(
      ReplaceSupplier(releasedPurchaseOrderFixture, {
        newSupplier: supplierFixtures[1],
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
    expect(supplierReplacementFixture.status).toBe("REVISED");
    expect(supplierReplacementFixture.version).toBe(2);
    expect(supplierReplacementFixture.releaseSnapshots).toEqual(
      releasedPurchaseOrderFixture.releaseSnapshots,
    );
    expect(supplierReplacementFixture.revisionHistory.at(-1)).toMatchObject({
      oldSupplierId: supplierFixtures[0].supplierId,
      newSupplierId: supplierFixtures[1].supplierId,
      beforeQuantity:
        supplierReplacementFixture.revisionHistory.at(-1)?.afterQuantity,
    });
  });

  it("reopens or cancels with reasons while preserving release snapshots", () => {
    expect(
      ReopenPurchaseOrder(releasedPurchaseOrderFixture, "", actor, at).accepted,
    ).toBe(false);
    const reopened = ReopenPurchaseOrder(
      releasedPurchaseOrderFixture,
      "Supplier requested correction",
      actor,
      at,
    ).purchaseOrder!;
    expect(reopened.status).toBe("REOPENED");
    expect(reopened.releaseSnapshots).toEqual(
      releasedPurchaseOrderFixture.releaseSnapshots,
    );
    const cancelled = CancelPurchaseOrder(
      releasedPurchaseOrderFixture,
      "Supplier cannot fulfil",
      actor,
      at,
    ).purchaseOrder!;
    expect(cancelled.status).toBe("CANCELLED");
    expect(cancelled.cancellationSnapshots.at(-1)).toMatchObject({
      reason: "Supplier cannot fulfil",
      priorReleaseSnapshotCount: 1,
    });
  });

  it("introduces no Warehouse, Dispatch, QA, Finance, or Accounting state", () => {
    const purchaseOrder = releasedPurchaseOrderFixture as unknown as Record<
      string,
      unknown
    >;
    const line = releasedPurchaseOrderFixture.lines[0] as unknown as Record<
      string,
      unknown
    >;
    [
      "warehouseReceiptId",
      "receivedQuantity",
      "dispatchId",
      "qaApprovalId",
      "invoiceId",
      "accountingEntryId",
    ].forEach((field) => {
      expect(field in purchaseOrder).toBe(false);
      expect(field in line).toBe(false);
    });
  });

  it("blocks attempts to inject Warehouse receiving state into a PO", () => {
    const draft = {
      ...purchaseOrderDraftFixtures[0],
      warehouseReceiptId: "receipt-not-allowed",
      lines: purchaseOrderDraftFixtures[0].lines.map((line) => ({
        ...line,
        receivedQuantity: line.quantity,
      })),
    } as unknown as (typeof purchaseOrderDraftFixtures)[number];
    const result = ValidatePurchaseOrder(draft, supplierFixtures, actor, at);
    expect(result.accepted).toBe(false);
    expect(
      result.purchaseOrder?.issues.map((issue) => issue.issueCode),
    ).toEqual(expect.arrayContaining(["FORBIDDEN_WAREHOUSE_FIELD"]));
  });
});
