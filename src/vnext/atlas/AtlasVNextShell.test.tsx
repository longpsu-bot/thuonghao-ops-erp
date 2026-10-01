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

describe("Atlas vNext shell", () => {
  it("portals desktop rail tooltips for hover and keyboard focus, then closes them", async () => {
    vi.stubGlobal(
      "matchMedia",
      vi.fn().mockReturnValue({
        matches: true,
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
      } as unknown as MediaQueryList),
    );
    vi.stubGlobal(
      "ResizeObserver",
      class {
        observe() {}
        unobserve() {}
        disconnect() {}
      },
    );

    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="schools">
          <p>Dense workbench</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );

    const ingredients = screen.getByRole("button", {
      name: "Nguyên liệu và Nhà cung ứng",
    });
    fireEvent.keyDown(document.body, { key: "Tab" });
    ingredients.focus();
    expect(
      await screen.findByRole("tooltip", {
        name: "Nguyên liệu và Nhà cung ứng",
      }),
    ).toBeVisible();
    fireEvent.keyDown(ingredients, { key: "Escape" });
    await waitFor(() =>
      expect(
        screen.queryByRole("tooltip", {
          name: "Nguyên liệu và Nhà cung ứng",
        }),
      ).not.toBeInTheDocument(),
    );
    ingredients.blur();
    ingredients.focus();
    expect(
      await screen.findByRole("tooltip", {
        name: "Nguyên liệu và Nhà cung ứng",
      }),
    ).toBeVisible();
    ingredients.blur();
    await waitFor(() =>
      expect(
        screen.getByRole("tooltip", {
          name: "Nguyên liệu và Nhà cung ứng",
        }),
      ).toHaveAttribute("data-state", "closed"),
    );
    expect(ingredients).not.toHaveAttribute("aria-describedby");

    const school = screen.getByRole("button", { name: "Trường học" });
    fireEvent.pointerEnter(school);
    const hovered = await screen.findByRole("tooltip", {
      name: "Trường học",
    });
    expect(hovered.parentElement?.parentElement).toHaveAttribute(
      "data-atlas-portal-root",
    );
    expect(school).toHaveAttribute("aria-describedby", hovered.id);

    fireEvent.pointerLeave(school);
    await waitFor(() =>
      expect(
        screen.getByRole("tooltip", { name: "Trường học" }),
      ).toHaveAttribute("data-state", "closed"),
    );
    expect(school).not.toHaveAttribute("aria-describedby");
  });
  it("marks the review-only Ingredient and Supplier module active", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="ingredients-suppliers">
          <p>Ingredient and Supplier review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    );
    expect(
      await screen.findByRole("button", {
        name: "Nguyên liệu và Nhà cung ứng",
      }),
    ).toHaveAttribute("aria-current", "page");
  });
  it("marks the review-only School module active", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="schools">
          <p>School defaults review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    );
    expect(
      await screen.findByRole("button", { name: "Trường học" }),
    ).toHaveAttribute("aria-current", "page");
  });
  it("marks the review-only reconciliation job active", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="reconciliation">
          <p>Reconciliation review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    );
    expect(
      await screen.findByRole("button", {
        name: "Đối chiếu PO / Phiếu xuất kho",
      }),
    ).toHaveAttribute("aria-current", "page");
    expect(
      screen.getByRole("button", { name: "Phiếu xuất kho" }),
    ).not.toHaveAttribute("aria-current");
  });
  it("marks the review-only School PXK module active", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="pxk">
          <p>PXK review</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    );
    expect(
      await screen.findByRole("button", { name: "Phiếu xuất kho" }),
    ).toHaveAttribute("aria-current", "page");
    expect(
      screen.getByRole("button", { name: "Kế hoạch mua hàng" }),
    ).not.toHaveAttribute("aria-current");
  });
  it("marks Planning active when composing its review workbench", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell activeModule="planning">
          <p>Thực đơn</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    );
    expect(
      await screen.findByRole("button", { name: "Lập nhu cầu" }),
    ).toHaveAttribute("aria-current", "page");
    expect(
      screen.getByRole("button", { name: "Kế hoạch mua hàng" }),
    ).not.toHaveAttribute("aria-current");
  });
  it("has one main and one semantic navigation with an explicit active page", async () => {
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
    fireEvent.click(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    );
    const nav = await screen.findByRole("navigation", {
      name: "Điều hướng Atlas",
    });
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
  it("provides a keyboard-reachable mobile toggle and returns focus on Escape", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell>
          <p>Nội dung</p>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    const toggle = screen.getByRole("button", {
      name: "Mở điều hướng Atlas",
    });
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    toggle.focus();
    expect(toggle).toHaveFocus();
    fireEvent.click(toggle);
    expect(toggle).toHaveAttribute("aria-expanded", "true");
    const nav = await screen.findByRole("navigation");
    expect(toggle.getAttribute("aria-controls")).toBe(nav.id);
    fireEvent.keyDown(nav, { key: "Escape" });
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    await waitFor(() => expect(toggle).toHaveFocus());
  });
  it("keeps environment identity visible in the compact connected header", () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell
          mode="connected"
          environmentLabel="Local · non-production"
          userLabel="operator@example.test"
        >
          <h1>Current job</h1>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    expect(
      within(screen.getByRole("banner")).getByText(
        "Môi trường · Local · non-production",
      ),
    ).toBeVisible();
    expect(screen.getByRole("heading", { name: "Current job" })).toBeVisible();
  });
  it("retains the non-authoritative reference label in the drawer", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasVNextShell>
          <h1>Review job</h1>
        </AtlasVNextShell>
      </AtlasVNextProvider>,
    );
    expect(
      within(screen.getByRole("banner")).queryByText(/Môi trường/),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Mở điều hướng Atlas" }),
    );
    const drawer = await screen.findByRole("dialog", {
      name: "Điều hướng Atlas",
    });
    expect(
      within(drawer).getByText("Bản tham chiếu · Dữ liệu minh họa"),
    ).toBeVisible();
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
