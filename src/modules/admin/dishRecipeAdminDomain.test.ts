import { describe, expect, it } from "vitest";
import {
  AddRecipeLine,
  ApproveRecipeChangeSet,
  CreateDish,
  CreateRecipeChangeSet,
  CreateRecipeDraft,
  CreateRecipeVersion,
  DishMenuReference,
  DishRecipeAdminWorkbench,
  ReleaseRecipeVersionForPlanning,
  RemoveRecipeLine,
  SetDishStatus,
  SetRecipeSchoolTypeVariant,
  UpdateRecipeLine,
  ValidateRecipeVersion,
  recipeVersionIssues,
  type DishRecipeAdminState,
} from "./dishRecipeAdminDomain";
import { dishRecipeAdminFixture } from "./dishRecipeAdminFixtures";

const audit = {
  actorId: "admin-test",
  at: "2026-07-14T07:00:00.000Z",
  reason: "Focused domain test",
};

const fixture = () => structuredClone(dishRecipeAdminFixture);

describe("Dishes & Recipes Admin domain", () => {
  it("enforces dish name and duplicate-active identity rules", () => {
    const state = fixture();
    const missing = CreateDish(state, {
      dishId: "dish-missing-name",
      dishName: " ",
      status: "DRAFT",
      requiresNeedGeneration: true,
      ...audit,
    });
    expect(missing.accepted).toBe(false);
    expect(missing.blockers[0]?.issueCode).toBe("DISH_NAME_MISSING");

    const duplicate = CreateDish(state, {
      dishId: "dish-duplicate",
      dishName: " pumpkin SOUP ",
      status: "ACTIVE",
      requiresNeedGeneration: true,
      ...audit,
    });
    expect(duplicate.accepted).toBe(false);
    expect(duplicate.blockers[0]?.issueCode).toBe("DUPLICATE_ACTIVE_DISH");
  });

  it("records explicit auditable dish status changes and requires override evidence for inactive menu use", () => {
    const result = SetDishStatus(fixture(), {
      dishId: "dish-legacy-soup",
      status: "ACTIVE",
      ...audit,
      reason: "Explicitly reactivate after Admin review",
    });
    expect(result.accepted).toBe(true);
    const dish = result.state.dishes.find(
      (item) => item.dishId === "dish-legacy-soup",
    )!;
    expect(dish.statusChanges.at(-1)).toMatchObject({
      beforeStatus: "INACTIVE",
      afterStatus: "ACTIVE",
      reason: "Explicitly reactivate after Admin review",
    });
    expect(dish.masterDataChanges.at(-1)?.changeType).toBe("DishActivated");

    const inactive = fixture().dishes.find(
      (item) => item.dishId === "dish-legacy-soup",
    );
    expect(DishMenuReference(inactive).accepted).toBe(false);
    expect(
      DishMenuReference(inactive, "Planning owner approved one new reference")
        .accepted,
    ).toBe(true);
  });

  it("creates recipe drafts and versions with an explicit lifecycle", () => {
    const draft = CreateRecipeDraft(fixture(), {
      recipeId: "recipe-new",
      recipeVersionId: "recipe-new-v1",
      dishId: "dish-fried-fish",
      recipeName: "Replacement fish recipe",
      ...audit,
    });
    expect(draft.accepted).toBe(true);
    expect(
      draft.state.recipeVersions.find(
        (version) => version.recipeVersionId === "recipe-new-v1",
      )?.status,
    ).toBe("DRAFT");

    const successor = CreateRecipeVersion(fixture(), {
      recipeVersionId: "recipe-pumpkin-v3",
      recipeId: "recipe-pumpkin-soup",
      basedOnRecipeVersionId: "recipe-pumpkin-v1",
      copyLines: true,
      ...audit,
    });
    expect(successor.accepted).toBe(true);
    expect(
      successor.state.recipeVersions.find(
        (version) => version.recipeVersionId === "recipe-pumpkin-v3",
      ),
    ).toMatchObject({ status: "DRAFT", versionNumber: 3 });
    expect(
      successor.state.recipeLines.filter(
        (line) => line.recipeVersionId === "recipe-pumpkin-v3",
      ),
    ).toHaveLength(2);
  });

  it("gates BOM add, update, remove, and school-type variants through audited commands", () => {
    let state = fixture();
    const add = AddRecipeLine(state, {
      recipeLineId: "fish-v1-rice",
      recipeVersionId: "recipe-fish-v1",
      ingredientId: "ingredient-rice",
      quantity: 0.1,
      unit: "kg",
      ...audit,
    });
    expect(add.accepted).toBe(true);
    state = add.state;
    expect(state.recipeMasterDataChanges.at(-1)?.changeType).toBe(
      "RecipeLineAdded",
    );

    const update = UpdateRecipeLine(state, {
      recipeLineId: "fish-v1-rice",
      recipeVersionId: "recipe-fish-v1",
      ingredientId: "ingredient-rice",
      quantity: 0.12,
      unit: "kg",
      ...audit,
    });
    expect(update.accepted).toBe(true);
    state = update.state;
    expect(state.recipeMasterDataChanges.at(-1)?.changeType).toBe(
      "RecipeLineUpdated",
    );

    const variant = SetRecipeSchoolTypeVariant(state, {
      schoolTypeRecipeVariantId: "fish-v1-primary-rice",
      recipeVersionId: "recipe-fish-v1",
      schoolTypeId: "school-type-primary",
      recipeLineId: "fish-v1-rice",
      quantity: 0.1,
      unit: "kg",
      ...audit,
    });
    expect(variant.accepted).toBe(true);
    state = variant.state;
    expect(state.recipeMasterDataChanges.at(-1)?.changeType).toBe(
      "RecipeSchoolTypeVariantSet",
    );

    const remove = RemoveRecipeLine(state, {
      recipeVersionId: "recipe-fish-v1",
      recipeLineId: "fish-v1-rice",
      ...audit,
    });
    expect(remove.accepted).toBe(true);
    expect(remove.state.recipeMasterDataChanges.at(-1)?.changeType).toBe(
      "RecipeLineRemoved",
    );
    expect(
      remove.state.schoolTypeVariants.some(
        (item) => item.recipeLineId === "fish-v1-rice",
      ),
    ).toBe(false);
  });

  it("blocks invalid ingredient, quantity, unit, duplicate-line, and missing-variant rules", () => {
    const base = fixture();
    const invalid: DishRecipeAdminState = {
      ...base,
      recipeLines: [
        ...base.recipeLines,
        {
          recipeLineId: "fish-v1-rice-a",
          recipeVersionId: "recipe-fish-v1",
          ingredientId: "ingredient-rice",
          quantity: 1,
          unit: "unsupported-unit",
        },
        {
          recipeLineId: "fish-v1-rice-b",
          recipeVersionId: "recipe-fish-v1",
          ingredientId: "ingredient-rice",
          quantity: 1,
          unit: "kg",
        },
        {
          recipeLineId: "fish-v1-inactive",
          recipeVersionId: "recipe-fish-v1",
          ingredientId: "ingredient-old-oil",
          quantity: 1,
          unit: "liter",
        },
      ],
    };
    const codes = recipeVersionIssues(invalid, "recipe-fish-v1").map(
      (issue) => issue.issueCode,
    );
    expect(codes).toEqual(
      expect.arrayContaining([
        "INGREDIENT_MISSING",
        "INVALID_QUANTITY",
        "UNIT_MISMATCH",
        "DUPLICATE_RECIPE_LINE",
        "INACTIVE_INGREDIENT_OVERRIDE_REQUIRED",
        "SCHOOL_TYPE_VARIANT_MISSING",
      ]),
    );
    expect(
      ValidateRecipeVersion(invalid, {
        recipeVersionId: "recipe-fish-v1",
        ...audit,
      }).accepted,
    ).toBe(false);
  });

  it("keeps released and locked versions immutable and requires a successor correction", () => {
    for (const recipeVersionId of ["recipe-pumpkin-v1", "recipe-rice-v1"]) {
      const result = UpdateRecipeLine(fixture(), {
        recipeLineId:
          recipeVersionId === "recipe-pumpkin-v1"
            ? "pumpkin-v1-rice"
            : "rice-v1-rice",
        recipeVersionId,
        ingredientId: "ingredient-rice",
        quantity: 999,
        unit: "kg",
        ...audit,
      });
      expect(result.accepted).toBe(false);
      expect(result.blockers[0]?.issueCode).toBe("VERSION_IMMUTABLE");
    }

    const successor = CreateRecipeVersion(fixture(), {
      recipeVersionId: "recipe-pumpkin-v3",
      recipeId: "recipe-pumpkin-soup",
      basedOnRecipeVersionId: "recipe-pumpkin-v1",
      copyLines: true,
      ...audit,
    });
    expect(successor.accepted).toBe(true);
    expect(
      successor.state.recipeVersions.find(
        (version) => version.recipeVersionId === "recipe-pumpkin-v1",
      )?.status,
    ).toBe("LOCKED");
  });

  it("releases only validated versions, preserves recipeVersionId, and never mutates prior operational facts", () => {
    const before = fixture();
    const priorFacts = structuredClone(before.downstreamRecipeUsage);
    expect(
      ReleaseRecipeVersionForPlanning(before, {
        recipeVersionId: "recipe-pumpkin-v2",
        ...audit,
      }).accepted,
    ).toBe(false);

    const validated = ValidateRecipeVersion(before, {
      recipeVersionId: "recipe-pumpkin-v2",
      ...audit,
    });
    expect(validated.accepted).toBe(true);
    const released = ReleaseRecipeVersionForPlanning(validated.state, {
      recipeVersionId: "recipe-pumpkin-v2",
      ...audit,
    });
    expect(released.accepted).toBe(true);
    expect(released.releasedReference).toMatchObject({
      recipeVersionId: "recipe-pumpkin-v2",
      effect: "FUTURE_PLANNING_REFERENCE_ONLY",
    });
    expect(released.state.downstreamRecipeUsage).toEqual(priorFacts);

    const rewrite = ReleaseRecipeVersionForPlanning(validated.state, {
      recipeVersionId: "recipe-pumpkin-v2",
      rewritePriorOperationalFacts: true,
      ...audit,
    });
    expect(rewrite.accepted).toBe(false);
    expect(rewrite.blockers[0]?.issueCode).toBe("PRIOR_FACT_REWRITE_FORBIDDEN");
  });

  it("records change review without granting QA or Production approval", () => {
    const version = CreateRecipeVersion(fixture(), {
      recipeVersionId: "recipe-rice-v2",
      recipeId: "recipe-steamed-rice",
      basedOnRecipeVersionId: "recipe-rice-v1",
      copyLines: true,
      ...audit,
    });
    const changeSet = CreateRecipeChangeSet(version.state, {
      recipeChangeSetId: "rice-change-v2",
      recipeId: "recipe-steamed-rice",
      fromRecipeVersionId: "recipe-rice-v1",
      toRecipeVersionId: "recipe-rice-v2",
      summary: "Adjust rice portion",
      ...audit,
    });
    expect(changeSet.accepted).toBe(true);
    expect(
      ApproveRecipeChangeSet(changeSet.state, {
        recipeChangeSetId: "rice-change-v2",
        evidence: "Admin BOM review",
        requestedApprovalScope: "QA",
        ...audit,
      }).accepted,
    ).toBe(false);

    const approved = ApproveRecipeChangeSet(changeSet.state, {
      recipeChangeSetId: "rice-change-v2",
      evidence: "Admin BOM review",
      requestedApprovalScope: "ADMIN_RECIPE_MASTER_DATA",
      ...audit,
    });
    expect(approved.accepted).toBe(true);
    expect(approved.state.recipeReviewEvidence.at(-1)).toMatchObject({
      grantsQaApproval: false,
      grantsProductionApproval: false,
    });
  });

  it("builds one decision-first read model with versions, locks, BOM, variants, evidence, blockers, and warnings", () => {
    const model = DishRecipeAdminWorkbench(
      fixture(),
      "dish-pumpkin-soup",
      "recipe-pumpkin-v2",
    );
    expect(model.selectedDish.dishName).toBe("Pumpkin soup");
    expect(
      model.versions.some((version) => version.lockStatus === "LOCKED"),
    ).toBe(true);
    expect(model.lines.length).toBeGreaterThan(0);
    expect(model.variants.length).toBeGreaterThan(0);
    expect(model.changeSets.length).toBeGreaterThan(0);
    expect(model.reviewEvidence.length).toBeGreaterThan(0);
    expect(model.warnings.map((issue) => issue.issueCode)).toEqual(
      expect.arrayContaining([
        "VARIANT_DIFFERS_FROM_BASE",
        "UNIT_CONVERSION_REVIEW",
        "OLDER_VERSION_REFERENCED",
      ]),
    );
    expect(model.boundaryNote).toMatch(/never rewrites prior Planning/);
  });
});
