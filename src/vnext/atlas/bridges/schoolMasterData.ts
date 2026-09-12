// Reviewed non-presentation School master-data authority only.
import type { MasterDataApi } from "../../../modules/atlas/master-data/masterDataApi";

export type SchoolMasterDataApi = Pick<
  MasterDataApi,
  "getSchools" | "updateSchoolDefaultsBulk"
>;

export type {
  MasterDataBulkCommandRequest,
  SchoolDefaultsBulkChange,
} from "../../../modules/atlas/master-data/masterDataApi";
export {
  responseArray,
  resultMessage,
  schoolDefaultsBulkCommandRequest,
  type SchoolMasterData,
} from "../../../modules/atlas/master-data/masterDataModel";
export type { AtlasRpcResult } from "../../../modules/atlas/connection/atlasRpc";
