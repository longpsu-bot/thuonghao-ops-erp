# ATLAS-MODEL-CONVERGENCE-01 — Canonical Recipe authority and domain-boundary convergence

**Date:** 6 September 2026

**Status:** Prepared bounded specification implementing the approved architecture-audit direction. No implementation, merge or deployment is certified by this document.

**Parent:** [ATLAS-MODEL-PRINCIPLE-01](../../decisions/decision-atlas-model-convergence.md).

**Baseline:** `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60` after merged PR #257.

**Delivery:** One bounded implementation branch and Draft PR; separate hosted-readiness gate.

## 1. Objective and success criterion

Eliminate competing normal Recipe interpretations by connecting the existing authoritative contracts to catalog/detail, typed base authoring, copy, Change Order targeting, temporal state and history. Record the same explicit/derived/generated distinctions through Procurement without rebuilding working Planning or Procurement behavior.

Success is not a smaller enum or fewer tables. It is that an operator receives one authoritative answer for each named business meaning, and a command uses the same context and identities that the operator reviewed.

## 2. Scope

### Included

- Repository decision, authority map, living-document precedence corrections, and regression/evidence map.
- Recipe UI consumption of `get_dish_recipe_operator_workbench`, including `base_authoring` independently of effective readiness.
- Explicit canonical School-Type selection and School-effective drill-down.
- Existing atomic `copy_dish_recipes` adoption, including both-scope readback and error handling.
- Existing effective-target context for Change Orders, including prior ADD-origin lines.
- Backend-shaped history, applicable exception counts and temporal effectiveness.
- Targeted UI/API/parser tests, real disposable-database contract verification, and preserved cross-domain journey checks.
- Read-only Staging inventory/readiness assessment; a recorded follow-up gate rather than a deployment.

### Excluded

Warehouse, Dispatch expansion, Wholesale redesign, recipe calculation or precedence changes, broad Planning/Procurement refactoring, new base Recipe scopes, automatic acceptance of proposals, new lifecycle states, new tables, new roles/capabilities, new libraries, generic workflow/registry frameworks, destructive history cleanup, compatibility API removal, business-data cutover, hosted writes, and deployment.

No database migration is planned. Do not modify reviewed migrations. A demonstrated missing backend contract must be reported with the smallest follow-up proposal; it cannot be solved by frontend reconstruction or by silently expanding this task. Independent authorized work may continue, but required blocked behavior remains unaccepted.

## 3. Existing contract authority

The final lifecycle amendment in `2026-09-05-recipe-effective-product-model-correction-design.md` supersedes the older GENERAL-fallback/base-copy statements in the original workbench design. The current RMVP-02A and RMVP-02B API documents and migration tests define actual payloads.

Reuse:

```text
RecipeApi.getEffectiveWorkbench(authSubject, correlationId, asOfDate, dishId, context)
RecipeApi.copyDishRecipes(dishRecipeCopyRequest(input))
RecipeApi.saveRecipe(recipeWorkflowCommandRequest(...))
RecipeAdjustmentApi.getEffectiveTargetContext(authSubject, correlationId, asOfDate, dishId, context)
RecipeAdjustmentApi.preview / create / supersede / cancel
```

`RecipeEffectiveContext` is exactly one of:

```ts
{
  kind: "system";
  schoolTypeId: string;
}
{
  kind: "school";
  schoolId: string;
}
```

The context is an operator selection, not a client-side Recipe-selection rule. Use existing builders and guarded parsers. Do not duplicate RPC names or introduce another nominal contract version.

## 4. Normal Recipe surface

### MC-R01 — Explicit context

Show selected Dish, explicit date, and either canonical system School Type or named School. A visible default date may use the existing Vietnam-local-date helper; send that exact selected date to the API. Never substitute browser UTC date, server CURRENT_DATE, or a hidden representative School.

Canonical type identities come from returned stable codes/IDs. No numeric School-Type literals or matching by translated names. Normal base authoring exposes only the two canonical roots, not nullable `Tất cả`/GENERAL and not a School-specific base Recipe. The new-Dish command's returned pair supplies immediate context; do not manufacture roots in React.

A locked Recipe still permits read-only switching between type, School and date contexts. A lock on editing must not disable legitimate navigation.

### MC-R02 — Catalog versus effective detail

The catalog may use the existing shaped reference catalog for Dish identity/search. It must not select released RecipeVersions locally and label their base composition as current/effective truth.

The selected Dish's effective/current section consumes `current_effective_bom`, `effective_readiness`, `school_exception_count`, and `history_periods` from `get_dish_recipe_operator_workbench`. System and School views are visibly distinct. Do not mix their data during asynchronous refresh.

Preserve useful search. A search over base composition must be explicitly labelled as such and cannot claim to filter effective composition after Change Orders. An effective-Ingredient filter must search authoritative effective rows in its stated context. Do not silently remove existing search or misrepresent a partial catalog as complete.

Do not solve catalog summaries by fetching full history/BOM for every Dish on every render. Prefer an identity catalog plus on-demand selected detail. A product requirement for whole-catalog effective-Ingredient search or current summary that existing shaped reads cannot meet must be recorded as a bounded backend-read gap; do not invent batch endpoints or hide truncation within this task.

### MC-R03 — Base authoring is independent of effective readiness

Consume `base_authoring` for composition, basis, Recipe/root/version identity, expected version and Save eligibility. Root-only, DRAFT, VALIDATED and released-but-unused contexts remain editable when the backend permits it. A blocked effective read is not automatically a blocked base editor.

For a selected unlocked system root, render the base editor and a separately named effective view when available. Never load an adjusted effective BOM into base authoring implicitly. School drill-down is an effective view; it must not accidentally allow edits to the system base under a School-specific label.

After approved Menu use, render the effective view read-only and offer the permitted Change Order action. Derive neither lock nor readiness in React. Preserve backend denial. Local dirty/invalid/busy/unknown-outcome restrictions can only make eligibility stricter.

A successful Save refreshes authoritative authoring and effective data for the same intended context. It does not call a separate activation, validate or release workflow, and does not claim a Dish lifecycle change.

### MC-R04 — No fabricated compatibility success

Missing canonical types, missing typed roots/releases, ambiguous context, auth/capability denial, unavailable API and malformed responses are distinct unavailable/blocked outcomes. Do not switch to GENERAL or the legacy resolver to make the normal view look ready. Do not create placeholder composition or an apparent zero quantity.

Keep controlled compatibility APIs and historical data intact. Where a separately labelled base-authoring surface has its own authorized read, its continued operation must not be presented as successful effective resolution or override a canonical lock/denial.

## 5. Atomic Dish-copy workflow

### MC-C01 — One meaningful command

The operator selects source Dish, target Dish and explicit as-of date, sees that both system School-Type Recipes are copied, and supplies the existing required reason. The final copy action invokes `copy_dish_recipes` once using the existing builder. It is not the old browser-only form-copy helper and not two `copy_recipe_version` calls.

The command uses the target Dish expected version. Obtain it from fresh authoritative catalog/readback; do not substitute RecipeVersion or root version. Source/target/date changes invalidate prior review and intent. An unsaved local draft must be resolved through the existing discard/return-to-edit interaction before issuing copy; never silently discard it.

The backend resolves both source system-effective scopes, excludes School layers, writes successor versions and provenance atomically, and checks target lock/concurrency. The UI neither resolves precedence nor submits copied source lines as a substitute command.

The current command resolves its authoritative source at command execution under the accepted contract. An informational preview is not a frozen source-version token. Do not invent a source fingerprint field or claim stronger preview-to-copy snapshot guarantees than the existing command provides; display authoritative output and provenance after execution.

### MC-C02 — Copy output is persisted DRAFT, not release

Consume the two returned canonical scope results and reload both target authoring contexts. A command success with failed, malformed or incomplete readback is not a completed usable UI state. Prevent further conflicting mutation until recovery succeeds. Never fabricate the second result or show partial success for an atomic failure.

Copied target versions remain DRAFT. Explain that the copied content is saved draft work and each relevant base scope must use normal Save to become effective-ready. Do not auto-call Save/release, and do not add a third root-provisioning or activation step.

Later changes to source rules cannot change the target snapshot. Source adjustment roots are not cloned into target facts. Existing target history is preserved.

### MC-C03 — Outcome and retry safety

Retain the complete submitted request for explicit recovery under the existing command contract. Unknown transport outcome never triggers an automatic resend or a fresh command ID. Refresh authoritative evidence before deciding the next action. Only documented retryable failure permits an explicit retry with the exact original request. Any changed intent discards that retry option.

A known server success with an invalid client response is still potentially committed; do not treat parser failure as proof of rollback. Block and reconcile. Unrelated catalog refresh must not clear an unresolved copy outcome.

## 6. Change Orders and history

### MC-A01 — Effective target identity

For non-ADD Dish-scoped changes, load `get_recipe_effective_target_context` for the exact selected Dish, date and system/School context. Choose among returned PRESENT lines. Display name, quantity, Unit and useful provenance, while retaining stable identity internally.

Use `RECIPE_LINE` + `target_recipe_line_id` or `ADJUSTMENT_LINE` + `adjustment_line_id`, exactly one. Never recover a target by Ingredient name, row index, newest version or local School-Type filtering. Preserve prior SYSTEM_DISH ADD and SCHOOL_DISH ADD targets through Preview, Create and Supersede.

ADD retains the existing active-Ingredient/reference contract. SYSTEM_INGREDIENT and SCHOOL Ingredient-level operations keep their existing semantics; do not force them into a Dish-line target model.

### MC-A02 — Preview matches intent

Changing Dish, School Type, School, date, action, target, quantity, Unit or reason invalidates the reviewed proposal as required by the existing workflow. A late response from a prior context cannot enable Save or replace the current selection. Backend preview and command validation remain authoritative.

A system-effective context must not use a first/representative School as a proxy. Verify the existing Preview/Create envelopes can express the approved system semantics. A missing system-preview/command context is a genuine contract gap: preserve safety, document it, and do not submit a School-contaminated preview as system-only proof.

### MC-A03 — History and applicability

Render backend `history_periods` as complete effective-BOM periods. Keep half-open dates unambiguous; an exclusive end date must not be presented as inclusive. Do not replay raw revisions, calculate exception counts, or infer `is_effective_now` from lifecycle/date fields.

Display materially contributing history and backend exception counts. Preserve simultaneous boundaries, finite periods, corrected/cancelled history and prior ADD lineage. A backend-coalesced panel must not hide access to immutable change evidence.

Legacy unattributed issuance remains visibly unattributed. Do not invent an issuer or use import time as original business issuance. Accommodate the actual nullable values permitted by backend evidence instead of either fabricating values or rejecting legitimate history.

## 7. Shared UI safety and quality

### Approved reference-date UX amendment — 6 September 2026

The normal Lệnh điều chỉnh ledger uses the current Vietnam-local business date automatically, sending an explicit ISO `as_of_date` to the existing RPC. Remove the routine `Ngày tham chiếu` input and explanatory reference-date copy. Render backend temporal state and effectivity; do not calculate that state from lifecycle or dates in React.

Keep actual business dates, including effective start/end, issuance, correction/cancellation dates and historical boundaries. The separate read-only effective-inspection surface may offer `Xem tại ngày`; it does not change the normal ledger's current-date operation. R04's read-only type/date navigation refers to explicit inspection, not a mandatory date control on the normal Change Order workspace. Dish copy remains an explicitly dated snapshot business command. This clarification changes neither migrations nor RPC contracts.

Use the existing design system and operator conventions; no global restyling. Preserve fast search, compact readable tables, natural Vietnamese labels, explicit work context, progressive disclosure and one dominant business action appropriate to the current state.

Use fresh authoritative action data. Unknown, loading, stale or conflicting responses cannot enable writes. Key asynchronous requests by auth/context/intent and reject superseded results. Keep dirty drafts through failed refreshes and require an explicit discard decision on context changes.

Keep secrets out of browser code and test artifacts. Do not change capability bindings to make tests pass. Test separate read/write permissions; a new effective API denial must remain a denial. Maintain existing quantity contracts: no new lossy conversions, no arbitrary rounding, no global number-to-string migration. Procurement's exact decimal string handling remains untouched.

Review-mode fixtures are not business authorities. Tests must include cases where base composition and effective output deliberately differ, so accidental frontend recomputation fails visibly.

## 8. Documentation convergence

Update living documents to state which facts are explicit, which results derived, and which supporting records generated. Correct stale current-context references, the Attendance default-setup story, the legacy demand-flag description and earlier Recipe GENERAL/base-copy interpretations.

Do not rewrite old approval history or claim future merge SHAs. Refer to this task's verified baseline as a baseline, not as a self-updating `main`. Link superseding documents. Use the existing decision-register convention without renumbering prior decisions.

## 9. Verification and change limits

Acceptance IDs and fixture obligations are in [the matrix](../../testing/atlas-model-convergence-acceptance.md). The implementation plan assigns concrete file ownership and commands. Tests must exercise normal connected components as well as adapters; mock-only API tests cannot prove adoption.

GitHub Actions owns comprehensive frontend and disposable-Supabase verification. Keep existing ordered fixture/reset dependencies. Do not start/reset local Supabase merely to duplicate full CI. A narrowly necessary local disposable-database check needs explicit task-local authorization; the default is CI.

One final exact-head disposable Full Integration run is appropriate for this cross-flow convergence. Existing `workflow_dispatch` supports running the integration workflow on the task branch while leaving the PR Draft. Inspect its current side effects first, do not dispatch hosted deployment workflows, and verify reported `head_sha` equals the reviewed commit. If unavailable, leave the gate blocked rather than declaring success or changing CI policy.

## 10. Definition of done

All required Recipe behavior is connected and tested; catalog/base/effective meanings are explicit; typed-only normal contexts and stable ADD targets work; copy is atomic and reconciles both DRAFT outputs; history/permissions/unknown outcomes are preserved; living docs align; exact-head CI and independent review are recorded; Staging readiness is separately classified.

P0/P1 acceptance failures and required contract gaps block completion. Deferred P2 cleanup does not block this delivery. Merge and deployment remain outside this authorization.
