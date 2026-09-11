import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { SchoolFulfilmentWorkbench } from "./SchoolFulfilmentWorkbench";
import {
  createSchoolFulfilmentReviewFixture,
  fulfilmentData,
  fulfilmentRow,
  fulfilmentSuccess,
  type SchoolFulfilmentScenario,
} from "./schoolFulfilmentReviewFixtures";
beforeEach(() =>
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  ),
);
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
function show(
  scenario: SchoolFulfilmentScenario = "ALL",
  api = createSchoolFulfilmentReviewFixture(scenario),
) {
  const read = vi.spyOn(api, "getWorkbench");
  render(
    <AtlasVNextProvider>
      <SchoolFulfilmentWorkbench
        api={api}
        authSubject="operator"
        initialDateStart="2026-09-24"
        initialDateEnd="2026-09-26"
      />
    </AtlasVNextProvider>,
  );
  return { read, api };
}
const table = () =>
  screen.getByRole("table", { name: "Đối chiếu theo trường" });
const filter = (value: string) =>
  fireEvent.change(screen.getByRole("combobox", { name: "Tình trạng" }), {
    target: { value },
  });
async function openFirst() {
  const buttons = await screen.findAllByRole("button", {
    name: "Xem đối chiếu",
  });
  fireEvent.click(buttons[0]);
  return buttons[0];
}
describe("read-only reconciliation operator workbench", () => {
  it("lands on exceptions with one h1, result before documents, and no business commands", async () => {
    const h = show();
    await screen.findAllByRole("button", { name: "Xem đối chiếu" });
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Đối chiếu PO / Phiếu xuất kho",
    );
    expect(screen.getByRole("combobox", { name: "Tình trạng" })).toHaveValue(
      "exceptions",
    );
    expect(
      within(table())
        .getAllByRole("columnheader")
        .map((e) => e.textContent),
    ).toEqual([
      "Ngày",
      "Trường / điểm giao",
      "Đối chiếu",
      "PO / PXK",
      "Số lượng",
      "Thao tác",
    ]);
    expect(screen.getByText("Cần xử lý 4 · Khớp 1")).toBeVisible();
    expect(within(table()).queryByText("Khớp")).toBeNull();
    expect(
      screen.queryByRole("button", {
        name: /phát hành|lưu|duyệt|xác nhận|sửa/i,
      }),
    ).toBeNull();
    expect(
      screen.queryByRole("textbox", { name: /số lượng|ghi chú/i }),
    ).toBeNull();
    expect(Object.keys(h.api)).toEqual(["getWorkbench"]);
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it.each([
    ["OK", "Khớp"],
    ["NO_PO", "Chưa có PO"],
    ["NO_PXK", "Chưa có PXK"],
    ["INGREDIENT_CHANGED", "Khác nguyên liệu"],
    ["MISMATCH", "Lệch số lượng"],
  ] as const)("uses backend %s label", async (status, label) => {
    const h = show(status);
    filter("all");
    await openFirst();
    expect(within(table()).getAllByRole("cell")[2]).toHaveTextContent(label);
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it("opens attached detail with row semantics, human identity, and returns focus", async () => {
    show("MISMATCH");
    const trigger = await openFirst();
    const detail = screen.getByRole("region", { name: "Chi tiết đối chiếu" });
    expect(detail).toHaveFocus();
    expect(trigger.closest("tr")).toHaveAttribute("aria-selected", "true");
    expect(
      trigger.closest("tr")?.querySelector("[data-selection-indicator]"),
    ).not.toBeNull();
    expect(within(detail).getByText("24/09/2026")).toBeVisible();
    expect(within(detail).getByText("Gạo thơm")).toBeVisible();
    expect(within(detail).getByText("Phiếu hiện hành")).toBeVisible();
    expect(
      within(detail).getByText("PO-20260924-A · PO-20260924-B"),
    ).toBeVisible();
    expect(within(detail).getByText("PXK-20260924-A")).toBeVisible();
    expect(detail).not.toHaveTextContent(/technical-|ingredient-rice|school-a/);
    fireEvent.click(
      within(detail).getByRole("button", { name: "Đóng chi tiết" }),
    );
    expect(trigger).toHaveFocus();
    expect(
      screen.queryByRole("region", { name: "Chi tiết đối chiếu" }),
    ).toBeNull();
  });
  it("shows exact backend quantities and keeps the same Ingredient in distinct Units", async () => {
    show("MIXED_UNITS");
    await openFirst();
    expect(
      within(table()).getByText("kg · PO 10 · PXK 20 · Δ -10"),
    ).toBeVisible();
    expect(
      within(table()).getByText("cái · PO 20 · PXK 10 · Δ +10"),
    ).toBeVisible();
    const detail = screen.getByRole("table", { name: "Chi tiết nguyên liệu" });
    expect(within(detail).getAllByText("Bí đỏ")).toHaveLength(2);
    expect(within(detail).getByText("-10")).toBeVisible();
    expect(within(detail).getByText("+10")).toBeVisible();
    expect(screen.queryByText(/tổng.*30/i)).toBeNull();
  });
  it("renders supplied status and delta even when a fixture contradicts local arithmetic", async () => {
    const row = fulfilmentRow({ comparison_status: "OK" });
    row.details[0].delta_quantity = "900719925474099312345.123456";
    const api = {
      getWorkbench: vi
        .fn()
        .mockResolvedValue(
          fulfilmentSuccess(fulfilmentData([row], "2026-09-24", "2026-09-26")),
        ),
    };
    show("OK", api);
    filter("all");
    await openFirst();
    expect(within(table()).getByText("Khớp")).toBeVisible();
    expect(screen.getByText("+900719925474099312345,123456")).toBeVisible();
  });
  it("keeps OK comparison separate from operational blockers and safe warning copy", async () => {
    show("OPERATIONAL_BLOCKER");
    filter("all");
    await openFirst();
    const detail = screen.getByRole("region", { name: "Chi tiết đối chiếu" });
    expect(within(detail).getByText("Khớp")).toBeVisible();
    expect(within(detail).getByText("Đang bị chặn")).toBeVisible();
    expect(
      within(detail).getByText(/Kế hoạch mua hàng chưa khớp/),
    ).toBeVisible();
  });
  it("shows warning separately without exposing unknown backend codes", async () => {
    show("WARNING");
    await openFirst();
    const detail = screen.getByRole("region", { name: "Chi tiết đối chiếu" });
    expect(within(detail).getByText("Lưu ý vận hành")).toBeVisible();
    expect(detail).not.toHaveTextContent("SOURCE_WARNING");
  });
  it("closes hidden detail on local search/status changes without reads", async () => {
    const h = show();
    await openFirst();
    const search = screen.getByRole("textbox", { name: "Tìm kiếm" });
    search.focus();
    fireEvent.change(search, { target: { value: "khong ton tai" } });
    expect(
      screen.queryByRole("region", { name: "Chi tiết đối chiếu" }),
    ).toBeNull();
    expect(search).toHaveFocus();
    expect(h.read).toHaveBeenCalledTimes(1);
    fireEvent.change(search, { target: { value: "" } });
    await openFirst();
    filter("OK");
    expect(
      screen.queryByRole("region", { name: "Chi tiết đối chiếu" }),
    ).toBeNull();
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it("School checkbox draft does not read; Apply reads and preserves full catalogue", async () => {
    const h = show();
    await screen.findAllByRole("button", { name: "Xem đối chiếu" });
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    const picker = await screen.findByRole("dialog", {
      name: "Trường / điểm giao",
    });
    fireEvent.click(
      within(picker).getByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    fireEvent.click(
      within(picker).getByRole("checkbox", {
        name: "Trường Tiểu học Nguyễn Du",
      }),
    );
    expect(h.read).toHaveBeenCalledTimes(1);
    await waitFor(() =>
      expect(
        within(picker).getByRole("button", { name: "Áp dụng" }),
      ).toBeEnabled(),
    );
    fireEvent.click(within(picker).getByRole("button", { name: "Áp dụng" }));
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    expect(h.read.mock.calls[1][0].payload).toMatchObject({
      school_ids: ["school-a"],
      search: null,
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Trường Tiểu học Nguyễn Du" }),
    );
    expect(
      await screen.findByRole("checkbox", { name: "Trường Mầm non Hoa Sen" }),
    ).toBeInTheDocument();
  });
  it.each(["READ_FAILURE", "PERMISSION_DENIED"] as const)(
    "exposes accessible explicit recovery for %s separate from refresh",
    async (scenario) => {
      const h = show(scenario);
      const retry = await screen.findByRole("button", {
        name: "Thử tải lại dữ liệu",
      });
      expect(screen.getByRole("alert")).toBeVisible();
      expect(
        screen.getByRole("button", { name: "Làm mới dữ liệu" }),
      ).toBeVisible();
      fireEvent.click(retry);
      await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    },
  );
  it("distinguishes an empty scope from local filters hiding rows", async () => {
    show("EMPTY");
    expect(
      await screen.findByText("Không có phạm vi đối chiếu hiện hành phù hợp."),
    ).toBeVisible();
  });
});
