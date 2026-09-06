import { describe, expect, it } from "vitest";
import type { AtlasSuccessEnvelope, JsonValue } from "../connection/atlasRpc";
import {
  dishRecipeCopyFromResult,
  dishRecipeOperatorWorkbenchFromResult,
  emptyRecipeWorkbench,
  recipeWorkbenchFromResult,
} from "./recipeModel";
import type {
  DishRecipeOperatorWorkbench,
  RecipeWorkbenchData,
} from "./recipeModel";
import { createReviewRecipeApi } from "./reviewRecipeApi";

function editableOperatorWorkbench(): DishRecipeOperatorWorkbench {
  return {
    dish: {
      dish_id: "dish-1",
      dish_name: "Canh rau",
      dish_type_name: "Canh",
      dish_status: "ACTIVE",
    },
    context_kind: "SYSTEM_SCHOOL_TYPE",
    as_of_date: "2026-09-05",
    school_id: null,
    school_type_id: "school-type-1",
    selected_recipe: {
      dish_id: "dish-1",
      school_type_id: "school-type-1",
      school_type_code: "v1-school-type-1",
      recipe_id: "recipe-1",
      recipe_version_id: "recipe-version-1",
      selection_scope: "SCHOOL_TYPE",
      basis_portions: 100,
      released_at: "2026-09-01T00:00:00.000Z",
    },
    basis_portions: 100,
    base_authoring: {
      dish_id: "dish-1",
      school_type_id: "school-type-1",
      recipe_id: "recipe-1",
      recipe_version_id: "recipe-version-1",
      expected_version: 1,
      in_use_recipe_version_id: "recipe-version-1",
      business_status: "AVAILABLE",
      locked_for_normal_editing: false,
      lock_reason: null,
      basis_portions: 100,
      composition: [],
      allowed_actions: { save_recipe: true, release_recipe: false },
      disabled_reason_codes: {
        save_recipe: null,
        release_recipe: "RELEASE_ALREADY_IN_USE",
      },
      disabled_reasons: {
        save_recipe: null,
        release_recipe: "Already released.",
      },
    },
    effective_readiness: { status: "READY", blockers: [], warnings: [] },
    editable_state: "EDITABLE_BASE",
    is_editable: true,
    is_operationally_locked: false,
    current_effective_bom: [
      {
        ingredient_id: "ingredient-effective",
        ingredient_name: "Bí xanh hiệu lực",
        quantity_per_basis: 12,
        unit_id: "unit-1",
        unit_name: "Kilôgam",
        target_kind: "RECIPE_LINE",
        target_recipe_line_id: "recipe-line-1",
        adjustment_line_id: null,
        target_id: "recipe-line-1",
        source_layer: "SYSTEM_DISH",
      },
    ],
    school_exception_count: 0,
    allowed_actions: ["COPY_DISH_RECIPES"],
    blockers: [],
    warnings: [],
    history_periods: [],
  };
}

async function createReviewCatalogFixture(): Promise<RecipeWorkbenchData> {
  const result = await createReviewRecipeApi("ready").getWorkbench(
    "subject",
    "correlation",
  );
  if (result.kind !== "success") throw new Error("Review catalog unavailable");
  return structuredClone(
    (result.response.workbench ??
      result.response) as unknown as RecipeWorkbenchData,
  );
}

describe("recipe workbench response parsing", () => {
  it("reads the authoritative nested workbench envelope", () => {
    const workbench = emptyRecipeWorkbench();
    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench,
        },
      }),
    ).toEqual(workbench);
  });

  it("fails closed when a required collection is missing", () => {
    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: {
            dishes: [],
          },
        },
      }),
    ).toBeNull();
  });

  it("normalizes only the exact SQL no-Dish selection omissions", async () => {
    const emptyCatalog = await createReviewCatalogFixture();
    emptyCatalog.dishes = [];
    emptyCatalog.recipes = [];
    emptyCatalog.recipe_versions = [];
    Object.assign(emptyCatalog.selected_recipe, {
      dish_id: null,
      school_type_id: null,
      recipe_id: null,
      recipe_version_id: null,
      business_status: "NEEDS_ATTENTION",
      locked_for_normal_editing: false,
      lock_reason: null,
      basis_portions: 100,
      composition: [],
      allowed_actions: { save_recipe: false, release_recipe: false },
      disabled_reason_codes: {
        save_recipe: "DISH_NOT_FOUND",
        release_recipe: "DISH_NOT_FOUND",
      },
      disabled_reasons: {
        save_recipe: "Không tìm thấy món ăn đã chọn.",
        release_recipe: "Không tìm thấy món ăn đã chọn.",
      },
    });
    delete (emptyCatalog.selected_recipe as unknown as Record<string, unknown>)
      .expected_version;
    delete (emptyCatalog.selected_recipe as unknown as Record<string, unknown>)
      .in_use_recipe_version_id;

    const parsed = recipeWorkbenchFromResult({
      kind: "success",
      response: { success: true, workbench: emptyCatalog },
    });
    expect(parsed?.selected_recipe.expected_version).toBeNull();
    expect(parsed?.selected_recipe.in_use_recipe_version_id).toBeNull();

    const foundDish = await createReviewCatalogFixture();
    delete (foundDish.selected_recipe as unknown as Record<string, unknown>)
      .expected_version;
    delete (foundDish.selected_recipe as unknown as Record<string, unknown>)
      .in_use_recipe_version_id;
    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: foundDish },
      }),
    ).toBeNull();
  });

  it.each([
    ["Dish version is not an integer", "dishes", "version", "1"],
    ["Dish version is zero", "dishes", "version", 0],
    ["Dish Type version is zero", "dish_types", "version", 0],
    ["Dish type identity is malformed", "dish_types", "dish_type_id", null],
    ["Recipe Dish reference is malformed", "recipes", "dish_id", 9],
    ["Recipe version is zero", "recipes", "version", 0],
    [
      "Recipe Version aggregate version is zero",
      "recipe_versions",
      "version",
      0,
    ],
    [
      "Recipe Version basis is fractional",
      "recipe_versions",
      "basis_portions",
      1.5,
    ],
    [
      "Recipe Version composition is malformed",
      "recipe_versions",
      "composition",
      [null],
    ],
    ["School Type identity is malformed", "school_types", "school_type_id", {}],
    ["Ingredient identity is malformed", "ingredients", "ingredient_id", 4],
    ["Unit status is malformed", "units", "unit_status", "ARCHIVED"],
  ])(
    "rejects catalog data when %s",
    async (_label, collection, field, malformedValue) => {
      const workbench = await createReviewCatalogFixture();
      const rows = workbench[
        collection as keyof Pick<
          typeof workbench,
          | "dishes"
          | "dish_types"
          | "recipes"
          | "recipe_versions"
          | "school_types"
          | "ingredients"
          | "units"
        >
      ] as unknown as Array<Record<string, unknown>>;
      rows[0][String(field)] = malformedValue;

      expect(
        recipeWorkbenchFromResult({
          kind: "success",
          response: { success: true, workbench },
        }),
      ).toBeNull();
    },
  );

  it.each([
    ["fractional expected version", 1.5],
    ["negative expected version", -1],
    ["zero expected version", 0],
    ["non-positive basis", 0],
    ["fractional basis", 1.5],
  ])("rejects catalog authoring with %s", async (_label, malformedValue) => {
    const workbench = await createReviewCatalogFixture();
    if (_label.includes("basis"))
      workbench.selected_recipe.basis_portions = malformedValue;
    else workbench.selected_recipe.expected_version = malformedValue;

    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      }),
    ).toBeNull();
  });

  it.each([
    ["zero REMOVED", "REMOVED", 0, "prior-line-revision", true],
    ["positive REMOVED", "REMOVED", 1, "prior-line-revision", false],
    ["REMOVED without predecessor", "REMOVED", 0, null, false],
    ["zero PRESENT", "PRESENT", 0, null, false],
    ["non-finite REMOVED", "REMOVED", Number.NaN, "prior-line-revision", false],
  ] as const)(
    "validates %s quantities in catalog Recipe Version composition",
    async (
      _label,
      lineDisposition,
      quantity,
      predecessorRevisionId,
      accepted,
    ) => {
      const workbench = await createReviewCatalogFixture();
      const line = workbench.recipe_versions[0].composition[0];
      workbench.recipe_versions[0].composition = [
        {
          ...line,
          predecessor_recipe_line_revision_id: predecessorRevisionId,
          quantity_per_basis: quantity,
          line_disposition: lineDisposition,
        },
      ];

      const parsed = recipeWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      });
      if (accepted) expect(parsed).not.toBeNull();
      else expect(parsed).toBeNull();
    },
  );

  it("parses a guarded effective Dish Recipe operator workbench", () => {
    const workbench = {
      dish: {
        dish_id: "dish-1",
        dish_name: "Canh rau",
        dish_type_name: "Canh",
        dish_status: "ACTIVE",
      },
      context_kind: "SYSTEM_SCHOOL_TYPE",
      as_of_date: "2026-09-05",
      school_id: null,
      school_type_id: "school-type-1",
      selected_recipe: {
        dish_id: "dish-1",
        school_type_id: "school-type-1",
        school_type_code: "v1-school-type-1",
        recipe_id: "recipe-1",
        recipe_version_id: "recipe-version-1",
        selection_scope: "SCHOOL_TYPE",
        basis_portions: 100,
        released_at: "2026-09-01T00:00:00.000Z",
      },
      basis_portions: 100,
      base_authoring: {
        dish_id: "dish-1",
        school_type_id: "school-type-1",
        recipe_id: "recipe-1",
        recipe_version_id: "recipe-version-1",
        expected_version: 1,
        in_use_recipe_version_id: "recipe-version-1",
        business_status: "LOCKED",
        locked_for_normal_editing: true,
        lock_reason: "Approved Menu evidence exists.",
        basis_portions: 100,
        composition: [],
        allowed_actions: { save_recipe: false, release_recipe: false },
        disabled_reason_codes: {
          save_recipe: "SAVE_OPERATIONALLY_LOCKED",
          release_recipe: "RELEASE_ALREADY_IN_USE",
        },
        disabled_reasons: {
          save_recipe: "Use a Change Order.",
          release_recipe: "Already released.",
        },
      },
      effective_readiness: { status: "READY", blockers: [], warnings: [] },
      editable_state: "LOCKED_CHANGE_ORDER",
      is_editable: false,
      is_operationally_locked: true,
      current_effective_bom: [],
      school_exception_count: 2,
      allowed_actions: ["CREATE_CHANGE_ORDER"],
      blockers: [],
      warnings: [],
      history_periods: [],
    };

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      }),
    ).toEqual(workbench);
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: { ...workbench, history_periods: null },
        },
      }),
    ).toBeNull();
  });

  it("parses the canonical selected Recipe for both system and School contexts", () => {
    const system = editableOperatorWorkbench();
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: system },
      }),
    ).not.toBeNull();

    const school = {
      ...editableOperatorWorkbench(),
      context_kind: "SCHOOL",
      school_id: "school-1",
    };
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: school },
      }),
    ).not.toBeNull();
  });

  it("requires revision-specific coherent effective-history issuance", () => {
    const workbench = editableOperatorWorkbench();
    const legacy = {
      adjustment_id: "adjustment-1",
      revision_id: "revision-1",
      revision_number: 1,
      revision_status: "SUPERSEDED" as const,
      business_event_kind: "CREATED" as const,
      scope_kind: "SYSTEM_DISH" as const,
      action_kind: "ADD" as const,
      effective_from: "2026-07-01",
      effective_to: null,
      reason_code: "LEGACY_IMPORT",
      reason: "Imported without original attribution.",
      issuance_kind: "LEGACY_UNATTRIBUTED" as const,
      issuer: null,
      issued_at: null,
    };
    const native = {
      ...legacy,
      revision_id: "revision-2",
      revision_number: 2,
      revision_status: "ACTIVE" as const,
      business_event_kind: "CORRECTED" as const,
      reason_code: "RULE_CORRECTION",
      reason: "Corrected in Atlas.",
      issuance_kind: "ATLAS_NATIVE" as const,
      issuer: "Nguyễn Điều phối",
      issued_at: "2026-09-06T04:00:00.000Z",
    };
    workbench.history_periods = [
      {
        period_from: "2026-07-01",
        period_to: null,
        resolution_status: "READY",
        effective_bom: workbench.current_effective_bom,
        change_orders: [legacy, native],
        warnings: [],
        blockers: [],
      },
    ];
    const parse = (changeOrders: Array<Record<string, JsonValue>>) =>
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: {
            ...workbench,
            history_periods: [
              { ...workbench.history_periods[0], change_orders: changeOrders },
            ],
          },
        },
      });

    expect(parse([legacy, native])).not.toBeNull();
    expect(parse([{ ...legacy, issuer: "Technical Importer" }])).toBeNull();
    expect(parse([{ ...native, issued_at: null }])).toBeNull();
    expect(parse([{ ...native, issuance_kind: "IMPORTER" }])).toBeNull();
  });

  it.each([
    ["malformed School Type code", { school_type_code: null }],
    ["non-canonical School Type code", { school_type_code: "general" }],
    ["missing release timestamp", { released_at: null }],
    ["cross-scope School Type", { school_type_id: "school-type-2" }],
    ["different base Recipe", { recipe_id: "recipe-other" }],
    ["GENERAL proxy scope", { selection_scope: "GENERAL" }],
  ])("rejects selected Recipe with %s", (_label, selectedPatch) => {
    const workbench = editableOperatorWorkbench();
    const selected = {
      ...workbench.selected_recipe!,
      ...selectedPatch,
    };
    const malformed = { ...workbench, selected_recipe: selected };

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: malformed },
      }),
    ).toBeNull();
  });

  it("rejects a selected Recipe missing its School Type identity", () => {
    const workbench = editableOperatorWorkbench();
    const selected = structuredClone(
      workbench.selected_recipe,
    ) as unknown as Record<string, JsonValue>;
    delete selected.school_type_id;

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: { ...workbench, selected_recipe: selected },
        },
      }),
    ).toBeNull();
  });

  it("accepts backend is_editable=false when root readiness blocks otherwise allowed base authoring", () => {
    const workbench = editableOperatorWorkbench();
    workbench.is_editable = false;
    workbench.effective_readiness = {
      status: "BLOCKED",
      blockers: [
        {
          code: "TYPED_ROOT_NOT_READY",
          message: "A canonical typed Recipe root is not ready.",
        },
      ],
      warnings: [],
    };
    workbench.blockers = [...workbench.effective_readiness.blockers];
    workbench.selected_recipe = null;
    workbench.current_effective_bom = [];
    workbench.history_periods = [];

    expect(workbench.base_authoring.allowed_actions.save_recipe).toBe(true);
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      }),
    ).not.toBeNull();

    workbench.is_editable = true;
    workbench.base_authoring.allowed_actions.save_recipe = false;
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      }),
    ).toBeNull();
  });

  it("parses root-only editable base authoring before effective readiness", () => {
    const workbench = {
      dish: {
        dish_id: "dish-new",
        dish_name: "Canh mới",
        dish_type_name: "Canh",
        dish_status: "ACTIVE",
      },
      context_kind: "SYSTEM_SCHOOL_TYPE",
      as_of_date: "2026-09-05",
      school_id: null,
      school_type_id: "school-type-1",
      selected_recipe: null,
      basis_portions: 100,
      base_authoring: {
        dish_id: "dish-new",
        school_type_id: "school-type-1",
        recipe_id: "recipe-new",
        recipe_version_id: null,
        expected_version: 1,
        in_use_recipe_version_id: null,
        business_status: "NOT_SAVED",
        locked_for_normal_editing: false,
        lock_reason: null,
        basis_portions: 100,
        composition: [],
        allowed_actions: { save_recipe: true, release_recipe: false },
        disabled_reason_codes: {
          save_recipe: null,
          release_recipe: "RELEASE_SAVE_REQUIRED",
        },
        disabled_reasons: {
          save_recipe: null,
          release_recipe: "Save first.",
        },
      },
      effective_readiness: {
        status: "BLOCKED",
        blockers: [
          { code: "RECIPE_SELECTION_BLOCKED", message: "No release." },
        ],
        warnings: [],
      },
      editable_state: "EDITABLE_BASE",
      is_editable: true,
      is_operationally_locked: false,
      current_effective_bom: [],
      school_exception_count: 0,
      allowed_actions: ["COPY_DISH_RECIPES"],
      blockers: [{ code: "RECIPE_SELECTION_BLOCKED", message: "No release." }],
      warnings: [],
      history_periods: [],
    };

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      }),
    ).toEqual(workbench);
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: { ...workbench, is_editable: false },
        },
      }),
    ).not.toBeNull();
  });

  it("rejects an effective workbench whose context identity disagrees with its kind", () => {
    const systemWithSchool = {
      ...editableOperatorWorkbench(),
      school_id: "school-1",
    };
    const schoolWithoutSchool = {
      ...editableOperatorWorkbench(),
      context_kind: "SCHOOL",
      school_id: null,
    };

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: systemWithSchool },
      }),
    ).toBeNull();
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: schoolWithoutSchool },
      }),
    ).toBeNull();
  });

  it("rejects mismatched selected Recipe identity and malformed stable line targets", () => {
    const selectedDishMismatch = editableOperatorWorkbench();
    selectedDishMismatch.selected_recipe!.dish_id = "dish-other";
    const bothTargets = editableOperatorWorkbench();
    const malformedTargets = {
      ...bothTargets,
      current_effective_bom: [
        {
          ...bothTargets.current_effective_bom[0],
          adjustment_line_id: "adjustment-line-1",
        },
      ],
    };

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: selectedDishMismatch },
      }),
    ).toBeNull();
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: malformedTargets },
      }),
    ).toBeNull();
  });

  it.each([
    ["unknown business status", { business_status: "PUBLISHED" }],
    ["fractional basis", { basis_portions: 1.5 }],
    ["malformed composition row", { composition: [null] }],
    [
      "composition row missing stable identity",
      {
        composition: [
          {
            predecessor_recipe_line_revision_id: null,
            ingredient_id: "ingredient-1",
            quantity_per_basis: 12,
            unit_id: "unit-1",
            line_disposition: "PRESENT",
            operational_note: null,
            line_code: null,
          },
        ],
      },
    ],
    [
      "malformed composition quantity",
      {
        composition: [
          {
            recipe_line_id: "line-1",
            predecessor_recipe_line_revision_id: null,
            ingredient_id: "ingredient-1",
            quantity_per_basis: "12",
            unit_id: "unit-1",
            line_disposition: "PRESENT",
            operational_note: null,
            line_code: null,
          },
        ],
      },
    ],
    [
      "non-finite composition quantity",
      {
        composition: [
          {
            recipe_line_id: "line-1",
            predecessor_recipe_line_revision_id: null,
            ingredient_id: "ingredient-1",
            quantity_per_basis: Number.NaN,
            unit_id: "unit-1",
            line_disposition: "PRESENT",
            operational_note: null,
            line_code: null,
          },
        ],
      },
    ],
    [
      "malformed disabled reason code",
      {
        disabled_reason_codes: {
          save_recipe: 7,
          release_recipe: "RELEASE_ALREADY_IN_USE",
        },
      },
    ],
    [
      "malformed disabled reason",
      {
        disabled_reasons: {
          save_recipe: null,
          release_recipe: { message: "Already released." },
        },
      },
    ],
  ])("rejects nested base authoring with %s", (_label, basePatch) => {
    const workbench = editableOperatorWorkbench();
    const malformed = {
      ...workbench,
      base_authoring: { ...workbench.base_authoring, ...basePatch },
    };

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench: malformed },
      }),
    ).toBeNull();
  });

  it.each([
    ["zero REMOVED", "REMOVED", 0, "prior-line-revision", true],
    ["positive REMOVED", "REMOVED", 1, "prior-line-revision", false],
    ["REMOVED without predecessor", "REMOVED", 0, null, false],
    ["zero PRESENT", "PRESENT", 0, null, false],
    ["non-finite PRESENT", "PRESENT", Number.NaN, null, false],
  ] as const)(
    "validates %s quantities in nested base authoring",
    (_label, lineDisposition, quantity, predecessorRevisionId, accepted) => {
      const workbench = editableOperatorWorkbench();
      workbench.base_authoring.composition = [
        {
          recipe_line_id: "line-1",
          predecessor_recipe_line_revision_id: predecessorRevisionId,
          ingredient_id: "ingredient-1",
          quantity_per_basis: quantity,
          unit_id: "unit-1",
          line_disposition: lineDisposition,
          operational_note: null,
          line_code: null,
        },
      ];

      const parsed = dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      });
      if (accepted) expect(parsed).not.toBeNull();
      else expect(parsed).toBeNull();
    },
  );

  it("parses Dish-copy results and rejects malformed scope rows", () => {
    const result = {
      success: true as const,
      contract_version: "RECIPE-EFFECTIVE.v1",
      command_id: "command-1",
      correlation_id: "correlation-1",
      idempotency_status: "COMPLETED",
      scope_results: [
        {
          school_type_id: "school-type-1",
          school_type_code: "v1-school-type-1",
          scope_name: "Tiểu học",
          status: "COPIED",
          source_recipe_id: "source-recipe-1",
          source_recipe_version_id: "source-version-1",
          source_selection_scope: "SCHOOL_TYPE",
          target_recipe_id: "target-recipe-1",
          target_recipe_version_id: "target-version-1",
        },
        {
          school_type_id: "school-type-2",
          school_type_code: "v1-school-type-2",
          scope_name: "Trung học",
          status: "COPIED",
          source_recipe_id: "source-recipe-2",
          source_recipe_version_id: "source-version-2",
          source_selection_scope: "SCHOOL_TYPE",
          target_recipe_id: "target-recipe-2",
          target_recipe_version_id: "target-version-2",
        },
      ],
    };
    expect(
      dishRecipeCopyFromResult({ kind: "success", response: result }),
    ).toEqual(result);
    expect(
      dishRecipeCopyFromResult({
        kind: "success",
        response: { ...result, scope_results: [{ status: 1 }] },
      }),
    ).toBeNull();
    expect(
      dishRecipeCopyFromResult({
        kind: "success",
        response: {
          ...result,
          scope_results: [
            {
              ...result.scope_results[0],
              status: "SOURCE_NOT_AVAILABLE",
            },
          ],
        },
      }),
    ).toBeNull();
    expect(
      dishRecipeCopyFromResult({
        kind: "success",
        response: {
          ...result,
          success: false,
        } as unknown as AtlasSuccessEnvelope,
      }),
    ).toBeNull();
    expect(
      dishRecipeCopyFromResult({
        kind: "success",
        response: { ...result, scope_results: [] },
      }),
    ).toBeNull();
    expect(
      dishRecipeCopyFromResult({
        kind: "success",
        response: {
          ...result,
          scope_results: [
            result.scope_results[0],
            {
              ...result.scope_results[1],
              school_type_code: "v1-school-type-1",
            },
          ],
        },
      }),
    ).toBeNull();
  });
});
