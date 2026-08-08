import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Eye, FloppyDisk, Plus } from "@phosphor-icons/react";
import type { AtlasAuthState } from "../../connection/authSession";
import type { JsonValue } from "../../connection/atlasRpc";
import { Chip, Panel } from "../../WorkbenchComponents";
import {
  pantryCommandRequest,
  type PantryApi,
  type PantryCommandRequest,
} from "./pantryApi";
import {
  pantryPreviewFromResult,
  pantryReadbackFromResult,
  pantryResultMessage,
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
  mode = "connected",
}: {
  authState: AtlasAuthState;
  api?: PantryApi;
  weekStart: string;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [load, setLoad] = useState<LoadState>("idle");
  const [data, setData] = useState(() => emptyWorkbench(weekStart));
  const [rows, setRows] = useState<PantryDraftRow[]>([]);
  const [noAdditions, setNoAdditions] = useState(false);
  const [preview, setPreview] =
    useState<ReturnType<typeof pantryPreviewFromResult>>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [reopenReason, setReopenReason] = useState("");
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

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
  }, [api, authSubject, correlationId, weekStart, adopt]);

  useEffect(() => {
    generation.current += 1;
    setData(emptyWorkbench(weekStart));
    setRows([]);
    setNoAdditions(false);
    setPreview(null);
    setDirty(false);
    setReopenReason("");
    if (authSubject) void refresh();
    else {
      setLoad("idle");
    }
  }, [authSubject, refresh, weekStart]);

  const purposes = useMemo(
    () =>
      [...data.purposes].sort(
        (left, right) =>
          left.display_order - right.display_order ||
          left.purpose_code.localeCompare(right.purpose_code),
      ),
    [data.purposes],
  );

  const markEdited = (next: PantryDraftRow[]) => {
    setRows(next);
    setPreview(null);
    setDirty(true);
  };

  const addRow = () => {
    const school = data.schools[0];
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
      rows as unknown as JsonValue[],
    );
    setSaving(false);
    setPreview(pantryPreviewFromResult(result));
    setNotice(pantryResultMessage(result));
  };

  const runCommand = async (
    invoke: (request: PantryCommandRequest) => ReturnType<PantryApi["save"]>,
    request: PantryCommandRequest,
  ) => {
    setSaving(true);
    const result = await invoke(request);
    setSaving(false);
    setNotice(pantryResultMessage(result));
    const workbench = pantryReadbackFromResult(result);
    if (workbench) {
      setLoad("ready");
      adopt(workbench);
    }
  };

  const save = async () => {
    if (!api || !authSubject || !preview?.can_save) return;
    await runCommand(
      api.save,
      pantryCommandRequest(
        authSubject,
        correlationId,
        data.batch?.version ?? 1,
        "PANTRY_DRAFT_SAVE",
        {
          week_start: weekStart,
          no_additions_confirmed: noAdditions,
          source_signature: preview.source_signature,
          expected_source_signature: data.batch?.source_signature ?? null,
          rows: rows as unknown as JsonValue[],
        },
      ),
    );
  };

  const lifecycle = async (action: "validate" | "approve" | "reopen") => {
    if (!api || !authSubject || !data.batch || dirty) return;
    await runCommand(
      api[action],
      pantryCommandRequest(
        authSubject,
        correlationId,
        data.batch.version,
        `PANTRY_${action.toUpperCase()}`,
        {
          week_start: weekStart,
          expected_source_signature: data.batch.source_signature,
        },
        action === "reopen" ? reopenReason : null,
      ),
    );
  };

  if (!authSubject) {
    return (
      <p className="operator-notice warning">
        {authState.status === "session_expired"
          ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại."
          : "Đăng nhập để xem và cập nhật Pantry."}
      </p>
    );
  }

  return (
    <div className="pantry-workbench">
      {mode === "review" && (
        <p className="operator-notice warning">
          Trạng thái xem thử Pantry — thay đổi không được lưu.
        </p>
      )}
      {notice && (
        <p
          className={`operator-notice${load === "error" ? " danger" : ""}`}
          role={load === "error" ? "alert" : "status"}
        >
          {notice}
        </p>
      )}
      {load === "loading" && <p className="empty">Đang tải Pantry…</p>}
      {load === "error" && (
        <button type="button" onClick={() => void refresh()}>
          Thử tải lại Pantry
        </button>
      )}

      <Panel
        title="Pantry"
        description="Nguồn bổ sung thủ công của Lập nhu cầu; Atlas tự suy ra Điểm giao nhận mặc định và Đơn vị mua."
        status={
          <Chip tone={statusTone(data.batch?.pantry_need_batch_status)}>
            {data.batch?.pantry_need_batch_status ?? "CHƯA CÓ"}
          </Chip>
        }
      >
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
            Có thay đổi chưa lưu. Hãy xem trước và lưu trước khi xác thực.
          </p>
        )}

        <div
          className="planning-workbench-toolbar pantry-toolbar"
          aria-label="Nhập và lưu Pantry"
        >
          <div className="planning-toolbar-group pantry-entry-actions">
            <span className="planning-toolbar-label">Nội dung bổ sung</span>
            <button
              type="button"
              className="secondary"
              onClick={addRow}
              disabled={saving || noAdditions || !data.allowed_actions.can_save}
            >
              <Plus size={17} aria-hidden="true" />
              Thêm dòng Pantry
            </button>
            <label className="pantry-zero-confirmation">
              <input
                type="checkbox"
                checked={noAdditions}
                disabled={saving || !data.allowed_actions.can_save}
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
              Xác nhận tuần này không có bổ sung
            </label>
          </div>
          <div className="planning-toolbar-group planning-local-actions">
            <span className="planning-toolbar-label">Bản nháp cục bộ</span>
            <button
              type="button"
              className="secondary"
              onClick={() => void previewRows()}
              disabled={saving || !data.allowed_actions.can_preview}
            >
              <Eye size={17} aria-hidden="true" />
              Xem trước có thẩm quyền
            </button>
            <button
              type="button"
              className="primary"
              onClick={() => void save()}
              disabled={
                saving || !data.allowed_actions.can_save || !preview?.can_save
              }
            >
              <FloppyDisk size={17} aria-hidden="true" />
              Lưu bản nháp
            </button>
          </div>
        </div>

        {rows.length === 0 ? (
          <p className={`empty${noAdditions ? " pantry-zero-state" : ""}`}>
            {noAdditions
              ? "Đã chọn xác nhận không có bổ sung; hãy xem trước trước khi lưu."
              : "Chưa có dòng Pantry."}
          </p>
        ) : (
          <div className="planning-grid-scroll">
            <table className="compact-table pantry-table">
              <thead>
                <tr>
                  <th>Ngày phục vụ</th>
                  <th>Trường</th>
                  <th>Điểm giao nhận</th>
                  <th>Nguyên liệu</th>
                  <th>Đơn vị</th>
                  <th>Mục đích</th>
                  <th>Số lượng</th>
                  <th>Ghi chú</th>
                  <th>Tham chiếu</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {rows.map((row, index) => {
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
                        <input
                          aria-label={`Ngày phục vụ dòng ${index + 1}`}
                          type="date"
                          min={data.week_start}
                          max={data.week_end}
                          value={row.service_date}
                          disabled={!data.allowed_actions.can_save}
                          onChange={(event) =>
                            updateRow(index, "service_date", event.target.value)
                          }
                        />
                      </td>
                      <td>
                        <select
                          aria-label={`Trường dòng ${index + 1}`}
                          value={row.school_id}
                          disabled={!data.allowed_actions.can_save}
                          onChange={(event) =>
                            updateRow(index, "school_id", event.target.value)
                          }
                        >
                          {data.schools.map((item) => (
                            <option value={item.school_id} key={item.school_id}>
                              {item.school_code} · {item.school_name}
                            </option>
                          ))}
                        </select>
                      </td>
                      <td data-derived="delivery-location">
                        {school?.default_delivery_location.location_name ?? "—"}
                      </td>
                      <td>
                        <select
                          aria-label={`Nguyên liệu dòng ${index + 1}`}
                          value={row.ingredient_id}
                          disabled={!data.allowed_actions.can_save}
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
                              {item.ingredient_code} · {item.ingredient_name}
                            </option>
                          ))}
                        </select>
                      </td>
                      <td data-derived="purchase-unit">
                        {ingredient?.purchase_unit.unit_name ?? "—"}
                      </td>
                      <td>
                        <select
                          aria-label={`Mục đích dòng ${index + 1}`}
                          value={row.pantry_need_purpose_id}
                          disabled={!data.allowed_actions.can_save}
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
                          disabled={!data.allowed_actions.can_save}
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
                            !data.allowed_actions.can_save ||
                            purpose?.note_rule === "PROHIBITED"
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
                          disabled={!data.allowed_actions.can_save}
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
                          disabled={!data.allowed_actions.can_save}
                          onClick={() =>
                            markEdited(
                              rows.filter(
                                (_candidate, rowIndex) => rowIndex !== index,
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

        <details className="planning-evidence">
          <summary>Bằng chứng nguồn Pantry</summary>
          <section
            className="planning-source-summary planning-source-summary-inline"
            aria-label="Nguồn Pantry"
          >
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
          </section>
        </details>

        {preview && (
          <section
            className="planning-preview-summary"
            aria-label="Xem trước Pantry"
          >
            <strong>
              {preview.comparison.status} · {preview.canonical_rows.length} dòng
            </strong>
            <span>
              Mới {preview.comparison.new_lines.length} · Thay đổi{" "}
              {preview.comparison.changed_lines.length} · Không đổi{" "}
              {preview.comparison.unchanged_lines.length} · Loại bỏ{" "}
              {preview.comparison.omitted_lines.length}
            </span>
            <code>{preview.source_signature}</code>
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
          </section>
        )}

        {(data.batch?.invalid_lines.length ?? 0) > 0 && (
          <details>
            <summary>
              Dòng đã vô hiệu ({data.batch?.invalid_lines.length})
            </summary>
            <ul>
              {data.batch?.invalid_lines.map((line) => (
                <li key={line.pantry_need_line_id}>
                  {dateVi(line.service_date)} · {line.school_name} ·{" "}
                  {line.ingredient_name} · {line.requested_quantity}{" "}
                  {line.unit_name}
                </li>
              ))}
            </ul>
          </details>
        )}

        <details>
          <summary>
            Lịch sử phê duyệt ({data.batch?.approval_history.length ?? 0})
          </summary>
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
        </details>
        <details>
          <summary>
            Lịch sử thay đổi ({data.batch?.change_history.length ?? 0})
          </summary>
          <ul>
            {data.batch?.change_history.map((change) => (
              <li key={change.audit_event_id}>
                {change.event_type} · v{change.version_after} ·{" "}
                {change.actor_display_name}
                {change.reason_note && <small>{change.reason_note}</small>}
              </li>
            ))}
          </ul>
        </details>
        <div
          className="planning-lifecycle-actions pantry-lifecycle-actions"
          aria-label="Thao tác vòng đời Pantry"
        >
          <span className="planning-action-heading">Quyết định vòng đời</span>
          <button
            type="button"
            className="primary"
            onClick={() => void lifecycle("validate")}
            disabled={saving || dirty || !data.allowed_actions.can_validate}
          >
            Xác thực
          </button>
          <button
            type="button"
            className="commitment"
            onClick={() => void lifecycle("approve")}
            disabled={saving || dirty || !data.allowed_actions.can_approve}
          >
            Phê duyệt
          </button>
          {data.batch?.pantry_need_batch_status === "APPROVED" && (
            <section className="pantry-reopen">
              <label>
                Lý do mở lại
                <textarea
                  value={reopenReason}
                  onChange={(event) => setReopenReason(event.target.value)}
                />
              </label>
              <button
                type="button"
                className="secondary"
                onClick={() => void lifecycle("reopen")}
                disabled={
                  saving ||
                  dirty ||
                  !data.allowed_actions.can_reopen ||
                  reopenReason.trim().length === 0
                }
              >
                Mở lại
              </button>
            </section>
          )}
        </div>
      </Panel>
    </div>
  );
}
