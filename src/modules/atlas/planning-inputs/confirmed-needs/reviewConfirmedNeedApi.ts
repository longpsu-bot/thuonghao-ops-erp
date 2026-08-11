import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";
import type { AtlasReviewScenario } from "../../review/reviewMode";
import type {
  ConfirmedNeedApi,
  ConfirmedNeedCommandRequest,
} from "./confirmedNeedApi";
import type {
  ConfirmedNeedValidationIssue,
  ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";

const batchId = "c4500000-0000-0000-0000-000000000001";
const revisionOne = "c4510000-0000-0000-0000-000000000001";
const revisionTwo = "c4510000-0000-0000-0000-000000000002";

export function createReviewConfirmedNeedFixture(
  lineCount = 2,
): ConfirmedNeedWorkbenchData {
  const workbench: ConfirmedNeedWorkbenchData = {
    confirmed_need_batch_id: batchId,
    source_kind: "NEED_GENERATION",
    batch_status: "DRAFT_REVIEW",
    batch_version: 1,
    authoritative_batch_status: "DRAFT_REVIEW",
    editing_allowed: true,
    validation_allowed: true,
    validation_disabled_reason: null,
    validation: {
      latest_attempt_id: null,
      latest_attempt_number: null,
      latest_outcome: null,
      evaluated_version: null,
      resulting_version: null,
      evaluated_actor: null,
      evaluated_at: null,
      validated_actor: null,
      validated_at: null,
      validation_fingerprint: null,
      blocking_count: 0,
      warning_count: 0,
      grouped_issues: { blocking: [], warnings: [] },
    },
    need_generation_source: {
      run_id: "c4100000-0000-0000-0000-000000000001",
      run_version: 3,
      release_snapshot_id: "c4400000-0000-0000-0000-000000000001",
    },
    service_period: { period_start: "2026-08-03", period_end: "2026-08-09" },
    line_counts: {
      total: lineCount,
      unreviewed: lineCount,
      confirmed: 0,
      adjusted: 0,
    },
    blockers: [],
    warnings: [],
    allowed_actions: {
      preview_confirmation: true,
      confirm_quantities: true,
      approve_confirmed_needs: false,
      release_confirmed_needs_for_purchase_handoff: false,
      save_confirmed_needs: true,
      release_confirmed_needs: false,
    },
    disabled_reason_codes: {
      approve_confirmed_needs: "APPROVAL_BATCH_NOT_VALIDATED",
      release_confirmed_needs_for_purchase_handoff:
        "RELEASE_BATCH_NOT_APPROVED",
      save_confirmed_needs: null,
      release_confirmed_needs: "RELEASE_INCOMPLETE",
    },
    disabled_reasons: {
      preview_confirmation: null,
      confirm_quantities: null,
      approve_confirmed_needs: "Lô nhu cầu chưa ở trạng thái đã kiểm tra.",
      release_confirmed_needs_for_purchase_handoff:
        "Lô nhu cầu chưa được phê duyệt.",
      save_confirmed_needs: null,
      release_confirmed_needs:
        "Còn dòng cần xử lý trước khi chuyển sang lên đơn.",
    },
    approval: {
      current_snapshot_id: null,
      approved_version: null,
      source_validated_version: null,
      validation_attempt_id: null,
      validation_attempt_fingerprint: null,
      validated_fact_fingerprint: null,
      approved_actor: null,
      approved_at: null,
      line_count: 0,
      warning_count: 0,
    },
    release: {
      current_release_id: null,
      approval_snapshot_id: null,
      source_approved_version: null,
      resulting_released_version: null,
      released_actor: null,
      released_at: null,
    },
    facts_changed_since_validation: null,
    facts_changed_since_approval: null,
    lifecycle_history: [],
    pagination: {
      offset: 0,
      limit: 100,
      total_lines: lineCount,
      has_more: lineCount > 100,
    },
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
          id: "a1100000-0000-0000-0000-000000000002",
          name: "Trường Mầm non Hoa Sen",
        },
        delivery_location: {
          id: "a1200000-0000-0000-0000-000000000002",
          name: "Bếp phụ",
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
        validation_issues: { blocking: [], warnings: [] },
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
        validation_issues: { blocking: [], warnings: [] },
        decision_history: [],
      },
    ],
  };
  if (lineCount > workbench.lines.length) {
    const templates = [...workbench.lines];
    for (let index = templates.length; index < lineCount; index += 1) {
      const template = templates[index % templates.length]!;
      const suffix = String(index + 1).padStart(12, "0");
      workbench.lines.push({
        ...structuredClone(template),
        confirmed_need_line_id: `c4520000-0000-0000-0000-${suffix}`,
        current_revision_id: `c4510000-0000-0000-0000-${suffix}`,
        service_date: `2026-08-${String(3 + (index % 7)).padStart(2, "0")}`,
        ingredient: {
          ...template.ingredient,
          id: `a1300000-0000-0000-0000-${suffix}`,
          name: `${template.ingredient.name} ${index + 1}`,
        },
      });
    }
  } else workbench.lines = workbench.lines.slice(0, lineCount);
  return workbench;
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
  options: { lineCount?: number } = {},
): ConfirmedNeedApi {
  let state = createReviewConfirmedNeedFixture(options.lineCount ?? 2);
  const receipts = new Map<string, AtlasRpcResult>();

  return {
    async getReview(
      _subject,
      correlationId,
      requestedBatchId,
      _filters,
      lineOffset = 0,
      lineLimit = 100,
    ) {
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
      const paged = {
        ...structuredClone(state),
        lines: structuredClone(
          state.lines.slice(lineOffset, lineOffset + lineLimit),
        ),
        pagination: {
          offset: lineOffset,
          limit: lineLimit,
          total_lines: state.lines.length,
          has_more: lineOffset + lineLimit < state.lines.length,
        },
      };
      return success({
        contract_version: "RMVP-05.v1",
        correlation_id: correlationId,
        workbench: paged as unknown as JsonValue,
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
      const nextLines = state.lines.map((line) => {
        const selected = request.payload.lines.find(
          (item) => item.confirmed_need_line_id === line.confirmed_need_line_id,
        );
        if (!selected) return line;
        const adjusted =
          selected.proposed_confirmed_quantity !==
          line.proposed_confirmed_quantity;
        return {
          ...line,
          current_revision_id: adjusted
            ? crypto.randomUUID()
            : line.current_revision_id,
          current_revision_number: adjusted
            ? line.current_revision_number + 1
            : line.current_revision_number,
          current_decision_id: crypto.randomUUID(),
          current_decision_number: (line.current_decision_number ?? 0) + 1,
          current_decision_kind: adjusted
            ? "ADJUSTED_QUANTITY_CONFIRMED"
            : "UNCHANGED_PROPOSAL_ACCEPTED",
          confirmed_quantity_after: selected.proposed_confirmed_quantity,
        };
      });
      state = {
        ...state,
        batch_version: state.batch_version + 1,
        line_counts: {
          total: nextLines.length,
          unreviewed: nextLines.filter((line) => !line.current_decision_id)
            .length,
          confirmed: nextLines.filter((line) => line.current_decision_id)
            .length,
          adjusted: nextLines.filter(
            (line) =>
              line.current_decision_kind === "ADJUSTED_QUANTITY_CONFIRMED",
          ).length,
        },
        lines: nextLines,
      };
      const result = success({
        contract_version: "RMVP-05.v1",
        command_id: request.command_id,
        safe_operator_message: "Đã xác nhận số lượng.",
        authoritative_readback: structuredClone(state) as unknown as JsonValue,
      });
      receipts.set(request.command_id, structuredClone(result));
      return result;
    },
    async validate(request) {
      const replay = receipts.get(request.command_id);
      if (replay) return structuredClone(replay);
      const blockers: ConfirmedNeedValidationIssue[] = state.lines.flatMap(
        (line) =>
          line.current_decision_id
            ? []
            : [
                {
                  code: "CURRENT_DECISION_MISSING",
                  message: `Dòng ${line.confirmed_need_line_id} chưa có quyết định hiện hành.`,
                  confirmed_need_line_id: line.confirmed_need_line_id,
                  severity: "BLOCKING" as const,
                  sort_position: 1,
                },
              ],
      );
      const outcome = blockers.length ? "BLOCKED" : "VALIDATED";
      const warnings: ConfirmedNeedValidationIssue[] = blockers.length
        ? [
            {
              code: "UPSTREAM_WARNING_RETAINED",
              message: "Cảnh báo thượng nguồn được giữ lại.",
              confirmed_need_line_id: state.lines[0]!.confirmed_need_line_id,
              severity: "WARNING" as const,
              sort_position: blockers.length + 1,
            },
          ]
        : [];
      const attemptId = crypto.randomUUID();
      const at = new Date().toISOString();
      const nextVersion =
        outcome === "VALIDATED" ? state.batch_version + 1 : state.batch_version;
      state = {
        ...state,
        batch_status:
          outcome === "VALIDATED" ? "VALIDATED" : state.batch_status,
        authoritative_batch_status:
          outcome === "VALIDATED" ? "VALIDATED" : state.batch_status,
        batch_version: nextVersion,
        editing_allowed: outcome !== "VALIDATED",
        validation_allowed: outcome !== "VALIDATED",
        validation_disabled_reason:
          outcome === "VALIDATED"
            ? "Lô đã được kiểm tra; chờ phê duyệt."
            : null,
        validation: {
          latest_attempt_id: attemptId,
          latest_attempt_number: 1,
          latest_outcome: outcome,
          evaluated_version: request.expected_version,
          resulting_version: nextVersion,
          evaluated_actor: { id: "review-only-atlas-operator", name: "Lan" },
          evaluated_at: at,
          validated_actor:
            outcome === "VALIDATED"
              ? { id: "review-only-atlas-operator", name: "Lan" }
              : null,
          validated_at: outcome === "VALIDATED" ? at : null,
          validation_fingerprint: "b".repeat(64),
          blocking_count: blockers.length,
          warning_count: warnings.length,
          grouped_issues: { blocking: blockers, warnings },
        },
        allowed_actions: {
          ...state.allowed_actions,
          approve_confirmed_needs: outcome === "VALIDATED",
          release_confirmed_needs_for_purchase_handoff: false,
        },
        disabled_reason_codes: {
          ...state.disabled_reason_codes,
          approve_confirmed_needs:
            outcome === "VALIDATED" ? null : "APPROVAL_BATCH_NOT_VALIDATED",
          release_confirmed_needs_for_purchase_handoff:
            "RELEASE_BATCH_NOT_APPROVED",
        },
        disabled_reasons: {
          ...state.disabled_reasons,
          approve_confirmed_needs:
            outcome === "VALIDATED"
              ? null
              : "Lô nhu cầu chưa ở trạng thái đã kiểm tra.",
          release_confirmed_needs_for_purchase_handoff:
            "Lô nhu cầu chưa được phê duyệt.",
        },
        facts_changed_since_validation: false,
        lifecycle_history: [
          {
            evidence_kind: "VALIDATION",
            evidence_id: attemptId,
            outcome,
            source_version: request.expected_version,
            resulting_version: nextVersion,
            actor: { id: "review-only-atlas-operator", name: "Lan" },
            occurred_at: at,
            reason_code: "BATCH_VALIDATION_REQUESTED",
            warning_count: warnings.length,
          },
          ...state.lifecycle_history,
        ],
        lines: state.lines.map((line) => ({
          ...line,
          validation_issues: {
            blocking: blockers.filter(
              (issue) =>
                issue.confirmed_need_line_id === line.confirmed_need_line_id,
            ),
            warnings: warnings.filter(
              (issue) =>
                issue.confirmed_need_line_id === line.confirmed_need_line_id,
            ),
          },
        })),
      };
      const result = success({
        contract_version: "RMVP-06.v1",
        command_id: request.command_id,
        validation_status: outcome,
        validation_attempt_id: attemptId,
        blocking_issue_count: blockers.length,
        warning_count: warnings.length,
        safe_operator_message:
          outcome === "VALIDATED"
            ? "Đã kiểm tra; chờ phê duyệt"
            : "Chưa đạt điều kiện kiểm tra",
        authoritative_readback: structuredClone(state) as unknown as JsonValue,
      });
      receipts.set(request.command_id, structuredClone(result));
      return result;
    },
    async approve(request) {
      const replay = receipts.get(request.command_id);
      if (replay) return structuredClone(replay);
      const snapshotId = crypto.randomUUID();
      const at = new Date().toISOString();
      const priorVersion = state.batch_version;
      state = {
        ...state,
        batch_status: "APPROVED",
        authoritative_batch_status: "APPROVED",
        batch_version: priorVersion + 1,
        allowed_actions: {
          ...state.allowed_actions,
          approve_confirmed_needs: false,
          release_confirmed_needs_for_purchase_handoff: true,
        },
        disabled_reason_codes: {
          ...state.disabled_reason_codes,
          approve_confirmed_needs: "APPROVAL_ALREADY_COMPLETED",
          release_confirmed_needs_for_purchase_handoff: null,
        },
        disabled_reasons: {
          ...state.disabled_reasons,
          approve_confirmed_needs: "Lô nhu cầu đã được phê duyệt.",
          release_confirmed_needs_for_purchase_handoff: null,
        },
        approval: {
          current_snapshot_id: snapshotId,
          approved_version: priorVersion + 1,
          source_validated_version: priorVersion,
          validation_attempt_id: state.validation.latest_attempt_id,
          validation_attempt_fingerprint:
            state.validation.validation_fingerprint,
          validated_fact_fingerprint: "c".repeat(64),
          approved_actor: { id: "review-only-atlas-operator", name: "Lan" },
          approved_at: at,
          line_count: state.line_counts.total,
          warning_count: state.validation.warning_count,
        },
        facts_changed_since_approval: false,
        lifecycle_history: [
          {
            evidence_kind: "APPROVAL",
            evidence_id: snapshotId,
            outcome: "APPROVED",
            source_version: priorVersion,
            resulting_version: priorVersion + 1,
            actor: { id: "review-only-atlas-operator", name: "Lan" },
            occurred_at: at,
            reason_code: "CONFIRMED_NEED_APPROVAL_REQUESTED",
            warning_count: state.validation.warning_count,
          },
          ...state.lifecycle_history,
        ],
      };
      const result = success({
        contract_version: "RMVP-07.v1",
        command_name: "approve_confirmed_needs",
        command_id: request.command_id,
        safe_operator_message: "Đã phê duyệt; đang chờ phát hành.",
        authoritative_readback: structuredClone(state) as unknown as JsonValue,
      });
      receipts.set(request.command_id, structuredClone(result));
      return result;
    },
    async release(request) {
      const replay = receipts.get(request.command_id);
      if (replay) return structuredClone(replay);
      const releaseId = crypto.randomUUID();
      const at = new Date().toISOString();
      const priorVersion = state.batch_version;
      state = {
        ...state,
        batch_status: "RELEASED_FOR_PURCHASE_HANDOFF",
        authoritative_batch_status: "RELEASED_FOR_PURCHASE_HANDOFF",
        batch_version: priorVersion + 1,
        allowed_actions: {
          ...state.allowed_actions,
          approve_confirmed_needs: false,
          release_confirmed_needs_for_purchase_handoff: false,
        },
        disabled_reason_codes: {
          ...state.disabled_reason_codes,
          approve_confirmed_needs: "APPROVAL_ALREADY_COMPLETED",
          release_confirmed_needs_for_purchase_handoff:
            "RELEASE_ALREADY_COMPLETED",
        },
        disabled_reasons: {
          ...state.disabled_reasons,
          approve_confirmed_needs: "Lô nhu cầu đã được phê duyệt.",
          release_confirmed_needs_for_purchase_handoff:
            "Lô nhu cầu đã được phát hành.",
        },
        release: {
          current_release_id: releaseId,
          approval_snapshot_id: state.approval.current_snapshot_id,
          source_approved_version: priorVersion,
          resulting_released_version: priorVersion + 1,
          released_actor: { id: "review-only-atlas-operator", name: "Lan" },
          released_at: at,
        },
        lifecycle_history: [
          {
            evidence_kind: "RELEASE",
            evidence_id: releaseId,
            outcome: "RELEASED_FOR_PURCHASE_HANDOFF",
            source_version: priorVersion,
            resulting_version: priorVersion + 1,
            actor: { id: "review-only-atlas-operator", name: "Lan" },
            occurred_at: at,
            reason_code: "CONFIRMED_NEED_RELEASE_REQUESTED",
            warning_count: state.approval.warning_count,
          },
          ...state.lifecycle_history,
        ],
      };
      const result = success({
        contract_version: "RMVP-07.v1",
        command_name: "release_confirmed_needs_for_purchase_handoff",
        command_id: request.command_id,
        safe_operator_message: "Đã phát hành sang bước lên đơn.",
        authoritative_readback: structuredClone(state) as unknown as JsonValue,
      });
      receipts.set(request.command_id, structuredClone(result));
      return result;
    },
    async save(request) {
      const replay = receipts.get(request.command_id);
      if (replay) return structuredClone(replay);
      if (scenario === "stale")
        return backendError("STALE_CONFIRMED_NEED_BATCH");
      const nextLines = state.lines.map((line) => {
        const changed = request.payload.lines.find(
          (candidate) =>
            candidate.confirmed_need_line_id === line.confirmed_need_line_id,
        );
        if (!changed) return line;
        const adjusted =
          changed.proposed_confirmed_quantity !==
          line.proposed_confirmed_quantity;
        return {
          ...line,
          current_revision_id: adjusted
            ? crypto.randomUUID()
            : line.current_revision_id,
          current_revision_number: adjusted
            ? line.current_revision_number + 1
            : line.current_revision_number,
          current_decision_id: crypto.randomUUID(),
          current_decision_number: (line.current_decision_number ?? 0) + 1,
          current_decision_kind: adjusted
            ? "ADJUSTED_QUANTITY_CONFIRMED"
            : "UNCHANGED_PROPOSAL_ACCEPTED",
          confirmed_quantity_after: changed.proposed_confirmed_quantity,
        };
      });
      state = {
        ...state,
        batch_version: state.batch_version + 1,
        lines: nextLines,
        allowed_actions: {
          ...state.allowed_actions,
          save_confirmed_needs: true,
          release_confirmed_needs: true,
        },
        disabled_reason_codes: {
          ...state.disabled_reason_codes,
          save_confirmed_needs: null,
          release_confirmed_needs: null,
        },
        disabled_reasons: {
          ...state.disabled_reasons,
          save_confirmed_needs: null,
          release_confirmed_needs: null,
        },
        line_counts: {
          total: nextLines.length,
          unreviewed: nextLines.filter((line) => !line.current_decision_id)
            .length,
          confirmed: nextLines.filter((line) => line.current_decision_id)
            .length,
          adjusted: nextLines.filter(
            (line) =>
              line.current_decision_kind === "ADJUSTED_QUANTITY_CONFIRMED",
          ).length,
        },
      };
      const result = success({
        contract_version: "RMVP-05.v2",
        command_id: request.command_id,
        safe_operator_message: "Đã lưu thay đổi.",
        authoritative_readback: structuredClone(state) as unknown as JsonValue,
      });
      receipts.set(request.command_id, structuredClone(result));
      return result;
    },
    async releaseSaved(request) {
      const replay = receipts.get(request.command_id);
      if (replay) return structuredClone(replay);
      if (scenario === "stale")
        return backendError("STALE_CONFIRMED_NEED_BATCH");
      if (state.line_counts.unreviewed > 0)
        return backendError("CONFIRMED_NEED_INCOMPLETE");
      const now = new Date().toISOString();
      const validationId = crypto.randomUUID();
      const approvalId = crypto.randomUUID();
      const releaseId = crypto.randomUUID();
      const resultingVersion = state.batch_version + 3;
      state = {
        ...state,
        batch_status: "RELEASED_FOR_PURCHASE_HANDOFF",
        authoritative_batch_status: "RELEASED_FOR_PURCHASE_HANDOFF",
        batch_version: resultingVersion,
        editing_allowed: false,
        validation_allowed: false,
        allowed_actions: {
          preview_confirmation: false,
          confirm_quantities: false,
          approve_confirmed_needs: false,
          release_confirmed_needs_for_purchase_handoff: false,
          save_confirmed_needs: false,
          release_confirmed_needs: false,
        },
        disabled_reason_codes: {
          ...state.disabled_reason_codes,
          save_confirmed_needs: "SAVE_BATCH_NOT_EDITABLE",
          release_confirmed_needs: "RELEASE_ALREADY_COMPLETED",
        },
        disabled_reasons: {
          ...state.disabled_reasons,
          save_confirmed_needs: "Dữ liệu này không còn cho phép chỉnh sửa.",
          release_confirmed_needs: "Dữ liệu đã được chuyển sang lên đơn.",
        },
        validation: {
          ...state.validation,
          latest_attempt_id: validationId,
          latest_attempt_number: 1,
          latest_outcome: "VALIDATED",
          evaluated_version: request.expected_version,
          resulting_version: request.expected_version + 1,
          blocking_count: 0,
        },
        approval: {
          ...state.approval,
          current_snapshot_id: approvalId,
          approved_version: request.expected_version + 2,
          source_validated_version: request.expected_version + 1,
          validation_attempt_id: validationId,
          line_count: state.line_counts.total,
          approved_actor: { id: "review-only-atlas-operator", name: "Lan" },
          approved_at: now,
        },
        release: {
          current_release_id: releaseId,
          approval_snapshot_id: approvalId,
          source_approved_version: request.expected_version + 2,
          resulting_released_version: resultingVersion,
          released_actor: { id: "review-only-atlas-operator", name: "Lan" },
          released_at: now,
        },
      };
      const result = success({
        contract_version: "RMVP-07.v2",
        command_id: request.command_id,
        safe_operator_message: "Đã chuyển sang lên đơn.",
        authoritative_readback: structuredClone(state) as unknown as JsonValue,
      });
      receipts.set(request.command_id, structuredClone(result));
      return result;
    },
  };
}
