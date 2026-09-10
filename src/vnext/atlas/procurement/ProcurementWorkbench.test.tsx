import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementWorkbench } from "./ProcurementWorkbench";
import {
  createProcurementReviewFixture,
  reviewDate,
  reviewFamily,
  reviewSchools,
} from "./procurementReviewFixtures";
beforeEach(() => {
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
  scenario: Parameters<typeof createProcurementReviewFixture>[0] = "normal",
) {
  const fixture = createProcurementReviewFixture(scenario);
  const read = vi.spyOn(fixture.purchaseReviewApi, "getConfirmedAllocations");
  const save = vi.spyOn(fixture.purchaseReviewApi, "saveConfirmedAllocation");
  const view = render(
    <AtlasVNextProvider>
      <ProcurementWorkbench
        {...fixture}
        authSubject="operator"
        initialServiceDate={reviewDate}
        schools={reviewSchools}
      />
    </AtlasVNextProvider>,
  );
  return { ...view, fixture, read, save };
}
const action = () =>
  screen.findByRole("button", { name: /^(Phân bổ NCC|Xem phân bổ) Gạo thơm$/ });
describe("Procurement vNext operator workbench", () => {
  it("has one h1, two job tabs, canonical columns and no technical identity", async () => {
    show();
    await action();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getAllByRole("tab").map((tab) => tab.textContent)).toEqual([
      "Phân bổ NCC",
      "Đơn mua",
    ]);
    expect(
      within(screen.getByRole("table", { name: "Phân bổ nhà cung ứng" }))
        .getAllByRole("columnheader")
        .map((cell) => cell.textContent),
    ).toEqual([
      "Nguyên liệu",
      "Trường / điểm giao",
      "Nhu cầu đã xác nhận",
      "Đã phân bổ",
      "Còn lại",
      "Nhà cung ứng",
      "Trạng thái",
      "Thao tác",
    ]);
    expect(document.body).not.toHaveTextContent(
      /private-|fingerprint|UUID|phiên bản/i,
    );
    expect(
      within(screen.getByRole("table")).getByText("Chưa phân bổ"),
    ).toBeVisible();
  });
  it("keeps search and exception filtering local", async () => {
    const { read } = show();
    await action();
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm kiếm" }), {
      target: { value: "gao" },
    });
    expect(await action()).toBeVisible();
    fireEvent.change(screen.getByRole("combobox", { name: "Ngoại lệ" }), {
      target: { value: "blocked" },
    });
    expect(
      screen.queryByRole("button", { name: "Phân bổ NCC Gạo thơm" }),
    ).not.toBeInTheDocument();
    expect(read).toHaveBeenCalledTimes(1);
  });
  it("opens detail, marks selection geometrically and returns focus to the row", async () => {
    show();
    const trigger = await action();
    fireEvent.click(trigger);
    expect(screen.getByRole("heading", { name: "Gạo thơm" })).toHaveFocus();
    const row = trigger.closest("tr")!;
    expect(row).toHaveAttribute("aria-selected", "true");
    expect(row.querySelector("[data-selection-indicator]")).not.toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Đóng" }));
    expect(trigger).toHaveFocus();
  });
  it("discard/reopen restores the authoritative draft", async () => {
    show("manual_split");
    fireEvent.click(await action());
    fireEvent.change(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
      { target: { value: "20" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Đóng" }));
    fireEvent.click(
      within(await screen.findByRole("dialog")).getByRole("button", {
        name: "Bỏ thay đổi và đóng",
      }),
    );
    fireEvent.click(await action());
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("60.000000");
  });
  it("requires explicit School Apply, supports search, and prevents zero-scope application", async () => {
    const { read } = show();
    await action();
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    const picker = await screen.findByRole("dialog", {
      name: "Trường / điểm giao",
    });
    expect(within(picker).getAllByRole("checkbox")).toHaveLength(33);
    fireEvent.click(
      within(picker).getByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    expect(
      within(picker).getByRole("button", { name: "Áp dụng" }),
    ).toBeDisabled();
    expect(read).toHaveBeenCalledTimes(1);
    fireEvent.change(
      within(picker).getByRole("textbox", { name: "Tìm trường" }),
      { target: { value: "Nguyễn" } },
    );
    expect(within(picker).getAllByRole("checkbox")).toHaveLength(1);
    fireEvent.click(
      within(picker).getByRole("checkbox", {
        name: reviewSchools[0]!.school_name,
      }),
    );
    await waitFor(() =>
      expect(
        within(picker).getByRole("button", { name: "Áp dụng" }),
      ).toBeEnabled(),
    );
    expect(read).toHaveBeenCalledTimes(1);
    fireEvent.click(within(picker).getByRole("button", { name: "Áp dụng" }));
    await waitFor(() => expect(read).toHaveBeenCalledTimes(2));
    expect(read.mock.lastCall![0].payload).toMatchObject({
      school_ids: ["school-0"],
    });
    expect(
      screen.getByRole("button", { name: reviewSchools[0]!.school_name }),
    ).toBeVisible();
  });
  it("closing the School picker cancels draft changes and selecting all normalizes scope", async () => {
    const { read } = show();
    await action();
    const trigger = screen.getByRole("button", { name: "Tất cả trường" });
    fireEvent.click(trigger);
    const picker = await screen.findByRole("dialog", {
      name: "Trường / điểm giao",
    });
    fireEvent.click(
      within(picker).getByRole("checkbox", {
        name: reviewSchools[0]!.school_name,
      }),
    );
    fireEvent.click(
      within(picker).getByRole("button", { name: "Đóng bộ chọn trường" }),
    );
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(read).toHaveBeenCalledTimes(1);
    fireEvent.click(trigger);
    const next = await screen.findByRole("dialog", {
      name: "Trường / điểm giao",
    });
    expect(
      within(next).getByRole("checkbox", {
        name: reviewSchools[0]!.school_name,
      }),
    ).toBeChecked();
    fireEvent.click(within(next).getByRole("button", { name: "Chọn tất cả" }));
    fireEvent.click(within(next).getByRole("button", { name: "Áp dụng" }));
    expect(read).toHaveBeenCalledTimes(1);
    expect(trigger).toHaveFocus();
  });
  it.each([
    ["rebalance", "Cần cập nhật"],
    ["needs_reallocation", "Cần phân bổ lại"],
    ["blocked", "Bị chặn"],
    ["manual_split", "Đã đủ"],
  ] as const)("shows the %s operator state", async (scenario, label) => {
    show(scenario);
    await action();
    expect(within(screen.getByRole("table")).getByText(label)).toBeVisible();
  });
  it("keeps preparation dominant only when ready and no detail is active", async () => {
    show("ready");
    const trigger = await action();
    expect(
      screen.getByRole("button", { name: "Tiếp tục lên đơn" }),
    ).toBeEnabled();
    fireEvent.click(trigger);
    expect(
      screen.queryByRole("button", { name: "Tiếp tục lên đơn" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Đóng" }));
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục lên đơn" }));
    await waitFor(() =>
      expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
        "Đơn mua",
      ),
    );
  });
  it("unknown Save shows labeled recovery and disables routine refresh and mutation", async () => {
    const { save } = show("unknown");
    fireEvent.click(await action());
    fireEvent.click(screen.getByRole("button", { name: "Dùng đề xuất" }));
    fireEvent.click(screen.getByRole("button", { name: "Lưu phân bổ" }));
    expect(
      await screen.findByRole("button", { name: "Tải lại để xác nhận" }),
    ).toBeEnabled();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toBeDisabled();
    expect(save).toHaveBeenCalledTimes(1);
  });
});
