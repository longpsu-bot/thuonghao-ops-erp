import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { MantineProvider } from "@mantine/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import { atlasTheme } from "../../../theme";
import { PlanningSchoolScopeControl } from "./PlanningSchoolScopeControl";
import {
  normalizePlanningSchoolScope,
  planningSchoolScopeLabel,
} from "./planningSchoolScope";

afterEach(cleanup);

const schools = [
  {
    school_id: "review-planning-school-2",
    school_code: "TH002",
    school_name: "Trường Tiểu học Trần Quốc Toản",
    display_order: 2,
  },
  {
    school_id: "review-planning-school-1",
    school_code: "TH001",
    school_name: "Trường Tiểu học Nguyễn Du",
    display_order: 1,
  },
  {
    school_id: "review-planning-school-3",
    school_code: "TH003",
    school_name: "Trường Mầm non Hoa Hồng",
    display_order: 3,
  },
];

function renderControl(selectedSchoolIds: string[] = [], onChange = vi.fn()) {
  render(
    <MantineProvider theme={atlasTheme} env="test">
      <PlanningSchoolScopeControl
        schools={schools}
        selectedSchoolIds={selectedSchoolIds}
        onChange={onChange}
      />
    </MantineProvider>,
  );
  return onChange;
}

describe("Planning school display scope", () => {
  it("normalizes invalid, duplicate, and all-school selections", () => {
    expect(normalizePlanningSchoolScope([], schools)).toEqual([]);
    expect(
      normalizePlanningSchoolScope(
        ["missing", "review-planning-school-2", "review-planning-school-2"],
        schools,
      ),
    ).toEqual(["review-planning-school-2"]);
    expect(
      normalizePlanningSchoolScope(
        schools.map((school) => school.school_id),
        schools,
      ),
    ).toEqual([]);
    expect(normalizePlanningSchoolScope(["missing"], schools)).toEqual([]);
  });

  it("labels all, one, and arbitrary multi-school scopes", () => {
    expect(planningSchoolScopeLabel([], schools)).toBe("Tất cả trường");
    expect(
      planningSchoolScopeLabel(["review-planning-school-1"], schools),
    ).toBe("Trường Tiểu học Nguyễn Du");
    expect(
      planningSchoolScopeLabel(
        ["review-planning-school-1", "review-planning-school-3"],
        schools,
      ),
    ).toBe("2 trường");
  });

  it("searches by Vietnamese school name and school code", () => {
    renderControl();
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));

    fireEvent.change(screen.getByRole("searchbox", { name: "Tìm trường" }), {
      target: { value: "Hoa Hồng" },
    });
    expect(screen.getByRole("checkbox", { name: /Hoa Hồng/ })).toBeVisible();
    expect(
      screen.queryByRole("checkbox", { name: /Nguyễn Du/ }),
    ).not.toBeInTheDocument();

    fireEvent.change(screen.getByRole("searchbox", { name: "Tìm trường" }), {
      target: { value: "TH001" },
    });
    expect(screen.getByRole("checkbox", { name: /Nguyễn Du/ })).toBeVisible();
  });

  it("applies an arbitrary draft subset and normalizes every school to external all", () => {
    const onChange = renderControl(["review-planning-school-1"], vi.fn());
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("checkbox", { name: /Trần Quốc Toản/ }));
    expect(onChange).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(onChange).toHaveBeenLastCalledWith([
      "review-planning-school-1",
      "review-planning-school-2",
    ]);

    cleanup();
    const selectLast = renderControl(
      ["review-planning-school-1", "review-planning-school-2"],
      vi.fn(),
    );
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("checkbox", { name: /Hoa Hồng/ }));
    expect(selectLast).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(selectLast).toHaveBeenLastCalledWith([]);
  });

  it("keeps Bỏ chọn tất cả as invalid draft UI state", () => {
    const onChange = renderControl([], vi.fn());
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("button", { name: "Bỏ chọn tất cả" }));

    expect(screen.getByText("Chọn ít nhất một trường")).toBeVisible();
    expect(screen.getByRole("button", { name: "Áp dụng" })).toBeDisabled();
    expect(onChange).not.toHaveBeenCalled();
    for (const checkbox of screen.getAllByRole("checkbox"))
      expect(checkbox).not.toBeChecked();
  });

  it("returns to external all-school scope through Chọn tất cả and Áp dụng", () => {
    const onChange = renderControl(
      ["review-planning-school-1", "review-planning-school-3"],
      vi.fn(),
    );
    expect(
      screen.getByRole("button", { name: "Phạm vi trường" }),
    ).toHaveTextContent("2 trường");
    fireEvent.click(screen.getByRole("button", { name: "Phạm vi trường" }));
    fireEvent.click(screen.getByRole("button", { name: "Chọn tất cả" }));
    expect(onChange).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(onChange).toHaveBeenLastCalledWith([]);
  });
});
