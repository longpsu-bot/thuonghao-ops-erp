import { describe, expect, it } from "vitest";
import type { MenuLine } from "../bridges/planning";
import {
  classifyWeeklyMenuSync,
  sameWeeklyMenuAssignments,
  weeklyMenuSyncDescription,
} from "./weeklyMenuSync";

const line = (slot: string, dish: string): MenuLine => ({
  school_id: "school-1",
  service_date: "2026-09-07",
  menu_slot_code: slot,
  dish_id: dish,
  source_row_reference: null,
});

describe("weekly Menu synchronization presentation delta", () => {
  it("classifies assignment changes without treating source evidence as a business change", () => {
    const unchanged = {
      ...line("soup", "dish-1"),
      source_row_reference: "new:4",
    };
    const delta = classifyWeeklyMenuSync(
      [line("soup", "dish-1"), line("main", "dish-2"), line("veg", "dish-3")],
      [unchanged, line("main", "dish-4"), line("dessert", "dish-5")],
    );
    expect(delta).toEqual({ unchanged: 1, added: 1, replaced: 1, removed: 1 });
    expect(weeklyMenuSyncDescription(delta)).toBe(
      "1 món đã được thay đổi · 1 món đã được bỏ.",
    );
  });

  it("treats exact and additions-only writes as quiet outcomes", () => {
    expect(
      sameWeeklyMenuAssignments(
        [line("soup", "dish-1")],
        [line("soup", "dish-1")],
      ),
    ).toBe(true);
    expect(
      weeklyMenuSyncDescription(
        classifyWeeklyMenuSync([], [line("soup", "dish-1")]),
      ),
    ).toBeNull();
  });
});
