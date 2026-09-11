import type {
  SchoolFulfilmentReconciliationApi,
  SchoolFulfilmentRow,
  SchoolFulfilmentWorkbenchData,
  SchoolFulfilmentScope,
} from "../bridges/schoolFulfilment";
import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
} from "../bridges/schoolDispatch";
export const reviewDate = "2026-09-24";
const kg = {
  unit_id: "unit-kg",
  unit_code: "kg",
  po_quantity: "100.000000",
  pxk_quantity: "98.000000",
  delta_quantity: "2.000000",
};
export function fulfilmentRow(
  overrides: Partial<SchoolFulfilmentRow> = {},
): SchoolFulfilmentRow {
  return {
    service_date: reviewDate,
    school_id: "school-a",
    school_name: "Trường Tiểu học Nguyễn Du",
    delivery_location_id: "location-a",
    delivery_location_name: "Bếp chính Nguyễn Du",
    comparison_status: "MISMATCH",
    quantity_totals_by_unit: [{ ...kg }],
    purchase_order_numbers: ["PO-20260924-A", "PO-20260924-B"],
    purchase_order_ids: ["technical-po-id"],
    pxk_document_number: "PXK-20260924-A",
    school_dispatch_release_id: "technical-pxk-id",
    pxk_state: "CURRENT",
    blockers: [],
    warnings: [],
    details: [
      { ...kg, ingredient_id: "ingredient-rice", ingredient_name: "Gạo thơm" },
    ],
    history: [],
    ...overrides,
  };
}
export function fulfilmentData(
  rows: SchoolFulfilmentRow[],
  start = reviewDate,
  end = reviewDate,
): SchoolFulfilmentWorkbenchData {
  return {
    success: true,
    contract_version: "SCHOOL-FULFILMENT-RECONCILIATION.v1",
    date_start: start,
    date_end: end,
    rows,
    warnings: [],
    blockers: [],
  };
}
export function fulfilmentSuccess(
  data: SchoolFulfilmentWorkbenchData,
): AtlasRpcResult {
  return { kind: "success", response: data as unknown as AtlasSuccessEnvelope };
}
export type SchoolFulfilmentScenario =
  | "ALL"
  | "OK"
  | "NO_PO"
  | "NO_PXK"
  | "INGREDIENT_CHANGED"
  | "MISMATCH"
  | "MIXED_UNITS"
  | "PXK_READY"
  | "PXK_CURRENT"
  | "PXK_REPLACEMENT_REQUIRED"
  | "PXK_BLOCKED"
  | "OPERATIONAL_BLOCKER"
  | "WARNING"
  | "MULTIPLE_SCHOOLS"
  | "MULTIPLE_DATES"
  | "MULTIPLE_PO_DOCUMENTS"
  | "EMPTY"
  | "PERMISSION_DENIED"
  | "READ_FAILURE"
  | "STALE_OLD_RESPONSE";
// Explicit authoritative snapshots: no comparison algorithm or hosted client.
function snapshots(scenario: SchoolFulfilmentScenario): SchoolFulfilmentRow[] {
  const ok = fulfilmentRow({
    comparison_status: "OK",
    school_id: "school-b",
    school_name: "Trường Mầm non Hoa Sen",
    delivery_location_id: "location-b",
    delivery_location_name: "Bếp Hoa Sen",
    quantity_totals_by_unit: [
      { ...kg, pxk_quantity: "100.000000", delta_quantity: "0.000000" },
    ],
    details: [
      {
        ...kg,
        pxk_quantity: "100.000000",
        delta_quantity: "0.000000",
        ingredient_id: "ingredient-rice",
        ingredient_name: "Gạo thơm",
      },
    ],
  });
  const noPo = fulfilmentRow({
    school_id: "school-c",
    school_name: "Trường Tiểu học Lê Quý Đôn",
    delivery_location_name: "Bếp Lê Quý Đôn",
    pxk_document_number: "PXK-20260924-C",
    comparison_status: "NO_PO",
    purchase_order_numbers: [],
    purchase_order_ids: [],
    pxk_state: "BLOCKED",
    blockers: ["PO_COVERAGE_INCOMPLETE"],
    quantity_totals_by_unit: [
      { ...kg, po_quantity: "0.000000", delta_quantity: "-98.000000" },
    ],
    details: [
      {
        ...kg,
        po_quantity: "0.000000",
        delta_quantity: "-98.000000",
        ingredient_id: "ingredient-rice",
        ingredient_name: "Gạo thơm",
      },
    ],
  });
  const changed = fulfilmentRow({
    school_id: "school-d",
    school_name: "Trường THCS Nguyễn Trãi",
    delivery_location_name: "Bếp Nguyễn Trãi",
    pxk_document_number: "PXK-20260924-D",
    comparison_status: "INGREDIENT_CHANGED",
    quantity_totals_by_unit: [
      { ...kg, pxk_quantity: "100.000000", delta_quantity: "0.000000" },
    ],
    details: [
      {
        ...kg,
        pxk_quantity: "0.000000",
        delta_quantity: "100.000000",
        ingredient_id: "ingredient-rice",
        ingredient_name: "Gạo thơm",
      },
      {
        ...kg,
        po_quantity: "0.000000",
        pxk_quantity: "100.000000",
        delta_quantity: "-100.000000",
        ingredient_id: "ingredient-brown-rice",
        ingredient_name: "Gạo lứt",
      },
    ],
  });
  const noPxk = fulfilmentRow({
    school_id: "school-e",
    school_name: "Trường Tiểu học và Trung học cơ sở Đoàn Thị Điểm",
    delivery_location_name: "Bếp Đoàn Thị Điểm",
    comparison_status: "NO_PXK",
    pxk_state: "READY",
    pxk_document_number: null,
    school_dispatch_release_id: null,
    quantity_totals_by_unit: [
      { ...kg, pxk_quantity: "0.000000", delta_quantity: "100.000000" },
    ],
    details: [
      {
        ...kg,
        pxk_quantity: "0.000000",
        delta_quantity: "100.000000",
        ingredient_id: "ingredient-rice",
        ingredient_name: "Gạo thơm",
      },
    ],
  });
  if (scenario === "EMPTY") return [];
  if (scenario === "OK" || scenario === "PXK_CURRENT") return [ok];
  if (scenario === "NO_PO") return [noPo];
  if (scenario === "NO_PXK" || scenario === "PXK_READY") return [noPxk];
  if (scenario === "INGREDIENT_CHANGED") return [changed];
  if (scenario === "MIXED_UNITS") {
    const totals = [
      {
        ...kg,
        po_quantity: "10.000000",
        pxk_quantity: "20.000000",
        delta_quantity: "-10.000000",
      },
      {
        unit_id: "unit-piece",
        unit_code: "cái",
        po_quantity: "20.000000",
        pxk_quantity: "10.000000",
        delta_quantity: "10.000000",
      },
    ];
    return [
      fulfilmentRow({
        quantity_totals_by_unit: totals,
        details: totals.map((t) => ({
          ...t,
          ingredient_id: "ingredient-pumpkin",
          ingredient_name: "Bí đỏ",
        })),
      }),
    ];
  }
  if (scenario === "PXK_REPLACEMENT_REQUIRED")
    return [fulfilmentRow({ pxk_state: "REPLACEMENT_REQUIRED" })];
  if (scenario === "PXK_BLOCKED" || scenario === "OPERATIONAL_BLOCKER")
    return [
      { ...ok, pxk_state: "BLOCKED", blockers: ["PROCUREMENT_NOT_CURRENT"] },
    ];
  if (scenario === "WARNING")
    return [fulfilmentRow({ warnings: ["SOURCE_WARNING"] })];
  if (scenario === "MULTIPLE_DATES")
    return [
      ok,
      fulfilmentRow(),
      fulfilmentRow({ service_date: "2026-09-25" }),
      { ...noPo, service_date: "2026-09-26" },
    ];
  if (scenario === "MISMATCH" || scenario === "MULTIPLE_PO_DOCUMENTS")
    return [fulfilmentRow()];
  return [ok, fulfilmentRow(), noPo, changed, noPxk];
}
export function createSchoolFulfilmentReviewFixture(
  scenario: SchoolFulfilmentScenario = "ALL",
): SchoolFulfilmentReconciliationApi {
  let reads = 0;
  return {
    async getWorkbench(request) {
      reads++;
      if (scenario === "READ_FAILURE")
        throw new Error("Local fixture read failure");
      if (scenario === "PERMISSION_DENIED")
        return {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "PERMISSION_DENIED",
            safe_message: "Bạn không có quyền xem đối chiếu trong phạm vi này.",
          },
        };
      const scope = request.payload as SchoolFulfilmentScope;
      const rows = snapshots(scenario).filter(
        (r) =>
          r.service_date >= scope.date_start &&
          r.service_date <= scope.date_end &&
          (!scope.school_ids.length || scope.school_ids.includes(r.school_id)),
      );
      if (scenario === "STALE_OLD_RESPONSE" && reads === 1)
        await new Promise((resolve) => setTimeout(resolve, 1500));
      return fulfilmentSuccess(
        fulfilmentData(rows, scope.date_start, scope.date_end),
      );
    },
  };
}
