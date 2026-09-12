import "@testing-library/jest-dom/vitest";
import { Box, useChakraContext } from "@chakra-ui/react";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { atlasSystem } from "./system";
import { AtlasVNextShell } from "./AtlasVNextShell";

afterEach(cleanup);

describe("Atlas vNext shell", () => {
  it("marks the review-only Ingredient and Supplier module active", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="Nguyên liệu và Nhà cung ứng">
          <p>Ingredient and Supplier review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    expect(
      screen.getByRole("button", { name: "Nguyên liệu và Nhà cung ứng" }),
    ).toHaveAttribute("aria-current", "page");
  });
  it("marks the review-only School module active", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="Trường học">
          <p>School defaults review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    expect(screen.getByRole("button", { name: "Trường học" })).toHaveAttribute(
      "aria-current",
      "page",
    );
  });
  it("marks the review-only reconciliation job active", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="Đối chiếu PO / Phiếu xuất kho">
          <p>Reconciliation review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    expect(
      screen.getByRole("button", { name: "Đối chiếu PO / Phiếu xuất kho" }),
    ).toHaveAttribute("aria-current", "page");
    expect(
      screen.getByRole("button", { name: "Phiếu xuất kho" }),
    ).not.toHaveAttribute("aria-current");
  });
  it("marks the review-only School PXK module active", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="Phiếu xuất kho">
          <p>PXK review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    expect(
      screen.getByRole("button", { name: "Phiếu xuất kho" }),
    ).toHaveAttribute("aria-current", "page");
    expect(
      screen.getByRole("button", { name: "Kế hoạch mua hàng" }),
    ).not.toHaveAttribute("aria-current");
  });
  it("marks Planning active when composing its review workbench", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="Lập nhu cầu">
          <p>Thực đơn</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    expect(screen.getByRole("button", { name: "Lập nhu cầu" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(
      screen.getByRole("button", { name: "Kế hoạch mua hàng" }),
    ).not.toHaveAttribute("aria-current");
  });
  it("has one main and one semantic navigation with an explicit active page", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell>
          <p>Phạm vi công việc</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    expect(screen.getAllByRole("main")).toHaveLength(1);
    expect(
      within(screen.getByRole("main")).getByText("Phạm vi công việc"),
    ).toBeInTheDocument();
    // jsdom uses the base/mobile CSS; desktop visibility is verified in browser.
    fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
    const nav = screen.getByRole("navigation", { name: "Điều hướng Atlas" });
    expect(
      within(nav).getByRole("button", { name: "Kế hoạch mua hàng" }),
    ).toHaveAttribute("aria-current", "page");
    const activeStyle = getComputedStyle(
      within(nav).getByRole("button", { name: "Kế hoạch mua hàng" }),
    );
    // jsdom retains CSS var fallbacks; browser verifies the resolved 3px rail.
    expect(activeStyle.borderLeftWidth).toBe("var(--atlas-layout-rail, 3px)");
    expect(activeStyle.borderLeftColor).toBe(
      "var(--atlas-colors-border-accent)",
    );
    expect(within(nav).queryByText("Tổng quan")).not.toBeInTheDocument();
  });
  it("provides a keyboard-reachable mobile toggle and returns focus on Escape", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell>
          <p>Nội dung</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    const toggle = screen.getByRole("button", { name: "Mở điều hướng" });
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    toggle.focus();
    expect(toggle).toHaveFocus();
    fireEvent.click(toggle);
    expect(toggle).toHaveAttribute("aria-expanded", "true");
    const nav = screen.getByRole("navigation");
    expect(toggle.getAttribute("aria-controls")).toBe(nav.id);
    fireEvent.keyDown(nav, { key: "Escape" });
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    expect(toggle).toHaveFocus();
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
    expect(atlasSystem.token("colors.atlas.workspace")).toBe("#F2F4F2");
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
