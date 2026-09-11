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
import { PlanningSourcesWorkbench } from "./PlanningSourcesWorkbench";
import { createPlanningStoryFixture } from "./planningStoryFixtures";
import {
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
async function show() {
  const fixture = createPlanningReviewFixture();
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
describe("Planning sources Chakra workbench", () => {
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
  });
  it("refreshes authoritative sources without fetching Google", async () => {
    const { fixture, read } = await show();
    const sync = vi.spyOn(fixture.api, "syncMenuFromGoogle");
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    await waitFor(() => expect(read).toHaveBeenCalledTimes(2));
    expect(sync).not.toHaveBeenCalled();
  });
  it("has one h1, exactly three jobs, and local search without backend reads", async () => {
    const { read } = await show();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getAllByRole("tab").map((t) => t.textContent)).toEqual([
      "Thực đơn",
      "Sĩ số",
      "Bổ sung",
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
    fireEvent.click(screen.getByRole("tab", { name: "Bổ sung" }));
    expect(
      await screen.findByRole("checkbox", {
        name: "Xác nhận toàn tuần không có bổ sung",
      }),
    ).toBeDisabled();
    expect(
      screen.getByText(
        "Chuyển về Tất cả trường để thay đổi xác nhận toàn tuần.",
      ),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Trường Nguyễn Du" }));
    fireEvent.click(await screen.findByRole("button", { name: "Chọn tất cả" }));
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(screen.getByRole("button", { name: "Tất cả trường" })).toBeVisible();
  });
  it("renders Google candidate and attached meaningful change review with one save", async () => {
    await show();
    fireEvent.click(
      screen.getByRole("button", { name: "Đồng bộ Google Sheet" }),
    );
    await screen.findByText("Đang chỉnh sửa · chưa lưu");
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = await screen.findByRole("complementary", {
      name: "Xem thay đổi",
    });
    expect(within(review).getByText("Canh rau ngót")).toBeVisible();
    expect(within(review).getByRole("button", { name: "Lưu" })).toBeEnabled();
    expect(
      screen.queryByText(/menu-preview|menu-authority|APPROVED/),
    ).not.toBeInTheDocument();
  });
  it("shows editable attendance, explicit zero and totals, with one dirty exit dialog", async () => {
    await show();
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    const input = await screen.findByRole("textbox", {
      name: "Học sinh Trường Nguyễn Du",
    });
    fireEvent.change(input, { target: { value: "0" } });
    expect(input).toHaveValue("0");
    expect(screen.getByText("Đang chỉnh sửa · chưa lưu")).toBeVisible();
    fireEvent.click(screen.getByRole("tab", { name: "Bổ sung" }));
    expect(await screen.findAllByRole("dialog")).toHaveLength(1);
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
    expect(input).toHaveValue("0");
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    fireEvent.click(screen.getByRole("tab", { name: "Bổ sung" }));
    fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
    await waitFor(() =>
      expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
        "Bổ sung",
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
  it("groups pantry mode by School/date and derives unit and delivery location", async () => {
    await show();
    fireEvent.click(screen.getByRole("tab", { name: "Bổ sung" }));
    fireEvent.change(
      await screen.findByRole("combobox", { name: "Trường thêm dòng" }),
      { target: { value: "school-0" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "+ Thêm dòng" }));
    fireEvent.click(screen.getByRole("button", { name: "+ Thêm dòng" }));
    expect(
      screen.getAllByRole("combobox", {
        name: "Cách kết hợp Trường Nguyễn Du",
      }),
    ).toHaveLength(1);
    fireEvent.change(
      screen.getAllByRole("combobox", { name: /Nguyên liệu dòng/ })[0],
      { target: { value: "ingredient-1" } },
    );
    expect(screen.getByText("kg")).toBeVisible();
    expect(screen.getByText("Bếp Trường Nguyễn Du")).toBeVisible();
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Xác nhận toàn tuần không có bổ sung",
      }),
    );
    expect(await screen.findByRole("dialog")).toBeVisible();
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
    if (job === "pantry")
      expect(
        screen.getByRole("combobox", { name: "Trường thêm dòng" }),
      ).toHaveTextContent(fixture.pantry.schools[0].school_name);
    fireEvent.click(
      screen.getByRole("tab", {
        name: job === "pantry" ? "Thực đơn" : "Bổ sung",
      }),
    );
    expect(
      await screen.findByRole("button", { name: "Thử tải lại dữ liệu" }),
    ).toBeEnabled();
  },
);

it.each([
  ["REQUIRED", "", "Cần ghi chú cho mục đích này."],
  ["PROHIBITED", "Keep this note", "Mục đích này không cho phép ghi chú."],
] as const)("renders inline %s note validation", async (rule, note, error) => {
  const fixture = createPlanningStoryFixture("pantry_review");
  fixture.pantry.purposes[0].note_rule = rule;
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
  const input = await screen.findByRole("textbox", { name: "Ghi chú dòng 1" });
  fireEvent.change(input, { target: { value: note } });
  expect(input).toHaveAttribute("aria-invalid", "true");
  await waitFor(() => expect(input).toHaveAccessibleErrorMessage(error));
  expect(input).toHaveValue(note);
  expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
});

it.each([
  [stale, "Tải lại dữ liệu hiện tại"],
  [unknown, "Tải lại để xác nhận"],
] as const)(
  "labels recovery by semantic result %s",
  async (response, label) => {
    const fixture = createPlanningReviewFixture();
    fixture.api.saveCompletedMenu = async () => response;
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
    fireEvent.click(
      await screen.findByRole("button", { name: "Xem thay đổi" }),
    );
    const save = await screen.findByRole("button", { name: /Lưu/ });
    await waitFor(() => expect(save).toBeEnabled());
    fireEvent.click(save);
    expect(await screen.findByRole("button", { name: label })).toBeEnabled();
  },
);
