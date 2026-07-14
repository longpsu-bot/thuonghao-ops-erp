import type {
  DispatchDeliveryState,
  DispatchRequirement,
  FulfilmentAllocation,
  FulfilmentEvidence,
} from "./dispatchDeliveryDomain";

const schoolRequirement: DispatchRequirement = {
  dispatchRequirementId: "DR-SCHOOL-CROSSDOCK-001",
  sourceOfNeed: "SCHOOL_CATERING",
  planningReleaseReference: "PLANNING-RELEASE-SCHOOL-001",
  requirementStatus: "FULFILMENT_READY",
  serviceOrDeliveryDate: "2026-07-14",
  destinationReference: "SCHOOL-AN-PHAT",
  destinationName: "An Phat School",
  deliveryLocationId: "DL-SCHOOL-AN-PHAT-KITCHEN",
  destinationActive: true,
  deliveryLocationActive: true,
  operationalNote: "Gate handover must be confirmed before 06:30.",
  lines: [
    {
      dispatchRequirementLineId: "DRL-SCHOOL-CROSSDOCK-001",
      itemReference: "ING-VEGETABLE",
      requiredQuantity: 20,
      requiredUnit: "kg",
      sourceTraceId: "CONFIRMED-NEED-SCHOOL-001",
    },
  ],
};

const schoolWarehouseRequirement: DispatchRequirement = {
  dispatchRequirementId: "DR-SCHOOL-WAREHOUSE-002",
  sourceOfNeed: "SCHOOL_CATERING",
  planningReleaseReference: "PLANNING-RELEASE-SCHOOL-002",
  requirementStatus: "FULFILMENT_READY",
  serviceOrDeliveryDate: "2026-07-14",
  destinationReference: "SCHOOL-BINH-MINH",
  destinationName: "Binh Minh School",
  deliveryLocationId: "DL-SCHOOL-BINH-MINH-KITCHEN",
  destinationActive: true,
  deliveryLocationActive: true,
  lines: [
    {
      dispatchRequirementLineId: "DRL-SCHOOL-WAREHOUSE-002",
      itemReference: "ING-RICE",
      requiredQuantity: 10,
      requiredUnit: "kg",
      sourceTraceId: "CONFIRMED-NEED-SCHOOL-002",
    },
  ],
};

const wholesaleRequirement: DispatchRequirement = {
  dispatchRequirementId: "DR-WHOLESALE-003",
  sourceOfNeed: "WHOLESALE",
  planningReleaseReference: "PLANNING-RELEASE-WHOLESALE-003",
  requirementStatus: "FULFILMENT_READY",
  serviceOrDeliveryDate: "2026-07-14",
  destinationReference: "CUSTOMER-MINH-AN",
  destinationName: "Minh An Wholesale Customer",
  deliveryLocationId: "DL-CUSTOMER-MINH-AN",
  destinationActive: true,
  deliveryLocationActive: true,
  lines: [
    {
      dispatchRequirementLineId: "DRL-WHOLESALE-003",
      itemReference: "ING-PUMPKIN",
      requiredQuantity: 15,
      requiredUnit: "kg",
      sourceTraceId: "WHOLESALE-ORDER-003",
    },
  ],
};

export const mixedFulfilmentRequirementFixture: DispatchRequirement = {
  dispatchRequirementId: "DR-MIXED-004",
  sourceOfNeed: "SCHOOL_CATERING",
  planningReleaseReference: "PLANNING-RELEASE-MIXED-004",
  requirementStatus: "FULFILMENT_READY",
  serviceOrDeliveryDate: "2026-07-14",
  destinationReference: "SCHOOL-HOA-SEN",
  destinationName: "Hoa Sen School",
  deliveryLocationId: "DL-SCHOOL-HOA-SEN-KITCHEN",
  destinationActive: true,
  deliveryLocationActive: true,
  lines: [
    {
      dispatchRequirementLineId: "DRL-MIXED-004",
      itemReference: "ING-RICE",
      requiredQuantity: 35,
      requiredUnit: "kg",
      sourceTraceId: "CONFIRMED-NEED-MIXED-004",
    },
  ],
};

export const exceptionRequirementFixture: DispatchRequirement = {
  dispatchRequirementId: "DR-EXCEPTION-005",
  sourceOfNeed: "WHOLESALE",
  planningReleaseReference: "PLANNING-RELEASE-EXCEPTION-005",
  requirementStatus: "FULFILMENT_READY",
  serviceOrDeliveryDate: "2026-07-14",
  destinationReference: "CUSTOMER-CLOSED-005",
  destinationName: "Closed Destination Customer",
  deliveryLocationId: "DL-CUSTOMER-CLOSED-005",
  destinationActive: true,
  deliveryLocationActive: true,
  operationalNote: "Receiver availability requires operator attention.",
  lines: [
    {
      dispatchRequirementLineId: "DRL-EXCEPTION-005",
      itemReference: "ING-POTATO",
      requiredQuantity: 12,
      requiredUnit: "kg",
      sourceTraceId: "WHOLESALE-ORDER-005",
    },
  ],
};

const allocations: readonly FulfilmentAllocation[] = [
  {
    fulfilmentAllocationId: "FA-SCHOOL-CROSSDOCK-001",
    dispatchRequirementId: schoolRequirement.dispatchRequirementId,
    allocationStatus: "READY_FOR_DISPATCH",
    procurementReference: "PO-SUPPLIER-001",
    lines: [
      {
        fulfilmentAllocationLineId: "FAL-SCHOOL-CROSSDOCK-001",
        dispatchRequirementLineId:
          schoolRequirement.lines[0].dispatchRequirementLineId,
        sourceType: "SUPPLIER_PO",
        allocatedQuantity: 20,
        allocatedUnit: "kg",
        supplierPurchaseOrderLineReference: "PO-LINE-001",
      },
    ],
  },
  {
    fulfilmentAllocationId: "FA-SCHOOL-WAREHOUSE-002",
    dispatchRequirementId: schoolWarehouseRequirement.dispatchRequirementId,
    allocationStatus: "READY_FOR_DISPATCH",
    procurementReference: "WAREHOUSE-REQUEST-002",
    lines: [
      {
        fulfilmentAllocationLineId: "FAL-SCHOOL-WAREHOUSE-002",
        dispatchRequirementLineId:
          schoolWarehouseRequirement.lines[0].dispatchRequirementLineId,
        sourceType: "WAREHOUSE_STOCK",
        allocatedQuantity: 10,
        allocatedUnit: "kg",
        warehouseStockRequestReference: "WSR-REQUEST-002",
      },
    ],
  },
  {
    fulfilmentAllocationId: "FA-WHOLESALE-003",
    dispatchRequirementId: wholesaleRequirement.dispatchRequirementId,
    allocationStatus: "READY_FOR_DISPATCH",
    procurementReference: "PO-SUPPLIER-003",
    lines: [
      {
        fulfilmentAllocationLineId: "FAL-WHOLESALE-003",
        dispatchRequirementLineId:
          wholesaleRequirement.lines[0].dispatchRequirementLineId,
        sourceType: "SUPPLIER_PO",
        allocatedQuantity: 15,
        allocatedUnit: "kg",
        supplierPurchaseOrderLineReference: "PO-LINE-003",
      },
    ],
  },
  {
    fulfilmentAllocationId: "FA-MIXED-004",
    dispatchRequirementId:
      mixedFulfilmentRequirementFixture.dispatchRequirementId,
    allocationStatus: "READY_FOR_DISPATCH",
    procurementReference: "MIXED-ALLOCATION-004",
    lines: [
      {
        fulfilmentAllocationLineId: "FAL-MIXED-SUPPLIER-004",
        dispatchRequirementLineId:
          mixedFulfilmentRequirementFixture.lines[0].dispatchRequirementLineId,
        sourceType: "SUPPLIER_PO",
        allocatedQuantity: 25,
        allocatedUnit: "kg",
        supplierPurchaseOrderLineReference: "PO-LINE-004",
      },
      {
        fulfilmentAllocationLineId: "FAL-MIXED-WAREHOUSE-004",
        dispatchRequirementLineId:
          mixedFulfilmentRequirementFixture.lines[0].dispatchRequirementLineId,
        sourceType: "WAREHOUSE_STOCK",
        allocatedQuantity: 10,
        allocatedUnit: "kg",
        warehouseStockRequestReference: "WSR-REQUEST-004",
      },
    ],
  },
  {
    fulfilmentAllocationId: "FA-EXCEPTION-005",
    dispatchRequirementId: exceptionRequirementFixture.dispatchRequirementId,
    allocationStatus: "READY_FOR_DISPATCH",
    procurementReference: "PO-SUPPLIER-005",
    lines: [
      {
        fulfilmentAllocationLineId: "FAL-EXCEPTION-005",
        dispatchRequirementLineId:
          exceptionRequirementFixture.lines[0].dispatchRequirementLineId,
        sourceType: "SUPPLIER_PO",
        allocatedQuantity: 12,
        allocatedUnit: "kg",
        supplierPurchaseOrderLineReference: "PO-LINE-005",
      },
    ],
  },
];

const fulfilmentEvidence: readonly FulfilmentEvidence[] = [
  {
    fulfilmentEvidenceId: "FE-CROSSDOCK-001",
    fulfilmentAllocationLineId: "FAL-SCHOOL-CROSSDOCK-001",
    evidenceType: "SUPPLIER_CROSS_DOCK",
    fulfilledQuantity: 20,
    fulfilledUnit: "kg",
    evidenceReference: "CROSSDOCK-HANDOVER-001",
    recordedAt: "2026-07-14T04:40:00.000Z",
  },
  {
    fulfilmentEvidenceId: "FE-WAREHOUSE-002",
    fulfilmentAllocationLineId: "FAL-SCHOOL-WAREHOUSE-002",
    evidenceType: "WAREHOUSE_STOCK_RELEASE",
    fulfilledQuantity: 10,
    fulfilledUnit: "kg",
    evidenceReference: "WAREHOUSE-RELEASE-002",
    recordedAt: "2026-07-14T04:45:00.000Z",
  },
  {
    fulfilmentEvidenceId: "FE-SUPPLIER-003",
    fulfilmentAllocationLineId: "FAL-WHOLESALE-003",
    evidenceType: "SUPPLIER_RECEIVING",
    fulfilledQuantity: 15,
    fulfilledUnit: "kg",
    evidenceReference: "SUPPLIER-RECEIVING-003",
    recordedAt: "2026-07-14T04:48:00.000Z",
  },
  {
    fulfilmentEvidenceId: "FE-MIXED-SUPPLIER-004",
    fulfilmentAllocationLineId: "FAL-MIXED-SUPPLIER-004",
    evidenceType: "SUPPLIER_RECEIVING",
    fulfilledQuantity: 25,
    fulfilledUnit: "kg",
    evidenceReference: "SUPPLIER-RECEIVING-004",
    recordedAt: "2026-07-14T04:50:00.000Z",
  },
  {
    fulfilmentEvidenceId: "FE-MIXED-WAREHOUSE-004",
    fulfilmentAllocationLineId: "FAL-MIXED-WAREHOUSE-004",
    evidenceType: "WAREHOUSE_STOCK_RELEASE",
    fulfilledQuantity: 10,
    fulfilledUnit: "kg",
    evidenceReference: "WAREHOUSE-RELEASE-004",
    recordedAt: "2026-07-14T04:52:00.000Z",
  },
  {
    fulfilmentEvidenceId: "FE-EXCEPTION-005",
    fulfilmentAllocationLineId: "FAL-EXCEPTION-005",
    evidenceType: "SUPPLIER_CROSS_DOCK",
    fulfilledQuantity: 12,
    fulfilledUnit: "kg",
    evidenceReference: "CROSSDOCK-HANDOVER-005",
    recordedAt: "2026-07-14T04:55:00.000Z",
  },
];

export const dispatchDeliveryInputFixture: DispatchDeliveryState = {
  requirements: [
    schoolRequirement,
    schoolWarehouseRequirement,
    wholesaleRequirement,
    mixedFulfilmentRequirementFixture,
    exceptionRequirementFixture,
  ],
  allocations,
  fulfilmentEvidence,
  plans: [],
  trips: [],
  loads: [],
  confirmations: [],
  exceptions: [],
  returns: [],
  statusChanges: [],
  auditEvents: [],
};

export const missingMixedEvidenceFixture: DispatchDeliveryState = {
  ...dispatchDeliveryInputFixture,
  fulfilmentEvidence: fulfilmentEvidence.filter(
    (candidate) => candidate.fulfilmentEvidenceId !== "FE-MIXED-WAREHOUSE-004",
  ),
};
