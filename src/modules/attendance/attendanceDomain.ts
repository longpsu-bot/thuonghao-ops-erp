export type AttendanceStatus =
  "DRAFT" | "VALIDATED" | "APPROVED" | "USED_FOR_NEED_GENERATION" | "REOPENED";
export type AttendanceLineStatus = "ACTIVE" | "INVALID";
export type AttendanceIssueSeverity = "WARNING" | "BLOCKING";

export type AttendanceLine = {
  id: string;
  attendanceBatchId: string;
  serviceDate: string;
  schoolId: string;
  studentPortions: number;
  teacherPortions: number;
  status: AttendanceLineStatus;
  sourceRowRef: string;
  createdBy: string;
  createdAt: string;
  updatedBy: string;
  updatedAt: string;
};

export type AttendanceIssue = {
  id: string;
  attendanceBatchId: string;
  attendanceLineId?: string;
  severity: AttendanceIssueSeverity;
  issueCode:
    | "UNKNOWN_SCHOOL"
    | "DATE_OUTSIDE_PERIOD"
    | "DUPLICATE_SCHOOL_DATE"
    | "NEGATIVE_STUDENT_PORTIONS"
    | "NEGATIVE_TEACHER_PORTIONS";
  message: string;
  isBlocking: boolean;
};

export type AttendanceChange = {
  id: string;
  type:
    | "AttendanceImported"
    | "AttendanceValidated"
    | "AttendanceValidationFailed"
    | "AttendanceLineEdited"
    | "AttendanceApproved"
    | "AttendanceReopened"
    | "AttendanceUsedForNeedGeneration";
  actorId: string;
  at: string;
  reason?: string;
  lineId?: string;
  before?: string;
  after?: string;
};

export type AttendanceApprovedSnapshot = {
  version: number;
  approvedBy: string;
  approvedAt: string;
  lineIds: string[];
};

export type AttendanceBatch = {
  id: string;
  periodStart: string;
  periodEnd: string;
  sourceType: string;
  sourceName: string;
  sourceSignature: string;
  status: AttendanceStatus;
  rowsCount: number;
  importedBy: string;
  importedAt: string;
  approvedBy?: string;
  approvedAt?: string;
  version: number;
  lines: AttendanceLine[];
  issues: AttendanceIssue[];
  changes: AttendanceChange[];
  approvedSnapshots: AttendanceApprovedSnapshot[];
  usedForNeedGenerationAt?: string;
};

export type AttendanceImportRow = {
  serviceDate: string;
  schoolId: string;
  studentPortions: number;
  teacherPortions: number;
  sourceRowRef: string;
};

export type AttendanceReferenceData = { schoolIds: readonly string[] };
export type AttendanceCommandResult = {
  batch: AttendanceBatch;
  accepted: boolean;
  message?: string;
};
export type AttendanceValidationResult = {
  batch: AttendanceBatch;
  accepted: boolean;
  isValid: boolean;
  blockingIssues: AttendanceIssue[];
  warnings: AttendanceIssue[];
  message?: string;
};

type ImportInput = {
  attendanceBatchId: string;
  periodStart: string;
  periodEnd: string;
  sourceType: string;
  sourceName: string;
  sourceSignature: string;
  rows: AttendanceImportRow[];
  actorId: string;
  at: string;
};

function issue(
  batchId: string,
  lineId: string,
  code: AttendanceIssue["issueCode"],
  message: string,
): AttendanceIssue {
  return {
    id: `${batchId}-issue-${code}-${lineId}`,
    attendanceBatchId: batchId,
    attendanceLineId: lineId,
    severity: "BLOCKING",
    issueCode: code,
    message,
    isBlocking: true,
  };
}

function isInPeriod(date: string, start: string, end: string) {
  return date >= start && date <= end;
}

function validate(
  batch: AttendanceBatch,
  references: AttendanceReferenceData,
): AttendanceIssue[] {
  const issues: AttendanceIssue[] = [];
  const seen = new Set<string>();
  for (const line of batch.lines) {
    if (!references.schoolIds.includes(line.schoolId)) {
      issues.push(
        issue(
          batch.id,
          line.id,
          "UNKNOWN_SCHOOL",
          "School reference is unknown.",
        ),
      );
    }
    if (!isInPeriod(line.serviceDate, batch.periodStart, batch.periodEnd)) {
      issues.push(
        issue(
          batch.id,
          line.id,
          "DATE_OUTSIDE_PERIOD",
          "Service date is outside the selected period.",
        ),
      );
    }
    const key = `${line.schoolId}|${line.serviceDate}`;
    if (seen.has(key)) {
      issues.push(
        issue(
          batch.id,
          line.id,
          "DUPLICATE_SCHOOL_DATE",
          "School and service date must be unique.",
        ),
      );
    }
    seen.add(key);
    if (line.studentPortions < 0) {
      issues.push(
        issue(
          batch.id,
          line.id,
          "NEGATIVE_STUDENT_PORTIONS",
          "Student portions cannot be negative.",
        ),
      );
    }
    if (line.teacherPortions < 0) {
      issues.push(
        issue(
          batch.id,
          line.id,
          "NEGATIVE_TEACHER_PORTIONS",
          "Teacher portions cannot be negative.",
        ),
      );
    }
  }
  return issues;
}

function withChange(batch: AttendanceBatch, change: AttendanceChange) {
  return { ...batch, changes: [...batch.changes, change] };
}

export function ImportAttendance(
  input: ImportInput,
  references: AttendanceReferenceData,
): AttendanceCommandResult {
  const lines = input.rows.map((row, index): AttendanceLine => ({
    id: `${input.attendanceBatchId}-line-${index + 1}`,
    attendanceBatchId: input.attendanceBatchId,
    serviceDate: row.serviceDate,
    schoolId: row.schoolId,
    studentPortions: row.studentPortions,
    teacherPortions: row.teacherPortions,
    status: "ACTIVE",
    sourceRowRef: row.sourceRowRef,
    createdBy: input.actorId,
    createdAt: input.at,
    updatedBy: input.actorId,
    updatedAt: input.at,
  }));
  const imported: AttendanceBatch = {
    id: input.attendanceBatchId,
    periodStart: input.periodStart,
    periodEnd: input.periodEnd,
    sourceType: input.sourceType,
    sourceName: input.sourceName,
    sourceSignature: input.sourceSignature,
    status: "DRAFT",
    rowsCount: lines.length,
    importedBy: input.actorId,
    importedAt: input.at,
    version: 1,
    lines,
    issues: [],
    changes: [],
    approvedSnapshots: [],
  };
  const batch = withChange(
    { ...imported, issues: validate(imported, references) },
    {
      id: `${input.attendanceBatchId}-event-1`,
      type: "AttendanceImported",
      actorId: input.actorId,
      at: input.at,
    },
  );
  return { batch, accepted: true };
}

export function ValidateAttendance(
  batch: AttendanceBatch,
  references: AttendanceReferenceData,
  actorId: string,
  at: string,
): AttendanceValidationResult {
  if (
    batch.status === "APPROVED" ||
    batch.status === "USED_FOR_NEED_GENERATION"
  ) {
    return {
      batch,
      accepted: false,
      isValid: false,
      blockingIssues: batch.issues.filter((item) => item.isBlocking),
      warnings: batch.issues.filter((item) => !item.isBlocking),
      message: "Reopen attendance before validating it again.",
    };
  }
  const issues = validate(batch, references);
  const isValid = !issues.some((item) => item.isBlocking);
  const next = withChange(
    { ...batch, status: isValid ? "VALIDATED" : "DRAFT", issues },
    {
      id: `${batch.id}-event-${batch.changes.length + 1}`,
      type: isValid ? "AttendanceValidated" : "AttendanceValidationFailed",
      actorId,
      at,
    },
  );
  return {
    batch: next,
    accepted: true,
    isValid,
    blockingIssues: issues.filter((item) => item.isBlocking),
    warnings: issues.filter((item) => !item.isBlocking),
  };
}

export function EditAttendanceLine(
  batch: AttendanceBatch,
  lineId: string,
  patch: Pick<
    AttendanceImportRow,
    "serviceDate" | "schoolId" | "studentPortions" | "teacherPortions"
  >,
  actorId: string,
  at: string,
): AttendanceCommandResult {
  if (
    batch.status === "APPROVED" ||
    batch.status === "USED_FOR_NEED_GENERATION"
  ) {
    return {
      batch,
      accepted: false,
      message: "Reopen attendance before editing it.",
    };
  }
  const original = batch.lines.find((line) => line.id === lineId);
  if (!original) {
    return {
      batch,
      accepted: false,
      message: "Attendance line was not found.",
    };
  }
  const lines = batch.lines.map((line) =>
    line.id === lineId
      ? { ...line, ...patch, updatedBy: actorId, updatedAt: at }
      : line,
  );
  const next = withChange(
    { ...batch, lines, status: "DRAFT", version: batch.version + 1 },
    {
      id: `${batch.id}-event-${batch.changes.length + 1}`,
      type: "AttendanceLineEdited",
      actorId,
      at,
      lineId,
      before: `${original.serviceDate}|${original.schoolId}|${original.studentPortions}|${original.teacherPortions}`,
      after: `${patch.serviceDate}|${patch.schoolId}|${patch.studentPortions}|${patch.teacherPortions}`,
    },
  );
  return { batch: next, accepted: true };
}

export function ApproveAttendance(
  batch: AttendanceBatch,
  actorId: string,
  at: string,
): AttendanceCommandResult {
  if (
    batch.status !== "VALIDATED" ||
    batch.issues.some((item) => item.isBlocking)
  ) {
    return {
      batch,
      accepted: false,
      message: "Resolve blocking issues and validate before approval.",
    };
  }
  const snapshot = {
    version: batch.version,
    approvedBy: actorId,
    approvedAt: at,
    lineIds: batch.lines.map((line) => line.id),
  };
  const next = withChange(
    {
      ...batch,
      status: "APPROVED",
      approvedBy: actorId,
      approvedAt: at,
      approvedSnapshots: [...batch.approvedSnapshots, snapshot],
    },
    {
      id: `${batch.id}-event-${batch.changes.length + 1}`,
      type: "AttendanceApproved",
      actorId,
      at,
    },
  );
  return { batch: next, accepted: true };
}

export function ReopenAttendance(
  batch: AttendanceBatch,
  reason: string,
  actorId: string,
  at: string,
): AttendanceCommandResult {
  if (
    (batch.status !== "APPROVED" &&
      batch.status !== "USED_FOR_NEED_GENERATION") ||
    !reason.trim()
  ) {
    return {
      batch,
      accepted: false,
      message: "An approved attendance batch and reason are required.",
    };
  }
  return {
    batch: withChange(
      { ...batch, status: "REOPENED" },
      {
        id: `${batch.id}-event-${batch.changes.length + 1}`,
        type: "AttendanceReopened",
        actorId,
        at,
        reason,
      },
    ),
    accepted: true,
  };
}

export function MarkAttendanceUsedForNeedGeneration(
  batch: AttendanceBatch,
  actorId: string,
  at: string,
): AttendanceCommandResult {
  if (batch.status !== "APPROVED") {
    return {
      batch,
      accepted: false,
      message: "Attendance can be handed off only from Approved.",
    };
  }
  return {
    batch: withChange(
      {
        ...batch,
        status: "USED_FOR_NEED_GENERATION",
        usedForNeedGenerationAt: at,
      },
      {
        id: `${batch.id}-event-${batch.changes.length + 1}`,
        type: "AttendanceUsedForNeedGeneration",
        actorId,
        at,
      },
    ),
    accepted: true,
  };
}

export type AttendanceWorkbench = {
  period: string;
  status: AttendanceStatus;
  blockingIssueCount: number;
  warningCount: number;
  changedSchoolDayCount: number;
  canValidate: boolean;
  canApprove: boolean;
  canUseForNeedGeneration: boolean;
  lines: AttendanceLine[];
};
export type AttendanceValidationIssues = {
  blocking: AttendanceIssue[];
  warnings: AttendanceIssue[];
};
export type AttendanceChangeHistory = AttendanceChange[];
export type AttendanceApprovalSummary = {
  importedRows: number;
  changedSchoolDays: number;
  approvedBy?: string;
  approvedAt?: string;
  usedForNeedGenerationAt?: string;
};

export function AttendanceWorkbench(
  batch: AttendanceBatch,
): AttendanceWorkbench {
  const blockingIssueCount = batch.issues.filter(
    (item) => item.isBlocking,
  ).length;
  const changedSchoolDayCount = new Set(
    batch.changes
      .filter((change) => change.type === "AttendanceLineEdited")
      .map((change) => change.lineId),
  ).size;
  return {
    period: `${batch.periodStart} to ${batch.periodEnd}`,
    status: batch.status,
    blockingIssueCount,
    warningCount: batch.issues.length - blockingIssueCount,
    changedSchoolDayCount,
    canValidate:
      batch.status === "DRAFT" ||
      batch.status === "REOPENED" ||
      batch.status === "VALIDATED",
    canApprove: batch.status === "VALIDATED" && blockingIssueCount === 0,
    canUseForNeedGeneration: batch.status === "APPROVED",
    lines: batch.lines,
  };
}

export function AttendanceValidationIssues(
  batch: AttendanceBatch,
): AttendanceValidationIssues {
  return {
    blocking: batch.issues.filter((item) => item.isBlocking),
    warnings: batch.issues.filter((item) => !item.isBlocking),
  };
}

export function AttendanceChangeHistory(
  batch: AttendanceBatch,
): AttendanceChangeHistory {
  return batch.changes;
}

export function AttendanceApprovalSummary(
  batch: AttendanceBatch,
): AttendanceApprovalSummary {
  return {
    importedRows: batch.rowsCount,
    changedSchoolDays: AttendanceWorkbench(batch).changedSchoolDayCount,
    approvedBy: batch.approvedBy,
    approvedAt: batch.approvedAt,
    usedForNeedGenerationAt: batch.usedForNeedGenerationAt,
  };
}
