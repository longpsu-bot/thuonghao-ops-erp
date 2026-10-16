import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import type { AllocationFamilyRow } from "../bridges/procurement";
import { ProcurementAllocationTable } from "./ProcurementAllocationTable";
import { reviewFamily } from "./procurementReviewFixtures";

afterEach(cleanup);

function row(
  id: string,
  ingredient: string,
  state: AllocationFamilyRow["state"],
  need: string,
  allocated?: string,
): AllocationFamilyRow {
  const fixture = reviewFamily("normal");
  return {
    ...fixture,
    family: { ...fixture.family, source_fingerprint: id },
    ingredient_id: id,
    ingredient_name: ingredient,
    state,
    family_quantity: need,
    recommendation: null,
    splits: allocated
      ? [
          {
            supplier_split_id: `${id}-split`,
            supplier_id: "supplier-a",
            supplier_name: "NCC An Phú",
            allocated_quantity: allocated,
            supplier_note: null,
            split_ratio: "1.000000000000",
          },
        ]
      : [],
  };
}

function visibleIssues() {
  const table = screen.getByRole("table", { name: "Phân bổ nhà cung ứng" });
  return within(table)
    .getAllByRole("row")
    .slice(1)
    .map((tableRow) =>
      tableRow
        .querySelector("[data-allocation-issue]")!
        .textContent!.replace("⚠", "")
        .trim(),
    );
}

describe("Procurement allocation issue sorting", () => {
  it("keeps all five sort actions reachable, resets canonical order and returns the exact family", () => {
    const first = row(
      "first",
      "Bí đỏ",
      "UNALLOCATED",
      "9007199254740993.000001",
    );
    const select = vi.fn();
    render(
      <AtlasVNextProvider>
        <ProcurementAllocationTable
          rows={[first, row("second", "Gạo", "BALANCED", "2", "2")]}
          selectedKey={null}
          disabled={false}
          onSelect={select}
        />
      </AtlasVNextProvider>,
    );
    const sorts = within(
      screen.getByRole("group", { name: "Sắp xếp phân bổ nhà cung ứng" }),
    );
    for (const label of [
      "Trường / điểm giao",
      "Nguyên liệu",
      "Nhu cầu",
      "Nhà cung ứng",
      "Tình trạng / vấn đề",
    ]) {
      const button = sorts.getByRole("button", {
        name: `Sắp xếp theo ${label}`,
      });
      expect(button).toBeVisible();
      fireEvent.click(button);
      expect(button).toHaveAttribute("aria-pressed", "true");
      fireEvent.click(button);
      fireEvent.click(button);
      expect(button).toHaveAttribute("aria-pressed", "false");
    }
    const family = screen.getByText("Bí đỏ").closest("tr")!;
    expect(family).toHaveTextContent("9007199254740993,000001");
    fireEvent.click(
      within(family).getByRole("button", { name: /Phân bổ NCC Bí đỏ/ }),
    );
    expect(select.mock.lastCall![0]).toBe(first);
  });
  it("keeps daily families separate and makes an explicit Ingredient sort primary across dates", () => {
    const first = {
      ...row("first", "Bí đỏ", "UNALLOCATED", "1"),
      service_date: "2026-10-12",
    };
    const second = {
      ...row("second", "Bí đỏ", "UNALLOCATED", "2"),
      ingredient_id: first.ingredient_id,
      service_date: "2026-10-13",
    };
    const sameDay = {
      ...row("same-day", "Gạo", "UNALLOCATED", "3"),
      service_date: "2026-10-12",
    };
    const select = vi.fn();
    render(
      <AtlasVNextProvider>
        <ProcurementAllocationTable
          rows={[second, first, sameDay]}
          selectedKey={null}
          disabled={false}
          onSelect={select}
        />
      </AtlasVNextProvider>,
    );
    expect(
      screen.getByRole("group", { name: "Sắp xếp phân bổ nhà cung ứng" }),
    ).toBeVisible();
    const dates = () =>
      within(screen.getByRole("table"))
        .getAllByRole("row")
        .slice(1)
        .map((item) =>
          item
            .querySelector("[data-allocation-date]")!
            .textContent!.replace("Ngày dùng ", ""),
        );
    const ingredients = () =>
      within(screen.getByRole("table"))
        .getAllByRole("row")
        .slice(1)
        .map(
          (item) =>
            item.querySelector("[data-allocation-ingredient]")!.textContent,
        );
    expect(ingredients()).toEqual(["Bí đỏ", "Bí đỏ", "Gạo"]);
    expect(dates()).toEqual(["12/10/2026", "13/10/2026", "12/10/2026"]);
    fireEvent.click(
      screen.getByRole("button", { name: "Sắp xếp theo Nguyên liệu" }),
    );
    expect(ingredients()).toEqual(["Bí đỏ", "Bí đỏ", "Gạo"]);
    expect(dates()).toEqual(["12/10/2026", "13/10/2026", "12/10/2026"]);
    fireEvent.click(
      screen.getByRole("button", {
        name: /Phân bổ NCC Bí đỏ.*13\/10\/2026/,
      }),
    );
    expect(select.mock.lastCall![0]).toBe(second);
  });
  it("sorts by the visible exact-remainder issue label in both directions", () => {
    render(
      <AtlasVNextProvider>
        <ProcurementAllocationTable
          rows={[
            row("balanced", "Gạo", "BALANCED", "1.000000", "1.000000"),
            row(
              "missing",
              "Bí đỏ",
              "NEEDS_REALLOCATION",
              "9007199254740993.000000",
              "9007199254740992.000000",
            ),
            row("unallocated", "Cà rốt", "UNALLOCATED", "1.000000"),
          ]}
          selectedKey={null}
          disabled={false}
          onSelect={() => {}}
        />
      </AtlasVNextProvider>,
    );

    expect(visibleIssues()).toEqual(["Thiếu 1 kg", "Chưa phân bổ", "Đủ"]);
    const sort = screen.getByRole("button", {
      name: "Sắp xếp theo Tình trạng / vấn đề",
    });
    fireEvent.click(sort);
    expect(visibleIssues()).toEqual(["Chưa phân bổ", "Đủ", "Thiếu 1 kg"]);
    fireEvent.click(sort);
    expect(visibleIssues()).toEqual(["Thiếu 1 kg", "Đủ", "Chưa phân bổ"]);
  });

  it("presents a backend recommendation as the resolved default without replacing persisted splits", () => {
    const derived = reviewFamily("normal");
    derived.location_name = derived.school_name!;
    derived.eligible_suppliers[0]!.priority = 2;
    const persisted = {
      ...reviewFamily("manual_split"),
      family: {
        ...reviewFamily("manual_split").family,
        source_fingerprint: "persisted",
      },
      ingredient_name: "Thịt heo",
    };
    const visiblyDifferentDestination = {
      ...reviewFamily("normal"),
      family: {
        ...reviewFamily("normal").family,
        source_fingerprint: "visible-destination",
      },
      ingredient_id: "ingredient-onion",
      ingredient_name: "Hành tây",
      school_name: "AN PHÚ",
      schools: [{ school_id: "school-an-phu", school_name: "AN PHÚ" }],
      location_name: "AN PHU",
    };
    render(
      <AtlasVNextProvider>
        <ProcurementAllocationTable
          rows={[persisted, derived, visiblyDifferentDestination]}
          selectedKey={null}
          disabled={false}
          onSelect={() => {}}
        />
      </AtlasVNextProvider>,
    );

    const table = screen.getByRole("table", { name: "Phân bổ nhà cung ứng" });
    expect(
      within(table)
        .getAllByRole("columnheader")
        .slice(0, 2)
        .map((cell) => cell.textContent),
    ).toEqual(["Nhu cầu và phân bổ", "Thao tác"]);
    expect(table).toHaveStyle({ minWidth: "var(--atlas-layout-zero, 0)" });

    const derivedRow = within(table).getByText("Gạo thơm").closest("tr")!;
    expect(derivedRow).toHaveTextContent("NCC An Phú");
    expect(derivedRow).toHaveTextContent("Mặc định #2");
    expect(derivedRow).toHaveTextContent("Đủ");
    expect(derivedRow).not.toHaveTextContent("Chưa phân bổ");
    expect(derivedRow).not.toHaveAttribute("data-attention");
    expect(
      within(derivedRow).getByRole("button", { name: /^Thay đổi / }),
    ).toBeVisible();
    expect(within(derivedRow).getAllByText(derived.school_name!)).toHaveLength(
      1,
    );
    const visibleDestinationRow = within(table)
      .getByText("Hành tây")
      .closest("tr")!;
    expect(within(visibleDestinationRow).getByText("AN PHÚ")).toBeVisible();
    expect(within(visibleDestinationRow).getByText("AN PHU")).toHaveAttribute(
      "data-row-secondary",
      "",
    );

    const persistedRow = within(table).getByText("Thịt heo").closest("tr")!;
    expect(persistedRow).toHaveTextContent("NCC An Phú, NCC Bình Minh");
    expect(persistedRow).not.toHaveTextContent("Mặc định");
  });

  it("orders a date range by canonical School then Ingredient by default", () => {
    const first = {
      ...row("first", "Cà rốt", "UNALLOCATED", "1"),
      service_date: "2026-09-10",
      school_id: "school-b",
      school_name: "Trường B",
      schools: [{ school_id: "school-b", school_name: "Trường B" }],
      location_name: "Trường B",
    };
    const second = {
      ...row("second", "Gạo", "UNALLOCATED", "1"),
      service_date: "2026-09-12",
      school_id: "school-a",
      school_name: "Trường A",
      schools: [{ school_id: "school-a", school_name: "Trường A" }],
      location_name: "Trường A",
    };
    const third = {
      ...row("third", "Bí đỏ", "UNALLOCATED", "1"),
      service_date: "2026-09-11",
      school_id: "school-a",
      school_name: "Trường A",
      schools: [{ school_id: "school-a", school_name: "Trường A" }],
      location_name: "Trường A",
    };
    render(
      <AtlasVNextProvider>
        <ProcurementAllocationTable
          rows={[first, second, third]}
          selectedKey={null}
          disabled={false}
          onSelect={() => {}}
        />
      </AtlasVNextProvider>,
    );

    const bodyRows = within(screen.getByRole("table"))
      .getAllByRole("row")
      .slice(1);
    expect(
      bodyRows.map((tableRow) => {
        return `${tableRow.querySelector("[data-allocation-recipient]")!.textContent}|${tableRow.querySelector("[data-allocation-ingredient]")!.textContent}`;
      }),
    ).toEqual(["Trường A|Bí đỏ", "Trường A|Gạo", "Trường B|Cà rốt"]);
  });
});
