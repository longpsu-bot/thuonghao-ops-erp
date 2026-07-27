import type { SupabaseClient } from "@supabase/supabase-js";

export const ATLAS_RPC_FUNCTIONS = {
  "atlas_api.record_wholesale_source": "record_wholesale_source",
  "atlas_api.release_wholesale_order": "release_wholesale_order",
  "atlas_api.release_purchase_handoff": "release_purchase_handoff",
  "atlas_api.release_dispatch_requirement": "release_dispatch_requirement",
  "atlas_api.allocate_supplier_direct_fulfilment":
    "allocate_supplier_direct_fulfilment",
  "atlas_api.release_supplier_purchase_order":
    "release_supplier_purchase_order",
  "atlas_api.record_supplier_receiving_evidence":
    "record_supplier_receiving_evidence",
  "atlas_api.apply_supplier_evidence_to_allocation":
    "apply_supplier_evidence_to_allocation",
  "atlas_api.create_dispatch_plan": "create_dispatch_plan",
  "atlas_api.create_or_assign_dispatch_trip": "create_or_assign_dispatch_trip",
  "atlas_api.confirm_dispatch_load": "confirm_dispatch_load",
  "atlas_api.record_dispatch_departure": "record_dispatch_departure",
  "atlas_api.confirm_successful_delivery": "confirm_successful_delivery",
  "atlas_api.close_successful_trip": "close_successful_trip",
  "atlas_api.get_supplier_direct_trace": "get_supplier_direct_trace",
  "atlas_api.get_dispatch_evidence_readiness":
    "get_dispatch_evidence_readiness",
  "atlas_api.get_operator_blockers": "get_operator_blockers",
  "atlas_api.get_command_audit_timeline": "get_command_audit_timeline",
  "atlas_api.get_school_master_data": "get_school_master_data",
  "atlas_api.get_ingredient_supplier_master_data":
    "get_ingredient_supplier_master_data",
  "atlas_api.update_school_portion_defaults": "update_school_portion_defaults",
  "atlas_api.create_ingredient": "create_ingredient",
  "atlas_api.update_ingredient": "update_ingredient",
  "atlas_api.set_ingredient_lifecycle": "set_ingredient_lifecycle",
  "atlas_api.create_supplier": "create_supplier",
  "atlas_api.update_supplier": "update_supplier",
  "atlas_api.replace_ingredient_supplier_priorities":
    "replace_ingredient_supplier_priorities",
  "atlas_api.get_dish_recipe_workbench": "get_dish_recipe_workbench",
  "atlas_api.create_dish": "create_dish",
  "atlas_api.update_dish": "update_dish",
  "atlas_api.set_dish_lifecycle": "set_dish_lifecycle",
  "atlas_api.set_recipe_lifecycle": "set_recipe_lifecycle",
  "atlas_api.create_recipe_draft": "create_recipe_draft",
  "atlas_api.create_recipe_successor_version":
    "create_recipe_successor_version",
  "atlas_api.replace_recipe_draft_composition":
    "replace_recipe_draft_composition",
  "atlas_api.validate_recipe_version": "validate_recipe_version",
  "atlas_api.release_recipe_version_for_planning":
    "release_recipe_version_for_planning",
  "atlas_api.copy_recipe_version": "copy_recipe_version",
  "atlas_api.apply_recipe_import": "apply_recipe_import",
} as const;

export type AtlasRpcName = keyof typeof ATLAS_RPC_FUNCTIONS;
export type JsonValue =
  string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };
export type AtlasRpcRequest = { [key: string]: JsonValue };

export type AtlasSuccessEnvelope = AtlasRpcRequest & {
  success: true;
  command_id?: string;
  correlation_id?: string;
  idempotency_status?: string;
  affected_aggregate_ids?: { [key: string]: JsonValue };
  new_versions?: { [key: string]: JsonValue };
  emitted_event_ids?: JsonValue[];
  audit_event_ids?: JsonValue[];
  safe_operator_message?: string;
  warnings?: JsonValue[];
  blockers?: JsonValue[];
};

export type AtlasSafeBackendError = {
  success: false;
  error_code: string;
  safe_message: string;
  contract_version?: string;
  domain?: string;
  command_name?: string;
  read_name?: string;
  retryable?: boolean;
  field_errors?: JsonValue[];
  blocking_references?: JsonValue[];
  expected_version?: number;
  actual_version?: number;
  correlation_id?: string;
  command_id?: string;
};

type SafeDiagnostic = {
  code:
    | "RPC_NOT_ALLOWED"
    | "SESSION_REQUIRED"
    | "SESSION_EXPIRED"
    | "NETWORK_FAILURE"
    | "RPC_TRANSPORT_FAILURE"
    | "UNEXPECTED_RESPONSE";
  safeMessage: string;
  correlationId?: string;
  commandId?: string;
};

export type AtlasRpcResult =
  | { kind: "success"; response: AtlasSuccessEnvelope }
  | { kind: "backend_error"; error: AtlasSafeBackendError }
  | { kind: "auth_error"; diagnostic: SafeDiagnostic }
  | { kind: "transport_error"; diagnostic: SafeDiagnostic }
  | { kind: "client_error"; diagnostic: SafeDiagnostic };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isAllowedRpcName(name: string): name is AtlasRpcName {
  return Object.hasOwn(ATLAS_RPC_FUNCTIONS, name);
}

function requestIdentifier(request: AtlasRpcRequest, key: string) {
  return typeof request[key] === "string" ? request[key] : undefined;
}

function diagnostic(
  code: SafeDiagnostic["code"],
  safeMessage: string,
  request: AtlasRpcRequest,
): SafeDiagnostic {
  return {
    code,
    safeMessage,
    correlationId: requestIdentifier(request, "correlation_id"),
    commandId: requestIdentifier(request, "command_id"),
  };
}

function safeBackendError(
  value: Record<string, unknown>,
): AtlasSafeBackendError {
  const result: AtlasSafeBackendError = {
    success: false,
    error_code:
      typeof value.error_code === "string" ? value.error_code : "UNKNOWN_ERROR",
    safe_message:
      typeof value.safe_message === "string"
        ? value.safe_message
        : "The backend rejected the request safely.",
  };
  const stringKeys = [
    "contract_version",
    "domain",
    "command_name",
    "read_name",
    "correlation_id",
    "command_id",
  ] as const;
  for (const key of stringKeys) {
    if (typeof value[key] === "string") result[key] = value[key];
  }
  if (typeof value.retryable === "boolean") result.retryable = value.retryable;
  if (Array.isArray(value.field_errors))
    result.field_errors = value.field_errors as JsonValue[];
  if (Array.isArray(value.blocking_references))
    result.blocking_references = value.blocking_references as JsonValue[];
  if (typeof value.expected_version === "number")
    result.expected_version = value.expected_version;
  if (typeof value.actual_version === "number")
    result.actual_version = value.actual_version;
  return result;
}

function appearsToBeNetworkFailure(error: unknown): boolean {
  if (!isRecord(error) || typeof error.message !== "string") return false;
  return /fetch|network|connection|refused|offline/i.test(error.message);
}

export function createAtlasRpcTransport(client: SupabaseClient) {
  return {
    async invoke(
      functionName: AtlasRpcName,
      request: AtlasRpcRequest,
    ): Promise<AtlasRpcResult> {
      if (!isAllowedRpcName(functionName)) {
        return {
          kind: "client_error",
          diagnostic: diagnostic(
            "RPC_NOT_ALLOWED",
            "The requested operation is not in the reviewed Atlas API registry.",
            request,
          ),
        };
      }

      const { data: sessionData, error: sessionError } =
        await client.auth.getSession();
      if (sessionError || !sessionData.session) {
        return {
          kind: "auth_error",
          diagnostic: diagnostic(
            "SESSION_REQUIRED",
            "An authenticated local Atlas session is required.",
            request,
          ),
        };
      }
      const session = sessionData.session;
      if (session.expires_at && session.expires_at * 1000 <= Date.now()) {
        return {
          kind: "auth_error",
          diagnostic: diagnostic(
            "SESSION_EXPIRED",
            "The Atlas session expired. Sign in and review before creating a new command intent.",
            request,
          ),
        };
      }

      const authoritativeRequest: AtlasRpcRequest = {
        ...request,
        requested_by_auth_subject: session.user.id,
      };
      const rpcName = ATLAS_RPC_FUNCTIONS[functionName];
      const { data, error } = await client
        .schema("atlas_api")
        .rpc(rpcName, { request: authoritativeRequest })
        .retry(false);

      if (error) {
        const networkFailure = appearsToBeNetworkFailure(error);
        return {
          kind: "transport_error",
          diagnostic: diagnostic(
            networkFailure ? "NETWORK_FAILURE" : "RPC_TRANSPORT_FAILURE",
            networkFailure
              ? "The local Supabase service could not be reached."
              : "The Atlas RPC transport failed safely.",
            request,
          ),
        };
      }
      if (isRecord(data) && data.success === true) {
        return { kind: "success", response: data as AtlasSuccessEnvelope };
      }
      if (isRecord(data) && data.success === false) {
        return { kind: "backend_error", error: safeBackendError(data) };
      }
      return {
        kind: "transport_error",
        diagnostic: diagnostic(
          "UNEXPECTED_RESPONSE",
          "The local Atlas API returned an unexpected safe response shape.",
          request,
        ),
      };
    },
  };
}
