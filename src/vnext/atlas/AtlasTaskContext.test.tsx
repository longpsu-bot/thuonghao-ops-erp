import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen, within } from "@testing-library/react";
import type { ComponentProps } from "react";
import { afterEach, expect, it } from "vitest";
import { AtlasTaskContext } from "./AtlasTaskContext";
import { AtlasVNextProvider } from "./AtlasVNextProvider";

afterEach(cleanup);

// A business-state callback or lifecycle flag would make this shared context
// responsible for more than display-ready presentation.
const presentationOnlyProps: ComponentProps<typeof AtlasTaskContext> = {
  ariaLabel: "Ngữ cảnh công việc mua hàng",
  moduleLabel: "Kế hoạch mua hàng",
  jobLabel: "Phân bổ nhà cung ứng",
  compactSummary: "11/09/2026 · Tất cả trường",
  details: [
    { label: "Ngày phục vụ", value: "11/09/2026" },
    { label: "Trường / điểm giao", value: "Tất cả trường" },
  ],
};

it("renders one supplied job heading and an explicit accessible compact summary", () => {
  render(
    <AtlasVNextProvider>
      <AtlasTaskContext {...presentationOnlyProps} />
    </AtlasVNextProvider>,
  );

  const context = screen.getByRole("region", {
    name: "Ngữ cảnh công việc mua hàng",
  });
  expect(within(context).getAllByRole("heading", { level: 1 })).toHaveLength(1);
  expect(
    within(context).getByRole("heading", {
      level: 1,
      name: "Phân bổ nhà cung ứng",
    }),
  ).toBeVisible();
  expect(
    within(context).getByLabelText(
      "Tóm tắt công việc: 11/09/2026 · Tất cả trường",
    ),
  ).toHaveTextContent("11/09/2026 · Tất cả trường");
  expect(within(context).queryByText("Ngày phục vụ")).not.toBeInTheDocument();
  expect(within(context).getByText("11/09/2026 · Tất cả trường")).toBeVisible();
});

it("owns a compact horizontal masthead without a desktop side-rail width", () => {
  render(
    <AtlasVNextProvider>
      <AtlasTaskContext {...presentationOnlyProps} />
    </AtlasVNextProvider>,
  );

  expect(
    screen.getByRole("region", {
      name: "Ngữ cảnh công việc mua hàng",
    }),
  ).toHaveStyle({ minHeight: "var(--atlas-task-context-min-height, 56px)" });
  expect(document.body.innerHTML).not.toContain(
    "--atlas-task-context-desktop-width",
  );
});
