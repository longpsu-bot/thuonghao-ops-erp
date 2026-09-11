import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  ConfirmedNeedApi,
  ConfirmedNeedLine,
  ConfirmedNeedWorkbenchData,
  JsonValue,
  NeedGenerationApi,
  NeedGenerationWorkbenchData,
  PlanningInputPreflightData,
  PreflightApi,
} from "../bridges/confirmedNeed";
export const reviewDate = "2026-09-07";
export function reviewSuccess(data: Record<string, unknown>): AtlasRpcResult {
  return {
    kind: "success",
    response: {
      success: true,
      ...structuredClone(data),
    } as AtlasSuccessEnvelope,
  };
}
export function reviewFailure(
  code = "CAPABILITY_DENIED",
  certainty = "NO_BUSINESS_WRITE",
): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: code,
      safe_message: "Không thể thực hiện yêu cầu. Hãy tải lại dữ liệu.",
      retryable: true,
      write_certainty: certainty,
    },
  } as AtlasRpcResult;
}
export function reviewLine(index = 0): ConfirmedNeedLine {
  return {
    confirmed_need_line_id: `line-${index}`,
    current_revision_id: `revision-${index}`,
    current_revision_number: 1,
    service_date: reviewDate,
    customer: { id: "customer", name: "Khối trường" },
    school: {
      id: `school-${index % 2}`,
      name: index % 2 ? "Trường Trần Quốc Toản" : "Trường Nguyễn Du",
    },
    delivery_location: { id: `location-${index % 2}`, name: "Bếp chính" },
    ingredient: {
      id: `ingredient-${index}`,
      name: ["Gạo thơm", "Thịt heo", "Cà rốt", "Dầu ăn", "Rau cải", "Trứng gà"][
        index % 6
      ]!,
    },
    controlled_unit: {
      id: "unit-kg",
      code: "kg",
      name: "Kilôgam",
      status: "ACTIVE",
    },
    theoretical_quantity: "10.250000",
    proposed_confirmed_quantity: "10.250000",
    current_decision_id: `decision-${index}`,
    current_decision_number: 1,
    current_decision_kind: "PROPOSAL_ACCEPTED",
    confirmed_quantity_after: "10.250000",
    confirmation_state: "CONFIRMED_CURRENT",
    effective_policy: {
      root_id: "policy",
      revision_id: "policy-revision",
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
  };
}
export function reviewBatch(): ConfirmedNeedWorkbenchData {
  return {
    confirmed_need_batch_id: "batch-current",
    source_kind: "NEED_GENERATION",
    batch_status: "DRAFT_REVIEW",
    batch_version: 4,
    authoritative_batch_status: "DRAFT_REVIEW",
    editing_allowed: true,
    validation_allowed: false,
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
      run_id: "run-current",
      run_version: 3,
      release_snapshot_id: "snapshot-current",
    },
    service_period: { period_start: reviewDate, period_end: reviewDate },
    line_counts: {
      total: 6,
      unreviewed: 0,
      confirmed: 6,
      adjusted: 0,
      carried_forward: 0,
      needs_review: 0,
      changed: 0,
      new: 0,
      removed: 0,
    },
    blockers: [],
    warnings: [],
    allowed_actions: {
      preview_confirmation: false,
      confirm_quantities: false,
      approve_confirmed_needs: false,
      release_confirmed_needs_for_purchase_handoff: false,
      save_confirmed_needs: true,
      release_confirmed_needs: false,
    },
    disabled_reason_codes: {
      approve_confirmed_needs: null,
      release_confirmed_needs_for_purchase_handoff: null,
      save_confirmed_needs: null,
      release_confirmed_needs: null,
    },
    disabled_reasons: {
      preview_confirmation: null,
      confirm_quantities: null,
      approve_confirmed_needs: null,
      release_confirmed_needs_for_purchase_handoff: null,
      save_confirmed_needs: null,
      release_confirmed_needs: null,
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
    pagination: { offset: 0, limit: 10000, total_lines: 6, has_more: false },
    lines: Array.from({ length: 6 }, (_, index) => reviewLine(index)),
  };
}
export function reviewPreflight(): PlanningInputPreflightData {
  const source = {
    selection_state: "SELECTED" as const,
    coverage: "COVERS" as const,
    source_current: true,
    selected: null,
    candidates: [],
    safe_message: "Dữ liệu đã sẵn sàng.",
  };
  return {
    period_start: reviewDate,
    period_end: reviewDate,
    readiness_state: "READY",
    source_evidence: {
      weekly_menu: source,
      attendance: source,
      pantry: source,
    },
    issues: [],
    blocking_issue_count: 0,
    downstream_currentness: "CURRENT",
    current_need: {
      confirmed_need_batch_id: "batch-current",
      confirmed_need_batch_status: "DRAFT_REVIEW",
      confirmed_need_batch_version: 4,
      need_generation_run_id: "run-current",
      need_generation_run_version: 3,
      need_generation_run_status: "RELEASED_FOR_CONFIRMATION",
    },
  };
}
export function reviewNeed(): NeedGenerationWorkbenchData {
  return {
    period: { period_start: reviewDate, period_end: reviewDate },
    planning_input_set: null,
    current_evaluation: null,
    source_evidence: { weekly_menu: {}, attendance: {}, pantry: {} },
    terminal_run_id: "run-current",
    selected_run: {
      need_generation_run_id: "run-current",
      attempt_ordinal: 1,
      predecessor_need_generation_run_id: null,
      status: "RELEASED_FOR_CONFIRMATION",
      version: 3,
      generated_line_count: 2,
      blocking_issue_count: 0,
      warning_count: 0,
      generated_at: "2026-09-07T02:00:00Z",
      validated_at: null,
      released_at: null,
      invalidated_at: null,
    },
    blocking_issues: [],
    warnings: [],
    grouped_requirements: [
      {
        service_date: reviewDate,
        customer_id: "customer",
        school_id: "school-0",
        school_name: "Trường Nguyễn Du",
        delivery_location_id: "location-0",
        delivery_location_name: "Bếp chính",
        ingredient_id: "ingredient-0",
        ingredient_name: "Gạo thơm",
        unit_id: "unit-kg",
        unit_name: "kg",
        total_theoretical_quantity: 10.25,
        recipe_derived_quantity: 8.25,
        pantry_direct_quantity: 2,
        active_contribution_count: 2,
        removed_contribution_count: 0,
        warning_count: 0,
      },
    ],
    atomic_detail: [],
    run_history: [],
    materialization: {
      confirmed_need_batch_id: "batch-current",
      confirmed_need_batch_version: 4,
      confirmed_need_status: "DRAFT_REVIEW",
      materialization_mode: "NONE",
    },
    allowed_actions: {
      create: false,
      validate: false,
      release: false,
      materialize: false,
      invalidate: false,
    },
    disabled_reasons: {},
    pagination: { offset: 0, limit: 25, total_groups: 1, has_more: false },
  };
}
export type ConfirmedReviewScenario =
  | "normal"
  | "loading"
  | "read_failure"
  | "no_demand"
  | "blocked"
  | "not_generated"
  | "outdated"
  | "legacy_overlap"
  | "correction_blocked"
  | "needs_review"
  | "carried"
  | "adjusted"
  | "released"
  | "historical"
  | "stale"
  | "unknown"
  | "recovery_failed"
  | "missing_readback";
// Review snapshots are explicit fixtures, never a simulation of backend rules.
export function createConfirmedNeedReviewFixture(
  scenario: ConfirmedReviewScenario = "normal",
) {
  const batch = reviewBatch();
  const preflight = reviewPreflight();
  const need = reviewNeed();
  if (["needs_review", "not_generated", "outdated"].includes(scenario)) {
    Object.assign(batch.lines[0]!, {
      current_decision_id: null,
      confirmed_quantity_after: null,
      confirmation_state: "NEW",
    });
    batch.line_counts.needs_review = 1;
    batch.line_counts.unreviewed = 1;
    batch.line_counts.confirmed = 5;
  }
  if (scenario === "carried")
    batch.lines[0]!.confirmation_state = "CARRIED_FORWARD";
  if (scenario === "adjusted") {
    batch.lines[0]!.confirmed_quantity_after = "11.000000";
    batch.line_counts.adjusted = 1;
  }
  if (scenario === "historical")
    batch.lines[0]!.confirmed_quantity_after = "10.123456";
  if (scenario === "released" || scenario === "correction_blocked") {
    batch.authoritative_batch_status = "RELEASED_FOR_PURCHASE_HANDOFF";
    batch.editing_allowed = false;
    batch.allowed_actions.save_confirmed_needs = false;
    preflight.current_need!.confirmed_need_batch_status =
      "RELEASED_FOR_PURCHASE_HANDOFF";
  }
  if (scenario === "not_generated") {
    preflight.downstream_currentness = "NOT_GENERATED";
    preflight.current_need = null;
  }
  if (scenario === "outdated" || scenario === "correction_blocked")
    preflight.downstream_currentness = "OUTDATED";
  if (scenario === "legacy_overlap")
    preflight.downstream_currentness = "LEGACY_OVERLAP";
  if (scenario === "blocked" || scenario === "no_demand") {
    preflight.readiness_state = "BLOCKED";
    preflight.current_need = null;
    preflight.downstream_currentness = "NOT_GENERATED";
    preflight.blocking_issue_count = 1;
    preflight.issues = [
      {
        severity: "BLOCKING",
        issue_code:
          scenario === "no_demand"
            ? "NO_NEED_SOURCE_FOR_SERVICE_DATE"
            : "ATTENDANCE_MISSING",
        message: "Cần lưu sĩ số trước khi tạo nhu cầu.",
        input_type: "attendance",
        school_id: null,
        service_date: reviewDate,
      },
    ];
  }
  const saved = reviewBatch();
  saved.batch_version = 5;
  saved.lines[0] = {
    ...saved.lines[0]!,
    confirmed_quantity_after: "12.500000",
    current_decision_id: "decision-saved",
    current_revision_id: "revision-saved",
  };
  let saveAttempted = false;
  let savedSnapshot = false;
  let generated = false;
  const preflightApi: PreflightApi = {
    async preflight() {
      if (scenario === "loading") return new Promise<AtlasRpcResult>(() => {});
      if (scenario === "read_failure") return reviewFailure();
      return reviewSuccess({
        preflight: generated ? reviewPreflight() : preflight,
      });
    },
  };
  const confirmedNeedApi: ConfirmedNeedApi = {
    async getReview() {
      if (saveAttempted && scenario === "recovery_failed")
        return reviewFailure();
      return reviewSuccess({ workbench: savedSnapshot ? saved : batch });
    },
    async save() {
      saveAttempted = true;
      if (scenario === "stale")
        return reviewFailure(
          "STALE_CONFIRMED_NEED_BATCH",
          "NO_COMMITTED_CHANGE",
        );
      if (scenario === "unknown" || scenario === "recovery_failed")
        return reviewFailure("UNREVIEWED_RESULT", "UNKNOWN");
      if (scenario === "missing_readback") return reviewSuccess({});
      savedSnapshot = true;
      return reviewSuccess({ authoritative_readback: saved });
    },
  };
  const needGenerationApi: NeedGenerationApi = {
    async execute() {
      generated = true;
      return reviewSuccess({
        authoritative_readback: {
          preflight: reviewPreflight(),
          need_generation: need,
        },
        result_counts: { needs_review_count: 1, carried_forward_count: 5 },
      });
    },
    async getWorkbench(_a, _c, _s, _e, _r, _f, offset, limit, group) {
      return reviewSuccess({
        workbench: {
          ...need,
          pagination: { ...need.pagination, offset, limit },
          atomic_detail: group
            ? [
                {
                  theoretical_need_line_id: "atomic-private",
                  contribution_family: "RECIPE_DERIVED",
                  theoretical_quantity: 8.25,
                  unit_id: "unit-kg",
                  unit_name: "kg",
                  disposition: "ACTIVE",
                  dish_name: "Cơm trắng",
                  warning_references: [],
                },
                {
                  theoretical_need_line_id: "atomic-private-2",
                  contribution_family: "PANTRY_DIRECT",
                  theoretical_quantity: 2,
                  unit_id: "unit-kg",
                  unit_name: "kg",
                  disposition: "ACTIVE",
                  pantry_purpose: "Bổ sung suất ăn",
                  pantry_source_reference: "Yêu cầu bếp",
                  warning_references: [],
                },
              ]
            : [],
        } as unknown as JsonValue,
      });
    },
  };
  return {
    batch,
    preflight,
    need,
    preflightApi,
    confirmedNeedApi,
    needGenerationApi,
  };
}
