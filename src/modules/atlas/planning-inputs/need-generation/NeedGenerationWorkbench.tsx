import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../../connection/authSession";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import { Chip, CompactTable, Panel } from "../../WorkbenchComponents";
import {
  confirmedNeedMaterializationRequest,
  needGenerationCommandRequest,
  type ConfirmedNeedMaterializationRequest,
  type NeedGenerationApi,
  type NeedGenerationCommandRequest,
  type NeedGenerationDetailGroup,
  type NeedGenerationFilters,
} from "./needGenerationApi";
import {
  formatQuantity,
  needGenerationReadbackFromResult,
  needGenerationResultAllowsExactRetry,
  needGenerationResultIsStale,
  needGenerationResultMessage,
  needGenerationWorkbenchFromResult,
  type NeedGenerationGroup,
  type NeedGenerationIssue,
  type NeedGenerationWorkbenchData,
} from "./needGenerationModel";

type Operation =
  "create" | "validate" | "release" | "materialize" | "invalidate";
type PendingCommand = {
  operation: Operation;
  request: NeedGenerationCommandRequest | ConfirmedNeedMaterializationRequest;
};

const emptyFilters: NeedGenerationFilters = {
  service_date: null,
  school_id: null,
  ingredient_id: null,
  contribution_family: null,
};

function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function statusLabel(status?: string | null) {
  const labels: Record<string, string> = {
    GENERATED: "ĐÃ TẠO",
    VALIDATED: "ĐÃ KIỂM TRA",
    RELEASED_FOR_CONFIRMATION: "ĐÃ PHÁT HÀNH",
    INVALIDATED: "ĐÃ VÔ HIỆU HÓA",
    NEED_GENERATION_REQUESTED: "ĐÃ YÊU CẦU TẠO NHU CẦU",
    READY: "SẴN SÀNG",
  };
  return status ? (labels[status] ?? status) : "CHƯA CÓ";
}

function statusTone(status?: string | null) {
  if (
    ["VALIDATED", "RELEASED_FOR_CONFIRMATION", "READY"].includes(status ?? "")
  )
    return "ok" as const;
  if (status === "INVALIDATED") return "danger" as const;
  return "warning" as const;
}

function IssueList({
  title,
  tone,
  items,
}: {
  title: string;
  tone: "danger" | "warning";
  items: NeedGenerationIssue[];
}) {
  if (!items.length) return null;
  return (
    <section className={`planning-issues ${tone}`} aria-label={title}>
      <strong>
        {title} ({items.length})
      </strong>
      <ul>
        {items.map((item) => (
          <li key={item.need_generation_issue_id}>
            {item.message}
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
  selectedWeekStart,
  selectedWeekEnd,
  onConfirmedNeedMaterialized,
}: {
  authState: AtlasAuthState;
  api?: NeedGenerationApi;
  selectedWeekStart: string;
  selectedWeekEnd: string;
  onConfirmedNeedMaterialized?: (confirmedNeedBatchId: string) => void;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [periodStart, setPeriodStart] = useState(selectedWeekStart);
  const [periodEnd, setPeriodEnd] = useState(selectedWeekEnd);
  const [draftStart, setDraftStart] = useState(selectedWeekStart);
  const [draftEnd, setDraftEnd] = useState(selectedWeekEnd);
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
  const [pending, setPending] = useState<PendingCommand | null>(null);
  const [invalidationReason, setInvalidationReason] = useState<
    "UPSTREAM_SOURCE_CHANGED" | "PLANNING_CORRECTION"
  >("PLANNING_CORRECTION");
  const [invalidationNote, setInvalidationNote] = useState("");
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;
  const limit = 100;

  const loadWorkbench = useCallback(
    async (
      overrides: {
        nextOffset?: number;
        nextFilters?: NeedGenerationFilters;
        nextDetail?: NeedGenerationDetailGroup | null;
        nextRunId?: string | null;
      } = {},
    ) => {
      if (!api || !authSubject) return false;
      const requestGeneration = ++generation.current;
      setLoading(true);
      const result = await api.getWorkbench(
        authSubject,
        correlationId,
        periodStart,
        periodEnd,
        overrides.nextRunId === undefined ? selectedRunId : overrides.nextRunId,
        overrides.nextFilters ?? filters,
        overrides.nextOffset ?? offset,
        limit,
        overrides.nextDetail === undefined ? detailGroup : overrides.nextDetail,
      );
      if (requestGeneration !== generation.current) return false;
      setLoading(false);
      const next = needGenerationWorkbenchFromResult(result);
      if (!next) {
        setWorkbench(null);
        setNotice(needGenerationResultMessage(result));
        return false;
      }
      setWorkbench(next);
      setNotice(null);
      return true;
    },
    [
      api,
      authSubject,
      correlationId,
      detailGroup,
      filters,
      offset,
      periodEnd,
      periodStart,
      selectedRunId,
    ],
  );

  useEffect(() => {
    setPeriodStart(selectedWeekStart);
    setPeriodEnd(selectedWeekEnd);
    setDraftStart(selectedWeekStart);
    setDraftEnd(selectedWeekEnd);
    setOffset(0);
    setSelectedRunId(null);
    setDetailGroup(null);
  }, [selectedWeekEnd, selectedWeekStart]);

  useEffect(() => {
    if (authSubject) void loadWorkbench();
    else setWorkbench(null);
  }, [authSubject, loadWorkbench]);

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

  const applyPeriod = () => {
    if (!draftStart || !draftEnd || draftEnd < draftStart) {
      setNotice("Cần chọn khoảng ngày hợp lệ.");
      return;
    }
    setPeriodStart(draftStart);
    setPeriodEnd(draftEnd);
    setOffset(0);
    setSelectedRunId(null);
    setDetailGroup(null);
    setPending(null);
  };

  const applyFilters = () => {
    setFilters(draftFilters);
    setOffset(0);
    setDetailGroup(null);
    void loadWorkbench({
      nextFilters: draftFilters,
      nextOffset: 0,
      nextDetail: null,
    });
  };

  const execute = useCallback(
    async (intent: PendingCommand) => {
      if (!api) return;
      setBusy(true);
      setNotice(null);
      let result: AtlasRpcResult;
      if (intent.operation === "materialize")
        result = await api.materialize(
          intent.request as ConfirmedNeedMaterializationRequest,
        );
      else
        result = await api[intent.operation](
          intent.request as NeedGenerationCommandRequest,
        );
      setBusy(false);
      if (needGenerationResultAllowsExactRetry(result)) {
        setPending(intent);
        setNotice(needGenerationResultMessage(result));
        return;
      }
      setPending(null);
      if (needGenerationResultIsStale(result)) {
        setWorkbench(null);
        setNotice(needGenerationResultMessage(result));
        await loadWorkbench();
        return;
      }
      if (result.kind !== "success") {
        setNotice(needGenerationResultMessage(result));
        return;
      }
      const readback = needGenerationReadbackFromResult(result);
      if (readback) setWorkbench(readback);
      else await loadWorkbench();
      setNotice(needGenerationResultMessage(result));
      if (intent.operation === "materialize") {
        const aggregates = result.response.affected_aggregate_ids;
        const confirmedNeedBatchId =
          aggregates?.confirmed_need_batch_id ??
          readback?.materialization.confirmed_need_batch_id;
        if (typeof confirmedNeedBatchId === "string")
          onConfirmedNeedMaterialized?.(confirmedNeedBatchId);
      }
      if (intent.operation === "invalidate") setInvalidationNote("");
    },
    [api, loadWorkbench, onConfirmedNeedMaterialized],
  );

  const beginAction = (operation: Operation) => {
    if (!authSubject || !workbench) return;
    const run = workbench.selected_run;
    let request: PendingCommand["request"];
    if (operation === "create") {
      const root = workbench.planning_input_set;
      const evaluation = workbench.current_evaluation;
      if (!root || !evaluation) return;
      request = needGenerationCommandRequest(
        authSubject,
        correlationId,
        evaluation.evaluation_version,
        "NEED_GENERATION_CREATED",
        null,
        {
          planning_input_set_id: root.planning_input_set_id,
          planning_input_evaluation_id: evaluation.planning_input_evaluation_id,
          period_start: periodStart,
          period_end: periodEnd,
        },
      );
    } else if (operation === "materialize") {
      if (!run) return;
      const materialization = workbench.materialization;
      const correction = materialization.materialization_mode === "CORRECTION";
      request = confirmedNeedMaterializationRequest(
        authSubject,
        correlationId,
        correction ? (materialization.confirmed_need_batch_version ?? 1) : 1,
        run.need_generation_run_id,
        run.version,
        correction ? materialization.confirmed_need_batch_id : null,
      );
    } else {
      if (!run) return;
      const reasons = {
        validate: ["NEED_GENERATION_VALIDATED", null] as const,
        release: ["NEED_GENERATION_RELEASED", null] as const,
        invalidate: [invalidationReason, invalidationNote.trim()] as const,
      };
      const [reasonCode, reasonNote] = reasons[operation];
      request = needGenerationCommandRequest(
        authSubject,
        correlationId,
        run.version,
        reasonCode,
        reasonNote,
        { need_generation_run_id: run.need_generation_run_id },
      );
    }
    const intent = { operation, request };
    setPending(intent);
    void execute(intent);
  };

  const action = (operation: Operation, label: string, allowed: boolean) => (
    <button
      type="button"
      disabled={busy || !allowed}
      title={workbench?.disabled_reasons[operation] ?? undefined}
      onClick={() => beginAction(operation)}
    >
      {label}
    </button>
  );

  return (
    <Panel
      title="Tạo nhu cầu"
      description="Tạo nhu cầu nguyên liệu từ đúng Thực đơn, Sĩ số và Pantry đã được đánh giá; mọi số lượng do backend quyết định."
      status={
        <Chip tone={statusTone(workbench?.selected_run?.status)}>
          {statusLabel(workbench?.selected_run?.status)}
        </Chip>
      }
    >
      <div className="need-generation-period">
        <label>
          Từ ngày
          <input
            aria-label="Từ ngày tạo nhu cầu"
            type="date"
            value={draftStart}
            onChange={(event) => setDraftStart(event.target.value)}
          />
        </label>
        <label>
          Đến ngày
          <input
            aria-label="Đến ngày tạo nhu cầu"
            type="date"
            value={draftEnd}
            onChange={(event) => setDraftEnd(event.target.value)}
          />
        </label>
        <button type="button" disabled={loading} onClick={applyPeriod}>
          Xem kỳ
        </button>
        <button
          type="button"
          disabled={loading}
          onClick={() => void loadWorkbench()}
        >
          Tải lại
        </button>
      </div>

      {loading && <p role="status">Đang tải nhu cầu có thẩm quyền…</p>}
      {notice && (
        <p className="operator-notice" role="status">
          {notice}
        </p>
      )}
      {!loading && !workbench && (
        <p className="operator-notice warning">
          Chưa có dữ liệu Need Generation cho kỳ này. Nếu chưa yêu cầu, hãy quay
          lại tab Sẵn sàng đầu vào.
        </p>
      )}

      {workbench && (
        <>
          <section
            className="need-generation-readiness"
            aria-label="Sẵn sàng đầu vào"
          >
            <div>
              <span>Sẵn sàng đầu vào</span>
              <Chip
                tone={statusTone(
                  workbench.planning_input_set?.readiness_status,
                )}
              >
                {statusLabel(workbench.planning_input_set?.readiness_status)}
              </Chip>
            </div>
            <div>
              <span>Đánh giá</span>
              <b>
                {workbench.current_evaluation
                  ? `${statusLabel(workbench.current_evaluation.evaluation_result)} · v${workbench.current_evaluation.evaluation_version}`
                  : "Chưa có"}
              </b>
            </div>
            {(["weekly_menu", "attendance", "pantry"] as const).map(
              (source) => (
                <div key={source}>
                  <span>
                    {source === "weekly_menu"
                      ? "Thực đơn"
                      : source === "attendance"
                        ? "Sĩ số"
                        : "Pantry"}
                  </span>
                  <b>
                    {String(workbench.source_evidence[source]?.line_count ?? 0)}{" "}
                    dòng
                  </b>
                </div>
              ),
            )}
          </section>

          {workbench.planning_input_set?.readiness_status !==
            "NEED_GENERATION_REQUESTED" && (
            <p className="operator-notice warning">
              Hãy quay lại Sẵn sàng đầu vào, đánh giá ba nguồn và chọn yêu cầu
              tạo nhu cầu.
            </p>
          )}

          {workbench.selected_run && (
            <section className="need-generation-run-summary">
              <div>
                <span>Lần tạo</span>
                <b>#{workbench.selected_run.attempt_ordinal}</b>
              </div>
              <div>
                <span>Trạng thái / phiên bản</span>
                <b>
                  {statusLabel(workbench.selected_run.status)} · v
                  {workbench.selected_run.version}
                </b>
              </div>
              <div>
                <span>Dòng nguyên tử</span>
                <b>{workbench.selected_run.generated_line_count}</b>
              </div>
              <div>
                <span>Lỗi chặn / cảnh báo</span>
                <b>
                  {workbench.selected_run.blocking_issue_count} /{" "}
                  {workbench.selected_run.warning_count}
                </b>
              </div>
            </section>
          )}

          <IssueList
            title="Lỗi chặn"
            tone="danger"
            items={workbench.blocking_issues}
          />
          <IssueList
            title="Cảnh báo"
            tone="warning"
            items={workbench.warnings}
          />

          <div className="need-generation-actions">
            {action("create", "Tạo nhu cầu", workbench.allowed_actions.create)}
            {action(
              "validate",
              "Kiểm tra nhu cầu",
              workbench.allowed_actions.validate,
            )}
            {action(
              "release",
              "Phát hành nhu cầu",
              workbench.allowed_actions.release,
            )}
            {action(
              "materialize",
              "Tạo nhu cầu xác nhận",
              workbench.allowed_actions.materialize,
            )}
            <select
              aria-label="Lý do vô hiệu hóa nhu cầu"
              value={invalidationReason}
              onChange={(event) => {
                setInvalidationReason(
                  event.target.value as typeof invalidationReason,
                );
                setPending(null);
              }}
            >
              <option value="PLANNING_CORRECTION">Điều chỉnh kế hoạch</option>
              <option value="UPSTREAM_SOURCE_CHANGED">
                Nguồn đầu vào thay đổi
              </option>
            </select>
            <input
              aria-label="Ghi chú vô hiệu hóa nhu cầu"
              value={invalidationNote}
              onChange={(event) => {
                setInvalidationNote(event.target.value);
                setPending(null);
              }}
              placeholder="Ghi chú bắt buộc"
            />
            {action(
              "invalidate",
              "Vô hiệu hóa",
              workbench.allowed_actions.invalidate &&
                Boolean(invalidationNote.trim()),
            )}
          </div>

          {pending && (
            <p className="operator-notice warning">
              Yêu cầu {pending.operation} đang được giữ nguyên.
              <button
                type="button"
                disabled={busy}
                onClick={() => void execute(pending)}
              >
                Thử lại đúng yêu cầu
              </button>
            </p>
          )}

          <section className="need-generation-materialization">
            <strong>Nhu cầu xác nhận</strong>
            <span>
              {workbench.materialization.confirmed_need_batch_id ?? "Chưa tạo"}{" "}
              · {workbench.materialization.confirmed_need_status ?? "NONE"} ·{" "}
              {workbench.materialization.materialization_mode}
            </span>
          </section>

          <div className="need-generation-filters">
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
                <option value="PANTRY_DIRECT">Pantry</option>
              </select>
            </label>
            <button type="button" onClick={applyFilters}>
              Lọc
            </button>
          </div>

          <div className="planning-grid-scroll">
            <CompactTable
              headers={[
                "Ngày",
                "Trường",
                "Điểm giao",
                "Nguyên liệu",
                "ĐVT",
                "Công thức",
                "Pantry",
                "Tổng",
                "Chi tiết",
              ]}
            >
              {workbench.grouped_requirements.map((group) => (
                <tr
                  key={`${group.service_date}:${group.school_id}:${group.delivery_location_id}:${group.ingredient_id}:${group.unit_id}`}
                >
                  <td>{viDate(group.service_date)}</td>
                  <th>{group.school_name}</th>
                  <td>{group.delivery_location_name}</td>
                  <td>{group.ingredient_name}</td>
                  <td>{group.unit_name}</td>
                  <td>{formatQuantity(group.recipe_derived_quantity)}</td>
                  <td>{formatQuantity(group.pantry_direct_quantity)}</td>
                  <td>
                    <b>{formatQuantity(group.total_theoretical_quantity)}</b>
                  </td>
                  <td>
                    <button
                      type="button"
                      onClick={() => {
                        const identity = groupIdentity(group);
                        setDetailGroup(identity);
                        void loadWorkbench({ nextDetail: identity });
                      }}
                    >
                      Xem{" "}
                      {group.active_contribution_count +
                        group.removed_contribution_count}
                    </button>
                  </td>
                </tr>
              ))}
            </CompactTable>
          </div>

          <div className="need-generation-pagination">
            <button
              type="button"
              disabled={offset === 0 || loading}
              onClick={() => {
                const next = Math.max(0, offset - limit);
                setOffset(next);
                void loadWorkbench({ nextOffset: next });
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
                void loadWorkbench({ nextOffset: next });
              }}
            >
              Trang sau
            </button>
          </div>

          {detailGroup && (
            <details open className="need-generation-detail">
              <summary>Chi tiết đóng góp nguyên tử</summary>
              <ul>
                {workbench.atomic_detail.map((item) => (
                  <li key={item.theoretical_need_line_id}>
                    <b>
                      {item.contribution_family === "RECIPE_DERIVED"
                        ? "Công thức"
                        : "Pantry"}
                    </b>{" "}
                    · {formatQuantity(item.theoretical_quantity)}{" "}
                    {item.unit_name} · {item.disposition}
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
                      void loadWorkbench({
                        nextRunId: run.need_generation_run_id,
                        nextDetail: null,
                      });
                    }}
                  >
                    Lần #{run.attempt_ordinal} · {statusLabel(run.status)} · v
                    {run.version}
                  </button>
                </li>
              ))}
            </ul>
          </details>
        </>
      )}
    </Panel>
  );
}
