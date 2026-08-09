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
  weekly_menu: "Thực đơn tuần",
  attendance: "Số suất ăn",
  pantry: "Nhu cầu bổ sung",
};

function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function currentnessLabel(
  currentness: PlanningInputPreflightData["downstream_currentness"],
) {
  const labels = {
    CURRENT: "HIỆN HÀNH",
    OUTDATED: "CẦN CẬP NHẬT",
    NOT_GENERATED: "CHƯA TẠO",
  } as const;
  return labels[currentness];
}

function currentnessTone(
  currentness: PlanningInputPreflightData["downstream_currentness"],
) {
  if (currentness === "CURRENT") return "ok" as const;
  if (currentness === "OUTDATED") return "danger" as const;
  return "warning" as const;
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
  preflightApi,
  selectedWeekStart,
  selectedWeekEnd,
  onConfirmedNeedMaterialized,
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
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [periodStart, setPeriodStart] = useState(selectedWeekStart);
  const [periodEnd, setPeriodEnd] = useState(selectedWeekEnd);
  const [draftStart, setDraftStart] = useState(selectedWeekStart);
  const [draftEnd, setDraftEnd] = useState(selectedWeekEnd);
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
      const [preflightResult, workbenchResult] = await Promise.all([
        preflightApi.preflight(
          authSubject,
          correlationId,
          periodStart,
          periodEnd,
        ),
        api.getWorkbench(
          authSubject,
          correlationId,
          periodStart,
          periodEnd,
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
      const nextPreflight = planningInputPreflightFromResult(preflightResult);
      if (!nextPreflight) {
        setPreflight(null);
        setNotice(readinessResultMessage(preflightResult));
        return false;
      }
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
      detailGroup,
      filters,
      offset,
      periodEnd,
      periodStart,
      preflightApi,
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
    if (authSubject) void loadAuthority();
    else {
      setPreflight(null);
      setWorkbench(null);
    }
  }, [authSubject, loadAuthority]);

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
  };

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
      refreshRequired ||
      executionBlocker
    )
      return;
    const request = needGenerationExecutionRequest(
      authSubject,
      correlationId,
      preflight.current_need?.need_generation_run_version ?? 1,
      periodStart,
      periodEnd,
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
    setPreflight(nextPreflight);
    setWorkbench(nextWorkbench);
    setNotice(needGenerationResultMessage(result));
    setExecutionBlocker(null);
    if (!nextPreflight || !nextWorkbench) setRefreshRequired(true);
  };

  const blockers =
    preflight?.issues.filter((issue) => issue.severity === "BLOCKING") ?? [];
  const warnings =
    preflight?.issues.filter((issue) => issue.severity === "WARNING") ?? [];
  const executionLabel =
    preflight?.downstream_currentness === "OUTDATED"
      ? "Cập nhật nhu cầu"
      : "Tạo nhu cầu";
  const canExecute =
    preflight?.readiness_state === "READY" &&
    preflight.downstream_currentness !== "CURRENT" &&
    !refreshRequired &&
    !executionBlocker;

  return (
    <Panel
      title="Tạo nhu cầu"
      description="Kiểm tra tự động ba nguồn đã lưu và tạo hoặc cập nhật nhu cầu bằng một thao tác."
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
            disabled={loading || busy}
            onClick={() => void loadAuthority()}
          >
            <ArrowClockwise aria-hidden="true" size={16} />
            Tải lại có thẩm quyền
          </button>
        </div>
      </details>

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
          tải lại dữ liệu có thẩm quyền.
        </p>
      )}

      {preflight && (
        <>
          <section
            className="need-generation-readiness"
            aria-label="Trạng thái hiện tại"
          >
            <header>
              <div>
                <span>Trạng thái đầu vào và nhu cầu</span>
                <h3>
                  {preflight.readiness_state === "BLOCKED"
                    ? "Đầu vào đang bị chặn"
                    : preflight.downstream_currentness === "CURRENT"
                      ? "Nhu cầu đang hiện hành"
                      : preflight.downstream_currentness === "OUTDATED"
                        ? "Nhu cầu cần cập nhật"
                        : "Đầu vào đã sẵn sàng tạo nhu cầu"}
                </h3>
              </div>
              <div className="planning-status-cluster">
                <Chip
                  tone={preflight.readiness_state === "READY" ? "ok" : "danger"}
                >
                  {preflight.readiness_state}
                </Chip>
                <Chip tone={currentnessTone(preflight.downstream_currentness)}>
                  {currentnessLabel(preflight.downstream_currentness)}
                </Chip>
              </div>
            </header>
          </section>

          <div className="readiness-source-grid" aria-label="Ba nguồn kế hoạch">
            {(["weekly_menu", "attendance", "pantry"] as const).map(
              (source) => {
                const evidence = preflight.source_evidence[source];
                const selectionState =
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
                        {selectionState === "SELECTED"
                          ? "ĐÃ LƯU"
                          : selectionState}
                      </Chip>
                    </header>
                    <p className="readiness-source-empty">
                      {evidence.safe_message}
                    </p>
                    {evidence.selected && (
                      <details className="readiness-source-audit">
                        <summary>Chi tiết bằng chứng</summary>
                        <span>
                          Phiên bản{" "}
                          {String(
                            evidence.selected.weekly_menu_version ??
                              evidence.selected.attendance_version ??
                              evidence.selected.pantry_need_batch_version ??
                              "—",
                          )}{" "}
                          · {evidence.selected.line_count} dòng
                        </span>
                      </details>
                    )}
                  </section>
                );
              },
            )}
          </div>

          <IssueList title="Lỗi chặn" tone="danger" items={blockers} />
          <IssueList title="Cảnh báo" tone="warning" items={warnings} />

          <section
            className="need-generation-forward"
            aria-label="Việc cần làm tiếp theo"
          >
            <header>
              <span>Việc cần làm tiếp theo</span>
              <h3>
                {preflight.downstream_currentness === "CURRENT"
                  ? "Tiếp tục rà soát nhu cầu xác nhận"
                  : canExecute
                    ? executionLabel
                    : "Xử lý lỗi chặn trước"}
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
            {preflight.downstream_currentness === "CURRENT" &&
              preflight.current_need?.confirmed_need_batch_id && (
                <button
                  type="button"
                  className="primary-forward"
                  onClick={() =>
                    onConfirmedNeedMaterialized?.(
                      preflight.current_need!.confirmed_need_batch_id,
                    )
                  }
                >
                  Mở Xác nhận nhu cầu
                </button>
              )}
          </section>
        </>
      )}

      {workbench?.selected_run && (
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

          <div className="need-generation-filters" aria-label="Bộ lọc nhu cầu">
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
                  key={`${group.service_date}:${group.school_id}:${group.delivery_location_id}:${group.ingredient_id}:${group.unit_id}`}
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
                  Lần #{run.attempt_ordinal} · {run.status} · v{run.version}
                </button>
              </li>
            ))}
          </ul>
        </details>
      )}
    </Panel>
  );
}
