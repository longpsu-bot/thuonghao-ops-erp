import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasVNextShell } from "./AtlasVNextShell";

afterEach(cleanup);

it("uses stable IDs, invokes navigation, and closes the mobile menu", async () => {
  const navigate = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="schools" onNavigate={navigate}>
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  const toggle = screen.getByRole("button", { name: "Mở điều hướng" });
  fireEvent.click(toggle);
  expect(
    await screen.findByRole("button", { name: "Trường học" }),
  ).toHaveAttribute("aria-current", "page");
  fireEvent.click(screen.getByRole("button", { name: "Công thức" }));
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
  expect(screen.getByText("Chủ nhật, 13/09/2026")).toBeInTheDocument();
  expect(screen.getByText("operator@example.test")).toBeInTheDocument();
  expect(screen.queryByText(/Bản tham chiếu/)).not.toBeInTheDocument();
  expect(screen.queryByText(/10\/09\/2026/)).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Đăng xuất" }));
  expect(signOut).toHaveBeenCalledOnce();
});

it("opens mobile navigation in a keyboard-contained drawer", async () => {
  render(
    <AtlasVNextProvider>
      <AtlasVNextShell onNavigate={vi.fn()}>
        <h1>Schools</h1>
      </AtlasVNextShell>
    </AtlasVNextProvider>,
  );
  fireEvent.click(screen.getByRole("button", { name: "Mở điều hướng" }));
  expect(
    await screen.findByRole("dialog", { name: "Điều hướng Atlas" }),
  ).toBeInTheDocument();
});
