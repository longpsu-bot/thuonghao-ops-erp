import {
  operatorDateRangeError,
  type AtlasOperatorDateRange,
} from "../atlasOperatorDateRange";
import type { AtlasOperation } from "../AtlasOperationStatus";
import type { AtlasModuleExitProps } from "../AtlasModuleExit";
import { useConfirmedNeedDraft } from "./useConfirmedNeedDraft";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  confirmedNeedCorrectionPreviewRequest,
  confirmedNeedCorrectionCommandRequest,
  confirmedNeedCorrectionPreviewFromResult,
  confirmedNeedCorrectionOutcome,
  type ConfirmedNeedCorrectionPayload,
  type ConfirmedNeedCorrectionCommandRequest,
  type ConfirmedNeedCorrectionPreview,
  confirmedNeedReadbackFromResult,
  confirmedNeedResultHasUnknownWriteOutcome,
  confirmedNeedResultIsStale,
  confirmedNeedResultMessage,
  confirmedNeedResultRequiresEligibilityRefresh,
  confirmedNeedSaveV2Request,
  loadCompleteConfirmedNeedReview,
  shoppingListRangeDates,
  initialConfirmedNeedDraft,
  type ShoppingListRangeContext,
  needGenerationContinuitySummaryFromResult,
  needGenerationExecutionRequest,
  needGenerationReadbackFromResult,
  needGenerationResultIsStale,
  needGenerationResultMessage,
  planningInputPreflightFromResult,
  type AtlasRpcResult,
  type ConfirmedNeedApi,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
  type NeedGenerationApi,
  type PlanningInputPreflightData,
  type PreflightApi,
} from "../bridges/confirmedNeed";
import {
  correctionBlocked,
  mondayOf,
  noDemand,
  generatedNoDemand,
  validBatch,
  validPreflight,
} from "./confirmedNeedAuthority";
import { draftLineRequest, historicalQuantity } from "./confirmedNeedDraft";
import type { ConfirmedNeedShoppingListImport } from "../bridges/confirmedNeed";
export type ConfirmedNeedWorkbenchProps = AtlasModuleExitProps & {
  authSubject: string | null;
  initialServiceDate: string;
  onServiceDateChange?: (date: string) => void;
  preflightApi: PreflightApi;
  needGenerationApi: NeedGenerationApi;
  confirmedNeedApi: ConfirmedNeedApi;
  onContinueAllocation?: (range: AtlasOperatorDateRange) => void;
  onExportShoppingList?: (
    workbench: ConfirmedNeedWorkbenchData,
    context?: ShoppingListRangeContext,
  ) => Promise<void>;
  onImportShoppingList?: (
    file: File,
    workbench: ConfirmedNeedWorkbenchData,
    drafts: Record<string, ConfirmedNeedDraftLine>,
    context?: ShoppingListRangeContext,
  ) => Promise<ConfirmedNeedShoppingListImport>;
};
type Transition = {
  range?: AtlasOperatorDateRange;
  exit?: () => void;
  date?: string;
  week?: string;
  schoolIds?: string[];
  refresh?: boolean;
  closeCorrection?: boolean;
  selectDay?: string;
};
type Correction = {
  target: ConfirmedNeedCorrectionPayload;
  quantity: string;
  reason_code: ConfirmedNeedDraftLine["reason_code"];
  reason_note: string;
  status:
    | "EDITING"
    | "PREVIEWING"
    | "SAVING"
    | "UNKNOWN"
    | "RETRYABLE"
    | "READBACK"
    | "STALE";
  preview: ConfirmedNeedCorrectionPreview | null;
  error: string | null;
};
type Lock = "unknown" | "stale" | "eligibility" | null;
const readFailure = "Không thể tải dữ liệu hiện tại. Hãy thử tải lại.";
export function useConfirmedNeedWorkbench({
  authSubject,
  initialServiceDate,
  onServiceDateChange,
  preflightApi,
  needGenerationApi,
  confirmedNeedApi,
  onContinueAllocation,
}: ConfirmedNeedWorkbenchProps) {
  const [date, setDate] = useState(initialServiceDate);
  const [range, setRange] = useState<AtlasOperatorDateRange>({
    start: initialServiceDate,
    end: initialServiceDate,
  });
  const [rangeError, setRangeError] = useState<string | null>(null);
  const invalidRange = useRef<string | null>(null);
  invalidRange.current = rangeError;
  const [rangeBusy, setRangeBusy] = useState(false);
  const [, updateDays] = useState(0);
  type Day = {
    preflight: PlanningInputPreflightData | null;
    workbench: ConfirmedNeedWorkbenchData | null;
    drafts: Record<string, ConfirmedNeedDraftLine>;
    dirty: boolean;
    lock: Lock;
    readError: string | null;
  };
  const days = useRef<Record<string, Day>>({});
  const loadedDate = useRef<string | null>(null);
  const rangeEpoch = useRef(0);
  const dates = shoppingListRangeDates(range);

  useEffect(() => {
    onServiceDateChange?.(date);
  }, [date, onServiceDateChange]);
  const week = mondayOf(date);
  const [schoolIds, setSchoolIds] = useState<string[]>([]);
  const [preflight, setPreflight] = useState<PlanningInputPreflightData | null>(
    null,
  );
  const [workbench, setWorkbench] = useState<ConfirmedNeedWorkbenchData | null>(
    null,
  );
  const [operation, setOperation] = useState<AtlasOperation>({
    status: "IDLE",
  });
  const [busy, setBusy] = useState(true);
  const [lock, setLock] = useState<Lock>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [readError, setReadError] = useState<string | null>(null);
  const [pendingTransition, setPendingTransition] = useState<Transition | null>(
    null,
  );
  const [correlation] = useState(() => crypto.randomUUID());
  const epoch = useRef(0);
  const inFlight = useRef(false);
  const saveNeedsReadback = useRef(false);
  const [correction, setCorrection] = useState<Correction | null>(null);
  const correctionRef = useRef(correction);
  correctionRef.current = correction;
  const correctionEpoch = useRef(0);
  const correctionRequest =
    useRef<ConfirmedNeedCorrectionCommandRequest | null>(null);
  const correctionCommittedVersion = useRef<number | null>(null);
  const correctionOriginalUnknown = useRef(false);
  const correctionFocus = useRef<HTMLElement | null>(null);
  const [correctionFocusPending, setCorrectionFocusPending] = useState(false);
  const correctionDirty = Boolean(
    correction &&
    (correction.quantity !== correction.target.proposed_confirmed_quantity ||
      correction.reason_code !== correction.target.reason_code ||
      correction.reason_note.trim()),
  );
  useEffect(() => {
    if (!correctionFocusPending || busy || rangeBusy || correction) return;
    const node = correctionFocus.current;
    if (
      node?.isConnected &&
      !(node instanceof HTMLButtonElement && node.disabled)
    ) {
      node.focus({ preventScroll: true });
      setCorrectionFocusPending(false);
    }
  }, [correctionFocusPending, busy, rangeBusy, correction]);

  const {
    drafts,
    setDrafts,
    resetDrafts,
    search,
    setSearch,
    filter,
    setFilter,
    differencesOnly,
    setDifferencesOnly,
    changedLines,
    dirty,
    errors,
    schools,
    visibleLines,
    hiddenDirtyCount,
  } = useConfirmedNeedDraft(workbench, schoolIds);
  if (loadedDate.current === date)
    days.current[date] = {
      preflight,
      workbench,
      drafts,
      dirty,
      lock,
      readError,
    };
  const allDirty =
    correctionDirty ||
    dirty ||
    Object.entries(days.current).some(
      ([d, day]) => d !== date && dates.includes(d) && day.dirty,
    );
  useEffect(() => {
    days.current = {};
    loadedDate.current = null;
    correctionEpoch.current++;
    setCorrection(null);
    correctionRequest.current = null;
    correctionCommittedVersion.current = null;
    correctionOriginalUnknown.current = false;
  }, [authSubject, preflightApi, confirmedNeedApi]);
  const shoppingContext = useRef({
    range,
    allDirty,
    rangeBusy,
    rangeError,
    date,
    workbench,
    drafts,
    dirty,
    busy,
    lock,
    authSubject,
  });
  shoppingContext.current = {
    range,
    allDirty,
    rangeBusy,
    rangeError,
    date,
    workbench,
    drafts,
    dirty,
    busy,
    lock,
    authSubject,
  };
  const adopt = useCallback(
    (b: ConfirmedNeedWorkbenchData) => {
      setWorkbench(b);
      resetDrafts(b);
    },
    [resetDrafts],
  );
  const loadBatch = useCallback(
    async (p: PlanningInputPreflightData) => {
      if (!authSubject || !p.current_need?.confirmed_need_batch_id) return null;
      const b = await loadCompleteConfirmedNeedReview(
        confirmedNeedApi,
        authSubject,
        p.current_need.confirmed_need_batch_id,
        date,
      );
      if (!validBatch(b, p, date)) throw new Error(readFailure);
      return b;
    },
    [authSubject, confirmedNeedApi, correlation, date],
  );
  const failRead = useCallback((message: string) => {
    setReadError(message);
    setLock((current) => current ?? "eligibility");
  }, []);
  const recover = useCallback(async () => {
    if (inFlight.current || invalidRange.current) return;
    const requestEpoch = ++epoch.current;
    inFlight.current = true;
    setBusy(true);
    setReadError(null);
    try {
      if (!authSubject) {
        failRead("Vui lòng đăng nhập để xem nhu cầu.");
        return;
      }
      const r = await preflightApi.preflight(
        authSubject,
        correlation,
        date,
        date,
      );
      if (epoch.current !== requestEpoch || invalidRange.current) return;
      const p = planningInputPreflightFromResult(r);
      if (!validPreflight(p, date)) {
        failRead(
          r.kind === "success" ? readFailure : confirmedNeedResultMessage(r),
        );
        return;
      }
      const requiresBatch =
        (p.downstream_currentness === "CURRENT" && !generatedNoDemand(p)) ||
        saveNeedsReadback.current;
      const b = requiresBatch ? await loadBatch(p) : null;
      if (epoch.current !== requestEpoch) return;
      if (requiresBatch && !b) {
        failRead(readFailure);
        return;
      }
      loadedDate.current = date;
      setPreflight(p);
      if (b && p.downstream_currentness === "CURRENT") adopt(b);
      else {
        setWorkbench(null);
        setDrafts({});
      }
      setLock(null);
      saveNeedsReadback.current = false;
      setNotice(null);
      setOperation({ status: "IDLE" });
    } catch (e) {
      if (epoch.current === requestEpoch) {
        failRead(e instanceof Error ? e.message : readFailure);
      }
    } finally {
      if (epoch.current === requestEpoch) {
        inFlight.current = false;
        setBusy(false);
      }
    }
  }, [
    authSubject,
    preflightApi,
    correlation,
    date,
    loadBatch,
    adopt,
    failRead,
  ]);
  useEffect(() => {
    const cached = days.current[date];
    if (cached) {
      inFlight.current = false;
      saveNeedsReadback.current = false;
      loadedDate.current = date;
      setPreflight(cached.preflight);
      setWorkbench(cached.workbench);
      setDrafts(cached.drafts);
      setLock(cached.lock);
      setReadError(cached.readError);
      setBusy(false);
      setNotice(null);
      setOperation({ status: "IDLE" });
      return () => {
        epoch.current++;
      };
    }
    loadedDate.current = null;
    setOperation({ status: "IDLE" });
    setPreflight(null);
    setWorkbench(null);
    setDrafts({});
    setLock(null);
    setNotice(null);
    inFlight.current = false;
    saveNeedsReadback.current = false;
    void recover();
    return () => {
      epoch.current++;
    };
  }, [recover]);
  useEffect(() => {
    const token = ++rangeEpoch.current;
    const pending = shoppingListRangeDates(range).filter(
      (d) => d !== date && !days.current[d],
    );
    if (invalidRange.current || !authSubject || !pending.length) {
      setRangeBusy(false);
      return;
    }
    setRangeBusy(true);
    void Promise.all(
      pending.map(async (day) => {
        try {
          const p = planningInputPreflightFromResult(
            await preflightApi.preflight(authSubject, correlation, day, day),
          );
          if (token !== rangeEpoch.current) return;
          if (!validPreflight(p, day)) throw new Error(readFailure);
          const b =
            p.downstream_currentness === "CURRENT" &&
            !generatedNoDemand(p) &&
            p.current_need?.confirmed_need_batch_id
              ? await loadCompleteConfirmedNeedReview(
                  confirmedNeedApi,
                  authSubject,
                  p.current_need.confirmed_need_batch_id,
                  day,
                )
              : null;
          if (
            p.downstream_currentness === "CURRENT" &&
            !generatedNoDemand(p) &&
            (!b || !validBatch(b, p, day))
          )
            throw new Error(readFailure);
          if (token !== rangeEpoch.current) return;
          days.current[day] = {
            preflight: p,
            workbench: b,
            drafts: Object.fromEntries(
              (b?.lines ?? []).map((l) => [
                l.confirmed_need_line_id,
                initialConfirmedNeedDraft(l),
              ]),
            ),
            dirty: false,
            lock: null,
            readError: null,
          };
        } catch (error) {
          if (token !== rangeEpoch.current) return;
          days.current[day] = {
            preflight: null,
            workbench: null,
            drafts: {},
            dirty: false,
            lock: "eligibility",
            readError: error instanceof Error ? error.message : readFailure,
          };
        }
      }),
    ).then(() => {
      if (token === rangeEpoch.current) {
        setRangeBusy(false);
        updateDays((v) => v + 1);
      }
    });
    return () => {
      rangeEpoch.current++;
    };
  }, [range, authSubject, preflightApi, confirmedNeedApi, correlation]);
  const released =
    workbench?.authoritative_batch_status === "RELEASED_FOR_PURCHASE_HANDOFF";
  const current = Boolean(
    authSubject &&
    preflight?.downstream_currentness === "CURRENT" &&
    workbench &&
    validBatch(workbench, preflight, date) &&
    preflight.readiness_state === "READY" &&
    workbench.blockers.length === 0 &&
    !workbench.lines.some((l) => l.source_stale || l.blockers.length > 0),
  );
  const editable =
    current &&
    !rangeError &&
    !released &&
    !correction &&
    workbench?.editing_allowed === true &&
    !busy &&
    !lock;
  const canSave =
    editable &&
    workbench?.allowed_actions.save_confirmed_needs === true &&
    dirty &&
    !Object.keys(errors).length;
  const canContinue =
    !rangeError &&
    current &&
    !allDirty &&
    !rangeBusy &&
    !Object.keys(errors).length &&
    !busy &&
    !lock &&
    Boolean(onContinueAllocation);
  const canGenerate = Boolean(
    !rangeError &&
    authSubject &&
    preflight &&
    validPreflight(preflight, date) &&
    preflight.readiness_state === "READY" &&
    !noDemand(preflight) &&
    ["NOT_GENERATED", "OUTDATED"].includes(preflight.downstream_currentness) &&
    (preflight.downstream_currentness !== "OUTDATED" ||
      Boolean(preflight.current_need?.need_generation_run_id)) &&
    !correctionBlocked(preflight) &&
    !busy &&
    !lock,
  );
  const edit = (id: string, change: Partial<ConfirmedNeedDraftLine>) => {
    const line = workbench?.lines.find((l) => l.confirmed_need_line_id === id);
    if (invalidRange.current || !editable || !line || historicalQuantity(line))
      return;
    setDrafts((d) => ({ ...d, [id]: { ...d[id]!, ...change } }));
  };
  const classifyFailure = (r: AtlasRpcResult, generation = false) => {
    if (generation) {
      const unknown =
        r.kind === "success" || confirmedNeedResultHasUnknownWriteOutcome(r);
      const message = unknown
        ? "Chưa xác định được kết quả. Tải lại để xác nhận trước khi gửi yêu cầu khác."
        : needGenerationResultMessage(r);
      setOperation(
        unknown
          ? { status: "UNKNOWN_OUTCOME", message }
          : {
              status: "FAILED",
              message,
              failureKind:
                r.kind === "backend_error" && r.error.retryable === true
                  ? "retryable"
                  : "business",
            },
      );
    }
    if (
      confirmedNeedResultIsStale(r) ||
      (generation && needGenerationResultIsStale(r))
    )
      setLock("stale");
    else if (
      confirmedNeedResultRequiresEligibilityRefresh(r) ||
      r.kind === "auth_error"
    )
      setLock("eligibility");
    else if (
      r.kind === "success" ||
      confirmedNeedResultHasUnknownWriteOutcome(r)
    )
      setLock("unknown");
    setNotice(
      r.kind === "success"
        ? "Chưa xác định được kết quả. Tải lại để xác nhận."
        : generation
          ? needGenerationResultMessage(r)
          : confirmedNeedResultMessage(r),
    );
  };
  const save = async () => {
    if (
      invalidRange.current ||
      !canSave ||
      !authSubject ||
      !workbench ||
      !preflight ||
      inFlight.current
    )
      return;
    setOperation({ status: "IDLE" });
    inFlight.current = true;
    setBusy(true);
    setNotice(null);
    const requestEpoch = epoch.current;
    const request = confirmedNeedSaveV2Request(
      authSubject,
      correlation,
      workbench.confirmed_need_batch_id,
      workbench.batch_version,
      changedLines.map((l) =>
        draftLineRequest(l, drafts[l.confirmed_need_line_id]!),
      ),
    );
    try {
      saveNeedsReadback.current = true;
      const r = await confirmedNeedApi.save(request);
      if (epoch.current !== requestEpoch) return;
      const b = confirmedNeedReadbackFromResult(r);
      if (
        validBatch(b, preflight, date) &&
        b.batch_version > workbench.batch_version
      ) {
        adopt(b);
        saveNeedsReadback.current = false;
        setLock(null);
        setNotice("Đã lưu thay đổi.");
      } else classifyFailure(r);
    } catch {
      if (epoch.current === requestEpoch) {
        setLock("unknown");
        setNotice("Chưa xác định được kết quả lưu. Tải lại để xác nhận.");
      }
    } finally {
      if (epoch.current === requestEpoch) {
        inFlight.current = false;
        setBusy(false);
      }
    }
  };
  const generate = async () => {
    if (
      invalidRange.current ||
      !canGenerate ||
      !authSubject ||
      !preflight ||
      inFlight.current
    )
      return;
    inFlight.current = true;
    setBusy(true);
    setOperation({
      status: "RUNNING",
      startedAt: Date.now(),
      action:
        preflight.downstream_currentness === "OUTDATED"
          ? "Đang cập nhật nhu cầu…"
          : "Đang tạo nhu cầu…",
    });
    setNotice(null);
    const requestEpoch = epoch.current;
    const request = needGenerationExecutionRequest(
      authSubject,
      correlation,
      preflight.current_need?.need_generation_run_version ?? 1,
      date,
      preflight.current_need?.need_generation_run_id ?? null,
    );
    try {
      const r = await needGenerationApi.execute(request);
      if (epoch.current !== requestEpoch) return;
      if (r.kind !== "success") {
        classifyFailure(r, true);
        return;
      }
      const p = planningInputPreflightFromResult(r);
      const need = needGenerationReadbackFromResult(r);
      if (
        !validPreflight(p, date) ||
        p.downstream_currentness !== "CURRENT" ||
        !p.current_need ||
        !need ||
        need.period.period_start !== date ||
        need.period.period_end !== date ||
        need.selected_run?.need_generation_run_id !==
          p.current_need.need_generation_run_id ||
        need.materialization.confirmed_need_batch_id !==
          p.current_need.confirmed_need_batch_id
      ) {
        classifyFailure(r, true);
        return;
      }
      if (generatedNoDemand(p)) {
        if (
          need.selected_run?.status !== "RELEASED_FOR_CONFIRMATION" ||
          need.selected_run.version !==
            p.current_need.need_generation_run_version ||
          !need.selected_run.release_snapshot_id ||
          need.selected_run.release_snapshot_id !==
            p.current_need.need_generation_release_snapshot_id ||
          need.grouped_requirements.some(
            (group) => group.total_theoretical_quantity !== 0,
          )
        ) {
          classifyFailure(r, true);
          return;
        }
        setPreflight(p);
        setWorkbench(null);
        setDrafts({});
        setLock(null);
        setOperation({ status: "SUCCEEDED", message: "Không có nhu cầu." });
        setNotice("Không có nhu cầu.");
        return;
      }
      const b = await loadBatch(p);
      if (epoch.current !== requestEpoch) return;
      if (!b) {
        classifyFailure(r, true);
        return;
      }
      setPreflight(p);
      adopt(b);
      setLock(null);
      const counts = needGenerationContinuitySummaryFromResult(r);
      setOperation({
        status: "SUCCEEDED",
        message:
          `${preflight.downstream_currentness === "OUTDATED" ? "Đã cập nhật nhu cầu." : "Đã tạo nhu cầu."} ${b.line_counts.total} dòng nhu cầu đã sẵn sàng để xác nhận.` +
          (preflight.downstream_currentness === "OUTDATED" && counts
            ? ` ${counts.needsReview} dòng cần rà soát · ${counts.carriedForward} xác nhận được giữ nguyên.`
            : ""),
      });
      setNotice(
        preflight.downstream_currentness === "OUTDATED" && counts
          ? `Đã cập nhật nhu cầu · ${counts.needsReview} dòng cần rà soát · ${counts.carriedForward} xác nhận được giữ nguyên`
          : "Đã tạo nhu cầu.",
      );
    } catch {
      if (epoch.current === requestEpoch) {
        setLock("unknown");
        setOperation({
          status: "UNKNOWN_OUTCOME",
          message:
            "Chưa xác định được kết quả tạo nhu cầu. Tải lại để xác nhận trước khi gửi yêu cầu khác.",
        });
        setNotice(
          "Chưa xác định được kết quả tạo nhu cầu. Tải lại để xác nhận.",
        );
      }
    } finally {
      if (epoch.current === requestEpoch) {
        inFlight.current = false;
        setBusy(false);
      }
    }
  };
  const clearCorrection = () => {
    correctionEpoch.current++;
    setCorrection(null);
    correctionRequest.current = null;
    correctionCommittedVersion.current = null;
    correctionOriginalUnknown.current = false;
    setCorrectionFocusPending(true);
  };
  const openCorrection = (id: string, returnFocus?: HTMLElement) => {
    if (
      invalidRange.current ||
      !released ||
      !current ||
      allDirty ||
      busy ||
      lock ||
      inFlight.current ||
      !workbench
    )
      return;
    const line = workbench.lines.find((l) => l.confirmed_need_line_id === id);
    const source = workbench.need_generation_source;
    if (
      !line?.current_revision_id ||
      !line.current_decision_id ||
      line.confirmed_quantity_after === null ||
      !source?.run_id ||
      !source.run_version
    )
      return;
    correctionEpoch.current++;
    correctionFocus.current = returnFocus ?? null;
    setCorrectionFocusPending(false);
    setCorrection({
      target: {
        need_generation_run_id: source.run_id,
        expected_need_generation_run_version: source.run_version,
        confirmed_need_batch_id: workbench.confirmed_need_batch_id,
        expected_confirmed_need_batch_version: workbench.batch_version,
        confirmed_need_line_id: id,
        expected_current_revision_id: line.current_revision_id,
        expected_current_decision_id: line.current_decision_id,
        proposed_confirmed_quantity: line.confirmed_quantity_after,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "",
      },
      quantity: line.confirmed_quantity_after,
      reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
      reason_note: "",
      status: "EDITING",
      preview: null,
      error: null,
    });
  };
  const updateCorrection = (
    change: Partial<
      Pick<Correction, "quantity" | "reason_code" | "reason_note">
    >,
  ) => {
    if (
      invalidRange.current ||
      !correctionRef.current ||
      inFlight.current ||
      correctionRequest.current ||
      lock
    )
      return;
    correctionEpoch.current++;
    setCorrection((v) =>
      v
        ? { ...v, ...change, status: "EDITING", preview: null, error: null }
        : v,
    );
  };
  const previewCorrection = async () => {
    const form = correctionRef.current;
    if (
      invalidRange.current ||
      !form ||
      !authSubject ||
      inFlight.current ||
      correctionRequest.current ||
      lock ||
      form.status === "STALE"
    )
      return;
    const token = ++correctionEpoch.current,
      context = epoch.current;
    try {
      const request = confirmedNeedCorrectionPreviewRequest(
        authSubject,
        correlation,
        {
          ...form.target,
          proposed_confirmed_quantity: form.quantity,
          reason_code: form.reason_code,
          reason_note: form.reason_note,
        },
      );
      setCorrection((v) =>
        v ? { ...v, status: "PREVIEWING", preview: null, error: null } : v,
      );
      const result = await confirmedNeedApi.previewCorrection(request);
      if (
        invalidRange.current ||
        token !== correctionEpoch.current ||
        context !== epoch.current
      )
        return;
      const preview = confirmedNeedCorrectionPreviewFromResult(
        result,
        request.payload,
      );
      setCorrection((v) =>
        v
          ? {
              ...v,
              status: "EDITING",
              preview,
              error: preview
                ? null
                : result.kind === "success"
                  ? readFailure
                  : confirmedNeedResultMessage(result),
            }
          : v,
      );
    } catch (error) {
      if (
        !invalidRange.current &&
        token === correctionEpoch.current &&
        context === epoch.current
      )
        setCorrection((v) =>
          v
            ? {
                ...v,
                status: "EDITING",
                preview: null,
                error: error instanceof Error ? error.message : readFailure,
              }
            : v,
        );
    }
  };
  const readCorrection = async (
    request: {
      payload: ConfirmedNeedCorrectionPayload;
      expected_version: number;
    },
    context: number,
  ) => {
    if (invalidRange.current) throw new Error(readFailure);
    if (!authSubject || !preflight) return false;
    const fresh = await loadCompleteConfirmedNeedReview(
      confirmedNeedApi,
      authSubject,
      request.payload.confirmed_need_batch_id,
      date,
    );
    if (epoch.current !== context) return false;
    if (invalidRange.current) throw new Error(readFailure);
    if (
      !validBatch(fresh, preflight, date) ||
      fresh.batch_version <
        (correctionCommittedVersion.current ?? request.expected_version)
    )
      throw new Error(readFailure);
    if (correctionCommittedVersion.current === null) {
      const line = fresh.lines.find(
        (l) =>
          l.confirmed_need_line_id === request.payload.confirmed_need_line_id,
      );
      if (!line?.current_revision_id || !line.current_decision_id)
        throw new Error(readFailure);
      adopt(fresh);
      setLock(null);
      setCorrection((v) =>
        v
          ? {
              ...v,
              status: "EDITING",
              preview: null,
              error: null,
              target: {
                ...v.target,
                expected_confirmed_need_batch_version: fresh.batch_version,
                expected_need_generation_run_version:
                  fresh.need_generation_source.run_version,
                expected_current_revision_id: line.current_revision_id,
                expected_current_decision_id: line.current_decision_id!,
                proposed_confirmed_quantity: line.confirmed_quantity_after!,
              },
            }
          : v,
      );
      return true;
    }
    adopt(fresh);
    setPreflight((p) =>
      p?.current_need
        ? {
            ...p,
            current_need: {
              ...p.current_need,
              confirmed_need_batch_status: fresh.authoritative_batch_status,
            },
          }
        : p,
    );
    setLock(null);
    setReadError(null);
    setNotice(
      "Đã lưu điều chỉnh. Cần rà soát mua hàng và phiếu xuất trước khi phát hành tiếp.",
    );
    clearCorrection();
    return true;
  };
  const executeCorrection = async (
    request: ConfirmedNeedCorrectionCommandRequest,
  ) => {
    if (invalidRange.current || inFlight.current) return;
    const context = epoch.current;
    inFlight.current = true;
    setBusy(true);
    setNotice(null);
    setCorrection((v) => (v ? { ...v, status: "SAVING", error: null } : v));
    try {
      const result = await confirmedNeedApi.correct(request);
      if (context !== epoch.current) return;
      const outcome = confirmedNeedCorrectionOutcome(result, request);
      if (outcome.kind === "committed") {
        correctionOriginalUnknown.current = false;
        correctionCommittedVersion.current = outcome.version;
        setCorrection((v) => (v ? { ...v, status: "READBACK" } : v));
        try {
          await readCorrection(request, context);
        } catch {
          if (context === epoch.current) {
            setLock("unknown");
            setCorrection((v) =>
              v ? { ...v, status: "READBACK", error: readFailure } : v,
            );
          }
        }
      } else if (
        outcome.kind === "unknown" ||
        correctionOriginalUnknown.current
      ) {
        // A denied or no-write retry does not resolve an earlier lost response.
        correctionOriginalUnknown.current = true;
        setLock("unknown");
        setCorrection((v) =>
          v
            ? {
                ...v,
                status: "UNKNOWN",
                error:
                  outcome.kind === "unknown"
                    ? "Chưa xác định được kết quả. Thử lại đúng yêu cầu đã gửi để xác nhận."
                    : `${outcome.message} Kết quả yêu cầu ban đầu vẫn chưa xác định; cần xác nhận đúng yêu cầu đã gửi.`,
              }
            : v,
        );
      } else {
        setLock(null);
        correctionCommittedVersion.current = null;
        if (outcome.kind !== "retryable") correctionRequest.current = null;
        setCorrection((v) =>
          v
            ? {
                ...v,
                status:
                  outcome.kind === "stale"
                    ? "STALE"
                    : outcome.kind === "retryable"
                      ? "RETRYABLE"
                      : "EDITING",
                preview: outcome.kind === "retryable" ? v.preview : null,
                error: outcome.message,
              }
            : v,
        );
      }
    } catch {
      if (context === epoch.current) {
        correctionOriginalUnknown.current = true;
        setLock("unknown");
        setCorrection((v) =>
          v
            ? {
                ...v,
                status: "UNKNOWN",
                error:
                  "Chưa xác định được kết quả. Thử lại đúng yêu cầu đã gửi để xác nhận.",
              }
            : v,
        );
      }
    } finally {
      if (context === epoch.current) {
        inFlight.current = false;
        setBusy(false);
      }
    }
  };
  const saveCorrection = async () => {
    const form = correctionRef.current;
    if (
      invalidRange.current ||
      !form?.preview?.allowed_actions.correct ||
      !authSubject ||
      inFlight.current ||
      correctionRequest.current ||
      lock ||
      pendingTransition
    )
      return;
    const request = confirmedNeedCorrectionCommandRequest(
      authSubject,
      correlation,
      form.preview.target,
      form.preview.proposal_fingerprint,
    );
    Object.freeze(request.payload);
    Object.freeze(request);
    correctionRequest.current = request;
    await executeCorrection(request);
  };
  const retryCorrection = async () => {
    if (invalidRange.current) return;
    if (
      correctionRequest.current &&
      correctionCommittedVersion.current === null
    )
      await executeCorrection(correctionRequest.current);
  };
  const recoverCorrection = async () => {
    const form = correctionRef.current;
    if (invalidRange.current || !form || !authSubject || inFlight.current)
      return;
    if (
      correctionRequest.current &&
      correctionCommittedVersion.current === null
    ) {
      await retryCorrection();
      return;
    }
    const request = correctionRequest.current ?? {
      payload: form.target,
      expected_version: form.target.expected_confirmed_need_batch_version,
    };
    const context = epoch.current;
    inFlight.current = true;
    setBusy(true);
    try {
      await readCorrection(request, context);
    } catch {
      if (context === epoch.current) {
        setLock(
          correctionCommittedVersion.current === null
            ? "eligibility"
            : "unknown",
        );
        setCorrection((v) => (v ? { ...v, error: readFailure } : v));
      }
    } finally {
      if (context === epoch.current) {
        inFlight.current = false;
        setBusy(false);
      }
    }
  };
  const applyTransition = (t: Transition) => {
    if (correctionRef.current) clearCorrection();
    if (t.exit) {
      t.exit();
      return;
    }
    if (t.range) {
      for (const key of Object.keys(days.current))
        if (key < t.range.start || key > t.range.end) delete days.current[key];
      setRange(t.range);
      if (date < t.range.start || date > t.range.end) setDate(t.range.start);
    }
    if (t.selectDay) setDate(t.selectDay);
    if (t.schoolIds) setSchoolIds(t.schoolIds);
    if (t.week) setDate(mondayOf(t.week));
    else if (t.date) {
      setDate(t.date);
      setRange({ start: t.date, end: t.date });
    }
    if (t.refresh) void recover();
  };
  const transition = (t: Transition) => {
    if (
      inFlight.current ||
      busy ||
      lock ||
      (invalidRange.current && (t.refresh || t.date || t.week))
    )
      return;
    const leavesDirty = t.range
      ? correctionDirty ||
        Object.entries(days.current).some(
          ([day, state]) =>
            state.dirty && (day < t.range!.start || day > t.range!.end),
        )
      : t.selectDay
        ? correctionDirty
        : t.exit || t.date || t.week
          ? allDirty
          : dirty || correctionDirty;
    if (leavesDirty) setPendingTransition(t);
    else applyTransition(t);
  };
  const discardTransition = () => {
    if (!pendingTransition || busy || lock || inFlight.current) return;
    const shouldDiscard = (day: string) =>
      pendingTransition.range
        ? day < pendingTransition.range.start ||
          day > pendingTransition.range.end
        : pendingTransition.exit ||
            pendingTransition.date ||
            pendingTransition.week
          ? true
          : day === date;
    if (workbench && shouldDiscard(date)) resetDrafts(workbench);
    for (const [dayDate, day] of Object.entries(days.current))
      if (day.workbench && shouldDiscard(dayDate)) {
        day.drafts = Object.fromEntries(
          day.workbench.lines.map((l) => [
            l.confirmed_need_line_id,
            initialConfirmedNeedDraft(l),
          ]),
        );
        day.dirty = false;
      }
    if (correctionRef.current) clearCorrection();
    const next = pendingTransition;
    setPendingTransition(null);
    applyTransition(next);
  };
  useEffect(() => {
    if (!allDirty && !lock && operation.status !== "RUNNING") return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [allDirty, lock, operation.status]);
  return {
    range,
    rangeError,
    rangeBusy,
    allDirty,
    days: dates.map((day) => ({
      date: day,
      ...(day === date
        ? { preflight, workbench, drafts, dirty, lock, readError }
        : days.current[day]),
    })),
    changeRange: (next: AtlasOperatorDateRange) => {
      if (busy || lock || inFlight.current) return;
      const error = operatorDateRangeError(next);
      setRangeError(error);
      invalidRange.current = error;
      if (error) {
        correctionEpoch.current++;
        setCorrection((v) =>
          v
            ? {
                ...v,
                preview: null,
                status: v.status === "PREVIEWING" ? "EDITING" : v.status,
              }
            : v,
        );
        rangeEpoch.current++;
        setRangeBusy(false);
        return;
      }
      transition({ range: next });
    },
    selectDay: (next: string) => {
      if (
        !busy &&
        !inFlight.current &&
        !rangeError &&
        !lock &&
        dates.includes(next) &&
        days.current[next]
      )
        transition({ selectDay: next });
    },
    shoppingRangeContext: {
      range,
      workbenches: dates.flatMap((d) =>
        days.current[d]?.workbench ? [days.current[d]!.workbench!] : [],
      ),
      drafts: Object.assign(
        {},
        ...dates.map((d) => days.current[d]?.drafts ?? {}),
      ),
      onSkippedDates: (skipped: string[]) =>
        setNotice(
          skipped.length
            ? `Không có nhu cầu: ${skipped.join(", ")}. Đã bỏ qua khi xuất.`
            : null,
        ),
      isCurrent: () =>
        !invalidRange.current &&
        !shoppingContext.current.rangeError &&
        shoppingContext.current.authSubject === authSubject &&
        shoppingContext.current.workbench === workbench &&
        shoppingContext.current.range === range &&
        !shoppingContext.current.allDirty &&
        !shoppingContext.current.rangeBusy &&
        shoppingContext.current.date === date &&
        shoppingContext.current.drafts === drafts &&
        !shoppingContext.current.dirty &&
        !shoppingContext.current.busy &&
        !shoppingContext.current.lock &&
        !rangeBusy &&
        !allDirty,
    } satisfies ShoppingListRangeContext,
    operation,
    date,
    week,
    schoolIds,
    preflight,
    workbench,
    drafts,
    busy,
    lock,
    notice,
    readError,
    search,
    setSearch,
    filter,
    setFilter,
    differencesOnly,
    setDifferencesOnly,
    schools,
    visibleLines,
    changedLines,
    hiddenDirtyCount,
    dirty,
    errors,
    released,
    editable,
    canSave,
    canGenerate,
    canContinue,
    edit,
    save,
    generate,
    recover: correction ? recoverCorrection : recover,
    correction,
    correctionDirty,
    openCorrection,
    updateCorrection,
    previewCorrection,
    saveCorrection,
    retryCorrection,
    closeCorrection: () => transition({ closeCorrection: true }),
    requestExit: (exit: () => void) => {
      if (busy || inFlight.current || lock) return;
      transition({ exit });
    },
    transition,
    pendingTransition,
    cancelTransition: () => setPendingTransition(null),
    discardTransition,
    continueAllocation: () => {
      if (!invalidRange.current && canContinue && !inFlight.current)
        onContinueAllocation?.(range);
    },
    captureShoppingListImport: () => {
      const expected = shoppingContext.current;
      return (imported: ConfirmedNeedShoppingListImport) => {
        const current = shoppingContext.current;
        if (
          allDirty ||
          rangeBusy ||
          expected.rangeError ||
          current.rangeError ||
          expected.dirty ||
          expected.busy ||
          expected.lock ||
          !expected.workbench?.editing_allowed ||
          current.range !== expected.range ||
          current.allDirty ||
          current.rangeBusy ||
          current.date !== expected.date ||
          current.workbench !== expected.workbench ||
          current.drafts !== expected.drafts ||
          current.authSubject !== expected.authSubject ||
          current.dirty ||
          current.busy ||
          current.lock
        )
          throw new Error(
            "Dữ liệu hoặc bản nháp đã thay đổi trong khi nhập. Hãy tải lại và chọn file một lần nữa.",
          );
        setOperation({ status: "IDLE" });
        if (imported.changedLineIds.length) {
          for (const day of Object.values(days.current))
            if (day.workbench) {
              day.drafts = Object.fromEntries(
                day.workbench.lines.map((l) => [
                  l.confirmed_need_line_id,
                  imported.drafts[l.confirmed_need_line_id] ??
                    day.drafts[l.confirmed_need_line_id]!,
                ]),
              );
              day.dirty = day.workbench.lines.some((l) =>
                imported.changedLineIds.includes(l.confirmed_need_line_id),
              );
            }
          setDrafts(days.current[date]?.drafts ?? imported.drafts);
          updateDays((v) => v + 1);
        }
        setNotice(
          `Đã nhập ${imported.changedLineIds.length} thay đổi vào bản nháp.`,
        );
      };
    },
  };
}
