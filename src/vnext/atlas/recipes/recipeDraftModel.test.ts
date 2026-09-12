import { describe, expect, it } from "vitest";
import {
  parseQuantity,
  recipeDraftFor,
  recipePayload,
  validRecipeDraft,
  sameComposition,
  canonicalScopes,
} from "./recipeDraftModel";

describe("base Recipe draft boundary", () => {
  it.each([
    ["0,5", 0.5],
    ["2.25", 2.25],
    ["1", 1],
    ["0", null],
    ["-1", null],
    ["1.2,3", null],
    ["1e2", null],
    ["", null],
  ])("parses %s without coercing malformed input", (value, expected) => {
    expect(parseQuantity(String(value))).toBe(expected);
  });
  const line = {
    recipe_line_id: "stable-line",
    predecessor_recipe_line_revision_id: null,
    ingredient_id: "pumpkin",
    quantity_per_basis: 2.5,
    unit_id: "kg",
    line_disposition: "PRESENT" as const,
    operational_note: null,
    line_code: "hidden",
  };
  const selection = {
    dish_id: "dish",
    school_type_id: "scope",
    recipe_version_id: "version",
    basis_portions: 80,
    composition: [line],
  };
  const refs = {
    ingredients: [{ ingredient_id: "pumpkin", ingredient_status: "ACTIVE" }],
    units: [{ unit_id: "kg", unit_status: "ACTIVE" }],
  };
  it("preserves stable identity, exact selected basis and optional note in the save payload", () => {
    const draft = recipeDraftFor(selection);
    draft.lines[0].quantity = "0,5";
    expect(recipePayload(selection, draft)).toEqual({
      dish_id: "dish",
      school_type_id: "scope",
      recipe_version_id: "version",
      basis_portions: 80,
      lines: [
        {
          recipe_line_id: "stable-line",
          ingredient_id: "pumpkin",
          quantity_per_basis: 0.5,
          unit_id: "kg",
          operational_note: null,
        },
      ],
    });
  });
  it("blocks fractional basis, duplicate Ingredient, inactive references and non-positive quantities", () => {
    const draft = recipeDraftFor(selection);
    expect(validRecipeDraft(draft, refs)).toBe(true);
    expect(validRecipeDraft({ ...draft, basis: "1.5" }, refs)).toBe(false);
    expect(
      validRecipeDraft(
        { ...draft, lines: [...draft.lines, { ...draft.lines[0], id: "new" }] },
        refs,
      ),
    ).toBe(false);
    expect(
      validRecipeDraft(draft, {
        ...refs,
        units: [{ unit_id: "kg", unit_status: "INACTIVE" }],
      }),
    ).toBe(false);
    draft.lines[0].quantity = "0";
    expect(validRecipeDraft(draft, refs)).toBe(false);
  });
  it("compares composition facts independently of order and revision metadata", () => {
    const revised = { ...line, recipe_line_revision_id: "new-revision" };
    expect(sameComposition([line], [revised])).toBe(true);
    expect(
      sameComposition([line], [{ ...line, quantity_per_basis: 2.6 }]),
    ).toBe(false);
    expect(sameComposition([line], [])).toBe(false);
  });
  it("uses canonical codes, never display names or unrelated School Types", () => {
    expect(
      canonicalScopes([
        {
          school_type_id: "one",
          school_type_code: "v1-school-type-1",
          school_type_name: "Khối A",
          school_type_status: "ACTIVE",
        },
        {
          school_type_id: "other",
          school_type_code: "other",
          school_type_name: "Tiểu học",
          school_type_status: "ACTIVE",
        },
      ]).map((x) => x.school_type_id),
    ).toEqual(["one"]);
  });
});
