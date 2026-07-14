import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import { receivingSessionFixture } from "./warehouseFixtures";
import {
  StartReceivingSession,
  type ReceivingSession,
} from "./warehouseDomain";
export function WarehouseWorkbench() {
  const [session, setSession] = useState<ReceivingSession>(
    receivingSessionFixture,
  );
  const start = () => {
    const next = StartReceivingSession(
      session,
      "warehouse-mai",
      "2026-07-14T03:05:00.000Z",
    );
    if (next.accepted && next.value) setSession(next.value);
  };
  return (
    <Panel
      title="Warehouse receiving decision"
      description="Can Warehouse safely receive these supplier-confirmed goods into controlled stock?"
      status={
        <Chip tone={session.status === "PREPARED" ? "warning" : "ok"}>
          {session.status}
        </Chip>
      }
    >
      <div className="trace-filter">
        <b>Supplier-confirmed PO:</b> {session.purchaseOrderId} v
        {session.purchaseOrderVersion} · Supplier {session.supplierId} · Release{" "}
        {session.releaseSnapshotReference}
      </div>
      <CompactTable
        headers={[
          "Ingredient",
          "Expected",
          "Received",
          "Accepted",
          "Rejected",
          "Missing / excess",
          "Discrepancies",
          "Source trace",
        ]}
      >
        {session.lines.map((line) => (
          <tr key={line.receivingLineId}>
            <td>{line.ingredientId}</td>
            <td>
              {line.supplierConfirmedQuantity} {line.purchaseUnit}
            </td>
            <td>{line.receivedQuantity}</td>
            <td>{line.acceptedQuantity}</td>
            <td>{line.rejectedQuantity}</td>
            <td>{line.supplierConfirmedQuantity - line.receivedQuantity}</td>
            <td>{line.discrepancies.length}</td>
            <td>
              <small>
                {line.confirmedNeedLineId} · {line.sourceTraceId}
              </small>
            </td>
          </tr>
        ))}
      </CompactTable>
      <div className="workbench-actions">
        <button
          className="primary"
          onClick={start}
          disabled={session.status !== "PREPARED"}
        >
          {session.status === "PREPARED"
            ? "Start receiving session"
            : "Record physical receiving evidence"}
        </button>
      </div>
      <p className="prototype-notice">
        In-memory fixture prototype. It creates no supplier message, QA
        approval, delivery confirmation, invoice, or accounting entry.
      </p>
    </Panel>
  );
}
