import { describe, expect, it } from "vitest";
import {
  AttemptUpstreamMutation,
  DispatchDeliveryWorkbench,
} from "../dispatch/dispatchDeliveryDomain";
import { BuildMvpMorningChaosReadModel } from "./mvpMorningChaos";
import { mvpMorningChaosScenario } from "./mvpMorningChaosFixtures";

describe("MVP morning chaos simulation", () => {
  const readModel = BuildMvpMorningChaosReadModel(mvpMorningChaosScenario);

  it("represents the required operating context and chronological 02:00-08:00 timeline", () => {
    expect(mvpMorningChaosScenario.resources.schools).toHaveLength(10);
    expect(mvpMorningChaosScenario.resources.wholesaleCustomers).toHaveLength(
      2,
    );
    expect(mvpMorningChaosScenario.resources.suppliers).toHaveLength(4);
    expect(mvpMorningChaosScenario.resources.warehouses).toHaveLength(1);
    expect(mvpMorningChaosScenario.resources.trips).toHaveLength(3);
    expect(readModel.requirements.length).toBeGreaterThanOrEqual(28);
    expect(readModel.requirements.length).toBeLessThanOrEqual(32);
    expect(readModel.timeline.map((event) => event.at)).toEqual(
      [...readModel.timeline.map((event) => event.at)].sort(),
    );
    expect(readModel.timeline[0].at).toContain("T02:00:00");
    expect(readModel.timeline.at(-1)?.at).toContain("T08:00:00");
  });

  it("retains every original immutable source trace without read-model mutation", () => {
    const before = JSON.stringify(mvpMorningChaosScenario);
    BuildMvpMorningChaosReadModel(mvpMorningChaosScenario);
    expect(JSON.stringify(mvpMorningChaosScenario)).toBe(before);
    const lineIds = mvpMorningChaosScenario.dispatchState.requirements.flatMap(
      (requirement) =>
        requirement.lines.map((line) => line.dispatchRequirementLineId),
    );
    expect(mvpMorningChaosScenario.sourceTraces).toHaveLength(lineIds.length);
    expect(
      mvpMorningChaosScenario.sourceTraces.map(
        (trace) => trace.dispatchRequirementLineId,
      ),
    ).toEqual(expect.arrayContaining(lineIds));
    expect(
      readModel.requirements.every((row) =>
        row.unresolved.every(
          (issue) => !issue.includes("immutable source trace"),
        ),
      ),
    ).toBe(true);
  });

  it("keeps the late Planning change explicit and preserves the prior release", () => {
    const revision = mvpMorningChaosScenario.planningRevisions[0];
    const original = mvpMorningChaosScenario.dispatchState.requirements.find(
      (requirement) =>
        requirement.dispatchRequirementId ===
        revision.originalRequirementReference,
    )!;
    const additional = mvpMorningChaosScenario.dispatchState.requirements.find(
      (requirement) =>
        requirement.dispatchRequirementId ===
        revision.revisedRequirementReference,
    )!;
    expect(original.lines[0].requiredQuantity).toBe(10);
    expect(original.planningReleaseReference).toBe(
      revision.originalPlanningReleaseReference,
    );
    expect(additional.lines[0].requiredQuantity).toBe(4);
    expect(additional.planningReleaseReference).toBe(
      revision.revisedPlanningReleaseReference,
    );
    expect(revision.revisedTotalQuantity).toBe(14);
    expect(
      readModel.requirements.find(
        (row) => row.requirementReference === "DR-S05",
      )?.revisionStatus,
    ).toBe("ORIGINAL_WITH_EXPLICIT_REVISION");
    expect(
      readModel.requirements.find(
        (row) => row.requirementReference === "DR-S05-REV1",
      )?.revisionStatus,
    ).toBe("EXPLICIT_REVISION");
  });

  it("keeps partial supplier and warehouse fallback evidence below full readiness", () => {
    const revision = mvpMorningChaosScenario.allocationRevisions[0];
    expect(revision).toMatchObject({
      dispatchRequirementLineId: "DR-S10-L2",
      previousSupplierQuantity: 20,
      revisedSupplierQuantity: 12,
      warehouseFallbackQuantity: 8,
    });
    const shortage = readModel.requirements.find(
      (row) => row.requirementLineReference === "DR-S10-L2",
    )!;
    expect(shortage.fulfilment).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          sourceType: "SUPPLIER_PO",
          allocatedQuantity: 12,
          evidencedQuantity: 12,
        }),
        expect.objectContaining({
          sourceType: "WAREHOUSE_STOCK",
          allocatedQuantity: 8,
          evidencedQuantity: 5,
          evidenceTypes: ["WAREHOUSE_STOCK_RELEASE"],
        }),
      ]),
    );
    expect(shortage.evidenceReady).toBe(false);
    expect(shortage.uncoveredQuantity).toBe(3);
    expect(shortage.nextActionOwner).toBe("PROCUREMENT");
    expect(
      DispatchDeliveryWorkbench(
        mvpMorningChaosScenario.dispatchState,
      ).rows.find((row) => row.requirementReference === "DR-S10")?.readyToLoad,
    ).toBe(false);
  });

  it("keeps supplier-direct evidence independent from Warehouse release", () => {
    const supplierDirect = readModel.requirements.find((row) =>
      row.fulfilment.some(
        (portion) =>
          portion.sourceType === "SUPPLIER_PO" &&
          portion.evidenceTypes.includes("SUPPLIER_CROSS_DOCK"),
      ),
    )!;
    const supplierPortions = supplierDirect.fulfilment.filter(
      (portion) => portion.sourceType === "SUPPLIER_PO",
    );
    expect(supplierPortions).not.toHaveLength(0);
    for (const portion of supplierPortions)
      expect(portion.evidenceTypes).not.toContain("WAREHOUSE_STOCK_RELEASE");
    expect(supplierDirect.evidenceReady).toBe(true);
  });

  it("allows trips to progress independently and preserves requirement-to-trip mapping", () => {
    const concurrentPreparation = readModel.timeline.filter((event) =>
      ["MC-0420-TRIP-A-PREPARED", "MC-0422-TRIP-B-PREPARED"].includes(
        event.eventId,
      ),
    );
    expect(concurrentPreparation).toHaveLength(2);
    expect(
      readModel.trips.find((trip) => trip.dispatchTripId === "TRIP-A"),
    ).toMatchObject({
      status: "DELIVERED",
      lateByMinutes: 0,
    });
    expect(
      readModel.trips.find((trip) => trip.dispatchTripId === "TRIP-B"),
    ).toMatchObject({
      status: "CLOSED_WITH_EXCEPTION",
      lateByMinutes: 32,
    });
    expect(
      readModel.trips.find((trip) => trip.dispatchTripId === "TRIP-C"),
    ).toMatchObject({
      status: "LOADED",
      departedAt: undefined,
      blockedRequirementReferences: expect.arrayContaining(["DR-S10"]),
    });
    expect(
      readModel.requirements.find(
        (row) => row.requirementLineReference === "DR-S10-L2",
      )?.tripReference,
    ).toBe("TRIP-C");
    expect(
      readModel.requirements
        .filter((row) => row.requirementReference === "DR-S09")
        .every((row) => row.tripReference === "TRIP-C"),
    ).toBe(true);
  });

  it("records rejection quantity and resolves only the Dispatch path with return evidence", () => {
    const rejected = readModel.requirements.find(
      (row) => row.requirementLineReference === "DR-S06-L1",
    )!;
    expect(rejected.exceptionQuantity).toBe(4);
    expect(rejected.returnedQuantity).toBe(4);
    expect(rejected.destinationOutcome).toBe("RESOLVED_WITH_EXCEPTION");
    expect(
      mvpMorningChaosScenario.dispatchState.exceptions.find(
        (exception) => exception.deliveryExceptionId === "DX-S06-REJECTED",
      )?.resolved,
    ).toBe(true);
    expect(
      mvpMorningChaosScenario.dispatchState.returns[0].evidenceReference,
    ).toBe("RETURN-HANDOVER-S06-4KG");
    expect(
      mvpMorningChaosScenario.dispatchState.fulfilmentEvidence.some(
        (evidence) => evidence.evidenceReference.includes("RETURN"),
      ),
    ).toBe(false);
  });

  it("keeps the end-of-window shortage visible with owner-grouped attention", () => {
    const shortage = readModel.blockedAtEndOfWindow.find(
      (row) => row.requirementLineReference === "DR-S10-L2",
    );
    expect(shortage).toMatchObject({
      uncoveredQuantity: 3,
      nextActionOwner: "PROCUREMENT",
      tripReference: "TRIP-C",
    });
    expect(shortage?.unresolved.join(" ")).toContain(
      "remains without physical fulfilment evidence",
    );
    expect(Object.keys(readModel.attentionByOwner)).toEqual(
      expect.arrayContaining([
        "PLANNING",
        "PROCUREMENT",
        "SUPPLIER_RECEIVING",
        "WAREHOUSE",
        "DISPATCH",
        "DESTINATION_FOLLOW_UP",
      ]),
    );
    expect(
      readModel.attentionByOwner.PROCUREMENT.some(
        (item) => item.status === "OPEN" && item.at.includes("T08:00:00"),
      ),
    ).toBe(true);
  });

  it("prevents Dispatch from manufacturing or editing upstream facts", () => {
    const before = JSON.stringify(mvpMorningChaosScenario.dispatchState);
    for (const target of [
      "PLANNING_REQUIREMENT",
      "PROCUREMENT_ALLOCATION",
      "SUPPLIER_RECEIVING",
      "WAREHOUSE_MOVEMENT",
    ] as const)
      expect(
        AttemptUpstreamMutation(mvpMorningChaosScenario.dispatchState, target)
          .accepted,
      ).toBe(false);
    expect(JSON.stringify(mvpMorningChaosScenario.dispatchState)).toBe(before);
  });

  it("introduces no excluded platform or production behavior", async () => {
    const module = await import("./mvpMorningChaos");
    expect(Object.keys(module)).toEqual(["BuildMvpMorningChaosReadModel"]);
    const serialized = JSON.stringify(mvpMorningChaosScenario).toLowerCase();
    for (const forbidden of [
      "credential",
      "supabase",
      "retool",
      "postgresql",
      "edgefunction",
      "routeoptimization",
      "livegps",
      "payroll",
      "fleetmaintenance",
      "workflowengine",
      "qualityapproval",
      "productionexecution",
      "accountingentry",
    ])
      expect(serialized).not.toContain(forbidden);
  });
});
