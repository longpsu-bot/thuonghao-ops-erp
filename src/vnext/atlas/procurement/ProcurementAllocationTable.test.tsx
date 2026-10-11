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
      within(tableRow)
        .getAllByRole("cell")[4]!
        .textContent!.replace("⚠", "")
        .trim(),
    );
}

describe("Procurement allocation issue sorting", () => {
  it("keeps daily families separate and dates primary when sorting ingredients", () => {
    const first = {
      ...row("first", "Gạo", "UNALLOCATED", "1"),
      service_date: "2026-10-12",
    };
    const second = {
      ...row("second", "Gạo", "UNALLOCATED", "2"),
      ingredient_id: first.ingredient_id,
      service_date: "2026-10-13",
    };
    const sameDay = {
      ...row("same-day", "Bí đỏ", "UNALLOCATED", "3"),
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
      screen.getByRole("columnheader", { name: "Ngày dùng" }),
    ).toBeInTheDocument();
    const dates = () =>
      within(screen.getByRole("table"))
        .getAllByRole("row")
        .slice(1)
        .map((item) => within(item).getAllByRole("cell")[1]!.textContent);
    expect(dates()).toEqual(["12/10/2026", "12/10/2026", "13/10/2026"]);
    fireEvent.click(
      screen.getByRole("button", { name: "Sắp xếp theo Nguyên liệu" }),
    );
    expect(dates()).toEqual(["12/10/2026", "12/10/2026", "13/10/2026"]);
    fireEvent.click(
      screen.getByRole("button", { name: /Phân bổ NCC Gạo.*13\/10\/2026/ }),
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

    expect(visibleIssues()).toEqual(["Đủ", "Thiếu 1 kg", "Chưa phân bổ"]);
    const sort = screen.getByRole("button", {
      name: "Sắp xếp theo Tình trạng / vấn đề",
    });
    fireEvent.click(sort);
    expect(visibleIssues()).toEqual(["Chưa phân bổ", "Đủ", "Thiếu 1 kg"]);
    fireEvent.click(sort);
    expect(visibleIssues()).toEqual(["Thiếu 1 kg", "Đủ", "Chưa phân bổ"]);
  });
});
