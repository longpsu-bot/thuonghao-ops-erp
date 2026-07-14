import type { StockLot, WarehouseUpstreamSnapshot } from "./warehouseDomain";

export type ReleasableStockStatus =
  "AVAILABLE" | "ON_HOLD" | "QUARANTINED" | "DAMAGED" | "EXPIRED" | "CANCELLED";

export type ReleaseTrace = WarehouseUpstreamSnapshot & {
  stockLotId: string;
  goodsReceiptId: string;
  receivingSessionId: string;
};

export type OnHandStock = ReleaseTrace & {
  locationId: string;
  lotReference?: string;
  status: ReleasableStockStatus;
  onHandQuantity: number;
  availableQuantity: number;
  reservedQuantity: number;
};

export type WarehouseReleaseIssueCode =
  | "STOCK_MISSING"
  | "TRACE_MISSING"
  | "QUANTITY_NOT_POSITIVE"
  | "INSUFFICIENT_AVAILABLE_STOCK"
  | "STOCK_NOT_AVAILABLE"
  | "FULFILMENT_TARGET_MISSING"
  | "UNIT_MISMATCH"
  | "RESERVATION_NOT_VALID"
  | "RESERVATION_NOT_RELEASED_TO_PICK"
  | "PICK_LIST_NOT_VALID"
  | "PICK_LIST_NOT_PICKING"
  | "PICK_EXCEEDS_RESERVED"
  | "PICK_LIST_NOT_READY"
  | "RELEASE_NOT_VALID"
  | "RELEASE_EXCEEDS_PICKED"
  | "HANDOFF_TARGET_MISSING"
  | "HANDOFF_EVIDENCE_MISSING"
  | "MOVEMENT_ALREADY_POSTED"
  | "MOVEMENT_EXCEEDS_ON_HAND"
  | "PARTIAL_RELEASE";

export type WarehouseReleaseIssue = {
  issueCode: WarehouseReleaseIssueCode;
  message: string;
  isBlocking: boolean;
};

export type WarehouseReleaseChange = {
  changeId: string;
  eventType: string;
  objectId: string;
  actorId: string;
  at: string;
  beforeStatus?: string;
  afterStatus: string;
};

export type StockReservation = ReleaseTrace & {
  reservationId: string;
  fulfilmentTarget: string;
  requestedQuantity: number;
  reservedQuantity: number;
  status: "PREPARED" | "VALIDATED" | "RELEASED_TO_PICK" | "CANCELLED";
  issues: readonly WarehouseReleaseIssue[];
  changes: readonly WarehouseReleaseChange[];
};

export type PickLine = ReleaseTrace & {
  pickLineId: string;
  reservationId: string;
  reservedQuantity: number;
  pickedQuantity: number;
  shortQuantity: number;
};

export type PickList = {
  pickListId: string;
  reservationId: string;
  fulfilmentTarget: string;
  status: "PREPARED" | "VALIDATED" | "PICKING" | "READY_FOR_WAREHOUSE_RELEASE";
  lines: readonly PickLine[];
  issues: readonly WarehouseReleaseIssue[];
  changes: readonly WarehouseReleaseChange[];
};

export type WarehouseHandoffEvidence = {
  handoffEvidenceId: string;
  handoffTarget: string;
  handedOffBy: string;
  handedOffAt: string;
  packageCount: number;
  evidenceReference: string;
  note?: string;
  confirmsDestinationDelivery: false;
};

export type WarehouseReleaseLine = ReleaseTrace & {
  warehouseReleaseLineId: string;
  pickLineId: string;
  pickedQuantity: number;
  releasedQuantity: number;
};

export type WarehouseRelease = {
  warehouseReleaseId: string;
  pickListId: string;
  handoffTarget: string;
  status:
    "DRAFT" | "VALIDATED" | "RELEASED_FROM_WAREHOUSE" | "STOCK_MOVEMENT_POSTED";
  lines: readonly WarehouseReleaseLine[];
  handoffEvidence?: WarehouseHandoffEvidence;
  issues: readonly WarehouseReleaseIssue[];
  changes: readonly WarehouseReleaseChange[];
  confirmsDestinationDelivery: false;
};

export type StockMovement = ReleaseTrace & {
  stockMovementId: string;
  warehouseReleaseId: string;
  movementType: "RELEASE_FROM_WAREHOUSE";
  quantityDelta: number;
  status: "POSTED";
  postedBy: string;
  postedAt: string;
};

export type ReleaseResult<T> = {
  accepted: boolean;
  value?: T;
  blockers: readonly WarehouseReleaseIssue[];
  warnings: readonly WarehouseReleaseIssue[];
};

export type PostedStockMovementResult = {
  release: WarehouseRelease;
  movement: StockMovement;
  movements: readonly StockMovement[];
  onHandStock: OnHandStock;
};

const releaseIssue = (
  issueCode: WarehouseReleaseIssueCode,
  message: string,
  isBlocking = true,
): WarehouseReleaseIssue => ({ issueCode, message, isBlocking });

const releaseResult = <T>(
  value: T | undefined,
  issues: readonly WarehouseReleaseIssue[] = [],
): ReleaseResult<T> => ({
  accepted: !issues.some((candidate) => candidate.isBlocking),
  value,
  blockers: issues.filter((candidate) => candidate.isBlocking),
  warnings: issues.filter((candidate) => !candidate.isBlocking),
});

const traceFields: readonly (keyof ReleaseTrace)[] = [
  "stockLotId",
  "goodsReceiptId",
  "receivingSessionId",
  "purchaseOrderId",
  "purchaseOrderVersion",
  "purchaseOrderLineId",
  "purchaseAllocationLineId",
  "purchaseHandoffLineId",
  "confirmedNeedLineId",
  "needGenerationRunId",
  "planningInputSetId",
  "sourceTraceId",
  "supplierId",
  "supplierConfirmationReference",
  "releaseSnapshotReference",
  "ingredientId",
  "supplierConfirmedQuantity",
  "purchaseUnit",
];

function missingTrace(trace: ReleaseTrace) {
  return traceFields.some((field) => {
    const value = trace[field];
    return typeof value === "number" ? !Number.isFinite(value) : !value.trim();
  });
}

function traceFromStock(stock: OnHandStock): ReleaseTrace {
  return Object.fromEntries(
    traceFields.map((field) => [field, stock[field]]),
  ) as ReleaseTrace;
}

function change(
  eventType: string,
  objectId: string,
  actorId: string,
  at: string,
  afterStatus: string,
  beforeStatus?: string,
): WarehouseReleaseChange {
  return {
    changeId: `${objectId}-${eventType}-${at}`,
    eventType,
    objectId,
    actorId,
    at,
    beforeStatus,
    afterStatus,
  };
}

export function OnHandStockFromStockLot(
  stockLot: StockLot,
  receivingSessionId: string,
): OnHandStock {
  return {
    ...stockLot,
    receivingSessionId,
    locationId: stockLot.locationId ?? "",
    status: stockLot.status,
    onHandQuantity: stockLot.quantity,
    availableQuantity: stockLot.status === "AVAILABLE" ? stockLot.quantity : 0,
    reservedQuantity: 0,
  };
}

export function CreateStockReservation(input: {
  reservationId: string;
  stock?: OnHandStock;
  fulfilmentTarget: string;
  requestedQuantity: number;
  purchaseUnit: string;
  unitConversionEvidence?: string;
  actorId: string;
  at: string;
}): ReleaseResult<StockReservation> {
  const issues: WarehouseReleaseIssue[] = [];
  if (!input.stock)
    issues.push(releaseIssue("STOCK_MISSING", "Controlled stock is required."));
  if (input.stock && missingTrace(input.stock))
    issues.push(releaseIssue("TRACE_MISSING", "Stock trace is incomplete."));
  if (input.requestedQuantity <= 0)
    issues.push(
      releaseIssue(
        "QUANTITY_NOT_POSITIVE",
        "Requested quantity must be positive.",
      ),
    );
  if (input.stock && input.requestedQuantity > input.stock.availableQuantity)
    issues.push(
      releaseIssue(
        "INSUFFICIENT_AVAILABLE_STOCK",
        "Requested quantity exceeds available stock.",
      ),
    );
  if (input.stock?.status !== "AVAILABLE")
    issues.push(
      releaseIssue(
        "STOCK_NOT_AVAILABLE",
        "Held, quarantined, damaged, expired, or cancelled stock cannot be reserved.",
      ),
    );
  if (!input.fulfilmentTarget.trim())
    issues.push(
      releaseIssue(
        "FULFILMENT_TARGET_MISSING",
        "Fulfilment target is required.",
      ),
    );
  if (
    input.stock &&
    input.purchaseUnit !== input.stock.purchaseUnit &&
    !input.unitConversionEvidence?.trim()
  )
    issues.push(
      releaseIssue(
        "UNIT_MISMATCH",
        "Unit mismatch requires conversion evidence.",
      ),
    );
  if (!input.stock || issues.some((candidate) => candidate.isBlocking))
    return releaseResult<StockReservation>(undefined, issues);
  const reservation: StockReservation = {
    ...traceFromStock(input.stock),
    reservationId: input.reservationId,
    fulfilmentTarget: input.fulfilmentTarget,
    requestedQuantity: input.requestedQuantity,
    reservedQuantity: input.requestedQuantity,
    status: "PREPARED",
    issues: [],
    changes: [
      change(
        "StockReservationCreated",
        input.reservationId,
        input.actorId,
        input.at,
        "PREPARED",
      ),
    ],
  };
  return releaseResult(reservation);
}

export function ValidateStockReservation(
  reservation: StockReservation,
  actorId: string,
  at: string,
): ReleaseResult<StockReservation> {
  const issues =
    reservation.status !== "PREPARED" ||
    reservation.issues.some((item) => item.isBlocking)
      ? [
          releaseIssue(
            "RESERVATION_NOT_VALID",
            "Prepared reservation without blockers is required.",
          ),
        ]
      : [];
  if (issues.length) return releaseResult(reservation, issues);
  return releaseResult({
    ...reservation,
    status: "VALIDATED",
    changes: [
      ...reservation.changes,
      change(
        "StockReservationValidated",
        reservation.reservationId,
        actorId,
        at,
        "VALIDATED",
        reservation.status,
      ),
    ],
  });
}

export function ReleaseStockReservationToPick(
  reservation: StockReservation,
  actorId: string,
  at: string,
): ReleaseResult<StockReservation> {
  if (reservation.status !== "VALIDATED")
    return releaseResult(reservation, [
      releaseIssue(
        "RESERVATION_NOT_VALID",
        "Validated reservation is required.",
      ),
    ]);
  return releaseResult({
    ...reservation,
    status: "RELEASED_TO_PICK",
    changes: [
      ...reservation.changes,
      change(
        "StockReservationReleasedToPick",
        reservation.reservationId,
        actorId,
        at,
        "RELEASED_TO_PICK",
        reservation.status,
      ),
    ],
  });
}

export function CreatePickListFromReservation(
  reservation: StockReservation,
  pickListId: string,
  actorId: string,
  at: string,
): ReleaseResult<PickList> {
  if (reservation.status !== "RELEASED_TO_PICK")
    return releaseResult<PickList>(undefined, [
      releaseIssue(
        "RESERVATION_NOT_RELEASED_TO_PICK",
        "Reservation must be released to picking.",
      ),
    ]);
  const line: PickLine = {
    ...reservation,
    pickLineId: `${pickListId}-line-1`,
    reservationId: reservation.reservationId,
    reservedQuantity: reservation.reservedQuantity,
    pickedQuantity: 0,
    shortQuantity: reservation.reservedQuantity,
  };
  return releaseResult({
    pickListId,
    reservationId: reservation.reservationId,
    fulfilmentTarget: reservation.fulfilmentTarget,
    status: "PREPARED",
    lines: [line],
    issues: [],
    changes: [change("PickListCreated", pickListId, actorId, at, "PREPARED")],
  });
}

export function ValidatePickList(
  pickList: PickList,
  actorId: string,
  at: string,
): ReleaseResult<PickList> {
  const invalid =
    pickList.status !== "PREPARED" ||
    pickList.lines.some((line) => !line.stockLotId || missingTrace(line));
  if (invalid)
    return releaseResult(pickList, [
      releaseIssue(
        "PICK_LIST_NOT_VALID",
        "Prepared traced pick list is required.",
      ),
    ]);
  return releaseResult({
    ...pickList,
    status: "VALIDATED",
    changes: [
      ...pickList.changes,
      change(
        "PickListValidated",
        pickList.pickListId,
        actorId,
        at,
        "VALIDATED",
        pickList.status,
      ),
    ],
  });
}

export function StartPicking(
  pickList: PickList,
  actorId: string,
  at: string,
): ReleaseResult<PickList> {
  if (pickList.status !== "VALIDATED")
    return releaseResult(pickList, [
      releaseIssue("PICK_LIST_NOT_VALID", "Validated pick list is required."),
    ]);
  return releaseResult({
    ...pickList,
    status: "PICKING",
    changes: [
      ...pickList.changes,
      change(
        "PickingStarted",
        pickList.pickListId,
        actorId,
        at,
        "PICKING",
        pickList.status,
      ),
    ],
  });
}

export function RecordPickLine(
  pickList: PickList,
  input: { pickLineId: string; pickedQuantity: number },
  actorId: string,
  at: string,
): ReleaseResult<PickList> {
  const line = pickList.lines.find(
    (candidate) => candidate.pickLineId === input.pickLineId,
  );
  const issues: WarehouseReleaseIssue[] = [];
  if (pickList.status !== "PICKING")
    issues.push(
      releaseIssue("PICK_LIST_NOT_PICKING", "Picking must be started."),
    );
  if (!line || missingTrace(line))
    issues.push(releaseIssue("TRACE_MISSING", "Pick-line trace is required."));
  if (input.pickedQuantity <= 0)
    issues.push(
      releaseIssue(
        "QUANTITY_NOT_POSITIVE",
        "Picked quantity must be positive.",
      ),
    );
  if (line && input.pickedQuantity > line.reservedQuantity)
    issues.push(
      releaseIssue(
        "PICK_EXCEEDS_RESERVED",
        "Picked quantity cannot exceed reserved quantity.",
      ),
    );
  if (issues.length) return releaseResult(pickList, issues);
  return releaseResult({
    ...pickList,
    lines: pickList.lines.map((candidate) =>
      candidate.pickLineId === input.pickLineId
        ? {
            ...candidate,
            pickedQuantity: input.pickedQuantity,
            shortQuantity: candidate.reservedQuantity - input.pickedQuantity,
          }
        : candidate,
    ),
    changes: [
      ...pickList.changes,
      change(
        "PickLineRecorded",
        pickList.pickListId,
        actorId,
        at,
        pickList.status,
        pickList.status,
      ),
    ],
  });
}

export function MarkPickListReadyForRelease(
  pickList: PickList,
  actorId: string,
  at: string,
): ReleaseResult<PickList> {
  if (
    pickList.status !== "PICKING" ||
    pickList.lines.some((line) => line.pickedQuantity <= 0)
  )
    return releaseResult(pickList, [
      releaseIssue(
        "PICK_LIST_NOT_PICKING",
        "Positive pick evidence is required.",
      ),
    ]);
  return releaseResult({
    ...pickList,
    status: "READY_FOR_WAREHOUSE_RELEASE",
    changes: [
      ...pickList.changes,
      change(
        "PickListReadyForRelease",
        pickList.pickListId,
        actorId,
        at,
        "READY_FOR_WAREHOUSE_RELEASE",
        pickList.status,
      ),
    ],
  });
}

export function CreateWarehouseReleaseFromPickList(input: {
  pickList: PickList;
  warehouseReleaseId: string;
  handoffTarget: string;
  releasedQuantities?: Readonly<Record<string, number>>;
  actorId: string;
  at: string;
}): ReleaseResult<WarehouseRelease> {
  if (input.pickList.status !== "READY_FOR_WAREHOUSE_RELEASE")
    return releaseResult<WarehouseRelease>(undefined, [
      releaseIssue(
        "PICK_LIST_NOT_READY",
        "Pick list must be ready for release.",
      ),
    ]);
  if (!input.handoffTarget.trim())
    return releaseResult<WarehouseRelease>(undefined, [
      releaseIssue(
        "HANDOFF_TARGET_MISSING",
        "Warehouse handoff target is required.",
      ),
    ]);
  const lines = input.pickList.lines.map<WarehouseReleaseLine>((line) => ({
    ...line,
    warehouseReleaseLineId: `${input.warehouseReleaseId}-${line.pickLineId}`,
    pickLineId: line.pickLineId,
    pickedQuantity: line.pickedQuantity,
    releasedQuantity:
      input.releasedQuantities?.[line.pickLineId] ?? line.pickedQuantity,
  }));
  return releaseResult({
    warehouseReleaseId: input.warehouseReleaseId,
    pickListId: input.pickList.pickListId,
    handoffTarget: input.handoffTarget,
    status: "DRAFT",
    lines,
    issues: [],
    changes: [
      change(
        "WarehouseReleaseCreated",
        input.warehouseReleaseId,
        input.actorId,
        input.at,
        "DRAFT",
      ),
    ],
    confirmsDestinationDelivery: false,
  });
}

export function ValidateWarehouseRelease(
  release: WarehouseRelease,
  actorId: string,
  at: string,
): ReleaseResult<WarehouseRelease> {
  const issues: WarehouseReleaseIssue[] = [];
  if (release.status !== "DRAFT")
    issues.push(
      releaseIssue("RELEASE_NOT_VALID", "Draft release is required."),
    );
  if (!release.handoffTarget.trim())
    issues.push(
      releaseIssue("HANDOFF_TARGET_MISSING", "Handoff target is required."),
    );
  for (const line of release.lines) {
    if (!line.stockLotId || missingTrace(line))
      issues.push(
        releaseIssue("TRACE_MISSING", "Release-line trace is required."),
      );
    if (line.releasedQuantity <= 0)
      issues.push(
        releaseIssue(
          "QUANTITY_NOT_POSITIVE",
          "Release quantity must be positive.",
        ),
      );
    if (line.releasedQuantity > line.pickedQuantity)
      issues.push(
        releaseIssue(
          "RELEASE_EXCEEDS_PICKED",
          "Release quantity cannot exceed picked quantity.",
        ),
      );
    if (line.releasedQuantity < line.pickedQuantity)
      issues.push(
        releaseIssue("PARTIAL_RELEASE", "Partial release recorded.", false),
      );
  }
  if (issues.some((candidate) => candidate.isBlocking))
    return releaseResult(release, issues);
  return releaseResult(
    {
      ...release,
      status: "VALIDATED",
      issues,
      changes: [
        ...release.changes,
        change(
          "WarehouseReleaseValidated",
          release.warehouseReleaseId,
          actorId,
          at,
          "VALIDATED",
          release.status,
        ),
      ],
    },
    issues,
  );
}

export function RecordWarehouseHandoffEvidence(
  release: WarehouseRelease,
  evidence: Omit<
    WarehouseHandoffEvidence,
    "handoffEvidenceId" | "confirmsDestinationDelivery"
  >,
): ReleaseResult<WarehouseRelease> {
  if (
    release.status !== "VALIDATED" ||
    !evidence.handoffTarget.trim() ||
    evidence.handoffTarget !== release.handoffTarget ||
    !evidence.handedOffBy.trim() ||
    !evidence.evidenceReference.trim() ||
    evidence.packageCount <= 0
  )
    return releaseResult(release, [
      releaseIssue(
        "HANDOFF_EVIDENCE_MISSING",
        "Complete Warehouse custody handoff evidence is required.",
      ),
    ]);
  return releaseResult({
    ...release,
    handoffEvidence: {
      ...evidence,
      handoffEvidenceId: `${release.warehouseReleaseId}-handoff-1`,
      confirmsDestinationDelivery: false,
    },
    changes: [
      ...release.changes,
      change(
        "WarehouseHandoffEvidenceRecorded",
        release.warehouseReleaseId,
        evidence.handedOffBy,
        evidence.handedOffAt,
        release.status,
        release.status,
      ),
    ],
  });
}

export function ReleaseGoodsFromWarehouse(
  release: WarehouseRelease,
  actorId: string,
  at: string,
): ReleaseResult<WarehouseRelease> {
  if (release.status !== "VALIDATED")
    return releaseResult(release, [
      releaseIssue("RELEASE_NOT_VALID", "Validated release is required."),
    ]);
  if (!release.handoffEvidence)
    return releaseResult(release, [
      releaseIssue("HANDOFF_EVIDENCE_MISSING", "Handoff evidence is required."),
    ]);
  return releaseResult({
    ...release,
    status: "RELEASED_FROM_WAREHOUSE",
    changes: [
      ...release.changes,
      change(
        "GoodsReleasedFromWarehouse",
        release.warehouseReleaseId,
        actorId,
        at,
        "RELEASED_FROM_WAREHOUSE",
        release.status,
      ),
    ],
    confirmsDestinationDelivery: false,
  });
}

export function PostReleaseStockMovement(input: {
  release: WarehouseRelease;
  stock: OnHandStock;
  movements: readonly StockMovement[];
  actorId: string;
  at: string;
}): ReleaseResult<PostedStockMovementResult> {
  if (input.release.status === "STOCK_MOVEMENT_POSTED")
    return releaseResult<PostedStockMovementResult>(undefined, [
      releaseIssue(
        "MOVEMENT_ALREADY_POSTED",
        "Release movement is already posted.",
      ),
    ]);
  if (input.release.status !== "RELEASED_FROM_WAREHOUSE")
    return releaseResult<PostedStockMovementResult>(undefined, [
      releaseIssue(
        "RELEASE_NOT_VALID",
        "Released Warehouse custody evidence is required.",
      ),
    ]);
  const line = input.release.lines.find(
    (candidate) => candidate.stockLotId === input.stock.stockLotId,
  );
  if (!line || line.releasedQuantity > input.stock.onHandQuantity)
    return releaseResult<PostedStockMovementResult>(undefined, [
      releaseIssue(
        "MOVEMENT_EXCEEDS_ON_HAND",
        "Posted release movement cannot exceed on-hand stock.",
      ),
    ]);
  const movement: StockMovement = {
    ...traceFromStock(input.stock),
    stockMovementId: `${input.release.warehouseReleaseId}-movement-${input.movements.length + 1}`,
    warehouseReleaseId: input.release.warehouseReleaseId,
    movementType: "RELEASE_FROM_WAREHOUSE",
    quantityDelta: -line.releasedQuantity,
    status: "POSTED",
    postedBy: input.actorId,
    postedAt: input.at,
  };
  const onHandStock: OnHandStock = {
    ...input.stock,
    onHandQuantity: input.stock.onHandQuantity + movement.quantityDelta,
    availableQuantity: input.stock.availableQuantity + movement.quantityDelta,
    reservedQuantity: Math.max(
      0,
      input.stock.reservedQuantity - line.releasedQuantity,
    ),
  };
  const release: WarehouseRelease = {
    ...input.release,
    status: "STOCK_MOVEMENT_POSTED",
    changes: [
      ...input.release.changes,
      change(
        "ReleaseStockMovementPosted",
        input.release.warehouseReleaseId,
        input.actorId,
        input.at,
        "STOCK_MOVEMENT_POSTED",
        input.release.status,
      ),
    ],
  };
  return releaseResult({
    release,
    movement,
    movements: [...input.movements, movement],
    onHandStock,
  });
}

export type WarehouseStockReleaseReadModel = {
  onHandQuantity: number;
  availableQuantity: number;
  reservedQuantity: number;
  pickedQuantity: number;
  releasedQuantity: number;
  postedMovementQuantity: number;
  nextAvailableAction: string;
  boundaryNote: string;
};

export function WarehouseStockReleaseWorkbench(input: {
  stock: OnHandStock;
  reservation?: StockReservation;
  pickList?: PickList;
  release?: WarehouseRelease;
  movements: readonly StockMovement[];
}): WarehouseStockReleaseReadModel {
  let nextAvailableAction = "Create stock reservation";
  if (input.reservation?.status === "PREPARED")
    nextAvailableAction = "Validate stock reservation";
  if (input.reservation?.status === "VALIDATED")
    nextAvailableAction = "Release reservation to pick";
  if (input.reservation?.status === "RELEASED_TO_PICK" && !input.pickList)
    nextAvailableAction = "Create pick list";
  if (input.pickList?.status === "PREPARED")
    nextAvailableAction = "Validate pick list";
  if (input.pickList?.status === "VALIDATED")
    nextAvailableAction = "Start picking";
  if (
    input.pickList?.status === "PICKING" &&
    input.pickList.lines.every((line) => line.pickedQuantity === 0)
  )
    nextAvailableAction = "Record pick line";
  if (
    input.pickList?.status === "PICKING" &&
    input.pickList.lines.some((line) => line.pickedQuantity > 0)
  )
    nextAvailableAction = "Mark pick list ready for release";
  if (
    input.pickList?.status === "READY_FOR_WAREHOUSE_RELEASE" &&
    !input.release
  )
    nextAvailableAction = "Create Warehouse release";
  if (input.release?.status === "DRAFT")
    nextAvailableAction = "Validate Warehouse release";
  if (input.release?.status === "VALIDATED" && !input.release.handoffEvidence)
    nextAvailableAction = "Record Warehouse handoff evidence";
  if (input.release?.status === "VALIDATED" && input.release.handoffEvidence)
    nextAvailableAction = "Release goods from Warehouse custody";
  if (input.release?.status === "RELEASED_FROM_WAREHOUSE")
    nextAvailableAction = "Post release stock movement";
  if (input.release?.status === "STOCK_MOVEMENT_POSTED")
    nextAvailableAction = "Stock reduction posted";
  return {
    onHandQuantity: input.stock.onHandQuantity,
    availableQuantity:
      input.stock.availableQuantity -
      (input.reservation && input.release?.status !== "STOCK_MOVEMENT_POSTED"
        ? input.reservation.reservedQuantity
        : 0),
    reservedQuantity:
      input.release?.status === "STOCK_MOVEMENT_POSTED"
        ? input.stock.reservedQuantity
        : (input.reservation?.reservedQuantity ?? 0),
    pickedQuantity:
      input.pickList?.lines.reduce(
        (sum, line) => sum + line.pickedQuantity,
        0,
      ) ?? 0,
    releasedQuantity:
      input.release?.lines.reduce(
        (sum, line) => sum + line.releasedQuantity,
        0,
      ) ?? 0,
    postedMovementQuantity: input.movements.reduce(
      (sum, movement) => sum + movement.quantityDelta,
      0,
    ),
    nextAvailableAction,
    boundaryNote:
      "WarehouseRelease confirms goods left warehouse-controlled stock custody; it does not confirm destination delivery.",
  };
}
