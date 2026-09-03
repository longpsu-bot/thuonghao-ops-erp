import { expect, it } from "vitest";
import { createReviewPurchaseJourney } from "./reviewPurchaseReviewApi";
import { confirmedNeedSaveV2Request } from "../planning-inputs/confirmed-needs/confirmedNeedApi";
import {
  confirmedAllocationReadRequest,
  confirmedAllocationFromResult,
  confirmedAllocationRequest,
  generatedPurchaseReviewRequest,
  preparePurchaseOrdersRequest,
} from "./purchaseReviewApi";
import {
  purchaseOrdersReadRequest,
  releasePurchaseOrderRequest,
} from "./schoolCateringProcurementApi";

it("keeps generated100 separate from saved120, retained72/48 and explicit75/50 through official release", async () => {
  const date = "2026-09-03";
  const journey = createReviewPurchaseJourney("ready", date);
  const read = () =>
    journey.purchaseReviewApi.getConfirmedAllocations(
      confirmedAllocationReadRequest("actor", "corr", {
        date_start: date,
        date_end: date,
        school_ids: [],
        states: [],
        search: null,
      }),
    );
  const previewRequest = generatedPurchaseReviewRequest("actor", "corr", date);
  const before = journey.inspect();
  const preview =
    await journey.purchaseReviewApi.getGeneratedReview(previewRequest);
  expect(journey.inspect()).toEqual(before);
  expect(confirmedAllocationFromResult(await read())!.rows[0]).toMatchObject({
    complete: false,
    family_quantity: null,
  });
  const saveNeed = async (quantity: string) => {
    const need = journey.inspect().need;
    const line = need.lines[0]!;
    return journey.confirmedNeedApi.save(
      confirmedNeedSaveV2Request(
        "actor",
        "corr",
        need.confirmed_need_batch_id,
        need.batch_version,
        [
          {
            confirmed_need_line_id: line.confirmed_need_line_id,
            expected_current_revision_id: line.current_revision_id,
            expected_current_decision_id: line.current_decision_id,
            proposed_confirmed_quantity: quantity,
            reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
            reason_note: "Rà soát giấy",
          },
        ],
      ),
    );
  };
  const saveSplit = async (a: string, b: string) => {
    const row = confirmedAllocationFromResult(await read())!.rows[0]!;
    return journey.purchaseReviewApi.saveConfirmedAllocation(
      confirmedAllocationRequest(
        "actor",
        "corr",
        row.family.version,
        {
          service_date: date,
          delivery_location_id: row.delivery_location_id,
          ingredient_id: row.ingredient_id,
          unit_id: row.unit_id,
          expected_source_fingerprint: row.family.source_fingerprint,
          expected_source_batch_id: row.family.source_confirmed_need_batch_id!,
          expected_source_batch_version:
            row.family.source_confirmed_need_batch_version!,
        },
        row.eligible_suppliers.map((s, i) => ({
          supplier_id: s.supplier_id,
          allocated_quantity: i ? b : a,
        })),
      ),
    );
  };
  await saveNeed("120.00");
  expect(
    confirmedAllocationFromResult(await read())!.rows[0]!.family_quantity,
  ).toBe("120.000000");
  await saveSplit("72.00", "48.00");
  const saved = journey.inspect().allocations[0];
  expect(journey.inspect().orders).toHaveLength(0);
  await saveNeed("125.00");
  const stale = confirmedAllocationFromResult(await read())!.rows[0]!;
  expect(stale.state).toBe("STALE_REBALANCE_AVAILABLE");
  expect(stale.splits.map((s) => s.allocated_quantity)).toEqual([
    "72.000000",
    "48.000000",
  ]);
  expect(stale.rebalance_proposal!.map((s) => s.allocated_quantity)).toEqual([
    "75.000000",
    "50.000000",
  ]);
  await saveSplit("75.00", "50.00");
  const preparation = confirmedAllocationFromResult(await read())!.preparation!;
  const request = preparePurchaseOrdersRequest("actor", "corr", preparation);
  const prepared =
    await journey.purchaseReviewApi.preparePurchaseOrders(request);
  expect(
    await journey.purchaseReviewApi.preparePurchaseOrders(request),
  ).toEqual(prepared);
  expect(journey.inspect().allocations[0]).toEqual(saved);
  expect(journey.inspect().allocations.at(-1)!.source_kind).toBe(
    "PURCHASE_HANDOFF",
  );
  expect(
    journey.inspect().orders.map((po) => po.lines[0]!.ordered_quantity),
  ).toEqual(["75.000000", "50.000000"]);
  const first = journey.inspect().orders[0]!;
  await journey.procurementApi.releasePurchaseOrder(
    releasePurchaseOrderRequest(
      "actor",
      "corr",
      first.version,
      first.purchase_order_id,
      first.current_revision.purchase_order_revision_id,
    ),
  );
  expect(journey.inspect().orders.map((po) => po.status)).toEqual([
    "RELEASED_TO_SUPPLIER",
    "DRAFT",
  ]);
  expect(
    await journey.purchaseReviewApi.getGeneratedReview(previewRequest),
  ).toEqual(preview);
  const unrelated = await journey.procurementApi.getPurchaseOrders(
    purchaseOrdersReadRequest("actor", "corr", {
      date_start: "2026-09-04",
      date_end: "2026-09-04",
      supplier_ids: [],
      statuses: [],
      search: null,
    }),
  );
  expect(
    unrelated.kind === "success" && unrelated.response.purchase_orders,
  ).toEqual([]);
});
