import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ConfirmedNeedWorkbench } from "./ConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
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

it("offers one shared range calendar and a derived day navigator", async () => {
  const fixture = createConfirmedNeedReviewFixture("normal");
  const { container } = render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...fixture}
        authSubject="operator"
        initialServiceDate={reviewDate}
      />
    </AtlasVNextProvider>,
  );
  expect(screen.queryByText("Tuần phục vụ")).not.toBeInTheDocument();
  await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
  fireEvent.click(
    within(screen.getByLabelText("Phạm vi xác nhận nhu cầu")).getByRole(
      "button",
      { name: "Bộ lọc" },
    ),
  );
  expect(screen.getByLabelText("Mở lịch — Khoảng ngày")).toBeEnabled();
  expect(
    screen.queryByRole("combobox", { name: "Ngày phục vụ" }),
  ).not.toBeInTheDocument();
  expect(
    container.querySelectorAll('[data-scope="date-picker"][data-part="root"]'),
  ).toHaveLength(1);
});

it("places Refresh in the shared control row without a vertical offset", async () => {
  const fixture = createConfirmedNeedReviewFixture("normal");
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...fixture}
        authSubject="operator"
        initialServiceDate={reviewDate}
      />
    </AtlasVNextProvider>,
  );
  await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
  const refresh = screen.getByLabelText("Làm mới dữ liệu");
  expect(refresh.closest("[data-atlas-workbar-actions]")).not.toBeNull();
  expect(refresh.closest("[data-atlas-workbar]")).toHaveAttribute(
    "aria-label",
    "Phạm vi xác nhận nhu cầu",
  );
});

it("keeps the original range and draft after cancelling a dirty range departure", async () => {
  const fixture = createConfirmedNeedReviewFixture("normal");
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...fixture}
        authSubject="operator"
        initialServiceDate={reviewDate}
      />
    </AtlasVNextProvider>,
  );
  const quantity = await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
  fireEvent.click(
    within(screen.getByLabelText("Phạm vi xác nhận nhu cầu")).getByRole(
      "button",
      { name: "Bộ lọc" },
    ),
  );
  fireEvent.change(quantity, { target: { value: "12" } });
  const trigger = screen.getByLabelText("Mở lịch — Khoảng ngày");
  fireEvent.click(trigger);
  const calendar = await screen.findByRole("grid");
  const day = calendar.querySelector<HTMLElement>(
    '[data-part="table-cell-trigger"][data-value="2026-09-08"]',
  )!;
  fireEvent.click(day);
  fireEvent.click(day);
  const dialog = await screen.findByRole("dialog");
  fireEvent.click(
    within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  await waitFor(() =>
    expect(screen.getByLabelText("Mở lịch — Khoảng ngày")).toHaveTextContent(
      "07/09/2026 — 07/09/2026",
    ),
  );
  await waitFor(() =>
    expect(screen.getByLabelText("Mở lịch — Khoảng ngày")).toHaveFocus(),
  );
  expect(quantity).toHaveValue("12");
});

it("blocks shopping callbacks and refresh on the retained authority until the range is corrected", async () => {
  const fixture = createConfirmedNeedReviewFixture("normal");
  const exportBook = vi.fn().mockResolvedValue(undefined),
    importBook = vi.fn();
  const preflight = vi.spyOn(fixture.preflightApi, "preflight");
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...fixture}
        authSubject="operator"
        initialServiceDate={reviewDate}
        onExportShoppingList={exportBook}
        onImportShoppingList={importBook}
      />
    </AtlasVNextProvider>,
  );
  await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
  const calls = preflight.mock.calls.length;
  fireEvent.click(
    within(screen.getByLabelText("Phạm vi xác nhận nhu cầu")).getByRole(
      "button",
      { name: "Bộ lọc" },
    ),
  );
  fireEvent.click(screen.getByLabelText("Mở lịch — Khoảng ngày"));
  const calendar = await screen.findByRole("grid");
  fireEvent.click(
    calendar.querySelector<HTMLElement>(
      '[data-part="table-cell-trigger"][data-value="2026-09-07"]',
    )!,
  );
  fireEvent.click(
    calendar.querySelector<HTMLElement>(
      '[data-part="table-cell-trigger"][data-value="2026-09-14"]',
    )!,
  );
  expect(await screen.findByText("Chọn tối đa 7 ngày.")).toBeInTheDocument();
  for (const name of [
    "Xuất Phiếu đi chợ",
    "Nhập Phiếu đi chợ",
    "Làm mới dữ liệu",
  ]) {
    const button =
      name === "Làm mới dữ liệu"
        ? screen.getByLabelText(name)
        : within(screen.getByLabelText("Tiện ích nhu cầu xác nhận")).getByRole(
            "button",
            { name },
          );
    expect(button).toBeDisabled();
    fireEvent.click(button);
  }
  expect(exportBook).not.toHaveBeenCalled();
  expect(importBook).not.toHaveBeenCalled();
  expect(preflight).toHaveBeenCalledTimes(calls);
  expect(screen.getByLabelText("Mở lịch — Khoảng ngày")).toBeEnabled();
});

it("presents generated zero demand as a normal day with no purchase continuation", async () => {
  const fixture = createConfirmedNeedReviewFixture("normal");
  fixture.preflight.demand_state = "NO_DEMAND";
  fixture.preflight.current_need!.confirmed_need_batch_id = null;
  fixture.preflight.current_need!.confirmed_need_batch_status = null;
  fixture.preflight.current_need!.confirmed_need_batch_version = null;
  fixture.preflight.current_need!.need_generation_release_snapshot_id =
    "snapshot-current";
  const read = vi.spyOn(fixture.confirmedNeedApi, "getReview");
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...fixture}
        authSubject="operator"
        initialServiceDate={reviewDate}
      />
    </AtlasVNextProvider>,
  );
  expect(
    await screen.findByText(/07\/09 · Không có nhu cầu/),
  ).toBeInTheDocument();
  expect(
    screen.queryByText(/Chưa xác định được kết quả/),
  ).not.toBeInTheDocument();
  expect(read).not.toHaveBeenCalled();
});
