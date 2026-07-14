import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  ApprovePurchaseAllocation,
  AssignSupplierToDemandLine,
  CreatePurchaseOrderDrafts,
  ProcurementWorkbench as shapeWorkbench,
  RecordSupplierConfirmation,
  ReleasePurchaseOrderToSupplier,
  ValidatePurchaseAllocation,
  ValidatePurchaseOrder,
  type PurchaseAllocationBatch,
  type PurchaseOrder,
} from "./procurementDomain";
import {
  preparedPurchaseAllocationFixture,
  supplierFixtures,
} from "./procurementFixtures";

const actor = "buyer-minh";

const statusLabels: Record<string, string> = {
  PREPARED: "Prepared",
  VALIDATED: "Validated",
  APPROVED: "Approved",
  RELEASED_TO_PO_DRAFTING: "Released to PO drafting",
  DRAFT: "Draft",
  RELEASED_TO_SUPPLIER: "Released to supplier",
  READY_FOR_WAREHOUSE_RECEIVING: "Supplier commitment confirmed",
};

export function ProcurementWorkbench() {
  const [batch, setBatch] = useState<PurchaseAllocationBatch>(
    preparedPurchaseAllocationFixture,
  );
  const [purchaseOrders, setPurchaseOrders] = useState<PurchaseOrder[]>([]);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const workbench = shapeWorkbench(batch, purchaseOrders);
  const activeOrder = purchaseOrders.find(
    (purchaseOrder) => purchaseOrder.status !== "CANCELLED",
  );

  const updateOrder = (purchaseOrder: PurchaseOrder) =>
    setPurchaseOrders((current) =>
      current.map((candidate) =>
        candidate.purchaseOrderId === purchaseOrder.purchaseOrderId
          ? purchaseOrder
          : candidate,
      ),
    );

  const assignSuppliers = () => {
    const next = batch.lines.reduce(
      (current, line) =>
        AssignSupplierToDemandLine(current, {
          purchaseAllocationLineId: line.purchaseAllocationLineId,
          supplier: supplierFixtures[0],
          assignedQuantity: line.demandQuantity,
          expectedDemandQuantity: line.demandQuantity,
          actorId: actor,
          at: "2026-07-14T02:05:00.000Z",
          reasonCode: "preferred_supplier",
        }).batch!,
      batch,
    );
    setBatch(next);
    setNotice("Suppliers assigned without changing Planning-approved demand.");
  };

  const validateAllocation = () => {
    const result = ValidatePurchaseAllocation(
      batch,
      supplierFixtures,
      actor,
      "2026-07-14T02:10:00.000Z",
    );
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted ? "Allocation validated." : (result.message ?? ""),
    );
  };

  const approveAllocation = () => {
    const result = ApprovePurchaseAllocation(
      batch,
      "procurement-manager-an",
      "2026-07-14T02:15:00.000Z",
    );
    if (result.batch) setBatch(result.batch);
    setNotice(
      result.accepted ? "Allocation approved." : (result.message ?? ""),
    );
  };

  const createDrafts = () => {
    const result = CreatePurchaseOrderDrafts(
      batch,
      supplierFixtures,
      actor,
      "2026-07-14T02:20:00.000Z",
    );
    if (result.allocationBatch) setBatch(result.allocationBatch);
    if (result.accepted) setPurchaseOrders([...result.drafts]);
    setNotice(
      result.accepted
        ? "Supplier-grouped PO drafts created; nothing has been sent yet."
        : (result.message ?? ""),
    );
  };

  const validatePurchaseOrder = () => {
    if (!activeOrder) return;
    const result = ValidatePurchaseOrder(
      activeOrder,
      supplierFixtures,
      actor,
      "2026-07-14T02:25:00.000Z",
    );
    if (result.purchaseOrder) updateOrder(result.purchaseOrder);
    setNotice(
      result.accepted ? "Purchase order validated." : (result.message ?? ""),
    );
  };

  const releasePurchaseOrder = () => {
    if (!activeOrder) return;
    const result = ReleasePurchaseOrderToSupplier(
      activeOrder,
      actor,
      "2026-07-14T02:30:00.000Z",
    );
    if (result.purchaseOrder) updateOrder(result.purchaseOrder);
    setNotice(
      result.accepted
        ? "Purchase order released to supplier with a preserved snapshot."
        : (result.message ?? ""),
    );
  };

  const confirmSupplier = () => {
    if (!activeOrder) return;
    const result = RecordSupplierConfirmation(activeOrder, {
      confirmationStatus: "ACCEPTED",
      confirmedBy: "supplier-contact",
      at: "2026-07-14T02:35:00.000Z",
      confirmedLineIds: activeOrder.lines.map(
        (line) => line.purchaseOrderLineId,
      ),
    });
    if (result.purchaseOrder) updateOrder(result.purchaseOrder);
    setNotice(
      result.accepted
        ? "Supplier commitment confirmed; Warehouse receiving was not created."
        : (result.message ?? ""),
    );
  };

  return (
    <Panel
      title="Procurement commitment workbench"
      description="Decision: Can Procurement safely convert released demand into supplier commitments?"
      status={
        <Chip tone={workbench.blockingIssueCount ? "danger" : "ok"}>
          {statusLabels[batch.status] ?? batch.status}
        </Chip>
      }
    >
      <div
        className="purchase-handoff-summary"
        aria-label="Procurement decision summary"
      >
        <article>
          <span>Service period</span>
          <strong>{workbench.servicePeriod}</strong>
        </article>
        <article>
          <span>Purchase Handoff</span>
          <strong>{workbench.purchaseHandoffReference}</strong>
        </article>
        <article>
          <span>Demand lines</span>
          <strong>{workbench.demandLineCount}</strong>
        </article>
        <article>
          <span>Supplier assignments</span>
          <strong>{workbench.supplierAssignmentCompleteness}</strong>
        </article>
        <article>
          <span>Blockers / warnings</span>
          <strong>
            {workbench.blockingIssueCount} / {workbench.warningCount}
          </strong>
        </article>
        <article>
          <span>PO drafts / released</span>
          <strong>
            {workbench.purchaseOrderDraftCount} /{" "}
            {workbench.releasedPurchaseOrderCount}
          </strong>
        </article>
        <article>
          <span>Supplier confirmation</span>
          <strong>{workbench.supplierConfirmationStatus}</strong>
        </article>
        <article>
          <span>Next action</span>
          <strong>{workbench.nextAvailableAction}</strong>
        </article>
      </div>
      <div className="workbench-actions">
        <button
          onClick={assignSuppliers}
          disabled={batch.status !== "PREPARED"}
        >
          Assign prototype suppliers
        </button>
        <button
          onClick={validateAllocation}
          disabled={!workbench.canValidateAllocation}
        >
          Validate allocation
        </button>
        <button
          onClick={approveAllocation}
          disabled={!workbench.canApproveAllocation}
        >
          Approve allocation
        </button>
        <button
          className="primary"
          onClick={createDrafts}
          disabled={!workbench.canCreatePurchaseOrderDrafts}
        >
          Create PO drafts
        </button>
        <button
          onClick={validatePurchaseOrder}
          disabled={!workbench.canValidatePurchaseOrder}
        >
          Validate PO
        </button>
        <button
          onClick={releasePurchaseOrder}
          disabled={!workbench.canReleasePurchaseOrder}
        >
          Release PO to supplier
        </button>
        <button
          onClick={confirmSupplier}
          disabled={!workbench.canRecordSupplierConfirmation}
        >
          Record supplier confirmation
        </button>
        <button
          onClick={() => setDetailsOpen((open) => !open)}
          aria-expanded={detailsOpen}
        >
          {detailsOpen ? "Hide details" : "Show details"}
        </button>
      </div>
      {notice && <p className="prototype-notice">{notice}</p>}
      {detailsOpen && (
        <div className="weekly-menu-details">
          <div className="trace-filter">
            <b>Boundary:</b>
            <span>
              Planning demand is read-only. This prototype assigns suppliers,
              prepares POs, and records supplier responses; it does not receive
              goods or create Warehouse, QA, Finance, or Accounting records.
            </span>
          </div>
          <CompactTable
            headers={[
              "Ingredient",
              "Planning demand",
              "Allocated",
              "Supplier",
              "Eligibility",
              "Assignment rationale",
              "Purchase Handoff line",
              "Confirmed Need line",
              "Source trace",
            ]}
          >
            {batch.lines.map((line) => {
              const supplier = supplierFixtures.find(
                (candidate) => candidate.supplierId === line.supplierId,
              );
              return (
                <tr key={line.purchaseAllocationLineId}>
                  <td>{line.ingredientId}</td>
                  <td>
                    {line.demandQuantity} {line.purchaseUnit}
                  </td>
                  <td>
                    {line.allocatedQuantity} {line.purchaseUnit}
                  </td>
                  <td>{supplier?.supplierName ?? "Unassigned"}</td>
                  <td>
                    {supplier?.allowedIngredientIds.includes(line.ingredientId)
                      ? "Eligible"
                      : "Not eligible"}
                  </td>
                  <td>{line.supplierAssignment?.reasonCode ?? "—"}</td>
                  <td>{line.purchaseHandoffLineId}</td>
                  <td>{line.confirmedNeedLineId}</td>
                  <td>{line.sourceTraceId}</td>
                </tr>
              );
            })}
          </CompactTable>
          {purchaseOrders.length > 0 && (
            <CompactTable
              headers={[
                "PO",
                "Supplier",
                "Status",
                "Lines",
                "Delivery instruction",
                "Release snapshots",
                "Confirmations",
                "Revisions",
              ]}
            >
              {purchaseOrders.map((purchaseOrder) => (
                <tr key={purchaseOrder.purchaseOrderId}>
                  <td>{purchaseOrder.purchaseOrderId}</td>
                  <td>
                    {supplierFixtures.find(
                      (supplier) =>
                        supplier.supplierId === purchaseOrder.supplierId,
                    )?.supplierName ?? purchaseOrder.supplierId}
                  </td>
                  <td>
                    {statusLabels[purchaseOrder.status] ?? purchaseOrder.status}
                  </td>
                  <td>{purchaseOrder.lineCount}</td>
                  <td>{purchaseOrder.deliveryRequirement}</td>
                  <td>{purchaseOrder.releaseSnapshots.length}</td>
                  <td>{purchaseOrder.confirmationHistory.length}</td>
                  <td>{purchaseOrder.revisionHistory.length}</td>
                </tr>
              ))}
            </CompactTable>
          )}
          <p className="weekly-menu-audit">
            {batch.changes.length} allocation events ·{" "}
            {purchaseOrders.reduce(
              (sum, purchaseOrder) => sum + purchaseOrder.changes.length,
              0,
            )}{" "}
            PO events · no downstream receiving record.
          </p>
        </div>
      )}
    </Panel>
  );
}
