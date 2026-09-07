export type AllocationFamilyState =
  | "UNALLOCATED"
  | "BALANCED"
  | "STALE_REBALANCE_AVAILABLE"
  | "NEEDS_REALLOCATION"
  | "BLOCKED";

export type ProcurementStage = "allocation" | "orders";

export type ExactQuantity = string;

export type AllocationFamilyReference = {
  service_date: string;
  delivery_location_id: string;
  ingredient_id: string;
  unit_id: string;
  expected_source_fingerprint: string;
};

export type AllocationFamilyIdentity = {
  source_kind?: "CONFIRMED_NEED" | "PURCHASE_HANDOFF";
  source_confirmed_need_batch_id?: string;
  source_confirmed_need_batch_version?: number;
  service_date: string;
  delivery_location_id: string;
  ingredient_id: string;
  unit_id: string;
  family_id: string | null;
  version: number;
  source_fingerprint: string;
};

export type SupplierSplitInput = {
  supplier_id: string;
  allocated_quantity: ExactQuantity;
};

export type RecommendationCandidate = AllocationFamilyReference & {
  expected_family_version: number;
};

export type EligibleSupplier = {
  supplier_id: string;
  supplier_name: string;
  priority: number;
};

export type AllocationSupplierSplit = {
  supplier_split_id: string;
  supplier_id: string;
  supplier_name: string;
  allocated_quantity: ExactQuantity;
  split_ratio: ExactQuantity;
};

export type AllocationProposalSplit = {
  supplier_id: string;
  allocated_quantity: ExactQuantity;
  split_ratio: ExactQuantity;
};

export type AllocationContribution = {
  purchase_handoff_line_revision_id?: string;
  confirmed_need_line_revision_id?: string;
  confirmed_need_line_decision_id?: string;
  contribution_quantity: ExactQuantity;
  [key: string]: unknown;
};

export type AllocationFamilyRow = {
  complete?: boolean;
  family: AllocationFamilyIdentity;
  service_date: string;
  delivery_location_id: string;
  location_name: string;
  school_id: string | null;
  school_name: string | null;
  schools?: ProcurementSchoolOption[];
  ingredient_id: string;
  ingredient_name: string;
  unit_id: string;
  unit_code: string;
  family_quantity: ExactQuantity | null;
  contributions: AllocationContribution[];
  contribution_count: number;
  splits: AllocationSupplierSplit[];
  eligible_suppliers: EligibleSupplier[];
  state: AllocationFamilyState;
  recommendation: AllocationProposalSplit | null;
  rebalance_proposal: AllocationProposalSplit[] | null;
  allowed_actions: {
    save_allocation: boolean;
    confirm_recommendation: boolean;
  };
  disabled_reasons: string[];
  blockers: string[];
  warnings: string[];
};

export type ProcurementWorkbenchData = {
  success: true;
  contract_version: "SCHOOL-CATERING-PROCUREMENT.v1";
  date_start: string;
  date_end: string;
  rows: AllocationFamilyRow[];
  warnings: string[];
  blockers: string[];
};

export type ProcurementSchoolOption = {
  school_id: string;
  school_name: string;
};

export type PurchaseOrderStatus =
  "DRAFT" | "RELEASED_TO_SUPPLIER" | "SUPERSEDED";

export type PurchaseOrderCommitmentState =
  | "DRAFT_CURRENT"
  | "DRAFT_STALE"
  | "CURRENT"
  | "REPLACEMENT_REQUIRED"
  | "CANCELLATION_REQUIRED"
  | "SUPERSEDED";

export type PurchaseOrderLine = {
  purchase_order_line_revision_id: string;
  purchase_order_line_id: string;
  ingredient: {
    ingredient_id: string;
    ingredient_name: string;
  };
  ordered_quantity: ExactQuantity;
  unit: { unit_id: string; unit_code: string };
  delivery_location: {
    delivery_location_id: string;
    location_name: string;
  };
  service_date: string;
  source: {
    family_id: string;
    family_revision_id: string;
    supplier_split_id: string;
  };
};

export type SchoolCateringPurchaseOrder = {
  purchase_order_id: string;
  supplier: {
    supplier_id: string;
    supplier_name: string;
    supplier_status: string;
  };
  service_date: string;
  status: PurchaseOrderStatus;
  version: number;
  document_number: string | null;
  replaces_purchase_order_id: string | null;
  replaced_by_purchase_order_id: string | null;
  commitment_state: PurchaseOrderCommitmentState;
  current_revision: {
    purchase_order_revision_id: string;
    revision_number: number;
    revision_kind: string;
    revision_status: string;
    predecessor_revision_id: string | null;
    supplier_name_snapshot: string | null;
    delivery_location_snapshot: unknown;
    released_by_actor_id: string | null;
    released_at: string | null;
    reason_note: string | null;
  };
  lines: PurchaseOrderLine[];
  stale: boolean;
  release_eligible: boolean;
  export_ready: boolean;
  blockers: string[];
  warnings: string[];
  allowed_actions: {
    release: boolean;
    export: boolean;
    create_replacement: boolean;
  };
  disabled_reasons: string[];
};

export type PurchaseOrdersData = {
  success: true;
  contract_version: "SCHOOL-CATERING-PROCUREMENT.v1";
  date_start: string;
  date_end: string;
  purchase_orders: SchoolCateringPurchaseOrder[];
  procurement_current: boolean;
  warnings: string[];
  blockers: string[];
};

export type ProcurementCommandClassification =
  | "SUCCESS"
  | "REPLAY_SUCCESS"
  | "RETRYABLE_FAILURE"
  | "STALE"
  | "UNKNOWN_OUTCOME"
  | "BLOCKED";

export type PurchaseOrderDraftReadinessReason =
  | "NO_CURRENT_FAMILIES"
  | "ALLOCATION_MISSING"
  | "SOURCE_CHANGED"
  | "ALLOCATION_IMBALANCED"
  | "SUPPLIER_INELIGIBLE";

export type PurchaseOrderDraftReadinessBlocker = {
  service_date: string;
  delivery_location_id?: string | null;
  ingredient_id?: string | null;
  unit_id?: string | null;
  family_id?: string | null;
  family_revision_id?: string | null;
  reason: PurchaseOrderDraftReadinessReason | string;
};

export type PurchaseOrderDraftSkippedDate = {
  service_date: string;
  family_count: number;
  ready: false;
  blockers: PurchaseOrderDraftReadinessBlocker[];
};

const purchaseOrderDraftReasonLabels: Record<
  PurchaseOrderDraftReadinessReason,
  string
> = {
  NO_CURRENT_FAMILIES: "chưa có nhu cầu mua hiện hành.",
  ALLOCATION_MISSING: "còn nhu cầu chưa phân bổ nhà cung ứng.",
  SOURCE_CHANGED: "phân bổ cần cập nhật theo nhu cầu mới.",
  ALLOCATION_IMBALANCED: "tổng phân bổ chưa khớp nhu cầu.",
  SUPPLIER_INELIGIBLE: "có nhà cung cấp không còn phù hợp.",
};

function readinessRecord(value: unknown) {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function readinessDateLabel(value: string) {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return match ? `${match[3]}/${match[2]}/${match[1]}` : value;
}

export function purchaseOrderDraftReadinessMessages(value: unknown) {
  if (!Array.isArray(value)) return [];
  const messages = value.flatMap((item) => {
    const skippedDate = readinessRecord(item);
    if (
      typeof skippedDate?.service_date !== "string" ||
      !Array.isArray(skippedDate.blockers)
    )
      return [];
    const date = readinessDateLabel(skippedDate.service_date);
    return skippedDate.blockers.flatMap((rawBlocker) => {
      const blocker = readinessRecord(rawBlocker);
      if (typeof blocker?.reason !== "string") return [];
      const reason = blocker.reason as PurchaseOrderDraftReadinessReason;
      return [
        `${date}: ${purchaseOrderDraftReasonLabels[reason] ?? "chưa thể tạo đơn mua; hãy kiểm tra điều kiện sẵn sàng."}`,
      ];
    });
  });
  return Array.from(new Set(messages));
}

export type ProcurementCommandOutcome = {
  classification: ProcurementCommandClassification;
  code: string | null;
  safe_message: string;
  affected_labels: string[];
  current_versions: string[];
  warnings: string[];
  blockers: string[];
  next_action: string | null;
};
