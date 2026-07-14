import type {
  DeliveryConfirmation,
  DeliveryException,
  DispatchDeliveryState,
  DispatchLoad,
  DispatchPlan,
  DispatchRequirement,
  DispatchTrip,
  FulfilmentAllocation,
  FulfilmentAllocationLine,
  FulfilmentEvidence,
  ReturnEvidence,
} from "../dispatch/dispatchDeliveryDomain";
import type { MvpVerticalSliceSourceTrace } from "./mvpVerticalSlice";
import type {
  MorningChaosResources,
  MorningChaosTimelineEvent,
  MvpMorningChaosScenario,
} from "./mvpMorningChaos";

const serviceDate = "2026-07-15";

const schools = Array.from({ length: 10 }, (_, index) => ({
  referenceId: `SCHOOL-${String(index + 1).padStart(2, "0")}`,
  name: [
    "An Phat School",
    "Binh Minh School",
    "Hoa Sen School",
    "Nguyen Du School",
    "Minh Khai School",
    "Le Quy Don School",
    "Tran Phu School",
    "Kim Dong School",
    "Phan Chu Trinh School",
    "Vo Thi Sau School",
  ][index],
}));

const wholesaleCustomers = [
  { referenceId: "CUSTOMER-W01", name: "Minh An Wholesale" },
  { referenceId: "CUSTOMER-W02", name: "Thanh Cong Wholesale" },
];

const suppliers = [
  { referenceId: "SUPPLIER-A", name: "An Phu Produce" },
  { referenceId: "SUPPLIER-B", name: "Binh Minh Foods" },
  { referenceId: "SUPPLIER-C", name: "Thanh Cong Rice" },
  { referenceId: "SUPPLIER-D", name: "Hoa Viet Supply" },
];

export const mvpMorningChaosResources: MorningChaosResources = {
  schools,
  wholesaleCustomers,
  suppliers,
  warehouses: [
    { referenceId: "WAREHOUSE-CENTRAL-01", name: "Central Warehouse" },
  ],
  trips: [
    {
      dispatchTripId: "TRIP-A",
      vehicleReference: "VEHICLE-01",
      driverReference: "DRIVER-LAN",
    },
    {
      dispatchTripId: "TRIP-B",
      vehicleReference: "VEHICLE-02",
      driverReference: "DRIVER-MINH",
    },
    {
      dispatchTripId: "TRIP-C",
      vehicleReference: "VEHICLE-03",
      driverReference: "DRIVER-QUANG",
    },
  ],
};

function schoolRequirement(index: number): DispatchRequirement {
  const school = schools[index - 1];
  const id = `DR-S${String(index).padStart(2, "0")}`;
  const firstQuantity = index === 5 ? 10 : 8 + index;
  const secondQuantity = index === 10 ? 20 : 5 + (index % 4);
  return {
    dispatchRequirementId: id,
    sourceOfNeed: "SCHOOL_CATERING",
    planningReleaseReference: `PLANNING-RELEASE-${id}`,
    requirementStatus:
      index <= 4
        ? "DELIVERED"
        : index <= 8
          ? "CLOSED_WITH_EXCEPTION"
          : "FULFILMENT_READY",
    serviceOrDeliveryDate: serviceDate,
    destinationReference: school.referenceId,
    destinationName: school.name,
    deliveryLocationId: `DL-${school.referenceId}`,
    destinationActive: true,
    deliveryLocationActive: true,
    lines: [
      {
        dispatchRequirementLineId: `${id}-L1`,
        itemReference: index % 2 === 0 ? "ING-RICE" : "ING-PUMPKIN",
        requiredQuantity: firstQuantity,
        requiredUnit: "kg",
        sourceTraceId: `TRACE-${id}-L1`,
      },
      {
        dispatchRequirementLineId: `${id}-L2`,
        itemReference: index % 3 === 0 ? "ING-CARROT" : "ING-VEGETABLE",
        requiredQuantity: secondQuantity,
        requiredUnit: "kg",
        sourceTraceId: `TRACE-${id}-L2`,
      },
    ],
  };
}

function wholesaleRequirement(index: number): DispatchRequirement {
  const customer = wholesaleCustomers[index - 1];
  const id = `DR-W0${index}`;
  return {
    dispatchRequirementId: id,
    sourceOfNeed: "WHOLESALE",
    planningReleaseReference: `PLANNING-RELEASE-${id}`,
    requirementStatus: index === 1 ? "DELIVERED" : "CLOSED_WITH_EXCEPTION",
    serviceOrDeliveryDate: serviceDate,
    destinationReference: customer.referenceId,
    destinationName: customer.name,
    deliveryLocationId: `DL-${customer.referenceId}`,
    destinationActive: true,
    deliveryLocationActive: true,
    lines: Array.from({ length: 5 }, (_, lineIndex) => ({
      dispatchRequirementLineId: `${id}-L${lineIndex + 1}`,
      itemReference: [
        "PRODUCT-RICE",
        "PRODUCT-PUMPKIN",
        "PRODUCT-CARROT",
        "PRODUCT-POTATO",
        "PRODUCT-VEGETABLE",
      ][lineIndex],
      requiredQuantity: 12 + index * 3 + lineIndex,
      requiredUnit: "kg",
      sourceTraceId: `TRACE-${id}-L${lineIndex + 1}`,
    })),
  };
}

const latePlanningRevisionRequirement: DispatchRequirement = {
  dispatchRequirementId: "DR-S05-REV1",
  sourceOfNeed: "SCHOOL_CATERING",
  planningReleaseReference: "PLANNING-RELEASE-DR-S05-REV1",
  requirementStatus: "CLOSED_WITH_EXCEPTION",
  serviceOrDeliveryDate: serviceDate,
  destinationReference: schools[4].referenceId,
  destinationName: schools[4].name,
  deliveryLocationId: `DL-${schools[4].referenceId}`,
  destinationActive: true,
  deliveryLocationActive: true,
  operationalNote:
    "Explicit post-release attendance revision; original requirement remains unchanged.",
  lines: [
    {
      dispatchRequirementLineId: "DR-S05-REV1-L1",
      itemReference: "ING-PUMPKIN",
      requiredQuantity: 4,
      requiredUnit: "kg",
      sourceTraceId: "TRACE-DR-S05-REV1-L1",
    },
  ],
};

const requirements: readonly DispatchRequirement[] = [
  ...Array.from({ length: 10 }, (_, index) => schoolRequirement(index + 1)),
  wholesaleRequirement(1),
  wholesaleRequirement(2),
  latePlanningRevisionRequirement,
];

function allocationLinesFor(
  requirement: DispatchRequirement,
  globalStart: number,
): FulfilmentAllocationLine[] {
  return requirement.lines.flatMap((line, lineIndex) => {
    if (line.dispatchRequirementLineId === "DR-S10-L2")
      return [
        {
          fulfilmentAllocationLineId: "FAL-DR-S10-L2-SUPPLIER",
          dispatchRequirementLineId: line.dispatchRequirementLineId,
          sourceType: "SUPPLIER_PO" as const,
          allocatedQuantity: 12,
          allocatedUnit: line.requiredUnit,
          supplierPurchaseOrderLineReference: "PO-SUPPLIER-D-LATE-PARTIAL",
        },
        {
          fulfilmentAllocationLineId: "FAL-DR-S10-L2-WAREHOUSE",
          dispatchRequirementLineId: line.dispatchRequirementLineId,
          sourceType: "WAREHOUSE_STOCK" as const,
          allocatedQuantity: 8,
          allocatedUnit: line.requiredUnit,
          warehouseStockRequestReference: "WSR-FALLBACK-DR-S10-L2",
        },
      ];
    if (line.dispatchRequirementLineId === "DR-S03-L1")
      return [
        {
          fulfilmentAllocationLineId: "FAL-DR-S03-L1-SUPPLIER",
          dispatchRequirementLineId: line.dispatchRequirementLineId,
          sourceType: "SUPPLIER_PO" as const,
          allocatedQuantity: 7,
          allocatedUnit: line.requiredUnit,
          supplierPurchaseOrderLineReference: "PO-SUPPLIER-B-MIXED",
        },
        {
          fulfilmentAllocationLineId: "FAL-DR-S03-L1-WAREHOUSE",
          dispatchRequirementLineId: line.dispatchRequirementLineId,
          sourceType: "WAREHOUSE_STOCK" as const,
          allocatedQuantity: line.requiredQuantity - 7,
          allocatedUnit: line.requiredUnit,
          warehouseStockRequestReference: "WSR-MIXED-DR-S03-L1",
        },
      ];
    const globalIndex = globalStart + lineIndex;
    if (globalIndex % 4 === 0)
      return [
        {
          fulfilmentAllocationLineId: `FAL-${line.dispatchRequirementLineId}`,
          dispatchRequirementLineId: line.dispatchRequirementLineId,
          sourceType: "WAREHOUSE_STOCK" as const,
          allocatedQuantity: line.requiredQuantity,
          allocatedUnit: line.requiredUnit,
          warehouseStockRequestReference: `WSR-${line.dispatchRequirementLineId}`,
        },
      ];
    const supplier = suppliers[globalIndex % suppliers.length];
    return [
      {
        fulfilmentAllocationLineId: `FAL-${line.dispatchRequirementLineId}`,
        dispatchRequirementLineId: line.dispatchRequirementLineId,
        sourceType: "SUPPLIER_PO" as const,
        allocatedQuantity: line.requiredQuantity,
        allocatedUnit: line.requiredUnit,
        supplierPurchaseOrderLineReference: `PO-${supplier.referenceId}-${line.dispatchRequirementLineId}`,
      },
    ];
  });
}

let lineOffset = 0;
const allocations: readonly FulfilmentAllocation[] = requirements.map(
  (requirement) => {
    const lines = allocationLinesFor(requirement, lineOffset);
    lineOffset += requirement.lines.length;
    return {
      fulfilmentAllocationId: `FA-${requirement.dispatchRequirementId}`,
      dispatchRequirementId: requirement.dispatchRequirementId,
      allocationStatus:
        requirement.dispatchRequirementId === "DR-S10"
          ? "ALLOCATED"
          : "READY_FOR_DISPATCH",
      procurementReference: `PROCUREMENT-${requirement.dispatchRequirementId}`,
      lines,
    };
  },
);

const fulfilmentEvidence: readonly FulfilmentEvidence[] = allocations.flatMap(
  (allocation) =>
    allocation.lines.map((line) => {
      const partialWarehouse =
        line.fulfilmentAllocationLineId === "FAL-DR-S10-L2-WAREHOUSE";
      return {
        fulfilmentEvidenceId: `FE-${line.fulfilmentAllocationLineId}`,
        fulfilmentAllocationLineId: line.fulfilmentAllocationLineId,
        evidenceType:
          line.sourceType === "WAREHOUSE_STOCK"
            ? "WAREHOUSE_STOCK_RELEASE"
            : line.fulfilmentAllocationLineId === "FAL-DR-S10-L2-SUPPLIER"
              ? "SUPPLIER_RECEIVING"
              : "SUPPLIER_CROSS_DOCK",
        fulfilledQuantity: partialWarehouse ? 5 : line.allocatedQuantity,
        fulfilledUnit: line.allocatedUnit,
        evidenceReference: partialWarehouse
          ? "WAREHOUSE-RELEASE-FALLBACK-5-OF-8"
          : `EVIDENCE-${line.fulfilmentAllocationLineId}`,
        recordedAt: partialWarehouse
          ? `${serviceDate}T04:18:00.000Z`
          : line.fulfilmentAllocationLineId === "FAL-DR-S10-L2-SUPPLIER"
            ? `${serviceDate}T04:00:00.000Z`
            : `${serviceDate}T03:35:00.000Z`,
      } satisfies FulfilmentEvidence;
    }),
);

const tripARequirements = ["DR-S01", "DR-S02", "DR-S03", "DR-S04", "DR-W01"];
const tripBRequirements = [
  "DR-S05",
  "DR-S06",
  "DR-S07",
  "DR-S08",
  "DR-S05-REV1",
  "DR-W02",
];
const tripCRequirements = ["DR-S09", "DR-S10"];

function plan(
  dispatchPlanId: string,
  ids: readonly string[],
  status: DispatchPlan["status"],
  createdAt: string,
): DispatchPlan {
  return {
    dispatchPlanId,
    serviceDate,
    dispatchRequirementIds: ids,
    fulfilmentAllocationIds: ids.map((id) => `FA-${id}`),
    status,
    createdBy: "dispatcher-lan",
    createdAt,
  };
}

const plans: readonly DispatchPlan[] = [
  plan(
    "PLAN-A",
    tripARequirements,
    "DELIVERED",
    `${serviceDate}T04:20:00.000Z`,
  ),
  plan(
    "PLAN-B",
    tripBRequirements,
    "CLOSED_WITH_EXCEPTION",
    `${serviceDate}T04:22:00.000Z`,
  ),
  plan("PLAN-C", tripCRequirements, "LOADED", `${serviceDate}T04:25:00.000Z`),
];

function stopsFor(
  dispatchTripId: string,
  ids: readonly string[],
  statusFor: (id: string) => DispatchTrip["stops"][number]["status"],
) {
  return ids.map((id, index) => {
    const requirement = requirements.find(
      (candidate) => candidate.dispatchRequirementId === id,
    )!;
    return {
      dispatchStopId: `${dispatchTripId}-STOP-${index + 1}`,
      dispatchTripId,
      dispatchRequirementId: id,
      stopSequence: index + 1,
      destinationReference: requirement.destinationReference,
      destinationName: requirement.destinationName,
      deliveryLocationId: requirement.deliveryLocationId,
      status: statusFor(id),
    };
  });
}

const trips: readonly DispatchTrip[] = [
  {
    dispatchTripId: "TRIP-A",
    dispatchPlanId: "PLAN-A",
    status: "DELIVERED",
    routeReference: "MORNING-WAVE-A",
    driverReference: "DRIVER-LAN",
    vehicleReference: "VEHICLE-01",
    departedAt: `${serviceDate}T05:08:00.000Z`,
    completedAt: `${serviceDate}T07:00:00.000Z`,
    stops: stopsFor("TRIP-A", tripARequirements, () => "DELIVERED"),
  },
  {
    dispatchTripId: "TRIP-B",
    dispatchPlanId: "PLAN-B",
    status: "CLOSED_WITH_EXCEPTION",
    routeReference: "MORNING-WAVE-B",
    driverReference: "DRIVER-MINH",
    vehicleReference: "VEHICLE-02",
    departedAt: `${serviceDate}T05:42:00.000Z`,
    completedAt: `${serviceDate}T07:35:00.000Z`,
    stops: stopsFor("TRIP-B", tripBRequirements, (id) =>
      id === "DR-S06" ? "RESOLVED_WITH_EXCEPTION" : "DELIVERED",
    ),
  },
  {
    dispatchTripId: "TRIP-C",
    dispatchPlanId: "PLAN-C",
    status: "LOADED",
    routeReference: "MORNING-WAVE-C",
    driverReference: "DRIVER-QUANG",
    vehicleReference: "VEHICLE-03",
    stops: stopsFor("TRIP-C", tripCRequirements, (id) =>
      id === "DR-S09" ? "LOADED" : "PENDING",
    ),
  },
];

function loadFor(requirementId: string, dispatchTripId: string): DispatchLoad {
  const allocation = allocations.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  return {
    dispatchLoadId: `LOAD-${requirementId}`,
    dispatchTripId,
    dispatchRequirementId: requirementId,
    fulfilmentAllocationId: allocation.fulfilmentAllocationId,
    loadedAt:
      dispatchTripId === "TRIP-A"
        ? `${serviceDate}T04:40:00.000Z`
        : dispatchTripId === "TRIP-B"
          ? `${serviceDate}T04:44:00.000Z`
          : `${serviceDate}T04:48:00.000Z`,
    loadedBy: "dispatcher-lan",
    lines: allocation.lines.map((line, index) => ({
      dispatchLoadLineId: `LOAD-${requirementId}-LINE-${index + 1}`,
      dispatchRequirementLineId: line.dispatchRequirementLineId,
      fulfilmentAllocationLineId: line.fulfilmentAllocationLineId,
      fulfilmentEvidenceIds: [`FE-${line.fulfilmentAllocationLineId}`],
      loadedQuantity: line.allocatedQuantity,
      loadedUnit: line.allocatedUnit,
    })),
  };
}

const loads: readonly DispatchLoad[] = [
  ...tripARequirements.map((id) => loadFor(id, "TRIP-A")),
  ...tripBRequirements.map((id) => loadFor(id, "TRIP-B")),
  loadFor("DR-S09", "TRIP-C"),
];

function confirmationFor(
  requirementId: string,
  dispatchTripId: string,
): DeliveryConfirmation {
  const load = loads.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  )!;
  const stop = trips
    .find((candidate) => candidate.dispatchTripId === dispatchTripId)!
    .stops.find(
      (candidate) => candidate.dispatchRequirementId === requirementId,
    )!;
  const rejected = requirementId === "DR-S06";
  return {
    deliveryConfirmationId: `DC-${requirementId}`,
    dispatchStopId: stop.dispatchStopId,
    confirmedAt:
      dispatchTripId === "TRIP-A"
        ? `${serviceDate}T06:30:00.000Z`
        : `${serviceDate}T06:45:00.000Z`,
    confirmedBy: dispatchTripId === "TRIP-A" ? "DRIVER-LAN" : "DRIVER-MINH",
    outcome: rejected ? "PARTIALLY_DELIVERED" : "DELIVERED",
    evidence: [
      {
        deliveryEvidenceId: `DE-${requirementId}`,
        evidenceReference: rejected
          ? "SCHOOL-S06-PARTIAL-ACCEPTANCE"
          : `RECEIVER-${requirementId}`,
        evidenceType: rejected ? "HANDOVER_NOTE" : "RECEIVER_REFERENCE",
      },
    ],
    lines: load.lines.map((line, index) => ({
      deliveryConfirmationLineId: `DCL-${requirementId}-${index + 1}`,
      dispatchLoadLineId: line.dispatchLoadLineId,
      deliveredQuantity:
        rejected && index === 0 ? line.loadedQuantity - 4 : line.loadedQuantity,
      returnedQuantity: 0,
      exceptionQuantity: rejected && index === 0 ? 4 : 0,
      unit: line.loadedUnit,
    })),
  };
}

const confirmations: readonly DeliveryConfirmation[] = [
  ...tripARequirements.map((id) => confirmationFor(id, "TRIP-A")),
  ...tripBRequirements.map((id) => confirmationFor(id, "TRIP-B")),
];

const rejectedLoadLine = loads.find(
  (candidate) => candidate.dispatchRequirementId === "DR-S06",
)!.lines[0];
const rejectedStop = trips[1].stops.find(
  (candidate) => candidate.dispatchRequirementId === "DR-S06",
)!;
const deliveryException: DeliveryException = {
  deliveryExceptionId: "DX-S06-REJECTED",
  dispatchStopId: rejectedStop.dispatchStopId,
  dispatchLoadLineId: rejectedLoadLine.dispatchLoadLineId,
  exceptionType: "REFUSED",
  exceptionQuantity: 4,
  reason: "School rejected 4 kg at destination.",
  recordedAt: `${serviceDate}T06:47:00.000Z`,
  resolved: true,
};
const returnEvidence: ReturnEvidence = {
  returnEvidenceId: "RETURN-S06-REJECTED",
  deliveryExceptionId: deliveryException.deliveryExceptionId,
  dispatchLoadLineId: rejectedLoadLine.dispatchLoadLineId,
  returnedQuantity: 4,
  evidenceReference: "RETURN-HANDOVER-S06-4KG",
  recordedAt: `${serviceDate}T07:10:00.000Z`,
};

const sourceTraces: readonly MvpVerticalSliceSourceTrace[] =
  requirements.flatMap((requirement) =>
    requirement.lines.map((line) => ({
      dispatchRequirementLineId: line.dispatchRequirementLineId,
      demandSourceType:
        requirement.sourceOfNeed === "WHOLESALE"
          ? "WHOLESALE_ORDER"
          : requirement.dispatchRequirementId === "DR-S05-REV1"
            ? "CORRECTION"
            : "CATERING_MENU",
      demandSourceReference:
        requirement.dispatchRequirementId === "DR-S05-REV1"
          ? "ATTENDANCE-CHANGE-S05-0310"
          : requirement.sourceOfNeed === "WHOLESALE"
            ? `ORDER-${requirement.dispatchRequirementId}`
            : `MENU-${requirement.dispatchRequirementId}`,
      whoNeedsIt: requirement.destinationName,
      schoolStatus:
        requirement.sourceOfNeed === "SCHOOL_CATERING" ? "ACTIVE" : undefined,
      deliveryLocationReference: requirement.deliveryLocationId,
      confirmedNeedLineReference: `CN-${line.dispatchRequirementLineId}`,
      confirmedNeedStatus: "RELEASED_FOR_PURCHASE_HANDOFF",
      purchaseHandoffLineReference: `PHL-${line.dispatchRequirementLineId}`,
      purchaseHandoffStatus: "RELEASED_TO_PROCUREMENT",
      planningReleaseReference: requirement.planningReleaseReference,
      requiredQuantity: line.requiredQuantity,
      requiredUnit: line.requiredUnit,
    })),
  );

export const mvpMorningChaosTimeline: readonly MorningChaosTimelineEvent[] = [
  {
    eventId: "MC-0200-RELEASE",
    at: `${serviceDate}T02:00:00.000Z`,
    owner: "PLANNING",
    summary:
      "Original school and wholesale requirements released with immutable source traces.",
    requirementReferences: requirements
      .filter((candidate) => candidate.dispatchRequirementId !== "DR-S05-REV1")
      .map((candidate) => candidate.dispatchRequirementId),
  },
  {
    eventId: "MC-0310-LATE-CHANGE",
    at: `${serviceDate}T03:10:00.000Z`,
    owner: "PLANNING",
    summary:
      "Minh Khai School reports a late attendance increase after normal release.",
    requirementReferences: ["DR-S05", "DR-S05-REV1"],
    attentionStatus: "RESOLVED",
  },
  {
    eventId: "MC-0318-REVISION",
    at: `${serviceDate}T03:18:00.000Z`,
    owner: "PLANNING",
    summary:
      "Planning releases an explicit +4 kg revision; the original 10 kg line remains unchanged.",
    requirementReferences: ["DR-S05", "DR-S05-REV1"],
  },
  {
    eventId: "MC-0340-SUPPLIER-LATE",
    at: `${serviceDate}T03:40:00.000Z`,
    owner: "SUPPLIER_RECEIVING",
    summary: "Supplier D reports late arrival for the 20 kg DR-S10-L2 PO line.",
    requirementReferences: ["DR-S10"],
    attentionStatus: "RESOLVED",
  },
  {
    eventId: "MC-0400-SUPPLIER-PARTIAL",
    at: `${serviceDate}T04:00:00.000Z`,
    owner: "SUPPLIER_RECEIVING",
    summary:
      "Supplier D arrives late and physically evidences only 12 of 20 kg.",
    requirementReferences: ["DR-S10"],
  },
  {
    eventId: "MC-0405-REALLOCATION",
    at: `${serviceDate}T04:05:00.000Z`,
    owner: "PROCUREMENT",
    summary:
      "Procurement revises the remaining 8 kg from supplier PO to warehouse stock.",
    requirementReferences: ["DR-S10"],
    attentionStatus: "RESOLVED",
  },
  {
    eventId: "MC-0418-WAREHOUSE-PARTIAL",
    at: `${serviceDate}T04:18:00.000Z`,
    owner: "WAREHOUSE",
    summary:
      "WarehouseStockRelease evidences 5 of the requested 8 kg fallback; 3 kg remains uncovered.",
    requirementReferences: ["DR-S10"],
    attentionStatus: "OPEN",
  },
  {
    eventId: "MC-0420-TRIP-A-PREPARED",
    at: `${serviceDate}T04:20:00.000Z`,
    owner: "DISPATCH",
    summary:
      "Trip A is prepared while Trip B preparation proceeds independently.",
    requirementReferences: tripARequirements,
  },
  {
    eventId: "MC-0422-TRIP-B-PREPARED",
    at: `${serviceDate}T04:22:00.000Z`,
    owner: "DISPATCH",
    summary:
      "Trip B is prepared two minutes after Trip A without changing Trip A state.",
    requirementReferences: tripBRequirements,
  },
  {
    eventId: "MC-0430-TRIP-C-WAITING",
    at: `${serviceDate}T04:30:00.000Z`,
    owner: "DISPATCH",
    summary:
      "Trip C waits for complete physical evidence on DR-S10 while its DR-S09 load remains assigned correctly.",
    requirementReferences: tripCRequirements,
    attentionStatus: "OPEN",
  },
  {
    eventId: "MC-0508-TRIP-A-DEPARTED",
    at: `${serviceDate}T05:08:00.000Z`,
    owner: "DISPATCH",
    summary: "Trip A departs independently with complete source-backed loads.",
    requirementReferences: tripARequirements,
  },
  {
    eventId: "MC-0542-TRIP-B-LATE",
    at: `${serviceDate}T05:42:00.000Z`,
    owner: "DISPATCH",
    summary: "Trip B departs 32 minutes after its planned departure.",
    requirementReferences: tripBRequirements,
    attentionStatus: "RESOLVED",
  },
  {
    eventId: "MC-0645-REJECTION",
    at: `${serviceDate}T06:45:00.000Z`,
    owner: "DESTINATION_FOLLOW_UP",
    summary:
      "Le Quy Don School rejects 4 kg; Dispatch records explicit exception quantity.",
    requirementReferences: ["DR-S06"],
    attentionStatus: "RESOLVED",
  },
  {
    eventId: "MC-0710-RETURN",
    at: `${serviceDate}T07:10:00.000Z`,
    owner: "DESTINATION_FOLLOW_UP",
    summary:
      "Return handover evidence resolves the Dispatch exception path only.",
    requirementReferences: ["DR-S06"],
  },
  {
    eventId: "MC-0800-SHORTAGE-OPEN",
    at: `${serviceDate}T08:00:00.000Z`,
    owner: "PROCUREMENT",
    summary:
      "The remaining 3 kg shortage for DR-S10 is still visible and requires Procurement action.",
    requirementReferences: ["DR-S10"],
    attentionStatus: "OPEN",
  },
];

export const mvpMorningChaosScenario: MvpMorningChaosScenario = {
  resources: mvpMorningChaosResources,
  timeline: mvpMorningChaosTimeline,
  sourceTraces,
  planningRevisions: [
    {
      revisionReference: "PLANNING-REVISION-S05-01",
      originalRequirementReference: "DR-S05",
      revisedRequirementReference: "DR-S05-REV1",
      originalPlanningReleaseReference: "PLANNING-RELEASE-DR-S05",
      revisedPlanningReleaseReference: "PLANNING-RELEASE-DR-S05-REV1",
      originalQuantity: 10,
      changeQuantity: 4,
      revisedTotalQuantity: 14,
      unit: "kg",
      reason:
        "Late attendance increase reported after normal Planning release.",
      recordedAt: `${serviceDate}T03:18:00.000Z`,
    },
  ],
  allocationRevisions: [
    {
      revisionReference: "PROCUREMENT-REVISION-S10-01",
      dispatchRequirementLineId: "DR-S10-L2",
      previousSupplierQuantity: 20,
      revisedSupplierQuantity: 12,
      warehouseFallbackQuantity: 8,
      reason: "Supplier D physically fulfilled only 12 kg.",
      revisedAt: `${serviceDate}T04:05:00.000Z`,
    },
  ],
  tripTargets: [
    {
      dispatchTripId: "TRIP-A",
      plannedDepartureAt: `${serviceDate}T05:10:00.000Z`,
    },
    {
      dispatchTripId: "TRIP-B",
      plannedDepartureAt: `${serviceDate}T05:10:00.000Z`,
    },
    {
      dispatchTripId: "TRIP-C",
      plannedDepartureAt: `${serviceDate}T05:25:00.000Z`,
    },
  ],
  dispatchState: {
    requirements,
    allocations,
    fulfilmentEvidence,
    plans,
    trips,
    loads,
    confirmations,
    exceptions: [deliveryException],
    returns: [returnEvidence],
    statusChanges: [],
    auditEvents: [],
  } satisfies DispatchDeliveryState,
};
