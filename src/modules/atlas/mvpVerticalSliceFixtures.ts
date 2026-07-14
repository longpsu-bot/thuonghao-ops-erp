import { CompleteDispatchTrip } from "../dispatch/dispatchDeliveryDomain";
import {
  missingMixedEvidenceFixture,
  normalMixedDispatchFixture,
  normalSchoolCrossDockDispatchFixture,
  normalWholesaleDispatchFixture,
  returnedExceptionResolvedFixture,
} from "../dispatch/dispatchDeliveryFixtures";
import type {
  MvpVerticalSliceScenario,
  MvpVerticalSliceSourceTrace,
} from "./mvpVerticalSlice";

function onlyRequirement(
  state: typeof missingMixedEvidenceFixture,
  requirementId: string,
) {
  const requirement = state.requirements.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const allocation = state.allocations.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const allocationLineIds = allocation.lines.map(
    (candidate) => candidate.fulfilmentAllocationLineId,
  );
  return {
    ...state,
    requirements: [requirement],
    allocations: [allocation],
    fulfilmentEvidence: state.fulfilmentEvidence.filter((candidate) =>
      allocationLineIds.includes(candidate.fulfilmentAllocationLineId),
    ),
    plans: [],
    trips: [],
    loads: [],
    confirmations: [],
    exceptions: [],
    returns: [],
  };
}

function sourceTrace(
  state: MvpVerticalSliceScenario["dispatchState"],
  input: Pick<
    MvpVerticalSliceSourceTrace,
    | "demandSourceType"
    | "demandSourceReference"
    | "whoNeedsIt"
    | "schoolStatus"
    | "confirmedNeedLineReference"
    | "purchaseHandoffLineReference"
  >,
): MvpVerticalSliceSourceTrace {
  const requirement = state.requirements[0];
  const line = requirement.lines[0];
  return {
    ...input,
    dispatchRequirementLineId: line.dispatchRequirementLineId,
    deliveryLocationReference: requirement.deliveryLocationId,
    confirmedNeedStatus: "RELEASED_FOR_PURCHASE_HANDOFF",
    purchaseHandoffStatus: "RELEASED_TO_PROCUREMENT",
    planningReleaseReference: requirement.planningReleaseReference,
    requiredQuantity: line.requiredQuantity,
    requiredUnit: line.requiredUnit,
  };
}

const exceptionClosed = CompleteDispatchTrip(returnedExceptionResolvedFixture, {
  dispatchTripId: returnedExceptionResolvedFixture.trips[0].dispatchTripId,
  actorId: "dispatcher-review",
  at: "2026-07-14T07:35:00.000Z",
});
if (!exceptionClosed.accepted)
  throw new Error(
    "Synthetic exception scenario must close with return evidence.",
  );

const blockedMixedState = onlyRequirement(
  missingMixedEvidenceFixture,
  "DR-MIXED-004",
);

export const mvpVerticalSliceScenarios: readonly MvpVerticalSliceScenario[] = [
  {
    scenarioId: "SCHOOL_CATERING_HAPPY_PATH",
    scenarioName: "School catering via supplier cross-dock",
    dispatchState: normalSchoolCrossDockDispatchFixture,
    sourceTraces: [
      sourceTrace(normalSchoolCrossDockDispatchFixture, {
        demandSourceType: "CATERING_MENU",
        demandSourceReference: "MENU-AN-PHAT-2026-07-14",
        whoNeedsIt: "An Phat School",
        schoolStatus: "ACTIVE",
        confirmedNeedLineReference: "CONFIRMED-NEED-SCHOOL-001",
        purchaseHandoffLineReference: "PHL-SCHOOL-001",
      }),
    ],
  },
  {
    scenarioId: "SCHOOL_CATERING_MIXED_FULFILMENT",
    scenarioName: "One school line split between supplier and warehouse stock",
    dispatchState: normalMixedDispatchFixture,
    sourceTraces: [
      sourceTrace(normalMixedDispatchFixture, {
        demandSourceType: "CATERING_MENU",
        demandSourceReference: "MENU-HOA-SEN-2026-07-14",
        whoNeedsIt: "Hoa Sen School",
        schoolStatus: "ACTIVE",
        confirmedNeedLineReference: "CONFIRMED-NEED-MIXED-004",
        purchaseHandoffLineReference: "PHL-MIXED-004",
      }),
    ],
  },
  {
    scenarioId: "WHOLESALE_HAPPY_PATH",
    scenarioName: "Wholesale order via supplier receiving",
    dispatchState: normalWholesaleDispatchFixture,
    sourceTraces: [
      sourceTrace(normalWholesaleDispatchFixture, {
        demandSourceType: "WHOLESALE_ORDER",
        demandSourceReference: "WHOLESALE-ORDER-003",
        whoNeedsIt: "Minh An Wholesale Customer",
        confirmedNeedLineReference: "CONFIRMED-NEED-WHOLESALE-003",
        purchaseHandoffLineReference: "PHL-WHOLESALE-003",
      }),
    ],
  },
  {
    scenarioId: "DELIVERY_EXCEPTION_AND_RETURN",
    scenarioName: "Partial destination delivery resolved by return evidence",
    dispatchState: exceptionClosed.state,
    sourceTraces: [
      sourceTrace(exceptionClosed.state, {
        demandSourceType: "WHOLESALE_ORDER",
        demandSourceReference: "WHOLESALE-ORDER-006",
        whoNeedsIt: "Returned Goods Customer",
        confirmedNeedLineReference: "CONFIRMED-NEED-WHOLESALE-006",
        purchaseHandoffLineReference: "PHL-WHOLESALE-006",
      }),
    ],
  },
  {
    scenarioId: "BLOCKED_OPERATING_DAY",
    scenarioName:
      "Mixed fulfilment missing warehouse evidence and trip assignment",
    dispatchState: blockedMixedState,
    sourceTraces: [
      sourceTrace(blockedMixedState, {
        demandSourceType: "CATERING_MENU",
        demandSourceReference: "MENU-HOA-SEN-2026-07-14",
        whoNeedsIt: "Hoa Sen School",
        schoolStatus: "ACTIVE",
        confirmedNeedLineReference: "CONFIRMED-NEED-MIXED-004",
        purchaseHandoffLineReference: "PHL-MIXED-004",
      }),
    ],
  },
];
