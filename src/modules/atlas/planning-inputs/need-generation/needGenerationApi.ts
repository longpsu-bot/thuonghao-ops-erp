import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../../connection/atlasRpc";

export const NEED_GENERATION_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_need_generation_workbench",
  execute: "atlas_api.execute_need_generation",
  create: "atlas_api.create_need_generation_run",
  validate: "atlas_api.validate_need_generation_run",
  release: "atlas_api.release_need_generation_run",
  invalidate: "atlas_api.invalidate_need_generation_run",
  materialize: "atlas_api.create_confirmed_needs_from_generation",
} as const satisfies Record<string, AtlasRpcName>;

export type NeedGenerationFilters = {
  service_date: string | null;
  school_id: string | null;
  ingredient_id: string | null;
  contribution_family: "RECIPE_DERIVED" | "PANTRY_DIRECT" | null;
};

export type NeedGenerationDetailGroup = {
  service_date: string;
  school_id: string;
  delivery_location_id: string;
  ingredient_id: string;
  unit_id: string;
};

export type NeedGenerationCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-04.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: string;
  reason_note: string | null;
  payload: Record<string, JsonValue>;
};

export type NeedGenerationExecutionRequest = AtlasRpcRequest & {
  contract_version: "RMVP-04.v2";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "NEED_GENERATION_EXECUTED";
  reason_note: string | null;
  payload: {
    period_start: string;
    period_end: string;
    expected_current_need_generation_run_id: string | null;
  };
};

export type ConfirmedNeedMaterializationRequest = AtlasRpcRequest & {
  contract_version: "PA-06E-H0C.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "MATERIALIZE_CONFIRMED_NEED";
  reason_note: null;
  payload: {
    need_generation_run_id: string;
    need_generation_run_version: number;
    confirmed_need_batch_id: string | null;
  };
};

export type NeedGenerationRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function needGenerationReadRequest(
  authSubject: string,
  correlationId: string,
  periodStart: string,
  periodEnd: string,
  runId: string | null,
  filters: NeedGenerationFilters,
  groupOffset: number,
  groupLimit: number,
  detailGroup: NeedGenerationDetailGroup | null,
): AtlasRpcRequest {
  return {
    contract_version: "RMVP-04.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {
      period_start: periodStart,
      period_end: periodEnd,
      need_generation_run_id: runId,
      filters,
      group_offset: groupOffset,
      group_limit: groupLimit,
      ...(detailGroup ? { detail_group: detailGroup } : {}),
    },
  };
}

export function needGenerationCommandRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  reasonCode: string,
  reasonNote: string | null,
  payload: Record<string, JsonValue>,
): NeedGenerationCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-04.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: reasonCode,
    reason_note: reasonNote,
    payload,
  };
}

export function needGenerationExecutionRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  periodStart: string,
  periodEnd: string,
  expectedCurrentRunId: string | null,
  reasonNote:
    string | null = "Tạo hoặc cập nhật nhu cầu từ dữ liệu nguồn hiện tại.",
): NeedGenerationExecutionRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-04.v2",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `need_generation_executed:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "NEED_GENERATION_EXECUTED",
    reason_note: reasonNote,
    payload: {
      period_start: periodStart,
      period_end: periodEnd,
      expected_current_need_generation_run_id: expectedCurrentRunId,
    },
  };
}

export function confirmedNeedMaterializationRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  runId: string,
  runVersion: number,
  confirmedNeedBatchId: string | null,
): ConfirmedNeedMaterializationRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "PA-06E-H0C.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `materialize-confirmed-need:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "MATERIALIZE_CONFIRMED_NEED",
    reason_note: null,
    payload: {
      need_generation_run_id: runId,
      need_generation_run_version: runVersion,
      confirmed_need_batch_id: confirmedNeedBatchId,
    },
  };
}

export function createNeedGenerationApi(invoker: NeedGenerationRpcInvoker) {
  return {
    execute(request: NeedGenerationExecutionRequest) {
      return invoker.invoke(NEED_GENERATION_RPC_FUNCTIONS.execute, request);
    },
    getWorkbench(
      authSubject: string,
      correlationId: string,
      periodStart: string,
      periodEnd: string,
      runId: string | null,
      filters: NeedGenerationFilters,
      groupOffset: number,
      groupLimit: number,
      detailGroup: NeedGenerationDetailGroup | null,
    ) {
      return invoker.invoke(
        NEED_GENERATION_RPC_FUNCTIONS.getWorkbench,
        needGenerationReadRequest(
          authSubject,
          correlationId,
          periodStart,
          periodEnd,
          runId,
          filters,
          groupOffset,
          groupLimit,
          detailGroup,
        ),
      );
    },
    create(request: NeedGenerationCommandRequest) {
      return invoker.invoke(NEED_GENERATION_RPC_FUNCTIONS.create, request);
    },
    validate(request: NeedGenerationCommandRequest) {
      return invoker.invoke(NEED_GENERATION_RPC_FUNCTIONS.validate, request);
    },
    release(request: NeedGenerationCommandRequest) {
      return invoker.invoke(NEED_GENERATION_RPC_FUNCTIONS.release, request);
    },
    invalidate(request: NeedGenerationCommandRequest) {
      return invoker.invoke(NEED_GENERATION_RPC_FUNCTIONS.invalidate, request);
    },
    materialize(request: ConfirmedNeedMaterializationRequest) {
      return invoker.invoke(NEED_GENERATION_RPC_FUNCTIONS.materialize, request);
    },
  };
}

export type NeedGenerationApi = ReturnType<typeof createNeedGenerationApi>;
