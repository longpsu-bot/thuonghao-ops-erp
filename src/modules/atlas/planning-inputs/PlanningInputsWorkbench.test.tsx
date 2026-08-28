import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../connection/authSession";
import type { PlanningInputsApi } from "./planningInputsApi";
import type { PlanningInputsWorkbenchData } from "./planningInputsModel";
import {
  AtlasDatePickerInputContext,
  PlanningInputsWorkbench,
  type AtlasDatePickerInputProps,
} from "./PlanningInputsWorkbench";
import { createReviewPlanningInputsApi } from "./reviewPlanningInputsApi";
import { createReviewPantryApi } from "./pantry/reviewPantryApi";
import { createReviewPlanningInputReadinessApi } from "./readiness/reviewPlanningInputReadinessApi";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

function renderWorkbench(api = createReviewPlanningInputsApi("ready")) {
  return render(
    <PlanningInputsWorkbench
      authState={authState}
      api={api}
      pantryApi={createReviewPantryApi("ready")}
      readinessApi={createReviewPlanningInputReadinessApi("ready")}
      mode="review"
    />,
  );
}

function withWorkbench(
  mutate: (workbench: PlanningInputsWorkbenchData) => void,
): PlanningInputsApi {
  const api = createReviewPlanningInputsApi("ready");
  const getWorkbench = api.getWorkbench.bind(api);
  api.getWorkbench = async (...args) => {
    const result = await getWorkbench(...args);
    if (result.kind === "success" && result.response.workbench) {
      mutate(
        result.response.workbench as unknown as PlanningInputsWorkbenchData,
      );
    }
    return result;
  };
  return api;
}

function addIsoCalendarDays(isoDate: string, days: number) {
  const [year, month, day] = isoDate.split("-").map(Number);
  const shifted = new Date(Date.UTC(year, month - 1, day + days));
  return shifted.toISOString().slice(0, 10);
}

function formatIsoDate(isoDate: string) {
  const [year, month, day] = isoDate.split("-");
  return `${day}/${month}/${year}`;
}

function followingWeekFrom(weekInput: HTMLInputElement) {
  const currentWeek = weekInput.dataset.businessValue!;
  const nextWeek = addIsoCalendarDays(currentWeek, 7);
  const nextWeekEnd = addIsoCalendarDays(nextWeek, 6);
  return {
    nextWeek,
    nextWeekEnd,
    nextWeekRange: `${formatIsoDate(nextWeek)} – ${formatIsoDate(nextWeekEnd)}`,
  };
}

describe("UI-QUALITY-02AB-UX Planning source cutover", () => {
  it("configures the real calendar surface for Vietnamese Monday-first use", async () => {
    let received: AtlasDatePickerInputProps | null = null;
    function CalendarProbe(props: AtlasDatePickerInputProps) {
      received = props;
      return (
        <input aria-label={props["aria-label"]} value={props.value} readOnly />
      );
    }
    render(
      <AtlasDatePickerInputContext.Provider value={CalendarProbe}>
        <PlanningInputsWorkbench
          authState={authState}
          api={createReviewPlanningInputsApi("ready")}
          pantryApi={createReviewPantryApi("ready")}
          readinessApi={createReviewPlanningInputReadinessApi("ready")}
          mode="review"
        />
      </AtlasDatePickerInputContext.Provider>,
    );
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    expect(received).toMatchObject({
      locale: "vi",
      firstDayOfWeek: 1,
      valueFormat: "DD/MM/YYYY",
    });
  });

  it("shows four operator tasks without Readiness or Need Generation peers", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    expect(
      screen.getAllByRole("tab").map((tab) => tab.getAttribute("aria-label")),
    ).toEqual(["Thực đơn", "Sĩ số", "Bổ sung", "Xác nhận nhu cầu"]);
    expect(
      screen.queryByRole("tab", { name: "Sẵn sàng đầu vào" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("tab", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
  });

  it("uses one workflow/status row and defaults the display scope to all schools", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const pageTitle = screen.getByRole("heading", {
      name: "Lập nhu cầu theo tuần",
    });
    const rail = screen.getByRole("region", {
      name: "Thanh điều hành Lập nhu cầu",
    });
    expect(rail).not.toContainElement(pageTitle);
    expect(within(rail).getByLabelText("Tuần phục vụ")).toBeVisible();
    expect(within(rail).getByLabelText("Ngày phục vụ")).toBeVisible();
    expect(within(rail).getByRole("button", { name: "Phạm vi trường" })).toBeVisible();
    expect(within(rail).getByRole("button", { name: "Làm mới" })).toBeVisible();
    expect(within(rail).getByLabelText("Hành động bước hiện tại")).toBeVisible();
    expect(screen.getAllByRole("tablist")).toHaveLength(1);
    expect(screen.getAllByRole("tab")).toHaveLength(4);
    expect(
      screen.getByRole("tab", { name: "Thực đơn" }),
    ).toHaveAccessibleDescription("Cần lưu");
    expect(
      screen.getByRole("tab", { name: "Sĩ số" }),
    ).toHaveAccessibleDescription("Cần lưu");
    expect(
      screen.getByRole("tab", { name: "Bổ sung" }),
    ).toHaveAccessibleDescription("12 mục");
    expect(
      screen.getByRole("tab", { name: "Xác nhận nhu cầu" }),
    ).toHaveAccessibleDescription("Sẵn sàng");
    expect(
      screen.getByRole("button", { name: "Phạm vi trường" }),
    ).toHaveTextContent("Tất cả trường");
  });

  it("keeps unsaved workflow status local to the active Menu or Attendance step", async () => {
    const api = withWorkbench((workbench) => {
      workbench.weekly_menu!.weekly_menu_status = "APPROVED";
      workbench.attendance!.attendance_status = "APPROVED";
      workbench.default_attendance_preview = structuredClone(
        workbench.attendance!.lines,
      );
    });
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderWorkbench(api);
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    fireEvent.change(
      screen.getAllByRole("combobox", { name: /Món canh ·/ })[0]!,
      {
        target: { value: "review-planning-dish-3" },
      },
    );
    expect(
      screen.getByRole("tab", { name: "Thực đơn" }),
    ).toHaveAccessibleDescription("Cần lưu");
    expect(
      screen.getByRole("tab", { name: "Sĩ số" }),
    ).toHaveAccessibleDescription("Sẵn sàng");

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    fireEvent.change(
      screen.getAllByRole("spinbutton", { name: /Suất học sinh/ })[0]!,
      { target: { value: "421" } },
    );
    expect(
      screen.getByRole("tab", { name: "Thực đơn" }),
    ).toHaveAccessibleDescription("Sẵn sàng");
    expect(
      screen.getByRole("tab", { name: "Sĩ số" }),
    ).toHaveAccessibleDescription("Cần lưu");
  });

  it("uses a compact header and keeps support evidence collapsed without hiding blockers", async () => {
    renderWorkbench(
      withWorkbench((workbench) => {
        workbench.weekly_menu!.issues.blockers = [
          {
            code: "EMPTY_WEEKLY_MENU",
            message: "Weekly Menu is empty.",
            source_row_reference: null,
          },
        ];
      }),
    );
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    expect(
      screen
        .getByRole("heading", { name: "Lập nhu cầu theo tuần" })
        .closest(".planning-compact-header"),
    ).not.toBeNull();
    expect(
      screen.getByText("Thực đơn tuần chưa có phân công hợp lệ."),
    ).toBeVisible();
    const supportSummary = screen.getByText("Chi tiết hỗ trợ");
    const support = supportSummary.closest("details");
    expect(support).not.toHaveAttribute("open");
    expect(
      within(support as HTMLElement).getByText("Bằng chứng nguồn hiện tại"),
    ).not.toBeVisible();
  });

  it("renders Confirmed Need as daily overview plus selected-date review without automation actions", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));

    expect(
      await screen.findByRole("complementary", {
        name: "Tổng quan nhu cầu theo ngày",
      }),
    ).toBeVisible();
    expect(
      screen.getByRole("region", { name: "Chi tiết xác nhận nhu cầu" }),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", {
        name: /Bổ sung tự động|Pantry Rules|Đặt hàng tự động/i,
      }),
    ).not.toBeInTheDocument();
  });

  it("persists a multi-school display scope across all steps and service dates", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("checkbox", { name: /Hoa Hồng/ }));
    expect(
      screen.getByRole("button", { name: "Phạm vi trường" }),
    ).toHaveTextContent("2 trường");

    const dateSelect = screen.getByLabelText("Ngày phục vụ");
    fireEvent.change(dateSelect, {
      target: { value: (dateSelect as HTMLSelectElement).options[1]!.value },
    });
    for (const step of ["Sĩ số", "Bổ sung", "Xác nhận nhu cầu", "Thực đơn"]) {
      fireEvent.click(screen.getByRole("tab", { name: step }));
      expect(
        screen.getByRole("button", { name: "Phạm vi trường" }),
      ).toHaveTextContent("2 trường");
    }
  });

  it("filters Menu and Attendance rendering without truncating authoritative previews", async () => {
    let hiddenServiceDate = "";
    const api = withWorkbench((workbench) => {
      const menuTemplate = workbench.weekly_menu!.lines[0]!;
      hiddenServiceDate = addIsoCalendarDays(workbench.week_start, 1);
      workbench.weekly_menu!.lines.push({
        ...menuTemplate,
        weekly_menu_line_id: "review-menu-line-3-school",
        school_id: "review-planning-school-3",
        dish_id: "review-planning-dish-3",
      });
      workbench.weekly_menu!.lines.push({
        ...menuTemplate,
        weekly_menu_line_id: "review-menu-line-hidden-date",
        service_date: hiddenServiceDate,
      });
      const attendanceTemplate = workbench.attendance!.lines[0]!;
      const thirdSchoolAttendance = {
        ...attendanceTemplate,
        attendance_line_id: "review-attendance-line-3-school",
        school_id: "review-planning-school-3",
        student_portions: 180,
        teacher_portions: 18,
      };
      const hiddenDateAttendance = {
        ...attendanceTemplate,
        attendance_line_id: "review-attendance-line-hidden-date",
        service_date: hiddenServiceDate,
        student_portions: 210,
        teacher_portions: 16,
      };
      workbench.attendance!.lines.push(
        thirdSchoolAttendance,
        hiddenDateAttendance,
      );
      workbench.default_attendance_preview.push(
        { ...thirdSchoolAttendance, student_portions: 175 },
        { ...hiddenDateAttendance, student_portions: 205 },
      );
    });
    const previewMenu = vi.spyOn(api, "previewMenu");
    const previewAttendance = vi.spyOn(api, "previewAttendance");
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderWorkbench(api);
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const menuPanel = screen
      .getByRole("heading", { name: "Thực đơn tuần" })
      .closest(".work-panel") as HTMLElement;
    const menuGrid = within(menuPanel).getByRole("region", {
      name: "Lưới thực đơn",
    });
    expect(menuGrid).toHaveClass("planning-dense-table-surface");
    expect(
      within(menuPanel).queryByRole("button", { name: "Xem thay đổi" }),
    ).not.toBeInTheDocument();
    expect(
      within(menuPanel).queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(within(menuGrid).queryByText(formatIsoDate(hiddenServiceDate))).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("checkbox", { name: /Hoa Hồng/ }));
    expect(
      screen.queryByRole("rowheader", { name: /Hoa Hồng/ }),
    ).not.toBeInTheDocument();

    fireEvent.change(
      screen.getByRole("combobox", {
        name: /Món canh · Trường Tiểu học Nguyễn Du/,
      }),
      { target: { value: "review-planning-dish-3" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await waitFor(() => expect(previewMenu).toHaveBeenCalledTimes(1));
    expect(previewMenu.mock.calls[0]?.[3]).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ school_id: "review-planning-school-3" }),
        expect.objectContaining({ service_date: hiddenServiceDate }),
      ]),
    );

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    const attendancePanel = screen
      .getByRole("heading", { name: "Sĩ số" })
      .closest(".work-panel") as HTMLElement;
    const attendanceGrid = within(attendancePanel).getByRole("region", {
      name: "Danh sách sĩ số",
    });
    expect(attendanceGrid).toHaveClass("planning-dense-table-surface");
    expect(within(attendanceGrid).getByRole("columnheader", { name: "Trường" })).toBeVisible();
    expect(
      within(attendanceGrid).getByRole("columnheader", {
        name: "Học sinh mặc định",
      }),
    ).toBeVisible();
    expect(
      within(attendanceGrid).getByRole("columnheader", {
        name: "Học sinh thực tế",
      }),
    ).toBeVisible();
    expect(within(attendanceGrid).getByRole("columnheader", { name: "Giáo viên" })).toBeVisible();
    expect(within(attendanceGrid).getByRole("columnheader", { name: "Tổng suất" })).toBeVisible();
    expect(within(attendanceGrid).queryByText(formatIsoDate(hiddenServiceDate))).not.toBeInTheDocument();
    expect(
      screen.queryByRole("rowheader", { name: "Trường Mầm non Hoa Hồng" }),
    ).not.toBeInTheDocument();
    fireEvent.change(
      screen.getAllByRole("spinbutton", { name: /Suất học sinh/ })[0]!,
      { target: { value: "421" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await waitFor(() => expect(previewAttendance).toHaveBeenCalledTimes(1));
    expect(previewAttendance.mock.calls[0]?.[3]).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ school_id: "review-planning-school-3" }),
        expect.objectContaining({ service_date: hiddenServiceDate }),
      ]),
    );
  });

  it("shows Google configuration only after the Google import flow is chosen", async () => {
    renderWorkbench(
      withWorkbench((workbench) => {
        workbench.google_sheet_sources = [];
      }),
    );
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    expect(
      screen.queryByText("Chưa cấu hình nguồn Google Sheet."),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByText("Nhập thực đơn"));
    expect(
      screen.queryByText("Chưa cấu hình nguồn Google Sheet."),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Google Sheet" }));
    expect(screen.getByText("Chưa cấu hình nguồn Google Sheet.")).toBeVisible();
  });

  it("derives the next rendered week from the active calendar", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const weekInput = screen.getByLabelText("Tuần phục vụ") as HTMLInputElement;
    const { nextWeek, nextWeekEnd, nextWeekRange } =
      followingWeekFrom(weekInput);
    const midweekSelection = addIsoCalendarDays(nextWeek, 2);
    fireEvent.change(weekInput, { target: { value: midweekSelection } });

    expect(weekInput).toHaveValue(formatIsoDate(nextWeek));
    expect(weekInput).toHaveAttribute("data-business-value", nextWeek);
    await waitFor(() =>
      expect(screen.getByText("Khoảng ngày").parentElement).toHaveTextContent(
        nextWeekRange,
      ),
    );
    expect(addIsoCalendarDays(nextWeek, 6)).toBe(nextWeekEnd);
  });

  it("requires a current human-readable Menu Review before one v2 Save", async () => {
    const api = createReviewPlanningInputsApi("ready");
    const preview = vi.spyOn(api, "previewMenu");
    const completed = vi.spyOn(api, "saveCompletedMenu");
    const draft = vi.spyOn(api, "saveMenu");
    const validate = vi.spyOn(api, "validateMenu");
    const approve = vi.spyOn(api, "approveMenu");
    renderWorkbench(api);

    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-3" } });
    expect(screen.queryByRole("button", { name: "Lưu" })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));

    await waitFor(() => expect(preview).toHaveBeenCalledTimes(1));
    const review = screen.getByRole("region", {
      name: "Xem thay đổi thực đơn",
    });
    expect(review).toHaveTextContent("Canh bí đỏ thịt bằm");
    expect(review).toHaveTextContent("Canh rau ngót");
    expect(review).toHaveTextContent("Đổi");
    const save = screen.getByRole("button", { name: "Lưu" });
    expect(save).toBeEnabled();
    fireEvent.click(save);

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    expect(completed.mock.calls[0]?.[0].contract_version).toBe("RMVP-03A.v2");
    expect(completed.mock.calls[0]?.[0].payload.rows).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ dish_id: "review-planning-dish-3" }),
      ]),
    );
    expect(draft).not.toHaveBeenCalled();
    expect(validate).not.toHaveBeenCalled();
    expect(approve).not.toHaveBeenCalled();
    expect(screen.getByText(/Đã lưu thực đơn\./)).toHaveTextContent(
      "Dữ liệu này sẽ được dùng khi tạo nhu cầu.",
    );
    expect(screen.queryByText(/trong một giao dịch/i)).not.toBeInTheDocument();
    expect(await screen.findByText("ĐÃ LƯU")).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Xác thực" }),
    ).not.toBeInTheDocument();
  });

  it("automatically presents Attendance defaults and preserves explicit zero in one reviewed v2 Save", async () => {
    const api = createReviewPlanningInputsApi("ready");
    const original = api.saveCompletedAttendance;
    vi.spyOn(api, "saveCompletedAttendance").mockImplementation(
      async (request) => {
        const result = await original(request);
        if (result.kind === "success")
          result.response.downstream_currentness = "CURRENT";
        return result;
      },
    );
    const defaultsWrite = vi.spyOn(api, "createAttendanceDefaults");
    const completed = vi.spyOn(api, "saveCompletedAttendance");
    const draft = vi.spyOn(api, "saveAttendance");
    const validate = vi.spyOn(api, "validateAttendance");
    const approve = vi.spyOn(api, "approveAttendance");
    renderWorkbench(api);

    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    expect(
      screen.queryByRole("button", { name: "Tạo từ sĩ số mặc định" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Chọn workbook")).not.toBeInTheDocument();
    expect(defaultsWrite).not.toHaveBeenCalled();

    const studentInput = await screen.findAllByRole("spinbutton", {
      name: /Suất học sinh/,
    });
    expect(studentInput[0]).toHaveValue(420);
    fireEvent.change(studentInput[0]!, { target: { value: "0" } });
    expect(screen.queryByRole("button", { name: "Lưu" })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));

    const review = await screen.findByRole("region", {
      name: "Xem thay đổi sĩ số",
    });
    expect(review).toHaveTextContent("420");
    expect(review).toHaveTextContent("0");
    const save = screen.getByRole("button", { name: "Lưu" });
    expect(save).toBeEnabled();
    const teacherInput = screen.getAllByRole("spinbutton", {
      name: /Suất giáo viên/,
    })[0]!;
    fireEvent.change(teacherInput, { target: { value: "29" } });
    expect(screen.queryByRole("button", { name: "Lưu" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeEnabled();
    expect(
      screen.queryByRole("region", { name: "Xem thay đổi sĩ số" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi sĩ số" });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    const request = completed.mock.calls[0]?.[0];
    expect(request?.contract_version).toBe("RMVP-03A.v2");
    expect(request?.payload.rows).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          student_portions: 0,
          teacher_portions: 29,
        }),
      ]),
    );
    expect(draft).not.toHaveBeenCalled();
    expect(validate).not.toHaveBeenCalled();
    expect(approve).not.toHaveBeenCalled();
    expect(screen.getByText(/Đã lưu số suất ăn\./)).toHaveTextContent(
      "Nhu cầu hiện tại vẫn khớp với dữ liệu đã lưu.",
    );
  });

  it("explains Attendance default differences with human values and hides the technical reference", async () => {
    const api = withWorkbench((workbench) => {
      workbench.attendance!.lines[0]!.student_portions = 200;
      workbench.default_attendance_preview[0]!.student_portions = 100;
      workbench.attendance!.issues.warnings = [
        {
          code: "PORTIONS_DIFFER_FROM_DEFAULT",
          message: "Attendance differs from the current school defaults.",
          source_row_reference: "default:TH001",
        },
      ];
    });
    renderWorkbench(api);

    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    expect(
      screen.getByText(
        "Sĩ số học sinh 200 khác mức mặc định 100 của Trường Tiểu học Nguyễn Du.",
      ),
    ).toBeVisible();
    expect(screen.queryByText("default:TH001")).not.toBeVisible();
    const supportSummaries = screen.getAllByText("Chi tiết hỗ trợ");
    fireEvent.click(supportSummaries[1]);
    fireEvent.click(supportSummaries[0]);
    expect(screen.getByText("default:TH001")).toBeVisible();
  });

  it("automatically uses defaults when Attendance is empty", async () => {
    const api = withWorkbench((workbench) => {
      workbench.attendance = null;
    });
    renderWorkbench(api);

    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    const studentInputs = await screen.findAllByRole("spinbutton", {
      name: /Suất học sinh/,
    });
    expect(studentInputs).toHaveLength(2);
    expect(studentInputs[0]).toHaveValue(420);
    expect(studentInputs[1]).toHaveValue(360);
  });

  it("keeps persisted Attendance and fills only missing Menu-covered pairs", async () => {
    const api = withWorkbench((workbench) => {
      workbench.default_attendance_preview[0]!.student_portions = 999;
      workbench.attendance!.lines = [workbench.attendance!.lines[0]!];
    });
    renderWorkbench(api);

    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    const studentInputs = await screen.findAllByRole("spinbutton", {
      name: /Suất học sinh/,
    });
    expect(studentInputs).toHaveLength(2);
    expect(studentInputs[0]).toHaveValue(420);
    expect(studentInputs[1]).toHaveValue(360);
  });

  it("requires Review and Save when an approved Attendance is missing a new Menu-covered pair", async () => {
    const api = withWorkbench((workbench) => {
      workbench.attendance!.attendance_status = "APPROVED";
      workbench.attendance!.lines = [workbench.attendance!.lines[0]!];
    });
    const completed = vi.spyOn(api, "saveCompletedAttendance");
    renderWorkbench(api);

    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    const studentInputs = await screen.findAllByRole("spinbutton", {
      name: /Suất học sinh/,
    });
    expect(studentInputs).toHaveLength(2);
    expect(studentInputs[0]).toHaveValue(420);
    expect(studentInputs[1]).toHaveValue(360);
    expect(
      screen.queryByText("Có thay đổi chưa lưu trong nguồn đang làm việc."),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("ĐÃ LƯU")).not.toBeInTheDocument();
    expect(screen.getByText("CẦN XEM & LƯU")).toHaveClass("warning");
    expect(
      screen.getByText("Có sĩ số mặc định mới theo thực đơn chưa được lưu."),
    ).toBeInTheDocument();
    const unload = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(unload);
    expect(unload.defaultPrevented).toBe(false);

    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = await screen.findByRole("region", {
      name: "Xem thay đổi sĩ số",
    });
    const newAttendanceRow = within(review).getByRole("row", {
      name: /Trường Tiểu học Trần Quốc Toản/,
    });
    expect(newAttendanceRow).toHaveTextContent("—");
    expect(newAttendanceRow).toHaveTextContent("360");
    expect(newAttendanceRow).toHaveTextContent("24");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    await waitFor(() =>
      expect(screen.queryByText("CẦN XEM & LƯU")).not.toBeInTheDocument(),
    );
    expect(
      screen.queryByText("Có sĩ số mặc định mới theo thực đơn chưa được lưu."),
    ).not.toBeInTheDocument();
    expect(screen.getByText("ĐÃ LƯU")).toBeInTheDocument();
  });

  it("adopts refreshed School defaults for still-unpersisted Attendance", async () => {
    let readCount = 0;
    const api = withWorkbench((workbench) => {
      readCount += 1;
      workbench.attendance = null;
      workbench.default_attendance_preview[0]!.student_portions =
        readCount === 1 ? 500 : 520;
    });
    renderWorkbench(api);
    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    expect(
      (await screen.findAllByRole("spinbutton", { name: /Suất học sinh/ }))[0],
    ).toHaveValue(500);

    fireEvent.click(screen.getByRole("button", { name: "Làm mới" }));

    await waitFor(() =>
      expect(
        screen.getAllByRole("spinbutton", { name: /Suất học sinh/ })[0],
      ).toHaveValue(520),
    );
  });

  it("does not coerce a blank Attendance quantity to zero", async () => {
    const api = createReviewPlanningInputsApi("ready");
    const preview = vi.spyOn(api, "previewAttendance");
    renderWorkbench(api);
    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    const studentInput = (
      await screen.findAllByRole("spinbutton", { name: /Suất học sinh/ })
    )[0]!;
    fireEvent.change(studentInput, { target: { value: "" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));

    await waitFor(() => expect(preview).toHaveBeenCalledTimes(1));
    const reviewedRows = preview.mock.calls[0]?.[3] as Array<{
      student_portions: number;
    }>;
    expect(Number.isNaN(reviewedRows[0]?.student_portions)).toBe(true);
    expect(reviewedRows[0]?.student_portions).not.toBe(0);
  });

  it("invalidates a reviewed Menu after a material edit", async () => {
    renderWorkbench();
    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-3" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();

    fireEvent.change(cell, { target: { value: "review-planning-dish-1" } });

    expect(screen.queryByRole("button", { name: "Lưu" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeEnabled();
    expect(
      screen.queryByRole("region", { name: "Xem thay đổi thực đơn" }),
    ).not.toBeInTheDocument();
  });

  it("searches the parent school scope without Vietnamese accents", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm trường" }), {
      target: { value: "tran quoc toan" },
    });

    expect(
      screen.getByRole("checkbox", { name: /Trần Quốc Toản/ }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("checkbox", { name: /Nguyễn Du/ }),
    ).not.toBeInTheDocument();
  });

  it("does not replace a dirty Attendance edit when refresh is rejected", async () => {
    const api = createReviewPlanningInputsApi("ready");
    const read = vi.spyOn(api, "getWorkbench");
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench(api);
    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    const studentInput = (
      await screen.findAllByRole("spinbutton", { name: /Suất học sinh/ })
    )[0]!;
    fireEvent.change(studentInput, { target: { value: "487" } });

    fireEvent.click(screen.getByRole("button", { name: "Làm mới" }));

    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Làm mới sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(studentInput).toHaveValue(487);
    expect(read).toHaveBeenCalledTimes(1);
  });

  it("surfaces the backend OUTDATED consequence after source Save", async () => {
    const api = createReviewPlanningInputsApi("ready");
    const original = api.saveCompletedMenu;
    vi.spyOn(api, "saveCompletedMenu").mockImplementation(async (request) => {
      const result = await original(request);
      if (result.kind === "success")
        result.response.downstream_currentness = "OUTDATED";
      return result;
    });
    renderWorkbench(api);

    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-3" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(await screen.findByText(/Đã lưu thực đơn\./)).toHaveTextContent(
      "Nhu cầu hiện tại cần cập nhật theo dữ liệu vừa lưu.",
    );
  });

  it("preserves a dirty Weekly Menu edit when a tab switch is rejected", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();

    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-3" } });
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(screen.getByRole("tab", { name: "Thực đơn" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(cell).toHaveValue("review-planning-dish-3");
  });

  it("preserves the current week and local source edit when week change is rejected", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();

    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-3" } });
    const weekInput = screen.getByLabelText("Tuần phục vụ") as HTMLInputElement;
    const currentWeek = weekInput.value;
    const { nextWeek } = followingWeekFrom(weekInput);
    fireEvent.change(weekInput, { target: { value: nextWeek } });

    expect(weekInput).toHaveValue(currentWeek);
    expect(cell).toHaveValue("review-planning-dish-3");
  });

  it("keeps beforeunload active while source work is unsaved", async () => {
    renderWorkbench();
    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-3" } });

    await waitFor(() => {
      const event = new Event("beforeunload", { cancelable: true });
      window.dispatchEvent(event);
      expect(event.defaultPrevented).toBe(true);
    });
  });

  it("guards Pantry edits and explicit no-additions during navigation", async () => {
    const confirm = vi
      .spyOn(window, "confirm")
      .mockReturnValueOnce(true)
      .mockReturnValueOnce(false);
    renderWorkbench();
    fireEvent.click(screen.getByRole("tab", { name: "Bổ sung" }));
    await screen.findByLabelText("Số lượng dòng 1");
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Xác nhận toàn tuần không có bổ sung",
      }),
    );
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    expect(screen.getByRole("tab", { name: "Bổ sung" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(
      screen.getByRole("checkbox", {
        name: "Xác nhận toàn tuần không có bổ sung",
      }),
    ).toBeChecked();
  });

  it("locks further source mutation after an unknown write outcome until refresh", async () => {
    const api = createReviewPlanningInputsApi("ready");
    vi.spyOn(api, "saveCompletedMenu").mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Mất kết nối" },
    });
    renderWorkbench(api);

    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-3" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    const save = screen.getByRole("button", { name: "Lưu" });
    fireEvent.click(save);

    await screen.findByText(/Cần làm mới dữ liệu/);
    expect(save).toBeDisabled();
  });
});
