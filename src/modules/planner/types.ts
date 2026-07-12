export type DemandSourceType =
  | "CATERING_MENU"
  | "WHOLESALE_ORDER"
  | "PANTRY_ADD"
  | "MANUAL_DEMAND"
  | "CORRECTION";
export type Severity = "OK" | "INFO" | "WARNING" | "BLOCKING";
export type Readiness = "READY" | "NEEDS_REVIEW" | "BLOCKED";
export type SupplierStatus = "ASSIGNED" | "MISSING" | "SUGGESTED" | "CONFLICT";
export type ViewMode = "DATE" | "CUSTOMER" | "SOURCE" | "SUPPLIER";

export type TraceStep = { label: string; value: string; note: string };
export type DemandSource = {
  id: string;
  type: DemandSourceType;
  customer: string;
  serviceDate: string;
  reference: string;
  basis: string;
  status: string;
};
export type RequirementLine = {
  id: string;
  sourceId: string;
  serviceDate: string;
  customer: string;
  sourceType: DemandSourceType;
  sourceReference: string;
  sourceBasis: string;
  ingredient: string;
  ingredientGroup: string;
  calculationMode: string;
  rawQuantity: number;
  adjustedQuantity: number;
  orderableQuantity: number;
  unit: string;
  severity: Severity;
  warningCode?: string;
  warningExplanation: string;
  supplierStatus: SupplierStatus;
  supplierName?: string;
  readiness: Readiness;
  hasSubstitution: boolean;
  hasOverride: boolean;
  adjustment: string;
  trace: TraceStep[];
  openQuestions: string[];
};
export type LocalLineState = {
  reviewed: boolean;
  flagged: boolean;
  substitutionDraft: boolean;
  overrideDraft: boolean;
  locallyReady: boolean;
  reviewNote: string;
};
export type Filters = {
  from: string;
  to: string;
  sourceType: string;
  customer: string;
  severity: string;
  readiness: string;
  search: string;
  exceptionOnly: boolean;
};
