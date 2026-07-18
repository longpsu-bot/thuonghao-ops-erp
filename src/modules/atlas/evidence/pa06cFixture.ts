export const PA06C_FIXTURE = {
  environmentNotice: "Local only · synthetic fixture · non-production",
  serviceDate: "2026-07-18",
  customer: {
    id: "b6000000-0000-0000-0000-000000000201",
    reference: "PA06B-LOCAL-CUSTOMER",
    name: "PA-06B Synthetic Local Customer",
  },
  deliveryLocation: {
    id: "b6c10000-0000-0000-0000-000000000101",
    reference: "PA06C-LOCATION",
    name: "PA-06C Synthetic Delivery Location",
  },
  source: {
    orderId: "b6c20000-0000-0000-0000-000000000200",
    orderReference: "PA06C-ORDER-001",
    lineRevisionId: "b6c20000-0000-0000-0000-000000000202",
  },
  allocation: {
    id: "b6c30000-0000-0000-0000-000000000600",
    lineRevisionId: "b6c30000-0000-0000-0000-000000000603",
  },
  supplier: {
    id: "b6c10000-0000-0000-0000-000000000104",
    reference: "PA06C-SUPPLIER",
    name: "PA-06C Synthetic Supplier",
  },
  ingredient: {
    id: "b6c10000-0000-0000-0000-000000000103",
    reference: "PA06C-RICE",
    name: "PA-06C Synthetic Rice",
  },
  unit: {
    id: "b6c10000-0000-0000-0000-000000000102",
    reference: "pa06c-kg",
    label: "kg",
  },
  purchaseOrder: {
    id: "b6c30000-0000-0000-0000-000000000700",
    reference: "PA06C-PO-001",
    lineRevisionId: "b6c30000-0000-0000-0000-000000000703",
  },
  quantity: 10,
} as const;

export const PA06C_READINESS_SELECTOR = {
  wholesale_order_line_revision_id: PA06C_FIXTURE.source.lineRevisionId,
} as const;

export const PA06C_BLOCKER_SELECTOR = {
  service_date: PA06C_FIXTURE.serviceDate,
  delivery_location_id: PA06C_FIXTURE.deliveryLocation.id,
} as const;
