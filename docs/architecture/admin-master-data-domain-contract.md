# PD-04 — Admin / Master Data Management Domain Contract

**Status:** Drafted in this PR; pending review and merge

**Domain:** Admin / Master Data Management

**Capability:** Controlled setup and governance of the master data required for the Atlas MVP

**Upstream evidence:** OPS v1 Supabase + Retool exports may be used as qualitative business evidence only

**Downstream consumers:** Planning, Procurement, Warehouse, Dispatch/Delivery, and future Production/QA and Finance/Accounting domains

**Architecture baseline:** ARCH-001 — OPS ERP Business Architecture; ARCH-002 — Atlas System Map

## Product decision

The first Atlas MVP should defer Production/QA and Accounting/Finance domain work and focus next on Admin / Master Data Management.

MVP priority:

```text
1. School info management
2. Ingredients & Suppliers management
3. Dishes & Recipes management
```

Rationale:

```text
Clean master data
→ reliable Planning
→ reliable Procurement
→ reliable Warehouse receiving/release
→ safer launch replacement for OPS v1 daily operations
```

## Purpose

Admin / Master Data Management defines, validates, governs, and changes the stable business reference data that operational domains depend on.

Admin answers:

```text
Which schools are active?
Which ingredients can be planned, purchased, received, and released?
Which suppliers are eligible for which ingredients?
Which dishes are available for menus?
Which recipe/BOM version should Planning use?
Which master-data facts are active, inactive, locked, or superseded?
```

Admin does not execute daily operations. It provides approved, traceable master data to the domains that execute daily operations.

## Core rule

```text
Admin owns master-data facts and governance.
Operational domains consume approved master-data references or snapshots.
Operational domains must not silently rewrite Admin-owned facts.
```

## OPS v1 and Retool interpretation

OPS v1 Retool apps are evidence of current business work, not target architecture.

Retool page separation must not be copied as a domain boundary.

Core rule:

```text
Retool page separation is implementation evidence, not domain authority.
```

## Recipe UI consolidation rule

OPS v1 separated recipe-related changes across multiple pages/layers because of Retool UI limitations.

Atlas should consolidate Dishes & Recipes into one coherent operator workbench. The user should be able to manage dish identity, recipe version, recipe lock state, BOM lines, school-type variants, active/inactive state, and change/review evidence in one page/workbench.

Atlas should not create one page for each v1 Retool recipe-change layer unless a future product decision proves a real business need.

## Ownership and boundaries

Admin owns:

- school/customer master data;
- school status, service profile, school type, and delivery location references;
- ingredient master data;
- ingredient unit profile and unit conversion references;
- supplier master data;
- ingredient-supplier eligibility and default/preferred supplier policy references;
- dish master data;
- recipe version, lock state, BOM lines, and school-type variants;
- active/inactive status changes;
- master-data change history and operator review evidence;
- downstream-safe references and snapshots.

Admin does not own:

- daily menu approval as a Planning fact;
- attendance collection or daily demand approval;
- Need Generation or Confirmed Need calculations;
- supplier allocation, purchase commitments, PO release, or supplier confirmation;
- warehouse receiving, goods receipt, stock identity, stock release, or stock movement;
- route planning, driver assignment, delivery confirmation, or delivery exceptions;
- production execution, kitchen portioning, food-safety inspection, or QA approval;
- invoice, payable, settlement, costing policy, or accounting entries;
- Supabase migrations, backend persistence, credentials, production data, or Retool changes in the prototype stage.

## Domain sections

Admin is one domain with three MVP sections. The UI may show them as Admin tabs or pages, but they remain part of the same supporting master-data domain.

```text
Admin / Master Data Management
├── School info management
├── Ingredients & Suppliers management
└── Dishes & Recipes management
```

## School info management

### Mission

Maintain the customer/school master data required for Planning, service calendars, delivery references, and operational visibility.

### Business objects

#### School

A customer or school location that can receive meal service or otherwise participate in operational planning.

Typical attributes:

- schoolId;
- schoolName;
- customer/group reference;
- schoolTypeId;
- active/inactive status;
- display order;
- default delivery location;
- operational notes;
- effective date range where applicable.

#### SchoolGroup / CustomerGroup

A grouping object for schools or customers used for filtering, reporting, planning context, or contract grouping.

#### SchoolType

A classification used by recipes, menus, and planning logic when portions or BOM variants differ by school type.

#### ServiceCalendar / ServiceDayRule

Reference rules that describe when a school is normally served. This is not daily attendance. It is a master-data rule consumed by Planning.

#### DeliveryLocation

A stable location reference used later by Warehouse release and Dispatch. Admin owns the location master-data fact; Dispatch owns actual delivery execution.

#### SchoolOperationalProfile

A profile combining school type, default service rules, delivery expectations, and operational notes. It helps Planning and downstream domains interpret school context without copying Retool UI behavior.

#### SchoolStatusChange

Auditable event for activating, deactivating, or changing school availability.

#### SchoolMasterDataChange

Append-only change evidence for school master-data edits.

### Commands

- `CreateSchool`
- `UpdateSchoolProfile`
- `SetSchoolStatus`
- `SetSchoolDisplayOrder`
- `AssignSchoolType`
- `SetSchoolServiceRule`
- `SetSchoolDeliveryLocation`
- `RecordSchoolMasterDataChange`

### Events

- `SchoolCreated`
- `SchoolProfileUpdated`
- `SchoolActivated`
- `SchoolDeactivated`
- `SchoolDisplayOrderChanged`
- `SchoolTypeAssigned`
- `SchoolServiceRuleChanged`
- `SchoolDeliveryLocationChanged`
- `SchoolMasterDataChangeRecorded`

### Validation blockers

- missing school name;
- duplicate active school identity where uniqueness is required;
- missing school type when required for planning;
- inactive school used in new Planning input without explicit override;
- missing delivery location when downstream fulfilment requires it;
- attempt to change historical Planning facts by editing school master data;
- attempt to treat school inactive status as cancellation of already released operational documents.

### Read model

`SchoolAdminWorkbench`

Decision question:

```text
Is this school/customer master data valid for Planning and downstream operational reference?
```

Shows active schools, inactive schools, school type, service rules, delivery location, display order, blocking issues, warnings, and change history.

## Ingredients & Suppliers management

### Mission

Maintain ingredient and supplier master data so Planning can calculate needs, Procurement can assign eligible suppliers, and Warehouse can receive/release goods with unit and trace consistency.

### Business objects

#### Ingredient

A purchasable or operational ingredient used by recipes, Planning, Procurement, and Warehouse.

Typical attributes:

- ingredientId;
- ingredientName;
- active/inactive status;
- purchase unit;
- usable/inventory unit where applicable;
- unit profile;
- ingredient group/category;
- operational notes.

#### IngredientUnitProfile

The unit rules for purchasing, planning, receiving, and inventory interpretation.

#### UnitConversionRule

Approved conversion between units where business usage requires it.

Example:

```text
purchase unit: case
inventory unit: item
usable unit: kg
```

The rule is reference data only. Operational domains still own their specific transaction quantities.

#### Supplier

A supplier that may provide ingredients.

Typical attributes:

- supplierId;
- supplierName;
- active/inactive status;
- contact reference where applicable;
- operational notes;
- eligibility status.

#### IngredientSupplierEligibility

A controlled relationship showing which supplier is eligible to supply which ingredient.

#### DefaultSupplierPolicy / SupplierPreference

A master-data reference indicating default or preferred supplier choices. Procurement consumes this as guidance or policy input; Procurement still owns supplier assignment and purchase commitment.

#### IngredientStatusChange

Auditable activation/deactivation/change event for ingredient status.

#### SupplierStatusChange

Auditable activation/deactivation/change event for supplier status.

#### IngredientSupplierChange

Append-only evidence for changes to ingredient-supplier eligibility or preference.

### Commands

- `CreateIngredient`
- `UpdateIngredientProfile`
- `SetIngredientStatus`
- `SetIngredientUnitProfile`
- `CreateUnitConversionRule`
- `CreateSupplier`
- `UpdateSupplierProfile`
- `SetSupplierStatus`
- `SetIngredientSupplierEligibility`
- `SetDefaultSupplierPolicy`
- `RecordIngredientSupplierChange`

### Events

- `IngredientCreated`
- `IngredientProfileUpdated`
- `IngredientActivated`
- `IngredientDeactivated`
- `IngredientUnitProfileChanged`
- `UnitConversionRuleCreated`
- `SupplierCreated`
- `SupplierProfileUpdated`
- `SupplierActivated`
- `SupplierDeactivated`
- `IngredientSupplierEligibilityChanged`
- `DefaultSupplierPolicyChanged`
- `IngredientSupplierChangeRecorded`

### Validation blockers

- missing ingredient name;
- duplicate active ingredient identity where uniqueness is required;
- missing purchase unit;
- missing required unit conversion rule;
- inactive ingredient used in new recipe/BOM, Planning input, Procurement allocation, or Warehouse flow without explicit override;
- inactive supplier selected for new Procurement assignment without explicit override;
- ingredient-supplier relationship missing where Procurement requires eligible suppliers;
- attempt to use preferred/default supplier policy as an already approved PO;
- attempt to mutate Procurement supplier commitment by editing Admin supplier policy.

### Read models

`IngredientAdminWorkbench`

Decision question:

```text
Is this ingredient valid for recipes, Planning, Procurement, and Warehouse use?
```

`SupplierAdminWorkbench`

Decision question:

```text
Which suppliers are active and eligible for which ingredients?
```

Shows ingredient status, unit profile, eligible suppliers, default/preferred suppliers, warnings, blockers, and change history.

## Dishes & Recipes management

### Mission

Maintain dishes and recipe/BOM definitions so Planning and Need Generation can use approved, versioned, and traceable meal composition data.

### Consolidated UI requirement

Dishes & Recipes should be one consolidated Atlas workbench.

The workbench should let an operator manage:

- dish identity;
- dish active/inactive status;
- recipe version;
- recipe lock state;
- recipe/BOM lines;
- school-type variants;
- ingredient quantities and units;
- change/review evidence;
- blocking issues and warnings;
- downstream usage warnings.

This must not be split into separate pages just because OPS v1 Retool had multiple screens/layers.

### Business objects

#### Dish

A menu-selectable item. A dish can exist even when a recipe is not yet valid for operational use.

Typical attributes:

- dishId;
- dishName;
- dish category/type;
- active/inactive status;
- display/order metadata;
- operational notes.

#### DishStatusChange

Auditable event for activating or deactivating a dish.

#### Recipe

A recipe definition associated with a dish and optionally a school type or variant rule.

#### RecipeVersion

A specific version of a recipe/BOM used by Planning and Need Generation. Released operations should reference the version used at the time of calculation.

#### RecipeLock

A governance state indicating whether a recipe version can be changed directly or requires a new version/change set.

#### RecipeLine / BOMLine

Line-level composition of the recipe.

Typical attributes:

- recipeLineId;
- recipeVersionId;
- ingredientId;
- quantity;
- unit;
- usable quantity rule where applicable;
- school type applicability where applicable;
- notes.

#### SchoolTypeRecipeVariant

A recipe variant that applies to a school type when ingredient quantity or composition differs by school type.

#### RecipeChangeSet / RecipeReviewEvidence

A controlled change package showing what was changed, why, by whom, and whether the change is ready for downstream use.

#### RecipeMasterDataChange

Append-only evidence for recipe master-data edits.

### Commands

- `CreateDish`
- `UpdateDishProfile`
- `SetDishStatus`
- `CreateRecipeDraft`
- `CreateRecipeVersion`
- `AddRecipeLine`
- `UpdateRecipeLine`
- `RemoveRecipeLine`
- `SetRecipeSchoolTypeVariant`
- `ValidateRecipeVersion`
- `LockRecipeVersion`
- `UnlockRecipeVersion`
- `CreateRecipeChangeSet`
- `ApproveRecipeChangeSet`
- `ReleaseRecipeVersionForPlanning`
- `RecordRecipeMasterDataChange`

### Events

- `DishCreated`
- `DishProfileUpdated`
- `DishActivated`
- `DishDeactivated`
- `RecipeDraftCreated`
- `RecipeVersionCreated`
- `RecipeLineAdded`
- `RecipeLineUpdated`
- `RecipeLineRemoved`
- `RecipeSchoolTypeVariantSet`
- `RecipeVersionValidated`
- `RecipeVersionLocked`
- `RecipeVersionUnlocked`
- `RecipeChangeSetCreated`
- `RecipeChangeSetApproved`
- `RecipeVersionReleasedForPlanning`
- `RecipeMasterDataChangeRecorded`

### Lifecycle

#### Dish lifecycle

```text
DRAFT
→ ACTIVE
→ INACTIVE
```

Reactivation requires explicit status-change evidence.

#### Recipe version lifecycle

```text
DRAFT
→ VALIDATED
→ RELEASED_FOR_PLANNING
→ LOCKED
```

Correction path:

```text
LOCKED
→ new RecipeVersion / RecipeChangeSet
```

Released Planning outputs should preserve the recipe version used and must not be silently recalculated by later recipe edits.

### Validation blockers

- missing dish name;
- inactive dish selected for new menu without explicit override;
- recipe missing for a dish that requires Need Generation;
- recipe line missing ingredient;
- recipe line ingredient inactive without explicit override;
- recipe line quantity zero or negative;
- unit mismatch without approved unit conversion;
- duplicate recipe line where the recipe policy disallows duplicates;
- missing school-type variant where required;
- attempt to edit a locked/released recipe version without creating a new version or change set;
- attempt to silently recalculate released Need Generation/Confirmed Need/Purchase Handoff after a recipe change;
- attempt to treat recipe approval as QA or production approval.

### Warnings

- dish active but no released recipe version;
- ingredient inactive but still used by old locked recipe version;
- recipe changed after recent Planning runs;
- school-type variant differs from base recipe;
- unit conversion exists but may require operator review;
- downstream domains already reference an older recipe version.

### Read model

`DishRecipeAdminWorkbench`

Decision question:

```text
Is this dish and recipe version safe to release for Planning and Need Generation?
```

Shows dish identity, dish status, recipe versions, lock state, BOM lines, school-type variants, validation issues, downstream usage warnings, and change history in one consolidated workbench.

## Cross-domain reference and snapshot rules

Operational domains should reference approved master data and preserve snapshots where operational correctness requires historical stability.

Examples:

```text
Planning Input / Need Generation references schoolId, dishId, recipeVersionId, ingredientId.
Procurement references ingredientId, supplierId, ingredient-supplier eligibility/policy snapshot.
Warehouse references ingredientId, purchase unit, stock lot, and upstream Procurement/Planning trace.
```

Rules:

- Admin can update future master-data state.
- Admin must not silently rewrite released operational facts.
- Operational documents should retain the master-data reference and, when needed, a release snapshot or version.
- Active/inactive changes affect future operations unless a specific domain command handles existing operational documents.
- Locked recipe versions used by released Planning flows must remain historically interpretable.

## Boundaries with Planning

Planning consumes Admin master data for schools, service rules, dishes, recipes, recipe versions, ingredients, and active/inactive status.

Planning owns daily demand, Need Generation, Confirmed Need, and Purchase Handoff.

Admin must not approve daily demand or recalculate released Planning outputs.

## Boundaries with Procurement

Procurement consumes ingredient, supplier, eligibility, unit, and default/preferred supplier references.

Procurement owns supplier assignment, purchase allocation, PO creation/release, and supplier confirmation.

Admin supplier preference is not a purchase commitment.

## Boundaries with Warehouse

Warehouse consumes ingredient, unit, and trace references from upstream Procurement and Admin master data.

Warehouse owns receiving, stock identity, goods receipt, stock release, and stock movement.

Admin must not modify stock balances, receiving evidence, or warehouse release evidence.

## Boundaries with Dispatch and Delivery

Admin may own delivery-location master data. Dispatch owns actual route planning, driver/vehicle assignment, trip execution, destination delivery confirmation, and delivery exceptions.

DeliveryLocation is not DeliveryConfirmation.

## Boundaries with Production and QA

Production and QA are deferred for the MVP.

Admin may store reference data that Production or QA may later consume, but Admin must not execute production, portioning, inspection, food-safety approval, corrective action, or QA release decisions.

Recipe validation is not QA approval.

## Boundaries with Finance and Accounting

Finance and Accounting are deferred for the MVP.

Admin may store reference fields that future Finance may consume, but Admin must not create invoice, payable, settlement, costing policy, accounting entry, or financial close behavior.

Supplier preference or ingredient reference price, if later added, is not a payable.

## Supabase / backend boundary

No Supabase migration, PostgreSQL schema, RLS, RPC, Edge Function, backend integration, credential, or production-data behavior is part of this contract PR.

Future persistence work must follow the approved contract, preserve domain boundaries, define database constraints explicitly, and avoid copying Retool schema convenience without architectural review.

## Retool boundary

Retool is OPS v1 evidence and selected diagnostic/support tooling only.

Atlas Admin should not clone Retool screens. In particular, Dishes & Recipes must be designed as a consolidated Atlas workbench unless a future product decision approves a split.

## MVP operator views

Recommended MVP Admin views:

```text
Admin Home
├── School Admin Workbench
├── Ingredients & Suppliers Workbench
└── Dishes & Recipes Workbench
```

Each view should be decision-first:

- What is active and usable?
- What is blocked?
- What changed?
- What downstream domains consume this fact?
- Is the object safe to use in new operational flows?

## Implementation readiness criteria

A future Admin foundation PR may proceed only after this contract is reviewed and merged.

The foundation should remain in-memory and fixture-backed first. It should prove:

- school active/inactive management and delivery-location/profile visibility;
- ingredient, supplier, and ingredient-supplier eligibility management;
- consolidated dish and recipe/BOM management;
- recipe version/lock behavior;
- validation blockers for missing, inactive, invalid, or unsafe master data;
- downstream-safe references/snapshots;
- no Planning, Procurement, Warehouse, Dispatch, QA/Production, Finance/Accounting, Supabase, Retool, backend, credential, or production-data behavior.

## Open questions for later implementation

- Which school fields are mandatory for first launch?
- Which supplier fields are needed before real Procurement persistence begins?
- Should ingredient reference pricing exist in Admin MVP, or be deferred to Finance?
- What is the minimum recipe review/approval path before Planning can consume a version?
- How should old recipe versions remain visible after dish or ingredient deactivation?
- How should Admin exports/imports be handled without turning the MVP into a spreadsheet clone?
- Which Admin tables will need release snapshots when Supabase persistence begins?
