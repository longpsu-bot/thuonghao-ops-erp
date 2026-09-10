import { useCallback, useEffect, useRef, useState } from "react";
import {
  activeMenuRows,
  activeAttendanceRows,
  attendanceWorkingRows,
  attendanceNeedsConfirmation,
  mondayOf,
  planningWorkbenchFromResult,
  pantryWorkbenchFromResult,
  planningPreviewFromResult,
  pantryPreviewFromResult,
  planningReadbackFromResult,
  pantryReadbackFromResult,
  planningResultMessage,
  parseMenuMatrix,
  parseAttendancePaste,
  pantryRowsFromBatch,
  pantryRowsForWrite,
  pantryModesForRows,
  planningCorrectionImpactFromResult,
  weeklyMenuCompletionRequest,
  attendanceCompletionRequest,
  pantryCompletionRequest,
  normalizePlanningSchoolScope,
  type PlanningInputsApi,
  type PantryApi,
  type PlanningInputsWorkbenchData,
  type PantryWorkbenchData,
  type MenuLine,
  type AttendanceLine,
  type PantryDraftRow,
  type PantrySchoolDateMode,
  type DirectNeedMode,
  type PlanningPreview,
  type PantryPreview,
  type PlanningCorrectionImpact,
  type PlanningCorrectionChain,
  type JsonValue,
  type AtlasRpcResult,
  type SourceMatrix,
} from "../bridges/planning";

type Source = "planning" | "pantry";
export type PlanningRecoveryKind =
  "READ_FAILURE" | "STALE" | "UNKNOWN_OR_MISSING_READBACK";
type SourceState = {
  loading: boolean;
  error: string;
  recovery: Exclude<PlanningRecoveryKind, "READ_FAILURE"> | null;
  outcome: string;
};
const initialSourceState: SourceState = {
  loading: true,
  error: "",
  recovery: null,
  outcome: "",
};
export type PlanningJob = "menu" | "attendance" | "pantry";
export type PlanningTransition = {
  job?: string;
  week?: string;
  date?: string;
  schoolIds?: string[];
  refresh?: boolean;
  noAdditions?: boolean;
};
export type PlanningSourcesProps = {
  api: Pick<
    PlanningInputsApi,
    | "getWorkbench"
    | "previewMenu"
    | "previewAttendance"
    | "syncMenuFromGoogle"
    | "saveCompletedMenu"
    | "saveCompletedAttendance"
    | "getCorrectionImpact"
    | "prepareCorrection"
  >;
  pantryApi: Pick<
    PantryApi,
    | "getWorkbench"
    | "preview"
    | "saveCompleted"
    | "getCorrectionImpact"
    | "prepareCorrection"
  >;
  authSubject: string;
  initialWeek?: string;
  initialJob?: PlanningJob;
};
export type AttendanceDraft = Omit<
  AttendanceLine,
  "student_portions" | "teacher_portions"
> & { student_portions: string; teacher_portions: string };
const attendanceDraft = (rows: AttendanceLine[]): AttendanceDraft[] =>
  rows.map((r) => ({
    ...r,
    student_portions: Number.isFinite(r.student_portions)
      ? String(r.student_portions)
      : "",
    teacher_portions: Number.isFinite(r.teacher_portions)
      ? String(r.teacher_portions)
      : "",
  }));
export const validCount = (s: string) =>
  /^\d+$/.test(s) && Number.isSafeInteger(Number(s));
const normalizeWeek = (s: string) => mondayOf(new Date(`${s}T12:00:00`));
const jsonRows = (rows: object[]) => rows as unknown as JsonValue[];
const networkFailure: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Kết nối bị gián đoạn." },
};
async function invoke(call: () => Promise<AtlasRpcResult>) {
  try {
    return await call();
  } catch {
    return networkFailure;
  }
}
const requiresReload = (r: AtlasRpcResult) =>
  r.kind === "transport_error" ||
  (r.kind === "backend_error" &&
    [
      "STALE_VERSION",
      "STALE_SOURCE_SIGNATURE",
      "SOURCE_SIGNATURE_MISMATCH",
      "PERSISTED_SIGNATURE_MISMATCH",
      "CHECKSUM_MISMATCH",
      "RETRYABLE_CONCURRENCY_FAILURE",
    ].includes(r.error.error_code));

export function usePlanningSources({
  api,
  pantryApi,
  authSubject,
  initialWeek = mondayOf(new Date()),
  initialJob = "menu",
}: PlanningSourcesProps) {
  const [week, setWeek] = useState(() => normalizeWeek(initialWeek));
  const [date, setDate] = useState(() => normalizeWeek(initialWeek));
  const [job, setJob] = useState<PlanningJob>(initialJob);
  const [schoolIds, setSchoolIds] = useState<string[]>([]);
  const [data, setData] = useState<PlanningInputsWorkbenchData | null>(null);
  const [pantryData, setPantryData] = useState<PantryWorkbenchData | null>(
    null,
  );
  const [menuRows, setMenuRows] = useState<MenuLine[]>([]);
  const [attendanceRows, setAttendanceRows] = useState<AttendanceDraft[]>([]);
  const [pantryRows, setPantryRows] = useState<PantryDraftRow[]>([]);
  const [modes, setModes] = useState<PantrySchoolDateMode[]>([]);
  const [noAdditions, setNoAdditions] = useState(false);
  const [menuSource, setMenuSource] = useState({
    type: "GOOGLE_SHEET",
    name: "",
  });
  const [menuCandidate, setMenuCandidate] = useState(false);
  const [attendanceSource, setAttendanceSource] = useState({
    type: "SCHOOL_DEFAULTS",
    name: "Mặc định theo Thực đơn tuần",
  });
  const [importErrors, setImportErrors] = useState<string[]>([]);
  const [importWarnings, setImportWarnings] = useState<string[]>([]);
  const [preview, setPreview] = useState<
    PlanningPreview<MenuLine | AttendanceLine> | PantryPreview | null
  >(null);
  const [impact, setImpact] = useState<PlanningCorrectionImpact | null>(null);
  const [pending, setPending] = useState<PlanningTransition | null>(null);
  const [sourceStates, setSourceStates] = useState<Record<Source, SourceState>>(
    { planning: initialSourceState, pantry: initialSourceState },
  );
  const source: Source = job === "pantry" ? "pantry" : "planning";
  const { loading, error: readError, recovery, outcome } = sourceStates[source];
  const locked = recovery !== null;
  const recoveryKind: PlanningRecoveryKind | null =
    recovery ?? (readError ? "READ_FAILURE" : null);
  const setOutcome = (outcome: string) =>
    setSourceStates((states) => ({
      ...states,
      [source]: { ...states[source], outcome },
    }));
  const setRecovery = (recovery: SourceState["recovery"]) =>
    setSourceStates((states) => ({
      ...states,
      [source]: { ...states[source], recovery },
    }));
  const [busy, setBusy] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const generation = useRef(0),
    googleGeneration = useRef(0),
    readGeneration = useRef({ planning: 0, pantry: 0 });
  const writeBusy = useRef(false);
  const clearReview = () => {
    setPreview(null);
    setImpact(null);
  };
  const resetPlanning = useCallback((p: PlanningInputsWorkbenchData | null) => {
    setMenuRows(activeMenuRows(p?.weekly_menu ?? null));
    setAttendanceRows(
      attendanceDraft(
        attendanceWorkingRows(
          p?.attendance ?? null,
          p?.default_attendance_preview ?? [],
        ),
      ),
    );
    setMenuSource({
      type: p?.weekly_menu?.source_type ?? "GOOGLE_SHEET",
      name: p?.weekly_menu?.source_name ?? "",
    });
    setMenuCandidate(false);
    setAttendanceSource({
      type: p?.attendance?.source_type ?? "SCHOOL_DEFAULTS",
      name: p?.attendance?.source_name ?? "Mặc định theo Thực đơn tuần",
    });
    setImportErrors([]);
    setImportWarnings([]);
  }, []);
  const resetPantry = useCallback((b: PantryWorkbenchData | null) => {
    setPantryRows(pantryRowsFromBatch(b?.batch ?? null));
    setModes(b?.batch?.school_date_modes ?? b?.school_date_modes ?? []);
    setNoAdditions(b?.batch?.no_additions_confirmed ?? false);
  }, []);
  const resetDrafts = (
    p: PlanningInputsWorkbenchData | null,
    b: PantryWorkbenchData | null,
  ) => {
    resetPlanning(p);
    resetPantry(b);
    clearReview();
  };
  const load = useCallback(
    async (targetWeek: string, target?: Source, recover = false) => {
      setPreview(null);
      setImpact(null);
      ++generation.current;
      ++googleGeneration.current;
      setSyncing(false);
      const sources: Source[] = target ? [target] : ["planning", "pantry"];
      await Promise.all(
        sources.map(async (current) => {
          const token = ++readGeneration.current[current];
          setSourceStates((states) => ({
            ...states,
            [current]: { ...states[current], loading: true, error: "" },
          }));
          const result = await invoke(() =>
            (current === "planning" ? api : pantryApi).getWorkbench(
              authSubject,
              crypto.randomUUID(),
              targetWeek,
            ),
          );
          if (token !== readGeneration.current[current]) return;
          const p =
            current === "planning" ? planningWorkbenchFromResult(result) : null;
          const b =
            current === "pantry" ? pantryWorkbenchFromResult(result) : null;
          const valid = (p ?? b)?.week_start === targetWeek;
          if (valid) {
            if (p) {
              setData(p);
              resetPlanning(p);
            }
            if (b) {
              setPantryData(b);
              resetPantry(b);
            }
          }
          setSourceStates((states) => ({
            ...states,
            [current]: {
              ...states[current],
              loading: false,
              error: valid
                ? ""
                : "Không tải được dữ liệu nguồn cho tuần đã chọn. Hãy thử tải lại.",
              ...(valid && recover ? { recovery: null, outcome: "" } : {}),
            },
          }));
        }),
      );
    },
    [api, pantryApi, authSubject, resetPlanning, resetPantry],
  );
  useEffect(() => {
    setData(null);
    setPantryData(null);
    resetPlanning(null);
    resetPantry(null);
    setPreview(null);
    setImpact(null);
    void load(week);
    return () => {
      ++readGeneration.current.planning;
      ++readGeneration.current.pantry;
      ++generation.current;
      ++googleGeneration.current;
    };
  }, [week, load, resetPlanning, resetPantry]);
  const authority = source === "planning" ? data : pantryData;
  const schools = authority?.schools ?? [];
  useEffect(() => {
    if (authority && !loading && !readError)
      setSchoolIds((ids) =>
        normalizePlanningSchoolScope(ids, authority.schools),
      );
  }, [authority, loading, readError]);

  const dirty =
    job === "menu"
      ? menuCandidate
      : job === "attendance"
        ? JSON.stringify(attendanceRows) !==
          JSON.stringify(
            attendanceDraft(
              attendanceWorkingRows(
                data?.attendance ?? null,
                data?.default_attendance_preview ?? [],
              ),
            ),
          )
        : JSON.stringify([
            pantryRows,
            pantryModesForRows(pantryRows, modes),
            noAdditions,
          ]) !==
          JSON.stringify([
            pantryRowsFromBatch(pantryData?.batch ?? null),
            pantryModesForRows(
              pantryRowsFromBatch(pantryData?.batch ?? null),
              pantryData?.batch?.school_date_modes ??
                pantryData?.school_date_modes ??
                [],
            ),
            pantryData?.batch?.no_additions_confirmed ?? false,
          ]);
  const candidate =
    dirty ||
    (job === "attendance" &&
      attendanceNeedsConfirmation(
        data?.attendance ?? null,
        data?.default_attendance_preview ?? [],
      ));
  const pantryRowErrors = pantryRows.map((r) => {
    const purpose = pantryData?.purposes.find(
      (p) => p.pantry_need_purpose_id === r.pantry_need_purpose_id,
    );
    return {
      ingredient: !r.ingredient_id ? "Chọn nguyên liệu." : "",
      purpose: !r.pantry_need_purpose_id ? "Chọn mục đích." : "",
      quantity: !r.requested_quantity.trim() ? "Nhập số lượng." : "",
      note:
        purpose?.note_rule === "REQUIRED" && !r.note.trim()
          ? "Cần ghi chú cho mục đích này."
          : purpose?.note_rule === "PROHIBITED" && r.note.trim()
            ? "Mục đích này không cho phép ghi chú."
            : "",
    };
  });
  const errors =
    job === "menu"
      ? importErrors
      : job === "attendance"
        ? attendanceRows.flatMap((r, i) => [
            ...(!validCount(r.student_portions) ||
            !validCount(r.teacher_portions)
              ? [
                  `Dòng ${i + 1}: nhập số nguyên không âm cho học sinh và giáo viên.`,
                ]
              : []),
            ...(!data?.schools.some((s) => s.school_id === r.school_id)
              ? [`Dòng ${i + 1}: chưa nhận diện được trường.`]
              : []),
            ...(r.service_date < week ||
            r.service_date > (data?.week_end ?? week)
              ? [`Dòng ${i + 1}: ngày phục vụ phải thuộc tuần đang chọn.`]
              : []),
          ])
        : pantryRowErrors.flatMap((row, i) =>
            Object.values(row)
              .filter(Boolean)
              .map((error) => `Dòng ${i + 1}: ${error}`),
          );
  const effectiveModes = pantryModesForRows(pantryRows, modes);
  const canEdit = !locked && !busy && !loading && !readError && !!authority;
  const applyTransition = (next: PlanningTransition) => {
    ++generation.current;
    ++googleGeneration.current;
    setSyncing(false);
    setBusy(false);
    clearReview();
    if (next.noAdditions !== undefined) {
      setPantryRows([]);
      setModes([]);
      setNoAdditions(next.noAdditions);
      return;
    }
    resetDrafts(data, pantryData);
    if (
      next.job === "menu" ||
      next.job === "attendance" ||
      next.job === "pantry"
    )
      setJob(next.job);
    if (next.week) {
      const w = normalizeWeek(next.week);
      setWeek(w);
      setDate(w);
    }
    if (
      next.date &&
      next.date >= week &&
      next.date <= (authority?.week_end ?? week)
    )
      setDate(next.date);
    if (next.schoolIds && authority && !readError)
      setSchoolIds(normalizePlanningSchoolScope(next.schoolIds, schools));
    if (next.refresh) void load(week);
  };
  const transition = (next: PlanningTransition) => {
    if (writeBusy.current) return;
    if (dirty) setPending(next);
    else applyTransition(next);
  };
  const markEdit = () => {
    ++generation.current;
    clearReview();
    setOutcome("");
  };
  const editAttendance = (
    index: number,
    field: "student_portions" | "teacher_portions",
    value: string,
  ) => {
    if (!canEdit) return;
    markEdit();
    setAttendanceSource({ type: "MANUAL", name: "Chỉnh sửa trực tiếp Atlas" });
    setAttendanceRows((rows) =>
      rows.map((r, i) => (i === index ? { ...r, [field]: value } : r)),
    );
  };
  const pasteAttendance = (value: string) => {
    if (!canEdit || !data) return;
    markEdit();
    setAttendanceSource({ type: "BULK_PASTE", name: "Dán hàng loạt Atlas" });
    setAttendanceRows(
      attendanceDraft(parseAttendancePaste(value, data.schools)),
    );
  };
  const addPantryRow = (schoolId: string) => {
    if (
      !canEdit ||
      noAdditions ||
      !pantryData?.schools.some(
        (s) => s.school_id === schoolId && s.school_status === "ACTIVE",
      )
    )
      return;
    markEdit();
    setPantryRows((rows) => [
      ...rows,
      {
        service_date: date,
        school_id: schoolId,
        ingredient_id: "",
        pantry_need_purpose_id: "",
        requested_quantity: "",
        note: "",
        source_request_reference: "",
        source_row_reference: `atlas:${crypto.randomUUID()}`,
      },
    ]);
  };
  const editPantryRow = (index: number, patch: Partial<PantryDraftRow>) => {
    if (!canEdit) return;
    markEdit();
    setPantryRows((rows) =>
      rows.map((r, i) => (i === index ? { ...r, ...patch } : r)),
    );
  };
  const removePantryRow = (index: number) => {
    if (!canEdit) return;
    markEdit();
    setPantryRows((rows) => rows.filter((_, i) => i !== index));
  };
  const setMode = (schoolId: string, mode: DirectNeedMode) => {
    if (!canEdit) return;
    markEdit();
    setModes((rows) => [
      ...rows.filter(
        (r) => r.school_id !== schoolId || r.service_date !== date,
      ),
      { school_id: schoolId, service_date: date, direct_need_mode: mode },
    ]);
  };
  const requestNoAdditions = (value: boolean) => {
    if (!canEdit || job !== "pantry" || schoolIds.length > 0) return;
    if (value && pantryRows.length) setPending({ noAdditions: true });
    else {
      markEdit();
      setNoAdditions(value);
    }
  };
  const syncGoogle = async (id: string) => {
    if (
      !canEdit ||
      !data?.google_sheet_sources.some(
        (s) =>
          s.weekly_menu_google_source_id === id && s.source_status === "ACTIVE",
      )
    )
      return;
    const token = ++googleGeneration.current,
      epoch = generation.current;
    setSyncing(true);
    clearReview();
    const result = await invoke(() =>
      api.syncMenuFromGoogle(id, week, crypto.randomUUID()),
    );
    if (token !== googleGeneration.current || epoch !== generation.current)
      return;
    if (result.kind !== "success") {
      setOutcome("Không tải được Google Sheet. Dữ liệu chưa được lưu.");
      setSyncing(false);
      return;
    }
    const source = result.response.source;
    if (
      !source ||
      typeof source !== "object" ||
      Array.isArray(source) ||
      typeof source.source_name !== "string" ||
      typeof source.sheet_name !== "string" ||
      !Array.isArray(result.response.rows) ||
      !result.response.rows.every(Array.isArray)
    ) {
      setOutcome("Google Sheet trả về dữ liệu không hợp lệ.");
      setSyncing(false);
      return;
    }
    try {
      const review = await parseMenuMatrix(
        result.response.rows as SourceMatrix,
        {
          sourceName: source.source_name,
          sheetName: source.sheet_name,
          firstRowNumber: 3,
        },
        data.dish_types,
        data.schools,
        data.dishes,
      );
      if (token !== googleGeneration.current || epoch !== generation.current)
        return;
      setMenuRows(review.rows);
      setMenuSource({ type: "GOOGLE_SHEET", name: review.sourceName });
      setMenuCandidate(true);
      setImportErrors(review.errors);
      setImportWarnings(review.warnings);
      setOutcome("");
    } catch {
      if (token === googleGeneration.current && epoch === generation.current)
        setOutcome("Không đọc được dữ liệu Google Sheet.");
    }
    if (token === googleGeneration.current && epoch === generation.current)
      setSyncing(false);
  };
  const payloadFor = (
    p: NonNullable<typeof preview>,
  ): Record<string, JsonValue> =>
    job === "pantry"
      ? {
          week_start: week,
          no_additions_confirmed: noAdditions,
          source_signature: p.source_signature,
          expected_source_signature:
            pantryData?.batch?.source_signature ?? null,
          rows: pantryRowsForWrite(pantryRows),
          school_date_modes: effectiveModes,
        }
      : {
          week_start: week,
          source_type: job === "menu" ? menuSource.type : attendanceSource.type,
          source_name: job === "menu" ? menuSource.name : attendanceSource.name,
          source_signature: p.source_signature,
          expected_source_signature:
            (job === "menu" ? data?.weekly_menu : data?.attendance)
              ?.source_signature ?? null,
          rows: p.canonical_rows as JsonValue[],
        };
  const recordFailure = (r: AtlasRpcResult) => {
    if (r.kind === "success") {
      setRecovery("UNKNOWN_OR_MISSING_READBACK");
      setOutcome("Chưa có dữ liệu xác nhận hợp lệ. Tải lại để xác nhận.");
    } else if (requiresReload(r)) {
      setRecovery(
        r.kind === "transport_error" ? "UNKNOWN_OR_MISSING_READBACK" : "STALE",
      );
      setOutcome(
        r.kind === "transport_error"
          ? "Chưa xác định kết quả thao tác. Tải lại để xác nhận."
          : "Dữ liệu nguồn đã thay đổi. Tải lại dữ liệu hiện tại.",
      );
    } else setOutcome(planningResultMessage(r));
  };
  const previewChanges = async () => {
    if (!canEdit || syncing || !candidate || errors.length) return;
    const epoch = ++generation.current;
    setBusy(true);
    clearReview();
    const result = await invoke(() =>
      job === "menu"
        ? api.previewMenu(
            authSubject,
            crypto.randomUUID(),
            week,
            jsonRows(menuRows),
          )
        : job === "attendance"
          ? api.previewAttendance(
              authSubject,
              crypto.randomUUID(),
              week,
              jsonRows(
                attendanceRows.map((r) => ({
                  ...r,
                  student_portions: Number(r.student_portions),
                  teacher_portions: Number(r.teacher_portions),
                })),
              ),
            )
          : pantryApi.preview(
              authSubject,
              crypto.randomUUID(),
              week,
              noAdditions,
              pantryRowsForWrite(pantryRows),
              effectiveModes,
            ),
    );
    if (epoch !== generation.current) return;
    const p =
      job === "pantry"
        ? pantryPreviewFromResult(result)
        : planningPreviewFromResult<MenuLine | AttendanceLine>(result);
    if (!p) {
      recordFailure(result);
      setBusy(false);
      return;
    }
    setPreview(p);
    if (p.can_save) {
      const target = job === "pantry" ? pantryApi : api;
      const response = await invoke(() =>
        target.getCorrectionImpact(
          authSubject,
          crypto.randomUUID(),
          job === "menu"
            ? "WEEKLY_MENU"
            : job === "attendance"
              ? "ATTENDANCE"
              : "PANTRY",
          payloadFor(p),
        ),
      );
      if (epoch !== generation.current) return;
      const nextImpact = planningCorrectionImpactFromResult(response);
      setImpact(nextImpact);
      if (!nextImpact) recordFailure(response);
      else setOutcome("");
    }
    setBusy(false);
  };
  const save = async () => {
    if (
      !canEdit ||
      writeBusy.current ||
      !preview?.can_save ||
      !impact?.save_allowed ||
      errors.length
    )
      return;
    writeBusy.current = true;
    setBusy(true);
    const p = payloadFor(preview);
    const result = await invoke(() =>
      job === "menu"
        ? api.saveCompletedMenu(
            weeklyMenuCompletionRequest(
              authSubject,
              crypto.randomUUID(),
              data?.weekly_menu?.version ?? 1,
              p as Parameters<typeof weeklyMenuCompletionRequest>[3],
            ),
          )
        : job === "attendance"
          ? api.saveCompletedAttendance(
              attendanceCompletionRequest(
                authSubject,
                crypto.randomUUID(),
                data?.attendance?.version ?? 1,
                p as Parameters<typeof attendanceCompletionRequest>[3],
              ),
            )
          : pantryApi.saveCompleted(
              pantryCompletionRequest(
                authSubject,
                crypto.randomUUID(),
                pantryData?.batch?.version ?? 1,
                p as Parameters<typeof pantryCompletionRequest>[3],
              ),
            ),
    );
    if (result.kind === "success") {
      const pRead =
        job !== "pantry" ? planningReadbackFromResult(result) : data;
      const bRead =
        job === "pantry" ? pantryReadbackFromResult(result) : pantryData;
      if ((job === "pantry" ? bRead : pRead)?.week_start === week) {
        ++readGeneration.current[source];
        if (job === "pantry") {
          setPantryData(bRead);
          resetPantry(bRead);
        } else {
          setData(pRead);
          resetPlanning(pRead);
        }
        clearReview();
        setOutcome("Đã lưu.");
      } else {
        setRecovery("UNKNOWN_OR_MISSING_READBACK");
        setOutcome(
          "Chưa có dữ liệu xác nhận sau khi lưu. Tải lại để xác nhận.",
        );
      }
    } else recordFailure(result);
    writeBusy.current = false;
    setBusy(false);
  };
  const prepareCorrection = async (chain: PlanningCorrectionChain) => {
    if (
      !canEdit ||
      writeBusy.current ||
      !impact?.date_impacts.some(
        (d) =>
          [
            "PLANNING_RELEASE_CORRECTION_REQUIRED",
            "LEGACY_RANGE_CORRECTION_REQUIRED",
          ].includes(d.correction_policy) &&
          d.chains.some(
            (c) =>
              c.need_generation_run_id === chain.need_generation_run_id &&
              c.confirmed_need_batch_id,
          ),
      )
    )
      return;
    writeBusy.current = true;
    setBusy(true);
    clearReview();
    const result = await invoke(() =>
      (job === "pantry" ? pantryApi : api).prepareCorrection(
        authSubject,
        crypto.randomUUID(),
        chain,
        "Hiệu chỉnh nguồn Kế hoạch sau khi rà soát ảnh hưởng.",
      ),
    );
    writeBusy.current = false;
    setBusy(false);
    if (result.kind === "success") await previewChanges();
    else recordFailure(result);
  };
  return {
    week,
    date,
    job,
    schoolIds,
    schools,
    authority,
    recoveryKind,
    pantryRowErrors,
    data,
    pantryData,
    menuRows,
    attendanceRows,
    pantryRows,
    modes: effectiveModes,
    noAdditions,
    menuSource,
    dirty,
    candidate,
    errors,
    importWarnings,
    preview,
    impact,
    pending,
    locked,
    outcome,
    readError,
    loading,
    busy,
    syncing,
    canEdit,
    transition,
    cancelTransition: () => setPending(null),
    discardTransition: () => {
      if (pending) applyTransition(pending);
      setPending(null);
    },
    editAttendance,
    pasteAttendance,
    addPantryRow,
    editPantryRow,
    removePantryRow,
    setMode,
    requestNoAdditions,
    syncGoogle,
    previewChanges,
    save,
    prepareCorrection,
    closeReview: clearReview,
    recover: () => load(week, source, true),
    previousAttendance: activeAttendanceRows(data?.attendance ?? null),
  };
}
export type PlanningSourcesController = ReturnType<typeof usePlanningSources>;
