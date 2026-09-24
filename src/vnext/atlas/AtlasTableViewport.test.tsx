import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen, within } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { AtlasTableViewport } from "./AtlasTableViewport";
import { AtlasVNextProvider } from "./AtlasVNextProvider";

afterEach(cleanup);

it("creates a named keyboard-reachable local scroll region", () => {
  render(
    <AtlasVNextProvider>
      <AtlasTableViewport label="Danh sách kiểm tra">
        <table>
          <tbody>
            <tr>
              <td>Nội dung</td>
            </tr>
          </tbody>
        </table>
      </AtlasTableViewport>
    </AtlasVNextProvider>,
  );

  const region = screen.getByRole("region", { name: "Danh sách kiểm tra" });
  expect(region).toHaveAttribute("tabindex", "0");
  expect(region).toHaveStyle({ overflow: "auto" });
  region.focus();
  expect(region).toHaveFocus();
  expect(within(region).getByText("Nội dung")).toBeVisible();
});
