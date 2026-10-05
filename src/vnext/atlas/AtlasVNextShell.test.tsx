import "@testing-library/jest-dom/vitest";
import { Box, useChakraContext } from "@chakra-ui/react";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { atlasSystem } from "./system";
import { AtlasVNextShell } from "./AtlasVNextShell";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("Atlas v2 workspace shell", () => {
  it.each([
    "schools",
    "ingredients-suppliers",
    "recipes",
    "planning",
    "procurement",
    "pxk",
    "reconciliation",
  ] as const)(
    "exposes %s through the registry launcher with truthful open indication",
    async (activeModule) => {
      render(
        <AtlasVNextProvider>
          <AtlasVNextShell activeModule={activeModule}>
            <h1>Current job</h1>
          </AtlasVNextShell>
        </AtlasVNextProvider>,
      );
      fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
      const launcher = await screen.findByRole("dialog", {
        name: "Bàn làm việc",
      });
      const active = within(launcher).getByRole("button", { current: "page" });
      expect(within(active).getByText("Đang mở")).toBeVisible();
      expect(within(launcher).getAllByRole("button")).toHaveLength(7);
      expect(screen.queryByRole("complementary")).not.toBeInTheDocument();
      expect(
        screen.getByRole("heading", { name: "Current job" }),
      ).toBeVisible();
    },
  );

  it("searches local labels, gives no-result feedback, traverses by keyboard, and restores focus on Escape", async () => {
    const navigate = vi.fn();
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell onNavigate={navigate}>
          <h1>Current job</h1>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    const trigger = screen.getByRole("button", { name: "Bàn làm việc" });
    fireEvent.click(trigger);
    const input = screen.getByRole("textbox", { name: "Tìm bàn làm việc" });
    expect(input).toHaveFocus();
    fireEvent.keyDown(input, { key: "ArrowUp" });
    expect(
      within(screen.getByRole("dialog", { name: "Bàn làm việc" })).getByRole(
        "button",
        { name: "Công thức" },
      ),
    ).toHaveFocus();
    input.focus();
    fireEvent.change(input, { target: { value: "khong tim thay" } });
    expect(screen.getByRole("status")).toHaveTextContent("Không tìm thấy");
    fireEvent.change(input, { target: { value: "cong thuc" } });
    const dialog = screen.getByRole("dialog", { name: "Bàn làm việc" });
    expect(within(dialog).getAllByRole("button")).toHaveLength(1);
    fireEvent.keyDown(input, { key: "ArrowDown" });
    expect(
      within(dialog).getByRole("button", { name: "Công thức" }),
    ).toHaveFocus();
    fireEvent.keyDown(dialog, { key: "Escape" });
    expect(trigger).toHaveFocus();
    expect(trigger).toHaveAttribute("aria-expanded", "false");
    expect(navigate).not.toHaveBeenCalled();
  });

  it("separates available-workbench launcher from narrow open-workbench selection and guarded close", () => {
    const navigate = vi.fn(),
      close = vi.fn();
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell
          activeModule="schools"
          openIds={["schools", "recipes"]}
          statuses={{ recipes: { unsaved: true, blocked: false } }}
          onNavigate={navigate}
          onClose={close}
        >
          <h1>Schools</h1>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    expect(screen.queryByRole("tablist")).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Đang mở: Trường học" }),
    );
    const selector = screen.getByRole("dialog", {
      name: "Bàn làm việc đang mở",
    });
    fireEvent.click(
      within(selector).getByRole("button", { name: "Công thức — Chưa lưu" }),
    );
    expect(navigate).toHaveBeenCalledWith("recipes");
    expect(
      screen.getByRole("button", { name: "Đang mở: Trường học" }),
    ).toHaveFocus();
    fireEvent.click(
      screen.getByRole("button", { name: "Đang mở: Trường học" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Đóng Công thức" }));
    expect(close).toHaveBeenCalledWith("recipes");
  });

  it("keeps user/environment/sign-out in one compact utility and out of launcher", () => {
    const signOut = vi.fn();
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell
          mode="connected"
          userLabel="operator@example.test"
          environmentLabel="Local"
          onSignOut={signOut}
        >
          <h1>Schools</h1>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
    const launcher = screen.getByRole("dialog", { name: "Bàn làm việc" });
    expect(
      within(launcher).queryByText("operator@example.test"),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Tài khoản và môi trường" }),
    );
    const account = screen.getByRole("dialog", {
      name: "Tài khoản và môi trường",
    });
    expect(within(account).getByText("operator@example.test")).toBeVisible();
    expect(within(account).getByText("Môi trường · Local")).toBeVisible();
    expect(screen.getAllByText("operator@example.test")).toHaveLength(1);
    fireEvent.click(within(account).getByRole("button", { name: "Đăng xuất" }));
    expect(signOut).toHaveBeenCalledOnce();
  });
});
describe("Atlas vNext provider", () => {
  it("uses a primary-action hover semantic independent of navigation", () => {
    const recipe = atlasSystem.getRecipe("button");
    expect(recipe.variants?.variant?.businessPrimary).toMatchObject({
      _hover: { bg: "action.primary.hover" },
    });
    expect(atlasSystem.token.var("colors.action.primary.hover")).not.toBe(
      atlasSystem.token.var("colors.bg.navigationHover"),
    );
  });
  it("keeps scoped component styles above legacy unlayered element rules in Storybook", () => {
    expect(atlasSystem._config.disableLayers).toBe(true);
  });
  it("supplies the Atlas system to Chakra children inside the scoped root", () => {
    function Probe() {
      const system = useChakraContext();
      return (
        <Box bg="bg.workspace">{system.token.var("colors.bg.workspace")}</Box>
      );
    }
    render(
      <AtlasVNextProvider>
        <Probe />
      </AtlasVNextProvider>,
    );
    const child = screen.getByText("var(--atlas-colors-bg-workspace)");
    expect(child.closest(".atlas-vnext")).toBeInTheDocument();
    expect(atlasSystem.token("colors.atlas.workspace")).toBe("#EDF0ED");
  });

  it("scopes resets, globals and variables without adopting global html/body selectors", () => {
    expect(atlasSystem._config.cssVarsRoot).toBe(".atlas-vnext");
    expect(atlasSystem._config.preflight).toEqual({
      scope: ":where(.atlas-vnext)",
    });
    expect(Object.keys(atlasSystem._config.globalCss ?? {})).toEqual([
      ".atlas-vnext",
    ]);
    const reset = atlasSystem.getPreflightCss();
    expect(Object.keys(reset)).toEqual([
      ":where(.atlas-vnext)",
      ":where(.atlas-vnext) ",
    ]);
    const variables = atlasSystem.getTokenCss();
    expect(
      Object.keys(variables).every((selector) =>
        selector.includes(".atlas-vnext"),
      ),
    ).toBe(true);
  });
});
