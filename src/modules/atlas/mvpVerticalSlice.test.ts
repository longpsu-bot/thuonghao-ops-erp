import { describe, expect, it } from "vitest";
import {
  AttemptUpstreamMutation,
  CompleteDispatchTrip,
} from "../dispatch/dispatchDeliveryDomain";
import { failedStopUnresolvedFixture } from "../dispatch/dispatchDeliveryFixtures";
import { BuildMvpVerticalSliceReadModel } from "./mvpVerticalSlice";
import { mvpVerticalSliceScenarios } from "./mvpVerticalSliceFixtures";

describe("MVP vertical-slice operator review", () => {
  const readModel = BuildMvpVerticalSliceReadModel(mvpVerticalSliceScenarios);

  it("traces every synthetic source need through Planning release to its delivery outcome", () => {
    expect(readModel.rows).toHaveLength(5);
    for (const row of readModel.rows) {
      expect(row.demandSourceReference).not.toBe("");
      expect(row.whoNeedsIt).not.toBe("");
      expect(row.trace.confirmedNeedLineReference).not.toBe("");
      expect(row.trace.purchaseHandoffLineReference).not.toBe("");
      expect(row.trace.planningReleaseReference).not.toBe("");
      expect(row.trace.dispatchRequirementReference).not.toBe("");
      expect(row.fulfilmentAllocationReference).not.toBe("MISSING");
    }
    expect(
      readModel.rows
        .filter((row) => !row.blocksOperatingDay)
        .map((row) => row.tripOutcome),
    ).toEqual(["DELIVERED", "DELIVERED", "DELIVERED", "CLOSED_WITH_EXCEPTION"]);
  });

  it("keeps Planning quantities and Procurement allocations immutable downstream", () => {
    for (const scenario of mvpVerticalSliceScenarios) {
      const before = JSON.stringify(scenario.dispatchState);
      BuildMvpVerticalSliceReadModel([scenario]);
      expect(JSON.stringify(scenario.dispatchState)).toBe(before);
      for (const requirement of scenario.dispatchState.requirements) {
        const allocation = scenario.dispatchState.allocations.find(
          (candidate) =>
            candidate.dispatchRequirementId ===
            requirement.dispatchRequirementId,
        )!;
        expect(
          allocation.lines.reduce(
            (sum, candidate) => sum + candidate.allocatedQuantity,
            0,
          ),
        ).toBe(
          requirement.lines.reduce(
            (sum, candidate) => sum + candidate.requiredQuantity,
            0,
          ),
        );
      }
      expect(
        AttemptUpstreamMutation(scenario.dispatchState, "PLANNING_REQUIREMENT")
          .accepted,
      ).toBe(false);
      expect(
        AttemptUpstreamMutation(
          scenario.dispatchState,
          "PROCUREMENT_ALLOCATION",
        ).accepted,
      ).toBe(false);
      expect(JSON.stringify(scenario.dispatchState)).toBe(before);
    }
  });

  it("requires source-specific evidence for every mixed-fulfilment portion", () => {
    const supplierHappy = readModel.rows.find(
      (row) => row.scenarioId === "SCHOOL_CATERING_HAPPY_PATH",
    )!;
    expect(supplierHappy.fulfilment[0].sourceType).toBe("SUPPLIER_PO");
    expect(supplierHappy.fulfilment[0].evidenceTypes).toEqual([
      "SUPPLIER_CROSS_DOCK",
    ]);
    expect(supplierHappy.fulfilment[0].evidenceTypes).not.toContain(
      "WAREHOUSE_STOCK_RELEASE",
    );

    const mixed = readModel.rows.find(
      (row) => row.scenarioId === "SCHOOL_CATERING_MIXED_FULFILMENT",
    )!;
    expect(mixed.fulfilment).toHaveLength(2);
    expect(mixed.fulfilment).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          sourceType: "SUPPLIER_PO",
          evidenceTypes: ["SUPPLIER_RECEIVING"],
          loadedQuantity: 25,
        }),
        expect.objectContaining({
          sourceType: "WAREHOUSE_STOCK",
          evidenceTypes: ["WAREHOUSE_STOCK_RELEASE"],
          loadedQuantity: 10,
        }),
      ]),
    );

    const blocked = readModel.rows.find(
      (row) => row.scenarioId === "BLOCKED_OPERATING_DAY",
    )!;
    const warehousePortion = blocked.fulfilment.find(
      (portion) => portion.sourceType === "WAREHOUSE_STOCK",
    )!;
    expect(warehousePortion.evidenceReferences).toEqual([]);
    expect(blocked.loadedQuantity).toBe(0);
    expect(blocked.blocksOperatingDay).toBe(true);
  });

  it("blocks unresolved exceptions and closes the Dispatch path after return evidence only", () => {
    const blockedClosure = CompleteDispatchTrip(failedStopUnresolvedFixture, {
      dispatchTripId: failedStopUnresolvedFixture.trips[0].dispatchTripId,
      actorId: "dispatcher-review",
      at: "2026-07-14T07:30:00.000Z",
    });
    expect(blockedClosure.accepted).toBe(false);
    expect(blockedClosure.blockers.map((issue) => issue.issueCode)).toContain(
      "EXCEPTION_UNRESOLVED",
    );

    const resolved = readModel.rows.find(
      (row) => row.scenarioId === "DELIVERY_EXCEPTION_AND_RETURN",
    )!;
    expect(resolved.tripOutcome).toBe("CLOSED_WITH_EXCEPTION");
    expect(resolved.deliveredQuantity).toBe(3);
    expect(resolved.returnedQuantity).toBe(5);
    expect(resolved.returnEvidenceReferences).toEqual(["RETURN-HANDOVER-006"]);
    expect(resolved.unresolved).toEqual([]);
  });

  it("keeps blocked requirements visible in operator attention", () => {
    const blocked = readModel.rows.find(
      (row) => row.scenarioId === "BLOCKED_OPERATING_DAY",
    )!;
    expect(blocked.trace.dispatchRequirementReference).toBe("DR-MIXED-004");
    expect(blocked.tripReference).toBe("NOT_ASSIGNED");
    expect(blocked.unresolved.join(" ")).toContain(
      "physical fulfilment evidence is incomplete",
    );
    expect(blocked.unresolved.join(" ")).toContain(
      "dispatch trip is not assigned",
    );
    expect(
      readModel.attention.some(
        (item) =>
          item.scenarioId === "BLOCKED_OPERATING_DAY" &&
          item.requirementReference === "DR-MIXED-004",
      ),
    ).toBe(true);
  });

  it("adds no excluded platform or operational behavior", async () => {
    const module = await import("./mvpVerticalSlice");
    expect(Object.keys(module)).toEqual(["BuildMvpVerticalSliceReadModel"]);
    const serialized = JSON.stringify(mvpVerticalSliceScenarios).toLowerCase();
    for (const forbidden of [
      "credential",
      "gps",
      "payroll",
      "routeoptimization",
      "workflowengine",
      "accountingentry",
      "qualityapproval",
      "productionexecution",
    ])
      expect(serialized).not.toContain(forbidden);
  });
});
