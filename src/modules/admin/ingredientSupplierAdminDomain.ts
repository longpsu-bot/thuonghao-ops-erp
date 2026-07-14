export type MasterDataStatus = "ACTIVE" | "INACTIVE";
export type EligibilityStatus = "ELIGIBLE" | "INELIGIBLE";
export type SupplierPreference = "DEFAULT" | "PREFERRED";
export type AdminIssueSeverity = "BLOCKING" | "WARNING";

export type IngredientUnitProfile = {
  purchaseUnit: string;
  planningUnit: string;
  inventoryUnit: string;
  usableUnit?: string;
};

export type UnitConversionRule = {
  unitConversionRuleId: string;
  ingredientId?: string;
  supplierId?: string;
  fromUnit: string;
  toUnit: string;
  factor: number;
  status: MasterDataStatus;
  actorId: string;
  at: string;
  reason: string;
};

export type IngredientStatusChange = {
  ingredientStatusChangeId: string;
  ingredientId: string;
  beforeStatus: MasterDataStatus;
  afterStatus: MasterDataStatus;
  actorId: string;
  at: string;
  reason: string;
};

export type SupplierStatusChange = {
  supplierStatusChangeId: string;
  supplierId: string;
  beforeStatus: MasterDataStatus;
  afterStatus: MasterDataStatus;
  actorId: string;
  at: string;
  reason: string;
};

export type IngredientMasterDataChange = {
  ingredientMasterDataChangeId: string;
  ingredientId: string;
  changeType:
    | "IngredientCreated"
    | "IngredientProfileUpdated"
    | "IngredientActivated"
    | "IngredientDeactivated"
    | "IngredientUnitProfileChanged"
    | "IngredientMasterDataChangeRecorded";
  actorId: string;
  at: string;
  reason: string;
  before?: string;
  after?: string;
};

export type SupplierMasterDataChange = {
  supplierMasterDataChangeId: string;
  supplierId: string;
  changeType:
    | "SupplierCreated"
    | "SupplierProfileUpdated"
    | "SupplierActivated"
    | "SupplierDeactivated"
    | "SupplierMasterDataChangeRecorded";
  actorId: string;
  at: string;
  reason: string;
  before?: string;
  after?: string;
};

export type IngredientSupplierChange = {
  ingredientSupplierChangeId: string;
  ingredientId: string;
  supplierId: string;
  changeType:
    | "IngredientSupplierEligibilityChanged"
    | "DefaultSupplierPolicyChanged"
    | "IngredientSupplierChangeRecorded";
  actorId: string;
  at: string;
  reason: string;
  before?: string;
  after?: string;
};

export type Ingredient = {
  ingredientId: string;
  ingredientName: string;
  status: MasterDataStatus;
  ingredientGroup?: string;
  operationalNotes?: string;
  unitProfile: IngredientUnitProfile;
  statusChanges: readonly IngredientStatusChange[];
  masterDataChanges: readonly IngredientMasterDataChange[];
};

export type Supplier = {
  supplierId: string;
  supplierName: string;
  status: MasterDataStatus;
  contactReference?: string;
  operationalNotes?: string;
  statusChanges: readonly SupplierStatusChange[];
  masterDataChanges: readonly SupplierMasterDataChange[];
};

export type IngredientSupplierEligibility = {
  ingredientSupplierEligibilityId: string;
  ingredientId: string;
  supplierId: string;
  status: EligibilityStatus;
};

export type DefaultSupplierPolicy = {
  defaultSupplierPolicyId: string;
  ingredientId: string;
  supplierId: string;
  preference: SupplierPreference;
  status: MasterDataStatus;
  effect: "ADMIN_REFERENCE_ONLY";
};

export type IngredientSupplierAdminState = {
  ingredients: readonly Ingredient[];
  suppliers: readonly Supplier[];
  unitConversionRules: readonly UnitConversionRule[];
  eligibilities: readonly IngredientSupplierEligibility[];
  defaultSupplierPolicies: readonly DefaultSupplierPolicy[];
  ingredientSupplierChanges: readonly IngredientSupplierChange[];
};

export type IngredientSupplierAdminIssue = {
  objectId: string;
  severity: AdminIssueSeverity;
  issueCode:
    | "INGREDIENT_NAME_MISSING"
    | "DUPLICATE_ACTIVE_INGREDIENT"
    | "PURCHASE_UNIT_MISSING"
    | "UNIT_CONVERSION_MISSING"
    | "INGREDIENT_INACTIVE"
    | "SUPPLIER_NAME_MISSING"
    | "DUPLICATE_ACTIVE_SUPPLIER"
    | "SUPPLIER_INACTIVE"
    | "ELIGIBLE_SUPPLIER_MISSING"
    | "DEFAULT_SUPPLIER_MISSING";
  message: string;
  isBlocking: boolean;
};

export type IngredientSupplierCommandResult = {
  state: IngredientSupplierAdminState;
  accepted: boolean;
  message?: string;
  blockers: readonly IngredientSupplierAdminIssue[];
};

type AuditInput = { actorId: string; at: string; reason: string };

const normalized = (value: string) => value.trim().toLocaleLowerCase();
const rejected = (
  state: IngredientSupplierAdminState,
  message: string,
  blockers: readonly IngredientSupplierAdminIssue[] = [],
): IngredientSupplierCommandResult => ({
  state,
  accepted: false,
  message,
  blockers,
});
const accepted = (
  state: IngredientSupplierAdminState,
): IngredientSupplierCommandResult => ({ state, accepted: true, blockers: [] });
const ingredientById = (state: IngredientSupplierAdminState, id: string) =>
  state.ingredients.find((item) => item.ingredientId === id);
const supplierById = (state: IngredientSupplierAdminState, id: string) =>
  state.suppliers.find((item) => item.supplierId === id);

function ingredientChange(
  ingredient: Ingredient,
  changeType: IngredientMasterDataChange["changeType"],
  input: AuditInput,
  before?: string,
  after?: string,
): IngredientMasterDataChange {
  return {
    ingredientMasterDataChangeId: `${ingredient.ingredientId}-change-${ingredient.masterDataChanges.length + 1}`,
    ingredientId: ingredient.ingredientId,
    changeType,
    ...input,
    before,
    after,
  };
}

function supplierChange(
  supplier: Supplier,
  changeType: SupplierMasterDataChange["changeType"],
  input: AuditInput,
  before?: string,
  after?: string,
): SupplierMasterDataChange {
  return {
    supplierMasterDataChangeId: `${supplier.supplierId}-change-${supplier.masterDataChanges.length + 1}`,
    supplierId: supplier.supplierId,
    changeType,
    ...input,
    before,
    after,
  };
}

function relationshipChange(
  state: IngredientSupplierAdminState,
  ingredientId: string,
  supplierId: string,
  changeType: IngredientSupplierChange["changeType"],
  input: AuditInput,
  before?: string,
  after?: string,
): IngredientSupplierChange {
  return {
    ingredientSupplierChangeId: `ingredient-supplier-change-${state.ingredientSupplierChanges.length + 1}`,
    ingredientId,
    supplierId,
    changeType,
    ...input,
    before,
    after,
  };
}

function replaceIngredient(
  state: IngredientSupplierAdminState,
  next: Ingredient,
): IngredientSupplierAdminState {
  return {
    ...state,
    ingredients: state.ingredients.map((item) =>
      item.ingredientId === next.ingredientId ? next : item,
    ),
  };
}

function replaceSupplier(
  state: IngredientSupplierAdminState,
  next: Supplier,
): IngredientSupplierAdminState {
  return {
    ...state,
    suppliers: state.suppliers.map((item) =>
      item.supplierId === next.supplierId ? next : item,
    ),
  };
}

function activeConversionExists(
  state: IngredientSupplierAdminState,
  ingredientId: string,
  fromUnit: string,
  toUnit: string,
) {
  if (fromUnit === toUnit) return true;
  const edges = state.unitConversionRules
    .filter(
      (rule) =>
        rule.status === "ACTIVE" &&
        (!rule.ingredientId || rule.ingredientId === ingredientId),
    )
    .flatMap(
      (rule) =>
        [
          [rule.fromUnit, rule.toUnit],
          [rule.toUnit, rule.fromUnit],
        ] as const,
    );
  const seen = new Set([fromUnit]);
  const queue = [fromUnit];
  while (queue.length) {
    const current = queue.shift()!;
    for (const [from, to] of edges) {
      if (from !== current || seen.has(to)) continue;
      if (to === toUnit) return true;
      seen.add(to);
      queue.push(to);
    }
  }
  return false;
}

export function ingredientIssues(
  state: IngredientSupplierAdminState,
  ingredient: Ingredient,
): IngredientSupplierAdminIssue[] {
  const issues: IngredientSupplierAdminIssue[] = [];
  if (!ingredient.ingredientName.trim())
    issues.push({
      objectId: ingredient.ingredientId,
      severity: "BLOCKING",
      issueCode: "INGREDIENT_NAME_MISSING",
      message: "Ingredient name is required.",
      isBlocking: true,
    });
  if (!ingredient.unitProfile.purchaseUnit.trim())
    issues.push({
      objectId: ingredient.ingredientId,
      severity: "BLOCKING",
      issueCode: "PURCHASE_UNIT_MISSING",
      message: "Purchase unit is required for operational use.",
      isBlocking: true,
    });
  const comparedUnits = [
    ingredient.unitProfile.planningUnit,
    ingredient.unitProfile.inventoryUnit,
    ingredient.unitProfile.usableUnit,
  ].filter((unit): unit is string => Boolean(unit?.trim()));
  if (
    ingredient.unitProfile.purchaseUnit.trim() &&
    comparedUnits.some(
      (unit) =>
        !activeConversionExists(
          state,
          ingredient.ingredientId,
          ingredient.unitProfile.purchaseUnit,
          unit,
        ),
    )
  )
    issues.push({
      objectId: ingredient.ingredientId,
      severity: "BLOCKING",
      issueCode: "UNIT_CONVERSION_MISSING",
      message:
        "An approved unit conversion is required between operational units.",
      isBlocking: true,
    });
  if (ingredient.status === "INACTIVE")
    issues.push({
      objectId: ingredient.ingredientId,
      severity: "WARNING",
      issueCode: "INGREDIENT_INACTIVE",
      message: "Inactive ingredient is retained for historical reference only.",
      isBlocking: false,
    });
  const eligible = state.eligibilities.filter(
    (item) =>
      item.ingredientId === ingredient.ingredientId &&
      item.status === "ELIGIBLE" &&
      supplierById(state, item.supplierId)?.status === "ACTIVE",
  );
  if (ingredient.status === "ACTIVE" && eligible.length === 0)
    issues.push({
      objectId: ingredient.ingredientId,
      severity: "BLOCKING",
      issueCode: "ELIGIBLE_SUPPLIER_MISSING",
      message: "No active eligible supplier is recorded for this ingredient.",
      isBlocking: true,
    });
  if (
    ingredient.status === "ACTIVE" &&
    !state.defaultSupplierPolicies.some(
      (policy) =>
        policy.ingredientId === ingredient.ingredientId &&
        policy.status === "ACTIVE",
    )
  )
    issues.push({
      objectId: ingredient.ingredientId,
      severity: "WARNING",
      issueCode: "DEFAULT_SUPPLIER_MISSING",
      message: "No default or preferred supplier reference is recorded.",
      isBlocking: false,
    });
  return issues;
}

export function supplierIssues(
  state: IngredientSupplierAdminState,
  supplier: Supplier,
): IngredientSupplierAdminIssue[] {
  const issues: IngredientSupplierAdminIssue[] = [];
  if (!supplier.supplierName.trim())
    issues.push({
      objectId: supplier.supplierId,
      severity: "BLOCKING",
      issueCode: "SUPPLIER_NAME_MISSING",
      message: "Supplier name is required.",
      isBlocking: true,
    });
  if (supplier.status === "INACTIVE")
    issues.push({
      objectId: supplier.supplierId,
      severity: "WARNING",
      issueCode: "SUPPLIER_INACTIVE",
      message:
        "Inactive supplier is unavailable for new Procurement assignment.",
      isBlocking: false,
    });
  return issues;
}

export function CreateIngredient(
  state: IngredientSupplierAdminState,
  input: Omit<Ingredient, "statusChanges" | "masterDataChanges"> & AuditInput,
): IngredientSupplierCommandResult {
  const candidate: Ingredient = {
    ...input,
    statusChanges: [],
    masterDataChanges: [],
  };
  if (!input.ingredientName.trim())
    return rejected(
      state,
      "Ingredient name is required.",
      ingredientIssues(state, candidate),
    );
  if (
    input.status === "ACTIVE" &&
    state.ingredients.some(
      (item) =>
        item.status === "ACTIVE" &&
        normalized(item.ingredientName) === normalized(input.ingredientName),
    )
  )
    return rejected(
      state,
      "Duplicate active ingredient identity is not allowed.",
      [
        {
          objectId: input.ingredientId,
          severity: "BLOCKING",
          issueCode: "DUPLICATE_ACTIVE_INGREDIENT",
          message: "An active ingredient with this name already exists.",
          isBlocking: true,
        },
      ],
    );
  if (!input.reason.trim())
    return rejected(state, "A creation reason is required.");
  const created = { ...candidate, ingredientName: input.ingredientName.trim() };
  return accepted({
    ...state,
    ingredients: [
      ...state.ingredients,
      {
        ...created,
        masterDataChanges: [
          ingredientChange(created, "IngredientCreated", input),
        ],
      },
    ],
  });
}

export function UpdateIngredientProfile(
  state: IngredientSupplierAdminState,
  input: {
    ingredientId: string;
    ingredientName: string;
    ingredientGroup?: string;
    operationalNotes?: string;
  } & AuditInput,
) {
  const current = ingredientById(state, input.ingredientId);
  if (!current) return rejected(state, "Ingredient was not found.");
  if (!input.ingredientName.trim())
    return rejected(state, "Ingredient name is required.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  if (
    current.status === "ACTIVE" &&
    state.ingredients.some(
      (item) =>
        item.ingredientId !== current.ingredientId &&
        item.status === "ACTIVE" &&
        normalized(item.ingredientName) === normalized(input.ingredientName),
    )
  )
    return rejected(
      state,
      "Duplicate active ingredient identity is not allowed.",
    );
  const updated = {
    ...current,
    ingredientName: input.ingredientName.trim(),
    ingredientGroup: input.ingredientGroup,
    operationalNotes: input.operationalNotes,
  };
  return accepted(
    replaceIngredient(state, {
      ...updated,
      masterDataChanges: [
        ...current.masterDataChanges,
        ingredientChange(
          current,
          "IngredientProfileUpdated",
          input,
          current.ingredientName,
          updated.ingredientName,
        ),
      ],
    }),
  );
}

export function SetIngredientUnitProfile(
  state: IngredientSupplierAdminState,
  input: {
    ingredientId: string;
    unitProfile: IngredientUnitProfile;
  } & AuditInput,
) {
  const current = ingredientById(state, input.ingredientId);
  if (!current) return rejected(state, "Ingredient was not found.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  return accepted(
    replaceIngredient(state, {
      ...current,
      unitProfile: input.unitProfile,
      masterDataChanges: [
        ...current.masterDataChanges,
        ingredientChange(
          current,
          "IngredientUnitProfileChanged",
          input,
          JSON.stringify(current.unitProfile),
          JSON.stringify(input.unitProfile),
        ),
      ],
    }),
  );
}

export function SetIngredientStatus(
  state: IngredientSupplierAdminState,
  input: { ingredientId: string; status: MasterDataStatus } & AuditInput,
) {
  const current = ingredientById(state, input.ingredientId);
  if (!current) return rejected(state, "Ingredient was not found.");
  if (current.status === input.status)
    return rejected(state, "Ingredient status is already set.");
  if (!input.reason.trim())
    return rejected(state, "A status-change reason is required.");
  if (
    input.status === "ACTIVE" &&
    state.ingredients.some(
      (item) =>
        item.ingredientId !== current.ingredientId &&
        item.status === "ACTIVE" &&
        normalized(item.ingredientName) === normalized(current.ingredientName),
    )
  )
    return rejected(
      state,
      "Duplicate active ingredient identity is not allowed.",
    );
  const statusChange: IngredientStatusChange = {
    ingredientStatusChangeId: `${current.ingredientId}-status-${current.statusChanges.length + 1}`,
    ingredientId: current.ingredientId,
    beforeStatus: current.status,
    afterStatus: input.status,
    actorId: input.actorId,
    at: input.at,
    reason: input.reason,
  };
  const changeType =
    input.status === "ACTIVE" ? "IngredientActivated" : "IngredientDeactivated";
  return accepted(
    replaceIngredient(state, {
      ...current,
      status: input.status,
      statusChanges: [...current.statusChanges, statusChange],
      masterDataChanges: [
        ...current.masterDataChanges,
        ingredientChange(
          current,
          changeType,
          input,
          current.status,
          input.status,
        ),
      ],
    }),
  );
}

export function CreateUnitConversionRule(
  state: IngredientSupplierAdminState,
  input: UnitConversionRule,
) {
  if (!input.reason.trim())
    return rejected(state, "A conversion reason is required.");
  if (!input.fromUnit.trim() || !input.toUnit.trim() || input.factor <= 0)
    return rejected(
      state,
      "Conversion units and a positive factor are required.",
    );
  if (input.ingredientId && !ingredientById(state, input.ingredientId))
    return rejected(state, "Ingredient was not found.");
  if (input.supplierId && !supplierById(state, input.supplierId))
    return rejected(state, "Supplier was not found.");
  return accepted({
    ...state,
    unitConversionRules: [...state.unitConversionRules, input],
  });
}

export function CreateSupplier(
  state: IngredientSupplierAdminState,
  input: Omit<Supplier, "statusChanges" | "masterDataChanges"> & AuditInput,
) {
  const candidate: Supplier = {
    ...input,
    statusChanges: [],
    masterDataChanges: [],
  };
  if (!input.supplierName.trim())
    return rejected(
      state,
      "Supplier name is required.",
      supplierIssues(state, candidate),
    );
  if (
    input.status === "ACTIVE" &&
    state.suppliers.some(
      (item) =>
        item.status === "ACTIVE" &&
        normalized(item.supplierName) === normalized(input.supplierName),
    )
  )
    return rejected(
      state,
      "Duplicate active supplier identity is not allowed.",
      [
        {
          objectId: input.supplierId,
          severity: "BLOCKING",
          issueCode: "DUPLICATE_ACTIVE_SUPPLIER",
          message: "An active supplier with this name already exists.",
          isBlocking: true,
        },
      ],
    );
  if (!input.reason.trim())
    return rejected(state, "A creation reason is required.");
  const created = { ...candidate, supplierName: input.supplierName.trim() };
  return accepted({
    ...state,
    suppliers: [
      ...state.suppliers,
      {
        ...created,
        masterDataChanges: [supplierChange(created, "SupplierCreated", input)],
      },
    ],
  });
}

export function UpdateSupplierProfile(
  state: IngredientSupplierAdminState,
  input: {
    supplierId: string;
    supplierName: string;
    contactReference?: string;
    operationalNotes?: string;
  } & AuditInput,
) {
  const current = supplierById(state, input.supplierId);
  if (!current) return rejected(state, "Supplier was not found.");
  if (!input.supplierName.trim())
    return rejected(state, "Supplier name is required.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  if (
    current.status === "ACTIVE" &&
    state.suppliers.some(
      (item) =>
        item.supplierId !== current.supplierId &&
        item.status === "ACTIVE" &&
        normalized(item.supplierName) === normalized(input.supplierName),
    )
  )
    return rejected(
      state,
      "Duplicate active supplier identity is not allowed.",
    );
  const updated = {
    ...current,
    supplierName: input.supplierName.trim(),
    contactReference: input.contactReference,
    operationalNotes: input.operationalNotes,
  };
  return accepted(
    replaceSupplier(state, {
      ...updated,
      masterDataChanges: [
        ...current.masterDataChanges,
        supplierChange(
          current,
          "SupplierProfileUpdated",
          input,
          current.supplierName,
          updated.supplierName,
        ),
      ],
    }),
  );
}

export function SetSupplierStatus(
  state: IngredientSupplierAdminState,
  input: { supplierId: string; status: MasterDataStatus } & AuditInput,
) {
  const current = supplierById(state, input.supplierId);
  if (!current) return rejected(state, "Supplier was not found.");
  if (current.status === input.status)
    return rejected(state, "Supplier status is already set.");
  if (!input.reason.trim())
    return rejected(state, "A status-change reason is required.");
  if (
    input.status === "ACTIVE" &&
    state.suppliers.some(
      (item) =>
        item.supplierId !== current.supplierId &&
        item.status === "ACTIVE" &&
        normalized(item.supplierName) === normalized(current.supplierName),
    )
  )
    return rejected(
      state,
      "Duplicate active supplier identity is not allowed.",
    );
  const statusChange: SupplierStatusChange = {
    supplierStatusChangeId: `${current.supplierId}-status-${current.statusChanges.length + 1}`,
    supplierId: current.supplierId,
    beforeStatus: current.status,
    afterStatus: input.status,
    actorId: input.actorId,
    at: input.at,
    reason: input.reason,
  };
  const changeType =
    input.status === "ACTIVE" ? "SupplierActivated" : "SupplierDeactivated";
  return accepted(
    replaceSupplier(state, {
      ...current,
      status: input.status,
      statusChanges: [...current.statusChanges, statusChange],
      masterDataChanges: [
        ...current.masterDataChanges,
        supplierChange(
          current,
          changeType,
          input,
          current.status,
          input.status,
        ),
      ],
    }),
  );
}

export function SetIngredientSupplierEligibility(
  state: IngredientSupplierAdminState,
  input: {
    ingredientId: string;
    supplierId: string;
    status: EligibilityStatus;
  } & AuditInput,
) {
  if (!ingredientById(state, input.ingredientId))
    return rejected(state, "Ingredient was not found.");
  if (!supplierById(state, input.supplierId))
    return rejected(state, "Supplier was not found.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  const current = state.eligibilities.find(
    (item) =>
      item.ingredientId === input.ingredientId &&
      item.supplierId === input.supplierId,
  );
  const next: IngredientSupplierEligibility = {
    ingredientSupplierEligibilityId:
      current?.ingredientSupplierEligibilityId ??
      `${input.ingredientId}-${input.supplierId}-eligibility`,
    ingredientId: input.ingredientId,
    supplierId: input.supplierId,
    status: input.status,
  };
  return accepted({
    ...state,
    eligibilities: current
      ? state.eligibilities.map((item) =>
          item.ingredientSupplierEligibilityId ===
          current.ingredientSupplierEligibilityId
            ? next
            : item,
        )
      : [...state.eligibilities, next],
    ingredientSupplierChanges: [
      ...state.ingredientSupplierChanges,
      relationshipChange(
        state,
        input.ingredientId,
        input.supplierId,
        "IngredientSupplierEligibilityChanged",
        input,
        current?.status,
        input.status,
      ),
    ],
  });
}

export function SetDefaultSupplierPolicy(
  state: IngredientSupplierAdminState,
  input: {
    defaultSupplierPolicyId: string;
    ingredientId: string;
    supplierId: string;
    preference: SupplierPreference;
    status: MasterDataStatus;
  } & AuditInput,
) {
  const supplier = supplierById(state, input.supplierId);
  if (!ingredientById(state, input.ingredientId))
    return rejected(state, "Ingredient was not found.");
  if (!supplier) return rejected(state, "Supplier was not found.");
  if (supplier.status !== "ACTIVE")
    return rejected(state, "Default supplier must be active.");
  if (
    !state.eligibilities.some(
      (item) =>
        item.ingredientId === input.ingredientId &&
        item.supplierId === input.supplierId &&
        item.status === "ELIGIBLE",
    )
  )
    return rejected(
      state,
      "Default supplier must be eligible for the ingredient.",
    );
  if (!input.reason.trim())
    return rejected(state, "A policy-change reason is required.");
  const current = state.defaultSupplierPolicies.find(
    (policy) => policy.ingredientId === input.ingredientId,
  );
  const next: DefaultSupplierPolicy = {
    defaultSupplierPolicyId: input.defaultSupplierPolicyId,
    ingredientId: input.ingredientId,
    supplierId: input.supplierId,
    preference: input.preference,
    status: input.status,
    effect: "ADMIN_REFERENCE_ONLY",
  };
  return accepted({
    ...state,
    defaultSupplierPolicies: current
      ? state.defaultSupplierPolicies.map((policy) =>
          policy.defaultSupplierPolicyId === current.defaultSupplierPolicyId
            ? next
            : policy,
        )
      : [...state.defaultSupplierPolicies, next],
    ingredientSupplierChanges: [
      ...state.ingredientSupplierChanges,
      relationshipChange(
        state,
        input.ingredientId,
        input.supplierId,
        "DefaultSupplierPolicyChanged",
        input,
        current ? `${current.preference}:${current.supplierId}` : undefined,
        `${next.preference}:${next.supplierId}`,
      ),
    ],
  });
}

export function RecordIngredientSupplierChange(
  state: IngredientSupplierAdminState,
  input: { ingredientId: string; supplierId: string } & AuditInput,
) {
  if (!ingredientById(state, input.ingredientId))
    return rejected(state, "Ingredient was not found.");
  if (!supplierById(state, input.supplierId))
    return rejected(state, "Supplier was not found.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  return accepted({
    ...state,
    ingredientSupplierChanges: [
      ...state.ingredientSupplierChanges,
      relationshipChange(
        state,
        input.ingredientId,
        input.supplierId,
        "IngredientSupplierChangeRecorded",
        input,
      ),
    ],
  });
}

export function RecordIngredientMasterDataChange(
  state: IngredientSupplierAdminState,
  input: { ingredientId: string } & AuditInput,
) {
  const current = ingredientById(state, input.ingredientId);
  if (!current) return rejected(state, "Ingredient was not found.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  return accepted(
    replaceIngredient(state, {
      ...current,
      masterDataChanges: [
        ...current.masterDataChanges,
        ingredientChange(current, "IngredientMasterDataChangeRecorded", input),
      ],
    }),
  );
}

export function RecordSupplierMasterDataChange(
  state: IngredientSupplierAdminState,
  input: { supplierId: string } & AuditInput,
) {
  const current = supplierById(state, input.supplierId);
  if (!current) return rejected(state, "Supplier was not found.");
  if (!input.reason.trim())
    return rejected(state, "A change reason is required.");
  return accepted(
    replaceSupplier(state, {
      ...current,
      masterDataChanges: [
        ...current.masterDataChanges,
        supplierChange(current, "SupplierMasterDataChangeRecorded", input),
      ],
    }),
  );
}

export function IngredientOperationalReference(
  ingredient: Ingredient | undefined,
  use: "RECIPE_BOM" | "PLANNING" | "PROCUREMENT" | "WAREHOUSE",
  explicitOverrideEvidence?: string,
) {
  if (!ingredient)
    return { accepted: false, message: "Ingredient reference is missing." };
  if (ingredient.status === "INACTIVE" && !explicitOverrideEvidence?.trim())
    return {
      accepted: false,
      message: `Inactive ingredient requires explicit override evidence for new ${use} reference.`,
    };
  return { accepted: true };
}

export function SupplierProcurementAssignmentReference(
  supplier: Supplier | undefined,
  explicitOverrideEvidence?: string,
) {
  if (!supplier)
    return { accepted: false, message: "Supplier reference is missing." };
  if (supplier.status === "INACTIVE" && !explicitOverrideEvidence?.trim())
    return {
      accepted: false,
      message:
        "Inactive supplier requires explicit override evidence for new Procurement assignment.",
    };
  return { accepted: true };
}

export function IngredientSupplierEligibilityReference(
  state: IngredientSupplierAdminState,
  ingredientId: string,
  supplierId: string,
) {
  const eligible = state.eligibilities.some(
    (item) =>
      item.ingredientId === ingredientId &&
      item.supplierId === supplierId &&
      item.status === "ELIGIBLE",
  );
  return eligible
    ? { accepted: true }
    : {
        accepted: false,
        message:
          "Supplier is not eligible for this ingredient in Admin master data.",
      };
}

export function DefaultSupplierPolicyReference(policy: DefaultSupplierPolicy) {
  return {
    policy,
    createsPurchaseOrder: false as const,
    createsSupplierCommitment: false as const,
    effect: "ADMIN_REFERENCE_ONLY" as const,
  };
}

export type IngredientSupplierAdminWorkbench = {
  activeIngredientCount: number;
  inactiveIngredientCount: number;
  activeSupplierCount: number;
  inactiveSupplierCount: number;
  blockingIssueCount: number;
  warningCount: number;
  ingredients: readonly (Ingredient & {
    issues: readonly IngredientSupplierAdminIssue[];
    eligibleSuppliers: readonly Supplier[];
    defaultSupplier?: Supplier;
    preference?: SupplierPreference;
  })[];
  suppliers: readonly (Supplier & {
    issues: readonly IngredientSupplierAdminIssue[];
    eligibleIngredients: readonly Ingredient[];
  })[];
  changeHistory: readonly (
    | IngredientMasterDataChange
    | SupplierMasterDataChange
    | IngredientSupplierChange
  )[];
  boundaryNote: string;
};

export function IngredientSupplierAdminWorkbench(
  state: IngredientSupplierAdminState,
): IngredientSupplierAdminWorkbench {
  const ingredients = state.ingredients.map((ingredient) => {
    const eligibleSupplierIds = state.eligibilities
      .filter(
        (item) =>
          item.ingredientId === ingredient.ingredientId &&
          item.status === "ELIGIBLE",
      )
      .map((item) => item.supplierId);
    const policy = state.defaultSupplierPolicies.find(
      (item) =>
        item.ingredientId === ingredient.ingredientId &&
        item.status === "ACTIVE",
    );
    return {
      ...ingredient,
      issues: ingredientIssues(state, ingredient),
      eligibleSuppliers: state.suppliers.filter((supplier) =>
        eligibleSupplierIds.includes(supplier.supplierId),
      ),
      defaultSupplier: policy
        ? supplierById(state, policy.supplierId)
        : undefined,
      preference: policy?.preference,
    };
  });
  const suppliers = state.suppliers.map((supplier) => {
    const eligibleIngredientIds = state.eligibilities
      .filter(
        (item) =>
          item.supplierId === supplier.supplierId && item.status === "ELIGIBLE",
      )
      .map((item) => item.ingredientId);
    return {
      ...supplier,
      issues: supplierIssues(state, supplier),
      eligibleIngredients: state.ingredients.filter((ingredient) =>
        eligibleIngredientIds.includes(ingredient.ingredientId),
      ),
    };
  });
  const issues = [
    ...ingredients.flatMap((item) => item.issues),
    ...suppliers.flatMap((item) => item.issues),
  ];
  return {
    activeIngredientCount: state.ingredients.filter(
      (item) => item.status === "ACTIVE",
    ).length,
    inactiveIngredientCount: state.ingredients.filter(
      (item) => item.status === "INACTIVE",
    ).length,
    activeSupplierCount: state.suppliers.filter(
      (item) => item.status === "ACTIVE",
    ).length,
    inactiveSupplierCount: state.suppliers.filter(
      (item) => item.status === "INACTIVE",
    ).length,
    blockingIssueCount: issues.filter((item) => item.isBlocking).length,
    warningCount: issues.filter((item) => !item.isBlocking).length,
    ingredients,
    suppliers,
    changeHistory: [
      ...state.ingredients.flatMap((item) => item.masterDataChanges),
      ...state.suppliers.flatMap((item) => item.masterDataChanges),
      ...state.ingredientSupplierChanges,
    ].sort((left, right) => right.at.localeCompare(left.at)),
    boundaryNote:
      "Admin governs ingredient, unit, supplier, eligibility, and preference reference data only. It does not create supplier commitments or rewrite Planning, Procurement, Warehouse, Dispatch, Production/QA, or Finance facts.",
  };
}
