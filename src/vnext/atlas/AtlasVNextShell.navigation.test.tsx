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
import { capacityDestinations } from "./AtlasWorkspaceCapacity.stories";

beforeEach(() =>
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue({
      matches: true,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  ),
);
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

it("uses stable IDs, selects via the launcher, and restores trigger focus", async () => {
  const navigate = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="schools" onNavigate={navigate}>
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  const trigger = screen.getByRole("button", { name: "Bàn làm việc" });
  expect(trigger).toHaveAttribute("title", "Bàn làm việc");
  expect(trigger.textContent).toBe("");
  expect(screen.getByRole("banner").firstElementChild).toBe(trigger);
  fireEvent.click(trigger);
  const launcher = screen.getByRole("dialog", { name: "Bàn làm việc" });
  expect(within(launcher).getByText("Bàn làm việc")).toBeVisible();
  expect(
    within(launcher).getByRole("button", { name: "Trường học" }),
  ).toHaveAttribute("aria-current", "page");
  fireEvent.click(within(launcher).getByRole("button", { name: "Công thức" }));
  expect(navigate).toHaveBeenCalledExactlyOnceWith("recipes");
  expect(trigger).toHaveAttribute("aria-expanded", "false");
  expect(trigger).toHaveFocus();
});

it("retains the injected Vietnam clock and one account/environment utility", () => {
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
  expect(screen.getByText("Hôm nay: 13/09/2026")).toBeVisible();
  fireEvent.click(
    screen.getByRole("button", { name: "Tài khoản và môi trường" }),
  );
  const account = screen.getByRole("dialog", {
    name: "Tài khoản và môi trường",
  });
  expect(within(account).getByText("Môi trường · Staging")).toBeVisible();
  expect(screen.getAllByText("operator@example.test")).toHaveLength(1);
  fireEvent.click(within(account).getByRole("button", { name: "Đăng xuất" }));
  expect(signOut).toHaveBeenCalledOnce();
});

it("uses attached tabs with roving Arrow/Home/End and Delete guarded close", () => {
  const navigate = vi.fn(),
    close = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell
        activeModule="schools"
        openIds={["schools", "planning", "procurement"]}
        onNavigate={navigate}
        onClose={close}
      >
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  const school = screen.getByRole("tab", { name: "Trường học" });
  expect(school).toHaveAttribute("tabindex", "0");
  expect(screen.getByRole("tab", { name: "Thực đơn" })).toHaveAttribute(
    "tabindex",
    "-1",
  );
  fireEvent.keyDown(school, { key: "ArrowRight" });
  expect(navigate).toHaveBeenLastCalledWith("planning");
  expect(screen.getByRole("tab", { name: "Thực đơn" })).toHaveFocus();
  fireEvent.keyDown(school, { key: "End" });
  expect(navigate).toHaveBeenLastCalledWith("procurement");
  fireEvent.keyDown(screen.getByRole("tab", { name: "Phân bổ NCC" }), {
    key: "Home",
  });
  expect(navigate).toHaveBeenLastCalledWith("schools");
  fireEvent.keyDown(school, { key: "Delete" });
  expect(close).toHaveBeenCalledExactlyOnceWith("schools");
});

it("opens launcher without changing workspace geometry and removes the primary rail", () => {
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell>
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  expect(screen.queryByRole("complementary")).not.toBeInTheDocument();
  const main = screen.getByRole("main"),
    before = main.getAttribute("class");
  const tabs = screen.getByRole("tablist", { name: "Bàn làm việc đang mở" });
  expect(getComputedStyle(tabs).overflowX).toBe("auto");
  fireEvent.click(screen.getByRole("button", { name: "Bàn làm việc" }));
  expect(main.getAttribute("class")).toBe(before);
  expect(screen.getByRole("dialog", { name: "Bàn làm việc" })).toBeVisible();
});

it("keeps all twelve test destinations reachable on desktop and in the narrow selector", () => {
  const navigate = vi.fn();
  const props = {
    destinations: capacityDestinations,
    openIds: capacityDestinations.map((w) => w.id),
    activeModule: capacityDestinations[0]!.id,
    onNavigate: navigate,
  };
  const { unmount } = render(
    <AtlasVNextProvider>
      <AtlasVNextShell {...props}>
        <h1>Capacity</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  expect(screen.getAllByRole("tab")).toHaveLength(12);
  fireEvent.keyDown(screen.getAllByRole("tab")[0]!, { key: "End" });
  expect(navigate).toHaveBeenLastCalledWith(capacityDestinations[11]!.id);
  unmount();
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue({
      matches: false,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  );
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell {...props}>
        <h1>Capacity</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  fireEvent.click(
    screen.getByRole("button", {
      name: `Đang mở: ${capacityDestinations[0]!.label}`,
    }),
  );
  const selector = screen.getByRole("dialog", { name: "Bàn làm việc đang mở" });
  for (const item of capacityDestinations) {
    expect(
      within(selector).getByRole("button", { name: item.label }),
    ).toBeVisible();
    expect(
      within(selector).getByRole("button", { name: `Đóng ${item.label}` }),
    ).toBeVisible();
  }
});
