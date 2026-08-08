import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowClockwise,
  CheckCircle,
  Eye,
  Lightning,
  Package,
  SealCheck,
  Wrench,
} from "@phosphor-icons/react";
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

const forwardSequence = [
  "create",
  "validate",
  "release",
  "materialize",
] as const;

const forwardCopy = {
  create: {
    label: "Tạo nhu cầu",
    description: "Tạo một lần chạy từ đúng bộ đầu vào đã được yêu cầu.",
    Icon: Lightning,
  },
  validate: {
    label: "Kiểm tra nhu cầu",
    description: "Xác nhận lần chạy không còn lỗi chặn trước khi phát hành.",
    Icon: CheckCircle,
  },
  release: {
    label: "Phát hành nhu cầu",
    description: "Khóa ảnh chụp các đóng góp để chuyển sang xác nhận.",
    Icon: SealCheck,
  },
  materialize: {
    label: "Tạo nhu cầu xác nhận",
    description: "Tạo hoặc cập nhật đối tượng rà soát Xác nhận nhu cầu.",
    Icon: Package,
  },
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

  const activeForwardAction = workbench
    ? forwardSequence.find((operation) => workbench.allowed_actions[operation])
    : undefined;

  const forwardActions = (
    <section
      className="need-generation-forward"
      aria-label="Bước vòng đời tiếp theo"
    >
      <header>
        <span>Bước hợp lệ tiếp theo</span>
        <h3>
          {activeForwardAction
            ? forwardCopy[activeForwardAction].label
            : "Chưa có thao tác chuyển bước"}
        </h3>
      </header>
      <div className="need-generation-action-sequence">
        {forwardSequence.map((operation, index) => {
          const { label, description, Icon } = forwardCopy[operation];
          const allowed = workbench?.allowed_actions[operation] ?? false;
          const disabledReason = workbench?.disabled_reasons[operation];
          return (
            <div
              className={`need-generation-action-step ${
                activeForwardAction === operation ? "active" : ""
              }`}
              key={operation}
            >
              <span className="need-generation-step-number">{index + 1}</span>
              <div>
                <b>{label}</b>
                <small id={`need-generation-action-${operation}`}>
                  {allowed ? description : disabledReason}
                </small>
              </div>
              {allowed ? (
                <button
                  type="button"
                  className="primary-forward"
                  disabled={busy}
                  aria-describedby={`need-generation-action-${operation}`}
                  onClick={() => beginAction(operation)}
                >
                  <Icon aria-hidden="true" size={18} weight="bold" />
                  {label}
                </button>
              ) : (
                <span
                  className="need-generation-disabled-action"
                  aria-disabled="true"
                  aria-describedby={`need-generation-action-${operation}`}
                >
                  <Icon aria-hidden="true" size={18} weight="bold" />
                  {label}
                </span>
              )}
            </div>
          );
        })}
      </div>
    </section>
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
      <p className="need-generation-context">
        Kỳ đang xem, bao gồm cả hai ngày: <b>{viDate(periodStart)}</b> –{" "}
        <b>{viDate(periodEnd)}</b>
      </p>
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
          <ArrowClockwise aria-hidden="true" size={16} weight="bold" />
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
            <header>
              <div>
                <span>Bằng chứng bàn giao</span>
                <h3>Sẵn sàng đầu vào</h3>
              </div>
              <Chip
                tone={statusTone(
                  workbench.planning_input_set?.readiness_status,
                )}
              >
                {statusLabel(workbench.planning_input_set?.readiness_status)}
              </Chip>
            </header>
            <dl>
              <div>
                <dt>Đánh giá</dt>
                <dd>
                  {workbench.current_evaluation
                    ? `${statusLabel(workbench.current_evaluation.evaluation_result)} · v${workbench.current_evaluation.evaluation_version}`
                    : "Chưa có"}
                </dd>
              </div>
              {(["weekly_menu", "attendance", "pantry"] as const).map(
                (source) => (
                  <div key={source}>
                    <dt>
                      {source === "weekly_menu"
                        ? "Thực đơn"
                        : source === "attendance"
                          ? "Sĩ số"
                          : "Pantry"}
                    </dt>
                    <dd>
                      v
                      {String(
                        workbench.source_evidence[source]?.version ?? "—",
                      )}
                      {" · "}
                      {String(
                        workbench.source_evidence[source]?.line_count ?? 0,
                      )}{" "}
                      dòng
                    </dd>
                  </div>
                ),
              )}
            </dl>
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
              <header>
                <span>Lần chạy đang rà soát</span>
                <h3>Lần #{workbench.selected_run.attempt_ordinal}</h3>
                <Chip tone={statusTone(workbench.selected_run.status)}>
                  {statusLabel(workbench.selected_run.status)} · v
                  {workbench.selected_run.version}
                </Chip>
              </header>
              <dl>
                <div>
                  <dt>Dòng nguyên tử</dt>
                  <dd>{workbench.selected_run.generated_line_count}</dd>
                </div>
                <div>
                  <dt>Lỗi chặn</dt>
                  <dd>{workbench.selected_run.blocking_issue_count}</dd>
                </div>
                <div>
                  <dt>Cảnh báo</dt>
                  <dd>{workbench.selected_run.warning_count}</dd>
                </div>
              </dl>
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

          {!workbench.selected_run && forwardActions}

          {pending && !workbench.selected_run && (
            <section
              className="command-outcome warning"
              aria-label="Yêu cầu đang chờ xác minh"
            >
              <b>Chưa tự động gửi lại thao tác</b>
              <span>
                Yêu cầu {pending.operation} đang được giữ nguyên. Chỉ gửi lại
                khi người vận hành chủ động xác nhận.
              </span>
              <button
                type="button"
                disabled={busy}
                onClick={() => void execute(pending)}
              >
                Thử lại đúng yêu cầu
              </button>
            </section>
          )}

          {workbench.selected_run && (
            <section
              className="need-generation-requirements"
              aria-labelledby="need-generation-requirements-title"
            >
              <header className="need-generation-requirements-heading">
                <div>
                  <span>Bề mặt rà soát chính</span>
                  <h3 id="need-generation-requirements-title">
                    Nhu cầu nguyên liệu đã tạo
                  </h3>
                </div>
                <small>
                  {workbench.pagination.total_groups} nhóm theo đúng kết quả
                  backend
                </small>
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
                    <option value="PANTRY_DIRECT">Pantry</option>
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
                    "Pantry",
                    "Tổng",
                    "Chi tiết",
                  ]}
                >
                  {workbench.grouped_requirements.map((group) => (
                    <tr
                      key={`${group.service_date}:${group.school_id}:${group.delivery_location_id}:${group.ingredient_id}:${group.unit_id}`}
                    >
                      <td className="need-generation-date-cell">
                        {viDate(group.service_date)}
                      </td>
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
                        <b>
                          {formatQuantity(group.total_theoretical_quantity)}
                        </b>
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
                          <Eye aria-hidden="true" size={16} weight="bold" />
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
                  {Math.min(offset + limit, workbench.pagination.total_groups)}{" "}
                  / {workbench.pagination.total_groups}
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

              {forwardActions}

              {workbench.allowed_actions.invalidate && (
                <details className="need-generation-correction">
                  <summary>
                    <Wrench aria-hidden="true" size={17} weight="bold" />
                    Vô hiệu hóa để điều chỉnh
                  </summary>
                  <p>
                    Đây là đường sửa sai, không phải bước tiến bình thường. Mọi
                    dòng, vấn đề và bằng chứng phát hành hiện có vẫn được giữ
                    lại.
                  </p>
                  <div className="need-generation-invalidation-form">
                    <label>
                      Lý do
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
                        <option value="PLANNING_CORRECTION">
                          Điều chỉnh kế hoạch
                        </option>
                        <option value="UPSTREAM_SOURCE_CHANGED">
                          Nguồn đầu vào thay đổi
                        </option>
                      </select>
                    </label>
                    <label>
                      Ghi chú bắt buộc
                      <input
                        aria-label="Ghi chú vô hiệu hóa nhu cầu"
                        value={invalidationNote}
                        onChange={(event) => {
                          setInvalidationNote(event.target.value);
                          setPending(null);
                        }}
                        placeholder="Nêu rõ lý do cần sửa"
                      />
                    </label>
                    <button
                      type="button"
                      className="destructive-secondary"
                      disabled={busy || !invalidationNote.trim()}
                      onClick={() => beginAction("invalidate")}
                    >
                      Vô hiệu hóa lần chạy
                    </button>
                  </div>
                </details>
              )}

              <section className="need-generation-materialization-boundary">
                <div>
                  <span>Ranh giới của bước cuối</span>
                  <h3>Tạo nhu cầu xác nhận</h3>
                </div>
                <p>
                  Tạo hoặc cập nhật đối tượng Xác nhận nhu cầu để tiếp tục rà
                  soát. Không tạo Bàn giao mua hàng, không chọn nhà cung cấp,
                  không tạo đơn mua hàng và không thay đổi Kho hay Giao nhận.
                </p>
                <small>
                  Hiện tại:{" "}
                  {workbench.materialization.confirmed_need_status ??
                    "chưa tạo"}
                  {workbench.materialization.confirmed_need_batch_id
                    ? ` · ${workbench.materialization.confirmed_need_batch_id}`
                    : ""}
                </small>
              </section>

              {pending && (
                <section
                  className="command-outcome warning"
                  aria-label="Yêu cầu đang chờ xác minh"
                >
                  <b>Chưa tự động gửi lại thao tác</b>
                  <span>
                    Yêu cầu {pending.operation} đang được giữ nguyên. Chỉ gửi
                    lại khi người vận hành chủ động xác nhận.
                  </span>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => void execute(pending)}
                  >
                    Thử lại đúng yêu cầu
                  </button>
                </section>
              )}
            </section>
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
