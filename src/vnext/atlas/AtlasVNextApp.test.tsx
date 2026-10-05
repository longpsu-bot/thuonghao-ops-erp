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
  ["Nguyên liệu và Nhà cung ứng", "Nguyên liệu"],
  ["Công thức", "Công thức"],
  ["Lập nhu cầu", "Thực đơn"],
  ["Kế hoạch mua hàng", "Phân bổ nhà cung ứng"],
  ["Phiếu xuất kho", "Phiếu xuất kho"],
  ["Đối chiếu PO / Phiếu xuất kho", "Đối chiếu PO / Phiếu xuất kho"],
];
function show() {
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
  return { apis, signOut, ...result };
}
async function nav(label: string) {
  fireEvent.click(await screen.findByRole("button", { name: "Bàn làm việc" }));
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
it.each(modules)(
  "launches %s with one active heading",
  async (label, heading) => {
    show();
    await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
    await nav(label!);
    expect(
      await screen.findByRole("heading", { level: 1, name: heading! }),
    ).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1),
    );
    fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
    expect(await screen.findByRole("button", { name: label! })).toHaveAttribute(
      "aria-current",
      "page",
    );
    fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
    await waitFor(() =>
      expect(
        document.querySelector('[role="dialog"][data-state="open"]'),
      ).toBeNull(),
    );
  },
  20000,
);
it("blocks dirty sign-out without discarding and resolves School through its close guard", async () => {
  const { signOut } = show();
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
  const { apis } = show();
  const save = vi.spyOn(apis.confirmedNeed, "save");
  const allocation = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  await nav("Lập nhu cầu");
  fireEvent.click(await screen.findByRole("tab", { name: "Xác nhận nhu cầu" }));
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
  const { apis } = show();
  const confirmed = vi.spyOn(apis.confirmedNeed, "getReview");
  const procurement = vi.spyOn(apis.purchaseReview, "getConfirmedAllocations");
  const pxk = vi.spyOn(apis.schoolDispatch, "getWorkbench");
  const reconciliation = vi.spyOn(apis.reconciliation, "getWorkbench");
  const prepare = vi.spyOn(apis.purchaseReview, "preparePurchaseOrders");
  await screen.findAllByRole("textbox", { name: /Học sinh mặc định/ });
  await nav("Lập nhu cầu");
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  const date = await screen.findByRole("combobox", { name: "Ngày phục vụ" });
  fireEvent.change(date, { target: { value: "2026-09-09" } });
  fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
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
  const { apis, signOut, rerender } = show();
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
  await waitFor(() =>
    expect(
      screen.getAllByRole("textbox", { name: /Học sinh mặc định/ })[0],
    ).not.toHaveValue("123"),
  );
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
});

it("uses the injected business date for Recipe's independent initial as-of context", async () => {
  const { apis } = show();
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
