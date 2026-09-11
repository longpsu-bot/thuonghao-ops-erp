import { useCallback, useEffect, useRef, useState } from "react";
import {
  releaseSchoolDispatchDocumentRequest,
  schoolDispatchReleaseReadRequest,
  type AtlasRpcResult,
  type ReleaseSchoolDispatchDocumentRequest,
  type SchoolDispatchDocument,
  type SchoolDispatchReleaseApi,
  type SchoolDispatchWorkbenchData,
  type SchoolDispatchWorkbenchRow,
} from "../bridges/schoolDispatch";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
export type SchoolPxkWorkbenchProps = {
  api: SchoolDispatchReleaseApi;
  authSubject: string | null;
  initialServiceDate: string;
  schools?: { school_id: string; school_name: string }[];
  onExportXlsx?: (document: SchoolDispatchDocument) => void | Promise<void>;
  onExportPdf?: (document: SchoolDispatchDocument) => void | Promise<void>;
};
type Transition = {
  date?: string;
  schoolIds?: string[];
  selectedKey?: string | null;
  refresh?: boolean;
};
export const schoolPxkRowKey = (
  r: Pick<
    SchoolDispatchWorkbenchRow,
    "service_date" | "school_id" | "delivery_location_id"
  >,
) => JSON.stringify([r.service_date, r.school_id, r.delivery_location_id]);
const priority = { REPLACEMENT_REQUIRED: 0, BLOCKED: 1, READY: 2, CURRENT: 3 };
const safeMessage = (r: AtlasRpcResult) =>
  r.kind === "backend_error"
    ? r.error.safe_message
    : r.kind === "success"
      ? "Không thể xác nhận dữ liệu hiện tại."
      : r.diagnostic.safeMessage;
function provesRelease(
  data: SchoolDispatchWorkbenchData,
  request: ReleaseSchoolDispatchDocumentRequest,
) {
  const row = data.rows.find(
    (r) => schoolPxkRowKey(r) === schoolPxkRowKey(request.payload),
  );
  const doc = row?.current_release;
  const predecessor = request.payload.predecessor_release_id;
  return Boolean(
    doc &&
    doc.status === "RELEASED" &&
    schoolPxkRowKey(doc) === schoolPxkRowKey(request.payload) &&
    doc.source_fingerprint === request.payload.expected_source_fingerprint &&
    doc.predecessor_release_id === predecessor &&
    (!predecessor ||
      (doc.school_dispatch_release_id !== predecessor &&
        row?.history.some(
          (d) =>
            d.school_dispatch_release_id === predecessor &&
            d.status === "SUPERSEDED",
        ))),
  );
}
export function useSchoolPxkWorkbench({
  api,
  authSubject,
  initialServiceDate,
  schools: externalSchools,
}: SchoolPxkWorkbenchProps) {
  const [date, setDate] = useState(initialServiceDate);
  const [schoolIds, setSchoolIds] = useState<string[]>([]);
  const [catalogue, setCatalogue] = useState<{
    subject: string;
    schools: { school_id: string; school_name: string }[];
  } | null>(null);
  const schools =
    externalSchools ??
    (catalogue?.subject === authSubject ? catalogue.schools : []);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const [data, setData] = useState<SchoolDispatchWorkbenchData | null>(null);
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [note, setNote] = useState("");
  const [pendingTransition, setPendingTransition] = useState<Transition | null>(
    null,
  );
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [readError, setReadError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [lock, setLock] = useState<"unknown" | "stale" | null>(null);
  const [loadedScope, setLoadedScope] = useState<string | null>(null);
  const [correlationId] = useState(() => crypto.randomUUID());
  const scope = JSON.stringify([authSubject, date, schoolIds]);
  const live = useRef({ scope, api });
  live.current = { scope, api };
  const generation = useRef(0);
  const authority = useRef<string | null>(null);
  const writing = useRef(false);
  const locked = useRef(false);
  const proof = useRef<ReleaseSchoolDispatchDocumentRequest | null>(null);
  const commandContext = useRef<{
    scope: string;
    rowKey: string;
    request: ReleaseSchoolDispatchDocumentRequest;
  } | null>(null);
  const invalidate = () => {
    authority.current = null;
    setLoadedScope(null);
    generation.current++;
  };
  const read =
    useCallback(async (): Promise<SchoolDispatchWorkbenchData | null> => {
      authority.current = null;
      setLoadedScope(null);
      const intent = ++generation.current;
      setLoading(true);
      setReadError(null);
      if (!authSubject) {
        setData(null);
        setLoading(false);
        setReadError("Đăng nhập để xem Phiếu xuất kho.");
        return null;
      }
      const active = () =>
        intent === generation.current &&
        live.current.scope === scope &&
        live.current.api === api;
      try {
        const result = await api.getWorkbench(
          schoolDispatchReleaseReadRequest(authSubject, correlationId, {
            date_start: date,
            date_end: date,
            school_ids: schoolIds,
            search: null,
          }),
        );
        if (!active()) return null;
        if (result.kind !== "success") {
          setReadError(safeMessage(result));
          return null;
        }
        const next = result.response as unknown as SchoolDispatchWorkbenchData;
        if (
          next.contract_version !== "SCHOOL-DISPATCH-RELEASE.v1" ||
          next.success !== true ||
          next.date_start !== date ||
          next.date_end !== date ||
          !Array.isArray(next.rows) ||
          next.rows.some(
            (r) =>
              r.service_date !== date ||
              (schoolIds.length && !schoolIds.includes(r.school_id)) ||
              schoolPxkRowKey(r.preview) !== schoolPxkRowKey(r),
          )
        ) {
          setReadError("Dữ liệu chưa khớp phạm vi đã chọn. Hãy thử tải lại.");
          return null;
        }
        setData(next);
        setLoadedScope(scope);
        authority.current = scope;
        if (!schoolIds.length)
          setCatalogue((previous) => ({
            subject: authSubject,
            schools: Array.from(
              new Map([
                ...(previous?.subject === authSubject
                  ? previous.schools
                  : []
                ).map((s) => [s.school_id, s] as const),
                ...next.rows.map(
                  (r) =>
                    [
                      r.school_id,
                      {
                        school_id: r.school_id,
                        school_name: r.preview.school_name,
                      },
                    ] as const,
                ),
              ]).values(),
            ),
          }));
        setSelectedKey((current) =>
          next.rows.some((r) => schoolPxkRowKey(r) === current)
            ? current
            : null,
        );
        return next;
      } catch {
        if (active()) setReadError("Không thể tải dữ liệu. Vui lòng thử lại.");
        return null;
      } finally {
        if (active()) setLoading(false);
      }
    }, [api, authSubject, correlationId, date, schoolIds, scope]);
  useEffect(() => {
    setData(null);
    setSelectedKey(null);
    void read();
    return () => {
      generation.current++;
      authority.current = null;
    };
  }, [read]);
  const rows = data?.rows ?? [];
  const selected = rows.find((r) => schoolPxkRowKey(r) === selectedKey) ?? null;
  const actionAllowed = Boolean(
    selected &&
    ((selected.state === "READY" &&
      !selected.current_release &&
      selected.allowed_actions.release) ||
      (selected.state === "REPLACEMENT_REQUIRED" &&
        selected.current_release &&
        selected.allowed_actions.replace)),
  );
  const canRelease =
    actionAllowed &&
    Boolean(authSubject) &&
    loadedScope === scope &&
    !loading &&
    !busy &&
    !lock;
  const visibleRows = rows
    .filter(
      (r) =>
        (filter === "all" || r.state === filter) &&
        foldVietnameseSearch(
          [
            r.preview.school_name,
            r.preview.delivery_location_name,
            r.current_release?.document_number,
            ...r.preview.lines.map((l) => l.ingredient_name),
            ...(r.current_release?.lines ?? []).map((l) => l.ingredient_name),
          ].join(" "),
        ).includes(foldVietnameseSearch(search)),
    )
    .sort((a, b) => priority[a.state] - priority[b.state]);
  const apply = (next: Transition) => {
    if (next.date || next.schoolIds || next.refresh) invalidate();
    if (next.date) {
      setDate(next.date);
      setSelectedKey(null);
    }
    if (next.schoolIds) {
      const ids = [...new Set(next.schoolIds)].sort();
      setSchoolIds(
        ids.length === schools.length &&
          schools.every((s) => ids.includes(s.school_id))
          ? []
          : ids,
      );
      setSelectedKey(null);
    }
    if ("selectedKey" in next) setSelectedKey(next.selectedKey ?? null);
    if (next.refresh) void read();
  };
  const transition = (next: Transition) => {
    if (writing.current || locked.current) return;
    if (Object.keys(next).length === 1 && next.date === date) return;
    if (
      Object.keys(next).length === 1 &&
      "selectedKey" in next &&
      next.selectedKey === selectedKey
    )
      return;
    if (note.trim()) {
      setPendingTransition(next);
      return;
    }
    setNote("");
    apply(next);
  };
  const release = async () => {
    if (
      !canRelease ||
      !selected ||
      !authSubject ||
      authority.current !== scope ||
      live.current.scope !== scope ||
      writing.current ||
      locked.current ||
      note.length > 500
    )
      return;
    writing.current = true;
    setBusy(true);
    setNotice(null);
    const request = releaseSchoolDispatchDocumentRequest(
      authSubject,
      correlationId,
      selected.expected_version,
      {
        service_date: selected.service_date,
        school_id: selected.school_id,
        delivery_location_id: selected.delivery_location_id,
        expected_source_fingerprint: selected.preview.source_fingerprint,
        predecessor_release_id:
          selected.state === "REPLACEMENT_REQUIRED"
            ? selected.current_release!.school_dispatch_release_id
            : null,
      },
      note,
    );
    commandContext.current = {
      scope,
      rowKey: schoolPxkRowKey(selected),
      request,
    };
    invalidate();
    const uncertain = () => {
      locked.current = true;
      setLock("unknown");
      setNotice("Kết quả phát hành chưa được xác nhận.");
    };
    try {
      const result = await api.releaseDocument(request);
      if (result.kind === "transport_error") {
        uncertain();
        return;
      }
      if (result.kind !== "success") {
        locked.current = true;
        setLock("stale");
        setNotice(safeMessage(result));
        return;
      }
      proof.current = request;
      const next = await read();
      if (
        !next ||
        live.current.scope !== scope ||
        !provesRelease(next, request)
      ) {
        uncertain();
        return;
      }
      proof.current = null;
      commandContext.current = null;
      setNote("");
      setNotice("Đã xác nhận phiếu xuất kho chính thức.");
    } catch {
      uncertain();
    } finally {
      writing.current = false;
      setBusy(false);
    }
  };
  const recover = async () => {
    if (writing.current || loading) return;
    const next = await read();
    if (!next) return;
    const context = commandContext.current;
    if (
      context &&
      (context.scope !== scope ||
        !next.rows.some((r) => schoolPxkRowKey(r) === context.rowKey))
    )
      return;
    if (proof.current && !provesRelease(next, proof.current)) return;
    if (
      proof.current ||
      (context &&
        provesRelease(next, context.request) &&
        next.rows.find((r) => schoolPxkRowKey(r) === context.rowKey)
          ?.current_release?.note === context.request.reason_note)
    )
      setNote("");
    proof.current = null;
    commandContext.current = null;
    locked.current = false;
    setLock(null);
    setNotice("Đã tải lại dữ liệu hiện tại.");
  };
  return {
    date,
    schoolIds,
    schools,
    search,
    setSearch,
    filter,
    setFilter,
    rows,
    visibleRows,
    selected,
    selectedKey,
    note,
    setNote,
    loading,
    busy,
    readError,
    notice,
    lock,
    canRelease,
    actionAllowed,
    pendingTransition,
    key: schoolPxkRowKey,
    transition,
    release,
    recover,
    cancelTransition: () => setPendingTransition(null),
    discardTransition: () => {
      const next = pendingTransition;
      setPendingTransition(null);
      setNote("");
      if (next) apply(next);
    },
  };
}
