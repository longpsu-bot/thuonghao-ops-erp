import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextApp } from "./AtlasVNextApp";
import {
  createAtlasApplicationFixture,
  applicationReviewNow,
} from "./atlasApplicationReviewFixtures";
afterEach(cleanup);
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
  fireEvent.click(await screen.findByRole("button", { name: "Mở điều hướng" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
  await waitFor(() =>
    expect(
      screen.queryByRole("dialog", { name: "Điều hướng Atlas" }),
    ).not.toBeInTheDocument(),
  );
}
it("renders exactly one vNext capability for every primary navigation entry", async () => {
  show();
  for (const [label, heading] of modules) {
    await waitFor(() =>
      expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1),
    );
    await act(async () => {});
    await nav(label!);
    expect(
      await screen.findByRole("heading", { level: 1, name: heading! }),
    ).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1),
    );
    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    expect(await screen.findByRole("button", { name: label! })).toHaveAttribute(
      "aria-current",
      "page",
    );
    fireEvent.click(screen.getByRole("button", { name: "Đóng điều hướng" }));
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
  }
}, 60000);
it("guards sign out with the active School discard interaction", async () => {
  const { signOut } = show();
  const fields = await screen.findAllByRole("textbox", {
    name: /Học sinh mặc định/,
  });
  fireEvent.change(fields[0]!, { target: { value: "123" } });
  fireEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
  expect(signOut).not.toHaveBeenCalled();
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  expect(signOut).not.toHaveBeenCalled();
  await waitFor(() =>
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
  );
  fireEvent.click(await screen.findByRole("button", { name: "Đăng xuất" }));
  fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
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
  fireEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
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
      name: "Xem công thức Canh bí đỏ thịt bằm",
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
