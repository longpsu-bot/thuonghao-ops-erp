import type {
  Ingredient,
  UnitConversionRule,
} from "./ingredientSupplierAdminDomain";

export type DishStatus = "DRAFT" | "ACTIVE" | "INACTIVE";
export type RecipeVersionStatus =
  "DRAFT" | "VALIDATED" | "RELEASED_FOR_PLANNING" | "LOCKED";
export type RecipeChangeSetStatus = "DRAFT" | "APPROVED";
export type RecipeIssueSeverity = "BLOCKING" | "WARNING";

type AuditInput = { actorId: string; at: string; reason: string };

export type DishStatusChange = {
  dishStatusChangeId: string;
  dishId: string;
  beforeStatus: DishStatus;
  afterStatus: DishStatus;
  actorId: string;
  at: string;
  reason: string;
};

export type DishMasterDataChange = {
  dishMasterDataChangeId: string;
  dishId: string;
  changeType:
    "DishCreated" | "DishProfileUpdated" | "DishActivated" | "DishDeactivated";
  actorId: string;
  at: string;
  reason: string;
  before?: string;
  after?: string;
};

export type Dish = {
  dishId: string;
  dishName: string;
  dishCategory?: string;
  status: DishStatus;
  displayOrder?: number;
  operationalNotes?: string;
  requiresNeedGeneration: boolean;
  statusChanges: readonly DishStatusChange[];
  masterDataChanges: readonly DishMasterDataChange[];
};

export type Recipe = {
  recipeId: string;
  dishId: string;
  recipeName: string;
  createdBy: string;
  createdAt: string;
};

export type RecipeVersion = {
  recipeVersionId: string;
  recipeId: string;
  versionNumber: number;
  status: RecipeVersionStatus;
  basedOnRecipeVersionId?: string;
  requiredSchoolTypeIds: readonly string[];
  createdBy: string;
  createdAt: string;
  validatedBy?: string;
  validatedAt?: string;
  releasedBy?: string;
  releasedAt?: string;
};

export type RecipeLock = {
  recipeLockId: string;
  recipeVersionId: string;
  status: "LOCKED" | "UNLOCKED";
  actorId: string;
  at: string;
  reason: string;
  approvedChangeSetId?: string;
};

export type RecipeLine = {
  recipeLineId: string;
  recipeVersionId: string;
  ingredientId: string;
  quantity: number;
  unit: string;
  notes?: string;
  inactiveIngredientOverrideEvidence?: string;
};

export type BOMLine = RecipeLine;

export type SchoolTypeRecipeVariant = {
  schoolTypeRecipeVariantId: string;
  recipeVersionId: string;
  schoolTypeId: string;
  recipeLineId: string;
  quantity: number;
  unit: string;
  reason: string;
};

export type RecipeChangeSet = {
  recipeChangeSetId: string;
  recipeId: string;
  fromRecipeVersionId: string;
  toRecipeVersionId: string;
  status: RecipeChangeSetStatus;
  summary: string;
  reason: string;
  actorId: string;
  at: string;
  approvedBy?: string;
  approvedAt?: string;
};

export type RecipeReviewEvidence = {
  recipeReviewEvidenceId: string;
  recipeChangeSetId: string;
  recipeVersionId: string;
  reviewScope: "ADMIN_RECIPE_MASTER_DATA";
  outcome: "APPROVED_FOR_RECIPE_RELEASE";
  actorId: string;
  at: string;
  evidence: string;
  grantsQaApproval: false;
  grantsProductionApproval: false;
};

export type RecipeMasterDataChange = {
  recipeMasterDataChangeId: string;
  recipeId: string;
  recipeVersionId?: string;
  recipeLineId?: string;
  changeType:
    | "RecipeDraftCreated"
    | "RecipeVersionCreated"
    | "RecipeLineAdded"
    | "RecipeLineUpdated"
    | "RecipeLineRemoved"
    | "RecipeSchoolTypeVariantSet"
    | "RecipeVersionValidated"
    | "RecipeVersionLocked"
    | "RecipeVersionUnlocked"
    | "RecipeChangeSetCreated"
    | "RecipeChangeSetApproved"
    | "RecipeVersionReleasedForPlanning"
    | "RecipeMasterDataChangeRecorded";
  actorId: string;
  at: string;
  reason: string;
  before?: string;
  after?: string;
};

export type ReleasedRecipeReference = {
  releasedRecipeReferenceId: string;
  dishId: string;
  recipeId: string;
  recipeVersionId: string;
  releasedAt: string;
  releasedBy: string;
  effect: "FUTURE_PLANNING_REFERENCE_ONLY";
};

export type DownstreamRecipeUsage = {
  usageId: string;
  recipeVersionId: string;
  domain:
    "PLANNING" | "NEED_GENERATION" | "CONFIRMED_NEED" | "PURCHASE_HANDOFF";
  referenceId: string;
  recordedAt: string;
};

export type DishRecipeAdminState = {
  dishes: readonly Dish[];
  recipes: readonly Recipe[];
  recipeVersions: readonly RecipeVersion[];
  recipeLocks: readonly RecipeLock[];
  recipeLines: readonly RecipeLine[];
  schoolTypeVariants: readonly SchoolTypeRecipeVariant[];
  recipeChangeSets: readonly RecipeChangeSet[];
  recipeReviewEvidence: readonly RecipeReviewEvidence[];
  recipeMasterDataChanges: readonly RecipeMasterDataChange[];
  ingredients: readonly Ingredient[];
  unitConversionRules: readonly UnitConversionRule[];
  releasedRecipeReferences: readonly ReleasedRecipeReference[];
  downstreamRecipeUsage: readonly DownstreamRecipeUsage[];
};

export type DishRecipeIssue = {
  objectId: string;
  severity: RecipeIssueSeverity;
  issueCode:
    | "DISH_NAME_MISSING"
    | "DUPLICATE_ACTIVE_DISH"
    | "INACTIVE_DISH_OVERRIDE_REQUIRED"
    | "RECIPE_MISSING"
    | "INGREDIENT_MISSING"
    | "INACTIVE_INGREDIENT_OVERRIDE_REQUIRED"
    | "INVALID_QUANTITY"
    | "UNIT_MISMATCH"
    | "DUPLICATE_RECIPE_LINE"
    | "SCHOOL_TYPE_VARIANT_MISSING"
    | "VERSION_IMMUTABLE"
    | "INVALID_VERSION_RELEASE"
    | "PRIOR_FACT_REWRITE_FORBIDDEN"
    | "RECIPE_APPROVAL_SCOPE_INVALID"
    | "NO_RELEASED_RECIPE"
    | "LOCKED_VERSION_USES_INACTIVE_INGREDIENT"
    | "CHANGED_AFTER_PLANNING"
    | "VARIANT_DIFFERS_FROM_BASE"
    | "UNIT_CONVERSION_REVIEW"
    | "OLDER_VERSION_REFERENCED";
  message: string;
  isBlocking: boolean;
};

export type DishRecipeCommandResult = {
  state: DishRecipeAdminState;
  accepted: boolean;
  message?: string;
  blockers: readonly DishRecipeIssue[];
  releasedReference?: ReleasedRecipeReference;
};

const normalized = (value: string) => value.trim().toLocaleLowerCase();
const accepted = (
  state: DishRecipeAdminState,
  releasedReference?: ReleasedRecipeReference,
): DishRecipeCommandResult => ({
  state,
  accepted: true,
  blockers: [],
  releasedReference,
});
const rejected = (
  state: DishRecipeAdminState,
  message: string,
  blockers: readonly DishRecipeIssue[] = [],
): DishRecipeCommandResult => ({
  state,
  accepted: false,
  message,
  blockers,
});
const dishById = (state: DishRecipeAdminState, id: string) =>
  state.dishes.find((item) => item.dishId === id);
const recipeById = (state: DishRecipeAdminState, id: string) =>
  state.recipes.find((item) => item.recipeId === id);
const versionById = (state: DishRecipeAdminState, id: string) =>
  state.recipeVersions.find((item) => item.recipeVersionId === id);
const ingredientById = (state: DishRecipeAdminState, id: string) =>
  state.ingredients.find((item) => item.ingredientId === id);
const currentLock = (state: DishRecipeAdminState, recipeVersionId: string) =>
  [...state.recipeLocks]
    .reverse()
    .find((item) => item.recipeVersionId === recipeVersionId);
const isImmutable = (state: DishRecipeAdminState, version: RecipeVersion) =>
  version.status === "RELEASED_FOR_PLANNING" ||
  version.status === "LOCKED" ||
  currentLock(state, version.recipeVersionId)?.status === "LOCKED";

function replaceDish(state: DishRecipeAdminState, next: Dish) {
  return {
    ...state,
    dishes: state.dishes.map((item) =>
      item.dishId === next.dishId ? next : item,
    ),
  };
}

function replaceVersion(state: DishRecipeAdminState, next: RecipeVersion) {
  return {
    ...state,
    recipeVersions: state.recipeVersions.map((item) =>
      item.recipeVersionId === next.recipeVersionId ? next : item,
    ),
  };
}

function auditChange(
  state: DishRecipeAdminState,
  input: AuditInput & {
    recipeId: string;
    recipeVersionId?: string;
    recipeLineId?: string;
    changeType: RecipeMasterDataChange["changeType"];
    before?: string;
    after?: string;
  },
) {
  const change: RecipeMasterDataChange = {
    recipeMasterDataChangeId: `recipe-change-${state.recipeMasterDataChanges.length + 1}`,
    ...input,
  };
  return {
    ...state,
    recipeMasterDataChanges: [...state.recipeMasterDataChanges, change],
  };
}

function conversionExists(
  state: DishRecipeAdminState,
  ingredientId: string,
  fromUnit: string,
  toUnit: string,
) {
  if (fromUnit === toUnit) return true;
  return state.unitConversionRules.some(
    (rule) =>
      rule.status === "ACTIVE" &&
      (!rule.ingredientId || rule.ingredientId === ingredientId) &&
      ((rule.fromUnit === fromUnit && rule.toUnit === toUnit) ||
        (rule.fromUnit === toUnit && rule.toUnit === fromUnit)),
  );
}

export function recipeVersionIssues(
  state: DishRecipeAdminState,
  recipeVersionId: string,
): DishRecipeIssue[] {
  const version = versionById(state, recipeVersionId);
  if (!version) return [];
  const recipe = recipeById(state, version.recipeId);
  const dish = recipe ? dishById(state, recipe.dishId) : undefined;
  const lines = state.recipeLines.filter(
    (line) => line.recipeVersionId === recipeVersionId,
  );
  const issues: DishRecipeIssue[] = [];
  if (!dish?.dishName.trim())
    issues.push({
      objectId: dish?.dishId ?? version.recipeVersionId,
      severity: "BLOCKING",
      issueCode: "DISH_NAME_MISSING",
      message: "Dish name is required.",
      isBlocking: true,
    });
  if (dish?.requiresNeedGeneration && lines.length === 0)
    issues.push({
      objectId: version.recipeVersionId,
      severity: "BLOCKING",
      issueCode: "RECIPE_MISSING",
      message: "A recipe with BOM lines is required for Need Generation.",
      isBlocking: true,
    });
  for (const line of lines) {
    const ingredient = ingredientById(state, line.ingredientId);
    if (!ingredient)
      issues.push({
        objectId: line.recipeLineId,
        severity: "BLOCKING",
        issueCode: "INGREDIENT_MISSING",
        message: "Recipe line ingredient is missing.",
        isBlocking: true,
      });
    if (
      ingredient?.status === "INACTIVE" &&
      !line.inactiveIngredientOverrideEvidence?.trim()
    )
      issues.push({
        objectId: line.recipeLineId,
        severity: "BLOCKING",
        issueCode: "INACTIVE_INGREDIENT_OVERRIDE_REQUIRED",
        message:
          "Inactive ingredient requires explicit override evidence for a new recipe version.",
        isBlocking: true,
      });
    if (line.quantity <= 0)
      issues.push({
        objectId: line.recipeLineId,
        severity: "BLOCKING",
        issueCode: "INVALID_QUANTITY",
        message: "Recipe line quantity must be greater than zero.",
        isBlocking: true,
      });
    if (
      ingredient &&
      line.unit !== ingredient.unitProfile.planningUnit &&
      !conversionExists(
        state,
        ingredient.ingredientId,
        line.unit,
        ingredient.unitProfile.planningUnit,
      )
    )
      issues.push({
        objectId: line.recipeLineId,
        severity: "BLOCKING",
        issueCode: "UNIT_MISMATCH",
        message:
          "Recipe unit does not match the Admin planning unit and has no approved conversion.",
        isBlocking: true,
      });
    else if (ingredient && line.unit !== ingredient.unitProfile.planningUnit)
      issues.push({
        objectId: line.recipeLineId,
        severity: "WARNING",
        issueCode: "UNIT_CONVERSION_REVIEW",
        message:
          "An approved unit conversion exists and needs operator review.",
        isBlocking: false,
      });
  }
  const duplicateIngredients = new Set<string>();
  for (const line of lines) {
    if (
      lines.some(
        (other) =>
          other.recipeLineId !== line.recipeLineId &&
          other.ingredientId === line.ingredientId,
      )
    )
      duplicateIngredients.add(line.ingredientId);
  }
  for (const ingredientId of duplicateIngredients)
    issues.push({
      objectId: ingredientId,
      severity: "BLOCKING",
      issueCode: "DUPLICATE_RECIPE_LINE",
      message:
        "Duplicate ingredient lines are not allowed in one recipe version.",
      isBlocking: true,
    });
  for (const schoolTypeId of version.requiredSchoolTypeIds) {
    if (
      !state.schoolTypeVariants.some(
        (variant) =>
          variant.recipeVersionId === version.recipeVersionId &&
          variant.schoolTypeId === schoolTypeId,
      )
    )
      issues.push({
        objectId: version.recipeVersionId,
        severity: "BLOCKING",
        issueCode: "SCHOOL_TYPE_VARIANT_MISSING",
        message: `Required school-type variant ${schoolTypeId} is missing.`,
        isBlocking: true,
      });
  }
  if (
    version.status === "LOCKED" &&
    lines.some(
      (line) => ingredientById(state, line.ingredientId)?.status === "INACTIVE",
    )
  )
    issues.push({
      objectId: version.recipeVersionId,
      severity: "WARNING",
      issueCode: "LOCKED_VERSION_USES_INACTIVE_INGREDIENT",
      message:
        "This historical locked version retains an inactive ingredient reference.",
      isBlocking: false,
    });
  if (
    state.schoolTypeVariants.some(
      (variant) =>
        variant.recipeVersionId === version.recipeVersionId &&
        lines.some(
          (line) =>
            line.recipeLineId === variant.recipeLineId &&
            (line.quantity !== variant.quantity || line.unit !== variant.unit),
        ),
    )
  )
    issues.push({
      objectId: version.recipeVersionId,
      severity: "WARNING",
      issueCode: "VARIANT_DIFFERS_FROM_BASE",
      message: "A school-type variant differs from the base recipe.",
      isBlocking: false,
    });
  const usage = state.downstreamRecipeUsage.filter((item) => {
    const usedVersion = versionById(state, item.recipeVersionId);
    return usedVersion?.recipeId === version.recipeId;
  });
  if (
    usage.some(
      (item) =>
        item.recipeVersionId !== version.recipeVersionId &&
        (version.createdAt > item.recordedAt ||
          version.validatedAt! > item.recordedAt),
    )
  )
    issues.push({
      objectId: version.recipeVersionId,
      severity: "WARNING",
      issueCode: "CHANGED_AFTER_PLANNING",
      message: "Recipe changed after a recent Planning run.",
      isBlocking: false,
    });
  if (usage.some((item) => item.recipeVersionId !== version.recipeVersionId))
    issues.push({
      objectId: version.recipeVersionId,
      severity: "WARNING",
      issueCode: "OLDER_VERSION_REFERENCED",
      message: "Downstream domains already reference an older recipe version.",
      isBlocking: false,
    });
  return issues;
}

export function dishIssues(
  state: DishRecipeAdminState,
  dish: Dish,
): DishRecipeIssue[] {
  const issues: DishRecipeIssue[] = [];
  if (!dish.dishName.trim())
    issues.push({
      objectId: dish.dishId,
      severity: "BLOCKING",
      issueCode: "DISH_NAME_MISSING",
      message: "Dish name is required.",
      isBlocking: true,
    });
  const recipeIds = state.recipes
    .filter((recipe) => recipe.dishId === dish.dishId)
    .map((recipe) => recipe.recipeId);
  if (
    dish.status === "ACTIVE" &&
    !state.recipeVersions.some(
      (version) =>
        recipeIds.includes(version.recipeId) &&
        (version.status === "RELEASED_FOR_PLANNING" ||
          version.status === "LOCKED"),
    )
  )
    issues.push({
      objectId: dish.dishId,
      severity: "WARNING",
      issueCode: "NO_RELEASED_RECIPE",
      message: "Active dish has no released recipe version.",
      isBlocking: false,
    });
  return issues;
}

export function CreateDish(
  state: DishRecipeAdminState,
  input: Omit<Dish, "statusChanges" | "masterDataChanges"> & AuditInput,
) {
  if (!input.dishName.trim())
    return rejected(state, "Dish name is required.", [
      {
        objectId: input.dishId,
        severity: "BLOCKING",
        issueCode: "DISH_NAME_MISSING",
        message: "Dish name is required.",
        isBlocking: true,
      },
    ]);
  if (
    input.status === "ACTIVE" &&
    state.dishes.some(
      (dish) =>
        dish.status === "ACTIVE" &&
        normalized(dish.dishName) === normalized(input.dishName),
    )
  )
    return rejected(state, "Duplicate active dish identity is not allowed.", [
      {
        objectId: input.dishId,
        severity: "BLOCKING",
        issueCode: "DUPLICATE_ACTIVE_DISH",
        message: "An active dish with this name already exists.",
        isBlocking: true,
      },
    ]);
  if (!input.reason.trim())
    return rejected(state, "A creation reason is required.");
  const dish: Dish = {
    ...input,
    dishName: input.dishName.trim(),
    statusChanges: [],
    masterDataChanges: [],
  };
  dish.masterDataChanges = [
    {
      dishMasterDataChangeId: `${dish.dishId}-change-1`,
      dishId: dish.dishId,
      changeType: "DishCreated",
      actorId: input.actorId,
      at: input.at,
      reason: input.reason,
    },
  ];
  return accepted({ ...state, dishes: [...state.dishes, dish] });
}

export function UpdateDishProfile(
  state: DishRecipeAdminState,
  input: {
    dishId: string;
    dishName: string;
    dishCategory?: string;
    displayOrder?: number;
    operationalNotes?: string;
    requiresNeedGeneration: boolean;
  } & AuditInput,
) {
  const current = dishById(state, input.dishId);
  if (!current) return rejected(state, "Dish was not found.");
  if (!input.dishName.trim()) return rejected(state, "Dish name is required.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  if (
    current.status === "ACTIVE" &&
    state.dishes.some(
      (dish) =>
        dish.dishId !== current.dishId &&
        dish.status === "ACTIVE" &&
        normalized(dish.dishName) === normalized(input.dishName),
    )
  )
    return rejected(state, "Duplicate active dish identity is not allowed.");
  const next: Dish = {
    ...current,
    dishName: input.dishName.trim(),
    dishCategory: input.dishCategory,
    displayOrder: input.displayOrder,
    operationalNotes: input.operationalNotes,
    requiresNeedGeneration: input.requiresNeedGeneration,
    masterDataChanges: [
      ...current.masterDataChanges,
      {
        dishMasterDataChangeId: `${current.dishId}-change-${current.masterDataChanges.length + 1}`,
        dishId: current.dishId,
        changeType: "DishProfileUpdated",
        actorId: input.actorId,
        at: input.at,
        reason: input.reason,
        before: current.dishName,
        after: input.dishName.trim(),
      },
    ],
  };
  return accepted(replaceDish(state, next));
}

export function SetDishStatus(
  state: DishRecipeAdminState,
  input: { dishId: string; status: DishStatus } & AuditInput,
) {
  const current = dishById(state, input.dishId);
  if (!current) return rejected(state, "Dish was not found.");
  if (current.status === input.status)
    return rejected(state, "Dish status is already set.");
  if (!input.reason.trim())
    return rejected(state, "A status-change reason is required.");
  const allowedTransition =
    (current.status === "DRAFT" && input.status === "ACTIVE") ||
    (current.status === "ACTIVE" && input.status === "INACTIVE") ||
    (current.status === "INACTIVE" && input.status === "ACTIVE");
  if (!allowedTransition)
    return rejected(
      state,
      "Dish status must follow DRAFT → ACTIVE → INACTIVE, with explicit evidence for reactivation.",
    );
  if (
    input.status === "ACTIVE" &&
    state.dishes.some(
      (dish) =>
        dish.dishId !== current.dishId &&
        dish.status === "ACTIVE" &&
        normalized(dish.dishName) === normalized(current.dishName),
    )
  )
    return rejected(state, "Duplicate active dish identity is not allowed.");
  const statusChange: DishStatusChange = {
    dishStatusChangeId: `${current.dishId}-status-${current.statusChanges.length + 1}`,
    dishId: current.dishId,
    beforeStatus: current.status,
    afterStatus: input.status,
    actorId: input.actorId,
    at: input.at,
    reason: input.reason,
  };
  const changeType =
    input.status === "ACTIVE" ? "DishActivated" : "DishDeactivated";
  return accepted(
    replaceDish(state, {
      ...current,
      status: input.status,
      statusChanges: [...current.statusChanges, statusChange],
      masterDataChanges: [
        ...current.masterDataChanges,
        {
          dishMasterDataChangeId: `${current.dishId}-change-${current.masterDataChanges.length + 1}`,
          dishId: current.dishId,
          changeType,
          actorId: input.actorId,
          at: input.at,
          reason: input.reason,
          before: current.status,
          after: input.status,
        },
      ],
    }),
  );
}

export function DishMenuReference(
  dish: Dish | undefined,
  explicitOverrideEvidence?: string,
) {
  if (!dish) return { accepted: false, message: "Dish reference is missing." };
  if (dish.status === "INACTIVE" && !explicitOverrideEvidence?.trim())
    return {
      accepted: false,
      message:
        "Inactive dish requires explicit override evidence for a new menu reference.",
    };
  return { accepted: true };
}

export function CreateRecipeDraft(
  state: DishRecipeAdminState,
  input: {
    recipeId: string;
    recipeVersionId: string;
    dishId: string;
    recipeName: string;
    requiredSchoolTypeIds?: readonly string[];
  } & AuditInput,
) {
  if (!dishById(state, input.dishId))
    return rejected(state, "Dish was not found.");
  if (state.recipes.some((recipe) => recipe.recipeId === input.recipeId))
    return rejected(state, "Recipe identity already exists.");
  if (!input.recipeName.trim() || !input.reason.trim())
    return rejected(state, "Recipe name and creation reason are required.");
  const recipe: Recipe = {
    recipeId: input.recipeId,
    dishId: input.dishId,
    recipeName: input.recipeName.trim(),
    createdBy: input.actorId,
    createdAt: input.at,
  };
  const version: RecipeVersion = {
    recipeVersionId: input.recipeVersionId,
    recipeId: input.recipeId,
    versionNumber: 1,
    status: "DRAFT",
    requiredSchoolTypeIds: input.requiredSchoolTypeIds ?? [],
    createdBy: input.actorId,
    createdAt: input.at,
  };
  return accepted(
    auditChange(
      {
        ...state,
        recipes: [...state.recipes, recipe],
        recipeVersions: [...state.recipeVersions, version],
      },
      {
        ...input,
        changeType: "RecipeDraftCreated",
        recipeId: input.recipeId,
        recipeVersionId: input.recipeVersionId,
      },
    ),
  );
}

export function CreateRecipeVersion(
  state: DishRecipeAdminState,
  input: {
    recipeVersionId: string;
    recipeId: string;
    basedOnRecipeVersionId: string;
    requiredSchoolTypeIds?: readonly string[];
    copyLines?: boolean;
  } & AuditInput,
) {
  const recipe = recipeById(state, input.recipeId);
  const base = versionById(state, input.basedOnRecipeVersionId);
  if (!recipe || !base || base.recipeId !== recipe.recipeId)
    return rejected(state, "Recipe or base version was not found.");
  if (
    state.recipeVersions.some(
      (version) => version.recipeVersionId === input.recipeVersionId,
    )
  )
    return rejected(state, "Recipe version identity already exists.");
  if (!input.reason.trim())
    return rejected(state, "A version reason is required.");
  const version: RecipeVersion = {
    recipeVersionId: input.recipeVersionId,
    recipeId: recipe.recipeId,
    versionNumber:
      Math.max(
        ...state.recipeVersions
          .filter((item) => item.recipeId === recipe.recipeId)
          .map((item) => item.versionNumber),
      ) + 1,
    status: "DRAFT",
    basedOnRecipeVersionId: base.recipeVersionId,
    requiredSchoolTypeIds:
      input.requiredSchoolTypeIds ?? base.requiredSchoolTypeIds,
    createdBy: input.actorId,
    createdAt: input.at,
  };
  const copiedLines = input.copyLines
    ? state.recipeLines
        .filter((line) => line.recipeVersionId === base.recipeVersionId)
        .map((line) => ({
          ...line,
          recipeLineId: `${input.recipeVersionId}-${line.recipeLineId}`,
          recipeVersionId: input.recipeVersionId,
          inactiveIngredientOverrideEvidence: undefined,
        }))
    : [];
  return accepted(
    auditChange(
      {
        ...state,
        recipeVersions: [...state.recipeVersions, version],
        recipeLines: [...state.recipeLines, ...copiedLines],
      },
      {
        ...input,
        changeType: "RecipeVersionCreated",
        recipeVersionId: version.recipeVersionId,
      },
    ),
  );
}

function editableVersion(
  state: DishRecipeAdminState,
  recipeVersionId: string,
): { version?: RecipeVersion; rejection?: DishRecipeCommandResult } {
  const version = versionById(state, recipeVersionId);
  if (!version)
    return { rejection: rejected(state, "Recipe version was not found.") };
  if (isImmutable(state, version))
    return {
      version,
      rejection: rejected(
        state,
        "Released or locked recipe versions cannot be edited; create a new version or change set.",
        [
          {
            objectId: recipeVersionId,
            severity: "BLOCKING",
            issueCode: "VERSION_IMMUTABLE",
            message:
              "Released or locked recipe versions cannot be edited directly.",
            isBlocking: true,
          },
        ],
      ),
    };
  if (version.status !== "DRAFT")
    return {
      version,
      rejection: rejected(
        state,
        "Validated versions require a new draft version before line changes.",
      ),
    };
  return { version };
}

export function AddRecipeLine(
  state: DishRecipeAdminState,
  input: RecipeLine & AuditInput,
) {
  const check = editableVersion(state, input.recipeVersionId);
  if (check.rejection) return check.rejection;
  if (!input.reason.trim())
    return rejected(state, "A line-change reason is required.");
  if (
    state.recipeLines.some((line) => line.recipeLineId === input.recipeLineId)
  )
    return rejected(state, "Recipe line identity already exists.");
  const next = {
    ...state,
    recipeLines: [
      ...state.recipeLines,
      {
        recipeLineId: input.recipeLineId,
        recipeVersionId: input.recipeVersionId,
        ingredientId: input.ingredientId,
        quantity: input.quantity,
        unit: input.unit,
        notes: input.notes,
        inactiveIngredientOverrideEvidence:
          input.inactiveIngredientOverrideEvidence,
      },
    ],
  };
  return accepted(
    auditChange(next, {
      ...input,
      recipeId: check.version!.recipeId,
      changeType: "RecipeLineAdded",
    }),
  );
}

export function UpdateRecipeLine(
  state: DishRecipeAdminState,
  input: RecipeLine & AuditInput,
) {
  const check = editableVersion(state, input.recipeVersionId);
  if (check.rejection) return check.rejection;
  const current = state.recipeLines.find(
    (line) => line.recipeLineId === input.recipeLineId,
  );
  if (!current || current.recipeVersionId !== input.recipeVersionId)
    return rejected(state, "Recipe line was not found.");
  if (!input.reason.trim())
    return rejected(state, "A line-change reason is required.");
  const line: RecipeLine = {
    recipeLineId: input.recipeLineId,
    recipeVersionId: input.recipeVersionId,
    ingredientId: input.ingredientId,
    quantity: input.quantity,
    unit: input.unit,
    notes: input.notes,
    inactiveIngredientOverrideEvidence:
      input.inactiveIngredientOverrideEvidence,
  };
  return accepted(
    auditChange(
      {
        ...state,
        recipeLines: state.recipeLines.map((item) =>
          item.recipeLineId === line.recipeLineId ? line : item,
        ),
      },
      {
        ...input,
        recipeId: check.version!.recipeId,
        changeType: "RecipeLineUpdated",
        before: JSON.stringify(current),
        after: JSON.stringify(line),
      },
    ),
  );
}

export function RemoveRecipeLine(
  state: DishRecipeAdminState,
  input: { recipeVersionId: string; recipeLineId: string } & AuditInput,
) {
  const check = editableVersion(state, input.recipeVersionId);
  if (check.rejection) return check.rejection;
  const current = state.recipeLines.find(
    (line) => line.recipeLineId === input.recipeLineId,
  );
  if (!current || current.recipeVersionId !== input.recipeVersionId)
    return rejected(state, "Recipe line was not found.");
  if (!input.reason.trim())
    return rejected(state, "A line-change reason is required.");
  return accepted(
    auditChange(
      {
        ...state,
        recipeLines: state.recipeLines.filter(
          (line) => line.recipeLineId !== input.recipeLineId,
        ),
        schoolTypeVariants: state.schoolTypeVariants.filter(
          (variant) => variant.recipeLineId !== input.recipeLineId,
        ),
      },
      {
        ...input,
        recipeId: check.version!.recipeId,
        changeType: "RecipeLineRemoved",
        before: JSON.stringify(current),
      },
    ),
  );
}

export function SetRecipeSchoolTypeVariant(
  state: DishRecipeAdminState,
  input: SchoolTypeRecipeVariant & AuditInput,
) {
  const check = editableVersion(state, input.recipeVersionId);
  if (check.rejection) return check.rejection;
  if (
    !state.recipeLines.some((line) => line.recipeLineId === input.recipeLineId)
  )
    return rejected(state, "Base recipe line was not found.");
  if (!input.reason.trim())
    return rejected(state, "A variant reason is required.");
  const current = state.schoolTypeVariants.find(
    (variant) =>
      variant.recipeVersionId === input.recipeVersionId &&
      variant.schoolTypeId === input.schoolTypeId &&
      variant.recipeLineId === input.recipeLineId,
  );
  const variant: SchoolTypeRecipeVariant = {
    schoolTypeRecipeVariantId: input.schoolTypeRecipeVariantId,
    recipeVersionId: input.recipeVersionId,
    schoolTypeId: input.schoolTypeId,
    recipeLineId: input.recipeLineId,
    quantity: input.quantity,
    unit: input.unit,
    reason: input.reason,
  };
  return accepted(
    auditChange(
      {
        ...state,
        schoolTypeVariants: current
          ? state.schoolTypeVariants.map((item) =>
              item.schoolTypeRecipeVariantId ===
              current.schoolTypeRecipeVariantId
                ? variant
                : item,
            )
          : [...state.schoolTypeVariants, variant],
      },
      {
        ...input,
        recipeId: check.version!.recipeId,
        changeType: "RecipeSchoolTypeVariantSet",
        before: current ? JSON.stringify(current) : undefined,
        after: JSON.stringify(variant),
      },
    ),
  );
}

export function ValidateRecipeVersion(
  state: DishRecipeAdminState,
  input: { recipeVersionId: string } & AuditInput,
) {
  const version = versionById(state, input.recipeVersionId);
  if (!version) return rejected(state, "Recipe version was not found.");
  if (version.status !== "DRAFT")
    return rejected(state, "Only a draft recipe version can be validated.");
  if (!input.reason.trim())
    return rejected(state, "A validation reason is required.");
  const blockers = recipeVersionIssues(state, input.recipeVersionId).filter(
    (issue) => issue.isBlocking,
  );
  if (blockers.length)
    return rejected(
      state,
      "Recipe version has blocking validation issues.",
      blockers,
    );
  const next = {
    ...version,
    status: "VALIDATED" as const,
    validatedBy: input.actorId,
    validatedAt: input.at,
  };
  return accepted(
    auditChange(replaceVersion(state, next), {
      ...input,
      recipeId: version.recipeId,
      changeType: "RecipeVersionValidated",
      before: version.status,
      after: next.status,
    }),
  );
}

export function LockRecipeVersion(
  state: DishRecipeAdminState,
  input: { recipeVersionId: string } & AuditInput,
) {
  const version = versionById(state, input.recipeVersionId);
  if (!version) return rejected(state, "Recipe version was not found.");
  if (version.status !== "RELEASED_FOR_PLANNING")
    return rejected(state, "Only a released recipe version can be locked.");
  if (!input.reason.trim())
    return rejected(state, "A lock reason is required.");
  const nextVersion = { ...version, status: "LOCKED" as const };
  const lock: RecipeLock = {
    recipeLockId: `${version.recipeVersionId}-lock-${state.recipeLocks.length + 1}`,
    recipeVersionId: version.recipeVersionId,
    status: "LOCKED",
    actorId: input.actorId,
    at: input.at,
    reason: input.reason,
  };
  return accepted(
    auditChange(
      {
        ...replaceVersion(state, nextVersion),
        recipeLocks: [...state.recipeLocks, lock],
      },
      {
        ...input,
        recipeId: version.recipeId,
        changeType: "RecipeVersionLocked",
      },
    ),
  );
}

export function UnlockRecipeVersion(
  state: DishRecipeAdminState,
  input: { recipeVersionId: string; approvedChangeSetId: string } & AuditInput,
) {
  const version = versionById(state, input.recipeVersionId);
  if (!version || version.status !== "LOCKED")
    return rejected(state, "Locked recipe version was not found.");
  const changeSet = state.recipeChangeSets.find(
    (item) =>
      item.recipeChangeSetId === input.approvedChangeSetId &&
      item.fromRecipeVersionId === version.recipeVersionId &&
      item.status === "APPROVED",
  );
  if (!changeSet)
    return rejected(
      state,
      "An approved change set is required to record unlock evidence.",
    );
  if (!input.reason.trim())
    return rejected(state, "An unlock reason is required.");
  const lock: RecipeLock = {
    recipeLockId: `${version.recipeVersionId}-lock-${state.recipeLocks.length + 1}`,
    recipeVersionId: version.recipeVersionId,
    status: "UNLOCKED",
    approvedChangeSetId: changeSet.recipeChangeSetId,
    actorId: input.actorId,
    at: input.at,
    reason: input.reason,
  };
  return accepted(
    auditChange(
      { ...state, recipeLocks: [...state.recipeLocks, lock] },
      {
        ...input,
        recipeId: version.recipeId,
        changeType: "RecipeVersionUnlocked",
        after:
          "Governance unlock evidence recorded; the released version remains immutable.",
      },
    ),
  );
}

export function CreateRecipeChangeSet(
  state: DishRecipeAdminState,
  input: Omit<RecipeChangeSet, "status" | "approvedBy" | "approvedAt">,
) {
  const from = versionById(state, input.fromRecipeVersionId);
  const to = versionById(state, input.toRecipeVersionId);
  if (
    !from ||
    !to ||
    from.recipeId !== input.recipeId ||
    to.recipeId !== input.recipeId
  )
    return rejected(state, "Change-set recipe versions are invalid.");
  if (to.status !== "DRAFT")
    return rejected(state, "A change set must target a draft recipe version.");
  if (!input.summary.trim() || !input.reason.trim())
    return rejected(state, "Change summary and reason are required.");
  const changeSet: RecipeChangeSet = { ...input, status: "DRAFT" };
  return accepted(
    auditChange(
      { ...state, recipeChangeSets: [...state.recipeChangeSets, changeSet] },
      {
        actorId: input.actorId,
        at: input.at,
        reason: input.reason,
        recipeId: input.recipeId,
        recipeVersionId: input.toRecipeVersionId,
        changeType: "RecipeChangeSetCreated",
      },
    ),
  );
}

export function ApproveRecipeChangeSet(
  state: DishRecipeAdminState,
  input: {
    recipeChangeSetId: string;
    evidence: string;
    requestedApprovalScope?: "ADMIN_RECIPE_MASTER_DATA" | "QA" | "PRODUCTION";
  } & AuditInput,
) {
  const current = state.recipeChangeSets.find(
    (item) => item.recipeChangeSetId === input.recipeChangeSetId,
  );
  if (!current) return rejected(state, "Recipe change set was not found.");
  if (current.status !== "DRAFT")
    return rejected(state, "Recipe change set is already approved.");
  if (
    input.requestedApprovalScope === "QA" ||
    input.requestedApprovalScope === "PRODUCTION"
  )
    return rejected(
      state,
      "Recipe approval is not QA or Production approval.",
      [
        {
          objectId: current.recipeChangeSetId,
          severity: "BLOCKING",
          issueCode: "RECIPE_APPROVAL_SCOPE_INVALID",
          message: "Recipe approval cannot grant QA or Production approval.",
          isBlocking: true,
        },
      ],
    );
  if (!input.evidence.trim() || !input.reason.trim())
    return rejected(state, "Review evidence and approval reason are required.");
  const approved: RecipeChangeSet = {
    ...current,
    status: "APPROVED",
    approvedBy: input.actorId,
    approvedAt: input.at,
  };
  const evidence: RecipeReviewEvidence = {
    recipeReviewEvidenceId: `${current.recipeChangeSetId}-evidence-${state.recipeReviewEvidence.length + 1}`,
    recipeChangeSetId: current.recipeChangeSetId,
    recipeVersionId: current.toRecipeVersionId,
    reviewScope: "ADMIN_RECIPE_MASTER_DATA",
    outcome: "APPROVED_FOR_RECIPE_RELEASE",
    actorId: input.actorId,
    at: input.at,
    evidence: input.evidence,
    grantsQaApproval: false,
    grantsProductionApproval: false,
  };
  return accepted(
    auditChange(
      {
        ...state,
        recipeChangeSets: state.recipeChangeSets.map((item) =>
          item.recipeChangeSetId === approved.recipeChangeSetId
            ? approved
            : item,
        ),
        recipeReviewEvidence: [...state.recipeReviewEvidence, evidence],
      },
      {
        ...input,
        recipeId: current.recipeId,
        recipeVersionId: current.toRecipeVersionId,
        changeType: "RecipeChangeSetApproved",
      },
    ),
  );
}

export function ReleaseRecipeVersionForPlanning(
  state: DishRecipeAdminState,
  input: {
    recipeVersionId: string;
    rewritePriorOperationalFacts?: boolean;
    approvalScope?: "ADMIN_RECIPE_MASTER_DATA" | "QA" | "PRODUCTION";
  } & AuditInput,
) {
  const version = versionById(state, input.recipeVersionId);
  if (!version) return rejected(state, "Recipe version was not found.");
  if (input.rewritePriorOperationalFacts)
    return rejected(
      state,
      "Recipe changes cannot rewrite prior Planning or handoff facts.",
      [
        {
          objectId: version.recipeVersionId,
          severity: "BLOCKING",
          issueCode: "PRIOR_FACT_REWRITE_FORBIDDEN",
          message:
            "Released Planning, Need Generation, Confirmed Need, and Purchase Handoff facts are immutable.",
          isBlocking: true,
        },
      ],
    );
  if (input.approvalScope === "QA" || input.approvalScope === "PRODUCTION")
    return rejected(state, "Recipe release is not QA or Production approval.");
  if (version.status !== "VALIDATED")
    return rejected(state, "Only a validated recipe version can be released.", [
      {
        objectId: version.recipeVersionId,
        severity: "BLOCKING",
        issueCode: "INVALID_VERSION_RELEASE",
        message: "Recipe version must be validated before release.",
        isBlocking: true,
      },
    ]);
  const blockers = recipeVersionIssues(state, version.recipeVersionId).filter(
    (issue) => issue.isBlocking,
  );
  if (blockers.length)
    return rejected(
      state,
      "Recipe version has blocking release issues.",
      blockers,
    );
  if (!input.reason.trim())
    return rejected(state, "A release reason is required.");
  const recipe = recipeById(state, version.recipeId)!;
  const reference: ReleasedRecipeReference = {
    releasedRecipeReferenceId: `${version.recipeVersionId}-release-${state.releasedRecipeReferences.length + 1}`,
    dishId: recipe.dishId,
    recipeId: recipe.recipeId,
    recipeVersionId: version.recipeVersionId,
    releasedAt: input.at,
    releasedBy: input.actorId,
    effect: "FUTURE_PLANNING_REFERENCE_ONLY",
  };
  const nextVersion: RecipeVersion = {
    ...version,
    status: "RELEASED_FOR_PLANNING",
    releasedBy: input.actorId,
    releasedAt: input.at,
  };
  const next = auditChange(
    {
      ...replaceVersion(state, nextVersion),
      releasedRecipeReferences: [...state.releasedRecipeReferences, reference],
    },
    {
      ...input,
      recipeId: version.recipeId,
      changeType: "RecipeVersionReleasedForPlanning",
      before: version.status,
      after: nextVersion.status,
    },
  );
  return accepted(next, reference);
}

export function RecordRecipeMasterDataChange(
  state: DishRecipeAdminState,
  input: {
    recipeId: string;
    recipeVersionId?: string;
    recipeLineId?: string;
  } & AuditInput,
) {
  if (!recipeById(state, input.recipeId))
    return rejected(state, "Recipe was not found.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  return accepted(
    auditChange(state, {
      ...input,
      changeType: "RecipeMasterDataChangeRecorded",
    }),
  );
}

export type DishRecipeAdminWorkbench = {
  activeDishCount: number;
  inactiveDishCount: number;
  dishesWithoutReleasedRecipeCount: number;
  blockingIssueCount: number;
  warningCount: number;
  selectedDish: Dish;
  selectedRecipe?: Recipe;
  selectedVersion?: RecipeVersion;
  versions: readonly (RecipeVersion & { lockStatus: "LOCKED" | "UNLOCKED" })[];
  lines: readonly (RecipeLine & {
    ingredientName: string;
    ingredientStatus?: "ACTIVE" | "INACTIVE";
  })[];
  variants: readonly SchoolTypeRecipeVariant[];
  changeSets: readonly RecipeChangeSet[];
  reviewEvidence: readonly RecipeReviewEvidence[];
  changeHistory: readonly RecipeMasterDataChange[];
  blockers: readonly DishRecipeIssue[];
  warnings: readonly DishRecipeIssue[];
  downstreamUsage: readonly DownstreamRecipeUsage[];
  canValidate: boolean;
  canRelease: boolean;
  canEditLines: boolean;
  boundaryNote: string;
};

export function DishRecipeAdminWorkbench(
  state: DishRecipeAdminState,
  selectedDishId: string,
  selectedRecipeVersionId?: string,
): DishRecipeAdminWorkbench {
  const selectedDish = dishById(state, selectedDishId);
  if (!selectedDish) throw new Error("Selected dish was not found.");
  const selectedRecipe = state.recipes.find(
    (recipe) => recipe.dishId === selectedDish.dishId,
  );
  const rawVersions = selectedRecipe
    ? state.recipeVersions.filter(
        (version) => version.recipeId === selectedRecipe.recipeId,
      )
    : [];
  const selectedVersion =
    rawVersions.find(
      (version) => version.recipeVersionId === selectedRecipeVersionId,
    ) ?? rawVersions.at(-1);
  const issues = [
    ...dishIssues(state, selectedDish),
    ...(selectedVersion
      ? recipeVersionIssues(state, selectedVersion.recipeVersionId)
      : selectedDish.requiresNeedGeneration
        ? [
            {
              objectId: selectedDish.dishId,
              severity: "BLOCKING" as const,
              issueCode: "RECIPE_MISSING" as const,
              message: "Dish requires a recipe before Need Generation.",
              isBlocking: true,
            },
          ]
        : []),
  ];
  const releasedDishIds = new Set(
    state.recipeVersions
      .filter(
        (version) =>
          version.status === "RELEASED_FOR_PLANNING" ||
          version.status === "LOCKED",
      )
      .map(
        (version) =>
          state.recipes.find((recipe) => recipe.recipeId === version.recipeId)
            ?.dishId,
      ),
  );
  const blockers = issues.filter((issue) => issue.isBlocking);
  const warnings = issues.filter((issue) => !issue.isBlocking);
  return {
    activeDishCount: state.dishes.filter((dish) => dish.status === "ACTIVE")
      .length,
    inactiveDishCount: state.dishes.filter((dish) => dish.status === "INACTIVE")
      .length,
    dishesWithoutReleasedRecipeCount: state.dishes.filter(
      (dish) => dish.status === "ACTIVE" && !releasedDishIds.has(dish.dishId),
    ).length,
    blockingIssueCount: blockers.length,
    warningCount: warnings.length,
    selectedDish,
    selectedRecipe,
    selectedVersion,
    versions: rawVersions.map((version) => ({
      ...version,
      lockStatus:
        currentLock(state, version.recipeVersionId)?.status ?? "UNLOCKED",
    })),
    lines: selectedVersion
      ? state.recipeLines
          .filter(
            (line) => line.recipeVersionId === selectedVersion.recipeVersionId,
          )
          .map((line) => {
            const ingredient = ingredientById(state, line.ingredientId);
            return {
              ...line,
              ingredientName:
                ingredient?.ingredientName ?? "Missing ingredient",
              ingredientStatus: ingredient?.status,
            };
          })
      : [],
    variants: selectedVersion
      ? state.schoolTypeVariants.filter(
          (variant) =>
            variant.recipeVersionId === selectedVersion.recipeVersionId,
        )
      : [],
    changeSets: selectedRecipe
      ? state.recipeChangeSets.filter(
          (changeSet) => changeSet.recipeId === selectedRecipe.recipeId,
        )
      : [],
    reviewEvidence: selectedVersion
      ? state.recipeReviewEvidence.filter(
          (evidence) =>
            evidence.recipeVersionId === selectedVersion.recipeVersionId,
        )
      : [],
    changeHistory: selectedRecipe
      ? state.recipeMasterDataChanges
          .filter((change) => change.recipeId === selectedRecipe.recipeId)
          .sort((left, right) => right.at.localeCompare(left.at))
      : [],
    blockers,
    warnings,
    downstreamUsage: selectedRecipe
      ? state.downstreamRecipeUsage.filter((usage) =>
          rawVersions.some(
            (version) => version.recipeVersionId === usage.recipeVersionId,
          ),
        )
      : [],
    canValidate: selectedVersion?.status === "DRAFT" && blockers.length === 0,
    canRelease:
      selectedVersion?.status === "VALIDATED" && blockers.length === 0,
    canEditLines: Boolean(
      selectedVersion &&
      selectedVersion.status === "DRAFT" &&
      !isImmutable(state, selectedVersion),
    ),
    boundaryNote:
      "Admin owns dish and recipe master-data facts. Release creates a versioned reference for future Planning only; it never rewrites prior Planning, Need Generation, Confirmed Need, or Purchase Handoff facts, and recipe approval is not QA or Production approval.",
  };
}
