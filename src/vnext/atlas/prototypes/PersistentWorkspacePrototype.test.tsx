/** Review-only workspace behavior; real workbenches, no hosted adapters. */
import { afterEach, expect, it } from "vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { ModernOperationalPilot } from "./ModernOperationalPilot.stories";

afterEach(() => {
  cleanup();
  window.history.replaceState(null, "", "/");
});
function start(surface = "need") {
  window.history.replaceState(null, "", `?variant=D&surface=${surface}`);
  render(<ModernOperationalPilot />);
}
async function launch(label: string) {
  fireEvent.click(screen.getByRole("button", { name: "Mở bàn làm việc" }));
  fireEvent.click(await screen.findByRole("button", { name: label }));
}
const tabs = () =>
  within(screen.getByRole("tablist", { name: "Bàn làm việc đang mở" }));

it("keeps real drafts, selection and initial reads when switching or launching an existing tab", async () => {
  start();
  expect(await screen.findByRole("tab", { name: "Lập nhu cầu" })).toBeTruthy();
  const quantity = await screen.findByRole("textbox", {
    name: "Số lượng xác nhận Gạo thơm",
  });
  fireEvent.change(quantity, { target: { value: "12,5" } });
  fireEvent.change(screen.getByRole("combobox", { name: "Lý do Gạo thơm" }), {
    target: { value: "OTHER" },
  });
  fireEvent.change(screen.getByRole("textbox", { name: "Ghi chú Gạo thơm" }), {
    target: { value: "Giữ bản nháp khi đổi bàn" },
  });
  await waitFor(() =>
    expect(
      tabs().getByRole("tab", { name: /Lập nhu cầu.*chưa lưu/ }),
    ).toBeTruthy(),
  );
  const needPanel = screen.getByTestId("workspace-panel-need");
  const reads = needPanel.dataset.readCount;
  await launch("Kế hoạch mua hàng");
  const search = await screen.findByRole("textbox", { name: "Tìm kiếm" });
  fireEvent.change(search, { target: { value: "Gạo" } });
  fireEvent.click(
    (
      await screen.findAllByRole("button", { name: /^Xem phân bổ Gạo thơm/ })
    )[0]!,
  );
  const note = await screen.findByRole("textbox", {
    name: /Ghi chú cho NCC An Phú/,
  });
  await launch("Công thức");
  await screen.findByRole("textbox", { name: "Tìm món" });
  await launch("Phiếu xuất kho");
  await screen.findByRole("heading", { name: "Phiếu xuất kho" });
  fireEvent.click(tabs().getByRole("tab", { name: /Lập nhu cầu/ }));
  expect(
    screen.getByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" }),
  ).toBe(quantity);
  expect((quantity as HTMLInputElement).value).toBe("12,5");
  expect(needPanel.dataset.mountCount).toBe("1");
  expect(needPanel.dataset.readCount).toBe(reads);
  expect(screen.queryByRole("dialog")).toBeNull();
  await launch("Kế hoạch mua hàng");
  expect(tabs().getAllByRole("tab")).toHaveLength(4);
  expect(screen.getByRole("textbox", { name: /Ghi chú cho NCC An Phú/ })).toBe(
    note,
  );
  expect((search as HTMLInputElement).value).toBe("Gạo");
  expect(needPanel.hidden).toBe(true);
  expect(needPanel.hasAttribute("inert")).toBe(true);
  expect(
    screen.queryByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" }),
  ).toBeNull();
}, 20000);

it("keeps Recipe metadata attention truthful and its existing close guard authoritative", async () => {
  start("recipes");
  fireEvent.click(await screen.findByRole("button", { name: "Tạo món mới" }));
  const name = await screen.findByRole("textbox", { name: "Tên món" });
  fireEvent.change(name, { target: { value: "Món minh họa chưa lưu" } });
  await waitFor(() =>
    expect(
      tabs().getByRole("tab", { name: /Công thức.*biểu mẫu món đang mở/ }),
    ).toBeTruthy(),
  );
  await launch("Lập nhu cầu");
  expect(
    tabs().getByRole("tab", { name: /Công thức.*biểu mẫu món đang mở/ }),
  ).toBeTruthy();
  fireEvent.click(tabs().getByRole("button", { name: "Đóng bàn Công thức" }));
  const guard = await screen.findByRole("dialog");
  fireEvent.click(
    within(guard).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  expect((name as HTMLInputElement).value).toBe("Món minh họa chưa lưu");
}, 20000);

it("seeds new Procurement from Need and retains an existing date and Orders stage", async () => {
  start();
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục phân bổ NCC" }),
  );
  await screen.findByRole("heading", { name: "Phân bổ nhà cung ứng" });
  const seeded = screen.getByTestId("workspace-panel-procurement");
  expect(seeded.dataset.serviceDate).toBe("2026-09-07");
  fireEvent.click(
    tabs().getByRole("button", { name: "Đóng bàn Kế hoạch mua hàng" }),
  );
  await waitFor(() =>
    expect(screen.queryByTestId("workspace-panel-procurement")).toBeNull(),
  );
  await launch("Kế hoạch mua hàng");
  fireEvent.click(await screen.findByRole("tab", { name: "Đơn mua" }));
  await screen.findByRole("heading", { name: "Đơn mua" });
  const existing = screen.getByTestId("workspace-panel-procurement");
  const reads = existing.dataset.readCount;
  fireEvent.click(tabs().getByRole("tab", { name: "Lập nhu cầu" }));
  fireEvent.click(screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }));
  expect(screen.getByTestId("workspace-panel-procurement")).toBe(existing);
  expect(existing.dataset.serviceDate).toBe("2026-09-10");
  expect(
    screen.getByRole("tab", { name: "Đơn mua" }).getAttribute("aria-selected"),
  ).toBe("true");
  expect(existing.dataset.mountCount).toBe("1");
  expect(existing.dataset.readCount).toBe(reads);
  expect(
    screen.getByText(/Nhu cầu ngày 07\/09\/2026.*đang giữ ngày 10\/09\/2026/),
  ).toBeTruthy();
}, 20000);

it("closes clean tabs and delegates dirty close to the existing Need discard guard", async () => {
  start();
  const quantity = await screen.findByRole("textbox", {
    name: "Số lượng xác nhận Gạo thơm",
  });
  fireEvent.change(quantity, { target: { value: "12,5" } });
  await launch("Công thức");
  await screen.findByRole("textbox", { name: "Tìm món" });
  fireEvent.click(tabs().getByRole("button", { name: "Đóng bàn Công thức" }));
  await waitFor(() =>
    expect(tabs().queryByRole("tab", { name: "Công thức" })).toBeNull(),
  );
  fireEvent.click(tabs().getByRole("button", { name: "Đóng bàn Lập nhu cầu" }));
  const dialog = await screen.findByRole("dialog");
  expect(
    within(dialog).getByText("Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?"),
  ).toBeTruthy();
  fireEvent.click(
    within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  expect((quantity as HTMLInputElement).value).toBe("12,5");
  fireEvent.click(tabs().getByRole("button", { name: "Đóng bàn Lập nhu cầu" }));
  fireEvent.click(
    within(await screen.findByRole("dialog")).getByRole("button", {
      name: "Bỏ thay đổi",
    }),
  );
  await waitFor(() =>
    expect(screen.queryByTestId("workspace-panel-need")).toBeNull(),
  );
}, 20000);
