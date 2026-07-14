import { describe, expect, it } from "vitest";
import {
  prototypeCalculationFixtures,
  readyPlanningInputFixture,
} from "./needGenerationFixtures";
import {
  GenerateTheoreticalNeedsFromInputs,
  InvalidateGeneratedNeeds,
  ReleaseGeneratedNeedsForConfirmation,
  ValidateGeneratedNeeds,
} from "./needGenerationDomain";

const generate = (
  inputSet = readyPlanningInputFixture,
  fixtures = prototypeCalculationFixtures,
) =>
  GenerateTheoreticalNeedsFromInputs({
    needGenerationRunId: "need-run-1",
    inputSet,
    fixtures,
    actorId: "planner-lan",
    at: "2026-07-14T01:00:00.000Z",
  });

describe("Need Generation lifecycle", () => {
  it("generates, validates, and releases theoretical needs only in order", () => {
    const generated = generate();
    expect(generated.accepted).toBe(true);
    expect(generated.run?.status).toBe("GENERATED");
    expect(generated.run?.generatedLineCount).toBe(2);

    const earlyRelease = ReleaseGeneratedNeedsForConfirmation(
      generated.run!,
      "planner-lan",
      "2026-07-14T01:01:00.000Z",
    );
    expect(earlyRelease.accepted).toBe(false);

    const validated = ValidateGeneratedNeeds(
      generated.run!,
      "planner-lan",
      "2026-07-14T01:02:00.000Z",
    );
    expect(validated.accepted).toBe(true);
    expect(validated.run?.status).toBe("VALIDATED");

    const released = ReleaseGeneratedNeedsForConfirmation(
      validated.run!,
      "manager-minh",
      "2026-07-14T01:03:00.000Z",
    );
    expect(released.accepted).toBe(true);
    expect(released.run?.status).toBe("RELEASED_FOR_CONFIRMATION");
    expect(released.run?.releasedSnapshot?.theoreticalNeedLineIds).toEqual([
      "need-run-1-line-1",
      "need-run-1-line-2",
    ]);
  });

  it("rejects non-ready inputs", () => {
    const result = generate({
      ...readyPlanningInputFixture,
      status: "INVALIDATED",
    });
    expect(result.accepted).toBe(false);
    expect(result.run).toBeUndefined();
  });

  it("keeps blockers visible and prevents validation and release", () => {
    const result = generate(readyPlanningInputFixture, {
      ...prototypeCalculationFixtures,
      recipes: [],
    });
    expect(result.run?.blockingIssueCount).toBe(1);
    expect(result.run?.issues[0].issueCode).toBe("MISSING_ACTIVE_RECIPE");

    const validation = ValidateGeneratedNeeds(
      result.run!,
      "planner-lan",
      "2026-07-14T01:02:00.000Z",
    );
    expect(validation.accepted).toBe(false);
    expect(validation.run?.changes.at(-1)?.eventType).toBe(
      "NeedGenerationValidationFailed",
    );
    expect(
      ReleaseGeneratedNeedsForConfirmation(
        validation.run!,
        "manager-minh",
        "2026-07-14T01:03:00.000Z",
      ).accepted,
    ).toBe(false);
  });

  it("preserves source, calculation, and version traceability", () => {
    const run = generate().run!;
    expect(run.inputSnapshot).toMatchObject({
      planningInputSetId: "planning-input-2026-29",
      weeklyMenuVersion: 1,
      attendanceVersion: 1,
      readinessSnapshotId: "readiness-2026-29-v1",
      calculationRuleVersion: "prototype-exact-portion-v1",
    });
    expect(run.lines[0]).toMatchObject({
      theoreticalNeedLineId: "need-run-1-line-1",
      quantity: 72,
      sourceTraceId:
        "menu-line-1:attendance-line-1:recipe-pumpkin-soup:bom-pumpkin",
      calculationTrace: {
        portions: 320,
        quantityPerPortion: 0.225,
        operation: "PORTIONS_MULTIPLIED_BY_BOM_QUANTITY",
      },
    });
  });

  it("does not allow released runs to be recalculated through validation", () => {
    const validated = ValidateGeneratedNeeds(
      generate().run!,
      "planner-lan",
      "2026-07-14T01:02:00.000Z",
    ).run!;
    const released = ReleaseGeneratedNeedsForConfirmation(
      validated,
      "manager-minh",
      "2026-07-14T01:03:00.000Z",
    ).run!;
    const protectedResult = ValidateGeneratedNeeds(
      released,
      "planner-lan",
      "2026-07-14T01:04:00.000Z",
    );
    expect(protectedResult.accepted).toBe(false);
    expect(protectedResult.run).toBe(released);
    expect(protectedResult.run?.releasedSnapshot).toEqual(
      released.releasedSnapshot,
    );
  });

  it("invalidates while preserving the released snapshot and prior identities", () => {
    const validated = ValidateGeneratedNeeds(
      generate().run!,
      "planner-lan",
      "2026-07-14T01:02:00.000Z",
    ).run!;
    const released = ReleaseGeneratedNeedsForConfirmation(
      validated,
      "manager-minh",
      "2026-07-14T01:03:00.000Z",
    ).run!;
    const invalidated = InvalidateGeneratedNeeds(
      released,
      "recipe-pumpkin-soup@4",
      "Recipe version changed",
      "recipe-owner-an",
      "2026-07-14T02:00:00.000Z",
    );
    expect(invalidated.accepted).toBe(true);
    expect(invalidated.run?.status).toBe("INVALIDATED");
    expect(invalidated.run?.releasedSnapshot).toEqual(
      released.releasedSnapshot,
    );
    expect(
      invalidated.run?.lines.map((line) => line.theoreticalNeedLineId),
    ).toEqual(released.lines.map((line) => line.theoreticalNeedLineId));
    expect(invalidated.run?.changes.at(-1)).toMatchObject({
      eventType: "NeedGenerationInvalidated",
      affectedReference: "recipe-pumpkin-soup@4",
      reason: "Recipe version changed",
    });
  });
});
