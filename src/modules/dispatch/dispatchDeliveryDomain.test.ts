import { describe, expect, it } from "vitest";
import {
  AssignDispatchTrip,
  AssignDriverOrVehicleReference,
  AttemptUpstreamMutation,
  CompleteDispatchTrip,
  ConfirmDeliveryStop,
  ConfirmDispatchLoad,
  CreateDispatchPlanFromRequirements,
  DispatchDeliveryWorkbench,
  RecordDeliveryException,
  RecordDispatchDeparture,
  RecordReturnEvidence,
  type DeliveryConfirmation,
  type DispatchDeliveryState,
} from "./dispatchDeliveryDomain";
import {
  dispatchDeliveryInputFixture,
  missingMixedEvidenceFixture,
} from "./dispatchDeliveryFixtures";

const actorId = "dispatcher-lan";
const at = "2026-07-14T05:10:00.000Z";

function assignedState(
  requirementIds: readonly string[],
  base = dispatchDeliveryInputFixture,
) {
  const planned = CreateDispatchPlanFromRequirements(base, {
    dispatchPlanId: "DP-TEST",
    requirementIds,
    serviceDate: "2026-07-14",
    actorId,
    at,
  });
  expect(planned.accepted).toBe(true);
  const assigned = AssignDispatchTrip(planned.state, {
    dispatchTripId: "DT-TEST",
    dispatchPlanId: "DP-TEST",
    routeReference: "ROUTE-MANUAL-TEST",
    actorId,
    at,
  });
  return AssignDriverOrVehicleReference(assigned.state, {
    dispatchTripId: "DT-TEST",
    driverReference: "DRIVER-REF-01",
    vehicleReference: "VEHICLE-REF-01",
    actorId,
    at,
  }).state;
}

function loadRequirement(
  state: DispatchDeliveryState,
  requirementId: string,
  quantities?: readonly number[],
) {
  const requirement = state.requirements.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const allocation = state.allocations.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  return ConfirmDispatchLoad(state, {
    dispatchLoadId: `LOAD-${requirementId}`,
    dispatchTripId: "DT-TEST",
    dispatchRequirementId: requirementId,
    actorId,
    at,
    lines: allocation.lines.map((line, index) => ({
      dispatchRequirementLineId: line.dispatchRequirementLineId,
      fulfilmentAllocationLineId: line.fulfilmentAllocationLineId,
      fulfilmentEvidenceIds: state.fulfilmentEvidence
        .filter(
          (candidate) =>
            candidate.fulfilmentAllocationLineId ===
            line.fulfilmentAllocationLineId,
        )
        .map((candidate) => candidate.fulfilmentEvidenceId),
      loadedQuantity: quantities?.[index] ?? line.allocatedQuantity,
      loadedUnit: requirement.lines[0].requiredUnit,
    })),
  });
}

describe("Dispatch and Delivery domain", () => {
  it("plans both school catering and wholesale requirements", () => {
    const result = CreateDispatchPlanFromRequirements(
      dispatchDeliveryInputFixture,
      {
        dispatchPlanId: "DP-SOURCES",
        requirementIds: ["DR-SCHOOL-CROSSDOCK-001", "DR-WHOLESALE-003"],
        serviceDate: "2026-07-14",
        actorId,
        at,
      },
    );
    expect(result.accepted).toBe(true);
    expect(result.state.plans[0].dispatchRequirementIds).toHaveLength(2);
    expect(
      DispatchDeliveryWorkbench(result.state).rows.map(
        (row) => row.sourceOfNeed,
      ),
    ).toEqual(expect.arrayContaining(["SCHOOL_CATERING", "WHOLESALE"]));
  });

  it("accepts supplier cross-dock evidence without warehouse release", () => {
    const state = assignedState(["DR-SCHOOL-CROSSDOCK-001"]);
    const result = loadRequirement(state, "DR-SCHOOL-CROSSDOCK-001");
    expect(result.accepted).toBe(true);
    expect(result.state.loads[0].lines[0].fulfilmentEvidenceIds).toEqual([
      "FE-CROSSDOCK-001",
    ]);
  });

  it("accepts warehouse release evidence only for warehouse allocation", () => {
    expect(
      loadRequirement(
        assignedState(["DR-SCHOOL-WAREHOUSE-002"]),
        "DR-SCHOOL-WAREHOUSE-002",
      ).accepted,
    ).toBe(true);
    const invalid: DispatchDeliveryState = {
      ...dispatchDeliveryInputFixture,
      fulfilmentEvidence: [
        ...dispatchDeliveryInputFixture.fulfilmentEvidence,
        {
          fulfilmentEvidenceId: "FE-WRONG",
          fulfilmentAllocationLineId: "FAL-SCHOOL-CROSSDOCK-001",
          evidenceType: "WAREHOUSE_STOCK_RELEASE",
          fulfilledQuantity: 20,
          fulfilledUnit: "kg",
          evidenceReference: "WRONG-WAREHOUSE-RELEASE",
          recordedAt: at,
        },
      ],
    };
    const state = assignedState(["DR-SCHOOL-CROSSDOCK-001"], invalid);
    const allocation = state.allocations.find(
      (candidate) =>
        candidate.dispatchRequirementId === "DR-SCHOOL-CROSSDOCK-001",
    )!;
    const result = ConfirmDispatchLoad(state, {
      dispatchLoadId: "LOAD-WRONG",
      dispatchTripId: "DT-TEST",
      dispatchRequirementId: "DR-SCHOOL-CROSSDOCK-001",
      actorId,
      at,
      lines: [
        {
          dispatchRequirementLineId: "DRL-SCHOOL-CROSSDOCK-001",
          fulfilmentAllocationLineId:
            allocation.lines[0].fulfilmentAllocationLineId,
          fulfilmentEvidenceIds: ["FE-WRONG"],
          loadedQuantity: 20,
          loadedUnit: "kg",
        },
      ],
    });
    expect(result.blockers.map((candidate) => candidate.issueCode)).toContain(
      "FULFILMENT_EVIDENCE_INVALID",
    );
  });

  it("requires evidence for every portion of mixed fulfilment", () => {
    const state = assignedState(["DR-MIXED-004"], missingMixedEvidenceFixture);
    const result = loadRequirement(state, "DR-MIXED-004");
    expect(result.accepted).toBe(false);
    expect(result.blockers.map((candidate) => candidate.issueCode)).toContain(
      "FULFILMENT_EVIDENCE_MISSING",
    );
    expect(
      loadRequirement(assignedState(["DR-MIXED-004"]), "DR-MIXED-004").accepted,
    ).toBe(true);
    const completeState = assignedState(["DR-MIXED-004"]);
    const allocation = completeState.allocations.find(
      (candidate) => candidate.dispatchRequirementId === "DR-MIXED-004",
    )!;
    const omittedPortion = ConfirmDispatchLoad(completeState, {
      dispatchLoadId: "LOAD-OMITTED-MIXED-PORTION",
      dispatchTripId: "DT-TEST",
      dispatchRequirementId: "DR-MIXED-004",
      actorId,
      at,
      lines: [
        {
          dispatchRequirementLineId: "DRL-MIXED-004",
          fulfilmentAllocationLineId:
            allocation.lines[0].fulfilmentAllocationLineId,
          fulfilmentEvidenceIds: ["FE-MIXED-SUPPLIER-004"],
          loadedQuantity: 25,
          loadedUnit: "kg",
        },
      ],
    });
    expect(omittedPortion.accepted).toBe(false);
  });

  it("blocks edits and actions owned by Planning, Procurement, physical sources, or other domains", () => {
    const original = JSON.stringify(dispatchDeliveryInputFixture);
    for (const target of [
      "PLANNING_REQUIREMENT",
      "PROCUREMENT_ALLOCATION",
      "WAREHOUSE_MOVEMENT",
      "SUPPLIER_RECEIVING",
      "CROSS_DOMAIN_APPROVAL",
    ] as const)
      expect(
        AttemptUpstreamMutation(dispatchDeliveryInputFixture, target).accepted,
      ).toBe(false);
    expect(JSON.stringify(dispatchDeliveryInputFixture)).toBe(original);
  });

  it("does not expose commands that create upstream physical evidence", async () => {
    const domain = await import("./dispatchDeliveryDomain");
    expect(domain).not.toHaveProperty("CreateWarehouseStockRelease");
    expect(domain).not.toHaveProperty("CreateSupplierReceivingEvidence");
    expect(domain).not.toHaveProperty("ApproveQuality");
    expect(domain).not.toHaveProperty("ApproveProductionExecution");
    expect(domain).not.toHaveProperty("SettleAccounting");
  });

  it("blocks loading above physical fulfilment and delivery above load", () => {
    const state = assignedState(["DR-WHOLESALE-003"]);
    expect(
      loadRequirement(state, "DR-WHOLESALE-003", [16]).blockers.map(
        (candidate) => candidate.issueCode,
      ),
    ).toContain("LOAD_EXCEEDS_FULFILLED");
    const loaded = loadRequirement(state, "DR-WHOLESALE-003").state;
    const departed = RecordDispatchDeparture(loaded, {
      dispatchTripId: "DT-TEST",
      actorId,
      at,
    }).state;
    const stop = departed.trips[0].stops[0];
    const loadLine = departed.loads[0].lines[0];
    const confirmation: DeliveryConfirmation = {
      deliveryConfirmationId: "DC-OVER",
      dispatchStopId: stop.dispatchStopId,
      confirmedAt: at,
      confirmedBy: actorId,
      outcome: "DELIVERED",
      evidence: [
        {
          deliveryEvidenceId: "DE-OVER",
          evidenceReference: "RECEIVER-OVER",
          evidenceType: "RECEIVER_REFERENCE",
        },
      ],
      lines: [
        {
          deliveryConfirmationLineId: "DCL-OVER",
          dispatchLoadLineId: loadLine.dispatchLoadLineId,
          deliveredQuantity: 16,
          returnedQuantity: 0,
          exceptionQuantity: 0,
          unit: "kg",
        },
      ],
    };
    expect(
      ConfirmDeliveryStop(departed, {
        dispatchTripId: "DT-TEST",
        confirmation,
        actorId,
        at,
      }).blockers.map((candidate) => candidate.issueCode),
    ).toContain("DELIVERY_EXCEEDS_LOADED");
  });

  it("blocks normal closure for unresolved exceptions and closes after return evidence", () => {
    let state = assignedState(["DR-EXCEPTION-005"]);
    state = loadRequirement(state, "DR-EXCEPTION-005").state;
    state = RecordDispatchDeparture(state, {
      dispatchTripId: "DT-TEST",
      actorId,
      at,
    }).state;
    const stop = state.trips[0].stops[0];
    const loadLine = state.loads[0].lines[0];
    const confirmation: DeliveryConfirmation = {
      deliveryConfirmationId: "DC-EXCEPTION",
      dispatchStopId: stop.dispatchStopId,
      confirmedAt: at,
      confirmedBy: actorId,
      outcome: "PARTIALLY_DELIVERED",
      evidence: [
        {
          deliveryEvidenceId: "DE-EXCEPTION",
          evidenceReference: "HANDOVER-NOTE-EXCEPTION",
          evidenceType: "HANDOVER_NOTE",
        },
      ],
      lines: [
        {
          deliveryConfirmationLineId: "DCL-EXCEPTION",
          dispatchLoadLineId: loadLine.dispatchLoadLineId,
          deliveredQuantity: 7,
          returnedQuantity: 0,
          exceptionQuantity: 5,
          unit: "kg",
        },
      ],
    };
    state = ConfirmDeliveryStop(state, {
      dispatchTripId: "DT-TEST",
      confirmation,
      actorId,
      at,
    }).state;
    state = RecordDeliveryException(state, {
      exception: {
        deliveryExceptionId: "DX-005",
        dispatchStopId: stop.dispatchStopId,
        dispatchLoadLineId: loadLine.dispatchLoadLineId,
        exceptionType: "DESTINATION_CLOSED",
        exceptionQuantity: 5,
        reason: "Destination closed before handover completed.",
        recordedAt: at,
        resolved: false,
      },
      actorId,
      at,
    }).state;
    expect(
      CompleteDispatchTrip(state, {
        dispatchTripId: "DT-TEST",
        actorId,
        at,
      }).blockers.map((candidate) => candidate.issueCode),
    ).toContain("EXCEPTION_UNRESOLVED");
    state = RecordReturnEvidence(state, {
      returnEvidence: {
        returnEvidenceId: "RE-005",
        deliveryExceptionId: "DX-005",
        dispatchLoadLineId: loadLine.dispatchLoadLineId,
        returnedQuantity: 5,
        evidenceReference: "RETURN-HANDOVER-005",
        recordedAt: at,
      },
      actorId,
      at,
    }).state;
    const closed = CompleteDispatchTrip(state, {
      dispatchTripId: "DT-TEST",
      actorId,
      at,
    });
    expect(closed.accepted).toBe(true);
    expect(closed.state.trips[0].status).toBe("CLOSED_WITH_EXCEPTION");
  });

  it("contains no fields that imply excluded implementation behavior", () => {
    const serialized = JSON.stringify(
      dispatchDeliveryInputFixture,
    ).toLowerCase();
    for (const forbidden of [
      "credential",
      "gps",
      "routeoptimization",
      "driverpayroll",
      "vehiclemaintenance",
      "productiondata",
    ])
      expect(serialized).not.toContain(forbidden);
  });
});
