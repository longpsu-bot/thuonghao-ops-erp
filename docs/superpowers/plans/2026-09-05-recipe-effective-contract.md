# Recipe Effective Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This task is explicitly single-agent; do not use subagents or parallel execution. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PostgreSQL the single authority for effective Recipe selection, system-versus-School BOM resolution, stable effective-line targeting, full-BOM history, ledger applicability, and atomic Dish-level Recipe copy.

**Architecture:** Add one forward-only migration that centralizes the existing School-Type→GENERAL selector, routes both system and School resolvers through one parameterized composition engine, broadens the existing adjustment-line identity contract, and publishes additive shaped reads/command. Keep React as a typed consumer by registering the new RPCs and result models without implementing PR B UI behavior.

**Tech Stack:** PostgreSQL 15, Supabase RPC/security-definer boundaries, pgTAP, React/TypeScript, Vitest, pnpm.

**Spec:** `docs/superpowers/specs/2026-09-05-recipe-effective-workbench-design.md`

## Global Constraints

- Start from `0779daacb49635dab5b40503f5718dd5f577d6f3` on `codex/recipe-effective-contract-01`.
- Use one agent with parallel execution and subagents disabled.
- Do not change Weekly Menu, Attendance, Need Generation formulas, Pantry, Confirmed Need, Procurement, PO lifecycle, Warehouse, Dispatch, roles/capabilities/RLS vocabulary, live OPS, Retool, hosted Staging data, or deployment state.
- Preserve all RMVP-02A/RMVP-02B v1/v2 callable APIs, immutable history, D-038 approved-menu lock, existing capabilities, fixed search paths, revoke-first grants, optimistic concurrency, idempotency, events, and audit.
- PostgreSQL owns selection, precedence, targeting, dates, history, lifecycle, and copy atomicity; React must not reconstruct them.
- Use only disposable local Supabase for database tests; make zero hosted writes.
- Each backend behavior follows RED → minimal GREEN → focused regression before the next task.

## File map

- Create `supabase/migrations/20260905105253_recipe_effective_contract_01.sql`: additive constraints, private helpers, resolver replacements, shaped reads, Dish copy command, ownership, grants, and comments.
- Create `supabase/tests/recipe_effective_contract_01.sql`: synthetic pgTAP fixture and required A–AF regression matrix.
- Modify `src/modules/atlas/connection/atlasRpc.ts`: allow-list the three additive reads and Dish-copy command.
- Modify `src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.ts`: explicit system/School resolver and target-context request builders.
- Modify `src/modules/atlas/recipe-adjustments/recipeAdjustmentModel.ts`: stable target, history-period, and backend effectiveness types/parsers.
- Modify `src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts`: request/RPC registration tests.
- Modify `src/modules/atlas/recipes/recipeApi.ts`: operator-read and Dish-copy request builders.
- Modify `src/modules/atlas/recipes/recipeModel.ts`: Dish Recipe operator/copy result types and parsers.
- Modify `src/modules/atlas/recipes/recipeApi.test.ts` and `src/modules/atlas/recipes/recipeModel.test.ts`: typed contract coverage.
- Modify `docs/api/rmvp-02a-recipes-bom.md`: additive Dish-level copy contract and lower-level compatibility.
- Modify `docs/api/rmvp-02b-recipe-adjustments-effective-bom.md`: centralized selection, system resolver, target identity, target-context, history, and ledger fields.
- Modify `docs/architecture/rmvp-02b-recipe-adjustments-effective-bom.md`: exact backend ownership and compatibility/rollback consequences.

---

### Task 1: RED contract fixture and centralized Recipe selection

**Files:**

- Create: `supabase/tests/recipe_effective_contract_01.sql`
- Create: `supabase/migrations/20260905105253_recipe_effective_contract_01.sql`

**Interfaces:**

- Produces: `atlas_core.recipe_effective_select_base_recipe(uuid, uuid) returns jsonb`.
- Produces: `atlas_core.recipe_effective_resolve_composition(date, uuid, uuid, uuid, jsonb, uuid, uuid) returns jsonb`, where context is `(as_of_date, school_id, dish_id, school_type_id, proposal, excluded_adjustment_id, historical_recipe_version_id)` and School context derives the type authoritatively.
- Preserves: `atlas_core.rmvp_02b_resolve_effective_composition(date, uuid, uuid, jsonb, uuid, uuid)` as a compatibility wrapper.

- [ ] **Step 1: Create the rolled-back pgTAP fixture and failing A–D assertions**

Create two active School Types named exactly `Tiểu học` and `Trung học`, two active Schools, active Dishes, a GENERAL release, exact School-Type releases, stable base lines, Ingredients, Unit, and authorized read/write Actors. Assert the private selector shape directly:

```sql
select is(
  atlas_core.recipe_effective_select_base_recipe(
    :'typed_dish_id'::uuid, :'primary_type_id'::uuid
  ) -> 'selected_recipe' ->> 'selection_scope',
  'SCHOOL_TYPE',
  'A. explicit Tiểu học selects its exact School-Type Recipe'
);

select is(
  atlas_core.recipe_effective_select_base_recipe(
    :'fallback_dish_id'::uuid, :'primary_type_id'::uuid
  ) -> 'selected_recipe' ->> 'selection_scope',
  'GENERAL',
  'B. Tiểu học falls back to GENERAL'
);

select is(
  atlas_core.recipe_effective_select_base_recipe(
    :'ambiguous_dish_id'::uuid, :'primary_type_id'::uuid
  ) ->> 'status',
  'BLOCKED',
  'C. ambiguity blocks selection'
);
```

For D, compare `selected_recipe.recipe_version_id` returned by the explicit-type engine and the compatibility School resolver.

- [ ] **Step 2: Run the new suite and capture RED**

Run:

```powershell
pnpm exec supabase test db supabase/tests/recipe_effective_contract_01.sql --local
```

Expected: A–D fail because `recipe_effective_select_base_recipe` and `recipe_effective_resolve_composition` do not exist.

- [ ] **Step 3: Implement the one selector and generic resolver boundary**

In the migration, make the selector return only business-safe structured evidence:

```sql
{
  "status": "READY|BLOCKED",
  "selected_recipe": {
    "dish_id": "uuid",
    "school_type_id": "uuid-or-null",
    "recipe_id": "uuid",
    "recipe_version_id": "uuid",
    "selection_scope": "SCHOOL_TYPE|GENERAL",
    "basis_portions": 100,
    "released_at": "timestamp"
  },
  "blockers": []
}
```

Count only active Recipe roots with a `RELEASED_FOR_PLANNING` version. Count the exact School-Type tier first; if zero, count GENERAL. Return `AMBIGUOUS_SCHOOL_TYPE_RECIPE`, `AMBIGUOUS_GENERAL_RECIPE`, or `RECIPE_SELECTION_BLOCKED` without choosing by UUID/time.

Copy the existing RMVP-02B transformation algorithm into the generic resolver, replacing its embedded candidate queries with the selector. When `school_id` is present, load the active School and overwrite `school_type_id` with the School's authoritative value. The compatibility function becomes only:

```sql
return atlas_core.recipe_effective_resolve_composition(
  target_as_of_date, target_school_id, target_dish_id, null,
  proposed_adjustment, excluded_adjustment_id,
  historical_recipe_version_id
);
```

- [ ] **Step 4: Run A–D GREEN and the existing resolver suite**

Run:

```powershell
pnpm exec supabase test db supabase/tests/recipe_effective_contract_01.sql supabase/tests/rmvp_02b_recipe_adjustments_effective_bom.sql --local
```

Expected: A–D pass and existing RMVP-02B selection/resolution assertions remain green.

- [ ] **Step 5: Commit centralized selection**

```powershell
git add supabase/migrations/20260905105253_recipe_effective_contract_01.sql supabase/tests/recipe_effective_contract_01.sql
git commit -m "feat: centralize effective recipe selection"
```

### Task 2: System-effective composition and shaped target context

**Files:**

- Modify: `supabase/migrations/20260905105253_recipe_effective_contract_01.sql`
- Modify: `supabase/tests/recipe_effective_contract_01.sql`

**Interfaces:**

- Consumes: `recipe_effective_resolve_composition(...)` from Task 1.
- Produces: `atlas_api.resolve_system_effective_recipe_composition(jsonb)` using `RECIPE-EFFECTIVE.v1`.
- Produces: `atlas_api.get_recipe_effective_target_context(jsonb)` using `RECIPE-EFFECTIVE.v1` and exactly one context key, `school_type_id` or `school_id`.

- [ ] **Step 1: Add failing E–G, Q, and R assertions**

Insert synthetic `SYSTEM_INGREDIENT`, `SYSTEM_DISH`, `SCHOOL`, and `SCHOOL_DISH` roots/revisions for the same date. Call the missing system RPC as an authenticated Actor and assert transformed Ingredient/quantity evidence includes only the first two layers. Assert target context for a typed scope backed only by GENERAL returns its present base line. Assert School context returns the final School-effective present lines.

- [ ] **Step 2: Run and capture RED**

Run the single new pgTAP file; expected failures are missing public functions.

- [ ] **Step 3: Implement the system resolver RPC**

Validate `RECIPE-EFFECTIVE.v1`, authenticated subject, explicit ISO `as_of_date`, `dish_id`, and active `school_type_id`; authorize `master_data.recipe_adjustments.read`; call the generic resolver with `school_id = null`. Because `rmvp_02b_active_rules` receives no School, it returns only system layers. Return `resolution` without client-selected RecipeVersion authority.

- [ ] **Step 4: Implement the target-context RPC**

Reject both/neither context IDs. Resolve using the system or School path and map each `PRESENT` line to:

```json
{
  "ingredient_id": "uuid",
  "ingredient_name": "text",
  "quantity_per_basis": "exact-decimal",
  "unit_id": "uuid",
  "unit_name": "text",
  "target_kind": "RECIPE_LINE|ADJUSTMENT_LINE",
  "target_recipe_line_id": "uuid-or-null",
  "adjustment_line_id": "uuid-or-null",
  "target_id": "uuid",
  "source_layer": "text"
}
```

Set `target_kind` and `target_id` from `base_recipe_line_id` when present, otherwise `adjustment_line_id`. Include the selected Recipe, basis, warnings, and blockers unchanged.

- [ ] **Step 5: Run E–G/Q/R GREEN and existing RMVP-02B regression**

Use the Task 1 two-file pgTAP command. Expected: system view excludes both School layers while School context includes them.

- [ ] **Step 6: Commit system and target reads**

```powershell
git add supabase/migrations/20260905105253_recipe_effective_contract_01.sql supabase/tests/recipe_effective_contract_01.sql
git commit -m "feat: add effective recipe target contexts"
```

### Task 3: Adjustment-line targeting through Preview and commands

**Files:**

- Modify: `supabase/migrations/20260905105253_recipe_effective_contract_01.sql`
- Modify: `supabase/tests/recipe_effective_contract_01.sql`

**Interfaces:**

- Changes: `atlas_admin.recipe_composition_adjustments_typed_scope_check` so non-ADD `SYSTEM_DISH`/`SCHOOL_DISH` stores exactly one target ID.
- Changes: `atlas_core.rmvp_02b_validate_proposed_adjustment(...)`, the generic resolver, and compatible Preview/Create/Supersede readback paths.
- Stable identity: `action_kind = 'ADD'` means `adjustment_line_id` is owned; otherwise exactly one of `target_recipe_line_id` or `adjustment_line_id` is targeted.

- [ ] **Step 1: Add failing H–P and S assertions**

Cover each non-ADD action (`REPLACE`, `ADJUST_QUANTITY`, `REMOVE`) against a base line and an earlier effective ADD. Cover `SCHOOL_DISH` against base, `SYSTEM_DISH ADD`, and earlier applicable `SCHOOL_DISH ADD`. Assert both IDs and neither ID return `TYPED_SCOPE_INVALID`; a removed/expired/cancelled origin returns `TARGET_NOT_APPLICABLE`; overlapping temporal targets still return `OVERLAPPING_ACTIVE_RULE`. For S, send the exact `target_kind`/ID returned by target context through Preview and Create and assert readback preserves it.

- [ ] **Step 2: Run and capture RED**

Expected: adjustment-line non-ADD proposals fail current typed validation and the current resolver cannot transform an added line.

- [ ] **Step 3: Relax only the typed XOR constraint and validation**

Replace the table CHECK in the forward migration. For non-ADD `SYSTEM_DISH`/`SCHOOL_DISH`, require `target_ingredient_id is null` and:

```sql
(target_recipe_line_id is not null)::integer
+ (adjustment_line_id is not null)::integer = 1
```

Apply the identical rule in `rmvp_02b_validate_proposed_adjustment`. Validate Recipe-line ownership as today. Validate adjustment-line applicability via resolver/Preview rather than mere root existence.

- [ ] **Step 4: Make target locks and overlap identity kind-aware**

Replace target-key expressions everywhere with:

```sql
case
  when action_kind = 'ADD' then 'OWNS_ADJUSTMENT_LINE:' || adjustment_line_id
  when target_recipe_line_id is not null then 'RECIPE_LINE:' || target_recipe_line_id
  else 'ADJUSTMENT_LINE:' || adjustment_line_id
end
```

Keep scope, Dish, School, School Type, and effective multirange comparisons unchanged. Do not collapse an owned ADD and a later modifier into duplicate roots; only competing non-ADD rules for the same origin/period conflict.

- [ ] **Step 5: Apply ADDs before modifiers within each line-scoped layer**

For `SYSTEM_DISH` and `SCHOOL_DISH`, order active rules by `case when action_kind = 'ADD' then 0 else 1 end`, then stable ID. Match modifiers with:

```sql
(rule.target_recipe_line_id is not null
 and line.base_recipe_line_id = rule.target_recipe_line_id)
or
(rule.target_recipe_line_id is null
 and line.adjustment_line_id = rule.adjustment_line_id)
```

Transform only `PRESENT` lines. Emit `TARGET_NOT_APPLICABLE` if no matching present line exists. This proves a School modifier can target a system-added line because all system rules complete before the School layers.

- [ ] **Step 6: Replace Preview/Create/Supersede applicability checks**

Where the current code searches only `base_recipe_line_id`, use the kind-aware predicate above. Preserve Create expected version `1`, Supersede frozen target identity, exact predecessor, and command receipts. Readback continues to expose both nullable target columns.

- [ ] **Step 7: Run H–P/S GREEN and both existing RMVP suites**

Run:

```powershell
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql supabase/tests/rmvp_02b_recipe_adjustments_effective_bom.sql supabase/tests/recipe_effective_contract_01.sql --local
```

Expected: new targeting cases pass with existing overlap, concurrency, correction, and immutable-history assertions unchanged.

- [ ] **Step 8: Commit stable target identity**

```powershell
git add supabase/migrations/20260905105253_recipe_effective_contract_01.sql supabase/tests/recipe_effective_contract_01.sql
git commit -m "feat: target effective adjustment lines"
```

### Task 4: Effective history, Dish operator read, and ledger effectiveness

**Files:**

- Modify: `supabase/migrations/20260905105253_recipe_effective_contract_01.sql`
- Modify: `supabase/tests/recipe_effective_contract_01.sql`

**Interfaces:**

- Produces: `atlas_core.recipe_effective_history(date, uuid, uuid, uuid) returns jsonb`.
- Produces: `atlas_api.get_dish_recipe_operator_workbench(jsonb)` using `RECIPE-EFFECTIVE.v1`.
- Changes: `atlas_api.get_recipe_adjustment_operator_workbench(jsonb)` adds `operator_rows[].is_effective_now` without changing `RMVP-02B.v2` inputs.

- [ ] **Step 1: Add failing T–Z assertions**

Assert full system BOM periods, full School BOM periods, one boundary for simultaneous changes, a new period at finite `effective_to`, and retained earlier periods after correction/cancellation. For each temporal state fixture, assert the exact backend boolean independently of `effective_to`.

- [ ] **Step 2: Run and capture RED**

Expected: history/operator RPC is missing and ledger rows omit `is_effective_now`.

- [ ] **Step 3: Implement the history helper**

Build applicable boundary dates from the selected Recipe's release date plus every applicable adjustment revision `effective_from` and non-null `effective_to`; use `UNION` to coalesce simultaneous dates. For each ordered boundary, call the generic resolver at that date and set `period_to` to the next boundary. Include the complete `lines` array and all revisions whose authoritative period contributes within that interval, shaped as:

```json
{
  "adjustment_id": "uuid",
  "action_kind": "ADD|REPLACE|ADJUST_QUANTITY|REMOVE",
  "effective_from": "date",
  "effective_to": "date-or-null",
  "reason": "text",
  "issuer": "text-or-null",
  "issued_at": "timestamp-or-null"
}
```

System context filters to `SYSTEM_INGREDIENT`/`SYSTEM_DISH`. School context also includes matching `SCHOOL`/`SCHOOL_DISH`. Retain immutable corrected/cancelled revisions when they contributed historically.

- [ ] **Step 4: Implement the Dish operator RPC**

Require `as_of_date`, `dish_id`, and exactly one of `school_type_id` or `school_id`. Resolve the current BOM and return Dish name/type, requested scope, selected base, basis, D-038 lock/allowed actions, current effective BOM, applicable School-exception count, blockers/warnings, and `history_periods`. For School context, return the final School-effective result and four-layer history.

- [ ] **Step 5: Add backend `is_effective_now` to the v2 ledger**

Call `uiq03b_recipe_adjustment_operator_payload(reference_date)` once, map its `operator_rows`, and add:

```sql
'is_effective_now', row ->> 'temporal_state' in (
  'ACTIVE', 'ACTIVE_RESUMED', 'ACTIVE_CHANGE_SCHEDULED',
  'ACTIVE_CANCELLATION_SCHEDULED'
)
```

Preserve `temporal_state`, `temporal_state_date`, `effective_from`, and `effective_to` independently.

- [ ] **Step 6: Run T–Z GREEN plus operator regressions**

Run the new suite, existing RMVP-02B pgTAP, and `supabase/tests/ui_quality_03b_recipe_adjustment_operator_workbench.sql`.

- [ ] **Step 7: Commit history/operator reads**

```powershell
git add supabase/migrations/20260905105253_recipe_effective_contract_01.sql supabase/tests/recipe_effective_contract_01.sql
git commit -m "feat: shape effective recipe history"
```

### Task 5: Atomic Dish-level Recipe copy

**Files:**

- Modify: `supabase/migrations/20260905105253_recipe_effective_contract_01.sql`
- Modify: `supabase/tests/recipe_effective_contract_01.sql`

**Interfaces:**

- Produces: `atlas_api.copy_dish_recipes(jsonb)` using `RECIPE-EFFECTIVE.v1` and existing `master_data.recipes.write` authority.
- Consumes: centralized selector and lower-level `atlas_api.copy_recipe_version(jsonb)`.
- Preserves: lower-level `copy_recipe_version` unchanged and callable.

- [ ] **Step 1: Add failing AA–AF assertions**

Assert one call creates target drafts for both active supported School Types, missing source resolution returns `SOURCE_NOT_AVAILABLE` without target Recipe, approved-menu lock yields no target writes, a second-scope induced failure rolls back the first scope, exact replay returns the original result and IDs, and a changed payload with the same idempotency key returns the existing conflict response.

- [ ] **Step 2: Run and capture RED**

Expected: `copy_dish_recipes` is missing.

- [ ] **Step 3: Extend the D-038 target-Dish lock resolver**

Replace `uiq03a_rmvp_02a_target_dish_ids` so command `copy_dish_recipes` resolves exactly `payload.target_dish_id`. Preserve every existing case. The outer prepare command therefore takes the same advisory lock and rejects approved-menu use before child writes.

- [ ] **Step 4: Implement the outer receipt and supported-scope resolution**

Validate the `RECIPE-EFFECTIVE.v1` command envelope by reusing RMVP-02A validation rules through an internal normalized validation request. Authorize `master_data.recipes.write`, require distinct active source/target Dishes and expected target Dish version, and enumerate active School Types whose exact business names are `Tiểu học` or `Trung học` in deterministic order.

For each scope call `recipe_effective_select_base_recipe`. A no-candidate result appends `{scope_name, status: 'SOURCE_NOT_AVAILABLE'}`; ambiguity aborts the command. A ready result derives a child RMVP-02A.v1 copy request with stable child command/idempotency IDs derived from the outer command and scope, the same authenticated subject, expected target Dish version, and exact selected `source_recipe_version_id`.

- [ ] **Step 5: Enforce all-scope atomicity with a subtransaction**

Execute every required child call inside one PL/pgSQL exception block. If any child response has `success <> true`, raise a private exception so all child Recipe/Version/Line/receipt/event/audit writes roll back, catch it outside the block, and finish only the outer receipt with a safe failure. On success finish the outer receipt with deterministic per-scope results and copied target IDs.

- [ ] **Step 6: Run AA–AF GREEN and RMVP-02A regressions**

Run the new suite, RMVP-02A connected suite, UI-QUALITY-03A Recipe workflow suite, and Issue 213 Recipe save activation suite.

- [ ] **Step 7: Commit Dish-level copy**

```powershell
git add supabase/migrations/20260905105253_recipe_effective_contract_01.sql supabase/tests/recipe_effective_contract_01.sql
git commit -m "feat: copy dish recipes atomically"
```

### Task 6: Typed React contract consumers

**Files:**

- Modify: `src/modules/atlas/connection/atlasRpc.ts`
- Modify: `src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.ts`
- Modify: `src/modules/atlas/recipe-adjustments/recipeAdjustmentModel.ts`
- Modify: `src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts`
- Modify: `src/modules/atlas/recipes/recipeApi.ts`
- Modify: `src/modules/atlas/recipes/recipeModel.ts`
- Modify: `src/modules/atlas/recipes/recipeApi.test.ts`
- Modify: `src/modules/atlas/recipes/recipeModel.test.ts`

**Interfaces:**

- Consumes: four public APIs from Tasks 2, 4, and 5.
- Produces: typed request builders and parsers for PR B; no workbench UI behavior changes.

- [ ] **Step 1: Add failing API tests**

Assert exact RPC names and payloads for system resolution, School/system target context, Dish operator context, and Dish copy. The copy request must preserve caller-supplied command/idempotency IDs in test fixtures so replay can be exercised.

- [ ] **Step 2: Run focused Vitest and capture RED**

Run:

```powershell
pnpm exec vitest run src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts src/modules/atlas/recipes/recipeApi.test.ts src/modules/atlas/recipes/recipeModel.test.ts
```

Expected: new exports/RPC names are absent.

- [ ] **Step 3: Register RPCs and implement request builders**

Register:

```ts
"atlas_api.resolve_system_effective_recipe_composition";
"atlas_api.get_recipe_effective_target_context";
"atlas_api.get_dish_recipe_operator_workbench";
"atlas_api.copy_dish_recipes";
```

All new requests use `contract_version: "RECIPE-EFFECTIVE.v1"`. Context builders accept discriminated unions so both/neither School IDs are unrepresentable in TypeScript.

- [ ] **Step 4: Add exact model types and guarded parsers**

Define `EffectiveTargetLine`, `EffectiveHistoryPeriod`, `DishRecipeOperatorWorkbench`, and `DishRecipeCopyResult`. Add `is_effective_now: boolean` to `RecipeAdjustmentOperatorRecord`. Parse only successful objects with required arrays/scalars; return `null` for malformed envelopes.

- [ ] **Step 5: Run focused Vitest GREEN and typecheck**

Run the Task 6 Vitest command and `pnpm typecheck`.

- [ ] **Step 6: Commit typed consumers**

```powershell
git add src/modules/atlas/connection/atlasRpc.ts src/modules/atlas/recipe-adjustments src/modules/atlas/recipes
git commit -m "feat: type effective recipe contracts"
```

### Task 7: API/architecture documentation and targeted completion verification

**Files:**

- Modify: `docs/api/rmvp-02a-recipes-bom.md`
- Modify: `docs/api/rmvp-02b-recipe-adjustments-effective-bom.md`
- Modify: `docs/architecture/rmvp-02b-recipe-adjustments-effective-bom.md`
- Verify: all touched files

**Interfaces:**

- Documents: exact callable names, envelopes, shapes, target XOR, history periods, ledger boolean, copy atomicity/replay, security, compatibility, and rollback.

- [ ] **Step 1: Update the exact API contracts**

Record `RECIPE-EFFECTIVE.v1`, function ownership/capability, required payload keys, safe blockers, and response examples. State that `copy_recipe_version` remains support-level and that PR B consumes the new shaped rows without Recipe selection, date inference, or revision replay.

- [ ] **Step 2: Update architecture and rollback notes**

Record one centralized selector, system-versus-School layer sets, stable origin targeting, immutable period history, no new business relation/capability/role, forward-only rollback after business history exists, and zero hosted/deployment change.

- [ ] **Step 3: Run required backend verification once**

Run affected RMVP-02A, affected RMVP-02B, new contract, operator, workflow, and lock tests in one targeted Supabase command. Record pgTAP assertion totals and failures from the output.

- [ ] **Step 4: Run required frontend verification**

Run relevant API/model Vitest and `pnpm typecheck`.

- [ ] **Step 5: Format only touched files and check whitespace**

```powershell
pnpm exec prettier --write docs/superpowers/specs/2026-09-05-recipe-effective-workbench-design.md docs/superpowers/plans/2026-09-05-recipe-effective-contract.md docs/api/rmvp-02a-recipes-bom.md docs/api/rmvp-02b-recipe-adjustments-effective-bom.md docs/architecture/rmvp-02b-recipe-adjustments-effective-bom.md src/modules/atlas/connection/atlasRpc.ts src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.ts src/modules/atlas/recipe-adjustments/recipeAdjustmentModel.ts src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts src/modules/atlas/recipes/recipeApi.ts src/modules/atlas/recipes/recipeModel.ts src/modules/atlas/recipes/recipeApi.test.ts src/modules/atlas/recipes/recipeModel.test.ts
git diff --check
```

- [ ] **Step 6: Inspect security and scope delta**

Confirm the migration adds no relation, capability, role, runtime role, RLS policy vocabulary, Warehouse reference, hosted credential, or deployment command. Confirm every new API has fixed empty `search_path`, correct runtime owner, authenticated execute, and revoked `PUBLIC`/`anon`/`service_role` execute.

- [ ] **Step 7: Commit documentation and verification-ready state**

```powershell
git add docs supabase src
git commit -m "docs: publish effective recipe contracts"
```

- [ ] **Step 8: Push and create a new Draft PR**

Push `codex/recipe-effective-contract-01` and create a Draft PR titled:

```text
RECIPE-EFFECTIVE-CONTRACT-01: unify effective Recipe, history, targeting and Dish-level copy
```

Do not mark Ready until targeted checks are green. Do not merge and do not deploy. Report starting/final SHA, PR URL, contract list, central selector, target identity proof, history shape, system-vs-School proof, copy atomicity, RED/GREEN counts, CI state, and zero hosted writes.

## Plan self-review

- Spec coverage: Tasks 1–7 cover selection A–D, system resolution E–G, targeting H–S, history T–X, ledger Y–Z, copy AA–AF, TypeScript consumers, documentation, security, rollback, and delivery.
- Placeholder scan: every step names concrete files, functions, shapes, commands, and expected failures/passes; no deferred implementation step remains.
- Type consistency: all new public APIs use `RECIPE-EFFECTIVE.v1`; both reads consume the same generic resolver; stable targets use the same two nullable IDs; the operator and TypeScript history shapes match the backend contract.
