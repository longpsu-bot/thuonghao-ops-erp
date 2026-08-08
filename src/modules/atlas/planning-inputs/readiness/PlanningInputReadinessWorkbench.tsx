import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowClockwise,
  Checks,
  ClockCounterClockwise,
  Lightning,
  Wrench,
} from "@phosphor-icons/react";
import type { AtlasAuthState } from "../../connection/authSession";
import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";
import { Chip, Panel } from "../../WorkbenchComponents";
import {
  planningInputReadinessCommandRequest,
  type PlanningInputReadinessApi,
  type PlanningInputReadinessCommandRequest,
} from "./planningInputReadinessApi";
import {
  historicalPantryMessage,
  invalidationReasonRequiresNote,
  mergeReadinessHistory,
  pantryReadinessEvidenceLabel,
  planningInputReadinessReadbackFromResult,
  planningInputReadinessWorkbenchFromResult,
  readinessCandidateKey,
  readinessCandidateTriple,
  readinessDecisionLabel,
  readinessExpectation,
  readinessResultAllowsExactRetry,
  readinessResultIsStale,
  readinessResultMessage,
  readinessSourceSelection,
  type PlanningInputReadinessWorkbenchData,
  type ReadinessCandidate,
  type ReadinessIssue,
  type ReadinessSourceKind,
} from "./planningInputReadinessModel";

type CommandOperation = "evaluate" | "requestNeedGeneration" | "invalidate";
type PendingCommand = {
  operation: CommandOperation;
  request: PlanningInputReadinessCommandRequest;
  retryable: boolean;
  uncertain: boolean;
};

const sources: { key: ReadinessSourceKind; label: string }[] = [
  { key: "weekly_menu", label: "Thực đơn tuần" },
  { key: "attendance", label: "Sĩ số" },
  { key: "pantry", label: "Pantry" },
];

function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function selectionLabel(state: string) {
  const labels: Record<string, string> = {
    SELECTED: "ĐÃ CHỌN",
    MISSING: "THIẾU",
    AMBIGUOUS: "CẦN CHỌN",
    STALE: "ĐÃ CŨ",
  };
  return labels[state] ?? state;
}

function sourceVersion(source: ReadinessSourceKind, item: ReadinessCandidate) {
  return source === "weekly_menu"
    ? item.weekly_menu_version
    : source === "attendance"
      ? item.attendance_version
      : item.pantry_need_batch_version;
}

function sourceSnapshotId(
  source: ReadinessSourceKind,
  item: ReadinessCandidate,
) {
  return source === "weekly_menu"
    ? item.weekly_menu_approval_snapshot_id
    : source === "attendance"
      ? item.attendance_approval_snapshot_id
      : item.pantry_need_approval_snapshot_id;
}

function candidateLabel(source: ReadinessSourceKind, item: ReadinessCandidate) {
  return `${viDate(item.source_period.period_start)}–${viDate(item.source_period.period_end)} · phiên bản ${sourceVersion(source, item)} · ${item.approved_by_display_name}`;
}

function SourceCard({
  source,
  label,
  workbench,
  onSelect,
  disabled,
}: {
  source: ReadinessSourceKind;
  label: string;
  workbench: PlanningInputReadinessWorkbenchData;
  onSelect: (candidate: ReadinessCandidate) => void;
  disabled: boolean;
}) {
  const evidence = workbench.source_evidence[source];
  const selected = evidence.selected;
  return (
    <article
      className={`readiness-source-card ${evidence.selection_state.toLowerCase()}`}
    >
      <header>
        <div>
          <span>Nguồn bằng chứng</span>
          <h3>{label}</h3>
        </div>
        <Chip
          tone={
            evidence.selection_state === "SELECTED"
              ? "ok"
              : evidence.selection_state === "STALE"
                ? "danger"
                : "warning"
          }
        >
          {selectionLabel(evidence.selection_state)}
        </Chip>
      </header>

      {evidence.selection_state === "AMBIGUOUS" && (
        <label>
          Chọn bằng chứng {label}
          <select
            aria-label={`Chọn bằng chứng ${label}`}
            defaultValue=""
            disabled={disabled}
            onChange={(event) => {
              const item = evidence.candidates.find(
                (candidate) =>
                  readinessCandidateKey(source, candidate) ===
                  event.target.value,
              );
              if (item) onSelect(item);
            }}
          >
            <option value="" disabled>
              Chọn một bản phê duyệt…
            </option>
            {evidence.candidates.map((candidate) => (
              <option
                key={readinessCandidateKey(source, candidate)}
                value={readinessCandidateKey(source, candidate)}
              >
                {candidateLabel(source, candidate)}
              </option>
            ))}
          </select>
        </label>
      )}

      {selected ? (
        <dl>
          <div>
            <dt>Kỳ nguồn</dt>
            <dd>
              {viDate(selected.source_period.period_start)} –{" "}
              {viDate(selected.source_period.period_end)}
            </dd>
          </div>
          <div>
            <dt>Phiên bản phê duyệt</dt>
            <dd>v{sourceVersion(source, selected)}</dd>
          </div>
          <div>
            <dt>Phê duyệt</dt>
            <dd>
              {selected.approved_by_display_name} ·{" "}
              {new Date(selected.approved_at).toLocaleString("vi-VN")}
            </dd>
          </div>
          <div>
            <dt>Hiện hành / phủ kỳ</dt>
            <dd>
              {selected.source_current ? "Hiện hành" : "Không hiện hành"} ·{" "}
              {selected.coverage === "COVERS" ? "Đủ kỳ" : "Không đủ kỳ"}
            </dd>
          </div>
          {source !== "pantry" && (
            <div>
              <dt>Số dòng</dt>
              <dd>{selected.line_count}</dd>
            </div>
          )}
        </dl>
      ) : (
        evidence.selection_state !== "AMBIGUOUS" && (
          <p className="readiness-source-empty">{evidence.safe_message}</p>
        )
      )}

      {source === "pantry" && (
        <p className="readiness-pantry-evidence">
          {pantryReadinessEvidenceLabel(evidence)}
        </p>
      )}

      {selected && (
        <details className="readiness-source-audit">
          <summary>Định danh bằng chứng</summary>
          <code>{sourceSnapshotId(source, selected)}</code>
        </details>
      )}
    </article>
  );
}

function Issues({
  title,
  tone,
  items,
}: {
  title: string;
  tone: "danger" | "warning";
  items: ReadinessIssue[];
}) {
  if (!items.length) return null;
  return (
    <section className={`planning-issues ${tone}`} aria-label={title}>
      <strong>
        {title} ({items.length})
      </strong>
      <ul>
        {items.map((item) => (
          <li key={item.planning_input_readiness_issue_id}>
            {item.safe_message}
            {(item.school_id || item.service_date) && (
              <small>
                {[
                  item.school_id,
                  item.service_date && viDate(item.service_date),
                ]
                  .filter(Boolean)
                  .join(" · ")}
              </small>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}

export function PlanningInputReadinessWorkbench({
  authState,
  api,
  selectedWeekStart,
  selectedWeekEnd,
  historyLimit = 25,
  confirmDiscard = (message) => window.confirm(message),
  onLocalSelectionDirtyChange,
}: {
  authState: AtlasAuthState;
  api?: PlanningInputReadinessApi;
  selectedWeekStart: string;
  selectedWeekEnd: string;
  mode?: "connected" | "review";
  historyLimit?: number;
  confirmDiscard?: (message: string) => boolean;
  onLocalSelectionDirtyChange?: (dirty: boolean) => void;
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [periodStart, setPeriodStart] = useState(selectedWeekStart);
  const [periodEnd, setPeriodEnd] = useState(selectedWeekEnd);
  const [draftStart, setDraftStart] = useState(selectedWeekStart);
  const [draftEnd, setDraftEnd] = useState(selectedWeekEnd);
  const [workbench, setWorkbench] =
    useState<PlanningInputReadinessWorkbenchData | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [selectionTouched, setSelectionTouched] = useState(false);
  const [invalidationReason, setInvalidationReason] = useState("");
  const [invalidationNote, setInvalidationNote] = useState("");
  const [pendingCommand, setPendingCommand] = useState<PendingCommand | null>(
    null,
  );
  const generation = useRef(0);
  const commandGeneration = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const loadWorkbench = useCallback(
    async ({
      sourceSelection,
      cursor = null,
      append = false,
    }: {
      sourceSelection?: Record<string, JsonValue>;
      cursor?: string | null;
      append?: boolean;
    } = {}) => {
      if (!api || !authSubject) return false;
      const requestGeneration = ++generation.current;
      setLoading(true);
      if (!append) setNotice(null);
      const result = await api.getWorkbench(
        authSubject,
        correlationId,
        periodStart,
        periodEnd,
        sourceSelection,
        historyLimit,
        cursor,
      );
      if (requestGeneration !== generation.current) return false;
      setLoading(false);
      const next = planningInputReadinessWorkbenchFromResult(result);
      if (!next) {
        setNotice(readinessResultMessage(result));
        if (!append) setWorkbench(null);
        return false;
      }
      setWorkbench((current) =>
        append && current ? mergeReadinessHistory(current, next) : next,
      );
      setInvalidationReason(
        next.allowed_actions.invalidation_reason_codes[0] ?? "",
      );
      return true;
    },
    [api, authSubject, correlationId, historyLimit, periodEnd, periodStart],
  );

  useEffect(() => {
    void loadWorkbench();
    return () => {
      generation.current += 1;
      commandGeneration.current += 1;
    };
  }, [loadWorkbench]);

  useEffect(() => {
    onLocalSelectionDirtyChange?.(selectionTouched);
    return () => onLocalSelectionDirtyChange?.(false);
  }, [onLocalSelectionDirtyChange, selectionTouched]);

  const applyPeriod = (nextStart: string, nextEnd: string) => {
    if (!nextStart || !nextEnd || nextEnd < nextStart) {
      setNotice("Cần chọn kỳ bao gồm Từ ngày và Đến ngày hợp lệ.");
      return;
    }
    if (
      selectionTouched &&
      !confirmDiscard(
        "Đổi kỳ sẽ bỏ các lựa chọn bằng chứng chưa đánh giá. Tiếp tục?",
      )
    )
      return;
    generation.current += 1;
    commandGeneration.current += 1;
    setSelectionTouched(false);
    setPendingCommand(null);
    setWorkbench(null);
    setNotice(null);
    setDraftStart(nextStart);
    setDraftEnd(nextEnd);
    setPeriodStart(nextStart);
    setPeriodEnd(nextEnd);
  };

  const selectCandidate = async (
    source: ReadinessSourceKind,
    candidate: ReadinessCandidate,
  ) => {
    if (!workbench) return;
    const selection = readinessSourceSelection(workbench);
    selection[source] = readinessCandidateTriple(source, candidate);
    setSelectionTouched(true);
    setWorkbench(null);
    await loadWorkbench({ sourceSelection: selection });
  };

  const executeCommand = useCallback(
    async (
      operation: CommandOperation,
      request: PlanningInputReadinessCommandRequest,
    ) => {
      if (!api) return;
      const activeGeneration = ++commandGeneration.current;
      setBusy(true);
      setNotice(null);
      const result: AtlasRpcResult = await api[operation](request);
      if (activeGeneration !== commandGeneration.current) return;
      setBusy(false);
      const readback = planningInputReadinessReadbackFromResult(result);
      if (readback) {
        setWorkbench(readback);
        setSelectionTouched(false);
        setPendingCommand(null);
        setInvalidationReason(
          readback.allowed_actions.invalidation_reason_codes[0] ?? "",
        );
        setInvalidationNote("");
        setNotice(readinessResultMessage(result));
        return;
      }
      const retryable = readinessResultAllowsExactRetry(result);
      const uncertain = result.kind === "transport_error";
      if (retryable || uncertain)
        setPendingCommand({ operation, request, retryable, uncertain });
      setNotice(readinessResultMessage(result));
      if (readinessResultIsStale(result)) {
        setWorkbench(null);
        await loadWorkbench();
      }
    },
    [api, loadWorkbench],
  );

  const evaluate = () => {
    if (!authSubject || !workbench) return;
    const request = planningInputReadinessCommandRequest(
      authSubject,
      correlationId,
      readinessExpectation(workbench),
      "READINESS_EVALUATION_REQUESTED",
      null,
      {
        period_start: periodStart,
        period_end: periodEnd,
        source_candidates: readinessSourceSelection(workbench),
      },
    );
    void executeCommand("evaluate", request);
  };

  const requestNeedGeneration = () => {
    if (!authSubject || !workbench?.root) return;
    const request = planningInputReadinessCommandRequest(
      authSubject,
      correlationId,
      readinessExpectation(workbench),
      "NEED_GENERATION_HANDOFF_REQUESTED",
      null,
      {
        planning_input_set_id: workbench.root.planning_input_set_id,
        period_start: periodStart,
        period_end: periodEnd,
      },
    );
    void executeCommand("requestNeedGeneration", request);
  };

  const invalidate = () => {
    if (!authSubject || !workbench?.root || !invalidationReason) return;
    const note = invalidationNote.trim() || null;
    if (invalidationReasonRequiresNote(invalidationReason) && !note) {
      setNotice("Cần nhập ghi chú cho lý do vô hiệu đã chọn.");
      return;
    }
    const request = planningInputReadinessCommandRequest(
      authSubject,
      correlationId,
      readinessExpectation(workbench),
      invalidationReason,
      note,
      {
        planning_input_set_id: workbench.root.planning_input_set_id,
        period_start: periodStart,
        period_end: periodEnd,
      },
    );
    void executeCommand("invalidate", request);
  };

  const currentIssues = workbench?.current_evaluation?.issues;
  const canSubmitInvalidation =
    Boolean(invalidationReason) &&
    (!invalidationReasonRequiresNote(invalidationReason) ||
      Boolean(invalidationNote.trim()));
  const currentSelection = useMemo(
    () => (workbench ? readinessSourceSelection(workbench) : undefined),
    [workbench],
  );

  if (!authSubject)
    return (
      <p className="operator-notice warning">
        Đăng nhập để đọc trạng thái sẵn sàng đầu vào.
      </p>
    );

  return (
    <section className="planning-input-readiness-workbench">
      <header className="readiness-question">
        <div>
          <span>Quyết định trước khi chuyển bước</span>
          <h2>Có thể yêu cầu tạo nhu cầu cho giai đoạn này không?</h2>
        </div>
        <p>
          Kỳ có thẩm quyền (bao gồm cả hai ngày): <b>{viDate(periodStart)}</b> –{" "}
          <b>{viDate(periodEnd)}</b>
        </p>
      </header>

      <section className="readiness-period-controls" aria-label="Kỳ đánh giá">
        <label>
          Từ ngày
          <input
            type="date"
            value={draftStart}
            onChange={(event) => setDraftStart(event.target.value)}
          />
        </label>
        <label>
          Đến ngày
          <input
            type="date"
            value={draftEnd}
            onChange={(event) => setDraftEnd(event.target.value)}
          />
        </label>
        <button
          type="button"
          onClick={() => applyPeriod(draftStart, draftEnd)}
          disabled={busy}
        >
          <ArrowClockwise aria-hidden="true" size={16} weight="bold" />
          Đọc đúng kỳ
        </button>
        <button
          type="button"
          className="secondary"
          onClick={() => applyPeriod(selectedWeekStart, selectedWeekEnd)}
          disabled={busy}
        >
          Dùng cả tuần đang chọn
        </button>
      </section>

      {loading && !workbench && (
        <p role="status">Đang đọc trạng thái sẵn sàng…</p>
      )}

      {workbench && (
        <>
          <section
            className={`readiness-decision ${workbench.decision.toLowerCase()}`}
            aria-label="Kết luận sẵn sàng có thẩm quyền"
          >
            <div>
              <span>Kết luận có thẩm quyền</span>
              <strong>{readinessDecisionLabel(workbench.decision)}</strong>
              <small>
                {workbench.allowed_actions.can_request_need_generation
                  ? "Ba nguồn đã đủ điều kiện để chuyển sang yêu cầu tạo nhu cầu."
                  : workbench.allowed_actions.can_evaluate
                    ? "Bước hợp lệ tiếp theo là đánh giá ba nguồn bằng chứng."
                    : "Xem lý do bị chặn và bằng chứng nguồn trước khi tiếp tục."}
              </small>
            </div>
            {workbench.allowed_actions.disabled_reasons.length > 0 && (
              <ul>
                {workbench.allowed_actions.disabled_reasons.map((reason) => (
                  <li key={reason}>{reason}</li>
                ))}
              </ul>
            )}
            {workbench.root ? (
              <details className="readiness-root-audit">
                <summary>Định danh Planning Input Set</summary>
                <code>{workbench.root.planning_input_set_id}</code>
              </details>
            ) : (
              <small>Chưa có Planning Input Set cho đúng kỳ này.</small>
            )}
          </section>

          <div className="readiness-source-grid">
            {sources.map(({ key, label }) => (
              <SourceCard
                key={key}
                source={key}
                label={label}
                workbench={workbench}
                onSelect={(candidate) => void selectCandidate(key, candidate)}
                disabled={busy || loading}
              />
            ))}
          </div>

          <Issues
            title="Lỗi chặn"
            tone="danger"
            items={currentIssues?.blockers ?? []}
          />
          <Issues
            title="Cảnh báo"
            tone="warning"
            items={currentIssues?.warnings ?? []}
          />

          <Panel
            title="Bước hợp lệ tiếp theo"
            description="PostgreSQL quyết định thao tác nào được phép; lý do bị chặn luôn hiển thị bên dưới."
          >
            <div className="readiness-forward-actions">
              <button
                type="button"
                className={
                  workbench.allowed_actions.can_evaluate
                    ? "primary-forward"
                    : "secondary-forward"
                }
                onClick={evaluate}
                disabled={busy || !workbench.allowed_actions.can_evaluate}
              >
                <Checks aria-hidden="true" size={18} weight="bold" />
                Đánh giá mức sẵn sàng
              </button>
              <button
                type="button"
                className={
                  workbench.allowed_actions.can_request_need_generation
                    ? "primary-forward"
                    : "secondary-forward"
                }
                onClick={requestNeedGeneration}
                disabled={
                  busy || !workbench.allowed_actions.can_request_need_generation
                }
              >
                <Lightning aria-hidden="true" size={18} weight="fill" />
                Yêu cầu tạo nhu cầu
              </button>
            </div>

            {workbench.allowed_actions.disabled_reasons.length > 0 && (
              <div className="readiness-action-reasons" aria-live="polite">
                <b>Vì sao chưa thể tiếp tục</b>
                <ul>
                  {workbench.allowed_actions.disabled_reasons.map((reason) => (
                    <li key={reason}>{reason}</li>
                  ))}
                </ul>
              </div>
            )}

            {workbench.allowed_actions.can_invalidate && (
              <details className="readiness-correction">
                <summary>
                  <Wrench aria-hidden="true" size={17} weight="bold" />
                  Điều chỉnh hoặc vô hiệu hóa kết quả
                </summary>
                <p>
                  Chỉ dùng khi cần sửa quyết định đã có; thao tác này không thay
                  đổi dữ liệu nguồn hay lần chạy tạo nhu cầu đã tồn tại.
                </p>
                <div className="readiness-invalidation-form">
                  <label>
                    Lý do vô hiệu
                    <select
                      value={invalidationReason}
                      onChange={(event) => {
                        setInvalidationReason(event.target.value);
                        setInvalidationNote("");
                      }}
                    >
                      {workbench.allowed_actions.invalidation_reason_codes.map(
                        (reason) => (
                          <option key={reason} value={reason}>
                            {reason}
                          </option>
                        ),
                      )}
                    </select>
                  </label>
                  <label>
                    Ghi chú vô hiệu
                    <input
                      value={invalidationNote}
                      onChange={(event) =>
                        setInvalidationNote(event.target.value)
                      }
                      required={invalidationReasonRequiresNote(
                        invalidationReason,
                      )}
                      placeholder={
                        invalidationReasonRequiresNote(invalidationReason)
                          ? "Bắt buộc"
                          : "Không bắt buộc"
                      }
                    />
                  </label>
                  <button
                    type="button"
                    className="destructive-secondary"
                    onClick={invalidate}
                    disabled={busy || !canSubmitInvalidation}
                  >
                    Vô hiệu hóa kết quả sẵn sàng
                  </button>
                </div>
              </details>
            )}
          </Panel>

          <details className="readiness-history">
            <summary>
              <span>
                <ClockCounterClockwise
                  aria-hidden="true"
                  size={18}
                  weight="bold"
                />
                Lịch sử đánh giá
              </span>
              <small>{workbench.history_items.length} mục đã tải</small>
            </summary>
            <section aria-label="Lịch sử sẵn sàng">
              {workbench.history_items.length === 0 ? (
                <p>Chưa có lịch sử cho kỳ này.</p>
              ) : (
                <ol>
                  {workbench.history_items.map((item) => {
                    const pantryMessage = historicalPantryMessage(item);
                    return (
                      <li key={`${item.history_kind}:${item.history_item_id}`}>
                        <b>
                          {item.history_kind === "EVALUATION"
                            ? `Đánh giá phiên bản ${item.evaluation?.evaluation_version ?? "—"}`
                            : item.history_kind === "NEED_GENERATION_REQUEST"
                              ? "Yêu cầu tạo nhu cầu"
                              : "Vô hiệu trạng thái"}
                        </b>
                        <span>
                          {new Date(item.occurred_at).toLocaleString("vi-VN")}
                          {item.actor_display_name
                            ? ` · ${item.actor_display_name}`
                            : ""}
                        </span>
                        {item.reason_note && <small>{item.reason_note}</small>}
                        {pantryMessage && (
                          <small className="historical-pantry-warning">
                            {pantryMessage}
                          </small>
                        )}
                      </li>
                    );
                  })}
                </ol>
              )}
              {workbench.history_has_more && workbench.history_next_cursor && (
                <button
                  type="button"
                  onClick={() =>
                    void loadWorkbench({
                      sourceSelection: currentSelection,
                      cursor: workbench.history_next_cursor,
                      append: true,
                    })
                  }
                  disabled={loading || busy}
                >
                  Tải thêm lịch sử
                </button>
              )}
            </section>
          </details>
        </>
      )}

      {pendingCommand && (
        <section
          className="command-outcome warning"
          aria-label="Lệnh đang chờ xác minh"
        >
          <b>
            {pendingCommand.uncertain
              ? "Chưa xác định kết quả lệnh"
              : "Có thể thử lại đúng yêu cầu"}
          </b>
          <small>Mã lệnh: {pendingCommand.request.command_id}</small>
          {pendingCommand.retryable && (
            <button
              type="button"
              onClick={() =>
                void executeCommand(
                  pendingCommand.operation,
                  pendingCommand.request,
                )
              }
              disabled={busy}
            >
              Gửi lại đúng yêu cầu
            </button>
          )}
          {pendingCommand.uncertain && (
            <button
              type="button"
              onClick={() => void loadWorkbench()}
              disabled={busy || loading}
            >
              Kiểm tra trạng thái có thẩm quyền
            </button>
          )}
        </section>
      )}

      {notice && (
        <p
          className="operator-notice"
          role={
            notice.includes("không") || notice.includes("Chưa")
              ? "alert"
              : "status"
          }
        >
          {notice}
        </p>
      )}
    </section>
  );
}
