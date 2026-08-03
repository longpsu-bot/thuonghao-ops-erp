import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../../connection/authSession";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import { Chip, CompactTable, Panel } from "../../WorkbenchComponents";
import {
  confirmedNeedCommandRequest,
  confirmedNeedPreviewRequest,
  type ConfirmedNeedApi,
  type ConfirmedNeedCommandRequest,
  type ConfirmedNeedFilters,
  type ConfirmedNeedLineRequest,
} from "./confirmedNeedApi";
import {
  confirmedNeedPreviewFromResult,
  confirmedNeedPreviewIsStale,
  confirmedNeedReadbackFromResult,
  confirmedNeedResultAllowsExactRetry,
  confirmedNeedResultIsStale,
  confirmedNeedResultMessage,
  confirmedNeedWorkbenchFromResult,
  exactQuantityDisplay,
  exactDecimalEqual,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedIssue,
  type ConfirmedNeedLine,
  type ConfirmedNeedPreview,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";

const emptyFilters: ConfirmedNeedFilters = {
  service_date: null,
  school_id: null,
  delivery_location_id: null,
  ingredient_id: null,
  decision_state: null,
};

function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function issueList(
  title: string,
  items: ConfirmedNeedIssue[],
  tone: "danger" | "warning",
) {
  if (!items.length) return null;
  return (
    <section className={`planning-issues ${tone}`} aria-label={title}>
      <strong>
        {title} ({items.length})
      </strong>
      <ul>
        {items.map((item, index) => (
          <li key={`${item.code}:${index}`}>{item.message ?? item.code}</li>
        ))}
      </ul>
    </section>
  );
}

function initialDraft(line: ConfirmedNeedLine): ConfirmedNeedDraftLine {
  return {
    selected: line.current_decision_id === null,
    exact_quantity: line.proposed_confirmed_quantity,
    reason_code: "PROPOSAL_ACCEPTED",
    reason_note: "",
  };
}

function lineRequest(
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

function localDraftError(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) {
  if (!draft.exact_quantity.trim()) return "Cần nhập số lượng xác nhận.";
  const unchanged = exactDecimalEqual(
    draft.exact_quantity,
    line.proposed_confirmed_quantity,
  );
  if (unchanged && draft.reason_code !== "PROPOSAL_ACCEPTED")
    return "Chấp nhận đề xuất phải dùng lý do PROPOSAL_ACCEPTED.";
  if (!unchanged && draft.reason_code === "PROPOSAL_ACCEPTED")
    return "Điều chỉnh số lượng cần chọn lý do điều chỉnh.";
  if (
    ["OPERATIONAL_QUANTITY_ADJUSTMENT", "OTHER"].includes(draft.reason_code) &&
    !draft.reason_note.trim()
  )
    return "Lý do này cần ghi chú.";
  if (line.current_decision_id && !draft.reason_note.trim())
    return "Thay thế bằng chứng quyết định cần ghi chú hiệu chỉnh.";
  if (unchanged && !line.current_decision_id && draft.reason_note.trim())
    return "Lần chấp nhận đề xuất đầu tiên không có ghi chú.";
  return null;
}

export function ConfirmedNeedReviewWorkbench({
  authState,
  api,
  initialBatchId,
}: {
  authState: AtlasAuthState;
  api?: ConfirmedNeedApi;
  initialBatchId?: string | null;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [batchId, setBatchId] = useState(initialBatchId ?? "");
  const [batchIdDraft, setBatchIdDraft] = useState(initialBatchId ?? "");
  const [workbench, setWorkbench] = useState<ConfirmedNeedWorkbenchData | null>(
    null,
  );
  const [drafts, setDrafts] = useState<Record<string, ConfirmedNeedDraftLine>>(
    {},
  );
  const [preview, setPreview] = useState<ConfirmedNeedPreview | null>(null);
  const [previewLines, setPreviewLines] = useState<ConfirmedNeedLineRequest[]>(
    [],
  );
  const [confirmAcknowledged, setConfirmAcknowledged] = useState(false);
  const [pendingCommand, setPendingCommand] =
    useState<ConfirmedNeedCommandRequest | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const adopt = useCallback((next: ConfirmedNeedWorkbenchData) => {
    setWorkbench(next);
    setDrafts((current) =>
      Object.fromEntries(
        next.lines.map((line) => [
          line.confirmed_need_line_id,
          current[line.confirmed_need_line_id] ?? initialDraft(line),
        ]),
      ),
    );
    setPreview(null);
    setPreviewLines([]);
    setConfirmAcknowledged(false);
  }, []);

  const loadReview = useCallback(
    async (requestedBatchId = batchId) => {
      if (!api || !authSubject || !requestedBatchId) return false;
      const requestGeneration = ++generation.current;
      setLoading(true);
      setNotice(null);
      const result = await api.getReview(
        authSubject,
        correlationId,
        requestedBatchId,
        emptyFilters,
      );
      if (requestGeneration !== generation.current) return false;
      setLoading(false);
      const next = confirmedNeedWorkbenchFromResult(result);
      if (!next) {
        setNotice(confirmedNeedResultMessage(result));
        return false;
      }
      setBatchId(requestedBatchId);
      setBatchIdDraft(requestedBatchId);
      adopt(next);
      return true;
    },
    [api, authSubject, batchId, correlationId, adopt],
  );

  useEffect(() => {
    if (!initialBatchId) return;
    setBatchId(initialBatchId);
    setBatchIdDraft(initialBatchId);
    if (authSubject) void loadReview(initialBatchId);
  }, [authSubject, initialBatchId, loadReview]);

  const selected = useMemo(
    () =>
      (workbench?.lines ?? []).flatMap((line) => {
        const draft = drafts[line.confirmed_need_line_id];
        return draft?.selected ? [lineRequest(line, draft)] : [];
      }),
    [drafts, workbench],
  );
  const localErrors = useMemo(
    () =>
      (workbench?.lines ?? []).flatMap((line) => {
        const draft = drafts[line.confirmed_need_line_id];
        if (!draft?.selected) return [];
        const message = localDraftError(line, draft);
        return message ? [{ line, message }] : [];
      }),
    [drafts, workbench],
  );

  const editDraft = (
    lineId: string,
    patch: Partial<ConfirmedNeedDraftLine>,
  ) => {
    setDrafts((current) => ({
      ...current,
      [lineId]: { ...current[lineId], ...patch },
    }));
    setPreview(null);
    setPreviewLines([]);
    setConfirmAcknowledged(false);
    setPendingCommand(null);
  };

  const setDecisionMode = (line: ConfirmedNeedLine, adjusted: boolean) => {
    editDraft(line.confirmed_need_line_id, {
      exact_quantity: line.proposed_confirmed_quantity,
      reason_code: adjusted ? "PLANNING_STEP_ADJUSTMENT" : "PROPOSAL_ACCEPTED",
      reason_note: "",
      selected: true,
    });
  };

  const requestPreview = async () => {
    if (!api || !authSubject || !workbench || !selected.length) return;
    if (localErrors.length) {
      setNotice(localErrors[0]?.message ?? "Bản nháp chưa hợp lệ.");
      return;
    }
    setBusy(true);
    setNotice(null);
    const result = await api.preview(
      confirmedNeedPreviewRequest(
        authSubject,
        correlationId,
        workbench.confirmed_need_batch_id,
        workbench.batch_version,
        selected,
      ),
    );
    setBusy(false);
    const next = confirmedNeedPreviewFromResult(result);
    if (!next) {
      setNotice(confirmedNeedResultMessage(result));
      if (confirmedNeedResultIsStale(result)) await loadReview();
      return;
    }
    if (!next.success && confirmedNeedPreviewIsStale(next)) {
      await loadReview();
      setNotice(
        "Dữ liệu đã thay đổi; đã làm mới bằng chứng có thẩm quyền và giữ bản nháp tương thích.",
      );
      return;
    }
    setPreview(next);
    setPreviewLines(selected);
    setConfirmAcknowledged(false);
    setPendingCommand(null);
    setNotice(
      next.success
        ? "Bản xem trước có thẩm quyền đã sẵn sàng; chưa ghi dữ liệu."
        : "Cần xử lý các lỗi chặn trước khi xác nhận.",
    );
  };

  const executeCommand = useCallback(
    async (request: ConfirmedNeedCommandRequest) => {
      if (!api) return;
      setBusy(true);
      setNotice(null);
      const result: AtlasRpcResult = await api.confirm(request);
      setBusy(false);
      if (confirmedNeedResultAllowsExactRetry(result)) {
        setPendingCommand(request);
        setNotice(confirmedNeedResultMessage(result));
        return;
      }
      setPendingCommand(null);
      if (confirmedNeedResultIsStale(result)) {
        setNotice(confirmedNeedResultMessage(result));
        await loadReview();
        return;
      }
      if (result.kind !== "success") {
        setNotice(confirmedNeedResultMessage(result));
        return;
      }
      const readback = confirmedNeedReadbackFromResult(result);
      if (readback) adopt(readback);
      else await loadReview();
      setNotice(confirmedNeedResultMessage(result));
    },
    [adopt, api, loadReview],
  );

  const confirm = () => {
    if (
      !authSubject ||
      !workbench ||
      !preview?.success ||
      !preview.preview_hash ||
      !confirmAcknowledged
    )
      return;
    const request = confirmedNeedCommandRequest(
      authSubject,
      correlationId,
      workbench.confirmed_need_batch_id,
      workbench.batch_version,
      preview.preview_hash,
      previewLines,
    );
    setPendingCommand(request);
    void executeCommand(request);
  };

  return (
    <Panel
      title="Xác nhận nhu cầu"
      description="So sánh số lượng lý thuyết, đề xuất và đã xác nhận; backend quyết định chính sách, bước lượng và bằng chứng bất biến."
      status={
        <Chip tone={workbench?.blockers.length ? "danger" : "warning"}>
          {workbench?.batch_status ?? "CHƯA TẢI"}
        </Chip>
      }
    >
      <div className="need-generation-period">
        <label>
          Mã lô Confirmed Need
          <input
            aria-label="Mã lô Confirmed Need"
            value={batchIdDraft}
            onChange={(event) => setBatchIdDraft(event.target.value.trim())}
            placeholder="UUID"
          />
        </label>
        <button
          type="button"
          disabled={loading || !batchIdDraft || !authSubject}
          onClick={() => void loadReview(batchIdDraft)}
        >
          Tải lô
        </button>
        {workbench && (
          <button
            type="button"
            disabled={loading}
            onClick={() => void loadReview()}
          >
            Làm mới
          </button>
        )}
      </div>

      {loading && <p role="status">Đang tải lô xác nhận nhu cầu…</p>}
      {workbench && (
        <>
          <section className="need-generation-summary">
            <span>
              Phiên bản <b>{workbench.batch_version}</b>
            </span>
            <span>
              Chưa xác nhận <b>{workbench.line_counts.unreviewed}</b>
            </span>
            <span>
              Đã xác nhận <b>{workbench.line_counts.confirmed}</b>
            </span>
            <span>
              Đã điều chỉnh <b>{workbench.line_counts.adjusted}</b>
            </span>
          </section>

          {issueList("Lỗi chặn", workbench.blockers, "danger")}
          {issueList("Cảnh báo", workbench.warnings, "warning")}

          <div className="table-scroll">
            <CompactTable
              headers={[
                "Chọn",
                "Ngày / Trường / Nguyên liệu",
                "Lý thuyết",
                "Đề xuất",
                "Đã xác nhận",
                "Bước lượng",
                "Bản nháp quyết định",
              ]}
            >
              {workbench.lines.map((line) => {
                const draft =
                  drafts[line.confirmed_need_line_id] ?? initialDraft(line);
                const error = draft.selected
                  ? localDraftError(line, draft)
                  : null;
                return (
                  <tr key={line.confirmed_need_line_id}>
                    <td>
                      <input
                        type="checkbox"
                        aria-label={`Chọn ${line.ingredient.name}`}
                        checked={draft.selected}
                        onChange={(event) =>
                          editDraft(line.confirmed_need_line_id, {
                            selected: event.target.checked,
                          })
                        }
                      />
                    </td>
                    <td>
                      <b>{line.ingredient.name}</b>
                      <small>
                        {viDate(line.service_date)} · {line.school.name} ·{" "}
                        {line.delivery_location.name}
                      </small>
                    </td>
                    <td>
                      {exactQuantityDisplay(line.theoretical_quantity)}{" "}
                      {line.controlled_unit.code}
                    </td>
                    <td>
                      {exactQuantityDisplay(line.proposed_confirmed_quantity)}{" "}
                      {line.controlled_unit.code}
                    </td>
                    <td>
                      {exactQuantityDisplay(line.confirmed_quantity_after)}{" "}
                      {line.controlled_unit.code}
                      <small>
                        {line.current_decision_kind ?? "Chưa có quyết định"}
                      </small>
                    </td>
                    <td>
                      {line.effective_policy
                        ? `${exactQuantityDisplay(line.effective_policy.planning_step)} ${line.controlled_unit.code}`
                        : "Bị chặn"}
                    </td>
                    <td>
                      <div className="planning-lifecycle-actions">
                        <button
                          type="button"
                          onClick={() => setDecisionMode(line, false)}
                        >
                          Chấp nhận đề xuất
                        </button>
                        <button
                          type="button"
                          onClick={() => setDecisionMode(line, true)}
                        >
                          Điều chỉnh số lượng
                        </button>
                      </div>
                      <input
                        aria-label={`Số lượng xác nhận ${line.ingredient.name}`}
                        inputMode="decimal"
                        value={draft.exact_quantity}
                        onChange={(event) =>
                          editDraft(line.confirmed_need_line_id, {
                            exact_quantity: event.target.value,
                          })
                        }
                      />
                      <select
                        aria-label={`Lý do ${line.ingredient.name}`}
                        value={draft.reason_code}
                        onChange={(event) =>
                          editDraft(line.confirmed_need_line_id, {
                            reason_code: event.target
                              .value as ConfirmedNeedDraftLine["reason_code"],
                          })
                        }
                      >
                        <option value="PROPOSAL_ACCEPTED">
                          Chấp nhận đề xuất
                        </option>
                        <option value="PLANNING_STEP_ADJUSTMENT">
                          Điều chỉnh theo bước lượng
                        </option>
                        <option value="OPERATIONAL_QUANTITY_ADJUSTMENT">
                          Điều chỉnh vận hành
                        </option>
                        <option value="OTHER">Lý do khác</option>
                      </select>
                      <input
                        aria-label={`Ghi chú ${line.ingredient.name}`}
                        value={draft.reason_note}
                        onChange={(event) =>
                          editDraft(line.confirmed_need_line_id, {
                            reason_note: event.target.value,
                          })
                        }
                        placeholder="Ghi chú khi bắt buộc"
                      />
                      {error && <small role="alert">{error}</small>}
                      {line.blockers.length > 0 &&
                        issueList("Lỗi dòng", line.blockers, "danger")}
                      {line.warnings.length > 0 &&
                        issueList("Cảnh báo dòng", line.warnings, "warning")}
                      {line.decision_history.length > 0 && (
                        <details>
                          <summary>
                            Lịch sử quyết định ({line.decision_history.length})
                          </summary>
                          <ol>
                            {line.decision_history.map((decision) => (
                              <li key={decision.decision_id}>
                                #{decision.decision_number} ·{" "}
                                {exactQuantityDisplay(
                                  decision.confirmed_quantity_after,
                                )}{" "}
                                · {decision.reason_code}
                                {decision.reason_note && (
                                  <small>{decision.reason_note}</small>
                                )}
                              </li>
                            ))}
                          </ol>
                        </details>
                      )}
                    </td>
                  </tr>
                );
              })}
            </CompactTable>
          </div>

          <div className="planning-lifecycle-actions">
            <button
              type="button"
              disabled={
                busy ||
                selected.length === 0 ||
                localErrors.length > 0 ||
                !workbench.allowed_actions.preview_confirmation
              }
              title={
                workbench.disabled_reasons.preview_confirmation ?? undefined
              }
              onClick={() => void requestPreview()}
            >
              Xem trước xác nhận
            </button>
          </div>

          {preview && (
            <section aria-label="Bản xem trước xác nhận">
              {issueList("Lỗi chặn bản xem trước", preview.blockers, "danger")}
              {issueList("Cảnh báo bản xem trước", preview.warnings, "warning")}
              {preview.ordered_preview_lines.map((line) => (
                <p key={line.confirmed_need_line_id}>
                  <b>{line.decision_kind}</b> · {line.proposed_quantity_before}{" "}
                  → {line.confirmed_quantity_after} · {line.planning_tick_count}{" "}
                  bước × {line.planning_step}
                </p>
              ))}
              {preview.success && (
                <>
                  <label>
                    <input
                      type="checkbox"
                      checked={confirmAcknowledged}
                      onChange={(event) =>
                        setConfirmAcknowledged(event.target.checked)
                      }
                    />{" "}
                    Tôi xác nhận đúng bản xem trước có thẩm quyền này
                  </label>
                  <button
                    type="button"
                    disabled={
                      busy ||
                      !confirmAcknowledged ||
                      !workbench.allowed_actions.confirm_quantities
                    }
                    title={
                      workbench.disabled_reasons.confirm_quantities ?? undefined
                    }
                    onClick={confirm}
                  >
                    Xác nhận số lượng
                  </button>
                </>
              )}
            </section>
          )}

          {pendingCommand && (
            <button
              type="button"
              disabled={busy}
              onClick={() => void executeCommand(pendingCommand)}
            >
              Gửi lại đúng lệnh chưa chắc chắn
            </button>
          )}
        </>
      )}

      {notice && <p role="status">{notice}</p>}
    </Panel>
  );
}
