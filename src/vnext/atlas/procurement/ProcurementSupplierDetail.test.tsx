import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementSupplierDetail } from "./ProcurementSupplierDetail";
import { reviewFamily } from "./procurementReviewFixtures";
afterEach(cleanup);
function show(row = reviewFamily(), disabled = false) {
  const onSave = vi.fn();
  const onClose = vi.fn();
  const view = render(
    <AtlasVNextProvider>
      <ProcurementSupplierDetail
        row={row}
        disabled={disabled}
        onSave={onSave}
        onClose={onClose}
      />
    </AtlasVNextProvider>,
  );
  return { ...view, onSave, onClose };
}
const click = (name: string) =>
  fireEvent.click(screen.getByRole("button", { name }));
const quantity = (name: string, value: string) =>
  fireEvent.change(screen.getByRole("textbox", { name: `Phân bổ ${name}` }), {
    target: { value },
  });
describe("Supplier decisions", () => {
  it("focuses the header and displays exact authoritative split/balance", async () => {
    show(reviewFamily("manual_split"));
    expect(screen.getByRole("heading", { name: "Gạo thơm" })).toHaveFocus();
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("60.000000");
    quantity("NCC An Phú", "59.999999");
    expect(
      screen.getByRole("status", { name: "Cân đối phân bổ" }),
    ).toHaveTextContent("0,000001 kg");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    quantity("NCC An Phú", "60");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
  });
  it.each(["bad", "", "-1", "60.0000001", "1e2"])(
    "rejects invalid quantity %s",
    (value) => {
      show(reviewFamily("manual_split"));
      quantity("NCC An Phú", value);
      expect(
        screen.getByRole("button", { name: "Lưu phân bổ" }),
      ).toBeDisabled();
      expect(
        screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
      ).toHaveAttribute("aria-invalid", "true");
    },
  );
  it("applies recommendation only to local draft then sends exact strings on explicit Save", () => {
    const { onSave } = show();
    click("Dùng đề xuất");
    expect(onSave).not.toHaveBeenCalled();
    click("Lưu phân bổ");
    expect(onSave).toHaveBeenCalledWith([
      { supplier_id: "supplier-a", allocated_quantity: "100.000000" },
    ]);
  });
  it("keeps prior splits authoritative while applying a rebalance locally", () => {
    const { onSave } = show(reviewFamily("rebalance"));
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("60.000000");
    click("Áp dụng đề xuất");
    expect(onSave).not.toHaveBeenCalled();
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("72.000000");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
  });
  it("shows ineligible saved supplier and quantity without transferring it", () => {
    show(reviewFamily("needs_reallocation"));
    expect(screen.getByRole("alert")).toHaveTextContent("NCC Bình Minh");
    expect(screen.getByRole("alert")).toHaveTextContent("40 kg");
    expect(
      screen.queryByRole("textbox", { name: "Phân bổ NCC Bình Minh" }),
    ).not.toBeInTheDocument();
    click("+ Thêm nhà cung ứng");
    expect(
      screen.queryByRole("option", { name: "NCC Bình Minh" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
  });
  it("adds and removes only eligible unselected participants", () => {
    show(reviewFamily("manual_split"));
    click("+ Thêm nhà cung ứng");
    expect(
      screen.queryByRole("option", { name: "NCC An Phú" }),
    ).not.toBeInTheDocument();
    fireEvent.change(
      screen.getByRole("combobox", { name: "Nhà cung ứng đủ điều kiện" }),
      { target: { value: "supplier-c" } },
    );
    click("Thêm");
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC Thành Công" }),
    ).toHaveValue("");
    click("Xóa NCC Thành Công");
    expect(
      screen.queryByRole("textbox", { name: "Phân bổ NCC Thành Công" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Xóa NCC An Phú" }),
    ).not.toBeInTheDocument();
  });
  it("never accepts an ineligible advisory supplier", () => {
    const row = reviewFamily();
    row.recommendation!.supplier_id = "ineligible";
    show(row);
    expect(screen.getByRole("button", { name: "Dùng đề xuất" })).toBeDisabled();
  });
  it.each(["backend", "locked"])(
    "keeps %s Save unavailable even when exactly balanced",
    (mode) => {
      const row = reviewFamily("manual_split");
      if (mode === "backend") row.allowed_actions.save_allocation = false;
      show(row, mode === "locked");
      expect(
        screen.getByRole("button", { name: "Lưu phân bổ" }),
      ).toBeDisabled();
    },
  );
  it("closes a numerically unchanged draft immediately", () => {
    const { onClose } = show(reviewFamily("manual_split"));
    quantity("NCC An Phú", "60");
    click("Đóng");
    expect(onClose).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
  it("uses a scoped dirty Dialog, cancel preserves the draft and discard closes", async () => {
    const { onClose } = show(reviewFamily("manual_split"));
    quantity("NCC An Phú", "50");
    click("Đóng");
    const dialog = await screen.findByRole("dialog");
    expect(dialog.closest(".atlas-vnext")).not.toBeNull();
    expect(dialog).toHaveTextContent("Có thay đổi phân bổ chưa lưu");
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(onClose).not.toHaveBeenCalled();
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("50");
    click("Đóng");
    fireEvent.click(
      within(await screen.findByRole("dialog")).getByRole("button", {
        name: "Bỏ thay đổi và đóng",
      }),
    );
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
