// Reviewed non-presentation Ingredient/Supplier master-data authority only.
import type { MasterDataApi } from "../../../modules/atlas/master-data/masterDataApi";

export type IngredientSupplierMasterDataApi = Pick<
  MasterDataApi,
  | "getIngredientsAndSuppliers"
  | "createIngredient"
  | "updateIngredient"
  | "setIngredientLifecycle"
  | "createSupplier"
  | "updateSupplier"
  | "replacePriorities"
>;

export type { MasterDataCommandRequest } from "../../../modules/atlas/master-data/masterDataApi";
export {
  commandRequest,
  responseArray,
  resultMessage,
  type IngredientMasterData,
  type IngredientOrderGroupMasterData,
  type IngredientTypeMasterData,
  type SupplierMasterData,
  type SupplierPriority,
  type UnitMasterData,
} from "../../../modules/atlas/master-data/masterDataModel";
export type { AtlasRpcResult } from "../../../modules/atlas/connection/atlasRpc";
