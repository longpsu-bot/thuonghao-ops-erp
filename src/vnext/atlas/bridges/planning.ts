// Reviewed business-only dependencies: APIs, canonical parsing, models and scope.
export {
  attendanceCompletionRequest,
  weeklyMenuCompletionRequest,
} from "../../../modules/atlas/planning-inputs/planningInputsApi";
export type { PlanningInputsApi } from "../../../modules/atlas/planning-inputs/planningInputsApi";
export * from "../../../modules/atlas/planning-inputs/planningInputsModel";
export {
  parseMenuMatrix,
  parseAttendancePaste,
} from "../../../modules/atlas/planning-inputs/planningInputsWorkbook";
export type { SourceMatrix } from "../../../modules/atlas/planning-inputs/planningInputsWorkbook";
export {
  planningCorrectionImpactFromResult,
  safeNoDownstreamImpact,
} from "../../../modules/atlas/planning-inputs/planningCorrectionApi";
export type {
  PlanningCorrectionImpact,
  PlanningCorrectionChain,
  PlanningCorrectionSourceKind,
} from "../../../modules/atlas/planning-inputs/planningCorrectionApi";
export {
  normalizePlanningSchoolScope,
  schoolInPlanningScope,
} from "../../../modules/atlas/planning-inputs/planningSchoolScope";
export { pantryCompletionRequest } from "../../../modules/atlas/planning-inputs/pantry/pantryApi";
export type { PantryApi } from "../../../modules/atlas/planning-inputs/pantry/pantryApi";
export * from "../../../modules/atlas/planning-inputs/pantry/pantryModel";
export type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../../../modules/atlas/connection/atlasRpc";
