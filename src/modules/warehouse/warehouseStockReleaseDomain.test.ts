import { describe, expect, it } from "vitest";
import {
  stockReleaseGoodsReceiptFixture,
  stockReleaseStockLotFixtures,
  onHandStockFixture,
} from "./warehouseStockReleaseFixtures";
import {
  CreatePickListFromReservation,
  CreateStockReservation,
  CreateWarehouseReleaseFromPickList,
  MarkPickListReadyForRelease,
  PostReleaseStockMovement,
  RecordPickLine,
  RecordWarehouseHandoffEvidence,
  ReleaseGoodsFromWarehouse,
  ReleaseStockReservationToPick,
  StartPicking,
  ValidatePickList,
  ValidateStockReservation,
  ValidateWarehouseRelease,
  type OnHandStock,
  type ReleaseTrace,
  type StockReservation,
  type PickList,
  type WarehouseRelease,
} from "./warehouseStockReleaseDomain";

const actor = "warehouse-mai";
const at = "2026-07-14T04:10:00.000Z";

function reservation(stock = onHandStockFixture, quantity = 10) {
  return CreateStockReservation({
    reservationId: "reservation-55",
    stock,
    fulfilmentTarget: "downstream-handoff-zone-a",
    requestedQuantity: quantity,
    purchaseUnit: stock.purchaseUnit,
    actorId: actor,
    at,
  }).value!;
}

function releasedReservation() {
  return ReleaseStockReservationToPick(
    ValidateStockReservation(reservation(), actor, at).value!,
    actor,
    at,
  ).value!;
}

function picking() {
  const prepared = CreatePickListFromReservation(
    releasedReservation(),
    "pick-list-55",
    actor,
    at,
  ).value!;
  return StartPicking(ValidatePickList(prepared, actor, at).value!, actor, at)
    .value!;
}

function readyPickList(quantity = 10) {
  const list = picking();
  return MarkPickListReadyForRelease(
    RecordPickLine(
      list,
      { pickLineId: list.lines[0].pickLineId, pickedQuantity: quantity },
      actor,
      at,
    ).value!,
    actor,
    at,
  ).value!;
}

function draftRelease(releasedQuantity = 10) {
  const list = readyPickList();
  return CreateWarehouseReleaseFromPickList({
    pickList: list,
    warehouseReleaseId: "warehouse-release-55",
    handoffTarget: "downstream-handoff-zone-a",
    releasedQuantities: { [list.lines[0].pickLineId]: releasedQuantity },
    actorId: actor,
    at,
  }).value!;
}

function releasedWarehouseRelease() {
  const validated = ValidateWarehouseRelease(draftRelease(), actor, at).value!;
  const evidenced = RecordWarehouseHandoffEvidence(validated, {
    handoffTarget: validated.handoffTarget,
    handedOffBy: actor,
    handedOffAt: at,
    packageCount: 1,
    evidenceReference: "handoff-evidence-55",
  }).value!;
  return ReleaseGoodsFromWarehouse(evidenced, actor, at).value!;
}

const traceFields: readonly (keyof ReleaseTrace)[] = [
  "stockLotId",
  "goodsReceiptId",
  "receivingSessionId",
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

describe("Warehouse Stock Release foundation", () => {
  it("reserves only controlled available stock", () => {
    expect(reservation().status).toBe("PREPARED");
    for (const status of [
      "ON_HOLD",
      "QUARANTINED",
      "DAMAGED",
      "EXPIRED",
      "CANCELLED",
    ] as const) {
      const result = CreateStockReservation({
        reservationId: `blocked-${status}`,
        stock: { ...onHandStockFixture, status },
        fulfilmentTarget: "target",
        requestedQuantity: 1,
        purchaseUnit: onHandStockFixture.purchaseUnit,
        actorId: actor,
        at,
      });
      expect(result.accepted).toBe(false);
      expect(result.blockers.map((item) => item.issueCode)).toContain(
        "STOCK_NOT_AVAILABLE",
      );
    }
  });

  it("blocks missing stock/trace, invalid quantity, excess, and unit mismatch", () => {
    const inputs = [
      { stock: undefined, quantity: 1, unit: "kg", code: "STOCK_MISSING" },
      {
        stock: { ...onHandStockFixture, sourceTraceId: "" },
        quantity: 1,
        unit: onHandStockFixture.purchaseUnit,
        code: "TRACE_MISSING",
      },
      {
        stock: onHandStockFixture,
        quantity: 0,
        unit: onHandStockFixture.purchaseUnit,
        code: "QUANTITY_NOT_POSITIVE",
      },
      {
        stock: onHandStockFixture,
        quantity: -1,
        unit: onHandStockFixture.purchaseUnit,
        code: "QUANTITY_NOT_POSITIVE",
      },
      {
        stock: onHandStockFixture,
        quantity: onHandStockFixture.availableQuantity + 1,
        unit: onHandStockFixture.purchaseUnit,
        code: "INSUFFICIENT_AVAILABLE_STOCK",
      },
      {
        stock: onHandStockFixture,
        quantity: 1,
        unit: "case",
        code: "UNIT_MISMATCH",
      },
    ] as const;
    for (const input of inputs) {
      const result = CreateStockReservation({
        reservationId: "blocked-reservation",
        stock: input.stock as OnHandStock | undefined,
        fulfilmentTarget: "target",
        requestedQuantity: input.quantity,
        purchaseUnit: input.unit,
        actorId: actor,
        at,
      });
      expect(result.accepted).toBe(false);
      expect(result.blockers.map((item) => item.issueCode)).toContain(
        input.code,
      );
    }
  });

  it("creates pick lists only from reservations released to pick", () => {
    expect(
      CreatePickListFromReservation(reservation(), "blocked-pick", actor, at)
        .accepted,
    ).toBe(false);
    expect(
      CreatePickListFromReservation(
        releasedReservation(),
        "valid-pick",
        actor,
        at,
      ).accepted,
    ).toBe(true);
  });

  it("blocks zero, negative, and over-reserved pick quantities", () => {
    const list = picking();
    for (const quantity of [0, -1, list.lines[0].reservedQuantity + 1])
      expect(
        RecordPickLine(
          list,
          { pickLineId: list.lines[0].pickLineId, pickedQuantity: quantity },
          actor,
          at,
        ).accepted,
      ).toBe(false);
  });

  it("creates Warehouse release only from a ready pick list and validates quantity", () => {
    expect(
      CreateWarehouseReleaseFromPickList({
        pickList: picking(),
        warehouseReleaseId: "blocked-release",
        handoffTarget: "target",
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
    expect(ValidateWarehouseRelease(draftRelease(11), actor, at).accepted).toBe(
      false,
    );
    expect(
      CreateWarehouseReleaseFromPickList({
        pickList: readyPickList(),
        warehouseReleaseId: "missing-target",
        handoffTarget: "",
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
  });

  it("requires complete Warehouse custody handoff evidence", () => {
    const validated = ValidateWarehouseRelease(
      draftRelease(),
      actor,
      at,
    ).value!;
    expect(ReleaseGoodsFromWarehouse(validated, actor, at).accepted).toBe(
      false,
    );
    expect(
      RecordWarehouseHandoffEvidence(validated, {
        handoffTarget: validated.handoffTarget,
        handedOffBy: actor,
        handedOffAt: at,
        packageCount: 0,
        evidenceReference: "",
      }).accepted,
    ).toBe(false);
  });

  it("posts an append-only negative movement and reduces on-hand stock", () => {
    const goodsReceiptBefore = JSON.stringify(stockReleaseGoodsReceiptFixture);
    const stockLotBefore = JSON.stringify(stockReleaseStockLotFixtures[0]);
    const result = PostReleaseStockMovement({
      release: releasedWarehouseRelease(),
      stock: { ...onHandStockFixture, reservedQuantity: 10 },
      movements: [],
      actorId: actor,
      at,
    });
    expect(result.accepted).toBe(true);
    expect(result.value!.movement).toMatchObject({
      movementType: "RELEASE_FROM_WAREHOUSE",
      quantityDelta: -10,
      status: "POSTED",
    });
    expect(result.value!.movements).toEqual([result.value!.movement]);
    expect(result.value!.onHandStock.onHandQuantity).toBe(
      onHandStockFixture.onHandQuantity - 10,
    );
    expect(result.value!.onHandStock.availableQuantity).toBe(
      onHandStockFixture.availableQuantity - 10,
    );
    expect(JSON.stringify(stockReleaseStockLotFixtures[0])).toBe(
      stockLotBefore,
    );
    expect(JSON.stringify(stockReleaseGoodsReceiptFixture)).toBe(
      goodsReceiptBefore,
    );
  });

  it("warns on partial release while preserving the bounded release path", () => {
    const result = ValidateWarehouseRelease(draftRelease(9), actor, at);
    expect(result.accepted).toBe(true);
    expect(result.warnings.map((item) => item.issueCode)).toContain(
      "PARTIAL_RELEASE",
    );
  });

  it("preserves full trace on reservation, pick, release, and movement", () => {
    const reservationValue = releasedReservation();
    const pick = readyPickList();
    const release = releasedWarehouseRelease();
    const movement = PostReleaseStockMovement({
      release,
      stock: onHandStockFixture,
      movements: [],
      actorId: actor,
      at,
    }).value!.movement;
    for (const value of [
      reservationValue,
      pick.lines[0],
      release.lines[0],
      movement,
    ])
      for (const field of traceFields)
        expect(value[field]).toBe(onHandStockFixture[field]);
  });

  it("does not create Dispatch delivery, QA, Finance, or integration behavior", () => {
    const release = releasedWarehouseRelease();
    expect(release.confirmsDestinationDelivery).toBe(false);
    expect(release.handoffEvidence?.confirmsDestinationDelivery).toBe(false);
    for (const forbidden of [
      "dispatchRouteId",
      "driverTripId",
      "vehicleId",
      "destinationDeliveryConfirmationId",
      "destinationAcceptanceId",
      "qaApprovalId",
      "invoiceId",
      "payableId",
      "settlementId",
      "accountingEntryId",
      "supabaseClient",
      "retoolQuery",
      "backendCall",
      "credential",
      "productionDataId",
    ])
      expect(forbidden in release).toBe(false);
  });
});
