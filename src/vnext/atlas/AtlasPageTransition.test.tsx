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
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";

// D-048 / 03C supersedes replacement-page motion: activation retains real owners;
// only an approved close is an exit. Observe the browser animation boundary
// without mocking the application, fixtures or domain guards.
const animate = vi.fn();
let reduced = false;
beforeEach(() => {
  reduced = false;
  animate.mockClear();
  vi.stubGlobal(
    "matchMedia",
    vi.fn((media: string) => ({
      media,
      matches: media.includes("prefers-reduced-motion")
        ? reduced
        : media.includes("min-width"),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  );
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
  Object.defineProperty(Element.prototype, "animate", {
    configurable: true,
    value: animate,
  });
});
afterEach(() => {
  cleanup();
  Reflect.deleteProperty(Element.prototype, "animate");
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});
async function show(unknown = false) {
  const apis = createAtlasApplicationFixture();
  if (unknown) apis.recipe = createRecipeReviewFixture("SAVE_UNKNOWN").api;
  const schoolsRead = vi.spyOn(apis.masterData, "getSchools");
  const recipeRead = vi.spyOn(apis.recipe, "getWorkbench");
  const result = render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={apis}
        authSubject="operator"
        userLabel="operator@example.test"
        environmentLabel="Local review"
        now={applicationReviewNow}
        onSignOut={vi.fn()}
      />
    </AtlasVNextProvider>,
  );
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  return { apis, schoolsRead, recipeRead, ...result };
}
function open(name: string) {
  fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
  fireEvent.click(
    within(screen.getByRole("dialog", { name: "Bàn làm việc" })).getByRole(
      "button",
      { name },
    ),
  );
}
function activate(name: string) {
  fireEvent.click(
    within(
      screen.getByRole("tablist", { name: "Bàn làm việc đang mở" }),
    ).getByRole("tab", { name: new RegExp(`^${name}`) }),
  );
}
function panel(name: string) {
  const tab = within(
    screen.getByRole("tablist", { name: "Bàn làm việc đang mở" }),
  ).getByRole("tab", { name: new RegExp(`^${name}`) });
  const owner = document.getElementById(tab.getAttribute("aria-controls")!);
  expect(owner).toHaveAttribute("role", "tabpanel");
  expect(owner).toHaveAccessibleName(name);
  return owner!;
}
async function recipe() {
  open("Công thức");
  await screen.findByRole("button", {
    name: "Sửa công thức Canh bí đỏ thịt bằm",
  });
}
async function dismissed() {
  await waitFor(() =>
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
  );
}

it("switches instantly without exit, animation or refresh and retains both owners' DOM", async () => {
  const h = await show();
  const schools = panel("Trường học");
  const input = screen.getAllByRole("textbox", {
    name: /Học sinh mặc định/,
  })[0]!;
  await recipe();
  const recipes = panel("Công thức");
  const edit = screen.getByRole("button", {
    name: "Sửa công thức Canh bí đỏ thịt bằm",
  });
  const reads = [
    h.schoolsRead.mock.calls.length,
    h.recipeRead.mock.calls.length,
  ];
  expect(schools).toHaveAttribute("hidden");
  expect(schools).toHaveAttribute("inert");
  expect(input).toBeInTheDocument();
  activate("Trường học");
  expect(panel("Trường học")).toBe(schools);
  expect(screen.getAllByRole("textbox", { name: /Học sinh mặc định/ })[0]).toBe(
    input,
  );
  expect(recipes).toHaveAttribute("hidden");
  open("Công thức");
  expect(panel("Công thức")).toBe(recipes);
  expect(
    screen.getByRole("button", { name: "Sửa công thức Canh bí đỏ thịt bằm" }),
  ).toBe(edit);
  expect(h.schoolsRead).toHaveBeenCalledTimes(reads[0]!);
  expect(h.recipeRead).toHaveBeenCalledTimes(reads[1]!);
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
  expect(animate).not.toHaveBeenCalled();
}, 20000);

it("allows a dirty switch but activates an inactive owner and guards its explicit close", async () => {
  await show();
  const input = screen.getAllByRole("textbox", {
    name: /Học sinh mặc định/,
  })[0]!;
  fireEvent.change(input, { target: { value: "123" } });
  await recipe();
  const recipes = panel("Công thức");
  expect(input).toHaveValue("123");
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  expect(panel("Trường học")).toBeVisible();
  expect(recipes).toHaveAttribute("hidden");
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  await dismissed();
  expect(input).toHaveValue("123");
  expect(
    screen.getByRole("tab", { name: /Trường học.*Chưa lưu/ }),
  ).toHaveAttribute("aria-selected", "true");
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
  await waitFor(() => expect(input).not.toBeInTheDocument());
  expect(panel("Công thức")).toBe(recipes);
  expect(
    screen.queryByRole("tab", { name: /Trường học/ }),
  ).not.toBeInTheDocument();
  expect(animate).not.toHaveBeenCalled();
}, 20000);

it("retains UNKNOWN recovery locally through activation and blocks its owner's close", async () => {
  await show(true);
  await recipe();
  const recipes = panel("Công thức");
  fireEvent.click(
    screen.getByRole("button", { name: "Sửa công thức Canh bí đỏ thịt bằm" }),
  );
  fireEvent.change(await screen.findByLabelText("Định lượng Bí đỏ"), {
    target: { value: "2,25" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  fireEvent.click(screen.getByRole("button", { name: "Lưu công thức" }));
  const recovery = await screen.findByRole("button", {
    name: "Tải lại để xác nhận",
  });
  activate("Trường học");
  expect(recipes).toHaveAttribute("hidden");
  expect(recipes).toHaveAttribute("inert");
  expect(recovery).toBeInTheDocument();
  expect(
    screen.queryByRole("button", { name: "Tải lại để xác nhận" }),
  ).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Đóng Công thức" }));
  expect(panel("Công thức")).toBe(recipes);
  expect(screen.getByRole("button", { name: "Tải lại để xác nhận" })).toBe(
    recovery,
  );
  expect(
    within(
      screen.getByRole("tablist", { name: "Bàn làm việc đang mở" }),
    ).getByRole("tab", { name: /^Công thức/ }),
  ).toHaveAttribute("aria-selected", "true");
  expect(
    screen.queryByRole("button", { name: "Bỏ thay đổi" }),
  ).not.toBeInTheDocument();
  expect(animate).not.toHaveBeenCalled();
}, 20000);

it("opens rapid destinations immediately and activates existing owners without duplicate panels", async () => {
  await show();
  open("Công thức");
  const recipes = panel("Công thức");
  open("Lập nhu cầu");
  const planning = panel("Lập nhu cầu");
  open("Phiếu xuất kho");
  const pxk = panel("Phiếu xuất kho");
  open("Công thức");
  expect(panel("Công thức")).toBe(recipes);
  expect(planning).toHaveAttribute("hidden");
  expect(pxk).toHaveAttribute("hidden");
  const tabs = within(
    screen.getByRole("tablist", { name: "Bàn làm việc đang mở" }),
  );
  expect(tabs.getAllByRole("tab")).toHaveLength(4);
  expect(tabs.getAllByRole("tab", { selected: true })).toHaveLength(1);
  expect(tabs.getByRole("tab", { selected: true })).toBe(
    tabs.getByRole("tab", { name: /^Công thức/ }),
  );
  expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
  expect(animate).not.toHaveBeenCalled();
}, 20000);

it("reduced motion preserves dirty switches and still guards an explicit close", async () => {
  reduced = true;
  await show();
  const input = screen.getAllByRole("textbox", {
    name: /Học sinh mặc định/,
  })[0]!;
  fireEvent.change(input, { target: { value: "123" } });
  await recipe();
  const recipes = panel("Công thức");
  expect(input).toHaveValue("123");
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  activate("Trường học");
  expect(screen.getAllByRole("textbox", { name: /Học sinh mặc định/ })[0]).toBe(
    input,
  );
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  expect(input).toBeInTheDocument();
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
  await waitFor(() => expect(input).not.toBeInTheDocument());
  expect(panel("Công thức")).toBe(recipes);
  expect(animate).not.toHaveBeenCalled();
}, 20000);

it("Confirmed Need opens Procurement at its exact local date and Allocation stage without a command", async () => {
  const { apis } = await show();
  const save = vi.spyOn(apis.confirmedNeed, "save");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  open("Lập nhu cầu");
  await screen.findByRole("table", { name: "Thực đơn theo trường" });
  const planning = panel("Lập nhu cầu");
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  fireEvent.change(
    await screen.findByRole("combobox", { name: "Ngày phục vụ" }),
    { target: { value: "2026-09-09" } },
  );
  fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
  const proceed = await screen.findByRole("button", {
    name: "Tiếp tục phân bổ NCC",
  });
  await waitFor(() => expect(proceed).toBeEnabled());
  expect(allocation).not.toHaveBeenCalled();
  fireEvent.click(proceed);
  expect(panel("Kế hoạch mua hàng")).toBeVisible();
  expect(planning).toHaveAttribute("hidden");
  expect(proceed).toBeInTheDocument();
  await waitFor(() =>
    expect(allocation).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          date_start: "2026-09-09",
          date_end: "2026-09-09",
        }),
      }),
    ),
  );
  expect(allocation).toHaveBeenCalledOnce();
  expect(screen.getByRole("tab", { name: "Phân bổ NCC" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  expect(save).not.toHaveBeenCalled();
  expect(prepare).not.toHaveBeenCalled();
  expect(animate).not.toHaveBeenCalled();
}, 20000);

it("keeps shell and session context stationary with only the active owner's content visible", async () => {
  const { container } = await show();
  const header = container.querySelector("header");
  const main = screen.getByRole("main");
  const launcher = screen.getByRole("button", { name: "Bàn làm việc" });
  const account = screen.getByRole("button", {
    name: "Tài khoản và môi trường",
  });
  const tabs = screen.getByRole("tablist", { name: "Bàn làm việc đang mở" });
  const schools = panel("Trường học");
  await recipe();
  expect(container.querySelector("header")).toBe(header);
  expect(screen.getByRole("main")).toBe(main);
  expect(screen.getByRole("button", { name: "Bàn làm việc" })).toBe(launcher);
  expect(screen.getByRole("button", { name: "Tài khoản và môi trường" })).toBe(
    account,
  );
  expect(screen.getByRole("tablist", { name: "Bàn làm việc đang mở" })).toBe(
    tabs,
  );
  expect(schools).toHaveAttribute("hidden");
  expect(schools).toHaveAttribute("inert");
  expect(
    screen.queryByRole("heading", { level: 1, name: "Sĩ số mặc định" }),
  ).not.toBeInTheDocument();
  expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
  fireEvent.click(account);
  const context = screen.getByRole("dialog", {
    name: "Tài khoản và môi trường",
  });
  expect(within(context).getByText("operator@example.test")).toBeVisible();
  expect(within(context).getByText("Môi trường · Local review")).toBeVisible();
  fireEvent.click(account);
  activate("Trường học");
  expect(panel("Trường học")).toBe(schools);
  expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
  expect(animate).not.toHaveBeenCalled();
}, 20000);
