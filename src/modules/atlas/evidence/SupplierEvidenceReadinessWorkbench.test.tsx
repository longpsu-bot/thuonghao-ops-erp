import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import type { Session } from "@supabase/supabase-js";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../connection/authSession";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import { PA06C_FIXTURE } from "./pa06cFixture";
import { SupplierEvidenceReadinessWorkbench } from "./SupplierEvidenceReadinessWorkbench";
import type { SupplierEvidenceApi } from "./supplierEvidenceApi";

const authSubject = "b6000000-0000-0000-0000-000000000101";
const otherAuthSubject = "b6000000-0000-0000-0000-000000000102";
const evidenceId = "b6c40000-0000-0000-0000-000000000101";

const session: Session = {
  access_token: "local-access-token",
  refresh_token: "local-refresh-token",
  expires_in: 3600,
  expires_at: Math.floor(Date.now() / 1000) + 3600,
  token_type: "bearer",
  user: {
    id: authSubject,
    aud: "authenticated",
    role: "authenticated",
    email: "atlas.operator@local.test",
    created_at: "2026-07-18T00:00:00.000Z",
    app_metadata: {},
    user_metadata: {},
  },
};

const authenticated: AtlasAuthState = {
  status: "authenticated",
  session,
  user: session.user,
  authSubject,
};

function authenticatedAs(subject: string): AtlasAuthState {
  const nextSession: Session = {
    ...session,
    access_token: `local-access-token-${subject}`,
    user: {
      ...session.user,
      id: subject,
      email: `atlas.operator.${subject.slice(-3)}@local.test`,
    },
  };
  return {
    status: "authenticated",
    session: nextSession,
    user: nextSession.user,
    authSubject: subject,
  };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((nextResolve) => {
    resolve = nextResolve;
  });
  return { promise, resolve };
}

function success(response: Record<string, unknown>): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...response } as never,
  };
}

function backendError(
  errorCode: string,
  safeMessage: string,
  extra: Record<string, unknown> = {},
): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: errorCode,
      safe_message: safeMessage,
      ...extra,
    },
  } as AtlasRpcResult;
}

function authError(safeMessage = "The session is no longer valid.") {
  return {
    kind: "auth_error",
    diagnostic: {
      code: "SESSION_REQUIRED",
      safeMessage,
    },
  } as AtlasRpcResult;
}

function readinessResult(version = 1, appliedQuantity = 0) {
  return success({
    readiness_items: [
      {
        readiness_status:
          appliedQuantity === PA06C_FIXTURE.quantity
            ? "EVIDENCE_COMPLETE"
            : "EVIDENCE_INCOMPLETE",
        allocated_quantity: PA06C_FIXTURE.quantity,
        loaded_quantity: 0,
        applied_evidence_quantity: appliedQuantity,
        unit_id: PA06C_FIXTURE.unit.id,
        evidence_references: [],
        blockers: appliedQuantity
          ? []
          : ["Evidence application is incomplete."],
        warnings: [],
        command_context: {
          fulfilment_allocation: {
            fulfilment_allocation_id: PA06C_FIXTURE.allocation.id,
            fulfilment_allocation_version: version,
            fulfilment_allocation_status: "RELEASED",
            fulfilment_allocation_revision_id:
              "b6c30000-0000-0000-0000-000000000601",
            fulfilment_allocation_revision_status: "RELEASED",
            fulfilment_allocation_line_id:
              "b6c30000-0000-0000-0000-000000000602",
            fulfilment_allocation_line_revision_id:
              PA06C_FIXTURE.allocation.lineRevisionId,
            supplier_id: PA06C_FIXTURE.supplier.id,
            ingredient_id: PA06C_FIXTURE.ingredient.id,
            unit_id: PA06C_FIXTURE.unit.id,
            allocated_quantity: PA06C_FIXTURE.quantity,
          },
          purchase_commitments: [
            {
              purchase_order_id: PA06C_FIXTURE.purchaseOrder.id,
              purchase_order_version: version,
              purchase_order_status: "RELEASED",
              purchase_order_revision_id:
                "b6c30000-0000-0000-0000-000000000701",
              purchase_order_revision_status: "RELEASED",
              purchase_order_line_id: "b6c30000-0000-0000-0000-000000000702",
              purchase_order_line_revision_id:
                PA06C_FIXTURE.purchaseOrder.lineRevisionId,
              supplier_id: PA06C_FIXTURE.supplier.id,
              ingredient_id: PA06C_FIXTURE.ingredient.id,
              ordered_quantity: PA06C_FIXTURE.quantity,
              unit_id: PA06C_FIXTURE.unit.id,
              service_date: PA06C_FIXTURE.serviceDate,
              delivery_location_id: PA06C_FIXTURE.deliveryLocation.id,
            },
          ],
        },
      },
    ],
  });
}

const blockerResult = success({
  blockers: [
    {
      blocker_type: "EVIDENCE_NOT_FULLY_APPLIED",
      severity: "BLOCKING",
      source_domain: "EVIDENCE",
      safe_message: "Evidence application is incomplete.",
      affected_opaque_ids: {
        purchase_order_id: PA06C_FIXTURE.purchaseOrder.id,
      },
      public_references: { trip_reference: null },
      suggested_owning_team: "PROCUREMENT",
      observed_at: "2026-07-18T01:00:00.000Z",
    },
  ],
});

const timelineResult = success({
  command_receipt_summary: {
    command_name: "record_supplier_receiving_evidence",
    outcome: "COMPLETED",
  },
  domain_events: [
    {
      event_type: "SUPPLIER_RECEIVING_EVIDENCE_RECORDED",
      occurred_at: "2026-07-18T01:00:00.000Z",
    },
  ],
  audit_events: [
    {
      event_type: "COMMAND_COMPLETED",
      reason_code: "SUPPLIER_RECEIPT",
      occurred_at: "2026-07-18T01:00:00.000Z",
    },
  ],
});

function fakeApi(overrides: Partial<SupplierEvidenceApi> = {}) {
  return {
    getReadiness: vi.fn().mockResolvedValue(readinessResult()),
    getBlockers: vi.fn().mockResolvedValue(blockerResult),
    getTimeline: vi.fn().mockResolvedValue(timelineResult),
    recordEvidence: vi.fn().mockResolvedValue(
      success({
        command_id: "b6c90000-0000-0000-0000-000000000101",
        affected_aggregate_ids: {
          supplier_receiving_evidence_id: evidenceId,
        },
        safe_operator_message: "Supplier Evidence recorded.",
      }),
    ),
    applyEvidence: vi.fn().mockResolvedValue(
      success({
        command_id: "b6c90000-0000-0000-0000-000000000102",
        safe_operator_message: "Evidence applied.",
      }),
    ),
    ...overrides,
  } as SupplierEvidenceApi & {
    [Key in keyof SupplierEvidenceApi]: ReturnType<typeof vi.fn>;
  };
}

async function renderLoaded(api = fakeApi()) {
  render(
    <SupplierEvidenceReadinessWorkbench authState={authenticated} api={api} />,
  );
  await screen.findByText("EVIDENCE_INCOMPLETE");
  return api;
}

afterEach(cleanup);

describe("PA-06C Supplier Evidence & Readiness workbench", () => {
  it("labels the synthetic boundary and exposes no arbitrary supplier or PO selector", async () => {
    const api = await renderLoaded();

    expect(
      screen.getByText("Local only · synthetic fixture · non-production"),
    ).toBeInTheDocument();
    expect(screen.getByText("No work queue exists.")).toBeInTheDocument();
    expect(
      screen.getByText(new RegExp(PA06C_FIXTURE.purchaseOrder.reference)),
    ).toBeInTheDocument();
    expect(screen.queryByLabelText(/supplier id/i)).not.toBeInTheDocument();
    expect(
      screen.queryByLabelText(/purchase order id/i),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText(`purchase_order_id: ${PA06C_FIXTURE.purchaseOrder.id}`),
    ).toBeInTheDocument();
    expect(api.getReadiness).toHaveBeenCalledOnce();
    expect(api.getBlockers).toHaveBeenCalledOnce();
  });

  it("reviews and submits Record Evidence once, then refreshes reads and timeline", async () => {
    const api = await renderLoaded();

    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    expect(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    ).toBeEnabled();
    expect(
      screen.getByRole("region", { name: "Record Evidence review" }),
    ).toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );

    expect(
      await screen.findByText("Supplier Evidence recorded."),
    ).toBeInTheDocument();
    expect(screen.getByText(evidenceId)).toBeInTheDocument();
    expect(api.recordEvidence).toHaveBeenCalledOnce();
    expect(api.applyEvidence).not.toHaveBeenCalled();
    await waitFor(() => expect(api.getReadiness).toHaveBeenCalledTimes(2));
    expect(api.getBlockers).toHaveBeenCalledTimes(2);
    expect(api.getTimeline).toHaveBeenCalledOnce();
    expect(
      screen.getByText(
        "SUPPLIER_RECEIVING_EVIDENCE_RECORDED · 2026-07-18T01:00:00.000Z",
      ),
    ).toBeInTheDocument();
  });

  it("gates Apply Evidence on the authoritative Record result and requires a separate review", async () => {
    const api = await renderLoaded();
    expect(
      screen.getByRole("button", { name: "Review Apply Evidence" }),
    ).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );
    await screen.findByText(evidenceId);

    expect(
      screen.getByRole("button", { name: "Review Apply Evidence" }),
    ).toBeEnabled();
    expect(
      screen.getByRole("button", { name: "Submit Apply Evidence" }),
    ).toBeDisabled();
    fireEvent.click(
      screen.getByRole("button", { name: "Review Apply Evidence" }),
    );
    expect(
      screen.getByRole("region", { name: "Apply Evidence review" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Submit Apply Evidence" }),
    ).toBeEnabled();
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Apply Evidence" }),
    );

    expect(await screen.findByText("Evidence applied.")).toBeInTheDocument();
    expect(api.applyEvidence).toHaveBeenCalledOnce();
    expect(api.applyEvidence.mock.calls[0][0].payload).toMatchObject({
      supplier_receiving_evidence_id: evidenceId,
      fulfilment_allocation_line_revision_id:
        PA06C_FIXTURE.allocation.lineRevisionId,
    });
  });

  it("refreshes stale READ-02 context, preserves draft, and requires a new identity", async () => {
    const getReadiness = vi
      .fn()
      .mockResolvedValueOnce(readinessResult(1))
      .mockResolvedValue(readinessResult(2));
    const recordEvidence = vi.fn().mockResolvedValue(
      backendError("STALE_VERSION", "The purchase commitment changed.", {
        expected_version: 1,
        actual_version: 2,
      }),
    );
    await renderLoaded(fakeApi({ getReadiness, recordEvidence }));
    fireEvent.change(screen.getByLabelText("Evidence quantity"), {
      target: { value: "6" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );

    expect(
      await screen.findByText(/Authoritative READ-02 context was refreshed/),
    ).toBeInTheDocument();
    expect(screen.getByText(/Expected version/)).toHaveTextContent(
      "Expected version 1; actual version 2",
    );
    expect(screen.getByLabelText("Evidence quantity")).toHaveValue(6);
    expect(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    ).toBeDisabled();
    const firstRequest = recordEvidence.mock.calls[0][0];
    expect(firstRequest.expected_version).toBe(1);

    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    const reviewedIdentity = screen.getByRole("region", {
      name: "Record Evidence review",
    });
    expect(reviewedIdentity).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );
    await waitFor(() => expect(recordEvidence).toHaveBeenCalledTimes(2));
    const secondRequest = recordEvidence.mock.calls[1][0];
    expect(secondRequest.expected_version).toBe(2);
    expect(secondRequest.command_id).not.toBe(firstRequest.command_id);
    expect(secondRequest.idempotency_key).not.toBe(
      firstRequest.idempotency_key,
    );
  });

  it("never auto-retries concurrency and reuses the exact frozen request only on explicit retry", async () => {
    const recordEvidence = vi
      .fn()
      .mockResolvedValueOnce(
        backendError(
          "RETRYABLE_CONCURRENCY_FAILURE",
          "The command can be retried explicitly.",
        ),
      )
      .mockResolvedValueOnce(
        success({
          affected_aggregate_ids: {
            supplier_receiving_evidence_id: evidenceId,
          },
          safe_operator_message: "Supplier Evidence recorded.",
        }),
      );
    await renderLoaded(fakeApi({ recordEvidence }));
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );

    expect(
      await screen.findByText("The command can be retried explicitly."),
    ).toBeInTheDocument();
    expect(recordEvidence).toHaveBeenCalledOnce();
    const serialized = JSON.stringify(recordEvidence.mock.calls[0][0]);
    fireEvent.click(
      screen.getByRole("button", { name: "Retry exact frozen request" }),
    );

    expect(
      await screen.findByText(
        "An authoritative result was returned for the exact frozen request. No duplicate was created.",
      ),
    ).toBeInTheDocument();
    expect(screen.getByText("exact retry result")).toBeInTheDocument();
    expect(screen.queryByText(/Already completed/)).not.toBeInTheDocument();
    expect(recordEvidence).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(recordEvidence.mock.calls[1][0])).toBe(serialized);
  });

  it("treats an ambiguous transport outcome as inspect-or-explicit-retry", async () => {
    const recordEvidence = vi.fn().mockResolvedValue({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "The local Supabase service could not be reached.",
      },
    });
    const api = await renderLoaded(fakeApi({ recordEvidence }));
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );

    expect(
      await screen.findByText(/outcome may be unknown/),
    ).toBeInTheDocument();
    expect(recordEvidence).toHaveBeenCalledOnce();
    expect(
      screen.getByRole("button", { name: "Retry exact frozen request" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Inspect audit timeline" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Evidence quantity")).toBeDisabled();

    fireEvent.click(
      screen.getByRole("button", { name: "Refresh approved reads" }),
    );
    await waitFor(() => expect(api.getReadiness).toHaveBeenCalledTimes(2));
    expect(screen.getByLabelText("Evidence quantity")).toBeEnabled();
    expect(
      screen.queryByRole("button", { name: "Retry exact frozen request" }),
    ).not.toBeInTheDocument();
    expect(recordEvidence).toHaveBeenCalledOnce();
  });

  it("renders capability denial safely without refreshing or progressing", async () => {
    const recordEvidence = vi
      .fn()
      .mockResolvedValue(
        backendError(
          "CAPABILITY_DENIED",
          "This operator is not allowed to record Evidence.",
        ),
      );
    const api = await renderLoaded(fakeApi({ recordEvidence }));
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );

    expect(
      await screen.findByText(
        "This operator is not allowed to record Evidence.",
      ),
    ).toBeInTheDocument();
    expect(api.getReadiness).toHaveBeenCalledOnce();
    expect(api.applyEvidence).not.toHaveBeenCalled();
  });

  it("distinguishes scope denial from capability denial", async () => {
    const recordEvidence = vi
      .fn()
      .mockResolvedValue(
        backendError(
          "SCOPE_DENIED",
          "This operator is outside the permitted fixture location scope.",
        ),
      );
    await renderLoaded(fakeApi({ recordEvidence }));
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );

    expect(
      await screen.findByText(
        "This operator is outside the permitted fixture location scope.",
      ),
    ).toBeInTheDocument();
    expect(screen.getByText("scope denied")).toBeInTheDocument();
    expect(recordEvidence).toHaveBeenCalledOnce();
  });

  it("clears every authorization-scoped view and outcome while preserving non-secret drafts on session expiry", async () => {
    const api = fakeApi();
    const rendered = render(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await screen.findByText("EVIDENCE_INCOMPLETE");
    fireEvent.change(screen.getByLabelText("Evidence quantity"), {
      target: { value: "7" },
    });
    fireEvent.change(screen.getByLabelText("Applied Evidence quantity"), {
      target: { value: "3" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );
    await screen.findByText(evidenceId);
    await screen.findByText(
      "SUPPLIER_RECEIVING_EVIDENCE_RECORDED · 2026-07-18T01:00:00.000Z",
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Review Apply Evidence" }),
    );
    expect(
      screen.getByRole("region", { name: "Apply Evidence review" }),
    ).toBeInTheDocument();

    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={{
          status: "session_expired",
          safeMessage: "The session expired.",
        }}
        api={api}
      />,
    );

    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Submit Record Evidence" }),
      ).toBeDisabled(),
    );
    expect(screen.getByLabelText("Evidence quantity")).toHaveValue(7);
    expect(screen.getByLabelText("Applied Evidence quantity")).toHaveValue(3);
    expect(screen.getAllByText(/non-secret draft is preserved/)).toHaveLength(
      2,
    );
    expect(screen.queryByText("EVIDENCE_INCOMPLETE")).not.toBeInTheDocument();
    expect(
      screen.queryByText("Evidence application is incomplete."),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText(
        "SUPPLIER_RECEIVING_EVIDENCE_RECORDED · 2026-07-18T01:00:00.000Z",
      ),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(evidenceId)).not.toBeInTheDocument();
    expect(
      screen.queryByText("Supplier Evidence recorded."),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("region", { name: "Apply Evidence review" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText("No authoritative fixture context is loaded."),
    ).toBeInTheDocument();
    expect(
      screen.getByText("No bounded blocker observations were returned."),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        "Submit or inspect a known command to load its bounded timeline.",
      ),
    ).toBeInTheDocument();
    expect(api.recordEvidence).toHaveBeenCalledOnce();
    expect(api.applyEvidence).not.toHaveBeenCalled();
  });

  it("does not let late READ-02 or READ-03 results repopulate state after session loss", async () => {
    const pendingReadiness = deferred<AtlasRpcResult>();
    const pendingBlockers = deferred<AtlasRpcResult>();
    const api = fakeApi({
      getReadiness: vi.fn(() => pendingReadiness.promise),
      getBlockers: vi.fn(() => pendingBlockers.promise),
    });
    const rendered = render(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await waitFor(() => expect(api.getReadiness).toHaveBeenCalledOnce());
    expect(api.getBlockers).toHaveBeenCalledOnce();

    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={{
          status: "session_expired",
          safeMessage: "The session expired.",
        }}
        api={api}
      />,
    );
    await screen.findByText("No authoritative fixture context is loaded.");

    await act(async () => {
      pendingReadiness.resolve(readinessResult());
      pendingBlockers.resolve(blockerResult);
      await Promise.all([pendingReadiness.promise, pendingBlockers.promise]);
    });

    expect(screen.queryByText("EVIDENCE_INCOMPLETE")).not.toBeInTheDocument();
    expect(
      screen.queryByText("Evidence application is incomplete."),
    ).not.toBeInTheDocument();
    expect(api.getReadiness).toHaveBeenCalledOnce();
    expect(api.getBlockers).toHaveBeenCalledOnce();
  });

  it("does not let a late READ-04 result repopulate the audit timeline after session loss", async () => {
    const pendingTimeline = deferred<AtlasRpcResult>();
    const api = fakeApi({
      getTimeline: vi.fn(() => pendingTimeline.promise),
    });
    const rendered = render(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await screen.findByText("EVIDENCE_INCOMPLETE");
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );
    await waitFor(() => expect(api.getTimeline).toHaveBeenCalledOnce());

    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={{
          status: "session_expired",
          safeMessage: "The session expired.",
        }}
        api={api}
      />,
    );
    await screen.findByText(
      "Submit or inspect a known command to load its bounded timeline.",
    );

    await act(async () => {
      pendingTimeline.resolve(timelineResult);
      await pendingTimeline.promise;
    });

    expect(
      screen.queryByText(
        "SUPPLIER_RECEIVING_EVIDENCE_RECORDED · 2026-07-18T01:00:00.000Z",
      ),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(evidenceId)).not.toBeInTheDocument();
  });

  it("clears subject A data before loading fresh authorized reads for subject B", async () => {
    const pendingReadinessForB = deferred<AtlasRpcResult>();
    const pendingBlockersForB = deferred<AtlasRpcResult>();
    const getReadiness = vi.fn((subject: string) =>
      subject === authSubject
        ? Promise.resolve(readinessResult())
        : pendingReadinessForB.promise,
    );
    const getBlockers = vi.fn((subject: string) =>
      subject === authSubject
        ? Promise.resolve(blockerResult)
        : pendingBlockersForB.promise,
    );
    const api = fakeApi({ getReadiness, getBlockers });
    const rendered = render(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await screen.findByText("EVIDENCE_INCOMPLETE");
    expect(
      screen.getAllByText("Evidence application is incomplete."),
    ).not.toHaveLength(0);

    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticatedAs(otherAuthSubject)}
        api={api}
      />,
    );
    await waitFor(() => expect(getReadiness).toHaveBeenCalledTimes(2));
    expect(getBlockers).toHaveBeenCalledTimes(2);
    expect(getReadiness.mock.calls[1][0]).toBe(otherAuthSubject);
    expect(getBlockers.mock.calls[1][0]).toBe(otherAuthSubject);
    expect(screen.queryByText("EVIDENCE_INCOMPLETE")).not.toBeInTheDocument();
    expect(
      screen.queryByText("Evidence application is incomplete."),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    ).toBeDisabled();

    await act(async () => {
      pendingReadinessForB.resolve(readinessResult(2, PA06C_FIXTURE.quantity));
      pendingBlockersForB.resolve(success({ blockers: [] }));
      await Promise.all([
        pendingReadinessForB.promise,
        pendingBlockersForB.promise,
      ]);
    });

    expect(await screen.findByText("EVIDENCE_COMPLETE")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    ).toBeEnabled();
  });

  it("clears authorized state and waits for an Auth transition after a read returns Auth error", async () => {
    const getReadiness = vi
      .fn()
      .mockResolvedValueOnce(readinessResult())
      .mockResolvedValueOnce(authError())
      .mockResolvedValueOnce(readinessResult(2));
    const api = fakeApi({ getReadiness });
    const rendered = render(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await screen.findByText("EVIDENCE_INCOMPLETE");
    fireEvent.click(
      screen.getByRole("button", { name: "Refresh approved reads" }),
    );

    await screen.findByText("No authoritative fixture context is loaded.");
    expect(screen.queryByText("EVIDENCE_INCOMPLETE")).not.toBeInTheDocument();
    expect(
      screen.queryByText("Evidence application is incomplete."),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Refresh approved reads" }),
    ).toBeDisabled();
    expect(getReadiness).toHaveBeenCalledTimes(2);
    expect(api.getBlockers).toHaveBeenCalledTimes(2);

    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticatedAs(authSubject)}
        api={api}
      />,
    );
    await waitFor(() => expect(getReadiness).toHaveBeenCalledTimes(3));
    expect(api.getBlockers).toHaveBeenCalledTimes(3);
    expect(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    ).toBeEnabled();
  });

  it("refreshes after reauthentication without replaying the cleared intent", async () => {
    const api = fakeApi();
    const rendered = render(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await screen.findByText("EVIDENCE_INCOMPLETE");
    fireEvent.change(screen.getByLabelText("Evidence quantity"), {
      target: { value: "8" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={{ status: "unauthenticated" }}
        api={api}
      />,
    );
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Submit Record Evidence" }),
      ).toBeDisabled(),
    );

    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await waitFor(() => expect(api.getReadiness).toHaveBeenCalledTimes(2));

    expect(screen.getByLabelText("Evidence quantity")).toHaveValue(8);
    expect(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    ).toBeDisabled();
    expect(api.recordEvidence).not.toHaveBeenCalled();
  });

  it("ignores a late command result after the Auth identity is lost", async () => {
    let resolveCommand!: (result: AtlasRpcResult) => void;
    const pendingCommand = new Promise<AtlasRpcResult>((resolve) => {
      resolveCommand = resolve;
    });
    const recordEvidence = vi.fn(() => pendingCommand);
    const api = fakeApi({ recordEvidence });
    const rendered = render(
      <SupplierEvidenceReadinessWorkbench
        authState={authenticated}
        api={api}
      />,
    );
    await screen.findByText("EVIDENCE_INCOMPLETE");
    fireEvent.click(
      screen.getByRole("button", { name: "Review Record Evidence" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Submit Record Evidence" }),
    );
    expect(screen.getByLabelText("Evidence quantity")).toBeDisabled();
    await waitFor(() => expect(recordEvidence).toHaveBeenCalledOnce());

    rendered.rerender(
      <SupplierEvidenceReadinessWorkbench
        authState={{
          status: "session_expired",
          safeMessage: "The session expired.",
        }}
        api={api}
      />,
    );
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Submit Record Evidence" }),
      ).toBeDisabled(),
    );
    await act(async () => {
      resolveCommand(
        success({
          affected_aggregate_ids: {
            supplier_receiving_evidence_id: evidenceId,
          },
          safe_operator_message: "This late result must not be restored.",
        }),
      );
      await pendingCommand;
    });

    expect(screen.queryByText(evidenceId)).not.toBeInTheDocument();
    expect(
      screen.queryByText("This late result must not be restored."),
    ).not.toBeInTheDocument();
    expect(screen.getAllByText(/non-secret draft is preserved/)).toHaveLength(
      2,
    );
  });
});
