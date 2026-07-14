export type SourceOfNeed = "SCHOOL_CATERING" | "WHOLESALE";
export type DispatchRequirementStatus =
  | "DRAFT"
  | "RELEASED_BY_PLANNING"
  | "ALLOCATED_FOR_FULFILMENT"
  | "FULFILMENT_READY"
  | "DISPATCHED"
  | "DELIVERED"
  | "CLOSED_WITH_EXCEPTION";
export type DispatchTripStatus =
  | "PLANNED"
  | "ASSIGNED"
  | "LOADED"
  | "IN_TRANSIT"
  | "PARTIALLY_DELIVERED"
  | "DELIVERED"
  | "CLOSED_WITH_EXCEPTION";
export type DeliveryStopStatus =
  | "PENDING"
  | "LOADED"
  | "IN_TRANSIT"
  | "DELIVERED"
  | "PARTIALLY_DELIVERED"
  | "FAILED"
  | "RETURNED"
  | "RESOLVED_WITH_EXCEPTION";
export type FulfilmentSourceType = "SUPPLIER_PO" | "WAREHOUSE_STOCK";
export type FulfilmentEvidenceType =
  "SUPPLIER_RECEIVING" | "SUPPLIER_CROSS_DOCK" | "WAREHOUSE_STOCK_RELEASE";

export type DispatchRequirementLine = Readonly<{
  dispatchRequirementLineId: string;
  itemReference: string;
  requiredQuantity: number;
  requiredUnit: string;
  sourceTraceId: string;
}>;

export type DispatchRequirement = Readonly<{
  dispatchRequirementId: string;
  sourceOfNeed: SourceOfNeed;
  planningReleaseReference: string;
  requirementStatus: DispatchRequirementStatus;
  serviceOrDeliveryDate: string;
  destinationReference: string;
  destinationName: string;
  deliveryLocationId: string;
  destinationActive: boolean;
  deliveryLocationActive: boolean;
  activeOverrideEvidence?: string;
  operationalNote?: string;
  lines: readonly DispatchRequirementLine[];
}>;

export type FulfilmentAllocationLine = Readonly<{
  fulfilmentAllocationLineId: string;
  dispatchRequirementLineId: string;
  sourceType: FulfilmentSourceType;
  allocatedQuantity: number;
  allocatedUnit: string;
  supplierPurchaseOrderLineReference?: string;
  warehouseStockRequestReference?: string;
}>;

export type FulfilmentAllocation = Readonly<{
  fulfilmentAllocationId: string;
  dispatchRequirementId: string;
  allocationStatus: "ALLOCATED" | "READY_FOR_DISPATCH";
  procurementReference: string;
  lines: readonly FulfilmentAllocationLine[];
}>;

export type FulfilmentEvidence = Readonly<{
  fulfilmentEvidenceId: string;
  fulfilmentAllocationLineId: string;
  evidenceType: FulfilmentEvidenceType;
  fulfilledQuantity: number;
  fulfilledUnit: string;
  evidenceReference: string;
  recordedAt: string;
}>;

export type DispatchPlan = Readonly<{
  dispatchPlanId: string;
  serviceDate: string;
  dispatchRequirementIds: readonly string[];
  fulfilmentAllocationIds: readonly string[];
  status: DispatchTripStatus;
  createdBy: string;
  createdAt: string;
}>;

export type DispatchStop = Readonly<{
  dispatchStopId: string;
  dispatchTripId: string;
  dispatchRequirementId: string;
  stopSequence: number;
  destinationReference: string;
  destinationName: string;
  deliveryLocationId: string;
  status: DeliveryStopStatus;
}>;

export type DispatchTrip = Readonly<{
  dispatchTripId: string;
  dispatchPlanId: string;
  status: DispatchTripStatus;
  routeReference?: string;
  driverReference?: string;
  vehicleReference?: string;
  departedAt?: string;
  completedAt?: string;
  stops: readonly DispatchStop[];
}>;

export type DispatchLoadLine = Readonly<{
  dispatchLoadLineId: string;
  dispatchRequirementLineId: string;
  fulfilmentAllocationLineId: string;
  fulfilmentEvidenceIds: readonly string[];
  loadedQuantity: number;
  loadedUnit: string;
}>;

export type DispatchLoad = Readonly<{
  dispatchLoadId: string;
  dispatchTripId: string;
  dispatchRequirementId: string;
  fulfilmentAllocationId: string;
  loadedAt: string;
  loadedBy: string;
  lines: readonly DispatchLoadLine[];
}>;

export type DeliveryEvidence = Readonly<{
  deliveryEvidenceId: string;
  evidenceReference: string;
  evidenceType: "RECEIVER_REFERENCE" | "HANDOVER_NOTE" | "PHOTO_REFERENCE";
}>;

export type DeliveryConfirmationLine = Readonly<{
  deliveryConfirmationLineId: string;
  dispatchLoadLineId: string;
  deliveredQuantity: number;
  returnedQuantity: number;
  exceptionQuantity: number;
  unit: string;
}>;

export type DeliveryConfirmation = Readonly<{
  deliveryConfirmationId: string;
  dispatchStopId: string;
  confirmedAt: string;
  confirmedBy: string;
  outcome: "DELIVERED" | "PARTIALLY_DELIVERED" | "FAILED";
  evidence: readonly DeliveryEvidence[];
  lines: readonly DeliveryConfirmationLine[];
}>;

export type DeliveryException = Readonly<{
  deliveryExceptionId: string;
  dispatchStopId: string;
  dispatchLoadLineId: string;
  exceptionType:
    | "DESTINATION_CLOSED"
    | "RECEIVER_UNAVAILABLE"
    | "SHORTAGE"
    | "DAMAGED"
    | "REFUSED"
    | "OTHER";
  exceptionQuantity: number;
  reason: string;
  recordedAt: string;
  resolved: boolean;
}>;

export type ReturnEvidence = Readonly<{
  returnEvidenceId: string;
  deliveryExceptionId: string;
  dispatchLoadLineId: string;
  returnedQuantity: number;
  evidenceReference: string;
  recordedAt: string;
}>;

export type DispatchEventType =
  | "DispatchPlanCreated"
  | "DispatchTripAssigned"
  | "DriverVehicleReferenceAssigned"
  | "DispatchLoadConfirmed"
  | "DispatchDeparted"
  | "DeliveryStopConfirmed"
  | "DeliveryExceptionRecorded"
  | "ReturnEvidenceRecorded"
  | "DispatchTripCompleted"
  | "DispatchAuditEventRecorded";

export type DispatchStatusChange = Readonly<{
  dispatchStatusChangeId: string;
  objectId: string;
  fromStatus: string;
  toStatus: string;
  changedBy: string;
  changedAt: string;
}>;

export type DispatchAuditEvent = Readonly<{
  dispatchAuditEventId: string;
  eventType: DispatchEventType;
  objectId: string;
  actorId: string;
  occurredAt: string;
  note: string;
}>;

export type DispatchDeliveryState = Readonly<{
  requirements: readonly DispatchRequirement[];
  allocations: readonly FulfilmentAllocation[];
  fulfilmentEvidence: readonly FulfilmentEvidence[];
  plans: readonly DispatchPlan[];
  trips: readonly DispatchTrip[];
  loads: readonly DispatchLoad[];
  confirmations: readonly DeliveryConfirmation[];
  exceptions: readonly DeliveryException[];
  returns: readonly ReturnEvidence[];
  statusChanges: readonly DispatchStatusChange[];
  auditEvents: readonly DispatchAuditEvent[];
}>;

export type DispatchIssueCode =
  | "REQUIREMENT_MISSING"
  | "REQUIREMENT_NOT_RELEASED"
  | "SOURCE_OF_NEED_MISSING"
  | "DESTINATION_MISSING"
  | "DELIVERY_LOCATION_MISSING"
  | "DESTINATION_INACTIVE"
  | "ALLOCATION_MISSING"
  | "ALLOCATION_INSUFFICIENT"
  | "ALLOCATION_SOURCE_INVALID"
  | "FULFILMENT_EVIDENCE_MISSING"
  | "FULFILMENT_EVIDENCE_INVALID"
  | "TRIP_MISSING"
  | "ASSIGNMENT_MISSING"
  | "LOAD_EXCEEDS_FULFILLED"
  | "DELIVERY_EXCEEDS_LOADED"
  | "DELIVERY_EVIDENCE_MISSING"
  | "QUANTITY_NOT_RECONCILED"
  | "EXCEPTION_UNRESOLVED"
  | "RETURN_EVIDENCE_MISSING"
  | "UPSTREAM_MUTATION_FORBIDDEN"
  | "CROSS_DOMAIN_ACTION_FORBIDDEN";

export type DispatchIssue = Readonly<{
  issueCode: DispatchIssueCode;
  message: string;
  isBlocking: boolean;
}>;
export type DispatchCommandResult = Readonly<{
  accepted: boolean;
  state: DispatchDeliveryState;
  blockers: readonly DispatchIssue[];
  warnings: readonly DispatchIssue[];
  event?: DispatchAuditEvent;
}>;

export const emptyDispatchDeliveryState = (): DispatchDeliveryState => ({
  requirements: [],
  allocations: [],
  fulfilmentEvidence: [],
  plans: [],
  trips: [],
  loads: [],
  confirmations: [],
  exceptions: [],
  returns: [],
  statusChanges: [],
  auditEvents: [],
});

const issue = (
  issueCode: DispatchIssueCode,
  message: string,
  isBlocking = true,
): DispatchIssue => ({ issueCode, message, isBlocking });
const result = (
  state: DispatchDeliveryState,
  issues: readonly DispatchIssue[] = [],
  event?: DispatchAuditEvent,
): DispatchCommandResult => ({
  accepted: !issues.some((candidate) => candidate.isBlocking),
  state,
  blockers: issues.filter((candidate) => candidate.isBlocking),
  warnings: issues.filter((candidate) => !candidate.isBlocking),
  event,
});
const audit = (
  eventType: DispatchEventType,
  objectId: string,
  actorId: string,
  occurredAt: string,
  note: string,
): DispatchAuditEvent => ({
  dispatchAuditEventId: `${objectId}-${eventType}-${occurredAt}`,
  eventType,
  objectId,
  actorId,
  occurredAt,
  note,
});
const withEvent = (
  state: DispatchDeliveryState,
  event: DispatchAuditEvent,
): DispatchDeliveryState => ({
  ...state,
  auditEvents: [...state.auditEvents, event],
});
const evidenceTypeFor = (
  source: FulfilmentSourceType,
  type: FulfilmentEvidenceType,
) =>
  source === "SUPPLIER_PO"
    ? type === "SUPPLIER_RECEIVING" || type === "SUPPLIER_CROSS_DOCK"
    : type === "WAREHOUSE_STOCK_RELEASE";
const total = (values: readonly number[]) =>
  values.reduce((sum, value) => sum + value, 0);

function validateRequirement(
  state: DispatchDeliveryState,
  requirementId: string,
) {
  const requirement = state.requirements.find(
    (candidate) => candidate.dispatchRequirementId === requirementId,
  );
  const issues: DispatchIssue[] = [];
  if (!requirement)
    return {
      issues: [
        issue(
          "REQUIREMENT_MISSING",
          "DispatchRequirement reference is required.",
        ),
      ],
    };
  if (
    ![
      "RELEASED_BY_PLANNING",
      "ALLOCATED_FOR_FULFILMENT",
      "FULFILMENT_READY",
    ].includes(requirement.requirementStatus)
  )
    issues.push(
      issue(
        "REQUIREMENT_NOT_RELEASED",
        "DispatchRequirement must be released by Planning.",
      ),
    );
  if (!requirement.sourceOfNeed)
    issues.push(issue("SOURCE_OF_NEED_MISSING", "Source of need is required."));
  if (!requirement.destinationReference)
    issues.push(
      issue(
        "DESTINATION_MISSING",
        "School, customer, or destination reference is required.",
      ),
    );
  if (!requirement.deliveryLocationId)
    issues.push(
      issue("DELIVERY_LOCATION_MISSING", "Delivery location is required."),
    );
  if (
    (!requirement.destinationActive || !requirement.deliveryLocationActive) &&
    !requirement.activeOverrideEvidence
  )
    issues.push(
      issue(
        "DESTINATION_INACTIVE",
        "Inactive destination or delivery location requires explicit override evidence.",
      ),
    );
  return { requirement, issues };
}

export function CreateDispatchPlanFromRequirements(
  state: DispatchDeliveryState,
  input: {
    dispatchPlanId: string;
    requirementIds: readonly string[];
    serviceDate: string;
    actorId: string;
    at: string;
    fullDispatchRequired?: boolean;
  },
): DispatchCommandResult {
  const issues: DispatchIssue[] = [];
  const allocations: FulfilmentAllocation[] = [];
  for (const id of input.requirementIds) {
    const checked = validateRequirement(state, id);
    issues.push(...checked.issues);
    if (!checked.requirement) continue;
    const allocation = state.allocations.find(
      (candidate) => candidate.dispatchRequirementId === id,
    );
    if (!allocation) {
      issues.push(
        issue(
          "ALLOCATION_MISSING",
          `FulfilmentAllocation is missing for ${id}.`,
        ),
      );
      continue;
    }
    allocations.push(allocation);
    for (const line of checked.requirement.lines) {
      const allocated = total(
        allocation.lines
          .filter(
            (candidate) =>
              candidate.dispatchRequirementLineId ===
              line.dispatchRequirementLineId,
          )
          .map((candidate) => candidate.allocatedQuantity),
      );
      if (
        (input.fullDispatchRequired ?? true) &&
        allocated < line.requiredQuantity
      )
        issues.push(
          issue(
            "ALLOCATION_INSUFFICIENT",
            `Allocated quantity is below required quantity for ${line.dispatchRequirementLineId}.`,
          ),
        );
    }
  }
  if (issues.some((candidate) => candidate.isBlocking))
    return result(state, issues);
  const plan: DispatchPlan = {
    dispatchPlanId: input.dispatchPlanId,
    serviceDate: input.serviceDate,
    dispatchRequirementIds: [...input.requirementIds],
    fulfilmentAllocationIds: allocations.map(
      (candidate) => candidate.fulfilmentAllocationId,
    ),
    status: "PLANNED",
    createdBy: input.actorId,
    createdAt: input.at,
  };
  const event = audit(
    "DispatchPlanCreated",
    plan.dispatchPlanId,
    input.actorId,
    input.at,
    "Dispatch plan created from immutable upstream references.",
  );
  return result(
    withEvent({ ...state, plans: [...state.plans, plan] }, event),
    issues,
    event,
  );
}

export function AssignDispatchTrip(
  state: DispatchDeliveryState,
  input: {
    dispatchTripId: string;
    dispatchPlanId: string;
    routeReference: string;
    actorId: string;
    at: string;
  },
): DispatchCommandResult {
  const plan = state.plans.find(
    (candidate) => candidate.dispatchPlanId === input.dispatchPlanId,
  );
  if (!plan)
    return result(state, [
      issue(
        "TRIP_MISSING",
        "DispatchPlan reference is required before trip assignment.",
      ),
    ]);
  const stops = plan.dispatchRequirementIds.map((id, index): DispatchStop => {
    const requirement = state.requirements.find(
      (candidate) => candidate.dispatchRequirementId === id,
    )!;
    return {
      dispatchStopId: `${input.dispatchTripId}-stop-${index + 1}`,
      dispatchTripId: input.dispatchTripId,
      dispatchRequirementId: id,
      stopSequence: index + 1,
      destinationReference: requirement.destinationReference,
      destinationName: requirement.destinationName,
      deliveryLocationId: requirement.deliveryLocationId,
      status: "PENDING",
    };
  });
  const trip: DispatchTrip = {
    dispatchTripId: input.dispatchTripId,
    dispatchPlanId: input.dispatchPlanId,
    status: "ASSIGNED",
    routeReference: input.routeReference,
    stops,
  };
  const event = audit(
    "DispatchTripAssigned",
    trip.dispatchTripId,
    input.actorId,
    input.at,
    "Trip and stop sequence assigned.",
  );
  return result(
    withEvent(
      {
        ...state,
        plans: state.plans.map((candidate) =>
          candidate.dispatchPlanId === plan.dispatchPlanId
            ? { ...candidate, status: "ASSIGNED" }
            : candidate,
        ),
        trips: [...state.trips, trip],
      },
      event,
    ),
    [],
    event,
  );
}

export function AssignDriverOrVehicleReference(
  state: DispatchDeliveryState,
  input: {
    dispatchTripId: string;
    driverReference?: string;
    vehicleReference?: string;
    actorId: string;
    at: string;
  },
): DispatchCommandResult {
  const trip = state.trips.find(
    (candidate) => candidate.dispatchTripId === input.dispatchTripId,
  );
  if (!trip)
    return result(state, [
      issue("TRIP_MISSING", "DispatchTrip reference is required."),
    ]);
  if (!input.driverReference && !input.vehicleReference)
    return result(state, [
      issue("ASSIGNMENT_MISSING", "Driver or vehicle reference is required."),
    ]);
  const event = audit(
    "DriverVehicleReferenceAssigned",
    trip.dispatchTripId,
    input.actorId,
    input.at,
    "Driver or vehicle reference assigned; no personnel or fleet record was created.",
  );
  return result(
    withEvent(
      {
        ...state,
        trips: state.trips.map((candidate) =>
          candidate.dispatchTripId === trip.dispatchTripId
            ? {
                ...candidate,
                driverReference:
                  input.driverReference ?? candidate.driverReference,
                vehicleReference:
                  input.vehicleReference ?? candidate.vehicleReference,
              }
            : candidate,
        ),
      },
      event,
    ),
    [
      issue(
        "ASSIGNMENT_MISSING",
        "Driver or vehicle reference was entered manually.",
        false,
      ),
    ],
    event,
  );
}

export function ConfirmDispatchLoad(
  state: DispatchDeliveryState,
  input: {
    dispatchLoadId: string;
    dispatchTripId: string;
    dispatchRequirementId: string;
    lines: readonly Omit<DispatchLoadLine, "dispatchLoadLineId">[];
    actorId: string;
    at: string;
  },
): DispatchCommandResult {
  const trip = state.trips.find(
    (candidate) => candidate.dispatchTripId === input.dispatchTripId,
  );
  const requirement = state.requirements.find(
    (candidate) =>
      candidate.dispatchRequirementId === input.dispatchRequirementId,
  );
  const allocation = state.allocations.find(
    (candidate) =>
      candidate.dispatchRequirementId === input.dispatchRequirementId,
  );
  const issues: DispatchIssue[] = [];
  if (!trip)
    issues.push(
      issue("TRIP_MISSING", "Assigned trip is required before loading."),
    );
  if (!requirement)
    issues.push(
      issue(
        "REQUIREMENT_MISSING",
        "DispatchRequirement reference is required.",
      ),
    );
  if (!allocation)
    issues.push(
      issue(
        "ALLOCATION_MISSING",
        "FulfilmentAllocation reference is required.",
      ),
    );
  if (trip && !trip.driverReference && !trip.vehicleReference)
    issues.push(
      issue(
        "ASSIGNMENT_MISSING",
        "Driver or vehicle reference is required before loading.",
      ),
    );
  if (allocation)
    for (const allocationLine of allocation.lines) {
      const loadLine = input.lines.find(
        (candidate) =>
          candidate.fulfilmentAllocationLineId ===
          allocationLine.fulfilmentAllocationLineId,
      );
      if (!loadLine) {
        issues.push(
          issue(
            "FULFILMENT_EVIDENCE_MISSING",
            `Every allocated portion requires a source-backed load line; ${allocationLine.fulfilmentAllocationLineId} is missing.`,
          ),
        );
        continue;
      }
      if (
        allocationLine.dispatchRequirementLineId !==
        loadLine.dispatchRequirementLineId
      ) {
        issues.push(
          issue(
            "ALLOCATION_SOURCE_INVALID",
            `Allocation line is invalid for ${loadLine.dispatchRequirementLineId}.`,
          ),
        );
        continue;
      }
      const evidence = state.fulfilmentEvidence.filter(
        (candidate) =>
          loadLine.fulfilmentEvidenceIds.includes(
            candidate.fulfilmentEvidenceId,
          ) &&
          candidate.fulfilmentAllocationLineId ===
            allocationLine.fulfilmentAllocationLineId,
      );
      if (!evidence.length)
        issues.push(
          issue(
            "FULFILMENT_EVIDENCE_MISSING",
            `Physical fulfilment evidence is required for ${allocationLine.fulfilmentAllocationLineId}.`,
          ),
        );
      if (
        evidence.some(
          (candidate) =>
            !evidenceTypeFor(allocationLine.sourceType, candidate.evidenceType),
        )
      )
        issues.push(
          issue(
            "FULFILMENT_EVIDENCE_INVALID",
            `Evidence type does not match ${allocationLine.sourceType}.`,
          ),
        );
      const fulfilled = total(
        evidence.map((candidate) => candidate.fulfilledQuantity),
      );
      if (loadLine.loadedQuantity > fulfilled)
        issues.push(
          issue(
            "LOAD_EXCEEDS_FULFILLED",
            `Loaded quantity exceeds fulfilled quantity for ${allocationLine.fulfilmentAllocationLineId}.`,
          ),
        );
    }
  if (
    issues.some((candidate) => candidate.isBlocking) ||
    !trip ||
    !requirement ||
    !allocation
  )
    return result(state, issues);
  const load: DispatchLoad = {
    dispatchLoadId: input.dispatchLoadId,
    dispatchTripId: trip.dispatchTripId,
    dispatchRequirementId: requirement.dispatchRequirementId,
    fulfilmentAllocationId: allocation.fulfilmentAllocationId,
    loadedBy: input.actorId,
    loadedAt: input.at,
    lines: input.lines.map((line, index) => ({
      ...line,
      dispatchLoadLineId: `${input.dispatchLoadId}-line-${index + 1}`,
    })),
  };
  const event = audit(
    "DispatchLoadConfirmed",
    load.dispatchLoadId,
    input.actorId,
    input.at,
    "Load confirmed only against matching physical fulfilment evidence.",
  );
  return result(
    withEvent(
      {
        ...state,
        loads: [...state.loads, load],
        trips: state.trips.map((candidate) =>
          candidate.dispatchTripId === trip.dispatchTripId
            ? {
                ...candidate,
                status: "LOADED",
                stops: candidate.stops.map((stop) =>
                  stop.dispatchRequirementId ===
                  requirement.dispatchRequirementId
                    ? { ...stop, status: "LOADED" }
                    : stop,
                ),
              }
            : candidate,
        ),
        plans: state.plans.map((candidate) =>
          candidate.dispatchPlanId === trip.dispatchPlanId
            ? { ...candidate, status: "LOADED" }
            : candidate,
        ),
      },
      event,
    ),
    issues,
    event,
  );
}

export function RecordDispatchDeparture(
  state: DispatchDeliveryState,
  input: { dispatchTripId: string; actorId: string; at: string },
): DispatchCommandResult {
  const trip = state.trips.find(
    (candidate) => candidate.dispatchTripId === input.dispatchTripId,
  );
  if (!trip)
    return result(state, [
      issue("TRIP_MISSING", "DispatchTrip reference is required."),
    ]);
  if (trip.status !== "LOADED")
    return result(state, [
      issue(
        "FULFILMENT_EVIDENCE_MISSING",
        "Trip must be fully loaded before departure.",
      ),
    ]);
  if (trip.stops.some((candidate) => candidate.status !== "LOADED"))
    return result(state, [
      issue(
        "FULFILMENT_EVIDENCE_MISSING",
        "Every stop must have a confirmed source-backed load before departure.",
      ),
    ]);
  const event = audit(
    "DispatchDeparted",
    trip.dispatchTripId,
    input.actorId,
    input.at,
    "Dispatch departure recorded.",
  );
  return result(
    withEvent(
      {
        ...state,
        trips: state.trips.map((candidate) =>
          candidate.dispatchTripId === trip.dispatchTripId
            ? {
                ...candidate,
                status: "IN_TRANSIT",
                departedAt: input.at,
                stops: candidate.stops.map((stop) => ({
                  ...stop,
                  status: "IN_TRANSIT",
                })),
              }
            : candidate,
        ),
        plans: state.plans.map((candidate) =>
          candidate.dispatchPlanId === trip.dispatchPlanId
            ? { ...candidate, status: "IN_TRANSIT" }
            : candidate,
        ),
        requirements: state.requirements.map((candidate) =>
          trip.stops.some(
            (stop) =>
              stop.dispatchRequirementId === candidate.dispatchRequirementId,
          )
            ? { ...candidate, requirementStatus: "DISPATCHED" }
            : candidate,
        ),
      },
      event,
    ),
    [],
    event,
  );
}

export function ConfirmDeliveryStop(
  state: DispatchDeliveryState,
  input: {
    dispatchTripId: string;
    confirmation: DeliveryConfirmation;
    actorId: string;
    at: string;
  },
): DispatchCommandResult {
  const trip = state.trips.find(
    (candidate) => candidate.dispatchTripId === input.dispatchTripId,
  );
  const issues: DispatchIssue[] = [];
  if (
    !trip ||
    !trip.stops.some(
      (candidate) =>
        candidate.dispatchStopId === input.confirmation.dispatchStopId,
    )
  )
    issues.push(
      issue("TRIP_MISSING", "Delivery stop must belong to the trip."),
    );
  if (!input.confirmation.evidence.length)
    issues.push(
      issue(
        "DELIVERY_EVIDENCE_MISSING",
        "Delivery confirmation requires delivery evidence.",
      ),
    );
  for (const line of input.confirmation.lines) {
    const loadLine = state.loads
      .flatMap((candidate) => candidate.lines)
      .find(
        (candidate) => candidate.dispatchLoadLineId === line.dispatchLoadLineId,
      );
    if (!loadLine || line.deliveredQuantity > loadLine.loadedQuantity)
      issues.push(
        issue(
          "DELIVERY_EXCEEDS_LOADED",
          `Delivered quantity exceeds loaded quantity for ${line.dispatchLoadLineId}.`,
        ),
      );
    if (
      loadLine &&
      line.deliveredQuantity +
        line.returnedQuantity +
        line.exceptionQuantity !==
        loadLine.loadedQuantity
    )
      issues.push(
        issue(
          "QUANTITY_NOT_RECONCILED",
          `Delivery outcome does not reconcile to loaded quantity for ${line.dispatchLoadLineId}.`,
        ),
      );
  }
  if (issues.some((candidate) => candidate.isBlocking) || !trip)
    return result(state, issues);
  const stopStatus: DeliveryStopStatus =
    input.confirmation.outcome === "DELIVERED"
      ? "DELIVERED"
      : input.confirmation.outcome === "FAILED"
        ? "FAILED"
        : "PARTIALLY_DELIVERED";
  const event = audit(
    "DeliveryStopConfirmed",
    input.confirmation.dispatchStopId,
    input.actorId,
    input.at,
    "Destination outcome confirmed with evidence.",
  );
  return result(
    withEvent(
      {
        ...state,
        confirmations: [...state.confirmations, input.confirmation],
        trips: state.trips.map((candidate) =>
          candidate.dispatchTripId === trip.dispatchTripId
            ? {
                ...candidate,
                status:
                  stopStatus === "DELIVERED" &&
                  candidate.stops.every(
                    (stop) =>
                      stop.dispatchStopId ===
                        input.confirmation.dispatchStopId ||
                      stop.status === "DELIVERED",
                  )
                    ? "DELIVERED"
                    : "PARTIALLY_DELIVERED",
                stops: candidate.stops.map((stop) =>
                  stop.dispatchStopId === input.confirmation.dispatchStopId
                    ? { ...stop, status: stopStatus }
                    : stop,
                ),
              }
            : candidate,
        ),
      },
      event,
    ),
    issues,
    event,
  );
}

export function RecordDeliveryException(
  state: DispatchDeliveryState,
  input: { exception: DeliveryException; actorId: string; at: string },
): DispatchCommandResult {
  const loadLine = state.loads
    .flatMap((candidate) => candidate.lines)
    .find(
      (candidate) =>
        candidate.dispatchLoadLineId === input.exception.dispatchLoadLineId,
    );
  if (!loadLine || input.exception.exceptionQuantity > loadLine.loadedQuantity)
    return result(state, [
      issue(
        "DELIVERY_EXCEEDS_LOADED",
        "Exception quantity cannot exceed loaded quantity.",
      ),
    ]);
  const event = audit(
    "DeliveryExceptionRecorded",
    input.exception.deliveryExceptionId,
    input.actorId,
    input.at,
    "Delivery exception recorded for resolution.",
  );
  return result(
    withEvent(
      { ...state, exceptions: [...state.exceptions, input.exception] },
      event,
    ),
    [],
    event,
  );
}

export function RecordReturnEvidence(
  state: DispatchDeliveryState,
  input: { returnEvidence: ReturnEvidence; actorId: string; at: string },
): DispatchCommandResult {
  const exception = state.exceptions.find(
    (candidate) =>
      candidate.deliveryExceptionId ===
      input.returnEvidence.deliveryExceptionId,
  );
  if (!exception || !input.returnEvidence.evidenceReference)
    return result(state, [
      issue(
        "RETURN_EVIDENCE_MISSING",
        "Return requires an exception and explicit return evidence.",
      ),
    ]);
  if (input.returnEvidence.returnedQuantity > exception.exceptionQuantity)
    return result(state, [
      issue(
        "QUANTITY_NOT_RECONCILED",
        "Returned quantity cannot exceed exception quantity.",
      ),
    ]);
  const resolved =
    input.returnEvidence.returnedQuantity === exception.exceptionQuantity;
  const event = audit(
    "ReturnEvidenceRecorded",
    input.returnEvidence.returnEvidenceId,
    input.actorId,
    input.at,
    "Return path recorded; Warehouse stock re-entry remains separate.",
  );
  return result(
    withEvent(
      {
        ...state,
        returns: [...state.returns, input.returnEvidence],
        exceptions: state.exceptions.map((candidate) =>
          candidate.deliveryExceptionId === exception.deliveryExceptionId
            ? { ...candidate, resolved }
            : candidate,
        ),
        trips: state.trips.map((trip) => ({
          ...trip,
          stops: trip.stops.map((stop) =>
            stop.dispatchStopId === exception.dispatchStopId && resolved
              ? { ...stop, status: "RETURNED" }
              : stop,
          ),
        })),
      },
      event,
    ),
    [],
    event,
  );
}

export function CompleteDispatchTrip(
  state: DispatchDeliveryState,
  input: { dispatchTripId: string; actorId: string; at: string },
): DispatchCommandResult {
  const trip = state.trips.find(
    (candidate) => candidate.dispatchTripId === input.dispatchTripId,
  );
  if (!trip)
    return result(state, [
      issue("TRIP_MISSING", "DispatchTrip reference is required."),
    ]);
  const stopIds = trip.stops.map((candidate) => candidate.dispatchStopId);
  const unresolved = state.exceptions.filter(
    (candidate) =>
      stopIds.includes(candidate.dispatchStopId) && !candidate.resolved,
  );
  if (unresolved.length)
    return result(state, [
      issue(
        "EXCEPTION_UNRESOLVED",
        "Trip cannot close while delivery exceptions are unresolved.",
      ),
    ]);
  const closedWithException = state.exceptions.some((candidate) =>
    stopIds.includes(candidate.dispatchStopId),
  );
  const allDelivered = trip.stops.every(
    (candidate) => candidate.status === "DELIVERED",
  );
  if (!allDelivered && !closedWithException)
    return result(state, [
      issue(
        "QUANTITY_NOT_RECONCILED",
        "Every stop must be delivered or resolved with exception evidence.",
      ),
    ]);
  const status: DispatchTripStatus = closedWithException
    ? "CLOSED_WITH_EXCEPTION"
    : "DELIVERED";
  const event = audit(
    "DispatchTripCompleted",
    trip.dispatchTripId,
    input.actorId,
    input.at,
    `Trip completed as ${status}.`,
  );
  const requirementIds = trip.stops.map(
    (candidate) => candidate.dispatchRequirementId,
  );
  return result(
    withEvent(
      {
        ...state,
        trips: state.trips.map((candidate) =>
          candidate.dispatchTripId === trip.dispatchTripId
            ? {
                ...candidate,
                status,
                completedAt: input.at,
                stops: candidate.stops.map((stop) =>
                  stop.status === "RETURNED"
                    ? { ...stop, status: "RESOLVED_WITH_EXCEPTION" }
                    : stop,
                ),
              }
            : candidate,
        ),
        plans: state.plans.map((candidate) =>
          candidate.dispatchPlanId === trip.dispatchPlanId
            ? { ...candidate, status }
            : candidate,
        ),
        requirements: state.requirements.map((candidate) =>
          requirementIds.includes(candidate.dispatchRequirementId)
            ? {
                ...candidate,
                requirementStatus: closedWithException
                  ? "CLOSED_WITH_EXCEPTION"
                  : "DELIVERED",
              }
            : candidate,
        ),
      },
      event,
    ),
    [],
    event,
  );
}

export function RecordDispatchAuditEvent(
  state: DispatchDeliveryState,
  input: { objectId: string; actorId: string; at: string; note: string },
): DispatchCommandResult {
  const event = audit(
    "DispatchAuditEventRecorded",
    input.objectId,
    input.actorId,
    input.at,
    input.note,
  );
  return result(withEvent(state, event), [], event);
}

export function AttemptUpstreamMutation(
  state: DispatchDeliveryState,
  target:
    | "PLANNING_REQUIREMENT"
    | "PROCUREMENT_ALLOCATION"
    | "WAREHOUSE_MOVEMENT"
    | "SUPPLIER_RECEIVING"
    | "CROSS_DOMAIN_APPROVAL",
): DispatchCommandResult {
  const upstream =
    target === "PLANNING_REQUIREMENT" || target === "PROCUREMENT_ALLOCATION";
  return result(state, [
    issue(
      upstream
        ? "UPSTREAM_MUTATION_FORBIDDEN"
        : "CROSS_DOMAIN_ACTION_FORBIDDEN",
      upstream
        ? "Dispatch cannot edit Planning requirements or Procurement allocations."
        : "Dispatch cannot create physical source records or represent approvals or settlements owned elsewhere.",
    ),
  ]);
}

export type DispatchAttentionCode =
  | "INACTIVE_DESTINATION"
  | "MISSING_FULFILMENT_EVIDENCE"
  | "MIXED_FULFILMENT_INCOMPLETE"
  | "TRIP_NOT_ASSIGNED"
  | "LOAD_NOT_CONFIRMED"
  | "DELIVERY_EVIDENCE_MISSING"
  | "DELIVERY_EXCEEDS_LOADED"
  | "UNRESOLVED_EXCEPTION"
  | "RETURN_EVIDENCE_REQUIRED"
  | "TRIP_CLOSURE_BLOCKED";

export type DispatchAttentionItem = Readonly<{
  attentionCode: DispatchAttentionCode;
  requirementReference: string;
  stopReference?: string;
  message: string;
}>;

export type DispatchDeliveryWorkbenchRow = Readonly<{
  sourceOfNeed: SourceOfNeed;
  requirementReference: string;
  planningReleaseReference: string;
  requirementStatus: DispatchRequirementStatus;
  allocationReference: string;
  fulfilmentSourceSplit: string;
  evidenceStatus: "READY" | "MISSING";
  readyToLoad: boolean;
  planReference: string;
  planStatus: string;
  tripReference: string;
  tripStatus: string;
  tripAssignmentStatus: "ASSIGNED" | "UNASSIGNED";
  driverReference: string;
  vehicleReference: string;
  stopSequence: number | null;
  stopStatus: string;
  destination: string;
  deliveryLocation: string;
  required: number;
  allocated: number;
  fulfilled: number;
  loaded: number;
  delivered: number;
  returned: number;
  exception: number;
  unit: string;
  deliveryEvidence: string;
  closureReadiness: "NOT_STARTED" | "BLOCKED" | "READY_TO_CLOSE" | "CLOSED";
  blockers: readonly string[];
}>;

export type DispatchDeliveryWorkbenchReadModel = Readonly<{
  rows: readonly DispatchDeliveryWorkbenchRow[];
  attentionQueue: readonly DispatchAttentionItem[];
  blockers: readonly string[];
  warnings: readonly string[];
  attentionStops: readonly string[];
  counts: Readonly<{
    total: number;
    readyToLoad: number;
    assigned: number;
    delivered: number;
    unresolved: number;
  }>;
}>;

function matchingEvidence(
  state: DispatchDeliveryState,
  allocationLine: FulfilmentAllocationLine,
) {
  return state.fulfilmentEvidence.filter(
    (candidate) =>
      candidate.fulfilmentAllocationLineId ===
        allocationLine.fulfilmentAllocationLineId &&
      evidenceTypeFor(allocationLine.sourceType, candidate.evidenceType),
  );
}

export function DispatchDeliveryWorkbench(
  state: DispatchDeliveryState,
): DispatchDeliveryWorkbenchReadModel {
  const attentionQueue: DispatchAttentionItem[] = [];
  const rows: DispatchDeliveryWorkbenchRow[] = state.requirements.map(
    (requirement) => {
      const requirementReference = requirement.dispatchRequirementId;
      const allocation = state.allocations.find(
        (candidate) => candidate.dispatchRequirementId === requirementReference,
      );
      const plan = state.plans.find((candidate) =>
        candidate.dispatchRequirementIds.includes(requirementReference),
      );
      const trip = state.trips.find(
        (candidate) =>
          candidate.dispatchPlanId === plan?.dispatchPlanId &&
          candidate.stops.some(
            (stop) => stop.dispatchRequirementId === requirementReference,
          ),
      );
      const stop = trip?.stops.find(
        (candidate) => candidate.dispatchRequirementId === requirementReference,
      );
      const loads = state.loads.filter(
        (candidate) =>
          candidate.dispatchRequirementId === requirementReference &&
          (!trip || candidate.dispatchTripId === trip.dispatchTripId),
      );
      const loadLines = loads.flatMap((candidate) => candidate.lines);
      const loadIds = loadLines.map(
        (candidate) => candidate.dispatchLoadLineId,
      );
      const confirmations = state.confirmations.filter(
        (candidate) =>
          candidate.dispatchStopId === stop?.dispatchStopId ||
          candidate.lines.some((line) =>
            loadIds.includes(line.dispatchLoadLineId),
          ),
      );
      const confirmationLines = confirmations.flatMap(
        (candidate) => candidate.lines,
      );
      const exceptions = state.exceptions.filter(
        (candidate) =>
          candidate.dispatchStopId === stop?.dispatchStopId ||
          loadIds.includes(candidate.dispatchLoadLineId),
      );
      const returns = state.returns.filter((candidate) =>
        loadIds.includes(candidate.dispatchLoadLineId),
      );
      const required = total(
        requirement.lines.map((candidate) => candidate.requiredQuantity),
      );
      const allocated = total(
        allocation?.lines.map((candidate) => candidate.allocatedQuantity) ?? [],
      );
      const fulfilled = total(
        allocation?.lines.flatMap((candidate) =>
          matchingEvidence(state, candidate).map(
            (evidence) => evidence.fulfilledQuantity,
          ),
        ) ?? [],
      );
      const loaded = total(
        loadLines.map((candidate) => candidate.loadedQuantity),
      );
      const delivered = total(
        confirmationLines.map((candidate) => candidate.deliveredQuantity),
      );
      const returned = Math.max(
        total(confirmationLines.map((candidate) => candidate.returnedQuantity)),
        total(returns.map((candidate) => candidate.returnedQuantity)),
      );
      const exceptionQuantity = Math.max(
        total(
          confirmationLines.map((candidate) => candidate.exceptionQuantity),
        ),
        total(exceptions.map((candidate) => candidate.exceptionQuantity)),
      );
      const evidenceReady =
        allocation?.lines.every(
          (line) =>
            total(
              matchingEvidence(state, line).map(
                (candidate) => candidate.fulfilledQuantity,
              ),
            ) >= line.allocatedQuantity,
        ) ?? false;
      const blockers = validateRequirement(state, requirementReference)
        .issues.filter((candidate) => candidate.isBlocking)
        .map((candidate) => candidate.message);
      const addAttention = (
        attentionCode: DispatchAttentionCode,
        message: string,
      ) => {
        attentionQueue.push({
          attentionCode,
          requirementReference,
          stopReference: stop?.dispatchStopId,
          message,
        });
        blockers.push(message);
      };

      if (
        (!requirement.destinationActive ||
          !requirement.deliveryLocationActive) &&
        !requirement.activeOverrideEvidence
      )
        addAttention(
          "INACTIVE_DESTINATION",
          `${requirementReference}: inactive destination or delivery location requires override evidence.`,
        );
      if (!evidenceReady) {
        addAttention(
          "MISSING_FULFILMENT_EVIDENCE",
          `${requirementReference}: physical fulfilment evidence is incomplete.`,
        );
        if ((allocation?.lines.length ?? 0) > 1)
          addAttention(
            "MIXED_FULFILMENT_INCOMPLETE",
            `${requirementReference}: every supplier and warehouse allocation portion requires matching evidence.`,
          );
      }
      if (!trip)
        addAttention(
          "TRIP_NOT_ASSIGNED",
          `${requirementReference}: dispatch trip is not assigned.`,
        );
      else if (!trip.driverReference || !trip.vehicleReference)
        addAttention(
          "TRIP_NOT_ASSIGNED",
          `${requirementReference}: driver and vehicle references are incomplete.`,
        );
      if (trip && !loads.length)
        addAttention(
          "LOAD_NOT_CONFIRMED",
          `${requirementReference}: source-backed load is not confirmed.`,
        );
      if (
        stop &&
        ["DELIVERED", "PARTIALLY_DELIVERED", "FAILED"].includes(stop.status) &&
        (!confirmations.length ||
          confirmations.some((candidate) => !candidate.evidence.length))
      )
        addAttention(
          "DELIVERY_EVIDENCE_MISSING",
          `${requirementReference}: destination outcome requires delivery evidence.`,
        );
      if (delivered > loaded)
        addAttention(
          "DELIVERY_EXCEEDS_LOADED",
          `${requirementReference}: delivered quantity exceeds loaded quantity.`,
        );
      const unresolved = exceptions.filter((candidate) => !candidate.resolved);
      if (unresolved.length) {
        addAttention(
          "UNRESOLVED_EXCEPTION",
          `${requirementReference}: ${unresolved.length} delivery exception(s) remain unresolved.`,
        );
        if (
          unresolved.some(
            (candidate) =>
              !returns.some(
                (returnEvidence) =>
                  returnEvidence.deliveryExceptionId ===
                  candidate.deliveryExceptionId,
              ),
          )
        )
          addAttention(
            "RETURN_EVIDENCE_REQUIRED",
            `${requirementReference}: return evidence is required to resolve the exception path.`,
          );
      }

      const closed =
        trip?.status === "DELIVERED" ||
        trip?.status === "CLOSED_WITH_EXCEPTION";
      const tripStopIds =
        trip?.stops.map((candidate) => candidate.dispatchStopId) ?? [];
      const tripHasUnresolvedException = state.exceptions.some(
        (candidate) =>
          tripStopIds.includes(candidate.dispatchStopId) && !candidate.resolved,
      );
      const tripStopsResolved =
        trip?.stops.every((candidate) =>
          ["DELIVERED", "RESOLVED_WITH_EXCEPTION"].includes(candidate.status),
        ) ?? false;
      const readyToClose =
        Boolean(trip) &&
        !closed &&
        blockers.length === 0 &&
        tripStopsResolved &&
        !tripHasUnresolvedException;
      let closureReadiness: DispatchDeliveryWorkbenchRow["closureReadiness"] =
        !plan
          ? "NOT_STARTED"
          : closed
            ? "CLOSED"
            : readyToClose
              ? "READY_TO_CLOSE"
              : "BLOCKED";
      if (plan && !closed && !readyToClose)
        addAttention(
          "TRIP_CLOSURE_BLOCKED",
          `${requirementReference}: trip closure is blocked by incomplete assignment, loading, delivery, or exception resolution.`,
        );
      if (!plan) closureReadiness = "NOT_STARTED";

      return {
        sourceOfNeed: requirement.sourceOfNeed,
        requirementReference,
        planningReleaseReference: requirement.planningReleaseReference,
        requirementStatus: requirement.requirementStatus,
        allocationReference: allocation?.fulfilmentAllocationId ?? "MISSING",
        fulfilmentSourceSplit:
          allocation?.lines
            .map(
              (candidate) =>
                `${candidate.sourceType} ${candidate.allocatedQuantity} ${candidate.allocatedUnit}`,
            )
            .join(" + ") ?? "MISSING",
        evidenceStatus: evidenceReady ? "READY" : "MISSING",
        readyToLoad: evidenceReady && allocated >= required,
        planReference: plan?.dispatchPlanId ?? "NOT_PLANNED",
        planStatus: plan?.status ?? "NOT_PLANNED",
        tripReference: trip?.dispatchTripId ?? "NOT_ASSIGNED",
        tripStatus: trip?.status ?? "NOT_ASSIGNED",
        tripAssignmentStatus: trip ? "ASSIGNED" : "UNASSIGNED",
        driverReference: trip?.driverReference ?? "UNASSIGNED",
        vehicleReference: trip?.vehicleReference ?? "UNASSIGNED",
        stopSequence: stop?.stopSequence ?? null,
        stopStatus: stop?.status ?? "NOT_ASSIGNED",
        destination: requirement.destinationName,
        deliveryLocation: requirement.deliveryLocationId,
        required,
        allocated,
        fulfilled,
        loaded,
        delivered,
        returned,
        exception: exceptionQuantity,
        unit: requirement.lines[0]?.requiredUnit ?? "",
        deliveryEvidence:
          [
            ...confirmations
              .flatMap((candidate) => candidate.evidence)
              .map((candidate) => candidate.evidenceReference),
            ...returns.map((candidate) => candidate.evidenceReference),
          ].join(", ") || "MISSING",
        closureReadiness,
        blockers,
      };
    },
  );
  const warnings = state.requirements
    .flatMap((candidate) => [
      candidate.operationalNote,
      candidate.sourceOfNeed === "WHOLESALE"
        ? `${candidate.dispatchRequirementId}: wholesale delivery uses a manually supplied customer-order trace.`
        : undefined,
    ])
    .filter((candidate): candidate is string => Boolean(candidate));
  const blockers = rows.flatMap((candidate) => candidate.blockers);
  const attentionStops = rows
    .filter(
      (candidate) =>
        candidate.stopSequence !== null && candidate.blockers.length,
    )
    .map(
      (candidate) =>
        `${candidate.stopSequence}. ${candidate.destination} — ${candidate.stopStatus}`,
    );
  return {
    rows,
    attentionQueue,
    blockers,
    warnings,
    attentionStops,
    counts: {
      total: rows.length,
      readyToLoad: rows.filter((candidate) => candidate.readyToLoad).length,
      assigned: rows.filter(
        (candidate) => candidate.tripAssignmentStatus === "ASSIGNED",
      ).length,
      delivered: rows.filter(
        (candidate) => candidate.stopStatus === "DELIVERED",
      ).length,
      unresolved: rows.filter((candidate) => candidate.blockers.length).length,
    },
  };
}
