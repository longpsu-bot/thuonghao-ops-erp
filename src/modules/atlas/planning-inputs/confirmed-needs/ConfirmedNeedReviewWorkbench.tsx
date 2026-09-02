import { useCallback, useEffect, useMemo, useState } from "react";
import type { AtlasAuthState } from "../../connection/authSession";
import { CompactTable, Panel } from "../../WorkbenchComponents";
import {
  planningSchoolScopeLabel,
  schoolInPlanningScope,
} from "../planningSchoolScope";
import { PlanningRailActionPortal } from "../PlanningRailActionPortal";
import {
  confirmedNeedPurchaseHandoffRequest,
  confirmedNeedReleaseV2Request,
  confirmedNeedSaveV2Request,
  type ConfirmedNeedApi,
  type ConfirmedNeedLineRequest,
  type ConfirmedNeedPurchaseHandoffRequest,
  type ConfirmedNeedSaveV2Request,
} from "./confirmedNeedApi";
import {
  confirmedNeedConfirmationStateLabel,
  confirmedNeedReadbackFromResult,
  confirmedNeedReasonLabel,
  confirmedNeedResultAllowsExactRetry,
  confirmedNeedResultMessage,
  confirmedNeedWorkbenchFromResult,
  exactDecimalEqual,
  exactQuantityDisplay,
  initialConfirmedNeedDraft,
  normalizeConfirmedNeedQuantity,
  subtractExactDecimals,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedIssue,
  type ConfirmedNeedLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";

const emptyFilters = {
  service_date: null,
  school_id: null,
  delivery_location_id: null,
  ingredient_id: null,
  decision_state: null,
} as const;
function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function foldSearch(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLocaleLowerCase("vi-VN");
}

function statusLabel(workbench: ConfirmedNeedWorkbenchData, dirty: boolean) {
  if (workbench.authoritative_batch_status === "RELEASED_FOR_PURCHASE_HANDOFF")
    return "Đã chuyển sang lên đơn";
  if (dirty || workbench.line_counts.unreviewed > 0) return "Chưa lưu";
  return "Đã lưu";
}

function issueMessage(item: ConfirmedNeedIssue) {
  const labels: Record<string, string> = {
    CONFIRMED_NEED_BATCH_NOT_REVIEWABLE:
      "Nhu cầu này chưa ở trạng thái có thể rà soát.",
  };
  return labels[item.code] ?? item.message ?? item.code;
}

function actionReason(code: string | null, fallback: string | null) {
  const labels: Record<string, string> = {
    SAVE_CAPABILITY_REQUIRED: "Bạn chưa có quyền lưu thay đổi này.",
    RELEASE_CAPABILITY_REQUIRED: "Bạn chưa có quyền thực hiện bước này.",
    SAVE_BATCH_NOT_EDITABLE: "Dữ liệu này không còn cho phép chỉnh sửa.",
    RELEASE_ALREADY_COMPLETED: "Dữ liệu đã được chuyển sang lên đơn.",
  };
  return (code && labels[code]) || fallback || undefined;
}

function issueList(
  title: "Cần xử lý" | "Cảnh báo",
  items: ConfirmedNeedIssue[],
) {
  if (!items.length) return null;
  return (
    <section
      className={`confirmed-need-issues ${title === "Cần xử lý" ? "danger" : "warning"}`}
      aria-label={title}
    >
      <strong>
        {title} ({items.length})
      </strong>
      <ul>
        {items.map((item, index) => (
          <li key={`${item.code}:${index}`}>{issueMessage(item)}</li>
        ))}
      </ul>
    </section>
  );
}

export function confirmedNeedLineRequest(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
): ConfirmedNeedLineRequest {
  return {
    confirmed_need_line_id: line.confirmed_need_line_id,
    expected_current_revision_id: line.current_revision_id,
    expected_current_decision_id: line.current_decision_id,
    proposed_confirmed_quantity: draft.exact_quantity,
    reason_code: draft.reason_code,
    reason_note: draft.reason_note.trim() || null,
  };
}

function hasUnsavedLocalChange(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) {
  const initial = initialConfirmedNeedDraft(line);
  return (
    line.current_decision_id === null ||
    !exactDecimalEqual(initial.exact_quantity, draft.exact_quantity) ||
    initial.reason_code !== draft.reason_code ||
    initial.reason_note.trim() !== draft.reason_note.trim()
  );
}

function draftError(line: ConfirmedNeedLine, draft: ConfirmedNeedDraftLine) {
  if (!normalizeConfirmedNeedQuantity(draft.exact_quantity))
    return "Số lượng phải là số không âm, tối đa 6 chữ số thập phân.";
  const initial = initialConfirmedNeedDraft(line);
  const unchanged = exactDecimalEqual(
    draft.exact_quantity,
    line.proposed_confirmed_quantity,
  );
  const preservesSavedAdjustment =
    line.current_decision_id !== null &&
    initial.reason_code !== "PROPOSAL_ACCEPTED";
  if (
    unchanged &&
    draft.reason_code !== "PROPOSAL_ACCEPTED" &&
    !preservesSavedAdjustment
  )
    return "Số lượng không đổi nên không cần lý do điều chỉnh.";
  if (!unchanged && draft.reason_code === "PROPOSAL_ACCEPTED")
    return "Hãy chọn lý do khi thay đổi số lượng.";
  if (
    ["OPERATIONAL_QUANTITY_ADJUSTMENT", "OTHER"].includes(draft.reason_code) &&
    !draft.reason_note.trim()
  )
    return "Lý do này cần ghi chú.";
  if (
    line.current_decision_id &&
    hasUnsavedLocalChange(line, draft) &&
    !draft.reason_note.trim()
  )
    return "Thay đổi nội dung đã lưu cần ghi chú.";
  return null;
}

export function ConfirmedNeedReviewWorkbench({
  authState,
  api,
  initialBatchId,
  currentNeedResolution = initialBatchId ? "available" : "idle",
  onDirtyChange,
  schoolScopeIds = [],
  onPurchaseHandoffReleased,
}: {
  authState: AtlasAuthState;
  api?: ConfirmedNeedApi;
  initialBatchId?: string | null;
  currentNeedResolution?:
    | "idle"
    | "loading"
    | "available"
    | "selection_required"
    | "missing"
    | "denied"
    | "error";
  mode?: "connected" | "review";
  onDirtyChange?: (dirty: boolean) => void;
  schoolScopeIds?: string[];
  onPurchaseHandoffReleased?: () => void;
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [workbench, setWorkbench] = useState<ConfirmedNeedWorkbenchData | null>(
    null,
  );
  const [drafts, setDrafts] = useState<Record<string, ConfirmedNeedDraftLine>>(
    {},
  );
  const [search, setSearch] = useState("");
  const [dateFilter, setDateFilter] = useState("");
  const [confirmationFilter, setConfirmationFilter] = useState<
    "" | "needs_review" | "carried_forward"
  >("");
  const [showDifferencesOnly, setShowDifferencesOnly] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [releaseConfirmation, setReleaseConfirmation] = useState(false);
  const [refreshRequired, setRefreshRequired] = useState(false);
  const [pendingSave, setPendingSave] =
    useState<ConfirmedNeedSaveV2Request | null>(null);
  const [pendingHandoff, setPendingHandoff] =
    useState<ConfirmedNeedPurchaseHandoffRequest | null>(null);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const adopt = useCallback((next: ConfirmedNeedWorkbenchData) => {
    setWorkbench(next);
    setDrafts(
      Object.fromEntries(
        next.lines.map((line) => [
          line.confirmed_need_line_id,
          initialConfirmedNeedDraft(line),
        ]),
      ),
    );
    setRefreshRequired(false);
    setPendingSave(null);
  }, []);

  const load = useCallback(async () => {
    if (!api || !authSubject || !initialBatchId) return;
    setBusy(true);
    const result = await api.getReview(
      authSubject,
      correlationId,
      initialBatchId,
      emptyFilters,
      0,
      10_000,
    );
    const next = confirmedNeedWorkbenchFromResult(result);
    if (next) adopt(next);
    setNotice(
      result.kind === "success" ? null : confirmedNeedResultMessage(result),
    );
    setBusy(false);
  }, [adopt, api, authSubject, correlationId, initialBatchId]);

  useEffect(() => void load(), [load]);
  useEffect(() => {
    setPendingHandoff(null);
    setReleaseConfirmation(false);
  }, [initialBatchId]);

  const changedLines = useMemo(() => {
    if (!workbench) return [];
    return workbench.lines.filter((line) => {
      const draft = drafts[line.confirmed_need_line_id];
      return Boolean(draft && hasUnsavedLocalChange(line, draft));
    });
  }, [drafts, workbench]);
  const dirty = changedLines.length > 0;

  useEffect(
    () => onDirtyChange?.(dirty || refreshRequired),
    [dirty, onDirtyChange, refreshRequired],
  );
  useEffect(() => {
    if (!dirty && !refreshRequired) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty, refreshRequired]);

  const errors = useMemo(
    () =>
      changedLines.flatMap((line) => {
        const message = draftError(line, drafts[line.confirmed_need_line_id]!);
        return message ? [`${line.ingredient.name}: ${message}`] : [];
      }),
    [changedLines, drafts],
  );

  const schools = useMemo(
    () =>
      workbench
        ? Array.from(
            new Map(
              workbench.lines.map((line) => [line.school.id, line.school]),
            ).values(),
          ).sort((a, b) => a.name.localeCompare(b.name, "vi"))
        : [],
    [workbench],
  );
  const dates = useMemo(
    () =>
      workbench
        ? Array.from(
            new Set(workbench.lines.map((line) => line.service_date)),
          ).sort()
        : [],
    [workbench],
  );
  const visibleLines = useMemo(() => {
    if (!workbench) return [];
    const query = foldSearch(search.trim());
    return workbench.lines.filter((line) => {
      if (!schoolInPlanningScope(line.school.id, schoolScopeIds)) return false;
      if (dateFilter && line.service_date !== dateFilter) return false;
      if (
        confirmationFilter === "needs_review" &&
        !["CHANGED", "NEW", "UNREVIEWED"].includes(line.confirmation_state)
      )
        return false;
      if (
        confirmationFilter === "carried_forward" &&
        line.confirmation_state !== "CARRIED_FORWARD"
      )
        return false;
      if (
        query &&
        !foldSearch(
          `${line.ingredient.name} ${line.school.name} ${line.delivery_location.name}`,
        ).includes(query)
      )
        return false;
      const draft = drafts[line.confirmed_need_line_id];
      return !(
        showDifferencesOnly &&
        draft &&
        !hasUnsavedLocalChange(line, draft)
      );
    });
  }, [
    confirmationFilter,
    dateFilter,
    drafts,
    schoolScopeIds,
    search,
    showDifferencesOnly,
    workbench,
  ]);

  const hiddenDirtyCount = changedLines.filter(
    (line) => !schoolInPlanningScope(line.school.id, schoolScopeIds),
  ).length;

  const save = async () => {
    if (
      !api ||
      !authSubject ||
      !workbench ||
      !workbench.allowed_actions.save_confirmed_needs ||
      !changedLines.length ||
      errors.length
    )
      return;
    const request = confirmedNeedSaveV2Request(
      authSubject,
      correlationId,
      workbench.confirmed_need_batch_id,
      workbench.batch_version,
      changedLines.map((line) =>
        confirmedNeedLineRequest(line, drafts[line.confirmed_need_line_id]!),
      ),
    );
    setPendingSave(request);
    setBusy(true);
    const result = await api.save(request);
    const readback = confirmedNeedReadbackFromResult(result);
    if (readback) adopt(readback);
    else if (confirmedNeedResultAllowsExactRetry(result)) {
      setRefreshRequired(true);
      setNotice(
        "Chưa xác định được kết quả lưu. Hãy làm mới dữ liệu trước khi tiếp tục.",
      );
    } else setNotice(confirmedNeedResultMessage(result));
    if (readback) setNotice("Đã lưu thay đổi.");
    setBusy(false);
  };

  const releaseHandoff = async (
    request: ConfirmedNeedPurchaseHandoffRequest,
  ) => {
    if (!api) return;
    setBusy(true);
    const result = await api.releasePurchaseHandoff(request);
    if (result.kind === "success") {
      setPendingHandoff(null);
      await load();
      setNotice("Đã chuyển sang lên đơn.");
      setBusy(false);
      onPurchaseHandoffReleased?.();
      return;
    }
    setPendingHandoff(request);
    setNotice(
      `Nhu cầu đã được phát hành. Bàn giao mua hàng chưa hoàn tất. ${confirmedNeedResultMessage(result)}`,
    );
    setBusy(false);
  };

  const release = async () => {
    if (!api || !authSubject || !workbench) return;
    setBusy(true);
    setReleaseConfirmation(false);
    const alreadyReleased =
      workbench.authoritative_batch_status === "RELEASED_FOR_PURCHASE_HANDOFF";
    let releasedWorkbench = workbench;
    if (!alreadyReleased) {
      if (!workbench.allowed_actions.release_confirmed_needs) {
        setBusy(false);
        return;
      }
      const result = await api.releaseSaved(
        confirmedNeedReleaseV2Request(
          authSubject,
          correlationId,
          workbench.confirmed_need_batch_id,
          workbench.batch_version,
        ),
      );
      const readback = confirmedNeedReadbackFromResult(result);
      if (!readback) {
        if (confirmedNeedResultAllowsExactRetry(result)) {
          setRefreshRequired(true);
          setNotice(
            "Chưa xác định được kết quả chuyển. Hãy làm mới dữ liệu trước khi tiếp tục.",
          );
        } else setNotice(confirmedNeedResultMessage(result));
        setBusy(false);
        return;
      }
      adopt(readback);
      releasedWorkbench = readback;
    }
    const handoffRequest =
      pendingHandoff ??
      confirmedNeedPurchaseHandoffRequest(
        authSubject,
        correlationId,
        releasedWorkbench.confirmed_need_batch_id,
        releasedWorkbench.batch_version,
      );
    await releaseHandoff(handoffRequest);
  };

  if (currentNeedResolution === "loading" || (busy && !workbench))
    return (
      <Panel title="Xác nhận nhu cầu">
        <p>Đang tải dữ liệu…</p>
      </Panel>
    );
  if (currentNeedResolution === "denied")
    return (
      <Panel title="Xác nhận nhu cầu">
        <p>Bạn không có quyền xem dữ liệu này.</p>
      </Panel>
    );
  if (currentNeedResolution === "error")
    return (
      <Panel title="Xác nhận nhu cầu">
        <p>Không thể tải nhu cầu hiện tại.</p>
      </Panel>
    );
  if (currentNeedResolution === "selection_required")
    return (
      <Panel title="Xác nhận nhu cầu">
        <p>Chọn ngày phục vụ ở trên để mở nhu cầu xác nhận.</p>
      </Panel>
    );
  if (!initialBatchId || ["idle", "missing"].includes(currentNeedResolution))
    return (
      <Panel title="Xác nhận nhu cầu">
        <p>Chưa có nhu cầu cho tuần đã chọn.</p>
      </Panel>
    );
  if (!workbench || workbench.confirmed_need_batch_id !== initialBatchId)
    return (
      <Panel title="Xác nhận nhu cầu">
        <p>Đang tải dữ liệu…</p>
      </Panel>
    );

  const released =
    workbench.authoritative_batch_status === "RELEASED_FOR_PURCHASE_HANDOFF";
  const backendCanSave = workbench.allowed_actions.save_confirmed_needs;
  const backendCanRelease = workbench.allowed_actions.release_confirmed_needs;
  const canSave =
    backendCanSave &&
    !released &&
    !busy &&
    !refreshRequired &&
    changedLines.length > 0 &&
    errors.length === 0;
  const canRelease =
    (backendCanRelease || released) &&
    !dirty &&
    !refreshRequired &&
    !busy &&
    errors.length === 0;
  const contextSchool = planningSchoolScopeLabel(
    schoolScopeIds,
    schools.map((school, index) => ({
      school_id: school.id,
      school_code: "",
      school_name: school.name,
      display_order: index + 1,
    })),
  );

  return (
    <section className="confirmed-need-shell" aria-label="Bàn xác nhận nhu cầu">
      <PlanningRailActionPortal>
        <div className="confirmed-need-rail-action">
          {changedLines.length > 0 ? (
            <button
              type="button"
              className={canSave ? "primary" : "secondary"}
              onClick={() => void save()}
              disabled={!canSave}
              title={
                backendCanSave
                  ? undefined
                  : actionReason(
                      workbench.disabled_reason_codes.save_confirmed_needs,
                      workbench.disabled_reasons.save_confirmed_needs,
                    )
              }
            >
              Lưu
            </button>
          ) : (
            <button
              type="button"
              className={canRelease ? "primary" : "secondary"}
              onClick={() => setReleaseConfirmation(true)}
              disabled={!canRelease}
              title={
                backendCanRelease || released
                  ? undefined
                  : actionReason(
                      workbench.disabled_reason_codes.release_confirmed_needs,
                      workbench.disabled_reasons.release_confirmed_needs,
                    )
              }
            >
              Chuyển sang lên đơn
            </button>
          )}
        </div>
      </PlanningRailActionPortal>

      <header className="confirmed-need-heading">
        <div>
          <h2>Xác nhận nhu cầu</h2>
          <p className="confirmed-need-period">
            Tuần {viDate(workbench.service_period.period_start)}–
            {viDate(workbench.service_period.period_end)}
          </p>
        </div>
      </header>

      <section
        className="confirmed-need-summary-strip"
        aria-label="Tóm tắt xác nhận nhu cầu"
      >
        <strong>{contextSchool}</strong>
        <span>{workbench.line_counts.total} dòng</span>
        <span>{workbench.line_counts.needs_review} cần rà soát</span>
        <span>{workbench.line_counts.confirmed} đã xác nhận</span>
        <span>{workbench.line_counts.adjusted} đã điều chỉnh</span>
        <span
          className={`confirmed-need-save-state ${changedLines.length ? "dirty" : ""}`}
        >
          {statusLabel(workbench, dirty)}
        </span>
      </section>

      {notice && (
        <p className="confirmed-need-notice" role="status">
          {notice}
        </p>
      )}
      {pendingHandoff && (
        <section
          className="confirmed-need-notice confirmed-need-handoff-recovery"
          aria-label="Khôi phục Bàn giao mua hàng"
        >
          <strong>Nhu cầu đã phát hành; Bàn giao mua hàng còn chờ.</strong>
          <button
            type="button"
            className="primary"
            disabled={busy}
            onClick={() => void releaseHandoff(pendingHandoff)}
          >
            Thử lại bàn giao
          </button>
        </section>
      )}
      {refreshRequired && (
        <div className="confirmed-need-attention" role="alert">
          <span>
            Kết quả thao tác chưa rõ. Atlas sẽ không tự gửi lại. Hãy làm mới dữ
            liệu trước khi tiếp tục.
          </span>
          <button type="button" onClick={() => void load()} disabled={busy}>
            Làm mới
          </button>
        </div>
      )}
      {issueList("Cần xử lý", workbench.blockers)}
      {issueList("Cảnh báo", workbench.warnings)}
      {hiddenDirtyCount > 0 && (
        <p className="confirmed-need-attention" role="status">
          Có {hiddenDirtyCount} thay đổi chưa lưu ngoài phạm vi trường đang hiển
          thị. Lưu vẫn áp dụng cho toàn bộ thay đổi hiện tại.
        </p>
      )}

      <section
        className="confirmed-need-toolbar"
        aria-label="Bộ lọc xác nhận nhu cầu"
      >
        <label className="confirmed-need-search">
          <span>Tìm kiếm</span>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Tìm theo nguyên liệu, trường, điểm giao…"
          />
        </label>
        {dates.length > 1 && (
          <label>
            <span>Ngày</span>
            <select
              value={dateFilter}
              onChange={(event) => setDateFilter(event.target.value)}
            >
              <option value="">Tất cả ngày</option>
              {dates.map((date) => (
                <option key={date} value={date}>
                  {viDate(date)}
                </option>
              ))}
            </select>
          </label>
        )}
        <label>
          <span>Tình trạng</span>
          <select
            value={confirmationFilter}
            onChange={(event) =>
              setConfirmationFilter(
                event.target.value as "" | "needs_review" | "carried_forward",
              )
            }
          >
            <option value="">Tất cả</option>
            <option value="needs_review">Cần rà soát</option>
            <option value="carried_forward">Giữ nguyên</option>
          </select>
        </label>
        <label className="confirmed-need-difference-filter">
          <input
            type="checkbox"
            checked={showDifferencesOnly}
            onChange={(event) => setShowDifferencesOnly(event.target.checked)}
          />
          <span>Chỉ hiển thị thay đổi chưa lưu</span>
        </label>
      </section>

      <p className="confirmed-need-result-count">
        Hiển thị {visibleLines.length}/{workbench.line_counts.total} dòng
      </p>
      <section
        className="confirmed-need-table-scroll"
        aria-label="Bảng xác nhận nhu cầu"
      >
        <CompactTable
          headers={[
            "Nguyên liệu / nơi nhận",
            "Đơn vị",
            "Nhu cầu tính",
            "Số lượng xác nhận",
            "Thay đổi chưa lưu",
            "Lý do / ghi chú",
          ]}
        >
          {visibleLines.map((line) => {
            const draft =
              drafts[line.confirmed_need_line_id] ??
              initialConfirmedNeedDraft(line);
            const initial = initialConfirmedNeedDraft(line);
            const rowHasUnsavedChange = hasUnsavedLocalChange(line, draft);
            const showsAdjustmentReason =
              draft.reason_code !== "PROPOSAL_ACCEPTED";
            const delta = rowHasUnsavedChange
              ? subtractExactDecimals(
                  draft.exact_quantity,
                  initial.exact_quantity,
                )
              : null;
            const error = rowHasUnsavedChange ? draftError(line, draft) : null;
            return (
              <tr key={line.confirmed_need_line_id}>
                <td>
                  <strong>{line.ingredient.name}</strong>
                  <span
                    className={`confirmed-need-line-state ${line.confirmation_state.toLocaleLowerCase()}`}
                  >
                    {confirmedNeedConfirmationStateLabel(
                      line.confirmation_state,
                    )}
                  </span>
                  <small>{line.school.name}</small>
                  <small>{line.delivery_location.name}</small>
                </td>
                <td>{line.controlled_unit.code}</td>
                <td>{exactQuantityDisplay(line.theoretical_quantity)}</td>
                <td>
                  <input
                    aria-label={`Số lượng xác nhận ${line.ingredient.name}`}
                    inputMode="decimal"
                    value={draft.exact_quantity}
                    disabled={released || !workbench.editing_allowed}
                    onChange={(event) => {
                      const exactQuantity = event.target.value;
                      const returnsToSavedBaseline = exactDecimalEqual(
                        exactQuantity,
                        initial.exact_quantity,
                      );
                      setDrafts((current) => ({
                        ...current,
                        [line.confirmed_need_line_id]: {
                          ...draft,
                          exact_quantity: exactQuantity,
                          reason_code: returnsToSavedBaseline
                            ? initial.reason_code
                            : draft.reason_code === "PROPOSAL_ACCEPTED"
                              ? "PLANNING_STEP_ADJUSTMENT"
                              : draft.reason_code,
                          reason_note: returnsToSavedBaseline
                            ? initial.reason_note
                            : draft.reason_note,
                        },
                      }));
                    }}
                  />
                  {error && <small className="field-error">{error}</small>}
                </td>
                <td>{delta && delta !== "0" ? delta : "—"}</td>
                <td>
                  {showsAdjustmentReason ? (
                    <>
                      <select
                        aria-label={`Lý do điều chỉnh ${line.ingredient.name}`}
                        value={draft.reason_code}
                        disabled={released || !workbench.editing_allowed}
                        onChange={(event) =>
                          setDrafts((current) => ({
                            ...current,
                            [line.confirmed_need_line_id]: {
                              ...draft,
                              reason_code: event.target
                                .value as ConfirmedNeedDraftLine["reason_code"],
                            },
                          }))
                        }
                      >
                        <option value="PLANNING_STEP_ADJUSTMENT">
                          Điều chỉnh theo quy cách
                        </option>
                        <option value="OPERATIONAL_QUANTITY_ADJUSTMENT">
                          Điều chỉnh vận hành
                        </option>
                        <option value="OTHER">Lý do khác</option>
                      </select>
                      <input
                        aria-label={`Ghi chú ${line.ingredient.name}`}
                        placeholder="Ghi chú khi cần"
                        value={draft.reason_note}
                        disabled={released || !workbench.editing_allowed}
                        onChange={(event) =>
                          setDrafts((current) => ({
                            ...current,
                            [line.confirmed_need_line_id]: {
                              ...draft,
                              reason_note: event.target.value,
                            },
                          }))
                        }
                      />
                    </>
                  ) : (
                    <span>{confirmedNeedReasonLabel("PROPOSAL_ACCEPTED")}</span>
                  )}
                </td>
              </tr>
            );
          })}
        </CompactTable>
      </section>

      {releaseConfirmation && (
        <section
          className="confirmed-need-commitment"
          role="dialog"
          aria-modal="true"
          aria-label="Xác nhận chuyển sang lên đơn"
        >
          <h3>Chuyển nhu cầu đã lưu sang bước lên đơn?</h3>
          <p>
            Atlas sẽ kiểm tra và phát hành nhu cầu đã lưu, sau đó tạo hoặc cập
            nhật Bàn giao mua hàng sang Thu mua. Bước này chưa phân bổ nhà cung
            cấp và chưa tạo Đơn mua.
          </p>
          <div>
            <button
              type="button"
              className="secondary"
              onClick={() => setReleaseConfirmation(false)}
            >
              Quay lại
            </button>
            <button
              type="button"
              className="primary"
              onClick={() => void release()}
            >
              Xác nhận chuyển
            </button>
          </div>
        </section>
      )}

      {workbench.lifecycle_history.length > 0 && (
        <details className="confirmed-need-history">
          <summary>Lịch sử xử lý</summary>
          <ul>
            {workbench.lifecycle_history.map((item) => (
              <li key={item.evidence_id}>
                {viDate(item.occurred_at)} · {item.actor.name}
              </li>
            ))}
          </ul>
        </details>
      )}
      {pendingSave && refreshRequired && (
        <span hidden>{pendingSave.command_id}</span>
      )}
    </section>
  );
}
