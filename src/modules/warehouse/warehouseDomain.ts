import type {
  PurchaseOrder,
  PurchaseOrderLine,
} from "../procurement/procurementDomain";

export type WarehouseIssue = {
  issueCode: string;
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
export type ReceivingLine = {
  receivingLineId: string;
  purchaseOrderLineId: string;
  purchaseAllocationLineId: string;
  purchaseHandoffLineId: string;
  confirmedNeedLineId: string;
  planningInputSetId: string;
  needGenerationRunId: string;
  sourceTraceId: string;
  ingredientId: string;
  supplierConfirmedQuantity: number;
  purchaseUnit: string;
  receivedQuantity: number;
  acceptedQuantity: number;
  rejectedQuantity: number;
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
export type GoodsReceipt = {
  goodsReceiptId: string;
  receivingSessionId: string;
  status: "RELEASED";
  lines: readonly ReceivingLine[];
  releaseSnapshotReference: string;
};
export type StockLot = {
  stockLotId: string;
  goodsReceiptId: string;
  purchaseOrderLineId: string;
  sourceTraceId: string;
  ingredientId: string;
  quantity: number;
  purchaseUnit: string;
  locationId?: string;
  status: "AVAILABLE" | "ON_HOLD" | "QUARANTINED";
};
export type Result<T> = {
  accepted: boolean;
  value?: T;
  blockers: readonly WarehouseIssue[];
  warnings: readonly WarehouseIssue[];
};
const issue = (
  issueCode: string,
  message: string,
  isBlocking: boolean,
  lineId?: string,
): WarehouseIssue => ({ issueCode, message, isBlocking, lineId });
const result = <T>(
  value: T | undefined,
  issues: readonly WarehouseIssue[] = [],
): Result<T> => ({
  accepted: !issues.some((x) => x.isBlocking),
  value,
  blockers: issues.filter((x) => x.isBlocking),
  warnings: issues.filter((x) => !x.isBlocking),
});
const trace = (line: PurchaseOrderLine) => ({
  planningInputSetId: line.purchaseDemandReference.planningInputSetId,
  needGenerationRunId: line.purchaseDemandReference.needGenerationRunId,
});
export function CreateReceivingSessionFromSupplierConfirmedPO(
  po: PurchaseOrder,
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const issues: WarehouseIssue[] = [];
  if (!po.purchaseOrderId)
    issues.push(issue("MISSING_PO", "Purchase order is required.", true));
  if (po.status !== "READY_FOR_WAREHOUSE_RECEIVING")
    issues.push(
      issue("PO_NOT_READY", "PO is not ready for Warehouse handoff.", true),
    );
  if (!po.releaseSnapshots.length)
    issues.push(
      issue(
        "MISSING_RELEASE_SNAPSHOT",
        "PO release snapshot is required.",
        true,
      ),
    );
  if (!po.confirmationHistory.length)
    issues.push(
      issue(
        "MISSING_SUPPLIER_CONFIRMATION",
        "Supplier confirmation is required.",
        true,
      ),
    );
  const lines = po.lines.map((line) => ({
    receivingLineId: `receiving-${line.purchaseOrderLineId}`,
    purchaseOrderLineId: line.purchaseOrderLineId,
    purchaseAllocationLineId: line.purchaseAllocationLineId,
    purchaseHandoffLineId: line.purchaseHandoffLineId,
    confirmedNeedLineId: line.confirmedNeedLineId,
    ...trace(line),
    sourceTraceId: line.sourceTraceId,
    ingredientId: line.ingredientId,
    supplierConfirmedQuantity: line.quantity,
    purchaseUnit: line.purchaseUnit,
    receivedQuantity: 0,
    acceptedQuantity: 0,
    rejectedQuantity: 0,
    discrepancies: [],
  }));
  for (const line of lines)
    if (
      !line.purchaseOrderLineId ||
      !line.sourceTraceId ||
      !line.purchaseAllocationLineId ||
      !line.purchaseHandoffLineId ||
      !line.confirmedNeedLineId
    )
      issues.push(
        issue(
          "MISSING_SOURCE_TRACE",
          "Receiving line must preserve all upstream references.",
          true,
          line.receivingLineId,
        ),
      );
  const session: ReceivingSession = {
    receivingSessionId: `receiving-session-${po.purchaseOrderId}`,
    purchaseOrderId: po.purchaseOrderId,
    purchaseOrderVersion: po.version,
    supplierId: po.supplierId,
    supplierConfirmationReference:
      po.confirmationHistory.at(-1)?.supplierConfirmationId ?? "",
    releaseSnapshotReference: `po-release-${po.releaseSnapshots.at(-1)?.releasedVersion ?? 0}`,
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
  return result(
    {
      ...session,
      status: "IN_PROGRESS",
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
    },
    issues,
  );
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
    locationId?: string;
    lotReference?: string;
  },
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const line = session.lines.find(
    (x) => x.receivingLineId === input.receivingLineId,
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
        "Receiving line is not from the PO.",
        true,
      ),
    );
  if (
    [
      input.receivedQuantity,
      input.acceptedQuantity,
      input.rejectedQuantity,
    ].some((x) => x < 0)
  )
    issues.push(
      issue(
        "NEGATIVE_QUANTITY",
        "Received, accepted, and rejected quantities cannot be below zero.",
        true,
      ),
    );
  if (input.acceptedQuantity + input.rejectedQuantity > input.receivedQuantity)
    issues.push(
      issue(
        "ACCEPTED_REJECTED_EXCEED_RECEIVED",
        "Accepted plus rejected exceeds received without discrepancy.",
        true,
      ),
    );
  if (
    line &&
    input.purchaseUnit !== line.purchaseUnit &&
    !input.unitConversionEvidence
  )
    issues.push(
      issue(
        "UNIT_MISMATCH",
        "Purchase unit requires conversion evidence.",
        true,
      ),
    );
  const lines = session.lines.map((x) =>
    x.receivingLineId === input.receivingLineId
      ? {
          ...x,
          receivedQuantity: input.receivedQuantity,
          acceptedQuantity: input.acceptedQuantity,
          rejectedQuantity: input.rejectedQuantity,
          locationId: input.locationId,
          lotReference: input.lotReference,
        }
      : x,
  );
  return result(
    {
      ...session,
      lines,
      issues,
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
    },
    issues,
  );
}
export function RecordReceivingDiscrepancy(
  session: ReceivingSession,
  input: Omit<WarehouseDiscrepancy, "warehouseDiscrepancyId">,
  actorId: string,
  at: string,
): Result<ReceivingSession> {
  const lines = session.lines.map((line) =>
    line.receivingLineId === input.receivingLineId
      ? {
          ...line,
          discrepancies: [
            ...line.discrepancies,
            {
              ...input,
              warehouseDiscrepancyId: `${line.receivingLineId}-${input.type}`,
            },
          ],
        }
      : line,
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
    const types = line.discrepancies.map((x) => x.type);
    if (
      line.receivedQuantity > line.supplierConfirmedQuantity &&
      !types.includes("OVERAGE")
    )
      issues.push(
        issue(
          "OVERAGE_WITHOUT_DISCREPANCY",
          "Overage requires a discrepancy.",
          true,
          line.receivingLineId,
        ),
      );
    if (
      line.receivedQuantity < line.supplierConfirmedQuantity &&
      !types.includes("SHORTAGE")
    )
      issues.push(
        issue(
          "SHORTAGE_WITHOUT_DISCREPANCY",
          "Shortage requires a discrepancy.",
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
    if (line.rejectedQuantity > 0)
      issues.push(
        issue(
          "DAMAGED_GOODS",
          "Rejected goods need follow-up.",
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
  return result(
    {
      ...session,
      status: "VALIDATED",
      issues,
      changes: [
        ...session.changes,
        {
          eventType: "ReceivingSessionValidated",
          actorId,
          at,
          beforeStatus: session.status,
          afterStatus: "VALIDATED",
        },
      ],
    },
    issues,
  );
}
export function ReleaseGoodsReceipt(
  session: ReceivingSession,
  actorId: string,
  at: string,
): Result<{ session: ReceivingSession; goodsReceipt: GoodsReceipt }> {
  const issues =
    session.status !== "VALIDATED" || session.issues.some((x) => x.isBlocking)
      ? [
          issue(
            "RECEIPT_RELEASE_BLOCKED",
            "Validated session without blockers is required.",
            true,
          ),
        ]
      : [];
  const updated = {
    ...session,
    status: "RELEASED_AS_GOODS_RECEIPT" as const,
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
  return result(
    {
      session: updated,
      goodsReceipt: {
        goodsReceiptId: `gr-${session.receivingSessionId}`,
        receivingSessionId: session.receivingSessionId,
        status: "RELEASED",
        lines: session.lines,
        releaseSnapshotReference: session.releaseSnapshotReference,
      },
    },
    issues,
  );
}
export function CreateStockFromGoodsReceipt(
  receipt: GoodsReceipt,
): Result<readonly StockLot[]> {
  const issues =
    receipt.status !== "RELEASED"
      ? [
          issue(
            "GOODS_RECEIPT_UNRELEASED",
            "Released goods receipt is required.",
            true,
          ),
        ]
      : [];
  const lots = receipt.lines
    .filter((x) => x.acceptedQuantity > 0)
    .map((x) => ({
      stockLotId: `stock-${x.receivingLineId}`,
      goodsReceiptId: receipt.goodsReceiptId,
      purchaseOrderLineId: x.purchaseOrderLineId,
      sourceTraceId: x.sourceTraceId,
      ingredientId: x.ingredientId,
      quantity: x.acceptedQuantity,
      purchaseUnit: x.purchaseUnit,
      locationId: x.locationId,
      status: (x.rejectedQuantity > 0
        ? "ON_HOLD"
        : "AVAILABLE") as StockLot["status"],
    }));
  if (!lots.length)
    issues.push(
      issue(
        "NO_ACCEPTED_STOCK",
        "Accepted quantity is required to create stock.",
        true,
      ),
    );
  return result(lots, issues);
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
  !locationId
    ? result(stock, [issue("MISSING_LOCATION", "Location is required.", true)])
    : result({ ...stock, locationId });
export const ReopenReceivingSession = (
  session: ReceivingSession,
  actorId: string,
  at: string,
  reason: string,
): Result<ReceivingSession> =>
  !reason
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
  !reason || !["PREPARED", "IN_PROGRESS"].includes(session.status)
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
