import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  act,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { userEvent } from "storybook/test";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider, AtlasWorkbenchScope } from "../AtlasVNextProvider";
import type { PantryApi } from "../bridges/planning";
import { PlanningSourcesWorkbench } from "./PlanningSourcesWorkbench";
import { createPlanningStoryFixture } from "./planningStoryFixtures";
import {
  menuPreview,
  attendancePreview,
  pantryPreview,
  success,
  unknown,
  stale,
} from "./planningReviewFixtures";
import {
  createPlanningReviewFixture,
  reviewWeek,
} from "./planningReviewFixtures";
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
async function show(schoolCount?: number) {
  const fixture = createPlanningReviewFixture();
  if (schoolCount) {
    fixture.planning.schools = fixture.planning.schools.slice(0, schoolCount);
    fixture.pantry.schools = fixture.pantry.schools.slice(0, schoolCount);
  }
  const read = vi.spyOn(fixture.api, "getWorkbench");
  render(
    <AtlasVNextProvider>
      <PlanningSourcesWorkbench
        {...fixture}
        authSubject="operator"
        initialWeek={reviewWeek}
      />
    </AtlasVNextProvider>,
  );
  await screen.findByRole("table", { name: "Thực đơn theo trường" });
  return { fixture, read };
}
function openFilters() {
  const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
  if (disclosure.getAttribute("aria-expanded") === "false")
    fireEvent.click(disclosure);
}
describe("Planning sources Chakra workbench", () => {
  it("groups Attendance warnings in Vietnamese while retaining every source reference and unknown detail", async () => {
    const { fixture } = await show();
    const preview = attendancePreview();
    preview.issues.warnings = [
      {
        code: "PORTIONS_DIFFER_FROM_DEFAULT",
        message: "Attendance differs from the current school defaults.",
        source_row_reference: "paste:row:2",
      },
      {
        code: "PORTIONS_DIFFER_FROM_DEFAULT",
        message: "Attendance differs from the current school defaults.",
        source_row_reference: "paste:row:3",
      },
      {
        code: "ZERO_TOTAL_PORTIONS",
        message:
          "Student and teacher portions total zero for this school and date.",
        source_row_reference: "paste:row:4",
      },
      {
        code: "FUTURE_ATTENDANCE_WARNING",
        message: "A new warning from the source.",
        source_row_reference: null,
      },
    ];
    fixture.api.previewAttendance = async () => success({ preview });
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    fireEvent.change(
      await screen.findByRole("textbox", { name: "Học sinh Trường Nguyễn Du" }),
      { target: { value: "101" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = await screen.findByRole("complementary", {
      name: "Xem thay đổi",
    });
    const warnings = within(review).getByRole("group", {
      name: "Cảnh báo sĩ số",
    });
    expect(
      within(warnings).getByText(
        /Số suất khác mặc định hiện tại của trường.*2 cảnh báo/,
      ),
    ).toBeVisible();
    const details = warnings.querySelectorAll("details");
    expect(details).toHaveLength(3);
    details.forEach((detail) =>
      fireEvent.click(detail.querySelector("summary")!),
    );
    for (const reference of ["paste:row:2", "paste:row:3", "paste:row:4"])
      expect(
        within(warnings).getByText(reference, { exact: false }),
      ).toBeInTheDocument();
    expect(
      within(warnings).getByText(/FUTURE_ATTENDANCE_WARNING/),
    ).toBeInTheDocument();
    expect(
      within(warnings).getByText(/A new warning from the source/),
    ).toBeInTheDocument();
    expect(
      within(warnings).getByText(/Chưa có vị trí nguồn/),
    ).toBeInTheDocument();
    expect(within(review).getByRole("button", { name: "Lưu" })).toBeEnabled();
  });
  it("retains an unknown Attendance blocker's original diagnostic", async () => {
    const { fixture } = await show();
    const preview = attendancePreview();
    preview.issues.blockers = [
      {
        code: "FUTURE_ATTENDANCE_BLOCKER",
        message: "Specific source diagnosis for support.",
        source_row_reference: "paste:row:2",
      },
    ];
    fixture.api.previewAttendance = async () => success({ preview });
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    fireEvent.change(
      await screen.findByRole("textbox", { name: "Học sinh Trường Nguyễn Du" }),
      { target: { value: "101" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = await screen.findByRole("complementary", {
      name: "Xem thay đổi",
    });
    expect(within(review).getByRole("alert")).toHaveTextContent(
      "Specific source diagnosis for support.",
    );
  });
  it("reuses canonical School order across Menu and Attendance without changing row edit identity", async () => {
    const fixture = createPlanningReviewFixture();
    const schools = fixture.planning.schools.slice(0, 3);
    schools[0] = { ...schools[0], school_name: "Vĩnh Tân", display_order: 0 };
    schools[1] = { ...schools[1], school_name: "Bình Quới", display_order: 1 };
    schools[2] = { ...schools[2], school_name: "An Bình", display_order: 1 };
    fixture.planning.schools = [schools[1], schools[0], schools[2]];
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
        />
      </AtlasVNextProvider>,
    );
    const table = await screen.findByRole("table", {
      name: "Thực đơn theo trường",
    });
    const schoolCells = () =>
      within(table)
        .getAllByRole("row")
        .slice(1)
        .map((row) => within(row).getAllByRole("cell")[0].textContent);
    expect(schoolCells()).toEqual(["Vĩnh Tân", "An Bình", "Bình Quới"]);
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    const attendance = await screen.findByRole("table", {
      name: "Sĩ số theo trường",
    });
    const rows = within(attendance).getAllByRole("row").slice(1);
    expect(
      rows.map((row) => within(row).getAllByRole("cell")[0].textContent),
    ).toEqual(["Vĩnh Tân", "An Bình", "Bình Quới"]);
    fireEvent.change(within(rows[1]).getAllByRole("textbox")[0], {
      target: { value: "321" },
    });
    expect(within(rows[1]).getAllByRole("textbox")[0]).toHaveValue("321");
    expect(within(rows[2]).getAllByRole("textbox")[0]).toHaveValue("100");
  });
  it("explains missing Pantry purposes in Vietnamese", async () => {
    const fixture = createPlanningReviewFixture();
    fixture.pantry.catalog_issues.blockers = [
      {
        code: "PURPOSE_CATALOG_EMPTY",
        message: "No active Pantry Purpose is configured.",
        field: "pantry_need_purpose_id",
        source_row_reference: null,
      },
    ];
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          ownerJob="pantry"
        />
      </AtlasVNextProvider>,
    );
    expect(
      await screen.findByText(
        "Chưa có phân loại nhập trực tiếp. Liên hệ người quản lý danh mục.",
      ),
    ).toBeVisible();
    expect(
      screen.queryByText("No active Pantry Purpose is configured."),
    ).not.toBeInTheDocument();
  });
  it("distinguishes filtered-out planning rows from explicit zero attendance or no additions", async () => {
    await show();
    fireEvent.change(
      screen.getByRole("textbox", { name: "Tìm trong công việc" }),
      {
        target: { value: "Không có trường phù hợp" },
      },
    );
    expect(screen.getByText("Không có trường phù hợp bộ lọc.")).toBeVisible();
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    await screen.findByRole("table", { name: "Sĩ số theo trường" });
    fireEvent.change(
      screen.getByRole("textbox", { name: "Tìm trong công việc" }),
      {
        target: { value: "Không có trường phù hợp" },
      },
    );
    expect(
      screen.getByText("Không có sĩ số phù hợp bộ lọc trong ngày."),
    ).toBeVisible();
    expect(
      screen.queryByText("Học sinh 0 · Giáo viên 0 · Tổng 0"),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Hàng đặt riêng" }));
    await screen.findByRole("table", { name: "Hàng đặt riêng" });
    fireEvent.change(
      screen.getByRole("textbox", { name: "Tìm trong công việc" }),
      {
        target: { value: "Không có trường phù hợp" },
      },
    );
    expect(screen.getByText("Không có trường phù hợp bộ lọc.")).toBeVisible();
    expect(
      screen.queryByText(
        "Không có bổ sung hoặc hàng đặt riêng trong ngày này.",
      ),
    ).not.toBeInTheDocument();
  });
  it("downloads the scoped blank attendance template without previewing or saving attendance", async () => {
    const fixture = createPlanningReviewFixture();
    const preview = vi.spyOn(fixture.api, "previewAttendance");
    const save = vi.spyOn(fixture.api, "saveCompletedAttendance");
    const exportTemplate = vi.fn().mockResolvedValue(undefined);
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          onExportAttendanceTemplate={exportTemplate}
        />
      </AtlasVNextProvider>,
    );
    await screen.findByRole("table", { name: "Thực đơn theo trường" });
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "Tải mẫu sĩ số XLSX" }),
    );
    await screen.findByText(
      "Đã tải mẫu nhập. Sĩ số chỉ được ghi nhận sau khi rà soát và Lưu.",
    );
    expect(exportTemplate).toHaveBeenCalledWith(
      reviewWeek,
      expect.arrayContaining([
        expect.objectContaining({
          school_id: fixture.planning.schools[0]!.school_id,
        }),
      ]),
    );
    expect(preview).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
  });
  it("does not move focus into an inactive source owner when its pending Review finishes", async () => {
    const fixture = createPlanningReviewFixture();
    let finish!: () => void;
    const preview = fixture.api.previewAttendance;
    fixture.api.previewAttendance = (...args) =>
      new Promise((resolve) => {
        finish = () => void preview(...args).then(resolve);
      });
    const view = (active: boolean) => (
      <AtlasVNextProvider>
        <button>Active owner control</button>
        <AtlasWorkbenchScope active={active}>
          <PlanningSourcesWorkbench
            {...fixture}
            authSubject="operator"
            initialWeek={reviewWeek}
            ownerJob="attendance"
          />
        </AtlasWorkbenchScope>
      </AtlasVNextProvider>
    );
    const { rerender } = render(view(true));
    fireEvent.change(
      await screen.findByRole("textbox", { name: "Học sinh Trường Nguyễn Du" }),
      { target: { value: "123" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    rerender(view(false));
    const outside = screen.getByRole("button", {
      name: "Active owner control",
    });
    outside.focus();
    await act(async () => finish());
    await screen.findByRole("complementary", { name: "Xem thay đổi" });
    expect(outside).toHaveFocus();
  });
  it("reports local attendance edits and frozen Review", async () => {
    const fixture = createPlanningReviewFixture();
    const report = vi.fn();
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          onWorkspaceStatus={report}
        />
      </AtlasVNextProvider>,
    );
    await screen.findByRole("table", { name: "Thực đơn theo trường" });
    await waitFor(() =>
      expect(report).toHaveBeenLastCalledWith(
        expect.objectContaining({ unsaved: false, blocked: false }),
      ),
    );
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    fireEvent.change(
      await screen.findByRole("textbox", { name: "Học sinh Trường Nguyễn Du" }),
      { target: { value: "0" } },
    );
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true, blocked: false }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await waitFor(() =>
      expect(report).toHaveBeenLastCalledWith(
        expect.objectContaining({ unsaved: true, blocked: true }),
      ),
    );
  });
  it("groups backend codes in Vietnamese while keeping the Menu table and retry accessible", async () => {
    const { fixture } = await show();
    const preview = menuPreview();
    preview.can_save = false;
    preview.issues.blockers = Array.from({ length: 18 }, (_, index) => ({
      code: index % 2 ? "UNKNOWN_DISH" : "INVALID_DISH_ID",
      message: "A row does not identify a valid dish.",
      source_row_reference: null,
    }));
    fixture.api.previewMenu = async () => success({ preview });
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    fireEvent.click(
      screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    const summary = await screen.findByRole("alert", {
      name: "Không thể đồng bộ thực đơn",
    });
    expect(
      within(summary).getAllByText(/18 lỗi chưa xác định được món ăn/),
    ).toHaveLength(1);
    expect(
      screen.queryByText("A row does not identify a valid dish."),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("table", { name: "Thực đơn theo trường" }),
    ).toBeVisible();
    expect(screen.getByText(/Google Sheets ·/)).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
    ).toBeEnabled();
    expect(
      screen.queryByRole("button", { name: "Xem thay đổi" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Đã đồng bộ thực đơn")).not.toBeInTheDocument();
    expect(save).not.toHaveBeenCalled();
  });
  it.each(["UNKNOWN_DISH", "AMBIGUOUS_DISH"])(
    "shows %s source evidence in bounded details",
    async (code) => {
      const { fixture } = await show();
      const name = "Sâm bổ lượng";
      if (code === "AMBIGUOUS_DISH")
        fixture.planning.dishes.push(
          ...["dup-1", "dup-2"].map((dish_id) => ({
            ...fixture.planning.dishes[0],
            dish_id,
            dish_code: dish_id,
            dish_name: name,
          })),
        );
      fixture.api.syncMenuFromGoogle = async () =>
        success({
          source: { source_name: "Google", sheet_name: "Tuần" },
          rows: [
            ["Tên trường", "Ngày", "Món mặn"],
            ["TH001", reviewWeek, name],
          ],
        });
      fireEvent.click(
        screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
      );
      const summary = await screen.findByRole("alert", {
        name: "Không thể đồng bộ thực đơn",
      });
      fireEvent.click(within(summary).getByText("Xem ô cần kiểm tra"));
      expect(within(summary).getByText(name)).toBeVisible();
      expect(within(summary).getByText("Món mặn · dòng 4")).toBeVisible();
      expect(
        within(summary).getByText(
          code === "UNKNOWN_DISH"
            ? "Không tìm thấy món này trong danh mục Atlas."
            : "Có nhiều món trùng tên; chưa thể xác định món chuẩn.",
        ),
      ).toBeVisible();
    },
  );
  it("shows valid neighbors, marks every rejected source cell, and counts a cell with two causes only once", async () => {
    const { fixture } = await show();
    fixture.api.syncMenuFromGoogle = async () =>
      success({
        source: { source_name: "Google", sheet_name: "Tuần" },
        rows: [
          ["Tên trường", "Ngày", "Món mặn", "Món canh"],
          ["TH001", reviewWeek, "Món sai", "CANH2"],
          ["TH001", reviewWeek, "MAN1", "Canh sai"],
          ["Trường lạ", "31/02/2026", "MAN1", ""],
          ["TH002", reviewWeek, "MAN1", "CANH2"],
        ],
      });
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    const preview = vi.spyOn(fixture.api, "previewMenu");
    fireEvent.click(
      screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    const alert = await screen.findByRole("alert", {
      name: "Không thể đồng bộ thực đơn",
    });
    expect(
      within(alert).getByText("3 ô cần xử lý trước khi lưu."),
    ).toBeVisible();
    expect(
      screen.getByText(
        "Bản đồng bộ chưa lưu · Sửa ô lỗi trong Google Sheet rồi đồng bộ lại.",
      ),
    ).toBeVisible();
    const table = screen.getByRole("table", { name: "Thực đơn theo trường" });
    const firstSchool = within(table).getByRole("row", {
      name: /Trường Nguyễn Du/,
    });
    expect(within(firstSchool).getByText("Canh rau ngót")).toBeVisible();
    expect(within(firstSchool).getByText("Thịt kho")).toBeVisible();
    const rejected = within(firstSchool)
      .getAllByRole("cell")
      .filter((cell) => cell.getAttribute("data-invalid") === "true");
    expect(rejected).toHaveLength(2);
    expect(
      within(rejected[0]).getByText("Không tìm thấy món “Món sai”"),
    ).toBeVisible();
    expect(
      within(rejected[1]).getByText("Không tìm thấy món “Canh sai”"),
    ).toBeVisible();
    const neighbor = within(table).getByRole("row", { name: /Trường Lê Lợi/ });
    expect(within(neighbor).getByText("Thịt kho")).toBeVisible();
    expect(within(neighbor).getByText("Canh rau ngót")).toBeVisible();
    expect(within(table).queryByText("Trường lạ")).not.toBeInTheDocument();
    fireEvent.click(within(alert).getByText("Xem ô cần kiểm tra"));
    expect(within(alert).getAllByText(/Trường lạ · 31\/02\/2026/)).toHaveLength(
      2,
    );
    expect(within(alert).getByText("Google:Tuần:row:4:main")).toBeVisible();
    expect(within(alert).getByText("Google:Tuần:row:5:soup")).toBeVisible();
    expect(within(alert).getAllByText("Google:Tuần:row:6:main")).toHaveLength(
      2,
    );
    expect(preview).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
  });
  it("places a visible current-job context before source tabs and the ordered workbar", async () => {
    await show();

    const context = screen.getByRole("region", {
      name: "Ngữ cảnh thực đơn",
    });
    expect(context).toHaveStyle({
      minHeight: "var(--atlas-task-context-min-height, 56px)",
    });
    expect(context.parentElement).toHaveStyle({
      gridTemplateRows: "auto minmax(0, 1fr)",
    });
    expect(
      within(context).getByLabelText(
        "Tóm tắt công việc: 07/09/2026 · Tất cả trường",
      ),
    ).toBeInTheDocument();
    const heading = screen.getByRole("heading", {
      level: 1,
      name: "Thực đơn",
    });
    const tabs = screen.getByRole("tablist", { name: "Công việc thực đơn" });
    const workbar = screen.getByRole("group", {
      name: "Phạm vi nguồn lập nhu cầu",
    });
    expect(heading).toBeVisible();
    expect(heading).toHaveAccessibleDescription("Thực đơn");
    expect(context).toContainElement(heading);
    expect(
      heading.compareDocumentPosition(tabs) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      tabs.compareDocumentPosition(workbar) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();

    const week = within(workbar).getByLabelText("Tuần phục vụ");
    const date = within(workbar).getByLabelText("Ngày phục vụ");
    openFilters();
    const scope = within(workbar).getByRole("button", {
      name: "Tất cả trường",
    });
    const search = within(workbar).getByRole("textbox", {
      name: "Tìm trong công việc",
    });
    const refresh = within(workbar).getByRole("button", {
      name: "Làm mới dữ liệu",
    });
    for (const [before, after] of [
      [week, date],
      [date, scope],
      [scope, search],
      [search, refresh],
    ] as const)
      expect(
        before.compareDocumentPosition(after) &
          Node.DOCUMENT_POSITION_FOLLOWING,
      ).toBeTruthy();
  });

  it("keeps search and refresh immediate while mobile filters expose a truthful summary", async () => {
    await show();

    expect(
      screen.getByRole("textbox", { name: "Tìm trong công việc" }),
    ).toBeEnabled();
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toBeEnabled();
    const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
    expect(disclosure).toHaveAttribute("aria-expanded", "false");
    expect(
      document.getElementById(disclosure.getAttribute("aria-controls")!),
    ).toBeInTheDocument();
    expect(
      screen.getByText("Tuần 07/09/2026 – 13/09/2026"),
    ).toBeInTheDocument();

    fireEvent.click(disclosure);
    fireEvent.change(screen.getByRole("combobox", { name: "Ngày phục vụ" }), {
      target: { value: "2026-09-08" },
    });
    fireEvent.click(disclosure);
    expect(
      screen.getByText("Tuần 07/09/2026 – 13/09/2026"),
    ).toBeInTheDocument();
    expect(
      screen.getByLabelText("Tóm tắt công việc: 08/09/2026 · Tất cả trường"),
    ).toBeInTheDocument();
  });

  it("tabs from the expanded 390px filter trigger into revealed controls", async () => {
    Object.defineProperty(window, "innerWidth", {
      configurable: true,
      value: 390,
    });
    await show();

    const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
    screen.getByRole("textbox", { name: "Tìm trong công việc" }).focus();
    await userEvent.tab();
    expect(disclosure).toHaveFocus();
    await userEvent.keyboard("{Enter}");
    expect(disclosure).toHaveAttribute("aria-expanded", "true");

    const filters = document.getElementById(
      disclosure.getAttribute("aria-controls")!,
    );
    expect(filters).toContainElement(document.activeElement as HTMLElement);
    while (filters?.contains(document.activeElement)) await userEvent.tab();
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toHaveFocus();
  });

  it("exits expanded review filters when Refresh is disabled at 390px and reverses to the trigger", async () => {
    Object.defineProperty(window, "innerWidth", {
      configurable: true,
      value: 390,
    });
    await show();
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    fireEvent.change(
      await screen.findByRole("textbox", { name: "Học sinh Trường Nguyễn Du" }),
      { target: { value: "0" } },
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Xem thay đổi" }),
    );
    await screen.findByRole("complementary", { name: "Xem thay đổi" });
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toBeDisabled();

    const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
    fireEvent.click(disclosure);
    const filters = document.getElementById(
      disclosure.getAttribute("aria-controls")!,
    )!;
    filters.querySelector<HTMLElement>("input, select, button")!.focus();
    for (
      let step = 0;
      step < 20 && filters.contains(document.activeElement);
      step += 1
    )
      await userEvent.tab();

    expect(filters).not.toContainElement(document.activeElement as HTMLElement);
    const onward = document.activeElement as HTMLElement;
    expect(
      disclosure.compareDocumentPosition(onward) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    await userEvent.tab({ shift: true });
    expect(disclosure).toHaveFocus();
  });

  it.each(["busy", "locked"] as const)(
    "keeps the 390px onward path reversible when Planning is %s",
    async (state) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: 390,
      });
      const fixture = createPlanningReviewFixture();
      if (state === "busy")
        fixture.api.saveCompletedAttendance = async () =>
          new Promise(() => undefined);
      else fixture.api.saveCompletedAttendance = async () => unknown;
      render(
        <AtlasVNextProvider>
          <PlanningSourcesWorkbench
            {...fixture}
            authSubject="operator"
            initialWeek={reviewWeek}
          />
        </AtlasVNextProvider>,
      );
      fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
      fireEvent.change(
        await screen.findByRole("textbox", {
          name: "Học sinh Trường Nguyễn Du",
        }),
        { target: { value: "0" } },
      );
      fireEvent.click(
        await screen.findByRole("button", { name: "Xem thay đổi" }),
      );
      fireEvent.click(await screen.findByRole("button", { name: "Lưu" }));
      if (state === "locked")
        await screen.findByRole("button", { name: "Tải lại để xác nhận" });
      await waitFor(() =>
        expect(
          screen.getByRole("button", { name: "Làm mới dữ liệu" }),
        ).toBeDisabled(),
      );

      const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
      fireEvent.click(disclosure);
      const filters = document.getElementById(
        disclosure.getAttribute("aria-controls")!,
      )!;
      filters.querySelector<HTMLElement>("input, select, button")!.focus();
      for (
        let step = 0;
        step < 20 && filters.contains(document.activeElement);
        step += 1
      )
        await userEvent.tab();
      expect(filters).not.toContainElement(
        document.activeElement as HTMLElement,
      );
      await userEvent.tab({ shift: true });
      expect(disclosure).toHaveFocus();
    },
  );

  it("renders backend Pantry before/after pairs in the shared comparison table", async () => {
    const fixture = createPlanningStoryFixture("pantry_review");
    const before = fixture.pantry.batch!.active_lines[0];
    fixture.pantryApi.preview = async () =>
      success({
        preview: {
          ...pantryPreview(),
          no_additions_confirmed: false,
          comparison: {
            ...pantryPreview().comparison,
            changed_lines: [
              { before, after: { ...before, requested_quantity: "30" } },
            ],
          },
        },
      });
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          initialJob="pantry"
        />
      </AtlasVNextProvider>,
    );
    fireEvent.change(
      await screen.findByRole("textbox", { name: "Số lượng dòng 1" }),
      { target: { value: "30" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const table = await screen.findByRole("table", {
      name: "So sánh thay đổi",
    });
    expect(within(table).getByText(/25.75/)).toBeVisible();
    expect(within(table).getByText(/30/)).toBeVisible();
    expect(within(table).getByText(/Gạo thơm/)).toBeVisible();
  });
  it("requires a source choice when several Google sources are configured", async () => {
    const fixture = createPlanningReviewFixture();
    fixture.planning.google_sheet_sources.push({
      ...fixture.planning.google_sheet_sources[0],
      weekly_menu_google_source_id: "google-2",
      source_name: "Thực đơn điểm lẻ",
    });
    const sync = vi.spyOn(fixture.api, "syncMenuFromGoogle");
    const preview = vi.spyOn(fixture.api, "previewMenu");
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    expect(sync).not.toHaveBeenCalled();
    fireEvent.click(
      await screen.findByRole("button", { name: "Thực đơn điểm lẻ" }),
    );
    await waitFor(() =>
      expect(sync).toHaveBeenCalledWith(
        "google-2",
        reviewWeek,
        expect.any(String),
      ),
    );
    await waitFor(() => expect(preview).toHaveBeenCalledOnce());
    expect(save).toHaveBeenCalledOnce();
  });
  it("refreshes authoritative sources without fetching Google", async () => {
    const { fixture, read } = await show();
    const sync = vi.spyOn(fixture.api, "syncMenuFromGoogle");
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    await waitFor(() => expect(read).toHaveBeenCalledTimes(2));
    expect(sync).not.toHaveBeenCalled();
  });
  it("renders every active Dish Type in authoritative order and keeps empty columns", async () => {
    await show();
    const table = screen.getByRole("table", {
      name: "Thực đơn theo trường",
    });
    expect(
      within(table)
        .getAllByRole("columnheader")
        .map((cell) => cell.textContent),
    ).toEqual([
      "Trường / điểm giao",
      "Món mặn",
      "Món canh",
      "Món xào",
      "Rau",
      "Tráng miệng",
    ]);
    expect(within(table).queryByText("Loại cũ")).not.toBeInTheDocument();
    const firstSchoolRow = within(table).getAllByRole("row")[1];
    expect(within(firstSchoolRow).getAllByRole("cell")[5]).toHaveTextContent(
      "—",
    );
  });
  it("keeps weekly Menu scrolling local with a sticky School column", async () => {
    await show();
    const table = screen.getByRole("table", {
      name: "Thực đơn theo trường",
    });
    expect(screen.getByTestId("weekly-menu-scroll")).toHaveAttribute(
      "data-horizontal-scroll",
      "local",
    );
    const viewport = screen.getByRole("region", {
      name: "Bảng thực đơn theo trường",
    });
    expect(viewport).toHaveAttribute("tabindex", "0");
    expect(viewport).toContainElement(table);
    expect(table).toHaveStyle({
      minWidth: "var(--atlas-layout-menu-table-width, max-content)",
      width: "100%",
      tableLayout: "fixed",
    });
    const schoolHeader = within(table).getByRole("columnheader", {
      name: "Trường / điểm giao",
    });
    expect(schoolHeader).toHaveAttribute("data-sticky-column", "school");
    expect(getComputedStyle(schoolHeader).zIndex).toBe(
      "var(--atlas-layer-sticky-corner, 3)",
    );
  });
  it("has one h1, exactly three jobs, and local search without backend reads", async () => {
    const { read } = await show();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getAllByRole("tab").map((t) => t.textContent)).toEqual([
      "Thực đơn",
      "Sĩ số",
      "Hàng đặt riêng",
    ]);
    const active = screen.getByRole("tab", { name: "Thực đơn" });
    expect(
      document.getElementById(active.getAttribute("aria-controls")!),
    ).toHaveAttribute("role", "tabpanel");
    fireEvent.change(
      screen.getByRole("textbox", { name: "Tìm trong công việc" }),
      { target: { value: "nguyen du" } },
    );
    expect(within(screen.getByRole("table")).getAllByRole("row")).toHaveLength(
      2,
    );
    expect(read).toHaveBeenCalledTimes(1);
    expect(
      screen.queryByText(/Need Generation|Xác nhận nhu cầu|Purchase Handoff/),
    ).not.toBeInTheDocument();
  });
  it("rejects zero selected schools and leaves committed scope unchanged on close", async () => {
    await show();
    openFilters();
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    expect(screen.getByRole("button", { name: "Áp dụng" })).toBeDisabled();
    fireEvent.click(
      await screen.findByRole("checkbox", { name: "Trường Nguyễn Du" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Đóng bộ chọn trường" }),
    );
    expect(screen.getByRole("button", { name: "Tất cả trường" })).toBeVisible();
  });
  it("commits one school on Apply and normalizes all explicitly selected schools", async () => {
    await show();
    openFilters();
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    fireEvent.click(
      await screen.findByRole("checkbox", { name: "Trường Nguyễn Du" }),
    );
    await waitFor(() =>
      expect(
        screen.getByRole("checkbox", { name: "Trường Nguyễn Du" }),
      ).toBeChecked(),
    );
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Áp dụng" })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(
      await screen.findByRole("button", { name: "Trường Nguyễn Du" }),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("tab", { name: "Hàng đặt riêng" }));
    expect(
      screen.queryByRole("checkbox", {
        name: "Xác nhận cả tuần không có hàng đặt riêng",
      }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Trường Nguyễn Du" }));
    fireEvent.click(await screen.findByRole("button", { name: "Chọn tất cả" }));
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(screen.getByRole("button", { name: "Tất cả trường" })).toBeVisible();
  });
  it("runs Menu sync as one action without Review or Save controls", async () => {
    await show();
    fireEvent.click(
      screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    expect(await screen.findByText(/Đã đồng bộ lúc/)).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Xem thay đổi" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText("Đang chỉnh sửa · chưa lưu"),
    ).not.toBeInTheDocument();
    const notice = await screen.findByRole("status", {
      name: /Đã đồng bộ thực đơn/,
    });
    expect(notice.parentElement).toHaveAttribute("data-atlas-portal-root");
  });
  it("saves the full canonical Menu payload despite School, date, and search filters", async () => {
    const fixture = createPlanningReviewFixture();
    const canonicalRows = [
      menuPreview().canonical_rows[0],
      {
        ...menuPreview().canonical_rows[0],
        school_id: "school-1",
        service_date: "2026-09-08",
        menu_slot_code: "main",
        dish_id: "dish-1",
        source_row_reference: "official:5",
      },
      {
        ...menuPreview().canonical_rows[0],
        school_id: "school-2",
        service_date: "2026-09-09",
        source_row_reference: "official:6",
      },
    ];
    fixture.api.previewMenu = async () =>
      success({
        preview: {
          ...menuPreview(),
          canonical_rows: canonicalRows,
          row_count: canonicalRows.length,
        },
      });
    const save = vi.spyOn(fixture.api, "saveCompletedMenu");
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
        />
      </AtlasVNextProvider>,
    );
    await screen.findByRole("table", { name: "Thực đơn theo trường" });
    openFilters();
    fireEvent.change(screen.getByRole("combobox", { name: "Ngày phục vụ" }), {
      target: { value: "2026-09-08" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    fireEvent.click(
      await screen.findByRole("checkbox", { name: "Trường Nguyễn Du" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    fireEvent.change(
      screen.getByRole("textbox", { name: "Tìm trong công việc" }),
      { target: { value: "nguyen du" } },
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    await waitFor(() => expect(save).toHaveBeenCalledOnce());
    expect(save.mock.calls[0][0].payload.rows).toEqual(canonicalRows);
  });
  it("keeps a downstream Menu blocker inline without reopening Review or Save", async () => {
    const fixture = createPlanningStoryFixture("menu_blocked");
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    const blocker = await screen.findByRole("alert", {
      name: /Chưa thể đồng bộ thực đơn/,
    });
    expect(within(blocker).getByText(/Đã có cam kết mua hàng/)).toBeVisible();
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("complementary", { name: "Xem thay đổi" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Chuẩn bị hiệu chỉnh" }),
    ).not.toBeInTheDocument();
  });
  it("shows editable attendance, explicit zero and totals, with one dirty exit dialog", async () => {
    await show();
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    const input = await screen.findByRole("textbox", {
      name: "Học sinh Trường Nguyễn Du",
    });
    const attendanceTable = screen.getByRole("table", {
      name: "Sĩ số theo trường",
    });
    const attendanceViewport = screen.getByRole("region", {
      name: "Bảng sĩ số theo trường",
    });
    expect(attendanceViewport).toHaveAttribute("tabindex", "0");
    expect(attendanceViewport).toContainElement(attendanceTable);
    expect(attendanceTable).toHaveStyle({
      minWidth: "var(--atlas-layout-zero, 0)",
      width: "100%",
      tableLayout: "fixed",
    });
    const attendanceRow = within(attendanceTable).getByRole("row", {
      name: /Trường Nguyễn Du/,
    });
    expect(
      within(
        attendanceRow.querySelector('[data-attendance-field="student"]')!,
      ).getByText("Học sinh"),
    ).toBeInTheDocument();
    expect(
      within(
        attendanceRow.querySelector('[data-attendance-field="teacher"]')!,
      ).getByText("Giáo viên"),
    ).toBeInTheDocument();
    expect(
      within(
        attendanceRow.querySelector('[data-attendance-field="total"]')!,
      ).getByText("Tổng"),
    ).toBeInTheDocument();
    fireEvent.change(input, { target: { value: "0" } });
    expect(input).toHaveValue("0");
    expect(screen.getByText("Đang chỉnh sửa · chưa lưu")).toBeVisible();
    fireEvent.click(screen.getByRole("tab", { name: "Hàng đặt riêng" }));
    expect(await screen.findAllByRole("dialog")).toHaveLength(1);
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
    expect(input).toHaveValue("0");
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    fireEvent.click(screen.getByRole("tab", { name: "Hàng đặt riêng" }));
    fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
    await waitFor(() =>
      expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
        "Hàng đặt riêng",
      ),
    );
  });
  it("uses a compact bulk paste disclosure and keeps invalid rows visible", async () => {
    await show();
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    expect(
      screen.queryByRole("textbox", { name: "Dữ liệu dán" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      await screen.findByRole("button", { name: "Dán hàng loạt" }),
    );
    fireEvent.change(screen.getByRole("textbox", { name: "Dữ liệu dán" }), {
      target: { value: "Unknown\t2026-09-07\tx\t0" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Dùng dữ liệu dán" }));
    expect(screen.getByText(/chưa nhận diện được trường/)).toBeVisible();
  });
  it("B1 displays actual persisted source sections and one creation category selector", async () => {
    const fixture = createPlanningStoryFixture("pantry_review");
    const first = fixture.pantry.batch!.active_lines[0];
    fixture.pantry.batch!.active_lines = [
      {
        ...first,
        pantry_need_purpose_id: "purpose-1",
        requested_quantity: "5",
        source_row_reference: "planning-source",
      },
      {
        ...first,
        pantry_need_line_id: "school-source-id",
        pantry_need_purpose_id: "purpose-2",
        requested_quantity: "3",
        source_row_reference: "school-source",
      },
    ];
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          initialJob="pantry"
        />
      </AtlasVNextProvider>,
    );
    const table = await screen.findByRole("table", { name: "Hàng đặt riêng" });
    expect(
      await screen.findByRole("combobox", { name: "Nguồn của dòng mới" }),
    ).toBeVisible();
    expect(within(table).getByText("Bổ sung", { exact: true })).toBeVisible();
    expect(
      within(table).getByText("Hàng đặt riêng", { exact: true }),
    ).toBeVisible();
    expect(
      screen.getByRole("textbox", { name: "Số lượng dòng 1" }),
    ).toHaveValue("5");
    expect(
      screen.getByRole("textbox", { name: "Số lượng dòng 2" }),
    ).toHaveValue("3");
    expect(
      within(table).queryByRole("combobox", { name: /Nguồn/ }),
    ).not.toBeInTheDocument();
  });
  it("offers only source category and previews a new School/date as ADDITIVE", async () => {
    const fixture = createPlanningReviewFixture();
    fixture.pantry.schools = fixture.pantry.schools.slice(0, 2);
    const preview = vi.spyOn(fixture.pantryApi, "preview");
    const save = vi.spyOn(fixture.pantryApi, "saveCompleted");
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          initialJob="pantry"
        />
      </AtlasVNextProvider>,
    );
    const school = await screen.findByRole("combobox", {
      name: "Trường cần thêm hàng",
    });
    const category = screen.getByRole("combobox", {
      name: "Nguồn của dòng mới",
    });
    const add = screen.getByRole("button", { name: "+ Thêm dòng" });
    expect(
      screen.queryByRole("combobox", { name: "Cách tính nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(category).toBeDisabled();
    expect(add).toBeDisabled();
    expect(
      school.compareDocumentPosition(category) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      category.compareDocumentPosition(add) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    fireEvent.focus(school);
    fireEvent.change(school, { target: { value: "nguyen du" } });
    fireEvent.click(
      await screen.findByRole("option", { name: /Trường Nguyễn Du/ }),
    );
    expect(category).toBeEnabled();
    fireEvent.change(category, {
      target: { value: "school_requested_supplement" },
    });
    expect(
      screen.queryByRole("textbox", { name: "Số lượng dòng 1" }),
    ).not.toBeInTheDocument();
    fireEvent.click(add);
    expect(
      await screen.findByRole("textbox", { name: "Số lượng dòng 1" }),
    ).toBeVisible();
    expect(category).toHaveValue("school_requested_supplement");
    const table = screen.getByRole("table", { name: "Hàng đặt riêng" });
    expect(
      within(table).queryByRole("combobox", { name: /Cách/ }),
    ).not.toBeInTheDocument();
    expect(within(table).getByText("Cộng với thực đơn")).toBeVisible();
    expect(preview).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
    const ingredient = screen.getByRole("combobox", {
      name: "Nguyên liệu dòng 1",
    });
    fireEvent.focus(ingredient);
    fireEvent.change(ingredient, { target: { value: "gao" } });
    fireEvent.click(await screen.findByRole("option", { name: /Gạo thơm/ }));
    fireEvent.change(screen.getByRole("textbox", { name: "Số lượng dòng 1" }), {
      target: { value: "5" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await waitFor(() => expect(preview).toHaveBeenCalledTimes(1));
    expect(preview.mock.calls[0]?.[4]).toEqual([
      expect.objectContaining({
        pantry_need_purpose_id: "purpose-2",
        requested_quantity: "5",
      }),
    ]);
    expect(preview.mock.calls[0]?.[5]).toEqual([
      {
        school_id: "school-0",
        service_date: reviewWeek,
        direct_need_mode: "ADDITIVE",
      },
    ]);
  });
  it("groups pantry mode by School/date and derives unit and delivery location", async () => {
    await show(2);
    fireEvent.click(screen.getByRole("tab", { name: "Hàng đặt riêng" }));
    const pantryTable = await screen.findByRole("table", {
      name: "Hàng đặt riêng",
    });
    const pantryViewport = screen.getByRole("region", {
      name: "Bảng hàng đặt riêng",
    });
    expect(pantryViewport).toHaveAttribute("tabindex", "0");
    expect(pantryViewport).toContainElement(pantryTable);
    expect(pantryTable).toHaveStyle({
      minWidth: "var(--atlas-layout-zero, 0)",
      width: "100%",
      tableLayout: "fixed",
    });
    const targetSchool = await screen.findByRole("combobox", {
      name: "Trường cần thêm hàng",
    });
    fireEvent.focus(targetSchool);
    fireEvent.change(targetSchool, { target: { value: "nguyen du" } });
    expect(targetSchool).toHaveValue("nguyen du");
    fireEvent.click(
      await screen.findByRole("option", { name: /Trường Nguyễn Du/ }),
    );
    fireEvent.click(screen.getByRole("button", { name: "+ Thêm dòng" }));
    fireEvent.click(screen.getByRole("button", { name: "+ Thêm dòng" }));
    expect(
      screen.queryByRole("combobox", {
        name: "Cách tính nhu cầu",
      }),
    ).not.toBeInTheDocument();
    expect(
      within(pantryTable).queryByRole("combobox", { name: /Cách/ }),
    ).not.toBeInTheDocument();
    const ingredient = screen.getAllByRole("combobox", {
      name: /Nguyên liệu dòng/,
    })[0];
    fireEvent.focus(ingredient);
    fireEvent.change(ingredient, { target: { value: "Gạo thơm" } });
    fireEvent.click(await screen.findByRole("option", { name: /Gạo thơm/ }));
    expect(
      within(
        screen.getByRole("textbox", { name: "Số lượng dòng 1" }).closest("td")!,
      ).getByText("KG"),
    ).toBeVisible();
    expect(screen.getAllByText("Bếp Trường Nguyễn Du")[0]).toBeVisible();
    expect(
      screen.queryByRole("checkbox", {
        name: "Xác nhận cả tuần không có hàng đặt riêng",
      }),
    ).not.toBeInTheDocument();
  });
  it("keeps Pantry School read-only and retains its exact draft through School filtering and Preview", async () => {
    const fixture = createPlanningStoryFixture("pantry_review");
    fixture.pantry.schools = fixture.pantry.schools.slice(0, 2);
    const read = vi.spyOn(fixture.pantryApi, "getWorkbench");
    const preview = vi.spyOn(fixture.pantryApi, "preview");
    const save = vi.spyOn(fixture.pantryApi, "saveCompleted");
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          initialJob="pantry"
        />
      </AtlasVNextProvider>,
    );
    const quantity = await screen.findByRole("textbox", {
      name: "Số lượng dòng 1",
    });
    expect(
      screen.queryByRole("combobox", { name: "Trường dòng 1" }),
    ).not.toBeInTheDocument();
    expect(quantity.closest("tr")).toHaveTextContent("Bếp Trường Nguyễn Du");

    const readsBefore = read.mock.calls.length;
    fireEvent.change(quantity, { target: { value: "26.000001" } });
    openFilters();
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    const picker = await screen.findByRole("dialog", {
      name: "Trường / điểm giao",
    });
    fireEvent.click(
      within(picker).getByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    fireEvent.click(
      within(picker).getByRole("checkbox", { name: "Trường Lê Lợi" }),
    );
    await waitFor(() =>
      expect(
        within(picker).getByRole("button", { name: "Áp dụng" }),
      ).toBeEnabled(),
    );
    fireEvent.click(within(picker).getByRole("button", { name: "Áp dụng" }));
    expect(read).toHaveBeenCalledTimes(readsBefore);
    expect(preview).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
    expect(
      screen.queryByRole("textbox", { name: "Số lượng dòng 1" }),
    ).not.toBeInTheDocument();
    expect(screen.getByText(/dòng ngoài bộ lọc vẫn được giữ/)).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await waitFor(() => expect(preview).toHaveBeenCalledTimes(1));
    const previewCall = preview.mock.calls[0] as unknown as Parameters<
      PantryApi["preview"]
    >;
    expect(previewCall[4]).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          source_row_reference: "fixture:1",
          school_id: "school-0",
          requested_quantity: "26.000001",
        }),
      ]),
    );
    expect(
      within(
        await screen.findByRole("table", { name: "So sánh thay đổi" }),
      ).getByText("Trường Nguyễn Du"),
    ).toBeVisible();
  });
  it("uses a single selected School when adding and preserves independent composition modes", async () => {
    const fixture = createPlanningStoryFixture("pantry_review");
    fixture.pantry.schools = fixture.pantry.schools.slice(0, 2);
    fixture.pantry.batch!.school_date_modes = [
      {
        school_id: "school-0",
        service_date: reviewWeek,
        direct_need_mode: "COMPLETE",
      },
      {
        school_id: "school-1",
        service_date: reviewWeek,
        direct_need_mode: "ADDITIVE",
      },
    ];
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          initialJob="pantry"
        />
      </AtlasVNextProvider>,
    );
    await screen.findByRole("textbox", { name: "Số lượng dòng 1" });
    openFilters();
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    const picker = await screen.findByRole("dialog", {
      name: "Trường / điểm giao",
    });
    fireEvent.click(
      within(picker).getByRole("button", { name: "Bỏ chọn tất cả" }),
    );
    fireEvent.click(
      within(picker).getByRole("checkbox", { name: "Trường Lê Lợi" }),
    );
    await waitFor(() =>
      expect(
        within(picker).getByRole("button", { name: "Áp dụng" }),
      ).toBeEnabled(),
    );
    fireEvent.click(within(picker).getByRole("button", { name: "Áp dụng" }));
    expect(
      screen.queryByRole("combobox", { name: "Trường cần thêm hàng" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "+ Thêm dòng" }));
    expect(
      screen.getByRole("textbox", { name: "Số lượng dòng 3" }).closest("tr"),
    ).toHaveTextContent("Bếp Trường Lê Lợi");
    expect(
      within(screen.getByRole("table", { name: "Hàng đặt riêng" })).getByText(
        "Cộng với thực đơn",
      ),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Trường Lê Lợi" }));
    const restoredPicker = await screen.findByRole("dialog", {
      name: "Trường / điểm giao",
    });
    fireEvent.click(
      within(restoredPicker).getByRole("button", { name: "Chọn tất cả" }),
    );
    fireEvent.click(
      within(restoredPicker).getByRole("button", { name: "Áp dụng" }),
    );
    const targetSchool = screen.getByRole("combobox", {
      name: "Trường cần thêm hàng",
    });
    fireEvent.focus(targetSchool);
    fireEvent.change(targetSchool, { target: { value: "nguyen du" } });
    fireEvent.click(
      await screen.findByRole("option", { name: /Trường Nguyễn Du/ }),
    );
    expect(
      screen.queryByRole("combobox", { name: "Cách tính nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      within(screen.getByRole("table", { name: "Hàng đặt riêng" })).getByText(
        "Danh sách đầy đủ (lịch sử)",
      ),
    ).toBeVisible();
    expect(
      screen.getByRole("textbox", { name: "Số lượng dòng 3" }).closest("tr"),
    ).toHaveTextContent("Bếp Trường Lê Lợi");
  });
});

it.each(["menu", "attendance", "pantry"] as const)(
  "renders %s with only its source authority",
  async (job) => {
    const fixture = createPlanningReviewFixture();
    (job === "pantry" ? fixture.api : fixture.pantryApi).getWorkbench =
      async () => unknown;
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
          initialJob={job}
        />
      </AtlasVNextProvider>,
    );
    await screen.findByRole("table");
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    if (job === "menu")
      expect(
        screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
      ).toBeEnabled();
    if (job === "attendance")
      expect(
        screen.getAllByRole("textbox").some((e) => !e.hasAttribute("disabled")),
      ).toBe(true);
    if (job === "pantry") {
      fireEvent.focus(
        screen.getByRole("combobox", { name: "Trường cần thêm hàng" }),
      );
      expect(
        await screen.findByRole("listbox", { name: "Trường cần thêm hàng" }),
      ).toHaveTextContent(fixture.pantry.schools[0].school_name);
    }
    fireEvent.click(
      screen.getByRole("tab", {
        name: job === "pantry" ? "Thực đơn" : "Hàng đặt riêng",
      }),
    );
    expect(
      await screen.findByRole("button", { name: "Thử tải lại dữ liệu" }),
    ).toBeEnabled();
  },
);

async function renderPantryNoteRule(
  rule: "OPTIONAL" | "REQUIRED" | "PROHIBITED",
  note: string,
) {
  const fixture = createPlanningStoryFixture("pantry_review");
  fixture.pantry.purposes[0].note_rule = rule;
  fixture.pantry.batch!.active_lines[0].note = note;
  render(
    <AtlasVNextProvider>
      <PlanningSourcesWorkbench
        {...fixture}
        authSubject="operator"
        initialWeek={reviewWeek}
        initialJob="pantry"
      />
    </AtlasVNextProvider>,
  );
}

it("keeps OPTIONAL Pantry notes optional", async () => {
  await renderPantryNoteRule("OPTIONAL", "");
  const input = await screen.findByRole("textbox", {
    name: "Ghi chú dòng 1",
  });
  expect(input).not.toBeRequired();
  expect(screen.queryByText(/Nhập lý do/)).not.toBeInTheDocument();
});

it.each(["REQUIRED", "PROHIBITED"] as const)(
  "retains historical Purpose note rules without relabeling the source: %s",
  async (rule) => {
    await renderPantryNoteRule(rule, "Nội dung giữ lại");
    const input = await screen.findByRole("textbox", {
      name: "Ghi chú dòng 1",
    });
    expect(input).not.toBeRequired();
    expect(input).toBeEnabled();
    expect(input).toHaveValue("Nội dung giữ lại");
    expect(
      screen.queryByRole("combobox", { name: /Mục đích/ }),
    ).not.toBeInTheDocument();
    fireEvent.change(input, { target: { value: "" } });
    expect(input).toBeEnabled();
    fireEvent.change(screen.getByRole("textbox", { name: "Số lượng dòng 1" }), {
      target: { value: "25.7" },
    });
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeEnabled();
  },
);

it.each([
  [stale, "Tải lại dữ liệu hiện tại"],
  [unknown, "Tải lại để xác nhận"],
] as const)(
  "labels recovery by semantic result %s",
  async (response, label) => {
    const fixture = createPlanningReviewFixture();
    fixture.api.saveCompletedMenu = async () => response;
    if (response.kind === "transport_error") {
      let reads = 0;
      fixture.api.getWorkbench = async () =>
        reads++ === 0 ? success({ workbench: fixture.planning }) : unknown;
    }
    render(
      <AtlasVNextProvider>
        <PlanningSourcesWorkbench
          {...fixture}
          authSubject="operator"
          initialWeek={reviewWeek}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    expect(await screen.findByRole("button", { name: label })).toBeEnabled();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
  },
);
