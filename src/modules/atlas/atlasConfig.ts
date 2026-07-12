export type AtlasPageId =
  | "operations-home"
  | "requirement-planning"
  | "purchase-planning"
  | "warehouse-receiving"
  | "customers-schools"
  | "ingredients-units"
  | "suppliers-eligibility"
  | "integration-status";

export const atlasGroups = [
  "Overview",
  "Active Workflow",
  "Supporting Data",
  "Administration",
] as const;

export type AtlasGroup = (typeof atlasGroups)[number];

export type AtlasPage = {
  id: AtlasPageId;
  label: string;
  group: AtlasGroup;
  role: string;
  input: string;
  responsibility: string;
  output: string;
  handoff: string;
  primaryAction: string;
};

export const atlasPages: AtlasPage[] = [
  {
    id: "operations-home",
    label: "Operations Home",
    group: "Overview",
    role: "Operations coordination",
    input: "Mock operational period",
    responsibility: "Direct work to the current planning or receiving stage",
    output: "A clear next action",
    handoff: "One of the three active stages",
    primaryAction: "Open active workflow",
  },
  {
    id: "requirement-planning",
    label: "Requirement Planning",
    group: "Active Workflow",
    role: "Planning",
    input: "Demand, service date, and outbound destination",
    responsibility:
      "Review what is needed, who needs it, and its school, kitchen, route, or outbound target",
    output: "Destination-linked requirements ready for purchasing",
    handoff: "Purchase Planning",
    primaryAction: "Review destination requirements",
  },
  {
    id: "purchase-planning",
    label: "Purchase Planning",
    group: "Active Workflow",
    role: "Purchasing",
    input: "Destination-linked requirements ready for purchasing",
    responsibility: "Assign suppliers and prepare the supplier order list",
    output: "Prepared order list with optional supplier coordination note",
    handoff: "Warehouse Receiving",
    primaryAction: "Prepare supplier orders",
  },
  {
    id: "warehouse-receiving",
    label: "Warehouse Receiving",
    group: "Active Workflow",
    role: "Warehouse",
    input: "Prepared supplier order list",
    responsibility:
      "Compare what was ordered with what was received and record discrepancies",
    output: "Receiving result and discrepancy record",
    handoff: "Future accounting reconciliation consumer",
    primaryAction: "Review receiving discrepancies",
  },
  {
    id: "customers-schools",
    label: "Customers and Schools",
    group: "Supporting Data",
    role: "Master Data",
    input: "Customer and school references",
    responsibility: "Maintain destination references",
    output: "Valid destination references",
    handoff: "Requirement Planning",
    primaryAction: "Review destination data",
  },
  {
    id: "ingredients-units",
    label: "Ingredients and Units",
    group: "Supporting Data",
    role: "Master Data",
    input: "Ingredient and unit references",
    responsibility: "Maintain ingredient references",
    output: "Valid planning references",
    handoff: "Requirement and Purchase Planning",
    primaryAction: "Review ingredient data",
  },
  {
    id: "suppliers-eligibility",
    label: "Suppliers and Eligibility",
    group: "Supporting Data",
    role: "Master Data",
    input: "Supplier reference data",
    responsibility: "Maintain supplier eligibility references",
    output: "Supplier options for Purchase Planning",
    handoff: "Purchase Planning",
    primaryAction: "Review supplier data",
  },
  {
    id: "integration-status",
    label: "Prototype Boundary",
    group: "Administration",
    role: "Administration",
    input: "Prototype scope",
    responsibility: "Show that this is mock UI only",
    output: "Clear implementation boundary",
    handoff: "Architecture review",
    primaryAction: "Review prototype boundary",
  },
];

export const journeys = [
  {
    id: "CAT-0713-ND",
    name: "Catering · Nguyen Du",
    context:
      "13/07/2026 · Pumpkin soup · 620 portions · Destination: Nguyen Du School / Route North",
    flow: ["Requirement Planning", "Purchase Planning", "Warehouse Receiving"],
  },
  {
    id: "WS-2026-0714",
    name: "Wholesale · Minh An Kitchen",
    context:
      "14/07/2026 · Jasmine rice · 250 kg · Destination: Minh An Kitchen / Outbound pickup",
    flow: ["Requirement Planning", "Purchase Planning", "Warehouse Receiving"],
  },
];
