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
  purchase_handoff_line_revision_id: string;
  contribution_quantity: ExactQuantity;
  [key: string]: unknown;
};

export type AllocationFamilyRow = {
  family: AllocationFamilyIdentity;
  service_date: string;
  delivery_location_id: string;
  location_name: string;
  school_id: string | null;
  school_name: string | null;
  ingredient_id: string;
  ingredient_name: string;
  unit_id: string;
  unit_code: string;
  family_quantity: ExactQuantity;
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

export type PurchaseOrderStatus = "DRAFT" | "RELEASED_TO_SUPPLIER";

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
  allowed_actions: { release: boolean; export: boolean };
  disabled_reasons: string[];
};

export type PurchaseOrdersData = {
  success: true;
  contract_version: "SCHOOL-CATERING-PROCUREMENT.v1";
  date_start: string;
  date_end: string;
  purchase_orders: SchoolCateringPurchaseOrder[];
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

export type ProcurementCommandOutcome = {
  classification: ProcurementCommandClassification;
  safe_message: string;
  affected_labels: string[];
  current_versions: string[];
  warnings: string[];
  blockers: string[];
  next_action: string | null;
};
