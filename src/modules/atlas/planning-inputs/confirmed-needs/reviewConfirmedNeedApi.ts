import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";
import type { AtlasReviewScenario } from "../../review/reviewMode";
import type {
  ConfirmedNeedApi,
  ConfirmedNeedCommandRequest,
} from "./confirmedNeedApi";
import type { ConfirmedNeedWorkbenchData } from "./confirmedNeedModel";

const batchId = "c4500000-0000-0000-0000-000000000001";
const revisionOne = "c4510000-0000-0000-0000-000000000001";
const revisionTwo = "c4510000-0000-0000-0000-000000000002";

function fixture(): ConfirmedNeedWorkbenchData {
  return {
    confirmed_need_batch_id: batchId,
    source_kind: "NEED_GENERATION",
    batch_status: "DRAFT_REVIEW",
    batch_version: 1,
    need_generation_source: {
      run_id: "c4100000-0000-0000-0000-000000000001",
      run_version: 3,
      release_snapshot_id: "c4400000-0000-0000-0000-000000000001",
    },
    service_period: { period_start: "2026-08-03", period_end: "2026-08-09" },
    line_counts: { total: 2, unreviewed: 2, confirmed: 0, adjusted: 0 },
    blockers: [],
    warnings: [],
    allowed_actions: {
      preview_confirmation: true,
      confirm_quantities: true,
    },
    disabled_reasons: {
      preview_confirmation: null,
      confirm_quantities: null,
    },
    pagination: { offset: 0, limit: 100, total_lines: 2, has_more: false },
    lines: [
      {
        confirmed_need_line_id: "c4520000-0000-0000-0000-000000000001",
        current_revision_id: revisionOne,
        current_revision_number: 1,
        service_date: "2026-08-03",
        customer: {
          id: "a1000000-0000-0000-0000-000000000001",
          name: "Khối trường Atlas",
        },
        school: {
          id: "a1100000-0000-0000-0000-000000000001",
          name: "Trường Tiểu học An Bình",
        },
        delivery_location: {
          id: "a1200000-0000-0000-0000-000000000001",
          name: "Bếp chính",
        },
        ingredient: {
          id: "a1300000-0000-0000-0000-000000000001",
          name: "Gạo thơm",
        },
        controlled_unit: {
          id: "a1400000-0000-0000-0000-000000000001",
          code: "kg",
          name: "Kilôgam",
          status: "ACTIVE",
        },
        theoretical_quantity: "10.250000",
        proposed_confirmed_quantity: "10.250000",
        current_decision_id: null,
        current_decision_number: null,
        current_decision_kind: null,
        confirmed_quantity_after: null,
        effective_policy: {
          root_id: "c4600000-0000-0000-0000-000000000001",
          revision_id: "c4610000-0000-0000-0000-000000000001",
          revision_number: 1,
          planning_step: "0.250000",
          status: "ACTIVE",
          effective_from: "2026-01-01",
          effective_to: null,
        },
        source_membership_count: 2,
        source_stale: false,
        blockers: [],
        warnings: [],
        decision_history: [],
      },
      {
        confirmed_need_line_id: "c4520000-0000-0000-0000-000000000002",
        current_revision_id: revisionTwo,
        current_revision_number: 1,
        service_date: "2026-08-04",
        customer: {
          id: "a1000000-0000-0000-0000-000000000001",
          name: "Khối trường Atlas",
        },
        school: {
          id: "a1100000-0000-0000-0000-000000000001",
          name: "Trường Tiểu học An Bình",
        },
        delivery_location: {
          id: "a1200000-0000-0000-0000-000000000001",
          name: "Bếp chính",
        },
        ingredient: {
          id: "a1300000-0000-0000-0000-000000000002",
          name: "Cà rốt",
        },
        controlled_unit: {
          id: "a1400000-0000-0000-0000-000000000001",
          code: "kg",
          name: "Kilôgam",
          status: "ACTIVE",
        },
        theoretical_quantity: "5.000000",
        proposed_confirmed_quantity: "5.000000",
        current_decision_id: null,
        current_decision_number: null,
        current_decision_kind: null,
        confirmed_quantity_after: null,
        effective_policy: {
          root_id: "c4600000-0000-0000-0000-000000000001",
          revision_id: "c4610000-0000-0000-0000-000000000001",
          revision_number: 1,
          planning_step: "0.250000",
          status: "ACTIVE",
          effective_from: "2026-01-01",
          effective_to: null,
        },
        source_membership_count: 1,
        source_stale: false,
        blockers: [],
        warnings: [],
        decision_history: [],
      },
    ],
  };
}

function success(payload: Record<string, JsonValue>): AtlasRpcResult {
  return { kind: "success", response: { success: true, ...payload } };
}

function backendError(code: string): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: code,
      safe_message: "Yêu cầu xem thử đã bị từ chối an toàn.",
    },
  };
}

export function createReviewConfirmedNeedApi(
  scenario: AtlasReviewScenario,
): ConfirmedNeedApi {
  let state = fixture();
  const receipts = new Map<string, AtlasRpcResult>();

  return {
    async getReview(_subject, correlationId, requestedBatchId) {
      if (scenario === "permission_denied")
        return backendError("CAPABILITY_DENIED");
      if (scenario === "server_error")
        return {
          kind: "transport_error",
          diagnostic: {
            code: "NETWORK_FAILURE",
            safeMessage: "Không thể kết nối dữ liệu xem thử.",
          },
        };
      if (requestedBatchId !== batchId)
        return backendError("CONFIRMED_NEED_BATCH_NOT_FOUND");
      return success({
        contract_version: "RMVP-05.v1",
        correlation_id: correlationId,
        workbench: structuredClone(state) as unknown as JsonValue,
      });
    },
    async preview(request) {
      if (scenario === "stale")
        return backendError("STALE_CONFIRMED_NEED_BATCH");
      const lines = request.payload.lines.map((line) => {
        const current = state.lines.find(
          (item) => item.confirmed_need_line_id === line.confirmed_need_line_id,
        )!;
        const adjusted =
          line.proposed_confirmed_quantity !==
          current.proposed_confirmed_quantity;
        return {
          confirmed_need_line_id: line.confirmed_need_line_id,
          current_revision_id: current.current_revision_id,
          current_revision_number: current.current_revision_number,
          controlled_unit_id: current.controlled_unit.id,
          controlled_unit_status: current.controlled_unit.status,
          theoretical_quantity_before: current.theoretical_quantity,
          proposed_quantity_before: current.proposed_confirmed_quantity,
          confirmed_quantity_after: line.proposed_confirmed_quantity,
          decision_kind: adjusted
            ? "ADJUSTED_QUANTITY_CONFIRMED"
            : "UNCHANGED_PROPOSAL_ACCEPTED",
          reason_code: line.reason_code,
          reason_note: line.reason_note,
          policy_root_id: current.effective_policy!.root_id,
          policy_revision_id: current.effective_policy!.revision_id,
          policy_revision_number: 1,
          planning_step: "0.250000",
          planning_tick_count: adjusted ? "21" : "41",
          successor_revision_required: adjusted,
          blockers: [],
          warnings: [],
        };
      });
      return success({
        contract_version: "RMVP-05.v1",
        preview: {
          success: true,
          confirmed_need_batch_id: batchId,
          expected_batch_version: state.batch_version,
          actual_batch_version: state.batch_version,
          ordered_preview_lines: lines,
          blockers: [],
          warnings: [],
          preview_hash: "a".repeat(64),
          write_certainty: "NO_WRITE",
        } as unknown as JsonValue,
      });
    },
    async confirm(request: ConfirmedNeedCommandRequest) {
      const replay = receipts.get(request.command_id);
      if (replay) return structuredClone(replay);
      state = {
        ...state,
        batch_version: state.batch_version + 1,
        line_counts: {
          total: 2,
          unreviewed: 0,
          confirmed: 2,
          adjusted: 1,
        },
        lines: state.lines.map((line) => {
          const selected = request.payload.lines.find(
            (item) =>
              item.confirmed_need_line_id === line.confirmed_need_line_id,
          );
          if (!selected) return line;
          const adjusted =
            selected.proposed_confirmed_quantity !==
            line.proposed_confirmed_quantity;
          return {
            ...line,
            current_revision_id: adjusted
              ? "c4510000-0000-0000-0000-000000000010"
              : line.current_revision_id,
            current_revision_number: adjusted
              ? 2
              : line.current_revision_number,
            current_decision_id: `c4530000-0000-0000-0000-00000000000${adjusted ? 2 : 1}`,
            current_decision_number: 1,
            current_decision_kind: adjusted
              ? "ADJUSTED_QUANTITY_CONFIRMED"
              : "UNCHANGED_PROPOSAL_ACCEPTED",
            confirmed_quantity_after: selected.proposed_confirmed_quantity,
          };
        }),
      };
      const result = success({
        contract_version: "RMVP-05.v1",
        command_id: request.command_id,
        safe_operator_message:
          "Đã xác nhận số lượng với bằng chứng quyết định bất biến.",
        authoritative_readback: structuredClone(state) as unknown as JsonValue,
      });
      receipts.set(request.command_id, structuredClone(result));
      return result;
    },
  };
}
