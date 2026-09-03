import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../connection/authSession";
import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";
import { AllocationFamilyTable } from "./AllocationFamilyTable";
import { ProcurementCommandResult } from "./ProcurementCommandResult";
import { PurchaseOrderStage } from "./PurchaseOrderStage";
import {
  confirmSupplierRecommendationsRequest,
  createPurchaseOrderDraftsRequest,
  procurementWorkbenchFromResult,
  procurementWorkbenchReadRequest,
  purchaseOrdersFromResult,
  purchaseOrdersReadRequest,
  releasePurchaseOrderRequest,
  saveSupplierAllocationRequest,
  type SchoolCateringProcurementApi,
} from "./schoolCateringProcurementApi";
import { purchaseOrderDraftReadinessMessages } from "./schoolCateringProcurementModel";
import type {
  AllocationFamilyRow,
  ProcurementCommandOutcome,
  ProcurementSchoolOption,
  ProcurementStage,
  ProcurementWorkbenchData,
  PurchaseOrdersData,
  SchoolCateringPurchaseOrder,
  SupplierSplitInput,
} from "./schoolCateringProcurementModel";
import { SupplierSplitPanel } from "./SupplierSplitPanel";
import {
  downloadPurchaseOrderPdf,
  downloadPurchaseOrderXlsx,
} from "./purchaseOrderExports";

type ProcurementReadCurrentness = "loading" | "current" | "unavailable";
type AllocationPresentationFilter =
  "" | "unallocated" | "needs_update" | "blocked";

const currentnessLabels: Record<ProcurementReadCurrentness, string> = {
  loading: "Đang cập nhật…",
  current: "Dữ liệu hiện tại",
  unavailable: "Chưa xác nhận dữ liệu hiện tại",
};

function fold(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLocaleLowerCase("vi-VN");
}

function strings(value: JsonValue | undefined) {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function schoolOptions(rows: AllocationFamilyRow[]) {
  return Array.from(
    new Map(
      rows.flatMap((row) =>
        row.school_id && row.school_name
          ? [[row.school_id, row.school_name] as const]
          : [],
      ),
    ),
    ([school_id, school_name]) => ({ school_id, school_name }),
  ).sort((a, b) => a.school_name.localeCompare(b.school_name, "vi"));
}

function SchoolScopeControl({
  schools,
  selectedSchoolIds,
  onChange,
}: {
  schools: ProcurementSchoolOption[];
  selectedSchoolIds: string[];
  onChange: (schoolIds: string[]) => void;
}) {
  const allSchoolIds = schools.map((school) => school.school_id);
  const selected = new Set(
    selectedSchoolIds.length ? selectedSchoolIds : allSchoolIds,
  );
  const label =
    selectedSchoolIds.length === 0
      ? "Tất cả trường"
      : selectedSchoolIds.length === 1
        ? (schools.find((school) => school.school_id === selectedSchoolIds[0])
            ?.school_name ?? "1 trường")
        : `${selectedSchoolIds.length} trường`;

  const toggleSchool = (schoolId: string, checked: boolean) => {
    const next = new Set(selected);
    if (checked) next.add(schoolId);
    else next.delete(schoolId);
    const ordered = allSchoolIds.filter((id) => next.has(id));
    onChange(
      ordered.length === 0 || ordered.length === allSchoolIds.length
        ? []
        : ordered,
    );
  };

  return (
    <details className="procurement-school-scope">
      <summary aria-label="Phạm vi trường">
        <span>Trường / điểm giao</span>
        <strong>{label}</strong>
      </summary>
      <div className="procurement-school-scope-options">
        <button type="button" onClick={() => onChange([])}>
          Tất cả trường
        </button>
        {schools.length === 0 ? (
          <p>Chưa có trường trong dữ liệu hiện tại.</p>
        ) : (
          schools.map((school) => (
            <label key={school.school_id}>
              <input
                type="checkbox"
                checked={selected.has(school.school_id)}
                onChange={(event) =>
                  toggleSchool(school.school_id, event.currentTarget.checked)
                }
              />
              <span>{school.school_name}</span>
            </label>
          ))
        )}
      </div>
    </details>
  );
}

function outcomeFromResult(
  result: AtlasRpcResult,
  affectedLabels: string[] = [],
): ProcurementCommandOutcome {
  if (result.kind === "success") {
    const replay = result.response.idempotency_status === "REPLAY";
    return {
      classification: replay ? "REPLAY_SUCCESS" : "SUCCESS",
      code: replay ? "EXACT_REPLAY" : null,
      safe_message:
        result.response.safe_operator_message ?? "Lệnh đã hoàn tất an toàn.",
      affected_labels: affectedLabels,
      current_versions: Object.entries(result.response.new_versions ?? {}).map(
        ([key, value]) => `${key}: ${String(value)}`,
      ),
      warnings: strings(result.response.warnings),
      blockers: Array.from(
        new Set([
          ...strings(result.response.blockers),
          ...purchaseOrderDraftReadinessMessages(result.response.blockers),
          ...purchaseOrderDraftReadinessMessages(result.response.skipped_dates),
        ]),
      ),
      next_action: null,
    };
  }
  if (result.kind === "backend_error") {
    const stale = [
      "STALE_VERSION",
      "SOURCE_CHANGED",
      "PO_DRAFT_STALE",
    ].includes(result.error.error_code);
    return {
      classification: stale
        ? "STALE"
        : result.error.retryable
          ? "RETRYABLE_FAILURE"
          : "BLOCKED",
      code: result.error.error_code,
      safe_message: result.error.safe_message,
      affected_labels: affectedLabels,
      current_versions:
        result.error.actual_version === undefined
          ? []
          : [String(result.error.actual_version)],
      warnings: [],
      blockers: strings(result.error.blocking_references),
      next_action: stale ? "Tải lại dữ liệu và kiểm tra thay đổi." : null,
    };
  }
  return {
    classification:
      result.kind === "transport_error" ? "UNKNOWN_OUTCOME" : "BLOCKED",
    code: result.diagnostic.code,
    safe_message: result.diagnostic.safeMessage,
    affected_labels: affectedLabels,
    current_versions: [],
    warnings: [],
    blockers: [],
    next_action:
      result.kind === "transport_error"
        ? "Tải lại dữ liệu hiện tại trước khi thao tác tiếp."
        : null,
  };
}

export function SchoolCateringProcurementWorkbench({
  authState,
  api,
  initialDateStart,
  initialDateEnd,
  initialStage = "allocation",
  onExportPurchaseOrderXlsx = downloadPurchaseOrderXlsx,
  onExportPurchaseOrderPdf = downloadPurchaseOrderPdf,
}: {
  authState: AtlasAuthState;
  api?: SchoolCateringProcurementApi;
  initialDateStart: string;
  initialDateEnd: string;
  initialStage?: ProcurementStage;
  mode?: "connected" | "review";
  onExportPurchaseOrderXlsx?: (
    order: SchoolCateringPurchaseOrder,
  ) => void | Promise<void>;
  onExportPurchaseOrderPdf?: (
    order: SchoolCateringPurchaseOrder,
  ) => void | Promise<void>;
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const allocationTrigger = useRef<HTMLButtonElement | null>(null);
  const [dateStart, setDateStart] = useState(initialDateStart);
  const [dateEnd, setDateEnd] = useState(initialDateEnd);
  const [stage, setStage] = useState<ProcurementStage>(initialStage);
  const [search, setSearch] = useState("");
  const [stateFilter, setStateFilter] =
    useState<AllocationPresentationFilter>("");
  const [selectedSchoolIds, setSelectedSchoolIds] = useState<string[]>([]);
  const [schoolCatalogue, setSchoolCatalogue] = useState<
    ProcurementSchoolOption[]
  >([]);
  const [workbench, setWorkbench] = useState<ProcurementWorkbenchData | null>(
    null,
  );
  const [purchaseOrders, setPurchaseOrders] =
    useState<PurchaseOrdersData | null>(null);
  const [selectedFamilyKey, setSelectedFamilyKey] = useState<string | null>(
    null,
  );
  const [selectedRecommendationKeys, setSelectedRecommendationKeys] = useState<
    Set<string>
  >(new Set());
  const [busy, setBusy] = useState(false);
  const [loadMessage, setLoadMessage] = useState<string | null>(null);
  const [purchaseOrderLoadMessage, setPurchaseOrderLoadMessage] = useState<
    string | null
  >(null);
  const [allocationCurrentness, setAllocationCurrentness] =
    useState<ProcurementReadCurrentness>("unavailable");
  const [purchaseOrderCurrentness, setPurchaseOrderCurrentness] =
    useState<ProcurementReadCurrentness>("unavailable");
  const [commandOutcome, setCommandOutcome] =
    useState<ProcurementCommandOutcome | null>(null);
  const [mutationLocked, setMutationLocked] = useState(false);
  const [retryAction, setRetryAction] = useState<(() => Promise<void>) | null>(
    null,
  );
  const intent = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const loadAllocation = useCallback(async () => {
    if (!api || !authSubject) return false;
    const currentIntent = ++intent.current;
    setAllocationCurrentness("loading");
    setBusy(true);
    const result = await api.getWorkbench(
      procurementWorkbenchReadRequest(authSubject, correlationId, {
        date_start: dateStart,
        date_end: dateEnd,
        school_ids: selectedSchoolIds,
        states: [],
        search: null,
      }),
    );
    if (currentIntent !== intent.current) return false;
    const next = procurementWorkbenchFromResult(result);
    if (next) {
      setWorkbench(next);
      if (selectedSchoolIds.length === 0)
        setSchoolCatalogue(schoolOptions(next.rows));
      setLoadMessage(null);
      setAllocationCurrentness("current");
      setMutationLocked(false);
      setSelectedFamilyKey((current) =>
        next.rows.some((row) => row.family.source_fingerprint === current)
          ? current
          : null,
      );
    } else {
      setWorkbench(null);
      setAllocationCurrentness("unavailable");
      setLoadMessage(
        result.kind === "backend_error"
          ? result.error.safe_message
          : result.kind === "auth_error" ||
              result.kind === "transport_error" ||
              result.kind === "client_error"
            ? result.diagnostic.safeMessage
            : "Không thể tải dữ liệu Procurement.",
      );
    }
    setBusy(false);
    return Boolean(next);
  }, [api, authSubject, correlationId, dateEnd, dateStart, selectedSchoolIds]);

  const loadPurchaseOrders = useCallback(async () => {
    if (!api || !authSubject) return false;
    const currentIntent = ++intent.current;
    setPurchaseOrderCurrentness("loading");
    setBusy(true);
    const result = await api.getPurchaseOrders(
      purchaseOrdersReadRequest(authSubject, correlationId, {
        date_start: dateStart,
        date_end: dateEnd,
        supplier_ids: [],
        statuses: [],
        search: null,
      }),
    );
    if (currentIntent !== intent.current) return false;
    const next = purchaseOrdersFromResult(result);
    if (next) {
      setPurchaseOrders(next);
      setPurchaseOrderLoadMessage(null);
      setPurchaseOrderCurrentness("current");
      setMutationLocked(false);
    } else {
      setPurchaseOrders(null);
      setPurchaseOrderCurrentness("unavailable");
      setPurchaseOrderLoadMessage(
        result.kind === "backend_error"
          ? result.error.safe_message
          : result.kind === "auth_error" ||
              result.kind === "transport_error" ||
              result.kind === "client_error"
            ? result.diagnostic.safeMessage
            : "Không thể tải danh sách đơn mua.",
      );
    }
    setBusy(false);
    return Boolean(next);
  }, [api, authSubject, correlationId, dateEnd, dateStart]);

  useEffect(() => {
    if (stage === "allocation") void loadAllocation();
    else void loadPurchaseOrders();
    return () => {
      intent.current += 1;
    };
  }, [loadAllocation, loadPurchaseOrders, stage]);

  const visibleRows = useMemo(() => {
    const query = fold(search.trim());
    return (workbench?.rows ?? []).filter((row) => {
      if (
        (stateFilter === "unallocated" && row.state !== "UNALLOCATED") ||
        (stateFilter === "needs_update" &&
          !["STALE_REBALANCE_AVAILABLE", "NEEDS_REALLOCATION"].includes(
            row.state,
          )) ||
        (stateFilter === "blocked" && row.state !== "BLOCKED")
      )
        return false;
      if (!query) return true;
      return fold(
        `${row.school_name ?? ""} ${row.location_name} ${row.ingredient_name} ${row.splits.map((split) => split.supplier_name).join(" ")} ${row.eligible_suppliers.map((supplier) => supplier.supplier_name).join(" ")}`,
      ).includes(query);
    });
  }, [search, stateFilter, workbench]);
  const selectedFamily = workbench?.rows.find(
    (row) => row.family.source_fingerprint === selectedFamilyKey,
  );

  const finishMutation = async (
    result: AtlasRpcResult,
    affectedLabels: string[],
    retry: () => Promise<void>,
    authoritativeReadback: () => Promise<boolean>,
    expectedIntent: number,
  ) => {
    if (expectedIntent !== intent.current) return;
    const outcome = outcomeFromResult(result, affectedLabels);
    setCommandOutcome(outcome);
    if (outcome.classification === "RETRYABLE_FAILURE") {
      setRetryAction(() => retry);
    } else setRetryAction(null);
    if (["STALE", "UNKNOWN_OUTCOME"].includes(outcome.classification)) {
      setMutationLocked(true);
      setBusy(false);
      return;
    }
    if (["SUCCESS", "REPLAY_SUCCESS"].includes(outcome.classification))
      await authoritativeReadback();
    setBusy(false);
  };

  const saveAllocation = async (
    row: AllocationFamilyRow,
    splits: SupplierSplitInput[],
    existingRequest?: ReturnType<typeof saveSupplierAllocationRequest>,
  ) => {
    if (!api || !authSubject || mutationLocked) return;
    const request =
      existingRequest ??
      saveSupplierAllocationRequest(
        authSubject,
        correlationId,
        row.family.version,
        {
          service_date: row.service_date,
          delivery_location_id: row.delivery_location_id,
          ingredient_id: row.ingredient_id,
          unit_id: row.unit_id,
          expected_source_fingerprint: row.family.source_fingerprint,
        },
        splits,
      );
    const mutationIntent = intent.current;
    setBusy(true);
    const result = await api.saveAllocation(request);
    await finishMutation(
      result,
      [row.ingredient_name],
      () => saveAllocation(row, splits, request),
      loadAllocation,
      mutationIntent,
    );
  };

  const confirmRecommendations = async () => {
    if (!api || !authSubject || mutationLocked || !workbench) return;
    const selected = workbench.rows.filter((row) =>
      selectedRecommendationKeys.has(row.family.source_fingerprint),
    );
    if (!selected.length) return;
    const request = confirmSupplierRecommendationsRequest(
      authSubject,
      correlationId,
      selected.map((row) => ({
        service_date: row.service_date,
        delivery_location_id: row.delivery_location_id,
        ingredient_id: row.ingredient_id,
        unit_id: row.unit_id,
        expected_family_version: row.family.version,
        expected_source_fingerprint: row.family.source_fingerprint,
      })),
    );
    const run = async () => {
      const mutationIntent = intent.current;
      setBusy(true);
      const result = await api.confirmRecommendations(request);
      await finishMutation(
        result,
        selected.map((row) => row.ingredient_name),
        run,
        loadAllocation,
        mutationIntent,
      );
      if (result.kind === "success") setSelectedRecommendationKeys(new Set());
    };
    await run();
  };

  const materializePurchaseOrders = async (
    existingRequest?: ReturnType<typeof createPurchaseOrderDraftsRequest>,
  ) => {
    if (!api || !authSubject || mutationLocked) return;
    const request =
      existingRequest ??
      createPurchaseOrderDraftsRequest(
        authSubject,
        correlationId,
        dateStart,
        dateEnd,
      );
    const run = async () => {
      const mutationIntent = intent.current;
      setBusy(true);
      const result = await api.createPurchaseOrderDrafts(request);
      await finishMutation(
        result,
        [`${dateStart} – ${dateEnd}`],
        run,
        loadPurchaseOrders,
        mutationIntent,
      );
    };
    await run();
  };

  const releasePurchaseOrder = async (
    order: SchoolCateringPurchaseOrder,
    existingRequest?: ReturnType<typeof releasePurchaseOrderRequest>,
  ) => {
    if (!api || !authSubject || mutationLocked) return;
    const request =
      existingRequest ??
      releasePurchaseOrderRequest(
        authSubject,
        correlationId,
        order.version,
        order.purchase_order_id,
        order.current_revision.purchase_order_revision_id,
      );
    const run = async () => {
      const mutationIntent = intent.current;
      setBusy(true);
      const result = await api.releasePurchaseOrder(request);
      await finishMutation(
        result,
        [order.supplier.supplier_name],
        run,
        loadPurchaseOrders,
        mutationIntent,
      );
    };
    await run();
  };

  const reloadAuthoritative = () =>
    stage === "allocation" ? loadAllocation() : loadPurchaseOrders();
  const currentness =
    stage === "allocation" ? allocationCurrentness : purchaseOrderCurrentness;

  const changeSchoolScope = (schoolIds: string[]) => {
    intent.current += 1;
    setSelectedFamilyKey(null);
    setSelectedRecommendationKeys(new Set());
    setSelectedSchoolIds(schoolIds);
  };

  return (
    <section className="procurement-workbench" aria-label="Kế hoạch mua hàng">
      <header className="procurement-heading">
        <div>
          <div className="procurement-heading-context">
            <span>Suất ăn học đường</span>
            <span>Kế hoạch mua hàng</span>
          </div>
          <h1>{stage === "allocation" ? "Phân bổ nhà cung ứng" : "Đơn mua"}</h1>
          <p>Phân bổ nhu cầu đã bàn giao và phát hành đơn theo nhà cung cấp.</p>
        </div>
      </header>

      <section
        className="procurement-context-strip"
        aria-label="Phạm vi Procurement"
      >
        <label>
          Từ ngày
          <input
            type="date"
            value={dateStart}
            onChange={(event) => setDateStart(event.target.value)}
          />
        </label>
        <label>
          Đến ngày
          <input
            type="date"
            value={dateEnd}
            onChange={(event) => setDateEnd(event.target.value)}
          />
        </label>
        {stage === "allocation" && (
          <SchoolScopeControl
            schools={schoolCatalogue}
            selectedSchoolIds={selectedSchoolIds}
            onChange={changeSchoolScope}
          />
        )}
        <label className="procurement-search">
          Tìm kiếm
          <input
            type="search"
            value={search}
            placeholder="Trường, điểm giao, nguyên liệu, nhà cung ứng…"
            onChange={(event) => setSearch(event.target.value)}
          />
        </label>
        {stage === "allocation" && (
          <label>
            Ngoại lệ
            <select
              value={stateFilter}
              onChange={(event) =>
                setStateFilter(
                  event.target.value as AllocationPresentationFilter,
                )
              }
            >
              <option value="">Tất cả</option>
              <option value="unallocated">Chưa phân bổ</option>
              <option value="needs_update">Cần cập nhật</option>
              <option value="blocked">Bị chặn</option>
            </select>
          </label>
        )}
        <button
          type="button"
          className="secondary"
          onClick={() => void reloadAuthoritative()}
        >
          Làm mới
        </button>
        <span className={`procurement-currentness ${currentness}`}>
          {currentnessLabels[currentness]}
        </span>
      </section>

      <nav
        className="procurement-stage-selector"
        aria-label="Các bước Procurement"
      >
        <button
          type="button"
          aria-label="Chế độ Phân bổ NCC"
          aria-current={stage === "allocation" ? "page" : undefined}
          onClick={() => setStage("allocation")}
        >
          Phân bổ NCC
        </button>
        <button
          type="button"
          aria-label="Chế độ Đơn mua"
          aria-current={stage === "orders" ? "page" : undefined}
          onClick={() => setStage("orders")}
        >
          Đơn mua
        </button>
      </nav>

      {commandOutcome && (
        <ProcurementCommandResult
          outcome={commandOutcome}
          onReload={() => void reloadAuthoritative()}
          onRetry={retryAction ? () => void retryAction() : undefined}
        />
      )}

      {stage === "allocation" ? (
        <>
          {loadMessage ? (
            <p className="procurement-load-message" role="alert">
              {loadMessage}
            </p>
          ) : workbench && workbench.rows.length === 0 ? (
            <p className="procurement-empty">
              Không có nhu cầu mua trong phạm vi này.
            </p>
          ) : (
            <div
              className={`procurement-allocation-layout${
                selectedFamily ? " has-detail" : ""
              }`}
            >
              <section
                className="procurement-family-master"
                aria-label="Danh sách Allocation Family"
              >
                <div className="procurement-family-actions">
                  <span>{visibleRows.length} nhóm nhu cầu</span>
                  <button
                    type="button"
                    className="secondary procurement-bulk-action"
                    disabled={
                      busy ||
                      mutationLocked ||
                      selectedRecommendationKeys.size === 0
                    }
                    onClick={() => void confirmRecommendations()}
                  >
                    Xác nhận phân bổ đề xuất
                  </button>
                </div>
                <AllocationFamilyTable
                  rows={visibleRows}
                  selectedFamilyKey={selectedFamilyKey}
                  selectedRecommendationKeys={selectedRecommendationKeys}
                  onSelect={(row, trigger) => {
                    allocationTrigger.current = trigger;
                    setSelectedFamilyKey(row.family.source_fingerprint);
                  }}
                  onToggleRecommendation={(row, selected) =>
                    setSelectedRecommendationKeys((current) => {
                      const next = new Set(current);
                      if (selected) next.add(row.family.source_fingerprint);
                      else next.delete(row.family.source_fingerprint);
                      return next;
                    })
                  }
                />
              </section>
              {selectedFamily && (
                <SupplierSplitPanel
                  row={selectedFamily}
                  busy={busy}
                  mutationLocked={mutationLocked}
                  onSave={(splits) =>
                    void saveAllocation(selectedFamily, splits)
                  }
                  onClose={() => {
                    setSelectedFamilyKey(null);
                    allocationTrigger.current?.focus();
                  }}
                />
              )}
            </div>
          )}
        </>
      ) : (
        <PurchaseOrderStage
          data={purchaseOrders}
          busy={busy}
          mutationLocked={mutationLocked}
          loadMessage={purchaseOrderLoadMessage}
          search={search}
          onMaterialize={() => void materializePurchaseOrders()}
          onRelease={(order) => void releasePurchaseOrder(order)}
          onExportXlsx={(order) => void onExportPurchaseOrderXlsx(order)}
          onExportPdf={(order) => void onExportPurchaseOrderPdf(order)}
        />
      )}
    </section>
  );
}
