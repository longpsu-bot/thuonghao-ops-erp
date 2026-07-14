import { describe, expect, it } from "vitest";
import {
  CreateReceivingSessionFromSupplierConfirmedPO,
  CreateStockFromGoodsReceipt,
  RecordReceivingDiscrepancy,
  RecordReceivingLine,
  ReleaseGoodsReceipt,
  StartReceivingSession,
  ValidateReceivingSession,
  type ReceivingSession,
  type WarehouseIssueCode,
  type WarehouseUpstreamSnapshot,
} from "./warehouseDomain";
import { supplierConfirmedPurchaseOrderFixture } from "./warehouseFixtures";

const actor = "warehouse-mai";
const at = "2026-07-14T03:10:00.000Z";
const upstreamFields: readonly (keyof WarehouseUpstreamSnapshot)[] = [
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

function prepared() {
  return CreateReceivingSessionFromSupplierConfirmedPO(
    supplierConfirmedPurchaseOrderFixture,
    actor,
    at,
  ).value!;
}

function started() {
  return StartReceivingSession(prepared(), actor, at).value!;
}

function issueCodes(result: {
  blockers: readonly { issueCode: WarehouseIssueCode }[];
  warnings: readonly { issueCode: WarehouseIssueCode }[];
}) {
  return [...result.blockers, ...result.warnings].map(
    (candidate) => candidate.issueCode,
  );
}

function recordExpectedLines(session: ReceivingSession) {
  return session.lines.reduce((current, line) => {
    return RecordReceivingLine(
      current,
      {
        receivingLineId: line.receivingLineId,
        receivedQuantity: line.supplierConfirmedQuantity,
        acceptedQuantity: line.supplierConfirmedQuantity,
        rejectedQuantity: 0,
        purchaseUnit: line.purchaseUnit,
        supplierDocumentReference: "delivery-note-49",
        locationId: "cold-a",
        lotReference: `lot-${line.ingredientId}`,
      },
      actor,
      at,
    ).value!;
  }, session);
}

describe("Warehouse receiving foundation", () => {
  it("blocks missing or unready Procurement handoff evidence", () => {
    const cases = [
      {
        po: { ...supplierConfirmedPurchaseOrderFixture, purchaseOrderId: "" },
        code: "MISSING_PO",
      },
      {
        po: {
          ...supplierConfirmedPurchaseOrderFixture,
          status: "RELEASED_TO_SUPPLIER" as const,
        },
        code: "PO_NOT_READY",
      },
      {
        po: { ...supplierConfirmedPurchaseOrderFixture, releaseSnapshots: [] },
        code: "MISSING_RELEASE_SNAPSHOT",
      },
      {
        po: {
          ...supplierConfirmedPurchaseOrderFixture,
          confirmationHistory: [],
        },
        code: "MISSING_SUPPLIER_CONFIRMATION",
      },
    ] as const;
    for (const testCase of cases) {
      const result = CreateReceivingSessionFromSupplierConfirmedPO(
        testCase.po,
        actor,
        at,
      );
      expect(result.accepted).toBe(false);
      expect(issueCodes(result)).toContain(testCase.code);
    }
  });

  it("preserves the complete upstream snapshot on receiving lines", () => {
    const created = CreateReceivingSessionFromSupplierConfirmedPO(
      supplierConfirmedPurchaseOrderFixture,
      actor,
      at,
    );
    expect(created.accepted).toBe(true);
    const line = created.value!.lines[0];
    for (const field of upstreamFields) expect(line[field]).not.toBe("");
    expect(line).toMatchObject({
      purchaseOrderId: supplierConfirmedPurchaseOrderFixture.purchaseOrderId,
      purchaseOrderVersion: supplierConfirmedPurchaseOrderFixture.version,
      supplierId: supplierConfirmedPurchaseOrderFixture.supplierId,
      purchaseOrderLineId:
        supplierConfirmedPurchaseOrderFixture.lines[0].purchaseOrderLineId,
      sourceTraceId:
        supplierConfirmedPurchaseOrderFixture.lines[0].sourceTraceId,
    });
  });

  it("blocks a missing required upstream trace field", () => {
    const session = started();
    const damaged: ReceivingSession = {
      ...session,
      lines: session.lines.map((line, index) =>
        index === 0 ? { ...line, planningInputSetId: "" } : line,
      ),
    };
    const result = ValidateReceivingSession(damaged, actor, at);
    expect(result.accepted).toBe(false);
    expect(issueCodes(result)).toContain("MISSING_REQUIRED_UPSTREAM_TRACE");
  });

  it("blocks unknown receiving lines for evidence and discrepancies", () => {
    const session = started();
    const evidence = RecordReceivingLine(
      session,
      {
        receivingLineId: "unknown-line",
        receivedQuantity: 1,
        acceptedQuantity: 1,
        rejectedQuantity: 0,
        purchaseUnit: "kg",
      },
      actor,
      at,
    );
    const discrepancy = RecordReceivingDiscrepancy(
      session,
      {
        receivingLineId: "unknown-line",
        type: "SHORTAGE",
        note: "not a real PO line",
      },
      actor,
      at,
    );
    expect(evidence.accepted).toBe(false);
    expect(discrepancy.accepted).toBe(false);
    expect(issueCodes(discrepancy)).toContain("MISSING_PO_LINE_REFERENCE");
  });

  it.each([
    {
      name: "negative received quantity",
      receivedQuantity: -1,
      acceptedQuantity: 0,
      rejectedQuantity: 0,
      purchaseUnit: "kg",
      code: "NEGATIVE_QUANTITY",
    },
    {
      name: "negative accepted quantity",
      receivedQuantity: 1,
      acceptedQuantity: -1,
      rejectedQuantity: 0,
      purchaseUnit: "kg",
      code: "NEGATIVE_QUANTITY",
    },
    {
      name: "negative rejected quantity",
      receivedQuantity: 1,
      acceptedQuantity: 0,
      rejectedQuantity: -1,
      purchaseUnit: "kg",
      code: "NEGATIVE_QUANTITY",
    },
    {
      name: "accepted plus rejected above received",
      receivedQuantity: 1,
      acceptedQuantity: 1,
      rejectedQuantity: 1,
      purchaseUnit: "kg",
      code: "ACCEPTED_REJECTED_EXCEED_RECEIVED",
    },
    {
      name: "unit mismatch without conversion evidence",
      receivedQuantity: 1,
      acceptedQuantity: 1,
      rejectedQuantity: 0,
      purchaseUnit: "case",
      code: "UNIT_MISMATCH",
    },
  ])("blocks $name", (testCase) => {
    const session = started();
    const line = session.lines[0];
    const result = RecordReceivingLine(
      session,
      {
        receivingLineId: line.receivingLineId,
        receivedQuantity: testCase.receivedQuantity,
        acceptedQuantity: testCase.acceptedQuantity,
        rejectedQuantity: testCase.rejectedQuantity,
        purchaseUnit: testCase.purchaseUnit,
      },
      actor,
      at,
    );
    expect(result.accepted).toBe(false);
    expect(issueCodes(result)).toContain(testCase.code);
  });

  it.each([
    {
      name: "shortage",
      quantityDelta: -1,
      code: "SHORTAGE_WITHOUT_DISCREPANCY",
    },
    {
      name: "overage",
      quantityDelta: 1,
      code: "OVERAGE_WITHOUT_DISCREPANCY",
    },
  ])("blocks $name without an explicit discrepancy", (testCase) => {
    let session = recordExpectedLines(started());
    const line = session.lines[0];
    const receivedQuantity =
      line.supplierConfirmedQuantity + testCase.quantityDelta;
    session = RecordReceivingLine(
      session,
      {
        receivingLineId: line.receivingLineId,
        receivedQuantity,
        acceptedQuantity: receivedQuantity,
        rejectedQuantity: 0,
        purchaseUnit: line.purchaseUnit,
        supplierDocumentReference: "delivery-note-49",
        locationId: "cold-a",
        lotReference: "lot-49",
      },
      actor,
      at,
    ).value!;
    const validation = ValidateReceivingSession(session, actor, at);
    expect(validation.accepted).toBe(false);
    expect(issueCodes(validation)).toContain(testCase.code);
  });

  it("reports required receiving warnings without turning Warehouse into QA", () => {
    let session = recordExpectedLines(started());
    const line = session.lines[0];
    session = RecordReceivingLine(
      session,
      {
        receivingLineId: line.receivingLineId,
        receivedQuantity: line.supplierConfirmedQuantity - 1,
        acceptedQuantity: line.supplierConfirmedQuantity - 2,
        rejectedQuantity: 1,
        purchaseUnit: line.purchaseUnit,
      },
      actor,
      at,
    ).value!;
    session = RecordReceivingDiscrepancy(
      session,
      {
        receivingLineId: line.receivingLineId,
        type: "SHORTAGE",
        note: "one unit short",
      },
      actor,
      at,
    ).value!;
    session = RecordReceivingDiscrepancy(
      session,
      {
        receivingLineId: line.receivingLineId,
        type: "DAMAGE",
        note: "one unit damaged",
      },
      actor,
      at,
    ).value!;
    const validation = ValidateReceivingSession(session, actor, at);
    expect(validation.accepted).toBe(true);
    expect(issueCodes(validation)).toEqual(
      expect.arrayContaining([
        "PARTIAL_DELIVERY",
        "DAMAGED_GOODS",
        "MISSING_SUPPLIER_DOCUMENT",
        "STORAGE_LOCATION_NOT_ASSIGNED",
        "LOT_MISSING",
        "QA_HOLD_RECOMMENDED",
      ]),
    );
  });

  it("reports overage delivery after the discrepancy is recorded", () => {
    let session = recordExpectedLines(started());
    const line = session.lines[0];
    session = RecordReceivingLine(
      session,
      {
        receivingLineId: line.receivingLineId,
        receivedQuantity: line.supplierConfirmedQuantity + 1,
        acceptedQuantity: line.supplierConfirmedQuantity + 1,
        rejectedQuantity: 0,
        purchaseUnit: line.purchaseUnit,
        supplierDocumentReference: "delivery-note-49",
        locationId: "cold-a",
        lotReference: "lot-49",
      },
      actor,
      at,
    ).value!;
    session = RecordReceivingDiscrepancy(
      session,
      {
        receivingLineId: line.receivingLineId,
        type: "OVERAGE",
        note: "one extra unit",
      },
      actor,
      at,
    ).value!;
    const validation = ValidateReceivingSession(session, actor, at);
    expect(validation.accepted).toBe(true);
    expect(issueCodes(validation)).toContain("OVERAGE_DELIVERY");
  });

  it("preserves the complete snapshot through GoodsReceipt and StockLot", () => {
    const validated = ValidateReceivingSession(
      recordExpectedLines(started()),
      actor,
      at,
    );
    const released = ReleaseGoodsReceipt(validated.value!, actor, at);
    const receiptLine = released.value!.goodsReceipt.lines[0];
    const stock = CreateStockFromGoodsReceipt(released.value!.goodsReceipt)
      .value![0];
    for (const field of upstreamFields) {
      expect(receiptLine[field]).toBe(validated.value!.lines[0][field]);
      expect(stock[field]).toBe(validated.value!.lines[0][field]);
    }
    expect(stock.goodsReceiptId).toBe(
      released.value!.goodsReceipt.goodsReceiptId,
    );
    for (const forbidden of [
      "dispatchDeliveryConfirmationId",
      "qaApprovalId",
      "invoiceId",
      "payableId",
      "accountingEntryId",
      "planningDemandEdit",
      "procurementCommitmentEdit",
    ]) {
      expect(forbidden in receiptLine).toBe(false);
      expect(forbidden in stock).toBe(false);
    }
  });
});
