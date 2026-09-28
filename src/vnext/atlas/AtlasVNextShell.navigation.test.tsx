import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextShell } from "./AtlasVNextShell";

beforeEach(() => {
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockImplementation((query: string) => ({
      matches: query === "(min-width: 64rem)",
      media: query,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  );
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

it("uses stable IDs, invokes navigation, and closes the overlay menu", async () => {
  const navigate = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="schools" onNavigate={navigate}>
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  const toggle = screen.getByRole("button", { name: "Mở điều hướng Atlas" });
  fireEvent.click(toggle);
  const menu = await screen.findByRole("dialog", { name: "Điều hướng Atlas" });
  expect(
    within(menu).getByRole("button", { name: "Trường học" }),
  ).toHaveAttribute("aria-current", "page");
  fireEvent.click(within(menu).getByRole("button", { name: "Công thức" }));
  expect(navigate).toHaveBeenCalledExactlyOnceWith("recipes");
  await waitFor(() => expect(toggle).toHaveAttribute("aria-expanded", "false"));
  expect(toggle).toHaveFocus();
});

it("shows safe connected context and the injected Vietnam date across UTC midnight", () => {
  const signOut = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell
        mode="connected"
        now={new Date("2026-09-12T18:00:00Z")}
        userLabel="operator@example.test"
        environmentLabel="Staging"
        onSignOut={signOut}
      >
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  expect(screen.getByText("Hôm nay: 13/09/2026")).toBeInTheDocument();
  expect(screen.queryByText("Vận hành trường học")).not.toBeInTheDocument();
  expect(screen.getByText("operator@example.test")).toBeInTheDocument();
  expect(screen.queryByText(/Bản tham chiếu/)).not.toBeInTheDocument();
  expect(screen.queryByText(/10\/09\/2026/)).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
  expect(signOut).toHaveBeenCalledOnce();
});

it("keeps a 72px desktop rail and opens a 272px overlay without changing the workspace width", async () => {
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell onNavigate={vi.fn()}>
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  const rail = screen.getByRole("complementary", {
    name: "Điều hướng nhanh Atlas",
  });
  expect(rail).toHaveStyle({
    width: "var(--atlas-layout-nav-rail-width, 72px)",
  });
  expect(
    within(rail).getByRole("button", { name: "Kế hoạch mua hàng" }),
  ).toHaveAttribute("aria-current", "page");
  const planning = within(rail).getByRole("button", { name: "Lập nhu cầu" });
  fireEvent.focus(planning);
  expect(
    await screen.findByRole("tooltip", { name: "Lập nhu cầu" }),
  ).toBeVisible();
  fireEvent.blur(planning);
  await waitFor(() =>
    expect(
      screen.queryByRole("tooltip", { name: "Lập nhu cầu" }),
    ).not.toBeInTheDocument(),
  );
  const workspace = screen.getByRole("main").parentElement!;
  const before = workspace.getAttribute("style");
  fireEvent.click(
    within(rail).getByRole("button", { name: "Mở điều hướng Atlas" }),
  );
  const dialog = await screen.findByRole("dialog", {
    name: "Điều hướng Atlas",
  });
  expect(dialog).toHaveStyle({
    width: "var(--atlas-layout-nav-drawer-width, 272px)",
  });
  expect(workspace.getAttribute("style")).toBe(before);
});
