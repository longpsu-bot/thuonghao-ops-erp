import type { Meta, StoryObj } from "@storybook/react-vite";
import type { Session } from "@supabase/supabase-js";
import type { AtlasAuthState } from "../connection/authSession";
import { PA06C_FIXTURE } from "./pa06cFixture";
import {
  SupplierEvidenceReadinessWorkbench,
  type ApplyDraft,
  type EvidenceReadinessItem,
  type RecordDraft,
  type SupplierEvidenceWorkbenchInitialModel,
} from "./SupplierEvidenceReadinessWorkbench";
import {
  freezeCommandIntent,
  initialCommandIntentState,
  type CommandIntentPhase,
  type CommandIntentState,
} from "./supplierEvidenceCommandIntent";
import type { EvidenceCommandRequest } from "./supplierEvidenceApi";

const authSubject = "b6000000-0000-0000-0000-000000000101";
const correlationId = "b6c90000-0000-0000-0000-000000000100";
const evidenceId = "b6c40000-0000-0000-0000-000000000101";
const session = {
  access_token: "story-local-token",
  refresh_token: "story-local-refresh",
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
} satisfies Session;

const authenticated: AtlasAuthState = {
  status: "authenticated",
  session,
  user: session.user,
  authSubject,
};

const recordDraft: RecordDraft = {
  evidenceQuantity: "10",
  evidenceReference: "PA06C-EVIDENCE-001",
  occurredAt: "2026-07-18T08:00",
  reasonCode: "SUPPLIER_RECEIPT",
  reasonNote: "Synthetic PA-06C pilot Evidence.",
};

const applyDraft: ApplyDraft = {
  appliedQuantity: "10",
  occurredAt: "2026-07-18T08:05",
  reasonCode: "APPLY_SUPPLIER_EVIDENCE",
  reasonNote: "Synthetic PA-06C pilot application.",
};

function commandRequest(kind: "record" | "apply"): EvidenceCommandRequest {
  return {
    contract_version: "PA-05B.v1",
    command_id:
      kind === "record"
        ? "b6c90000-0000-0000-0000-000000000101"
        : "b6c90000-0000-0000-0000-000000000102",
    correlation_id: correlationId,
    idempotency_key: `pa06c-story-${kind}`,
    expected_version: 1,
    requested_by_auth_subject: authSubject,
    requested_at: "2026-07-18T01:00:00.000Z",
    reason_code:
      kind === "record" ? "SUPPLIER_RECEIPT" : "APPLY_SUPPLIER_EVIDENCE",
    reason_note: "Synthetic Storybook state.",
    payload:
      kind === "record"
        ? {
            purchase_order_line_revision_id:
              PA06C_FIXTURE.purchaseOrder.lineRevisionId,
            supplier_id: PA06C_FIXTURE.supplier.id,
            ingredient_id: PA06C_FIXTURE.ingredient.id,
            unit_id: PA06C_FIXTURE.unit.id,
            evidence_quantity: 10,
            evidence_reference: "PA06C-EVIDENCE-001",
            occurred_at: "2026-07-18T01:00:00.000Z",
          }
        : {
            supplier_receiving_evidence_id: evidenceId,
            fulfilment_allocation_line_revision_id:
              PA06C_FIXTURE.allocation.lineRevisionId,
            unit_id: PA06C_FIXTURE.unit.id,
            applied_quantity: 10,
            occurred_at: "2026-07-18T01:05:00.000Z",
          },
  };
}

function commandState<Draft>(
  draft: Draft,
  kind: "record" | "apply",
  phase: CommandIntentPhase,
): CommandIntentState<Draft> {
  const base = initialCommandIntentState(draft);
  const intent = freezeCommandIntent(commandRequest(kind));
  if (phase === "reviewed") return { ...base, phase, intent };
  if (phase === "success" || phase === "exact_retry_result") {
    return {
      ...base,
      phase,
      intent,
      notice:
        phase === "exact_retry_result"
          ? "An authoritative result was returned for the exact frozen request. No duplicate was created."
          : null,
      response: {
        success: true,
        command_id: intent.request.command_id,
        safe_operator_message:
          kind === "record"
            ? "Supplier Evidence recorded."
            : "Evidence applied to allocation.",
      },
    };
  }
  if (phase === "stale") {
    return {
      ...base,
      phase,
      intent,
      error: {
        success: false,
        error_code: "STALE_VERSION",
        safe_message: "The authoritative aggregate version changed.",
        expected_version: 1,
        actual_version: 2,
      },
    };
  }
  if (phase === "denied") {
    return {
      ...base,
      phase,
      intent,
      error: {
        success: false,
        error_code: "CAPABILITY_DENIED",
        safe_message: "This operator is not allowed to record Evidence.",
      },
    };
  }
  if (phase === "ambiguous_transport") {
    return {
      ...base,
      phase,
      intent,
      notice:
        "The authoritative outcome may be unknown. Inspect the timeline or explicitly retry this exact frozen request.",
    };
  }
  if (phase === "session_expired") {
    return {
      ...base,
      phase,
      notice:
        "Session ended. The non-secret draft is preserved; refresh and review again after sign-in.",
    };
  }
  return base;
}

function readiness(appliedEvidenceQuantity = 0): EvidenceReadinessItem {
  return {
    readiness_status:
      appliedEvidenceQuantity === 10
        ? "EVIDENCE_COMPLETE"
        : "EVIDENCE_INCOMPLETE",
    allocated_quantity: 10,
    loaded_quantity: 0,
    applied_evidence_quantity: appliedEvidenceQuantity,
    unit_id: PA06C_FIXTURE.unit.id,
    evidence_references: appliedEvidenceQuantity
      ? [
          {
            supplier_receiving_evidence_id: evidenceId,
            evidence_reference: "PA06C-EVIDENCE-001",
            evidence_status: "RECORDED",
          },
        ]
      : [],
    blockers: appliedEvidenceQuantity ? [] : ["Evidence is not fully applied."],
    warnings: [],
    command_context: {
      fulfilment_allocation: {
        fulfilment_allocation_id: PA06C_FIXTURE.allocation.id,
        fulfilment_allocation_version: 1,
        fulfilment_allocation_status: "RELEASED",
        fulfilment_allocation_revision_id:
          "b6c30000-0000-0000-0000-000000000601",
        fulfilment_allocation_revision_status: "RELEASED",
        fulfilment_allocation_line_id: "b6c30000-0000-0000-0000-000000000602",
        fulfilment_allocation_line_revision_id:
          PA06C_FIXTURE.allocation.lineRevisionId,
        supplier_id: PA06C_FIXTURE.supplier.id,
        ingredient_id: PA06C_FIXTURE.ingredient.id,
        unit_id: PA06C_FIXTURE.unit.id,
        allocated_quantity: 10,
      },
      purchase_commitments: [
        {
          purchase_order_id: PA06C_FIXTURE.purchaseOrder.id,
          purchase_order_version: 1,
          purchase_order_status: "RELEASED",
          purchase_order_revision_id: "b6c30000-0000-0000-0000-000000000701",
          purchase_order_revision_status: "RELEASED",
          purchase_order_line_id: "b6c30000-0000-0000-0000-000000000702",
          purchase_order_line_revision_id:
            PA06C_FIXTURE.purchaseOrder.lineRevisionId,
          supplier_id: PA06C_FIXTURE.supplier.id,
          ingredient_id: PA06C_FIXTURE.ingredient.id,
          ordered_quantity: 10,
          unit_id: PA06C_FIXTURE.unit.id,
          service_date: PA06C_FIXTURE.serviceDate,
          delivery_location_id: PA06C_FIXTURE.deliveryLocation.id,
        },
      ],
    },
  };
}

function model(
  overrides: SupplierEvidenceWorkbenchInitialModel = {},
): SupplierEvidenceWorkbenchInitialModel {
  return {
    readiness: { status: "success", data: [readiness()] },
    blockers: { status: "success", data: [] },
    disableAutoLoad: true,
    ...overrides,
  };
}

const meta = {
  title: "Atlas/Supplier Evidence & Readiness",
  component: SupplierEvidenceReadinessWorkbench,
  args: {
    authState: authenticated,
    initialModel: model(),
  },
  parameters: {
    docs: {
      description: {
        component:
          "Controlled PA-06C fixture states. They are synthetic, local-only, and do not call a backend.",
      },
    },
  },
} satisfies Meta<typeof SupplierEvidenceReadinessWorkbench>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Initial: Story = {};

export const RecordReview: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "reviewed"),
    }),
  },
};

export const RecordSuccess: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "success"),
      evidenceId,
    }),
  },
};

export const ExactRetryResult: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "exact_retry_result"),
      evidenceId,
    }),
  },
};

export const ApplyReview: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "success"),
      applyState: commandState(applyDraft, "apply", "reviewed"),
      evidenceId,
    }),
  },
};

export const ApplyCompleted: Story = {
  args: {
    initialModel: model({
      readiness: { status: "success", data: [readiness(10)] },
      recordState: commandState(recordDraft, "record", "success"),
      applyState: commandState(applyDraft, "apply", "success"),
      evidenceId,
    }),
  },
};

export const StaleVersion: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "stale"),
    }),
  },
};

export const CapabilityDenied: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "denied"),
    }),
  },
};

export const ScopeDenied: Story = {
  args: {
    initialModel: model({
      recordState: {
        ...commandState(recordDraft, "record", "denied"),
        error: {
          success: false,
          error_code: "SCOPE_DENIED",
          safe_message:
            "This operator is outside the permitted fixture location scope.",
        },
      },
    }),
  },
};

export const AmbiguousTransport: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "ambiguous_transport"),
    }),
  },
};

export const SessionExpired: Story = {
  args: {
    authState: {
      status: "session_expired",
      safeMessage: "The local Auth session expired.",
    },
    initialModel: model({
      recordState: commandState(recordDraft, "record", "session_expired"),
      applyState: commandState(applyDraft, "apply", "session_expired"),
    }),
  },
};

export const CommandAuditTimeline: Story = {
  args: {
    initialModel: model({
      recordState: commandState(recordDraft, "record", "success"),
      evidenceId,
      timeline: {
        status: "success",
        data: {
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
        },
      },
    }),
  },
};
