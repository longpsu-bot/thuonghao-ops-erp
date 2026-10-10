// Reviewed non-presentation School master-data authority only.
import type { MasterDataApi } from "../../../modules/atlas/master-data/masterDataApi";

export type SchoolMasterDataApi = Pick<
  MasterDataApi,
  "getSchools" | "updateSchoolDefaultsBulk"
> &
  Partial<
    Pick<
      MasterDataApi,
      | "getCookingGroups"
      | "upsertCookingGroup"
      | "setSchoolCookingGroup"
      | "getDispatchGroups"
      | "upsertDispatchGroup"
      | "setSchoolDispatchGroup"
    >
  >;

export type {
  MasterDataCommandRequest,
  MasterDataBulkCommandRequest,
  SchoolDefaultsBulkChange,
} from "../../../modules/atlas/master-data/masterDataApi";
export {
  commandRequest,
  type CookingGroupMasterData,
  type DispatchGroupMasterData,
  responseArray,
  resultMessage,
  schoolDefaultsBulkCommandRequest,
  type SchoolMasterData,
} from "../../../modules/atlas/master-data/masterDataModel";
export type { AtlasRpcResult } from "../../../modules/atlas/connection/atlasRpc";
