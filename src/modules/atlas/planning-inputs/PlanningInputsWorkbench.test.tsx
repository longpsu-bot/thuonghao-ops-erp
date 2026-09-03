import "@testing-library/jest-dom/vitest";
import {
  act,
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

function createMenuApi() {
  const api = createReviewPlanningInputsApi("ready");
  const sync = api.syncMenuFromGoogle;
  api.syncMenuFromGoogle = async (...args) => {
    const result = await sync(...args);
    if (result.kind === "success")
      result.response.rows = [
        ["Tên trường", "Ngày", "Món canh"],
        ["TH001", args[1], "MON003"],
      ];
    return result;
  };
  return api;
}

async function fetchGoogleCandidate() {
  const sync = await screen.findByRole("button", {
    name: "Đồng bộ từ Google Sheet",
  });
  await waitFor(() => expect(sync).toBeEnabled());
  fireEvent.click(sync);
  await screen.findByText("Có bản đồng bộ chờ xác nhận");
}

function renderWorkbench(api = createMenuApi()) {
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
  const api = createMenuApi();
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
  it.each([
    ["Thực đơn", "Xem thay đổi thực đơn"],
    ["Sĩ số", "Xem thay đổi sĩ số"],
  ])(
    "moves focus into %s review and back to its rail action",
    async (task, label) => {
      renderWorkbench();
      fireEvent.click(await screen.findByRole("tab", { name: task }));
      const action = await screen.findByRole("button", {
        name: "Xem thay đổi",
      });
      await waitFor(() => expect(action).toBeEnabled());
      action.focus();
      fireEvent.click(action);
      const review = await screen.findByRole("region", { name: label });
      expect(review).toHaveFocus();
      fireEvent.click(within(review).getByRole("button", { name: "Quay lại" }));
      expect(
        screen.getByRole("button", { name: "Xem thay đổi" }),
      ).toHaveFocus();
      expect(
        screen.queryByRole("region", { name: label }),
      ).not.toBeInTheDocument();
    },
  );

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
          api={createMenuApi()}
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
      valueFormat: expect.stringMatching(
        /^DD\/MM\/YYYY \[– \d{2}\/\d{2}\/\d{4}]$/,
      ),
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

  it("uses the active Planning job as the single page H1", async () => {
    renderWorkbench();

    expect(
      await screen.findByRole("heading", {
        level: 1,
        name: "Thực đơn tuần",
      }),
    ).toBeVisible();
    expect(
      screen.queryByRole("heading", { name: "Lập nhu cầu theo tuần" }),
    ).not.toBeInTheDocument();

    for (const [tab, heading] of [
      ["Sĩ số", "Sĩ số"],
      ["Bổ sung", "Nhu cầu bổ sung"],
      ["Xác nhận nhu cầu", "Xác nhận nhu cầu"],
    ] as const) {
      fireEvent.click(screen.getByRole("tab", { name: tab }));
      expect(
        await screen.findByRole("heading", { level: 1, name: heading }),
      ).toBeVisible();
      expect(screen.getAllByRole("heading", { name: heading })).toHaveLength(1);
    }
  });

  it("uses one workflow/status row and defaults the display scope to all schools", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const pageTitle = screen.getByRole("heading", {
      level: 1,
      name: "Thực đơn tuần",
    });
    const rail = screen.getByRole("region", {
      name: "Thanh điều hành Lập nhu cầu",
    });
    expect(rail).not.toContainElement(pageTitle);
    expect(within(rail).getByLabelText("Tuần phục vụ")).toBeVisible();
    expect(within(rail).getByLabelText("Ngày phục vụ")).toBeVisible();
    expect(
      within(rail).getByRole("button", { name: "Phạm vi trường" }),
    ).toBeVisible();
    const refresh = within(rail).getByRole("button", {
      name: "Làm mới dữ liệu",
    });
    expect(refresh).toBeVisible();
    expect(refresh).toHaveAttribute("title", "Làm mới dữ liệu");
    expect(refresh).not.toHaveTextContent("Làm mới");
    expect(
      within(rail).getByLabelText("Hành động bước hiện tại"),
    ).toBeVisible();
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

  it("keeps Menu discard quiet in the source strip and preserves Attendance tools", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const menuToolbar = screen.getByLabelText("Nguồn thực đơn tuần");
    expect(
      within(menuToolbar).queryByText("Thao tác cục bộ"),
    ).not.toBeInTheDocument();
    expect(
      within(menuToolbar).queryByRole("button", { name: "Bỏ bản đồng bộ" }),
    ).not.toBeInTheDocument();

    const persisted = screen.getByLabelText("Lưới thực đơn").textContent;
    await fetchGoogleCandidate();
    expect(
      within(menuToolbar).getByRole("button", { name: "Bỏ bản đồng bộ" }),
    ).toBeVisible();
    fireEvent.click(
      within(menuToolbar).getByRole("button", { name: "Bỏ bản đồng bộ" }),
    );
    expect(screen.getByLabelText("Lưới thực đơn").textContent).toBe(persisted);
    expect(
      screen.queryByText("Có bản đồng bộ chờ xác nhận"),
    ).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    const attendanceToolbar = screen.getByLabelText(
      "Tìm kiếm, rà soát và lưu sĩ số",
    );
    expect(
      within(attendanceToolbar).getByText("Dán hàng loạt từ bảng tính"),
    ).toBeVisible();
    expect(
      within(attendanceToolbar).queryByRole("button", {
        name: "Hủy thay đổi",
      }),
    ).not.toBeInTheDocument();

    fireEvent.change(
      screen.getAllByRole("spinbutton", { name: /Suất học sinh/ })[0]!,
      { target: { value: "421" } },
    );
    expect(
      within(attendanceToolbar).getByRole("button", {
        name: "Hủy thay đổi",
      }),
    ).toBeVisible();
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

    await fetchGoogleCandidate();
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
        .getByRole("heading", { level: 1, name: "Thực đơn tuần" })
        .closest(".planning-compact-header"),
    ).not.toBeNull();
    expect(
      screen.getByText("Thực đơn tuần chưa có phân công hợp lệ."),
    ).toBeVisible();
    const supportSummary = screen.getByText("Nguồn & lịch sử");
    const support = supportSummary.closest("details");
    expect(support).not.toHaveAttribute("open");
    expect(
      within(support as HTMLElement).getByText("Bằng chứng nguồn hiện tại"),
    ).not.toBeVisible();
  });

  it("renders Confirmed Need for the shared current date without a daily navigator", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));

    expect(
      await screen.findByRole("complementary", {
        name: "Tình trạng nhu cầu ngày phục vụ",
      }),
    ).toBeVisible();
    expect(
      screen.queryByRole("navigation", { name: "Chọn ngày xác nhận nhu cầu" }),
    ).not.toBeInTheDocument();
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
    const syncMenu = api.syncMenuFromGoogle;
    api.syncMenuFromGoogle = async (...args) => {
      const result = await syncMenu(...args);
      if (result.kind === "success")
        result.response.rows = [
          ["Tên trường", "Ngày", "Món canh"],
          ["TH001", args[1], "MON003"],
          ["TH003", args[1], "MON003"],
          ["TH001", hiddenServiceDate, "MON001"],
        ];
      return result;
    };
    const previewAttendance = vi.spyOn(api, "previewAttendance");
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderWorkbench(api);
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const menuPanel = screen.getByRole("region", {
      name: "Bề mặt làm việc Thực đơn tuần",
    });
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
    expect(
      within(menuGrid).queryByText(formatIsoDate(hiddenServiceDate)),
    ).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("checkbox", { name: /Hoa Hồng/ }));
    expect(
      screen.queryByRole("rowheader", { name: /Hoa Hồng/ }),
    ).not.toBeInTheDocument();

    await fetchGoogleCandidate();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await waitFor(() => expect(previewMenu).toHaveBeenCalledTimes(1));
    expect(previewMenu.mock.calls[0]?.[3]).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ school_id: "review-planning-school-3" }),
        expect.objectContaining({ service_date: hiddenServiceDate }),
      ]),
    );

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    const attendancePanel = screen.getByRole("region", {
      name: "Bề mặt làm việc Sĩ số",
    });
    const attendanceGrid = within(attendancePanel).getByRole("region", {
      name: "Danh sách sĩ số",
    });
    expect(attendanceGrid).toHaveClass("planning-dense-table-surface");
    expect(
      within(attendanceGrid).getByRole("columnheader", { name: "Trường" }),
    ).toBeVisible();
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
    expect(
      within(attendanceGrid).getByRole("columnheader", { name: "Giáo viên" }),
    ).toBeVisible();
    expect(
      within(attendanceGrid).getByRole("columnheader", { name: "Tổng suất" }),
    ).toBeVisible();
    expect(
      within(attendanceGrid).queryByText(formatIsoDate(hiddenServiceDate)),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("rowheader", { name: "Trường Mầm non Hoa Hồng" }),
    ).not.toBeInTheDocument();
    const attendanceSearch = screen.getByRole("searchbox", {
      name: "Tìm trong sĩ số",
    });
    fireEvent.change(attendanceSearch, { target: { value: "nguyen du" } });
    expect(
      screen.queryByRole("rowheader", {
        name: "Trường Tiểu học Trần Quốc Toản",
      }),
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

  it("shows the disabled Google authority strip only in Menu when no source is configured", async () => {
    renderWorkbench(
      withWorkbench((workbench) => {
        workbench.google_sheet_sources = [];
      }),
    );
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const strip = screen.getByRole("region", { name: "Nguồn thực đơn tuần" });
    expect(within(strip).getByText("Google Sheets")).toBeVisible();
    expect(within(strip).getByText("Nguồn chính thức")).toBeVisible();
    expect(
      within(strip).getByText("Chưa cấu hình nguồn Google Sheet"),
    ).toBeVisible();
    const sync = within(strip).getByRole("button", {
      name: "Đồng bộ từ Google Sheet",
    });
    expect(sync).toBeDisabled();
    expect(sync).toHaveAttribute("title", "Chưa cấu hình nguồn Google Sheet");
    const rail = screen.getByRole("region", {
      name: "Thanh điều hành Lập nhu cầu",
    });
    expect(rail).not.toContainElement(strip);
    expect(
      within(rail).queryByLabelText("Đồng bộ từ Google Sheet"),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Nhập thực đơn")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Workbook" }),
    ).not.toBeInTheDocument();
    expect(document.querySelector('input[type="file"]')).toBeNull();
    for (const tab of ["Sĩ số", "Bổ sung", "Xác nhận nhu cầu"]) {
      fireEvent.click(screen.getByRole("tab", { name: tab }));
      expect(
        screen.queryByLabelText("Nguồn thực đơn tuần"),
      ).not.toBeInTheDocument();
      expect(
        screen.queryByLabelText("Đồng bộ từ Google Sheet"),
      ).not.toBeInTheDocument();
    }
  });

  it("directly fetches the sole configured source without saving or offering Menu editors", async () => {
    const api = createMenuApi();
    const sync = vi.spyOn(api, "syncMenuFromGoogle");
    const save = vi.spyOn(api, "saveCompletedMenu");
    renderWorkbench(api);
    await fetchGoogleCandidate();
    expect(sync).toHaveBeenCalledWith(
      "review-google-source",
      expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
      expect.any(String),
    );
    expect(save).not.toHaveBeenCalled();
    expect(screen.getByLabelText("Đồng bộ từ Google Sheet")).toHaveAttribute(
      "title",
      "Đồng bộ từ Google Sheet",
    );
    expect(screen.getByLabelText("Lưới thực đơn")).toHaveTextContent(
      "Canh rau ngót",
    );
    expect(
      within(screen.getByLabelText("Lưới thực đơn")).queryByRole("combobox"),
    ).not.toBeInTheDocument();
    expect(
      screen.getAllByRole("button", { name: "Xem thay đổi" }),
    ).toHaveLength(1);
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    expect(document.querySelector('input[type="file"]')).toBeNull();
  });

  it("saves the complete Google candidate after School and date display filtering", async () => {
    const api = createMenuApi();
    const fetch = api.syncMenuFromGoogle;
    api.syncMenuFromGoogle = async (...args) => {
      const result = await fetch(...args);
      if (result.kind === "success")
        result.response.rows = [
          ["Tên trường", "Ngày", "Món canh"],
          ["TH001", args[1], "MON003"],
          ["TH003", args[1], "MON001"],
          ["TH001", addIsoCalendarDays(args[1], 2), "MON003"],
        ];
      return result;
    };
    const completed = vi.spyOn(api, "saveCompletedMenu");
    renderWorkbench(api);
    await fetchGoogleCandidate();
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("checkbox", { name: /Hoa Hồng/ }));
    const dates = screen.getByLabelText("Ngày phục vụ") as HTMLSelectElement;
    fireEvent.change(dates, { target: { value: dates.options[2]!.value } });
    expect(
      screen.queryByRole("rowheader", { name: /Hoa Hồng/ }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const save = await screen.findByRole("button", { name: "Lưu" });
    fireEvent.click(save);
    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    const payload = completed.mock.calls[0]![0].payload;
    expect(payload.source_type).toBe("GOOGLE_SHEET");
    expect(payload.expected_source_signature).toBe("review-menu-checksum");
    expect(payload.rows).toHaveLength(3);
    expect(payload.rows).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ school_id: "review-planning-school-3" }),
        expect.objectContaining({ service_date: dates.options[0]!.value }),
        expect.objectContaining({ service_date: dates.options[2]!.value }),
      ]),
    );
    await waitFor(() =>
      expect(
        screen.queryByText("Có bản đồng bộ chờ xác nhận"),
      ).not.toBeInTheDocument(),
    );
  });

  it.each(["week", "tab", "refresh"])(
    "ignores a late Google response after changing %s context",
    async (context) => {
      vi.spyOn(crypto.subtle, "digest").mockResolvedValue(new ArrayBuffer(32));
      const api = createMenuApi();
      const fetch = api.syncMenuFromGoogle;
      let finish!: () => void;
      const gate = new Promise<void>((resolve) => {
        finish = resolve;
      });
      let pending!: ReturnType<typeof fetch>;
      vi.spyOn(api, "syncMenuFromGoogle").mockImplementation((...args) => {
        pending = gate.then(() => fetch(...args));
        return pending;
      });
      renderWorkbench(api);
      const sync = await screen.findByLabelText("Đồng bộ từ Google Sheet");
      await waitFor(() => expect(sync).toBeEnabled());
      fireEvent.click(sync);
      await screen.findByText("Đang tải Google Sheet…");
      if (context === "week") {
        const week = screen.getByLabelText("Tuần phục vụ") as HTMLInputElement;
        fireEvent.change(week, {
          target: { value: followingWeekFrom(week).nextWeek },
        });
      } else if (context === "tab")
        fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
      else fireEvent.click(screen.getByLabelText("Làm mới dữ liệu"));
      await act(async () => {
        finish();
        await pending;
      });
      if (context === "tab")
        fireEvent.click(screen.getByRole("tab", { name: "Thực đơn" }));
      expect(
        screen.queryByText("Có bản đồng bộ chờ xác nhận"),
      ).not.toBeInTheDocument();
      expect(
        screen.queryByRole("button", { name: "Bỏ bản đồng bộ" }),
      ).not.toBeInTheDocument();
      expect(screen.getByLabelText("Lưới thực đơn")).toHaveTextContent(
        "Canh bí đỏ thịt bằm",
      );
    },
  );

  it("chooses among active sources inside the compact Menu strip", async () => {
    const api = withWorkbench((data) => {
      data.google_sheet_sources.unshift({
        ...data.google_sheet_sources[0]!,
        weekly_menu_google_source_id: "second-source",
        source_name: "Nguồn thứ hai",
      });
      data.google_sheet_sources.push({
        ...data.google_sheet_sources[0]!,
        weekly_menu_google_source_id: "inactive-source",
        source_name: "Nguồn đã ngừng",
        source_status: "INACTIVE",
      });
    });
    const sync = vi.spyOn(api, "syncMenuFromGoogle");
    renderWorkbench(api);
    const syncButton = await screen.findByLabelText("Đồng bộ từ Google Sheet");
    await waitFor(() => expect(syncButton).toBeEnabled());
    fireEvent.click(syncButton);
    expect(sync).not.toHaveBeenCalled();
    const strip = screen.getByLabelText("Nguồn thực đơn tuần");
    fireEvent.click(
      within(strip).getByRole("button", { name: "Nguồn thực đơn xem thử" }),
    );
    await screen.findByText("Có bản đồng bộ chờ xác nhận");
    expect(sync).toHaveBeenCalledWith(
      "review-google-source",
      expect.any(String),
      expect.any(String),
    );
    expect(
      screen.queryByRole("button", { name: "Nguồn đã ngừng" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Nhập thực đơn")).not.toBeInTheDocument();
  });

  it("derives the next rendered week from the active calendar", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const weekInput = screen.getByLabelText("Tuần phục vụ") as HTMLInputElement;
    const { nextWeek, nextWeekEnd } = followingWeekFrom(weekInput);
    const midweekSelection = addIsoCalendarDays(nextWeek, 2);
    fireEvent.change(weekInput, { target: { value: midweekSelection } });

    expect(weekInput).toHaveValue(
      `${formatIsoDate(nextWeek)} – ${formatIsoDate(nextWeekEnd)}`,
    );
    expect(weekInput).toHaveAttribute("data-business-value", nextWeek);
    await waitFor(() =>
      expect(
        screen.getByRole("option", {
          name: `Chủ Nhật · ${formatIsoDate(nextWeekEnd)}`,
        }),
      ).toBeInTheDocument(),
    );
    expect(screen.queryByText("Khoảng ngày")).not.toBeInTheDocument();
    expect(addIsoCalendarDays(nextWeek, 6)).toBe(nextWeekEnd);
  });

  it("requires a current human-readable Menu Review before one v2 Save", async () => {
    const api = createMenuApi();
    const preview = vi.spyOn(api, "previewMenu");
    const completed = vi.spyOn(api, "saveCompletedMenu");
    const draft = vi.spyOn(api, "saveMenu");
    const validate = vi.spyOn(api, "validateMenu");
    const approve = vi.spyOn(api, "approveMenu");
    renderWorkbench(api);

    await fetchGoogleCandidate();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));

    await waitFor(() => expect(preview).toHaveBeenCalledTimes(1));
    const review = screen.getByRole("region", {
      name: "Xem thay đổi thực đơn",
    });
    const menuDecisionLayout = screen.getByRole("group", {
      name: "Bảng và phần xem thay đổi thực đơn",
    });
    expect(menuDecisionLayout).toHaveClass("has-review");
    expect(
      within(menuDecisionLayout).getByLabelText("Lưới thực đơn"),
    ).toBeVisible();
    expect(
      within(menuDecisionLayout).getByLabelText("Xem thay đổi thực đơn"),
    ).toBeVisible();
    expect(
      within(review).getByRole("button", { name: "Quay lại" }),
    ).toBeVisible();
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
    expect(
      screen.queryByText("Có bản đồng bộ chờ xác nhận"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Xác thực" }),
    ).not.toBeInTheDocument();
  });

  it("automatically presents Attendance defaults and preserves explicit zero in one reviewed v2 Save", async () => {
    const api = createMenuApi();
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
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));

    const review = await screen.findByRole("region", {
      name: "Xem thay đổi sĩ số",
    });
    const attendanceDecisionLayout = screen.getByRole("group", {
      name: "Bảng và phần xem thay đổi sĩ số",
    });
    expect(attendanceDecisionLayout).toHaveClass("has-review");
    expect(
      within(attendanceDecisionLayout).getByLabelText("Danh sách sĩ số"),
    ).toBeVisible();
    expect(
      within(attendanceDecisionLayout).getByLabelText("Xem thay đổi sĩ số"),
    ).toBeVisible();
    expect(
      within(review).getByRole("button", { name: "Quay lại" }),
    ).toBeVisible();
    expect(review).toHaveTextContent("420");
    expect(review).toHaveTextContent("0");
    const save = screen.getByRole("button", { name: "Lưu" });
    expect(save).toBeEnabled();
    const teacherInput = screen.getAllByRole("spinbutton", {
      name: /Suất giáo viên/,
    })[0]!;
    fireEvent.change(teacherInput, { target: { value: "29" } });
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
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
    fireEvent.click(screen.getByText("Nguồn & lịch sử"));
    fireEvent.click(screen.getByText("Chi tiết hỗ trợ"));
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

    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));

    await waitFor(() =>
      expect(
        screen.getAllByRole("spinbutton", { name: /Suất học sinh/ })[0],
      ).toHaveValue(520),
    );
  });

  it("does not coerce a blank Attendance quantity to zero", async () => {
    const api = createMenuApi();
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

  it("invalidates a reviewed Menu after another Google fetch", async () => {
    renderWorkbench();
    await fetchGoogleCandidate();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();

    await fetchGoogleCandidate();
    await waitFor(() =>
      expect(
        screen.queryByRole("button", { name: "Lưu" }),
      ).not.toBeInTheDocument(),
    );

    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
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
    const api = createMenuApi();
    const read = vi.spyOn(api, "getWorkbench");
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench(api);
    fireEvent.click(await screen.findByRole("tab", { name: "Sĩ số" }));
    const studentInput = (
      await screen.findAllByRole("spinbutton", { name: /Suất học sinh/ })
    )[0]!;
    fireEvent.change(studentInput, { target: { value: "487" } });

    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));

    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Làm mới sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(studentInput).toHaveValue(487);
    expect(read).toHaveBeenCalledTimes(1);
  });

  it("surfaces the backend OUTDATED consequence after source Save", async () => {
    const api = createMenuApi();
    const original = api.saveCompletedMenu;
    vi.spyOn(api, "saveCompletedMenu").mockImplementation(async (request) => {
      const result = await original(request);
      if (result.kind === "success")
        result.response.downstream_currentness = "OUTDATED";
      return result;
    });
    renderWorkbench(api);

    await fetchGoogleCandidate();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(await screen.findByText(/Đã lưu thực đơn\./)).toHaveTextContent(
      "Nhu cầu hiện tại cần cập nhật theo dữ liệu vừa lưu.",
    );
  });

  it("shows synchronized source identity from authoritative Google save readback", async () => {
    renderWorkbench();
    await fetchGoogleCandidate();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(await screen.findByRole("button", { name: "Lưu" }));
    const strip = screen.getByLabelText("Nguồn thực đơn tuần");
    expect(await within(strip).findByText(/^Đã đồng bộ/)).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Bỏ bản đồng bộ" }),
    ).not.toBeInTheDocument();
  });

  it("preserves a dirty Weekly Menu edit when a tab switch is rejected", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();

    await fetchGoogleCandidate();
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(screen.getByRole("tab", { name: "Thực đơn" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(screen.getByLabelText("Lưới thực đơn")).toHaveTextContent(
      "Canh rau ngót",
    );
  });

  it("preserves the current week and local source edit when week change is rejected", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();

    await fetchGoogleCandidate();
    const weekInput = screen.getByLabelText("Tuần phục vụ") as HTMLInputElement;
    const currentWeek = weekInput.value;
    const { nextWeek } = followingWeekFrom(weekInput);
    fireEvent.change(weekInput, { target: { value: nextWeek } });

    expect(weekInput).toHaveValue(currentWeek);
    expect(screen.getByLabelText("Lưới thực đơn")).toHaveTextContent(
      "Canh rau ngót",
    );
  });

  it("keeps beforeunload active while source work is unsaved", async () => {
    renderWorkbench();
    await fetchGoogleCandidate();

    await waitFor(() => {
      const event = new Event("beforeunload", { cancelable: true });
      window.dispatchEvent(event);
      expect(event.defaultPrevented).toBe(true);
    });
  });

  it("guards Pantry edits and explicit no-additions during navigation", async () => {
    vi.spyOn(window, "confirm")
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
    const api = createMenuApi();
    vi.spyOn(api, "saveCompletedMenu").mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Mất kết nối" },
    });
    renderWorkbench(api);

    await fetchGoogleCandidate();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    await screen.findByRole("region", { name: "Xem thay đổi thực đơn" });
    const save = screen.getByRole("button", { name: "Lưu" });
    fireEvent.click(save);

    await screen.findByText("Cần làm mới dữ liệu trước khi tiếp tục.");
    expect(save).toBeDisabled();
    expect(screen.getByLabelText("Đồng bộ từ Google Sheet")).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Bỏ bản đồng bộ" }),
    ).toBeDisabled();
  });
});
