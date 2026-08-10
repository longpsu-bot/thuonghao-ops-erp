import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../connection/authSession";
import { PlanningInputsWorkbench } from "./PlanningInputsWorkbench";
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
  const nextWeek = addIsoCalendarDays(weekInput.value, 7);
  const nextWeekEnd = addIsoCalendarDays(nextWeek, 6);
  return {
    nextWeek,
    nextWeekEnd,
    nextWeekRange: `${formatIsoDate(nextWeek)} – ${formatIsoDate(nextWeekEnd)}`,
  };
}

describe("UI-QUALITY-02AB-UX Planning source cutover", () => {
  it("retires Readiness as a primary destination", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });
    expect(
      screen
        .getAllByRole("tab")
        .map((tab) => tab.textContent?.replace(/\s+/g, " ").trim()),
    ).toEqual([
      "Thực đơn tuần",
      "Sĩ số",
      "Pantry",
      "Tạo nhu cầu",
      "Xác nhận nhu cầu",
    ]);
    expect(
      screen.queryByRole("tab", { name: "Sẵn sàng đầu vào" }),
    ).not.toBeInTheDocument();
  });

  it("derives the next rendered week from the active calendar", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Thực đơn tuần" });

    const weekInput = screen.getByLabelText("Tuần phục vụ") as HTMLInputElement;
    const { nextWeek, nextWeekEnd, nextWeekRange } =
      followingWeekFrom(weekInput);
    fireEvent.change(weekInput, { target: { value: nextWeek } });

    expect(weekInput).toHaveValue(nextWeek);
    await waitFor(() =>
      expect(screen.getByText("Khoảng ngày").parentElement).toHaveTextContent(
        nextWeekRange,
      ),
    );
    expect(addIsoCalendarDays(nextWeek, 6)).toBe(nextWeekEnd);
  });

  it("previews then saves Weekly Menu with exactly one v2 write", async () => {
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
    fireEvent.change(cell, { value: "review-planning-dish-1" });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thực đơn" }));

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    expect(preview).toHaveBeenCalledTimes(1);
    expect(completed.mock.calls[0]?.[0].contract_version).toBe("RMVP-03A.v2");
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

  it("prepares Attendance defaults locally and preserves explicit zero in one v2 Save", async () => {
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
    fireEvent.click(
      await screen.findByRole("button", {
        name: "Tạo từ sĩ số mặc định",
      }),
    );
    await waitFor(() => expect(defaultsWrite).not.toHaveBeenCalled());

    const studentInput = await screen.findAllByRole("spinbutton", {
      name: /Suất học sinh/,
    });
    fireEvent.change(studentInput[0]!, { target: { value: "0" } });
    fireEvent.click(screen.getByRole("button", { name: "Lưu số suất ăn" }));

    await waitFor(() => expect(completed).toHaveBeenCalledTimes(1));
    const request = completed.mock.calls[0]?.[0];
    expect(request?.contract_version).toBe("RMVP-03A.v2");
    expect(request?.payload.rows).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ student_portions: 0 }),
      ]),
    );
    expect(draft).not.toHaveBeenCalled();
    expect(validate).not.toHaveBeenCalled();
    expect(approve).not.toHaveBeenCalled();
    expect(screen.getByText(/Đã lưu số suất ăn\./)).toHaveTextContent(
      "Nhu cầu hiện tại vẫn khớp với dữ liệu đã lưu.",
    );
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
    fireEvent.change(cell, { target: { value: "review-planning-dish-1" } });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thực đơn" }));

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
    fireEvent.change(cell, { target: { value: "review-planning-dish-1" } });
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(screen.getByRole("tab", { name: "Thực đơn tuần" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(cell).toHaveValue("review-planning-dish-1");
  });

  it("preserves the current week and local source edit when week change is rejected", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();

    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-1" } });
    const weekInput = screen.getByLabelText("Tuần phục vụ") as HTMLInputElement;
    const currentWeek = weekInput.value;
    const { nextWeek } = followingWeekFrom(weekInput);
    fireEvent.change(weekInput, { target: { value: nextWeek } });

    expect(weekInput).toHaveValue(currentWeek);
    expect(cell).toHaveValue("review-planning-dish-1");
  });

  it("keeps beforeunload active while source work is unsaved", async () => {
    renderWorkbench();
    const cell = await screen.findByRole("combobox", {
      name: /Món canh · Trường Tiểu học Nguyễn Du/,
    });
    fireEvent.change(cell, { target: { value: "review-planning-dish-1" } });

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
    fireEvent.click(screen.getByRole("tab", { name: "Pantry" }));
    await screen.findByLabelText("Số lượng dòng 1");
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
      }),
    );
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    expect(screen.getByRole("tab", { name: "Pantry" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(
      screen.getByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
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
    fireEvent.change(cell, { target: { value: "review-planning-dish-1" } });
    const save = screen.getByRole("button", { name: "Lưu thực đơn" });
    fireEvent.click(save);

    await screen.findByText(/Cần tải lại dữ liệu có thẩm quyền/);
    expect(save).toBeDisabled();
  });
});
