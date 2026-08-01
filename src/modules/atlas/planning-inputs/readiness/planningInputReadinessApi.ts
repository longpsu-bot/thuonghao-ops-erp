import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../../connection/atlasRpc";

export const PLANNING_INPUT_READINESS_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_planning_input_readiness_workbench",
  evaluate: "atlas_api.evaluate_planning_input_readiness",
  requestNeedGeneration: "atlas_api.request_planning_input_need_generation",
  invalidate: "atlas_api.invalidate_planning_input_readiness",
} as const satisfies Record<string, AtlasRpcName>;

export type ReadinessRootStatus =
  | "ABSENT"
  | "NOT_READY"
  | "READY"
  | "NEED_GENERATION_REQUESTED"
  | "INVALIDATED";

export type ReadinessCommandExpectation = {
  expectedRootStatus: ReadinessRootStatus;
  expectedCurrentEvaluationId: string | null;
  expectedCurrentEvaluationVersion: number | null;
};

export type PlanningInputReadinessCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-03B.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  requested_by_auth_subject: string;
  requested_at: string;
  expected_root_status: ReadinessRootStatus;
  expected_current_evaluation_id: string | null;
  expected_current_evaluation_version: number | null;
  reason_code: string;
  reason_note: string | null;
  payload: Record<string, JsonValue>;
};

export type PlanningInputReadinessRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function planningInputReadinessReadRequest(
  authSubject: string,
  correlationId: string,
  periodStart: string,
  periodEnd: string,
  sourceSelection?: Record<string, JsonValue>,
  historyLimit = 25,
  historyCursor: string | null = null,
): AtlasRpcRequest {
  return {
    contract_version: "RMVP-03B.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {
      period_start: periodStart,
      period_end: periodEnd,
      ...(sourceSelection ? { source_selection: sourceSelection } : {}),
      history_limit: historyLimit,
      history_cursor: historyCursor,
    },
  };
}

export function planningInputReadinessCommandRequest(
  authSubject: string,
  correlationId: string,
  expectation: ReadinessCommandExpectation,
  reasonCode: string,
  reasonNote: string | null,
  payload: Record<string, JsonValue>,
): PlanningInputReadinessCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-03B.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    expected_root_status: expectation.expectedRootStatus,
    expected_current_evaluation_id: expectation.expectedCurrentEvaluationId,
    expected_current_evaluation_version:
      expectation.expectedCurrentEvaluationVersion,
    reason_code: reasonCode,
    reason_note: reasonNote,
    payload,
  };
}

export function createPlanningInputReadinessApi(
  invoker: PlanningInputReadinessRpcInvoker,
) {
  return {
    getWorkbench(
      authSubject: string,
      correlationId: string,
      periodStart: string,
      periodEnd: string,
      sourceSelection?: Record<string, JsonValue>,
      historyLimit = 25,
      historyCursor: string | null = null,
    ) {
      return invoker.invoke(
        PLANNING_INPUT_READINESS_RPC_FUNCTIONS.getWorkbench,
        planningInputReadinessReadRequest(
          authSubject,
          correlationId,
          periodStart,
          periodEnd,
          sourceSelection,
          historyLimit,
          historyCursor,
        ),
      );
    },
    evaluate(request: PlanningInputReadinessCommandRequest) {
      return invoker.invoke(
        PLANNING_INPUT_READINESS_RPC_FUNCTIONS.evaluate,
        request,
      );
    },
    requestNeedGeneration(request: PlanningInputReadinessCommandRequest) {
      return invoker.invoke(
        PLANNING_INPUT_READINESS_RPC_FUNCTIONS.requestNeedGeneration,
        request,
      );
    },
    invalidate(request: PlanningInputReadinessCommandRequest) {
      return invoker.invoke(
        PLANNING_INPUT_READINESS_RPC_FUNCTIONS.invalidate,
        request,
      );
    },
  };
}

export type PlanningInputReadinessApi = ReturnType<
  typeof createPlanningInputReadinessApi
>;
