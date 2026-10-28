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
import { schoolDefaultsFixtureSchools } from "./schools/schoolDefaultsReviewFixtures";
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
async function showMenu(schoolLimit?: number) {
  const apis = createAtlasApplicationFixture();
  if (schoolLimit !== undefined) {
    apis.masterData.getSchools = async () => ({
      kind: "success",
      response: {
        success: true,
        schools: structuredClone(
          schoolDefaultsFixtureSchools.slice(0, schoolLimit),
        ),
      },
    });
  }
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
  const menu = await screen.findByRole("region", { name: "Thực đơn" });
  await waitFor(() =>
    expect(
      within(menu).getByRole("button", { name: "Đồng bộ Google Sheet" }),
    ).toBeEnabled(),
  );
  return { apis, signOut, ...result };
}
async function showSchool(schoolLimit?: number) {
  const result = await showMenu(schoolLimit);
  await nav("Trường học");
  const panel = screen.getByRole("tabpanel", {
    name: "Trường học",
    hidden: true,
  });
  expect(panel).toBeVisible();
  const fields = await within(panel).findAllByLabelText(/Học sinh mặc định/, {
    selector: "input",
  });
  expect(fields[0]).toBeVisible();
  await waitFor(() => expect(fields[0]).toBeEnabled());
  return { ...result, schoolFields: fields };
}
async function nav(label: string) {
  const trigger = await within(screen.getByRole("banner")).findByLabelText(
    "Chức năng",
    { selector: "button" },
  );
  expect(trigger).toBeVisible();
  fireEvent.click(trigger);
  const launcher = await screen.findByRole("dialog", { name: "Chức năng" });
  const destination = within(launcher).getByRole("button", {
    name: label,
    hidden: true,
  });
  expect(destination).toBeVisible();
  fireEvent.click(destination);
  await waitFor(() =>
    expect(
      screen.queryByRole("dialog", { name: "Chức năng" }),
    ).not.toBeInTheDocument(),
  );
  const panel = await screen.findByRole("tabpanel", {
    name: label,
    hidden: true,
  });
  const strip = screen.getByRole("tablist", {
    name: "Màn hình đang mở",
    hidden: true,
  });
  const tab = within(strip)
    .getAllByRole("tab", { hidden: true })
    .find((item) => item.getAttribute("aria-controls") === panel.id);
  expect(tab).toBeDefined();
  expect(tab).toHaveTextContent(label);
  await waitFor(() => expect(tab).toHaveAttribute("aria-selected", "true"));
  expect(panel).toBeVisible();
  const heading = modules.find(([name]) => name === label)?.[1];
  expect(
    await within(panel).findByRole("heading", { level: 1, name: heading }),
  ).toBeVisible();
  return panel;
}
async function clickSignOut(userLabel?: string) {
  fireEvent.click(
    within(screen.getByRole("banner")).getByRole("button", {
      name: "Tài khoản và môi trường",
      hidden: true,
    }),
  );
  const account = await screen.findByRole("dialog", {
    name: "Tài khoản và môi trường",
  });
  if (userLabel) expect(within(account).getByText(userLabel)).toBeVisible();
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
  const allocationRange = screen.getByRole("button", {
    name: "Mở lịch — Khoảng ngày",
  });
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
  expect(allocationRange).toBeInTheDocument();
  expect(allocationRange).toHaveTextContent("07/09/2026 — 09/09/2026");
  expect(allocationRange).not.toBeVisible();
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
    const { schoolFields } = await showSchool();
    expect(schoolFields).toHaveLength(schoolDefaultsFixtureSchools.length);
    const panel = await nav(label!);
    expect(
      await within(panel).findByRole("heading", { level: 1, name: heading! }),
    ).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1),
    );
    const trigger = within(screen.getByRole("banner")).getByLabelText(
      "Chức năng",
      {
        selector: "button",
      },
    );
    expect(trigger).toBeVisible();
    fireEvent.click(trigger);
    const launcher = await screen.findByRole("dialog", {
      name: "Chức năng",
      hidden: true,
    });
    expect(launcher).toBeVisible();
    const destination = within(launcher).getByRole("button", {
      name: label!,
      hidden: true,
    });
    expect(destination).toBeVisible();
    expect(destination).toHaveAttribute("aria-current", "page");
    fireEvent.click(trigger);
    await waitFor(() =>
      expect(
        document.querySelector('[role="dialog"][data-state="open"]'),
      ).toBeNull(),
    );
  },
  20000,
);
it("blocks dirty sign-out without discarding and resolves two Schools through their close guard", async () => {
  // One dirty and one untouched School isolate owner guards from catalog size.
  const { signOut, schoolFields: fields } = await showSchool(2);
  expect(fields).toHaveLength(2);
  expect(fields[1]).toHaveValue("317");
  const strip = within(
    screen.getByRole("tablist", {
      name: "Màn hình đang mở",
      hidden: true,
    }),
  );
  const close = strip.getByLabelText("Đóng Trường học", { selector: "button" });
  expect(fields[0]).toBeVisible();
  expect(close).toBeVisible();
  fireEvent.change(fields[0]!, { target: { value: "123" } });
  await clickSignOut();
  expect(signOut).not.toHaveBeenCalled();
  expect(
    screen.getByRole("button", { name: "Trường học — Chưa lưu", hidden: true }),
  ).toBeVisible();
  expect(
    screen.queryByRole("button", { name: "Bỏ thay đổi", hidden: true }),
  ).not.toBeInTheDocument();
  expect(fields[0]).toHaveValue("123");
  expect(fields[1]).toHaveValue("317");
  fireEvent.click(close);
  const dialog = await screen.findByRole("dialog", {
    hidden: true,
    name: "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?",
  });
  expect(dialog).toBeVisible();
  const cancel = within(dialog).getByRole("button", {
    name: "Tiếp tục chỉnh sửa",
    hidden: true,
  });
  expect(cancel).toBeVisible();
  fireEvent.click(cancel);
  expect(fields[0]).toHaveValue("123");
  expect(fields[1]).toHaveValue("317");
  await waitFor(() => expect(dialog).toHaveAttribute("data-state", "closed"));
  fireEvent(dialog, new Event("animationcancel", { bubbles: true }));
  await waitFor(() => expect(dialog).not.toBeInTheDocument());
  expect(close).toBeVisible();
  fireEvent.click(close);
  const discardDialog = await screen.findByRole("dialog", {
    hidden: true,
    name: "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?",
  });
  const discard = within(discardDialog).getByRole("button", {
    name: "Bỏ thay đổi",
    hidden: true,
  });
  expect(discard).toBeVisible();
  fireEvent.click(discard);
  await waitFor(() => expect(fields[0]!.isConnected).toBe(false));
  expect(fields[1]!.isConnected).toBe(false);
  // Closing restores navigation focus on the next frame. Let that finish
  // before opening the account popup, whose blur handler closes it.
  await waitFor(() =>
    expect(screen.getByRole("tab", { name: /^Thực đơn/ })).toHaveFocus(),
  );
  await clickSignOut();
  expect(signOut).toHaveBeenCalledOnce();
});
it("Confirmed Need continues to supplier allocation with no hidden write", async () => {
  const { apis } = await showMenu();
  const save = vi.spyOn(apis.confirmedNeed, "save");
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
  const need = await nav("Xác nhận nhu cầu");
  const proceed = await within(need).findByRole("button", {
    name: "Tiếp tục phân bổ NCC",
  });
  await waitFor(() => expect(proceed).toBeEnabled());
  fireEvent.click(proceed);
  await waitFor(() =>
    expect(allocation).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-07",
          date_end: "2026-09-07",
        }),
      }),
    ),
  );
  const destination = screen.getByRole("tabpanel", {
    name: "Phân bổ NCC",
    hidden: true,
  });
  expect(destination).toBeVisible();
  expect(save).not.toHaveBeenCalled();
  expect(prepare).not.toHaveBeenCalled();
  expect(
    screen.getByRole("tab", { name: /Phân bổ/, hidden: true }),
  ).toHaveAttribute("aria-selected", "true");
});

it("preserves a changed date through Planning, Confirmed Need, Procurement, PXK and Reconciliation", async () => {
  const { apis } = await showMenu();
  const confirmed = vi.spyOn(apis.confirmedNeed, "getReview");
  const procurement = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  const pxk = vi.spyOn(apis.schoolDispatch, "getWorkbench");
  const reconciliation = vi.spyOn(apis.reconciliation, "getWorkbench");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
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

it("clean sign out calls back once without a dirty-state blocker", async () => {
  const { apis, signOut } = await showMenu(2);
  const save = vi.spyOn(apis.masterData, "updateSchoolDefaultsBulk");
  await clickSignOut("operator@example.test");
  expect(signOut).toHaveBeenCalledOnce();
  expect(screen.queryByText(/Chưa thể đăng xuất/)).not.toBeInTheDocument();
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  expect(save).not.toHaveBeenCalled();
}, 5000);

it("a changed identity loses the prior unsaved draft including a stale post-sign-out edit", async () => {
  const { apis, signOut, rerender, schoolFields: fields } = await showSchool(2);
  const save = vi.spyOn(apis.masterData, "updateSchoolDefaultsBulk");
  const read = vi.spyOn(apis.masterData, "getSchools");
  expect(fields).toHaveLength(2);
  await clickSignOut("operator@example.test");
  expect(signOut).toHaveBeenCalledOnce();
  // The callback does not unmount this harness: retain the original stale-edit race.
  fireEvent.change(fields[0]!, { target: { value: "123" } });
  expect(fields[0]).toHaveValue("123");
  expect(fields[1]).toHaveValue("317");
  expect(save).not.toHaveBeenCalled();
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
  expect(fields[0]!.isConnected).toBe(false);
  expect(fields[1]!.isConnected).toBe(false);
  const nextSchool = await nav("Trường học");
  const nextFields = await within(nextSchool).findAllByLabelText(
    /Học sinh mặc định/,
    { selector: "input" },
  );
  expect(nextFields).toHaveLength(2);
  expect(read).toHaveBeenCalledWith("second-operator", expect.any(String));
  for (const [index, field] of nextFields.entries()) {
    expect(field).toBeVisible();
    expect(field).toBeEnabled();
    expect(field).not.toHaveValue("123");
    expect(field).toHaveValue(
      String(schoolDefaultsFixtureSchools[index]!.default_student_portions),
    );
  }
  fireEvent.click(
    within(screen.getByRole("banner")).getByRole("button", {
      name: "Tài khoản và môi trường",
    }),
  );
  const account = await screen.findByRole("dialog", {
    name: "Tài khoản và môi trường",
  });
  expect(within(account).getByText("second@example.test")).toBeVisible();
  expect(
    within(account).queryByText("operator@example.test"),
  ).not.toBeInTheDocument();
  fireEvent.click(
    within(screen.getByRole("banner")).getByRole("button", {
      name: "Tài khoản và môi trường",
    }),
  );
  expect(save).not.toHaveBeenCalled();
  expect(signOut).toHaveBeenCalledOnce();
  expect(screen.queryByText(/Chưa thể đăng xuất/)).not.toBeInTheDocument();
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
}, 5000);

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
