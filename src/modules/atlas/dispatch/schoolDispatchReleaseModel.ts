export type SchoolDispatchReleaseState =
  "READY" | "CURRENT" | "REPLACEMENT_REQUIRED" | "BLOCKED";

export type SchoolDispatchReleaseStatus = "RELEASED" | "SUPERSEDED";

export type SchoolDispatchLineSource = {
  confirmed_need_line_revision_id: string;
  confirmed_need_line_decision_id: string;
  allocation_family_revision_id: string;
  allocation_family_contribution_id: string;
  allocation_supplier_split_id: string;
  purchase_order_id: string;
  purchase_order_revision_id: string;
  purchase_order_line_revision_id: string;
  covered_quantity: string;
};

export type SchoolDispatchLine = {
  school_dispatch_release_line_id?: string;
  ingredient_id: string;
  ingredient_name: string;
  unit_id: string;
  unit_code: string;
  quantity: string;
  sources: SchoolDispatchLineSource[];
};

export type SchoolDispatchPreview = {
  service_date: string;
  school_id: string;
  delivery_location_id: string;
  school_name: string;
  delivery_location_name: string;
  delivery_address: string;
  source_fingerprint: string;
  ready: boolean;
  lines: SchoolDispatchLine[];
  blockers: string[];
  warnings: string[];
};

export type SchoolDispatchDocument = {
  school_dispatch_release_id: string;
  service_date: string;
  school_id: string;
  delivery_location_id: string;
  status: SchoolDispatchReleaseStatus;
  document_number: string;
  source_fingerprint: string;
  predecessor_release_id: string | null;
  school_name: string;
  delivery_location_name: string;
  delivery_address: string;
  note: string | null;
  version: number;
  released_by_actor_id: string;
  released_at: string;
  export_ready: boolean;
  lines: SchoolDispatchLine[];
};

export type SchoolDispatchWorkbenchRow = {
  service_date: string;
  school_id: string;
  delivery_location_id: string;
  state: SchoolDispatchReleaseState;
  expected_version: number;
  preview: SchoolDispatchPreview;
  current_release: SchoolDispatchDocument | null;
  history: SchoolDispatchDocument[];
  allowed_actions: {
    release: boolean;
    replace: boolean;
    export: boolean;
  };
  blockers: string[];
  warnings: string[];
};

export type SchoolDispatchWorkbenchData = {
  success: true;
  contract_version: "SCHOOL-DISPATCH-RELEASE.v1";
  date_start: string;
  date_end: string;
  rows: SchoolDispatchWorkbenchRow[];
  warnings: string[];
  blockers: string[];
};

export const SCHOOL_DISPATCH_STATE_LABELS: Record<
  SchoolDispatchReleaseState,
  string
> = {
  READY: "Sẵn sàng phát hành",
  CURRENT: "Phiếu hiện hành",
  REPLACEMENT_REQUIRED: "Cần phiếu thay thế",
  BLOCKED: "Đang bị chặn",
};

export const SCHOOL_DISPATCH_BLOCKER_LABELS: Record<string, string> = {
  SCHOOL_SCOPE_INVALID: "Trường hoặc điểm giao không còn hợp lệ.",
  NO_CURRENT_NEED: "Chưa có nhu cầu hiện hành cho trường và ngày này.",
  PO_COVERAGE_INCOMPLETE:
    "Đơn mua đã phát hành chưa bao phủ đầy đủ nhu cầu của trường.",
  PROCUREMENT_NOT_CURRENT:
    "Kế hoạch mua hàng chưa khớp với nhu cầu và phân bổ hiện hành.",
  CANCELLATION_REQUIRED:
    "Cam kết nhà cung ứng cũ cần được xử lý trước khi phát hành Phiếu xuất kho.",
};

export function schoolDispatchBlockerLabel(code: string) {
  return (
    SCHOOL_DISPATCH_BLOCKER_LABELS[code] ??
    "Phiếu xuất kho chưa đủ điều kiện phát hành."
  );
}
