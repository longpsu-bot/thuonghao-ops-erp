# D-038 — Recipe Creation and Approved-Menu Commitment Lock Boundary

**Status:** Accepted
**Date:** 2026-08-11
**Owning domain:** Admin / Master Data
**Contract:** `RMVP-02A.v2`

**Partial supersession, 6 September 2026:** the [Recipe product-model amendment](../superpowers/specs/2026-09-05-recipe-effective-product-model-correction-design.md) and [model-convergence decision](decision-atlas-model-convergence.md) supersede this decision's original GENERAL/nullable normal-authoring, current-effective catalogue and browser-local copy descriptions. Normal creation now returns an ACTIVE Dish with two typed roots and zero versions; base-labelled catalogue search opens authoritative selected effective detail, and one `copy_dish_recipes` command persists two system-effective DRAFT snapshots. The original approval date, committed-Menu lock, normal Save and immutable-history decisions remain unchanged. The historical descriptions below are retained as the 11 August decision record, not current instructions for these superseded routes.

## Decision

Recipe work has three separate operator jobs:

1. `Danh sách` is a read-only current-effective Dish/Recipe catalog.
2. `Tạo món & công thức` creates a Dish and its initial general or School-Type Recipe. `Tạo`/`Lưu` makes valid composition available to Planning; there is no separate normal `Đưa vào sử dụng` action.
3. `Điều chỉnh` owns Recipe composition modification after first committed approved-Menu use. Its existing RMVP-02B semantics are unchanged and its UI redesign is deferred to UI-QUALITY-03B.

A Dish crosses the normal-edit boundary when it first appears in immutable approved Weekly Menu evidence: `atlas_planning.weekly_menu_approval_snapshot_lines`. From that committed approved-Menu use, normal Recipe Save for every scope of that Dish is denied. The backend must not create a successor as a substitute for Change Order.

This is the Atlas representation of retained OPS v1 evidence: `daily_order_dishes` has an `AFTER INSERT` trigger that sets `recipes.is_locked = true` for every Recipe of the referenced Dish, and the BOM guard rejects base-BOM insert/update/delete when the Recipe is locked. Retool `BoMCreation` presents creation and copy; `SystemChangeOrder` presents replace, quantity change, add, and remove; `overrideDish` and `overrideSchoolWise` present scoped override jobs.

## Mutability

Before first committed approved-Menu use:

- Dish stable code remains immutable after creation under RMVP-02A.v1; the 03A application does not expose normal Dish metadata maintenance in the catalog.
- Dish descriptive metadata is captured during creation. Existing v1 support APIs remain physically callable; 03A does not broaden them.
- Recipe scope identity is fixed by Dish plus nullable School Type.
- Recipe basis and base composition may be saved again. PostgreSQL may use internal version lineage to preserve released evidence while no approved Weekly Menu snapshot contains the Dish.
- `Tạo`/`Lưu` validates, materializes immutable line revisions, and leaves the Recipe `RELEASED_FOR_PLANNING` (human status `Sẵn sàng cho Lập nhu cầu`).

After first committed approved-Menu use:

- Normal base Recipe/BOM composition mutation is prohibited. The protected commands fail before a new Recipe root, Recipe Version, Recipe Line, Recipe Line Revision, import/mapping, or release write. The safe direction is: `Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.`
- Recipe composition changes proceed through the accepted RMVP-02B `Điều chỉnh` contract.
- Dish details and Dish/Recipe-root lifecycle administration remain governed by their own accepted RMVP-02A contracts, including optimistic version, capability, lifecycle, event, and audit rules. Approved-Menu use alone does not prohibit those commands.
- UI-QUALITY-03A does not expose ordinary editing of existing catalog records, and it introduces no Dish metadata correction workflow or Dish Change Order.
- Historical Recipe, approved Menu, Planning selection, and line-use evidence remains immutable.

## Contract consequences

- Keep additive `atlas_api.save_recipe(jsonb)` and `atlas_api.release_recipe(jsonb)` plus all RMVP-02A.v1 entry points physically callable.
- `save_recipe` is the only normal creation-workbench commitment. It checks committed approved-Menu use under the serialized Dish boundary, validates full composition, preserves idempotency/concurrency/lineage, and makes the Recipe Planning-eligible atomically.
- `release_recipe` remains a compatibility/support entry point. React does not invoke it in the normal workflow.
- The v2 read returns `business_status`, `locked_for_normal_editing`, `lock_reason`, and backend-authoritative Save eligibility.
- Lock evidence is Dish-wide, matching the v1 trigger. It is not Recipe creation, validation, release, or first Save.
- No Recipe Adjustment relation/command, Planning calculation, Confirmed Need, Procurement, Warehouse, or Dispatch behavior changes.

## Application consequences

The following two paragraphs record the original 11 August UI consequence and are superseded for catalogue/effective selection and copy by the amendment above. Current implementation guidance is the [updated RMVP-02A architecture boundary](../architecture/rmvp-02a-connected-recipes-bom.md#ui-boundary).

The catalog exposes current-effective Dish name/type, Recipe scope/basis/Ingredients/status, text search, `Xem`, and clear navigation to creation or Change Order. Stable Dish codes remain backend identity and search/support evidence; the normal catalog does not present them as operator-facing metadata. It contains no edit, validation, release, successor, or lifecycle controls.

Creation exposes selected Dish/scope, basis, Ingredient search, composition, and one `Tạo`/`Lưu` action. Recipe Copy is a modal local creation helper: search/select source, preview composition, and `Dùng công thức này` fill the current unsaved form and close the modal. It performs no backend write until the operator checks and saves. Dirty context/navigation changes require confirmation; page unload uses the native browser guard.

Technical version history remains support disclosure only. Unknown write outcomes require an authoritative refresh and are never automatically retried.

## Safety and rollback

The helper reads only approved-Menu snapshot `dish_id` and runs under the existing fixed-path runtime boundary. Weekly Menu approval and every relevant base Recipe/BOM mutation take the same deterministic transaction lock before committing or rechecking committed approved-Menu use. No browser role receives private-schema table access.

Disposable local databases may reset before approved-Menu commitment. Any deployed rollback is forward-only and must preserve Recipe identities, revisions, approved Menu snapshots, Planning evidence, receipts, events, and audit records. Reopening a committed base Recipe or rewriting history is prohibited.
