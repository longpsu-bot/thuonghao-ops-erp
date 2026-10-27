import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { useRef, useState } from "react";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import type { PantrySchool } from "../bridges/planning";
import { createPlanningReviewFixture } from "./planningReviewFixtures";
import { PantrySchoolChooser } from "./PantrySchoolChooser";

beforeEach(() =>
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  ),
);
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
const schools: PantrySchool[] = Array.from({ length: 50 }, (_, i) => ({
  ...createPlanningReviewFixture().pantry.schools[0]!,
  school_id: `school-${i}`,
  school_code: `TH-${i}`,
  school_name: i >= 47 ? "Trường Nguyễn Du" : `Trường ${i}`,
  school_status: i === 49 ? "INACTIVE" : "ACTIVE",
}));
function Example({
  catalog = schools,
  disabled = false,
  change,
}: {
  catalog?: PantrySchool[];
  disabled?: boolean;
  change: (id: string) => void;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [value, setValue] = useState("");
  return (
    <AtlasVNextProvider>
      <PantrySchoolChooser
        inputRef={input}
        schools={catalog}
        disabled={disabled}
        value={value}
        onChange={(id) => {
          change(id);
          setValue(id);
        }}
      />
      <button>Tiếp theo</button>
    </AtlasVNextProvider>
  );
}
it("searches fifty Schools by accent-folded name/reference and commits only the exact eligible UUID", async () => {
  const change = vi.fn();
  render(<Example change={change} />);
  const input = screen.getByRole("combobox", { name: "Trường cần thêm hàng" });
  fireEvent.focus(input);
  expect(await screen.findAllByRole("option")).toHaveLength(40);
  fireEvent.change(input, { target: { value: "nguyen du" } });
  expect(input).toHaveValue("nguyen du");
  expect(screen.getAllByRole("option")).toHaveLength(3);
  expect(screen.getByRole("option", { name: /TH-49/ })).toHaveAttribute(
    "aria-disabled",
    "true",
  );
  expect(change).not.toHaveBeenCalled();
  fireEvent.keyDown(input, { key: "ArrowDown" });
  fireEvent.keyDown(input, { key: "ArrowDown" });
  fireEvent.keyDown(input, { key: "Enter" });
  expect(change).toHaveBeenCalledExactlyOnceWith("school-48");
  expect(input).toHaveValue("Trường Nguyễn Du");
  fireEvent.click(input);
  fireEvent.change(input, { target: { value: "NO MATCH" } });
  expect(screen.getByRole("status")).toHaveTextContent(
    "Không tìm thấy trường phù hợp",
  );
  fireEvent.keyDown(input, { key: "Escape" });
  expect(input).toHaveValue("Trường Nguyễn Du");
  fireEvent.click(input);
  fireEvent.change(input, { target: { value: "TH-47" } });
  fireEvent.pointerDown(screen.getByRole("option", { name: /TH-47/ }));
  fireEvent.click(screen.getByRole("option", { name: /TH-47/ }));
  expect(change).toHaveBeenLastCalledWith("school-47");
  fireEvent.click(input);
  fireEvent.change(input, { target: { value: "another query" } });
  fireEvent.keyDown(input, { key: "Tab" });
  expect(input).toHaveValue("Trường Nguyễn Du");
  expect(change).toHaveBeenCalledTimes(2);
});
it("retains highlighted UUID through reorder and rejects removed, inactive or disabled targets", async () => {
  const change = vi.fn();
  const rows = schools.slice(47);
  const view = render(<Example change={change} catalog={rows} />);
  const input = screen.getByRole("combobox");
  fireEvent.focus(input);
  fireEvent.keyDown(input, { key: "ArrowDown" });
  view.rerender(
    <Example change={change} catalog={[rows[1]!, rows[0]!, rows[2]!]} />,
  );
  fireEvent.keyDown(input, { key: "Enter" });
  expect(change).toHaveBeenCalledExactlyOnceWith("school-47");
  fireEvent.click(input);
  fireEvent.keyDown(input, { key: "ArrowDown" });
  view.rerender(
    <Example
      change={change}
      catalog={rows.filter((row) => row.school_id !== "school-48")}
    />,
  );
  fireEvent.keyDown(input, { key: "Enter" });
  expect(change).toHaveBeenCalledTimes(1);
  view.rerender(
    <Example
      change={change}
      catalog={rows.map((row) => ({ ...row, school_status: "INACTIVE" }))}
    />,
  );
  fireEvent.keyDown(input, { key: "Enter" });
  fireEvent.click(await screen.findByRole("option", { name: /TH-48/ }));
  expect(change).toHaveBeenCalledTimes(1);
  view.rerender(<Example change={change} disabled />);
  expect(input).toBeDisabled();
  await waitFor(() =>
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument(),
  );
});

it("keeps an imported School reference searchable without showing it to operators", async () => {
  const change = vi.fn();
  const imported: PantrySchool = {
    ...schools[0]!,
    school_id: "school-imported",
    school_code: "v1-school-11",
    school_name: "ĐẤT CUỐC",
  };
  render(<Example change={change} catalog={[imported]} />);
  const input = screen.getByRole("combobox");
  fireEvent.focus(input);
  fireEvent.change(input, { target: { value: "v1-school-11" } });
  const option = await screen.findByRole("option");
  expect(option).toHaveTextContent("ĐẤT CUỐC");
  expect(option).not.toHaveTextContent("v1-school-11");
});
