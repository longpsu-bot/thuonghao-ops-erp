import type { PurchaseOrder } from "../procurement/procurementDomain";

export type WarehouseIssueCode =
  | "MISSING_PO"
  | "PO_NOT_READY"
  | "MISSING_RELEASE_SNAPSHOT"
  | "MISSING_SUPPLIER_CONFIRMATION"
  | "MISSING_REQUIRED_UPSTREAM_TRACE"
  | "MISSING_PO_LINE_REFERENCE"
  | "RECEIVING_NOT_STARTABLE"
  | "RECEIVING_NOT_IN_PROGRESS"
  | "NEGATIVE_QUANTITY"
  | "ACCEPTED_REJECTED_EXCEED_RECEIVED"
  | "UNIT_MISMATCH"
  | "OVERAGE_WITHOUT_DISCREPANCY"
  | "SHORTAGE_WITHOUT_DISCREPANCY"
  | "PARTIAL_DELIVERY"
  | "OVERAGE_DELIVERY"
  | "DAMAGED_GOODS"
  | "MISSING_SUPPLIER_DOCUMENT"
  | "STORAGE_LOCATION_NOT_ASSIGNED"
  | "LOT_MISSING"
  | "QA_HOLD_RECOMMENDED"
  | "RECEIPT_RELEASE_BLOCKED"
  | "GOODS_RECEIPT_UNRELEASED"
  | "NO_ACCEPTED_STOCK"
  | "STOCK_NOT_ON_HOLD"
  | "MISSING_LOCATION"
  | "REOPEN_REASON_REQUIRED"
  | "CANCEL_BLOCKED";

export type WarehouseIssue = {
  issueCode: WarehouseIssueCode;
  message: string;
  isBlocking: boolean;
  lineId?: string;
};

export type WarehouseChange = {
  eventType: string;
  actorId: string;
  at: string;
  beforeStatus?: string;
  afterStatus: string;
};

export type WarehouseDiscrepancy = {
  warehouseDiscrepancyId: string;
  receivingLineId: string;
  type:
    "SHORTAGE" | "OVERAGE" | "DAMAGE" | "MISSING_DOCUMENT" | "UNIT_MISMATCH";
  note: string;
};

export type WarehouseUpstreamSnapshot = {
  purchaseOrderId: string;
  purchaseOrderVersion: number;
  purchaseOrderLineId: string;
  purchaseAllocationLineId: string;
  purchaseHandoffLineId: string;
  confirmedNeedLineId: string;
  needGenerationRunId: string;
  planningInputSetId: string;
  sourceTraceId: string;
  supplierId: string;
  supplierConfirmationReference: string;
  releaseSnapshotReference: string;
  ingredientId: string;
  supplierConfirmedQuantity: number;
  purchaseUnit: string;
};

export type ReceivingLine = WarehouseUpstreamSnapshot & {
  receivingLineId: string;
  receivedQuantity: number;
  acceptedQuantity: number;
  rejectedQuantity: number;
  unitConversionEvidence?: string;
  supplierDocumentReference?: string;
  locationId?: string;
  lotReference?: string;
  discrepancies: readonly WarehouseDiscrepancy[];
};

export type ReceivingSession = {
  receivingSessionId: string;
  purchaseOrderId: string;
  purchaseOrderVersion: number;
  supplierId: string;
  supplierConfirmationReference: string;
  releaseSnapshotReference: string;
  status:
    | "PREPARED"
    | "IN_PROGRESS"
    | "VALIDATED"
    | "RELEASED_AS_GOODS_RECEIPT"
    | "REOPENED"
    | "CANCELLED";
  lines: readonly ReceivingLine[];
  issues: readonly WarehouseIssue[];
  changes: readonly WarehouseChange[];
};

export type GoodsReceiptLine = ReceivingLine;

export type GoodsReceipt = {
  goodsReceiptId: string;
  receivingSessionId: string;
  status: "RELEASED";
  lines: readonly GoodsReceiptLine[];
};

export type StockLot = WarehouseUpstreamSnapshot & {
  stockLotId: string;
  goodsReceiptId: string;
  quantity: number;
  locationId?: string;
  lotReference?: string;
  status: "AVAILABLE" | "ON_HOLD" | "QUARANTINED";
};

export type Result<T> = {
  accepted: boolean;
  value?: T;
  blockers: readonly WarehouseIssue[];
  warnings: readonly WarehouseIssue[];
};

const issue = (
  issueCode: WarehouseIssueCode,
  message: string,
  isBlocking: boolean,
  lineId?: string,
): WarehouseIssue => ({ issueCode, message, isBlocking, lineId });

const result = <T>(
  value: T | undefined,
  issues: readonly WarehouseIssue[] = [],
): Result<T> => ({
  accepted: !issues.some((candidate) => candidate.isBlocking),
  value,
  blockers: issues.filter((candidate) => candidate.isBlocking),
  warnings: issues.filter((candidate) => !candidate.isBlocking),
});

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

function missingUpstreamFields(snapshot: WarehouseUpstreamSnapshot) {
  return upstreamFields.filter((field) => {
    const value = snapshot[field];
    return typeof value === "number"
      ? !Number.isFinite(value) ||
          (field === "purchaseOrderVersion" && value <= 0)
      : !value.trim();
  });
}

function upstreamIssue(
  snapshot: WarehouseUpstreamSnapshot,
  lineId: string,
): WarehouseIssue | undefined {
  const missing = missingUpstreamFields(snapshot);
  return missing.length
    ? issue(
        "MISSING_REQUIRED_UPSTREAM_TRACE",
        `Required upstream trace is missing: ${missing.join(", ")}.`,
        true,
        lineId,
      )
    : undefined;
}

export function CreateReceivingSessionFromSupplierConfirmedPO(
  po: PurchaseOrder,
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const issues: WarehouseIssue[] = [];
  const releaseSnapshot = po.releaseSnapshots.at(-1);
  const supplierConfirmation = po.confirmationHistory.at(-1);
  if (!po.purchaseOrderId)
    issues.push(issue("MISSING_PO", "Purchase order is required.", true));
  if (po.status !== "READY_FOR_WAREHOUSE_RECEIVING")
    issues.push(
      issue("PO_NOT_READY", "PO is not ready for Warehouse handoff.", true),
    );
  if (!releaseSnapshot)
    issues.push(
      issue(
        "MISSING_RELEASE_SNAPSHOT",
        "PO release snapshot is required.",
        true,
      ),
    );
  if (!supplierConfirmation?.supplierConfirmationId)
    issues.push(
      issue(
        "MISSING_SUPPLIER_CONFIRMATION",
        "Supplier confirmation is required.",
        true,
      ),
    );

  const releaseSnapshotReference = releaseSnapshot
    ? `${po.purchaseOrderId}@release-${releaseSnapshot.releasedVersion}`
    : "";
  const supplierConfirmationReference =
    supplierConfirmation?.supplierConfirmationId ?? "";
  const lines: ReceivingLine[] = po.lines.map((line) => ({
    receivingLineId: `receiving-${line.purchaseOrderLineId || "missing-line"}`,
    purchaseOrderId: po.purchaseOrderId,
    purchaseOrderVersion: po.version,
    purchaseOrderLineId: line.purchaseOrderLineId,
    purchaseAllocationLineId: line.purchaseAllocationLineId,
    purchaseHandoffLineId: line.purchaseHandoffLineId,
    confirmedNeedLineId: line.confirmedNeedLineId,
    needGenerationRunId: line.purchaseDemandReference.needGenerationRunId,
    planningInputSetId: line.purchaseDemandReference.planningInputSetId,
    sourceTraceId: line.sourceTraceId,
    supplierId: po.supplierId,
    supplierConfirmationReference,
    releaseSnapshotReference,
    ingredientId: line.ingredientId,
    supplierConfirmedQuantity: line.quantity,
    purchaseUnit: line.purchaseUnit,
    receivedQuantity: 0,
    acceptedQuantity: 0,
    rejectedQuantity: 0,
    discrepancies: [],
  }));

  for (const line of lines) {
    const traceIssue = upstreamIssue(line, line.receivingLineId);
    if (traceIssue) issues.push(traceIssue);
  }

  const session: ReceivingSession = {
    receivingSessionId: `receiving-session-${po.purchaseOrderId}`,
    purchaseOrderId: po.purchaseOrderId,
    purchaseOrderVersion: po.version,
    supplierId: po.supplierId,
    supplierConfirmationReference,
    releaseSnapshotReference,
    status: "PREPARED",
    lines,
    issues,
    changes: [
      {
        eventType: "ReceivingSessionCreated",
        actorId,
        at,
        afterStatus: "PREPARED",
      },
    ],
  };
  return result(session, issues);
}

export function StartReceivingSession(
  session: ReceivingSession,
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const issues =
    session.status !== "PREPARED" && session.status !== "REOPENED"
      ? [
          issue(
            "RECEIVING_NOT_STARTABLE",
            "Session must be prepared or reopened.",
            true,
          ),
        ]
      : [];
  const value = issues.length
    ? session
    : {
        ...session,
        status: "IN_PROGRESS" as const,
        issues,
        changes: [
          ...session.changes,
          {
            eventType: "ReceivingSessionStarted",
            actorId,
            at,
            beforeStatus: session.status,
            afterStatus: "IN_PROGRESS",
          },
        ],
      };
  return result(value, issues);
}

export function RecordReceivingLine(
  session: ReceivingSession,
  input: {
    receivingLineId: string;
    receivedQuantity: number;
    acceptedQuantity: number;
    rejectedQuantity: number;
    purchaseUnit: string;
    unitConversionEvidence?: string;
    supplierDocumentReference?: string;
    locationId?: string;
    lotReference?: string;
  },
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const line = session.lines.find(
    (candidate) => candidate.receivingLineId === input.receivingLineId,
  );
  const issues: WarehouseIssue[] = [];
  if (session.status !== "IN_PROGRESS")
    issues.push(
      issue("RECEIVING_NOT_IN_PROGRESS", "Session must be in progress.", true),
    );
  if (!line)
    issues.push(
      issue(
        "MISSING_PO_LINE_REFERENCE",
        "Receiving line is not from the supplier-confirmed PO.",
        true,
        input.receivingLineId,
      ),
    );
  if (
    [
      input.receivedQuantity,
      input.acceptedQuantity,
      input.rejectedQuantity,
    ].some((quantity) => quantity < 0)
  )
    issues.push(
      issue(
        "NEGATIVE_QUANTITY",
        "Received, accepted, and rejected quantities cannot be below zero.",
        true,
        input.receivingLineId,
      ),
    );
  if (input.acceptedQuantity + input.rejectedQuantity > input.receivedQuantity)
    issues.push(
      issue(
        "ACCEPTED_REJECTED_EXCEED_RECEIVED",
        "Accepted plus rejected cannot exceed received quantity.",
        true,
        input.receivingLineId,
      ),
    );
  if (
    line &&
    input.purchaseUnit !== line.purchaseUnit &&
    !input.unitConversionEvidence?.trim()
  )
    issues.push(
      issue(
        "UNIT_MISMATCH",
        "Purchase-unit mismatch requires conversion evidence.",
        true,
        input.receivingLineId,
      ),
    );
  if (line) {
    const traceIssue = upstreamIssue(line, line.receivingLineId);
    if (traceIssue) issues.push(traceIssue);
  }

  if (issues.some((candidate) => candidate.isBlocking))
    return result({ ...session, issues }, issues);

  const lines = session.lines.map((candidate) =>
    candidate.receivingLineId === input.receivingLineId
      ? {
          ...candidate,
          receivedQuantity: input.receivedQuantity,
          acceptedQuantity: input.acceptedQuantity,
          rejectedQuantity: input.rejectedQuantity,
          unitConversionEvidence: input.unitConversionEvidence,
          supplierDocumentReference: input.supplierDocumentReference,
          locationId: input.locationId,
          lotReference: input.lotReference,
        }
      : candidate,
  );
  return result({
    ...session,
    lines,
    issues: [],
    changes: [
      ...session.changes,
      {
        eventType: "ReceivingLineRecorded",
        actorId,
        at,
        beforeStatus: session.status,
        afterStatus: session.status,
      },
    ],
  });
}

export function RecordReceivingDiscrepancy(
  session: ReceivingSession,
  input: Omit<WarehouseDiscrepancy, "warehouseDiscrepancyId">,
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const line = session.lines.find(
    (candidate) => candidate.receivingLineId === input.receivingLineId,
  );
  if (!line)
    return result(session, [
      issue(
        "MISSING_PO_LINE_REFERENCE",
        "Discrepancy must reference a receiving line from the PO.",
        true,
        input.receivingLineId,
      ),
    ]);
  const lines = session.lines.map((candidate) =>
    candidate.receivingLineId === input.receivingLineId
      ? {
          ...candidate,
          discrepancies: [
            ...candidate.discrepancies,
            {
              ...input,
              warehouseDiscrepancyId: `${candidate.receivingLineId}-${input.type}-${candidate.discrepancies.length + 1}`,
            },
          ],
        }
      : candidate,
  );
  return result({
    ...session,
    lines,
    changes: [
      ...session.changes,
      {
        eventType: "ReceivingDiscrepancyRecorded",
        actorId,
        at,
        beforeStatus: session.status,
        afterStatus: session.status,
      },
    ],
  });
}

export function ValidateReceivingSession(
  session: ReceivingSession,
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const issues: WarehouseIssue[] = [];
  for (const line of session.lines) {
    const traceIssue = upstreamIssue(line, line.receivingLineId);
    if (traceIssue) issues.push(traceIssue);
    if (
      [
        line.receivedQuantity,
        line.acceptedQuantity,
        line.rejectedQuantity,
      ].some((quantity) => quantity < 0)
    )
      issues.push(
        issue(
          "NEGATIVE_QUANTITY",
          "Received, accepted, and rejected quantities cannot be below zero.",
          true,
          line.receivingLineId,
        ),
      );
    if (line.acceptedQuantity + line.rejectedQuantity > line.receivedQuantity)
      issues.push(
        issue(
          "ACCEPTED_REJECTED_EXCEED_RECEIVED",
          "Accepted plus rejected cannot exceed received quantity.",
          true,
          line.receivingLineId,
        ),
      );
    const discrepancyTypes = line.discrepancies.map(
      (discrepancy) => discrepancy.type,
    );
    if (
      line.receivedQuantity > line.supplierConfirmedQuantity &&
      !discrepancyTypes.includes("OVERAGE")
    )
      issues.push(
        issue(
          "OVERAGE_WITHOUT_DISCREPANCY",
          "Overage requires an explicit discrepancy.",
          true,
          line.receivingLineId,
        ),
      );
    if (
      line.receivedQuantity < line.supplierConfirmedQuantity &&
      !discrepancyTypes.includes("SHORTAGE")
    )
      issues.push(
        issue(
          "SHORTAGE_WITHOUT_DISCREPANCY",
          "Shortage requires an explicit discrepancy.",
          true,
          line.receivingLineId,
        ),
      );
    if (line.receivedQuantity < line.supplierConfirmedQuantity)
      issues.push(
        issue(
          "PARTIAL_DELIVERY",
          "Partial delivery recorded.",
          false,
          line.receivingLineId,
        ),
      );
    if (line.receivedQuantity > line.supplierConfirmedQuantity)
      issues.push(
        issue(
          "OVERAGE_DELIVERY",
          "Overage delivery recorded.",
          false,
          line.receivingLineId,
        ),
      );
    if (line.rejectedQuantity > 0 || discrepancyTypes.includes("DAMAGE")) {
      issues.push(
        issue(
          "DAMAGED_GOODS",
          "Damaged or rejected goods require follow-up.",
          false,
          line.receivingLineId,
        ),
      );
      issues.push(
        issue(
          "QA_HOLD_RECOMMENDED",
          "A warehouse hold is recommended pending the external QA decision.",
          false,
          line.receivingLineId,
        ),
      );
    }
    if (
      !line.supplierDocumentReference ||
      discrepancyTypes.includes("MISSING_DOCUMENT")
    )
      issues.push(
        issue(
          "MISSING_SUPPLIER_DOCUMENT",
          "Supplier delivery document is missing.",
          false,
          line.receivingLineId,
        ),
      );
    if (!line.locationId)
      issues.push(
        issue(
          "STORAGE_LOCATION_NOT_ASSIGNED",
          "Storage location is not assigned.",
          false,
          line.receivingLineId,
        ),
      );
    if (!line.lotReference)
      issues.push(
        issue(
          "LOT_MISSING",
          "Lot/batch information is missing.",
          false,
          line.receivingLineId,
        ),
      );
  }
  const accepted = !issues.some((candidate) => candidate.isBlocking);
  const status = accepted ? "VALIDATED" : session.status;
  const value: ReceivingSession = {
    ...session,
    status,
    issues,
    changes: [
      ...session.changes,
      {
        eventType: accepted
          ? "ReceivingSessionValidated"
          : "ReceivingValidationFailed",
        actorId,
        at,
        beforeStatus: session.status,
        afterStatus: status,
      },
    ],
  };
  return result(value, issues);
}

export function ReleaseGoodsReceipt(
  session: ReceivingSession,
  actorId: string,
  at: string,
): Result<{ session: ReceivingSession; goodsReceipt: GoodsReceipt }> {
  const issues =
    session.status !== "VALIDATED" ||
    session.issues.some((item) => item.isBlocking)
      ? [
          issue(
            "RECEIPT_RELEASE_BLOCKED",
            "Validated session without blockers is required.",
            true,
          ),
        ]
      : [];
  if (issues.length)
    return result<{ session: ReceivingSession; goodsReceipt: GoodsReceipt }>(
      undefined,
      issues,
    );
  const updated: ReceivingSession = {
    ...session,
    status: "RELEASED_AS_GOODS_RECEIPT",
    changes: [
      ...session.changes,
      {
        eventType: "GoodsReceiptReleased",
        actorId,
        at,
        beforeStatus: session.status,
        afterStatus: "RELEASED_AS_GOODS_RECEIPT",
      },
    ],
  };
  return result({
    session: updated,
    goodsReceipt: {
      goodsReceiptId: `gr-${session.receivingSessionId}`,
      receivingSessionId: session.receivingSessionId,
      status: "RELEASED",
      lines: session.lines.map((line) => ({ ...line })),
    },
  });
}

export function CreateStockFromGoodsReceipt(
  receipt: GoodsReceipt,
): Result<readonly StockLot[]> {
  const issues: WarehouseIssue[] = [];
  if (receipt.status !== "RELEASED")
    issues.push(
      issue(
        "GOODS_RECEIPT_UNRELEASED",
        "Released goods receipt is required.",
        true,
      ),
    );
  for (const line of receipt.lines) {
    const traceIssue = upstreamIssue(line, line.receivingLineId);
    if (traceIssue) issues.push(traceIssue);
  }
  const lots = receipt.lines
    .filter((line) => line.acceptedQuantity > 0)
    .map<StockLot>((line) => ({
      stockLotId: `stock-${line.receivingLineId}`,
      goodsReceiptId: receipt.goodsReceiptId,
      purchaseOrderId: line.purchaseOrderId,
      purchaseOrderVersion: line.purchaseOrderVersion,
      purchaseOrderLineId: line.purchaseOrderLineId,
      purchaseAllocationLineId: line.purchaseAllocationLineId,
      purchaseHandoffLineId: line.purchaseHandoffLineId,
      confirmedNeedLineId: line.confirmedNeedLineId,
      needGenerationRunId: line.needGenerationRunId,
      planningInputSetId: line.planningInputSetId,
      sourceTraceId: line.sourceTraceId,
      supplierId: line.supplierId,
      supplierConfirmationReference: line.supplierConfirmationReference,
      releaseSnapshotReference: line.releaseSnapshotReference,
      ingredientId: line.ingredientId,
      supplierConfirmedQuantity: line.supplierConfirmedQuantity,
      purchaseUnit: line.purchaseUnit,
      quantity: line.acceptedQuantity,
      locationId: line.locationId,
      lotReference: line.lotReference,
      status:
        line.rejectedQuantity > 0 ||
        line.discrepancies.some((discrepancy) => discrepancy.type === "DAMAGE")
          ? "ON_HOLD"
          : "AVAILABLE",
    }));
  if (!lots.length)
    issues.push(
      issue(
        "NO_ACCEPTED_STOCK",
        "Accepted quantity is required to create stock.",
        true,
      ),
    );
  return result(
    issues.some((candidate) => candidate.isBlocking) ? undefined : lots,
    issues,
  );
}

export const PlaceStockOnHold = (stock: StockLot): Result<StockLot> =>
  result({ ...stock, status: "ON_HOLD" });

export const ReleaseStockHold = (stock: StockLot): Result<StockLot> =>
  stock.status !== "ON_HOLD"
    ? result(stock, [
        issue("STOCK_NOT_ON_HOLD", "Only held stock can be released.", true),
      ])
    : result({ ...stock, status: "AVAILABLE" });

export const MoveStockLocation = (
  stock: StockLot,
  locationId: string,
): Result<StockLot> =>
  !locationId.trim()
    ? result(stock, [issue("MISSING_LOCATION", "Location is required.", true)])
    : result({ ...stock, locationId });

export const ReopenReceivingSession = (
  session: ReceivingSession,
  actorId: string,
  at: string,
  reason: string,
): Result<ReceivingSession> =>
  !reason.trim()
    ? result(session, [
        issue("REOPEN_REASON_REQUIRED", "Reopen reason is required.", true),
      ])
    : result({
        ...session,
        status: "REOPENED",
        changes: [
          ...session.changes,
          {
            eventType: "ReceivingSessionReopened",
            actorId,
            at,
            beforeStatus: session.status,
            afterStatus: "REOPENED",
          },
        ],
      });

export const CancelReceivingSession = (
  session: ReceivingSession,
  actorId: string,
  at: string,
  reason: string,
): Result<ReceivingSession> =>
  !reason.trim() || !["PREPARED", "IN_PROGRESS"].includes(session.status)
    ? result(session, [
        issue(
          "CANCEL_BLOCKED",
          "Only prepared/in-progress sessions with a reason can be cancelled.",
          true,
        ),
      ])
    : result({
        ...session,
        status: "CANCELLED",
        changes: [
          ...session.changes,
          {
            eventType: "ReceivingSessionCancelled",
            actorId,
            at,
            beforeStatus: session.status,
            afterStatus: "CANCELLED",
          },
        ],
      });
