import type {
  ConfirmedNeedBatch,
  ConfirmedNeedLine,
  ConfirmedNeedStatus,
} from "../confirmed-need/confirmedNeedDomain";

export type PurchaseHandoffStatus =
  | "PREPARED"
  | "VALIDATED"
  | "RELEASED_TO_PROCUREMENT"
  | "REOPENED"
  | "INVALIDATED";
export type PurchaseHandoffIssueSeverity = "BLOCKING" | "WARNING";

export type PurchaseDemandReference = {
  confirmedNeedBatchId: string;
  confirmedNeedBatchVersion: number;
  confirmedNeedLineId: string;
  theoreticalNeedLineId: string;
  needGenerationRunId: string;
  planningInputSetId: string;
  weeklyMenuReference: string;
  attendanceReference: string;
  recipeBomReference?: string;
  sourceTraceId: string;
  approvedConfirmedQuantity: number;
  approvedConfirmedUnit: string;
};

export type PurchaseHandoffLine = {
  purchaseHandoffLineId: string;
  purchaseHandoffBatchId: string;
  confirmedNeedLineId: string;
  serviceDate: string;
  schoolId?: string;
  ingredientId: string;
  quantity: number;
  purchaseUnit: string;
  deliveryRequirement?: string;
  sourceTraceId: string;
  purchaseDemandReference: PurchaseDemandReference;
  status: "PREPARED" | "VALIDATED" | "RELEASED";
};

export type PurchaseHandoffIssue = {
  purchaseHandoffIssueId: string;
  purchaseHandoffBatchId: string;
  purchaseHandoffLineId?: string;
  severity: PurchaseHandoffIssueSeverity;
  issueCode:
    | "MISSING_CONFIRMED_NEED_REFERENCE"
    | "MISSING_SOURCE_TRACE"
    | "MISSING_INGREDIENT"
    | "MISSING_PURCHASE_UNIT"
    | "NEGATIVE_QUANTITY"
    | "ZERO_QUANTITY"
    | "FORBIDDEN_PROCUREMENT_FIELD";
  message: string;
  isBlocking: boolean;
};

export type PurchaseHandoffChange = {
  eventId: string;
  eventType:
    | "PurchaseHandoffPrepared"
    | "PurchaseHandoffValidated"
    | "PurchaseHandoffValidationFailed"
    | "PurchaseHandoffReleasedToProcurement"
    | "PurchaseHandoffReopened"
    | "PurchaseHandoffInvalidated";
  purchaseHandoffBatchId: string;
  actorId: string;
  at: string;
  affectedLineIds?: readonly string[];
  beforeStatus?: PurchaseHandoffStatus;
  afterStatus: PurchaseHandoffStatus;
  reason?: string;
  affectedSource?: string;
};

export type PurchaseHandoffReleaseSnapshot = {
  releasedVersion: number;
  confirmedNeedBatchVersion: number;
  lines: readonly {
    purchaseHandoffLineId: string;
    confirmedNeedLineId: string;
    quantity: number;
    purchaseUnit: string;
  }[];
  blockingIssueCount: number;
  warningCount: number;
  releasedBy: string;
  releasedAt: string;
};

export type PurchaseHandoffBatch = {
  purchaseHandoffBatchId: string;
  confirmedNeedBatchId: string;
  periodStart: string;
  periodEnd: string;
  status: PurchaseHandoffStatus;
  confirmedNeedStatus: ConfirmedNeedStatus;
  confirmedNeedReference: {
    confirmedNeedBatchId: string;
    batchVersion: number;
    releasedBy: string;
    releasedAt: string;
  };
  lines: readonly PurchaseHandoffLine[];
  issues: readonly PurchaseHandoffIssue[];
  lineCount: number;
  blockingIssueCount: number;
  warningCount: number;
  preparedBy: string;
  preparedAt: string;
  validatedBy?: string;
  validatedAt?: string;
  releasedBy?: string;
  releasedAt?: string;
  releaseSnapshots: readonly PurchaseHandoffReleaseSnapshot[];
  reopenedBy?: string;
  reopenedAt?: string;
  reopenReason?: string;
  invalidatedBy?: string;
  invalidatedAt?: string;
  invalidationReason?: string;
  invalidatedSource?: string;
  version: number;
  changes: readonly PurchaseHandoffChange[];
};

export type PurchaseHandoffCommandResult = {
  batch?: PurchaseHandoffBatch;
  accepted: boolean;
  message?: string;
};

const counts = (issues: readonly PurchaseHandoffIssue[]) => ({
  blockingIssueCount: issues.filter((issue) => issue.isBlocking).length,
  warningCount: issues.filter((issue) => !issue.isBlocking).length,
});

const forbiddenFieldNames = [
  "supplierId",
  "supplierAssignment",
  "supplierSplit",
  "purchaseOrderId",
  "purchaseOrderLineId",
] as const;

function hasForbiddenProcurementFields(line: PurchaseHandoffLine) {
  return forbiddenFieldNames.some((field) => field in (line as object));
}

function evaluateIssues(
  batchId: string,
  lines: readonly PurchaseHandoffLine[],
): PurchaseHandoffIssue[] {
  const issues: PurchaseHandoffIssue[] = [];
  const add = (
    line: PurchaseHandoffLine,
    issueCode: PurchaseHandoffIssue["issueCode"],
    message: string,
    severity: PurchaseHandoffIssueSeverity,
  ) =>
    issues.push({
      purchaseHandoffIssueId: `${batchId}-issue-${issues.length + 1}`,
      purchaseHandoffBatchId: batchId,
      purchaseHandoffLineId: line.purchaseHandoffLineId,
      severity,
      issueCode,
      message,
      isBlocking: severity === "BLOCKING",
    });
  for (const line of lines) {
    if (!line.confirmedNeedLineId)
      add(
        line,
        "MISSING_CONFIRMED_NEED_REFERENCE",
        "Handoff line must reference a stable Confirmed Need line.",
        "BLOCKING",
      );
    if (
      !line.sourceTraceId ||
      !line.purchaseDemandReference.theoreticalNeedLineId ||
      !line.purchaseDemandReference.planningInputSetId
    )
      add(
        line,
        "MISSING_SOURCE_TRACE",
        "Handoff line must retain its approved demand and upstream trace.",
        "BLOCKING",
      );
    if (!line.ingredientId)
      add(
        line,
        "MISSING_INGREDIENT",
        "Handoff line requires an ingredient reference.",
        "BLOCKING",
      );
    if (!line.purchaseUnit.trim())
      add(
        line,
        "MISSING_PURCHASE_UNIT",
        "Handoff line requires a purchase unit.",
        "BLOCKING",
      );
    if (line.quantity < 0)
      add(
        line,
        "NEGATIVE_QUANTITY",
        "Handoff quantity cannot be negative.",
        "BLOCKING",
      );
    else if (line.quantity === 0)
      add(
        line,
        "ZERO_QUANTITY",
        "Zero quantity should be excluded from Procurement intake.",
        "WARNING",
      );
    if (hasForbiddenProcurementFields(line))
      add(
        line,
        "FORBIDDEN_PROCUREMENT_FIELD",
        "Supplier selection and purchase-order fields belong to Procurement, not Purchase Handoff.",
        "BLOCKING",
      );
  }
  return issues;
}

function reference(
  batch: ConfirmedNeedBatch,
  line: ConfirmedNeedLine,
): PurchaseDemandReference {
  return {
    confirmedNeedBatchId: batch.confirmedNeedBatchId,
    confirmedNeedBatchVersion: batch.version,
    confirmedNeedLineId: line.confirmedNeedLineId,
    theoreticalNeedLineId: line.theoreticalNeedLineId,
    needGenerationRunId: batch.needGenerationRunId,
    planningInputSetId: line.sourceReference.planningInputSetId,
    weeklyMenuReference: line.sourceReference.weeklyMenuReference,
    attendanceReference: line.sourceReference.attendanceReference,
    recipeBomReference: line.sourceReference.recipeBomReference,
    sourceTraceId: line.sourceTraceId,
    approvedConfirmedQuantity: line.confirmedQuantity,
    approvedConfirmedUnit: line.unit,
  };
}

function change(
  batch: PurchaseHandoffBatch,
  eventType: PurchaseHandoffChange["eventType"],
  actorId: string,
  at: string,
  afterStatus: PurchaseHandoffStatus,
  extra: Partial<PurchaseHandoffChange> = {},
): PurchaseHandoffChange {
  return {
    eventId: `${batch.purchaseHandoffBatchId}-event-${batch.changes.length + 1}`,
    eventType,
    purchaseHandoffBatchId: batch.purchaseHandoffBatchId,
    actorId,
    at,
    beforeStatus: batch.status,
    afterStatus,
    ...extra,
  };
}

export function CreatePurchaseHandoffFromConfirmedNeeds(input: {
  purchaseHandoffBatchId: string;
  confirmedNeedBatch: ConfirmedNeedBatch;
  actorId: string;
  at: string;
}): PurchaseHandoffCommandResult {
  const source = input.confirmedNeedBatch;
  if (
    (source.status !== "APPROVED" &&
      source.status !== "RELEASED_FOR_PURCHASE_HANDOFF") ||
    !source.releasedBy ||
    !source.releasedAt
  )
    return {
      accepted: false,
      message:
        "Purchase Handoff requires Approved demand released for Purchase Handoff.",
    };
  const lines: PurchaseHandoffLine[] = source.lines.map((line, index) => ({
    purchaseHandoffLineId: `${input.purchaseHandoffBatchId}-line-${index + 1}`,
    purchaseHandoffBatchId: input.purchaseHandoffBatchId,
    confirmedNeedLineId: line.confirmedNeedLineId,
    serviceDate: line.serviceDate,
    schoolId: line.schoolId,
    ingredientId: line.ingredientId,
    quantity: line.confirmedQuantity,
    purchaseUnit: line.unit,
    sourceTraceId: line.sourceTraceId,
    purchaseDemandReference: reference(source, line),
    status: "PREPARED",
  }));
  const issues = evaluateIssues(input.purchaseHandoffBatchId, lines);
  const issueCounts = counts(issues);
  const base: PurchaseHandoffBatch = {
    purchaseHandoffBatchId: input.purchaseHandoffBatchId,
    confirmedNeedBatchId: source.confirmedNeedBatchId,
    periodStart: source.periodStart,
    periodEnd: source.periodEnd,
    status: "PREPARED",
    confirmedNeedStatus: source.status,
    confirmedNeedReference: {
      confirmedNeedBatchId: source.confirmedNeedBatchId,
      batchVersion: source.version,
      releasedBy: source.releasedBy,
      releasedAt: source.releasedAt,
    },
    lines,
    issues,
    lineCount: lines.length,
    ...issueCounts,
    preparedBy: input.actorId,
    preparedAt: input.at,
    releaseSnapshots: [],
    version: 1,
    changes: [],
  };
  return {
    accepted: true,
    batch: {
      ...base,
      changes: [
        change(
          base,
          "PurchaseHandoffPrepared",
          input.actorId,
          input.at,
          "PREPARED",
          { affectedLineIds: lines.map((line) => line.purchaseHandoffLineId) },
        ),
      ],
    },
  };
}

export function ValidatePurchaseHandoff(
  batch: PurchaseHandoffBatch,
  actorId: string,
  at: string,
): PurchaseHandoffCommandResult {
  if (batch.status !== "PREPARED" && batch.status !== "REOPENED")
    return {
      batch,
      accepted: false,
      message: "Only Prepared or Reopened handoffs can be validated.",
    };
  const issues = evaluateIssues(batch.purchaseHandoffBatchId, batch.lines);
  const issueCounts = counts(issues);
  if (issueCounts.blockingIssueCount > 0)
    return {
      accepted: false,
      message:
        "Blocking issues must be resolved before release to Procurement.",
      batch: {
        ...batch,
        issues,
        ...issueCounts,
        changes: [
          ...batch.changes,
          change(
            batch,
            "PurchaseHandoffValidationFailed",
            actorId,
            at,
            batch.status,
          ),
        ],
      },
    };
  const status: PurchaseHandoffStatus = "VALIDATED";
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      issues,
      ...issueCounts,
      lines: batch.lines.map((line) => ({ ...line, status: "VALIDATED" })),
      validatedBy: actorId,
      validatedAt: at,
      changes: [
        ...batch.changes,
        change(batch, "PurchaseHandoffValidated", actorId, at, status),
      ],
    },
  };
}

export function ReleasePurchaseHandoffToProcurement(
  batch: PurchaseHandoffBatch,
  actorId: string,
  at: string,
): PurchaseHandoffCommandResult {
  if (batch.status !== "VALIDATED" || batch.blockingIssueCount > 0)
    return {
      batch,
      accepted: false,
      message:
        "Only Validated handoffs without blockers can be released to Procurement.",
    };
  const status: PurchaseHandoffStatus = "RELEASED_TO_PROCUREMENT";
  const snapshot: PurchaseHandoffReleaseSnapshot = {
    releasedVersion: batch.version,
    confirmedNeedBatchVersion: batch.confirmedNeedReference.batchVersion,
    lines: batch.lines.map((line) => ({
      purchaseHandoffLineId: line.purchaseHandoffLineId,
      confirmedNeedLineId: line.confirmedNeedLineId,
      quantity: line.quantity,
      purchaseUnit: line.purchaseUnit,
    })),
    blockingIssueCount: batch.blockingIssueCount,
    warningCount: batch.warningCount,
    releasedBy: actorId,
    releasedAt: at,
  };
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      lines: batch.lines.map((line) => ({ ...line, status: "RELEASED" })),
      releasedBy: actorId,
      releasedAt: at,
      releaseSnapshots: [...batch.releaseSnapshots, snapshot],
      changes: [
        ...batch.changes,
        change(
          batch,
          "PurchaseHandoffReleasedToProcurement",
          actorId,
          at,
          status,
          {
            affectedLineIds: batch.lines.map(
              (line) => line.purchaseHandoffLineId,
            ),
          },
        ),
      ],
    },
  };
}

export function ReopenPurchaseHandoff(
  batch: PurchaseHandoffBatch,
  reason: string,
  actorId: string,
  at: string,
): PurchaseHandoffCommandResult {
  if (
    (batch.status !== "VALIDATED" &&
      batch.status !== "RELEASED_TO_PROCUREMENT") ||
    !reason.trim()
  )
    return {
      batch,
      accepted: false,
      message:
        "Only Validated or Released handoffs can be reopened with a reason.",
    };
  const status: PurchaseHandoffStatus = "REOPENED";
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      version: batch.version + 1,
      lines: batch.lines.map((line) => ({ ...line, status: "PREPARED" })),
      reopenedBy: actorId,
      reopenedAt: at,
      reopenReason: reason,
      changes: [
        ...batch.changes,
        change(batch, "PurchaseHandoffReopened", actorId, at, status, {
          reason,
        }),
      ],
    },
  };
}

export function InvalidatePurchaseHandoff(
  batch: PurchaseHandoffBatch,
  affectedSource: string,
  reason: string,
  actorId: string,
  at: string,
): PurchaseHandoffCommandResult {
  if (
    batch.status === "INVALIDATED" ||
    !affectedSource.trim() ||
    !reason.trim()
  )
    return {
      batch,
      accepted: false,
      message: "An active handoff, affected source, and reason are required.",
    };
  const status: PurchaseHandoffStatus = "INVALIDATED";
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      invalidatedBy: actorId,
      invalidatedAt: at,
      invalidationReason: reason,
      invalidatedSource: affectedSource,
      changes: [
        ...batch.changes,
        change(batch, "PurchaseHandoffInvalidated", actorId, at, status, {
          reason,
          affectedSource,
        }),
      ],
    },
  };
}

export type PurchaseHandoffWorkbench = {
  servicePeriod: string;
  sourceConfirmedNeedStatus: ConfirmedNeedStatus;
  handoffStatus: PurchaseHandoffStatus;
  blockingIssueCount: number;
  warningCount: number;
  lineCount: number;
  canValidate: boolean;
  canReleaseToProcurement: boolean;
};

export function PurchaseHandoffWorkbench(
  batch: PurchaseHandoffBatch,
): PurchaseHandoffWorkbench {
  return {
    servicePeriod: `${batch.periodStart} to ${batch.periodEnd}`,
    sourceConfirmedNeedStatus: batch.confirmedNeedStatus,
    handoffStatus: batch.status,
    blockingIssueCount: batch.blockingIssueCount,
    warningCount: batch.warningCount,
    lineCount: batch.lineCount,
    canValidate:
      (batch.status === "PREPARED" || batch.status === "REOPENED") &&
      batch.blockingIssueCount === 0,
    canReleaseToProcurement:
      batch.status === "VALIDATED" && batch.blockingIssueCount === 0,
  };
}
