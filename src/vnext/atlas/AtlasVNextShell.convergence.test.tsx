import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextShell } from "./AtlasVNextShell";
import { atlasWorkbenches } from "./AtlasWorkbenchRegistry";

function viewport(desktop: boolean) {
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue({
      matches: desktop,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  );
}
beforeEach(() => viewport(true));
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

it("gives all thirteen workbenches distinct registry icons", () => {
  expect(atlasWorkbenches).toHaveLength(13);
  expect(new Set(atlasWorkbenches.map(({ icon }) => icon)).size).toBe(13);
});

it("keeps registry icons identical in launcher, desktop tabs and mobile switcher", () => {
  const props = {
    activeModule: "planning" as const,
    openIds: atlasWorkbenches.map(({ id }) => id),
  };
  const show = () =>
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell {...props}>
          <h1>Current workspace</h1>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
  const desktop = show();
  fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
  const launcher = screen.getByRole("dialog", { name: "Bàn làm việc" });
  const iconShapes = new Map<string, string>();
  for (const item of atlasWorkbenches) {
    const launcherIcon = within(launcher)
      .getByRole("button", { name: item.label })
      .querySelector("svg");
    const tabIcon = screen
      .getByRole("tab", { name: item.label })
      .querySelector("svg");
    expect(launcherIcon).not.toBeNull();
    expect(tabIcon).not.toBeNull();
    expect(tabIcon?.innerHTML).toBe(launcherIcon?.innerHTML);
    expect(tabIcon).toHaveAttribute("aria-hidden", "true");
    iconShapes.set(item.id, launcherIcon!.innerHTML);
  }
  desktop.unmount();
  viewport(false);
  show();
  const trigger = screen.getByRole("button", { name: "Đang mở: Thực đơn" });
  expect(trigger.querySelector("svg")?.innerHTML).toBe(
    iconShapes.get("planning"),
  );
  fireEvent.click(trigger);
  const mobile = screen.getByRole("dialog", { name: "Bàn làm việc đang mở" });
  for (const item of atlasWorkbenches) {
    const icon = within(mobile)
      .getByRole("button", { name: item.label })
      .querySelector("svg");
    expect(icon?.innerHTML).toBe(iconShapes.get(item.id));
  }
});

it("gives inactive workspaces resting boundaries and the active workspace a distinct surface", () => {
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="schools" openIds={["schools", "planning"]}>
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  const active = screen.getByRole("tab", { name: "Trường học" });
  const inactive = screen.getByRole("tab", { name: "Thực đơn" });
  expect(active).toHaveAttribute("aria-selected", "true");
  expect(inactive).toHaveAttribute("aria-selected", "false");
  for (const tab of [active, inactive]) {
    const style = getComputedStyle(tab.parentElement!);
    expect(style.borderLeftWidth).toBe("var(--atlas-layout-edge, 1px)");
    expect(style.borderRightWidth).toBe("var(--atlas-layout-edge, 1px)");
    expect(style.borderLeftColor).not.toBe("transparent");
  }
  expect(getComputedStyle(active.parentElement!).background).not.toBe(
    getComputedStyle(inactive.parentElement!).background,
  );
});

it("distinguishes unsaved, attention and blocked markers by shape with readable labels", () => {
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell
        activeModule="schools"
        openIds={["schools", "planning", "procurement"]}
        statuses={{
          schools: { unsaved: true, blocked: false },
          planning: {
            unsaved: false,
            blocked: false,
            attention: "Cần kiểm tra",
          },
          procurement: { unsaved: false, blocked: true },
        }}
      >
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  const shapes = ["Chưa lưu", "Cần kiểm tra", "Cần giải quyết"].map((label) => {
    const marker = screen.getByLabelText(label);
    expect(marker).toHaveAttribute("title", label);
    expect(marker.closest("[role=tab]")).toHaveAttribute(
      "aria-description",
      label,
    );
    return marker.querySelector("svg")?.innerHTML;
  });
  expect(new Set(shapes).size).toBe(3);
});
