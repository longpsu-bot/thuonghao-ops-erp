import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { useRef, useState } from "react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { SchoolPxkDirtyExitDialog } from "./SchoolPxkDirtyExitDialog";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

it("does not steal later external focus when Cancel finishes exiting", async () => {
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
  const resolveDestination = vi.fn();
  function Harness() {
    const [open, setOpen] = useState(true);
    const target = useRef<HTMLButtonElement>(null);
    return (
      <AtlasVNextProvider>
        <button ref={target} key={String(open)}>
          Date destination
        </button>
        <button>Later operator destination</button>
        <SchoolPxkDirtyExitDialog
          open={open}
          onCancel={() => setOpen(false)}
          onDiscard={() => setOpen(false)}
          finalFocusEl={() => {
            resolveDestination();
            return target.current;
          }}
        />
      </AtlasVNextProvider>
    );
  }
  render(<Harness />);
  const dialog = await screen.findByRole("dialog");
  await waitFor(() =>
    expect(dialog.contains(document.activeElement)).toBe(true),
  );
  fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
  await waitFor(() => expect(dialog).toHaveAttribute("data-state", "closed"));
  const onward = screen.getByText("Later operator destination");
  onward.focus();
  expect(onward).toHaveFocus();
  await waitFor(() =>
    expect(
      !dialog.isConnected || dialog.style.animationFillMode === "forwards",
    ).toBe(true),
  );
  const beforeExit = resolveDestination.mock.calls.length;
  fireEvent(dialog, new Event("animationcancel", { bubbles: true }));
  await waitFor(() => expect(dialog).not.toBeInTheDocument());
  await waitFor(() =>
    expect(resolveDestination.mock.calls.length).toBeGreaterThan(beforeExit),
  );
  expect(onward).toHaveFocus();
});
