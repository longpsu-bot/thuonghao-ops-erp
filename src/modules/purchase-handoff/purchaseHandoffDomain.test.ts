import { describe, expect, it } from "vitest";
import {
  ApproveConfirmedNeeds,
  ValidateConfirmedNeeds,
} from "../confirmed-need/confirmedNeedDomain";
import { draftConfirmedNeedFixture } from "../confirmed-need/confirmedNeedFixtures";
import {
  preparedPurchaseHandoffFixture,
  releasedConfirmedNeedFixture,
} from "./purchaseHandoffFixtures";
import {
  CreatePurchaseHandoffFromConfirmedNeeds,
  InvalidatePurchaseHandoff,
  ReleasePurchaseHandoffToProcurement,
  ReopenPurchaseHandoff,
  ValidatePurchaseHandoff,
} from "./purchaseHandoffDomain";

const validate = (batch = preparedPurchaseHandoffFixture) =>
  ValidatePurchaseHandoff(batch, "planner-lan", "2026-07-14T01:40:00.000Z")
    .batch!;
const release = (batch = validate()) =>
  ReleasePurchaseHandoffToProcurement(
    batch,
    "planner-lan",
    "2026-07-14T01:45:00.000Z",
  ).batch!;

describe("Purchase Handoff lifecycle", () => {
  it("creates only from released Confirmed Need", () => {
    expect(preparedPurchaseHandoffFixture.status).toBe("PREPARED");
    expect(preparedPurchaseHandoffFixture.lineCount).toBe(2);
    const approvedOnly = ApproveConfirmedNeeds(
      ValidateConfirmedNeeds(
        draftConfirmedNeedFixture,
        "planner-lan",
        "2026-07-14T01:20:00.000Z",
      ).batch!,
      "manager-minh",
      "2026-07-14T01:25:00.000Z",
    ).batch!;
    expect(
      CreatePurchaseHandoffFromConfirmedNeeds({
        purchaseHandoffBatchId: "rejected-handoff",
        confirmedNeedBatch: approvedOnly,
        actorId: "planner-lan",
        at: "2026-07-14T01:35:00.000Z",
      }).accepted,
    ).toBe(false);
  });

  it("validates and releases only in lifecycle order", () => {
    expect(
      ReleasePurchaseHandoffToProcurement(
        preparedPurchaseHandoffFixture,
        "planner-lan",
        "2026-07-14T01:36:00.000Z",
      ).accepted,
    ).toBe(false);
    const validated = validate();
    expect(validated.status).toBe("VALIDATED");
    const released = release(validated);
    expect(released.status).toBe("RELEASED_TO_PROCUREMENT");
    expect(released.releaseSnapshots).toHaveLength(1);
    expect(released.releaseSnapshots[0].lines).toEqual(
      released.lines.map((line) => ({
        purchaseHandoffLineId: line.purchaseHandoffLineId,
        confirmedNeedLineId: line.confirmedNeedLineId,
        quantity: line.quantity,
        purchaseUnit: line.purchaseUnit,
      })),
    );
  });

  it("preserves full confirmed, theoretical, and planning source trace", () => {
    const line = preparedPurchaseHandoffFixture.lines[0];
    expect(line.purchaseDemandReference).toEqual({
      confirmedNeedBatchId: "confirmed-need-2026-29-v1",
      confirmedNeedBatchVersion: 1,
      confirmedNeedLineId: "confirmed-need-2026-29-v1-line-1",
      theoreticalNeedLineId: "need-run-2026-29-v1-line-1",
      needGenerationRunId: "need-run-2026-29-v1",
      planningInputSetId: "planning-input-2026-29",
      weeklyMenuReference: "weekly-menu-2026-29@1",
      attendanceReference: "attendance-2026-29@1",
      recipeBomReference: "recipe-pumpkin-soup@3:bom-pumpkin",
      sourceTraceId:
        "menu-line-1:attendance-line-1:recipe-pumpkin-soup:bom-pumpkin",
      approvedConfirmedQuantity: 72,
      approvedConfirmedUnit: "kg",
    });
    expect(preparedPurchaseHandoffFixture.confirmedNeedReference).toMatchObject(
      {
        confirmedNeedBatchId: releasedConfirmedNeedFixture.confirmedNeedBatchId,
        batchVersion: releasedConfirmedNeedFixture.version,
      },
    );
  });

  it("blocks missing trace, purchase unit, negative quantities, and Procurement fields", () => {
    const line = preparedPurchaseHandoffFixture.lines[0];
    const blocked = {
      ...preparedPurchaseHandoffFixture,
      lines: [
        {
          ...line,
          confirmedNeedLineId: "",
          sourceTraceId: "",
          purchaseUnit: "",
          quantity: -1,
          supplierId: "supplier-not-allowed",
          purchaseOrderId: "po-not-allowed",
        },
      ],
    } as unknown as typeof preparedPurchaseHandoffFixture;
    const result = ValidatePurchaseHandoff(
      blocked,
      "planner-lan",
      "2026-07-14T01:40:00.000Z",
    );
    expect(result.accepted).toBe(false);
    expect(result.batch?.issues.map((issue) => issue.issueCode)).toEqual([
      "MISSING_CONFIRMED_NEED_REFERENCE",
      "MISSING_SOURCE_TRACE",
      "MISSING_PURCHASE_UNIT",
      "NEGATIVE_QUANTITY",
      "FORBIDDEN_PROCUREMENT_FIELD",
    ]);
  });

  it("keeps supplier and purchase-order fields out of the handoff type and instances", () => {
    const line = preparedPurchaseHandoffFixture.lines[0] as Record<
      string,
      unknown
    >;
    expect("supplierId" in line).toBe(false);
    expect("supplierAssignment" in line).toBe(false);
    expect("purchaseOrderId" in line).toBe(false);
    expect("purchaseOrderLineId" in line).toBe(false);
  });

  it("reopens with a reason and preserves prior release history", () => {
    const released = release();
    expect(
      ReopenPurchaseHandoff(
        released,
        "",
        "planner-lan",
        "2026-07-14T02:00:00.000Z",
      ).accepted,
    ).toBe(false);
    const reopened = ReopenPurchaseHandoff(
      released,
      "Confirmed demand changed",
      "planner-lan",
      "2026-07-14T02:00:00.000Z",
    ).batch!;
    expect(reopened.status).toBe("REOPENED");
    expect(reopened.version).toBe(2);
    expect(reopened.releaseSnapshots).toEqual(released.releaseSnapshots);
    expect(reopened.changes.at(-1)).toMatchObject({
      eventType: "PurchaseHandoffReopened",
      reason: "Confirmed demand changed",
    });
  });

  it("invalidates with source and reason while preserving released snapshots", () => {
    const released = release();
    expect(
      InvalidatePurchaseHandoff(
        released,
        "",
        "",
        "planner-lan",
        "2026-07-14T02:00:00.000Z",
      ).accepted,
    ).toBe(false);
    const invalidated = InvalidatePurchaseHandoff(
      released,
      "confirmed-need-2026-29-v1@2",
      "Confirmed Need reopened",
      "planner-lan",
      "2026-07-14T02:00:00.000Z",
    ).batch!;
    expect(invalidated.status).toBe("INVALIDATED");
    expect(invalidated.releaseSnapshots).toEqual(released.releaseSnapshots);
    expect(invalidated.changes.at(-1)).toMatchObject({
      eventType: "PurchaseHandoffInvalidated",
      affectedSource: "confirmed-need-2026-29-v1@2",
      reason: "Confirmed Need reopened",
    });
  });
});
