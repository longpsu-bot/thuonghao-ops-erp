import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../connection/atlasRpc";
import {
  PA06C_BLOCKER_SELECTOR,
  PA06C_READINESS_SELECTOR,
} from "./pa06cFixture";

export const PA06C_RPC_FUNCTIONS = {
  recordEvidence: "atlas_api.record_supplier_receiving_evidence",
  applyEvidence: "atlas_api.apply_supplier_evidence_to_allocation",
  getReadiness: "atlas_api.get_dispatch_evidence_readiness",
  getBlockers: "atlas_api.get_operator_blockers",
  getTimeline: "atlas_api.get_command_audit_timeline",
} as const satisfies Record<string, AtlasRpcName>;

export type Pa06cRpcName =
  (typeof PA06C_RPC_FUNCTIONS)[keyof typeof PA06C_RPC_FUNCTIONS];

export type EvidenceCommandRequest = AtlasRpcRequest & {
  contract_version: "PA-05B.v1";
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

type AtlasRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

function readRequest(
  authSubject: string,
  correlationId: string,
  payload: Record<string, JsonValue>,
): AtlasRpcRequest {
  return {
    contract_version: "PA-05C.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload,
  };
}

export function createSupplierEvidenceApi(invoker: AtlasRpcInvoker) {
  return {
    recordEvidence(request: EvidenceCommandRequest) {
      return invoker.invoke(PA06C_RPC_FUNCTIONS.recordEvidence, request);
    },
    applyEvidence(request: EvidenceCommandRequest) {
      return invoker.invoke(PA06C_RPC_FUNCTIONS.applyEvidence, request);
    },
    getReadiness(authSubject: string, correlationId: string) {
      return invoker.invoke(
        PA06C_RPC_FUNCTIONS.getReadiness,
        readRequest(authSubject, correlationId, PA06C_READINESS_SELECTOR),
      );
    },
    getBlockers(authSubject: string, correlationId: string) {
      return invoker.invoke(
        PA06C_RPC_FUNCTIONS.getBlockers,
        readRequest(authSubject, correlationId, PA06C_BLOCKER_SELECTOR),
      );
    },
    getTimeline(authSubject: string, correlationId: string, commandId: string) {
      return invoker.invoke(
        PA06C_RPC_FUNCTIONS.getTimeline,
        readRequest(authSubject, correlationId, { command_id: commandId }),
      );
    },
  };
}

export type SupplierEvidenceApi = ReturnType<typeof createSupplierEvidenceApi>;
