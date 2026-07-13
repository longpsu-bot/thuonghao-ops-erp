import { describe, expect, it } from "vitest";
import {
  EvaluatePlanningInputReadiness,
  InvalidatePlanningInputReadiness,
  PlanningInputReadinessHistory,
  PlanningInputReadinessIssues,
  PlanningInputReadinessSummary,
  PlanningInputReadinessWorkbench,
  RequestNeedGenerationFromInputs,
  type PlanningInputReference,
} from "./planningInputReadinessDomain";

const at = "2026-07-14T08:00:00.000Z";
const periodStart = "2026-07-20";
const periodEnd = "2026-07-26";
const weeklyMenu: PlanningInputReference = {
  inputType: "WEEKLY_MENU",
  inputId: "menu-30",
  inputVersion: 2,
  inputStatus: "APPROVED",
  periodStart,
  periodEnd,
  approvedBy: "manager-minh",
  approvedAt: at,
};
const attendance: PlanningInputReference = {
  inputType: "ATTENDANCE",
  inputId: "attendance-30",
  inputVersion: 4,
  inputStatus: "APPROVED",
  periodStart,
  periodEnd,
  approvedBy: "manager-minh",
  approvedAt: at,
};
const evaluate = (
  overrides: Partial<Parameters<typeof EvaluatePlanningInputReadiness>[0]> = {},
) =>
  EvaluatePlanningInputReadiness({
    planningInputSetId: "input-set-30",
    periodStart,
    periodEnd,
    weeklyMenuReference: weeklyMenu,
    attendanceReference: attendance,
    actorId: "planner-lan",
    at,
    ...overrides,
  }).inputSet;

describe("Planning Input Readiness domain", () => {
  it("blocks missing, unapproved, mismatched, and blocking inputs", () => {
    expect(
      evaluate({ weeklyMenuReference: undefined }).issues[0].issueCode,
    ).toBe("MISSING_WEEKLY_MENU");
    expect(
      evaluate({ attendanceReference: undefined }).issues[0].issueCode,
    ).toBe("MISSING_ATTENDANCE");
    expect(
      evaluate({
        weeklyMenuReference: { ...weeklyMenu, inputStatus: "DRAFT" },
      }).issues.map((item) => item.issueCode),
    ).toContain("UNAPPROVED_WEEKLY_MENU");
    expect(
      evaluate({
        attendanceReference: { ...attendance, inputStatus: "DRAFT" },
      }).issues.map((item) => item.issueCode),
    ).toContain("UNAPPROVED_ATTENDANCE");
    expect(
      evaluate({
        attendanceReference: { ...attendance, periodEnd: "2026-07-27" },
      }).issues.map((item) => item.issueCode),
    ).toContain("MISMATCHED_SERVICE_PERIOD");
    expect(
      evaluate({
        weeklyMenuReference: { ...weeklyMenu, unresolvedBlockingIssueCount: 1 },
      }).issues.map((item) => item.issueCode),
    ).toContain("WEEKLY_MENU_BLOCKING_ISSUES");
    expect(
      evaluate({
        attendanceReference: { ...attendance, unresolvedBlockingIssueCount: 1 },
      }).issues.map((item) => item.issueCode),
    ).toContain("ATTENDANCE_BLOCKING_ISSUES");
  });

  it("passes approved inputs, including handed-off upstream inputs", () => {
    expect(evaluate().status).toBe("READY");
    expect(
      evaluate({
        weeklyMenuReference: {
          ...weeklyMenu,
          inputStatus: "NEED_GENERATION_REQUESTED",
        },
        attendanceReference: {
          ...attendance,
          inputStatus: "USED_FOR_NEED_GENERATION",
        },
      }).status,
    ).toBe("READY");
  });

  it("only requests Need Generation from Ready inputs", () => {
    expect(
      RequestNeedGenerationFromInputs(evaluate(), "planner-lan", at).accepted,
    ).toBe(true);
    expect(
      RequestNeedGenerationFromInputs(
        evaluate({ weeklyMenuReference: undefined }),
        "planner-lan",
        at,
      ).accepted,
    ).toBe(false);
  });

  it("invalidates changed inputs, preserves the reason, and blocks a later request", () => {
    const invalidated = InvalidatePlanningInputReadiness(
      evaluate(),
      { ...weeklyMenu, inputVersion: 3 },
      "Weekly Menu version changed",
      "planner-lan",
      at,
    ).inputSet;
    expect(invalidated.status).toBe("INVALIDATED");
    expect(invalidated.weeklyMenuReference?.inputVersion).toBe(3);
    expect(PlanningInputReadinessHistory(invalidated).at(-1)).toMatchObject({
      type: "PlanningInputReadinessInvalidated",
      reason: "Weekly Menu version changed",
    });
    expect(
      RequestNeedGenerationFromInputs(invalidated, "planner-lan", at).accepted,
    ).toBe(false);
  });

  it("exposes status, issue counts, input versions, and available actions in read models", () => {
    const ready = evaluate();
    expect(PlanningInputReadinessWorkbench(ready)).toMatchObject({
      status: "READY",
      blockingIssueCount: 0,
      inputVersions: { weeklyMenu: 2, attendance: 4 },
      canRequestNeedGeneration: true,
    });
    expect(PlanningInputReadinessSummary(ready).evaluatedBy).toBe(
      "planner-lan",
    );
    expect(PlanningInputReadinessIssues(ready).blocking).toEqual([]);
  });
});
