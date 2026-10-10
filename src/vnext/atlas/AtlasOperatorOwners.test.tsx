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
import { AtlasVNextApp } from "./AtlasVNextApp";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import {
  applicationReviewNow,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";
import { atlasWorkbenches } from "./AtlasWorkbenchRegistry";
import {
  createProcurementReviewFixture,
  reviewDate,
} from "./procurement/procurementReviewFixtures";

beforeEach(() => {
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue({
      matches: true,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  );
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
function show(
  apis = createAtlasApplicationFixture(),
  now = applicationReviewNow,
) {
  const signOut = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        now={now}
        onSignOut={signOut}
      />
    </AtlasVNextProvider>,
  );
  return { apis, signOut };
}
async function open(name: string) {
  fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
  fireEvent.click(
    within(screen.getByRole("dialog", { name: "Bàn làm việc" })).getByRole(
      "button",
      { name },
    ),
  );
  await waitFor(() => expect(owner(name)).toBeVisible());
}
const owner = (name: string) =>
  document.querySelector<HTMLElement>(
    `[role="tabpanel"][aria-label="${name}"]`,
  )!;
function nextOrdersDay() {
  const start = within(
    screen.getByRole("group", { name: "Từ ngày" }),
  ).getByRole("spinbutton", { name: "Day" });
  const end = within(screen.getByRole("group", { name: "Đến ngày" })).getByRole(
    "spinbutton",
    { name: "Day" },
  );
  // An incomplete reversed draft keeps authority until both ends form the next day.
  fireEvent.focus(start);
  fireEvent.keyDown(start, { key: "ArrowUp" });
  fireEvent.focus(end);
  fireEvent.keyDown(end, { key: "ArrowUp" });
}
function retained(panel: HTMLElement, input: HTMLElement, value: string) {
  expect(panel).toHaveAttribute("hidden");
  expect(panel).toHaveAttribute("inert");
  expect(input).toBeInTheDocument();
  expect(input).toHaveValue(value);
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
}
async function guards(names: string[], signOut: ReturnType<typeof vi.fn>) {
  fireEvent.click(
    screen.getByRole("button", { name: "Tài khoản và môi trường" }),
  );
  fireEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
  expect(signOut).not.toHaveBeenCalled();
  for (const name of names)
    expect(
      screen.getByRole("button", { name: `${name} — Chưa lưu` }),
    ).toBeVisible();
  for (const name of names) {
    fireEvent.click(screen.getByRole("button", { name: `Đóng ${name}` }));
    const dialog = await screen.findByRole("dialog");
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() => expect(dialog).toHaveAttribute("data-state", "closed"));
    fireEvent(dialog, new Event("animationcancel", { bubbles: true }));
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
  }
}

it("registers exactly thirteen real operator owners in the approved groups", () => {
  expect(atlasWorkbenches.map(({ id, label }) => [id, label])).toEqual([
    ["planning", "Thực đơn"],
    ["attendance", "Sĩ số"],
    ["pantry", "Hàng đặt riêng"],
    ["confirmed-need", "Xác nhận nhu cầu"],
    ["procurement", "Phân bổ NCC"],
    ["purchase-orders", "Đơn mua"],
    ["pxk", "Phiếu xuất kho"],
    ["reconciliation", "Đối chiếu PO / Phiếu xuất kho"],
    ["schools", "Trường học"],
    ["ingredients", "Nguyên liệu"],
    ["suppliers", "Nhà cung ứng"],
    ["recipes", "Công thức"],
    ["change-orders", "Lệnh điều chỉnh"],
  ]);
  expect(
    atlasWorkbenches
      .slice(0, 8)
      .every((w) => w.group === "CÔNG VIỆC HẰNG NGÀY"),
  ).toBe(true);
  expect(
    atlasWorkbenches.slice(8).every((w) => w.group === "DỮ LIỆU & CẤU HÌNH"),
  ).toBe(true);
});

it("retains separate Menu, Attendance, direct-order and Need owners without navigation writes", async () => {
  const { apis, signOut } = show();
  const sources = vi.spyOn(apis.planning, "getWorkbench"),
    pantry = vi.spyOn(apis.pantry, "getWorkbench"),
    need = vi.spyOn(apis.confirmedNeed, "getReview");
  const writes = [
    vi.spyOn(apis.planning, "syncMenuFromGoogle"),
    vi.spyOn(apis.planning, "saveCompletedMenu"),
    vi.spyOn(apis.planning, "saveCompletedAttendance"),
    vi.spyOn(apis.planning, "prepareCorrection"),
    vi.spyOn(apis.pantry, "saveCompleted"),
    vi.spyOn(apis.pantry, "prepareCorrection"),
    vi.spyOn(apis.confirmedNeed, "save"),
  ];
  await open("Thực đơn");
  await screen.findByRole("table", { name: "Thực đơn theo trường" });
  const menuOwner = owner("Thực đơn");
  const menuSearch = screen.getByRole("textbox", {
    name: "Tìm trong công việc",
  });
  fireEvent.change(menuSearch, { target: { value: "Nguyễn" } });
  await open("Sĩ số");
  const attendance = await screen.findByRole("textbox", {
    name: "Học sinh Trường Nguyễn Du",
  });
  fireEvent.change(attendance, { target: { value: "123" } });
  const attendanceOwner = owner("Sĩ số");
  await open("Hàng đặt riêng");
  const addSchool = await screen.findByRole("combobox", {
    name: "Trường thêm dòng",
  });
  await waitFor(() => expect(addSchool).toBeEnabled());
  fireEvent.change(addSchool, { target: { value: "school-1" } });
  fireEvent.click(screen.getByRole("button", { name: "+ Thêm dòng" }));
  const pantryQuantity = await screen.findByRole("textbox", {
    name: "Số lượng dòng 1",
  });
  fireEvent.change(pantryQuantity, { target: { value: "3,5" } });
  const pantryOwner = owner("Hàng đặt riêng");
  await open("Xác nhận nhu cầu");
  const quantity = await screen.findByRole("textbox", {
    name: "Số lượng xác nhận Gạo thơm",
  });
  fireEvent.change(quantity, { target: { value: "12,5" } });
  const needOwner = owner("Xác nhận nhu cầu");
  const reads = [
    sources.mock.calls.length,
    pantry.mock.calls.length,
    need.mock.calls.length,
  ];
  retained(menuOwner, menuSearch, "Nguyễn");
  retained(attendanceOwner, attendance, "123");
  retained(pantryOwner, pantryQuantity, "3,5");
  await open("Thực đơn");
  expect(screen.getByRole("textbox", { name: "Tìm trong công việc" })).toBe(
    menuSearch,
  );
  await open("Sĩ số");
  expect(
    screen.getByRole("textbox", { name: "Học sinh Trường Nguyễn Du" }),
  ).toBe(attendance);
  retained(needOwner, quantity, "12,5");
  await open("Hàng đặt riêng");
  expect(screen.getByRole("textbox", { name: "Số lượng dòng 1" })).toBe(
    pantryQuantity,
  );
  await open("Xác nhận nhu cầu");
  expect(
    screen.getByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" }),
  ).toBe(quantity);
  expect([
    sources.mock.calls.length,
    pantry.mock.calls.length,
    need.mock.calls.length,
  ]).toEqual(reads);
  for (const panel of [menuOwner, attendanceOwner, pantryOwner]) {
    expect(panel.querySelector('[data-tab-tier="secondary"]')).toBeNull();
    expect(panel.querySelector('[role="tabpanel"]')).toBeNull();
  }
  const filterIds = [menuOwner, attendanceOwner, pantryOwner].map((panel) =>
    within(panel)
      .getByRole("button", { name: "Bộ lọc", hidden: true })
      .getAttribute("aria-controls"),
  );
  expect(new Set(filterIds).size).toBe(3);
  await guards(["Sĩ số", "Hàng đặt riêng", "Xác nhận nhu cầu"], signOut);
  expect(attendance).toHaveValue("123");
  expect(quantity).toHaveValue("12,5");
  expect(pantryQuantity).toHaveValue("3,5");
  await open("Xác nhận nhu cầu");
  expect(attendanceOwner).toHaveAttribute("hidden");
  fireEvent.click(screen.getByRole("button", { name: "Đóng Sĩ số" }));
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
  await waitFor(() => expect(attendanceOwner).not.toBeInTheDocument());
  expect(pantryQuantity).toHaveValue("3,5");
  expect(quantity).toHaveValue("12,5");
  await open("Sĩ số");
  const reopened = await screen.findByRole("textbox", {
    name: "Học sinh Trường Nguyễn Du",
  });
  expect(reopened).not.toBe(attendance);
  expect(reopened).not.toHaveValue("123");
  for (const write of writes) expect(write).not.toHaveBeenCalled();
}, 60000);

it("retains independent Recipe and Change Order editors, filters and guards without activation reads", async () => {
  const { apis, signOut } = show();
  const recipes = vi.spyOn(apis.recipe, "getWorkbench"),
    changes = vi.spyOn(apis.recipeAdjustment, "getOperatorWorkbench");
  await open("Công thức");
  fireEvent.click(
    await screen.findByRole("button", {
      name: "Sửa công thức Canh bí đỏ thịt bằm",
    }),
  );
  const quantity = await screen.findByRole("textbox", {
    name: "Định lượng Bí đỏ",
  });
  fireEvent.change(quantity, { target: { value: "2,25" } });
  const recipeOwner = owner("Công thức");
  await open("Lệnh điều chỉnh");
  const search = screen.getByRole("textbox", { name: "Tìm lệnh" });
  fireEvent.change(search, { target: { value: "Thử" } });
  const create = await screen.findByRole("button", {
    name: "Tạo lệnh điều chỉnh",
  });
  await waitFor(() => expect(create).toBeEnabled());
  fireEvent.click(create);
  const reason = screen.getByRole("textbox", { name: "Lý do điều chỉnh" });
  fireEvent.change(reason, { target: { value: "Điều chỉnh thử" } });
  const changeOwner = owner("Lệnh điều chỉnh");
  const reads = [recipes.mock.calls.length, changes.mock.calls.length];
  retained(recipeOwner, quantity, "2,25");
  await open("Công thức");
  expect(screen.getByRole("textbox", { name: "Định lượng Bí đỏ" })).toBe(
    quantity,
  );
  retained(changeOwner, reason, "Điều chỉnh thử");
  await open("Lệnh điều chỉnh");
  expect(screen.getByRole("textbox", { name: "Tìm lệnh" })).toBe(search);
  expect(search).toHaveValue("Thử");
  expect(screen.getByRole("textbox", { name: "Lý do điều chỉnh" })).toBe(
    reason,
  );
  expect([recipes.mock.calls.length, changes.mock.calls.length]).toEqual(reads);
  await guards(["Công thức", "Lệnh điều chỉnh"], signOut);
  expect(quantity).toHaveValue("2,25");
  expect(reason).toHaveValue("Điều chỉnh thử");
}, 30000);

it("retains independent Ingredient and Supplier drafts while reusing the existing master-data API", async () => {
  const { apis, signOut } = show();
  const reads = vi.spyOn(apis.masterData, "getIngredientsAndSuppliers");
  await open("Nguyên liệu");
  const create = await screen.findByRole("button", { name: "Tạo nguyên liệu" });
  await waitFor(() => expect(create).toBeEnabled());
  fireEvent.change(screen.getByRole("textbox", { name: "Tìm nguyên liệu" }), {
    target: { value: "Nguyên liệu thử" },
  });
  fireEvent.click(create);
  const ingredient = screen.getByRole("textbox", { name: "Tên nguyên liệu" });
  fireEvent.change(ingredient, { target: { value: "Nguyên liệu thử" } });
  const ingredientOwner = owner("Nguyên liệu");
  await open("Nhà cung ứng");
  const supplierCreate = await screen.findByRole("button", {
    name: "Tạo nhà cung ứng",
  });
  await waitFor(() => expect(supplierCreate).toBeEnabled());
  fireEvent.change(screen.getByRole("textbox", { name: "Tìm nhà cung ứng" }), {
    target: { value: "Nhà cung ứng thử" },
  });
  fireEvent.click(supplierCreate);
  const supplier = screen.getByRole("textbox", { name: "Tên nhà cung ứng" });
  fireEvent.change(supplier, { target: { value: "Nhà cung ứng thử" } });
  const supplierOwner = owner("Nhà cung ứng");
  retained(ingredientOwner, ingredient, "Nguyên liệu thử");
  await open("Nguyên liệu");
  retained(supplierOwner, supplier, "Nhà cung ứng thử");
  expect(screen.getByRole("textbox", { name: "Tên nguyên liệu" })).toBe(
    ingredient,
  );
  await open("Nhà cung ứng");
  expect(screen.getByRole("textbox", { name: "Tên nhà cung ứng" })).toBe(
    supplier,
  );
  expect(reads).toHaveBeenCalledTimes(2);
  await guards(["Nguyên liệu", "Nhà cung ứng"], signOut);
  expect(ingredient).toHaveValue("Nguyên liệu thử");
  expect(supplier).toHaveValue("Nhà cung ứng thử");
}, 30000);

it("retains Allocation's dirty supplier detail and Orders search with independent panels and dates", async () => {
  const { apis, signOut } = show();
  const allocations = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations"),
    orders = vi.spyOn(apis.procurement, "getPurchaseOrders");
  await open("Phân bổ NCC");
  fireEvent.click(
    await screen.findByRole("button", {
      name: /^(Phân bổ NCC|Xem phân bổ) Gạo thơm/,
    }),
  );
  const note = screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" });
  fireEvent.change(note, { target: { value: "Giao sớm" } });
  const allocationOwner = owner("Phân bổ NCC");
  await open("Đơn mua");
  await waitFor(() => expect(orders).toHaveBeenCalledOnce());
  const search = screen.getByRole("textbox", { name: "Tìm kiếm" });
  fireEvent.change(search, { target: { value: "An Phú" } });
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  nextOrdersDay();
  await waitFor(() => expect(orders).toHaveBeenCalledTimes(2));
  const ordersOwner = owner("Đơn mua");
  retained(allocationOwner, note, "Giao sớm");
  await open("Phân bổ NCC");
  retained(ordersOwner, search, "An Phú");
  expect(screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" })).toBe(
    note,
  );
  await open("Đơn mua");
  expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBe(search);
  for (const label of ["Từ ngày", "Đến ngày"]) {
    expect(
      within(screen.getByRole("group", { name: label })).getByRole(
        "spinbutton",
        { name: "Day" },
      ),
    ).toHaveAttribute("aria-valuenow", "8");
  }
  expect(allocations).toHaveBeenCalledOnce();
  expect(orders).toHaveBeenCalledTimes(2);
  const filterIds = [allocationOwner, ordersOwner].map((panel) =>
    within(panel)
      .getByRole("button", { name: "Bộ lọc", hidden: true })
      .getAttribute("aria-controls"),
  );
  expect(new Set(filterIds).size).toBe(2);
  await guards(["Phân bổ NCC"], signOut);
  expect(note).toHaveValue("Giao sớm");
}, 30000);

it.each([false, true])(
  "preparation activates existing Orders without reading or changing its local context (different date: %s)",
  async (differentDate) => {
    const apis = createAtlasApplicationFixture(),
      fixture = createProcurementReviewFixture("ready");
    apis.purchaseReview = fixture.purchaseReviewApi;
    apis.procurement = fixture.procurementApi;
    const orders = vi.spyOn(apis.procurement, "getPurchaseOrders"),
      allocations = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations"),
      prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
    show(apis, new Date(`${reviewDate}T03:00:00Z`));
    await open("Phân bổ NCC");
    const allocationOwner = owner("Phân bổ NCC");
    await screen.findByRole("button", { name: "Tiếp tục lên đơn" });
    await open("Đơn mua");
    await waitFor(() => expect(orders).toHaveBeenCalledOnce());
    const ordersOwner = owner("Đơn mua"),
      search = screen.getByRole("textbox", { name: "Tìm kiếm" });
    fireEvent.change(search, { target: { value: "Giữ bộ lọc" } });
    if (differentDate) {
      fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
      nextOrdersDay();
      await waitFor(() => expect(orders).toHaveBeenCalledTimes(2));
    }
    await open("Phân bổ NCC");
    const proceed = await screen.findByRole("button", {
      name: "Tiếp tục lên đơn",
    });
    await waitFor(() => expect(proceed).toBeEnabled());
    fireEvent.click(proceed);
    await waitFor(() => expect(ordersOwner).toBeVisible());
    expect(prepare).toHaveBeenCalledOnce();
    expect(prepare.mock.calls[0]![0].payload.service_date).toBe(reviewDate);
    expect(allocations).toHaveBeenCalledTimes(2); // First mount plus post-command Allocation authority.
    expect(orders).toHaveBeenCalledTimes(differentDate ? 3 : 2); // Mount/date reads plus command proof; activation adds no read.
    expect(search).toHaveValue("Giữ bộ lọc");
    expect(
      screen.getByText(/^Chuyển sang Đơn mua từ Phân bổ NCC ngày/),
    ).toHaveTextContent("Tải lại dữ liệu tại Đơn mua");
    expect(
      screen.getByText(/^Chuyển sang Đơn mua từ Phân bổ NCC ngày/),
    ).toHaveTextContent(
      `giữ ngày ${differentDate ? "2026-09-11" : reviewDate}`,
    );
    expect(allocationOwner).toHaveAttribute("hidden");
    await open("Phân bổ NCC");
    expect(owner("Phân bổ NCC")).toBe(allocationOwner);
    expect(
      screen.getByRole("heading", { level: 1, name: "Phân bổ NCC" }),
    ).toBeVisible();
  },
  30000,
);
