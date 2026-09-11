import { useConfirmedNeedDraft } from "./useConfirmedNeedDraft";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  confirmedNeedReadbackFromResult,
  confirmedNeedResultHasUnknownWriteOutcome,
  confirmedNeedResultIsStale,
  confirmedNeedResultMessage,
  confirmedNeedResultRequiresEligibilityRefresh,
  confirmedNeedSaveV2Request,
  confirmedNeedWorkbenchFromResult,
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
  validBatch,
  validPreflight,
} from "./confirmedNeedAuthority";
import { draftLineRequest, historicalQuantity } from "./confirmedNeedDraft";
export type ConfirmedNeedWorkbenchProps = {
  authSubject: string | null;
  initialServiceDate: string;
  preflightApi: PreflightApi;
  needGenerationApi: NeedGenerationApi;
  confirmedNeedApi: ConfirmedNeedApi;
  onContinueAllocation?: (serviceDate: string) => void;
};
type Transition = {
  date?: string;
  week?: string;
  schoolIds?: string[];
  refresh?: boolean;
};
type Lock = "unknown" | "stale" | "eligibility" | null;
const readFailure = "Không thể tải dữ liệu hiện tại. Hãy thử tải lại.";
export function useConfirmedNeedWorkbench({
  authSubject,
  initialServiceDate,
  preflightApi,
  needGenerationApi,
  confirmedNeedApi,
  onContinueAllocation,
}: ConfirmedNeedWorkbenchProps) {
  const [date, setDate] = useState(initialServiceDate);
  const week = mondayOf(date);
  const [schoolIds, setSchoolIds] = useState<string[]>([]);
  const [preflight, setPreflight] = useState<PlanningInputPreflightData | null>(
    null,
  );
  const [workbench, setWorkbench] = useState<ConfirmedNeedWorkbenchData | null>(
    null,
  );
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
  const adopt = useCallback(
    (b: ConfirmedNeedWorkbenchData) => {
      setWorkbench(b);
      resetDrafts(b);
    },
    [resetDrafts],
  );
  const loadBatch = useCallback(
    async (p: PlanningInputPreflightData) => {
      if (!authSubject || !p.current_need) return null;
      const r = await confirmedNeedApi.getReview(
        authSubject,
        correlation,
        p.current_need.confirmed_need_batch_id,
        {
          service_date: date,
          school_id: null,
          delivery_location_id: null,
          ingredient_id: null,
          decision_state: null,
        },
        0,
        10000,
      );
      const b = confirmedNeedWorkbenchFromResult(r);
      if (!validBatch(b, p, date))
        throw new Error(
          r.kind === "success" ? readFailure : confirmedNeedResultMessage(r),
        );
      return b;
    },
    [authSubject, confirmedNeedApi, correlation, date],
  );
  const failRead = useCallback((message: string) => {
    setReadError(message);
    setLock((current) => current ?? "eligibility");
  }, []);
  const recover = useCallback(async () => {
    if (inFlight.current) return;
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
      if (epoch.current !== requestEpoch) return;
      const p = planningInputPreflightFromResult(r);
      if (!validPreflight(p, date)) {
        failRead(
          r.kind === "success" ? readFailure : confirmedNeedResultMessage(r),
        );
        return;
      }
      const requiresBatch =
        p.downstream_currentness === "CURRENT" || saveNeedsReadback.current;
      const b = requiresBatch ? await loadBatch(p) : null;
      if (epoch.current !== requestEpoch) return;
      if (requiresBatch && !b) {
        failRead(readFailure);
        return;
      }
      setPreflight(p);
      if (b && p.downstream_currentness === "CURRENT") adopt(b);
      else {
        setWorkbench(null);
        setDrafts({});
      }
      setLock(null);
      saveNeedsReadback.current = false;
      setNotice(null);
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
    !released &&
    workbench?.editing_allowed === true &&
    !busy &&
    !lock;
  const canSave =
    editable &&
    workbench?.allowed_actions.save_confirmed_needs === true &&
    dirty &&
    !Object.keys(errors).length;
  const canContinue =
    current &&
    !dirty &&
    !Object.keys(errors).length &&
    !busy &&
    !lock &&
    Boolean(onContinueAllocation);
  const canGenerate = Boolean(
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
    if (!editable || !line || historicalQuantity(line)) return;
    setDrafts((d) => ({ ...d, [id]: { ...d[id]!, ...change } }));
  };
  const classifyFailure = (r: AtlasRpcResult, generation = false) => {
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
      !canSave ||
      !authSubject ||
      !workbench ||
      !preflight ||
      inFlight.current
    )
      return;
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
    if (!canGenerate || !authSubject || !preflight || inFlight.current) return;
    inFlight.current = true;
    setBusy(true);
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
      setNotice(
        preflight.downstream_currentness === "OUTDATED" && counts
          ? `Đã cập nhật nhu cầu · ${counts.needsReview} dòng cần rà soát · ${counts.carriedForward} xác nhận được giữ nguyên`
          : "Đã tạo nhu cầu.",
      );
    } catch {
      if (epoch.current === requestEpoch) {
        setLock("unknown");
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
  const applyTransition = (t: Transition) => {
    if (t.schoolIds) setSchoolIds(t.schoolIds);
    if (t.week) setDate(mondayOf(t.week));
    else if (t.date) setDate(t.date);
    if (t.refresh) void recover();
  };
  const transition = (t: Transition) => {
    if (busy || lock) return;
    if (dirty) setPendingTransition(t);
    else applyTransition(t);
  };
  const discardTransition = () => {
    if (!pendingTransition) return;
    if (workbench) resetDrafts(workbench);
    const next = pendingTransition;
    setPendingTransition(null);
    applyTransition(next);
  };
  useEffect(() => {
    if (!dirty && !lock) return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty, lock]);
  return {
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
    recover,
    transition,
    pendingTransition,
    cancelTransition: () => setPendingTransition(null),
    discardTransition,
    continueAllocation: () => {
      if (canContinue && !inFlight.current) onContinueAllocation?.(date);
    },
  };
}
