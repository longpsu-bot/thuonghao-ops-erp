import type { SchoolStatus } from "../admin/schoolAdminDomain";
import type { ConfirmedNeedStatus } from "../confirmed-need/confirmedNeedDomain";
import {
  DispatchDeliveryWorkbench,
  type DispatchDeliveryState,
  type FulfilmentEvidenceType,
  type FulfilmentSourceType,
  type SourceOfNeed,
} from "../dispatch/dispatchDeliveryDomain";
import type { DemandSourceType } from "../planner/types";
import type { PurchaseHandoffStatus } from "../purchase-handoff/purchaseHandoffDomain";

export type MvpVerticalSliceSourceTrace = Readonly<{
  dispatchRequirementLineId: string;
  demandSourceType: DemandSourceType;
  demandSourceReference: string;
  whoNeedsIt: string;
  schoolStatus?: SchoolStatus;
  deliveryLocationReference: string;
  confirmedNeedLineReference: string;
  confirmedNeedStatus: ConfirmedNeedStatus;
  purchaseHandoffLineReference: string;
  purchaseHandoffStatus: PurchaseHandoffStatus;
  planningReleaseReference: string;
  requiredQuantity: number;
  requiredUnit: string;
}>;

export type MvpVerticalSliceScenario = Readonly<{
  scenarioId: string;
  scenarioName: string;
  sourceTraces: readonly MvpVerticalSliceSourceTrace[];
  dispatchState: DispatchDeliveryState;
}>;

export type MvpVerticalSliceFulfilmentPortion = Readonly<{
  allocationLineReference: string;
  sourceType: FulfilmentSourceType;
  allocatedQuantity: number;
  evidenceTypes: readonly FulfilmentEvidenceType[];
  evidenceReferences: readonly string[];
  evidencedQuantity: number;
  loadedQuantity: number;
}>;

export type MvpVerticalSliceRow = Readonly<{
  scenarioId: string;
  scenarioName: string;
  sourceOfNeed: SourceOfNeed;
  demandSourceType: DemandSourceType;
  demandSourceReference: string;
  whoNeedsIt: string;
  schoolStatus?: SchoolStatus;
  deliveryLocationReference: string;
  itemReference: string;
  requiredQuantity: number;
  requiredUnit: string;
  trace: Readonly<{
    confirmedNeedLineReference: string;
    purchaseHandoffLineReference: string;
    planningReleaseReference: string;
    dispatchRequirementReference: string;
    dispatchRequirementLineReference: string;
  }>;
  fulfilmentAllocationReference: string;
  fulfilment: readonly MvpVerticalSliceFulfilmentPortion[];
  loadedQuantity: number;
  deliveredQuantity: number;
  returnedQuantity: number;
  exceptionQuantity: number;
  deliveryEvidenceReferences: readonly string[];
  returnEvidenceReferences: readonly string[];
  tripReference: string;
  tripOutcome: string;
  unresolved: readonly string[];
  blocksOperatingDay: boolean;
}>;

export type MvpVerticalSliceReadModel = Readonly<{
  rows: readonly MvpVerticalSliceRow[];
  attention: readonly Readonly<{
    scenarioId: string;
    requirementReference: string;
    message: string;
  }>[];
}>;

function total(values: readonly number[]) {
  return values.reduce((sum, value) => sum + value, 0);
}

export function BuildMvpVerticalSliceReadModel(
  scenarios: readonly MvpVerticalSliceScenario[],
): MvpVerticalSliceReadModel {
  const attention: {
    scenarioId: string;
    requirementReference: string;
    message: string;
  }[] = [];
  const rows = scenarios.flatMap((scenario) => {
    const workbench = DispatchDeliveryWorkbench(scenario.dispatchState);
    attention.push(
      ...workbench.attentionQueue.map((item) => ({
        scenarioId: scenario.scenarioId,
        requirementReference: item.requirementReference,
        message: item.message,
      })),
    );

    return scenario.dispatchState.requirements.flatMap((requirement) => {
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
        (candidate) => candidate.dispatchPlanId === plan?.dispatchPlanId,
      );
      const rowAttention = workbench.attentionQueue.filter(
        (item) =>
          item.requirementReference === requirement.dispatchRequirementId,
      );

      return requirement.lines.map((requirementLine) => {
        const sourceTrace = scenario.sourceTraces.find(
          (candidate) =>
            candidate.dispatchRequirementLineId ===
            requirementLine.dispatchRequirementLineId,
        );
        if (!sourceTrace)
          throw new Error(
            `${scenario.scenarioId}: missing source trace for ${requirementLine.dispatchRequirementLineId}.`,
          );
        const allocationLines =
          allocation?.lines.filter(
            (candidate) =>
              candidate.dispatchRequirementLineId ===
              requirementLine.dispatchRequirementLineId,
          ) ?? [];
        const loadLines = scenario.dispatchState.loads.flatMap((load) =>
          load.lines.filter(
            (candidate) =>
              candidate.dispatchRequirementLineId ===
              requirementLine.dispatchRequirementLineId,
          ),
        );
        const loadLineIds = loadLines.map(
          (candidate) => candidate.dispatchLoadLineId,
        );
        const confirmationLines = scenario.dispatchState.confirmations.flatMap(
          (confirmation) =>
            confirmation.lines.filter((line) =>
              loadLineIds.includes(line.dispatchLoadLineId),
            ),
        );
        const exceptions = scenario.dispatchState.exceptions.filter(
          (candidate) => loadLineIds.includes(candidate.dispatchLoadLineId),
        );
        const returns = scenario.dispatchState.returns.filter((candidate) =>
          loadLineIds.includes(candidate.dispatchLoadLineId),
        );
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
            evidenceTypes: evidence.map((candidate) => candidate.evidenceType),
            evidenceReferences: evidence.map(
              (candidate) => candidate.evidenceReference,
            ),
            evidencedQuantity: total(
              evidence.map((candidate) => candidate.fulfilledQuantity),
            ),
            loadedQuantity: total(
              loadLines
                .filter(
                  (candidate) =>
                    candidate.fulfilmentAllocationLineId ===
                    allocationLine.fulfilmentAllocationLineId,
                )
                .map((candidate) => candidate.loadedQuantity),
            ),
          };
        });
        const traceIssues = [
          sourceTrace.planningReleaseReference !==
          requirement.planningReleaseReference
            ? `${requirement.dispatchRequirementId}: Planning release trace does not match the Dispatch requirement.`
            : undefined,
          sourceTrace.requiredQuantity !== requirementLine.requiredQuantity ||
          sourceTrace.requiredUnit !== requirementLine.requiredUnit
            ? `${requirement.dispatchRequirementId}: Planning-owned quantity changed downstream.`
            : undefined,
        ].filter((issue): issue is string => Boolean(issue));
        const unresolved = [
          ...traceIssues,
          ...rowAttention.map((item) => item.message),
        ];
        return {
          scenarioId: scenario.scenarioId,
          scenarioName: scenario.scenarioName,
          sourceOfNeed: requirement.sourceOfNeed,
          demandSourceType: sourceTrace.demandSourceType,
          demandSourceReference: sourceTrace.demandSourceReference,
          whoNeedsIt: sourceTrace.whoNeedsIt,
          schoolStatus: sourceTrace.schoolStatus,
          deliveryLocationReference: sourceTrace.deliveryLocationReference,
          itemReference: requirementLine.itemReference,
          requiredQuantity: requirementLine.requiredQuantity,
          requiredUnit: requirementLine.requiredUnit,
          trace: {
            confirmedNeedLineReference: sourceTrace.confirmedNeedLineReference,
            purchaseHandoffLineReference:
              sourceTrace.purchaseHandoffLineReference,
            planningReleaseReference: requirement.planningReleaseReference,
            dispatchRequirementReference: requirement.dispatchRequirementId,
            dispatchRequirementLineReference:
              requirementLine.dispatchRequirementLineId,
          },
          fulfilmentAllocationReference:
            allocation?.fulfilmentAllocationId ?? "MISSING",
          fulfilment,
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
          deliveryEvidenceReferences:
            scenario.dispatchState.confirmations.flatMap((confirmation) =>
              confirmation.lines.some((line) =>
                loadLineIds.includes(line.dispatchLoadLineId),
              )
                ? confirmation.evidence.map(
                    (candidate) => candidate.evidenceReference,
                  )
                : [],
            ),
          returnEvidenceReferences: returns.map(
            (candidate) => candidate.evidenceReference,
          ),
          tripReference: trip?.dispatchTripId ?? "NOT_ASSIGNED",
          tripOutcome: trip?.status ?? "NOT_ASSIGNED",
          unresolved,
          blocksOperatingDay: unresolved.length > 0,
        } satisfies MvpVerticalSliceRow;
      });
    });
  });
  return { rows, attention };
}
