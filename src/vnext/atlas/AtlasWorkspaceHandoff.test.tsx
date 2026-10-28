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
  const needRead = vi.spyOn(apis.planningReadiness, "preflight");
  const menuSave = vi.spyOn(apis.planning, "saveCompletedMenu");
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
  return { allocationRead, ordersRead, pxkRead, needRead, menuSave, signOut };
}

async function open(label: string) {
  fireEvent.click(screen.getByRole("button", { name: "Chức năng" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
}
async function planning() {
  await open("Xác nhận nhu cầu");
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

it("refreshes retained clean Need authority after a committed Menu sync without remounting it", async () => {
  const h = show();
  await planning();
  const panel = screen.getByRole("tabpanel", { name: "Xác nhận nhu cầu" });
  const reads = h.needRead.mock.calls.length;
  await open("Thực đơn");
  fireEvent.click(
    await screen.findByRole("button", { name: "Đồng bộ Google Sheet" }),
  );
  await waitFor(() => expect(h.menuSave).toHaveBeenCalledOnce());
  await waitFor(() =>
    expect(h.needRead.mock.calls.length).toBeGreaterThan(reads),
  );
  await planning();
  expect(screen.getByRole("tabpanel", { name: "Xác nhận nhu cầu" })).toBe(
    panel,
  );
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
}, 15000);

it("Need activates same-context Procurement without a discrepancy, remount or read", async () => {
  const h = show();
  await planning();
  await open("Phân bổ NCC");
  await allocationAction();
  const panel = screen.getByRole("tabpanel", { name: "Phân bổ NCC" });
  const search = screen.getByRole("textbox", { name: "Tìm kiếm" });
  const allocationReads = h.allocationRead.mock.calls.length;
  const ordersReads = h.ordersRead.mock.calls.length;
  fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
  continueAllocation();
  expect(screen.getByRole("tabpanel", { name: "Phân bổ NCC" })).toBe(panel);
  expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBe(search);
  expect(screen.getByRole("tab", { name: "Phân bổ NCC" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  expect(
    screen.queryByText(/^Cần phân bổ NCC cho nhu cầu từ/),
  ).not.toBeInTheDocument();
  expect(h.allocationRead).toHaveBeenCalledTimes(allocationReads);
  expect(h.ordersRead).toHaveBeenCalledTimes(ordersReads);
}, 15000);

it("preserves dirty Supplier detail after a sibling commit, suspends Save and still permits discard", async () => {
  const h = show();
  await open("Phân bổ NCC");
  fireEvent.click(await allocationAction());
  const note = screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" });
  fireEvent.change(note, { target: { value: "Giao trước 05:30" } });
  await open("Thực đơn");
  fireEvent.click(
    await screen.findByRole("button", { name: "Đồng bộ Google Sheet" }),
  );
  await waitFor(() => expect(h.menuSave).toHaveBeenCalledOnce());
  await open("Phân bổ NCC");
  expect(screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" })).toBe(
    note,
  );
  expect(note).toHaveValue("Giao trước 05:30");
  expect(h.allocationRead).toHaveBeenCalledOnce();
  expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
  fireEvent.click(screen.getByRole("button", { name: /^Đóng$/ }));
  fireEvent.click(
    await screen.findByRole("button", { name: "Bỏ thay đổi và đóng" }),
  );
  await waitFor(() =>
    expect(h.allocationRead.mock.calls.length).toBeGreaterThan(1),
  );
}, 15000);

it("Need discloses the intended context while retaining Allocation's different local date", async () => {
  const h = show();
  await planning();
  await open("Phân bổ NCC");
  await allocationAction();
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  fireEvent.click(
    screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
  );
  const calendar = await screen.findByRole("grid");
  const day = calendar.querySelector<HTMLElement>(
    '[data-part="table-cell-trigger"][data-value="2026-09-08"]',
  )!;
  fireEvent.click(day);
  fireEvent.click(day);
  await waitFor(() => expect(h.allocationRead).toHaveBeenCalledTimes(2));
  await allocationAction();
  await waitFor(() =>
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toBeEnabled(),
  );
  const panel = screen.getByRole("tabpanel", { name: "Phân bổ NCC" });
  const search = screen.getByRole("textbox", { name: "Tìm kiếm" });
  fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
  continueAllocation();
  const notice = screen.getByText(/^Cần phân bổ NCC cho nhu cầu từ/);
  expect(notice.closest('[role="status"]')).toBeVisible();
  expect(notice).toHaveTextContent(
    `Cần phân bổ NCC cho nhu cầu từ ${applicationReviewDate} đến ${applicationReviewDate}`,
  );
  expect(notice).toHaveTextContent("giữ khoảng ngày 2026-09-08 → 2026-09-08");
  expect(screen.getByRole("tabpanel", { name: "Phân bổ NCC" })).toBe(panel);
  expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBe(search);
  expect(screen.getByRole("tab", { name: "Phân bổ NCC" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  expect(
    screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
  ).toHaveTextContent("08/09/2026 — 08/09/2026");
  expect(h.allocationRead).toHaveBeenCalledTimes(2);
  expect(h.ordersRead).not.toHaveBeenCalled();
}, 15000);

it("Need returns to Procurement's dirty selected Supplier detail with its note and search intact", async () => {
  const h = show();
  await open("Phân bổ NCC");
  await allocationAction();
  const panel = screen.getByRole("tabpanel", { name: "Phân bổ NCC" });
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
  expect(search).toBeInTheDocument();
  expect(search).not.toBeVisible();
  expect(search).toHaveValue("Gạo");
  expect(selected).toHaveAttribute("aria-expanded", "true");
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  expect(
    screen.getByRole("tab", { name: /Phân bổ NCC.*Chưa lưu/ }),
  ).toBeVisible();
  expect(h.allocationRead).toHaveBeenCalledOnce();
  fireEvent.click(screen.getByRole("button", { name: "Đóng" }));
  fireEvent.click(
    await screen.findByRole("button", { name: "Bỏ thay đổi và đóng" }),
  );
  expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBe(search);
  expect(search).toBeVisible();
  expect(search).toHaveValue("Gạo");
  expect(h.allocationRead).toHaveBeenCalledOnce();
}, 15000);

it("retains PXK note and selection across switches and includes the hidden draft in a multi-owner sign-out block", async () => {
  const h = show();
  await open("Trường học");
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
