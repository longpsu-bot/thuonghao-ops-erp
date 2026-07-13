export type WeeklyMenuStatus =
  "DRAFT" | "VALIDATED" | "APPROVED" | "NEED_GENERATION_REQUESTED" | "REOPENED";

export type WeeklyMenuLineStatus = "ACTIVE" | "INVALID";
export type WeeklyMenuIssueSeverity = "WARNING" | "BLOCKING";

export type WeeklyMenuLine = {
  id: string;
  weeklyMenuId: string;
  serviceDate: string;
  schoolId: string;
  menuSlot: string;
  dishId: string;
  status: WeeklyMenuLineStatus;
  sourceRowRef: string;
  createdBy: string;
  createdAt: string;
  updatedBy: string;
  updatedAt: string;
};

export type WeeklyMenuIssue = {
  id: string;
  weeklyMenuId: string;
  weeklyMenuLineId?: string;
  severity: WeeklyMenuIssueSeverity;
  issueCode:
    | "DATE_OUTSIDE_WEEK"
    | "UNKNOWN_SCHOOL"
    | "UNKNOWN_DISH"
    | "DUPLICATE_ASSIGNMENT"
    | "INVALID_COMMAND";
  message: string;
  isBlocking: boolean;
  resolvedAt?: string;
  resolvedBy?: string;
};

export type WeeklyMenuChange = {
  id: string;
  type:
    | "WeeklyMenuImported"
    | "WeeklyMenuValidated"
    | "WeeklyMenuValidationFailed"
    | "WeeklyMenuLineEdited"
    | "WeeklyMenuApproved"
    | "WeeklyMenuReopened"
    | "PlanningNeedGenerationRequested";
  actorId: string;
  at: string;
  reason?: string;
  lineId?: string;
  before?: string;
  after?: string;
};

export type WeeklyMenuApprovedSnapshot = {
  version: number;
  approvedBy: string;
  approvedAt: string;
  lineIds: string[];
};

export type WeeklyMenu = {
  id: string;
  weekStart: string;
  weekEnd: string;
  sourceType: string;
  sourceName: string;
  sourceSignature: string;
  status: WeeklyMenuStatus;
  rowsCount: number;
  importedBy: string;
  importedAt: string;
  approvedBy?: string;
  approvedAt?: string;
  version: number;
  lines: WeeklyMenuLine[];
  issues: WeeklyMenuIssue[];
  changes: WeeklyMenuChange[];
  approvedSnapshots: WeeklyMenuApprovedSnapshot[];
  needGenerationRequestedAt?: string;
};

export type WeeklyMenuCommandResult = {
  menu: WeeklyMenu;
  accepted: boolean;
  validation?: WeeklyMenuValidationResult;
  message?: string;
};

export type WeeklyMenuValidationResult = {
  menu: WeeklyMenu;
  isValid: boolean;
  blockingIssues: WeeklyMenuIssue[];
  warnings: WeeklyMenuIssue[];
};

export type WeeklyMenuImportRow = {
  serviceDate: string;
  schoolId: string;
  menuSlot: string;
  dishId: string;
  sourceRowRef: string;
};

export type WeeklyMenuReferenceData = {
  schoolIds: readonly string[];
  dishIds: readonly string[];
};

type ImportInput = {
  weeklyMenuId: string;
  weekStart: string;
  weekEnd: string;
  sourceType: string;
  sourceName: string;
  sourceSignature: string;
  rows: WeeklyMenuImportRow[];
  actorId: string;
  at: string;
};

const issue = (
  menuId: string,
  lineId: string | undefined,
  code: WeeklyMenuIssue["issueCode"],
  message: string,
): WeeklyMenuIssue => ({
  id: `${menuId}-issue-${code}-${lineId ?? "menu"}`,
  weeklyMenuId: menuId,
  weeklyMenuLineId: lineId,
  severity: "BLOCKING",
  issueCode: code,
  message,
  isBlocking: true,
});

function isDateInWeek(date: string, weekStart: string, weekEnd: string) {
  return date >= weekStart && date <= weekEnd;
}

function validate(menu: WeeklyMenu, references: WeeklyMenuReferenceData) {
  const issues: WeeklyMenuIssue[] = [];
  const assignmentLines = new Map<string, WeeklyMenuLine>();
  for (const line of menu.lines) {
    if (!isDateInWeek(line.serviceDate, menu.weekStart, menu.weekEnd)) {
      issues.push(
        issue(
          menu.id,
          line.id,
          "DATE_OUTSIDE_WEEK",
          "Service date is outside the selected week.",
        ),
      );
    }
    if (!references.schoolIds.includes(line.schoolId)) {
      issues.push(
        issue(
          menu.id,
          line.id,
          "UNKNOWN_SCHOOL",
          "School reference is unknown.",
        ),
      );
    }
    if (!references.dishIds.includes(line.dishId)) {
      issues.push(
        issue(menu.id, line.id, "UNKNOWN_DISH", "Dish reference is unknown."),
      );
    }
    const key = `${line.schoolId}|${line.serviceDate}|${line.menuSlot}`;
    const original = assignmentLines.get(key);
    if (original) {
      issues.push(
        issue(
          menu.id,
          line.id,
          "DUPLICATE_ASSIGNMENT",
          "School, service date, and menu slot must be unique.",
        ),
      );
    } else {
      assignmentLines.set(key, line);
    }
  }
  return issues;
}

function withChange(menu: WeeklyMenu, change: WeeklyMenuChange): WeeklyMenu {
  return { ...menu, changes: [...menu.changes, change] };
}

export function ImportWeeklyMenu(
  input: ImportInput,
  references: WeeklyMenuReferenceData,
): WeeklyMenuCommandResult {
  const lines = input.rows.map((row, index): WeeklyMenuLine => ({
    id: `${input.weeklyMenuId}-line-${index + 1}`,
    weeklyMenuId: input.weeklyMenuId,
    serviceDate: row.serviceDate,
    schoolId: row.schoolId,
    menuSlot: row.menuSlot,
    dishId: row.dishId,
    status: "ACTIVE",
    sourceRowRef: row.sourceRowRef,
    createdBy: input.actorId,
    createdAt: input.at,
    updatedBy: input.actorId,
    updatedAt: input.at,
  }));
  const imported: WeeklyMenu = {
    id: input.weeklyMenuId,
    weekStart: input.weekStart,
    weekEnd: input.weekEnd,
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
  const menu = withChange(
    { ...imported, issues: validate(imported, references) },
    {
      id: `${input.weeklyMenuId}-event-1`,
      type: "WeeklyMenuImported",
      actorId: input.actorId,
      at: input.at,
    },
  );
  return { menu, accepted: true };
}

export function ValidateWeeklyMenu(
  menu: WeeklyMenu,
  references: WeeklyMenuReferenceData,
  actorId: string,
  at: string,
): WeeklyMenuValidationResult {
  const issues = validate(menu, references);
  const isValid = !issues.some((current) => current.isBlocking);
  const next = withChange(
    { ...menu, status: isValid ? "VALIDATED" : "DRAFT", issues },
    {
      id: `${menu.id}-event-${menu.changes.length + 1}`,
      type: isValid ? "WeeklyMenuValidated" : "WeeklyMenuValidationFailed",
      actorId,
      at,
    },
  );
  return {
    menu: next,
    isValid,
    blockingIssues: issues.filter((current) => current.isBlocking),
    warnings: issues.filter((current) => !current.isBlocking),
  };
}

export function EditWeeklyMenuLine(
  menu: WeeklyMenu,
  lineId: string,
  patch: Pick<
    WeeklyMenuImportRow,
    "serviceDate" | "schoolId" | "menuSlot" | "dishId"
  >,
  actorId: string,
  at: string,
): WeeklyMenuCommandResult {
  if (
    menu.status === "APPROVED" ||
    menu.status === "NEED_GENERATION_REQUESTED"
  ) {
    return {
      menu,
      accepted: false,
      message: "Reopen the approved menu before editing.",
    };
  }
  const original = menu.lines.find((line) => line.id === lineId);
  if (!original)
    return {
      menu,
      accepted: false,
      message: "Weekly menu line was not found.",
    };
  const lines = menu.lines.map((line) =>
    line.id === lineId
      ? { ...line, ...patch, updatedBy: actorId, updatedAt: at }
      : line,
  );
  const next = withChange(
    { ...menu, lines, status: "DRAFT", version: menu.version + 1 },
    {
      id: `${menu.id}-event-${menu.changes.length + 1}`,
      type: "WeeklyMenuLineEdited",
      actorId,
      at,
      lineId,
      before: `${original.serviceDate}|${original.schoolId}|${original.menuSlot}|${original.dishId}`,
      after: `${patch.serviceDate}|${patch.schoolId}|${patch.menuSlot}|${patch.dishId}`,
    },
  );
  return { menu: next, accepted: true };
}

export function ApproveWeeklyMenu(
  menu: WeeklyMenu,
  actorId: string,
  at: string,
): WeeklyMenuCommandResult {
  if (
    menu.issues.some((current) => current.isBlocking) ||
    menu.status !== "VALIDATED"
  ) {
    return {
      menu,
      accepted: false,
      message: "Resolve blocking issues and validate before approval.",
    };
  }
  const snapshot = {
    version: menu.version,
    approvedBy: actorId,
    approvedAt: at,
    lineIds: menu.lines.map((line) => line.id),
  };
  const next = withChange(
    {
      ...menu,
      status: "APPROVED",
      approvedBy: actorId,
      approvedAt: at,
      approvedSnapshots: [...menu.approvedSnapshots, snapshot],
    },
    {
      id: `${menu.id}-event-${menu.changes.length + 1}`,
      type: "WeeklyMenuApproved",
      actorId,
      at,
    },
  );
  return { menu: next, accepted: true };
}

export function ReopenWeeklyMenu(
  menu: WeeklyMenu,
  reason: string,
  actorId: string,
  at: string,
): WeeklyMenuCommandResult {
  if (
    (menu.status !== "APPROVED" &&
      menu.status !== "NEED_GENERATION_REQUESTED") ||
    !reason.trim()
  ) {
    return {
      menu,
      accepted: false,
      message: "An approved menu and a reopen reason are required.",
    };
  }
  const next = withChange(
    { ...menu, status: "REOPENED" },
    {
      id: `${menu.id}-event-${menu.changes.length + 1}`,
      type: "WeeklyMenuReopened",
      actorId,
      at,
      reason,
    },
  );
  return { menu: next, accepted: true };
}

export function RequestPlanningNeedGeneration(
  menu: WeeklyMenu,
  actorId: string,
  at: string,
): WeeklyMenuCommandResult {
  if (menu.status !== "APPROVED") {
    return {
      menu,
      accepted: false,
      message: "Need generation can only be requested from Approved.",
    };
  }
  const next = withChange(
    {
      ...menu,
      status: "NEED_GENERATION_REQUESTED",
      needGenerationRequestedAt: at,
    },
    {
      id: `${menu.id}-event-${menu.changes.length + 1}`,
      type: "PlanningNeedGenerationRequested",
      actorId,
      at,
    },
  );
  return { menu: next, accepted: true };
}

export type WeeklyMenuWorkbench = {
  week: string;
  status: WeeklyMenuStatus;
  blockingIssueCount: number;
  warningCount: number;
  changedSchoolDayCount: number;
  canApprove: boolean;
  canRequestNeedGeneration: boolean;
  lines: WeeklyMenuLine[];
};
export type WeeklyMenuValidationIssues = {
  blocking: WeeklyMenuIssue[];
  warnings: WeeklyMenuIssue[];
};
export type WeeklyMenuChangeHistory = WeeklyMenuChange[];
export type WeeklyMenuApprovalSummary = {
  importedRows: number;
  changedSchoolDays: number;
  approvedBy?: string;
  approvedAt?: string;
  needGenerationRequestedAt?: string;
};

export function WeeklyMenuWorkbench(menu: WeeklyMenu): WeeklyMenuWorkbench {
  const blockingIssueCount = menu.issues.filter(
    (current) => current.isBlocking,
  ).length;
  const changedSchoolDayCount = new Set(
    menu.changes
      .filter((change) => change.type === "WeeklyMenuLineEdited")
      .map((change) => change.lineId),
  ).size;
  return {
    week: `${menu.weekStart} to ${menu.weekEnd}`,
    status: menu.status,
    blockingIssueCount,
    warningCount: menu.issues.length - blockingIssueCount,
    changedSchoolDayCount,
    canApprove: menu.status === "VALIDATED" && blockingIssueCount === 0,
    canRequestNeedGeneration: menu.status === "APPROVED",
    lines: menu.lines,
  };
}

export function WeeklyMenuValidationIssues(
  menu: WeeklyMenu,
): WeeklyMenuValidationIssues {
  return {
    blocking: menu.issues.filter((issue) => issue.isBlocking),
    warnings: menu.issues.filter((issue) => !issue.isBlocking),
  };
}

export function WeeklyMenuChangeHistory(
  menu: WeeklyMenu,
): WeeklyMenuChangeHistory {
  return menu.changes;
}

export function WeeklyMenuApprovalSummary(
  menu: WeeklyMenu,
): WeeklyMenuApprovalSummary {
  return {
    importedRows: menu.rowsCount,
    changedSchoolDays: WeeklyMenuWorkbench(menu).changedSchoolDayCount,
    approvedBy: menu.approvedBy,
    approvedAt: menu.approvedAt,
    needGenerationRequestedAt: menu.needGenerationRequestedAt,
  };
}
