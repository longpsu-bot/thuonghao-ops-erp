# Recipe Effective Product Model Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. OPS project policy requires one agent; do not use subagents or parallel execution.

**Goal:** Correct Draft PR #257 so every new Dish owns exactly two canonical typed Recipe roots, unlocked base authoring remains possible before any released Recipe exists, RECIPE-EFFECTIVE uses typed-only selection, Dish-level copy snapshots the system-effective BOM for both scopes, and history/exception reads include only materially applicable Change Orders.

**Architecture:** Preserve both reviewed #257 migrations, including the existing product-model correction after `20260905105253_recipe_effective_contract_01.sql`, and add the approved lifecycle correction as a new forward migration after `20260905161348_recipe_effective_product_model_correction.sql`. PostgreSQL remains authoritative for canonical scope identity, Recipe lifecycle, effective selection, Change Order precedence, copy materialization, history relevance, and allowed actions. React/TypeScript only exposes and validates the corrected shaped contracts. Existing NULL-general and synthetic Recipe data remains compatibility evidence and is not backfilled by this task.

**Tech Stack:** PostgreSQL 17 / Supabase CLI 2.111.0, pgTAP, TypeScript 7, React 19, Vitest 4, pnpm 11.

**Spec:** `docs/superpowers/specs/2026-09-05-recipe-effective-product-model-correction-design.md`

## Approved final lifecycle amendment — execute after the existing tasks

This amendment is authoritative over earlier plan text that makes a new Dish
`DRAFT` or preserves Recipe-save activation. Do not rewrite reviewed migrations
`20260905105253_recipe_effective_contract_01.sql` or
`20260905161348_recipe_effective_product_model_correction.sql`. Generate one
new forward correction migration after both.

The implementation sequence is:

1. Add a dedicated lifecycle-correction pgTAP suite and update the registered
   Issue #213 suite first; run both against head
   `e8899940efa923f5427246c82a00b5ea2ad3c52a` and retain the expected RED
   evidence.
2. In the new migration, replace `create_dish` so the atomic Dish/root command
   persists and reads back `ACTIVE` at version 1, keeps the active Dish-Type
   precondition, prechecks normalized active-name uniqueness, and relies on the
   existing unique index as the final concurrent-race guard.
3. Replace the Recipe command finalizer so Recipe Save records only Recipe
   event/audit evidence and returns the unchanged Dish version without a Dish
   lifecycle mutation or `DishActivated` evidence.
4. Preserve strict released-Recipe readiness while proving root-only,
   DRAFT/VALIDATED, and released unused states remain `EDITABLE_BASE`; prove
   approved Menu evidence derives `LOCKED_CHANGE_ORDER` without changing Dish
   status/version.
5. Exercise a newly command-created Dish as the immediate two-scope copy target
   and retain locked-target, Need readiness, and school-specific Change Order
   regressions.
6. Update only relevant RMVP-02A / Recipe-effective documentation and the local
   browser verifier. Do not add an activate/deactivate UI control.
7. Run focused pgTAP, Recipe API/model Vitest, typecheck, touched-file Prettier,
   `git diff --check`, and the security catalog. Only after targeted GREEN,
   push the same PR, mark it Ready, and wait for exact-head Full Integration.

Final acceptance maps A–R to: ACTIVE persistence/readback; two canonical roots;
zero versions; duplicate normalized-name and inactive Dish-Type protection;
root-only editability with blocked readiness; no Save-time Dish mutation,
activation event, or lifecycle version bump; released unused editability;
approved-Menu-derived lock without lifecycle mutation; immediate new-Dish copy
targeting; locked-target denial; released Recipe Need eligibility; and retained
school-specific Change Order behavior.

## Global Constraints

- Start from Draft PR #257 branch `codex/recipe-effective-contract-01`; do not create a new PR.
- Keep PR #257 Draft until all targeted checks are green.
- OPS_SYSTEM_MAP v1.0 and repository authority override external skill guidance.
- Single agent only; parallel work OFF; subagents OFF.
- Add a forward correction migration; do not edit `20260905105253_recipe_effective_contract_01.sql` or `20260905161348_recipe_effective_product_model_correction.sql`.
- Canonical Recipe scopes are identified only by `school_type_code = 'v1-school-type-1'` and `'v1-school-type-2'`; display-name capitalization is never identity.
- Every newly command-created Dish owns exactly one active Recipe root for each canonical School Type; no RecipeVersion is created by `create_dish`.
- `RECIPE-EFFECTIVE.v1` never falls back to `school_type_id IS NULL`.
- Unlocked base Recipe authoring must work when a typed Recipe root has no RecipeVersion, a DRAFT/VALIDATED version, or an unrelocked RELEASED version.
- Effective reads, Change Orders, history, and source-side Dish copy require a released typed Recipe.
- Dish-level copy snapshots system-effective BOM only: base typed Recipe → SYSTEM_INGREDIENT → SYSTEM_DISH. Never include SCHOOL or SCHOOL_DISH.
- Copy writes into the two pre-provisioned target Recipe roots, preserves immutable RecipeVersion/line history, and is atomic across both scopes.
- School-specific Change Order targeting already implemented on #257 must remain intact, including ADJUSTMENT_LINE targets.
- No Weekly Menu behavior, Attendance, Need Generation formula, Pantry, Confirmed Need, Procurement, PO, Warehouse, Dispatch, capability vocabulary, RLS vocabulary, hosted Staging data, live OPS, or Retool mutation.
- No deployment and no merge from this task.
- During development run focused tests only. GitHub Actions is the broad authority after the PR is marked Ready.

---

### Task 1: Establish RED coverage for the corrected product model

**Files:**

- Create: `supabase/tests/recipe_effective_product_model_correction.sql`
- Modify: `supabase/tests/recipe_effective_contract_01.sql`
- Test: `supabase/tests/rmvp_02a_connected_recipes_bom.sql`
- Test: `supabase/tests/ui_quality_03a_recipe_workflow.sql`

**Interfaces:**

- Consumes: existing #257 functions `atlas_core.recipe_effective_select_base_recipe`, `atlas_core.recipe_effective_resolve_composition`, `atlas_api.get_dish_recipe_operator_workbench`, `atlas_api.copy_dish_recipes`.
- Produces: one failing pgTAP correction suite that proves the exact product-model gaps before the forward correction migration exists.

- [ ] **Step 1: Add canonical uppercase fixtures and helper assertions**

Create `supabase/tests/recipe_effective_product_model_correction.sql` with canonical School Types whose stable codes are correct and whose display names are uppercase:

```sql
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name, school_type_status
) values
  ('d1100000-0000-0000-0000-000000000001', 'v1-school-type-1', 'TIỂU HỌC', 'ACTIVE'),
  ('d1100000-0000-0000-0000-000000000002', 'v1-school-type-2', 'TRUNG HỌC', 'ACTIVE')
on conflict (school_type_code) do update
set school_type_name = excluded.school_type_name,
    school_type_status = excluded.school_type_status;
```

Use isolated `d1...` fixture IDs for the new Dish/Recipe/copy/history cases so the suite does not depend on #257's existing `c1...` fixtures.

- [ ] **Step 2: Add RED assertions A–F for Dish pair creation and typed-only effective selection**

After creating a Dish through `atlas_api.create_dish`, assert:

```sql
select is(
  (select count(*) from atlas_admin.recipes r where r.dish_id = :new_dish and r.recipe_status = 'ACTIVE'),
  2::bigint,
  'A. create_dish provisions exactly two active Recipe roots'
);

select is(
  (select count(*) from atlas_admin.recipes r
   join atlas_admin.school_types st on st.school_type_id = r.school_type_id
   where r.dish_id = :new_dish and st.school_type_code = 'v1-school-type-1'),
  1::bigint,
  'B. exactly one TIỂU HỌC root exists'
);

select is(
  (select count(*) from atlas_admin.recipes r
   join atlas_admin.school_types st on st.school_type_id = r.school_type_id
   where r.dish_id = :new_dish and st.school_type_code = 'v1-school-type-2'),
  1::bigint,
  'C. exactly one TRUNG HỌC root exists'
);
```

Create a legacy NULL Recipe fixture and assert `recipe_effective_select_base_recipe` ignores it and blocks when the exact typed released Recipe is missing:

```sql
select ok(
  atlas_core.recipe_effective_select_base_recipe(:dish_id, :primary_type)
    -> 'blockers' @? '$[*] ? (@.code == "RECIPE_SELECTION_BLOCKED")',
  'D/E. RECIPE-EFFECTIVE never falls back to NULL-general data'
);
```

Repeat for Trung học for requirement F.

- [ ] **Step 3: Add RED assertions for unlocked base-authoring states**

Create four operator-read fixtures for the same canonical scope:

```text
root only / no RecipeVersion
DRAFT
VALIDATED
RELEASED_FOR_PLANNING but Dish not operationally locked
```

For each call `atlas_api.get_dish_recipe_operator_workbench` and assert:

```sql
response #>> '{workbench,editable_state}' = 'EDITABLE_BASE'
response #>> '{workbench,is_editable}' = 'true'
```

For the root-only case assert that effective readiness may be blocked/absent but the operator read itself succeeds and exposes an empty base composition rather than returning an effective-read failure.

Create an approved-Menu lock fixture and assert:

```sql
response #>> '{workbench,editable_state}' = 'LOCKED_CHANGE_ORDER'
response #>> '{workbench,is_editable}' = 'false'
```

- [ ] **Step 4: Add RED assertions H–P for effective snapshot copy**

Build source typed Recipes with released BOMs for both canonical scopes, then layer a SYSTEM_DISH adjustment and a School-specific adjustment. The expected source snapshot for copy must include the system change and exclude the School change.

Assert:

```sql
-- H/I/J
select ok(copy_response ->> 'success' = 'true', 'both typed scopes copy');
select ok(target_primary_bom @> :expected_system_effective_primary, 'system-effective Tiểu học snapshot copied');
select ok(target_secondary_bom @> :expected_system_effective_secondary, 'system-effective Trung học snapshot copied');

-- K
select ok(not target_primary_bom @? '$[*] ? (@.ingredient_name == "school-only ingredient")',
  'School-specific adjustment is excluded from Dish copy');

-- L
select is(source_original_bom_after, source_original_bom_before,
  'copy does not mutate source base Recipe/BOM');
```

After the copy, mutate only local test adjustment state to simulate a later source system-rule change and assert the already-created target RecipeVersion composition is byte-for-byte unchanged (M).

For N/O/P, assert both-scope atomicity, missing required source typed scope causes no target RecipeVersion change, and D-038 locked target causes no target write.

- [ ] **Step 5: Add RED assertions for history and exception relevance**

Create:

- an unrelated SYSTEM_INGREDIENT adjustment targeting an Ingredient absent from the Dish;
- a relevant SYSTEM_INGREDIENT adjustment targeting an Ingredient present in the effective Dish;
- an unrelated SCHOOL adjustment targeting an Ingredient absent from the selected Dish;
- a relevant SCHOOL adjustment and a relevant SCHOOL_DISH adjustment.

Assert the unrelated system adjustment creates neither a history tag nor a standalone BOM boundary, while the relevant one does. Assert `school_exception_count` counts only the two relevant school-specific roots.

- [ ] **Step 6: Run the correction suite and capture expected RED**

Run:

```bash
pnpm exec supabase test db supabase/tests/recipe_effective_product_model_correction.sql
```

Expected before implementation: failures proving at least pair provisioning, typed-only selector, unlocked root-only operator state, effective snapshot copy semantics, and history/exception applicability are not yet satisfied.

- [ ] **Step 7: Commit the RED tests**

```bash
git add supabase/tests/recipe_effective_product_model_correction.sql \
  supabase/tests/recipe_effective_contract_01.sql \
  supabase/tests/rmvp_02a_connected_recipes_bom.sql \
  supabase/tests/ui_quality_03a_recipe_workflow.sql
git commit -m "test(recipes): define corrected effective Recipe product model"
```

---

### Task 2: Add the forward correction migration for canonical Recipe roots and typed-only selection

**Files:**

- Create: `supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql`
- Modify: `supabase/tests/recipe_effective_product_model_correction.sql`
- Test: `supabase/tests/rmvp_02a_connected_recipes_bom.sql`
- Test: `supabase/tests/recipe_effective_contract_01.sql`

**Interfaces:**

- Produces: `atlas_core.recipe_effective_canonical_school_types()`, corrected `atlas_api.create_dish(jsonb)`, corrected `atlas_core.recipe_effective_select_base_recipe(uuid,uuid)`.
- Consumes later: Tasks 3–5 use these canonical typed roots and selector.

- [ ] **Step 1: Implement canonical School-Type resolution by stable code**

In the new forward migration, add a private helper:

```sql
create function atlas_core.recipe_effective_canonical_school_types()
returns table (
  scope_order integer,
  school_type_id uuid,
  school_type_code text,
  school_type_name text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select expected.scope_order,
         school_type.school_type_id,
         school_type.school_type_code,
         school_type.school_type_name
  from (values
    (1, 'v1-school-type-1'::text),
    (2, 'v1-school-type-2'::text)
  ) expected(scope_order, school_type_code)
  join atlas_admin.school_types school_type
    on school_type.school_type_code = expected.school_type_code
   and school_type.school_type_status = 'ACTIVE'
  order by expected.scope_order;
$$;
```

Callers must also verify the helper returns exactly two rows; the helper itself does not silently substitute by display name.

- [ ] **Step 2: Replace `create_dish` in the forward migration**

Preserve the existing #254/#256 envelope, code generation, authorization, receipt and event behavior. After `rmvp_02a_prepare_command` returns a non-replay execution context:

```sql
select count(*) into v_canonical_count
from atlas_core.recipe_effective_canonical_school_types();
if v_canonical_count <> 2 then
  return atlas_core.pa_05b_finish_command(
    v_receipt_id,
    atlas_core.pa_05b_command_error(
      request, 'INVARIANT_VIOLATION',
      'The two canonical Recipe School Types are not ready.',
      'ADMIN', v_name
    ), false
  );
end if;
```

Lock both canonical rows in stable code order, insert the Dish, then insert two active Recipe roots in the same transaction:

```sql
insert into atlas_admin.recipes (dish_id, school_type_id, recipe_status)
select v_dish_id, canonical.school_type_id, 'ACTIVE'
from atlas_core.recipe_effective_canonical_school_types() canonical
order by canonical.scope_order
returning recipe_id, school_type_id;
```

Do not insert any RecipeVersion. Return `affected_aggregate_ids.recipe_ids` as an ordered JSON array with `school_type_id`, `school_type_code`, and `recipe_id`.

- [ ] **Step 3: Make the RECIPE-EFFECTIVE selector typed-only**

Replace `atlas_core.recipe_effective_select_base_recipe(uuid,uuid)` so it:

- rejects null/noncanonical/inactive School Type context;
- requires exactly one active Recipe root for the exact `dish_id + school_type_id`;
- requires exactly one `RELEASED_FOR_PLANNING` RecipeVersion for that root;
- never queries `school_type_id is null`;
- returns `selection_scope = 'SCHOOL_TYPE'` only.

Use explicit blocker codes:

```text
CANONICAL_SCHOOL_TYPE_REQUIRED
TYPED_RECIPE_ROOT_MISSING
RECIPE_SELECTION_BLOCKED
AMBIGUOUS_SCHOOL_TYPE_RECIPE
```

Keep legacy RMVP-02B compatibility through its renamed/private compatibility path; do not route RECIPE-EFFECTIVE.v1 back through NULL fallback.

- [ ] **Step 4: Run focused pair/selector tests**

```bash
pnpm exec supabase test db supabase/tests/recipe_effective_product_model_correction.sql
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql
pnpm exec supabase test db supabase/tests/recipe_effective_contract_01.sql
```

Expected: A–F and existing Recipe creation/selection regressions pass; copy/history tests may still fail until later tasks.

- [ ] **Step 5: Commit canonical-root and selector correction**

```bash
git add supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql \
  supabase/tests/recipe_effective_product_model_correction.sql \
  supabase/tests/rmvp_02a_connected_recipes_bom.sql \
  supabase/tests/recipe_effective_contract_01.sql
git commit -m "fix(recipes): provision canonical typed Recipe roots"
```

---

### Task 3: Correct Dish operator state so base authoring works before effective readiness

**Files:**

- Modify: `supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql`
- Modify: `supabase/tests/recipe_effective_product_model_correction.sql`
- Modify: `src/modules/atlas/recipes/recipeModel.ts`
- Test: `src/modules/atlas/recipes/recipeModel.test.ts`
- Modify: `src/modules/atlas/recipes/reviewRecipeApi.ts`

**Interfaces:**

- Consumes: canonical typed Recipe roots from Task 2.
- Produces: corrected `get_dish_recipe_operator_workbench` states `EDITABLE_BASE` and `LOCKED_CHANGE_ORDER`; TypeScript parser accepts both states without inferring lifecycle in React.

- [ ] **Step 1: Shape base-authoring state independently from strict effective selection**

For system School-Type context, resolve the exact canonical Recipe root first. Inspect its current RecipeVersion state using existing RMVP-02A lifecycle semantics. Do not call the strict effective selector before deciding whether the Dish is unlocked.

Implement the state decision as:

```text
if uiq03a_dish_used_operationally(dish_id):
    strict effective resolution required
    editable_state = LOCKED_CHANGE_ORDER
    is_editable = false
else:
    typed Recipe root required
    effective release not required
    editable_state = EDITABLE_BASE
    is_editable = existing RMVP-02A authoring eligibility
```

For `EDITABLE_BASE`, return enough shaped base-authoring information to render:

- root only / empty composition;
- current DRAFT composition;
- current VALIDATED composition;
- current RELEASED base composition when still unlocked.

Do not manufacture `current_effective_bom` for a root with no released Recipe. Use an empty effective BOM plus explicit readiness/blocker metadata, or a separate `base_composition` field, whichever is most consistent with the existing parser contract. The normal authoring path must remain unblocked.

- [ ] **Step 2: Correct allowed actions**

Backend action rules:

```text
EDITABLE_BASE:
  CREATE_CHANGE_ORDER absent
  COPY_DISH_RECIPES present only if target is otherwise copy-eligible and D-038 unlocked
  normal RMVP-02A save/edit actions remain authoritative

LOCKED_CHANGE_ORDER + effective READY:
  CREATE_CHANGE_ORDER present
  COPY_DISH_RECIPES absent
```

React may narrow these actions but never widen them.

- [ ] **Step 3: Update TypeScript model and parser**

Change:

```ts
editable_state: "LOCKED_RELEASED";
```

to:

```ts
editable_state: "EDITABLE_BASE" | "LOCKED_CHANGE_ORDER";
```

Add typed optional/base-authoring fields matching the SQL response. Update `dishRecipeOperatorWorkbenchFromResult` so root-only editable responses parse successfully while malformed lifecycle combinations fail closed.

- [ ] **Step 4: Update review adapter fixtures**

`reviewRecipeApi.ts` must expose at least:

- one `EDITABLE_BASE` root-only scenario;
- one unlocked released scenario;
- one `LOCKED_CHANGE_ORDER` scenario.

This is browser-only review data; do not reconstruct business rules there.

- [ ] **Step 5: Run focused SQL and Vitest**

```bash
pnpm exec supabase test db supabase/tests/recipe_effective_product_model_correction.sql
pnpm exec vitest run src/modules/atlas/recipes/recipeModel.test.ts src/modules/atlas/recipes/recipeApi.test.ts
pnpm typecheck
```

Expected: all unlocked/locked authoring-state tests pass.

- [ ] **Step 6: Commit operator-state correction**

```bash
git add supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql \
  supabase/tests/recipe_effective_product_model_correction.sql \
  src/modules/atlas/recipes/recipeModel.ts \
  src/modules/atlas/recipes/recipeModel.test.ts \
  src/modules/atlas/recipes/reviewRecipeApi.ts
git commit -m "fix(recipes): separate base authoring from effective readiness"
```

---

### Task 4: Rewrite Dish-level copy as an atomic system-effective snapshot

**Files:**

- Modify: `supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql`
- Modify: `supabase/tests/recipe_effective_product_model_correction.sql`
- Modify: `src/modules/atlas/recipes/recipeApi.ts`
- Test: `src/modules/atlas/recipes/recipeApi.test.ts`
- Modify: `src/modules/atlas/recipes/recipeModel.ts`
- Test: `src/modules/atlas/recipes/recipeModel.test.ts`

**Interfaces:**

- Consumes: typed-only selector and system-effective resolver.
- Produces: `atlas_api.copy_dish_recipes(jsonb)` requiring `payload.as_of_date` and materializing two independent target RecipeVersion snapshots without delegating business semantics to `copy_recipe_version`.

- [ ] **Step 1: Amend copy request builder**

Change the TypeScript request builder so the payload is exactly:

```ts
{
  source_dish_id: string;
  target_dish_id: string;
  as_of_date: string; // YYYY-MM-DD
}
```

Keep the outer expected target Dish version, reason, command ID, correlation ID and idempotency key in the command envelope.

- [ ] **Step 2: Resolve both canonical source scopes before writing**

Inside `copy_dish_recipes`, resolve canonical scopes in stable code order. For each:

```sql
v_resolution := atlas_core.recipe_effective_resolve_composition(
  v_as_of_date,
  null,
  v_source_dish_id,
  canonical.school_type_id
);
```

Require `status = READY`. Verify lineage contains no `SCHOOL`/`SCHOOL_DISH` contribution; the system resolver itself should already guarantee this.

Before any target RecipeVersion write, verify:

- both canonical source scopes resolve READY;
- both canonical target Recipe roots exist and are active;
- target Dish version matches expected_version;
- target Dish is not D-038 locked;
- neither target Recipe root has an unfinished DRAFT/VALIDATED version that conflicts with copy.

Any failure returns one outer command error and writes nothing.

- [ ] **Step 3: Materialize each effective BOM into a new target RecipeVersion**

For each target typed Recipe root:

1. Determine next version number and predecessor from existing target history.
2. Create a DRAFT RecipeVersion carrying `basis_portions` from the selected source effective Recipe.
3. For each PRESENT effective Ingredient:
   - reuse a stable target `recipe_line_id` for the same Ingredient when one exists in prior target evidence;
   - otherwise create a new `recipe_lines` row;
   - append one `recipe_line_revisions` row for the new version with effective quantity and Unit.
4. For stable target lines present in the predecessor but absent from the copied effective BOM, append a `REMOVED` successor line revision for the new version.
5. Leave the copied RecipeVersion DRAFT/editable; do not validate or release it automatically.

Do not mutate source RecipeVersions or adjustment roots/revisions.

- [ ] **Step 4: Persist copy provenance**

Set target RecipeVersion `source_evidence` to an object containing:

```json
{
  "source_kind": "RECIPE_EFFECTIVE_COPY",
  "source_dish_id": "...",
  "source_school_type_id": "...",
  "source_school_type_code": "v1-school-type-1",
  "copy_as_of_date": "2026-09-05",
  "source_recipe_id": "...",
  "source_recipe_version_id": "...",
  "contributing_system_adjustments": [
    {
      "adjustment_id": "...",
      "revision_id": "..."
    }
  ],
  "outer_command_id": "...",
  "reason_note": "..."
}
```

Deduplicate adjustment/revision pairs and include only contributing SYSTEM_INGREDIENT/SYSTEM_DISH lineage.

- [ ] **Step 5: Preserve outer idempotency and atomicity**

Do not call `copy_recipe_version` as a child business command. Keep one outer receipt scope for the Dish-level copy. Use one inner PL/pgSQL subtransaction only to guarantee both Recipe scope materializations roll back together if a later scope fails.

Exact replay must return the original shaped result. Same idempotency key with changed source/target/date must remain `IDEMPOTENCY_CONFLICT`.

- [ ] **Step 6: Run copy regressions**

```bash
pnpm exec supabase test db supabase/tests/recipe_effective_product_model_correction.sql
pnpm exec supabase test db supabase/tests/recipe_effective_contract_01.sql
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql
pnpm exec vitest run src/modules/atlas/recipes/recipeApi.test.ts src/modules/atlas/recipes/recipeModel.test.ts
```

Expected: H–P copy cases pass, including School-layer exclusion, snapshot independence, no source mutation, missing required scope rollback, D-038 lock, exact replay and changed-content conflict.

- [ ] **Step 7: Commit effective snapshot copy**

```bash
git add supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql \
  supabase/tests/recipe_effective_product_model_correction.sql \
  supabase/tests/recipe_effective_contract_01.sql \
  supabase/tests/rmvp_02a_connected_recipes_bom.sql \
  src/modules/atlas/recipes/recipeApi.ts \
  src/modules/atlas/recipes/recipeApi.test.ts \
  src/modules/atlas/recipes/recipeModel.ts \
  src/modules/atlas/recipes/recipeModel.test.ts
git commit -m "fix(recipes): copy system-effective BOM snapshots"
```

---

### Task 5: Make Recipe history and School exception counts materially applicable to the Dish

**Files:**

- Modify: `supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql`
- Modify: `supabase/tests/recipe_effective_product_model_correction.sql`
- Test: `supabase/tests/ui_quality_03b_recipe_adjustment_operator_workbench.sql`
- Modify: `src/modules/atlas/recipes/recipeModel.ts`
- Test: `src/modules/atlas/recipes/recipeModel.test.ts`

**Interfaces:**

- Consumes: resolver `lineage`, history period shape from #257, typed-only selector.
- Produces: history periods/tags limited to roots that actually contribute to the Dish; `school_exception_count` counts distinct materially applicable School-layer roots.

- [ ] **Step 1: Filter history roots by resolver lineage**

Retain candidate date boundaries for potentially applicable adjustments, but determine material membership by resolver output. For each period, collect distinct adjustment IDs from effective line lineage:

```sql
select distinct lineage_item ->> 'adjustment_id'
from jsonb_array_elements(v_resolution -> 'lines') line
cross join lateral jsonb_array_elements(coalesce(line -> 'lineage', '[]'::jsonb)) lineage_item;
```

A SYSTEM_INGREDIENT root appears in the operator history only if its adjustment ID occurs in lineage for this Dish in at least one relevant period. Do not show a tag for an unrelated global Ingredient rule.

- [ ] **Step 2: Preserve correction/cancellation audit evidence without duplicate operator BOM panels**

When an adjustment root contributed in a prior interval, retain its correction/cancellation evidence in the `change_orders` metadata associated with the appropriate history transition even if a later CANCELLED revision contributes no PRESENT line.

Coalesce adjacent periods only when their normalized effective BOM state is identical. Normalized equality must compare business BOM content and stable target origin, not JSON object ordering. Coalescing must not delete backend revision history.

- [ ] **Step 3: Compute `school_exception_count` from actual School resolver lineage**

For a system School-Type operator view:

- enumerate active Schools of that exact canonical School Type;
- resolve each School's current effective composition for the selected Dish/date;
- collect distinct `SCHOOL`/`SCHOOL_DISH` adjustment IDs from line lineage;
- count distinct roots across those Schools.

For a School operator view, evaluate only that School.

Do not count a School Ingredient adjustment merely because its School has the selected type; the adjustment must appear in the selected Dish's resolved lineage.

- [ ] **Step 4: Run history/ledger regressions**

```bash
pnpm exec supabase test db supabase/tests/recipe_effective_product_model_correction.sql
pnpm exec supabase test db supabase/tests/ui_quality_03b_recipe_adjustment_operator_workbench.sql
pnpm exec supabase test db supabase/tests/recipe_effective_contract_01.sql
pnpm exec vitest run src/modules/atlas/recipes/recipeModel.test.ts
```

Expected: unrelated global/system and School adjustments no longer pollute history or counts; relevant system and School-layer evidence remains; existing correction/cancellation and full-BOM history cases remain green.

- [ ] **Step 5: Commit material-history correction**

```bash
git add supabase/migrations/20260905170000_recipe_effective_product_model_correction.sql \
  supabase/tests/recipe_effective_product_model_correction.sql \
  supabase/tests/ui_quality_03b_recipe_adjustment_operator_workbench.sql \
  supabase/tests/recipe_effective_contract_01.sql \
  src/modules/atlas/recipes/recipeModel.ts \
  src/modules/atlas/recipes/recipeModel.test.ts
git commit -m "fix(recipes): scope effective history to material changes"
```

---

### Task 6: Reconcile API docs, review adapters, security catalog and compatibility tests

**Files:**

- Modify: `docs/api/rmvp-02a-recipes-bom.md`
- Modify: `docs/api/rmvp-02b-recipe-adjustments-effective-bom.md`
- Modify: `docs/architecture/rmvp-02b-recipe-adjustments-effective-bom.md`
- Modify: `src/modules/atlas/recipes/reviewRecipeApi.ts`
- Modify: `src/modules/atlas/recipe-adjustments/reviewRecipeAdjustmentApi.ts`
- Test: `src/modules/atlas/recipes/recipeApi.test.ts`
- Test: `src/modules/atlas/recipes/recipeModel.test.ts`
- Test: `src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts`
- Test: `scripts/atlas-staging-contract.test.mjs`
- Test: `supabase/tests/atlas_current_platform_security_catalog.sql`

**Interfaces:**

- Produces: documentation and browser adapters that match the corrected backend contract exactly; no new capability/role/RLS concept.

- [ ] **Step 1: Amend API docs with the canonical two-root invariant**

Document:

- `create_dish` provisions exactly two active typed Recipe roots and no RecipeVersion;
- RECIPE-EFFECTIVE typed-only selection never uses NULL fallback;
- root-only/DRAFT/VALIDATED/released unlocked authoring remains `EDITABLE_BASE`;
- locked effective view requires released typed Recipe;
- `copy_dish_recipes` requires `as_of_date` and snapshots system-effective BOM into both existing target roots;
- school-specific adjustments are excluded from copy;
- compatibility NULL Recipe data remains pre-cutover evidence only.

- [ ] **Step 2: Update review adapters and model fixtures**

Ensure review-mode examples include:

```text
new Dish with two typed roots and no RecipeVersions
editable Tiểu học Recipe
editable Trung học Recipe
locked effective Recipe
School-specific effective Recipe
system-effective copy preview/result
```

Review adapters must use the corrected response shape, not implement precedence themselves.

- [ ] **Step 3: Update security catalog expectations**

If the correction introduces only private helper functions and replaces existing public APIs, keep the public API count unchanged. Assert every new private/public function has fixed empty `search_path`, intended owner, revoke-first EXECUTE posture, and no anonymous/service-role browser exposure beyond existing policy.

- [ ] **Step 4: Run targeted TypeScript/contract/security checks**

```bash
pnpm exec vitest run \
  src/modules/atlas/recipes/recipeApi.test.ts \
  src/modules/atlas/recipes/recipeModel.test.ts \
  src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts \
  scripts/atlas-staging-contract.test.mjs
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql
pnpm typecheck
```

Expected: all pass.

- [ ] **Step 5: Commit contract/documentation reconciliation**

```bash
git add docs/api/rmvp-02a-recipes-bom.md \
  docs/api/rmvp-02b-recipe-adjustments-effective-bom.md \
  docs/architecture/rmvp-02b-recipe-adjustments-effective-bom.md \
  src/modules/atlas/recipes/reviewRecipeApi.ts \
  src/modules/atlas/recipe-adjustments/reviewRecipeAdjustmentApi.ts \
  src/modules/atlas/recipes/recipeApi.test.ts \
  src/modules/atlas/recipes/recipeModel.test.ts \
  src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts \
  scripts/atlas-staging-contract.test.mjs \
  supabase/tests/atlas_current_platform_security_catalog.sql
git commit -m "docs(recipes): align effective Recipe correction contracts"
```

---

### Task 7: Full targeted verification and Draft-to-Ready gate

**Files:**

- Verify only; modify files only to fix failures attributable to this correction.
- PR: #257 remains the delivery surface.

**Interfaces:**

- Consumes: Tasks 1–6.
- Produces: one reviewed branch head ready for broad GitHub Actions validation.

- [ ] **Step 1: Reset local Supabase once and run the focused SQL set**

```bash
pnpm exec supabase db reset
pnpm exec supabase test db supabase/tests/recipe_effective_product_model_correction.sql
pnpm exec supabase test db supabase/tests/recipe_effective_contract_01.sql
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql
pnpm exec supabase test db supabase/tests/rmvp_02b_recipe_adjustments_effective_bom.sql
pnpm exec supabase test db supabase/tests/ui_quality_03a_recipe_workflow.sql
pnpm exec supabase test db supabase/tests/ui_quality_03b_recipe_adjustment_operator_workbench.sql
pnpm exec supabase test db supabase/tests/issue_213_preserve_dish_activation_invariants.sql
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql
```

If an exact existing test filename differs, use the repository's actual file already registered in Full Integration; do not silently omit the corresponding suite.

Expected: zero failures in every affected Recipe/Adjustment/security suite.

- [ ] **Step 2: Run focused Vitest and typecheck**

```bash
pnpm exec vitest run \
  src/modules/atlas/connection/atlasRpc.test.ts \
  src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts \
  src/modules/atlas/recipes/recipeApi.test.ts \
  src/modules/atlas/recipes/recipeModel.test.ts \
  scripts/atlas-staging-contract.test.mjs
pnpm typecheck
```

Expected: zero failures.

- [ ] **Step 3: Run formatting and whitespace checks**

```bash
pnpm exec prettier --check \
  docs/superpowers/specs/2026-09-05-recipe-effective-product-model-correction-design.md \
  docs/superpowers/plans/2026-09-05-recipe-effective-product-model-correction.md \
  docs/api/rmvp-02a-recipes-bom.md \
  docs/api/rmvp-02b-recipe-adjustments-effective-bom.md \
  docs/architecture/rmvp-02b-recipe-adjustments-effective-bom.md \
  src/modules/atlas/recipes/recipeApi.ts \
  src/modules/atlas/recipes/recipeModel.ts \
  src/modules/atlas/recipes/reviewRecipeApi.ts \
  src/modules/atlas/recipe-adjustments/reviewRecipeAdjustmentApi.ts
git diff --check
```

Expected: all clean.

- [ ] **Step 4: Inspect the final diff against the correction spec**

Verify explicitly:

```text
A  create_dish creates exactly two canonical Recipe roots
B  exactly one Tiểu học root
C  exactly one Trung học root
D  no RECIPE-EFFECTIVE NULL fallback
E  missing Tiểu học scope blocks effective resolution
F  missing Trung học scope blocks effective resolution
G  uppercase display names work because stable codes are identity
H  Tiểu học copy uses system-effective BOM
I  Trung học copy uses system-effective BOM
J  system adjustment is materialized
K  School adjustment is excluded
L  source base Recipe/BOM is unchanged
M  copied target is independent from later source-rule changes
N  both scopes copy atomically
O  missing required source scope produces no target changes
P  locked target produces no changes
Q  root-only/DRAFT/VALIDATED/released unlocked authoring stays EDITABLE_BASE
R  locked state is LOCKED_CHANGE_ORDER
S  unrelated adjustments do not pollute history/counts
T  existing SCHOOL_DISH adjustment-line targeting remains green
```

- [ ] **Step 5: Update PR #257 body with correction evidence**

Amend the PR description to name:

- forward correction migration filename;
- exact previous and final branch SHAs;
- two-root invariant;
- typed-only selection;
- unlocked base-authoring distinction;
- system-effective copy snapshot semantics;
- school-layer exclusion;
- history/count applicability;
- local RED/GREEN evidence;
- zero hosted writes.

Do not remove prior #257 history; clearly state that the forward migration supersedes the conflicting behavior from the earlier migration.

- [ ] **Step 6: Mark PR #257 Ready only after targeted GREEN**

Once Tasks 1–5 are green and the final diff is reviewed, mark the existing Draft PR Ready. Do not merge.

Expected GitHub behavior: Frontend CI, Supabase Integration including policy-driven Full Integration, Qodana, and existing preview workflows run against the exact final head.

- [ ] **Step 7: Stop at the merge-review gate**

Report:

```text
starting correction head: 6b2a49ffb76121d77e390ac45db95c238ad6aba7
final head: <actual final SHA>
PR: #257
migration: 20260905170000_recipe_effective_product_model_correction.sql
RED evidence: <actual failures before correction>
GREEN evidence: <actual test/assertion counts>
GitHub CI: <actual states>
hosted writes: 0
merged: no
```

Do not deploy and do not merge without separate explicit authorization.

## Plan self-review

- **Spec coverage:** Tasks 2–5 cover the two-root invariant, canonical code identity, typed-only effective selection, editable base authoring, system-effective snapshot copy, School-layer exclusion, copy atomicity/provenance, operator lifecycle state, material history, and school exception counts. Task 6 covers TypeScript and documentation; Task 7 covers the Ready/CI gate.
- **Placeholder scan:** No implementation requirement is deferred. Runtime evidence fields shown as `<actual ...>` appear only in the final human report template because their values cannot exist before execution; they are not implementation placeholders.
- **Type consistency:** The plan consistently uses `EDITABLE_BASE | LOCKED_CHANGE_ORDER`, `RECIPE_EFFECTIVE.v1`, `school_type_code`, and the existing `RECIPE_LINE | ADJUSTMENT_LINE` target model. `copy_dish_recipes` consistently requires `payload.as_of_date`.
