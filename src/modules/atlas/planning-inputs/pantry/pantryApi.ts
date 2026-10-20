import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../../connection/atlasRpc";
import { createPlanningCorrectionApi } from "../planningCorrectionApi";
import type { PantrySchoolDateMode } from "./pantryModel";

export const PANTRY_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_pantry_source_workbench",
  preview: "atlas_api.preview_pantry_source",
  saveCompleted: "atlas_api.save_pantry",
  save: "atlas_api.save_pantry_draft",
  validate: "atlas_api.validate_pantry",
  approve: "atlas_api.approve_pantry",
  reopen: "atlas_api.reopen_pantry",
} as const satisfies Record<string, AtlasRpcName>;

export type PantryRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export type PantryCommandRequest = AtlasRpcRequest & {
  contract_version: "PANTRY-02.v1";
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

export type PantryCompletionPayload = Record<string, JsonValue> & {
  week_start: string;
  no_additions_confirmed: boolean;
  source_signature: string;
  expected_source_signature: string | null;
  rows: JsonValue[];
  school_date_modes: PantrySchoolDateMode[];
};

export type PantryCompletionCommandRequest = AtlasRpcRequest & {
  contract_version: "PANTRY-02.v3" | "PANTRY-02.v4";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: "PANTRY_SAVED";
  reason_note: string | null;
  payload: PantryCompletionPayload;
};

export function pantryReadRequest(
  authSubject: string,
  correlationId: string,
  payload: Record<string, JsonValue>,
): AtlasRpcRequest {
  return {
    contract_version: "PANTRY-02.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload,
  };
}

export function pantryCommandRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  reasonCode: string,
  payload: Record<string, JsonValue>,
  reasonNote: string | null = "Cập nhật Pantry từ Nguồn kế hoạch Atlas.",
): PantryCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "PANTRY-02.v1",
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

export function pantryCompletionRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  payload: PantryCompletionPayload,
  reasonNote: string | null = "Lưu và hoàn tất Nhu cầu bổ sung.",
  contractVersion: "PANTRY-02.v3" | "PANTRY-02.v4" = "PANTRY-02.v3",
): PantryCompletionCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: contractVersion,
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `pantry_saved:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "PANTRY_SAVED",
    reason_note: reasonNote,
    payload,
  };
}

export function createPantryApi(invoker: PantryRpcInvoker) {
  const correction = createPlanningCorrectionApi(invoker);
  return {
    getCorrectionImpact(
      subject: string,
      correlationId: string,
      kind: Parameters<typeof correction.impact>[2],
      payload: Parameters<typeof correction.impact>[3],
      contractVersion: "PANTRY-02.v3" | "PANTRY-02.v4" = "PANTRY-02.v3",
    ) {
      return correction.impact(
        subject,
        correlationId,
        kind,
        kind === "PANTRY" && contractVersion === "PANTRY-02.v4"
          ? { ...payload, source_contract_version: contractVersion }
          : payload,
      );
    },
    prepareCorrection: correction.prepare,
    getWorkbench(
      authSubject: string,
      correlationId: string,
      weekStart: string,
    ) {
      return invoker.invoke(
        PANTRY_RPC_FUNCTIONS.getWorkbench,
        pantryReadRequest(authSubject, correlationId, {
          week_start: weekStart,
        }),
      );
    },
    preview(
      authSubject: string,
      correlationId: string,
      weekStart: string,
      noAdditionsConfirmed: boolean,
      rows: JsonValue[],
      schoolDateModes: PantrySchoolDateMode[] = [],
      claimedSourceSignature?: string,
      contractVersion: "PANTRY-02.v3" | "PANTRY-02.v4" = "PANTRY-02.v3",
    ) {
      return invoker.invoke(PANTRY_RPC_FUNCTIONS.preview, {
        ...pantryReadRequest(authSubject, correlationId, {
          week_start: weekStart,
          no_additions_confirmed: noAdditionsConfirmed,
          rows,
          claimed_source_signature: claimedSourceSignature ?? null,
          school_date_modes: schoolDateModes as unknown as JsonValue,
        }),
        contract_version: contractVersion,
      });
    },
    saveCompleted(request: PantryCompletionCommandRequest) {
      return invoker.invoke(PANTRY_RPC_FUNCTIONS.saveCompleted, request);
    },
    save(request: PantryCommandRequest) {
      return invoker.invoke(PANTRY_RPC_FUNCTIONS.save, request);
    },
    validate(request: PantryCommandRequest) {
      return invoker.invoke(PANTRY_RPC_FUNCTIONS.validate, request);
    },
    approve(request: PantryCommandRequest) {
      return invoker.invoke(PANTRY_RPC_FUNCTIONS.approve, request);
    },
    reopen(request: PantryCommandRequest) {
      return invoker.invoke(PANTRY_RPC_FUNCTIONS.reopen, request);
    },
  };
}

export type PantryApi = ReturnType<typeof createPantryApi>;
