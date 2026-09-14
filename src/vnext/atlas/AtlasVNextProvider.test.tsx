import "@testing-library/jest-dom/vitest";
import { Portal } from "@chakra-ui/react";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import * as atlas from "./AtlasVNextProvider";

afterEach(cleanup);

it("provides exactly one Atlas-scoped destination for Chakra portals", async () => {
  expect(atlas).toHaveProperty("useAtlasPortalContainer");
  function Probe() {
    const container = atlas.useAtlasPortalContainer();
    return (
      <Portal container={container}>
        <p>Scoped popup probe</p>
      </Portal>
    );
  }
  const { container } = render(
    <atlas.AtlasVNextProvider>
      <Probe />
    </atlas.AtlasVNextProvider>,
  );
  await waitFor(() =>
    expect(screen.getByText("Scoped popup probe")).toBeVisible(),
  );
  const roots = container.querySelectorAll("[data-atlas-portal-root]");
  expect(roots).toHaveLength(1);
  expect(container.querySelectorAll(".atlas-vnext")).toHaveLength(1);
  expect(roots[0].parentElement).toHaveClass("atlas-vnext");
  expect(roots[0]).toContainElement(screen.getByText("Scoped popup probe"));
});
