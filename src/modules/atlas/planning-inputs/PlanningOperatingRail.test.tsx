import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { MantineProvider } from "@mantine/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import { atlasTheme } from "../../../theme";
import { PlanningOperatingRail } from "./PlanningOperatingRail";
import {
  PlanningRailActionPortal,
  PlanningRailActionProvider,
} from "./PlanningRailActionPortal";
import type { PlanningWorkflowItem } from "./PlanningWorkflowBar";

afterEach(cleanup);

const items: PlanningWorkflowItem<"menu" | "attendance" | "pantry" | "need">[] =
  [
    {
      id: "menu",
      label: "Thực đơn",
      status: "Cần lưu",
      tone: "warning",
    },
    {
      id: "attendance",
      label: "Sĩ số",
      status: "Sẵn sàng",
      tone: "ok",
    },
    {
      id: "pantry",
      label: "Bổ sung",
      status: "2 mục",
      tone: "neutral",
    },
    {
      id: "need",
      label: "Xác nhận nhu cầu",
      status: "Chờ xác nhận",
      tone: "warning",
    },
  ];

function renderRail(children?: React.ReactNode) {
  const onStepChange = vi.fn();
  render(
    <MantineProvider theme={atlasTheme} env="test">
      <PlanningRailActionProvider>
        <PlanningOperatingRail
          weekControl={<button type="button">Tuần 25/08</button>}
          serviceDateControl={<button type="button">Ngày 25/08</button>}
          schoolControl={<button type="button">Tất cả trường</button>}
          workflowItems={items}
          activeId="menu"
          onStepChange={onStepChange}
          secondaryActions={<button type="button">Làm mới</button>}
          actions={<button type="button">Xem thay đổi</button>}
        />
        {children}
      </PlanningRailActionProvider>
    </MantineProvider>,
  );
  return onStepChange;
}

describe("PlanningOperatingRail", () => {
  it("groups workflow tabs and actions together below the separate context group", () => {
    renderRail();
    const context = screen.getByRole("group", { name: "Phạm vi vận hành" });
    const workflow = screen.getByRole("group", {
      name: "Công việc lập nhu cầu",
    });
    expect(within(context).queryByRole("tab")).not.toBeInTheDocument();
    expect(within(workflow).getAllByRole("tab")).toHaveLength(4);
    expect(
      within(workflow).getByRole("button", { name: "Làm mới" }),
    ).toBeVisible();
    expect(
      within(workflow).getByRole("button", { name: "Xem thay đổi" }),
    ).toBeVisible();
    expect(
      context.compareDocumentPosition(workflow) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });
  it("keeps operating context, one workflow, and the parent action in one rail", () => {
    const onStepChange = renderRail();
    const rail = screen.getByRole("region", {
      name: "Thanh điều hành Lập nhu cầu",
    });

    expect(
      within(rail).getByRole("button", { name: "Tuần 25/08" }),
    ).toBeVisible();
    expect(
      within(rail).getByRole("button", { name: "Ngày 25/08" }),
    ).toBeVisible();
    expect(
      within(rail).getByRole("button", { name: "Tất cả trường" }),
    ).toBeVisible();
    expect(
      within(rail).getByRole("group", { name: "Phạm vi vận hành" }),
    ).toBeVisible();
    expect(
      within(rail).getByRole("group", { name: "Công việc lập nhu cầu" }),
    ).toBeVisible();
    expect(within(rail).getAllByRole("tablist")).toHaveLength(1);
    expect(screen.getAllByRole("tablist")).toHaveLength(1);
    const actionHost = within(rail).getByLabelText("Hành động bước hiện tại");
    expect(
      within(actionHost).getByRole("button", { name: "Xem thay đổi" }),
    ).toBeVisible();
    expect(screen.getAllByLabelText("Hành động bước hiện tại")).toHaveLength(1);

    fireEvent.click(within(rail).getByRole("tab", { name: "Bổ sung" }));
    expect(onStepChange).toHaveBeenCalledWith("pantry");
  });

  it("projects a child-owned action into the same rail action host", async () => {
    renderRail(
      <PlanningRailActionPortal>
        <button type="button">Lưu bổ sung</button>
      </PlanningRailActionPortal>,
    );

    const actionHost = screen.getByLabelText("Hành động bước hiện tại");
    expect(
      await within(actionHost).findByRole("button", { name: "Lưu bổ sung" }),
    ).toBeVisible();
    expect(screen.getAllByLabelText("Hành động bước hiện tại")).toHaveLength(1);
  });
});
