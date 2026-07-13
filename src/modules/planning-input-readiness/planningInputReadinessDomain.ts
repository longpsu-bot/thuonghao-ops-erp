export type PlanningInputType = "WEEKLY_MENU" | "ATTENDANCE";
export type PlanningInputReadinessStatus =
  "NOT_READY" | "READY" | "NEED_GENERATION_REQUESTED" | "INVALIDATED";
export type PlanningInputReadinessSeverity = "BLOCKING" | "WARNING";

export type PlanningInputReference = {
  inputType: PlanningInputType;
  inputId: string;
  inputVersion: number;
  inputStatus: string;
  periodStart: string;
  periodEnd: string;
  approvedBy?: string;
  approvedAt?: string;
  handoffStatus?: string;
  unresolvedBlockingIssueCount?: number;
};

export type PlanningInputReadinessIssue = {
  id: string;
  planningInputSetId: string;
  severity: PlanningInputReadinessSeverity;
  issueCode:
    | "MISSING_WEEKLY_MENU"
    | "MISSING_ATTENDANCE"
    | "UNAPPROVED_WEEKLY_MENU"
    | "UNAPPROVED_ATTENDANCE"
    | "MISMATCHED_SERVICE_PERIOD"
    | "WEEKLY_MENU_BLOCKING_ISSUES"
    | "ATTENDANCE_BLOCKING_ISSUES";
  message: string;
  inputType?: PlanningInputType;
  isBlocking: boolean;
};

export type PlanningInputReadinessChange = {
  id: string;
  type:
    | "PlanningInputReadinessEvaluated"
    | "PlanningInputReadinessPassed"
    | "PlanningInputReadinessFailed"
    | "PlanningInputReadinessInvalidated"
    | "NeedGenerationRequestedFromPlanningInputs";
  actorId: string;
  at: string;
  reason?: string;
  beforeStatus?: PlanningInputReadinessStatus;
  afterStatus: PlanningInputReadinessStatus;
};

export type PlanningInputSet = {
  id: string;
  periodStart: string;
  periodEnd: string;
  status: PlanningInputReadinessStatus;
  weeklyMenuReference?: PlanningInputReference;
  attendanceReference?: PlanningInputReference;
  issues: PlanningInputReadinessIssue[];
  evaluatedBy: string;
  evaluatedAt: string;
  requestedBy?: string;
  requestedAt?: string;
  version: number;
  changes: PlanningInputReadinessChange[];
};

export type PlanningInputReadinessCommandResult = {
  inputSet: PlanningInputSet;
  accepted: boolean;
  message?: string;
};

type EvaluateInput = {
  planningInputSetId: string;
  periodStart: string;
  periodEnd: string;
  weeklyMenuReference?: PlanningInputReference;
  attendanceReference?: PlanningInputReference;
  actorId: string;
  at: string;
};

const isWeeklyMenuApproved = (reference: PlanningInputReference) =>
  reference.inputStatus === "APPROVED" ||
  reference.inputStatus === "NEED_GENERATION_REQUESTED";

const isAttendanceApproved = (reference: PlanningInputReference) =>
  reference.inputStatus === "APPROVED" ||
  reference.inputStatus === "USED_FOR_NEED_GENERATION";

function issue(
  setId: string,
  code: PlanningInputReadinessIssue["issueCode"],
  message: string,
  inputType?: PlanningInputType,
): PlanningInputReadinessIssue {
  return {
    id: `${setId}-issue-${code}`,
    planningInputSetId: setId,
    severity: "BLOCKING",
    issueCode: code,
    message,
    inputType,
    isBlocking: true,
  };
}

function evaluateIssues(input: EvaluateInput) {
  const issues: PlanningInputReadinessIssue[] = [];
  const weeklyMenu = input.weeklyMenuReference;
  const attendance = input.attendanceReference;
  if (!weeklyMenu) {
    issues.push(
      issue(
        input.planningInputSetId,
        "MISSING_WEEKLY_MENU",
        "Weekly Menu is missing for the service period.",
        "WEEKLY_MENU",
      ),
    );
  } else {
    if (!isWeeklyMenuApproved(weeklyMenu))
      issues.push(
        issue(
          input.planningInputSetId,
          "UNAPPROVED_WEEKLY_MENU",
          "Weekly Menu must be approved before Need Generation.",
          "WEEKLY_MENU",
        ),
      );
    if (weeklyMenu.unresolvedBlockingIssueCount)
      issues.push(
        issue(
          input.planningInputSetId,
          "WEEKLY_MENU_BLOCKING_ISSUES",
          "Weekly Menu has unresolved blocking issues.",
          "WEEKLY_MENU",
        ),
      );
  }
  if (!attendance) {
    issues.push(
      issue(
        input.planningInputSetId,
        "MISSING_ATTENDANCE",
        "Attendance is missing for the service period.",
        "ATTENDANCE",
      ),
    );
  } else {
    if (!isAttendanceApproved(attendance))
      issues.push(
        issue(
          input.planningInputSetId,
          "UNAPPROVED_ATTENDANCE",
          "Attendance must be approved before Need Generation.",
          "ATTENDANCE",
        ),
      );
    if (attendance.unresolvedBlockingIssueCount)
      issues.push(
        issue(
          input.planningInputSetId,
          "ATTENDANCE_BLOCKING_ISSUES",
          "Attendance has unresolved blocking issues.",
          "ATTENDANCE",
        ),
      );
  }
  for (const reference of [weeklyMenu, attendance]) {
    if (
      reference &&
      (reference.periodStart !== input.periodStart ||
        reference.periodEnd !== input.periodEnd)
    ) {
      issues.push(
        issue(
          input.planningInputSetId,
          "MISMATCHED_SERVICE_PERIOD",
          "Planning input service period does not match the evaluated period.",
          reference.inputType,
        ),
      );
    }
  }
  return issues;
}

function change(set: PlanningInputSet, next: PlanningInputReadinessChange) {
  return { ...set, changes: [...set.changes, next] };
}

export function EvaluatePlanningInputReadiness(
  input: EvaluateInput,
): PlanningInputReadinessCommandResult {
  const issues = evaluateIssues(input);
  const status: PlanningInputReadinessStatus = issues.some(
    (item) => item.isBlocking,
  )
    ? "NOT_READY"
    : "READY";
  const base: PlanningInputSet = {
    id: input.planningInputSetId,
    periodStart: input.periodStart,
    periodEnd: input.periodEnd,
    status,
    weeklyMenuReference: input.weeklyMenuReference,
    attendanceReference: input.attendanceReference,
    issues,
    evaluatedBy: input.actorId,
    evaluatedAt: input.at,
    version: 1,
    changes: [],
  };
  const evaluated = change(base, {
    id: `${base.id}-event-1`,
    type: "PlanningInputReadinessEvaluated",
    actorId: input.actorId,
    at: input.at,
    afterStatus: status,
  });
  return {
    inputSet: change(evaluated, {
      id: `${base.id}-event-2`,
      type:
        status === "READY"
          ? "PlanningInputReadinessPassed"
          : "PlanningInputReadinessFailed",
      actorId: input.actorId,
      at: input.at,
      afterStatus: status,
    }),
    accepted: true,
  };
}

export function RequestNeedGenerationFromInputs(
  inputSet: PlanningInputSet,
  actorId: string,
  at: string,
): PlanningInputReadinessCommandResult {
  if (
    inputSet.status !== "READY" ||
    inputSet.issues.some((item) => item.isBlocking)
  )
    return {
      inputSet,
      accepted: false,
      message: "Need Generation can only be requested from Ready inputs.",
    };
  const status: PlanningInputReadinessStatus = "NEED_GENERATION_REQUESTED";
  return {
    inputSet: change(
      { ...inputSet, status, requestedBy: actorId, requestedAt: at },
      {
        id: `${inputSet.id}-event-${inputSet.changes.length + 1}`,
        type: "NeedGenerationRequestedFromPlanningInputs",
        actorId,
        at,
        beforeStatus: inputSet.status,
        afterStatus: status,
      },
    ),
    accepted: true,
  };
}

export function InvalidatePlanningInputReadiness(
  inputSet: PlanningInputSet,
  changedReference: PlanningInputReference,
  reason: string,
  actorId: string,
  at: string,
): PlanningInputReadinessCommandResult {
  if (
    (inputSet.status !== "READY" &&
      inputSet.status !== "NEED_GENERATION_REQUESTED") ||
    !reason.trim()
  )
    return {
      inputSet,
      accepted: false,
      message:
        "A Ready or requested input set and invalidation reason are required.",
    };
  const status: PlanningInputReadinessStatus = "INVALIDATED";
  return {
    inputSet: change(
      {
        ...inputSet,
        status,
        version: inputSet.version + 1,
        weeklyMenuReference:
          changedReference.inputType === "WEEKLY_MENU"
            ? changedReference
            : inputSet.weeklyMenuReference,
        attendanceReference:
          changedReference.inputType === "ATTENDANCE"
            ? changedReference
            : inputSet.attendanceReference,
      },
      {
        id: `${inputSet.id}-event-${inputSet.changes.length + 1}`,
        type: "PlanningInputReadinessInvalidated",
        actorId,
        at,
        reason,
        beforeStatus: inputSet.status,
        afterStatus: status,
      },
    ),
    accepted: true,
  };
}

export type PlanningInputReadinessWorkbench = {
  period: string;
  weeklyMenuStatus?: string;
  attendanceStatus?: string;
  status: PlanningInputReadinessStatus;
  blockingIssueCount: number;
  warningCount: number;
  inputVersions: { weeklyMenu?: number; attendance?: number };
  canRequestNeedGeneration: boolean;
};
export type PlanningInputReadinessIssues = {
  blocking: PlanningInputReadinessIssue[];
  warnings: PlanningInputReadinessIssue[];
};
export type PlanningInputReadinessSummary = PlanningInputReadinessWorkbench & {
  evaluatedBy: string;
  evaluatedAt: string;
  requestedBy?: string;
  requestedAt?: string;
};
export type PlanningInputReadinessHistory = PlanningInputReadinessChange[];

export function PlanningInputReadinessWorkbench(
  inputSet: PlanningInputSet,
): PlanningInputReadinessWorkbench {
  const blockingIssueCount = inputSet.issues.filter(
    (item) => item.isBlocking,
  ).length;
  return {
    period: `${inputSet.periodStart} to ${inputSet.periodEnd}`,
    weeklyMenuStatus: inputSet.weeklyMenuReference?.inputStatus,
    attendanceStatus: inputSet.attendanceReference?.inputStatus,
    status: inputSet.status,
    blockingIssueCount,
    warningCount: inputSet.issues.length - blockingIssueCount,
    inputVersions: {
      weeklyMenu: inputSet.weeklyMenuReference?.inputVersion,
      attendance: inputSet.attendanceReference?.inputVersion,
    },
    canRequestNeedGeneration:
      inputSet.status === "READY" && blockingIssueCount === 0,
  };
}
export function PlanningInputReadinessIssues(
  inputSet: PlanningInputSet,
): PlanningInputReadinessIssues {
  return {
    blocking: inputSet.issues.filter((item) => item.isBlocking),
    warnings: inputSet.issues.filter((item) => !item.isBlocking),
  };
}
export function PlanningInputReadinessSummary(
  inputSet: PlanningInputSet,
): PlanningInputReadinessSummary {
  return {
    ...PlanningInputReadinessWorkbench(inputSet),
    evaluatedBy: inputSet.evaluatedBy,
    evaluatedAt: inputSet.evaluatedAt,
    requestedBy: inputSet.requestedBy,
    requestedAt: inputSet.requestedAt,
  };
}
export function PlanningInputReadinessHistory(
  inputSet: PlanningInputSet,
): PlanningInputReadinessHistory {
  return inputSet.changes;
}
