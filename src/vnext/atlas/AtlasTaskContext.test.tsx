import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { AtlasTaskContext } from "./AtlasTaskContext";
import { AtlasVNextProvider } from "./AtlasVNextProvider";

afterEach(cleanup);

it("renders display-ready task context with the locked responsive geometry", () => {
  render(
    <AtlasVNextProvider>
      <AtlasTaskContext
        ariaLabel="Ngữ cảnh công việc mua hàng"
        moduleLabel="Kế hoạch mua hàng"
        jobLabel="Phân bổ nhà cung ứng"
        details={[
          { label: "Ngày phục vụ", value: "11/09/2026" },
          { label: "Trường / điểm giao", value: "Tất cả trường" },
        ]}
      />
    </AtlasVNextProvider>,
  );

  const context = screen.getByRole("complementary", {
    name: "Ngữ cảnh công việc mua hàng",
  });
  expect(context).toHaveStyle({
    "--atlas-task-context-desktop-width": "196px",
    "--atlas-task-context-mobile-height": "88px",
  });
  expect(
    screen.getByRole("heading", { level: 1, name: "Phân bổ nhà cung ứng" }),
  ).toBeVisible();
  expect(screen.getByText("Ngày phục vụ")).toBeInTheDocument();
  expect(screen.getByText("11/09/2026")).toBeVisible();
  expect(screen.getByText("Trường / điểm giao")).toBeInTheDocument();
  expect(screen.getByText("Tất cả trường")).toBeVisible();
});
