import { useCallback, useEffect, useRef, useState } from "react";
import {
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
export type ProcurementControllerProps = {
  authSubject: string | null;
  purchaseReviewApi: PurchaseReviewApi;
  procurementApi: SchoolCateringProcurementApi;
  initialServiceDate: string;
  initialStage?: ProcurementStage;
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
      message: procurementOperatorMessage(result.error.safe_message, fallback),
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
  initialStage = "allocation",
}: ProcurementControllerProps) {
  const [date, setDate] = useState(initialServiceDate);
  const [schoolIds, setSchoolIds] = useState<string[]>([]);
  const [stage, setStage] = useState<ProcurementStage>(initialStage);
  const [allocation, setAllocation] =
    useState<ConfirmedAllocationWorkbench | null>(null);
  const [orders, setOrders] = useState<PurchaseOrdersData | null>(null);
  const [current, setCurrent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [mutationLocked, setMutationLocked] = useState(false);
  const [feedback, setFeedback] = useState<ProcurementFeedback | null>(null);
  const [readError, setReadError] = useState<string | null>(null);
  const [revision, setRevision] = useState(0);
  const [hasRetry, setHasRetry] = useState(false);
  const correlation = useRef(crypto.randomUUID());
  const generation = useRef(0);
  const active = useRef(false);
  const retryCommand = useRef<(() => Promise<void>) | null>(null);
  const recoveryStage = useRef<ProcurementStage | null>(null);
  const skipPreparedStageRead = useRef(false);

  const clearRetry = () => {
    retryCommand.current = null;
    setHasRetry(false);
  };
  const read = useCallback(
    async (target: ProcurementStage): Promise<boolean | null> => {
      const ticket = ++generation.current;
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
                      date_end: date,
                      school_ids: schoolIds,
                      states: [],
                      search: null,
                    },
                  ),
                )
              : await procurementApi.getPurchaseOrders(
                  purchaseOrdersReadRequest(authSubject, correlation.current, {
                    date_start: date,
                    date_end: date,
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
        Array.isArray(rawOrders.purchase_orders)
          ? rawOrders
          : null;
      const ok =
        target === "allocation" ? Boolean(nextAllocation) : Boolean(nextOrders);
      if (target === "allocation") setAllocation(nextAllocation);
      else setOrders(nextOrders);
      setCurrent(ok);
      setLoading(false);
      setBusy(false);
      active.current = false;
      if (ok) {
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
    [authSubject, purchaseReviewApi, procurementApi, date, schoolIds],
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
    setCurrent(false);
    setAllocation(null);
    setOrders(null);
    setFeedback(null);
    setReadError(null);
    setBusy(false);
    setMutationLocked(true);
  };
  const changeDate = (value: string) => {
    if (value !== date) {
      invalidate();
      setDate(value);
    }
  };
  const changeSchools = (ids: string[]) => {
    if (ids.join("|") !== schoolIds.join("|")) {
      invalidate();
      setSchoolIds(ids);
    }
  };
  const changeStage = (value: ProcurementStage) => {
    if (value !== stage) {
      invalidate();
      setStage(value);
    }
  };
  const enterOrdersAfterRead = () => {
    recoveryStage.current = null;
    if (stage !== "orders") {
      skipPreparedStageRead.current = true;
      setStage("orders");
    }
  };
  const reload = async () => {
    if (active.current) return;
    clearRetry();
    const target = recoveryStage.current ?? stage;
    const ok = await read(target);
    if (ok) {
      setFeedback(null);
      if (target === "orders" && recoveryStage.current) enterOrdersAfterRead();
    }
  };

  const locked = !current || mutationLocked || hasRetry;
  const canStart = () =>
    Boolean(authSubject && current && !locked && !active.current);
  const runCommand = async (
    invoke: () => Promise<AtlasRpcResult>,
    target: ProcurementStage,
    preparation = false,
  ) => {
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
    if (ticket !== generation.current) return;
    const nextFeedback = feedbackFromResult(result);
    setFeedback(nextFeedback);
    if (preparation && ["success", "unknown"].includes(nextFeedback.kind))
      recoveryStage.current = "orders";
    if (nextFeedback.kind === "success") {
      const ok = await read(target);
      if (ok === null) return;
      if (!ok) {
        setFeedback(uncertain());
        setMutationLocked(true);
      } else if (preparation) enterOrdersAfterRead();
      return;
    }
    if (["stale", "unknown"].includes(nextFeedback.kind))
      setMutationLocked(true);
    if (nextFeedback.kind === "retryable") {
      // This closure retains the exact request built before the first attempt.
      retryCommand.current = async () => {
        if (generation.current === ticket && !active.current)
          await runCommand(invoke, target, preparation);
      };
      setHasRetry(true);
    }
    active.current = false;
    setBusy(false);
  };

  const save = async (
    candidate: AllocationFamilyRow,
    splits: SupplierSplitInput[],
  ) => {
    if (!canStart() || stage !== "allocation") return;
    const row = allocation?.rows.find(
      (item) =>
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
      await runCommand(
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
      await runCommand(
        () => procurementApi.saveAllocation(request),
        "allocation",
      );
    }
  };
  const prepare = async (editing: boolean) => {
    const source = allocation?.preparation;
    if (
      !canStart() ||
      stage !== "allocation" ||
      editing ||
      !source?.ready ||
      !source.allowed
    )
      return;
    const request = preparePurchaseOrdersRequest(
      authSubject!,
      correlation.current,
      source,
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
    if (
      order.status === "DRAFT" &&
      order.commitment_state === "DRAFT_CURRENT" &&
      !order.stale &&
      order.release_eligible &&
      order.allowed_actions.release
    ) {
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
        date,
        date,
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
  const retry = async () => {
    await retryCommand.current?.();
  };
  return {
    date,
    schoolIds,
    stage,
    allocation,
    orders,
    current,
    loading,
    busy,
    locked,
    feedback,
    readError,
    revision,
    hasRetry,
    changeDate,
    changeSchools,
    changeStage,
    reload,
    save,
    prepare,
    orderAction,
    retry,
  };
}
