# D-038 — Recipe Creation and Operational-Use Lock Boundary

**Status:** Accepted
**Date:** 2026-08-11
**Owning domain:** Admin / Master Data
**Contract:** `RMVP-02A.v2`

## Decision

Recipe work has three separate operator jobs:

1. `Danh sách` is a read-only current-effective Dish/Recipe catalog.
2. `Tạo món & công thức` creates a Dish and its initial general or School-Type Recipe. `Tạo`/`Lưu` makes valid composition available to Planning; there is no separate normal `Đưa vào sử dụng` action.
3. `Điều chỉnh` owns every business modification after first operational use. Its existing RMVP-02B semantics are unchanged and its UI redesign is deferred to UI-QUALITY-03B.

A Dish becomes operationally used when it first appears in immutable approved Weekly Menu evidence: `atlas_planning.weekly_menu_approval_snapshot_lines`. From that point, normal Recipe Save for every scope of that Dish is denied. The backend must not create a successor as a substitute for Change Order.

This is the Atlas representation of retained OPS v1 evidence: `daily_order_dishes` has an `AFTER INSERT` trigger that sets `recipes.is_locked = true` for every Recipe of the referenced Dish, and the BOM guard rejects base-BOM insert/update/delete when the Recipe is locked. Retool `BoMCreation` presents creation and copy; `SystemChangeOrder` presents replace, quantity change, add, and remove; `overrideDish` and `overrideSchoolWise` present scoped override jobs.

## Mutability

Before first operational use:

- Dish stable code remains immutable after creation under RMVP-02A.v1; the 03A application does not expose normal Dish metadata maintenance in the catalog.
- Dish descriptive metadata is captured during creation. Existing v1 support APIs remain physically callable; 03A does not broaden them.
- Recipe scope identity is fixed by Dish plus nullable School Type.
- Recipe basis and base composition may be saved again. PostgreSQL may use internal version lineage to preserve released evidence while the Dish is still unused.
- `Tạo`/`Lưu` validates, materializes immutable line revisions, and leaves the Recipe `RELEASED_FOR_PLANNING` (human status `Sẵn sàng sử dụng`).

After first operational use:

- Dish stable identity, the Recipe scope identity, and base Recipe composition are not normally editable.
- `save_recipe` fails before creating a Recipe/version/line write and returns: `Món/công thức này đã được sử dụng. Hãy tạo Phiếu điều chỉnh để thay đổi.`
- Descriptive changes or composition changes that represent a business correction must follow an approved Change Order/override path; 03A does not redesign that contract.
- Historical Recipe, approved Menu, Planning selection, and line-use evidence remains immutable.

## Contract consequences

- Keep additive `atlas_api.save_recipe(jsonb)` and `atlas_api.release_recipe(jsonb)` plus all RMVP-02A.v1 entry points physically callable.
- `save_recipe` is the only normal creation-workbench commitment. It checks operational use under the locked Dish row, validates full composition, preserves idempotency/concurrency/lineage, and makes the Recipe Planning-eligible atomically.
- `release_recipe` remains a compatibility/support entry point. React does not invoke it in the normal workflow.
- The v2 read returns `business_status`, `locked_for_normal_editing`, `lock_reason`, and backend-authoritative Save eligibility.
- Lock evidence is Dish-wide, matching the v1 trigger. It is not Recipe creation, validation, release, or first Save.
- No Recipe Adjustment relation/command, Planning calculation, Confirmed Need, Procurement, Warehouse, or Dispatch behavior changes.

## Application consequences

The catalog exposes current-effective Dish name/code/type, Recipe scope/basis/Ingredients/status, text search, `Xem`, and clear navigation to creation or Change Order. It contains no edit, validation, release, successor, or lifecycle controls.

Creation exposes selected Dish/scope, basis, Ingredient search, composition, and one `Tạo`/`Lưu` action. Recipe Copy is a local creation helper: it fills the current unsaved form and performs no backend write until the operator checks and saves. Dirty context/navigation changes require confirmation; page unload uses the native browser guard.

Technical version history remains support disclosure only. Unknown write outcomes require an authoritative refresh and are never automatically retried.

## Safety and rollback

The helper reads only approved-Menu snapshot `dish_id` and runs under the existing fixed-path runtime boundary. Save takes the Dish lock before rechecking operational use, preventing a normal edit after approved evidence exists. No browser role receives private-schema table access.

Disposable local databases may reset before operational use. Any deployed rollback is forward-only and must preserve Recipe identities, revisions, approved Menu snapshots, Planning evidence, receipts, events, and audit records. Reopening a used base Recipe or rewriting history is prohibited.
