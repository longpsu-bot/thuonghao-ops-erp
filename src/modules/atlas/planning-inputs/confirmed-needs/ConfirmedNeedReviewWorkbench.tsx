import { useCallback, useEffect, useMemo, useState } from "react";
import type { AtlasAuthState } from "../../connection/authSession";
import { CompactTable, Panel } from "../../WorkbenchComponents";
import {
  confirmedNeedReleaseV2Request,
  confirmedNeedSaveV2Request,
  type ConfirmedNeedApi,
  type ConfirmedNeedLineRequest,
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
const exportExplanation =
  "Chức năng xuất file sẽ được hoàn thiện sau khi mẫu dữ liệu được chốt.";

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
          <li key={`${item.code}:${index}`}>{item.message || item.code}</li>
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

function differs(line: ConfirmedNeedLine, draft: ConfirmedNeedDraftLine) {
  const initial = initialConfirmedNeedDraft(line);
  return (
    !exactDecimalEqual(initial.exact_quantity, draft.exact_quantity) ||
    initial.reason_code !== draft.reason_code ||
    initial.reason_note.trim() !== draft.reason_note.trim()
  );
}

function draftError(line: ConfirmedNeedLine, draft: ConfirmedNeedDraftLine) {
  if (!normalizeConfirmedNeedQuantity(draft.exact_quantity))
    return "Số lượng phải là số không âm, tối đa 6 chữ số thập phân.";
  const unchanged = exactDecimalEqual(
    draft.exact_quantity,
    line.proposed_confirmed_quantity,
  );
  if (unchanged && draft.reason_code !== "PROPOSAL_ACCEPTED")
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
    differs(line, draft) &&
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
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [workbench, setWorkbench] = useState<ConfirmedNeedWorkbenchData | null>(
    null,
  );
  const [drafts, setDrafts] = useState<Record<string, ConfirmedNeedDraftLine>>(
    {},
  );
  const [search, setSearch] = useState("");
  const [schoolFilter, setSchoolFilter] = useState("");
  const [dateFilter, setDateFilter] = useState("");
  const [confirmationFilter, setConfirmationFilter] = useState<
    "" | "needs_review" | "carried_forward"
  >("");
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [releaseConfirmation, setReleaseConfirmation] = useState(false);
  const [refreshRequired, setRefreshRequired] = useState(false);
  const [pendingSave, setPendingSave] =
    useState<ConfirmedNeedSaveV2Request | null>(null);
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
    setNotice(confirmedNeedResultMessage(result));
    setBusy(false);
  }, [adopt, api, authSubject, correlationId, initialBatchId]);

  useEffect(() => void load(), [load]);

  const changedLines = useMemo(() => {
    if (!workbench) return [];
    return workbench.lines.filter((line) => {
      const draft = drafts[line.confirmed_need_line_id];
      return Boolean(
        draft && (line.current_decision_id === null || differs(line, draft)),
      );
    });
  }, [drafts, workbench]);
  const dirty = changedLines.some((line) => line.current_decision_id !== null);

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
      if (schoolFilter && line.school.id !== schoolFilter) return false;
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
      if (!query) return true;
      return foldSearch(
        `${line.ingredient.name} ${line.school.name} ${line.delivery_location.name}`,
      ).includes(query);
    });
  }, [confirmationFilter, dateFilter, schoolFilter, search, workbench]);

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

  const release = async () => {
    if (
      !api ||
      !authSubject ||
      !workbench ||
      !workbench.allowed_actions.release_confirmed_needs
    )
      return;
    setBusy(true);
    setReleaseConfirmation(false);
    const result = await api.releaseSaved(
      confirmedNeedReleaseV2Request(
        authSubject,
        correlationId,
        workbench.confirmed_need_batch_id,
        workbench.batch_version,
      ),
    );
    const readback = confirmedNeedReadbackFromResult(result);
    if (readback) adopt(readback);
    else if (confirmedNeedResultAllowsExactRetry(result)) {
      setRefreshRequired(true);
      setNotice(
        "Chưa xác định được kết quả chuyển. Hãy làm mới dữ liệu trước khi tiếp tục.",
      );
    } else setNotice(confirmedNeedResultMessage(result));
    if (readback) setNotice("Đã chuyển sang lên đơn.");
    setBusy(false);
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
        <p>Chọn ngày phục vụ ở bảng trên để mở nhu cầu xác nhận.</p>
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
    backendCanRelease &&
    !released &&
    !dirty &&
    !refreshRequired &&
    !busy &&
    errors.length === 0;
  const backendActionReason = dirty
    ? workbench.disabled_reasons.save_confirmed_needs
    : workbench.disabled_reasons.release_confirmed_needs;
  const contextSchool = schoolFilter
    ? schools.find((school) => school.id === schoolFilter)?.name
    : "Tất cả trường";

  return (
    <div className="confirmed-need-shell">
      <header className="confirmed-need-hero">
        <div>
          <p className="confirmed-need-eyebrow">Lập nhu cầu</p>
          <h2>Xác nhận nhu cầu</h2>
          <p className="confirmed-need-period">
            Tuần {viDate(workbench.service_period.period_start)}–
            {viDate(workbench.service_period.period_end)}
          </p>
        </div>
        <div
          className="confirmed-need-context-summary"
          aria-label="Thông tin công việc"
        >
          <strong>{contextSchool}</strong>
          <span>{workbench.line_counts.total} dòng</span>
          {workbench.line_counts.needs_review > 0 && (
            <span>{workbench.line_counts.needs_review} cần rà soát</span>
          )}
          {workbench.line_counts.carried_forward > 0 && (
            <span>{workbench.line_counts.carried_forward} giữ nguyên</span>
          )}
          <span className={`confirmed-need-save-state ${dirty ? "dirty" : ""}`}>
            {statusLabel(workbench, dirty)}
          </span>
        </div>
      </header>

      {notice && (
        <p className="confirmed-need-notice" role="status">
          {notice}
        </p>
      )}
      {refreshRequired && (
        <p className="confirmed-need-attention" role="alert">
          Kết quả thao tác chưa rõ. Atlas sẽ không tự gửi lại. Hãy làm mới dữ
          liệu trước khi tiếp tục.
        </p>
      )}
      {issueList("Cần xử lý", workbench.blockers)}
      {issueList("Cảnh báo", workbench.warnings)}

      <section className="confirmed-need-toolbar" aria-label="Tìm và lọc">
        <label className="confirmed-need-search">
          <span>Tìm kiếm</span>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Tìm theo nguyên liệu, trường, điểm giao…"
          />
        </label>
        <label>
          <span>Trường</span>
          <select
            value={schoolFilter}
            onChange={(event) => setSchoolFilter(event.target.value)}
          >
            <option value="">Tất cả trường</option>
            {schools.map((school) => (
              <option key={school.id} value={school.id}>
                {school.name}
              </option>
            ))}
          </select>
        </label>
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
      </section>

      <p className="confirmed-need-result-count">
        Hiển thị {visibleLines.length}/{workbench.line_counts.total} dòng
      </p>
      <div className="confirmed-need-table-scroll">
        <CompactTable
          headers={[
            "Nguyên liệu",
            "Tình trạng",
            "Trường / điểm giao",
            "Ngày",
            "Nhu cầu tính",
            "Số lượng xác nhận",
            "Chênh lệch",
            "Lý do / ghi chú",
          ]}
        >
          {visibleLines.map((line) => {
            const draft =
              drafts[line.confirmed_need_line_id] ??
              initialConfirmedNeedDraft(line);
            const adjusted = !exactDecimalEqual(
              draft.exact_quantity,
              line.proposed_confirmed_quantity,
            );
            const error = draftError(line, draft);
            return (
              <tr key={line.confirmed_need_line_id}>
                <td>
                  <strong>{line.ingredient.name}</strong>
                  <small>{line.controlled_unit.name}</small>
                </td>
                <td>
                  <span
                    className={`confirmed-need-line-state ${line.confirmation_state.toLocaleLowerCase()}`}
                  >
                    {confirmedNeedConfirmationStateLabel(
                      line.confirmation_state,
                    )}
                  </span>
                </td>
                <td>
                  {line.school.name}
                  <small>{line.delivery_location.name}</small>
                </td>
                <td>{viDate(line.service_date)}</td>
                <td>
                  {exactQuantityDisplay(line.theoretical_quantity)}{" "}
                  {line.controlled_unit.code}
                </td>
                <td>
                  <input
                    aria-label={`Số lượng xác nhận ${line.ingredient.name}`}
                    inputMode="decimal"
                    value={draft.exact_quantity}
                    disabled={released || !workbench.editing_allowed}
                    onChange={(event) => {
                      const exactQuantity = event.target.value;
                      const returnsToProposal = exactDecimalEqual(
                        exactQuantity,
                        line.proposed_confirmed_quantity,
                      );
                      setDrafts((current) => ({
                        ...current,
                        [line.confirmed_need_line_id]: {
                          ...draft,
                          exact_quantity: exactQuantity,
                          reason_code: returnsToProposal
                            ? "PROPOSAL_ACCEPTED"
                            : draft.reason_code === "PROPOSAL_ACCEPTED"
                              ? "PLANNING_STEP_ADJUSTMENT"
                              : draft.reason_code,
                        },
                      }));
                    }}
                  />
                  {error && <small className="field-error">{error}</small>}
                </td>
                <td>
                  {subtractExactDecimals(
                    draft.exact_quantity,
                    line.proposed_confirmed_quantity,
                  ) ?? "—"}
                </td>
                <td>
                  {adjusted ? (
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
      </div>

      <footer className="confirmed-need-actions">
        <div className="confirmed-need-utility-actions">
          <button
            type="button"
            className="quiet"
            onClick={() => void load()}
            disabled={busy}
          >
            Làm mới
          </button>
          <button
            type="button"
            className="quiet"
            disabled
            title={exportExplanation}
            aria-describedby="confirmed-need-export-note"
          >
            Xuất Excel
          </button>
          <button
            type="button"
            className="quiet"
            disabled
            title={exportExplanation}
            aria-describedby="confirmed-need-export-note"
          >
            Xuất PDF
          </button>
          <small id="confirmed-need-export-note">{exportExplanation}</small>
        </div>
        <div className="confirmed-need-business-actions">
          <button
            type="button"
            className={canSave ? "primary" : "secondary"}
            onClick={() => void save()}
            disabled={!canSave}
            title={
              backendCanSave
                ? undefined
                : (workbench.disabled_reasons.save_confirmed_needs ?? undefined)
            }
          >
            Lưu
          </button>
          <button
            type="button"
            className={canRelease ? "primary" : "secondary"}
            onClick={() => setReleaseConfirmation(true)}
            disabled={!canRelease}
            title={
              backendCanRelease
                ? undefined
                : (workbench.disabled_reasons.release_confirmed_needs ??
                  undefined)
            }
          >
            Chuyển sang lên đơn
          </button>
          {backendActionReason && (
            <small role="status">{backendActionReason}</small>
          )}
        </div>
      </footer>

      {releaseConfirmation && (
        <section
          className="confirmed-need-commitment"
          role="dialog"
          aria-modal="true"
          aria-label="Xác nhận chuyển sang lên đơn"
        >
          <h3>Chuyển nhu cầu đã lưu sang bước lên đơn?</h3>
          <p>
            Atlas sẽ kiểm tra toàn bộ dữ liệu và ghi nhận cam kết. Hành động này
            chưa phân bổ nhà cung cấp, chưa tạo Bàn giao mua hàng và chưa tạo
            Đơn mua hàng.
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
    </div>
  );
}
