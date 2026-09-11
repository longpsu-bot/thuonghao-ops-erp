// Reviewed non-presentation contracts only. No legacy lifecycle commands escape.
import type { createPlanningInputReadinessApi } from "../../../modules/atlas/planning-inputs/readiness/planningInputReadinessApi";
import type { NeedGenerationApi as GenerationApi } from "../../../modules/atlas/planning-inputs/need-generation/needGenerationApi";
import type { ConfirmedNeedApi as ConfirmationApi } from "../../../modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi";
export type PreflightApi = Pick<
  ReturnType<typeof createPlanningInputReadinessApi>,
  "preflight"
>;
export type NeedGenerationApi = Pick<GenerationApi, "execute" | "getWorkbench">;
export type ConfirmedNeedApi = Pick<ConfirmationApi, "getReview" | "save">;
export { needGenerationExecutionRequest } from "../../../modules/atlas/planning-inputs/need-generation/needGenerationApi";
export type {
  NeedGenerationFilters,
  NeedGenerationDetailGroup,
} from "../../../modules/atlas/planning-inputs/need-generation/needGenerationApi";
export { confirmedNeedSaveV2Request } from "../../../modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi";
export type { ConfirmedNeedLineRequest } from "../../../modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi";
export { planningInputPreflightFromResult } from "../../../modules/atlas/planning-inputs/readiness/planningInputReadinessModel";
export type { PlanningInputPreflightData } from "../../../modules/atlas/planning-inputs/readiness/planningInputReadinessModel";
export {
  needGenerationWorkbenchFromResult,
  needGenerationReadbackFromResult,
  needGenerationContinuitySummaryFromResult,
  needGenerationResultIsStale,
  needGenerationResultMessage,
  formatQuantity,
} from "../../../modules/atlas/planning-inputs/need-generation/needGenerationModel";
export type {
  NeedGenerationWorkbenchData,
  NeedGenerationGroup,
} from "../../../modules/atlas/planning-inputs/need-generation/needGenerationModel";
export {
  initialConfirmedNeedDraft,
  exactDecimalEqual,
  normalizeConfirmedNeedQuantity,
  normalizeConfirmedNeedEntry,
  confirmedNeedInputDisplay,
  subtractExactDecimals,
  confirmedNeedWorkbenchFromResult,
  confirmedNeedReadbackFromResult,
  confirmedNeedResultIsStale,
  confirmedNeedResultHasUnknownWriteOutcome,
  confirmedNeedResultRequiresEligibilityRefresh,
  confirmedNeedResultMessage,
  exactQuantityDisplay,
  confirmedNeedConfirmationStateLabel,
  confirmedNeedReasonLabels,
} from "../../../modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel";
export type {
  ConfirmedNeedDraftLine,
  ConfirmedNeedLine,
  ConfirmedNeedWorkbenchData,
} from "../../../modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel";
export type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../../../modules/atlas/connection/atlasRpc";
