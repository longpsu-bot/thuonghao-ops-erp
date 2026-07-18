import { describe, expect, it } from "vitest";
import {
  commandIntentReducer,
  freezeCommandIntent,
  initialCommandIntentState,
} from "./supplierEvidenceCommandIntent";
import type { EvidenceCommandRequest } from "./supplierEvidenceApi";

const request: EvidenceCommandRequest = {
  contract_version: "PA-05B.v1",
  command_id: "b6c90000-0000-0000-0000-000000000101",
  correlation_id: "b6c90000-0000-0000-0000-000000000100",
  idempotency_key: "pa06c-record-001",
  expected_version: 1,
  requested_by_auth_subject: "b6000000-0000-0000-0000-000000000101",
  requested_at: "2026-07-18T01:00:00.000Z",
  reason_code: "SUPPLIER_RECEIPT",
  reason_note: null,
  payload: {
    evidence_quantity: 10,
    evidence_reference: "PA06C-EVIDENCE-001",
  },
};

describe("PA-06C frozen command intent", () => {
  it("deep-copies, serializes, and freezes the complete reviewed request", () => {
    const mutable = structuredClone(request);
    const intent = freezeCommandIntent(mutable);
    mutable.expected_version = 99;
    mutable.payload.evidence_quantity = 99;

    expect(intent.request).toEqual(request);
    expect(intent.serializedRequest).toBe(JSON.stringify(request));
    expect(Object.isFrozen(intent)).toBe(true);
    expect(Object.isFrozen(intent.request)).toBe(true);
    expect(Object.isFrozen(intent.request.payload)).toBe(true);
  });

  it("invalidates the reviewed identity when any draft field changes", () => {
    const reviewed = commandIntentReducer(
      initialCommandIntentState({ quantity: "10" }),
      {
        type: "REVIEW",
        intent: freezeCommandIntent(request),
      },
    );
    const edited = commandIntentReducer(reviewed, {
      type: "EDIT",
      draft: { quantity: "9" },
    });

    expect(edited.phase).toBe("draft");
    expect(edited.intent).toBeNull();
    expect(edited.notice).toContain("invalidated");
  });

  it("preserves the exact frozen request for explicit exact retry", () => {
    const intent = freezeCommandIntent(request);
    const reviewed = commandIntentReducer(
      initialCommandIntentState({ quantity: "10" }),
      {
        type: "REVIEW",
        intent,
      },
    );
    const concurrency = commandIntentReducer(reviewed, {
      type: "BACKEND_ERROR",
      error: {
        success: false,
        error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        safe_message: "Retry may be attempted explicitly.",
      },
    });
    const retryResult = commandIntentReducer(concurrency, {
      type: "SUCCESS",
      response: { command_id: request.command_id },
      exactRetry: true,
    });

    expect(concurrency.intent).toBe(intent);
    expect(concurrency.intent?.serializedRequest).toBe(JSON.stringify(request));
    expect(retryResult.phase).toBe("exact_retry_result");
    expect(retryResult.notice).toBe(
      "An authoritative result was returned for the exact frozen request. No duplicate was created.",
    );
  });

  it.each([
    ["STALE_VERSION", "stale"],
    ["RETRYABLE_CONCURRENCY_FAILURE", "retryable_concurrency"],
    ["CAPABILITY_DENIED", "denied"],
    ["SCOPE_DENIED", "denied"],
    ["VALIDATION_FAILED", "validation_failure"],
    ["INVARIANT_VIOLATION", "invariant_violation"],
    ["EVIDENCE_VOIDED", "invariant_violation"],
    ["EVIDENCE_OVER_APPLIED", "invariant_violation"],
    ["IDEMPOTENCY_CONFLICT", "invariant_violation"],
    ["UNEXPECTED", "internal_failure"],
  ] as const)("maps %s to %s", (errorCode, phase) => {
    const state = commandIntentReducer(
      initialCommandIntentState({ quantity: "10" }),
      {
        type: "BACKEND_ERROR",
        error: {
          success: false,
          error_code: errorCode,
          safe_message: "Safe message.",
        },
      },
    );
    expect(state.phase).toBe(phase);
  });

  it("preserves only the non-secret draft across a session loss", () => {
    const reviewed = commandIntentReducer(
      initialCommandIntentState({ quantity: "10" }),
      {
        type: "REVIEW",
        intent: freezeCommandIntent(request),
      },
    );
    const expired = commandIntentReducer(reviewed, { type: "SESSION_LOST" });
    const restored = commandIntentReducer(expired, {
      type: "SESSION_RESTORED",
    });

    expect(expired.draft).toEqual({ quantity: "10" });
    expect(expired.intent).toBeNull();
    expect(expired.response).toBeNull();
    expect(expired.phase).toBe("session_expired");
    expect(restored.phase).toBe("draft");
    expect(restored.notice).toContain("reads must refresh");
  });

  it("clears a stale identity after refresh while preserving the edited draft", () => {
    const reviewed = commandIntentReducer(
      initialCommandIntentState({ quantity: "6" }),
      {
        type: "REVIEW",
        intent: freezeCommandIntent(request),
      },
    );
    const stale = commandIntentReducer(reviewed, {
      type: "BACKEND_ERROR",
      error: {
        success: false,
        error_code: "STALE_VERSION",
        safe_message: "Version is stale.",
        expected_version: 1,
        actual_version: 2,
      },
    });
    const refreshed = commandIntentReducer(stale, {
      type: "STALE_REFRESHED",
      notice: "Authoritative READ-02 context was refreshed.",
    });

    expect(refreshed.draft).toEqual({ quantity: "6" });
    expect(refreshed.intent).toBeNull();
    expect(refreshed.phase).toBe("draft");
    expect(refreshed.error).toMatchObject({
      error_code: "STALE_VERSION",
      expected_version: 1,
      actual_version: 2,
    });
  });
});
