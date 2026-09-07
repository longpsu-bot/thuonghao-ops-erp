import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
} from "../connection/atlasRpc";
import type { SchoolFulfilmentWorkbenchData } from "./schoolFulfilmentReconciliationModel";

export const SCHOOL_FULFILMENT_RECONCILIATION_RPC =
  "atlas_api.get_school_fulfilment_reconciliation_workbench" as const satisfies AtlasRpcName;

export type SchoolFulfilmentScope = {
  date_start: string;
  date_end: string;
  school_ids: string[];
  search: string | null;
};

export function schoolFulfilmentReadRequest(
  authSubject: string,
  correlationId: string,
  scope: SchoolFulfilmentScope,
): AtlasRpcRequest {
  return {
    contract_version: "SCHOOL-FULFILMENT-RECONCILIATION.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: scope,
  };
}

export function schoolFulfilmentWorkbenchFromResult(
  result: AtlasRpcResult,
): SchoolFulfilmentWorkbenchData | null {
  return result.kind === "success"
    ? (result.response as unknown as SchoolFulfilmentWorkbenchData)
    : null;
}

export function createSchoolFulfilmentReconciliationApi(invoker: {
  invoke(name: AtlasRpcName, request: AtlasRpcRequest): Promise<AtlasRpcResult>;
}) {
  return {
    getWorkbench(request: AtlasRpcRequest) {
      return invoker.invoke(SCHOOL_FULFILMENT_RECONCILIATION_RPC, request);
    },
  };
}

export type SchoolFulfilmentReconciliationApi = ReturnType<
  typeof createSchoolFulfilmentReconciliationApi
>;
