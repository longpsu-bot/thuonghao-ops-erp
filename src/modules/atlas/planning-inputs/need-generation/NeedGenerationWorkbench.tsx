import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ArrowClockwise, Eye, Lightning } from "@phosphor-icons/react";
import type { AtlasAuthState } from "../../connection/authSession";
import { Chip, CompactTable, Panel } from "../../WorkbenchComponents";
import { createPlanningInputReadinessApi } from "../readiness/planningInputReadinessApi";
import {
  planningInputPreflightFromResult,
  readinessResultMessage,
  type PlanningInputPreflightData,
  type PlanningInputPreflightIssue,
  type ReadinessSelectionState,
  type ReadinessSourceKind,
} from "../readiness/planningInputReadinessModel";
import {
  needGenerationExecutionRequest,
  type NeedGenerationApi,
  type NeedGenerationDetailGroup,
  type NeedGenerationFilters,
} from "./needGenerationApi";
import {
  formatQuantity,
  needGenerationContinuitySummaryFromResult,
  needGenerationReadbackFromResult,
  needGenerationResultIsStale,
  needGenerationResultMessage,
  needGenerationWorkbenchFromResult,
  type NeedGenerationGroup,
  type NeedGenerationWorkbenchData,
} from "./needGenerationModel";

const emptyFilters: NeedGenerationFilters = {
  service_date: null,
  school_id: null,
  ingredient_id: null,
  contribution_family: null,
};

const sourceNames: Record<ReadinessSourceKind, string> = {
  weekly_menu: "Thực đơn",
  attendance: "Sĩ số",
  pantry: "Nhu cầu bổ sung",
};

function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function serviceDates(weekStart: string, weekEnd: string) {
  const dates: string[] = [];
  const cursor = new Date(`${weekStart}T00:00:00Z`);
  const end = new Date(`${weekEnd}T00:00:00Z`);
  while (cursor <= end && dates.length < 7) {
    dates.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return dates;
}

function currentnessLabel(
  currentness: PlanningInputPreflightData["downstream_currentness"],
) {
  const labels = {
    CURRENT: "Đã cập nhật",
    OUTDATED: "Cần cập nhật",
    NOT_GENERATED: "Chưa tạo",
    LEGACY_OVERLAP: "Vướng nhu cầu cũ",
  } as const;
  return labels[currentness];
}

function confirmedNeedStatusLabel(status: string | null | undefined) {
  const labels: Record<string, string> = {
    DRAFT_REVIEW: "Chờ xác nhận",
    REOPENED: "Cần xác nhận lại",
    VALIDATED: "Đã kiểm tra",
    APPROVED: "Đã xác nhận",
    RELEASED_FOR_PURCHASE_HANDOFF: "Đã chuyển sang lên đơn",
  };
  return status ? (labels[status] ?? "Có nhu cầu xác nhận") : "Chưa có";
}

function runStatusLabel(
  status: NeedGenerationWorkbenchData["run_history"][number]["status"],
) {
  const labels = {
    GENERATED: "Đã tính",
    VALIDATED: "Đã kiểm tra",
    RELEASED_FOR_CONFIRMATION: "Chờ xác nhận",
    INVALIDATED: "Không còn hiệu lực",
  } as const;
  return labels[status];
}

function currentnessTone(
  currentness: PlanningInputPreflightData["downstream_currentness"],
) {
  if (currentness === "CURRENT") return "ok" as const;
  if (currentness === "OUTDATED" || currentness === "LEGACY_OVERLAP")
    return "danger" as const;
  return "warning" as const;
}

function readinessLabel(state: PlanningInputPreflightData["readiness_state"]) {
  return state === "READY" ? "SẴN SÀNG" : "CẦN XỬ LÝ";
}

function sourceSelectionLabel(state: ReadinessSelectionState) {
  const labels: Record<ReadinessSelectionState, string> = {
    SELECTED: "ĐÃ LƯU",
    MISSING: "CHƯA CÓ",
    AMBIGUOUS: "CẦN XỬ LÝ",
    STALE: "CẦN TẢI LẠI",
  };
  return labels[state];
}

function sourceSelectionMessage(state: ReadinessSelectionState) {
  const messages: Record<ReadinessSelectionState, string> = {
    SELECTED: "Dữ liệu đã lưu hiện hành cho kỳ này.",
    MISSING: "Chưa có dữ liệu đã lưu phù hợp với kỳ này.",
    AMBIGUOUS:
      "Có nhiều bản dữ liệu phù hợp. Cần xử lý nguồn trước khi tiếp tục.",
    STALE: "Dữ liệu nguồn đã thay đổi. Hãy làm mới trước khi tiếp tục.",
  };
  return messages[state];
}

const preflightIssueMessages: Record<string, string> = {
  MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT:
    "Chưa có thực đơn tuần đã lưu phù hợp với kỳ này.",
  MISSING_ATTENDANCE_APPROVAL_SNAPSHOT:
    "Chưa có số suất ăn đã lưu phù hợp với kỳ này.",
  MISSING_PANTRY_APPROVAL_SNAPSHOT:
    "Chưa có xác nhận nhu cầu bổ sung phù hợp với kỳ này.",
  SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH:
    "Dữ liệu nguồn không thuộc đúng phạm vi cần xử lý.",
  WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD:
    "Thực đơn tuần đã lưu chưa bao phủ toàn bộ kỳ đang xử lý.",
  ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD:
    "Số suất ăn đã lưu chưa bao phủ toàn bộ kỳ đang xử lý.",
  PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD:
    "Nhu cầu bổ sung đã lưu chưa bao phủ toàn bộ kỳ đang xử lý.",
  STALE_OR_MISMATCHED_SNAPSHOT_BINDING:
    "Dữ liệu nguồn đã thay đổi hoặc không còn khớp. Hãy làm mới trước khi tiếp tục.",
  REQUEST_WITHOUT_CURRENT_READY_EVALUATION:
    "Dữ liệu đầu vào hiện tại chưa sẵn sàng để tạo nhu cầu.",
  MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE:
    "Có thực đơn nhưng chưa có số suất ăn tương ứng cho trường và ngày này.",
  ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU:
    "Có số suất ăn nhưng chưa có thực đơn tương ứng cho trường và ngày này.",
  ZERO_ATTENDANCE_FOR_PLANNED_MENU:
    "Thực đơn đã có nhưng tổng số suất ăn của trường và ngày này bằng 0.",
  AMBIGUOUS_WEEKLY_MENU_SOURCE:
    "Có nhiều thực đơn tuần phù hợp. Cần xử lý nguồn trước khi tiếp tục.",
  STALE_WEEKLY_MENU_SOURCE:
    "Thực đơn tuần đã thay đổi. Hãy làm mới trước khi tiếp tục.",
  AMBIGUOUS_ATTENDANCE_SOURCE:
    "Có nhiều bản số suất ăn phù hợp. Cần xử lý nguồn trước khi tiếp tục.",
  STALE_ATTENDANCE_SOURCE:
    "Số suất ăn đã thay đổi. Hãy làm mới trước khi tiếp tục.",
  AMBIGUOUS_PANTRY_SOURCE:
    "Có nhiều bản nhu cầu bổ sung phù hợp. Cần xử lý nguồn trước khi tiếp tục.",
  STALE_PANTRY_SOURCE:
    "Nhu cầu bổ sung đã thay đổi. Hãy làm mới trước khi tiếp tục.",
  ACTIVE_LEGACY_NEED_RANGE_OVERLAP:
    "Ngày này đã nằm trong một nhu cầu nhiều ngày đang có hiệu lực. Giữ nguyên nhu cầu cũ và chờ quy trình điều chỉnh.",
  NO_NEED_SOURCE_FOR_SERVICE_DATE: "Không có nhu cầu cần lập cho ngày này.",
};

function preflightIssueMessage(issue: PlanningInputPreflightIssue) {
  return (
    preflightIssueMessages[issue.issue_code] ??
    "Có vấn đề với dữ liệu đầu vào. Hãy làm mới và kiểm tra nguồn trước khi tiếp tục."
  );
}

function releasedCorrectionBlocked(preflight: PlanningInputPreflightData) {
  return (
    preflight.downstream_currentness === "OUTDATED" &&
    preflight.current_need?.confirmed_need_batch_status ===
      "RELEASED_FOR_PURCHASE_HANDOFF"
  );
}

function hasNoNeedSource(preflight: PlanningInputPreflightData) {
  return preflight.issues.some(
    (issue) => issue.issue_code === "NO_NEED_SOURCE_FOR_SERVICE_DATE",
  );
}

function planningStatusSentence(preflight: PlanningInputPreflightData) {
  if (preflight.downstream_currentness === "LEGACY_OVERLAP")
    return "Ngày này đã thuộc một nhu cầu nhiều ngày đang có hiệu lực nên không thể tạo nhu cầu mới.";

  if (hasNoNeedSource(preflight)) return "Không có nhu cầu cần lập";

  if (releasedCorrectionBlocked(preflight))
    return "Nhu cầu này đã được chuyển sang lên đơn nên chưa thể cập nhật trực tiếp tại đây.";

  if (preflight.readiness_state === "BLOCKED") {
    const action =
      preflight.downstream_currentness === "OUTDATED" ? "cập nhật" : "tạo";
    for (const source of ["weekly_menu", "attendance", "pantry"] as const) {
      const evidence = preflight.source_evidence[source];
      const state =
        evidence.selection_state ??
        (evidence.selected ? "SELECTED" : "MISSING");
      if (state === "MISSING")
        return `Cần lưu ${sourceNames[source]} trước khi ${action} nhu cầu.`;
      if (state === "AMBIGUOUS")
        return `Cần kiểm tra ${sourceNames[source]} trước khi ${action} nhu cầu.`;
      if (state === "STALE")
        return `${sourceNames[source]} đã thay đổi. Cần làm mới dữ liệu trước khi tiếp tục.`;
    }
    const firstBlocker = preflight.issues.find(
      (issue) => issue.severity === "BLOCKING",
    );
    return firstBlocker
      ? preflightIssueMessage(firstBlocker)
      : "Cần xử lý dữ liệu đầu vào trước khi tạo nhu cầu.";
  }

  if (preflight.downstream_currentness === "CURRENT")
    return "Nhu cầu đã cập nhật từ dữ liệu hiện tại.";
  if (preflight.downstream_currentness === "OUTDATED")
    return "Dữ liệu nguồn đã thay đổi sau lần tính gần nhất.";
  return "Dữ liệu đã sẵn sàng.";
}

function dailyOperatorStatus(preflight: PlanningInputPreflightData) {
  if (preflight.downstream_currentness === "LEGACY_OVERLAP")
    return "Thuộc nhu cầu đã lập trước đây";
  if (hasNoNeedSource(preflight)) return "Không có nhu cầu cần lập";
  if (preflight.readiness_state === "BLOCKED")
    return planningStatusSentence(preflight);
  if (preflight.downstream_currentness === "OUTDATED")
    return "Dữ liệu đã thay đổi";
  if (preflight.downstream_currentness === "CURRENT")
    return preflight.current_need?.confirmed_need_batch_status
      ? confirmedNeedStatusLabel(
          preflight.current_need.confirmed_need_batch_status,
        )
      : "Chờ xác nhận";
  return "Sẵn sàng lập nhu cầu";
}

function dailyReviewAction(preflight: PlanningInputPreflightData | undefined) {
  if (!preflight) return "Đang tải";
  if (
    preflight.downstream_currentness === "CURRENT" &&
    preflight.current_need?.confirmed_need_batch_id
  )
    return "Mở xác nhận";
  if (preflight.downstream_currentness === "LEGACY_OVERLAP") return "Xem";
  if (hasNoNeedSource(preflight)) return "Xem";
  if (preflight.readiness_state === "BLOCKED") return "Xem lỗi";
  if (
    preflight.downstream_currentness === "OUTDATED" ||
    preflight.downstream_currentness === "NOT_GENERATED"
  )
    return "Rà soát";
  return "Xem";
}

function IssueList({
  title,
  tone,
  items,
}: {
  title: string;
  tone: "danger" | "warning";
  items: PlanningInputPreflightIssue[];
}) {
  if (!items.length) return null;
  return (
    <section className={`planning-issues ${tone}`} aria-label={title}>
      <strong>
        {title} ({items.length})
      </strong>
      <ul>
        {items.map((item, index) => (
          <li key={`${item.issue_code}:${item.input_type}:${index}`}>
            {preflightIssueMessage(item)}
            {(item.service_date || item.school_id) && (
              <small>
                {[
                  item.service_date && viDate(item.service_date),
                  item.school_id,
                ]
                  .filter(Boolean)
                  .join(" · ")}
              </small>
            )}
            {!preflightIssueMessages[item.issue_code] && (
              <details>
                <summary>Chi tiết hỗ trợ</summary>
                <code>{item.issue_code}</code>
              </details>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}

function groupIdentity(group: NeedGenerationGroup): NeedGenerationDetailGroup {
  return {
    service_date: group.service_date,
    school_id: group.school_id,
    delivery_location_id: group.delivery_location_id,
    ingredient_id: group.ingredient_id,
    unit_id: group.unit_id,
  };
}

export function NeedGenerationWorkbench({
  authState,
  api,
  preflightApi,
  selectedWeekStart,
  selectedWeekEnd,
  onConfirmedNeedMaterialized,
  onConfirmedNeedSelected,
  embeddedInConfirmedNeed = false,
}: {
  authState: AtlasAuthState;
  api?: NeedGenerationApi;
  preflightApi?: Pick<
    ReturnType<typeof createPlanningInputReadinessApi>,
    "preflight"
  >;
  selectedWeekStart: string;
  selectedWeekEnd: string;
  onConfirmedNeedMaterialized?: (confirmedNeedBatchId: string) => void;
  onConfirmedNeedSelected?: (
    confirmedNeedBatchId: string,
    serviceDate: string,
    authoritativePreflight: PlanningInputPreflightData,
  ) => void;
  embeddedInConfirmedNeed?: boolean;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const days = useMemo(
    () => serviceDates(selectedWeekStart, selectedWeekEnd),
    [selectedWeekEnd, selectedWeekStart],
  );
  const [selectedServiceDate, setSelectedServiceDate] =
    useState(selectedWeekStart);
  const [dailyPreflights, setDailyPreflights] = useState<
    Record<string, PlanningInputPreflightData>
  >({});
  const [preflight, setPreflight] = useState<PlanningInputPreflightData | null>(
    null,
  );
  const [workbench, setWorkbench] =
    useState<NeedGenerationWorkbenchData | null>(null);
  const [filters, setFilters] = useState<NeedGenerationFilters>(emptyFilters);
  const [draftFilters, setDraftFilters] =
    useState<NeedGenerationFilters>(emptyFilters);
  const [offset, setOffset] = useState(0);
  const [detailGroup, setDetailGroup] =
    useState<NeedGenerationDetailGroup | null>(null);
  const [selectedRunId, setSelectedRunId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [refreshRequired, setRefreshRequired] = useState(false);
  const [executionBlocker, setExecutionBlocker] = useState<string | null>(null);
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;
  const limit = 100;

  const loadAuthority = useCallback(
    async (
      overrides: {
        nextOffset?: number;
        nextFilters?: NeedGenerationFilters;
        nextDetail?: NeedGenerationDetailGroup | null;
        nextRunId?: string | null;
      } = {},
    ) => {
      if (!api || !preflightApi || !authSubject) return false;
      const requestGeneration = ++generation.current;
      setLoading(true);
      setNotice(null);
      const [preflightResults, workbenchResult] = await Promise.all([
        Promise.all(
          days.map((serviceDate) =>
            preflightApi.preflight(
              authSubject,
              correlationId,
              serviceDate,
              serviceDate,
            ),
          ),
        ),
        api.getWorkbench(
          authSubject,
          correlationId,
          selectedServiceDate,
          selectedServiceDate,
          overrides.nextRunId === undefined
            ? selectedRunId
            : overrides.nextRunId,
          overrides.nextFilters ?? filters,
          overrides.nextOffset ?? offset,
          limit,
          overrides.nextDetail === undefined
            ? detailGroup
            : overrides.nextDetail,
        ),
      ]);
      if (requestGeneration !== generation.current) return false;
      setLoading(false);
      const parsedDays = Object.fromEntries(
        days.flatMap((serviceDate, index) => {
          const parsed = planningInputPreflightFromResult(
            preflightResults[index]!,
          );
          return parsed ? [[serviceDate, parsed]] : [];
        }),
      ) as Record<string, PlanningInputPreflightData>;
      const nextPreflight = parsedDays[selectedServiceDate] ?? null;
      if (!nextPreflight) {
        setPreflight(null);
        const failed = preflightResults.find(
          (result) => !planningInputPreflightFromResult(result),
        );
        if (failed) setNotice(readinessResultMessage(failed));
        return false;
      }
      setDailyPreflights(parsedDays);
      setPreflight(nextPreflight);
      setWorkbench(needGenerationWorkbenchFromResult(workbenchResult));
      setRefreshRequired(false);
      setExecutionBlocker(null);
      return true;
    },
    [
      api,
      authSubject,
      correlationId,
      days,
      detailGroup,
      filters,
      offset,
      preflightApi,
      selectedServiceDate,
      selectedRunId,
    ],
  );

  useEffect(() => {
    setSelectedServiceDate(selectedWeekStart);
    setOffset(0);
    setSelectedRunId(null);
    setDetailGroup(null);
  }, [selectedWeekEnd, selectedWeekStart]);

  useEffect(() => {
    if (authSubject) void loadAuthority();
    else {
      setPreflight(null);
      setWorkbench(null);
    }
    // Loading is keyed by the authenticated week/day selection. The callback
    // also carries paging/detail state for explicit operator refreshes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authSubject, selectedServiceDate, selectedWeekEnd, selectedWeekStart]);

  const filterOptions = useMemo(() => {
    const groups = workbench?.grouped_requirements ?? [];
    return {
      schools: Array.from(
        new Map(groups.map((item) => [item.school_id, item.school_name])),
      ),
      ingredients: Array.from(
        new Map(
          groups.map((item) => [item.ingredient_id, item.ingredient_name]),
        ),
      ),
    };
  }, [workbench]);

  const applyFilters = () => {
    setFilters(draftFilters);
    setOffset(0);
    setDetailGroup(null);
    void loadAuthority({
      nextFilters: draftFilters,
      nextOffset: 0,
      nextDetail: null,
    });
  };

  const executeNeed = async () => {
    if (
      !api ||
      !authSubject ||
      !preflight ||
      preflight.readiness_state !== "READY" ||
      preflight.downstream_currentness === "CURRENT" ||
      preflight.downstream_currentness === "LEGACY_OVERLAP" ||
      releasedCorrectionBlocked(preflight) ||
      refreshRequired ||
      executionBlocker
    )
      return;
    const wasUpdate = preflight.downstream_currentness === "OUTDATED";
    const request = needGenerationExecutionRequest(
      authSubject,
      correlationId,
      preflight.current_need?.need_generation_run_version ?? 1,
      selectedServiceDate,
      preflight.current_need?.need_generation_run_id ?? null,
    );
    setBusy(true);
    setNotice(null);
    const result = await api.execute(request);
    setBusy(false);
    if (
      result.kind === "transport_error" ||
      needGenerationResultIsStale(result)
    ) {
      setRefreshRequired(true);
      setNotice(needGenerationResultMessage(result));
      return;
    }
    if (result.kind !== "success") {
      const message = needGenerationResultMessage(result);
      setExecutionBlocker(message);
      setNotice(message);
      return;
    }
    const nextPreflight = planningInputPreflightFromResult(result);
    const nextWorkbench = needGenerationReadbackFromResult(result);
    const continuitySummary = needGenerationContinuitySummaryFromResult(result);
    setPreflight(nextPreflight);
    setDailyPreflights((current) =>
      nextPreflight
        ? { ...current, [nextPreflight.period_start]: nextPreflight }
        : current,
    );
    setWorkbench(nextWorkbench);
    setExecutionBlocker(null);
    if (!nextPreflight || !nextWorkbench) {
      setRefreshRequired(true);
      setNotice(
        "Đã nhận kết quả nhưng chưa đọc lại được dữ liệu mới nhất. Hãy làm mới.",
      );
      return;
    }
    setNotice(
      wasUpdate && continuitySummary
        ? `Nhu cầu đã được cập nhật. ${continuitySummary.needsReview} dòng cần rà soát; ${continuitySummary.carriedForward} xác nhận trước đó được giữ nguyên.`
        : wasUpdate
          ? "Đã cập nhật nhu cầu."
          : "Đã tạo nhu cầu.",
    );
    const nextBatchId = nextPreflight.current_need?.confirmed_need_batch_id;
    if (nextBatchId) {
      onConfirmedNeedMaterialized?.(nextBatchId);
      onConfirmedNeedSelected?.(
        nextBatchId,
        nextPreflight.period_start,
        nextPreflight,
      );
    }
  };

  const blockers =
    preflight?.issues.filter(
      (issue) =>
        issue.severity === "BLOCKING" &&
        issue.issue_code !== "NO_NEED_SOURCE_FOR_SERVICE_DATE",
    ) ?? [];
  const warnings =
    preflight?.issues.filter((issue) => issue.severity === "WARNING") ?? [];
  const executionLabel =
    preflight?.downstream_currentness === "OUTDATED"
      ? "Cập nhật nhu cầu"
      : "Tạo nhu cầu";
  const correctionBlocked = preflight
    ? releasedCorrectionBlocked(preflight)
    : false;
  const noNeedSource = preflight ? hasNoNeedSource(preflight) : false;
  const canExecute =
    preflight?.readiness_state === "READY" &&
    preflight.downstream_currentness !== "CURRENT" &&
    preflight.downstream_currentness !== "LEGACY_OVERLAP" &&
    !correctionBlocked &&
    !loading &&
    !refreshRequired &&
    !executionBlocker;

  const openDailyReview = (
    serviceDate: string,
    state: PlanningInputPreflightData | undefined,
  ) => {
    setLoading(selectedServiceDate !== serviceDate);
    setSelectedServiceDate(serviceDate);
    setPreflight(state ?? null);
    setOffset(0);
    setSelectedRunId(null);
    setDetailGroup(null);
    const batchId = state?.current_need?.confirmed_need_batch_id;
    if (state?.downstream_currentness === "CURRENT" && batchId) {
      onConfirmedNeedMaterialized?.(batchId);
      onConfirmedNeedSelected?.(batchId, serviceDate, state);
    }
  };

  const openSelectedConfirmedNeed = () => {
    const batchId = preflight?.current_need?.confirmed_need_batch_id;
    if (preflight?.downstream_currentness !== "CURRENT" || !batchId) return;
    onConfirmedNeedMaterialized?.(batchId);
    onConfirmedNeedSelected?.(batchId, selectedServiceDate, preflight);
  };

  if (embeddedInConfirmedNeed) {
    return (
      <section
        className="need-generation-daily-navigator"
        role="region"
        aria-label="Tổng quan nhu cầu theo ngày"
        aria-busy={loading}
      >
        <header className="need-generation-daily-heading">
          <strong>Chọn ngày xác nhận</strong>
          <span>{days.length} ngày phục vụ</span>
        </header>
        <nav
          className="need-generation-daily-selector"
          aria-label="Chọn ngày xác nhận nhu cầu"
        >
          {days.map((serviceDate) => {
            const state = dailyPreflights[serviceDate];
            const action = dailyReviewAction(state);
            const selected = selectedServiceDate === serviceDate;
            return (
              <button
                key={serviceDate}
                type="button"
                className={`need-generation-daily-option${selected ? " selected" : ""}`}
                aria-label={`${action} ${viDate(serviceDate)}`}
                aria-current={selected ? "date" : undefined}
                aria-controls="planning-confirmed-review"
                onClick={() => openDailyReview(serviceDate, state)}
              >
                <strong>{viDate(serviceDate)}</strong>
                <span>
                  {action} · {state ? dailyOperatorStatus(state) : "Đang tải…"}
                </span>
              </button>
            );
          })}
        </nav>
        {preflight && (
          <section
            className="need-generation-daily-selected-action"
            role="region"
            aria-label="Việc cần làm cho ngày đã chọn"
          >
            <div className="need-generation-daily-selected-copy">
              <span>Ngày đang xem</span>
              <strong>{viDate(selectedServiceDate)}</strong>
              <p>{planningStatusSentence(preflight)}</p>
            </div>
            {canExecute && (
              <button
                type="button"
                className="primary-forward"
                disabled={busy}
                onClick={() => void executeNeed()}
              >
                <Lightning aria-hidden="true" size={18} />
                {executionLabel}
              </button>
            )}
            {preflight.downstream_currentness === "CURRENT" &&
              preflight.current_need?.confirmed_need_batch_id && (
                <button
                  type="button"
                  className="primary-forward"
                  disabled={busy}
                  onClick={openSelectedConfirmedNeed}
                >
                  <Eye aria-hidden="true" size={18} />
                  Mở xác nhận
                </button>
              )}
            {notice && (
              <p
                className="operator-notice need-generation-daily-selected-notice"
                role={refreshRequired ? "alert" : "status"}
              >
                {notice}
              </p>
            )}
          </section>
        )}
      </section>
    );
  }

  return (
    <Panel
      title={embeddedInConfirmedNeed ? "Tình trạng nhu cầu" : "Tạo nhu cầu"}
      description="Atlas kiểm tra dữ liệu nguồn và chỉ đưa ra việc cần làm tiếp theo cho từng ngày."
    >
      <p className="need-generation-context">
        Tuần đang xem: <b>{viDate(selectedWeekStart)}</b> –{" "}
        <b>{viDate(selectedWeekEnd)}</b>.
      </p>
      <button
        type="button"
        disabled={loading || busy}
        onClick={() => void loadAuthority()}
      >
        <ArrowClockwise aria-hidden="true" size={16} />
        Làm mới
      </button>

      <div className="table-scroll">
        <table aria-label="Tổng quan nhu cầu theo ngày">
          <thead>
            <tr>
              <th>Ngày phục vụ</th>
              <th>Trạng thái</th>
              <th>Việc cần làm</th>
            </tr>
          </thead>
          <tbody>
            {days.map((serviceDate) => {
              const state = dailyPreflights[serviceDate];
              const action = dailyReviewAction(state);
              return (
                <tr
                  key={serviceDate}
                  aria-current={
                    selectedServiceDate === serviceDate ? "date" : undefined
                  }
                >
                  <td>{viDate(serviceDate)}</td>
                  <td>{state ? dailyOperatorStatus(state) : "Đang tải…"}</td>
                  <td>
                    <button
                      type="button"
                      aria-label={`${action} ${viDate(serviceDate)}`}
                      onClick={() => openDailyReview(serviceDate, state)}
                    >
                      {action}
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {loading && <p role="status">Đang kiểm tra dữ liệu nguồn và nhu cầu…</p>}
      {notice && (
        <p
          className="operator-notice"
          role={refreshRequired ? "alert" : "status"}
        >
          {notice}
        </p>
      )}
      {refreshRequired && (
        <p className="operator-notice warning" role="alert">
          Kết quả ghi chưa thể xác nhận an toàn. Không thể ghi tiếp cho đến khi
          làm mới dữ liệu.
        </p>
      )}

      {preflight && (
        <>
          <section
            className={`need-generation-status ${
              noNeedSource
                ? "ready"
                : correctionBlocked || preflight.readiness_state === "BLOCKED"
                  ? "danger"
                  : preflight.downstream_currentness === "OUTDATED"
                    ? "warning"
                    : "ready"
            }`}
            aria-label="Trạng thái tạo nhu cầu"
          >
            <h3>{planningStatusSentence(preflight)}</h3>
          </section>

          <IssueList title="Lỗi chặn" tone="danger" items={blockers} />
          <IssueList title="Cảnh báo" tone="warning" items={warnings} />

          <section
            className="need-generation-forward"
            aria-label="Việc cần làm tiếp theo"
          >
            <header>
              <span>Bước tiếp theo</span>
              <h3>
                {preflight.downstream_currentness === "CURRENT"
                  ? "Xác nhận nhu cầu"
                  : preflight.downstream_currentness === "LEGACY_OVERLAP"
                    ? "Chờ quy trình điều chỉnh nhu cầu cũ"
                    : noNeedSource
                      ? "Không có nhu cầu cần lập"
                      : correctionBlocked
                        ? "Chờ quy trình điều chỉnh tiếp theo"
                        : canExecute
                          ? executionLabel
                          : "Hoàn tất dữ liệu còn thiếu"}
              </h3>
            </header>
            {canExecute && (
              <div className="need-generation-active-action">
                <p>
                  Atlas sẽ kiểm tra lại, tạo toàn bộ nhu cầu và chuẩn bị Phiếu
                  nhu cầu xác nhận trong cùng một giao dịch.
                </p>
                <button
                  type="button"
                  className="primary-forward"
                  disabled={busy}
                  onClick={() => void executeNeed()}
                >
                  <Lightning aria-hidden="true" size={18} />
                  {executionLabel}
                </button>
              </div>
            )}
            {executionBlocker && (
              <p className="need-generation-blocked-reason">
                {executionBlocker}
              </p>
            )}
            {correctionBlocked && (
              <p className="need-generation-blocked-reason" role="status">
                Nhu cầu đã chuyển sang lên đơn được giữ nguyên. Quy trình điều
                chỉnh tiếp theo chưa thuộc màn hình này.
              </p>
            )}
            {preflight.downstream_currentness === "CURRENT" &&
              preflight.current_need?.confirmed_need_batch_id && (
                <button
                  type="button"
                  className="primary-forward"
                  onClick={openSelectedConfirmedNeed}
                >
                  Mở Xác nhận nhu cầu
                </button>
              )}
          </section>

          <details className="need-generation-support-detail">
            <summary>Chi tiết hỗ trợ</summary>
            <div className="need-generation-support-state">
              <Chip
                tone={
                  noNeedSource
                    ? "warning"
                    : preflight.readiness_state === "READY"
                      ? "ok"
                      : "danger"
                }
              >
                {noNeedSource
                  ? "KHÔNG CÓ NHU CẦU"
                  : readinessLabel(preflight.readiness_state)}
              </Chip>
              <Chip tone={currentnessTone(preflight.downstream_currentness)}>
                {currentnessLabel(preflight.downstream_currentness)}
              </Chip>
            </div>
            <div
              className="readiness-source-grid"
              aria-label="Chi tiết ba nguồn kế hoạch"
            >
              {(["weekly_menu", "attendance", "pantry"] as const).map(
                (source) => {
                  const evidence = preflight.source_evidence[source];
                  const selectionState: ReadinessSelectionState =
                    evidence.selection_state ??
                    (evidence.selected ? "SELECTED" : "MISSING");
                  return (
                    <section
                      className={`readiness-source-card ${selectionState.toLowerCase()}`}
                      key={source}
                    >
                      <header>
                        <h3>{sourceNames[source]}</h3>
                        <Chip
                          tone={selectionState === "SELECTED" ? "ok" : "danger"}
                        >
                          {sourceSelectionLabel(selectionState)}
                        </Chip>
                      </header>
                      <p className="readiness-source-empty">
                        {sourceSelectionMessage(selectionState)}
                      </p>
                      {evidence.selected && (
                        <span className="readiness-source-audit">
                          Phiên bản{" "}
                          {String(
                            evidence.selected.weekly_menu_version ??
                              evidence.selected.attendance_version ??
                              evidence.selected.pantry_need_batch_version ??
                              "—",
                          )}{" "}
                          · {evidence.selected.line_count} dòng
                        </span>
                      )}
                    </section>
                  );
                },
              )}
            </div>
          </details>
        </>
      )}

      {workbench?.selected_run && (
        <details className="need-generation-support-detail">
          <summary>Chi tiết tính nhu cầu</summary>
          <section
            className="need-generation-requirements"
            aria-labelledby="need-generation-requirements-title"
          >
            <header className="need-generation-requirements-heading">
              <div>
                <span>Bề mặt rà soát chính</span>
                <h3 id="need-generation-requirements-title">
                  Nhu cầu nguyên liệu hiện có
                </h3>
              </div>
              <small>{workbench.pagination.total_groups} nhóm nhu cầu</small>
            </header>

            <div
              className="need-generation-filters"
              aria-label="Bộ lọc nhu cầu"
            >
              <label>
                Ngày
                <input
                  type="date"
                  value={draftFilters.service_date ?? ""}
                  onChange={(event) =>
                    setDraftFilters((current) => ({
                      ...current,
                      service_date: event.target.value || null,
                    }))
                  }
                />
              </label>
              <label>
                Trường
                <select
                  value={draftFilters.school_id ?? ""}
                  onChange={(event) =>
                    setDraftFilters((current) => ({
                      ...current,
                      school_id: event.target.value || null,
                    }))
                  }
                >
                  <option value="">Tất cả</option>
                  {filterOptions.schools.map(([id, name]) => (
                    <option value={id} key={id}>
                      {name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Nguyên liệu
                <select
                  value={draftFilters.ingredient_id ?? ""}
                  onChange={(event) =>
                    setDraftFilters((current) => ({
                      ...current,
                      ingredient_id: event.target.value || null,
                    }))
                  }
                >
                  <option value="">Tất cả</option>
                  {filterOptions.ingredients.map(([id, name]) => (
                    <option value={id} key={id}>
                      {name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Nguồn
                <select
                  value={draftFilters.contribution_family ?? ""}
                  onChange={(event) =>
                    setDraftFilters((current) => ({
                      ...current,
                      contribution_family:
                        (event.target
                          .value as NeedGenerationFilters["contribution_family"]) ||
                        null,
                    }))
                  }
                >
                  <option value="">Tất cả</option>
                  <option value="RECIPE_DERIVED">Công thức</option>
                  <option value="PANTRY_DIRECT">Nhu cầu bổ sung</option>
                </select>
              </label>
              <button type="button" onClick={applyFilters}>
                Lọc
              </button>
            </div>

            <div className="planning-grid-scroll need-generation-table-scroll">
              <CompactTable
                headers={[
                  "Ngày",
                  "Trường",
                  "Điểm giao",
                  "Nguyên liệu",
                  "ĐVT",
                  "Công thức",
                  "Bổ sung",
                  "Tổng",
                  "Chi tiết",
                ]}
              >
                {workbench.grouped_requirements.map((group) => (
                  <tr
                    key={`${group.service_date}:${group.customer_id}:${group.school_id}:${group.delivery_location_id}:${group.ingredient_id}:${group.unit_id}`}
                  >
                    <td>{viDate(group.service_date)}</td>
                    <th scope="row">{group.school_name}</th>
                    <td>{group.delivery_location_name}</td>
                    <td>{group.ingredient_name}</td>
                    <td>{group.unit_name}</td>
                    <td className="quantity-cell">
                      {formatQuantity(group.recipe_derived_quantity)}
                    </td>
                    <td className="quantity-cell">
                      {formatQuantity(group.pantry_direct_quantity)}
                    </td>
                    <td className="quantity-cell total">
                      <b>{formatQuantity(group.total_theoretical_quantity)}</b>
                    </td>
                    <td>
                      <button
                        type="button"
                        onClick={() => {
                          const identity = groupIdentity(group);
                          setDetailGroup(identity);
                          void loadAuthority({ nextDetail: identity });
                        }}
                      >
                        <Eye aria-hidden="true" size={16} />
                        Xem
                      </button>
                    </td>
                  </tr>
                ))}
              </CompactTable>
            </div>

            {detailGroup && (
              <details open className="need-generation-detail">
                <summary>Chi tiết hình thành số lượng</summary>
                <ul>
                  {workbench.atomic_detail.map((item) => (
                    <li key={item.theoretical_need_line_id}>
                      <b>
                        {item.contribution_family === "RECIPE_DERIVED"
                          ? "Công thức"
                          : "Nhu cầu bổ sung"}
                      </b>{" "}
                      · {formatQuantity(item.theoretical_quantity)}{" "}
                      {item.unit_name}
                      <small>
                        {item.dish_name ??
                          item.pantry_purpose ??
                          item.pantry_source_reference ??
                          "Bằng chứng đã chụp"}
                      </small>
                    </li>
                  ))}
                </ul>
              </details>
            )}

            <div className="need-generation-pagination">
              <button
                type="button"
                disabled={offset === 0 || loading}
                onClick={() => {
                  const next = Math.max(0, offset - limit);
                  setOffset(next);
                  void loadAuthority({ nextOffset: next });
                }}
              >
                Trang trước
              </button>
              <span>
                {offset + 1}–
                {Math.min(offset + limit, workbench.pagination.total_groups)} /{" "}
                {workbench.pagination.total_groups}
              </span>
              <button
                type="button"
                disabled={!workbench.pagination.has_more || loading}
                onClick={() => {
                  const next = offset + limit;
                  setOffset(next);
                  void loadAuthority({ nextOffset: next });
                }}
              >
                Trang sau
              </button>
            </div>
          </section>
        </details>
      )}

      {workbench && (
        <details className="planning-history">
          <summary>
            Lịch sử tạo nhu cầu ({workbench.run_history.length})
          </summary>
          <ul>
            {workbench.run_history.map((run) => (
              <li key={run.need_generation_run_id}>
                <button
                  type="button"
                  onClick={() => {
                    setSelectedRunId(run.need_generation_run_id);
                    setDetailGroup(null);
                    void loadAuthority({
                      nextRunId: run.need_generation_run_id,
                      nextDetail: null,
                    });
                  }}
                >
                  Lần #{run.attempt_ordinal} · {runStatusLabel(run.status)} ·
                  phiên bản {run.version}
                </button>
              </li>
            ))}
          </ul>
        </details>
      )}
    </Panel>
  );
}
