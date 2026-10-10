import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ConfirmedNeedCommandFeedback } from "./ConfirmedNeedCommandFeedback";
afterEach(cleanup);

it("shows one explanation when command feedback and read recovery repeat the same failure", () => {
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedCommandFeedback
        lock="unknown"
        notice="Chưa xác định được kết quả lưu."
        readError="Chưa xác định được kết quả lưu."
        busy={false}
        onRecover={() => {}}
      />
    </AtlasVNextProvider>,
  );
  expect(screen.getAllByText("Chưa xác định được kết quả lưu.")).toHaveLength(
    1,
  );
  expect(
    screen.queryByText(
      "Chưa xác định được kết quả. Các thao tác ghi đang tạm khóa.",
    ),
  ).not.toBeInTheDocument();
  expect(
    screen.getByRole("button", { name: "Tải lại để xác nhận" }),
  ).toBeEnabled();
});
