import type {
  NeedGenerationRun,
  NeedGenerationStatus,
  TheoreticalNeedLine,
} from "../need-generation/needGenerationDomain";

export type ConfirmedNeedStatus =
  | "DRAFT_REVIEW"
  | "VALIDATED"
  | "APPROVED"
  | "RELEASED_FOR_PURCHASE_HANDOFF"
  | "REOPENED";
export type ConfirmedNeedIssueSeverity = "BLOCKING" | "WARNING";

export type ConfirmedNeedSourceReference = {
  needGenerationRunId: string;
  needGenerationRunVersion: number;
  theoreticalNeedLineId: string;
  planningInputSetId: string;
  weeklyMenuReference: string;
  attendanceReference: string;
  recipeBomReference?: string;
  sourceTraceId: string;
};

export type ConfirmedNeedAdjustment = {
  confirmedNeedAdjustmentId: string;
  confirmedNeedLineId: string;
  adjustedBy: string;
  adjustedAt: string;
  reasonCode?: string;
  reasonNote?: string;
  beforeQuantity: number;
  afterQuantity: number;
  unit: string;
};

export type ConfirmedNeedLine = {
  confirmedNeedLineId: string;
  confirmedNeedBatchId: string;
  theoreticalNeedLineId: string;
  serviceDate: string;
  schoolId: string;
  dishId?: string;
  ingredientId: string;
  theoreticalQuantity: number;
  confirmedQuantity: number;
  unit: string;
  sourceTraceId: string;
  sourceReference: ConfirmedNeedSourceReference;
  status: "DRAFT" | "VALIDATED" | "APPROVED" | "RELEASED";
  adjustments: readonly ConfirmedNeedAdjustment[];
};

export type ConfirmedNeedIssue = {
  confirmedNeedIssueId: string;
  confirmedNeedBatchId: string;
  confirmedNeedLineId?: string;
  severity: ConfirmedNeedIssueSeverity;
  issueCode:
    | "MISSING_SOURCE_TRACE"
    | "NEGATIVE_CONFIRMED_QUANTITY"
    | "ZERO_CONFIRMED_QUANTITY";
  message: string;
  isBlocking: boolean;
};

export type ConfirmedNeedChange = {
  eventId: string;
  eventType:
    | "ConfirmedNeedsCreated"
    | "ConfirmedNeedsValidated"
    | "ConfirmedNeedValidationFailed"
    | "ConfirmedNeedLineAdjusted"
    | "ConfirmedNeedsApproved"
    | "ConfirmedNeedsReopened"
    | "ConfirmedNeedsReleasedForPurchaseHandoff";
  confirmedNeedBatchId: string;
  actorId: string;
  at: string;
  affectedLineIds?: readonly string[];
  beforeStatus?: ConfirmedNeedStatus;
  afterStatus: ConfirmedNeedStatus;
  beforeQuantity?: number;
  afterQuantity?: number;
  unit?: string;
  reasonCode?: string;
  reasonNote?: string;
};

export type ConfirmedNeedApprovedSnapshot = {
  approvedVersion: number;
  lines: readonly {
    confirmedNeedLineId: string;
    theoreticalNeedLineId: string;
    confirmedQuantity: number;
    unit: string;
  }[];
  blockingIssueCount: number;
  warningCount: number;
  approvedBy: string;
  approvedAt: string;
};

export type ConfirmedNeedBatch = {
  confirmedNeedBatchId: string;
  needGenerationRunId: string;
  periodStart: string;
  periodEnd: string;
  status: ConfirmedNeedStatus;
  sourceGenerationStatus: NeedGenerationStatus;
  sourceGenerationReference: {
    needGenerationRunId: string;
    runVersion: number;
    releasedAt: string;
    releasedBy: string;
  };
  lines: readonly ConfirmedNeedLine[];
  issues: readonly ConfirmedNeedIssue[];
  lineCount: number;
  blockingIssueCount: number;
  warningCount: number;
  createdBy: string;
  createdAt: string;
  validatedBy?: string;
  validatedAt?: string;
  approvedBy?: string;
  approvedAt?: string;
  releasedBy?: string;
  releasedAt?: string;
  releaseReference?: {
    batchVersion: number;
    confirmedNeedLineIds: readonly string[];
  };
  reopenedBy?: string;
  reopenedAt?: string;
  reopenReason?: string;
  version: number;
  approvedSnapshots: readonly ConfirmedNeedApprovedSnapshot[];
  changes: readonly ConfirmedNeedChange[];
};

export type ConfirmedNeedCommandResult = {
  batch?: ConfirmedNeedBatch;
  accepted: boolean;
  message?: string;
};

const issueCounts = (issues: readonly ConfirmedNeedIssue[]) => ({
  blockingIssueCount: issues.filter((issue) => issue.isBlocking).length,
  warningCount: issues.filter((issue) => !issue.isBlocking).length,
});

function evaluateIssues(
  batchId: string,
  lines: readonly ConfirmedNeedLine[],
): ConfirmedNeedIssue[] {
  const issues: ConfirmedNeedIssue[] = [];
  const add = (
    line: ConfirmedNeedLine,
    issueCode: ConfirmedNeedIssue["issueCode"],
    message: string,
    severity: ConfirmedNeedIssueSeverity,
  ) =>
    issues.push({
      confirmedNeedIssueId: `${batchId}-issue-${issues.length + 1}`,
      confirmedNeedBatchId: batchId,
      confirmedNeedLineId: line.confirmedNeedLineId,
      severity,
      issueCode,
      message,
      isBlocking: severity === "BLOCKING",
    });
  for (const line of lines) {
    if (
      !line.sourceTraceId ||
      !line.theoreticalNeedLineId ||
      !line.sourceReference.planningInputSetId
    )
      add(
        line,
        "MISSING_SOURCE_TRACE",
        "Confirmed line must retain its theoretical and upstream source trace.",
        "BLOCKING",
      );
    if (line.confirmedQuantity < 0)
      add(
        line,
        "NEGATIVE_CONFIRMED_QUANTITY",
        "Confirmed quantity cannot be negative.",
        "BLOCKING",
      );
    else if (line.confirmedQuantity === 0)
      add(
        line,
        "ZERO_CONFIRMED_QUANTITY",
        "Zero confirmed quantity requires Planning review.",
        "WARNING",
      );
  }
  return issues;
}

function sourceReference(
  run: NeedGenerationRun,
  line: TheoreticalNeedLine,
): ConfirmedNeedSourceReference {
  return {
    needGenerationRunId: run.needGenerationRunId,
    needGenerationRunVersion: run.version,
    theoreticalNeedLineId: line.theoreticalNeedLineId,
    planningInputSetId: run.inputSnapshot.planningInputSetId,
    weeklyMenuReference: `${run.inputSnapshot.weeklyMenuId}@${run.inputSnapshot.weeklyMenuVersion}`,
    attendanceReference: `${run.inputSnapshot.attendanceBatchId}@${run.inputSnapshot.attendanceVersion}`,
    recipeBomReference: `${line.recipeId}@${line.recipeVersion}:${line.bomLineId}`,
    sourceTraceId: line.sourceTraceId,
  };
}

function change(
  batch: ConfirmedNeedBatch,
  eventType: ConfirmedNeedChange["eventType"],
  actorId: string,
  at: string,
  afterStatus: ConfirmedNeedStatus,
  extra: Partial<ConfirmedNeedChange> = {},
): ConfirmedNeedChange {
  return {
    eventId: `${batch.confirmedNeedBatchId}-event-${batch.changes.length + 1}`,
    eventType,
    confirmedNeedBatchId: batch.confirmedNeedBatchId,
    actorId,
    at,
    beforeStatus: batch.status,
    afterStatus,
    ...extra,
  };
}

export function CreateConfirmedNeedsFromGeneration(input: {
  confirmedNeedBatchId: string;
  generationRun: NeedGenerationRun;
  actorId: string;
  at: string;
}): ConfirmedNeedCommandResult {
  const run = input.generationRun;
  if (
    run.status !== "RELEASED_FOR_CONFIRMATION" ||
    !run.releasedSnapshot ||
    !run.releasedBy ||
    !run.releasedAt
  )
    return {
      accepted: false,
      message:
        "Confirmed Need can only be created from released generated needs.",
    };
  const lines: ConfirmedNeedLine[] = run.lines.map((line, index) => ({
    confirmedNeedLineId: `${input.confirmedNeedBatchId}-line-${index + 1}`,
    confirmedNeedBatchId: input.confirmedNeedBatchId,
    theoreticalNeedLineId: line.theoreticalNeedLineId,
    serviceDate: line.serviceDate,
    schoolId: line.schoolId,
    dishId: line.dishId,
    ingredientId: line.ingredientId,
    theoreticalQuantity: line.quantity,
    confirmedQuantity: line.quantity,
    unit: line.unit,
    sourceTraceId: line.sourceTraceId,
    sourceReference: sourceReference(run, line),
    status: "DRAFT",
    adjustments: [],
  }));
  const issues = evaluateIssues(input.confirmedNeedBatchId, lines);
  const counts = issueCounts(issues);
  const base: ConfirmedNeedBatch = {
    confirmedNeedBatchId: input.confirmedNeedBatchId,
    needGenerationRunId: run.needGenerationRunId,
    periodStart: run.periodStart,
    periodEnd: run.periodEnd,
    status: "DRAFT_REVIEW",
    sourceGenerationStatus: run.status,
    sourceGenerationReference: {
      needGenerationRunId: run.needGenerationRunId,
      runVersion: run.version,
      releasedAt: run.releasedAt,
      releasedBy: run.releasedBy,
    },
    lines,
    issues,
    lineCount: lines.length,
    ...counts,
    createdBy: input.actorId,
    createdAt: input.at,
    version: 1,
    approvedSnapshots: [],
    changes: [],
  };
  return {
    accepted: true,
    batch: {
      ...base,
      changes: [
        change(
          base,
          "ConfirmedNeedsCreated",
          input.actorId,
          input.at,
          "DRAFT_REVIEW",
          { affectedLineIds: lines.map((line) => line.confirmedNeedLineId) },
        ),
      ],
    },
  };
}

export function ValidateConfirmedNeeds(
  batch: ConfirmedNeedBatch,
  actorId: string,
  at: string,
): ConfirmedNeedCommandResult {
  if (batch.status !== "DRAFT_REVIEW" && batch.status !== "REOPENED")
    return {
      batch,
      accepted: false,
      message:
        "Only Draft Review or Reopened confirmed needs can be validated.",
    };
  const issues = evaluateIssues(batch.confirmedNeedBatchId, batch.lines);
  const counts = issueCounts(issues);
  if (counts.blockingIssueCount > 0)
    return {
      accepted: false,
      message: "Blocking issues must be resolved before validation.",
      batch: {
        ...batch,
        issues,
        ...counts,
        changes: [
          ...batch.changes,
          change(
            batch,
            "ConfirmedNeedValidationFailed",
            actorId,
            at,
            batch.status,
          ),
        ],
      },
    };
  const status: ConfirmedNeedStatus = "VALIDATED";
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      issues,
      ...counts,
      lines: batch.lines.map((line) => ({ ...line, status: "VALIDATED" })),
      validatedBy: actorId,
      validatedAt: at,
      changes: [
        ...batch.changes,
        change(batch, "ConfirmedNeedsValidated", actorId, at, status),
      ],
    },
  };
}

export function AdjustConfirmedNeedLine(
  batch: ConfirmedNeedBatch,
  input: {
    confirmedNeedLineId: string;
    actorId: string;
    at: string;
    reasonCode?: string;
    reasonNote?: string;
    beforeQuantity: number;
    afterQuantity: number;
    unit: string;
  },
): ConfirmedNeedCommandResult {
  if (batch.status !== "DRAFT_REVIEW" && batch.status !== "REOPENED")
    return {
      batch,
      accepted: false,
      message:
        "Adjustments are only allowed in Draft Review or Reopened state.",
    };
  const line = batch.lines.find(
    (candidate) => candidate.confirmedNeedLineId === input.confirmedNeedLineId,
  );
  if (!line)
    return {
      batch,
      accepted: false,
      message: "Confirmed need line was not found.",
    };
  if (
    (!input.reasonCode?.trim() && !input.reasonNote?.trim()) ||
    input.beforeQuantity !== line.confirmedQuantity ||
    input.unit !== line.unit
  )
    return {
      batch,
      accepted: false,
      message:
        "Adjustment requires a reason, matching before quantity, and matching unit.",
    };
  const adjustment: ConfirmedNeedAdjustment = {
    confirmedNeedAdjustmentId: `${line.confirmedNeedLineId}-adjustment-${line.adjustments.length + 1}`,
    confirmedNeedLineId: line.confirmedNeedLineId,
    adjustedBy: input.actorId,
    adjustedAt: input.at,
    reasonCode: input.reasonCode,
    reasonNote: input.reasonNote,
    beforeQuantity: input.beforeQuantity,
    afterQuantity: input.afterQuantity,
    unit: input.unit,
  };
  const lines = batch.lines.map((candidate) =>
    candidate.confirmedNeedLineId === line.confirmedNeedLineId
      ? {
          ...candidate,
          confirmedQuantity: input.afterQuantity,
          status: "DRAFT" as const,
          adjustments: [...candidate.adjustments, adjustment],
        }
      : candidate,
  );
  const issues = evaluateIssues(batch.confirmedNeedBatchId, lines);
  const counts = issueCounts(issues);
  return {
    accepted: true,
    batch: {
      ...batch,
      lines,
      issues,
      ...counts,
      changes: [
        ...batch.changes,
        change(
          batch,
          "ConfirmedNeedLineAdjusted",
          input.actorId,
          input.at,
          batch.status,
          {
            affectedLineIds: [line.confirmedNeedLineId],
            beforeQuantity: input.beforeQuantity,
            afterQuantity: input.afterQuantity,
            unit: input.unit,
            reasonCode: input.reasonCode,
            reasonNote: input.reasonNote,
          },
        ),
      ],
    },
  };
}

export function ApproveConfirmedNeeds(
  batch: ConfirmedNeedBatch,
  actorId: string,
  at: string,
): ConfirmedNeedCommandResult {
  if (batch.status !== "VALIDATED" || batch.blockingIssueCount > 0)
    return {
      batch,
      accepted: false,
      message:
        "Only Validated confirmed needs without blockers can be approved.",
    };
  const status: ConfirmedNeedStatus = "APPROVED";
  const snapshot: ConfirmedNeedApprovedSnapshot = {
    approvedVersion: batch.version,
    lines: batch.lines.map((line) => ({
      confirmedNeedLineId: line.confirmedNeedLineId,
      theoreticalNeedLineId: line.theoreticalNeedLineId,
      confirmedQuantity: line.confirmedQuantity,
      unit: line.unit,
    })),
    blockingIssueCount: batch.blockingIssueCount,
    warningCount: batch.warningCount,
    approvedBy: actorId,
    approvedAt: at,
  };
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      lines: batch.lines.map((line) => ({ ...line, status: "APPROVED" })),
      approvedBy: actorId,
      approvedAt: at,
      approvedSnapshots: [...batch.approvedSnapshots, snapshot],
      changes: [
        ...batch.changes,
        change(batch, "ConfirmedNeedsApproved", actorId, at, status, {
          affectedLineIds: batch.lines.map((line) => line.confirmedNeedLineId),
        }),
      ],
    },
  };
}

export function ReopenConfirmedNeeds(
  batch: ConfirmedNeedBatch,
  reason: string,
  actorId: string,
  at: string,
): ConfirmedNeedCommandResult {
  if (
    (batch.status !== "APPROVED" &&
      batch.status !== "RELEASED_FOR_PURCHASE_HANDOFF") ||
    !reason.trim()
  )
    return {
      batch,
      accepted: false,
      message:
        "Only Approved or Released confirmed needs can be reopened with a reason.",
    };
  const status: ConfirmedNeedStatus = "REOPENED";
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      version: batch.version + 1,
      lines: batch.lines.map((line) => ({ ...line, status: "DRAFT" })),
      reopenedBy: actorId,
      reopenedAt: at,
      reopenReason: reason,
      changes: [
        ...batch.changes,
        change(batch, "ConfirmedNeedsReopened", actorId, at, status, {
          reasonNote: reason,
        }),
      ],
    },
  };
}

export function ReleaseConfirmedNeedsForPurchaseHandoff(
  batch: ConfirmedNeedBatch,
  actorId: string,
  at: string,
): ConfirmedNeedCommandResult {
  if (batch.status !== "APPROVED")
    return {
      batch,
      accepted: false,
      message:
        "Only Approved confirmed needs can be released for Purchase Handoff.",
    };
  const status: ConfirmedNeedStatus = "RELEASED_FOR_PURCHASE_HANDOFF";
  const lineIds = batch.lines.map((line) => line.confirmedNeedLineId);
  return {
    accepted: true,
    batch: {
      ...batch,
      status,
      lines: batch.lines.map((line) => ({ ...line, status: "RELEASED" })),
      releasedBy: actorId,
      releasedAt: at,
      releaseReference: {
        batchVersion: batch.version,
        confirmedNeedLineIds: lineIds,
      },
      changes: [
        ...batch.changes,
        change(
          batch,
          "ConfirmedNeedsReleasedForPurchaseHandoff",
          actorId,
          at,
          status,
          { affectedLineIds: lineIds },
        ),
      ],
    },
  };
}

export type ConfirmedNeedWorkbench = {
  servicePeriod: string;
  sourceGenerationStatus: NeedGenerationStatus;
  confirmedNeedStatus: ConfirmedNeedStatus;
  blockingIssueCount: number;
  warningCount: number;
  changedLineCount: number;
  canValidate: boolean;
  canApprove: boolean;
  canReleaseForPurchaseHandoff: boolean;
};

export function ConfirmedNeedWorkbench(
  batch: ConfirmedNeedBatch,
): ConfirmedNeedWorkbench {
  return {
    servicePeriod: `${batch.periodStart} to ${batch.periodEnd}`,
    sourceGenerationStatus: batch.sourceGenerationStatus,
    confirmedNeedStatus: batch.status,
    blockingIssueCount: batch.blockingIssueCount,
    warningCount: batch.warningCount,
    changedLineCount: batch.lines.filter(
      (line) => line.confirmedQuantity !== line.theoreticalQuantity,
    ).length,
    canValidate:
      (batch.status === "DRAFT_REVIEW" || batch.status === "REOPENED") &&
      batch.blockingIssueCount === 0,
    canApprove: batch.status === "VALIDATED" && batch.blockingIssueCount === 0,
    canReleaseForPurchaseHandoff: batch.status === "APPROVED",
  };
}
