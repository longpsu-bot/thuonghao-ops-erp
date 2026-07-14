import { describe, expect, it } from "vitest";
import {
  CreateReceivingSessionFromSupplierConfirmedPO,
  CreateStockFromGoodsReceipt,
  RecordReceivingDiscrepancy,
  RecordReceivingLine,
  ReleaseGoodsReceipt,
  StartReceivingSession,
  ValidateReceivingSession,
} from "./warehouseDomain";
import { supplierConfirmedPurchaseOrderFixture } from "./warehouseFixtures";
describe("Warehouse receiving foundation", () => {
  it("starts only from a confirmed PO and preserves upstream trace", () => {
    const rejected = CreateReceivingSessionFromSupplierConfirmedPO(
      {
        ...supplierConfirmedPurchaseOrderFixture,
        status: "RELEASED_TO_SUPPLIER",
      },
      "mai",
      "at",
    );
    expect(rejected.accepted).toBe(false);
    const created = CreateReceivingSessionFromSupplierConfirmedPO(
      supplierConfirmedPurchaseOrderFixture,
      "mai",
      "at",
    );
    expect(created.accepted).toBe(true);
    expect(created.value?.lines[0]).toMatchObject({
      purchaseOrderLineId:
        supplierConfirmedPurchaseOrderFixture.lines[0].purchaseOrderLineId,
      sourceTraceId:
        supplierConfirmedPurchaseOrderFixture.lines[0].sourceTraceId,
      confirmedNeedLineId:
        supplierConfirmedPurchaseOrderFixture.lines[0].confirmedNeedLineId,
    });
  });
  it("requires explicit shortage evidence before receipt release and creates stock only after release", () => {
    let s = StartReceivingSession(
      CreateReceivingSessionFromSupplierConfirmedPO(
        supplierConfirmedPurchaseOrderFixture,
        "mai",
        "at",
      ).value!,
      "mai",
      "at",
    ).value!;
    const line = s.lines[0];
    for (const other of s.lines.slice(1)) {
      s = RecordReceivingLine(
        s,
        {
          receivingLineId: other.receivingLineId,
          receivedQuantity: other.supplierConfirmedQuantity,
          acceptedQuantity: other.supplierConfirmedQuantity,
          rejectedQuantity: 0,
          purchaseUnit: other.purchaseUnit,
          locationId: "cold-a",
          lotReference: "lot-other",
        },
        "mai",
        "at",
      ).value!;
    }
    s = RecordReceivingLine(
      s,
      {
        receivingLineId: line.receivingLineId,
        receivedQuantity: line.supplierConfirmedQuantity - 1,
        acceptedQuantity: line.supplierConfirmedQuantity - 1,
        rejectedQuantity: 0,
        purchaseUnit: line.purchaseUnit,
        locationId: "cold-a",
        lotReference: "lot-1",
      },
      "mai",
      "at",
    ).value!;
    expect(ValidateReceivingSession(s, "mai", "at").accepted).toBe(false);
    s = RecordReceivingDiscrepancy(
      s,
      {
        receivingLineId: line.receivingLineId,
        type: "SHORTAGE",
        note: "one short",
      },
      "mai",
      "at",
    ).value!;
    const validated = ValidateReceivingSession(s, "mai", "at");
    expect(validated.accepted).toBe(true);
    const receipt = ReleaseGoodsReceipt(validated.value!, "mai", "at");
    expect(receipt.accepted).toBe(true);
    expect(
      CreateStockFromGoodsReceipt(receipt.value!.goodsReceipt).value?.[0]
        .sourceTraceId,
    ).toBe(line.sourceTraceId);
  });
});
