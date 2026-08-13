import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../connection/atlasRpc";

export const RECIPE_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_dish_recipe_workbench",
  createDish: "atlas_api.create_dish",
  updateDish: "atlas_api.update_dish",
  setDishLifecycle: "atlas_api.set_dish_lifecycle",
  setRecipeLifecycle: "atlas_api.set_recipe_lifecycle",
  createDraft: "atlas_api.create_recipe_draft",
  createSuccessor: "atlas_api.create_recipe_successor_version",
  replaceComposition: "atlas_api.replace_recipe_draft_composition",
  validateVersion: "atlas_api.validate_recipe_version",
  releaseVersion: "atlas_api.release_recipe_version_for_planning",
  saveRecipe: "atlas_api.save_recipe",
  releaseRecipe: "atlas_api.release_recipe",
  copyVersion: "atlas_api.copy_recipe_version",
  applyImport: "atlas_api.apply_recipe_import",
} as const satisfies Record<string, AtlasRpcName>;

export type RecipeCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-02A.v1";
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

export type RecipeWorkflowCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-02A.v2";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "RECIPE_SAVED" | "RECIPE_PUT_INTO_USE";
  reason_note: null;
  payload: Record<string, JsonValue>;
};

export type AtlasRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function recipeReadRequest(
  authSubject: string,
  correlationId: string,
  selection?: { dishId: string; schoolTypeId: string | null },
): AtlasRpcRequest {
  return {
    contract_version: "RMVP-02A.v2",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: selection
      ? {
          dish_id: selection.dishId,
          school_type_id: selection.schoolTypeId,
        }
      : {},
  };
}

export function recipeCommandRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  reasonCode: string,
  payload: Record<string, JsonValue>,
  reasonNote = "Cập nhật từ khu vực Công thức Atlas.",
): RecipeCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-02A.v1",
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

export function recipeWorkflowCommandRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  action: "save" | "release",
  payload: Record<string, JsonValue>,
): RecipeWorkflowCommandRequest {
  const commandId = crypto.randomUUID();
  const reasonCode = action === "save" ? "RECIPE_SAVED" : "RECIPE_PUT_INTO_USE";
  return {
    contract_version: "RMVP-02A.v2",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: reasonCode,
    reason_note: null,
    payload,
  };
}

export function createRecipeApi(invoker: AtlasRpcInvoker) {
  const command =
    (
      name: Exclude<
        keyof typeof RECIPE_RPC_FUNCTIONS,
        "getWorkbench" | "saveRecipe" | "releaseRecipe"
      >,
    ) =>
    (request: RecipeCommandRequest) =>
      invoker.invoke(RECIPE_RPC_FUNCTIONS[name], request);
  const workflowCommand =
    (name: "saveRecipe" | "releaseRecipe") =>
    (request: RecipeWorkflowCommandRequest) =>
      invoker.invoke(RECIPE_RPC_FUNCTIONS[name], request);
  return {
    getWorkbench(
      authSubject: string,
      correlationId: string,
      selection?: { dishId: string; schoolTypeId: string | null },
    ) {
      return invoker.invoke(
        RECIPE_RPC_FUNCTIONS.getWorkbench,
        recipeReadRequest(authSubject, correlationId, selection),
      );
    },
    createDish: command("createDish"),
    updateDish: command("updateDish"),
    setDishLifecycle: command("setDishLifecycle"),
    setRecipeLifecycle: command("setRecipeLifecycle"),
    createDraft: command("createDraft"),
    createSuccessor: command("createSuccessor"),
    replaceComposition: command("replaceComposition"),
    validateVersion: command("validateVersion"),
    releaseVersion: command("releaseVersion"),
    saveRecipe: workflowCommand("saveRecipe"),
    releaseRecipe: workflowCommand("releaseRecipe"),
    copyVersion: command("copyVersion"),
    applyImport: command("applyImport"),
  };
}

export type RecipeApi = ReturnType<typeof createRecipeApi>;
