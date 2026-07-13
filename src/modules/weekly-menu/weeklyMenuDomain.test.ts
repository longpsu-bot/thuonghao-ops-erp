import { describe, expect, it } from "vitest";
import {
  ApproveWeeklyMenu,
  EditWeeklyMenuLine,
  ImportWeeklyMenu,
  ReopenWeeklyMenu,
  RequestPlanningNeedGeneration,
  ValidateWeeklyMenu,
  type WeeklyMenuImportRow,
} from "./weeklyMenuDomain";

const references = {
  schoolIds: ["school-nguyen-du"],
  dishIds: ["dish-pumpkin-soup", "dish-rice"],
};
const at = "2026-07-13T08:00:00.000Z";
const validRow: WeeklyMenuImportRow = {
  serviceDate: "2026-07-14",
  schoolId: "school-nguyen-du",
  menuSlot: "soup",
  dishId: "dish-pumpkin-soup",
  sourceRowRef: "Sheet1!A2",
};
function imported(rows = [validRow]) {
  return ImportWeeklyMenu(
    {
      weeklyMenuId: "menu-29",
      weekStart: "2026-07-13",
      weekEnd: "2026-07-19",
      sourceType: "GOOGLE_SHEET",
      sourceName: "Week 29",
      sourceSignature: "sig-29",
      rows,
      actorId: "planner-lan",
      at,
    },
    references,
  ).menu;
}
function approved() {
  const validated = ValidateWeeklyMenu(
    imported(),
    references,
    "planner-lan",
    at,
  ).menu;
  return ApproveWeeklyMenu(validated, "manager-minh", at).menu;
}

describe("Weekly Menu domain", () => {
  it("creates Draft menu lines from a valid import", () => {
    const menu = imported();
    expect(menu.status).toBe("DRAFT");
    expect(menu.lines).toHaveLength(1);
    expect(menu.issues).toEqual([]);
  });
  it("creates blocking issues for unknown school and dish", () => {
    const menu = imported([
      { ...validRow, schoolId: "unknown", dishId: "missing" },
    ]);
    expect(menu.issues.map((issue) => issue.issueCode)).toEqual([
      "UNKNOWN_SCHOOL",
      "UNKNOWN_DISH",
    ]);
    expect(menu.issues.every((issue) => issue.isBlocking)).toBe(true);
  });
  it("creates a blocking issue for duplicate school, date, and slot", () => {
    const menu = imported([
      validRow,
      { ...validRow, dishId: "dish-rice", sourceRowRef: "Sheet1!A3" },
    ]);
    expect(
      menu.issues.some((issue) => issue.issueCode === "DUPLICATE_ASSIGNMENT"),
    ).toBe(true);
  });
  it("blocks approval while blocking issues exist", () => {
    const result = ApproveWeeklyMenu(
      imported([{ ...validRow, schoolId: "unknown" }]),
      "manager-minh",
      at,
    );
    expect(result.accepted).toBe(false);
  });
  it("does not allow an approved menu to be edited without reopening", () => {
    const result = EditWeeklyMenuLine(
      approved(),
      "menu-29-line-1",
      validRow,
      "planner-lan",
      at,
    );
    expect(result.accepted).toBe(false);
  });
  it("preserves the reopen reason in change history", () => {
    const result = ReopenWeeklyMenu(
      approved(),
      "Corrected school request",
      "manager-minh",
      at,
    );
    expect(result.accepted).toBe(true);
    expect(result.menu.changes.at(-1)).toMatchObject({
      type: "WeeklyMenuReopened",
      reason: "Corrected school request",
    });
  });
  it("only allows need generation to be requested from Approved", () => {
    expect(
      RequestPlanningNeedGeneration(imported(), "planner-lan", at).accepted,
    ).toBe(false);
    expect(
      RequestPlanningNeedGeneration(approved(), "planner-lan", at).menu.status,
    ).toBe("NEED_GENERATION_REQUESTED");
  });
});
