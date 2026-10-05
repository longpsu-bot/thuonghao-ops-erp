import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextApp } from "./AtlasVNextApp";
import {
  applicationReviewDate,
  applicationReviewNow,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";

beforeEach(() => {
  const desktop = {
    matches: true,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  };
  vi.stubGlobal("matchMedia", vi.fn().mockReturnValue(desktop));
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function show() {
  const apis = createAtlasApplicationFixture();
  const signOut = vi.fn();
  const allocationRead = vi.spyOn(
    apis.purchaseReview,
    "getConfirmedAllocations",
  );
  const ordersRead = vi.spyOn(apis.procurement, "getPurchaseOrders");
  const pxkRead = vi.spyOn(apis.schoolDispatch, "getWorkbench");
  render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        now={applicationReviewNow}
        onSignOut={signOut}
      />
    </AtlasVNextProvider>,
  );
  return { allocationRead, ordersRead, pxkRead, signOut };
}

async function open(label: string) {
  fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
}
async function planning() {
  await open("Lập nhu cầu");
  await screen.findByRole("table", { name: "Thực đơn theo trường" });
  fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
  await waitFor(() =>
    expect(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toBeEnabled(),
  );
}
const allocationAction = () =>
  screen.findByRole("button", {
    name: /^(Phân bổ NCC|Xem phân bổ) Gạo thơm · Trường Tiểu học Nguyễn Du · Bếp chính Nguyễn Du$/,
  });
const continueAllocation = () =>
  fireEvent.click(screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }));

it("Need activates same-context Procurement without a discrepancy, remount or read", async () => {
  const h = show();
  await planning();
  await open("Kế hoạch mua hàng");
  await allocationAction();
  const panel = screen.getByRole("tabpanel", { name: "Kế hoạch mua hàng" });
  const search = screen.getByRole("textbox", { name: "Tìm kiếm" });
  const allocationReads = h.allocationRead.mock.calls.length;
  const ordersReads = h.ordersRead.mock.calls.length;
  fireEvent.click(screen.getByRole("tab", { name: "Lập nhu cầu" }));
  continueAllocation();
  expect(screen.getByRole("tabpanel", { name: "Kế hoạch mua hàng" })).toBe(
    panel,
  );
  expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBe(search);
  expect(screen.getByRole("tab", { name: "Phân bổ NCC" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  expect(screen.queryByText(/^Nhu cầu ngày/)).not.toBeInTheDocument();
  expect(h.allocationRead).toHaveBeenCalledTimes(allocationReads);
  expect(h.ordersRead).toHaveBeenCalledTimes(ordersReads);
}, 15000);

it("Need discloses the intended context while retaining Procurement's different local date and Orders stage", async () => {
  const h = show();
  await planning();
  await open("Kế hoạch mua hàng");
  await allocationAction();
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  const day = screen.getByRole("spinbutton", { name: "Day" });
  fireEvent.focus(day);
  fireEvent.keyDown(day, { key: "ArrowUp" });
  await waitFor(() => expect(h.allocationRead).toHaveBeenCalledTimes(2));
  await allocationAction();
  fireEvent.click(screen.getByRole("tab", { name: "Đơn mua" }));
  await waitFor(() => expect(h.ordersRead).toHaveBeenCalledOnce());
  await waitFor(() =>
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toBeEnabled(),
  );
  const panel = screen.getByRole("tabpanel", { name: "Kế hoạch mua hàng" });
  const search = screen.getByRole("textbox", { name: "Tìm kiếm" });
  fireEvent.click(screen.getByRole("tab", { name: "Lập nhu cầu" }));
  continueAllocation();
  const notice = screen.getByText(/^Nhu cầu ngày/);
  expect(notice.closest('[role="status"]')).toBeVisible();
  expect(notice).toHaveTextContent(
    `Nhu cầu ngày ${applicationReviewDate} yêu cầu Phân bổ NCC`,
  );
  expect(notice).toHaveTextContent("giữ ngày 2026-09-08, giai đoạn Đơn mua");
  expect(screen.getByRole("tabpanel", { name: "Kế hoạch mua hàng" })).toBe(
    panel,
  );
  expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBe(search);
  expect(screen.getByRole("tab", { name: "Đơn mua" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  expect(screen.getByRole("spinbutton", { name: "Day" })).toHaveAttribute(
    "aria-valuenow",
    "8",
  );
  expect(h.allocationRead).toHaveBeenCalledTimes(2);
  expect(h.ordersRead).toHaveBeenCalledOnce();
}, 15000);

it("Need returns to Procurement's dirty selected Supplier detail with its note and search intact", async () => {
  const h = show();
  await open("Kế hoạch mua hàng");
  await allocationAction();
  const panel = screen.getByRole("tabpanel", { name: "Kế hoạch mua hàng" });
  const search = screen.getByRole("textbox", { name: "Tìm kiếm" });
  fireEvent.change(search, { target: { value: "Gạo" } });
  const selected = await allocationAction();
  fireEvent.click(selected);
  const note = screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" });
  fireEvent.change(note, { target: { value: "Giao trước 05:30" } });
  await planning();
  expect(note.isConnected).toBe(true);
  expect(panel).toHaveAttribute("hidden");
  expect(panel).toHaveAttribute("inert");
  continueAllocation();
  expect(screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" })).toBe(
    note,
  );
  expect(note).toHaveValue("Giao trước 05:30");
  expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBe(search);
  expect(search).toHaveValue("Gạo");
  expect(selected).toHaveAttribute("aria-expanded", "true");
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  expect(
    screen.getByRole("tab", { name: /Kế hoạch mua hàng.*Chưa lưu/ }),
  ).toBeVisible();
  expect(h.allocationRead).toHaveBeenCalledOnce();
}, 15000);

it("retains PXK note and selection across switches and includes the hidden draft in a multi-owner sign-out block", async () => {
  const h = show();
  const school = (
    await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ })
  )[0]!;
  fireEvent.change(school, { target: { value: "123" } });
  await open("Phiếu xuất kho");
  fireEvent.click(await screen.findByRole("button", { name: "Phát hành" }));
  const detail = screen.getByRole("region", { name: "Nội dung phiếu" });
  const note = screen.getByRole("textbox", { name: "Ghi chú trên phiếu" });
  fireEvent.change(note, { target: { value: "Giao cổng phụ" } });
  fireEvent.click(screen.getByRole("tab", { name: /Trường học/ }));
  expect(note.isConnected).toBe(true);
  expect(note.closest('[role="tabpanel"]')).toHaveAttribute("hidden");
  fireEvent.click(
    screen.getByRole("button", { name: "Tài khoản và môi trường" }),
  );
  fireEvent.click(await screen.findByRole("button", { name: "Đăng xuất" }));
  expect(h.signOut).not.toHaveBeenCalled();
  expect(
    screen.getByRole("button", { name: "Trường học — Chưa lưu" }),
  ).toBeVisible();
  expect(
    screen.getByRole("button", { name: "Phiếu xuất kho — Chưa lưu" }),
  ).toBeVisible();
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  expect(school).toHaveValue("123");
  fireEvent.click(
    screen.getByRole("button", { name: "Phiếu xuất kho — Chưa lưu" }),
  );
  expect(screen.getByRole("region", { name: "Nội dung phiếu" })).toBe(detail);
  expect(screen.getByRole("textbox", { name: "Ghi chú trên phiếu" })).toBe(
    note,
  );
  expect(note).toHaveValue("Giao cổng phụ");
  expect(h.pxkRead).toHaveBeenCalledOnce();
}, 15000);
