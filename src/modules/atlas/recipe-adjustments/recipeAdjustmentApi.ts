import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../connection/atlasRpc";

export const RECIPE_ADJUSTMENT_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_recipe_adjustment_workbench",
  getOperatorWorkbench: "atlas_api.get_recipe_adjustment_operator_workbench",
  resolve: "atlas_api.resolve_effective_recipe_composition",
  resolveSystem: "atlas_api.resolve_system_effective_recipe_composition",
  getEffectiveTargetContext: "atlas_api.get_recipe_effective_target_context",
  preview: "atlas_api.preview_recipe_composition_adjustment",
  create: "atlas_api.create_recipe_composition_adjustment",
  supersede: "atlas_api.supersede_recipe_composition_adjustment",
  cancel: "atlas_api.cancel_recipe_composition_adjustment",
} as const satisfies Record<string, AtlasRpcName>;

export type RecipeEffectiveContext =
  | { kind: "system"; schoolTypeId: string }
  | { kind: "school"; schoolId: string };

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

export function recipeAdjustmentOperatorReadRequest(
  authSubject: string,
  correlationId: string,
  asOfDate: string,
): AtlasRpcRequest {
  return {
    contract_version: "RMVP-02B.v2",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: { as_of_date: asOfDate },
  };
}

export function systemEffectiveRecipeRequest(
  authSubject: string,
  correlationId: string,
  asOfDate: string,
  dishId: string,
  schoolTypeId: string,
): AtlasRpcRequest {
  return {
    contract_version: "RECIPE-EFFECTIVE.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {
      as_of_date: asOfDate,
      dish_id: dishId,
      school_type_id: schoolTypeId,
    },
  };
}

export function recipeEffectiveTargetContextRequest(
  authSubject: string,
  correlationId: string,
  asOfDate: string,
  dishId: string,
  context: RecipeEffectiveContext,
): AtlasRpcRequest {
  return {
    contract_version: "RECIPE-EFFECTIVE.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {
      as_of_date: asOfDate,
      dish_id: dishId,
      ...(context.kind === "system"
        ? { school_type_id: context.schoolTypeId }
        : { school_id: context.schoolId }),
    },
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
    getOperatorWorkbench(
      authSubject: string,
      correlationId: string,
      asOfDate: string,
    ) {
      return invoker.invoke(
        RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getOperatorWorkbench,
        recipeAdjustmentOperatorReadRequest(
          authSubject,
          correlationId,
          asOfDate,
        ),
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
    resolveSystem(
      authSubject: string,
      correlationId: string,
      asOfDate: string,
      dishId: string,
      schoolTypeId: string,
    ) {
      return invoker.invoke(
        RECIPE_ADJUSTMENT_RPC_FUNCTIONS.resolveSystem,
        systemEffectiveRecipeRequest(
          authSubject,
          correlationId,
          asOfDate,
          dishId,
          schoolTypeId,
        ),
      );
    },
    getEffectiveTargetContext(
      authSubject: string,
      correlationId: string,
      asOfDate: string,
      dishId: string,
      context: RecipeEffectiveContext,
    ) {
      return invoker.invoke(
        RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getEffectiveTargetContext,
        recipeEffectiveTargetContextRequest(
          authSubject,
          correlationId,
          asOfDate,
          dishId,
          context,
        ),
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
