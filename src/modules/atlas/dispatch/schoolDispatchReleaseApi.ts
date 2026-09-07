import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
} from "../connection/atlasRpc";
import type { SchoolDispatchWorkbenchData } from "./schoolDispatchReleaseModel";

export const SCHOOL_DISPATCH_RELEASE_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_school_dispatch_release_workbench",
  releaseDocument: "atlas_api.release_school_dispatch_document",
} as const satisfies Record<string, AtlasRpcName>;

export type SchoolDispatchReleaseScope = {
  date_start: string;
  date_end: string;
  school_ids: string[];
  search: string | null;
};

export type SchoolDispatchReleasePayload = {
  service_date: string;
  school_id: string;
  delivery_location_id: string;
  expected_source_fingerprint: string;
  predecessor_release_id: string | null;
};

export type ReleaseSchoolDispatchDocumentRequest = AtlasRpcRequest & {
  contract_version: "SCHOOL-DISPATCH-RELEASE.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "SCHOOL_DISPATCH_DOCUMENT_RELEASED";
  reason_note: string | null;
  payload: SchoolDispatchReleasePayload;
};

export type SchoolDispatchReleaseRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function schoolDispatchReleaseReadRequest(
  authSubject: string,
  correlationId: string,
  scope: SchoolDispatchReleaseScope,
): AtlasRpcRequest {
  return {
    contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: scope,
  };
}

export function releaseSchoolDispatchDocumentRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  payload: SchoolDispatchReleasePayload,
  reasonNote: string | null = null,
): ReleaseSchoolDispatchDocumentRequest {
  const commandId = crypto.randomUUID();
  const normalizedReasonNote = reasonNote?.trim() || null;
  return {
    contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `school-dispatch-release:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "SCHOOL_DISPATCH_DOCUMENT_RELEASED",
    reason_note: normalizedReasonNote,
    payload,
  };
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function schoolDispatchWorkbenchFromResult(
  result: AtlasRpcResult,
): SchoolDispatchWorkbenchData | null {
  return result.kind === "success"
    ? (record(result.response) as SchoolDispatchWorkbenchData | null)
    : null;
}

export function createSchoolDispatchReleaseApi(
  invoker: SchoolDispatchReleaseRpcInvoker,
) {
  return {
    getWorkbench(request: AtlasRpcRequest) {
      return invoker.invoke(
        SCHOOL_DISPATCH_RELEASE_RPC_FUNCTIONS.getWorkbench,
        request,
      );
    },
    releaseDocument(request: ReleaseSchoolDispatchDocumentRequest) {
      return invoker.invoke(
        SCHOOL_DISPATCH_RELEASE_RPC_FUNCTIONS.releaseDocument,
        request,
      );
    },
  };
}

export type SchoolDispatchReleaseApi = ReturnType<
  typeof createSchoolDispatchReleaseApi
>;
