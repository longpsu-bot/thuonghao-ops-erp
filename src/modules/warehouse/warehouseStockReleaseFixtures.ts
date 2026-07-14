import {
  CreateStockFromGoodsReceipt,
  RecordReceivingLine,
  ReleaseGoodsReceipt,
  StartReceivingSession,
  ValidateReceivingSession,
} from "./warehouseDomain";
import { receivingSessionFixture } from "./warehouseFixtures";
import { OnHandStockFromStockLot } from "./warehouseStockReleaseDomain";

const actor = "warehouse-mai";
const at = "2026-07-14T04:00:00.000Z";

const started = StartReceivingSession(
  receivingSessionFixture,
  actor,
  at,
).value!;
const recorded = started.lines.reduce(
  (session, line) =>
    RecordReceivingLine(
      session,
      {
        receivingLineId: line.receivingLineId,
        receivedQuantity: line.supplierConfirmedQuantity,
        acceptedQuantity: line.supplierConfirmedQuantity,
        rejectedQuantity: 0,
        purchaseUnit: line.purchaseUnit,
        supplierDocumentReference: "release-fixture-delivery-note",
        locationId: "warehouse-a",
        lotReference: `release-lot-${line.ingredientId}`,
      },
      actor,
      at,
    ).value!,
  started,
);
const validated = ValidateReceivingSession(recorded, actor, at).value!;
export const stockReleaseGoodsReceiptFixture = ReleaseGoodsReceipt(
  validated,
  actor,
  at,
).value!.goodsReceipt;
export const stockReleaseStockLotFixtures = CreateStockFromGoodsReceipt(
  stockReleaseGoodsReceiptFixture,
).value!;
export const onHandStockFixture = OnHandStockFromStockLot(
  stockReleaseStockLotFixtures[0],
  stockReleaseGoodsReceiptFixture.receivingSessionId,
);
