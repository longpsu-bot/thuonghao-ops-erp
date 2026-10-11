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
import { userEvent } from "storybook/test";
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
function show(scenario: SchoolPxkScenario = "READY", expandedFilters = true) {
  const api = createSchoolPxkReviewFixture(scenario);
  const read = vi.spyOn(api, "getWorkbench");
  const write = vi.spyOn(api, "releaseDocument");
  const xlsx = vi.fn();
  const pdf = vi.fn();
  const groupedXlsx = vi.fn();
  const zip = vi.fn();
  render(
    <AtlasVNextProvider>
      <SchoolPxkWorkbench
        api={api}
        authSubject="operator"
        initialServiceDate={reviewDate}
        onExportXlsx={xlsx}
        onExportPdf={pdf}
        onExportGroupedXlsx={groupedXlsx}
        onExportZip={zip}
      />
    </AtlasVNextProvider>,
  );
  if (expandedFilters) {
    const filters = screen.queryByRole("button", { name: "Bộ lọc" });
    if (filters) fireEvent.click(filters);
  }
  return { api, read, write, xlsx, pdf, groupedXlsx, zip };
}
async function open(label = "Phát hành") {
  const button = await screen.findByRole("button", { name: label });
  fireEvent.click(button);
  return button;
}
describe("School PXK operator table and attached detail", () => {
  it("retains the selected loaded document and export after an invalid range edit", async () => {
    const h = show("CURRENT");
    await open("Xem phiếu");
    fireEvent.click(
      screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
    );
    const rangeGrid = await screen.findByRole("grid");
    for (const date of ["2026-09-17", "2026-09-24"])
      fireEvent.click(
        rangeGrid.querySelector<HTMLElement>(
          `[data-part="table-cell-trigger"][data-value="${date}"]`,
        )!,
      );
    expect(await screen.findByText("Chọn tối đa 7 ngày.")).toBeVisible();
    expect(h.read).toHaveBeenCalledTimes(1);
    expect(
      screen.getByRole("region", { name: "Nội dung phiếu" }),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Xuất Excel" }));
    expect(h.xlsx.mock.lastCall![0].service_date).toBe(reviewDate);
    fireEvent.click(
      screen.getByRole("button", { name: "Xuất ZIP · phạm vi đã tải" }),
    );
    expect(
      h.zip.mock.lastCall![0].every(
        (document: { service_date: string }) =>
          document.service_date === reviewDate,
      ),
    ).toBe(true);
  });
  it("packages unique loaded history with the selected date/entity mode", async () => {
    const h = show("HISTORY_WITH_SUPERSEDED");
    const button = screen.getByRole("button", {
      name: "Xuất ZIP · phạm vi đã tải",
    });
    await waitFor(() => expect(button).toBeEnabled());
    fireEvent.change(
      screen.getByRole("combobox", { name: "Nhóm file xuất kho" }),
      { target: { value: "entity" } },
    );
    fireEvent.click(button);
    expect(h.zip).toHaveBeenCalledOnce();
    const [documents, mode] = h.zip.mock.calls[0]!;
    expect(mode).toBe("entity");
    expect(documents).toHaveLength(2);
    expect(
      new Set(
        documents.map(
          (d: { school_dispatch_release_id: string }) =>
            d.school_dispatch_release_id,
        ),
      ).size,
    ).toBe(2);
    expect(h.write).not.toHaveBeenCalled();
  });
  it("blocks loaded exports for denied rows and an unsaved release note", async () => {
    const row = pxkRow("REPLACEMENT_REQUIRED");
    row.allowed_actions.export = false;
    const api = createSchoolPxkReviewFixture("REPLACEMENT_REQUIRED");
    vi.spyOn(api, "getWorkbench").mockResolvedValue(pxkSuccess(pxkData([row])));
    const zip = vi.fn();
    render(
      <AtlasVNextProvider>
        <SchoolPxkWorkbench
          api={api}
          authSubject="operator"
          initialServiceDate={reviewDate}
          onExportZip={zip}
        />
      </AtlasVNextProvider>,
    );
    await open("Tạo phiếu thay thế");
    const button = screen.getByRole("button", {
      name: "Xuất ZIP · phạm vi đã tải",
    });
    expect(button).toBeDisabled();
    cleanup();
    const h = show("REPLACEMENT_REQUIRED");
    await open("Tạo phiếu thay thế");
    const dirtyButton = screen.getByRole("button", {
      name: "Xuất ZIP · phạm vi đã tải",
    });
    expect(dirtyButton).toBeEnabled();
    fireEvent.change(screen.getByRole("textbox", { name: /Ghi chú/ }), {
      target: { value: "Chưa lưu" },
    });
    expect(dirtyButton).toBeDisabled();
    expect(zip).not.toHaveBeenCalled();
    expect(h.zip).not.toHaveBeenCalled();
  });
  it("keeps compact search immediate and discloses the exact date, School and state filters", async () => {
    show("READY", false);
    await open();
    const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
    expect(disclosure).toHaveAttribute("aria-expanded", "false");
    expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBeEnabled();
    expect(
      screen.queryByRole("combobox", { name: "Tình trạng" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText("Ngày 24/09/2026 · Tất cả trường · Tình trạng: Tất cả"),
    ).toBeVisible();
    fireEvent.click(disclosure);
    const state = screen.getByRole("combobox", { name: "Tình trạng" });
    fireEvent.change(state, { target: { value: "BLOCKED" } });
    fireEvent.click(disclosure);
    expect(screen.getByText(/Tình trạng: Bị chặn/)).toBeVisible();
    expect(disclosure).toHaveAttribute("aria-expanded", "false");
  });
  it("names keyboard table scrolling and describes row action identity without changing the action", async () => {
    show();
    const action = await open();
    expect(action).toHaveAccessibleDescription(
      /Trường Tiểu học Nguyễn Du.*Bếp chính/,
    );
    const viewport = screen.getByRole("region", {
      name: "Bảng phiếu xuất kho theo trường",
    });
    expect(viewport).toHaveAttribute("tabindex", "0");
    expect(viewport).toContainElement(
      screen.getByRole("table", { name: "Phiếu xuất kho theo trường" }),
    );
    const lines = screen.getByRole("region", { name: "Bảng Nội dung dự kiến" });
    expect(lines).toHaveAttribute("tabindex", "0");
    expect(lines).toContainElement(
      screen.getByRole("table", { name: "Nội dung dự kiến" }),
    );
  });
  it("reports local note edits without treating untouched selection as unsaved", async () => {
    const report = vi.fn();
    render(
      <AtlasVNextProvider>
        <SchoolPxkWorkbench
          api={createSchoolPxkReviewFixture("READY")}
          authSubject="operator"
          initialServiceDate={reviewDate}
          onWorkspaceStatus={report}
        />
      </AtlasVNextProvider>,
    );
    await open();
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    );
    const note = screen.getByRole("textbox", { name: "Ghi chú trên phiếu" });
    fireEvent.change(note, { target: { value: "Giao trước 5h" } });
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true }),
    );
    fireEvent.change(note, { target: { value: "  " } });
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false }),
    );
  });
  it.each([false, true])(
    "Cancel restores the displayed range as well as the dirty note context (quick: %s)",
    async (quick) => {
      const h = show();
      await open();
      fireEvent.change(
        screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
        { target: { value: "Giữ ngày" } },
      );
      fireEvent.click(
        screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
      );
      const rangeGrid = await screen.findByRole("grid");
      for (const date of ["2026-09-24", "2026-09-25"])
        fireEvent.click(
          rangeGrid.querySelector<HTMLElement>(
            `[data-part="table-cell-trigger"][data-value="${date}"]`,
          )!,
        );
      const dialog = await screen.findByRole("dialog", {
        name: "Có ghi chú chưa phát hành. Bỏ ghi chú và tiếp tục?",
      });
      const cancel = within(dialog).getByRole("button", {
        name: "Tiếp tục chỉnh sửa",
      });
      if (quick) fireEvent.click(cancel);
      else {
        await waitFor(() =>
          expect(dialog.contains(document.activeElement)).toBe(true),
        );
        await userEvent.click(cancel);
      }
      await waitFor(() =>
        expect(
          screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
        ).toHaveTextContent("24/09/2026 — 24/09/2026"),
      );
      expect(
        screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
      ).toHaveValue("Giữ ngày");
      await waitFor(() =>
        expect(
          screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
        ).toHaveFocus(),
      );
      fireEvent.click(
        screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
      );
      const restoredGrid = await screen.findByRole("grid");
      for (const edge of ["start", "end"])
        expect(
          restoredGrid.querySelector(
            `[data-part="table-cell-trigger"][data-range-${edge}]`,
          ),
        ).toHaveAttribute("data-value", "2026-09-24");
      expect(h.read).toHaveBeenCalledTimes(1);
    },
  );
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
        screen.queryByRole("button", { name: "Xuất Excel" }),
      ).not.toBeInTheDocument(),
    );
    expect(
      screen.queryByRole("button", { name: "Xuất PDF" }),
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
    await waitFor(() => expect(dialog).toHaveAttribute("data-state", "closed"));
    expect(note).toHaveValue("Chưa phát hành");
    expect(h.read).toHaveBeenCalledTimes(1);
    fireEvent.click(
      await screen.findByRole("button", { name: "Làm mới dữ liệu" }),
    );
    fireEvent.click(await screen.findByRole("button", { name: "Bỏ ghi chú" }));
    await waitFor(() => expect(h.read).toHaveBeenCalledTimes(2));
    expect(note).toHaveValue("");
    expect(confirm).not.toHaveBeenCalled();
  });
  it("READY preview cannot export; confirmed success exposes exact immutable callbacks", async () => {
    const h = show();
    await open();
    expect(
      screen.queryByRole("button", { name: "Xuất Excel" }),
    ).not.toBeInTheDocument();
    fireEvent.change(
      screen.getByRole("textbox", { name: "Ghi chú trên phiếu" }),
      { target: { value: " Cổng phụ " } },
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Phát hành phiếu xuất kho" }),
    );
    await screen.findByText("Đã xác nhận phiếu xuất kho chính thức.");
    fireEvent.click(screen.getByRole("button", { name: "Xuất Excel" }));
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Xuất PDF" })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xuất PDF" }));
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
    fireEvent.click(screen.getByRole("button", { name: "Xuất Excel" }));
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
    fireEvent.click(
      within(disclosure).getByRole("button", { name: "Xuất PDF" }),
    );
    expect(h.pdf.mock.calls[0]![0]).toMatchObject({
      status: "SUPERSEDED",
      document_number: "PXK-20260924-0000",
    });
    expect(h.write).not.toHaveBeenCalled();
  });
  it("groups every unique export-ready released snapshot in operational order", async () => {
    const h = show("HISTORY_WITH_SUPERSEDED");
    fireEvent.click(
      await screen.findByRole("button", {
        name: "Xuất Excel · phạm vi đã tải",
      }),
    );
    await waitFor(() => expect(h.groupedXlsx).toHaveBeenCalledOnce());
    expect(h.groupedXlsx.mock.calls[0]![0]).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          document_number: "PXK-20260924-0000",
          status: "SUPERSEDED",
        }),
        expect.objectContaining({ status: "RELEASED" }),
      ]),
    );
  });
  it("empty scope shows a useful quiet message", async () => {
    show("EMPTY");
    expect(
      await screen.findByText("Không có phiếu xuất kho trong phạm vi đã chọn."),
    ).toBeInTheDocument();
  });
});
