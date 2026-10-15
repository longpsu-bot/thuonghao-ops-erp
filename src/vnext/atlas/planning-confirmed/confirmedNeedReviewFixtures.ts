import type { ConfirmedNeedCorrectionPayload } from "../bridges/confirmedNeed";
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
export const oct12ReviewDate = "2026-10-12";
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
    proposal_rounding_step: "0.250000",
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
  | "oct12_school_first"
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
  | "missing_readback"
  | "certified_shape";
// Review snapshots are explicit fixtures, never a simulation of backend rules.
export function createConfirmedNeedReviewFixture(
  scenario: ConfirmedReviewScenario = "normal",
  serviceDate: string = reviewDate,
) {
  const batch = reviewBatch();
  const preflight = reviewPreflight();
  const need = reviewNeed();
  let reviewEvidence: {
    currentDecisionCount: number;
    proposalAcceptanceCount: number;
    adjustedLineId: string;
    retainedHistoricalIdentities: Array<{
      confirmedNeedLineId: string;
      decisionId: string;
      exactQuantity: string;
    }>;
  } | null = null;
  if (scenario === "oct12_school_first") {
    const identities = [
      ["AN PHÚ (BD)", "AN PHÚ (BD)", "Cà rốt"],
      ["AN PHÚ (BD)", "PHÂN HIỆU 2", "Gạo thơm"],
      ["BÌNH MỸ - BÌNH DƯƠNG", "BÌNH MỸ - BÌNH DƯƠNG", "Bí đỏ"],
      ["PHÚ CƯỜNG", "Bếp chính", "Thịt heo"],
      ["TÂN ĐỊNH", "TÂN ĐỊNH", "Cải thìa"],
      ["TÂN ĐỊNH", "Điểm giao khu A", "Trứng gà"],
    ] as const;
    batch.service_period = {
      period_start: oct12ReviewDate,
      period_end: oct12ReviewDate,
    };
    batch.lines.forEach((line, index) => {
      const [schoolName, locationName, ingredientName] = identities[index]!;
      line.service_date = oct12ReviewDate;
      line.school = { id: `oct12-school-${index}`, name: schoolName };
      line.delivery_location = {
        id: `oct12-location-${index}`,
        name: locationName,
      };
      line.ingredient = {
        id: `oct12-ingredient-${index}`,
        name: ingredientName,
      };
      if (index === 0) {
        line.theoretical_quantity = "12.000000";
        line.proposed_confirmed_quantity = "12.000000";
        line.confirmed_quantity_after = "12.000000";
      }
    });
    preflight.period_start = oct12ReviewDate;
    preflight.period_end = oct12ReviewDate;
    need.period = {
      period_start: oct12ReviewDate,
      period_end: oct12ReviewDate,
    };
    need.grouped_requirements[0] = {
      ...need.grouped_requirements[0]!,
      service_date: oct12ReviewDate,
      school_id: "oct12-school-0",
      school_name: "AN PHÚ (BD)",
      delivery_location_id: "oct12-location-0",
      delivery_location_name: "AN PHÚ (BD)",
      ingredient_id: "oct12-ingredient-0",
      ingredient_name: "Cà rốt",
      total_theoretical_quantity: 12,
      recipe_derived_quantity: 10,
      pantry_direct_quantity: 2,
    };
  }
  if (scenario === "certified_shape") {
    batch.lines = Array.from({ length: 248 }, (_, index) => reviewLine(index));
    batch.lines[0]!.ingredient.name =
      "Thịt heo nạc vai sơ chế theo quy cách bếp bán trú Trường Nguyễn Du cơ sở trung tâm";
    batch.lines[0]!.theoretical_quantity = "12.345000";
    batch.lines[0]!.proposed_confirmed_quantity = "12.350000";
    batch.lines[0]!.confirmed_quantity_after = "12.350000";
    Object.assign(batch.lines[1]!.controlled_unit, {
      id: "unit-qua",
      code: "Quả",
      name: "Quả",
    });
    batch.lines[1]!.theoretical_quantity = "18.000000";
    batch.lines[1]!.proposed_confirmed_quantity = "18.000000";
    batch.lines[1]!.confirmed_quantity_after = "18.000000";
    batch.lines[1]!.proposal_rounding_step = "1.000000";
    batch.lines[1]!.effective_policy!.planning_step = "1.000000";
    const adjusted = batch.lines[247]!;
    adjusted.current_decision_kind = "OPERATIONAL_ADJUSTMENT";
    adjusted.confirmed_quantity_after = "10.500000";
    adjusted.decision_history = [
      {
        decision_id: adjusted.current_decision_id!,
        decision_number: 1,
        predecessor_decision_id: null,
        decision_kind: "OPERATIONAL_ADJUSTMENT",
        revision_id: adjusted.current_revision_id,
        theoretical_quantity_before: adjusted.theoretical_quantity,
        proposed_quantity_before: adjusted.proposed_confirmed_quantity,
        confirmed_quantity_after: "10.500000",
        planning_tick_count: "42",
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Điều chỉnh vận hành đã xác nhận",
        policy_revision_id: adjusted.effective_policy!.revision_id,
        decided_at: "2026-09-07T03:00:00Z",
        batch_version: batch.batch_version,
      },
    ];
    batch.line_counts = {
      ...batch.line_counts,
      total: 248,
      confirmed: 248,
      adjusted: 1,
    };
    batch.pagination.total_lines = 248;
    reviewEvidence = {
      currentDecisionCount: 248,
      proposalAcceptanceCount: 247,
      adjustedLineId: adjusted.confirmed_need_line_id,
      retainedHistoricalIdentities: Array.from({ length: 249 }, (_, index) => ({
        confirmedNeedLineId: `retained-line-${index}`,
        decisionId: `retained-decision-${index}`,
        exactQuantity: index === 248 ? "10.123456" : "10.250000",
      })),
    };
  }
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
  // Stamp explicit synthetic identities before the adapter owns state, not only outgoing JSON.
  const dated = <T>(value: T): T =>
    serviceDate === reviewDate
      ? structuredClone(value)
      : (JSON.parse(
          JSON.stringify(value)
            .replaceAll(reviewDate, serviceDate)
            .replaceAll('"batch-current"', `"batch-current-${serviceDate}"`)
            .replaceAll('"run-current"', `"run-current-${serviceDate}"`)
            .replace(
              /"((?:line|revision|decision)-(?:\d+|saved))"/g,
              `"$1-${serviceDate}"`,
            ),
        ) as T);
  if (serviceDate !== reviewDate) {
    Object.assign(batch, dated(batch));
    Object.assign(preflight, dated(preflight));
    Object.assign(need, dated(need));
  }
  const saved =
    scenario === "oct12_school_first"
      ? structuredClone(batch)
      : dated(reviewBatch());
  saved.batch_version = 5;
  saved.line_counts.adjusted = 1;
  saved.lines[0] = {
    ...saved.lines[0]!,
    confirmed_quantity_after: "12.500000",
    current_decision_id: "decision-saved",
    current_revision_id: "revision-saved",
    current_revision_number: 2,
    current_decision_number: 2,
    current_decision_kind: "OPERATIONAL_ADJUSTMENT",
    decision_history: [
      {
        decision_id: "decision-saved",
        decision_number: 2,
        predecessor_decision_id: "decision-0",
        decision_kind: "OPERATIONAL_ADJUSTMENT",
        revision_id: "revision-saved",
        theoretical_quantity_before: "10.250000",
        proposed_quantity_before: "10.250000",
        confirmed_quantity_after: "12.500000",
        planning_tick_count: "50",
        reason_code: "OTHER",
        reason_note: "Bếp yêu cầu",
        policy_revision_id: "policy-revision",
        decided_at: "2026-09-07T03:30:00Z",
        batch_version: 5,
      },
    ],
  };
  let saveAttempted = false;
  let savedSnapshot = false;
  let correctedSnapshot = false;
  let generated = false;
  const preflightApi: PreflightApi = {
    async preflight() {
      if (scenario === "loading") return new Promise<AtlasRpcResult>(() => {});
      if (scenario === "read_failure") return reviewFailure();
      return reviewSuccess({
        preflight: generated ? dated(reviewPreflight()) : preflight,
      });
    },
  };

  const correctionError = (code: string): AtlasRpcResult => ({
    kind: "backend_error",
    error: {
      success: false,
      error_code: code,
      contract_version: "CONFIRMED-NEED-CORRECTION.v1",
      safe_message:
        "Không thể lưu điều chỉnh. Hãy kiểm tra và xem lại dữ liệu.",
      retryable: false,
      write_certainty: "NO_COMMITTED_CHANGE",
    },
  });
  let correctionProposal: {
    target: ConfirmedNeedCorrectionPayload;
    fingerprint: string;
  } | null = null;
  const correctionReceipts = new Map<
    string,
    { request: string; result: AtlasRpcResult }
  >();
  const correctionExact = (v: string) => {
    const [a, b = ""] = v.split(".");
    return BigInt(a! + b.padEnd(6, "0"));
  };
  const correctionText = (v: bigint) => {
    const sign = v < 0n ? "-" : "";
    const a = (v < 0n ? -v : v).toString().padStart(7, "0");
    return sign + a.slice(0, -6) + "." + a.slice(-6);
  };

  const confirmedNeedApi: ConfirmedNeedApi = {
    async previewCorrection(request) {
      const target = request.payload,
        line = batch.lines.find(
          (l) => l.confirmed_need_line_id === target.confirmed_need_line_id,
        );
      if (
        !line ||
        batch.confirmed_need_batch_id !== target.confirmed_need_batch_id ||
        batch.need_generation_source.run_id !== target.need_generation_run_id ||
        batch.need_generation_source.run_version !==
          target.expected_need_generation_run_version ||
        batch.authoritative_batch_status !== "RELEASED_FOR_PURCHASE_HANDOFF"
      )
        return correctionError("CORRECTION_NOT_APPLICABLE");
      if (
        batch.batch_version !== target.expected_confirmed_need_batch_version ||
        line.current_revision_id !== target.expected_current_revision_id ||
        line.current_decision_id !== target.expected_current_decision_id
      )
        return correctionError("STALE_VERSION");
      if (!target.reason_note.trim())
        return correctionError("ADJUSTMENT_REASON_INCOMPLETE");
      const members = batch.lines.filter(
        (l) =>
          l.service_date === line.service_date &&
          l.delivery_location.id === line.delivery_location.id &&
          l.ingredient.id === line.ingredient.id &&
          l.controlled_unit.id === line.controlled_unit.id,
      );
      const before = members.reduce(
          (sum, l) => sum + correctionExact(l.confirmed_quantity_after!),
          0n,
        ),
        delta =
          correctionExact(target.proposed_confirmed_quantity) -
          correctionExact(line.confirmed_quantity_after!);
      if (delta === 0n) return correctionError("NO_APPLICABLE_CORRECTION");
      const fingerprint = crypto.randomUUID().replaceAll("-", "").repeat(2);
      correctionProposal = { target: structuredClone(target), fingerprint };
      return reviewSuccess({
        contract_version: "CONFIRMED-NEED-CORRECTION.v1",
        read_name: "get_confirmed_need_correction_preview",
        write_certainty: "NO_WRITE",
        target: structuredClone(target),
        proposal_fingerprint: fingerprint,
        quantity: {
          before: line.confirmed_quantity_after,
          after: target.proposed_confirmed_quantity,
          delta: correctionText(delta),
        },
        family: {
          service_date: line.service_date,
          delivery_location_id: line.delivery_location.id,
          ingredient_id: line.ingredient.id,
          unit_id: line.controlled_unit.id,
          quantity_before: correctionText(before),
          quantity_after: correctionText(before + delta),
          contributions: members.map((l) => ({
            confirmed_need_batch_id: batch.confirmed_need_batch_id,
            confirmed_need_line_id: l.confirmed_need_line_id,
            revision_id: l.current_revision_id,
            decision_id: l.current_decision_id,
            school_id: l.school.id,
            customer_id: l.customer.id,
            delivery_location_id: l.delivery_location.id,
            quantity: l.confirmed_quantity_after,
            source_membership: [],
          })),
        },
        display: {
          ingredient_name: line.ingredient.name,
          delivery_location_name: line.delivery_location.name,
          unit_name: line.controlled_unit.name,
          schools: members.map((l) => ({
            confirmed_need_line_id: l.confirmed_need_line_id,
            school_id: l.school.id,
            school_name: l.school.name,
            customer_id: l.customer.id,
            customer_name: l.customer.name,
            delivery_location_id: l.delivery_location.id,
          })),
        },
        allowed_actions: { correct: true },
        disabled_reasons: { correct: null },
        procurement_details_coverage: "AUTHORIZED_DETAILS_ONLY",
        procurement_details: [],
        purchase_order_coverage: "AUTHORIZED_DOCUMENTS_ONLY",
        purchase_orders: [],
      });
    },
    async correct(request) {
      const replay = correctionReceipts.get(request.command_id);
      if (replay)
        return replay.request === JSON.stringify(request)
          ? structuredClone(replay.result)
          : correctionError("IDEMPOTENCY_KEY_REUSED");
      const { proposal_fingerprint, ...target } = request.payload;
      if (
        !correctionProposal ||
        proposal_fingerprint !== correctionProposal.fingerprint ||
        JSON.stringify(target) !== JSON.stringify(correctionProposal.target) ||
        batch.batch_version !== request.expected_version
      )
        return correctionError("STALE_CORRECTION_PROPOSAL");
      const line = batch.lines.find(
        (l) => l.confirmed_need_line_id === target.confirmed_need_line_id,
      )!;
      correctedSnapshot = true;
      const oldRevision = line.current_revision_id,
        oldDecision = line.current_decision_id;
      batch.batch_version += 2;
      batch.authoritative_batch_status = "REOPENED";
      batch.batch_status = "REOPENED";
      batch.editing_allowed = true;
      batch.allowed_actions.save_confirmed_needs = true;
      line.current_revision_number += 1;
      line.current_revision_id = crypto.randomUUID();
      line.current_decision_number = (line.current_decision_number ?? 0) + 1;
      line.current_decision_id = crypto.randomUUID();
      line.confirmed_quantity_after = target.proposed_confirmed_quantity;
      line.current_decision_kind = "OPERATIONAL_ADJUSTMENT";
      batch.line_counts.adjusted = batch.lines.filter((item) =>
        item.current_decision_kind?.includes("ADJUST"),
      ).length;
      line.decision_history.push({
        decision_id: line.current_decision_id,
        decision_number: line.current_decision_number,
        predecessor_decision_id: oldDecision,
        decision_kind: "OPERATIONAL_ADJUSTMENT",
        revision_id: line.current_revision_id,
        theoretical_quantity_before: line.theoretical_quantity,
        proposed_quantity_before: line.proposed_confirmed_quantity,
        confirmed_quantity_after: target.proposed_confirmed_quantity,
        planning_tick_count: "0",
        reason_code: target.reason_code,
        reason_note: target.reason_note,
        policy_revision_id: line.effective_policy?.revision_id ?? oldRevision,
        decided_at: request.requested_at,
        batch_version: batch.batch_version,
      });
      const result = reviewSuccess({
        contract_version: "CONFIRMED-NEED-CORRECTION.v1",
        command_name: "correct_confirmed_need",
        command_id: request.command_id,
        confirmed_need_batch_id: batch.confirmed_need_batch_id,
        receipt_id: crypto.randomUUID(),
        idempotency_status: "COMPLETED",
        resulting_batch_version: batch.batch_version,
        child_command_ids: [crypto.randomUUID(), crypto.randomUUID()],
        created_successor_revision_ids: [line.current_revision_id],
        created_decision_ids: [line.current_decision_id],
        authoritative_readback: structuredClone(batch) as unknown as JsonValue,
      });
      correctionReceipts.set(request.command_id, {
        request: JSON.stringify(request),
        result: structuredClone(result),
      });
      return result;
    },

    async getReview() {
      if (saveAttempted && scenario === "recovery_failed")
        return reviewFailure();
      return reviewSuccess({
        workbench: correctedSnapshot ? batch : savedSnapshot ? saved : batch,
      });
    },
    async save(request) {
      saveAttempted = true;
      if (correctedSnapshot) {
        if (request.expected_version !== batch.batch_version)
          return reviewFailure(
            "STALE_CONFIRMED_NEED_BATCH",
            "NO_COMMITTED_CHANGE",
          );
        for (const changed of request.payload.lines) {
          const line = batch.lines.find(
            (l) => l.confirmed_need_line_id === changed.confirmed_need_line_id,
          );
          if (
            !line ||
            line.current_revision_id !== changed.expected_current_revision_id ||
            line.current_decision_id !== changed.expected_current_decision_id
          )
            return reviewFailure(
              "STALE_CONFIRMED_NEED_LINE",
              "NO_COMMITTED_CHANGE",
            );
        }
        batch.batch_version++;
        for (const changed of request.payload.lines) {
          const line = batch.lines.find(
            (l) => l.confirmed_need_line_id === changed.confirmed_need_line_id,
          )!;
          line.confirmed_quantity_after = changed.proposed_confirmed_quantity;
          line.current_revision_id = crypto.randomUUID();
          line.current_revision_number++;
          line.current_decision_id = crypto.randomUUID();
          line.current_decision_number =
            (line.current_decision_number ?? 0) + 1;
        }
        return reviewSuccess({ authoritative_readback: batch });
      }
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
    reviewEvidence,
    preflightApi,
    confirmedNeedApi,
    needGenerationApi,
  };
}
