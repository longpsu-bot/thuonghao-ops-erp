import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../connection/atlasRpc";

export const MASTER_DATA_RPC_FUNCTIONS = {
  getSchools: "atlas_api.get_school_master_data",
  getIngredientsAndSuppliers: "atlas_api.get_ingredient_supplier_master_data",
  updateSchoolDefaults: "atlas_api.update_school_portion_defaults",
  updateSchoolDefaultsBulk: "atlas_api.update_school_portion_defaults_bulk",
  createIngredient: "atlas_api.create_ingredient",
  updateIngredient: "atlas_api.update_ingredient",
  setIngredientLifecycle: "atlas_api.set_ingredient_lifecycle",
  createSupplier: "atlas_api.create_supplier",
  updateSupplier: "atlas_api.update_supplier",
  replacePriorities: "atlas_api.replace_ingredient_supplier_priorities",
} as const satisfies Record<string, AtlasRpcName>;

export type MasterDataCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-01.v1";
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

export type SchoolDefaultsBulkChange = {
  school_id: string;
  expected_version: number;
  default_student_portions: number;
  default_teacher_portions: number;
};

export type MasterDataBulkCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-01.v2";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: string;
  reason_note: string | null;
  payload: { changes: SchoolDefaultsBulkChange[] };
};

type AtlasRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

function readRequest(authSubject: string, correlationId: string) {
  return {
    contract_version: "RMVP-01.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {},
  } satisfies AtlasRpcRequest;
}

export function createMasterDataApi(invoker: AtlasRpcInvoker) {
  return {
    getSchools(authSubject: string, correlationId: string) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.getSchools,
        readRequest(authSubject, correlationId),
      );
    },
    getIngredientsAndSuppliers(authSubject: string, correlationId: string) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.getIngredientsAndSuppliers,
        readRequest(authSubject, correlationId),
      );
    },
    updateSchoolDefaults(request: MasterDataCommandRequest) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.updateSchoolDefaults,
        request,
      );
    },
    updateSchoolDefaultsBulk(request: MasterDataBulkCommandRequest) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.updateSchoolDefaultsBulk,
        request,
      );
    },
    createIngredient(request: MasterDataCommandRequest) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.createIngredient,
        request,
      );
    },
    updateIngredient(request: MasterDataCommandRequest) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.updateIngredient,
        request,
      );
    },
    setIngredientLifecycle(request: MasterDataCommandRequest) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.setIngredientLifecycle,
        request,
      );
    },
    createSupplier(request: MasterDataCommandRequest) {
      return invoker.invoke(MASTER_DATA_RPC_FUNCTIONS.createSupplier, request);
    },
    updateSupplier(request: MasterDataCommandRequest) {
      return invoker.invoke(MASTER_DATA_RPC_FUNCTIONS.updateSupplier, request);
    },
    replacePriorities(request: MasterDataCommandRequest) {
      return invoker.invoke(
        MASTER_DATA_RPC_FUNCTIONS.replacePriorities,
        request,
      );
    },
  };
}

export type MasterDataApi = ReturnType<typeof createMasterDataApi>;
