import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasSchoolScope } from "./AtlasSchoolScope";

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
it("searches 50 Schools without applying draft selection and retains exact UUIDs", async () => {
  const schools = Array.from({ length: 50 }, (_, i) => ({
    school_id: `90000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`,
    school_name: i === 0 ? "Trường Đặng Thị Nhu" : `Trường Nguyễn Du ${i + 1}`,
  }));
  const apply = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasSchoolScope schools={schools} value={[]} onApply={apply} />
    </AtlasVNextProvider>,
  );
  fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
  const picker = await screen.findByRole("dialog", {
    name: "Trường / điểm giao",
  });
  expect(within(picker).getAllByRole("checkbox")).toHaveLength(50);
  expect(within(picker).getByText("Đã chọn 50 / 50 trường")).toBeVisible();
  fireEvent.click(
    within(picker).getByRole("button", { name: "Bỏ chọn tất cả" }),
  );
  expect(
    within(picker).getByRole("button", { name: "Áp dụng" }),
  ).toBeDisabled();
  const search = within(picker).getByRole("textbox", { name: "Tìm trường" });
  fireEvent.change(search, { target: { value: "DANG THI NHU" } });
  expect(within(picker).getAllByRole("checkbox")).toHaveLength(1);
  fireEvent.click(
    within(picker).getByRole("checkbox", { name: "Trường Đặng Thị Nhu" }),
  );
  await waitFor(() =>
    expect(
      within(picker).getByRole("button", { name: "Áp dụng" }),
    ).toBeEnabled(),
  );
  expect(apply).not.toHaveBeenCalled();
  fireEvent.change(search, { target: { value: "không tồn tại" } });
  expect(
    within(picker).getByText("Không tìm thấy trường phù hợp."),
  ).toBeVisible();
  fireEvent.click(within(picker).getByRole("button", { name: "Áp dụng" }));
  expect(apply).toHaveBeenCalledExactlyOnceWith([
    "90000000-0000-4000-8000-000000000001",
  ]);
  await waitFor(() => expect(picker).not.toBeInTheDocument());
  expect(screen.getByRole("button", { name: "Tất cả trường" })).toHaveFocus();
});
