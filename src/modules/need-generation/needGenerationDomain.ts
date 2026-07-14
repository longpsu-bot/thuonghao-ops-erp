import type { PlanningInputReadinessStatus } from "../planning-input-readiness/planningInputReadinessDomain";

export type NeedGenerationStatus =
  "GENERATED" | "VALIDATED" | "RELEASED_FOR_CONFIRMATION" | "INVALIDATED";
export type NeedGenerationIssueSeverity = "BLOCKING" | "WARNING";

export type ReadyPlanningInputSetFixture = {
  id: string;
  periodStart: string;
  periodEnd: string;
  status: PlanningInputReadinessStatus;
  version: number;
  readinessSnapshotId: string;
  weeklyMenu: {
    id: string;
    version: number;
    lines: readonly {
      id: string;
      serviceDate: string;
      schoolId: string;
      dishId: string;
    }[];
  };
  attendance: {
    id: string;
    version: number;
    lines: readonly {
      id: string;
      serviceDate: string;
      schoolId: string;
      portions: number;
    }[];
  };
};

export type PrototypeBomLineFixture = {
  id: string;
  ingredientId: string;
  quantityPerPortion: number;
  unit: string;
  ingredientActive: boolean;
};
export type PrototypeRecipeFixture = {
  id: string;
  version: number;
  dishId: string;
  active: boolean;
  bomLines: readonly PrototypeBomLineFixture[];
};
export type NeedGenerationCalculationFixtures = {
  calculationRuleVersion: string;
  recipes: readonly PrototypeRecipeFixture[];
};

export type NeedGenerationInputSnapshot = {
  planningInputSetId: string;
  planningInputSetVersion: number;
  weeklyMenuId: string;
  weeklyMenuVersion: number;
  attendanceBatchId: string;
  attendanceVersion: number;
  readinessSnapshotId: string;
  calculationRuleVersion: string;
  recipeReferences: readonly { recipeId: string; recipeVersion: number }[];
};

export type CalculationTrace = {
  ruleVersion: string;
  attendanceLineId: string;
  portions: number;
  quantityPerPortion: number;
  operation: "PORTIONS_MULTIPLIED_BY_BOM_QUANTITY";
};

export type TheoreticalNeedLine = {
  theoreticalNeedLineId: string;
  needGenerationRunId: string;
  serviceDate: string;
  schoolId: string;
  dishId: string;
  recipeId: string;
  recipeVersion: number;
  bomLineId: string;
  ingredientId: string;
  quantity: number;
  unit: string;
  sourceTraceId: string;
  calculationTrace: CalculationTrace;
  status: "THEORETICAL" | "RELEASED_FOR_CONFIRMATION" | "INVALIDATED";
};

export type NeedGenerationIssue = {
  needGenerationIssueId: string;
  needGenerationRunId: string;
  theoreticalNeedLineId?: string;
  severity: NeedGenerationIssueSeverity;
  issueCode:
    | "INPUT_SET_NOT_READY"
    | "MISSING_ATTENDANCE"
    | "MISSING_ACTIVE_RECIPE"
    | "MISSING_BOM_LINES"
    | "INACTIVE_INGREDIENT"
    | "NEGATIVE_QUANTITY"
    | "MISSING_SOURCE_TRACE"
    | "ZERO_QUANTITY";
  message: string;
  schoolId?: string;
  serviceDate?: string;
  dishId?: string;
  recipeId?: string;
  ingredientId?: string;
  isBlocking: boolean;
};

export type NeedGenerationChange = {
  eventId: string;
  eventType:
    | "TheoreticalNeedsGenerated"
    | "NeedGenerationValidated"
    | "NeedGenerationValidationFailed"
    | "GeneratedNeedsReleasedForConfirmation"
    | "NeedGenerationInvalidated";
  needGenerationRunId: string;
  inputSnapshotReference: string;
  actorId: string;
  at: string;
  beforeStatus?: NeedGenerationStatus;
  afterStatus: NeedGenerationStatus;
  blockingIssueCount: number;
  warningCount: number;
  reason?: string;
  affectedReference?: string;
};

export type NeedGenerationRun = {
  needGenerationRunId: string;
  planningInputSetId: string;
  periodStart: string;
  periodEnd: string;
  readinessStatus: PlanningInputReadinessStatus;
  status: NeedGenerationStatus;
  inputSnapshot: NeedGenerationInputSnapshot;
  lines: readonly TheoreticalNeedLine[];
  issues: readonly NeedGenerationIssue[];
  generatedLineCount: number;
  blockingIssueCount: number;
  warningCount: number;
  generatedBy: string;
  generatedAt: string;
  validatedBy?: string;
  validatedAt?: string;
  releasedBy?: string;
  releasedAt?: string;
  releasedSnapshot?: {
    runVersion: number;
    theoreticalNeedLineIds: readonly string[];
    blockingIssueCount: number;
    warningCount: number;
    releasedBy: string;
    releasedAt: string;
  };
  invalidatedBy?: string;
  invalidatedAt?: string;
  invalidationReason?: string;
  invalidatedReference?: string;
  version: number;
  changes: readonly NeedGenerationChange[];
};

export type NeedGenerationCommandResult = {
  run?: NeedGenerationRun;
  accepted: boolean;
  message?: string;
};

const counts = (issues: readonly NeedGenerationIssue[]) => ({
  blockingIssueCount: issues.filter((item) => item.isBlocking).length,
  warningCount: issues.filter((item) => !item.isBlocking).length,
});

function makeIssue(
  runId: string,
  sequence: number,
  issueCode: NeedGenerationIssue["issueCode"],
  message: string,
  context: Partial<NeedGenerationIssue> = {},
  severity: NeedGenerationIssueSeverity = "BLOCKING",
): NeedGenerationIssue {
  return {
    needGenerationIssueId: `${runId}-issue-${sequence}`,
    needGenerationRunId: runId,
    severity,
    issueCode,
    message,
    isBlocking: severity === "BLOCKING",
    ...context,
  };
}

const snapshotReference = (run: Pick<NeedGenerationRun, "inputSnapshot">) =>
  `${run.inputSnapshot.readinessSnapshotId}@${run.inputSnapshot.planningInputSetVersion}`;

function event(
  run: NeedGenerationRun,
  eventType: NeedGenerationChange["eventType"],
  actorId: string,
  at: string,
  afterStatus: NeedGenerationStatus,
  extra: Pick<NeedGenerationChange, "reason" | "affectedReference"> = {},
): NeedGenerationChange {
  return {
    eventId: `${run.needGenerationRunId}-event-${run.changes.length + 1}`,
    eventType,
    needGenerationRunId: run.needGenerationRunId,
    inputSnapshotReference: snapshotReference(run),
    actorId,
    at,
    beforeStatus: run.status,
    afterStatus,
    blockingIssueCount: run.blockingIssueCount,
    warningCount: run.warningCount,
    ...extra,
  };
}

export function GenerateTheoreticalNeedsFromInputs(input: {
  needGenerationRunId: string;
  inputSet: ReadyPlanningInputSetFixture;
  fixtures: NeedGenerationCalculationFixtures;
  actorId: string;
  at: string;
}): NeedGenerationCommandResult {
  if (
    input.inputSet.status !== "READY" &&
    input.inputSet.status !== "NEED_GENERATION_REQUESTED"
  ) {
    return {
      accepted: false,
      message:
        "Theoretical needs require a Ready or requested PlanningInputSet.",
    };
  }

  const runId = input.needGenerationRunId;
  const issues: NeedGenerationIssue[] = [];
  const lines: TheoreticalNeedLine[] = [];
  const recipeReferences = new Map<string, number>();

  for (const menuLine of input.inputSet.weeklyMenu.lines) {
    const attendance = input.inputSet.attendance.lines.find(
      (line) =>
        line.schoolId === menuLine.schoolId &&
        line.serviceDate === menuLine.serviceDate,
    );
    const recipe = input.fixtures.recipes.find(
      (candidate) => candidate.dishId === menuLine.dishId && candidate.active,
    );
    if (!attendance) {
      issues.push(
        makeIssue(
          runId,
          issues.length + 1,
          "MISSING_ATTENDANCE",
          "No attendance exists for the planned school and date.",
          {
            schoolId: menuLine.schoolId,
            serviceDate: menuLine.serviceDate,
            dishId: menuLine.dishId,
          },
        ),
      );
      continue;
    }
    if (!recipe) {
      issues.push(
        makeIssue(
          runId,
          issues.length + 1,
          "MISSING_ACTIVE_RECIPE",
          "The planned dish has no active prototype recipe.",
          {
            schoolId: menuLine.schoolId,
            serviceDate: menuLine.serviceDate,
            dishId: menuLine.dishId,
          },
        ),
      );
      continue;
    }
    recipeReferences.set(recipe.id, recipe.version);
    if (recipe.bomLines.length === 0) {
      issues.push(
        makeIssue(
          runId,
          issues.length + 1,
          "MISSING_BOM_LINES",
          "The active recipe has no BOM lines.",
          {
            schoolId: menuLine.schoolId,
            serviceDate: menuLine.serviceDate,
            dishId: menuLine.dishId,
            recipeId: recipe.id,
          },
        ),
      );
      continue;
    }
    for (const bomLine of recipe.bomLines) {
      if (!bomLine.ingredientActive) {
        issues.push(
          makeIssue(
            runId,
            issues.length + 1,
            "INACTIVE_INGREDIENT",
            "The BOM line references an inactive ingredient.",
            {
              schoolId: menuLine.schoolId,
              serviceDate: menuLine.serviceDate,
              dishId: menuLine.dishId,
              recipeId: recipe.id,
              ingredientId: bomLine.ingredientId,
            },
          ),
        );
        continue;
      }
      const quantity = attendance.portions * bomLine.quantityPerPortion;
      const lineId = `${runId}-line-${lines.length + 1}`;
      const sourceTraceId = `${menuLine.id}:${attendance.id}:${recipe.id}:${bomLine.id}`;
      const line: TheoreticalNeedLine = {
        theoreticalNeedLineId: lineId,
        needGenerationRunId: runId,
        serviceDate: menuLine.serviceDate,
        schoolId: menuLine.schoolId,
        dishId: menuLine.dishId,
        recipeId: recipe.id,
        recipeVersion: recipe.version,
        bomLineId: bomLine.id,
        ingredientId: bomLine.ingredientId,
        quantity,
        unit: bomLine.unit,
        sourceTraceId,
        calculationTrace: {
          ruleVersion: input.fixtures.calculationRuleVersion,
          attendanceLineId: attendance.id,
          portions: attendance.portions,
          quantityPerPortion: bomLine.quantityPerPortion,
          operation: "PORTIONS_MULTIPLIED_BY_BOM_QUANTITY",
        },
        status: "THEORETICAL",
      };
      lines.push(line);
      if (quantity < 0)
        issues.push(
          makeIssue(
            runId,
            issues.length + 1,
            "NEGATIVE_QUANTITY",
            "Generated quantity cannot be negative.",
            { theoreticalNeedLineId: lineId },
          ),
        );
      else if (quantity === 0)
        issues.push(
          makeIssue(
            runId,
            issues.length + 1,
            "ZERO_QUANTITY",
            "Generated quantity is zero and should be reviewed.",
            { theoreticalNeedLineId: lineId },
            "WARNING",
          ),
        );
      if (!sourceTraceId)
        issues.push(
          makeIssue(
            runId,
            issues.length + 1,
            "MISSING_SOURCE_TRACE",
            "Generated line lacks source trace.",
            { theoreticalNeedLineId: lineId },
          ),
        );
    }
  }

  const issueCounts = counts(issues);
  const snapshot: NeedGenerationInputSnapshot = {
    planningInputSetId: input.inputSet.id,
    planningInputSetVersion: input.inputSet.version,
    weeklyMenuId: input.inputSet.weeklyMenu.id,
    weeklyMenuVersion: input.inputSet.weeklyMenu.version,
    attendanceBatchId: input.inputSet.attendance.id,
    attendanceVersion: input.inputSet.attendance.version,
    readinessSnapshotId: input.inputSet.readinessSnapshotId,
    calculationRuleVersion: input.fixtures.calculationRuleVersion,
    recipeReferences: [...recipeReferences].map(
      ([recipeId, recipeVersion]) => ({ recipeId, recipeVersion }),
    ),
  };
  const base: NeedGenerationRun = {
    needGenerationRunId: runId,
    planningInputSetId: input.inputSet.id,
    periodStart: input.inputSet.periodStart,
    periodEnd: input.inputSet.periodEnd,
    readinessStatus: input.inputSet.status,
    status: "GENERATED",
    inputSnapshot: snapshot,
    lines,
    issues,
    generatedLineCount: lines.length,
    ...issueCounts,
    generatedBy: input.actorId,
    generatedAt: input.at,
    version: 1,
    changes: [],
  };
  const generatedEvent: NeedGenerationChange = {
    eventId: `${runId}-event-1`,
    eventType: "TheoreticalNeedsGenerated",
    needGenerationRunId: runId,
    inputSnapshotReference: snapshotReference(base),
    actorId: input.actorId,
    at: input.at,
    afterStatus: "GENERATED",
    ...issueCounts,
  };
  return { accepted: true, run: { ...base, changes: [generatedEvent] } };
}

export function ValidateGeneratedNeeds(
  run: NeedGenerationRun,
  actorId: string,
  at: string,
): NeedGenerationCommandResult {
  if (run.status !== "GENERATED")
    return {
      run,
      accepted: false,
      message: "Only a Generated run can be validated.",
    };
  if (run.blockingIssueCount > 0) {
    return {
      run: {
        ...run,
        changes: [
          ...run.changes,
          event(
            run,
            "NeedGenerationValidationFailed",
            actorId,
            at,
            "GENERATED",
          ),
        ],
      },
      accepted: false,
      message: "Blocking issues must be resolved before validation.",
    };
  }
  const status: NeedGenerationStatus = "VALIDATED";
  return {
    accepted: true,
    run: {
      ...run,
      status,
      validatedBy: actorId,
      validatedAt: at,
      changes: [
        ...run.changes,
        event(run, "NeedGenerationValidated", actorId, at, status),
      ],
    },
  };
}

export function ReleaseGeneratedNeedsForConfirmation(
  run: NeedGenerationRun,
  actorId: string,
  at: string,
): NeedGenerationCommandResult {
  if (run.status !== "VALIDATED" || run.blockingIssueCount > 0)
    return {
      run,
      accepted: false,
      message:
        "Only a Validated run without blockers can be released for confirmation.",
    };
  const status: NeedGenerationStatus = "RELEASED_FOR_CONFIRMATION";
  const lineIds = run.lines.map((line) => line.theoreticalNeedLineId);
  return {
    accepted: true,
    run: {
      ...run,
      status,
      lines: run.lines.map((line) => ({
        ...line,
        status: "RELEASED_FOR_CONFIRMATION",
      })),
      releasedBy: actorId,
      releasedAt: at,
      releasedSnapshot: {
        runVersion: run.version,
        theoreticalNeedLineIds: lineIds,
        blockingIssueCount: run.blockingIssueCount,
        warningCount: run.warningCount,
        releasedBy: actorId,
        releasedAt: at,
      },
      changes: [
        ...run.changes,
        event(
          run,
          "GeneratedNeedsReleasedForConfirmation",
          actorId,
          at,
          status,
        ),
      ],
    },
  };
}

export function InvalidateGeneratedNeeds(
  run: NeedGenerationRun,
  affectedReference: string,
  reason: string,
  actorId: string,
  at: string,
): NeedGenerationCommandResult {
  if (
    run.status === "INVALIDATED" ||
    !affectedReference.trim() ||
    !reason.trim()
  )
    return {
      run,
      accepted: false,
      message: "An active run, affected reference, and reason are required.",
    };
  const status: NeedGenerationStatus = "INVALIDATED";
  return {
    accepted: true,
    run: {
      ...run,
      status,
      lines: run.lines.map((line) => ({ ...line, status: "INVALIDATED" })),
      invalidatedBy: actorId,
      invalidatedAt: at,
      invalidationReason: reason,
      invalidatedReference: affectedReference,
      changes: [
        ...run.changes,
        event(run, "NeedGenerationInvalidated", actorId, at, status, {
          reason,
          affectedReference,
        }),
      ],
    },
  };
}

export type NeedGenerationWorkbench = {
  servicePeriod: string;
  readinessStatus: PlanningInputReadinessStatus;
  generationStatus: NeedGenerationStatus;
  blockingIssueCount: number;
  warningCount: number;
  generatedLineCount: number;
  canValidate: boolean;
  canReleaseForConfirmation: boolean;
};

export function NeedGenerationWorkbench(
  run: NeedGenerationRun,
): NeedGenerationWorkbench {
  return {
    servicePeriod: `${run.periodStart} to ${run.periodEnd}`,
    readinessStatus: run.readinessStatus,
    generationStatus: run.status,
    blockingIssueCount: run.blockingIssueCount,
    warningCount: run.warningCount,
    generatedLineCount: run.generatedLineCount,
    canValidate: run.status === "GENERATED" && run.blockingIssueCount === 0,
    canReleaseForConfirmation:
      run.status === "VALIDATED" && run.blockingIssueCount === 0,
  };
}
