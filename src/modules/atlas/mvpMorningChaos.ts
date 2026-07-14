import {
  DispatchDeliveryWorkbench,
  type DispatchDeliveryState,
  type FulfilmentEvidenceType,
  type FulfilmentSourceType,
  type SourceOfNeed,
} from "../dispatch/dispatchDeliveryDomain";
import type { MvpVerticalSliceSourceTrace } from "./mvpVerticalSlice";

export type MorningChaosOwner =
  | "PLANNING"
  | "PROCUREMENT"
  | "SUPPLIER_RECEIVING"
  | "WAREHOUSE"
  | "DISPATCH"
  | "DESTINATION_FOLLOW_UP";

export type MorningChaosReference = Readonly<{
  referenceId: string;
  name: string;
}>;

export type MorningChaosResources = Readonly<{
  schools: readonly MorningChaosReference[];
  wholesaleCustomers: readonly MorningChaosReference[];
  suppliers: readonly MorningChaosReference[];
  warehouses: readonly MorningChaosReference[];
  trips: readonly Readonly<{
    dispatchTripId: string;
    vehicleReference: string;
    driverReference: string;
  }>[];
}>;

export type MorningChaosTimelineEvent = Readonly<{
  eventId: string;
  at: string;
  owner: MorningChaosOwner;
  summary: string;
  requirementReferences: readonly string[];
  attentionStatus?: "OPEN" | "RESOLVED";
}>;

export type MorningChaosPlanningRevision = Readonly<{
  revisionReference: string;
  originalRequirementReference: string;
  revisedRequirementReference: string;
  originalPlanningReleaseReference: string;
  revisedPlanningReleaseReference: string;
  originalQuantity: number;
  changeQuantity: number;
  revisedTotalQuantity: number;
  unit: string;
  reason: string;
  recordedAt: string;
}>;

export type MorningChaosAllocationRevision = Readonly<{
  revisionReference: string;
  dispatchRequirementLineId: string;
  previousSupplierQuantity: number;
  revisedSupplierQuantity: number;
  warehouseFallbackQuantity: number;
  reason: string;
  revisedAt: string;
}>;

export type MorningChaosTripTarget = Readonly<{
  dispatchTripId: string;
  plannedDepartureAt: string;
}>;

export type MvpMorningChaosScenario = Readonly<{
  resources: MorningChaosResources;
  timeline: readonly MorningChaosTimelineEvent[];
  sourceTraces: readonly MvpVerticalSliceSourceTrace[];
  planningRevisions: readonly MorningChaosPlanningRevision[];
  allocationRevisions: readonly MorningChaosAllocationRevision[];
  tripTargets: readonly MorningChaosTripTarget[];
  dispatchState: DispatchDeliveryState;
}>;

export type MorningChaosFulfilmentPortion = Readonly<{
  allocationLineReference: string;
  sourceType: FulfilmentSourceType;
  allocatedQuantity: number;
  evidencedQuantity: number;
  evidenceTypes: readonly FulfilmentEvidenceType[];
  evidenceReferences: readonly string[];
}>;

export type MorningChaosRequirementRow = Readonly<{
  requirementReference: string;
  requirementLineReference: string;
  sourceOfNeed: SourceOfNeed;
  demandSourceReference: string;
  planningReleaseReference: string;
  confirmedNeedLineReference: string;
  purchaseHandoffLineReference: string;
  revisionStatus:
    "UNCHANGED" | "ORIGINAL_WITH_EXPLICIT_REVISION" | "EXPLICIT_REVISION";
  linkedRevisionReference?: string;
  destinationReference: string;
  itemReference: string;
  requiredQuantity: number;
  unit: string;
  fulfilment: readonly MorningChaosFulfilmentPortion[];
  evidencedQuantity: number;
  loadedQuantity: number;
  deliveredQuantity: number;
  returnedQuantity: number;
  exceptionQuantity: number;
  uncoveredQuantity: number;
  tripReference: string;
  tripStatus: string;
  evidenceReady: boolean;
  destinationOutcome: string;
  unresolved: readonly string[];
  nextActionOwner?: MorningChaosOwner;
}>;

export type MorningChaosTripRow = Readonly<{
  dispatchTripId: string;
  vehicleReference: string;
  status: string;
  plannedDepartureAt: string;
  departedAt?: string;
  lateByMinutes: number;
  requirementReferences: readonly string[];
  blockedRequirementReferences: readonly string[];
}>;

export type MorningChaosAttentionItem = Readonly<{
  eventId: string;
  at: string;
  status: "OPEN" | "RESOLVED";
  message: string;
  requirementReferences: readonly string[];
}>;

export type MvpMorningChaosReadModel = Readonly<{
  timeline: readonly MorningChaosTimelineEvent[];
  requirements: readonly MorningChaosRequirementRow[];
  trips: readonly MorningChaosTripRow[];
  attentionByOwner: Readonly<
    Record<MorningChaosOwner, readonly MorningChaosAttentionItem[]>
  >;
  blockedAtEndOfWindow: readonly MorningChaosRequirementRow[];
}>;

const owners: readonly MorningChaosOwner[] = [
  "PLANNING",
  "PROCUREMENT",
  "SUPPLIER_RECEIVING",
  "WAREHOUSE",
  "DISPATCH",
  "DESTINATION_FOLLOW_UP",
];

const total = (values: readonly number[]) =>
  values.reduce((sum, value) => sum + value, 0);

function minutesBetween(planned: string, actual?: string) {
  if (!actual) return 0;
  return Math.max(
    0,
    Math.round((Date.parse(actual) - Date.parse(planned)) / 60_000),
  );
}

export function BuildMvpMorningChaosReadModel(
  scenario: MvpMorningChaosScenario,
): MvpMorningChaosReadModel {
  const workbench = DispatchDeliveryWorkbench(scenario.dispatchState);
  const requirements = scenario.dispatchState.requirements.flatMap(
    (requirement) => {
      const allocation = scenario.dispatchState.allocations.find(
        (candidate) =>
          candidate.dispatchRequirementId === requirement.dispatchRequirementId,
      );
      const plan = scenario.dispatchState.plans.find((candidate) =>
        candidate.dispatchRequirementIds.includes(
          requirement.dispatchRequirementId,
        ),
      );
      const trip = scenario.dispatchState.trips.find(
        (candidate) =>
          candidate.dispatchPlanId === plan?.dispatchPlanId &&
          candidate.stops.some(
            (stop) =>
              stop.dispatchRequirementId === requirement.dispatchRequirementId,
          ),
      );
      const stop = trip?.stops.find(
        (candidate) =>
          candidate.dispatchRequirementId === requirement.dispatchRequirementId,
      );
      const requirementAttention = workbench.attentionQueue.filter(
        (candidate) =>
          candidate.requirementReference === requirement.dispatchRequirementId,
      );
      return requirement.lines.map((line) => {
        const sourceTrace = scenario.sourceTraces.find(
          (candidate) =>
            candidate.dispatchRequirementLineId ===
            line.dispatchRequirementLineId,
        );
        if (!sourceTrace)
          throw new Error(
            `Missing immutable source trace for ${line.dispatchRequirementLineId}.`,
          );
        const allocationLines =
          allocation?.lines.filter(
            (candidate) =>
              candidate.dispatchRequirementLineId ===
              line.dispatchRequirementLineId,
          ) ?? [];
        const fulfilment = allocationLines.map((allocationLine) => {
          const evidence = scenario.dispatchState.fulfilmentEvidence.filter(
            (candidate) =>
              candidate.fulfilmentAllocationLineId ===
              allocationLine.fulfilmentAllocationLineId,
          );
          return {
            allocationLineReference: allocationLine.fulfilmentAllocationLineId,
            sourceType: allocationLine.sourceType,
            allocatedQuantity: allocationLine.allocatedQuantity,
            evidencedQuantity: total(
              evidence.map((candidate) => candidate.fulfilledQuantity),
            ),
            evidenceTypes: evidence.map((candidate) => candidate.evidenceType),
            evidenceReferences: evidence.map(
              (candidate) => candidate.evidenceReference,
            ),
          } satisfies MorningChaosFulfilmentPortion;
        });
        const loadLines = scenario.dispatchState.loads.flatMap((load) =>
          load.lines.filter(
            (candidate) =>
              candidate.dispatchRequirementLineId ===
              line.dispatchRequirementLineId,
          ),
        );
        const loadLineIds = loadLines.map(
          (candidate) => candidate.dispatchLoadLineId,
        );
        const confirmationLines = scenario.dispatchState.confirmations.flatMap(
          (confirmation) =>
            confirmation.lines.filter((candidate) =>
              loadLineIds.includes(candidate.dispatchLoadLineId),
            ),
        );
        const exceptions = scenario.dispatchState.exceptions.filter(
          (candidate) => loadLineIds.includes(candidate.dispatchLoadLineId),
        );
        const returns = scenario.dispatchState.returns.filter((candidate) =>
          loadLineIds.includes(candidate.dispatchLoadLineId),
        );
        const planningRevision = scenario.planningRevisions.find(
          (candidate) =>
            candidate.originalRequirementReference ===
              requirement.dispatchRequirementId ||
            candidate.revisedRequirementReference ===
              requirement.dispatchRequirementId,
        );
        const revisionStatus = planningRevision
          ? planningRevision.revisedRequirementReference ===
            requirement.dispatchRequirementId
            ? "EXPLICIT_REVISION"
            : "ORIGINAL_WITH_EXPLICIT_REVISION"
          : "UNCHANGED";
        const evidencedQuantity = total(
          fulfilment.map((candidate) => candidate.evidencedQuantity),
        );
        const allocatedQuantity = total(
          fulfilment.map((candidate) => candidate.allocatedQuantity),
        );
        const uncoveredQuantity = Math.max(
          0,
          line.requiredQuantity -
            Math.min(allocatedQuantity, evidencedQuantity),
        );
        const traceIssues = [
          sourceTrace.planningReleaseReference !==
          requirement.planningReleaseReference
            ? "Planning release reference does not match the immutable source trace."
            : undefined,
          sourceTrace.requiredQuantity !== line.requiredQuantity ||
          sourceTrace.requiredUnit !== line.requiredUnit
            ? "Planning-owned quantity differs from the immutable source trace."
            : undefined,
        ].filter((candidate): candidate is string => Boolean(candidate));
        const unresolved = [
          ...traceIssues,
          ...(uncoveredQuantity > 0
            ? [
                `${uncoveredQuantity} ${line.requiredUnit} remains without physical fulfilment evidence.`,
              ]
            : []),
          ...requirementAttention.map((candidate) => candidate.message),
          ...exceptions
            .filter((candidate) => !candidate.resolved)
            .map((candidate) => candidate.reason),
        ];
        let nextActionOwner: MorningChaosOwner | undefined;
        if (uncoveredQuantity > 0) nextActionOwner = "PROCUREMENT";
        else if (!trip) nextActionOwner = "DISPATCH";
        else if (exceptions.some((candidate) => !candidate.resolved))
          nextActionOwner = "DESTINATION_FOLLOW_UP";
        return {
          requirementReference: requirement.dispatchRequirementId,
          requirementLineReference: line.dispatchRequirementLineId,
          sourceOfNeed: requirement.sourceOfNeed,
          demandSourceReference: sourceTrace.demandSourceReference,
          planningReleaseReference: requirement.planningReleaseReference,
          confirmedNeedLineReference: sourceTrace.confirmedNeedLineReference,
          purchaseHandoffLineReference:
            sourceTrace.purchaseHandoffLineReference,
          revisionStatus,
          linkedRevisionReference: planningRevision?.revisionReference,
          destinationReference: requirement.destinationReference,
          itemReference: line.itemReference,
          requiredQuantity: line.requiredQuantity,
          unit: line.requiredUnit,
          fulfilment,
          evidencedQuantity,
          loadedQuantity: total(
            loadLines.map((candidate) => candidate.loadedQuantity),
          ),
          deliveredQuantity: total(
            confirmationLines.map((candidate) => candidate.deliveredQuantity),
          ),
          returnedQuantity: Math.max(
            total(
              confirmationLines.map((candidate) => candidate.returnedQuantity),
            ),
            total(returns.map((candidate) => candidate.returnedQuantity)),
          ),
          exceptionQuantity: Math.max(
            total(
              confirmationLines.map((candidate) => candidate.exceptionQuantity),
            ),
            total(exceptions.map((candidate) => candidate.exceptionQuantity)),
          ),
          uncoveredQuantity,
          tripReference: trip?.dispatchTripId ?? "NOT_ASSIGNED",
          tripStatus: trip?.status ?? "NOT_ASSIGNED",
          evidenceReady:
            fulfilment.length > 0 &&
            fulfilment.every(
              (candidate) =>
                candidate.evidencedQuantity >= candidate.allocatedQuantity,
            ) &&
            allocatedQuantity >= line.requiredQuantity,
          destinationOutcome: stop?.status ?? "NOT_STARTED",
          unresolved: [...new Set(unresolved)],
          nextActionOwner,
        } satisfies MorningChaosRequirementRow;
      });
    },
  );

  const trips = scenario.dispatchState.trips.map((trip) => {
    const target = scenario.tripTargets.find(
      (candidate) => candidate.dispatchTripId === trip.dispatchTripId,
    );
    if (!target)
      throw new Error(`Missing planned departure for ${trip.dispatchTripId}.`);
    const requirementReferences = trip.stops.map(
      (candidate) => candidate.dispatchRequirementId,
    );
    return {
      dispatchTripId: trip.dispatchTripId,
      vehicleReference: trip.vehicleReference ?? "UNASSIGNED",
      status: trip.status,
      plannedDepartureAt: target.plannedDepartureAt,
      departedAt: trip.departedAt,
      lateByMinutes: minutesBetween(target.plannedDepartureAt, trip.departedAt),
      requirementReferences,
      blockedRequirementReferences: requirements
        .filter(
          (candidate) =>
            requirementReferences.includes(candidate.requirementReference) &&
            candidate.unresolved.length > 0,
        )
        .map((candidate) => candidate.requirementReference),
    } satisfies MorningChaosTripRow;
  });

  const attentionByOwner = owners.reduce(
    (grouped, owner) => ({
      ...grouped,
      [owner]: scenario.timeline
        .filter(
          (candidate) => candidate.owner === owner && candidate.attentionStatus,
        )
        .map((candidate) => ({
          eventId: candidate.eventId,
          at: candidate.at,
          status: candidate.attentionStatus!,
          message: candidate.summary,
          requirementReferences: candidate.requirementReferences,
        })),
    }),
    {} as Record<MorningChaosOwner, readonly MorningChaosAttentionItem[]>,
  );

  return {
    timeline: [...scenario.timeline].sort((a, b) => a.at.localeCompare(b.at)),
    requirements,
    trips,
    attentionByOwner,
    blockedAtEndOfWindow: requirements.filter(
      (candidate) => candidate.unresolved.length > 0,
    ),
  };
}
