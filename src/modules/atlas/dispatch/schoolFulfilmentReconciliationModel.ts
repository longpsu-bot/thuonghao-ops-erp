export type SchoolFulfilmentComparisonStatus =
  "OK" | "NO_PO" | "NO_PXK" | "INGREDIENT_CHANGED" | "MISMATCH";

export type SchoolFulfilmentQuantityTotal = {
  unit_id: string;
  unit_code: string;
  po_quantity: string;
  pxk_quantity: string;
  delta_quantity: string;
};

export type SchoolFulfilmentDetail = SchoolFulfilmentQuantityTotal & {
  ingredient_id: string;
  ingredient_name: string;
};

export type SchoolFulfilmentRow = {
  service_date: string;
  school_id: string;
  school_name: string;
  delivery_location_id: string;
  delivery_location_name: string;
  comparison_status: SchoolFulfilmentComparisonStatus;
  quantity_totals_by_unit: SchoolFulfilmentQuantityTotal[];
  purchase_order_numbers: string[];
  purchase_order_ids: string[];
  pxk_document_number: string | null;
  school_dispatch_release_id: string | null;
  pxk_state: "READY" | "CURRENT" | "REPLACEMENT_REQUIRED" | "BLOCKED";
  blockers: string[];
  warnings: string[];
  details: SchoolFulfilmentDetail[];
  history: unknown[];
};

export type SchoolFulfilmentWorkbenchData = {
  success: true;
  contract_version: "SCHOOL-FULFILMENT-RECONCILIATION.v1";
  date_start: string;
  date_end: string;
  rows: SchoolFulfilmentRow[];
  warnings: string[];
  blockers: string[];
};

export const SCHOOL_FULFILMENT_STATUS_LABELS: Record<
  SchoolFulfilmentComparisonStatus,
  string
> = {
  OK: "Khớp",
  NO_PO: "Chưa có PO",
  NO_PXK: "Chưa có PXK",
  INGREDIENT_CHANGED: "Khác nguyên liệu",
  MISMATCH: "Lệch số lượng",
};
