import type { AtlasSafeBackendError } from "../connection/atlasRpc";
import type { EvidenceCommandRequest } from "./supplierEvidenceApi";

export type CommandIntentPhase =
  | "draft"
  | "reviewed"
  | "submitting"
  | "success"
  | "exact_replay"
  | "stale"
  | "retryable_concurrency"
  | "denied"
  | "validation_failure"
  | "invariant_violation"
  | "ambiguous_transport"
  | "session_expired"
  | "internal_failure";

export type FrozenCommandIntent = {
  request: EvidenceCommandRequest;
  serializedRequest: string;
};

export type CommandIntentState<Draft> = {
  phase: CommandIntentPhase;
  draft: Draft;
  intent: FrozenCommandIntent | null;
  response: Record<string, unknown> | null;
  error: AtlasSafeBackendError | null;
  notice: string | null;
};

export type CommandIntentAction<Draft> =
  | { type: "EDIT"; draft: Draft }
  | { type: "REVIEW"; intent: FrozenCommandIntent }
  | { type: "SUBMIT" }
  | {
      type: "SUCCESS";
      response: Record<string, unknown>;
      exactRetry: boolean;
    }
  | { type: "BACKEND_ERROR"; error: AtlasSafeBackendError }
  | { type: "AMBIGUOUS_TRANSPORT"; notice: string }
  | { type: "STALE_REFRESHED"; notice: string }
  | { type: "SESSION_LOST" }
  | { type: "SESSION_RESTORED" }
  | { type: "RESET_OUTCOME" };

function deepFreeze<T>(value: T): T {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value);
    Object.values(value).forEach((child) => deepFreeze(child));
  }
  return value;
}

export function freezeCommandIntent(
  request: EvidenceCommandRequest,
): FrozenCommandIntent {
  const frozenRequest = deepFreeze(
    JSON.parse(JSON.stringify(request)) as EvidenceCommandRequest,
  );
  return deepFreeze({
    request: frozenRequest,
    serializedRequest: JSON.stringify(frozenRequest),
  });
}

export function initialCommandIntentState<Draft>(
  draft: Draft,
): CommandIntentState<Draft> {
  return {
    phase: "draft",
    draft,
    intent: null,
    response: null,
    error: null,
    notice: null,
  };
}

function phaseForBackendError(
  error: AtlasSafeBackendError,
): CommandIntentPhase {
  if (error.error_code === "STALE_VERSION") return "stale";
  if (error.error_code === "RETRYABLE_CONCURRENCY_FAILURE")
    return "retryable_concurrency";
  if (
    error.error_code === "CAPABILITY_DENIED" ||
    error.error_code === "SCOPE_DENIED"
  )
    return "denied";
  if (error.error_code === "VALIDATION_FAILED") return "validation_failure";
  if (
    error.error_code === "INVARIANT_VIOLATION" ||
    error.error_code === "EVIDENCE_VOIDED" ||
    error.error_code === "EVIDENCE_OVER_APPLIED" ||
    error.error_code === "IDEMPOTENCY_CONFLICT"
  )
    return "invariant_violation";
  return "internal_failure";
}

export function commandIntentReducer<Draft>(
  state: CommandIntentState<Draft>,
  action: CommandIntentAction<Draft>,
): CommandIntentState<Draft> {
  switch (action.type) {
    case "EDIT":
      return {
        ...state,
        phase: "draft",
        draft: action.draft,
        intent: null,
        response: null,
        error: null,
        notice: state.intent
          ? "The reviewed intent was invalidated by this edit. Review again."
          : null,
      };
    case "REVIEW":
      return {
        ...state,
        phase: "reviewed",
        intent: action.intent,
        response: null,
        error: null,
        notice: null,
      };
    case "SUBMIT":
      return { ...state, phase: "submitting", error: null, notice: null };
    case "SUCCESS":
      return {
        ...state,
        phase: action.exactRetry ? "exact_replay" : "success",
        response: action.response,
        error: null,
        notice: action.exactRetry
          ? "Already completed — the original authoritative result was returned."
          : null,
      };
    case "BACKEND_ERROR":
      return {
        ...state,
        phase: phaseForBackendError(action.error),
        response: null,
        error: action.error,
        notice: null,
      };
    case "AMBIGUOUS_TRANSPORT":
      return {
        ...state,
        phase: "ambiguous_transport",
        response: null,
        error: null,
        notice: action.notice,
      };
    case "STALE_REFRESHED":
      return {
        ...state,
        phase: "draft",
        intent: null,
        response: null,
        notice: action.notice,
      };
    case "SESSION_LOST":
      return {
        ...state,
        phase: "session_expired",
        intent: null,
        response: null,
        error: null,
        notice:
          "Session ended. The non-secret draft is preserved; refresh and review again after sign-in.",
      };
    case "SESSION_RESTORED":
      return state.phase === "session_expired"
        ? {
            ...state,
            phase: "draft",
            intent: null,
            response: null,
            error: null,
            notice:
              "Session restored. Authoritative reads must refresh before a new review.",
          }
        : state;
    case "RESET_OUTCOME":
      return {
        ...state,
        phase: "draft",
        intent: null,
        response: null,
        error: null,
        notice: null,
      };
  }
}
