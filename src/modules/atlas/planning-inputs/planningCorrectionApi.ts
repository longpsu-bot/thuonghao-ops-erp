import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../connection/atlasRpc";

export const PLANNING_CORRECTION_RPC_FUNCTIONS = {
  impact: "atlas_api.get_planning_source_correction_impact",
  prepare: "atlas_api.prepare_planning_source_correction",
} as const satisfies Record<string, AtlasRpcName>;

export type PlanningCorrectionSourceKind =
  "WEEKLY_MENU" | "ATTENDANCE" | "PANTRY";

export type PlanningCorrectionChain = {
  need_generation_run_id: string;
  need_generation_run_version: number;
  run_status: string;
  period_start: string;
  period_end: string;
  is_legacy_range: boolean;
  confirmed_need_batch_id: string | null;
  confirmed_need_batch_version: number | null;
  confirmed_need_status: string | null;
  planning_release_occurred: boolean;
  active_purchase_handoff_exists: boolean;
  later_downstream_commitment_exists: boolean;
};

export type PlanningCorrectionDateImpact = {
  service_date: string;
  need_state: string;
  confirmed_need_state: string | null;
  planning_release_occurred: boolean;
  purchase_handoff_exists: boolean;
  later_downstream_commitment_exists: boolean;
  legacy_overlap_exists: boolean;
  correction_policy:
    | "SAFE_NOT_GENERATED"
    | "SAFE_REGENERATE"
    | "PLANNING_RELEASE_CORRECTION_REQUIRED"
    | "LEGACY_RANGE_CORRECTION_REQUIRED"
    | "BLOCKED_BY_PURCHASE_HANDOFF"
    | "BLOCKED_BY_DOWNSTREAM_COMMITMENT";
  safe_to_save: boolean;
  next_required_action: string;
  operator_message: string;
  chains: PlanningCorrectionChain[];
};

export type PlanningCorrectionImpact = {
  source_kind: PlanningCorrectionSourceKind;
  material_change: boolean;
  affected_service_dates: string[];
  date_impacts: PlanningCorrectionDateImpact[];
  save_allowed: boolean;
  save_blocker_code: string | null;
};

export function safeNoDownstreamImpact(
  sourceKind: PlanningCorrectionSourceKind,
): PlanningCorrectionImpact {
  return {
    source_kind: sourceKind,
    material_change: false,
    affected_service_dates: [],
    date_impacts: [],
    save_allowed: true,
    save_blocker_code: null,
  };
}

export type PlanningCorrectionInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

function isRecord(value: unknown): value is Record<string, JsonValue> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function planningCorrectionImpactFromResult(
  result: AtlasRpcResult,
): PlanningCorrectionImpact | null {
  if (result.kind !== "success" || !isRecord(result.response.impact))
    return null;
  const impact = result.response.impact;
  if (
    !Array.isArray(impact.affected_service_dates) ||
    !Array.isArray(impact.date_impacts) ||
    typeof impact.save_allowed !== "boolean"
  )
    return null;
  return impact as unknown as PlanningCorrectionImpact;
}

export function createPlanningCorrectionApi(
  invoker: PlanningCorrectionInvoker,
) {
  return {
    impact(
      authSubject: string,
      correlationId: string,
      sourceKind: PlanningCorrectionSourceKind,
      sourcePayload: Record<string, JsonValue>,
    ) {
      return invoker.invoke(PLANNING_CORRECTION_RPC_FUNCTIONS.impact, {
        contract_version: "PLANNING-CORRECTION.v1",
        requested_by_auth_subject: authSubject,
        correlation_id: correlationId,
        payload: {
          source_kind: sourceKind,
          source_payload: sourcePayload,
        },
      });
    },
    prepare(
      authSubject: string,
      correlationId: string,
      chain: PlanningCorrectionChain,
      reasonNote: string,
    ) {
      const commandId = crypto.randomUUID();
      return invoker.invoke(PLANNING_CORRECTION_RPC_FUNCTIONS.prepare, {
        contract_version: "PLANNING-CORRECTION.v1",
        command_id: commandId,
        correlation_id: correlationId,
        idempotency_key: `planning-correction:${commandId}`,
        expected_version: chain.need_generation_run_version,
        requested_by_auth_subject: authSubject,
        requested_at: new Date().toISOString(),
        reason_code: "PLANNING_SOURCE_CORRECTION_PREPARED",
        reason_note: reasonNote,
        payload: {
          need_generation_run_id: chain.need_generation_run_id,
          confirmed_need_batch_id: chain.confirmed_need_batch_id,
          expected_confirmed_need_batch_version:
            chain.confirmed_need_batch_version,
        },
      });
    },
  };
}

export type PlanningCorrectionApi = ReturnType<
  typeof createPlanningCorrectionApi
>;
