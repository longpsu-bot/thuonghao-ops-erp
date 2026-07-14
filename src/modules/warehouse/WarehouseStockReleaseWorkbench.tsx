import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
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
  WarehouseStockReleaseWorkbench as buildReadModel,
  type OnHandStock,
  type PickList,
  type StockMovement,
  type StockReservation,
  type WarehouseRelease,
} from "./warehouseStockReleaseDomain";
import { onHandStockFixture } from "./warehouseStockReleaseFixtures";

const actorId = "warehouse-mai";
const at = "2026-07-14T05:00:00.000Z";
const requestedQuantity = 10;

export function WarehouseStockReleaseWorkbench() {
  const [stock, setStock] = useState<OnHandStock>(onHandStockFixture);
  const [reservation, setReservation] = useState<StockReservation>();
  const [pickList, setPickList] = useState<PickList>();
  const [release, setRelease] = useState<WarehouseRelease>();
  const [movements, setMovements] = useState<readonly StockMovement[]>([]);
  const readModel = buildReadModel({
    stock,
    reservation,
    pickList,
    release,
    movements,
  });

  const runNextCommand = () => {
    if (!reservation) {
      const result = CreateStockReservation({
        reservationId: "reservation-fixture-55",
        stock,
        fulfilmentTarget: "school-kitchen-fixture",
        requestedQuantity,
        purchaseUnit: stock.purchaseUnit,
        actorId,
        at,
      });
      if (result.accepted) setReservation(result.value);
      return;
    }
    if (reservation.status === "PREPARED") {
      setReservation(ValidateStockReservation(reservation, actorId, at).value);
      return;
    }
    if (reservation.status === "VALIDATED") {
      setReservation(
        ReleaseStockReservationToPick(reservation, actorId, at).value,
      );
      return;
    }
    if (!pickList) {
      setPickList(
        CreatePickListFromReservation(
          reservation,
          "pick-list-fixture-55",
          actorId,
          at,
        ).value,
      );
      return;
    }
    if (pickList.status === "PREPARED") {
      setPickList(ValidatePickList(pickList, actorId, at).value);
      return;
    }
    if (pickList.status === "VALIDATED") {
      setPickList(StartPicking(pickList, actorId, at).value);
      return;
    }
    if (
      pickList.status === "PICKING" &&
      pickList.lines.every((line) => line.pickedQuantity === 0)
    ) {
      setPickList(
        RecordPickLine(
          pickList,
          {
            pickLineId: pickList.lines[0].pickLineId,
            pickedQuantity: requestedQuantity,
          },
          actorId,
          at,
        ).value,
      );
      return;
    }
    if (pickList.status === "PICKING") {
      setPickList(MarkPickListReadyForRelease(pickList, actorId, at).value);
      return;
    }
    if (!release) {
      setRelease(
        CreateWarehouseReleaseFromPickList({
          pickList,
          warehouseReleaseId: "warehouse-release-fixture-55",
          handoffTarget: "school-kitchen-fixture",
          actorId,
          at,
        }).value,
      );
      return;
    }
    if (release.status === "DRAFT") {
      setRelease(ValidateWarehouseRelease(release, actorId, at).value);
      return;
    }
    if (release.status === "VALIDATED" && !release.handoffEvidence) {
      setRelease(
        RecordWarehouseHandoffEvidence(release, {
          handoffTarget: release.handoffTarget,
          handedOffBy: actorId,
          handedOffAt: at,
          evidenceReference: "warehouse-gate-note-fixture-55",
          packageCount: 1,
        }).value,
      );
      return;
    }
    if (release.status === "VALIDATED") {
      setRelease(ReleaseGoodsFromWarehouse(release, actorId, at).value);
      return;
    }
    if (release.status === "RELEASED_FROM_WAREHOUSE") {
      const result = PostReleaseStockMovement({
        release,
        stock,
        movements,
        actorId,
        at,
      });
      if (result.accepted && result.value) {
        setRelease(result.value.release);
        setStock(result.value.onHandStock);
        setMovements(result.value.movements);
      }
    }
  };

  return (
    <Panel
      title="Warehouse stock release decision"
      description="Can Warehouse reserve, pick, and release traced stock from Warehouse custody?"
      status={
        <Chip
          tone={release?.status === "STOCK_MOVEMENT_POSTED" ? "ok" : "warning"}
        >
          {release?.status ??
            pickList?.status ??
            reservation?.status ??
            "AVAILABLE"}
        </Chip>
      }
    >
      <div className="trace-filter">
        <b>Controlled lot:</b> {stock.stockLotId} · Ingredient{" "}
        {stock.ingredientId} · PO {stock.purchaseOrderId} v
        {stock.purchaseOrderVersion} · Trace {stock.sourceTraceId}
      </div>
      <CompactTable
        headers={[
          "On hand",
          "Available",
          "Reserved",
          "Picked",
          "Released",
          "Posted movement",
          "Unit",
        ]}
      >
        <tr>
          <td>{readModel.onHandQuantity}</td>
          <td>{readModel.availableQuantity}</td>
          <td>{readModel.reservedQuantity}</td>
          <td>{readModel.pickedQuantity}</td>
          <td>{readModel.releasedQuantity}</td>
          <td>{readModel.postedMovementQuantity}</td>
          <td>{stock.purchaseUnit}</td>
        </tr>
      </CompactTable>
      <div className="workbench-actions">
        {release?.status === "STOCK_MOVEMENT_POSTED" ? (
          <Chip tone="ok">Stock reduction posted</Chip>
        ) : (
          <button className="primary" onClick={runNextCommand}>
            {readModel.nextAvailableAction}
          </button>
        )}
      </div>
      <p className="prototype-notice" aria-live="polite">
        {readModel.boundaryNote} In-memory fixture only; no Dispatch operation,
        destination delivery confirmation, QA approval, or financial entry is
        created.
      </p>
    </Panel>
  );
}
