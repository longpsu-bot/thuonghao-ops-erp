import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../connection/atlasRpc";

export const RECIPE_ADJUSTMENT_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_recipe_adjustment_workbench",
  resolve: "atlas_api.resolve_effective_recipe_composition",
  preview: "atlas_api.preview_recipe_composition_adjustment",
  create: "atlas_api.create_recipe_composition_adjustment",
  supersede: "atlas_api.supersede_recipe_composition_adjustment",
  cancel: "atlas_api.cancel_recipe_composition_adjustment",
} as const satisfies Record<string, AtlasRpcName>;

export type RecipeAdjustmentCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-02B.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: string;
  reason_note: string;
  payload: Record<string, JsonValue>;
};

export type RecipeAdjustmentRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function recipeAdjustmentReadRequest(
  authSubject: string,
  correlationId: string,
  payload: Record<string, JsonValue> = {},
): AtlasRpcRequest {
  return {
    contract_version: "RMVP-02B.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload,
  };
}

export function recipeAdjustmentCommandRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  reasonCode: string,
  reasonNote: string,
  payload: Record<string, JsonValue>,
): RecipeAdjustmentCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-02B.v1",
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

export function createRecipeAdjustmentApi(invoker: RecipeAdjustmentRpcInvoker) {
  return {
    getWorkbench(authSubject: string, correlationId: string) {
      return invoker.invoke(
        RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getWorkbench,
        recipeAdjustmentReadRequest(authSubject, correlationId),
      );
    },
    resolve(
      authSubject: string,
      correlationId: string,
      payload: Record<string, JsonValue>,
    ) {
      return invoker.invoke(
        RECIPE_ADJUSTMENT_RPC_FUNCTIONS.resolve,
        recipeAdjustmentReadRequest(authSubject, correlationId, payload),
      );
    },
    preview(
      authSubject: string,
      correlationId: string,
      payload: Record<string, JsonValue>,
    ) {
      return invoker.invoke(
        RECIPE_ADJUSTMENT_RPC_FUNCTIONS.preview,
        recipeAdjustmentReadRequest(authSubject, correlationId, payload),
      );
    },
    create(request: RecipeAdjustmentCommandRequest) {
      return invoker.invoke(RECIPE_ADJUSTMENT_RPC_FUNCTIONS.create, request);
    },
    supersede(request: RecipeAdjustmentCommandRequest) {
      return invoker.invoke(RECIPE_ADJUSTMENT_RPC_FUNCTIONS.supersede, request);
    },
    cancel(request: RecipeAdjustmentCommandRequest) {
      return invoker.invoke(RECIPE_ADJUSTMENT_RPC_FUNCTIONS.cancel, request);
    },
  };
}

export type RecipeAdjustmentApi = ReturnType<typeof createRecipeAdjustmentApi>;
