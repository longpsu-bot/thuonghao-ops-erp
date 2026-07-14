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
  ReleasePurchaseOrderToSupplier,
  ReplaceSupplier,
  ValidatePurchaseAllocation,
  ValidatePurchaseOrder,
  type PurchaseAllocationBatch,
  type Supplier,
} from "./procurementDomain";

const actor = "buyer-minh";
const at = "2026-07-14T02:00:00.000Z";

export const releasedPurchaseHandoffFixture =
  ReleasePurchaseHandoffToProcurement(
    ValidatePurchaseHandoff(
      preparedPurchaseHandoffFixture,
      "planner-lan",
      "2026-07-14T01:40:00.000Z",
    ).batch!,
    "planner-lan",
    "2026-07-14T01:45:00.000Z",
  ).batch!;

export const supplierFixtures: readonly Supplier[] = [
  {
    supplierId: "supplier-atlas-main",
    supplierName: "Atlas Fresh Supply",
    status: "ACTIVE",
    allowedIngredientIds: ["ingredient-pumpkin", "ingredient-stock"],
    defaultDeliveryTerms: "Deliver before 05:30 to the referenced kitchen.",
    contactReference: "purchasing@atlas-fresh.example",
    priceReferenceStatus: "CURRENT",
    recentIssueCount: 0,
    concentrationRisk: false,
    createdAt: "2026-07-01T00:00:00.000Z",
    updatedAt: "2026-07-13T00:00:00.000Z",
  },
  {
    supplierId: "supplier-atlas-backup",
    supplierName: "Atlas Backup Produce",
    status: "ACTIVE",
    allowedIngredientIds: ["ingredient-pumpkin", "ingredient-stock"],
    defaultDeliveryTerms: "Deliver before 05:45 to the referenced kitchen.",
    contactReference: "orders@atlas-backup.example",
    priceReferenceStatus: "STALE",
    recentIssueCount: 1,
    concentrationRisk: false,
    createdAt: "2026-07-01T00:00:00.000Z",
    updatedAt: "2026-07-10T00:00:00.000Z",
  },
  {
    supplierId: "supplier-inactive",
    supplierName: "Inactive Supplier",
    status: "INACTIVE",
    allowedIngredientIds: ["ingredient-pumpkin", "ingredient-stock"],
    defaultDeliveryTerms: "",
    contactReference: "inactive@example.test",
    priceReferenceStatus: "UNKNOWN",
    recentIssueCount: 0,
    concentrationRisk: false,
    createdAt: "2026-07-01T00:00:00.000Z",
    updatedAt: "2026-07-01T00:00:00.000Z",
  },
  {
    supplierId: "supplier-ineligible",
    supplierName: "Ineligible Supplier",
    status: "ACTIVE",
    allowedIngredientIds: ["ingredient-rice"],
    defaultDeliveryTerms: "Deliver before 05:30.",
    contactReference: "ineligible@example.test",
    priceReferenceStatus: "CURRENT",
    recentIssueCount: 0,
    concentrationRisk: false,
    createdAt: "2026-07-01T00:00:00.000Z",
    updatedAt: "2026-07-13T00:00:00.000Z",
  },
];

export const preparedPurchaseAllocationFixture =
  CreatePurchaseAllocationFromHandoff({
    purchaseAllocationBatchId: "purchase-allocation-2026-29-v1",
    purchaseHandoffBatch: releasedPurchaseHandoffFixture,
    actorId: actor,
    at,
  }).batch!;

function assignAllLines(batch: PurchaseAllocationBatch) {
  return batch.lines.reduce(
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
}

export const successfulPurchaseAllocationFixture = assignAllLines(
  preparedPurchaseAllocationFixture,
);

export const blockerPurchaseAllocationFixture: PurchaseAllocationBatch = {
  ...successfulPurchaseAllocationFixture,
  lines: successfulPurchaseAllocationFixture.lines.map((line, index) =>
    index === 0
      ? {
          ...line,
          supplierId: "supplier-inactive",
          supplierAssignment: {
            ...line.supplierAssignment!,
            supplierId: "supplier-inactive",
          },
        }
      : {
          ...line,
          supplierId: "supplier-ineligible",
          supplierAssignment: {
            ...line.supplierAssignment!,
            supplierId: "supplier-ineligible",
          },
        },
  ),
};

export const approvedPurchaseAllocationFixture = ApprovePurchaseAllocation(
  ValidatePurchaseAllocation(
    successfulPurchaseAllocationFixture,
    supplierFixtures,
    actor,
    "2026-07-14T02:10:00.000Z",
  ).batch!,
  "procurement-manager-an",
  "2026-07-14T02:15:00.000Z",
).batch!;

const draftResult = CreatePurchaseOrderDrafts(
  approvedPurchaseAllocationFixture,
  supplierFixtures,
  actor,
  "2026-07-14T02:20:00.000Z",
);

export const releasedAllocationFixture = draftResult.allocationBatch!;
export const purchaseOrderDraftFixtures = draftResult.drafts;

export const releasedPurchaseOrderFixture = ReleasePurchaseOrderToSupplier(
  ValidatePurchaseOrder(
    purchaseOrderDraftFixtures[0],
    supplierFixtures,
    actor,
    "2026-07-14T02:25:00.000Z",
  ).purchaseOrder!,
  actor,
  "2026-07-14T02:30:00.000Z",
).purchaseOrder!;

export const supplierReplacementFixture = ReplaceSupplier(
  releasedPurchaseOrderFixture,
  {
    newSupplier: supplierFixtures[1],
    actorId: actor,
    at: "2026-07-14T02:35:00.000Z",
    reasonCode: "supplier_availability",
    reasonNote: "Primary supplier cannot meet the delivery window.",
  },
).purchaseOrder!;
