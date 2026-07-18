import {
  useCallback,
  useEffect,
  useReducer,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { AtlasAuthState } from "../connection/authSession";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import { Chip, Panel } from "../WorkbenchComponents";
import { PA06C_FIXTURE } from "./pa06cFixture";
import {
  commandIntentReducer,
  freezeCommandIntent,
  initialCommandIntentState,
  type CommandIntentState,
} from "./supplierEvidenceCommandIntent";
import type {
  EvidenceCommandRequest,
  SupplierEvidenceApi,
} from "./supplierEvidenceApi";

type FulfilmentAllocationContext = {
  fulfilment_allocation_id: string;
  fulfilment_allocation_version: number;
  fulfilment_allocation_status: string;
  fulfilment_allocation_revision_id: string;
  fulfilment_allocation_revision_status: string;
  fulfilment_allocation_line_id: string;
  fulfilment_allocation_line_revision_id: string;
  supplier_id: string;
  ingredient_id: string;
  unit_id: string;
  allocated_quantity: number;
};

type PurchaseCommitment = {
  purchase_order_id: string;
  purchase_order_version: number;
  purchase_order_status: string;
  purchase_order_revision_id: string;
  purchase_order_revision_status: string;
  purchase_order_line_id: string;
  purchase_order_line_revision_id: string;
  supplier_id: string;
  ingredient_id: string;
  ordered_quantity: number;
  unit_id: string;
  service_date: string;
  delivery_location_id: string;
};

export type EvidenceReadinessItem = {
  readiness_status: string;
  allocated_quantity: number;
  loaded_quantity: number;
  applied_evidence_quantity: number;
  unit_id: string;
  evidence_references: Array<Record<string, unknown>>;
  blockers: string[];
  warnings: string[];
  command_context: {
    fulfilment_allocation: FulfilmentAllocationContext;
    purchase_commitments: PurchaseCommitment[];
  };
};

export type OperatorBlocker = {
  blocker_type: string;
  severity: string;
  source_domain: string;
  safe_message: string;
  affected_opaque_ids: Record<string, unknown>;
  public_references: { trip_reference?: string | null };
  suggested_owning_team: string;
  observed_at: string | null;
};

type Timeline = {
  command_receipt_summary: Record<string, unknown> | null;
  domain_events: Array<Record<string, unknown>>;
  audit_events: Array<Record<string, unknown>>;
};

type ReadState<T> =
  | { status: "idle" | "loading"; data: T }
  | { status: "success"; data: T }
  | { status: "error"; data: T; safeMessage: string };

export type RecordDraft = {
  evidenceQuantity: string;
  evidenceReference: string;
  occurredAt: string;
  reasonCode: string;
  reasonNote: string;
};

export type ApplyDraft = {
  appliedQuantity: string;
  occurredAt: string;
  reasonCode: string;
  reasonNote: string;
};

export type SupplierEvidenceWorkbenchInitialModel = {
  readiness?: ReadState<EvidenceReadinessItem[]>;
  blockers?: ReadState<OperatorBlocker[]>;
  timeline?: ReadState<Timeline | null>;
  recordState?: CommandIntentState<RecordDraft>;
  applyState?: CommandIntentState<ApplyDraft>;
  evidenceId?: string | null;
  disableAutoLoad?: boolean;
};

function localDateTimeValue(date = new Date()) {
  const offset = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 16);
}

const initialRecordDraft = (): RecordDraft => ({
  evidenceQuantity: String(PA06C_FIXTURE.quantity),
  evidenceReference: "PA06C-EVIDENCE-001",
  occurredAt: localDateTimeValue(),
  reasonCode: "SUPPLIER_RECEIPT",
  reasonNote: "",
});

const initialApplyDraft = (): ApplyDraft => ({
  appliedQuantity: String(PA06C_FIXTURE.quantity),
  occurredAt: localDateTimeValue(),
  reasonCode: "APPLY_SUPPLIER_EVIDENCE",
  reasonNote: "",
});

function recordValue(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function resultSafeMessage(result: AtlasRpcResult): string {
  if (result.kind === "backend_error") return result.error.safe_message;
  if (result.kind === "success")
    return typeof result.response.safe_operator_message === "string"
      ? result.response.safe_operator_message
      : "The authoritative Atlas response was returned.";
  return result.diagnostic.safeMessage;
}

function successArray<T>(result: AtlasRpcResult, key: string): T[] | null {
  if (result.kind !== "success") return null;
  const value = result.response[key];
  return Array.isArray(value) ? (value as T[]) : null;
}

function currentContext(items: EvidenceReadinessItem[]) {
  const item = items[0];
  const allocation = item?.command_context?.fulfilment_allocation;
  const purchaseCommitment = item?.command_context?.purchase_commitments?.[0];
  return allocation && purchaseCommitment
    ? { item, allocation, purchaseCommitment }
    : null;
}

function safeReferenceText(value: unknown): string | null {
  if (["string", "number", "boolean"].includes(typeof value))
    return String(value);
  if (
    Array.isArray(value) &&
    value.every((item) => ["string", "number", "boolean"].includes(typeof item))
  )
    return value.map(String).join(", ");
  return null;
}

function reviewedIdentity(request: EvidenceCommandRequest) {
  return (
    <dl className="evidence-identity-grid">
      <div>
        <dt>Command ID</dt>
        <dd>
          <code>{request.command_id}</code>
        </dd>
      </div>
      <div>
        <dt>Correlation ID</dt>
        <dd>
          <code>{request.correlation_id}</code>
        </dd>
      </div>
      <div>
        <dt>Expected version</dt>
        <dd>{request.expected_version}</dd>
      </div>
      <div>
        <dt>Requested at</dt>
        <dd>{request.requested_at}</dd>
      </div>
    </dl>
  );
}

function OutcomePanel({
  title,
  state,
  onExactRetry,
  onInspectTimeline,
}: {
  title: string;
  state: CommandIntentState<RecordDraft | ApplyDraft>;
  onExactRetry: () => void;
  onInspectTimeline: () => void;
}) {
  if (state.phase === "draft" && !state.notice && !state.error) return null;

  let tone: "neutral" | "ok" | "warning" | "danger" = "neutral";
  let label = state.phase.replaceAll("_", " ");
  let message = state.notice;
  if (state.phase === "success") {
    tone = "ok";
    label = "success";
    message =
      typeof state.response?.safe_operator_message === "string"
        ? state.response.safe_operator_message
        : "The authoritative command completed.";
  } else if (state.phase === "exact_retry_result") {
    tone = "ok";
    label = "exact retry result";
  } else if (
    state.phase === "stale" ||
    state.phase === "retryable_concurrency" ||
    state.phase === "ambiguous_transport"
  ) {
    tone = "warning";
  } else if (
    state.phase === "denied" ||
    state.phase === "validation_failure" ||
    state.phase === "invariant_violation" ||
    state.phase === "session_expired" ||
    state.phase === "internal_failure"
  ) {
    tone = "danger";
  }
  if (state.phase === "denied")
    label =
      state.error?.error_code === "SCOPE_DENIED"
        ? "scope denied"
        : "capability denied";
  if (state.error && state.phase !== "draft")
    message = state.error.safe_message;

  return (
    <section
      className={`command-outcome ${tone}`}
      aria-label={`${title} outcome`}
    >
      <div className="command-outcome-heading">
        <h3>{title}</h3>
        <Chip tone={tone}>{label}</Chip>
      </div>
      {message && <p>{message}</p>}
      {state.error?.error_code === "STALE_VERSION" && (
        <p>
          Expected version <b>{state.error.expected_version ?? "unknown"}</b>;
          actual version <b>{state.error.actual_version ?? "unknown"}</b>.
          Resubmission of this stale intent is disabled.
        </p>
      )}
      {state.intent && reviewedIdentity(state.intent.request)}
      {(state.phase === "retryable_concurrency" ||
        state.phase === "ambiguous_transport") && (
        <button type="button" onClick={onExactRetry}>
          Retry exact frozen request
        </button>
      )}
      {(state.intent || state.response) && (
        <button type="button" onClick={onInspectTimeline}>
          Inspect audit timeline
        </button>
      )}
    </section>
  );
}

function Field({ children }: { children: ReactNode }) {
  return <label className="evidence-field">{children}</label>;
}

export function SupplierEvidenceReadinessWorkbench({
  authState,
  api,
  initialModel,
}: {
  authState: AtlasAuthState;
  api?: SupplierEvidenceApi;
  initialModel?: SupplierEvidenceWorkbenchInitialModel;
}) {
  const authenticated = authState.status === "authenticated";
  const authSubject = authenticated ? authState.authSubject : null;
  const authIdentity = `${authState.status}:${authSubject ?? ""}`;
  const authSessionToken = authenticated
    ? authState.session.access_token
    : null;
  const [correlationId] = useState(() => crypto.randomUUID());
  const [readiness, setReadiness] = useState<
    ReadState<EvidenceReadinessItem[]>
  >(initialModel?.readiness ?? { status: "idle", data: [] });
  const [blockers, setBlockers] = useState<ReadState<OperatorBlocker[]>>(
    initialModel?.blockers ?? { status: "idle", data: [] },
  );
  const [timeline, setTimeline] = useState<ReadState<Timeline | null>>(
    initialModel?.timeline ?? { status: "idle", data: null },
  );
  const [authoritativeEvidenceId, setAuthoritativeEvidenceId] = useState<
    string | null
  >(initialModel?.evidenceId ?? null);
  const [recordState, dispatchRecord] = useReducer(
    commandIntentReducer<RecordDraft>,
    initialModel?.recordState ??
      initialCommandIntentState(initialRecordDraft()),
  );
  const [applyState, dispatchApply] = useReducer(
    commandIntentReducer<ApplyDraft>,
    initialModel?.applyState ?? initialCommandIntentState(initialApplyDraft()),
  );
  const [authorizationInvalidated, setAuthorizationInvalidated] =
    useState(!authenticated);
  const authorizationInvalidatedRef = useRef(!authenticated);
  const previousAuthIdentity = useRef<string | null>(null);
  const previousAuthSessionToken = useRef(authSessionToken);
  const authIdentityRef = useRef(authIdentity);
  const readinessRequestGeneration = useRef(0);
  const blockerRequestGeneration = useRef(0);
  const timelineRequestGeneration = useRef(0);
  authIdentityRef.current = authIdentity;
  const authorized = authenticated && !authorizationInvalidated;
  const context = currentContext(readiness.data);
  const recordEditLocked =
    recordState.phase === "submitting" ||
    recordState.phase === "ambiguous_transport";
  const applyEditLocked =
    applyState.phase === "submitting" ||
    applyState.phase === "ambiguous_transport";

  const clearAuthorizedWorkbenchState = useCallback(() => {
    authorizationInvalidatedRef.current = true;
    setAuthorizationInvalidated(true);
    readinessRequestGeneration.current += 1;
    blockerRequestGeneration.current += 1;
    timelineRequestGeneration.current += 1;
    setReadiness({ status: "idle", data: [] });
    setBlockers({ status: "idle", data: [] });
    setTimeline({ status: "idle", data: null });
    setAuthoritativeEvidenceId(null);
    dispatchRecord({ type: "SESSION_LOST" });
    dispatchApply({ type: "SESSION_LOST" });
  }, []);

  const loadReads = useCallback(async () => {
    if (!api || !authSubject || authorizationInvalidatedRef.current)
      return false;
    const requestAuthIdentity = authIdentityRef.current;
    const readinessGeneration = ++readinessRequestGeneration.current;
    const blockerGeneration = ++blockerRequestGeneration.current;
    setReadiness((current) => ({ status: "loading", data: current.data }));
    setBlockers((current) => ({ status: "loading", data: current.data }));
    const [readinessResult, blockerResult] = await Promise.all([
      api.getReadiness(authSubject, correlationId),
      api.getBlockers(authSubject, correlationId),
    ]);
    if (
      authIdentityRef.current !== requestAuthIdentity ||
      authorizationInvalidatedRef.current ||
      readinessRequestGeneration.current !== readinessGeneration ||
      blockerRequestGeneration.current !== blockerGeneration
    )
      return false;
    if (
      readinessResult.kind === "auth_error" ||
      blockerResult.kind === "auth_error"
    ) {
      clearAuthorizedWorkbenchState();
      return false;
    }
    const readinessItems = successArray<EvidenceReadinessItem>(
      readinessResult,
      "readiness_items",
    );
    const blockerItems = successArray<OperatorBlocker>(
      blockerResult,
      "blockers",
    );
    if (readinessItems) {
      setReadiness({ status: "success", data: readinessItems });
    } else {
      setReadiness((current) => ({
        status: "error",
        data: current.data,
        safeMessage: resultSafeMessage(readinessResult),
      }));
    }
    if (blockerItems) {
      setBlockers({ status: "success", data: blockerItems });
    } else {
      setBlockers((current) => ({
        status: "error",
        data: current.data,
        safeMessage: resultSafeMessage(blockerResult),
      }));
    }
    return Boolean(readinessItems && blockerItems);
  }, [api, authSubject, clearAuthorizedWorkbenchState, correlationId]);

  const loadTimeline = useCallback(
    async (commandId: string) => {
      if (!api || !authSubject || authorizationInvalidatedRef.current) return;
      const requestAuthIdentity = authIdentityRef.current;
      const timelineGeneration = ++timelineRequestGeneration.current;
      setTimeline((current) => ({ status: "loading", data: current.data }));
      const result = await api.getTimeline(
        authSubject,
        correlationId,
        commandId,
      );
      if (
        authIdentityRef.current !== requestAuthIdentity ||
        authorizationInvalidatedRef.current ||
        timelineRequestGeneration.current !== timelineGeneration
      )
        return;
      if (result.kind === "auth_error") {
        clearAuthorizedWorkbenchState();
        return;
      }
      if (result.kind !== "success") {
        setTimeline((current) => ({
          status: "error",
          data: current.data,
          safeMessage: resultSafeMessage(result),
        }));
        return;
      }
      const response = result.response as Record<string, unknown>;
      setTimeline({
        status: "success",
        data: {
          command_receipt_summary: recordValue(
            response.command_receipt_summary,
          ),
          domain_events: Array.isArray(response.domain_events)
            ? (response.domain_events as Array<Record<string, unknown>>)
            : [],
          audit_events: Array.isArray(response.audit_events)
            ? (response.audit_events as Array<Record<string, unknown>>)
            : [],
        },
      });
    },
    [api, authSubject, clearAuthorizedWorkbenchState, correlationId],
  );

  useEffect(() => {
    if (
      authorized &&
      readiness.status === "idle" &&
      !initialModel?.disableAutoLoad
    ) {
      void loadReads();
    }
  }, [authorized, initialModel?.disableAutoLoad, loadReads, readiness.status]);

  useEffect(() => {
    const previous = previousAuthIdentity.current;
    const previousSessionToken = previousAuthSessionToken.current;
    previousAuthIdentity.current = authIdentity;
    previousAuthSessionToken.current = authSessionToken;
    if (previous === null) {
      if (!authenticated) clearAuthorizedWorkbenchState();
      return;
    }
    if (previous === authIdentity) {
      if (
        authenticated &&
        authorizationInvalidatedRef.current &&
        previousSessionToken !== authSessionToken
      ) {
        authorizationInvalidatedRef.current = false;
        setAuthorizationInvalidated(false);
        dispatchRecord({ type: "SESSION_RESTORED" });
        dispatchApply({ type: "SESSION_RESTORED" });
      }
      return;
    }

    clearAuthorizedWorkbenchState();
    if (authenticated) {
      authorizationInvalidatedRef.current = false;
      setAuthorizationInvalidated(false);
      dispatchRecord({ type: "SESSION_RESTORED" });
      dispatchApply({ type: "SESSION_RESTORED" });
    }
  }, [
    authIdentity,
    authenticated,
    authSessionToken,
    clearAuthorizedWorkbenchState,
  ]);

  const editRecord = (change: Partial<RecordDraft>) =>
    dispatchRecord({
      type: "EDIT",
      draft: { ...recordState.draft, ...change },
    });
  const editApply = (change: Partial<ApplyDraft>) =>
    dispatchApply({
      type: "EDIT",
      draft: { ...applyState.draft, ...change },
    });

  const reviewRecord = () => {
    if (!authorized || !context || !authSubject) return;
    const quantity = Number(recordState.draft.evidenceQuantity);
    const occurredAt = new Date(recordState.draft.occurredAt);
    if (
      !Number.isFinite(quantity) ||
      quantity <= 0 ||
      !recordState.draft.evidenceReference.trim() ||
      !recordState.draft.reasonCode.trim() ||
      Number.isNaN(occurredAt.getTime())
    )
      return;
    const request: EvidenceCommandRequest = {
      contract_version: "PA-05B.v1",
      command_id: crypto.randomUUID(),
      correlation_id: correlationId,
      idempotency_key: `pa06c-record-${crypto.randomUUID()}`,
      expected_version: context.purchaseCommitment.purchase_order_version,
      requested_by_auth_subject: authSubject,
      requested_at: new Date().toISOString(),
      reason_code: recordState.draft.reasonCode.trim(),
      reason_note: recordState.draft.reasonNote.trim() || null,
      payload: {
        purchase_order_line_revision_id:
          context.purchaseCommitment.purchase_order_line_revision_id,
        supplier_id: context.purchaseCommitment.supplier_id,
        ingredient_id: context.purchaseCommitment.ingredient_id,
        unit_id: context.purchaseCommitment.unit_id,
        evidence_quantity: quantity,
        evidence_reference: recordState.draft.evidenceReference.trim(),
        occurred_at: occurredAt.toISOString(),
      },
    };
    dispatchRecord({ type: "REVIEW", intent: freezeCommandIntent(request) });
  };

  const reviewApply = () => {
    if (!authorized || !context || !authSubject || !authoritativeEvidenceId)
      return;
    const quantity = Number(applyState.draft.appliedQuantity);
    const occurredAt = new Date(applyState.draft.occurredAt);
    if (
      !Number.isFinite(quantity) ||
      quantity <= 0 ||
      !applyState.draft.reasonCode.trim() ||
      Number.isNaN(occurredAt.getTime())
    )
      return;
    const request: EvidenceCommandRequest = {
      contract_version: "PA-05B.v1",
      command_id: crypto.randomUUID(),
      correlation_id: correlationId,
      idempotency_key: `pa06c-apply-${crypto.randomUUID()}`,
      expected_version: context.allocation.fulfilment_allocation_version,
      requested_by_auth_subject: authSubject,
      requested_at: new Date().toISOString(),
      reason_code: applyState.draft.reasonCode.trim(),
      reason_note: applyState.draft.reasonNote.trim() || null,
      payload: {
        supplier_receiving_evidence_id: authoritativeEvidenceId,
        fulfilment_allocation_line_revision_id:
          context.allocation.fulfilment_allocation_line_revision_id,
        unit_id: context.allocation.unit_id,
        applied_quantity: quantity,
        occurred_at: occurredAt.toISOString(),
      },
    };
    dispatchApply({ type: "REVIEW", intent: freezeCommandIntent(request) });
  };

  const executeCommand = async (
    kind: "record" | "apply",
    exactRetry = false,
  ) => {
    const state = kind === "record" ? recordState : applyState;
    const dispatch = kind === "record" ? dispatchRecord : dispatchApply;
    if (
      !api ||
      !authSubject ||
      authorizationInvalidatedRef.current ||
      !state.intent
    )
      return;
    const submissionAuthIdentity = authIdentity;
    dispatch({ type: "SUBMIT" });
    const result =
      kind === "record"
        ? await api.recordEvidence(state.intent.request)
        : await api.applyEvidence(state.intent.request);
    if (
      authIdentityRef.current !== submissionAuthIdentity ||
      authorizationInvalidatedRef.current
    )
      return;
    if (result.kind === "success") {
      const response = result.response as Record<string, unknown>;
      dispatch({ type: "SUCCESS", response, exactRetry });
      if (kind === "record") {
        const ids = recordValue(response.affected_aggregate_ids);
        const evidenceId = ids?.supplier_receiving_evidence_id;
        if (typeof evidenceId === "string")
          setAuthoritativeEvidenceId(evidenceId);
      }
      await loadReads();
      await loadTimeline(state.intent.request.command_id);
      return;
    }
    if (result.kind === "backend_error") {
      dispatch({ type: "BACKEND_ERROR", error: result.error });
      if (result.error.error_code === "STALE_VERSION") {
        const refreshed = await loadReads();
        if (refreshed) {
          dispatch({
            type: "STALE_REFRESHED",
            notice:
              "Authoritative READ-02 context was refreshed. Review a new intent; the stale request cannot be resubmitted.",
          });
        }
      }
      await loadTimeline(state.intent.request.command_id);
      return;
    }
    if (result.kind === "auth_error") {
      clearAuthorizedWorkbenchState();
      return;
    }
    dispatch({
      type: "AMBIGUOUS_TRANSPORT",
      notice:
        "The authoritative outcome may be unknown. No retry occurred. Inspect the timeline or explicitly retry this exact frozen request.",
    });
  };

  const inspectStateTimeline = (
    state: CommandIntentState<RecordDraft | ApplyDraft>,
  ) => {
    const responseCommandId = state.response?.command_id;
    const commandId =
      typeof responseCommandId === "string"
        ? responseCommandId
        : state.intent?.request.command_id;
    if (commandId) void loadTimeline(commandId);
  };

  const refreshApprovedReads = async () => {
    const refreshed = await loadReads();
    if (!refreshed) return;
    if (recordState.phase === "ambiguous_transport")
      dispatchRecord({ type: "RESET_OUTCOME" });
    if (applyState.phase === "ambiguous_transport")
      dispatchApply({ type: "RESET_OUTCOME" });
  };

  return (
    <div className="evidence-workbench">
      <section
        className="fixture-boundary"
        aria-label="PA-06C fixture boundary"
      >
        <div>
          <span>PA-06C PILOT</span>
          <h2>Supplier Evidence &amp; Readiness</h2>
          <strong>{PA06C_FIXTURE.environmentNotice}</strong>
        </div>
        <ul>
          <li>No work queue exists.</li>
          <li>No supplier or PO discovery exists.</li>
          <li>No production data is connected.</li>
          <li>Fixture IDs are predetermined and not editable.</li>
          <li>Backend commands remain authoritative.</li>
        </ul>
      </section>

      <Panel
        title="Fixture context"
        description="Safe references for one predetermined supplier-direct source lineage."
        status={<Chip>Fixture only</Chip>}
      >
        <dl className="fixture-context-grid">
          <div>
            <dt>Customer / location</dt>
            <dd>
              {PA06C_FIXTURE.customer.reference} /{" "}
              {PA06C_FIXTURE.deliveryLocation.reference}
            </dd>
          </div>
          <div>
            <dt>Source line</dt>
            <dd>
              {PA06C_FIXTURE.source.orderReference}
              <code>{PA06C_FIXTURE.source.lineRevisionId}</code>
            </dd>
          </div>
          <div>
            <dt>Allocation</dt>
            <dd>
              <code>{PA06C_FIXTURE.allocation.id}</code>
            </dd>
          </div>
          <div>
            <dt>Supplier / PO</dt>
            <dd>
              {PA06C_FIXTURE.supplier.reference} /{" "}
              {PA06C_FIXTURE.purchaseOrder.reference}
            </dd>
          </div>
          <div>
            <dt>Quantity</dt>
            <dd>
              {PA06C_FIXTURE.quantity} {PA06C_FIXTURE.unit.label}
            </dd>
          </div>
        </dl>
      </Panel>

      <div className="evidence-read-grid">
        <Panel
          title="Readiness"
          description="Advisory READ-02. It does not grant command permission."
          status={
            <Chip tone={readiness.status === "error" ? "danger" : "neutral"}>
              {readiness.status}
            </Chip>
          }
        >
          {readiness.status === "error" && (
            <p role="alert">{readiness.safeMessage}</p>
          )}
          {context ? (
            <>
              <dl className="readiness-summary">
                <div>
                  <dt>Status</dt>
                  <dd>{context.item.readiness_status}</dd>
                </div>
                <div>
                  <dt>Allocated</dt>
                  <dd>{context.item.allocated_quantity}</dd>
                </div>
                <div>
                  <dt>Applied Evidence</dt>
                  <dd>{context.item.applied_evidence_quantity}</dd>
                </div>
                <div>
                  <dt>Loaded</dt>
                  <dd>{context.item.loaded_quantity}</dd>
                </div>
              </dl>
              <details>
                <summary>Authoritative current command context</summary>
                <p>
                  Allocation version{" "}
                  <b>{context.allocation.fulfilment_allocation_version}</b> ·
                  line revision{" "}
                  <code>
                    {context.allocation.fulfilment_allocation_line_revision_id}
                  </code>
                </p>
                <p>
                  PO version{" "}
                  <b>{context.purchaseCommitment.purchase_order_version}</b> ·
                  line revision{" "}
                  <code>
                    {context.purchaseCommitment.purchase_order_line_revision_id}
                  </code>
                </p>
              </details>
              {context.item.evidence_references.length > 0 && (
                <ul>
                  {context.item.evidence_references.map((reference, index) => (
                    <li key={index}>
                      {String(reference.evidence_reference ?? "Evidence")}:{" "}
                      {String(reference.evidence_status ?? "unknown")}
                    </li>
                  ))}
                </ul>
              )}
              {[...context.item.blockers, ...context.item.warnings].map(
                (message) => (
                  <p key={message}>{message}</p>
                ),
              )}
            </>
          ) : (
            <p>No authoritative fixture context is loaded.</p>
          )}
          <button
            type="button"
            disabled={!authorized || readiness.status === "loading"}
            onClick={() => void refreshApprovedReads()}
          >
            Refresh approved reads
          </button>
        </Panel>

        <Panel
          title="Operator blockers"
          description="Derived observations only; blockers are not permission."
          status={<Chip>{blockers.data.length} observations</Chip>}
        >
          {blockers.status === "error" && (
            <p role="alert">{blockers.safeMessage}</p>
          )}
          {blockers.data.length === 0 ? (
            <p>No bounded blocker observations were returned.</p>
          ) : (
            <ul className="blocker-list">
              {blockers.data.map((blocker, index) => (
                <li key={`${blocker.blocker_type}-${index}`}>
                  <strong>
                    {blocker.blocker_type} · {blocker.severity}
                  </strong>
                  <span>{blocker.safe_message}</span>
                  <small>
                    {blocker.source_domain} · {blocker.suggested_owning_team} ·{" "}
                    {blocker.observed_at ?? "No observation time"}
                  </small>
                  {blocker.public_references.trip_reference && (
                    <code>{blocker.public_references.trip_reference}</code>
                  )}
                  {Object.entries(blocker.affected_opaque_ids).map(
                    ([key, value]) => {
                      const safeValue = safeReferenceText(value);
                      return safeValue ? (
                        <code key={key}>
                          {key}: {safeValue}
                        </code>
                      ) : null;
                    },
                  )}
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </div>

      <div className="evidence-command-grid">
        <Panel
          title="Record supplier receiving Evidence"
          description="Supplier, ingredient, unit, and PO line come from the authoritative current commitment."
          status={<Chip>{recordState.phase}</Chip>}
        >
          <div className="evidence-form-grid">
            <Field>
              Quantity
              <input
                aria-label="Evidence quantity"
                type="number"
                min="0.000001"
                step="any"
                required
                disabled={recordEditLocked}
                value={recordState.draft.evidenceQuantity}
                onChange={(event) =>
                  editRecord({ evidenceQuantity: event.target.value })
                }
              />
            </Field>
            <Field>
              Evidence reference
              <input
                aria-label="Evidence reference"
                required
                disabled={recordEditLocked}
                value={recordState.draft.evidenceReference}
                onChange={(event) =>
                  editRecord({ evidenceReference: event.target.value })
                }
              />
            </Field>
            <Field>
              Occurred time
              <input
                aria-label="Evidence occurred time"
                type="datetime-local"
                required
                disabled={recordEditLocked}
                value={recordState.draft.occurredAt}
                onChange={(event) =>
                  editRecord({ occurredAt: event.target.value })
                }
              />
            </Field>
            <Field>
              Reason code
              <input
                aria-label="Evidence reason code"
                required
                disabled={recordEditLocked}
                value={recordState.draft.reasonCode}
                onChange={(event) =>
                  editRecord({ reasonCode: event.target.value })
                }
              />
            </Field>
            <Field>
              Reason note
              <textarea
                aria-label="Evidence reason note"
                disabled={recordEditLocked}
                value={recordState.draft.reasonNote}
                onChange={(event) =>
                  editRecord({ reasonNote: event.target.value })
                }
              />
            </Field>
          </div>
          {recordState.phase === "reviewed" && recordState.intent && (
            <section
              className="command-review"
              aria-label="Record Evidence review"
            >
              <h3>Review authoritative Record Evidence intent</h3>
              <p>
                {recordState.draft.evidenceQuantity} {PA06C_FIXTURE.unit.label}{" "}
                from {PA06C_FIXTURE.supplier.reference} against{" "}
                {PA06C_FIXTURE.purchaseOrder.reference}.
              </p>
              {reviewedIdentity(recordState.intent.request)}
            </section>
          )}
          <div className="workbench-actions">
            <button
              type="button"
              disabled={
                !authorized ||
                !context ||
                readiness.status !== "success" ||
                recordEditLocked ||
                recordState.phase === "session_expired"
              }
              onClick={reviewRecord}
            >
              Review Record Evidence
            </button>
            <button
              type="button"
              className="primary"
              disabled={recordState.phase !== "reviewed" || !authorized}
              onClick={() => void executeCommand("record")}
            >
              Submit Record Evidence
            </button>
          </div>
          <OutcomePanel
            title="Record Evidence command outcome"
            state={recordState}
            onExactRetry={() => void executeCommand("record", true)}
            onInspectTimeline={() => inspectStateTimeline(recordState)}
          />
        </Panel>

        <Panel
          title="Apply Evidence to allocation"
          description="This is a separate reviewed command and never runs automatically after recording."
          status={
            <Chip tone={authoritativeEvidenceId ? "ok" : "warning"}>
              {authoritativeEvidenceId
                ? "Evidence result available"
                : "Awaiting Record success"}
            </Chip>
          }
        >
          {authoritativeEvidenceId && (
            <p>
              Authoritative Evidence ID <code>{authoritativeEvidenceId}</code>
            </p>
          )}
          <div className="evidence-form-grid">
            <Field>
              Applied quantity
              <input
                aria-label="Applied Evidence quantity"
                type="number"
                min="0.000001"
                step="any"
                required
                disabled={applyEditLocked}
                value={applyState.draft.appliedQuantity}
                onChange={(event) =>
                  editApply({ appliedQuantity: event.target.value })
                }
              />
            </Field>
            <Field>
              Occurred time
              <input
                aria-label="Application occurred time"
                type="datetime-local"
                required
                disabled={applyEditLocked}
                value={applyState.draft.occurredAt}
                onChange={(event) =>
                  editApply({ occurredAt: event.target.value })
                }
              />
            </Field>
            <Field>
              Reason code
              <input
                aria-label="Application reason code"
                required
                disabled={applyEditLocked}
                value={applyState.draft.reasonCode}
                onChange={(event) =>
                  editApply({ reasonCode: event.target.value })
                }
              />
            </Field>
            <Field>
              Reason note
              <textarea
                aria-label="Application reason note"
                disabled={applyEditLocked}
                value={applyState.draft.reasonNote}
                onChange={(event) =>
                  editApply({ reasonNote: event.target.value })
                }
              />
            </Field>
          </div>
          {applyState.phase === "reviewed" && applyState.intent && (
            <section
              className="command-review"
              aria-label="Apply Evidence review"
            >
              <h3>Review authoritative Apply Evidence intent</h3>
              <p>
                Apply {applyState.draft.appliedQuantity}{" "}
                {PA06C_FIXTURE.unit.label} to the current allocation-line
                revision.
              </p>
              {reviewedIdentity(applyState.intent.request)}
            </section>
          )}
          <div className="workbench-actions">
            <button
              type="button"
              disabled={
                !authorized ||
                !context ||
                !authoritativeEvidenceId ||
                readiness.status !== "success" ||
                applyEditLocked ||
                applyState.phase === "session_expired"
              }
              onClick={reviewApply}
            >
              Review Apply Evidence
            </button>
            <button
              type="button"
              className="primary"
              disabled={applyState.phase !== "reviewed" || !authorized}
              onClick={() => void executeCommand("apply")}
            >
              Submit Apply Evidence
            </button>
          </div>
          <OutcomePanel
            title="Apply Evidence command outcome"
            state={applyState}
            onExactRetry={() => void executeCommand("apply", true)}
            onInspectTimeline={() => inspectStateTimeline(applyState)}
          />
        </Panel>
      </div>

      <Panel
        title="Command and audit timeline"
        description="Command receipt, domain events, and audit events are distinct authoritative record types."
        status={<Chip>{timeline.status}</Chip>}
      >
        {timeline.status === "error" && (
          <p role="alert">{timeline.safeMessage}</p>
        )}
        {!timeline.data ? (
          <p>Submit or inspect a known command to load its bounded timeline.</p>
        ) : (
          <div className="timeline-grid">
            <section>
              <h3>Command receipt</h3>
              <p>
                {timeline.data.command_receipt_summary
                  ? `${String(timeline.data.command_receipt_summary.command_name ?? "Command")} · ${String(timeline.data.command_receipt_summary.outcome ?? "unknown")}`
                  : "No receipt summary returned."}
              </p>
            </section>
            <section>
              <h3>Domain events</h3>
              <ul>
                {timeline.data.domain_events.map((event, index) => (
                  <li key={index}>
                    {String(event.event_type ?? "Domain event")} ·{" "}
                    {String(event.occurred_at ?? "unknown time")}
                  </li>
                ))}
              </ul>
            </section>
            <section>
              <h3>Audit events</h3>
              <ul>
                {timeline.data.audit_events.map((event, index) => (
                  <li key={index}>
                    {String(event.event_type ?? "Audit event")} ·{" "}
                    {String(event.reason_code ?? "no reason code")} ·{" "}
                    {String(event.occurred_at ?? "unknown time")}
                  </li>
                ))}
              </ul>
            </section>
          </div>
        )}
      </Panel>
    </div>
  );
}
