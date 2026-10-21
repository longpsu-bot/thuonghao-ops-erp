import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { useLayoutEffect } from "react";
import { reviewOrder, reviewSuccess } from "./procurementReviewFixtures";
import { pxkRow } from "../dispatch/schoolPxkReviewFixtures";
import { ProcurementPxkImpact } from "./ProcurementPxkImpact";
afterEach(cleanup);
it("never paints the previous PO impact while a different PO read is pending", async () => {
  const first = reviewOrder("po_released");
  const next = {
    ...first,
    purchase_order_id: "next-po",
    lines: first.lines.map((line) => ({
      ...line,
      school_breakdown: line.school_breakdown.map((school) => ({
        ...school,
        school_id: "school-next",
      })),
    })),
  };
  const row = pxkRow("CURRENT");
  row.service_date = first.service_date;
  row.school_id = "school-0";
  row.delivery_location_id = "location-0";
  row.preview.school_name = "Previous School only";
  const api = {
    getWorkbench: vi.fn().mockResolvedValue(
      reviewSuccess({
        contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
        date_start: first.service_date,
        date_end: first.service_date,
        rows: [row],
      }),
    ),
    releaseDocument: vi.fn(),
  };
  const committed: string[] = [];
  function View({ order }: { order: typeof first }) {
    useLayoutEffect(() => {
      committed.push(document.body.textContent ?? "");
    }, [order]);
    return (
      <AtlasVNextProvider>
        <ProcurementPxkImpact
          authSubject="operator"
          api={api}
          order={order}
          disabled={false}
        />
      </AtlasVNextProvider>
    );
  }
  const view = render(<View order={first} />);
  await screen.findByText(/Previous School only/);
  api.getWorkbench.mockImplementationOnce(() => new Promise(() => {}));
  view.rerender(<View order={next} />);
  expect(committed.at(-1)).not.toContain("Previous School only");
  expect(committed.at(-1)).toContain("Đang kiểm tra PXK");
});
it("reads exact School scope and reports actual PXK state without creating a successor", async () => {
  const order = reviewOrder("po_released");
  const row = pxkRow("REPLACEMENT_REQUIRED");
  row.service_date = order.service_date;
  row.school_id = "school-0";
  row.delivery_location_id = "location-0";
  const unrelated = {
    ...row,
    school_id: "school-other",
    state: "CURRENT" as const,
  };
  const api = {
    getWorkbench: vi.fn().mockResolvedValue(
      reviewSuccess({
        contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
        date_start: order.service_date,
        date_end: order.service_date,
        rows: [row, unrelated],
      }),
    ),
    releaseDocument: vi.fn(),
  };
  const open = vi.fn();
  render(
    <AtlasVNextProvider>
      <ProcurementPxkImpact
        authSubject="operator"
        api={api}
        order={order}
        disabled={false}
        onOpenPxk={open}
      />
    </AtlasVNextProvider>,
  );
  expect(await screen.findByText("Cần phiếu thay thế")).toBeInTheDocument();
  expect(screen.queryByText("Phiếu hiện hành")).not.toBeInTheDocument();
  expect(api.getWorkbench.mock.lastCall![0].payload).toMatchObject({
    school_ids: ["school-0"],
    date_start: order.service_date,
    date_end: order.service_date,
  });
  expect(api.releaseDocument).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole("button", { name: "Mở Phiếu xuất kho" }));
  expect(open).toHaveBeenCalledWith(order.service_date, ["school-0"]);
  api.getWorkbench.mockRejectedValueOnce(new Error("offline"));
  fireEvent.click(
    screen.getByRole("button", { name: "Tải lại ảnh hưởng PXK" }),
  );
  await waitFor(() =>
    expect(screen.getByRole("alert")).toHaveTextContent("Chưa xác nhận"),
  );
  expect(screen.queryByText("Cần phiếu thay thế")).not.toBeInTheDocument();
});
