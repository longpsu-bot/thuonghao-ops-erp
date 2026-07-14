import { describe, expect, it } from "vitest";
import {
  ApproveAttendance,
  ImportAttendance,
  ValidateAttendance,
} from "../attendance/attendanceDomain";
import {
  ApproveConfirmedNeeds,
  CreateConfirmedNeedsFromGeneration,
  ReleaseConfirmedNeedsForPurchaseHandoff,
  ValidateConfirmedNeeds,
} from "../confirmed-need/confirmedNeedDomain";
import {
  GenerateTheoreticalNeedsFromInputs,
  ReleaseGeneratedNeedsForConfirmation,
  ValidateGeneratedNeeds,
  type NeedGenerationCalculationFixtures,
  type ReadyPlanningInputSetFixture,
} from "../need-generation/needGenerationDomain";
import {
  EvaluatePlanningInputReadiness,
  RequestNeedGenerationFromInputs,
} from "../planning-input-readiness/planningInputReadinessDomain";
import {
  CreatePurchaseHandoffFromConfirmedNeeds,
  ReleasePurchaseHandoffToProcurement,
  ValidatePurchaseHandoff,
} from "../purchase-handoff/purchaseHandoffDomain";
import {
  ApproveWeeklyMenu,
  ImportWeeklyMenu,
  RequestPlanningNeedGeneration,
  ValidateWeeklyMenu,
} from "../weekly-menu/weeklyMenuDomain";

const at = "2026-07-14T01:00:00.000Z";
const actor = "planner-lan";
const period = { start: "2026-07-13", end: "2026-07-19" };

const calculationFixtures: NeedGenerationCalculationFixtures = {
  calculationRuleVersion: "prototype-exact-portion-v1",
  recipes: [
    {
      id: "recipe-pumpkin-soup",
      version: 3,
      dishId: "dish-pumpkin-soup",
      active: true,
      bomLines: [
        {
          id: "bom-pumpkin",
          ingredientId: "ingredient-pumpkin",
          quantityPerPortion: 0.225,
          unit: "kg",
          ingredientActive: true,
        },
      ],
    },
  ],
};

function approvedPlanningSources() {
  const importedMenu = ImportWeeklyMenu(
    {
      weeklyMenuId: "weekly-menu-2026-29",
      weekStart: period.start,
      weekEnd: period.end,
      sourceType: "controlled-import",
      sourceName: "Weekly menu",
      sourceSignature: "weekly-menu-v1",
      rows: [
        {
          serviceDate: "2026-07-14",
          schoolId: "school-nguyen-du",
          menuSlot: "lunch",
          dishId: "dish-pumpkin-soup",
          sourceRowRef: "menu-row-1",
        },
      ],
      actorId: actor,
      at,
    },
    { schoolIds: ["school-nguyen-du"], dishIds: ["dish-pumpkin-soup"] },
  ).menu;
  const approvedMenu = ApproveWeeklyMenu(
    ValidateWeeklyMenu(
      importedMenu,
      { schoolIds: ["school-nguyen-du"], dishIds: ["dish-pumpkin-soup"] },
      actor,
      at,
    ).menu,
    "manager-minh",
    at,
  ).menu;
  const requestedMenu = RequestPlanningNeedGeneration(
    approvedMenu,
    actor,
    at,
  ).menu;

  const importedAttendance = ImportAttendance(
    {
      attendanceBatchId: "attendance-2026-29",
      periodStart: period.start,
      periodEnd: period.end,
      sourceType: "controlled-import",
      sourceName: "Attendance",
      sourceSignature: "attendance-v1",
      rows: [
        {
          serviceDate: "2026-07-14",
          schoolId: "school-nguyen-du",
          studentPortions: 310,
          teacherPortions: 10,
          sourceRowRef: "attendance-row-1",
        },
      ],
      actorId: actor,
      at,
    },
    { schoolIds: ["school-nguyen-du"] },
  ).batch;
  const approvedAttendance = ApproveAttendance(
    ValidateAttendance(
      importedAttendance,
      { schoolIds: ["school-nguyen-du"] },
      actor,
      at,
    ).batch,
    "manager-minh",
    at,
  ).batch;

  return { requestedMenu, approvedAttendance };
}

function readyGenerationInput() {
  const { requestedMenu, approvedAttendance } = approvedPlanningSources();
  const readiness = EvaluatePlanningInputReadiness({
    planningInputSetId: "planning-input-2026-29",
    periodStart: period.start,
    periodEnd: period.end,
    weeklyMenuReference: {
      inputType: "WEEKLY_MENU",
      inputId: requestedMenu.id,
      inputVersion: requestedMenu.version,
      inputStatus: requestedMenu.status,
      periodStart: requestedMenu.weekStart,
      periodEnd: requestedMenu.weekEnd,
      approvedBy: requestedMenu.approvedBy,
      approvedAt: requestedMenu.approvedAt,
      unresolvedBlockingIssueCount: 0,
    },
    attendanceReference: {
      inputType: "ATTENDANCE",
      inputId: approvedAttendance.id,
      inputVersion: approvedAttendance.version,
      inputStatus: approvedAttendance.status,
      periodStart: approvedAttendance.periodStart,
      periodEnd: approvedAttendance.periodEnd,
      approvedBy: approvedAttendance.approvedBy,
      approvedAt: approvedAttendance.approvedAt,
      unresolvedBlockingIssueCount: 0,
    },
    actorId: actor,
    at,
  }).inputSet;
  const requested = RequestNeedGenerationFromInputs(
    readiness,
    actor,
    at,
  ).inputSet;
  const inputSet: ReadyPlanningInputSetFixture = {
    id: requested.id,
    periodStart: requested.periodStart,
    periodEnd: requested.periodEnd,
    status: requested.status,
    version: requested.version,
    readinessSnapshotId: `${requested.id}@${requested.version}`,
    weeklyMenu: {
      id: requestedMenu.id,
      version: requestedMenu.version,
      lines: requestedMenu.lines.map((line) => ({
        id: line.id,
        serviceDate: line.serviceDate,
        schoolId: line.schoolId,
        dishId: line.dishId,
      })),
    },
    attendance: {
      id: approvedAttendance.id,
      version: approvedAttendance.version,
      lines: approvedAttendance.lines.map((line) => ({
        id: line.id,
        serviceDate: line.serviceDate,
        schoolId: line.schoolId,
        portions: line.studentPortions + line.teacherPortions,
      })),
    },
  };
  return { requestedMenu, approvedAttendance, readiness, requested, inputSet };
}

describe("PD-01 Planning chain integration", () => {
  it("flows controlled Planning inputs through a released Procurement demand queue with complete source trace", () => {
    const {
      requestedMenu,
      approvedAttendance,
      readiness,
      requested,
      inputSet,
    } = readyGenerationInput();
    const generated = GenerateTheoreticalNeedsFromInputs({
      needGenerationRunId: "need-run-2026-29-v1",
      inputSet,
      fixtures: calculationFixtures,
      actorId: actor,
      at,
    }).run!;
    const releasedGeneration = ReleaseGeneratedNeedsForConfirmation(
      ValidateGeneratedNeeds(generated, actor, at).run!,
      "manager-minh",
      at,
    ).run!;
    const approvedConfirmedNeeds = ApproveConfirmedNeeds(
      ValidateConfirmedNeeds(
        CreateConfirmedNeedsFromGeneration({
          confirmedNeedBatchId: "confirmed-need-2026-29-v1",
          generationRun: releasedGeneration,
          actorId: actor,
          at,
        }).batch!,
        actor,
        at,
      ).batch!,
      "manager-minh",
      at,
    ).batch!;
    const releasedConfirmedNeeds = ReleaseConfirmedNeedsForPurchaseHandoff(
      approvedConfirmedNeeds,
      actor,
      at,
    ).batch!;
    const releasedHandoff = ReleasePurchaseHandoffToProcurement(
      ValidatePurchaseHandoff(
        CreatePurchaseHandoffFromConfirmedNeeds({
          purchaseHandoffBatchId: "purchase-handoff-2026-29-v1",
          confirmedNeedBatch: releasedConfirmedNeeds,
          actorId: actor,
          at,
        }).batch!,
        actor,
        at,
      ).batch!,
      actor,
      at,
    ).batch!;

    const line = releasedHandoff.lines[0];
    expect(readiness.status).toBe("READY");
    expect(requested.status).toBe("NEED_GENERATION_REQUESTED");
    expect(line.quantity).toBe(72);
    expect(line.purchaseDemandReference).toMatchObject({
      planningInputSetId: requested.id,
      weeklyMenuReference: `${requestedMenu.id}@${requestedMenu.version}`,
      attendanceReference: `${approvedAttendance.id}@${approvedAttendance.version}`,
      needGenerationRunId: releasedGeneration.needGenerationRunId,
      confirmedNeedBatchId: releasedConfirmedNeeds.confirmedNeedBatchId,
      confirmedNeedLineId: line.confirmedNeedLineId,
      theoreticalNeedLineId: releasedGeneration.lines[0].theoreticalNeedLineId,
      sourceTraceId: releasedGeneration.lines[0].sourceTraceId,
    });
    expect(line.sourceTraceId).toBe(
      `${requestedMenu.lines[0].id}:${approvedAttendance.lines[0].id}:recipe-pumpkin-soup:bom-pumpkin`,
    );
    expect(releasedHandoff.status).toBe("RELEASED_TO_PROCUREMENT");
    expect(releasedHandoff.releaseSnapshots).toHaveLength(1);
    expect(releasedHandoff.changes.at(-1)?.eventType).toBe(
      "PurchaseHandoffReleasedToProcurement",
    );
    expect("supplierId" in line).toBe(false);
    expect("purchaseOrderId" in line).toBe(false);
  });

  it("does not permit Confirmed Need or Purchase Handoff to bypass their required release gates", () => {
    const { inputSet } = readyGenerationInput();
    expect(
      GenerateTheoreticalNeedsFromInputs({
        needGenerationRunId: "rejected-not-ready-run",
        inputSet: { ...inputSet, status: "NOT_READY" },
        fixtures: calculationFixtures,
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
    const generated = GenerateTheoreticalNeedsFromInputs({
      needGenerationRunId: "need-run-for-gates",
      inputSet,
      fixtures: calculationFixtures,
      actorId: actor,
      at,
    }).run!;
    expect(
      CreateConfirmedNeedsFromGeneration({
        confirmedNeedBatchId: "rejected-confirmed-needs",
        generationRun: generated,
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
    const releasedGeneration = ReleaseGeneratedNeedsForConfirmation(
      ValidateGeneratedNeeds(generated, actor, at).run!,
      "manager-minh",
      at,
    ).run!;
    const approvedConfirmedNeeds = ApproveConfirmedNeeds(
      ValidateConfirmedNeeds(
        CreateConfirmedNeedsFromGeneration({
          confirmedNeedBatchId: "confirmed-needs-for-gates",
          generationRun: releasedGeneration,
          actorId: actor,
          at,
        }).batch!,
        actor,
        at,
      ).batch!,
      "manager-minh",
      at,
    ).batch!;
    expect(
      CreatePurchaseHandoffFromConfirmedNeeds({
        purchaseHandoffBatchId: "rejected-handoff",
        confirmedNeedBatch: approvedConfirmedNeeds,
        actorId: actor,
        at,
      }).accepted,
    ).toBe(false);
  });
});
