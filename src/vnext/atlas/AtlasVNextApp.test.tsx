import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextApp } from "./AtlasVNextApp";
import {
  createAtlasApplicationFixture,
  applicationReviewNow,
} from "./atlasApplicationReviewFixtures";
beforeEach(() => {
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue({
      matches: true,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  );
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
const modules = [
  ["Trường học", "Sĩ số mặc định"],
  ["Nguyên liệu", "Nguyên liệu"],
  ["Nhà cung ứng", "Nhà cung ứng"],
  ["Công thức", "Công thức"],
  ["Thực đơn", "Thực đơn"],
  ["Sĩ số", "Sĩ số"],
  ["Hàng đặt riêng", "Hàng đặt riêng"],
  ["Xác nhận nhu cầu", "Xác nhận nhu cầu"],
  ["Phân bổ NCC", "Phân bổ NCC"],
  ["Đơn mua", "Đơn mua"],
  ["Lệnh điều chỉnh", "Lệnh điều chỉnh"],
  ["Phiếu xuất kho", "Phiếu xuất kho"],
  ["Đối chiếu PO / Phiếu xuất kho", "Đối chiếu PO / Phiếu xuất kho"],
];
async function showSchool() {
  const apis = createAtlasApplicationFixture();
  const signOut = vi.fn();
  const result = render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        userLabel="operator@example.test"
        now={applicationReviewNow}
        onSignOut={signOut}
      />
    </AtlasVNextProvider>,
  );
  await nav("Trường học");
  return { apis, signOut, ...result };
}
async function nav(label: string) {
  fireEvent.click(await screen.findByRole("button", { name: "Chức năng" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
  await waitFor(() =>
    expect(
      document.querySelector('[role="dialog"][data-state="open"]'),
    ).toBeNull(),
  );
}
async function clickSignOut() {
  fireEvent.click(
    screen.getByRole("button", { name: "Tài khoản và môi trường" }),
  );
  const account = await screen.findByRole("dialog", {
    name: "Tài khoản và môi trường",
  });
  fireEvent.click(within(account).getByRole("button", { name: "Đăng xuất" }));
}
async function selectRange(start: string, end: string, label = "Khoảng ngày") {
  const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
  if (disclosure.getAttribute("aria-expanded") === "false")
    fireEvent.click(disclosure);
  fireEvent.click(screen.getByRole("button", { name: `Mở lịch — ${label}` }));
  const calendar = await screen.findByRole("grid");
  for (const date of [start, end])
    fireEvent.click(
      calendar.querySelector<HTMLElement>(
        `[data-part="table-cell-trigger"][data-value="${date}"]`,
      )!,
    );
}

it("opens Weekly Menu as the actual fresh-session workbench without initializing School editing", async () => {
  const apis = createAtlasApplicationFixture();
  const schools = vi.spyOn(apis.masterData, "getSchools");
  render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        now={applicationReviewNow}
        onSignOut={vi.fn()}
      />
    </AtlasVNextProvider>,
  );
  expect(
    await screen.findByRole("heading", { level: 1, name: "Thực đơn" }),
  ).toBeVisible();
  expect(screen.getByRole("tab", { name: "Thực đơn" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  expect(
    screen.queryByRole("tab", { name: "Trường học" }),
  ).not.toBeInTheDocument();
  expect(schools).not.toHaveBeenCalled();
});

it("carries the selected seven-day range from new Confirmed Need to Allocation and Orders without preparation", async () => {
  const { apis } = await showSchool();
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  const orders = vi.spyOn(apis.procurement, "getPurchaseOrders");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
  const save = vi.spyOn(apis.confirmedNeed, "save");
  await nav("Xác nhận nhu cầu");
  const proceed = await screen.findByRole("button", {
    name: "Tiếp tục phân bổ NCC",
  });
  await waitFor(() => expect(proceed).toBeEnabled());
  await selectRange("2026-09-07", "2026-09-13");
  await waitFor(() => expect(proceed).toBeEnabled());
  fireEvent.click(proceed);
  await waitFor(() =>
    expect(allocation).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-07",
          date_end: "2026-09-13",
        }),
      }),
    ),
  );
  expect(
    await screen.findByText("Chọn 1 ngày để chuẩn bị đơn mua."),
  ).toBeVisible();
  fireEvent.click(await screen.findByRole("button", { name: "Xem đơn mua" }));
  await waitFor(() =>
    expect(orders).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-07",
          date_end: "2026-09-13",
        }),
      }),
    ),
  );
  expect(
    await screen.findByRole("heading", { level: 1, name: "Đơn mua" }),
  ).toBeVisible();
  expect(prepare).not.toHaveBeenCalled();
  expect(save).not.toHaveBeenCalled();
}, 60000);

it("preserves an existing Allocation range and unsaved split note when Confirmed Need requests another range", async () => {
  const { apis } = await showSchool();
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  const save = vi.spyOn(apis.purchaseReview, "saveConfirmedAllocation");
  await nav("Phân bổ NCC");
  await screen.findByRole("button", { name: /Xem phân bổ Gạo thơm/ });
  await selectRange("2026-09-07", "2026-09-09");
  fireEvent.click(
    await screen.findByRole("button", { name: /Xem phân bổ Gạo thơm/ }),
  );
  const note = screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" });
  fireEvent.change(note, {
    target: { value: "Giữ ghi chú của phạm vi đang mở" },
  });
  const readsBeforeNavigation = allocation.mock.calls.length;
  await nav("Xác nhận nhu cầu");
  const proceed = await screen.findByRole("button", {
    name: "Tiếp tục phân bổ NCC",
  });
  await waitFor(() => expect(proceed).toBeEnabled());
  await selectRange("2026-09-10", "2026-09-16");
  await waitFor(() =>
    expect(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toBeEnabled(),
  );
  fireEvent.click(screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }));
  expect(
    await screen.findByText(
      /Phân bổ NCC vẫn giữ khoảng ngày 2026-09-07 → 2026-09-09/,
    ),
  ).toBeVisible();
  expect(
    screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" }),
  ).toHaveValue("Giữ ghi chú của phạm vi đang mở");
  expect(
    screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
  ).toHaveTextContent("07/09/2026 — 09/09/2026");
  expect(allocation).toHaveBeenCalledTimes(readsBeforeNavigation);
  expect(save).not.toHaveBeenCalled();
}, 60000);

it("preserves an existing Orders range and selected order when Allocation requests another range", async () => {
  const { apis } = await showSchool();
  const orders = vi.spyOn(apis.procurement, "getPurchaseOrders");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
  await nav("Đơn mua");
  await screen.findByRole("button", { name: /^Xem đơn NCC An Phú/ });
  await selectRange("2026-09-07", "2026-09-09", "Khoảng ngày dùng");
  fireEvent.click(
    await screen.findByRole("button", { name: /^Xem đơn NCC An Phú/ }),
  );
  const readsBeforeNavigation = orders.mock.calls.length;
  await nav("Phân bổ NCC");
  await screen.findByRole("button", { name: /Xem phân bổ Gạo thơm/ });
  await selectRange("2026-09-10", "2026-09-16");
  fireEvent.click(await screen.findByRole("button", { name: "Xem đơn mua" }));
  expect(
    await screen.findByText(
      /Đơn mua vẫn giữ khoảng ngày 2026-09-07 → 2026-09-09/,
    ),
  ).toBeVisible();
  expect(
    screen.getByRole("button", { name: "Mở lịch — Khoảng ngày dùng" }),
  ).toHaveTextContent("07/09/2026 — 09/09/2026");
  expect(
    screen.getByRole("region", { name: "Chi tiết đơn mua NCC An Phú" }),
  ).toBeVisible();
  expect(orders).toHaveBeenCalledTimes(readsBeforeNavigation);
  expect(prepare).not.toHaveBeenCalled();
}, 60000);
it("downloads the attendance template from its persistent owner without saving attendance", async () => {
  const apis = createAtlasApplicationFixture();
  const preview = vi.spyOn(apis.planning, "previewAttendance");
  const save = vi.spyOn(apis.planning, "saveCompletedAttendance");
  const exportTemplate = vi.fn().mockResolvedValue(undefined);
  render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        now={applicationReviewNow}
        exporters={{ attendanceTemplateXlsx: exportTemplate }}
      />
    </AtlasVNextProvider>,
  );
  await nav("Sĩ số");
  fireEvent.click(
    await screen.findByRole("button", { name: "Tải mẫu sĩ số XLSX" }),
  );
  await screen.findByText(
    "Đã tải mẫu nhập. Sĩ số chỉ được ghi nhận sau khi rà soát và Lưu.",
  );
  expect(exportTemplate).toHaveBeenCalledWith(
    "2026-09-07",
    expect.arrayContaining([
      expect.objectContaining({ school_id: expect.any(String) }),
    ]),
  );
  expect(preview).not.toHaveBeenCalled();
  expect(save).not.toHaveBeenCalled();
});
it.each(modules)(
  "launches %s with one active heading",
  async (label, heading) => {
    await showSchool();
    await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
    await nav(label!);
    expect(
      await screen.findByRole("heading", { level: 1, name: heading! }),
    ).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1),
    );
    fireEvent.click(screen.getByRole("button", { name: "Chức năng" }));
    expect(await screen.findByRole("button", { name: label! })).toHaveAttribute(
      "aria-current",
      "page",
    );
    fireEvent.click(screen.getByRole("button", { name: "Chức năng" }));
    await waitFor(() =>
      expect(
        document.querySelector('[role="dialog"][data-state="open"]'),
      ).toBeNull(),
    );
  },
  20000,
);
it("blocks dirty sign-out without discarding and resolves School through its close guard", async () => {
  const { signOut } = await showSchool();
  const fields = await screen.findAllByRole("textbox", {
    name: /Học sinh mặc định/,
  });
  fireEvent.change(fields[0]!, { target: { value: "123" } });
  await clickSignOut();
  expect(signOut).not.toHaveBeenCalled();
  expect(
    await screen.findByRole("button", { name: "Trường học — Chưa lưu" }),
  ).toBeVisible();
  expect(
    screen.queryByRole("button", { name: "Bỏ thay đổi" }),
  ).not.toBeInTheDocument();
  expect(fields[0]).toHaveValue("123");
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  expect(fields[0]).toHaveValue("123");
  await waitFor(() =>
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
  );
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
  await waitFor(() => expect(fields[0]!.isConnected).toBe(false));
  await clickSignOut();
  expect(signOut).toHaveBeenCalledOnce();
});
it("Confirmed Need continues to supplier allocation with no hidden write", async () => {
  const { apis } = await showSchool();
  const save = vi.spyOn(apis.confirmedNeed, "save");
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  await nav("Thực đơn");
  await nav("Xác nhận nhu cầu");
  const proceed = await screen.findByRole("button", {
    name: "Tiếp tục phân bổ NCC",
  });
  await waitFor(() => expect(proceed).toBeEnabled());
  fireEvent.click(proceed);
  await waitFor(() => expect(allocation).toHaveBeenCalled());
  expect(save).not.toHaveBeenCalled();
  expect(screen.getByRole("tab", { name: /Phân bổ/ })).toHaveAttribute(
    "aria-selected",
    "true",
  );
});

it("preserves a changed date through Planning, Confirmed Need, Procurement, PXK and Reconciliation", async () => {
  const { apis } = await showSchool();
  const confirmed = vi.spyOn(apis.confirmedNeed, "getReview");
  const procurement = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  const pxk = vi.spyOn(apis.schoolDispatch, "getWorkbench");
  const reconciliation = vi.spyOn(apis.reconciliation, "getWorkbench");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  await nav("Thực đơn");
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  const date = await screen.findByRole("combobox", { name: "Ngày phục vụ" });
  fireEvent.change(date, { target: { value: "2026-09-09" } });
  await nav("Xác nhận nhu cầu");
  await waitFor(() =>
    expect(confirmed).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      expect.anything(),
      expect.objectContaining({ service_date: "2026-09-09" }),
      expect.anything(),
      expect.anything(),
    ),
  );
  const proceed = await screen.findByRole("button", {
    name: "Tiếp tục phân bổ NCC",
  });
  await waitFor(() => expect(proceed).toBeEnabled());
  fireEvent.click(proceed);
  await waitFor(() =>
    expect(procurement).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-09",
          date_end: "2026-09-09",
        }),
      }),
    ),
  );
  await nav("Phiếu xuất kho");
  await waitFor(() =>
    expect(pxk).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-09",
          date_end: "2026-09-09",
        }),
      }),
    ),
  );
  await nav("Đối chiếu PO / Phiếu xuất kho");
  await waitFor(() =>
    expect(reconciliation).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-09",
          date_end: "2026-09-09",
        }),
      }),
    ),
  );
  expect(prepare).not.toHaveBeenCalled();
}, 60000);

it("clean sign out runs immediately and a changed identity loses the prior draft", async () => {
  const { apis, signOut, rerender } = await showSchool();
  const fields = await screen.findAllByRole("textbox", {
    name: /Học sinh mặc định/,
  });
  await clickSignOut();
  expect(signOut).toHaveBeenCalledOnce();
  fireEvent.change(fields[0]!, { target: { value: "123" } });
  rerender(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="second-operator"
        userLabel="second@example.test"
        now={applicationReviewNow}
        onSignOut={signOut}
      />
    </AtlasVNextProvider>,
  );
  expect(
    await screen.findByRole("heading", { level: 1, name: "Thực đơn" }),
  ).toBeVisible();
  await nav("Trường học");
  await waitFor(() =>
    expect(
      screen.getAllByRole("textbox", { name: /Học sinh mặc định/ })[0],
    ).not.toHaveValue("123"),
  );
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
});

it("uses the injected business date for Recipe's independent initial as-of context", async () => {
  const { apis } = await showSchool();
  const effective = vi.spyOn(apis.recipe, "getEffectiveWorkbench");
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  await nav("Công thức");
  fireEvent.click(
    await screen.findByRole("button", {
      name: "Sửa công thức Canh bí đỏ thịt bằm",
    }),
  );
  await waitFor(() =>
    expect(effective).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      "2026-09-07",
      expect.anything(),
      expect.anything(),
    ),
  );
}, 15000);
