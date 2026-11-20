import "@testing-library/jest-dom/vitest";
import { Portal } from "@chakra-ui/react";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import * as atlas from "./AtlasVNextProvider";

afterEach(cleanup);

it("selects editable cell contents on entry and leaves the caret available for later clicks", () => {
  render(
    <atlas.AtlasVNextProvider>
      <table>
        <tbody>
          <tr>
            <td>
              <input aria-label="Note" defaultValue="Lunch" />
            </td>
          </tr>
        </tbody>
      </table>
      <input aria-label="Quantity" inputMode="decimal" defaultValue="10.25" />
      <input aria-label="Filter" defaultValue="North" />
    </atlas.AtlasVNextProvider>,
  );
  for (const label of ["Note", "Quantity"]) {
    const input = screen.getByLabelText<HTMLInputElement>(label);
    input.focus();
    expect([input.selectionStart, input.selectionEnd]).toEqual([
      0,
      input.value.length,
    ]);
    input.setSelectionRange(2, 2);
    input.click();
    expect([input.selectionStart, input.selectionEnd]).toEqual([2, 2]);
  }
  const filter = screen.getByLabelText<HTMLInputElement>("Filter");
  filter.setSelectionRange(1, 1);
  filter.focus();
  expect([filter.selectionStart, filter.selectionEnd]).toEqual([1, 1]);
});

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
