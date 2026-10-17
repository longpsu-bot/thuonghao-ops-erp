import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
} from "../../connection/atlasRpc";
import { normalizeConfirmedNeedQuantity } from "./confirmedNeedModel";
import type { ConfirmedNeedDraftLine } from "./confirmedNeedModel";

export const CONFIRMED_NEED_RPC_FUNCTIONS = {
  getReview: "atlas_api.get_confirmed_need_review",
  previewCorrection: "atlas_api.get_confirmed_need_correction_preview",
  correct: "atlas_api.correct_confirmed_need",
  preview: "atlas_api.preview_confirmed_need_confirmation",
  confirm: "atlas_api.confirm_need_quantities",
  validate: "atlas_api.validate_confirmed_needs",
  approve: "atlas_api.approve_confirmed_needs",
  release: "atlas_api.release_confirmed_needs_for_purchase_handoff",
  saveV2: "atlas_api.save_confirmed_needs",
  releaseV2: "atlas_api.release_confirmed_needs",
  releasePurchaseHandoff: "atlas_api.release_school_catering_purchase_handoff",
} as const satisfies Record<string, AtlasRpcName>;

export type ConfirmedNeedCorrectionPayload = {
  need_generation_run_id: string;
  expected_need_generation_run_version: number;
  confirmed_need_batch_id: string;
  expected_confirmed_need_batch_version: number;
  confirmed_need_line_id: string;
  expected_current_revision_id: string;
  expected_current_decision_id: string;
  proposed_confirmed_quantity: string;
  reason_code: ConfirmedNeedDraftLine["reason_code"];
  reason_note: string;
};
export type ConfirmedNeedCorrectionPreviewRequest = AtlasRpcRequest & {
  contract_version: "CONFIRMED-NEED-CORRECTION.v1";
  requested_by_auth_subject: string;
  correlation_id: string;
  payload: ConfirmedNeedCorrectionPayload;
};
export type ConfirmedNeedCorrectionCommandRequest =
  ConfirmedNeedCorrectionPreviewRequest & {
    command_id: string;
    idempotency_key: string;
    requested_at: string;
    expected_version: number;
    reason_code: "CONFIRMED_NEED_CORRECTION_SAVED";
    reason_note: string;
    payload: ConfirmedNeedCorrectionPayload & { proposal_fingerprint: string };
  };
export function confirmedNeedCorrectionPreviewRequest(
  authSubject: string,
  correlationId: string,
  input: ConfirmedNeedCorrectionPayload,
): ConfirmedNeedCorrectionPreviewRequest {
  const {
    need_generation_run_id,
    expected_need_generation_run_version,
    confirmed_need_batch_id,
    expected_confirmed_need_batch_version,
    confirmed_need_line_id,
    expected_current_revision_id,
    expected_current_decision_id,
    reason_code,
    reason_note,
  } = input;
  const quantity =
    typeof input.proposed_confirmed_quantity === "string"
      ? normalizeConfirmedNeedQuantity(input.proposed_confirmed_quantity)
      : null;
  if (
    ![
      authSubject,
      correlationId,
      need_generation_run_id,
      confirmed_need_batch_id,
      confirmed_need_line_id,
      expected_current_revision_id,
      expected_current_decision_id,
      reason_note,
    ].every((v) => typeof v === "string" && v.trim()) ||
    ![
      expected_need_generation_run_version,
      expected_confirmed_need_batch_version,
    ].every((v) => Number.isSafeInteger(v) && v > 0) ||
    ![
      "PROPOSAL_ACCEPTED",
      "PLANNING_STEP_ADJUSTMENT",
      "OPERATIONAL_QUANTITY_ADJUSTMENT",
      "OTHER",
    ].includes(reason_code) ||
    !quantity
  )
    throw new Error(
      "Thông tin điều chỉnh chưa đầy đủ hoặc số lượng không hợp lệ.",
    );
  const [integer, fraction = ""] = quantity.split(".");
  return {
    contract_version: "CONFIRMED-NEED-CORRECTION.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: {
      need_generation_run_id,
      expected_need_generation_run_version,
      confirmed_need_batch_id,
      expected_confirmed_need_batch_version,
      confirmed_need_line_id,
      expected_current_revision_id,
      expected_current_decision_id,
      proposed_confirmed_quantity: `${integer}.${fraction.padEnd(6, "0")}`,
      reason_code,
      reason_note,
    },
  };
}
export function confirmedNeedCorrectionCommandRequest(
  authSubject: string,
  correlationId: string,
  payload: ConfirmedNeedCorrectionPayload,
  fingerprint: string,
): ConfirmedNeedCorrectionCommandRequest {
  if (!/^[0-9a-f]{64}$/.test(fingerprint))
    throw new Error("Cần xem lại đề xuất điều chỉnh hiện tại.");
  const preview = confirmedNeedCorrectionPreviewRequest(
      authSubject,
      correlationId,
      payload,
    ),
    command = crypto.randomUUID();
  return {
    ...preview,
    command_id: command,
    idempotency_key: `confirmed-need-correction:${command}`,
    requested_at: new Date().toISOString(),
    expected_version: preview.payload.expected_confirmed_need_batch_version,
    reason_code: "CONFIRMED_NEED_CORRECTION_SAVED",
    reason_note: preview.payload.reason_note,
    payload: { ...preview.payload, proposal_fingerprint: fingerprint },
  };
}

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

export type ConfirmedNeedPurchaseHandoffRequest = AtlasRpcRequest & {
  contract_version: "SCHOOL-CATERING-HANDOFF.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED";
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

export function confirmedNeedPurchaseHandoffRequest(
  authSubject: string,
  correlationId: string,
  batchId: string,
  expectedVersion: number,
): ConfirmedNeedPurchaseHandoffRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "SCHOOL-CATERING-HANDOFF.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `school-catering-handoff:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED",
    reason_note: null,
    payload: { confirmed_need_batch_id: batchId },
  };
}

export function createConfirmedNeedApi(invoker: ConfirmedNeedRpcInvoker) {
  return {
    previewCorrection(request: ConfirmedNeedCorrectionPreviewRequest) {
      return invoker.invoke(
        CONFIRMED_NEED_RPC_FUNCTIONS.previewCorrection,
        request,
      );
    },
    correct(request: ConfirmedNeedCorrectionCommandRequest) {
      return invoker.invoke(CONFIRMED_NEED_RPC_FUNCTIONS.correct, request);
    },
    getShoppingListExport(request: AtlasRpcRequest) {
      return invoker.invoke(
        "atlas_api.get_confirmed_need_shopping_list_export",
        request,
      );
    },
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
    releasePurchaseHandoff(request: ConfirmedNeedPurchaseHandoffRequest) {
      return invoker.invoke(
        CONFIRMED_NEED_RPC_FUNCTIONS.releasePurchaseHandoff,
        request,
      );
    },
  };
}

export type ConfirmedNeedApi = Omit<
  ReturnType<typeof createConfirmedNeedApi>,
  "getShoppingListExport"
> &
  Partial<
    Pick<ReturnType<typeof createConfirmedNeedApi>, "getShoppingListExport">
  >;
