import { describe, expect, it } from "vitest";
import {
  GenerateTheoreticalNeedsFromInputs,
  ValidateGeneratedNeeds,
} from "../need-generation/needGenerationDomain";
import {
  prototypeCalculationFixtures,
  readyPlanningInputFixture,
} from "../need-generation/needGenerationFixtures";
import {
  draftConfirmedNeedFixture,
  releasedNeedGenerationFixture,
} from "./confirmedNeedFixtures";
import {
  AdjustConfirmedNeedLine,
  ApproveConfirmedNeeds,
  CreateConfirmedNeedsFromGeneration,
  ReleaseConfirmedNeedsForPurchaseHandoff,
  ReopenConfirmedNeeds,
  ValidateConfirmedNeeds,
} from "./confirmedNeedDomain";

const validate = (batch = draftConfirmedNeedFixture) =>
  ValidateConfirmedNeeds(batch, "planner-lan", "2026-07-14T01:20:00.000Z")
    .batch!;
const approve = (batch = validate()) =>
  ApproveConfirmedNeeds(batch, "manager-minh", "2026-07-14T01:25:00.000Z")
    .batch!;

describe("Confirmed Need lifecycle", () => {
  it("creates only from released generated needs with equal initial quantities", () => {
    expect(draftConfirmedNeedFixture.status).toBe("DRAFT_REVIEW");
    expect(draftConfirmedNeedFixture.lines).toHaveLength(2);
    expect(
      draftConfirmedNeedFixture.lines.every(
        (line) => line.confirmedQuantity === line.theoreticalQuantity,
      ),
    ).toBe(true);

    const generated = GenerateTheoreticalNeedsFromInputs({
      needGenerationRunId: "unreleased-run",
      inputSet: readyPlanningInputFixture,
      fixtures: prototypeCalculationFixtures,
      actorId: "planner-lan",
      at: "2026-07-14T01:00:00.000Z",
    }).run!;
    const unreleased = ValidateGeneratedNeeds(
      generated,
      "planner-lan",
      "2026-07-14T01:05:00.000Z",
    ).run!;
    expect(
      CreateConfirmedNeedsFromGeneration({
        confirmedNeedBatchId: "rejected-batch",
        generationRun: unreleased,
        actorId: "planner-lan",
        at: "2026-07-14T01:10:00.000Z",
      }).accepted,
    ).toBe(false);
  });

  it("validates, approves, and releases only in lifecycle order", () => {
    expect(
      ApproveConfirmedNeeds(
        draftConfirmedNeedFixture,
        "manager-minh",
        "2026-07-14T01:21:00.000Z",
      ).accepted,
    ).toBe(false);
    const validated = validate();
    expect(validated.status).toBe("VALIDATED");
    const approved = approve(validated);
    expect(approved.status).toBe("APPROVED");
    expect(approved.approvedSnapshots).toHaveLength(1);
    const released = ReleaseConfirmedNeedsForPurchaseHandoff(
      approved,
      "planner-lan",
      "2026-07-14T01:30:00.000Z",
    );
    expect(released.accepted).toBe(true);
    expect(released.batch?.status).toBe("RELEASED_FOR_PURCHASE_HANDOFF");
    expect(released.batch?.releaseReference?.confirmedNeedLineIds).toEqual(
      approved.lines.map((line) => line.confirmedNeedLineId),
    );
  });

  it("records complete adjustment audit evidence", () => {
    const line = draftConfirmedNeedFixture.lines[0];
    const result = AdjustConfirmedNeedLine(draftConfirmedNeedFixture, {
      confirmedNeedLineId: line.confirmedNeedLineId,
      actorId: "planner-lan",
      at: "2026-07-14T01:18:00.000Z",
      reasonCode: "PORTION_CORRECTION",
      reasonNote: "Kitchen confirmed fewer portions",
      beforeQuantity: line.confirmedQuantity,
      afterQuantity: 70,
      unit: line.unit,
    });
    expect(result.accepted).toBe(true);
    expect(result.batch?.lines[0].adjustments[0]).toMatchObject({
      adjustedBy: "planner-lan",
      adjustedAt: "2026-07-14T01:18:00.000Z",
      reasonCode: "PORTION_CORRECTION",
      beforeQuantity: 72,
      afterQuantity: 70,
      unit: "kg",
    });
    expect(result.batch?.changes.at(-1)).toMatchObject({
      eventType: "ConfirmedNeedLineAdjusted",
      beforeQuantity: 72,
      afterQuantity: 70,
    });
  });

  it("rejects incomplete or stale adjustment evidence", () => {
    const line = draftConfirmedNeedFixture.lines[0];
    expect(
      AdjustConfirmedNeedLine(draftConfirmedNeedFixture, {
        confirmedNeedLineId: line.confirmedNeedLineId,
        actorId: "planner-lan",
        at: "2026-07-14T01:18:00.000Z",
        beforeQuantity: 999,
        afterQuantity: 70,
        unit: line.unit,
      }).accepted,
    ).toBe(false);
  });

  it("protects approved and released quantities from direct adjustment", () => {
    const approved = approve();
    const line = approved.lines[0];
    const adjustment = {
      confirmedNeedLineId: line.confirmedNeedLineId,
      actorId: "planner-lan",
      at: "2026-07-14T01:31:00.000Z",
      reasonNote: "Correction",
      beforeQuantity: line.confirmedQuantity,
      afterQuantity: 68,
      unit: line.unit,
    };
    expect(AdjustConfirmedNeedLine(approved, adjustment).accepted).toBe(false);
    const released = ReleaseConfirmedNeedsForPurchaseHandoff(
      approved,
      "planner-lan",
      "2026-07-14T01:30:00.000Z",
    ).batch!;
    expect(AdjustConfirmedNeedLine(released, adjustment).accepted).toBe(false);
  });

  it("preserves full source trace to generation and planning inputs", () => {
    const source = draftConfirmedNeedFixture.lines[0].sourceReference;
    expect(source).toEqual({
      needGenerationRunId: "need-run-2026-29-v1",
      needGenerationRunVersion: 1,
      theoreticalNeedLineId: "need-run-2026-29-v1-line-1",
      planningInputSetId: "planning-input-2026-29",
      weeklyMenuReference: "weekly-menu-2026-29@1",
      attendanceReference: "attendance-2026-29@1",
      recipeBomReference: "recipe-pumpkin-soup@3:bom-pumpkin",
      sourceTraceId:
        "menu-line-1:attendance-line-1:recipe-pumpkin-soup:bom-pumpkin",
    });
    expect(draftConfirmedNeedFixture.sourceGenerationReference).toMatchObject({
      needGenerationRunId: releasedNeedGenerationFixture.needGenerationRunId,
      runVersion: releasedNeedGenerationFixture.version,
    });
  });

  it("reopens with reason and preserves every prior approved snapshot", () => {
    const approved = approve();
    expect(
      ReopenConfirmedNeeds(
        approved,
        "",
        "manager-minh",
        "2026-07-14T02:00:00.000Z",
      ).accepted,
    ).toBe(false);
    const reopened = ReopenConfirmedNeeds(
      approved,
      "Attendance correction received",
      "manager-minh",
      "2026-07-14T02:00:00.000Z",
    ).batch!;
    expect(reopened.status).toBe("REOPENED");
    expect(reopened.version).toBe(2);
    expect(reopened.approvedSnapshots).toEqual(approved.approvedSnapshots);
    expect(reopened.changes.at(-1)).toMatchObject({
      eventType: "ConfirmedNeedsReopened",
      reasonNote: "Attendance correction received",
    });
    const line = reopened.lines[0];
    expect(
      AdjustConfirmedNeedLine(reopened, {
        confirmedNeedLineId: line.confirmedNeedLineId,
        actorId: "planner-lan",
        at: "2026-07-14T02:05:00.000Z",
        reasonNote: "Apply corrected attendance",
        beforeQuantity: line.confirmedQuantity,
        afterQuantity: 69,
        unit: line.unit,
      }).accepted,
    ).toBe(true);
  });
});
