import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import {
  AttemptUpstreamMutation,
  DispatchDeliveryWorkbench as createReadModel,
} from "../dispatch/dispatchDeliveryDomain";
import {
  deliveryExceedsLoadFixture,
  dispatchDeliveryInputFixture,
  dispatchOperatorReviewFixture,
  failedStopUnresolvedFixture,
  inactiveDestinationBlockerFixture,
  loadedNotDepartedFixture,
  missingEvidenceBlockerFixture,
  missingMixedEvidenceFixture,
  normalSchoolCrossDockDispatchFixture,
  normalSchoolWarehouseDispatchFixture,
  normalWholesaleDispatchFixture,
  partialDeliveryFixture,
  returnedExceptionResolvedFixture,
  unassignedTripFixture,
} from "../dispatch/dispatchDeliveryFixtures";
import { AtlasApp } from "./AtlasApp";

afterEach(cleanup);

function objectKeys(value: unknown): string[] {
  if (!value || typeof value !== "object") return [];
  if (Array.isArray(value)) return value.flatMap(objectKeys);
  return Object.entries(value).flatMap(([key, nested]) => [
    key,
    ...objectKeys(nested),
  ]);
}

describe("PD-05 Dispatch integration and operator-workflow review", () => {
  it("maps each Planning requirement through allocation, evidence, load, and delivery outcome", () => {
    const model = createReadModel(dispatchOperatorReviewFixture);
    expect(model.rows).toHaveLength(7);
    const crossDock = model.rows.find(
      (row) => row.requirementReference === "DR-SCHOOL-CROSSDOCK-001",
    );
    expect(crossDock).toMatchObject({
      sourceOfNeed: "SCHOOL_CATERING",
      requirementStatus: "FULFILMENT_READY",
      allocationReference: "FA-SCHOOL-CROSSDOCK-001",
      fulfilmentSourceSplit: "SUPPLIER_PO 20 kg",
      evidenceStatus: "READY",
      readyToLoad: true,
      planReference: "DP-MORNING-01",
      tripReference: "DT-MORNING-01",
      driverReference: "DRIVER-REF-LAN",
      vehicleReference: "VEHICLE-REF-51",
      stopSequence: 1,
      destination: "An Phat School",
      deliveryLocation: "DL-SCHOOL-AN-PHAT-KITCHEN",
      required: 20,
      allocated: 20,
      fulfilled: 20,
      loaded: 20,
      delivered: 20,
      returned: 0,
      exception: 0,
      deliveryEvidence: "RECEIVER-SIGNATURE-001",
    });
    const returned = model.rows.find(
      (row) => row.requirementReference === "DR-RETURNED-006",
    );
    expect(returned).toMatchObject({
      loaded: 8,
      delivered: 3,
      returned: 5,
      exception: 5,
      stopStatus: "RESOLVED_WITH_EXCEPTION",
    });
  });

  it("surfaces every morning attention category explicitly", () => {
    const operatorCodes = createReadModel(
      dispatchOperatorReviewFixture,
    ).attentionQueue.map((item) => item.attentionCode);
    expect(operatorCodes).toEqual(
      expect.arrayContaining([
        "MISSING_FULFILMENT_EVIDENCE",
        "MIXED_FULFILMENT_INCOMPLETE",
        "TRIP_NOT_ASSIGNED",
        "LOAD_NOT_CONFIRMED",
        "DELIVERY_EVIDENCE_MISSING",
        "UNRESOLVED_EXCEPTION",
        "RETURN_EVIDENCE_REQUIRED",
        "TRIP_CLOSURE_BLOCKED",
        "INACTIVE_DESTINATION",
      ]),
    );
    expect(
      createReadModel(deliveryExceedsLoadFixture).attentionQueue.map(
        (item) => item.attentionCode,
      ),
    ).toContain("DELIVERY_EXCEEDS_LOADED");
  });

  it("keeps supplier and warehouse evidence valid only for their allocated source", () => {
    const ready = createReadModel(dispatchDeliveryInputFixture);
    const supplier = ready.rows.find(
      (row) => row.requirementReference === "DR-SCHOOL-CROSSDOCK-001",
    )!;
    expect(supplier.evidenceStatus).toBe("READY");
    expect(supplier.fulfilmentSourceSplit).toBe("SUPPLIER_PO 20 kg");
    expect(supplier.fulfilled).toBe(20);

    const warehouse = ready.rows.find(
      (row) => row.requirementReference === "DR-SCHOOL-WAREHOUSE-002",
    )!;
    expect(warehouse.evidenceStatus).toBe("READY");
    expect(warehouse.fulfilmentSourceSplit).toBe("WAREHOUSE_STOCK 10 kg");

    expect(
      createReadModel(missingEvidenceBlockerFixture).attentionQueue.map(
        (item) => item.attentionCode,
      ),
    ).toContain("MISSING_FULFILMENT_EVIDENCE");
    expect(
      createReadModel(missingMixedEvidenceFixture).attentionQueue.map(
        (item) => item.attentionCode,
      ),
    ).toContain("MIXED_FULFILMENT_INCOMPLETE");
    for (const fixture of [
      normalSchoolCrossDockDispatchFixture,
      normalSchoolWarehouseDispatchFixture,
      normalWholesaleDispatchFixture,
    ]) {
      const row = createReadModel(fixture).rows[0];
      expect(row).toMatchObject({
        evidenceStatus: "READY",
        loaded: row.required,
        delivered: row.required,
        closureReadiness: "CLOSED",
      });
    }
  });

  it("distinguishes unassigned, loaded-not-departed, unresolved, and returned paths", () => {
    expect(createReadModel(unassignedTripFixture).rows[0]).toMatchObject({
      tripAssignmentStatus: "UNASSIGNED",
      tripStatus: "NOT_ASSIGNED",
      closureReadiness: "BLOCKED",
    });
    expect(loadedNotDepartedFixture.trips[0]).toMatchObject({
      status: "LOADED",
      departedAt: undefined,
    });
    expect(createReadModel(loadedNotDepartedFixture).rows[0]).toMatchObject({
      loaded: 10,
      delivered: 0,
      stopStatus: "LOADED",
      closureReadiness: "BLOCKED",
    });
    const model = createReadModel(dispatchOperatorReviewFixture);
    const unresolved = model.rows.find(
      (row) => row.requirementReference === "DR-EXCEPTION-005",
    )!;
    expect(unresolved.blockers.join(" ")).toMatch(
      /return evidence is required/,
    );
    const returned = model.rows.find(
      (row) => row.requirementReference === "DR-RETURNED-006",
    )!;
    expect(returned.blockers.join(" ")).not.toMatch(
      /return evidence is required/,
    );
    expect(createReadModel(partialDeliveryFixture).rows[0].stopStatus).toBe(
      "PARTIALLY_DELIVERED",
    );
    expect(
      createReadModel(failedStopUnresolvedFixture).attentionQueue.map(
        (item) => item.attentionCode,
      ),
    ).toContain("UNRESOLVED_EXCEPTION");
    expect(
      createReadModel(returnedExceptionResolvedFixture).attentionQueue.map(
        (item) => item.attentionCode,
      ),
    ).not.toContain("RETURN_EVIDENCE_REQUIRED");
  });

  it("requires override evidence for an inactive destination or location", () => {
    const blocked = createReadModel(inactiveDestinationBlockerFixture);
    expect(blocked.attentionQueue.map((item) => item.attentionCode)).toContain(
      "INACTIVE_DESTINATION",
    );
    const overridden = {
      ...inactiveDestinationBlockerFixture,
      requirements: inactiveDestinationBlockerFixture.requirements.map(
        (requirement) => ({
          ...requirement,
          activeOverrideEvidence: "APPROVED-OVERRIDE-007",
        }),
      ),
    };
    expect(
      createReadModel(overridden).attentionQueue.map(
        (item) => item.attentionCode,
      ),
    ).not.toContain("INACTIVE_DESTINATION");
  });

  it("preserves cross-domain ownership and contains no excluded behavior fields", async () => {
    const before = structuredClone(dispatchDeliveryInputFixture);
    for (const target of [
      "PLANNING_REQUIREMENT",
      "PROCUREMENT_ALLOCATION",
      "SUPPLIER_RECEIVING",
      "WAREHOUSE_MOVEMENT",
      "CROSS_DOMAIN_APPROVAL",
    ] as const)
      expect(AttemptUpstreamMutation(before, target).accepted).toBe(false);
    expect(dispatchDeliveryInputFixture).toEqual(before);

    const domain = await import("../dispatch/dispatchDeliveryDomain");
    for (const command of [
      "RecalculatePlanningNeed",
      "EditPlanningRequirementQuantity",
      "EditFulfilmentAllocation",
      "CreateSupplierPurchaseOrder",
      "CreateSupplierReceivingEvidence",
      "CreateWarehouseStockRelease",
      "PostWarehouseStockMovement",
      "ApproveQuality",
      "ApproveProductionExecution",
      "CreateInvoice",
      "CreateSettlement",
      "CreateAccountingRecord",
      "OptimizeRoute",
      "TrackLiveGps",
      "ManageDriverPayroll",
      "ManageVehicleMaintenance",
    ])
      expect(domain).not.toHaveProperty(command);

    const forbiddenFields = [
      "planningRecalculation",
      "supplierReceivingImplementation",
      "stockMovementId",
      "qaApprovalId",
      "productionExecutionId",
      "invoiceId",
      "settlementId",
      "accountingRecordId",
      "routeOptimization",
      "liveGps",
      "driverPayroll",
      "vehicleMaintenance",
      "supabaseClient",
      "retoolQuery",
      "credential",
      "productionData",
    ];
    expect(objectKeys(dispatchOperatorReviewFixture)).not.toEqual(
      expect.arrayContaining(forbiddenFields),
    );
  });

  it("renders the decision-first Atlas surface and required boundary note", () => {
    render(<AtlasApp initialPage="dispatch-delivery" />);
    expect(
      screen.getByLabelText("Dispatch morning decision summary"),
    ).toBeInTheDocument();
    expect(screen.getByText("Operator attention queue")).toBeInTheDocument();
    expect(
      screen.getByText(/Dispatch confirms transport and destination outcome/),
    ).toHaveTextContent(
      "It does not rewrite Planning demand, Procurement fulfilment allocation, Warehouse stock movement, supplier receiving evidence, QA approval, Production execution, or Finance/Accounting settlement.",
    );
  });
});
