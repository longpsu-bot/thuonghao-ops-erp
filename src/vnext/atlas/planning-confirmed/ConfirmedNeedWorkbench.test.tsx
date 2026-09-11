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
import { ConfirmedNeedWorkbench } from "./ConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
  type ConfirmedReviewScenario,
} from "./confirmedNeedReviewFixtures";
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
function show(scenario: ConfirmedReviewScenario = "normal") {
  const f = createConfirmedNeedReviewFixture(scenario);
  const navigate = vi.fn();
  const detail = vi.spyOn(f.needGenerationApi, "getWorkbench");
  const save = vi.spyOn(f.confirmedNeedApi, "save");
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...f}
        authSubject="operator"
        initialServiceDate={reviewDate}
        onContinueAllocation={navigate}
      />
    </AtlasVNextProvider>,
  );
  return { f, navigate, detail, save };
}
async function quantity() {
  return screen.findByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" });
}
async function editValid() {
  fireEvent.change(await quantity(), { target: { value: "12,5" } });
  fireEvent.change(screen.getByRole("combobox", { name: "Lý do Gạo thơm" }), {
    target: { value: "OTHER" },
  });
  fireEvent.change(screen.getByRole("textbox", { name: "Ghi chú Gạo thơm" }), {
    target: { value: "Bếp yêu cầu" },
  });
}
describe("Confirmed Need Chakra operator surface", () => {
  it("displays an exact cent delta beyond binary floating-point precision", async () => {
    const h = show();
    await quantity();
    h.f.batch.lines[0]!.confirmed_quantity_after = "99999999999999.980000";
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    await waitFor(() =>
      expect(
        screen.getByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" }),
      ).toHaveValue("99999999999999,98"),
    );
    fireEvent.change(await quantity(), {
      target: { value: "99999999999999,99" },
    });
    expect(screen.getByRole("cell", { name: "+0,01" })).toBeVisible();
  });
  it("pages Need detail through bounded backend reads and applies school/ingredient filters explicitly", async () => {
    const h = show();
    await quantity();
    h.f.need.pagination.has_more = true;
    h.f.need.pagination.total_groups = 26;
    fireEvent.click(
      screen.getByRole("button", { name: "Xem cách hình thành nhu cầu" }),
    );
    await screen.findByRole("table", { name: "Cách hình thành nhu cầu" });
    fireEvent.click(screen.getByRole("button", { name: "Trang sau" }));
    await waitFor(() => expect(h.detail).toHaveBeenCalledTimes(2));
    expect(h.detail.mock.calls[1]!.slice(6, 8)).toEqual([25, 25]);
    await screen.findByRole("table", { name: "Cách hình thành nhu cầu" });
    fireEvent.change(
      screen.getByRole("combobox", { name: "Trường chi tiết" }),
      { target: { value: "school-0" } },
    );
    fireEvent.change(
      screen.getByRole("combobox", { name: "Nguyên liệu chi tiết" }),
      { target: { value: "ingredient-0" } },
    );
    expect(h.detail).toHaveBeenCalledTimes(2);
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng chi tiết" }));
    await waitFor(() => expect(h.detail).toHaveBeenCalledTimes(3));
    expect(h.detail.mock.calls[2]![5]).toMatchObject({
      service_date: reviewDate,
      school_id: "school-0",
      ingredient_id: "ingredient-0",
    });
    expect(h.detail.mock.calls[2]![6]).toBe(0);
  });
  it.each([
    ["no_demand", "Không có nhu cầu cần lập cho ngày này."],
    ["blocked", "Cần lưu sĩ số trước khi tạo nhu cầu."],
  ] as const)(
    "shows compact %s state without an empty table",
    async (scenario, message) => {
      show(scenario);
      expect(await screen.findByText(message)).toBeVisible();
      expect(screen.queryByRole("table")).not.toBeInTheDocument();
    },
  );
  it.each([
    ["not_generated", "Tạo nhu cầu"],
    ["outdated", "Cập nhật nhu cầu"],
  ] as const)(
    "opens generated Confirmed Need directly from %s",
    async (scenario, label) => {
      show(scenario);
      fireEvent.click(await screen.findByRole("button", { name: label }));
      expect(
        await screen.findByRole("table", { name: "Nhu cầu xác nhận" }),
      ).toBeVisible();
      expect(screen.queryByText("Mở xác nhận")).not.toBeInTheDocument();
    },
  );
  it("has one h1, quiet summary, semantic table and no technical identifiers", async () => {
    show();
    await quantity();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Xác nhận nhu cầu",
    );
    expect(screen.getAllByRole("columnheader")).toHaveLength(6);
    expect(document.body.textContent).not.toMatch(
      /batch-current|line-0|revision-0|decision-0|DRAFT_REVIEW/,
    );
    expect(screen.getByText(/6 dòng/)).toBeVisible();
  });
  it("links invalid quantity to its error and disables Save/Continue", async () => {
    show();
    const input = await quantity();
    fireEvent.change(input, { target: { value: "10,123" } });
    expect(input).toHaveAttribute("aria-invalid", "true");
    expect(
      document.getElementById(input.getAttribute("aria-describedby")!),
    ).toHaveTextContent("2 chữ số thập phân");
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toBeDisabled();
  });
  it("renders historical six-place authority read-only without rounding", async () => {
    show("historical");
    expect(await quantity()).toHaveValue("10,123456");
    expect(await quantity()).toHaveAttribute("readonly");
  });
  it("saves valid changes and adopts the returned value", async () => {
    const h = show();
    await editValid();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(await screen.findByText("Đã lưu thay đổi.")).toBeVisible();
    expect(await quantity()).toHaveValue("12,5");
    expect(h.save).toHaveBeenCalledTimes(1);
  });
  it("protects refresh through one dialog, preserving draft on cancel", async () => {
    show();
    fireEvent.change(await quantity(), { target: { value: "12,5" } });
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    expect(await screen.findByRole("dialog")).toHaveTextContent(
      "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?",
    );
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
    expect(await quantity()).toHaveValue("12,5");
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(await quantity()).toHaveValue("10,25");
  });
  it("uses the same dirty dialog for committed School Apply", async () => {
    show();
    fireEvent.change(await quantity(), { target: { value: "12,5" } });
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    fireEvent.click(
      await screen.findByRole("checkbox", { name: "Trường Nguyễn Du" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(
      await screen.findByRole("dialog", {
        name: "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?",
      }),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
    expect(await quantity()).toHaveValue("12,5");
  });
  it("shows hidden changes while search stays local", async () => {
    show();
    fireEvent.change(await quantity(), { target: { value: "12,5" } });
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm kiếm" }), {
      target: { value: "thit" },
    });
    expect(
      screen.getByText("Có 1 thay đổi chưa lưu ngoài bộ lọc hiện tại."),
    ).toBeVisible();
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
  it.each(["stale", "unknown", "recovery_failed"] as const)(
    "exposes accessible %s recovery and locks writes",
    async (scenario) => {
      show(scenario);
      await editValid();
      fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
      const recovery = await screen.findByRole("button", {
        name:
          scenario === "stale"
            ? "Tải lại dữ liệu hiện tại"
            : "Tải lại để xác nhận",
      });
      expect(
        screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
      ).toBeDisabled();
      fireEvent.click(recovery);
      if (scenario === "recovery_failed") {
        expect(
          await screen.findByText(
            "Không thể thực hiện yêu cầu. Hãy tải lại dữ liệu.",
          ),
        ).toBeVisible();
        expect(
          screen.getByRole("button", { name: "Tải lại để xác nhận" }),
        ).toBeVisible();
      } else
        await waitFor(() =>
          expect(
            screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
          ).toBeEnabled(),
        );
    },
  );
  it("released authority is read-only but navigates directly without a dialog", async () => {
    const h = show("released");
    expect(await quantity()).toBeDisabled();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    );
    expect(h.navigate).toHaveBeenCalledWith(reviewDate);
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
  it("loads grouped Need only on disclosure with exact date and backend page bounds", async () => {
    const h = show();
    await quantity();
    expect(h.detail).not.toHaveBeenCalled();
    fireEvent.click(
      screen.getByRole("button", { name: "Xem cách hình thành nhu cầu" }),
    );
    expect(
      await screen.findByRole("table", { name: "Cách hình thành nhu cầu" }),
    ).toBeVisible();
    expect(h.detail).toHaveBeenCalledWith(
      "operator",
      expect.any(String),
      reviewDate,
      reviewDate,
      "run-current",
      {
        service_date: reviewDate,
        school_id: null,
        ingredient_id: null,
        contribution_family: null,
      },
      0,
      25,
      null,
    );
    fireEvent.change(screen.getByRole("combobox", { name: "Nguồn đóng góp" }), {
      target: { value: "PANTRY_DIRECT" },
    });
    expect(h.detail).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng chi tiết" }));
    await waitFor(() => expect(h.detail).toHaveBeenCalledTimes(2));
    expect(h.detail.mock.calls[1]![5].contribution_family).toBe(
      "PANTRY_DIRECT",
    );
    fireEvent.click(
      within(
        screen.getByRole("table", { name: "Cách hình thành nhu cầu" }),
      ).getByRole("button", { name: "Gạo thơm" }),
    );
    expect(await screen.findByText(/Cơm trắng/)).toBeVisible();
    expect(screen.getByText(/Bổ sung suất ăn/)).toBeVisible();
    expect(document.body.textContent).not.toContain("atomic-private");
  });
});
