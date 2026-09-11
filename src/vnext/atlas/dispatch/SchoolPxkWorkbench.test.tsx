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
import { SchoolPxkWorkbench } from "./SchoolPxkWorkbench";
import {
  createSchoolPxkReviewFixture,
  pxkData,
  pxkRow,
  pxkSuccess,
  reviewDate,
  type SchoolPxkScenario,
} from "./schoolPxkReviewFixtures";
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
function show(scenario: SchoolPxkScenario = "READY") {
  const api = createSchoolPxkReviewFixture(scenario);
  const read = vi.spyOn(api, "getWorkbench");
  const write = vi.spyOn(api, "releaseDocument");
  const xlsx = vi.fn();
  const pdf = vi.fn();
  render(
    <AtlasVNextProvider>
      <SchoolPxkWorkbench
        api={api}
        authSubject="operator"
        initialServiceDate={reviewDate}
        onExportXlsx={xlsx}
        onExportPdf={pdf}
      />
    </AtlasVNextProvider>,
  );
  return { api, read, write, xlsx, pdf };
}
async function open(label = "Phát hành") {
  const button = await screen.findByRole("button", { name: label });
  fireEvent.click(button);
  return button;
}
describe("School PXK operator table and attached detail", () => {
  it("Cancel restores the displayed date segments as well as the dirty note context", async () => {
    const h = show();
    await open();
    fireEvent.change(
      screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
      { target: { value: "Giữ ngày" } },
    );
    fireEvent.focus(screen.getByRole("spinbutton", { name: "Day" }));
    fireEvent.keyDown(screen.getByRole("spinbutton", { name: "Day" }), {
      key: "ArrowUp",
    });
    const dialog = await screen.findByRole("dialog");
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() =>
      expect(screen.getByRole("spinbutton", { name: "Day" })).toHaveAttribute(
        "aria-valuenow",
        "24",
      ),
    );
    expect(
      screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
    ).toHaveValue("Giữ ngày");
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it("presents filters in operational order", async () => {
    show();
    await open();
    expect(
      within(screen.getByRole("combobox", { name: "Tình trạng" }))
        .getAllByRole("option")
        .map((o) => o.textContent),
    ).toEqual([
      "Tất cả",
      "Cần phát hành",
      "Cần thay thế",
      "Bị chặn",
      "Đã phát hành",
    ]);
  });
  it("an official document without export readiness has no export utilities", async () => {
    const h = show("CURRENT");
    await open("Xem phiếu");
    const row = pxkRow("CURRENT");
    row.current_release!.export_ready = false;
    h.read.mockResolvedValueOnce(pxkSuccess(pxkData([row])));
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    await waitFor(() =>
      expect(
        screen.queryByRole("button", { name: "XLSX" }),
      ).not.toBeInTheDocument(),
    );
    expect(
      screen.queryByRole("button", { name: "PDF" }),
    ).not.toBeInTheDocument();
  });
  it("has one h1, quiet summary, explicit actions, readable quantities before release and selected rail", async () => {
    show();
    const trigger = await open();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Phiếu xuất kho",
    );
    expect(
      screen.getByText(/Cần phát hành 1 · Cần thay thế 0/),
    ).toBeInTheDocument();
    const row = trigger.closest("tr")!;
    expect(row).toHaveAttribute("aria-selected", "true");
    expect(getComputedStyle(row.cells[0]!).position).toBe("relative");
    const detail = screen.getByRole("region", { name: "Nội dung phiếu" });
    expect(
      within(detail).getByRole("columnheader", { name: "Số lượng" }),
    ).toBeInTheDocument();
    expect(within(detail).getAllByText("kg")).toHaveLength(3);
    expect(within(detail).getByText("48,5")).toBeInTheDocument();
    expect(within(detail).getByText("25,75")).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(
      /source-new|release-1|expected_version|fingerprint|ingredient-0|Save draft|Validate PXK/,
    );
    await waitFor(() => expect(detail).toHaveFocus());
    fireEvent.click(
      within(detail).getByRole("button", { name: "Đóng chi tiết" }),
    );
    await waitFor(() => expect(trigger).toHaveFocus());
  });
  it("orders non-current work before CURRENT with all explicit action labels", async () => {
    show("MULTIPLE_SCHOOLS");
    await screen.findAllByRole("button", { name: "Xem phiếu" });
    const rows = within(
      screen.getByRole("table", { name: "Phiếu xuất kho theo trường" }),
    )
      .getAllByRole("row")
      .slice(1);
    expect(rows[0]).toHaveTextContent("Cần thay thế");
    expect(rows.at(-1)).toHaveTextContent("Đã phát hành");
    for (const label of [
      "Tạo phiếu thay thế",
      "Xem lỗi",
      "Phát hành",
      "Xem phiếu",
    ])
      expect(
        screen.getAllByRole("button", { name: label }).length,
      ).toBeGreaterThan(0);
  });
  it("School checkbox drafts do not read; Apply reads exactly once and retains full picker", async () => {
    const h = show("MULTIPLE_SCHOOLS");
    await screen.findAllByRole("button", { name: "Phát hành" });
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    fireEvent.click(
      screen.getByRole("checkbox", { name: "Trường Mầm non Hoa Sen" }),
    );
    expect(h.read).toHaveBeenCalledTimes(1);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Áp dụng" })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    expect(h.read.mock.calls[1]![0].payload).toMatchObject({
      school_ids: ["school-2"],
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Trường Mầm non Hoa Sen" }),
    );
    expect(await screen.findAllByRole("checkbox")).toHaveLength(18);
  });
  it("local filters keep a dirty note and do not read", async () => {
    const h = show();
    await open();
    fireEvent.change(
      screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
      { target: { value: "Cổng phụ" } },
    );
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm kiếm" }), {
      target: { value: "khong khop" },
    });
    fireEvent.change(screen.getByRole("combobox", { name: "Tình trạng" }), {
      target: { value: "CURRENT" },
    });
    expect(
      screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
    ).toHaveValue("Cổng phụ");
    expect(h.read).toHaveBeenCalledTimes(1);
  });
  it("dirty Dialog preserves exact context on cancel and discards before refresh", async () => {
    const confirm = vi.spyOn(window, "confirm");
    const h = show();
    await open();
    const note = screen.getByRole("textbox", { name: "Ghi chú trên phiếu" });
    fireEvent.change(note, { target: { value: "Chưa phát hành" } });
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    const dialog = await screen.findByRole("dialog");
    expect(dialog).toHaveTextContent(
      "Có ghi chú chưa phát hành. Bỏ ghi chú và tiếp tục?",
    );
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    expect(note).toHaveValue("Chưa phát hành");
    expect(h.read).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    fireEvent.click(await screen.findByRole("button", { name: "Bỏ ghi chú" }));
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    expect(note).toHaveValue("");
    expect(confirm).not.toHaveBeenCalled();
  });
  it("READY preview cannot export; confirmed success exposes exact immutable callbacks", async () => {
    const h = show();
    await open();
    expect(
      screen.queryByRole("button", { name: "XLSX" }),
    ).not.toBeInTheDocument();
    fireEvent.change(
      screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
      { target: { value: " Cổng phụ " } },
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
    );
    await screen.findByText("Đã xác nhận phiếu xuất kho chính thức.");
    fireEvent.click(screen.getByRole("button", { name: "XLSX" }));
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "PDF" })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "PDF" }));
    const readback = await h.read.mock.results[1]!.value;
    const document = (
      readback as ReturnType<typeof pxkSuccess> & {
        response: ReturnType<typeof pxkData>;
      }
    ).response.rows[0]!.current_release;
    expect(h.xlsx).toHaveBeenCalledWith(document);
    expect(h.pdf).toHaveBeenCalledWith(document);
    expect(document!.note).toBe("Cổng phụ");
    expect(h.write).toHaveBeenCalledTimes(1);
    expect(
      screen.queryByRole("button", { name: "Phát hành phiếu xuất kho" }),
    ).not.toBeInTheDocument();
  });
  it("CURRENT uses official lines rather than a changed preview", async () => {
    const h = show("CURRENT");
    await open("Xem phiếu");
    const row = pxkRow("CURRENT");
    row.preview.lines = [{ ...row.preview.lines[0]!, quantity: "999.000000" }];
    h.read.mockResolvedValueOnce(pxkSuccess(pxkData([row])));
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    expect(screen.queryByText("999")).not.toBeInTheDocument();
    expect(screen.getByText("100")).toBeInTheDocument();
  });
  it("replacement shows old official contents/export and target before explicit successor", async () => {
    const h = show("REPLACEMENT_REQUIRED");
    await open("Tạo phiếu thay thế");
    expect(
      screen.getByText(
        "Nội dung nguồn đã thay đổi. Cần phát hành phiếu thay thế.",
      ),
    ).toBeInTheDocument();
    expect(screen.getByText("90")).toBeInTheDocument();
    expect(screen.getByText("100")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "XLSX" }));
    expect(h.xlsx.mock.calls[0]![0]).toMatchObject({
      school_dispatch_release_id: "release-1",
      source_fingerprint: "source-old-1",
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Phát hành phiếu thay thế" }),
    );
    await screen.findByText("Đã xác nhận phiếu xuất kho chính thức.");
    fireEvent.click(screen.getByText("Lịch sử phiếu"));
    expect(screen.getByText(/Đã được thay thế/)).toBeInTheDocument();
  });
  it("BLOCKED cancellation is safe and offers no release command", async () => {
    show("BLOCKED");
    await open("Xem lỗi");
    expect(screen.getByText(/Atlas không tự hủy đơn mua/)).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /Phát hành phiếu/ }),
    ).not.toBeInTheDocument();
    expect(document.body.textContent).not.toContain("CANCELLATION_REQUIRED");
  });
  it.each(["UNKNOWN_RELEASE", "SUCCESS_THEN_READBACK_FAILURE"] as const)(
    "%s locks writes and exposes confirmation reload",
    async (scenario) => {
      show(scenario);
      await open();
      fireEvent.click(
        screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
      );
      await screen.findByText("Kết quả phát hành chưa được xác nhận.");
      expect(
        screen.getByRole("button", { name: "Tải lại để xác nhận" }),
      ).toBeInTheDocument();
      expect(
        screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
      ).toBeDisabled();
    },
  );
  it.each(["STALE", "SOURCE_CHANGED"] as const)(
    "%s uses current-data recovery",
    async (scenario) => {
      show(scenario);
      await open();
      fireEvent.click(
        screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
      );
      expect(
        await screen.findByRole("button", { name: "Tải lại dữ liệu hiện tại" }),
      ).toBeInTheDocument();
      expect(
        screen.queryByText(scenario, { exact: true }),
      ).not.toBeInTheDocument();
    },
  );
  it.each(["READ_FAILURE", "PERMISSION_DENIED"] as const)(
    "%s is ordinary read failure",
    async (scenario) => {
      show(scenario);
      expect(
        await screen.findByRole("button", { name: "Thử tải lại dữ liệu" }),
      ).toBeInTheDocument();
      expect(
        screen.queryByRole("button", { name: "Tải lại để xác nhận" }),
      ).not.toBeInTheDocument();
      expect(document.body.textContent).not.toContain("CAPABILITY_DENIED");
    },
  );
  it("history is collapsed, immutable superseded contents remain readable and exportable", async () => {
    const h = show("HISTORY_WITH_SUPERSEDED");
    await open("Xem phiếu");
    const disclosure = screen.getByText("Lịch sử phiếu").closest("details")!;
    expect(disclosure.open).toBe(false);
    fireEvent.click(screen.getByText("Lịch sử phiếu"));
    fireEvent.click(within(disclosure).getByRole("button", { name: "PDF" }));
    expect(h.pdf.mock.calls[0]![0]).toMatchObject({
      status: "SUPERSEDED",
      document_number: "PXK-20260924-0000",
    });
    expect(h.write).not.toHaveBeenCalled();
  });
  it("empty scope shows a useful quiet message", async () => {
    show("EMPTY");
    expect(
      await screen.findByText("Không có phiếu xuất kho trong phạm vi đã chọn."),
    ).toBeInTheDocument();
  });
});
