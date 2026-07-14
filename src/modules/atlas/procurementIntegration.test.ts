import { describe, expect, it } from "vitest";
import {
  ReleasePurchaseHandoffToProcurement,
  ValidatePurchaseHandoff,
} from "../purchase-handoff/purchaseHandoffDomain";
import { preparedPurchaseHandoffFixture } from "../purchase-handoff/purchaseHandoffFixtures";
import {
  ApprovePurchaseAllocation,
  AssignSupplierToDemandLine,
  CreatePurchaseAllocationFromHandoff,
  CreatePurchaseOrderDrafts,
  RecordSupplierConfirmation,
  ReleasePurchaseOrderToSupplier,
  ValidatePurchaseAllocation,
  ValidatePurchaseOrder,
  type PurchaseAllocationBatch,
} from "../procurement/procurementDomain";
import { supplierFixtures } from "../procurement/procurementFixtures";

const planner = "planner-lan";
const buyer = "buyer-minh";
const manager = "procurement-manager-an";

function assignReleasedDemand(batch: PurchaseAllocationBatch) {
  return batch.lines.reduce((current, line, index) => {
    const result = AssignSupplierToDemandLine(current, {
      purchaseAllocationLineId: line.purchaseAllocationLineId,
      supplier: supplierFixtures[0],
      assignedQuantity: line.demandQuantity,
      expectedDemandQuantity: line.demandQuantity,
      actorId: buyer,
      at: `2026-07-14T02:${String(index + 1).padStart(2, "0")}:00.000Z`,
      reasonCode: "preferred_supplier",
    });
    expect(result.accepted).toBe(true);
    return result.batch!;
  }, batch);
}

describe("PD-02 Planning to Procurement integration conformance", () => {
  it("converts released Purchase Handoff demand into a traceable supplier commitment", () => {
    const validatedHandoff = ValidatePurchaseHandoff(
      preparedPurchaseHandoffFixture,
      planner,
      "2026-07-14T01:40:00.000Z",
    ).batch!;
    const releasedHandoff = ReleasePurchaseHandoffToProcurement(
      validatedHandoff,
      planner,
      "2026-07-14T01:45:00.000Z",
    ).batch!;
    const planningDemandBeforeProcurement = releasedHandoff.lines.map(
      (line) => ({
        purchaseHandoffLineId: line.purchaseHandoffLineId,
        confirmedNeedLineId: line.confirmedNeedLineId,
        quantity: line.quantity,
        purchaseUnit: line.purchaseUnit,
        sourceTraceId: line.sourceTraceId,
        purchaseDemandReference: line.purchaseDemandReference,
      }),
    );

    const preparedAllocation = CreatePurchaseAllocationFromHandoff({
      purchaseAllocationBatchId: "allocation-2026-29-v1",
      purchaseHandoffBatch: releasedHandoff,
      actorId: buyer,
      at: "2026-07-14T02:00:00.000Z",
    }).batch!;
    const assignedAllocation = assignReleasedDemand(preparedAllocation);
    const validatedAllocation = ValidatePurchaseAllocation(
      assignedAllocation,
      supplierFixtures,
      buyer,
      "2026-07-14T02:10:00.000Z",
    ).batch!;
    const approvedAllocation = ApprovePurchaseAllocation(
      validatedAllocation,
      manager,
      "2026-07-14T02:15:00.000Z",
    ).batch!;
    const draftResult = CreatePurchaseOrderDrafts(
      approvedAllocation,
      supplierFixtures,
      buyer,
      "2026-07-14T02:20:00.000Z",
    );
    const validatedOrder = ValidatePurchaseOrder(
      draftResult.drafts[0],
      supplierFixtures,
      buyer,
      "2026-07-14T02:25:00.000Z",
    ).purchaseOrder!;
    const releasedOrder = ReleasePurchaseOrderToSupplier(
      validatedOrder,
      buyer,
      "2026-07-14T02:30:00.000Z",
    ).purchaseOrder!;
    const confirmedOrder = RecordSupplierConfirmation(releasedOrder, {
      confirmationStatus: "ACCEPTED",
      confirmedBy: "supplier-contact",
      at: "2026-07-14T02:35:00.000Z",
      confirmedLineIds: releasedOrder.lines.map(
        (line) => line.purchaseOrderLineId,
      ),
    }).purchaseOrder!;

    expect(draftResult.accepted).toBe(true);
    expect(draftResult.allocationBatch?.status).toBe("RELEASED_TO_PO_DRAFTING");
    expect(releasedOrder.status).toBe("RELEASED_TO_SUPPLIER");
    expect(releasedOrder.releaseSnapshots).toHaveLength(1);
    expect(confirmedOrder.status).toBe("READY_FOR_WAREHOUSE_RECEIVING");
    expect(confirmedOrder.confirmationHistory).toHaveLength(1);

    for (const sourceLine of planningDemandBeforeProcurement) {
      const allocationLine = approvedAllocation.lines.find(
        (line) =>
          line.purchaseHandoffLineId === sourceLine.purchaseHandoffLineId,
      );
      const purchaseOrderLine = releasedOrder.lines.find(
        (line) =>
          line.purchaseHandoffLineId === sourceLine.purchaseHandoffLineId,
      );
      expect(allocationLine).toMatchObject({
        confirmedNeedLineId: sourceLine.confirmedNeedLineId,
        demandQuantity: sourceLine.quantity,
        purchaseUnit: sourceLine.purchaseUnit,
        sourceTraceId: sourceLine.sourceTraceId,
        purchaseDemandReference: sourceLine.purchaseDemandReference,
        supplierId: supplierFixtures[0].supplierId,
      });
      expect(purchaseOrderLine).toMatchObject({
        purchaseAllocationLineId: allocationLine?.purchaseAllocationLineId,
        confirmedNeedLineId: sourceLine.confirmedNeedLineId,
        demandQuantity: sourceLine.quantity,
        quantity: sourceLine.quantity,
        purchaseUnit: sourceLine.purchaseUnit,
        sourceTraceId: sourceLine.sourceTraceId,
        purchaseDemandReference: sourceLine.purchaseDemandReference,
        supplierId: supplierFixtures[0].supplierId,
      });
    }

    expect(
      releasedHandoff.lines.map((line) => ({
        purchaseHandoffLineId: line.purchaseHandoffLineId,
        confirmedNeedLineId: line.confirmedNeedLineId,
        quantity: line.quantity,
        purchaseUnit: line.purchaseUnit,
        sourceTraceId: line.sourceTraceId,
        purchaseDemandReference: line.purchaseDemandReference,
      })),
    ).toEqual(planningDemandBeforeProcurement);
  });

  it("preserves command gates and domain ownership across the boundary", () => {
    expect(
      CreatePurchaseAllocationFromHandoff({
        purchaseAllocationBatchId: "allocation-bypass",
        purchaseHandoffBatch: preparedPurchaseHandoffFixture,
        actorId: buyer,
        at: "2026-07-14T02:00:00.000Z",
      }).accepted,
    ).toBe(false);

    const releasedHandoff = ReleasePurchaseHandoffToProcurement(
      ValidatePurchaseHandoff(
        preparedPurchaseHandoffFixture,
        planner,
        "2026-07-14T01:40:00.000Z",
      ).batch!,
      planner,
      "2026-07-14T01:45:00.000Z",
    ).batch!;
    const preparedAllocation = CreatePurchaseAllocationFromHandoff({
      purchaseAllocationBatchId: "allocation-gates",
      purchaseHandoffBatch: releasedHandoff,
      actorId: buyer,
      at: "2026-07-14T02:00:00.000Z",
    }).batch!;

    expect(
      CreatePurchaseOrderDrafts(
        preparedAllocation,
        supplierFixtures,
        buyer,
        "2026-07-14T02:05:00.000Z",
      ).accepted,
    ).toBe(false);
    const sourceLine = preparedAllocation.lines[0];
    const changedDemand = AssignSupplierToDemandLine(preparedAllocation, {
      purchaseAllocationLineId: sourceLine.purchaseAllocationLineId,
      supplier: supplierFixtures[0],
      assignedQuantity: sourceLine.demandQuantity,
      expectedDemandQuantity: sourceLine.demandQuantity + 1,
      actorId: buyer,
      at: "2026-07-14T02:06:00.000Z",
    });
    expect(changedDemand.accepted).toBe(false);
    expect(changedDemand.batch?.lines[0].demandQuantity).toBe(
      sourceLine.demandQuantity,
    );

    const assignedAllocation = assignReleasedDemand(preparedAllocation);
    expect(
      releasedHandoff.lines.every(
        (line) => !("supplierId" in line) && !("purchaseOrderId" in line),
      ),
    ).toBe(true);
    expect(
      assignedAllocation.lines.every(
        (line) => line.supplierId === supplierFixtures[0].supplierId,
      ),
    ).toBe(true);

    const approvedAllocation = ApprovePurchaseAllocation(
      ValidatePurchaseAllocation(
        assignedAllocation,
        supplierFixtures,
        buyer,
        "2026-07-14T02:10:00.000Z",
      ).batch!,
      manager,
      "2026-07-14T02:15:00.000Z",
    ).batch!;
    const draft = CreatePurchaseOrderDrafts(
      approvedAllocation,
      supplierFixtures,
      buyer,
      "2026-07-14T02:20:00.000Z",
    ).drafts[0];

    expect(
      ReleasePurchaseOrderToSupplier(draft, buyer, "2026-07-14T02:21:00.000Z")
        .accepted,
    ).toBe(false);
    expect(
      RecordSupplierConfirmation(draft, {
        confirmationStatus: "ACCEPTED",
        confirmedBy: "supplier-contact",
        at: "2026-07-14T02:22:00.000Z",
        confirmedLineIds: draft.lines.map((line) => line.purchaseOrderLineId),
      }).accepted,
    ).toBe(false);

    const validatedOrder = ValidatePurchaseOrder(
      draft,
      supplierFixtures,
      buyer,
      "2026-07-14T02:25:00.000Z",
    ).purchaseOrder!;
    const releasedOrder = ReleasePurchaseOrderToSupplier(
      validatedOrder,
      buyer,
      "2026-07-14T02:30:00.000Z",
    ).purchaseOrder!;
    const confirmedOrder = RecordSupplierConfirmation(releasedOrder, {
      confirmationStatus: "ACCEPTED",
      confirmedBy: "supplier-contact",
      at: "2026-07-14T02:35:00.000Z",
      confirmedLineIds: releasedOrder.lines.map(
        (line) => line.purchaseOrderLineId,
      ),
    }).purchaseOrder!;

    const forbiddenFields = [
      "warehouseReceiptId",
      "receivedQuantity",
      "stockMovementId",
      "dispatchId",
      "qaApprovalId",
      "invoiceId",
      "accountingEntryId",
    ];
    for (const value of [confirmedOrder, ...confirmedOrder.lines]) {
      for (const field of forbiddenFields) expect(field in value).toBe(false);
    }
    expect(confirmedOrder.releaseSnapshots[0]).toMatchObject({
      supplierId: supplierFixtures[0].supplierId,
      releasedBy: buyer,
    });
    expect(confirmedOrder.readyForWarehouseReceivingAt).toBe(
      "2026-07-14T02:35:00.000Z",
    );
  });
});
