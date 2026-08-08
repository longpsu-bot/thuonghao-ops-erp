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
    description: "Tạo nhu cầu nguyên liệu từ bộ đầu vào đã sẵn sàng.",
    Icon: Lightning,
  },
  validate: {
    label: "Kiểm tra nhu cầu",
    description: "Xác nhận kết quả không còn lỗi chặn trước khi phát hành.",
    Icon: CheckCircle,
  },
  release: {
    label: "Phát hành nhu cầu",
    description: "Chốt kết quả đã kiểm tra để chuyển sang xác nhận nhu cầu.",
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

function workflowStatus(workbench: NeedGenerationWorkbenchData) {
  const run = workbench.selected_run;
  if (!run)
    return workbench.planning_input_set?.readiness_status ===
      "NEED_GENERATION_REQUESTED"
      ? "Sẵn sàng tạo nhu cầu"
      : "Chưa thể tạo nhu cầu";
  if (run.status === "GENERATED")
    return run.blocking_issue_count > 0
      ? "Đã tạo — cần xử lý lỗi chặn"
      : "Đã tạo — cần kiểm tra";
  if (run.status === "VALIDATED") return "Đã kiểm tra — có thể phát hành";
  if (run.status === "RELEASED_FOR_CONFIRMATION")
    return workbench.materialization.confirmed_need_batch_id
      ? "Đã chuyển sang Xác nhận nhu cầu"
      : "Đã phát hành — có thể tạo nhu cầu xác nhận";
  if (run.status === "INVALIDATED")
    return "Đã vô hiệu hóa — cần tạo lại khi đủ điều kiện";
  return statusLabel(run.status);
}

function expectedOperation(workbench: NeedGenerationWorkbenchData) {
  const status = workbench.selected_run?.status;
  if (!status || status === "INVALIDATED") return "create" as const;
  if (status === "GENERATED") return "validate" as const;
  if (status === "VALIDATED") return "release" as const;
  if (status === "RELEASED_FOR_CONFIRMATION") return "materialize" as const;
  return null;
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
    void execute(intent);
  };

  const allowedForwardActions = workbench
    ? forwardSequence.filter(
        (operation) => workbench.allowed_actions[operation],
      )
    : [];
  const activeForwardAction =
    allowedForwardActions.length === 1 ? allowedForwardActions[0] : null;
  const unexpectedForwardActions = allowedForwardActions.length > 1;
  const expectedBlockedAction = workbench ? expectedOperation(workbench) : null;
  const expectedDisabledReason =
    workbench && expectedBlockedAction
      ? workbench.disabled_reasons[expectedBlockedAction]
      : null;

  const forwardActions = (
    <section
      className="need-generation-forward"
      aria-label="Việc cần làm tiếp theo"
    >
      <header>
        <span>Việc cần làm tiếp theo</span>
        <h3>
          {activeForwardAction
            ? forwardCopy[activeForwardAction].label
            : "Chưa thể tiếp tục"}
        </h3>
      </header>
      {activeForwardAction &&
        (() => {
          const { label, description, Icon } = forwardCopy[activeForwardAction];
          return (
            <div className="need-generation-active-action">
              <p id={`need-generation-action-${activeForwardAction}`}>
                {description}
              </p>
              <button
                type="button"
                className="primary-forward"
                disabled={busy}
                aria-describedby={`need-generation-action-${activeForwardAction}`}
                onClick={() => beginAction(activeForwardAction)}
              >
                <Icon aria-hidden="true" size={18} />
                {label}
              </button>
            </div>
          );
        })()}
      {!activeForwardAction &&
        !unexpectedForwardActions &&
        expectedDisabledReason && (
          <p className="need-generation-blocked-reason">
            {expectedDisabledReason}
          </p>
        )}
      {unexpectedForwardActions && (
        <p className="operator-notice warning" role="alert">
          Hệ thống trả về nhiều thao tác tiếp theo cùng lúc. Hãy tải lại trước
          khi tiếp tục.
        </p>
      )}
    </section>
  );

  return (
    <Panel
      title="Tạo nhu cầu"
      description="Rà soát nhu cầu nguyên liệu và thực hiện đúng việc tiếp theo."
    >
      <p className="need-generation-context">
        Tuần đang xử lý: <b>{viDate(periodStart)}</b> –{" "}
        <b>{viDate(periodEnd)}</b>
      </p>
      <details className="need-generation-period-disclosure">
        <summary>Đổi phạm vi xem</summary>
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
            Xem phạm vi này
          </button>
          <button
            type="button"
            disabled={loading}
            onClick={() => void loadWorkbench()}
          >
            <ArrowClockwise aria-hidden="true" size={16} />
            Tải lại
          </button>
        </div>
      </details>

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
            aria-label="Trạng thái hiện tại"
          >
            <header>
              <div>
                <span>Trạng thái hiện tại</span>
                <h3>{workflowStatus(workbench)}</h3>
              </div>
              <Chip
                tone={statusTone(
                  workbench.selected_run?.status ??
                    workbench.planning_input_set?.readiness_status,
                )}
              >
                {statusLabel(
                  workbench.selected_run?.status ??
                    workbench.planning_input_set?.readiness_status,
                )}
              </Chip>
            </header>
            <small>
              {workbench.selected_run
                ? `Lần tạo #${workbench.selected_run.attempt_ordinal}`
                : workbench.planning_input_set?.readiness_status ===
                    "NEED_GENERATION_REQUESTED"
                  ? "Đầu vào đã được bàn giao để tạo nhu cầu."
                  : "Cần hoàn tất kiểm tra đầu vào trước."}
            </small>
            <details className="need-generation-support-detail">
              <summary>Chi tiết đầu vào và lần tạo</summary>
              <dl>
                <div>
                  <dt>Đánh giá đầu vào</dt>
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
                        )}{" "}
                        ·{" "}
                        {String(
                          workbench.source_evidence[source]?.line_count ?? 0,
                        )}{" "}
                        dòng
                      </dd>
                    </div>
                  ),
                )}
                {workbench.selected_run && (
                  <div>
                    <dt>Thông tin hỗ trợ</dt>
                    <dd>
                      Phiên bản {workbench.selected_run.version} ·{" "}
                      {workbench.selected_run.generated_line_count} dòng chi
                      tiết
                    </dd>
                  </div>
                )}
              </dl>
              {workbench.planning_input_set && (
                <code>
                  {workbench.planning_input_set.planning_input_set_id}
                </code>
              )}
              {workbench.current_evaluation && (
                <code>
                  {workbench.current_evaluation.planning_input_evaluation_id}
                </code>
              )}
            </details>
          </section>

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
                          <Eye aria-hidden="true" size={16} />
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
                  <summary>Chi tiết hình thành số lượng</summary>
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
                    <Wrench aria-hidden="true" size={17} />
                    Thao tác khác
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

              {(activeForwardAction === "materialize" ||
                Boolean(workbench.materialization.confirmed_need_batch_id)) && (
                <section className="need-generation-materialization-boundary">
                  <div>
                    <span>Kết quả của thao tác</span>
                    <h3>Tạo nhu cầu xác nhận</h3>
                  </div>
                  <p>
                    Chuyển kết quả đã phát hành sang bước Xác nhận nhu cầu. Bước
                    này chưa đặt mua hàng và chưa chọn nhà cung cấp.
                  </p>
                  {workbench.materialization.confirmed_need_batch_id && (
                    <details>
                      <summary>Chi tiết kỹ thuật</summary>
                      <small>
                        {workbench.materialization.confirmed_need_status ??
                          "Đã tạo"}{" "}
                        · {workbench.materialization.confirmed_need_batch_id}
                      </small>
                    </details>
                  )}
                </section>
              )}

              {pending && (
                <section
                  className="command-outcome warning"
                  aria-label="Yêu cầu đang chờ xác minh"
                >
                  <b>Kết quả chưa xác định. Hệ thống chưa tự gửi lại.</b>
                  <span>
                    Hãy kiểm tra trạng thái hoặc chủ động thử lại đúng yêu cầu.
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

          {pending && !workbench.selected_run && (
            <section
              className="command-outcome warning"
              aria-label="Yêu cầu đang chờ xác minh"
            >
              <b>Kết quả chưa xác định. Hệ thống chưa tự gửi lại.</b>
              <span>
                Hãy kiểm tra trạng thái hoặc chủ động thử lại đúng yêu cầu.
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
