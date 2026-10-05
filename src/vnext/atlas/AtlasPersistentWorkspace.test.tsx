import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextApp } from "./AtlasVNextApp";
import {
  applicationReviewNow,
  createAtlasApplicationFixture,
} from "./atlasApplicationReviewFixtures";

beforeEach(() => {
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

function show() {
  const apis = createAtlasApplicationFixture();
  const signOut = vi.fn();
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
  return { apis, signOut };
}

async function open(label: string) {
  fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
}

it("returns to an already-open School workbench with its exact draft and input instance", async () => {
  render(
    <AtlasVNextProvider>
      <AtlasVNextApp
        apis={createAtlasApplicationFixture()}
        authSubject="operator"
        now={applicationReviewNow}
      />
    </AtlasVNextProvider>,
  );
  const field = (
    await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ })
  )[0]!;
  fireEvent.change(field, { target: { value: "123" } });
  await open("Phiếu xuất kho");
  await screen.findByRole("heading", { name: "Phiếu xuất kho" });
  expect(field.isConnected).toBe(true);
  expect(field.closest('[role="tabpanel"]')).toHaveAttribute("hidden");
  expect(field.closest('[role="tabpanel"]')).toHaveAttribute("inert");
  await open("Trường học");
  await waitFor(() =>
    expect(
      screen.getAllByRole("textbox", { name: /Học sinh mặc định/ })[0],
    ).toBe(field),
  );
  expect(field).toHaveValue("123");
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
}, 20_000);

it("activates existing instances with no duplicate or initialization reads", async () => {
  const { apis } = show();
  const schools = vi.spyOn(apis.masterData, "getSchools");
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  await open("Kế hoạch mua hàng");
  await waitFor(() => expect(allocation).toHaveBeenCalledOnce());
  const schoolReads = schools.mock.calls.length;
  await open("Trường học");
  await open("Kế hoạch mua hàng");
  await open("Kế hoạch mua hàng");
  expect(allocation).toHaveBeenCalledOnce();
  expect(schools).toHaveBeenCalledTimes(schoolReads);
  expect(
    document.querySelectorAll(
      '[role="tabpanel"][aria-label="Kế hoạch mua hàng"]',
    ),
  ).toHaveLength(1);
  expect(
    screen.getByRole("tab", { name: "Kế hoạch mua hàng" }),
  ).toHaveAttribute("aria-selected", "true");
}, 20_000);

it("blocks sign-out with multiple dirty owners and preserves every hidden draft", async () => {
  const { signOut } = show();
  const school = (
    await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ })
  )[0]!;
  fireEvent.change(school, { target: { value: "123" } });
  await open("Công thức");
  fireEvent.click(await screen.findByRole("button", { name: "Tạo món mới" }));
  const dish = await screen.findByRole("textbox", { name: "Tên món" });
  fireEvent.change(dish, { target: { value: "Món thử" } });
  await open("Phiếu xuất kho");
  fireEvent.click(
    screen.getByRole("button", { name: "Tài khoản và môi trường" }),
  );
  fireEvent.click(await screen.findByRole("button", { name: "Đăng xuất" }));
  expect(signOut).not.toHaveBeenCalled();
  expect(
    screen.getByRole("button", { name: "Trường học — Chưa lưu" }),
  ).toBeVisible();
  expect(
    screen.getByRole("button", { name: "Công thức — Chưa lưu" }),
  ).toBeVisible();
  expect(
    screen.queryByRole("button", { name: "Bỏ thay đổi" }),
  ).not.toBeInTheDocument();
  expect(school).toHaveValue("123");
  expect(dish).toHaveValue("Món thử");
  const unload = new Event("beforeunload", { cancelable: true });
  window.dispatchEvent(unload);
  expect(unload.defaultPrevented).toBe(true);
}, 20_000);

it("makes an inactive dirty owner visible before close, retains cancellation, and closes only that owner on approval", async () => {
  show();
  const school = (
    await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ })
  )[0]!;
  fireEvent.change(school, { target: { value: "123" } });
  await open("Phiếu xuất kho");
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  expect(school.closest('[role="tabpanel"]')).not.toHaveAttribute("hidden");
  const cancelledDialog = await screen.findByRole("dialog");
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  await waitFor(() =>
    expect(cancelledDialog).toHaveAttribute("data-state", "closed"),
  );
  fireEvent(cancelledDialog, new Event("animationcancel", { bubbles: true }));
  expect(school).toHaveValue("123");
  await waitFor(() =>
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
  );
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
  await waitFor(() => expect(school.isConnected).toBe(false));
  expect(screen.getByRole("tab", { name: "Phiếu xuất kho" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  await waitFor(() =>
    expect(screen.getByRole("tab", { name: "Phiếu xuất kho" })).toHaveFocus(),
  );
}, 20_000);

it("restores current active navigation when close focus cleanup completes after another owner opens", async () => {
  show();
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  await open("Công thức");
  await screen.findByRole("button", { name: "Tạo món mới" });
  const frames: FrameRequestCallback[] = [];
  vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) =>
    frames.push(callback),
  );
  fireEvent.click(screen.getByRole("button", { name: "Đóng Trường học" }));
  await open("Phiếu xuất kho");
  act(() =>
    frames.splice(0).forEach((callback) => callback(performance.now())),
  );
  const active = screen.getByRole("tab", { name: /^Phiếu xuất kho/ });
  expect(active).toHaveAttribute("aria-selected", "true");
  await waitFor(() => expect(active).toHaveFocus());
}, 20_000);
