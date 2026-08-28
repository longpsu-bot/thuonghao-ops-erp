import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { MantineProvider } from "@mantine/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import { atlasTheme } from "../../../theme";
import {
  PlanningWorkflowBar,
  type PlanningWorkflowItem,
} from "./PlanningWorkflowBar";

afterEach(cleanup);

const items: PlanningWorkflowItem<
  "menu" | "attendance" | "pantry" | "confirmed"
>[] = [
  {
    id: "menu",
    step: 1,
    label: "Thực đơn",
    status: "Cần lưu",
    tone: "warning",
  },
  { id: "attendance", step: 2, label: "Sĩ số", status: "Sẵn sàng", tone: "ok" },
  { id: "pantry", step: 3, label: "Bổ sung", status: "2 mục", tone: "neutral" },
  {
    id: "confirmed",
    step: 4,
    label: "Xác nhận nhu cầu",
    status: "Chờ xác nhận",
    tone: "warning",
  },
];

describe("PlanningWorkflowBar", () => {
  it("renders one accessible four-step workflow/status tablist", () => {
    render(
      <MantineProvider theme={atlasTheme} env="test">
        <PlanningWorkflowBar items={items} activeId="menu" onChange={vi.fn()} />
      </MantineProvider>,
    );

    expect(screen.getAllByRole("tablist")).toHaveLength(1);
    const tabs = screen.getAllByRole("tab");
    expect(tabs).toHaveLength(4);
    expect(tabs.map((tab) => tab.getAttribute("aria-label"))).toEqual([
      "Thực đơn",
      "Sĩ số",
      "Bổ sung",
      "Xác nhận nhu cầu",
    ]);
    items.forEach((item) => {
      const tab = screen.getByRole("tab", { name: item.label });
      expect(tab).toHaveTextContent(String(item.step));
      expect(tab).toHaveTextContent(item.label);
      expect(tab).toHaveAccessibleDescription(item.status);
    });
    expect(screen.getByRole("tab", { name: "Thực đơn" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
  });

  it("changes the active workflow step", () => {
    const onChange = vi.fn();
    render(
      <MantineProvider theme={atlasTheme} env="test">
        <PlanningWorkflowBar
          items={items}
          activeId="menu"
          onChange={onChange}
        />
      </MantineProvider>,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Bổ sung" }));
    expect(onChange).toHaveBeenCalledWith("pantry");
  });
});
