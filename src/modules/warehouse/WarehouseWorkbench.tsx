import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import { receivingSessionFixture } from "./warehouseFixtures";
import {
  CreateStockFromGoodsReceipt,
  RecordReceivingDiscrepancy,
  RecordReceivingLine,
  ReleaseGoodsReceipt,
  StartReceivingSession,
  ValidateReceivingSession,
  type GoodsReceipt,
  type ReceivingSession,
  type StockLot,
} from "./warehouseDomain";

const actor = "warehouse-mai";
const at = "2026-07-14T03:05:00.000Z";
type WorkbenchStep =
  | "START"
  | "RECORD_EVIDENCE"
  | "RECORD_DISCREPANCY"
  | "VALIDATE"
  | "RELEASE_RECEIPT"
  | "CREATE_STOCK"
  | "COMPLETE";
const actionLabels: Record<Exclude<WorkbenchStep, "COMPLETE">, string> = {
  START: "Start receiving session",
  RECORD_EVIDENCE: "Record sample receiving evidence",
  RECORD_DISCREPANCY: "Record shortage discrepancy",
  VALIDATE: "Validate receiving session",
  RELEASE_RECEIPT: "Release goods receipt",
  CREATE_STOCK: "Create controlled stock",
};

export function WarehouseWorkbench() {
  const [session, setSession] = useState<ReceivingSession>(
    receivingSessionFixture,
  );
  const [step, setStep] = useState<WorkbenchStep>("START");
  const [goodsReceipt, setGoodsReceipt] = useState<GoodsReceipt>();
  const [stock, setStock] = useState<readonly StockLot[]>([]);
  const [notice, setNotice] = useState("Ready to start receiving.");

  const runNextCommand = () => {
    if (step === "START") {
      const next = StartReceivingSession(session, actor, at);
      if (next.accepted && next.value) {
        setSession(next.value);
        setStep("RECORD_EVIDENCE");
        setNotice("Receiving session started.");
      }
      return;
    }
    if (step === "RECORD_EVIDENCE") {
      const firstLineId = session.lines[0]?.receivingLineId;
      const next = session.lines.reduce(
        (current, line) =>
          RecordReceivingLine(
            current,
            {
              receivingLineId: line.receivingLineId,
              receivedQuantity:
                line.supplierConfirmedQuantity -
                (line.receivingLineId === firstLineId ? 1 : 0),
              acceptedQuantity:
                line.supplierConfirmedQuantity -
                (line.receivingLineId === firstLineId ? 1 : 0),
              rejectedQuantity: 0,
              purchaseUnit: line.purchaseUnit,
              supplierDocumentReference: "delivery-note-fixture-49",
              locationId: "warehouse-a",
              lotReference: `lot-${line.ingredientId}`,
            },
            actor,
            at,
          ).value!,
        session,
      );
      setSession(next);
      setStep("RECORD_DISCREPANCY");
      setNotice(
        "Sample receiving evidence recorded; one shortage remains explicit.",
      );
      return;
    }
    if (step === "RECORD_DISCREPANCY") {
      const next = RecordReceivingDiscrepancy(
        session,
        {
          receivingLineId: session.lines[0].receivingLineId,
          type: "SHORTAGE",
          note: "Fixture delivery is one purchase unit short.",
        },
        actor,
        at,
      );
      if (next.accepted && next.value) {
        setSession(next.value);
        setStep("VALIDATE");
        setNotice(
          "Shortage discrepancy recorded without changing the PO commitment.",
        );
      }
      return;
    }
    if (step === "VALIDATE") {
      const next = ValidateReceivingSession(session, actor, at);
      if (next.accepted && next.value) {
        setSession(next.value);
        setStep("RELEASE_RECEIPT");
        setNotice(
          "Receiving session validated with warning evidence retained.",
        );
      }
      return;
    }
    if (step === "RELEASE_RECEIPT") {
      const next = ReleaseGoodsReceipt(session, actor, at);
      if (next.accepted && next.value) {
        setSession(next.value.session);
        setGoodsReceipt(next.value.goodsReceipt);
        setStep("CREATE_STOCK");
        setNotice(
          `Goods receipt ${next.value.goodsReceipt.goodsReceiptId} released.`,
        );
      }
      return;
    }
    if (step === "CREATE_STOCK" && goodsReceipt) {
      const next = CreateStockFromGoodsReceipt(goodsReceipt);
      if (next.accepted && next.value) {
        setStock(next.value);
        setStep("COMPLETE");
        setNotice(
          `${next.value.length} controlled stock lots created from accepted goods.`,
        );
      }
    }
  };

  return (
    <Panel
      title="Warehouse receiving decision"
      description="Can Warehouse safely receive these supplier-confirmed goods into controlled stock?"
      status={
        <Chip tone={step === "COMPLETE" ? "ok" : "warning"}>
          {session.status}
        </Chip>
      }
    >
      <div className="trace-filter">
        <b>Supplier-confirmed PO:</b> {session.purchaseOrderId} v
        {session.purchaseOrderVersion} · Supplier {session.supplierId} · Release{" "}
        {session.releaseSnapshotReference} · Confirmation{" "}
        {session.supplierConfirmationReference}
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
                {line.purchaseOrderLineId} · {line.confirmedNeedLineId} ·{" "}
                {line.sourceTraceId}
              </small>
            </td>
          </tr>
        ))}
      </CompactTable>
      <div className="workbench-actions">
        {step === "COMPLETE" ? (
          <Chip tone="ok">Controlled stock created · {stock.length} lots</Chip>
        ) : (
          <button className="primary" onClick={runNextCommand}>
            {actionLabels[step]}
          </button>
        )}
      </div>
      <p className="prototype-notice" aria-live="polite">
        {notice} In-memory fixture only; no supplier message, QA approval,
        delivery confirmation, invoice, payable, or accounting entry is created.
      </p>
    </Panel>
  );
}
