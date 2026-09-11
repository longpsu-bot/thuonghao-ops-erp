import {
  SCHOOL_FULFILMENT_STATUS_LABELS,
  type SchoolFulfilmentScope,
  type SchoolFulfilmentWorkbenchData,
} from "../bridges/schoolFulfilment";
import { SCHOOL_DISPATCH_STATE_LABELS } from "../bridges/schoolDispatch";
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;
const strings = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every((v) => typeof v === "string");
const dateStamp = (date: string) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return NaN;
  const stamp = Date.parse(`${date}T00:00:00Z`);
  return Number.isFinite(stamp) &&
    new Date(stamp).toISOString().slice(0, 10) === date
    ? stamp
    : NaN;
};
export function reconciliationRangeError(start: string, end: string) {
  const from = dateStamp(start),
    to = dateStamp(end);
  if (!Number.isFinite(from) || !Number.isFinite(to))
    return "Chọn ngày đối chiếu hợp lệ.";
  if (from > to) return "Đến ngày không được trước Từ ngày.";
  if ((to - from) / 86400000 + 1 > 31)
    return "Khoảng đối chiếu tối đa 31 ngày.";
  return null;
}
const quantity = (value: unknown) =>
  typeof value === "string" && /^-?\d+(?:\.\d+)?$/.test(value);
const total = (value: unknown) =>
  record(value) &&
  typeof value.unit_id === "string" &&
  typeof value.unit_code === "string" &&
  quantity(value.po_quantity) &&
  quantity(value.pxk_quantity) &&
  quantity(value.delta_quantity);
/** Validate shape and scope, not the backend's comparison or arithmetic. */
export function isSchoolFulfilmentAuthority(
  value: unknown,
  scope: SchoolFulfilmentScope,
): value is SchoolFulfilmentWorkbenchData {
  if (
    !record(value) ||
    value.success !== true ||
    value.contract_version !== "SCHOOL-FULFILMENT-RECONCILIATION.v1" ||
    value.date_start !== scope.date_start ||
    value.date_end !== scope.date_end ||
    !strings(value.blockers) ||
    !strings(value.warnings) ||
    !Array.isArray(value.rows)
  )
    return false;
  return value.rows.every(
    (row) =>
      record(row) &&
      typeof row.service_date === "string" &&
      Number.isFinite(dateStamp(row.service_date)) &&
      row.service_date >= scope.date_start &&
      row.service_date <= scope.date_end &&
      typeof row.school_id === "string" &&
      (!scope.school_ids.length || scope.school_ids.includes(row.school_id)) &&
      typeof row.school_name === "string" &&
      typeof row.delivery_location_id === "string" &&
      typeof row.delivery_location_name === "string" &&
      typeof row.comparison_status === "string" &&
      Object.hasOwn(SCHOOL_FULFILMENT_STATUS_LABELS, row.comparison_status) &&
      typeof row.pxk_state === "string" &&
      Object.hasOwn(SCHOOL_DISPATCH_STATE_LABELS, row.pxk_state) &&
      strings(row.purchase_order_numbers) &&
      strings(row.purchase_order_ids) &&
      (row.pxk_document_number === null ||
        typeof row.pxk_document_number === "string") &&
      (row.school_dispatch_release_id === null ||
        typeof row.school_dispatch_release_id === "string") &&
      strings(row.blockers) &&
      strings(row.warnings) &&
      Array.isArray(row.history) &&
      Array.isArray(row.quantity_totals_by_unit) &&
      row.quantity_totals_by_unit.every(total) &&
      Array.isArray(row.details) &&
      row.details.every(
        (d) =>
          record(d) &&
          total(d) &&
          typeof d.ingredient_id === "string" &&
          typeof d.ingredient_name === "string",
      ),
  );
}
