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
import type {
  AllocationFamilyRow,
  AllocationFamilyState,
  ProcurementCommandOutcome,
  ProcurementStage,
  ProcurementWorkbenchData,
  PurchaseOrdersData,
  SchoolCateringPurchaseOrder,
  SupplierSplitInput,
} from "./schoolCateringProcurementModel";
import { SupplierSplitPanel } from "./SupplierSplitPanel";

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
      blockers: strings(result.response.blockers),
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
        ? "Tải lại dữ liệu có thẩm quyền trước khi thao tác tiếp."
        : null,
  };
}

export function SchoolCateringProcurementWorkbench({
  authState,
  api,
  initialDateStart,
  initialDateEnd,
  initialStage = "allocation",
}: {
  authState: AtlasAuthState;
  api?: SchoolCateringProcurementApi;
  initialDateStart: string;
  initialDateEnd: string;
  initialStage?: ProcurementStage;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [dateStart, setDateStart] = useState(initialDateStart);
  const [dateEnd, setDateEnd] = useState(initialDateEnd);
  const [stage, setStage] = useState<ProcurementStage>(initialStage);
  const [search, setSearch] = useState("");
  const [stateFilter, setStateFilter] = useState<AllocationFamilyState | "">(
    "",
  );
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
    setBusy(true);
    const result = await api.getWorkbench(
      procurementWorkbenchReadRequest(authSubject, correlationId, {
        date_start: dateStart,
        date_end: dateEnd,
        school_ids: [],
        states: [],
        search: null,
      }),
    );
    if (currentIntent !== intent.current) return false;
    const next = procurementWorkbenchFromResult(result);
    if (next) {
      setWorkbench(next);
      setLoadMessage(null);
      setMutationLocked(false);
      setSelectedFamilyKey((current) =>
        next.rows.some((row) => row.family.source_fingerprint === current)
          ? current
          : null,
      );
    } else {
      setWorkbench(null);
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
  }, [api, authSubject, correlationId, dateEnd, dateStart]);

  const loadPurchaseOrders = useCallback(async () => {
    if (!api || !authSubject) return false;
    const currentIntent = ++intent.current;
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
      setMutationLocked(false);
    } else {
      setPurchaseOrders(null);
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
      if (stateFilter && row.state !== stateFilter) return false;
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
  ) => {
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
    setBusy(true);
    const result = await api.saveAllocation(request);
    await finishMutation(
      result,
      [row.ingredient_name],
      () => saveAllocation(row, splits, request),
      loadAllocation,
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
      setBusy(true);
      const result = await api.confirmRecommendations(request);
      await finishMutation(
        result,
        selected.map((row) => row.ingredient_name),
        run,
        loadAllocation,
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
      setBusy(true);
      const result = await api.createPurchaseOrderDrafts(request);
      await finishMutation(
        result,
        [`${dateStart} – ${dateEnd}`],
        run,
        loadPurchaseOrders,
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
      setBusy(true);
      const result = await api.releasePurchaseOrder(request);
      await finishMutation(
        result,
        [order.supplier.supplier_name],
        run,
        loadPurchaseOrders,
      );
    };
    await run();
  };

  const reloadAuthoritative = () =>
    stage === "allocation" ? loadAllocation() : loadPurchaseOrders();

  return (
    <section className="procurement-workbench" aria-label="Kế hoạch mua hàng">
      <header className="procurement-heading">
        <div>
          <span>School catering</span>
          <h1>Kế hoạch mua hàng</h1>
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
        <details>
          <summary>Trường / điểm giao</summary>
          <p>Phạm vi hiện tại theo quyền truy cập.</p>
        </details>
        <label className="procurement-search">
          Tìm kiếm
          <input
            type="search"
            value={search}
            placeholder="Trường, điểm giao, nguyên liệu, nhà cung ứng…"
            onChange={(event) => setSearch(event.target.value)}
          />
        </label>
        <label>
          Ngoại lệ
          <select
            value={stateFilter}
            onChange={(event) =>
              setStateFilter(event.target.value as AllocationFamilyState | "")
            }
          >
            <option value="">Tất cả</option>
            <option value="UNALLOCATED">Chưa phân bổ</option>
            <option value="BLOCKED">Chưa đủ / lệch</option>
            <option value="BALANCED">Đã đủ</option>
            <option value="NEEDS_REALLOCATION">Cần phân bổ lại</option>
            <option value="STALE_REBALANCE_AVAILABLE">NCC không phù hợp</option>
          </select>
        </label>
        <button
          type="button"
          className="secondary"
          onClick={() => void reloadAuthoritative()}
        >
          Làm mới
        </button>
        <span className="procurement-currentness">
          {busy ? "Đang cập nhật…" : "Dữ liệu hiện tại"}
        </span>
      </section>

      <nav
        className="procurement-stage-selector"
        aria-label="Các bước Procurement"
      >
        <button
          type="button"
          aria-current={stage === "allocation" ? "page" : undefined}
          onClick={() => setStage("allocation")}
        >
          Phân bổ nhà cung ứng
        </button>
        <button
          type="button"
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
            <div className="procurement-allocation-layout">
              <section
                className="procurement-family-master"
                aria-label="Danh sách Allocation Family"
              >
                <div className="procurement-family-actions">
                  <span>{visibleRows.length} Allocation Family</span>
                  <button
                    type="button"
                    className="primary procurement-primary-action"
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
                  onSelect={(row) =>
                    setSelectedFamilyKey(row.family.source_fingerprint)
                  }
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
        />
      )}
    </section>
  );
}
