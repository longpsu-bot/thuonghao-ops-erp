import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useProcurementWorkbench } from "./useProcurementWorkbench";
import {
  createProcurementReviewFixture,
  reviewFailure,
  reviewFamily,
  reviewSuccess,
  reviewUnknown,
  reviewDate,
} from "./procurementReviewFixtures";
import type { AtlasRpcResult } from "../bridges/procurement";
afterEach(cleanup);
function deferred() {
  let resolve!: (value: AtlasRpcResult) => void;
  const promise = new Promise<AtlasRpcResult>((r) => {
    resolve = r;
  });
  return { promise, resolve };
}
function setup(
  scenario: Parameters<typeof createProcurementReviewFixture>[0] = "normal",
) {
  const fixture = createProcurementReviewFixture(scenario);
  const read = vi.spyOn(fixture.purchaseReviewApi, "getConfirmedAllocations");
  const save = vi.spyOn(fixture.purchaseReviewApi, "saveConfirmedAllocation");
  const poRead = vi.spyOn(fixture.procurementApi, "getPurchaseOrders");
  const prepare = vi.spyOn(fixture.purchaseReviewApi, "preparePurchaseOrders");
  const hook = renderHook(() =>
    useProcurementWorkbench({
      authSubject: "operator",
      ...fixture,
      initialServiceDate: reviewDate,
    }),
  );
  return { ...hook, fixture, read, save, poRead, prepare };
}
const ready = async (result: ReturnType<typeof setup>["result"]) =>
  waitFor(() => expect(result.current.current).toBe(true));
const splits = [
  { supplier_id: "supplier-a", allocated_quantity: "100.000000" },
];

describe("Procurement authoritative scope", () => {
  it("loads the confirmed single-date path with an all-school scope", async () => {
    const { result, read } = setup();
    await ready(result);
    expect(read.mock.calls[0]![0]).toMatchObject({
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      requested_by_auth_subject: "operator",
      payload: {
        date_start: reviewDate,
        date_end: reviewDate,
        school_ids: [],
        states: [],
        search: null,
      },
    });
  });
  it("invalidates a date synchronously and rejects an older scoped response", async () => {
    const { result, read, fixture } = setup();
    await ready(result);
    const old = deferred();
    const latest = deferred();
    read.mockReturnValueOnce(old.promise).mockReturnValueOnce(latest.promise);
    act(() => result.current.changeDate("2026-09-11"));
    expect(result.current.current).toBe(false);
    expect(result.current.allocation).toBeNull();
    act(() => result.current.changeDate("2026-09-12"));
    await act(async () =>
      latest.resolve(
        reviewSuccess({
          ...fixture.allocation,
          rows: [{ ...reviewFamily(), ingredient_name: "Mới nhất" }],
        }),
      ),
    );
    await ready(result);
    await act(async () => old.resolve(reviewSuccess(fixture.allocation)));
    expect(result.current.allocation?.rows[0]?.ingredient_name).toBe(
      "Mới nhất",
    );
  });
  it("commits exact School scope and leaves failed reads unactionable", async () => {
    const { result, read } = setup();
    await ready(result);
    read.mockResolvedValueOnce(reviewFailure("ACCESS_DENIED"));
    await act(async () =>
      result.current.changeSchools(["school-1", "school-2"]),
    );
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(read.mock.lastCall![0].payload).toMatchObject({
      school_ids: ["school-1", "school-2"],
    });
    expect(result.current.current).toBe(false);
    expect(result.current.locked).toBe(true);
  });
  it("does not accept an obsolete mutation result after a stage change", async () => {
    const { result, save } = setup();
    await ready(result);
    const pending = deferred();
    save.mockReturnValueOnce(pending.promise);
    act(() => {
      void result.current.save(reviewFamily(), splits);
    });
    act(() => result.current.changeStage("orders"));
    await ready(result);
    await act(async () => pending.resolve(reviewUnknown));
    expect(result.current.stage).toBe("orders");
    expect(result.current.feedback).toBeNull();
  });
});

describe("Procurement command safety", () => {
  it("saves the exact confirmed source request and replaces the read with authority", async () => {
    const { result, fixture, read, save } = setup();
    await ready(result);
    fixture.allocation = {
      ...fixture.allocation,
      rows: [reviewFamily("manual_split")],
    };
    await act(async () => result.current.save(reviewFamily(), splits));
    expect(save).toHaveBeenCalledTimes(1);
    expect(read).toHaveBeenCalledTimes(2);
    expect(save.mock.calls[0]![0]).toMatchObject({
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      expected_version: 0,
      requested_by_auth_subject: "operator",
      idempotency_key: expect.any(String),
      correlation_id: expect.any(String),
      payload: {
        family: {
          expected_source_batch_id: "private-batch",
          expected_source_batch_version: 3,
          expected_source_fingerprint: "private-fingerprint",
        },
        splits,
      },
    });
    expect(
      result.current.allocation?.rows[0]?.splits[0]?.allocated_quantity,
    ).toBe("60.000000");
  });
  it("uses the existing Handoff writer only for returned Handoff authority", async () => {
    const { result, fixture, save } = setup();
    await ready(result);
    const row = reviewFamily();
    row.family.source_kind = "PURCHASE_HANDOFF";
    fixture.allocation.rows = [row];
    await act(async () => result.current.reload());
    const handoff = vi.spyOn(fixture.procurementApi, "saveAllocation");
    await act(async () => result.current.save(row, splits));
    expect(save).not.toHaveBeenCalled();
    expect(handoff.mock.calls[0]![0].contract_version).toBe(
      "SCHOOL-CATERING-PROCUREMENT.v1",
    );
  });
  it("rejects invalid, ineligible or unbalanced input even if called outside the editor", async () => {
    const { result, save } = setup();
    await ready(result);
    for (const input of [
      [{ supplier_id: "supplier-a", allocated_quantity: "99" }],
      [{ supplier_id: "other", allocated_quantity: "100" }],
      [{ supplier_id: "supplier-a", allocated_quantity: "1e2" }],
    ]) {
      await act(async () => result.current.save(reviewFamily(), input));
    }
    expect(save).not.toHaveBeenCalled();
  });
  it.each([reviewFailure(), reviewFailure("SOURCE_CHANGED"), reviewUnknown])(
    "locks uncertain/stale mutation until successful reload",
    async (failure) => {
      const { result, fixture, save, read } = setup();
      await ready(result);
      fixture.commandResult = failure;
      await act(async () => result.current.save(reviewFamily(), splits));
      expect(result.current.locked).toBe(true);
      await act(async () => result.current.save(reviewFamily(), splits));
      expect(save).toHaveBeenCalledTimes(1);
      read.mockResolvedValueOnce(reviewFailure("ACCESS_DENIED"));
      await act(async () => result.current.reload());
      expect(result.current.locked).toBe(true);
      await act(async () => result.current.reload());
      expect(result.current.locked).toBe(false);
    },
  );
  it("treats a rejected command promise as unknown, never as a safe failure", async () => {
    const { result, save } = setup();
    await ready(result);
    save.mockRejectedValueOnce(new Error("private internal error"));
    await act(async () => result.current.save(reviewFamily(), splits));
    expect(result.current.feedback?.kind).toBe("unknown");
    expect(result.current.locked).toBe(true);
  });
  it("requires explicit retry and preserves the entire original request", async () => {
    const { result, fixture, save } = setup("retryable_failure");
    await ready(result);
    await act(async () => result.current.save(reviewFamily(), splits));
    expect(save).toHaveBeenCalledTimes(1);
    expect(result.current.locked).toBe(true);
    fixture.commandResult = reviewSuccess();
    await act(async () => result.current.retry());
    expect(save).toHaveBeenCalledTimes(2);
    expect(save.mock.calls[1]![0]).toBe(save.mock.calls[0]![0]);
    expect(result.current.locked).toBe(false);
  });
  it("discards retry when authoritative scope changes", async () => {
    const { result, save } = setup("retryable_failure");
    await ready(result);
    await act(async () => result.current.save(reviewFamily(), splits));
    act(() => result.current.changeDate("2026-09-11"));
    await ready(result);
    await act(async () => result.current.retry());
    expect(save).toHaveBeenCalledTimes(1);
  });
  it("suppresses duplicate command activation immediately", async () => {
    const { result, save } = setup();
    await ready(result);
    const pending = deferred();
    save.mockReturnValue(pending.promise);
    act(() => {
      void result.current.save(reviewFamily(), splits);
      void result.current.save(reviewFamily(), splits);
    });
    expect(save).toHaveBeenCalledTimes(1);
    await act(async () => pending.resolve(reviewSuccess()));
  });
  it("does not claim success if successful Save readback fails", async () => {
    const { result, read } = setup();
    await ready(result);
    read.mockResolvedValueOnce(reviewFailure("ACCESS_DENIED"));
    await act(async () => result.current.save(reviewFamily(), splits));
    expect(result.current.feedback?.kind).toBe("unknown");
    expect(result.current.locked).toBe(true);
  });
});

describe("Preparation and PO actions", () => {
  it("prepares only ready authority without an active editor and reads orders before switching", async () => {
    const { result, prepare, poRead } = setup("ready");
    await ready(result);
    await act(async () => result.current.prepare(true));
    expect(prepare).not.toHaveBeenCalled();
    await act(async () => result.current.prepare(false));
    expect(prepare.mock.calls[0]![0]).toMatchObject({
      contract_version: "PURCHASE-COMMITMENT.v1",
      expected_version: 3,
      payload: {
        confirmed_need_batch_id: "private-batch",
        service_date: reviewDate,
      },
    });
    expect(poRead).toHaveBeenCalledTimes(1);
    expect(result.current.stage).toBe("orders");
    expect(result.current.current).toBe(true);
  });
  it("does not prepare when backend readiness or permission is absent", async () => {
    const { result, prepare } = setup();
    await ready(result);
    await act(async () => result.current.prepare(false));
    expect(prepare).not.toHaveBeenCalled();
  });
  it("keeps failed preparation readback uncertain and recovers by reading orders", async () => {
    const { result, poRead } = setup("ready");
    await ready(result);
    poRead.mockResolvedValueOnce(reviewFailure("ACCESS_DENIED"));
    await act(async () => result.current.prepare(false));
    expect(result.current.stage).toBe("allocation");
    expect(result.current.locked).toBe(true);
    expect(result.current.feedback?.kind).toBe("unknown");
    await act(async () => result.current.reload());
    expect(result.current.stage).toBe("orders");
    expect(result.current.locked).toBe(false);
  });
  it.each([
    ["po_draft", "releasePurchaseOrder"],
    ["po_stale", "createPurchaseOrderDrafts"],
    ["replacement_required", "createPurchaseOrderReplacement"],
  ] as const)(
    "uses authoritative %s command and PO readback",
    async (scenario, method) => {
      const { result, fixture, poRead } = setup(scenario);
      await ready(result);
      act(() => result.current.changeStage("orders"));
      await ready(result);
      const command = vi.spyOn(fixture.procurementApi, method);
      await act(async () =>
        result.current.orderAction(fixture.orders.purchase_orders[0]!),
      );
      expect(command).toHaveBeenCalledTimes(1);
      expect(poRead).toHaveBeenCalledTimes(2);
      expect(command.mock.calls[0]![0]).toMatchObject({
        requested_by_auth_subject: "operator",
        correlation_id: expect.any(String),
        idempotency_key: expect.any(String),
        expected_version: scenario === "po_stale" ? 1 : 4,
      });
      if (scenario === "po_draft")
        expect(command.mock.calls[0]![0].payload).toEqual({
          purchase_order_id: "private-order",
          expected_purchase_order_revision_id: "private-order-revision",
        });
      if (scenario === "replacement_required")
        expect(command.mock.calls[0]![0].payload).toEqual({
          replaced_purchase_order_id: "private-order",
          expected_purchase_order_revision_id: "private-order-revision",
        });
    },
  );
  it.each(["cancellation_required", "superseded", "po_released"] as const)(
    "never invents a write for %s",
    async (scenario) => {
      const { result, fixture } = setup(scenario);
      await ready(result);
      act(() => result.current.changeStage("orders"));
      await ready(result);
      const release = vi.spyOn(fixture.procurementApi, "releasePurchaseOrder");
      const replace = vi.spyOn(
        fixture.procurementApi,
        "createPurchaseOrderReplacement",
      );
      await act(async () =>
        result.current.orderAction(fixture.orders.purchase_orders[0]!),
      );
      expect(release).not.toHaveBeenCalled();
      expect(replace).not.toHaveBeenCalled();
    },
  );
});
