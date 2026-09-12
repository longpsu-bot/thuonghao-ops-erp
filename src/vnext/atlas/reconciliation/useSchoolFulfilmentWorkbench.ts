import { useCallback, useEffect, useRef, useState } from "react";
import {
  schoolFulfilmentReadRequest,
  type SchoolFulfilmentReconciliationApi,
  type SchoolFulfilmentRow,
  type SchoolFulfilmentWorkbenchData,
} from "../bridges/schoolFulfilment";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import {
  isSchoolFulfilmentAuthority,
  reconciliationRangeError,
} from "./schoolFulfilmentAuthority";
type School = { school_id: string; school_name: string };
export type SchoolFulfilmentWorkbenchProps = {
  api: SchoolFulfilmentReconciliationApi;
  authSubject: string | null;
  initialDateStart: string;
  initialDateEnd: string;
  schools?: School[];
};
export const fulfilmentRowKey = (r: SchoolFulfilmentRow) =>
  JSON.stringify([r.service_date, r.school_id, r.delivery_location_id]);
export function useSchoolFulfilmentWorkbench({
  api,
  authSubject,
  initialDateStart,
  initialDateEnd,
  schools: externalSchools,
}: SchoolFulfilmentWorkbenchProps) {
  const [dateStart, updateStart] = useState(initialDateStart);
  const [dateEnd, updateEnd] = useState(initialDateEnd);
  const [schoolIds, setSchoolIds] = useState<string[]>([]);
  const [catalogue, setCatalogue] = useState<{
    subject: string;
    schools: School[];
  } | null>(null);
  const schools = authSubject
    ? (externalSchools ??
      (catalogue?.subject === authSubject ? catalogue.schools : []))
    : [];
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("exceptions");
  const [selection, setSelection] = useState<string | null>(null);
  const [loaded, setLoaded] = useState<{
    scope: string;
    data: SchoolFulfilmentWorkbenchData;
  } | null>(null);
  const [loading, setLoading] = useState(false);
  const [readError, setReadError] = useState<string | null>(null);
  const scope = JSON.stringify([authSubject, dateStart, dateEnd, schoolIds]);
  const live = useRef({ scope, api });
  live.current = { scope, api };
  const generation = useRef(0);
  const rangeError = reconciliationRangeError(dateStart, dateEnd);
  const invalidate = () => {
    generation.current++;
    setLoaded(null);
    setSelection(null);
  };
  const read = useCallback(async () => {
    const intent = ++generation.current;
    setLoaded(null);
    setSelection(null);
    setReadError(null);
    if (rangeError || !authSubject) {
      setLoading(false);
      return;
    }
    setLoading(true);
    const active = () =>
      generation.current === intent &&
      live.current.scope === scope &&
      live.current.api === api;
    const requestScope = {
      date_start: dateStart,
      date_end: dateEnd,
      school_ids: schoolIds,
      search: null,
    };
    try {
      const result = await api.getWorkbench(
        schoolFulfilmentReadRequest(
          authSubject,
          crypto.randomUUID(),
          requestScope,
        ),
      );
      if (!active()) return;
      if (result.kind !== "success") {
        setReadError(
          result.kind === "backend_error"
            ? result.error.safe_message
            : result.diagnostic.safeMessage,
        );
        return;
      }
      if (!isSchoolFulfilmentAuthority(result.response, requestScope)) {
        setReadError("Dữ liệu chưa khớp phạm vi đã chọn. Hãy thử tải lại.");
        return;
      }
      const data = result.response;
      setLoaded({ scope, data });
      if (!schoolIds.length)
        setCatalogue((previous) => ({
          subject: authSubject,
          schools: Array.from(
            new Map([
              ...(previous?.subject === authSubject
                ? previous.schools
                : []
              ).map((s) => [s.school_id, s] as const),
              ...data.rows.map(
                (r) =>
                  [
                    r.school_id,
                    { school_id: r.school_id, school_name: r.school_name },
                  ] as const,
              ),
            ]).values(),
          ),
        }));
    } catch {
      if (active()) setReadError("Không thể tải dữ liệu. Vui lòng thử lại.");
    } finally {
      if (active()) setLoading(false);
    }
  }, [api, authSubject, dateStart, dateEnd, schoolIds, scope, rangeError]);
  useEffect(() => {
    void read();
    return () => {
      generation.current++;
    };
  }, [read]);
  const data = loaded?.scope === scope ? loaded.data : null;
  const rows = data?.rows ?? [];
  const visibleRows = rows
    .filter(
      (r) =>
        (filter === "all" ||
          (filter === "exceptions"
            ? r.comparison_status !== "OK"
            : r.comparison_status === filter)) &&
        foldVietnameseSearch(
          [
            r.school_name,
            r.delivery_location_name,
            ...r.purchase_order_numbers,
            r.pxk_document_number,
            ...r.details.flatMap((d) => [d.ingredient_name, d.unit_code]),
            ...r.quantity_totals_by_unit.map((t) => t.unit_code),
          ].join(" "),
        ).includes(foldVietnameseSearch(search)),
    )
    .sort(
      (a, b) =>
        (a.comparison_status === "OK" ? 1 : 0) -
        (b.comparison_status === "OK" ? 1 : 0),
    );
  const selected =
    visibleRows.find((r) => fulfilmentRowKey(r) === selection) ?? null;
  useEffect(() => {
    if (selection && !selected) setSelection(null);
  }, [selection, selected]);
  return {
    dateStart,
    dateEnd,
    schoolIds,
    schools,
    search,
    setSearch,
    filter,
    setFilter,
    rows,
    visibleRows,
    selected,
    loading,
    readError,
    rangeError,
    blockers: data?.blockers ?? [],
    warnings: data?.warnings ?? [],
    setDateStart: (value: string) => {
      if (value !== dateStart) {
        invalidate();
        updateStart(value);
      }
    },
    setDateEnd: (value: string) => {
      if (value !== dateEnd) {
        invalidate();
        updateEnd(value);
      }
    },
    applySchools: (values: string[]) => {
      const ids = [...new Set(values)].sort();
      const normalized =
        ids.length === schools.length &&
        schools.every((s) => ids.includes(s.school_id))
          ? []
          : ids;
      if (JSON.stringify(normalized) !== JSON.stringify(schoolIds)) {
        invalidate();
        setSchoolIds(normalized);
      }
    },
    select: (row: SchoolFulfilmentRow | null) =>
      setSelection(row ? fulfilmentRowKey(row) : null),
    refresh: () => {
      void read();
    },
  };
}
