import type {
  AtlasEdgeFunctionName,
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../connection/atlasRpc";
import { ATLAS_EDGE_FUNCTIONS } from "../connection/atlasRpc";
import { createPlanningCorrectionApi } from "./planningCorrectionApi";

export const PLANNING_INPUT_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_planning_inputs_workbench",
  previewMenu: "atlas_api.preview_weekly_menu_import",
  previewAttendance: "atlas_api.preview_attendance_import",
  saveCompletedMenu: "atlas_api.save_weekly_menu",
  saveMenu: "atlas_api.save_weekly_menu_draft",
  validateMenu: "atlas_api.validate_weekly_menu",
  approveMenu: "atlas_api.approve_weekly_menu",
  reopenMenu: "atlas_api.reopen_weekly_menu",
  createAttendanceDefaults: "atlas_api.create_attendance_draft_from_defaults",
  saveCompletedAttendance: "atlas_api.save_attendance",
  saveAttendance: "atlas_api.save_attendance_draft",
  validateAttendance: "atlas_api.validate_attendance",
  approveAttendance: "atlas_api.approve_attendance",
  reopenAttendance: "atlas_api.reopen_attendance",
} as const satisfies Record<string, AtlasRpcName>;

export type PlanningCommandRequest = AtlasRpcRequest & {
  contract_version: "RMVP-03A.v1";
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

export type WeeklyMenuCompletionPayload = Record<string, JsonValue> & {
  week_start: string;
  source_type: string;
  source_name: string;
  source_signature: string;
  expected_source_signature: string | null;
  rows: JsonValue[];
};

export type AttendanceCompletionPayload = Record<string, JsonValue> & {
  week_start: string;
  source_type: string;
  source_name: string;
  source_signature: string;
  expected_source_signature: string | null;
  rows: JsonValue[];
};

export type PlanningCompletionCommandRequest<
  Payload extends Record<string, JsonValue>,
> = AtlasRpcRequest & {
  contract_version: "RMVP-03A.v2";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_code: string;
  reason_note: string | null;
  payload: Payload;
};

export type PlanningRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
  invokeEdgeFunction?(
    functionName: AtlasEdgeFunctionName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function planningReadRequest(
  authSubject: string,
  correlationId: string,
  payload: Record<string, JsonValue>,
): AtlasRpcRequest {
  return {
    contract_version: "RMVP-03A.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload,
  };
}

export function planningCommandRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  reasonCode: string,
  payload: Record<string, JsonValue>,
  reasonNote: string | null = "Cập nhật từ khu vực Nguồn kế hoạch Atlas.",
): PlanningCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-03A.v1",
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

function planningCompletionRequest<Payload extends Record<string, JsonValue>>(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  reasonCode: string,
  payload: Payload,
  reasonNote: string | null,
): PlanningCompletionCommandRequest<Payload> {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-03A.v2",
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

export function weeklyMenuCompletionRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  payload: WeeklyMenuCompletionPayload,
  reasonNote: string | null = "Lưu và hoàn tất Thực đơn tuần.",
) {
  return planningCompletionRequest(
    authSubject,
    correlationId,
    expectedVersion,
    "WEEKLY_MENU_SAVED",
    payload,
    reasonNote,
  );
}

export function attendanceCompletionRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  payload: AttendanceCompletionPayload,
  reasonNote: string | null = "Lưu và hoàn tất Số suất ăn.",
) {
  return planningCompletionRequest(
    authSubject,
    correlationId,
    expectedVersion,
    "ATTENDANCE_SAVED",
    payload,
    reasonNote,
  );
}

export function createPlanningInputsApi(invoker: PlanningRpcInvoker) {
  const correction = createPlanningCorrectionApi(invoker);
  const command =
    (
      name: Exclude<
        keyof typeof PLANNING_INPUT_RPC_FUNCTIONS,
        | "getWorkbench"
        | "previewMenu"
        | "previewAttendance"
        | "saveCompletedMenu"
        | "saveCompletedAttendance"
      >,
    ) =>
    (request: PlanningCommandRequest) =>
      invoker.invoke(PLANNING_INPUT_RPC_FUNCTIONS[name], request);

  return {
    getCorrectionImpact: correction.impact,
    prepareCorrection: correction.prepare,
    getWorkbench(
      authSubject: string,
      correlationId: string,
      weekStart: string,
    ) {
      return invoker.invoke(
        PLANNING_INPUT_RPC_FUNCTIONS.getWorkbench,
        planningReadRequest(authSubject, correlationId, {
          week_start: weekStart,
        }),
      );
    },
    previewMenu(
      authSubject: string,
      correlationId: string,
      weekStart: string,
      rows: JsonValue[],
      sourceSignature?: string,
    ) {
      return invoker.invoke(
        PLANNING_INPUT_RPC_FUNCTIONS.previewMenu,
        planningReadRequest(authSubject, correlationId, {
          week_start: weekStart,
          rows,
          source_signature: sourceSignature ?? null,
        }),
      );
    },
    previewAttendance(
      authSubject: string,
      correlationId: string,
      weekStart: string,
      rows: JsonValue[],
      sourceSignature?: string,
    ) {
      return invoker.invoke(
        PLANNING_INPUT_RPC_FUNCTIONS.previewAttendance,
        planningReadRequest(authSubject, correlationId, {
          week_start: weekStart,
          rows,
          source_signature: sourceSignature ?? null,
        }),
      );
    },
    syncMenuFromGoogle(
      weeklyMenuGoogleSourceId: string,
      weekStart: string,
      correlationId: string,
    ) {
      const request: AtlasRpcRequest = {
        weekly_menu_google_source_id: weeklyMenuGoogleSourceId,
        week_start: weekStart,
        correlation_id: correlationId,
      };
      if (!invoker.invokeEdgeFunction) {
        return Promise.resolve<AtlasRpcResult>({
          kind: "client_error",
          diagnostic: {
            code: "RPC_NOT_ALLOWED",
            safeMessage:
              "The Google Sheet connector is unavailable in this runtime.",
            correlationId,
          },
        });
      }
      return invoker.invokeEdgeFunction(
        ATLAS_EDGE_FUNCTIONS.weeklyMenuGoogleSync,
        request,
      );
    },
    saveCompletedMenu(
      request: PlanningCompletionCommandRequest<WeeklyMenuCompletionPayload>,
    ) {
      return invoker.invoke(
        PLANNING_INPUT_RPC_FUNCTIONS.saveCompletedMenu,
        request,
      );
    },
    saveCompletedAttendance(
      request: PlanningCompletionCommandRequest<AttendanceCompletionPayload>,
    ) {
      return invoker.invoke(
        PLANNING_INPUT_RPC_FUNCTIONS.saveCompletedAttendance,
        request,
      );
    },
    saveMenu: command("saveMenu"),
    validateMenu: command("validateMenu"),
    approveMenu: command("approveMenu"),
    reopenMenu: command("reopenMenu"),
    createAttendanceDefaults: command("createAttendanceDefaults"),
    saveAttendance: command("saveAttendance"),
    validateAttendance: command("validateAttendance"),
    approveAttendance: command("approveAttendance"),
    reopenAttendance: command("reopenAttendance"),
  };
}

export type PlanningInputsApi = ReturnType<typeof createPlanningInputsApi>;
