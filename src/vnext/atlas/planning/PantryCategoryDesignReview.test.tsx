import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { PantryCategoryDesignReview } from "./PantryCategoryDesignReview";
afterEach(cleanup);
it("isolates the two-category design, preserves separate 5/3 lines, inherits creation context and never offers Save", () => {
  render(
    <AtlasVNextProvider>
      <PantryCategoryDesignReview />
    </AtlasVNextProvider>,
  );
  const supplement = screen.getByRole("region", { name: "Bổ sung" });
  const requested = screen.getByRole("region", {
    name: "Hàng đặt riêng",
  });
  expect(
    within(supplement).getByRole("textbox", { name: /Số lượng minh họa/ }),
  ).toHaveValue("5");
  expect(
    within(requested).getByRole("textbox", { name: /Số lượng minh họa/ }),
  ).toHaveValue("3");
  fireEvent.change(screen.getByLabelText("Trường thêm hàng"), {
    target: { value: "school-1" },
  });
  fireEvent.change(screen.getByLabelText("Nguồn của dòng mới"), {
    target: { value: "school_requested_supplement" },
  });
  fireEvent.click(screen.getByRole("button", { name: "+ Thêm dòng minh họa" }));
  expect(
    within(requested).getByText(/Trường Lê Lợi · Bếp Trường Lê Lợi/),
  ).toBeVisible();
  expect(
    within(supplement).getByRole("textbox", { name: /Số lượng minh họa/ }),
  ).toHaveValue("5");
  expect(
    screen.getByRole("button", { name: "Lưu hai nguồn · chưa khả dụng" }),
  ).toBeDisabled();
  expect(screen.getByRole("note")).toHaveTextContent("Không lưu");
  expect(
    screen.queryByRole("combobox", { name: "Cách kết hợp nhu cầu (ví dụ)" }),
  ).not.toBeInTheDocument();
});
