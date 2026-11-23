import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  renderHook,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementOrdersStage } from "./ProcurementOrdersStage";
import { useProcurementWorkbench } from "./useProcurementWorkbench";
import { canReleasePurchaseOrder } from "../bridges/procurement";
import {
  createProcurementReviewFixture,
  reviewDate,
  reviewFailure,
  reviewOrder,
  reviewSuccess,
  reviewUnknown,
} from "./procurementReviewFixtures";

afterEach(cleanup);
function batch() {
  const fixture = createProcurementReviewFixture("po_draft");
  const second = structuredClone(fixture.orders.purchase_orders[0]!);
  second.purchase_order_id = "second-order";
  second.supplier.supplier_name = "Second supplier";
  second.current_revision.purchase_order_revision_id = "second-revision";
  fixture.orders.purchase_orders.push(
    second,
    reviewOrder("po_stale"),
    reviewOrder("po_released"),
  );
  fixture.orders.purchase_orders[2]!.purchase_order_id = "stale-order";
  fixture.orders.purchase_orders[3]!.purchase_order_id = "released-order";
  const release = vi
    .spyOn(fixture.procurementApi, "releasePurchaseOrder")
    .mockImplementation(async (request) => {
      const order = fixture.orders.purchase_orders.find(
        (o) => o.purchase_order_id === request.payload.purchase_order_id,
      )!;
      order.status = "RELEASED_TO_SUPPLIER";
      order.commitment_state = "CURRENT";
      order.allowed_actions.release = false;
      return reviewSuccess({});
    });
  const reviewed = () =>
    structuredClone(
      fixture.orders.purchase_orders.filter(canReleasePurchaseOrder),
    );
  return { fixture, release, reviewed };
}
function hook() {
  const h = batch();
  const result = renderHook(() =>
    useProcurementWorkbench({
      ...h.fixture,
      authSubject: "operator",
      initialServiceDate: reviewDate,
      ownerStage: "orders",
    }),
  );
  return { ...h, ...result };
}
describe("Publish all loaded eligible POs", () => {
  it("reviews the filtered list by default and includes hidden suppliers only after choosing the whole date scope", async () => {
    const { fixture } = batch(),
      releaseAll = vi.fn();
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search="Second supplier"
          onAction={vi.fn()}
          onReleaseAll={releaseAll}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Tiện ích đơn mua" }));
    fireEvent.click(screen.getByRole("button", { name: "Phát hành (1)" }));
    const dialog = within(
      await screen.findByRole("dialog", { name: "Đơn mua sẽ phát hành" }),
    );
    const list = dialog.getByRole("list", { name: "Danh sách đơn mua" });
    expect(list).toHaveTextContent("Second supplier");
    expect(list).toHaveTextContent("10/09/2026");
    expect(list).not.toHaveTextContent(
      /NCC An Phú|private-|second-order|second-revision/,
    );
    expect(releaseAll).not.toHaveBeenCalled();
    fireEvent.click(dialog.getByRole("button", { name: "Phát hành 1 đơn" }));
    expect(releaseAll).toHaveBeenCalledWith([
      fixture.orders.purchase_orders[1],
    ]);
    const scope = await screen.findByRole("combobox", {
      name: "Phạm vi thao tác",
    });
    fireEvent.change(scope, { target: { value: "loaded" } });
    fireEvent.click(screen.getByRole("button", { name: "Phát hành (2)" }));
    const all = within(
      await screen.findByRole("dialog", { name: "Đơn mua sẽ phát hành" }),
    );
    expect(all.getAllByRole("listitem")).toHaveLength(2);
    expect(all.getByRole("list")).toHaveTextContent("NCC An Phú");
    fireEvent.click(all.getByRole("button", { name: "Quay lại" }));
    expect(releaseAll).toHaveBeenCalledTimes(1);
  });
  it("releases only eligible current drafts once, using each exact version and revision", async () => {
    const h = hook();
    await waitFor(() => expect(h.result.current.current).toBe(true));
    await act(async () => {
      await h.result.current.releaseAllOrders(h.reviewed());
    });
    expect(h.release.mock.calls.map(([r]) => r.payload)).toEqual([
      {
        purchase_order_id: "private-order",
        expected_purchase_order_revision_id: "private-order-revision",
      },
      {
        purchase_order_id: "second-order",
        expected_purchase_order_revision_id: "second-revision",
      },
    ]);
    expect(h.release.mock.calls.every(([r]) => r.expected_version === 4)).toBe(
      true,
    );
    expect(new Set(h.release.mock.calls.map(([r]) => r.command_id)).size).toBe(
      2,
    );
    await act(async () => {
      await h.result.current.releaseAllOrders(h.reviewed());
    });
    expect(h.release).toHaveBeenCalledTimes(2);
    expect(h.result.current.feedback?.message).toContain("2/2");
  });
  it.each([
    reviewUnknown,
    reviewFailure("ACCESS_DENIED"),
    reviewFailure("RETRYABLE_CONCURRENCY_FAILURE", true),
  ])(
    "stops before the next PO on a failed or uncertain result",
    async (failure) => {
      const h = hook();
      await waitFor(() => expect(h.result.current.current).toBe(true));
      h.release.mockResolvedValueOnce(failure);
      await act(async () => {
        await h.result.current.releaseAllOrders(h.reviewed());
      });
      expect(h.release).toHaveBeenCalledOnce();
      expect(h.result.current.feedback?.kind).not.toBe("success");
      if (failure.kind === "transport_error")
        expect(h.result.current.locked).toBe(true);
    },
  );
  it("guards duplicate bulk and individual submissions while one request is pending", async () => {
    const h = hook();
    await waitFor(() => expect(h.result.current.current).toBe(true));
    let finish!: (value: typeof reviewUnknown) => void;
    h.release.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    let pending!: Promise<void>;
    act(() => {
      pending = h.result.current.releaseAllOrders(h.reviewed());
    });
    await act(async () => {
      await h.result.current.releaseAllOrders(h.reviewed());
      await h.result.current.orderAction(h.fixture.orders.purchase_orders[1]!);
    });
    expect(h.release).toHaveBeenCalledOnce();
    expect(h.result.current.busy).toBe(true);
    await act(async () => {
      finish(reviewUnknown);
      await pending;
    });
    expect(h.result.current.busy).toBe(false);
  });
  it("explains a date-wide preparation rejection in Vietnamese and stops the batch", async () => {
    const h = hook();
    await waitFor(() => expect(h.result.current.current).toBe(true));
    const failure = reviewFailure("PREPARATION_BLOCKED");
    if (failure.kind !== "backend_error") throw new Error("Expected rejection");
    failure.error.safe_message =
      "Prepare the complete current Supplier/date document set before release.";
    h.release.mockResolvedValueOnce(failure);
    await act(async () => {
      await h.result.current.releaseAllOrders(h.reviewed());
    });
    expect(h.release).toHaveBeenCalledOnce();
    expect(h.result.current.feedback?.kind).toBe("blocked");
    expect(h.result.current.feedback?.message).toContain("đơn mua");
    expect(h.result.current.feedback?.message).toContain("Cần cập nhật");
    expect(h.result.current.feedback?.message).not.toContain("Supplier/date");
    expect(h.result.current.feedback?.messages.join(" ")).toContain("0/2");
  });
  it("stops when a fresh read changes the next approved PO instead of releasing a new revision", async () => {
    const h = hook();
    await waitFor(() => expect(h.result.current.current).toBe(true));
    const release = h.release.getMockImplementation()!;
    h.release.mockImplementation(async (request) => {
      const response = await release(request);
      h.fixture.orders.purchase_orders[1]!.version += 1;
      h.fixture.orders.purchase_orders[1]!.current_revision.purchase_order_revision_id =
        "unapproved-new-revision";
      return response;
    });
    await act(async () => {
      await h.result.current.releaseAllOrders(h.reviewed());
    });
    expect(h.release).toHaveBeenCalledOnce();
    expect(h.result.current.feedback?.kind).toBe("stale");
    expect(h.result.current.feedback?.message).toContain("1/2");
  });
  it("keeps the combined workbench on Orders until an uncertain batch result is recovered", async () => {
    const h = batch();
    const { result } = renderHook(() =>
      useProcurementWorkbench({
        ...h.fixture,
        authSubject: "operator",
        initialServiceDate: reviewDate,
        initialStage: "orders",
      }),
    );
    await waitFor(() => expect(result.current.current).toBe(true));
    let finish!: (value: typeof reviewUnknown) => void;
    h.release.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    let pending!: Promise<void>;
    act(() => {
      pending = result.current.releaseAllOrders(h.reviewed());
    });
    act(() => result.current.changeStage("allocation"));
    expect(result.current.stage).toBe("orders");
    await act(async () => {
      finish(reviewUnknown);
      await pending;
    });
    expect(result.current.feedback?.kind).toBe("unknown");
    expect(result.current.locked).toBe(true);
  });
});
