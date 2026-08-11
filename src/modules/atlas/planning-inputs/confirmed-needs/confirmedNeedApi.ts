import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
} from "../../connection/atlasRpc";
import type { ConfirmedNeedDraftLine } from "./confirmedNeedModel";

export const CONFIRMED_NEED_RPC_FUNCTIONS = {
  getReview: "atlas_api.get_confirmed_need_review",
  preview: "atlas_api.preview_confirmed_need_confirmation",
  confirm: "atlas_api.confirm_need_quantities",
  validate: "atlas_api.validate_confirmed_needs",
  approve: "atlas_api.approve_confirmed_needs",
  release: "atlas_api.release_confirmed_needs_for_purchase_handoff",
  saveV2: "atlas_api.save_confirmed_needs",
  releaseV2: "atlas_api.release_confirmed_needs",
} as const satisfies Record<string, AtlasRpcName>;

export type ConfirmedNeedFilters = {
  service_date: string | null;
  school_id: string | null;
  delivery_location_id: string | null;
  ingredient_id: string | null;
  decision_state: "UNREVIEWED" | "CONFIRMED" | null;
};

export type ConfirmedNeedLineRequest = {
  confirmed_need_line_id: string;
  expected_current_revision_id: string;
  expected_current_decision_id: string | null;
  proposed_confirmed_quantity: string;
  reason_code: ConfirmedNeedDraftLine["reason_code"];
  reason_note: string | null;
};

export type ConfirmedNeedPreviewRequest = AtlasRpcRequest & {
  contract_version: "RMVP-05.v1";
  requested_by_auth_subject: string;
  correlation_id: string;
  payload: {
    confirmed_need_batch_id: string;
    expected_batch_version: number;
    lines: ConfirmedNeedLineRequest[];
  };
};

export type ConfirmedNeedCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-05.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "CONFIRMED_NEED_QUANTITIES_CONFIRMED";
  reason_note: null;
  payload: {
    confirmed_need_batch_id: string;
    preview_hash: string;
    lines: ConfirmedNeedLineRequest[];
  };
};

export type ConfirmedNeedValidationRequest = AtlasRpcRequest & {
  contract_version: "RMVP-06.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "BATCH_VALIDATION_REQUESTED";
  reason_note: string | null;
  payload: { confirmed_need_batch_id: string };
};

export type ConfirmedNeedApprovalRequest = AtlasRpcRequest & {
  contract_version: "RMVP-07.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "CONFIRMED_NEED_APPROVAL_REQUESTED";
  reason_note: string | null;
  payload: { confirmed_need_batch_id: string };
};

export type ConfirmedNeedReleaseRequest = AtlasRpcRequest & {
  contract_version: "RMVP-07.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "CONFIRMED_NEED_RELEASE_REQUESTED";
  reason_note: string | null;
  payload: { confirmed_need_batch_id: string };
};

export type ConfirmedNeedSaveV2Request = AtlasRpcRequest & {
  contract_version: "RMVP-05.v2";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "CONFIRMED_NEED_SAVED";
  reason_note: null;
  payload: {
    confirmed_need_batch_id: string;
    lines: ConfirmedNeedLineRequest[];
  };
};

export type ConfirmedNeedReleaseV2Request = AtlasRpcRequest & {
  contract_version: "RMVP-07.v2";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "CONFIRMED_NEED_RELEASED";
  reason_note: null;
  payload: { confirmed_need_batch_id: string };
};

export type ConfirmedNeedRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function confirmedNeedReadRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  filters: ConfirmedNeedFilters,
  lineOffset = 0,
  lineLimit = 100,
): AtlasRpcRequest {
  return {
    contract_version: "RMVP-05.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {
      confirmed_need_batch_id: batchId,
      filters,
      line_offset: lineOffset,
      line_limit: lineLimit,
    },
  };
}

export function confirmedNeedPreviewRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
  lines: ConfirmedNeedLineRequest[],
): ConfirmedNeedPreviewRequest {
  return {
    contract_version: "RMVP-05.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {
      confirmed_need_batch_id: batchId,
      expected_batch_version: expectedVersion,
      lines,
    },
  };
}

export function confirmedNeedCommandRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
  previewHash: string,
  lines: ConfirmedNeedLineRequest[],
): ConfirmedNeedCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-05.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `confirmed-need-quantities:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "CONFIRMED_NEED_QUANTITIES_CONFIRMED",
    reason_note: null,
    payload: {
      confirmed_need_batch_id: batchId,
      preview_hash: previewHash,
      lines,
    },
  };
}

export function confirmedNeedValidationRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
  reasonNote: string | null = null,
): ConfirmedNeedValidationRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-06.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `confirmed-need-validation:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "BATCH_VALIDATION_REQUESTED",
    reason_note: reasonNote?.trim() || null,
    payload: { confirmed_need_batch_id: batchId },
  };
}

function confirmedNeedLifecycleRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
  kind: "approval" | "release",
  reasonNote: string | null,
): ConfirmedNeedApprovalRequest | ConfirmedNeedReleaseRequest {
  const commandId = crypto.randomUUID();
  const base = {
    contract_version: "RMVP-07.v1" as const,
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `confirmed-need-${kind}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_note: reasonNote?.trim() || null,
    payload: { confirmed_need_batch_id: batchId },
  };
  return kind === "approval"
    ? { ...base, reason_code: "CONFIRMED_NEED_APPROVAL_REQUESTED" }
    : { ...base, reason_code: "CONFIRMED_NEED_RELEASE_REQUESTED" };
}

export function confirmedNeedApprovalRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
  reasonNote: string | null = null,
): ConfirmedNeedApprovalRequest {
  return confirmedNeedLifecycleRequest(
    authSubject,
    correlationId,
    batchId,
    expectedVersion,
    "approval",
    reasonNote,
  ) as ConfirmedNeedApprovalRequest;
}

export function confirmedNeedReleaseRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
  reasonNote: string | null = null,
): ConfirmedNeedReleaseRequest {
  return confirmedNeedLifecycleRequest(
    authSubject,
    correlationId,
    batchId,
    expectedVersion,
    "release",
    reasonNote,
  ) as ConfirmedNeedReleaseRequest;
}

export function confirmedNeedSaveV2Request(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
  lines: ConfirmedNeedLineRequest[],
): ConfirmedNeedSaveV2Request {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-05.v2",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `confirmed-need-save:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "CONFIRMED_NEED_SAVED",
    reason_note: null,
    payload: { confirmed_need_batch_id: batchId, lines },
  };
}

export function confirmedNeedReleaseV2Request(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
): ConfirmedNeedReleaseV2Request {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-07.v2",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `confirmed-need-release:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "CONFIRMED_NEED_RELEASED",
    reason_note: null,
    payload: { confirmed_need_batch_id: batchId },
  };
}

export function createConfirmedNeedApi(invoker: ConfirmedNeedRpcInvoker) {
  return {
    getReview(
      authSubject: string,
      correlationId: string,
      batchId: string,
      filters: ConfirmedNeedFilters,
      lineOffset = 0,
      lineLimit = 100,
    ) {
      return invoker.invoke(
        CONFIRMED_NEED_RPC_FUNCTIONS.getReview,
        confirmedNeedReadRequest(
          authSubject,
          correlationId,
          batchId,
          filters,
          lineOffset,
          lineLimit,
        ),
      );
    },
    preview(request: ConfirmedNeedPreviewRequest) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.preview, request);
    },
    confirm(request: ConfirmedNeedCommandRequest) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.confirm, request);
    },
    validate(request: ConfirmedNeedValidationRequest) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.validate, request);
    },
    approve(request: ConfirmedNeedApprovalRequest) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.approve, request);
    },
    release(request: ConfirmedNeedReleaseRequest) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.release, request);
    },
    save(request: ConfirmedNeedSaveV2Request) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.saveV2, request);
    },
    releaseSaved(request: ConfirmedNeedReleaseV2Request) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.releaseV2, request);
    },
  };
}

export type ConfirmedNeedApi = ReturnType<typeof createConfirmedNeedApi>;
