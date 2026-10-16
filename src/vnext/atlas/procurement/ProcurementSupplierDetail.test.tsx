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
  it.each([true, false])(
    "brings the new editor into view only on narrow screens (%s)",
    (narrow) => {
      const original = HTMLElement.prototype.scrollIntoView;
      const scroll = vi.fn();
      HTMLElement.prototype.scrollIntoView = scroll;
      vi.stubGlobal(
        "matchMedia",
        vi.fn(() => ({ matches: narrow })),
      );
      try {
        const { onSave } = show();
        expect(
          screen.getByRole("heading", { level: 2, name: "Gạo thơm" }),
        ).toHaveFocus();
        if (narrow) expect(scroll).toHaveBeenCalledWith({ block: "start" });
        else expect(scroll).not.toHaveBeenCalled();
        expect(onSave).not.toHaveBeenCalled();
      } finally {
        if (original) HTMLElement.prototype.scrollIntoView = original;
        else
          delete (HTMLElement.prototype as Partial<HTMLElement>).scrollIntoView;
        vi.unstubAllGlobals();
      }
    },
  );
  it.each(["\u00a0", "\u2003", "\u000b"])(
    "preserves backend-significant note suffix %j",
    (suffix) => {
      const row = reviewFamily("manual_split");
      row.splits[0]!.supplier_note = `Giao sớm${suffix}`;
      const { onSave } = show(row);
      const note = screen.getByRole("textbox", {
        name: "Ghi chú cho NCC An Phú",
      });
      expect(
        screen.getByRole("button", { name: "Lưu phân bổ" }),
      ).toBeDisabled();
      fireEvent.change(note, { target: { value: "Giao sớm" } });
      expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
      fireEvent.change(note, { target: { value: `Giao sớm${suffix}` } });
      expect(
        screen.getByRole("button", { name: "Lưu phân bổ" }),
      ).toBeDisabled();
      quantity("NCC An Phú", "50");
      quantity("NCC Bình Minh", "50");
      click("Lưu phân bổ");
      expect(onSave).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({
            supplier_id: "supplier-a",
            supplier_note: `Giao sớm${suffix}`,
          }),
        ]),
      );
    },
  );
  it("treats a supplier note as part of the saved allocation decision", async () => {
    const row = reviewFamily("manual_split");
    row.splits[0]!.supplier_note = "Loại 500g/gói";
    const { onSave, onClose } = show(row);
    const note = screen.getByRole("textbox", {
      name: "Ghi chú cho NCC An Phú",
    });
    expect(note).toHaveValue("Loại 500g/gói");
    fireEvent.change(note, { target: { value: "Giao trước 05:30" } });
    expect(screen.getByText("Đang chỉnh sửa · chưa lưu")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
    click("Đóng");
    expect(await screen.findByRole("dialog")).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    click("Lưu phân bổ");
    expect(onSave).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({
          supplier_id: "supplier-a",
          allocated_quantity: "60.000000",
          supplier_note: "Giao trước 05:30",
        }),
      ]),
    );
  });
  it("uses mobile-safe targets and keeps Save as the detail business action", () => {
    const { container } = show(reviewFamily("manual_split"));

    expect(
      container.querySelector('[aria-label="Phân bổ Gạo thơm"]'),
    ).toHaveStyle({
      "--atlas-procurement-detail-desktop-max-height":
        "var(--atlas-procurement-editor-max-height, max(360px, calc(100dvh - 320px)))",
    });

    for (const name of ["Đóng", "Lưu phân bổ", "+ Thêm nhà cung ứng"]) {
      expect(screen.getByRole("button", { name })).toHaveStyle({
        minHeight: "var(--atlas-layout-mobile-target, 44px)",
      });
    }
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    expect(
      screen.queryByRole("button", { name: "Tiếp tục lên đơn" }),
    ).not.toBeInTheDocument();
  });

  it("focuses the header and displays exact authoritative split/balance", async () => {
    show(reviewFamily("manual_split"));
    expect(screen.getByRole("heading", { name: "Gạo thơm" })).toHaveFocus();
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("60");
    quantity("NCC An Phú", "59.999999");
    expect(
      screen.getByRole("status", { name: "Cân đối phân bổ" }),
    ).toHaveTextContent("99,999999 / 100 kg đã phân bổ · Thiếu 0,000001 kg");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    quantity("NCC An Phú", "60");
    expect(
      screen.getByRole("status", { name: "Cân đối phân bổ" }),
    ).toHaveTextContent("100 / 100 kg đã phân bổ · Đã đủ");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
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
  it("opens the exact derived baseline and closes without Save or dirty protection", () => {
    const { onSave, onClose } = show();
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("100");
    expect(
      screen.getByRole("status", { name: "Cân đối phân bổ" }),
    ).toHaveTextContent("100 / 100 kg đã phân bổ · Đã đủ");
    expect(
      screen.queryByText("Đang chỉnh sửa · chưa lưu"),
    ).not.toBeInTheDocument();
    expect(screen.getByText("Mặc định #1")).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Dùng đề xuất" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    click("Lưu phân bổ");
    expect(onSave).not.toHaveBeenCalled();
    click("Đóng");
    expect(onClose).toHaveBeenCalledOnce();
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
  it("saves a real note override with exact quantities and restores semantic baseline", () => {
    const { onSave } = show();
    const note = screen.getByRole("textbox", {
      name: "Ghi chú cho NCC An Phú",
    });
    fireEvent.change(note, { target: { value: "Giao sớm" } });
    expect(screen.getByText("Đang chỉnh sửa · chưa lưu")).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
    // Applying the proposal retains this note, so it would be a no-op.
    expect(
      screen.queryByRole("button", { name: "Dùng đề xuất" }),
    ).not.toBeInTheDocument();
    click("Lưu phân bổ");
    expect(onSave).toHaveBeenCalledWith([
      {
        supplier_id: "supplier-a",
        allocated_quantity: "100.000000",
        supplier_note: "Giao sớm",
      },
    ]);
    fireEvent.change(note, { target: { value: "   " } });
    quantity("NCC An Phú", "100.000000");
    expect(
      screen.queryByText("Đang chỉnh sửa · chưa lưu"),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
  });
  it("changes Supplier, adds a split, and removes it back to the exact derived baseline", () => {
    show();
    click("+ Thêm nhà cung ứng");
    fireEvent.change(
      screen.getByRole("combobox", { name: "Nhà cung ứng đủ điều kiện" }),
      {
        target: { value: "supplier-b" },
      },
    );
    click("Thêm");
    quantity("NCC An Phú", "0");
    quantity("NCC Bình Minh", "100");
    expect(screen.getByText("Đang chỉnh sửa · chưa lưu")).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
    quantity("NCC An Phú", "40");
    quantity("NCC Bình Minh", "60");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
    click("Xóa NCC Bình Minh");
    quantity("NCC An Phú", "100");
    expect(
      screen.queryByText("Đang chỉnh sửa · chưa lưu"),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    expect(
      screen.queryByRole("button", { name: "Dùng đề xuất" }),
    ).not.toBeInTheDocument();
  });
  it("retains a persisted manual baseline over preference and disables exact restoration", () => {
    const row = reviewFamily("manual_split");
    row.recommendation = reviewFamily().recommendation;
    const { onSave } = show(row);
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Dùng đề xuất" })).toBeEnabled();
    quantity("NCC An Phú", "50");
    quantity("NCC Bình Minh", "50");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
    quantity("NCC An Phú", "60.000000");
    quantity("NCC Bình Minh", "40");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    expect(
      screen.queryByText("Đang chỉnh sửa · chưa lưu"),
    ).not.toBeInTheDocument();
    expect(onSave).not.toHaveBeenCalled();
  });
  it("does not create manual authority for an added zero split omitted by Save", () => {
    const { onSave } = show();
    click("+ Thêm nhà cung ứng");
    fireEvent.change(
      screen.getByRole("combobox", { name: "Nhà cung ứng đủ điều kiện" }),
      {
        target: { value: "supplier-b" },
      },
    );
    click("Thêm");
    quantity("NCC Bình Minh", "0");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    click("Lưu phân bổ");
    expect(onSave).not.toHaveBeenCalled();
  });
  it("lets an operator split the seeded default and return to it without losing its note", () => {
    show();
    const note = screen.getByRole("textbox", {
      name: "Ghi chú cho NCC An Phú",
    });
    fireEvent.change(note, { target: { value: "Giao trước 05:30" } });
    quantity("NCC An Phú", "40");
    click("+ Thêm nhà cung ứng");
    fireEvent.change(
      screen.getByRole("combobox", { name: "Nhà cung ứng đủ điều kiện" }),
      { target: { value: "supplier-b" } },
    );
    click("Thêm");
    quantity("NCC Bình Minh", "60");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();

    click("Dùng đề xuất");
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("100");
    expect(
      screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" }),
    ).toHaveValue("Giao trước 05:30");
    expect(
      screen.queryByRole("textbox", { name: "Phân bổ NCC Bình Minh" }),
    ).not.toBeInTheDocument();
  });
  it("keeps prior splits authoritative while applying a rebalance locally", () => {
    const row = reviewFamily("rebalance");
    row.splits[0]!.supplier_note = "Rau non, không lấy bó già";
    const { onSave } = show(row);
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("60");
    click("Áp dụng đề xuất");
    expect(onSave).not.toHaveBeenCalled();
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("72");
    expect(
      screen.getByRole("textbox", { name: "Ghi chú cho NCC An Phú" }),
    ).toHaveValue("Rau non, không lấy bó già");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
    click("Lưu phân bổ");
    expect(onSave).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({
          supplier_id: "supplier-a",
          supplier_note: "Rau non, không lấy bó già",
        }),
      ]),
    );
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
    expect(
      screen.getByRole("textbox", { name: "Ghi chú cho NCC Thành Công" }),
    ).toHaveValue("");
    fireEvent.change(
      screen.getByRole("textbox", { name: "Ghi chú cho NCC Thành Công" }),
      { target: { value: "Only this supplier" } },
    );
    click("Xóa NCC Thành Công");
    expect(
      screen.queryByRole("textbox", { name: "Phân bổ NCC Thành Công" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("textbox", { name: "Ghi chú cho NCC Thành Công" }),
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
