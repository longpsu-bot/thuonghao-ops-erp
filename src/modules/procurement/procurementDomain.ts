import type {
  PurchaseDemandReference,
  PurchaseHandoffBatch,
} from "../purchase-handoff/purchaseHandoffDomain";

export type SupplierStatus = "ACTIVE" | "INACTIVE" | "SUSPENDED" | "UNAPPROVED";

export type Supplier = {
  supplierId: string;
  supplierName: string;
  status: SupplierStatus;
  allowedIngredientIds: readonly string[];
  defaultDeliveryTerms: string;
  contactReference: string;
  priceReferenceStatus: "CURRENT" | "STALE" | "UNKNOWN";
  recentIssueCount: number;
  concentrationRisk: boolean;
  createdAt: string;
  updatedAt: string;
};

export type SupplierAssignment = {
  supplierAssignmentId: string;
  purchaseHandoffLineId: string;
  confirmedNeedLineId: string;
  ingredientId: string;
  supplierId: string;
  previousSupplierId?: string;
  assignmentStatus: "ASSIGNED" | "REVISED" | "REPLACED";
  assignedQuantity: number;
  purchaseUnit: string;
  assignedBy: string;
  assignedAt: string;
  reasonCode?: string;
  reasonNote?: string;
  sourceTraceId: string;
};

export type PurchaseAllocationStatus =
  | "PREPARED"
  | "VALIDATED"
  | "APPROVED"
  | "RELEASED_TO_PO_DRAFTING"
  | "REOPENED";

export type PurchaseAllocationLine = {
  purchaseAllocationLineId: string;
  purchaseAllocationBatchId: string;
  purchaseHandoffLineId: string;
  confirmedNeedLineId: string;
  ingredientId: string;
  demandQuantity: number;
  allocatedQuantity: number;
  purchaseUnit: string;
  supplierId?: string;
  allocationStatus: "UNASSIGNED" | "ASSIGNED" | "VALIDATED" | "APPROVED";
  sourceTraceId: string;
  purchaseDemandReference: PurchaseDemandReference;
  serviceDate: string;
  deliveryLocationReference?: string;
  deliveryRequirement?: string;
  supplierAssignment?: SupplierAssignment;
};

export type ProcurementIssueSeverity = "BLOCKING" | "WARNING";

export type ProcurementIssue = {
  procurementIssueId: string;
  purchaseAllocationBatchId?: string;
  purchaseOrderId?: string;
  lineId?: string;
  severity: ProcurementIssueSeverity;
  issueCode:
    | "SOURCE_HANDOFF_NOT_RELEASED"
    | "MISSING_HANDOFF_REFERENCE"
    | "MISSING_CONFIRMED_NEED_REFERENCE"
    | "MISSING_SOURCE_TRACE"
    | "SUPPLIER_MISSING"
    | "SUPPLIER_INACTIVE"
    | "SUPPLIER_INELIGIBLE"
    | "MISSING_PURCHASE_UNIT"
    | "NEGATIVE_ALLOCATION_QUANTITY"
    | "ALLOCATION_EXCEEDS_DEMAND"
    | "ALLOCATION_INCOMPLETE"
    | "PLANNING_DEMAND_CHANGED"
    | "ZERO_QUANTITY"
    | "MISSING_ALLOCATION_REFERENCE"
    | "PO_RELEASE_BLOCKED"
    | "SUPPLIER_CONFIRMATION_BEFORE_RELEASE"
    | "FORBIDDEN_WAREHOUSE_FIELD"
    | "SUPPLIER_RESPONSE_REQUIRES_REVISION"
    | "UNUSUAL_SUPPLIER_CHANGE"
    | "SUPPLIER_CONCENTRATION_RISK"
    | "STALE_PRICE_REFERENCE"
    | "SUPPLIER_RECENT_ISSUE"
    | "DELIVERY_TIME_RISK"
    | "INCOMPLETE_DELIVERY_INSTRUCTION";
  message: string;
  isBlocking: boolean;
  resolvedBy?: string;
  resolvedAt?: string;
};

export type ProcurementEventType =
  | "PurchaseAllocationCreated"
  | "SupplierAssigned"
  | "PurchaseAllocationValidated"
  | "PurchaseAllocationValidationFailed"
  | "PurchaseAllocationApproved"
  | "PurchaseAllocationReleasedToPODrafting"
  | "PurchaseOrderDraftCreated"
  | "PurchaseOrderValidated"
  | "PurchaseOrderValidationFailed"
  | "PurchaseOrderReleasedToSupplier"
  | "SupplierConfirmed"
  | "SupplierPartiallyConfirmed"
  | "SupplierRejected"
  | "SupplierAssignmentRevised"
  | "SupplierReplacementRecorded"
  | "PurchaseOrderReopened"
  | "PurchaseOrderCancelled";

export type ProcurementChange = {
  procurementChangeId: string;
  eventType: ProcurementEventType;
  businessObjectType: "PURCHASE_ALLOCATION" | "PURCHASE_ORDER";
  businessObjectId: string;
  actorId: string;
  at: string;
  beforeStatus?: string;
  afterStatus: string;
  affectedLineIds?: readonly string[];
  reasonCode?: string;
  reasonNote?: string;
  sourceTraceId?: string;
};

export type PurchaseAllocationApprovedSnapshot = {
  approvedVersion: number;
  lines: readonly {
    purchaseAllocationLineId: string;
    purchaseHandoffLineId: string;
    confirmedNeedLineId: string;
    supplierId: string;
    demandQuantity: number;
    allocatedQuantity: number;
    purchaseUnit: string;
    sourceTraceId: string;
  }[];
  approvedBy: string;
  approvedAt: string;
};

export type PurchaseAllocationBatch = {
  purchaseAllocationBatchId: string;
  purchaseHandoffBatchId: string;
  periodStart: string;
  periodEnd: string;
  status: PurchaseAllocationStatus;
  purchaseHandoffReference: {
    purchaseHandoffBatchId: string;
    releasedVersion: number;
    releasedBy: string;
    releasedAt: string;
  };
  lines: readonly PurchaseAllocationLine[];
  issues: readonly ProcurementIssue[];
  lineCount: number;
  blockingIssueCount: number;
  warningCount: number;
  preparedBy: string;
  preparedAt: string;
  validatedBy?: string;
  validatedAt?: string;
  approvedBy?: string;
  approvedAt?: string;
  releasedBy?: string;
  releasedAt?: string;
  version: number;
  approvedSnapshots: readonly PurchaseAllocationApprovedSnapshot[];
  changes: readonly ProcurementChange[];
};

export type PurchaseOrderStatus =
  | "DRAFT"
  | "VALIDATED"
  | "RELEASED_TO_SUPPLIER"
  | "SUPPLIER_CONFIRMED"
  | "READY_FOR_WAREHOUSE_RECEIVING"
  | "REOPENED"
  | "REVISED"
  | "CANCELLED";

export type PurchaseOrderLine = {
  purchaseOrderLineId: string;
  purchaseOrderId: string;
  purchaseAllocationLineId: string;
  purchaseHandoffLineId: string;
  confirmedNeedLineId: string;
  ingredientId: string;
  supplierId: string;
  demandQuantity: number;
  quantity: number;
  purchaseUnit: string;
  deliveryDate: string;
  deliveryLocationReference: string;
  status: "DRAFT" | "VALIDATED" | "RELEASED" | "CONFIRMED" | "CANCELLED";
  sourceTraceId: string;
  purchaseDemandReference: PurchaseDemandReference;
};

export type SupplierConfirmationStatus =
  "ACCEPTED" | "PARTIALLY_ACCEPTED" | "REJECTED" | "CHANGE_REQUESTED";

export type SupplierConfirmation = {
  supplierConfirmationId: string;
  purchaseOrderId: string;
  supplierId: string;
  confirmationStatus: SupplierConfirmationStatus;
  confirmedBy: string;
  confirmedAt: string;
  confirmedLineSummary: readonly string[];
  rejectedLineSummary: readonly string[];
  reasonNote?: string;
};

export type ProcurementRevision = {
  procurementRevisionId: string;
  originalPurchaseOrderId: string;
  affectedPurchaseOrderLineIds: readonly string[];
  oldSupplierId: string;
  newSupplierId?: string;
  beforeQuantity: number;
  afterQuantity: number;
  purchaseUnit: string;
  reasonCode?: string;
  reasonNote?: string;
  revisedBy: string;
  revisedAt: string;
  sourceTraceId: string;
};

export type SupplierReplacement = ProcurementRevision;

export type ReleasedPurchaseSnapshot = {
  releasedVersion: number;
  supplierId: string;
  lines: readonly {
    purchaseOrderLineId: string;
    purchaseAllocationLineId: string;
    purchaseHandoffLineId: string;
    confirmedNeedLineId: string;
    quantity: number;
    purchaseUnit: string;
    sourceTraceId: string;
  }[];
  releasedBy: string;
  releasedAt: string;
};

export type PurchaseOrderCancellationSnapshot = {
  cancelledVersion: number;
  supplierId: string;
  reason: string;
  cancelledBy: string;
  cancelledAt: string;
  priorReleaseSnapshotCount: number;
};

export type PurchaseOrder = {
  purchaseOrderId: string;
  purchaseOrderDraftId: string;
  purchaseAllocationBatchId: string;
  supplierId: string;
  servicePeriod: string;
  deliveryRequirement: string;
  status: PurchaseOrderStatus;
  lines: readonly PurchaseOrderLine[];
  issues: readonly ProcurementIssue[];
  lineCount: number;
  blockingIssueCount: number;
  warningCount: number;
  createdBy: string;
  createdAt: string;
  validatedBy?: string;
  validatedAt?: string;
  releasedBy?: string;
  releasedAt?: string;
  supplierConfirmedBy?: string;
  supplierConfirmedAt?: string;
  readyForWarehouseReceivingAt?: string;
  reopenedBy?: string;
  reopenedAt?: string;
  reopenReason?: string;
  cancelledBy?: string;
  cancelledAt?: string;
  cancellationReason?: string;
  version: number;
  releaseSnapshots: readonly ReleasedPurchaseSnapshot[];
  cancellationSnapshots: readonly PurchaseOrderCancellationSnapshot[];
  confirmationHistory: readonly SupplierConfirmation[];
  revisionHistory: readonly ProcurementRevision[];
  changes: readonly ProcurementChange[];
};

export type PurchaseOrderDraft = PurchaseOrder & { status: "DRAFT" };

export type PurchaseAllocationCommandResult = {
  batch?: PurchaseAllocationBatch;
  accepted: boolean;
  message?: string;
};

export type PurchaseOrderDraftsResult = {
  allocationBatch?: PurchaseAllocationBatch;
  drafts: readonly PurchaseOrderDraft[];
  accepted: boolean;
  message?: string;
};

export type PurchaseOrderCommandResult = {
  purchaseOrder?: PurchaseOrder;
  accepted: boolean;
  message?: string;
};

const issueCounts = (issues: readonly ProcurementIssue[]) => ({
  blockingIssueCount: issues.filter((issue) => issue.isBlocking).length,
  warningCount: issues.filter((issue) => !issue.isBlocking).length,
});

function procurementIssue(
  owner: { allocationBatchId?: string; purchaseOrderId?: string },
  issueCode: ProcurementIssue["issueCode"],
  message: string,
  severity: ProcurementIssueSeverity,
  lineId?: string,
): ProcurementIssue {
  return {
    procurementIssueId: `${owner.allocationBatchId ?? owner.purchaseOrderId}-issue-${issueCode}-${lineId ?? "batch"}`,
    purchaseAllocationBatchId: owner.allocationBatchId,
    purchaseOrderId: owner.purchaseOrderId,
    lineId,
    severity,
    issueCode,
    message,
    isBlocking: severity === "BLOCKING",
  };
}

function allocationChange(
  batch: PurchaseAllocationBatch,
  eventType: ProcurementEventType,
  actorId: string,
  at: string,
  afterStatus: PurchaseAllocationStatus,
  extra: Partial<ProcurementChange> = {},
): ProcurementChange {
  return {
    procurementChangeId: `${batch.purchaseAllocationBatchId}-event-${batch.changes.length + 1}`,
    eventType,
    businessObjectType: "PURCHASE_ALLOCATION",
    businessObjectId: batch.purchaseAllocationBatchId,
    actorId,
    at,
    beforeStatus: batch.status,
    afterStatus,
    ...extra,
  };
}

function purchaseOrderChange(
  purchaseOrder: PurchaseOrder,
  eventType: ProcurementEventType,
  actorId: string,
  at: string,
  afterStatus: PurchaseOrderStatus,
  extra: Partial<ProcurementChange> = {},
): ProcurementChange {
  return {
    procurementChangeId: `${purchaseOrder.purchaseOrderId}-event-${purchaseOrder.changes.length + 1}`,
    eventType,
    businessObjectType: "PURCHASE_ORDER",
    businessObjectId: purchaseOrder.purchaseOrderId,
    actorId,
    at,
    beforeStatus: purchaseOrder.status,
    afterStatus,
    ...extra,
  };
}

function supplierById(
  suppliers: readonly Supplier[],
  supplierId: string | undefined,
) {
  return suppliers.find((supplier) => supplier.supplierId === supplierId);
}

function isEligible(supplier: Supplier, ingredientId: string) {
  return supplier.allowedIngredientIds.includes(ingredientId);
}

function evaluateAllocationIssues(
  batch: Pick<PurchaseAllocationBatch, "purchaseAllocationBatchId" | "lines">,
  suppliers: readonly Supplier[],
): ProcurementIssue[] {
  const issues: ProcurementIssue[] = [];
  const owner = { allocationBatchId: batch.purchaseAllocationBatchId };
  for (const line of batch.lines) {
    const lineId = line.purchaseAllocationLineId;
    if (!line.purchaseHandoffLineId)
      issues.push(
        procurementIssue(
          owner,
          "MISSING_HANDOFF_REFERENCE",
          "Allocation line must reference released Purchase Handoff demand.",
          "BLOCKING",
          lineId,
        ),
      );
    if (!line.confirmedNeedLineId)
      issues.push(
        procurementIssue(
          owner,
          "MISSING_CONFIRMED_NEED_REFERENCE",
          "Allocation line must retain its Confirmed Need reference.",
          "BLOCKING",
          lineId,
        ),
      );
    if (!line.sourceTraceId)
      issues.push(
        procurementIssue(
          owner,
          "MISSING_SOURCE_TRACE",
          "Allocation line must retain its Planning source trace.",
          "BLOCKING",
          lineId,
        ),
      );
    if (!line.purchaseUnit.trim())
      issues.push(
        procurementIssue(
          owner,
          "MISSING_PURCHASE_UNIT",
          "Allocation line requires a purchase unit.",
          "BLOCKING",
          lineId,
        ),
      );
    if (
      line.demandQuantity !==
        line.purchaseDemandReference.approvedConfirmedQuantity ||
      line.purchaseUnit !== line.purchaseDemandReference.approvedConfirmedUnit
    )
      issues.push(
        procurementIssue(
          owner,
          "PLANNING_DEMAND_CHANGED",
          "Procurement cannot change Planning-approved demand quantity or unit.",
          "BLOCKING",
          lineId,
        ),
      );
    if (line.allocatedQuantity < 0)
      issues.push(
        procurementIssue(
          owner,
          "NEGATIVE_ALLOCATION_QUANTITY",
          "Allocation quantity cannot be negative.",
          "BLOCKING",
          lineId,
        ),
      );
    if (line.allocatedQuantity > line.demandQuantity)
      issues.push(
        procurementIssue(
          owner,
          "ALLOCATION_EXCEEDS_DEMAND",
          "Allocation cannot exceed released demand without an approved rule.",
          "BLOCKING",
          lineId,
        ),
      );
    if (line.allocatedQuantity !== line.demandQuantity)
      issues.push(
        procurementIssue(
          owner,
          "ALLOCATION_INCOMPLETE",
          "The prototype requires full line allocation before approval.",
          "BLOCKING",
          lineId,
        ),
      );
    const supplier = supplierById(suppliers, line.supplierId);
    if (!supplier)
      issues.push(
        procurementIssue(
          owner,
          "SUPPLIER_MISSING",
          "A supplier must be assigned before allocation approval.",
          "BLOCKING",
          lineId,
        ),
      );
    else {
      if (supplier.status !== "ACTIVE")
        issues.push(
          procurementIssue(
            owner,
            "SUPPLIER_INACTIVE",
            "Only active suppliers may receive an allocation.",
            "BLOCKING",
            lineId,
          ),
        );
      if (!isEligible(supplier, line.ingredientId))
        issues.push(
          procurementIssue(
            owner,
            "SUPPLIER_INELIGIBLE",
            "Supplier is not eligible for this ingredient.",
            "BLOCKING",
            lineId,
          ),
        );
      if (supplier.priceReferenceStatus === "STALE")
        issues.push(
          procurementIssue(
            owner,
            "STALE_PRICE_REFERENCE",
            "Supplier price reference is marked stale.",
            "WARNING",
            lineId,
          ),
        );
      if (supplier.recentIssueCount > 0)
        issues.push(
          procurementIssue(
            owner,
            "SUPPLIER_RECENT_ISSUE",
            "Supplier has recent rejection or issue history.",
            "WARNING",
            lineId,
          ),
        );
      if (supplier.concentrationRisk)
        issues.push(
          procurementIssue(
            owner,
            "SUPPLIER_CONCENTRATION_RISK",
            "Supplier is marked with a concentration risk.",
            "WARNING",
            lineId,
          ),
        );
    }
  }
  return issues;
}

const forbiddenWarehouseFields = [
  "warehouseReceiptId",
  "receivedQuantity",
  "stockMovementId",
] as const;

function hasForbiddenWarehouseField(value: object) {
  return forbiddenWarehouseFields.some((field) => field in value);
}

function evaluatePurchaseOrderIssues(
  purchaseOrder: PurchaseOrder,
  suppliers: readonly Supplier[],
): ProcurementIssue[] {
  const issues: ProcurementIssue[] = [];
  const owner = { purchaseOrderId: purchaseOrder.purchaseOrderId };
  const supplier = supplierById(suppliers, purchaseOrder.supplierId);
  if (!supplier)
    issues.push(
      procurementIssue(
        owner,
        "SUPPLIER_MISSING",
        "Purchase order requires a supplier.",
        "BLOCKING",
      ),
    );
  else if (supplier.status !== "ACTIVE")
    issues.push(
      procurementIssue(
        owner,
        "SUPPLIER_INACTIVE",
        "Purchase order supplier must remain active.",
        "BLOCKING",
      ),
    );
  if (!purchaseOrder.deliveryRequirement.trim())
    issues.push(
      procurementIssue(
        owner,
        "INCOMPLETE_DELIVERY_INSTRUCTION",
        "Delivery instruction is incomplete.",
        "WARNING",
      ),
    );
  if (hasForbiddenWarehouseField(purchaseOrder as object))
    issues.push(
      procurementIssue(
        owner,
        "FORBIDDEN_WAREHOUSE_FIELD",
        "Procurement must not create Warehouse receiving state.",
        "BLOCKING",
      ),
    );
  for (const line of purchaseOrder.lines) {
    const lineId = line.purchaseOrderLineId;
    if (!line.purchaseAllocationLineId)
      issues.push(
        procurementIssue(
          owner,
          "MISSING_ALLOCATION_REFERENCE",
          "PO line must reference an approved allocation line.",
          "BLOCKING",
          lineId,
        ),
      );
    if (!line.purchaseHandoffLineId)
      issues.push(
        procurementIssue(
          owner,
          "MISSING_HANDOFF_REFERENCE",
          "PO line must retain its Purchase Handoff reference.",
          "BLOCKING",
          lineId,
        ),
      );
    if (!line.confirmedNeedLineId)
      issues.push(
        procurementIssue(
          owner,
          "MISSING_CONFIRMED_NEED_REFERENCE",
          "PO line must retain its Confirmed Need reference.",
          "BLOCKING",
          lineId,
        ),
      );
    if (!line.sourceTraceId)
      issues.push(
        procurementIssue(
          owner,
          "MISSING_SOURCE_TRACE",
          "PO line must retain its Planning source trace.",
          "BLOCKING",
          lineId,
        ),
      );
    if (!line.purchaseUnit.trim())
      issues.push(
        procurementIssue(
          owner,
          "MISSING_PURCHASE_UNIT",
          "PO line requires a purchase unit.",
          "BLOCKING",
          lineId,
        ),
      );
    if (
      line.demandQuantity !==
        line.purchaseDemandReference.approvedConfirmedQuantity ||
      line.quantity > line.demandQuantity
    )
      issues.push(
        procurementIssue(
          owner,
          "PLANNING_DEMAND_CHANGED",
          "PO line cannot redefine Planning-approved demand.",
          "BLOCKING",
          lineId,
        ),
      );
    if (line.quantity < 0)
      issues.push(
        procurementIssue(
          owner,
          "NEGATIVE_ALLOCATION_QUANTITY",
          "PO quantity cannot be negative.",
          "BLOCKING",
          lineId,
        ),
      );
    if (line.quantity === 0)
      issues.push(
        procurementIssue(
          owner,
          "ZERO_QUANTITY",
          "Zero quantity must be excluded before supplier release.",
          "BLOCKING",
          lineId,
        ),
      );
    if (supplier && !isEligible(supplier, line.ingredientId))
      issues.push(
        procurementIssue(
          owner,
          "SUPPLIER_INELIGIBLE",
          "PO supplier is not eligible for this ingredient.",
          "BLOCKING",
          lineId,
        ),
      );
    if (hasForbiddenWarehouseField(line as object))
      issues.push(
        procurementIssue(
          owner,
          "FORBIDDEN_WAREHOUSE_FIELD",
          "PO line must not contain Warehouse receiving state.",
          "BLOCKING",
          lineId,
        ),
      );
  }
  return issues;
}

export function CreatePurchaseAllocationFromHandoff(input: {
  purchaseAllocationBatchId: string;
  purchaseHandoffBatch: PurchaseHandoffBatch;
  actorId: string;
  at: string;
}): PurchaseAllocationCommandResult {
  const source = input.purchaseHandoffBatch;
  if (
    source.status !== "RELEASED_TO_PROCUREMENT" ||
    !source.releasedBy ||
    !source.releasedAt ||
    source.releaseSnapshots.length === 0
  )
    return {
      accepted: false,
      message: "Purchase Allocation requires a released Purchase Handoff.",
    };
  const lines: PurchaseAllocationLine[] = source.lines.map((line, index) => ({
    purchaseAllocationLineId: `${input.purchaseAllocationBatchId}-line-${index + 1}`,
    purchaseAllocationBatchId: input.purchaseAllocationBatchId,
    purchaseHandoffLineId: line.purchaseHandoffLineId,
    confirmedNeedLineId: line.confirmedNeedLineId,
    ingredientId: line.ingredientId,
    demandQuantity: line.quantity,
    allocatedQuantity: 0,
    purchaseUnit: line.purchaseUnit,
    allocationStatus: "UNASSIGNED",
    sourceTraceId: line.sourceTraceId,
    purchaseDemandReference: line.purchaseDemandReference,
    serviceDate: line.serviceDate,
    deliveryLocationReference: line.schoolId,
    deliveryRequirement: line.deliveryRequirement,
  }));
  const base: PurchaseAllocationBatch = {
    purchaseAllocationBatchId: input.purchaseAllocationBatchId,
    purchaseHandoffBatchId: source.purchaseHandoffBatchId,
    periodStart: source.periodStart,
    periodEnd: source.periodEnd,
    status: "PREPARED",
    purchaseHandoffReference: {
      purchaseHandoffBatchId: source.purchaseHandoffBatchId,
      releasedVersion: source.releaseSnapshots.at(-1)!.releasedVersion,
      releasedBy: source.releasedBy,
      releasedAt: source.releasedAt,
    },
    lines,
    issues: [],
    lineCount: lines.length,
    blockingIssueCount: lines.length,
    warningCount: 0,
    preparedBy: input.actorId,
    preparedAt: input.at,
    version: 1,
    approvedSnapshots: [],
    changes: [],
  };
  return {
    accepted: true,
    batch: {
      ...base,
      changes: [
        allocationChange(
          base,
          "PurchaseAllocationCreated",
          input.actorId,
          input.at,
          "PREPARED",
          {
            affectedLineIds: lines.map((line) => line.purchaseAllocationLineId),
          },
        ),
      ],
    },
  };
}

export function AssignSupplierToDemandLine(
  batch: PurchaseAllocationBatch,
  input: {
    purchaseAllocationLineId: string;
    supplier: Supplier;
    assignedQuantity: number;
    expectedDemandQuantity: number;
    actorId: string;
    at: string;
    reasonCode?: string;
    reasonNote?: string;
  },
): PurchaseAllocationCommandResult {
  if (batch.status !== "PREPARED" && batch.status !== "REOPENED")
    return {
      batch,
      accepted: false,
      message: "Supplier assignment requires Prepared or Reopened allocation.",
    };
  const line = batch.lines.find(
    (candidate) =>
      candidate.purchaseAllocationLineId === input.purchaseAllocationLineId,
  );
  if (!line)
    return {
      batch,
      accepted: false,
      message: "Allocation line was not found.",
    };
  if (
    input.expectedDemandQuantity !== line.demandQuantity ||
    line.demandQuantity !==
      line.purchaseDemandReference.approvedConfirmedQuantity
  )
    return {
      batch,
      accepted: false,
      message: "Supplier assignment cannot change Planning-approved demand.",
    };
  if (input.supplier.status !== "ACTIVE")
    return { batch, accepted: false, message: "Supplier must be active." };
  if (!isEligible(input.supplier, line.ingredientId))
    return {
      batch,
      accepted: false,
      message: "Supplier is not eligible for this ingredient.",
    };
  if (
    input.assignedQuantity < 0 ||
    input.assignedQuantity > line.demandQuantity
  )
    return {
      batch,
      accepted: false,
      message: "Assigned quantity must stay within released demand.",
    };
  const assignment: SupplierAssignment = {
    supplierAssignmentId: `${line.purchaseAllocationLineId}-assignment-${line.supplierAssignment ? 2 : 1}`,
    purchaseHandoffLineId: line.purchaseHandoffLineId,
    confirmedNeedLineId: line.confirmedNeedLineId,
    ingredientId: line.ingredientId,
    supplierId: input.supplier.supplierId,
    previousSupplierId: line.supplierId,
    assignmentStatus: line.supplierId ? "REVISED" : "ASSIGNED",
    assignedQuantity: input.assignedQuantity,
    purchaseUnit: line.purchaseUnit,
    assignedBy: input.actorId,
    assignedAt: input.at,
    reasonCode: input.reasonCode,
    reasonNote: input.reasonNote,
    sourceTraceId: line.sourceTraceId,
  };
  const lines = batch.lines.map((candidate) =>
    candidate.purchaseAllocationLineId === line.purchaseAllocationLineId
      ? {
          ...candidate,
          supplierId: input.supplier.supplierId,
          allocatedQuantity: input.assignedQuantity,
          allocationStatus: "ASSIGNED" as const,
          supplierAssignment: assignment,
        }
      : candidate,
  );
  return {
    accepted: true,
    batch: {
      ...batch,
      lines,
      issues: [],
      blockingIssueCount: 0,
      warningCount: 0,
      changes: [
        ...batch.changes,
        allocationChange(
          batch,
          line.supplierId ? "SupplierAssignmentRevised" : "SupplierAssigned",
          input.actorId,
          input.at,
          batch.status,
          {
            affectedLineIds: [line.purchaseAllocationLineId],
            reasonCode: input.reasonCode,
            reasonNote: input.reasonNote,
            sourceTraceId: line.sourceTraceId,
          },
        ),
      ],
    },
  };
}

export function ReviseSupplierAssignment(
  batch: PurchaseAllocationBatch,
  input: {
    purchaseAllocationLineId: string;
    supplier: Supplier;
    actorId: string;
    at: string;
    reasonCode?: string;
    reasonNote?: string;
  },
): PurchaseAllocationCommandResult {
  const line = batch.lines.find(
    (candidate) =>
      candidate.purchaseAllocationLineId === input.purchaseAllocationLineId,
  );
  if (
    !line?.supplierId ||
    (!input.reasonCode?.trim() && !input.reasonNote?.trim())
  )
    return {
      batch,
      accepted: false,
      message: "Supplier revision requires an existing assignment and reason.",
    };
  return AssignSupplierToDemandLine(batch, {
    ...input,
    assignedQuantity: line.allocatedQuantity,
    expectedDemandQuantity: line.demandQuantity,
  });
}

export function ValidatePurchaseAllocation(
  batch: PurchaseAllocationBatch,
  suppliers: readonly Supplier[],
  actorId: string,
  at: string,
): PurchaseAllocationCommandResult {
  if (batch.status !== "PREPARED" && batch.status !== "REOPENED")
    return {
      batch,
      accepted: false,
      message: "Only Prepared or Reopened allocation can be validated.",
    };
  const issues = evaluateAllocationIssues(batch, suppliers);
  const counts = issueCounts(issues);
  if (counts.blockingIssueCount > 0)
    return {
      accepted: false,
      message: "Blocking allocation issues must be resolved.",
      batch: {
        ...batch,
        issues,
        ...counts,
        changes: [
          ...batch.changes,
          allocationChange(
            batch,
            "PurchaseAllocationValidationFailed",
            actorId,
            at,
            batch.status,
          ),
        ],
      },
    };
  const status: PurchaseAllocationStatus = "VALIDATED";
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      issues,
      ...counts,
      lines: batch.lines.map((line) => ({
        ...line,
        allocationStatus: "VALIDATED",
      })),
      validatedBy: actorId,
      validatedAt: at,
      changes: [
        ...batch.changes,
        allocationChange(
          batch,
          "PurchaseAllocationValidated",
          actorId,
          at,
          status,
        ),
      ],
    },
  };
}

export function ApprovePurchaseAllocation(
  batch: PurchaseAllocationBatch,
  actorId: string,
  at: string,
): PurchaseAllocationCommandResult {
  if (batch.status !== "VALIDATED" || batch.blockingIssueCount > 0)
    return {
      batch,
      accepted: false,
      message: "Only Validated allocation without blockers can be approved.",
    };
  const status: PurchaseAllocationStatus = "APPROVED";
  const snapshot: PurchaseAllocationApprovedSnapshot = {
    approvedVersion: batch.version,
    lines: batch.lines.map((line) => ({
      purchaseAllocationLineId: line.purchaseAllocationLineId,
      purchaseHandoffLineId: line.purchaseHandoffLineId,
      confirmedNeedLineId: line.confirmedNeedLineId,
      supplierId: line.supplierId!,
      demandQuantity: line.demandQuantity,
      allocatedQuantity: line.allocatedQuantity,
      purchaseUnit: line.purchaseUnit,
      sourceTraceId: line.sourceTraceId,
    })),
    approvedBy: actorId,
    approvedAt: at,
  };
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      lines: batch.lines.map((line) => ({
        ...line,
        allocationStatus: "APPROVED",
      })),
      approvedBy: actorId,
      approvedAt: at,
      approvedSnapshots: [...batch.approvedSnapshots, snapshot],
      changes: [
        ...batch.changes,
        allocationChange(
          batch,
          "PurchaseAllocationApproved",
          actorId,
          at,
          status,
        ),
      ],
    },
  };
}

export function CreatePurchaseOrderDrafts(
  batch: PurchaseAllocationBatch,
  suppliers: readonly Supplier[],
  actorId: string,
  at: string,
): PurchaseOrderDraftsResult {
  if (batch.status !== "APPROVED" || batch.blockingIssueCount > 0)
    return {
      allocationBatch: batch,
      drafts: [],
      accepted: false,
      message: "PO drafts require Approved allocation without blockers.",
    };
  const grouped = new Map<string, PurchaseAllocationLine[]>();
  for (const line of batch.lines) {
    if (!line.supplierId) continue;
    grouped.set(line.supplierId, [
      ...(grouped.get(line.supplierId) ?? []),
      line,
    ]);
  }
  const drafts = [...grouped.entries()].map(
    ([supplierId, lines], index): PurchaseOrderDraft => {
      const supplier = supplierById(suppliers, supplierId);
      const purchaseOrderId = `${batch.purchaseAllocationBatchId}-po-${index + 1}`;
      const purchaseOrderDraftId = `${purchaseOrderId}-draft-v1`;
      const base: PurchaseOrderDraft = {
        purchaseOrderId,
        purchaseOrderDraftId,
        purchaseAllocationBatchId: batch.purchaseAllocationBatchId,
        supplierId,
        servicePeriod: `${batch.periodStart} to ${batch.periodEnd}`,
        deliveryRequirement: supplier?.defaultDeliveryTerms ?? "",
        status: "DRAFT",
        lines: lines.map((line, lineIndex) => ({
          purchaseOrderLineId: `${purchaseOrderId}-line-${lineIndex + 1}`,
          purchaseOrderId,
          purchaseAllocationLineId: line.purchaseAllocationLineId,
          purchaseHandoffLineId: line.purchaseHandoffLineId,
          confirmedNeedLineId: line.confirmedNeedLineId,
          ingredientId: line.ingredientId,
          supplierId,
          demandQuantity: line.demandQuantity,
          quantity: line.allocatedQuantity,
          purchaseUnit: line.purchaseUnit,
          deliveryDate: line.serviceDate,
          deliveryLocationReference:
            line.deliveryLocationReference ?? "central-kitchen",
          status: "DRAFT",
          sourceTraceId: line.sourceTraceId,
          purchaseDemandReference: line.purchaseDemandReference,
        })),
        issues: [],
        lineCount: lines.length,
        blockingIssueCount: 0,
        warningCount: 0,
        createdBy: actorId,
        createdAt: at,
        version: 1,
        releaseSnapshots: [],
        cancellationSnapshots: [],
        confirmationHistory: [],
        revisionHistory: [],
        changes: [],
      };
      return {
        ...base,
        changes: [
          purchaseOrderChange(
            base,
            "PurchaseOrderDraftCreated",
            actorId,
            at,
            "DRAFT",
            {
              affectedLineIds: base.lines.map(
                (line) => line.purchaseOrderLineId,
              ),
            },
          ),
        ],
      };
    },
  );
  const status: PurchaseAllocationStatus = "RELEASED_TO_PO_DRAFTING";
  return {
    accepted: true,
    drafts,
    allocationBatch: {
      ...batch,
      status,
      releasedBy: actorId,
      releasedAt: at,
      changes: [
        ...batch.changes,
        allocationChange(
          batch,
          "PurchaseAllocationReleasedToPODrafting",
          actorId,
          at,
          status,
          {
            affectedLineIds: batch.lines.map(
              (line) => line.purchaseAllocationLineId,
            ),
          },
        ),
      ],
    },
  };
}

export function ValidatePurchaseOrder(
  purchaseOrder: PurchaseOrder,
  suppliers: readonly Supplier[],
  actorId: string,
  at: string,
): PurchaseOrderCommandResult {
  if (
    purchaseOrder.status !== "DRAFT" &&
    purchaseOrder.status !== "REOPENED" &&
    purchaseOrder.status !== "REVISED"
  )
    return {
      purchaseOrder,
      accepted: false,
      message: "Only Draft, Reopened, or Revised PO can be validated.",
    };
  const issues = evaluatePurchaseOrderIssues(purchaseOrder, suppliers);
  const counts = issueCounts(issues);
  if (counts.blockingIssueCount > 0)
    return {
      accepted: false,
      message: "Blocking PO issues must be resolved before release.",
      purchaseOrder: {
        ...purchaseOrder,
        issues,
        ...counts,
        changes: [
          ...purchaseOrder.changes,
          purchaseOrderChange(
            purchaseOrder,
            "PurchaseOrderValidationFailed",
            actorId,
            at,
            purchaseOrder.status,
          ),
        ],
      },
    };
  const status: PurchaseOrderStatus = "VALIDATED";
  return {
    accepted: true,
    purchaseOrder: {
      ...purchaseOrder,
      status,
      issues,
      ...counts,
      lines: purchaseOrder.lines.map((line) => ({
        ...line,
        status: "VALIDATED",
      })),
      validatedBy: actorId,
      validatedAt: at,
      changes: [
        ...purchaseOrder.changes,
        purchaseOrderChange(
          purchaseOrder,
          "PurchaseOrderValidated",
          actorId,
          at,
          status,
        ),
      ],
    },
  };
}

export function ReleasePurchaseOrderToSupplier(
  purchaseOrder: PurchaseOrder,
  actorId: string,
  at: string,
): PurchaseOrderCommandResult {
  if (
    purchaseOrder.status !== "VALIDATED" ||
    purchaseOrder.blockingIssueCount > 0
  )
    return {
      purchaseOrder,
      accepted: false,
      message: "Only Validated PO without blockers can be released.",
    };
  const status: PurchaseOrderStatus = "RELEASED_TO_SUPPLIER";
  const snapshot: ReleasedPurchaseSnapshot = {
    releasedVersion: purchaseOrder.version,
    supplierId: purchaseOrder.supplierId,
    lines: purchaseOrder.lines.map((line) => ({
      purchaseOrderLineId: line.purchaseOrderLineId,
      purchaseAllocationLineId: line.purchaseAllocationLineId,
      purchaseHandoffLineId: line.purchaseHandoffLineId,
      confirmedNeedLineId: line.confirmedNeedLineId,
      quantity: line.quantity,
      purchaseUnit: line.purchaseUnit,
      sourceTraceId: line.sourceTraceId,
    })),
    releasedBy: actorId,
    releasedAt: at,
  };
  return {
    accepted: true,
    purchaseOrder: {
      ...purchaseOrder,
      status,
      lines: purchaseOrder.lines.map((line) => ({
        ...line,
        status: "RELEASED",
      })),
      releasedBy: actorId,
      releasedAt: at,
      releaseSnapshots: [...purchaseOrder.releaseSnapshots, snapshot],
      changes: [
        ...purchaseOrder.changes,
        purchaseOrderChange(
          purchaseOrder,
          "PurchaseOrderReleasedToSupplier",
          actorId,
          at,
          status,
          {
            affectedLineIds: purchaseOrder.lines.map(
              (line) => line.purchaseOrderLineId,
            ),
          },
        ),
      ],
    },
  };
}

export function RecordSupplierConfirmation(
  purchaseOrder: PurchaseOrder,
  input: {
    confirmationStatus: SupplierConfirmationStatus;
    confirmedBy: string;
    at: string;
    confirmedLineIds: readonly string[];
    rejectedLineIds?: readonly string[];
    reasonNote?: string;
  },
): PurchaseOrderCommandResult {
  if (purchaseOrder.status !== "RELEASED_TO_SUPPLIER")
    return {
      purchaseOrder,
      accepted: false,
      message: "Supplier confirmation requires a released PO.",
    };
  if (input.confirmationStatus !== "ACCEPTED" && !input.reasonNote?.trim())
    return {
      purchaseOrder,
      accepted: false,
      message: "Partial, rejected, or changed confirmation requires a reason.",
    };
  const confirmation: SupplierConfirmation = {
    supplierConfirmationId: `${purchaseOrder.purchaseOrderId}-confirmation-${purchaseOrder.confirmationHistory.length + 1}`,
    purchaseOrderId: purchaseOrder.purchaseOrderId,
    supplierId: purchaseOrder.supplierId,
    confirmationStatus: input.confirmationStatus,
    confirmedBy: input.confirmedBy,
    confirmedAt: input.at,
    confirmedLineSummary: input.confirmedLineIds,
    rejectedLineSummary: input.rejectedLineIds ?? [],
    reasonNote: input.reasonNote,
  };
  const fullyAccepted = input.confirmationStatus === "ACCEPTED";
  const status: PurchaseOrderStatus = fullyAccepted
    ? "READY_FOR_WAREHOUSE_RECEIVING"
    : "SUPPLIER_CONFIRMED";
  const responseIssue = fullyAccepted
    ? []
    : [
        procurementIssue(
          { purchaseOrderId: purchaseOrder.purchaseOrderId },
          "SUPPLIER_RESPONSE_REQUIRES_REVISION",
          "Supplier response requires a visible Procurement revision.",
          "BLOCKING",
        ),
      ];
  const issues = [...purchaseOrder.issues, ...responseIssue];
  const counts = issueCounts(issues);
  const eventType: ProcurementEventType =
    input.confirmationStatus === "ACCEPTED"
      ? "SupplierConfirmed"
      : input.confirmationStatus === "PARTIALLY_ACCEPTED"
        ? "SupplierPartiallyConfirmed"
        : "SupplierRejected";
  return {
    accepted: true,
    purchaseOrder: {
      ...purchaseOrder,
      status,
      issues,
      ...counts,
      lines: purchaseOrder.lines.map((line) => ({
        ...line,
        status: input.confirmedLineIds.includes(line.purchaseOrderLineId)
          ? "CONFIRMED"
          : line.status,
      })),
      supplierConfirmedBy: input.confirmedBy,
      supplierConfirmedAt: input.at,
      readyForWarehouseReceivingAt: fullyAccepted ? input.at : undefined,
      confirmationHistory: [...purchaseOrder.confirmationHistory, confirmation],
      changes: [
        ...purchaseOrder.changes,
        purchaseOrderChange(
          purchaseOrder,
          eventType,
          input.confirmedBy,
          input.at,
          status,
          {
            affectedLineIds: [
              ...input.confirmedLineIds,
              ...(input.rejectedLineIds ?? []),
            ],
            reasonNote: input.reasonNote,
          },
        ),
      ],
    },
  };
}

export function ReplaceSupplier(
  purchaseOrder: PurchaseOrder,
  input: {
    newSupplier: Supplier;
    actorId: string;
    at: string;
    reasonCode?: string;
    reasonNote?: string;
  },
): PurchaseOrderCommandResult {
  if (
    purchaseOrder.status !== "RELEASED_TO_SUPPLIER" &&
    purchaseOrder.status !== "SUPPLIER_CONFIRMED" &&
    purchaseOrder.status !== "READY_FOR_WAREHOUSE_RECEIVING"
  )
    return {
      purchaseOrder,
      accepted: false,
      message: "Supplier replacement requires a released or confirmed PO.",
    };
  if (!input.reasonCode?.trim() && !input.reasonNote?.trim())
    return {
      purchaseOrder,
      accepted: false,
      message: "Supplier replacement requires a reason.",
    };
  if (
    input.newSupplier.status !== "ACTIVE" ||
    purchaseOrder.lines.some(
      (line) => !isEligible(input.newSupplier, line.ingredientId),
    )
  )
    return {
      purchaseOrder,
      accepted: false,
      message:
        "Replacement supplier must be active and eligible for all lines.",
    };
  const revision: ProcurementRevision = {
    procurementRevisionId: `${purchaseOrder.purchaseOrderId}-revision-${purchaseOrder.revisionHistory.length + 1}`,
    originalPurchaseOrderId: purchaseOrder.purchaseOrderId,
    affectedPurchaseOrderLineIds: purchaseOrder.lines.map(
      (line) => line.purchaseOrderLineId,
    ),
    oldSupplierId: purchaseOrder.supplierId,
    newSupplierId: input.newSupplier.supplierId,
    beforeQuantity: purchaseOrder.lines.reduce(
      (sum, line) => sum + line.quantity,
      0,
    ),
    afterQuantity: purchaseOrder.lines.reduce(
      (sum, line) => sum + line.quantity,
      0,
    ),
    purchaseUnit: purchaseOrder.lines[0]?.purchaseUnit ?? "",
    reasonCode: input.reasonCode,
    reasonNote: input.reasonNote,
    revisedBy: input.actorId,
    revisedAt: input.at,
    sourceTraceId: purchaseOrder.lines[0]?.sourceTraceId ?? "",
  };
  const status: PurchaseOrderStatus = "REVISED";
  return {
    accepted: true,
    purchaseOrder: {
      ...purchaseOrder,
      supplierId: input.newSupplier.supplierId,
      status,
      version: purchaseOrder.version + 1,
      lines: purchaseOrder.lines.map((line) => ({
        ...line,
        supplierId: input.newSupplier.supplierId,
        status: "DRAFT",
      })),
      issues: [],
      blockingIssueCount: 0,
      warningCount: 0,
      revisionHistory: [...purchaseOrder.revisionHistory, revision],
      changes: [
        ...purchaseOrder.changes,
        purchaseOrderChange(
          purchaseOrder,
          "SupplierReplacementRecorded",
          input.actorId,
          input.at,
          status,
          {
            affectedLineIds: revision.affectedPurchaseOrderLineIds,
            reasonCode: input.reasonCode,
            reasonNote: input.reasonNote,
            sourceTraceId: revision.sourceTraceId,
          },
        ),
      ],
    },
  };
}

export function ReopenPurchaseOrder(
  purchaseOrder: PurchaseOrder,
  reason: string,
  actorId: string,
  at: string,
): PurchaseOrderCommandResult {
  if (
    (purchaseOrder.status !== "RELEASED_TO_SUPPLIER" &&
      purchaseOrder.status !== "SUPPLIER_CONFIRMED" &&
      purchaseOrder.status !== "READY_FOR_WAREHOUSE_RECEIVING") ||
    !reason.trim()
  )
    return {
      purchaseOrder,
      accepted: false,
      message: "Released or confirmed PO and reopen reason are required.",
    };
  const status: PurchaseOrderStatus = "REOPENED";
  return {
    accepted: true,
    purchaseOrder: {
      ...purchaseOrder,
      status,
      version: purchaseOrder.version + 1,
      lines: purchaseOrder.lines.map((line) => ({
        ...line,
        status: "DRAFT",
      })),
      reopenedBy: actorId,
      reopenedAt: at,
      reopenReason: reason,
      changes: [
        ...purchaseOrder.changes,
        purchaseOrderChange(
          purchaseOrder,
          "PurchaseOrderReopened",
          actorId,
          at,
          status,
          { reasonNote: reason },
        ),
      ],
    },
  };
}

export function CancelPurchaseOrder(
  purchaseOrder: PurchaseOrder,
  reason: string,
  actorId: string,
  at: string,
): PurchaseOrderCommandResult {
  if (purchaseOrder.status === "CANCELLED" || !reason.trim())
    return {
      purchaseOrder,
      accepted: false,
      message: "Active PO and cancellation reason are required.",
    };
  const status: PurchaseOrderStatus = "CANCELLED";
  const cancellationSnapshot: PurchaseOrderCancellationSnapshot = {
    cancelledVersion: purchaseOrder.version,
    supplierId: purchaseOrder.supplierId,
    reason,
    cancelledBy: actorId,
    cancelledAt: at,
    priorReleaseSnapshotCount: purchaseOrder.releaseSnapshots.length,
  };
  return {
    accepted: true,
    purchaseOrder: {
      ...purchaseOrder,
      status,
      lines: purchaseOrder.lines.map((line) => ({
        ...line,
        status: "CANCELLED",
      })),
      cancelledBy: actorId,
      cancelledAt: at,
      cancellationReason: reason,
      cancellationSnapshots: [
        ...purchaseOrder.cancellationSnapshots,
        cancellationSnapshot,
      ],
      changes: [
        ...purchaseOrder.changes,
        purchaseOrderChange(
          purchaseOrder,
          "PurchaseOrderCancelled",
          actorId,
          at,
          status,
          { reasonNote: reason },
        ),
      ],
    },
  };
}

export type ProcurementWorkbenchReadModel = {
  servicePeriod: string;
  purchaseHandoffReference: string;
  demandLineCount: number;
  assignedLineCount: number;
  supplierAssignmentCompleteness: string;
  blockingIssueCount: number;
  warningCount: number;
  purchaseOrderDraftCount: number;
  releasedPurchaseOrderCount: number;
  supplierConfirmationStatus: string;
  nextAvailableAction: string;
  canValidateAllocation: boolean;
  canApproveAllocation: boolean;
  canCreatePurchaseOrderDrafts: boolean;
  canValidatePurchaseOrder: boolean;
  canReleasePurchaseOrder: boolean;
  canRecordSupplierConfirmation: boolean;
};

export function ProcurementWorkbench(
  batch: PurchaseAllocationBatch,
  purchaseOrders: readonly PurchaseOrder[],
): ProcurementWorkbenchReadModel {
  const assignedLineCount = batch.lines.filter(
    (line) => line.supplierId,
  ).length;
  const activeOrder = purchaseOrders.find(
    (purchaseOrder) => purchaseOrder.status !== "CANCELLED",
  );
  const purchaseOrderDraftCount = purchaseOrders.filter(
    (purchaseOrder) => purchaseOrder.status === "DRAFT",
  ).length;
  const releasedPurchaseOrderCount = purchaseOrders.filter(
    (purchaseOrder) => purchaseOrder.releaseSnapshots.length > 0,
  ).length;
  let nextAvailableAction = "Assign suppliers";
  if (batch.status === "PREPARED" && assignedLineCount === batch.lineCount)
    nextAvailableAction = "Validate purchase allocation";
  if (batch.status === "VALIDATED") nextAvailableAction = "Approve allocation";
  if (batch.status === "APPROVED") nextAvailableAction = "Create PO drafts";
  if (activeOrder?.status === "DRAFT") nextAvailableAction = "Validate PO";
  if (activeOrder?.status === "VALIDATED")
    nextAvailableAction = "Release PO to supplier";
  if (activeOrder?.status === "RELEASED_TO_SUPPLIER")
    nextAvailableAction = "Record supplier confirmation";
  if (activeOrder?.status === "READY_FOR_WAREHOUSE_RECEIVING")
    nextAvailableAction = "Supplier commitment ready for Warehouse handoff";
  return {
    servicePeriod: `${batch.periodStart} to ${batch.periodEnd}`,
    purchaseHandoffReference: `${batch.purchaseHandoffReference.purchaseHandoffBatchId}@${batch.purchaseHandoffReference.releasedVersion}`,
    demandLineCount: batch.lineCount,
    assignedLineCount,
    supplierAssignmentCompleteness: `${assignedLineCount}/${batch.lineCount}`,
    blockingIssueCount:
      batch.blockingIssueCount +
      purchaseOrders.reduce(
        (sum, purchaseOrder) => sum + purchaseOrder.blockingIssueCount,
        0,
      ),
    warningCount:
      batch.warningCount +
      purchaseOrders.reduce(
        (sum, purchaseOrder) => sum + purchaseOrder.warningCount,
        0,
      ),
    purchaseOrderDraftCount,
    releasedPurchaseOrderCount,
    supplierConfirmationStatus:
      activeOrder?.confirmationHistory.at(-1)?.confirmationStatus ?? "PENDING",
    nextAvailableAction,
    canValidateAllocation:
      (batch.status === "PREPARED" || batch.status === "REOPENED") &&
      assignedLineCount === batch.lineCount,
    canApproveAllocation:
      batch.status === "VALIDATED" && batch.blockingIssueCount === 0,
    canCreatePurchaseOrderDrafts:
      batch.status === "APPROVED" && batch.blockingIssueCount === 0,
    canValidatePurchaseOrder:
      activeOrder?.status === "DRAFT" ||
      activeOrder?.status === "REOPENED" ||
      activeOrder?.status === "REVISED",
    canReleasePurchaseOrder:
      activeOrder?.status === "VALIDATED" &&
      activeOrder.blockingIssueCount === 0,
    canRecordSupplierConfirmation:
      activeOrder?.status === "RELEASED_TO_SUPPLIER",
  };
}
