import { useCallback, useEffect, useRef, useState } from "react";
import { useAtlasAuthorityFreshness } from "../AtlasModuleExit";
import {
  operatorDateRangeError,
  type AtlasOperatorDateRange,
} from "../atlasOperatorDateRange";
import {
  canReleasePurchaseOrder,
  confirmedAllocationFromResult,
  confirmedAllocationReadRequest,
  confirmedAllocationRequest,
  createPurchaseOrderDraftsRequest,
  createPurchaseOrderReplacementRequest,
  preparePurchaseOrdersRequest,
  procurementOperatorMessage,
  procurementOperatorMessages,
  purchaseOrderDraftReadinessMessages,
  purchaseOrdersFromResult,
  purchaseOrdersReadRequest,
  releasePurchaseOrderRequest,
  saveSupplierAllocationRequest,
  type AllocationFamilyRow,
  type AtlasRpcResult,
  type ConfirmedAllocationWorkbench,
  type ProcurementStage,
  type PurchaseOrdersData,
  type PurchaseReviewApi,
  type SchoolCateringProcurementApi,
  type SchoolCateringPurchaseOrder,
  type SupplierSplitInput,
} from "../bridges/procurement";
import {
  parseExactQuantity,
  sumExactQuantities,
} from "./procurementExactQuantity";

export type ProcurementFeedback = {
  kind: "success" | "blocked" | "stale" | "unknown" | "retryable";
  message: string;
  messages: string[];
};
type DayPreparation = {
  date: string;
  ticket: number;
  loading: boolean;
  source: ConfirmedAllocationWorkbench["preparation"];
  message: string | null;
};

function readyForPreparation(
  source: ConfirmedAllocationWorkbench["preparation"] | undefined,
  date: string,
) {
  return Boolean(
    source?.service_date === date &&
    source.ready === true &&
    source.allowed === true &&
    source.blockers?.length === 0 &&
    source.confirmed_need_batch_id &&
    Number.isInteger(source.expected_version) &&
    source.expected_version > 0,
  );
}
export type ProcurementControllerProps = {
  authSubject: string | null;
  purchaseReviewApi: PurchaseReviewApi;
  procurementApi: SchoolCateringProcurementApi;
  initialServiceDate: string;
  initialRange?: AtlasOperatorDateRange;
  initialSchoolIds?: string[];
  onServiceDateChange?: (date: string) => void;
  initialStage?: ProcurementStage;
  ownerStage?: ProcurementStage;
  onOpenOrders?: (scope: string | AtlasOperatorDateRange) => void;
  onCommitted?: () => void;
  freshnessRevision?: number;
};
const uncertain = (): ProcurementFeedback => ({
  kind: "unknown",
  message: "Chưa xác nhận kết quả. Hãy tải lại dữ liệu trước khi tiếp tục.",
  messages: [],
});
const fallback = "Chưa thể tiếp tục; hãy kiểm tra dữ liệu hiện tại.";
function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}
function feedbackFromResult(result: AtlasRpcResult): ProcurementFeedback {
  if (result.kind === "success")
    return {
      kind: "success",
      message: procurementOperatorMessage(
        result.response.safe_operator_message ?? "Đã hoàn tất thao tác.",
        fallback,
      ),
      messages: procurementOperatorMessages(
        [
          ...stringList(result.response.warnings),
          ...stringList(result.response.blockers),
          ...purchaseOrderDraftReadinessMessages(result.response.skipped_dates),
        ],
        fallback,
      ),
    };
  if (result.kind === "backend_error")
    return {
      kind: ["STALE_VERSION", "SOURCE_CHANGED", "PO_DRAFT_STALE"].includes(
        result.error.error_code,
      )
        ? "stale"
        : result.error.retryable
          ? "retryable"
          : "blocked",
      message: procurementOperatorMessage(
        result.error.error_code === "PREPARATION_BLOCKED"
          ? result.error.error_code
          : result.error.safe_message,
        fallback,
      ),
      messages: [],
    };
  return result.kind === "transport_error"
    ? uncertain()
    : {
        kind: "blocked",
        message: procurementOperatorMessage(
          result.diagnostic.safeMessage,
          fallback,
        ),
        messages: [],
      };
}

export function useProcurementWorkbench({
  authSubject,
  purchaseReviewApi,
  procurementApi,
  initialServiceDate,
  initialRange,
  initialSchoolIds,
  onServiceDateChange,
  initialStage = "allocation",
  ownerStage,
  onOpenOrders,
  onCommitted,
  freshnessRevision,
}: ProcurementControllerProps) {
  const freshness = useAtlasAuthorityFreshness(freshnessRevision);
  const fixedStage = useRef(ownerStage).current;
  const initialScope = initialRange ?? {
    start: initialServiceDate,
    end: initialServiceDate,
  };
  const [date, setDate] = useState(initialScope.start);
  const [dateEnd, setDateEnd] = useState(initialScope.end);
  const [range, setRange] = useState<AtlasOperatorDateRange>(initialScope);
  const rangeError = operatorDateRangeError(range);
  useEffect(() => {
    onServiceDateChange?.(date);
  }, [date, onServiceDateChange]);
  const [schoolIds, setSchoolIds] = useState<string[]>(initialSchoolIds ?? []);
  const [scopeRefresh, setScopeRefresh] = useState(0);
  const [stage, setStage] = useState<ProcurementStage>(
    fixedStage ?? initialStage,
  );
  const [allocation, setAllocation] =
    useState<ConfirmedAllocationWorkbench | null>(null);
  const [orders, setOrders] = useState<PurchaseOrdersData | null>(null);
  const ordersAuthority = useRef<PurchaseOrdersData | null>(null);
  const [current, setCurrent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [bulkProgress, setBulkProgress] = useState<{
    completed: number;
    total: number;
  } | null>(null);
  const bulkActive = useRef(false);
  const [mutationLocked, setMutationLocked] = useState(false);
  const [feedback, setFeedback] = useState<ProcurementFeedback | null>(null);
  const [readError, setReadError] = useState<string | null>(null);
  const [revision, setRevision] = useState(0);
  const [hasRetry, setHasRetry] = useState(false);
  const correlation = useRef(crypto.randomUUID());
  const generation = useRef(0);
  const active = useRef(false);
  const retryCommand = useRef<(() => Promise<boolean | undefined>) | null>(
    null,
  );
  const recoveryStage = useRef<ProcurementStage | null>(null);
  const preparedDay = useRef<string | null>(null);
  const returnAllocationRange = useRef<AtlasOperatorDateRange | null>(null);
  const [dayPreparation, setDayPreparation] = useState<DayPreparation | null>(
    null,
  );
  const dayRequest = useRef(0);
  const recoveryInvalidation = useRef(false);
  const skipPreparedStageRead = useRef(false);

  const clearRetry = () => {
    retryCommand.current = null;
    setHasRetry(false);
  };
  const read = useCallback(
    async (
      target: ProcurementStage,
      orderDate?: string | null,
    ): Promise<boolean | null> => {
      if (operatorDateRangeError({ start: date, end: dateEnd })) return false;
      const readRevision = freshness.capture();
      const ticket = ++generation.current;
      dayRequest.current += 1;
      setDayPreparation(null);
      active.current = true;
      setCurrent(false);
      setLoading(true);
      setReadError(null);
      let result: AtlasRpcResult | null = null;
      try {
        if (authSubject)
          result =
            target === "allocation"
              ? await purchaseReviewApi.getConfirmedAllocations(
                  confirmedAllocationReadRequest(
                    authSubject,
                    correlation.current,
                    {
                      date_start: date,
                      date_end: dateEnd,
                      school_ids: schoolIds,
                      states: [],
                      search: null,
                    },
                  ),
                )
              : await procurementApi.getPurchaseOrders(
                  purchaseOrdersReadRequest(authSubject, correlation.current, {
                    date_start: orderDate ?? date,
                    date_end: orderDate ?? dateEnd,
                    supplier_ids: [],
                    statuses: [],
                    search: null,
                  }),
                );
      } catch {
        /* Read failure means unavailable authority, never a write retry. */
      }
      if (ticket !== generation.current) return null;
      const nextAllocation =
        target === "allocation" && result
          ? confirmedAllocationFromResult(result)
          : null;
      const rawOrders =
        target === "orders" && result ? purchaseOrdersFromResult(result) : null;
      const nextOrders =
        rawOrders?.contract_version === "SCHOOL-CATERING-PROCUREMENT.v1" &&
        Array.isArray(rawOrders.purchase_orders) &&
        (!orderDate ||
          (rawOrders.date_start === orderDate &&
            rawOrders.date_end === orderDate))
          ? rawOrders
          : null;
      const ok =
        target === "allocation" ? Boolean(nextAllocation) : Boolean(nextOrders);
      if (target === "allocation") setAllocation(nextAllocation);
      else {
        ordersAuthority.current = nextOrders;
        setOrders(nextOrders);
      }
      setCurrent(ok);
      setLoading(false);
      setBusy(false);
      active.current = false;
      if (ok) {
        freshness.acknowledge(readRevision);
        setMutationLocked(false);
        setRevision((value) => value + 1);
      } else {
        setMutationLocked(true);
        setReadError(
          result && result.kind !== "success"
            ? feedbackFromResult(result).message
            : "Chưa tải được dữ liệu hiện tại. Hãy tải lại để tiếp tục.",
        );
      }
      return ok;
    },
    [
      authSubject,
      purchaseReviewApi,
      procurementApi,
      date,
      dateEnd,
      schoolIds,
      scopeRefresh,
    ],
  );

  useEffect(() => {
    if (skipPreparedStageRead.current) skipPreparedStageRead.current = false;
    else {
      clearRetry();
      setFeedback(null);
      void read(stage);
    }
    return () => {
      generation.current += 1;
    };
  }, [read, stage]);

  const invalidate = () => {
    generation.current += 1;
    active.current = false;
    clearRetry();
    recoveryStage.current = null;
    preparedDay.current = null;
    setDayPreparation(null);
    dayRequest.current += 1;
    setCurrent(false);
    setAllocation(null);
    setOrders(null);
    ordersAuthority.current = null;
    setFeedback(null);
    setReadError(null);
    setBusy(false);
    setMutationLocked(true);
  };
  const changeRange = (value: AtlasOperatorDateRange) => {
    if (busy || bulkActive.current) return;
    setRange(value);
    if (operatorDateRangeError(value)) return;
    if (value.start !== date || value.end !== dateEnd) {
      invalidate();
      setDate(value.start);
      setDateEnd(value.end);
    }
  };
  const changeDate = (value: string) =>
    changeRange({ start: value, end: value });
  const applyNeedScope = (value: AtlasOperatorDateRange, ids: string[]) => {
    if (
      bulkActive.current ||
      busy ||
      loading ||
      mutationLocked ||
      !current ||
      hasRetry ||
      operatorDateRangeError(value)
    )
      return;
    invalidate();
    setRange(value);
    setDate(value.start);
    setDateEnd(value.end);
    setSchoolIds([...new Set(ids)]);
    setScopeRefresh((value) => value + 1);
  };
  const changeSchools = (ids: string[]) => {
    if (rangeError || busy || bulkActive.current) return;
    if (ids.join("|") !== schoolIds.join("|")) {
      invalidate();
      setSchoolIds(ids);
    }
  };
  const changeStage = (value: ProcurementStage) => {
    if (bulkActive.current) return;
    if (!fixedStage && value !== stage) {
      invalidate();
      if (value === "allocation" && returnAllocationRange.current) {
        const prior = returnAllocationRange.current;
        setDate(prior.start);
        setDateEnd(prior.end);
        setRange(prior);
        returnAllocationRange.current = null;
      }
      setStage(value);
    }
  };
  const enterOrdersAfterRead = async (readStage: ProcurementStage) => {
    const targetDate = preparedDay.current ?? date;
    if (fixedStage === "allocation") {
      // Orders proof cannot make the retained Allocation snapshot current.
      recoveryStage.current = "allocation";
      if (readStage !== "allocation" && !(await read("allocation"))) return;
      recoveryStage.current = null;
      preparedDay.current = null;
      onOpenOrders?.(targetDate);
      return;
    }
    recoveryStage.current = null;
    if (stage !== "orders") {
      if (targetDate !== date || targetDate !== dateEnd) {
        returnAllocationRange.current = { start: date, end: dateEnd };
        setDate(targetDate);
        setDateEnd(targetDate);
        setRange({ start: targetDate, end: targetDate });
      }
      preparedDay.current = null;
      skipPreparedStageRead.current = true;
      setStage("orders");
    }
  };
  const reload = async () => {
    if (active.current || bulkActive.current || rangeError) return;
    clearRetry();
    const target = recoveryStage.current ?? stage;
    const ok = await read(
      target,
      target === "orders" ? preparedDay.current : null,
    );
    if (ok) {
      if (recoveryInvalidation.current) {
        recoveryInvalidation.current = false;
        onCommitted?.();
      }
      setFeedback(null);
      if (recoveryStage.current) await enterOrdersAfterRead(target);
    }
  };

  const locked = !current || mutationLocked || hasRetry;
  const canStart = () =>
    Boolean(
      authSubject &&
      current &&
      !freshness.stale &&
      !locked &&
      !active.current &&
      !bulkActive.current &&
      !rangeError,
    );
  const runCommand = async (
    invoke: () => Promise<AtlasRpcResult>,
    target: ProcurementStage,
    preparation = false,
  ): Promise<boolean> => {
    const ticket = generation.current;
    active.current = true;
    setBusy(true);
    clearRetry();
    setFeedback(null);
    let result: AtlasRpcResult;
    try {
      result = await invoke();
    } catch {
      result = {
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Chưa xác nhận kết quả.",
        },
      };
    }
    if (result.kind === "success") onCommitted?.();
    if (ticket !== generation.current) return false;
    const nextFeedback = feedbackFromResult(result);
    recoveryInvalidation.current = nextFeedback.kind === "unknown";
    setFeedback(nextFeedback);
    if (preparation && ["success", "unknown"].includes(nextFeedback.kind))
      recoveryStage.current = "orders";
    if (nextFeedback.kind === "success") {
      const ok = await read(target, preparation ? preparedDay.current : null);
      if (ok === null) return false;
      if (!ok) {
        setFeedback(uncertain());
        setMutationLocked(true);
      } else if (preparation) await enterOrdersAfterRead(target);
      return ok === true;
    }
    if (["stale", "unknown"].includes(nextFeedback.kind))
      setMutationLocked(true);
    if (nextFeedback.kind === "retryable") {
      // This closure retains the exact request built before the first attempt.
      retryCommand.current = async () => {
        if (generation.current === ticket && !active.current)
          return runCommand(invoke, target, preparation);
      };
      setHasRetry(true);
    }
    active.current = false;
    setBusy(false);
    return false;
  };

  const save = async (
    candidate: AllocationFamilyRow,
    splits: SupplierSplitInput[],
  ) => {
    if (!canStart() || stage !== "allocation") return;
    const row = allocation?.rows.find(
      (item) =>
        item.service_date === candidate.service_date &&
        item.delivery_location_id === candidate.delivery_location_id &&
        item.ingredient_id === candidate.ingredient_id &&
        item.unit_id === candidate.unit_id &&
        item.family.source_fingerprint ===
          candidate.family.source_fingerprint &&
        item.family.version === candidate.family.version,
    );
    if (
      !row ||
      !row.allowed_actions.save_allocation ||
      row.complete === false ||
      row.family_quantity === null
    )
      return;
    if (
      !splits.length ||
      new Set(splits.map((split) => split.supplier_id)).size !==
        splits.length ||
      splits.some(
        (split) =>
          !row.eligible_suppliers.some(
            (supplier) => supplier.supplier_id === split.supplier_id,
          ) || (parseExactQuantity(split.allocated_quantity) ?? 0n) <= 0n,
      ) ||
      sumExactQuantities(splits.map((split) => split.allocated_quantity)) !==
        parseExactQuantity(row.family_quantity)
    )
      return;
    const family = {
      service_date: row.service_date,
      delivery_location_id: row.delivery_location_id,
      ingredient_id: row.ingredient_id,
      unit_id: row.unit_id,
      expected_source_fingerprint: row.family.source_fingerprint,
    };
    if (row.family.source_kind === "CONFIRMED_NEED") {
      if (
        !row.family.source_confirmed_need_batch_id ||
        !row.family.source_confirmed_need_batch_version
      )
        return;
      const request = confirmedAllocationRequest(
        authSubject!,
        correlation.current,
        row.family.version,
        {
          ...family,
          expected_source_batch_id: row.family.source_confirmed_need_batch_id,
          expected_source_batch_version:
            row.family.source_confirmed_need_batch_version,
        },
        splits,
      );
      return runCommand(
        () => purchaseReviewApi.saveConfirmedAllocation(request),
        "allocation",
      );
    } else {
      const request = saveSupplierAllocationRequest(
        authSubject!,
        correlation.current,
        row.family.version,
        family,
        splits,
      );
      return runCommand(
        () => procurementApi.saveAllocation(request),
        "allocation",
      );
    }
  };
  const checkPreparationDay = async (targetDate: string, editing: boolean) => {
    if (
      !canStart() ||
      stage !== "allocation" ||
      editing ||
      date === dateEnd ||
      operatorDateRangeError({ start: targetDate, end: targetDate }) ||
      targetDate < date ||
      targetDate > dateEnd
    )
      return;
    const ticket = ++dayRequest.current;
    const scopeTicket = generation.current;
    const readRevision = freshness.capture();
    const check = {
      date: targetDate,
      ticket,
      loading: true,
      source: null,
      message: null,
    };
    setDayPreparation(check);
    let result: AtlasRpcResult | null = null;
    try {
      result = await purchaseReviewApi.getConfirmedAllocations(
        confirmedAllocationReadRequest(authSubject!, correlation.current, {
          date_start: targetDate,
          date_end: targetDate,
          // Preparation covers the whole day even if the weekly table shows one school.
          school_ids: [],
          states: [],
          search: null,
        }),
      );
    } catch {
      // This read made no change. Staff can check the day again.
    }
    if (
      ticket !== dayRequest.current ||
      scopeTicket !== generation.current ||
      freshness.capture() !== readRevision
    )
      return;
    const response = result && confirmedAllocationFromResult(result);
    const day =
      response?.date_start === targetDate && response.date_end === targetDate
        ? response
        : null;
    // The backend can return just ready/allowed/blockers when the day has no single authorized batch.
    const source = day?.preparation ?? null;
    const blockers = [...(day?.blockers ?? []), ...(source?.blockers ?? [])];
    const messages = procurementOperatorMessages(
      blockers,
      "Kiểm tra phân bổ trước khi chuẩn bị đơn mua.",
    );
    let message = messages.length ? messages.join(" ") : null;
    if (!day)
      message =
        result?.kind === "backend_error"
          ? feedbackFromResult(result).message
          : "Chưa tải được phân bổ của ngày này. Hãy kiểm tra lại.";
    else if (!message && !readyForPreparation(source, targetDate))
      message =
        source?.ready && !source.allowed
          ? "Bạn chưa có quyền chuẩn bị đơn mua cho ngày này."
          : "Chưa đủ dữ liệu để chuẩn bị đơn mua cho ngày này.";
    setDayPreparation({
      ...check,
      loading: false,
      source: message ? null : source,
      message,
    });
  };
  const preparationDate = date === dateEnd ? date : dayPreparation?.date;
  const preparationSource =
    date === dateEnd ? allocation?.preparation : dayPreparation?.source;
  const canPrepare = Boolean(
    preparationDate &&
    readyForPreparation(preparationSource, preparationDate) &&
    (date !== dateEnd || !allocation?.blockers.length),
  );
  const prepare = async (editing: boolean) => {
    if (
      !canStart() ||
      stage !== "allocation" ||
      editing ||
      !canPrepare ||
      !preparationSource ||
      (date !== dateEnd && dayPreparation?.ticket !== dayRequest.current)
    )
      return;
    preparedDay.current = preparationSource.service_date;
    const request = preparePurchaseOrdersRequest(
      authSubject!,
      correlation.current,
      preparationSource,
    );
    await runCommand(
      () => purchaseReviewApi.preparePurchaseOrders(request),
      "orders",
      true,
    );
  };
  const orderAction = async (candidate: SchoolCateringPurchaseOrder) => {
    if (!canStart() || stage !== "orders") return;
    const order = orders?.purchase_orders.find(
      (item) =>
        item.purchase_order_id === candidate.purchase_order_id &&
        item.version === candidate.version &&
        item.current_revision.purchase_order_revision_id ===
          candidate.current_revision.purchase_order_revision_id,
    );
    if (!order) return;
    if (canReleasePurchaseOrder(order)) {
      const request = releasePurchaseOrderRequest(
        authSubject!,
        correlation.current,
        order.version,
        order.purchase_order_id,
        order.current_revision.purchase_order_revision_id,
      );
      await runCommand(
        () => procurementApi.releasePurchaseOrder(request),
        "orders",
      );
    } else if (
      order.status === "DRAFT" &&
      order.commitment_state === "DRAFT_STALE"
    ) {
      const request = createPurchaseOrderDraftsRequest(
        authSubject!,
        correlation.current,
        order.service_date,
        order.service_date,
      );
      await runCommand(
        () => procurementApi.createPurchaseOrderDrafts(request),
        "orders",
      );
    } else if (
      order.status === "RELEASED_TO_SUPPLIER" &&
      order.commitment_state === "REPLACEMENT_REQUIRED" &&
      order.allowed_actions.create_replacement
    ) {
      const request = createPurchaseOrderReplacementRequest(
        authSubject!,
        correlation.current,
        order.version,
        order.purchase_order_id,
        order.current_revision.purchase_order_revision_id,
      );
      await runCommand(
        () => procurementApi.createPurchaseOrderReplacement(request),
        "orders",
      );
    }
  };
  const releaseAllOrders = async (reviewed: SchoolCateringPurchaseOrder[]) => {
    if (!canStart() || stage !== "orders") return;
    const eligible = reviewed.filter(canReleasePurchaseOrder).map((order) => ({
      id: order.purchase_order_id,
      version: order.version,
      revision: order.current_revision.purchase_order_revision_id,
    }));
    if (!eligible.length) return;
    bulkActive.current = true;
    let completed = 0;
    setBulkProgress({ completed, total: eligible.length });
    try {
      for (const order of eligible) {
        const latest = ordersAuthority.current?.purchase_orders.find(
          (item) => item.purchase_order_id === order.id,
        );
        if (
          !latest ||
          !canReleasePurchaseOrder(latest) ||
          latest.version !== order.version ||
          latest.current_revision.purchase_order_revision_id !== order.revision
        ) {
          setMutationLocked(true);
          setFeedback({
            kind: "stale",
            message: `Đã phát hành ${completed}/${eligible.length} đơn mua. Đơn tiếp theo đã thay đổi. Hãy tải lại và kiểm tra trước khi tiếp tục.`,
            messages: [],
          });
          return;
        }
        const request = releasePurchaseOrderRequest(
          authSubject!,
          correlation.current,
          order.version,
          order.id,
          order.revision,
        );
        const ok = await runCommand(
          () => procurementApi.releasePurchaseOrder(request),
          "orders",
        );
        if (!ok) {
          setFeedback(
            (previous) =>
              previous && {
                ...previous,
                messages: [
                  `Đã xác nhận phát hành ${completed}/${eligible.length} PO. Đã dừng; kiểm tra kết quả trước khi tiếp tục.`,
                  ...previous.messages,
                ],
              },
          );
          return;
        }
        completed += 1;
        setBulkProgress({ completed, total: eligible.length });
      }
      setFeedback({
        kind: "success",
        message: `Đã phát hành ${completed}/${eligible.length} PO.`,
        messages: [],
      });
    } finally {
      bulkActive.current = false;
      setBulkProgress(null);
    }
  };
  const retry = async () => {
    if (rangeError) return;
    return retryCommand.current?.();
  };
  const openOrders = () => {
    if (busy || rangeError) return;
    if (fixedStage === "allocation")
      onOpenOrders?.({ start: date, end: dateEnd });
    else changeStage("orders");
  };
  return {
    date,
    dateEnd,
    range,
    rangeError,
    changeRange,
    applyNeedScope,
    schoolIds,
    stage,
    allocation,
    orders,
    current,
    freshness,
    stale: freshness.stale,
    loading,
    busy: busy || bulkProgress !== null,
    bulkProgress,
    locked,
    feedback,
    readError,
    revision,
    hasRetry,
    changeDate,
    changeSchools,
    changeStage,
    openOrders,
    reload,
    save,
    checkPreparationDay,
    dayPreparation,
    canPrepare,
    prepare,
    orderAction,
    releaseAllOrders,
    retry,
  };
}
