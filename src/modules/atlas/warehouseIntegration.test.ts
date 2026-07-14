import "@testing-library/jest-dom/vitest";
import { createElement } from "react";
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { WarehouseWorkbench } from "../warehouse/WarehouseWorkbench";
import {
  CreateReceivingSessionFromSupplierConfirmedPO,
  CreateStockFromGoodsReceipt,
  RecordReceivingDiscrepancy,
  RecordReceivingLine,
  ReleaseGoodsReceipt,
  StartReceivingSession,
  ValidateReceivingSession,
  type WarehouseUpstreamSnapshot,
} from "../warehouse/warehouseDomain";
import { supplierConfirmedPurchaseOrderFixture } from "../warehouse/warehouseFixtures";

const actor = "warehouse-mai";
const at = "2026-07-14T03:30:00.000Z";
const traceFields: readonly (keyof WarehouseUpstreamSnapshot)[] = [
  "purchaseOrderId",
  "purchaseOrderVersion",
  "purchaseOrderLineId",
  "purchaseAllocationLineId",
  "purchaseHandoffLineId",
  "confirmedNeedLineId",
  "needGenerationRunId",
  "planningInputSetId",
  "sourceTraceId",
  "supplierId",
  "supplierConfirmationReference",
  "releaseSnapshotReference",
  "ingredientId",
  "supplierConfirmedQuantity",
  "purchaseUnit",
];

describe("PD-03 Procurement to Warehouse integration conformance", () => {
  it("accepts only a supplier-confirmed PO ready for Warehouse handoff", () => {
    for (const purchaseOrder of [
      { ...supplierConfirmedPurchaseOrderFixture, status: "DRAFT" as const },
      {
        ...supplierConfirmedPurchaseOrderFixture,
        status: "RELEASED_TO_SUPPLIER" as const,
      },
      { ...supplierConfirmedPurchaseOrderFixture, confirmationHistory: [] },
    ]) {
      expect(
        CreateReceivingSessionFromSupplierConfirmedPO(purchaseOrder, actor, at)
          .accepted,
      ).toBe(false);
    }
  });

  it("preserves Procurement and Planning trace without rewriting upstream commitments", () => {
    const procurementBefore = JSON.stringify(
      supplierConfirmedPurchaseOrderFixture,
    );
    const planningBefore = supplierConfirmedPurchaseOrderFixture.lines.map(
      (line) => line.purchaseDemandReference,
    );
    let session = StartReceivingSession(
      CreateReceivingSessionFromSupplierConfirmedPO(
        supplierConfirmedPurchaseOrderFixture,
        actor,
        at,
      ).value!,
      actor,
      at,
    ).value!;

    session = session.lines.reduce(
      (current, line) =>
        RecordReceivingLine(
          current,
          {
            receivingLineId: line.receivingLineId,
            receivedQuantity: line.supplierConfirmedQuantity,
            acceptedQuantity: line.supplierConfirmedQuantity,
            rejectedQuantity: 0,
            purchaseUnit: line.purchaseUnit,
            supplierDocumentReference: "delivery-note-51",
            locationId: "warehouse-a",
            lotReference: `lot-${line.ingredientId}`,
          },
          actor,
          at,
        ).value!,
      session,
    );
    session = RecordReceivingDiscrepancy(
      session,
      {
        receivingLineId: session.lines[0].receivingLineId,
        type: "MISSING_DOCUMENT",
        note: "Warehouse warning only; Procurement commitment is unchanged.",
      },
      actor,
      at,
    ).value!;
    const validation = ValidateReceivingSession(session, actor, at);
    const validated = validation.value!;
    const released = ReleaseGoodsReceipt(validated, actor, at).value!;
    const stockLots = CreateStockFromGoodsReceipt(released.goodsReceipt).value!;

    expect(JSON.stringify(supplierConfirmedPurchaseOrderFixture)).toBe(
      procurementBefore,
    );
    expect(
      supplierConfirmedPurchaseOrderFixture.lines.map(
        (line) => line.purchaseDemandReference,
      ),
    ).toEqual(planningBefore);

    for (const [index, line] of released.goodsReceipt.lines.entries()) {
      const stockLot = stockLots[index];
      for (const field of traceFields) {
        expect(line[field]).toBeDefined();
        expect(stockLot[field]).toBe(line[field]);
      }
      expect(line.purchaseOrderId).toBe(
        supplierConfirmedPurchaseOrderFixture.purchaseOrderId,
      );
      expect(line.purchaseOrderLineId).toBe(
        supplierConfirmedPurchaseOrderFixture.lines[index].purchaseOrderLineId,
      );
      expect(line.planningInputSetId).toBe(
        supplierConfirmedPurchaseOrderFixture.lines[index]
          .purchaseDemandReference.planningInputSetId,
      );
    }
    expect(validation.warnings.map((warning) => warning.issueCode)).toContain(
      "MISSING_SUPPLIER_DOCUMENT",
    );
  });

  it("does not create downstream, QA, Finance, or production behavior", () => {
    const session = CreateReceivingSessionFromSupplierConfirmedPO(
      supplierConfirmedPurchaseOrderFixture,
      actor,
      at,
    ).value!;
    const forbiddenFields = [
      "dispatchDeliveryConfirmationId",
      "dispatchId",
      "qaApprovalId",
      "foodSafetyDecisionId",
      "invoiceId",
      "payableId",
      "settlementId",
      "accountingEntryId",
      "supabaseClient",
      "retoolQuery",
      "productionDataId",
    ];
    for (const value of [session, ...session.lines])
      for (const field of forbiddenFields) expect(field in value).toBe(false);
  });

  it("keeps the React workbench command-gated", () => {
    render(createElement(WarehouseWorkbench));
    expect(
      screen.getByRole("button", { name: "Start receiving session" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", {
        name: "Record sample receiving evidence",
      }),
    ).not.toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: "Start receiving session" }),
    );
    expect(
      screen.getByRole("button", { name: "Record sample receiving evidence" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Release goods receipt" }),
    ).not.toBeInTheDocument();
  });
});
