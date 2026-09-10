import "@testing-library/jest-dom/vitest";
import { Box, useChakraContext } from "@chakra-ui/react";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { atlasSystem } from "./system";

afterEach(cleanup);

describe("Atlas vNext provider", () => {
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
    expect(atlasSystem.token("colors.atlas.workspace")).toBe("#f4f1eb");
  });

  it("scopes resets, globals and variables without adopting global html/body selectors", () => {
    expect(atlasSystem._config.cssVarsRoot).toBe(".atlas-vnext");
    expect(atlasSystem._config.preflight).toEqual({ scope: ".atlas-vnext" });
    expect(Object.keys(atlasSystem._config.globalCss ?? {})).toEqual([
      ".atlas-vnext",
    ]);
    const reset = atlasSystem.getPreflightCss()["@layer reset"];
    expect(Object.keys(reset)).toEqual([".atlas-vnext", ".atlas-vnext "]);
  });
});
