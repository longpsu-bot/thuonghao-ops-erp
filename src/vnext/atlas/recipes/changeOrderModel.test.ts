import { describe, expect, it } from "vitest";
import {
  actionsFor,
  scopeFromDecisions,
  newChangeDraft,
  previewRequest,
  commandPayload,
  validChangeDraft,
  proposalFor,
  vietnamLocalDate,
} from "./changeOrderModel";
import {
  emptyRecipeAdjustmentWorkbench,
  type EffectiveTargetContext,
} from "../bridges/recipeAdjustment";
const data = emptyRecipeAdjustmentWorkbench();
data.scope_catalog = [
  {
    scope_kind: "SYSTEM_DISH",
    actions: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  },
  {
    scope_kind: "SCHOOL_DISH",
    actions: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  },
  { scope_kind: "SCHOOL", actions: ["REPLACE", "REMOVE"] },
  { scope_kind: "SYSTEM_INGREDIENT", actions: ["REPLACE"] },
];
data.school_types = [
  {
    school_type_id: "type",
    school_type_code: "v1-school-type-1",
    school_type_status: "ACTIVE",
  },
];
data.schools = [
  { school_id: "school", school_type_id: "type", school_status: "ACTIVE" },
];
data.dishes = [{ dish_id: "dish", dish_status: "ACTIVE" }];
data.ingredients = [
  {
    ingredient_id: "carrot",
    ingredient_status: "ACTIVE",
    purchase_unit_id: "kg",
  },
];
data.units = [{ unit_id: "kg", unit_status: "ACTIVE" }];
const targets: EffectiveTargetContext = {
  as_of_date: "2026-09-12",
  dish_id: "dish",
  school_id: null,
  school_type_id: "type",
  selected_recipe: null,
  basis_portions: 100,
  blockers: [],
  warnings: [],
  effective_lines: [
    {
      target_id: "base",
      target_kind: "RECIPE_LINE",
      target_recipe_line_id: "base",
      adjustment_line_id: null,
      ingredient_id: "pumpkin",
      ingredient_name: "Bí đỏ",
      quantity_per_basis: 2,
      unit_id: "kg",
      unit_name: "kg",
      source_layer: "BASE",
    },
    {
      target_id: "added",
      target_kind: "ADJUSTMENT_LINE",
      target_recipe_line_id: null,
      adjustment_line_id: "added",
      ingredient_id: "pumpkin",
      ingredient_name: "Bí đỏ",
      quantity_per_basis: 3,
      unit_id: "kg",
      unit_name: "kg",
      source_layer: "SYSTEM_DISH",
    },
  ],
};
function draft() {
  return {
    ...newChangeDraft("2026-09-12"),
    dishId: "dish",
    schoolTypeId: "type",
    action: "REPLACE" as const,
    targetKey: "RECIPE_LINE:base",
    substituteId: "carrot",
    reason: "Đổi nguyên liệu",
  };
}
describe("Change Order business decisions and exact command identity", () => {
  it.each([
    [
      "recipe",
      "all",
      "SYSTEM_DISH",
      ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
    ],
    [
      "recipe",
      "one",
      "SCHOOL_DISH",
      ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
    ],
    ["ingredient", "all", "SYSTEM_INGREDIENT", ["REPLACE"]],
    ["ingredient", "one", "SCHOOL", ["REPLACE", "REMOVE"]],
  ] as const)(
    "maps %s/%s and restricts actions by authority",
    (object, audience, scope, actions) => {
      expect(scopeFromDecisions(object, audience)).toBe(scope);
      expect(actionsFor(scope, data)).toEqual(actions);
      expect(actionsFor(scope, { ...data, scope_catalog: [] })).toEqual([]);
    },
  );
  it("derives Vietnam's business date across UTC midnight", () => {
    expect(vietnamLocalDate(new Date("2026-09-11T17:01:00Z"))).toBe(
      "2026-09-12",
    );
  });
  it("keeps system Preview/Create and correction context School-free", () => {
    const d = { ...draft(), previewSchoolId: "school" };
    const p = proposalFor(d, data, targets);
    const read = previewRequest(d, data, p);
    expect(read).toEqual({
      as_of_date: "2026-09-12",
      dish_id: "dish",
      school_type_id: "type",
      proposed_adjustment: p,
    });
    expect(commandPayload(d, data, p)).not.toHaveProperty("preview_school_id");
    expect(commandPayload(d, data, p)).toMatchObject({
      preview_school_type_id: "type",
      preview_dish_id: "dish",
    });
  });
  it("retains School impact contexts without changing ingredient-wide identity", () => {
    const d = {
      ...draft(),
      object: "ingredient" as const,
      audience: "all" as const,
      ingredientId: "carrot",
      previewSchoolId: "school",
      previewDishId: "dish",
    };
    const p = proposalFor(d, data, targets);
    expect(p).toMatchObject({
      school_id: null,
      dish_id: null,
      target_ingredient_id: "carrot",
    });
    expect(previewRequest(d, data, p)).toMatchObject({
      school_id: "school",
      dish_id: "dish",
    });
    expect(commandPayload(d, data, p)).toMatchObject({
      preview_school_id: "school",
      preview_dish_id: "dish",
    });
  });
  it.each([
    ["RECIPE_LINE:base", "base", null],
    ["ADJUSTMENT_LINE:added", null, "added"],
  ])("targets exact identity %s with XOR", (key, recipe, adjustment) => {
    expect(
      proposalFor({ ...draft(), targetKey: key! }, data, targets),
    ).toMatchObject({
      target_recipe_line_id: recipe,
      adjustment_line_id: adjustment,
      target_ingredient_id: null,
    });
  });
  it("retains generated ADD line and revision identities through Preview and command", () => {
    const d = {
      ...draft(),
      action: "ADD" as const,
      ingredientId: "carrot",
      quantity: "2,25",
    };
    const p = proposalFor(d, data, targets);
    expect(p).toMatchObject({
      adjustment_line_id: d.addLineId,
      revision_id: d.revisionId,
      quantity_per_basis: 2.25,
      unit_id: "kg",
      target_recipe_line_id: null,
    });
    expect(commandPayload(d, data, p).adjustment_line_id).toBe(d.addLineId);
  });
  it.each(["0", "-1", "1e2", "NaN", "1,2.3", ""])(
    "rejects invalid required quantity %s",
    (quantity) => {
      expect(
        validChangeDraft(
          { ...draft(), action: "ADJUST_QUANTITY", quantity },
          data,
          targets,
        ),
      ).toBe(false);
    },
  );
  it("requires reason, canonical type, exact target and a valid half-open date interval", () => {
    expect(validChangeDraft(draft(), data, targets)).toBe(true);
    for (const patch of [
      { reason: " " },
      { schoolTypeId: "unknown" },
      { dishId: "" },
      { targetKey: "Bí đỏ" },
      { effectiveTo: "2026-09-12" },
      { effectiveFrom: "2026-02-30" },
    ])
      expect(validChangeDraft({ ...draft(), ...patch }, data, targets)).toBe(
        false,
      );
  });
  it("REMOVE sends no substitute, quantity or Unit, and quantity REPLACE uses purchase Unit", () => {
    expect(
      proposalFor(
        { ...draft(), action: "REMOVE", quantity: "10" },
        data,
        targets,
      ),
    ).toMatchObject({
      substitute_ingredient_id: null,
      quantity_per_basis: null,
      unit_id: null,
    });
    expect(
      proposalFor(
        { ...draft(), replaceQuantity: true, quantity: "1.5" },
        data,
        targets,
      ),
    ).toMatchObject({ quantity_per_basis: 1.5, unit_id: "kg" });
  });
});

import { ledgerRows, rowFacts } from "./changeOrderModel";
import { changeOrderFixtureData } from "./changeOrderReviewFixtures";
describe("Ledger search and deterministic temporal order", () => {
  it("searches Vietnamese human facts and attributed actors locally", () => {
    const d = changeOrderFixtureData();
    for (const query of [
      "ca rot",
      "canh bi do",
      "nguyen lan",
      "theo thuc don",
      "khoi nho",
    ])
      expect(ledgerRows(d, query, "all", "")).toHaveLength(1);
    expect(ledgerRows(d, "revision-existing", "all", "")).toHaveLength(0);
  });
  it("groups current attention before active and scheduled while retaining source order within groups", () => {
    const d = changeOrderFixtureData(),
      row = d.operator_rows[0];
    d.operator_rows = [
      "EXPIRED",
      "ACTIVE",
      "SCHEDULED",
      "ACTIVE_CHANGE_SCHEDULED",
      "ACTIVE_CANCELLATION_SCHEDULED",
      "CANCELLED",
      "ACTIVE_RESUMED",
    ].map((state, i) => ({
      ...row,
      adjustment_id: `row-${i}`,
      temporal_state: state as typeof row.temporal_state,
      is_effective_now: state.startsWith("ACTIVE"),
    }));
    expect(ledgerRows(d, "", "all", "").map((r) => r.adjustment_id)).toEqual([
      "row-3",
      "row-4",
      "row-1",
      "row-6",
      "row-2",
      "row-0",
      "row-5",
    ]);
    expect(ledgerRows(d, "", "current", "")).toHaveLength(5);
  });
  it("finds the Ingredient of an exact prior ADD identity without guessing by name", () => {
    const d = changeOrderFixtureData(),
      row = d.operator_rows[0];
    d.operator_rows.push({
      ...row,
      adjustment_id: "prior-add",
      action_kind: "ADD",
      adjustment_line_id: "added",
      target_recipe_line_id: null,
      target_ingredient_id: "ingredient-2",
    });
    const target = {
      ...row,
      adjustment_line_id: "added",
      target_recipe_line_id: null,
    };
    expect(rowFacts(target, d)).toContain("Hành lá");
  });
});
