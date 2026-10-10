import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
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

it("offers one editable service-day calendar and no editable week or day select", async () => {
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
  await screen.findByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" });
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  expect(
    screen.getByRole("button", { name: "Mở lịch — Ngày phục vụ" }),
  ).toBeEnabled();
  expect(
    screen.queryByRole("combobox", { name: "Ngày phục vụ" }),
  ).not.toBeInTheDocument();
  expect(
    container.querySelectorAll('[data-scope="date-input"][data-part="root"]'),
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
  await screen.findByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" });
  const refresh = screen.getByRole("button", { name: "Làm mới dữ liệu" });
  expect(refresh.closest("[data-atlas-workbar-actions]")).not.toBeNull();
  expect(refresh.closest("[data-atlas-workbar]")).toHaveAttribute(
    "aria-label",
    "Phạm vi xác nhận nhu cầu",
  );
});

it("restores the displayed day and focus after cancelling a dirty keyboard date edit", async () => {
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
  const quantity = await screen.findByRole("textbox", {
    name: "Số lượng xác nhận Gạo thơm",
  });
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  fireEvent.change(quantity, { target: { value: "12" } });
  const day = screen.getByRole("spinbutton", { name: "Day" });
  day.focus();
  fireEvent.keyDown(day, { key: "ArrowUp" });
  fireEvent.click(
    await screen.findByRole("button", { name: "Tiếp tục chỉnh sửa" }),
  );
  await waitFor(() =>
    expect(screen.getByRole("spinbutton", { name: "Day" })).toHaveTextContent(
      "07",
    ),
  );
  await waitFor(() =>
    expect(screen.getByRole("spinbutton", { name: "Day" })).toHaveFocus(),
  );
  expect(quantity).toHaveValue("12");
});
