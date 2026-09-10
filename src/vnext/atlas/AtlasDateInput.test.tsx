import "@testing-library/jest-dom/vitest";
import { LocaleProvider } from "@chakra-ui/react";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasDateInput } from "./AtlasDateInput";
import { AtlasVNextProvider } from "./AtlasVNextProvider";

afterEach(cleanup);

describe("Atlas date convention", () => {
  it("renders leading-zero day/month/year segments despite the surrounding locale", () => {
    const { container } = render(
      <AtlasVNextProvider>
        <LocaleProvider locale="en-US">
          <AtlasDateInput
            label="Ngày phục vụ"
            value="2026-09-05"
            onValueChange={() => {}}
          />
        </LocaleProvider>
      </AtlasVNextProvider>,
    );
    expect(container.querySelector('input[type="date"]')).toBeNull();
    const segments = screen.getAllByRole("spinbutton");
    expect(
      segments.map((segment) => segment.getAttribute("data-type")),
    ).toEqual(["day", "month", "year"]);
    expect(segments.map((segment) => segment.textContent)).toEqual([
      "05",
      "09",
      "2026",
    ]);
    expect(
      container.querySelector('[data-part="segment-group"]')?.textContent,
    ).toBe("05/09/2026");
  });
  it("emits canonical business dates when a day segment is edited", async () => {
    const onValueChange = vi.fn();
    render(
      <AtlasVNextProvider>
        <AtlasDateInput
          label="Ngày phục vụ"
          value="2026-09-05"
          onValueChange={onValueChange}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.focus(screen.getAllByRole("spinbutton")[0]);
    fireEvent.keyDown(screen.getAllByRole("spinbutton")[0], { key: "ArrowUp" });
    await waitFor(() =>
      expect(onValueChange).toHaveBeenCalledWith("2026-09-06"),
    );
  });
});
