import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Eye, FloppyDisk, Plus } from "@phosphor-icons/react";
import type { AtlasAuthState } from "../../connection/authSession";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import { planningSourceSaveOutcome } from "../planningInputsModel";
import { schoolInPlanningScope } from "../planningSchoolScope";
import { PlanningCorrectionImpactPanel } from "../PlanningCorrectionImpactPanel";
import { PlanningRailActionPortal } from "../PlanningRailActionPortal";
import {
  planningCorrectionImpactFromResult,
  safeNoDownstreamImpact,
  type PlanningCorrectionChain,
  type PlanningCorrectionImpact,
} from "../planningCorrectionApi";
import { Chip } from "../../WorkbenchComponents";
import { pantryCompletionRequest, type PantryApi } from "./pantryApi";
import {
  pantryPreviewFromResult,
  pantryReadbackFromResult,
  pantryResultMessage,
  pantryRowsForWrite,
  pantryRowsFromBatch,
  pantryWorkbenchFromResult,
  type PantryDraftRow,
  type PantryIssue,
  type PantryWorkbenchData,
} from "./pantryModel";

type LoadState = "idle" | "loading" | "ready" | "error";

function dateVi(value: string) {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function emptyWorkbench(weekStart: string): PantryWorkbenchData {
  const end = new Date(`${weekStart}T00:00:00Z`);
  end.setUTCDate(end.getUTCDate() + 6);
  return {
    week_start: weekStart,
    week_end: end.toISOString().slice(0, 10),
    source_method: {
      source_type: "MANUAL_ATLAS",
      source_name: "Nhập thủ công Atlas",
    },
    purposes: [],
    schools: [],
    ingredients: [],
    catalog_issues: { blockers: [], warnings: [] },
    batch: null,
    allowed_actions: {
      can_preview: false,
      can_save: false,
      can_validate: false,
      can_approve: false,
      can_reopen: false,
    },
  };
}

function statusTone(status?: string) {
  if (status === "APPROVED") return "ok" as const;
  if (status === "VALIDATED") return "neutral" as const;
  return "warning" as const;
}

function statusLabel(status?: string) {
  const labels: Record<string, string> = {
    DRAFT: "CHƯA LƯU HOÀN TẤT",
    VALIDATED: "CẦN LƯU HOÀN TẤT",
    APPROVED: "ĐÃ LƯU",
    REOPENED: "ĐANG CHỈNH SỬA",
  };
  return status ? (labels[status] ?? status) : "CHƯA CÓ";
}

function PantryIssues({
  title,
  issues,
  tone,
}: {
  title: string;
  issues: PantryIssue[];
  tone: "danger" | "warning";
}) {
  if (!issues.length) return null;
  return (
    <section className={`planning-issues ${tone}`}>
      <strong>
        {title} ({issues.length})
      </strong>
      <ul>
        {issues.map((issue, index) => (
          <li key={`${issue.code}:${issue.source_row_reference}:${index}`}>
            {issue.message}
            {issue.source_row_reference && (
              <small>{issue.source_row_reference}</small>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}

export function PantryWorkbench({
  authState,
  api,
  weekStart,
  onDirtyChange,
  schoolScopeIds = [],
}: {
  authState: AtlasAuthState;
  api?: PantryApi;
  weekStart: string;
  mode?: "connected" | "review";
  onDirtyChange?: (dirty: boolean) => void;
  schoolScopeIds?: string[];
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [load, setLoad] = useState<LoadState>("idle");
  const [data, setData] = useState(() => emptyWorkbench(weekStart));
  const [rows, setRows] = useState<PantryDraftRow[]>([]);
  const [noAdditions, setNoAdditions] = useState(false);
  const [preview, setPreview] =
    useState<ReturnType<typeof pantryPreviewFromResult>>(null);
  const [correctionImpact, setCorrectionImpact] =
    useState<PlanningCorrectionImpact | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [consequence, setConsequence] = useState<string | null>(null);
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [refreshRequired, setRefreshRequired] = useState(false);
  const generation = useRef(0);
  const reviewRef = useRef<HTMLElement>(null);
  const reviewActionRef = useRef<HTMLButtonElement>(null);
  const returnToReviewAction = useRef(false);
  useEffect(() => {
    if (preview) reviewRef.current?.focus();
    else if (returnToReviewAction.current) {
      returnToReviewAction.current = false;
      reviewActionRef.current?.focus();
    }
  }, [preview]);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;
  const serviceDates = useMemo(() => {
    const start = new Date(`${data.week_start}T00:00:00Z`);
    return Array.from({ length: 7 }, (_, index) => {
      const date = new Date(start);
      date.setUTCDate(start.getUTCDate() + index);
      return date.toISOString().slice(0, 10);
    });
  }, [data.week_start]);

  const adopt = useCallback((workbench: PantryWorkbenchData) => {
    setData(workbench);
    setRows(pantryRowsFromBatch(workbench.batch));
    setNoAdditions(workbench.batch?.no_additions_confirmed ?? false);
    setPreview(null);
    setDirty(false);
  }, []);

  const refresh = useCallback(async () => {
    if (!api || !authSubject) return;
    const request = ++generation.current;
    setLoad("loading");
    setNotice(null);
    const result = await api.getWorkbench(
      authSubject,
      correlationId,
      weekStart,
    );
    if (request !== generation.current) return;
    const workbench = pantryWorkbenchFromResult(result);
    if (!workbench) {
      setLoad("error");
      setNotice(pantryResultMessage(result));
      return;
    }
    setLoad("ready");
    adopt(workbench);
    setRefreshRequired(false);
    setConsequence(null);
  }, [api, authSubject, correlationId, weekStart, adopt]);

  useEffect(() => {
    generation.current += 1;
    setData(emptyWorkbench(weekStart));
    setRows([]);
    setNoAdditions(false);
    setPreview(null);
    setDirty(false);
    setRefreshRequired(false);
    setConsequence(null);
    if (authSubject) void refresh();
    else {
      setLoad("idle");
    }
  }, [authSubject, refresh, weekStart]);

  useEffect(() => {
    onDirtyChange?.(dirty);
  }, [dirty, onDirtyChange]);

  useEffect(
    () => () => {
      onDirtyChange?.(false);
    },
    [onDirtyChange],
  );

  const purposes = useMemo(
    () =>
      [...data.purposes].sort(
        (left, right) =>
          left.display_order - right.display_order ||
          left.purpose_code.localeCompare(right.purpose_code),
      ),
    [data.purposes],
  );
  const scopedSchools = useMemo(
    () =>
      data.schools.filter((school) =>
        schoolInPlanningScope(school.school_id, schoolScopeIds),
      ),
    [data.schools, schoolScopeIds],
  );
  const visibleRowEntries = useMemo(
    () =>
      rows
        .map((row, index) => ({ row, index }))
        .filter(({ row }) =>
          schoolInPlanningScope(row.school_id, schoolScopeIds),
        ),
    [rows, schoolScopeIds],
  );

  const markEdited = (next: PantryDraftRow[]) => {
    setRows(next);
    setPreview(null);
    setDirty(true);
  };

  const discardLocalChanges = () => {
    setRows(pantryRowsFromBatch(data.batch));
    setNoAdditions(data.batch?.no_additions_confirmed ?? false);
    setPreview(null);
    setDirty(false);
  };

  const addRow = () => {
    const school = scopedSchools[0];
    const ingredient = data.ingredients[0];
    const purpose = purposes[0];
    if (!school || !ingredient || !purpose) return;
    markEdited([
      ...rows,
      {
        service_date: weekStart,
        school_id: school.school_id,
        ingredient_id: ingredient.ingredient_id,
        pantry_need_purpose_id: purpose.pantry_need_purpose_id,
        requested_quantity: "",
        note: "",
        source_request_reference: "",
        source_row_reference: `atlas:${rows.length + 1}`,
      },
    ]);
  };

  const updateRow = (
    index: number,
    field: keyof PantryDraftRow,
    value: string,
  ) => {
    markEdited(
      rows.map((row, rowIndex) =>
        rowIndex === index ? { ...row, [field]: value } : row,
      ),
    );
  };

  const previewRows = async () => {
    if (!api || !authSubject) return;
    setSaving(true);
    const result = await api.preview(
      authSubject,
      correlationId,
      weekStart,
      noAdditions,
      pantryRowsForWrite(rows),
    );
    const nextPreview = pantryPreviewFromResult(result);
    setPreview(nextPreview);
    const impactResult =
      nextPreview?.can_save && api.getCorrectionImpact
        ? await api.getCorrectionImpact(authSubject, correlationId, "PANTRY", {
            week_start: weekStart,
            no_additions_confirmed: noAdditions,
            source_signature: nextPreview.source_signature,
            expected_source_signature: data.batch?.source_signature ?? null,
            rows: pantryRowsForWrite(rows),
          })
        : null;
    const impact = impactResult
      ? planningCorrectionImpactFromResult(impactResult)
      : nextPreview?.can_save
        ? safeNoDownstreamImpact("PANTRY")
        : null;
    setCorrectionImpact(impact);
    setSaving(false);
    setNotice(pantryResultMessage(impactResult ?? result));
  };

  const runCompletion = async (invoke: () => Promise<AtlasRpcResult>) => {
    setSaving(true);
    setNotice(null);
    setConsequence(null);
    const result = await invoke();
    setSaving(false);
    const currentness =
      result.kind === "success" &&
      typeof result.response.downstream_currentness === "string"
        ? result.response.downstream_currentness
        : null;
    const outcome =
      currentness === "CURRENT" ||
      currentness === "OUTDATED" ||
      currentness === "NOT_GENERATED"
        ? planningSourceSaveOutcome("pantry", currentness)
        : null;
    setNotice(outcome?.savedMessage ?? pantryResultMessage(result));
    setConsequence(outcome?.consequenceMessage ?? null);
    if (
      result.kind === "transport_error" ||
      (result.kind === "backend_error" &&
        ["STALE_VERSION", "STALE_SOURCE_SIGNATURE"].includes(
          result.error.error_code,
        ))
    ) {
      setRefreshRequired(true);
      return;
    }
    const workbench = pantryReadbackFromResult(result);
    if (workbench) {
      setLoad("ready");
      adopt(workbench);
      setRefreshRequired(false);
    } else if (result.kind === "success") {
      setRefreshRequired(true);
    }
  };

  const save = async () => {
    if (
      !api ||
      !authSubject ||
      !preview?.can_save ||
      !correctionImpact?.save_allowed ||
      refreshRequired
    )
      return;
    const request = pantryCompletionRequest(
      authSubject,
      correlationId,
      data.batch?.version ?? 1,
      {
        week_start: weekStart,
        no_additions_confirmed: noAdditions,
        source_signature: preview.source_signature,
        expected_source_signature: data.batch?.source_signature ?? null,
        rows: pantryRowsForWrite(rows),
      },
    );
    await runCompletion(() => api.saveCompleted(request));
  };

  const prepareCorrection = async (chain: PlanningCorrectionChain) => {
    if (!api?.prepareCorrection || !authSubject) return;
    setSaving(true);
    const result = await api.prepareCorrection(
      authSubject,
      correlationId,
      chain,
      "Hiệu chỉnh Nhu cầu bổ sung sau khi rà soát ảnh hưởng.",
    );
    setNotice(pantryResultMessage(result));
    if (
      result.kind === "transport_error" ||
      (result.kind === "backend_error" &&
        ["STALE_VERSION", "RETRYABLE_CONCURRENCY_FAILURE"].includes(
          result.error.error_code,
        ))
    ) {
      setSaving(false);
      setRefreshRequired(true);
      return;
    }
    setSaving(false);
    if (result.kind === "success") await previewRows();
  };

  const canEdit =
    !saving && !refreshRequired && data.catalog_issues.blockers.length === 0;

  if (!authSubject) {
    return (
      <p className="operator-notice warning">
        {authState.status === "session_expired"
          ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại."
          : "Đăng nhập để xem và cập nhật Nhu cầu bổ sung."}
      </p>
    );
  }

  return (
    <div className="pantry-workbench">
      <PlanningRailActionPortal>
        {preview?.can_save && correctionImpact?.save_allowed ? (
          <button
            type="button"
            className="primary"
            onClick={() => void save()}
            disabled={saving || refreshRequired || !dirty}
          >
            <FloppyDisk size={17} aria-hidden="true" />
            Lưu
          </button>
        ) : (
          <button
            type="button"
            className="primary"
            onClick={() => void previewRows()}
            ref={reviewActionRef}
            disabled={!canEdit}
          >
            <Eye size={17} aria-hidden="true" />
            Xem thay đổi
          </button>
        )}
      </PlanningRailActionPortal>
      {notice && (
        <p
          className={`operator-notice${load === "error" ? " danger" : ""}`}
          role={load === "error" ? "alert" : "status"}
        >
          {notice}
          {consequence && <span> {consequence}</span>}
          {refreshRequired && (
            <span> Cần tải lại dữ liệu mới nhất trước khi ghi tiếp.</span>
          )}
        </p>
      )}
      {load === "loading" && <p className="empty">Đang tải Nhu cầu bổ sung…</p>}
      {load === "error" && (
        <button type="button" onClick={() => void refresh()}>
          Thử tải lại dữ liệu
        </button>
      )}

      <section
        className="planning-job-surface planning-pantry-surface"
        aria-label="Bề mặt làm việc Nhu cầu bổ sung"
      >
        <div
          className="planning-job-status"
          aria-label="Trạng thái Nhu cầu bổ sung"
        >
          <Chip tone={statusTone(data.batch?.pantry_need_batch_status)}>
            {statusLabel(data.batch?.pantry_need_batch_status)}
          </Chip>
        </div>
        <PantryIssues
          title="Lỗi danh mục"
          issues={data.catalog_issues.blockers}
          tone="danger"
        />
        <PantryIssues
          title="Cảnh báo danh mục"
          issues={data.catalog_issues.warnings}
          tone="warning"
        />

        {dirty && (
          <p className="planning-dirty-notice" role="status">
            Có thay đổi chưa lưu. Hãy xem thay đổi rồi lưu.
          </p>
        )}

        <div
          className="planning-workbench-toolbar pantry-toolbar"
          aria-label="Nhập Nhu cầu bổ sung"
        >
          <div
            className="planning-toolbar-group pantry-entry-actions"
            role="group"
            aria-label="Thao tác dòng bổ sung"
          >
            <button
              type="button"
              className="secondary"
              onClick={addRow}
              disabled={!canEdit || noAdditions}
            >
              <Plus size={17} aria-hidden="true" />
              Thêm dòng
            </button>
            {dirty && (
              <button
                type="button"
                className="quiet planning-toolbar-discard"
                onClick={discardLocalChanges}
              >
                Hủy thay đổi
              </button>
            )}
          </div>
          <div
            className="pantry-zero-decision"
            role="group"
            aria-label="Xác nhận không phát sinh"
          >
            <label className="pantry-zero-confirmation">
              <input
                type="checkbox"
                checked={noAdditions}
                disabled={!canEdit}
                onChange={(event) => {
                  const checked = event.target.checked;
                  if (
                    checked &&
                    rows.length > 0 &&
                    !window.confirm(
                      "Xác nhận không có bổ sung sẽ loại mọi dòng đang nhập?",
                    )
                  )
                    return;
                  setNoAdditions(checked);
                  if (checked) setRows([]);
                  setPreview(null);
                  setDirty(true);
                }}
              />
              Xác nhận toàn tuần không có bổ sung
            </label>
          </div>
        </div>

        <div
          className={`planning-decision-layout${preview ? " has-review" : ""}`}
          role="group"
          aria-label="Bảng và phần xem thay đổi Nhu cầu bổ sung"
        >
          <div className="planning-decision-work">
            {visibleRowEntries.length === 0 ? (
              <p className={`empty${noAdditions ? " pantry-zero-state" : ""}`}>
                {noAdditions
                  ? "Đã xác nhận không có bổ sung; hãy xem thay đổi trước khi lưu."
                  : "Chưa có dòng bổ sung."}
              </p>
            ) : (
              <div
                className="planning-grid-scroll planning-dense-table-surface"
                role="region"
                aria-label="Bảng nhu cầu bổ sung"
              >
                <table className="compact-table pantry-table">
                  <thead>
                    <tr>
                      <th>Ngày phục vụ</th>
                      <th>Trường / điểm giao</th>
                      <th>Nguyên liệu / đơn vị</th>
                      <th>Mục đích</th>
                      <th>Số lượng</th>
                      <th>Ghi chú</th>
                      <th>Tham chiếu</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {visibleRowEntries.map(({ row, index }) => {
                      const school = data.schools.find(
                        (item) => item.school_id === row.school_id,
                      );
                      const ingredient = data.ingredients.find(
                        (item) => item.ingredient_id === row.ingredient_id,
                      );
                      const purpose = purposes.find(
                        (item) =>
                          item.pantry_need_purpose_id ===
                          row.pantry_need_purpose_id,
                      );
                      return (
                        <tr key={`${row.source_row_reference}:${index}`}>
                          <td>
                            <select
                              aria-label={`Ngày phục vụ dòng ${index + 1}`}
                              value={row.service_date}
                              disabled={!canEdit}
                              onChange={(event) =>
                                updateRow(
                                  index,
                                  "service_date",
                                  event.target.value,
                                )
                              }
                            >
                              {serviceDates.map((date) => (
                                <option value={date} key={date}>
                                  {dateVi(date)}
                                </option>
                              ))}
                            </select>
                          </td>
                          <td>
                            <select
                              aria-label={`Trường dòng ${index + 1}`}
                              value={row.school_id}
                              disabled={!canEdit}
                              onChange={(event) =>
                                updateRow(
                                  index,
                                  "school_id",
                                  event.target.value,
                                )
                              }
                            >
                              {scopedSchools.map((item) => (
                                <option
                                  value={item.school_id}
                                  key={item.school_id}
                                >
                                  {item.school_code} · {item.school_name}
                                </option>
                              ))}
                            </select>
                            <small
                              className="pantry-derived-value"
                              data-derived="delivery-location"
                            >
                              {school?.default_delivery_location
                                .location_name ?? "—"}
                            </small>
                          </td>
                          <td>
                            <select
                              aria-label={`Nguyên liệu dòng ${index + 1}`}
                              value={row.ingredient_id}
                              disabled={!canEdit}
                              onChange={(event) =>
                                updateRow(
                                  index,
                                  "ingredient_id",
                                  event.target.value,
                                )
                              }
                            >
                              {data.ingredients.map((item) => (
                                <option
                                  value={item.ingredient_id}
                                  key={item.ingredient_id}
                                >
                                  {item.ingredient_code} ·{" "}
                                  {item.ingredient_name}
                                </option>
                              ))}
                            </select>
                            <small
                              className="pantry-derived-value"
                              data-derived="purchase-unit"
                            >
                              {ingredient?.purchase_unit.unit_name ?? "—"}
                            </small>
                          </td>
                          <td>
                            <select
                              aria-label={`Mục đích dòng ${index + 1}`}
                              value={row.pantry_need_purpose_id}
                              disabled={!canEdit}
                              onChange={(event) =>
                                updateRow(
                                  index,
                                  "pantry_need_purpose_id",
                                  event.target.value,
                                )
                              }
                            >
                              {purposes.map((purpose) => (
                                <option
                                  value={purpose.pantry_need_purpose_id}
                                  key={purpose.pantry_need_purpose_id}
                                  title={purpose.purpose_description}
                                >
                                  {purpose.purpose_name_vi}
                                </option>
                              ))}
                            </select>
                          </td>
                          <td>
                            <input
                              aria-label={`Số lượng dòng ${index + 1}`}
                              type="number"
                              min="0.000001"
                              step="0.000001"
                              value={row.requested_quantity}
                              disabled={!canEdit}
                              onChange={(event) =>
                                updateRow(
                                  index,
                                  "requested_quantity",
                                  event.target.value,
                                )
                              }
                            />
                          </td>
                          <td>
                            <input
                              aria-label={`Ghi chú dòng ${index + 1}`}
                              value={row.note}
                              required={purpose?.note_rule === "REQUIRED"}
                              disabled={
                                !canEdit || purpose?.note_rule === "PROHIBITED"
                              }
                              placeholder={
                                purpose?.note_rule === "REQUIRED"
                                  ? "Bắt buộc theo Mục đích"
                                  : purpose?.note_rule === "PROHIBITED"
                                    ? "Không được phép theo Mục đích"
                                    : "Không bắt buộc"
                              }
                              onChange={(event) =>
                                updateRow(index, "note", event.target.value)
                              }
                            />
                          </td>
                          <td>
                            <input
                              aria-label={`Tham chiếu dòng ${index + 1}`}
                              value={row.source_request_reference}
                              disabled={!canEdit}
                              onChange={(event) =>
                                updateRow(
                                  index,
                                  "source_request_reference",
                                  event.target.value,
                                )
                              }
                            />
                          </td>
                          <td>
                            <button
                              type="button"
                              aria-label={`Xóa dòng ${index + 1}`}
                              disabled={!canEdit}
                              onClick={() =>
                                markEdited(
                                  rows.filter(
                                    (_candidate, rowIndex) =>
                                      rowIndex !== index,
                                  ),
                                )
                              }
                            >
                              Xóa
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {preview && (
            <aside className="planning-decision-review">
              <section
                ref={reviewRef}
                tabIndex={-1}
                className="planning-review pantry-review"
                aria-label="Xem thay đổi Nhu cầu bổ sung"
              >
                <div className="planning-review-heading">
                  <strong>Xem thay đổi</strong>
                  <span>{preview.canonical_rows.length} dòng sau khi lưu</span>
                </div>
                <p className="pantry-review-summary">
                  {preview.comparison.new_lines.length} dòng mới ·{" "}
                  {preview.comparison.changed_lines.length} dòng thay đổi ·{" "}
                  {preview.comparison.omitted_lines.length} dòng sẽ bỏ
                </p>
                <PantryIssues
                  title="Lỗi chặn"
                  issues={preview.issues.blockers}
                  tone="danger"
                />
                <PantryIssues
                  title="Cảnh báo"
                  issues={preview.issues.warnings}
                  tone="warning"
                />
                <details className="planning-preview-summary">
                  <summary>Chi tiết đối chiếu kỹ thuật</summary>
                  <span>
                    {preview.comparison.status} · Không đổi{" "}
                    {preview.comparison.unchanged_lines.length}
                  </span>
                  <code>{preview.source_signature}</code>
                </details>
                <button
                  type="button"
                  className="secondary planning-review-back"
                  onClick={() => {
                    returnToReviewAction.current = true;
                    setPreview(null);
                    setCorrectionImpact(null);
                  }}
                >
                  Quay lại
                </button>
              </section>
              <PlanningCorrectionImpactPanel
                impact={correctionImpact}
                busy={saving}
                onPrepare={(chain) => void prepareCorrection(chain)}
              />
            </aside>
          )}
        </div>

        <details className="planning-evidence pantry-support-disclosure">
          <summary>Nguồn &amp; lịch sử</summary>
          <div className="pantry-support-content">
            <section
              className="pantry-support-section"
              aria-label="Chi tiết hỗ trợ Nhu cầu bổ sung"
            >
              <h3>Nguồn hiện tại</h3>
              <div className="planning-source-summary planning-source-summary-inline">
                <span>
                  Tuần:{" "}
                  <b>
                    {dateVi(data.week_start)} – {dateVi(data.week_end)}
                  </b>
                </span>
                <span>
                  Nguồn: <b>{data.source_method.source_name}</b>
                </span>
                <span>
                  Phiên bản: <b>{data.batch?.version ?? "—"}</b>
                </span>
                <span>
                  Chữ ký: <code>{data.batch?.source_signature ?? "—"}</code>
                </span>
              </div>
            </section>

            {(data.batch?.invalid_lines.length ?? 0) > 0 && (
              <section className="pantry-support-section">
                <h3>Dòng đã vô hiệu ({data.batch?.invalid_lines.length})</h3>
                <ul>
                  {data.batch?.invalid_lines.map((line) => (
                    <li key={line.pantry_need_line_id}>
                      {dateVi(line.service_date)} · {line.school_name} ·{" "}
                      {line.ingredient_name} · {line.requested_quantity}{" "}
                      {line.unit_name}
                    </li>
                  ))}
                </ul>
              </section>
            )}

            <section className="pantry-support-section">
              <h3>
                Lịch sử phê duyệt ({data.batch?.approval_history.length ?? 0})
              </h3>
              <ul>
                {data.batch?.approval_history.map((snapshot) => (
                  <li key={snapshot.pantry_need_approval_snapshot_id}>
                    Phiên bản {snapshot.approved_batch_version} ·{" "}
                    {snapshot.approved_by_display_name} ·{" "}
                    {new Date(snapshot.approved_at).toLocaleString("vi-VN")} ·{" "}
                    {snapshot.line_count} dòng
                  </li>
                ))}
              </ul>
            </section>
            <section className="pantry-support-section">
              <h3>
                Lịch sử thay đổi ({data.batch?.change_history.length ?? 0})
              </h3>
              <ul>
                {data.batch?.change_history.map((change) => (
                  <li key={change.audit_event_id}>
                    {change.event_type} · v{change.version_after} ·{" "}
                    {change.actor_display_name}
                    {change.reason_note && <small>{change.reason_note}</small>}
                  </li>
                ))}
              </ul>
            </section>
          </div>
        </details>
      </section>
    </div>
  );
}
