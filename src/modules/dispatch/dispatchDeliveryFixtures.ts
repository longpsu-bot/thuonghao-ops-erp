import {
  AssignDispatchTrip,
  AssignDriverOrVehicleReference,
  CompleteDispatchTrip,
  ConfirmDeliveryStop,
  ConfirmDispatchLoad,
  CreateDispatchPlanFromRequirements,
  RecordDispatchDeparture,
  type DeliveryConfirmation,
  type DispatchDeliveryState,
  type DispatchRequirement,
  type FulfilmentAllocation,
  type FulfilmentEvidence,
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

function completedDispatchFixture(
  requirementId: string,
): DispatchDeliveryState {
  const suffix = requirementId.replace("DR-", "");
  const sourceRequirement = dispatchDeliveryInputFixture.requirements.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const sourceAllocation = dispatchDeliveryInputFixture.allocations.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const allocationLineIds = sourceAllocation.lines.map(
    (candidate) => candidate.fulfilmentAllocationLineId,
  );
  const sourceState: DispatchDeliveryState = {
    ...dispatchDeliveryInputFixture,
    requirements: [sourceRequirement],
    allocations: [sourceAllocation],
    fulfilmentEvidence: dispatchDeliveryInputFixture.fulfilmentEvidence.filter(
      (candidate) =>
        allocationLineIds.includes(candidate.fulfilmentAllocationLineId),
    ),
  };
  let state = CreateDispatchPlanFromRequirements(sourceState, {
    dispatchPlanId: `DP-NORMAL-${suffix}`,
    requirementIds: [requirementId],
    serviceDate: "2026-07-14",
    actorId: "dispatcher-review",
    at: "2026-07-14T04:00:00.000Z",
  }).state;
  state = AssignDispatchTrip(state, {
    dispatchTripId: `DT-NORMAL-${suffix}`,
    dispatchPlanId: `DP-NORMAL-${suffix}`,
    routeReference: `MORNING-REFERENCE-${suffix}`,
    actorId: "dispatcher-review",
    at: "2026-07-14T04:05:00.000Z",
  }).state;
  state = AssignDriverOrVehicleReference(state, {
    dispatchTripId: `DT-NORMAL-${suffix}`,
    driverReference: "DRIVER-NORMAL-01",
    vehicleReference: "VEHICLE-NORMAL-01",
    actorId: "dispatcher-review",
    at: "2026-07-14T04:10:00.000Z",
  }).state;
  const allocation = state.allocations.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  state = ConfirmDispatchLoad(state, {
    dispatchLoadId: `LOAD-NORMAL-${suffix}`,
    dispatchTripId: `DT-NORMAL-${suffix}`,
    dispatchRequirementId: requirementId,
    actorId: "dispatcher-review",
    at: "2026-07-14T04:20:00.000Z",
    lines: allocation.lines.map((line) => ({
      dispatchRequirementLineId: line.dispatchRequirementLineId,
      fulfilmentAllocationLineId: line.fulfilmentAllocationLineId,
      fulfilmentEvidenceIds: state.fulfilmentEvidence
        .filter(
          (candidate) =>
            candidate.fulfilmentAllocationLineId ===
            line.fulfilmentAllocationLineId,
        )
        .map((candidate) => candidate.fulfilmentEvidenceId),
      loadedQuantity: line.allocatedQuantity,
      loadedUnit: line.allocatedUnit,
    })),
  }).state;
  state = RecordDispatchDeparture(state, {
    dispatchTripId: `DT-NORMAL-${suffix}`,
    actorId: "dispatcher-review",
    at: "2026-07-14T05:00:00.000Z",
  }).state;
  const stop = state.trips.find(
    (candidate) => candidate.dispatchTripId === `DT-NORMAL-${suffix}`,
  )!.stops[0];
  const loadLines = state.loads.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!.lines;
  const confirmation: DeliveryConfirmation = {
    deliveryConfirmationId: `DC-NORMAL-${suffix}`,
    dispatchStopId: stop.dispatchStopId,
    confirmedAt: "2026-07-14T06:00:00.000Z",
    confirmedBy: "driver-review",
    outcome: "DELIVERED",
    evidence: [
      {
        deliveryEvidenceId: `DE-NORMAL-${suffix}`,
        evidenceReference: `RECEIVER-NORMAL-${suffix}`,
        evidenceType: "RECEIVER_REFERENCE",
      },
    ],
    lines: loadLines.map((line, index) => ({
      deliveryConfirmationLineId: `DCL-NORMAL-${suffix}-${index + 1}`,
      dispatchLoadLineId: line.dispatchLoadLineId,
      deliveredQuantity: line.loadedQuantity,
      returnedQuantity: 0,
      exceptionQuantity: 0,
      unit: line.loadedUnit,
    })),
  };
  state = ConfirmDeliveryStop(state, {
    dispatchTripId: `DT-NORMAL-${suffix}`,
    confirmation,
    actorId: "driver-review",
    at: "2026-07-14T06:00:00.000Z",
  }).state;
  return CompleteDispatchTrip(state, {
    dispatchTripId: `DT-NORMAL-${suffix}`,
    actorId: "dispatcher-review",
    at: "2026-07-14T07:30:00.000Z",
  }).state;
}

export const normalSchoolCrossDockDispatchFixture = completedDispatchFixture(
  "DR-SCHOOL-CROSSDOCK-001",
);
export const normalSchoolWarehouseDispatchFixture = completedDispatchFixture(
  "DR-SCHOOL-WAREHOUSE-002",
);
export const normalMixedDispatchFixture =
  completedDispatchFixture("DR-MIXED-004");
export const normalWholesaleDispatchFixture =
  completedDispatchFixture("DR-WHOLESALE-003");

export const missingMixedEvidenceFixture: DispatchDeliveryState = {
  ...dispatchDeliveryInputFixture,
  fulfilmentEvidence: fulfilmentEvidence.filter(
    (candidate) => candidate.fulfilmentEvidenceId !== "FE-MIXED-WAREHOUSE-004",
  ),
};

export {
  schoolRequirement as schoolCrossDockRequirementFixture,
  schoolWarehouseRequirement as schoolWarehouseRequirementFixture,
  wholesaleRequirement as wholesaleRequirementFixture,
};

export const inactiveDestinationRequirementFixture: DispatchRequirement = {
  dispatchRequirementId: "DR-INACTIVE-007",
  sourceOfNeed: "SCHOOL_CATERING",
  planningReleaseReference: "PLANNING-RELEASE-INACTIVE-007",
  requirementStatus: "FULFILMENT_READY",
  serviceOrDeliveryDate: "2026-07-14",
  destinationReference: "SCHOOL-INACTIVE-007",
  destinationName: "Inactive School Destination",
  deliveryLocationId: "DL-INACTIVE-007",
  destinationActive: false,
  deliveryLocationActive: false,
  lines: [
    {
      dispatchRequirementLineId: "DRL-INACTIVE-007",
      itemReference: "ING-RICE",
      requiredQuantity: 5,
      requiredUnit: "kg",
      sourceTraceId: "CONFIRMED-NEED-INACTIVE-007",
    },
  ],
};

const returnedRequirement: DispatchRequirement = {
  dispatchRequirementId: "DR-RETURNED-006",
  sourceOfNeed: "WHOLESALE",
  planningReleaseReference: "PLANNING-RELEASE-RETURNED-006",
  requirementStatus: "DISPATCHED",
  serviceOrDeliveryDate: "2026-07-14",
  destinationReference: "CUSTOMER-RETURNED-006",
  destinationName: "Returned Goods Customer",
  deliveryLocationId: "DL-CUSTOMER-RETURNED-006",
  destinationActive: true,
  deliveryLocationActive: true,
  lines: [
    {
      dispatchRequirementLineId: "DRL-RETURNED-006",
      itemReference: "ING-CARROT",
      requiredQuantity: 8,
      requiredUnit: "kg",
      sourceTraceId: "WHOLESALE-ORDER-006",
    },
  ],
};

const reviewAllocations: readonly FulfilmentAllocation[] = [
  ...allocations,
  {
    fulfilmentAllocationId: "FA-RETURNED-006",
    dispatchRequirementId: returnedRequirement.dispatchRequirementId,
    allocationStatus: "READY_FOR_DISPATCH",
    procurementReference: "PO-SUPPLIER-006",
    lines: [
      {
        fulfilmentAllocationLineId: "FAL-RETURNED-006",
        dispatchRequirementLineId: "DRL-RETURNED-006",
        sourceType: "SUPPLIER_PO",
        allocatedQuantity: 8,
        allocatedUnit: "kg",
        supplierPurchaseOrderLineReference: "PO-LINE-006",
      },
    ],
  },
  {
    fulfilmentAllocationId: "FA-INACTIVE-007",
    dispatchRequirementId:
      inactiveDestinationRequirementFixture.dispatchRequirementId,
    allocationStatus: "READY_FOR_DISPATCH",
    procurementReference: "WAREHOUSE-REQUEST-007",
    lines: [
      {
        fulfilmentAllocationLineId: "FAL-INACTIVE-007",
        dispatchRequirementLineId: "DRL-INACTIVE-007",
        sourceType: "WAREHOUSE_STOCK",
        allocatedQuantity: 5,
        allocatedUnit: "kg",
        warehouseStockRequestReference: "WSR-REQUEST-007",
      },
    ],
  },
];

const reviewEvidence: readonly FulfilmentEvidence[] = [
  ...fulfilmentEvidence.filter(
    (candidate) => candidate.fulfilmentEvidenceId !== "FE-MIXED-WAREHOUSE-004",
  ),
  {
    fulfilmentEvidenceId: "FE-RETURNED-006",
    fulfilmentAllocationLineId: "FAL-RETURNED-006",
    evidenceType: "SUPPLIER_RECEIVING",
    fulfilledQuantity: 8,
    fulfilledUnit: "kg",
    evidenceReference: "SUPPLIER-RECEIVING-006",
    recordedAt: "2026-07-14T05:00:00.000Z",
  },
  {
    fulfilmentEvidenceId: "FE-INACTIVE-007",
    fulfilmentAllocationLineId: "FAL-INACTIVE-007",
    evidenceType: "WAREHOUSE_STOCK_RELEASE",
    fulfilledQuantity: 5,
    fulfilledUnit: "kg",
    evidenceReference: "WAREHOUSE-RELEASE-007",
    recordedAt: "2026-07-14T05:02:00.000Z",
  },
];

export const dispatchOperatorReviewFixture: DispatchDeliveryState = {
  requirements: [
    schoolRequirement,
    schoolWarehouseRequirement,
    wholesaleRequirement,
    mixedFulfilmentRequirementFixture,
    exceptionRequirementFixture,
    returnedRequirement,
    inactiveDestinationRequirementFixture,
  ],
  allocations: reviewAllocations,
  fulfilmentEvidence: reviewEvidence,
  plans: [
    {
      dispatchPlanId: "DP-MORNING-01",
      serviceDate: "2026-07-14",
      dispatchRequirementIds: [
        "DR-SCHOOL-CROSSDOCK-001",
        "DR-SCHOOL-WAREHOUSE-002",
        "DR-EXCEPTION-005",
        "DR-RETURNED-006",
      ],
      fulfilmentAllocationIds: [
        "FA-SCHOOL-CROSSDOCK-001",
        "FA-SCHOOL-WAREHOUSE-002",
        "FA-EXCEPTION-005",
        "FA-RETURNED-006",
      ],
      status: "PARTIALLY_DELIVERED",
      createdBy: "dispatcher-lan",
      createdAt: "2026-07-14T03:30:00.000Z",
    },
    {
      dispatchPlanId: "DP-WHOLESALE-02",
      serviceDate: "2026-07-14",
      dispatchRequirementIds: ["DR-WHOLESALE-003"],
      fulfilmentAllocationIds: ["FA-WHOLESALE-003"],
      status: "PLANNED",
      createdBy: "dispatcher-lan",
      createdAt: "2026-07-14T03:35:00.000Z",
    },
    {
      dispatchPlanId: "DP-MIXED-03",
      serviceDate: "2026-07-14",
      dispatchRequirementIds: ["DR-MIXED-004"],
      fulfilmentAllocationIds: ["FA-MIXED-004"],
      status: "ASSIGNED",
      createdBy: "dispatcher-lan",
      createdAt: "2026-07-14T03:40:00.000Z",
    },
  ],
  trips: [
    {
      dispatchTripId: "DT-MORNING-01",
      dispatchPlanId: "DP-MORNING-01",
      status: "PARTIALLY_DELIVERED",
      routeReference: "MORNING-WAVE-A",
      driverReference: "DRIVER-REF-LAN",
      vehicleReference: "VEHICLE-REF-51",
      departedAt: "2026-07-14T05:20:00.000Z",
      stops: [
        {
          dispatchStopId: "DT-MORNING-01-STOP-1",
          dispatchTripId: "DT-MORNING-01",
          dispatchRequirementId: "DR-SCHOOL-CROSSDOCK-001",
          stopSequence: 1,
          destinationReference: "SCHOOL-AN-PHAT",
          destinationName: "An Phat School",
          deliveryLocationId: "DL-SCHOOL-AN-PHAT-KITCHEN",
          status: "DELIVERED",
        },
        {
          dispatchStopId: "DT-MORNING-01-STOP-2",
          dispatchTripId: "DT-MORNING-01",
          dispatchRequirementId: "DR-SCHOOL-WAREHOUSE-002",
          stopSequence: 2,
          destinationReference: "SCHOOL-BINH-MINH",
          destinationName: "Binh Minh School",
          deliveryLocationId: "DL-SCHOOL-BINH-MINH-KITCHEN",
          status: "LOADED",
        },
        {
          dispatchStopId: "DT-MORNING-01-STOP-3",
          dispatchTripId: "DT-MORNING-01",
          dispatchRequirementId: "DR-EXCEPTION-005",
          stopSequence: 3,
          destinationReference: "CUSTOMER-CLOSED-005",
          destinationName: "Closed Destination Customer",
          deliveryLocationId: "DL-CUSTOMER-CLOSED-005",
          status: "FAILED",
        },
        {
          dispatchStopId: "DT-MORNING-01-STOP-4",
          dispatchTripId: "DT-MORNING-01",
          dispatchRequirementId: "DR-RETURNED-006",
          stopSequence: 4,
          destinationReference: "CUSTOMER-RETURNED-006",
          destinationName: "Returned Goods Customer",
          deliveryLocationId: "DL-CUSTOMER-RETURNED-006",
          status: "RESOLVED_WITH_EXCEPTION",
        },
      ],
    },
    {
      dispatchTripId: "DT-MIXED-03",
      dispatchPlanId: "DP-MIXED-03",
      status: "ASSIGNED",
      routeReference: "MORNING-WAVE-C",
      driverReference: "DRIVER-REF-MINH",
      stops: [
        {
          dispatchStopId: "DT-MIXED-03-STOP-1",
          dispatchTripId: "DT-MIXED-03",
          dispatchRequirementId: "DR-MIXED-004",
          stopSequence: 1,
          destinationReference: "SCHOOL-HOA-SEN",
          destinationName: "Hoa Sen School",
          deliveryLocationId: "DL-SCHOOL-HOA-SEN-KITCHEN",
          status: "PENDING",
        },
      ],
    },
  ],
  loads: [
    {
      dispatchLoadId: "LOAD-CROSSDOCK-001",
      dispatchTripId: "DT-MORNING-01",
      dispatchRequirementId: "DR-SCHOOL-CROSSDOCK-001",
      fulfilmentAllocationId: "FA-SCHOOL-CROSSDOCK-001",
      loadedAt: "2026-07-14T05:05:00.000Z",
      loadedBy: "dispatcher-lan",
      lines: [
        {
          dispatchLoadLineId: "LOAD-LINE-CROSSDOCK-001",
          dispatchRequirementLineId: "DRL-SCHOOL-CROSSDOCK-001",
          fulfilmentAllocationLineId: "FAL-SCHOOL-CROSSDOCK-001",
          fulfilmentEvidenceIds: ["FE-CROSSDOCK-001"],
          loadedQuantity: 20,
          loadedUnit: "kg",
        },
      ],
    },
    {
      dispatchLoadId: "LOAD-WAREHOUSE-002",
      dispatchTripId: "DT-MORNING-01",
      dispatchRequirementId: "DR-SCHOOL-WAREHOUSE-002",
      fulfilmentAllocationId: "FA-SCHOOL-WAREHOUSE-002",
      loadedAt: "2026-07-14T05:08:00.000Z",
      loadedBy: "dispatcher-lan",
      lines: [
        {
          dispatchLoadLineId: "LOAD-LINE-WAREHOUSE-002",
          dispatchRequirementLineId: "DRL-SCHOOL-WAREHOUSE-002",
          fulfilmentAllocationLineId: "FAL-SCHOOL-WAREHOUSE-002",
          fulfilmentEvidenceIds: ["FE-WAREHOUSE-002"],
          loadedQuantity: 10,
          loadedUnit: "kg",
        },
      ],
    },
    {
      dispatchLoadId: "LOAD-EXCEPTION-005",
      dispatchTripId: "DT-MORNING-01",
      dispatchRequirementId: "DR-EXCEPTION-005",
      fulfilmentAllocationId: "FA-EXCEPTION-005",
      loadedAt: "2026-07-14T05:12:00.000Z",
      loadedBy: "dispatcher-lan",
      lines: [
        {
          dispatchLoadLineId: "LOAD-LINE-EXCEPTION-005",
          dispatchRequirementLineId: "DRL-EXCEPTION-005",
          fulfilmentAllocationLineId: "FAL-EXCEPTION-005",
          fulfilmentEvidenceIds: ["FE-EXCEPTION-005"],
          loadedQuantity: 12,
          loadedUnit: "kg",
        },
      ],
    },
    {
      dispatchLoadId: "LOAD-RETURNED-006",
      dispatchTripId: "DT-MORNING-01",
      dispatchRequirementId: "DR-RETURNED-006",
      fulfilmentAllocationId: "FA-RETURNED-006",
      loadedAt: "2026-07-14T05:15:00.000Z",
      loadedBy: "dispatcher-lan",
      lines: [
        {
          dispatchLoadLineId: "LOAD-LINE-RETURNED-006",
          dispatchRequirementLineId: "DRL-RETURNED-006",
          fulfilmentAllocationLineId: "FAL-RETURNED-006",
          fulfilmentEvidenceIds: ["FE-RETURNED-006"],
          loadedQuantity: 8,
          loadedUnit: "kg",
        },
      ],
    },
  ],
  confirmations: [
    {
      deliveryConfirmationId: "DC-CROSSDOCK-001",
      dispatchStopId: "DT-MORNING-01-STOP-1",
      confirmedAt: "2026-07-14T06:10:00.000Z",
      confirmedBy: "driver-lan",
      outcome: "DELIVERED",
      evidence: [
        {
          deliveryEvidenceId: "DE-CROSSDOCK-001",
          evidenceReference: "RECEIVER-SIGNATURE-001",
          evidenceType: "RECEIVER_REFERENCE",
        },
      ],
      lines: [
        {
          deliveryConfirmationLineId: "DCL-CROSSDOCK-001",
          dispatchLoadLineId: "LOAD-LINE-CROSSDOCK-001",
          deliveredQuantity: 20,
          returnedQuantity: 0,
          exceptionQuantity: 0,
          unit: "kg",
        },
      ],
    },
    {
      deliveryConfirmationId: "DC-EXCEPTION-005",
      dispatchStopId: "DT-MORNING-01-STOP-3",
      confirmedAt: "2026-07-14T06:40:00.000Z",
      confirmedBy: "driver-lan",
      outcome: "PARTIALLY_DELIVERED",
      evidence: [],
      lines: [
        {
          deliveryConfirmationLineId: "DCL-EXCEPTION-005",
          dispatchLoadLineId: "LOAD-LINE-EXCEPTION-005",
          deliveredQuantity: 7,
          returnedQuantity: 0,
          exceptionQuantity: 5,
          unit: "kg",
        },
      ],
    },
    {
      deliveryConfirmationId: "DC-RETURNED-006",
      dispatchStopId: "DT-MORNING-01-STOP-4",
      confirmedAt: "2026-07-14T06:55:00.000Z",
      confirmedBy: "driver-lan",
      outcome: "PARTIALLY_DELIVERED",
      evidence: [
        {
          deliveryEvidenceId: "DE-RETURNED-006",
          evidenceReference: "PARTIAL-HANDOVER-006",
          evidenceType: "HANDOVER_NOTE",
        },
      ],
      lines: [
        {
          deliveryConfirmationLineId: "DCL-RETURNED-006",
          dispatchLoadLineId: "LOAD-LINE-RETURNED-006",
          deliveredQuantity: 3,
          returnedQuantity: 0,
          exceptionQuantity: 5,
          unit: "kg",
        },
      ],
    },
  ],
  exceptions: [
    {
      deliveryExceptionId: "DX-UNRESOLVED-005",
      dispatchStopId: "DT-MORNING-01-STOP-3",
      dispatchLoadLineId: "LOAD-LINE-EXCEPTION-005",
      exceptionType: "DESTINATION_CLOSED",
      exceptionQuantity: 5,
      reason: "Receiver unavailable for the remaining quantity.",
      recordedAt: "2026-07-14T06:42:00.000Z",
      resolved: false,
    },
    {
      deliveryExceptionId: "DX-RETURNED-006",
      dispatchStopId: "DT-MORNING-01-STOP-4",
      dispatchLoadLineId: "LOAD-LINE-RETURNED-006",
      exceptionType: "REFUSED",
      exceptionQuantity: 5,
      reason: "Receiver accepted only part of the load.",
      recordedAt: "2026-07-14T06:56:00.000Z",
      resolved: true,
    },
  ],
  returns: [
    {
      returnEvidenceId: "RE-RETURNED-006",
      deliveryExceptionId: "DX-RETURNED-006",
      dispatchLoadLineId: "LOAD-LINE-RETURNED-006",
      returnedQuantity: 5,
      evidenceReference: "RETURN-HANDOVER-006",
      recordedAt: "2026-07-14T07:20:00.000Z",
    },
  ],
  statusChanges: [],
  auditEvents: [],
};

function reviewScenario(requirementId: string): DispatchDeliveryState {
  const requirement = dispatchOperatorReviewFixture.requirements.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const allocation = dispatchOperatorReviewFixture.allocations.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const allocationLineIds = allocation.lines.map(
    (candidate) => candidate.fulfilmentAllocationLineId,
  );
  const plan = dispatchOperatorReviewFixture.plans.find((candidate) =>
    candidate.dispatchRequirementIds.includes(requirementId),
  );
  const trip = dispatchOperatorReviewFixture.trips.find(
    (candidate) => candidate.dispatchPlanId === plan?.dispatchPlanId,
  );
  const stop = trip?.stops.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  );
  const loads = dispatchOperatorReviewFixture.loads.filter(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  );
  const loadLineIds = loads.flatMap((candidate) =>
    candidate.lines.map((line) => line.dispatchLoadLineId),
  );
  return {
    requirements: [requirement],
    allocations: [allocation],
    fulfilmentEvidence: dispatchOperatorReviewFixture.fulfilmentEvidence.filter(
      (candidate) =>
        allocationLineIds.includes(candidate.fulfilmentAllocationLineId),
    ),
    plans: plan
      ? [
          {
            ...plan,
            dispatchRequirementIds: [requirementId],
            fulfilmentAllocationIds: [allocation.fulfilmentAllocationId],
          },
        ]
      : [],
    trips:
      trip && stop
        ? [
            {
              ...trip,
              stops: [stop],
            },
          ]
        : [],
    loads,
    confirmations: dispatchOperatorReviewFixture.confirmations.filter(
      (candidate) =>
        candidate.dispatchStopId === stop?.dispatchStopId ||
        candidate.lines.some((line) =>
          loadLineIds.includes(line.dispatchLoadLineId),
        ),
    ),
    exceptions: dispatchOperatorReviewFixture.exceptions.filter(
      (candidate) =>
        candidate.dispatchStopId === stop?.dispatchStopId ||
        loadLineIds.includes(candidate.dispatchLoadLineId),
    ),
    returns: dispatchOperatorReviewFixture.returns.filter((candidate) =>
      loadLineIds.includes(candidate.dispatchLoadLineId),
    ),
    statusChanges: [],
    auditEvents: [],
  };
}

export const failedStopUnresolvedFixture = reviewScenario("DR-EXCEPTION-005");
export const returnedExceptionResolvedFixture =
  reviewScenario("DR-RETURNED-006");
export const partialDeliveryFixture: DispatchDeliveryState = {
  ...failedStopUnresolvedFixture,
  trips: failedStopUnresolvedFixture.trips.map((trip) => ({
    ...trip,
    status: "PARTIALLY_DELIVERED",
    stops: trip.stops.map((stop) => ({
      ...stop,
      status: "PARTIALLY_DELIVERED",
    })),
  })),
};

export const missingEvidenceBlockerFixture: DispatchDeliveryState = {
  ...dispatchDeliveryInputFixture,
  fulfilmentEvidence: dispatchDeliveryInputFixture.fulfilmentEvidence.filter(
    (candidate) => candidate.fulfilmentEvidenceId !== "FE-CROSSDOCK-001",
  ),
};

export const unassignedTripFixture: DispatchDeliveryState = {
  ...dispatchOperatorReviewFixture,
  requirements: [wholesaleRequirement],
  allocations: reviewAllocations.filter(
    (candidate) => candidate.dispatchRequirementId === "DR-WHOLESALE-003",
  ),
  fulfilmentEvidence: reviewEvidence.filter(
    (candidate) => candidate.fulfilmentAllocationLineId === "FAL-WHOLESALE-003",
  ),
  plans: dispatchOperatorReviewFixture.plans.filter(
    (candidate) => candidate.dispatchPlanId === "DP-WHOLESALE-02",
  ),
  trips: [],
  loads: [],
  confirmations: [],
  exceptions: [],
  returns: [],
};

export const loadedNotDepartedFixture: DispatchDeliveryState = {
  ...dispatchOperatorReviewFixture,
  requirements: [schoolWarehouseRequirement],
  allocations: reviewAllocations.filter(
    (candidate) =>
      candidate.dispatchRequirementId === "DR-SCHOOL-WAREHOUSE-002",
  ),
  fulfilmentEvidence: reviewEvidence.filter(
    (candidate) =>
      candidate.fulfilmentAllocationLineId === "FAL-SCHOOL-WAREHOUSE-002",
  ),
  plans: [
    {
      ...dispatchOperatorReviewFixture.plans[0],
      dispatchRequirementIds: ["DR-SCHOOL-WAREHOUSE-002"],
      fulfilmentAllocationIds: ["FA-SCHOOL-WAREHOUSE-002"],
      status: "LOADED",
    },
  ],
  trips: [
    {
      ...dispatchOperatorReviewFixture.trips[0],
      status: "LOADED",
      departedAt: undefined,
      stops: [dispatchOperatorReviewFixture.trips[0].stops[1]],
    },
  ],
  loads: dispatchOperatorReviewFixture.loads.filter(
    (candidate) =>
      candidate.dispatchRequirementId === "DR-SCHOOL-WAREHOUSE-002",
  ),
  confirmations: [],
  exceptions: [],
  returns: [],
};

export const inactiveDestinationBlockerFixture: DispatchDeliveryState = {
  ...dispatchDeliveryInputFixture,
  requirements: [inactiveDestinationRequirementFixture],
  allocations: reviewAllocations.filter(
    (candidate) => candidate.dispatchRequirementId === "DR-INACTIVE-007",
  ),
  fulfilmentEvidence: reviewEvidence.filter(
    (candidate) => candidate.fulfilmentAllocationLineId === "FAL-INACTIVE-007",
  ),
};

export const deliveryExceedsLoadFixture: DispatchDeliveryState = {
  ...dispatchOperatorReviewFixture,
  confirmations: dispatchOperatorReviewFixture.confirmations.map((candidate) =>
    candidate.deliveryConfirmationId === "DC-CROSSDOCK-001"
      ? {
          ...candidate,
          lines: candidate.lines.map((line) => ({
            ...line,
            deliveredQuantity: 21,
          })),
        }
      : candidate,
  ),
};
