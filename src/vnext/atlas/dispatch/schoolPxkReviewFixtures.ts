import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  SchoolDispatchDocument,
  SchoolDispatchReleaseApi,
  SchoolDispatchWorkbenchData,
  SchoolDispatchWorkbenchRow,
} from "../bridges/schoolDispatch";
export const reviewDate = "2026-09-24";
export type SchoolPxkScenario =
  | "READY"
  | "CURRENT"
  | "REPLACEMENT_REQUIRED"
  | "BLOCKED"
  | "EMPTY"
  | "PERMISSION_DENIED"
  | "READ_FAILURE"
  | "STALE"
  | "SOURCE_CHANGED"
  | "PXK_NOT_READY"
  | "UNKNOWN_RELEASE"
  | "SUCCESS_THEN_READBACK_FAILURE"
  | "MULTIPLE_SCHOOLS"
  | "MULTIPLE_INGREDIENTS"
  | "HISTORY_WITH_SUPERSEDED"
  | "EXPORT_READY"
  | "DIRTY_NOTE";
export function pxkSuccess(value: unknown): AtlasRpcResult {
  return { kind: "success", response: value as AtlasSuccessEnvelope };
}
export function pxkFailure(code = "CAPABILITY_DENIED"): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: code,
      safe_message:
        code === "CAPABILITY_DENIED"
          ? "Bạn không có quyền thực hiện thao tác này."
          : "Nguồn phiếu đã thay đổi. Hãy tải lại dữ liệu hiện tại.",
    },
  };
}
export function pxkUnknown(): AtlasRpcResult {
  return {
    kind: "transport_error",
    diagnostic: {
      code: "NETWORK_FAILURE",
      safeMessage: "Không thể kết nối hệ thống.",
    },
  };
}
export function pxkRow(
  state: SchoolDispatchWorkbenchRow["state"] = "READY",
  index = 1,
): SchoolDispatchWorkbenchRow {
  const lines = ["Gạo thơm", "Thịt heo", "Cà rốt"].map(
    (ingredient_name, i) => ({
      ingredient_id: `ingredient-${i}`,
      ingredient_name,
      unit_id: "unit-kg",
      unit_code: "kg",
      quantity: ["100.000000", "48.500000", "25.750000"][i]!,
      sources: [],
    }),
  );
  const preview = {
    service_date: reviewDate,
    school_id: `school-${index}`,
    delivery_location_id: `location-${index}`,
    school_name:
      [
        "Trường Tiểu học Nguyễn Du",
        "Trường Mầm non Hoa Sen",
        "Trường Tiểu học và Trung học cơ sở Nguyễn Thị Minh Khai",
      ][(index - 1) % 3]! + (index > 3 ? ` · Cơ sở ${index}` : ""),
    delivery_location_name: "Bếp chính",
    delivery_address: `${index} Nguyễn Du, phường Bến Thành`,
    source_fingerprint: `source-new-${index}`,
    ready: state !== "BLOCKED",
    lines,
    blockers: state === "BLOCKED" ? ["CANCELLATION_REQUIRED"] : [],
    warnings: [],
  };
  const document: SchoolDispatchDocument = {
    ...preview,
    school_dispatch_release_id: `release-${index}`,
    status: "RELEASED",
    document_number: `PXK-20260924-${String(index).padStart(4, "0")}`,
    source_fingerprint:
      state === "REPLACEMENT_REQUIRED"
        ? `source-old-${index}`
        : preview.source_fingerprint,
    predecessor_release_id: null,
    note: "Giao tại cổng phụ trước 06:00",
    version: 1,
    released_by_actor_id: "actor-1",
    released_at: "2026-09-23T08:00:00.000Z",
    export_ready: true,
    lines:
      state === "REPLACEMENT_REQUIRED"
        ? [{ ...lines[0]!, quantity: "90.000000" }]
        : lines,
  };
  const current =
    state === "CURRENT" || state === "REPLACEMENT_REQUIRED" ? document : null;
  return {
    service_date: reviewDate,
    school_id: preview.school_id,
    delivery_location_id: preview.delivery_location_id,
    state,
    expected_version: current ? 1 : 0,
    preview,
    current_release: current,
    history: current ? [current] : [],
    allowed_actions: {
      release: state === "READY",
      replace: state === "REPLACEMENT_REQUIRED",
      export: Boolean(current),
    },
    blockers: preview.blockers,
    warnings: [],
  };
}
export function pxkData(
  rows = [pxkRow()],
  date = reviewDate,
): SchoolDispatchWorkbenchData {
  return {
    success: true,
    contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
    date_start: date,
    date_end: date,
    rows,
    blockers: [],
    warnings: [],
  };
}
/** In-memory review adapter only. No hosted client, transport, or business writes. */
export function createSchoolPxkReviewFixture(
  scenario: SchoolPxkScenario = "READY",
): SchoolDispatchReleaseApi {
  const state = ["CURRENT", "EXPORT_READY", "HISTORY_WITH_SUPERSEDED"].includes(
    scenario,
  )
    ? "CURRENT"
    : scenario === "REPLACEMENT_REQUIRED"
      ? "REPLACEMENT_REQUIRED"
      : scenario === "BLOCKED"
        ? "BLOCKED"
        : "READY";
  let rows =
    scenario === "EMPTY"
      ? []
      : scenario === "MULTIPLE_SCHOOLS"
        ? Array.from({ length: 18 }, (_, i) =>
            pxkRow(
              (
                ["CURRENT", "READY", "BLOCKED", "REPLACEMENT_REQUIRED"] as const
              )[i % 4],
              i + 1,
            ),
          )
        : [pxkRow(state)];
  if (scenario === "HISTORY_WITH_SUPERSEDED") {
    rows[0]!.history.push({
      ...rows[0]!.current_release!,
      school_dispatch_release_id: "old-release",
      document_number: "PXK-20260924-0000",
      status: "SUPERSEDED",
      note: "Phiếu trước khi điều chỉnh",
    });
  }
  let wrote = false;
  return {
    async getWorkbench(request) {
      if (scenario === "PERMISSION_DENIED") return pxkFailure();
      if (
        scenario === "READ_FAILURE" ||
        (wrote && scenario === "SUCCESS_THEN_READBACK_FAILURE")
      )
        return pxkUnknown();
      const scope = request.payload as {
        date_start: string;
        school_ids: string[];
      };
      const scoped = rows
        .filter(
          (r) =>
            !scope.school_ids.length || scope.school_ids.includes(r.school_id),
        )
        .map((r) => ({
          ...r,
          service_date: scope.date_start,
          preview: { ...r.preview, service_date: scope.date_start },
          current_release: r.current_release
            ? { ...r.current_release, service_date: scope.date_start }
            : null,
        }));
      return pxkSuccess(pxkData(scoped, scope.date_start));
    },
    async releaseDocument(request) {
      if (scenario === "UNKNOWN_RELEASE") return pxkUnknown();
      if (["STALE", "SOURCE_CHANGED", "PXK_NOT_READY"].includes(scenario))
        return pxkFailure(scenario === "STALE" ? "STALE_VERSION" : scenario);
      wrote = true;
      rows = rows.map((r) => {
        if (
          r.school_id !== request.payload.school_id ||
          r.delivery_location_id !== request.payload.delivery_location_id
        )
          return r;
        const previous = r.current_release;
        const current: SchoolDispatchDocument = {
          ...pxkRow("CURRENT").current_release!,
          ...r.preview,
          school_dispatch_release_id: previous
            ? "successor-release"
            : "initial-release",
          document_number: previous ? "PXK-20260924-0020" : "PXK-20260924-0019",
          status: "RELEASED",
          predecessor_release_id: request.payload.predecessor_release_id,
          note: request.reason_note,
          version: r.expected_version + 1,
        };
        return {
          ...r,
          state: "CURRENT",
          current_release: current,
          expected_version: current.version,
          history: [
            current,
            ...r.history.map((d) => ({ ...d, status: "SUPERSEDED" as const })),
          ],
          allowed_actions: { release: false, replace: false, export: true },
        };
      });
      return pxkSuccess({ success: true });
    },
  };
}
