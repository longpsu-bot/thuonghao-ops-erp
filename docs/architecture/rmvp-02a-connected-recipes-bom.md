# RMVP-02A connected Dishes, Recipes, and BOM

## Decision and boundary

RMVP-02A connects the Vietnamese `Công thức` workspace to the existing private Atlas recipe foundation. It reuses `atlas_admin.dishes`, `recipes`, `recipe_versions`, `recipe_lines`, and `recipe_line_revisions`; it creates no new business relation, role, module, or operating stage.

The retained foundation supports these historical root shapes:

- one general Recipe per Dish;
- one Recipe per active School Type and Dish.

Normal authoring now uses exactly the two canonical School-Type roots returned by Atlas, with no GENERAL fallback. Existing RMVP-02B and Recipe-effective contracts govern dated system and School composition; Requirement Planning consumes their authoritative result. The [6 September product-model amendment](../superpowers/specs/2026-09-05-recipe-effective-product-model-correction-design.md) and [model-convergence decision](../decisions/decision-atlas-model-convergence.md) supersede the earlier normal GENERAL, activation and browser-copy routing. Historical roots and compatibility APIs remain evidence, not normal UI choices.

## Lifecycle and lineage

Current `create_dish` returns an `ACTIVE` Dish and its two canonical typed roots, with no Recipe Versions. No separate activation or root-provisioning UI is required. The existing lifecycle catalog and historical Dish states remain intact. The RMVP-03A correction extends the same existing Dish commands with authoritative `dish_type_id`. New Dishes and later type changes require an active `atlas_admin.dish_types` row. `dish_category` remains transitional descriptive text and does not drive Menu behavior. Historical Dishes may remain unmapped until reviewed. A Recipe root can be `ACTIVE` or `INACTIVE`.

A Recipe Version follows:

```text
DRAFT → VALIDATED → RELEASED_FOR_PLANNING → LOCKED
```

The retained v1 composition-replacement command accepts only a `DRAFT`. Its replacement is one transactional command over the full BOM, including the positive basis quantity and a concise reason. Draft composition is bounded JSON on the existing Recipe Version because a draft is editable proposal state, not yet an authoritative BOM fact. Normal `save_recipe` uses the additive boundary below and follows returned `base_authoring` permissions independently of effective readiness.

Validation materializes stable Recipe Lines and immutable Recipe Line Revisions exactly once. Release makes that validated version available to Requirement Planning. Releasing a successor locks the prior planning release. Corrections create a successor draft with an exact Recipe Version predecessor and exact Recipe Line Revision predecessors. A removed ingredient remains an explicit `REMOVED` revision with zero quantity; it is never represented by silent omission.

Released or locked facts are not recalculated or rewritten when a Dish, Ingredient, Unit, or later Recipe Version changes.

## Commands, reads, and security

The migration adds one shaped read and eleven commands under `atlas_api`. `atlas_read_runtime` owns the read. The existing `atlas_master_data_command_runtime` owns the commands and receives only the relation, column, function, and RLS privileges required by these operations. RMVP-03A replaces the existing Dish functions in place—without duplicate APIs—to return the full Dish Type catalog and resolved Dish Type identifiers, codes, and names, and to validate `dish_type_id`. No browser role receives private-schema usage or table access.

Five backend-checked capabilities separate read, maintenance, validation, planning release, and reviewed import:

- `master_data.recipes.read`
- `master_data.recipes.write`
- `master_data.recipes.validate`
- `master_data.recipes.release`
- `master_data.recipes.import`

Retained v1 writes use the `RMVP-02A.v1` envelope; normal Save uses `RMVP-02A.v2`, and atomic Dish copy uses `RECIPE-EFFECTIVE.v1`. Existing server-resolved actor identity, scope, optimistic version checks, idempotent receipts, events, audit and authoritative readback remain enforced. `anon` and `service_role` execute no Atlas API.

### D-038 additive creation-and-lock boundary

`RMVP-02A.v2` adds two physically callable public commands without adding a relation, role, capability, scope kind, lifecycle state, module, or dependency:

- `save_recipe` is the normal human `Tạo`/`Lưu` boundary. Under the serialized Dish boundary, it first denies a Dish already present in `weekly_menu_approval_snapshot_lines`. For a pre-commit Dish it validates the complete composition, creates or advances internal Recipe lineage as required, materializes immutable line revisions, and leaves the new version `RELEASED_FOR_PLANNING` in one transaction.
- `release_recipe` remains an additive compatibility/support boundary. It is not rendered as a normal creation action, and React does not call it.

Release means eligible for future Planning; it is not first committed approved-Menu use. Atlas committed-use evidence is an immutable approved Weekly Menu snapshot line containing the Dish. The read accepts optional `dish_id` and `school_type_id` and returns `selected_recipe` with `business_status`, `locked_for_normal_editing`, `lock_reason`, and backend-authoritative action eligibility.

Before the first committed approved-Menu use, Save may preserve immutable prior release evidence through internal successor lineage. After that commitment, Save returns before any Recipe/version/line write, cannot create a successor, and directs the operator to Change Order. Existing Planning selections and historical facts are never recalculated.

Capability granularity is unchanged. Save requires `master_data.recipes.write`; `master_data.recipes.validate` and `master_data.recipes.release` remain available through v1 and controlled support entry points.

## OPS v1 workbook import

The browser accepts only `.xlsx` workbooks and recognizes the narrow OPS v1 Vietnamese headers:

- recipe sheet: `Tên món`, `Loại công thức`, `Tên công thức`;
- BOM sheet: `Tên món`, `Loại công thức`, `Tên nguyên liệu`, `Định lượng/100 suất`, `Đơn vị mua (tham khảo)`.

The review step normalizes decimal commas, resolves only existing active School Types, Ingredients, and Units, reports row-level errors, sorts canonical rows, and calculates SHA-256. It does not auto-create reference data.

The apply command revalidates canonical JSON and checksum, rejects missing or ambiguous references before target writes, creates only Dish/Recipe/Recipe Version draft state, and records source counts, target counts, inserted/updated/skipped/rejected counts, reconciliation, and typed `atlas_legacy.master_data_mappings`. Recipe Line Revision mapping is added only when a later explicit validation materializes that immutable fact. An identical checksum replays without duplicate target writes.

Retool export `D:\Project\OPS v2\OPS - Công thức.json` was inspected as read-only legacy evidence. Its SHA-256 was `E50AB600E98C1AC683BD449C8B2C859846C0BF5E5AE2A5A807BBE827B03852E9`. Atlas does not execute or depend on that export.

## UI boundary

The connected React page separates three operator jobs:

- `Danh sách`: read-only identity and explicitly base-labelled composition search. `Xem` lazily loads the selected date/system-or-School result through `get_dish_recipe_operator_workbench`, including effective BOM, readiness, lock, exceptions, history and actions. The catalog does not claim base composition is effective. Stable Dish codes remain backend identity and search/support evidence; the normal catalog does not render them as operator-facing metadata. It has no edit, validation, release, successor, or lifecycle control.
- `Tạo món & công thức`: selected Dish/type/scope, editable basis and composition, active-Ingredient search, and one `Tạo`/`Lưu` action. Save makes the Recipe `Sẵn sàng cho Lập nhu cầu`; there is no normal release/lifecycle action.
- `Điều chỉnh`: the RMVP-02B workbench for changes after committed approved-Menu use. Non-ADD Dish targets come from `get_recipe_effective_target_context` and retain exact base-line or prior-ADD identity. System-Dish target reads work, while unsupported system-only Preview/Create/Supersede remains blocked as A07; no representative School is substituted.

Recipe Copy sends one `copy_dish_recipes` command with source Dish, target Dish, explicit date, fresh target Dish version and reason. It snapshots both system-effective typed scopes into two persisted DRAFTs, verifies both returned identities and reloads both target authoring contexts. It does not auto-Save or release. This supersedes the browser-local `Dùng công thức này` helper. Workbook import remains an advanced creation utility with its existing reviewed contract.

Every still-callable v1/v2 Recipe-Version, composition, copy, and import mutation that can change base Recipe/BOM truth reuses `atlas_core.uiq03a_dish_used_operationally(uuid)`. Weekly Menu approval and these mutations acquire the same deterministic transaction lock, so the first committed approved snapshot wins and later base composition mutation is denied before business writes. Dish details and Dish/Recipe-root lifecycle commands retain their accepted RMVP-02A administration semantics and do not become Change Orders merely because approved-Menu evidence exists. RMVP-02B adjustment commands are unchanged.

When backend readback reports `locked_for_normal_editing`, basis, Ingredient search, composition controls, and Save are disabled, and the operator is directed to `Điều chỉnh`. Dish/scope/tab changes with dirty creation state require explicit discard confirmation; browser unload uses the native guard.

Normal operator language avoids Recipe Version machinery. Technical number/identifier evidence remains under Recipe history/support disclosure. Unknown or successful-but-unreadable writes remain blocked until exact retained-command evidence is reconciled; an unrelated refresh is insufficient. React invokes only `save_recipe` for normal base commitment and chains no v1 lifecycle calls.

Review mode uses deterministic browser-only data and retains its non-persistence notice.

## Rollback and production boundary

This task performs no hosted Supabase, production data, OPS v1/v2, or Retool mutation.

On a disposable pre-cutover database, rollback is a local reset to the prior migration set. Once Recipe Versions or Planning evidence are referenced, rollback must be a forward migration that preserves all stable identities, immutable revisions, mappings, events, and audit facts. Dropping the new columns or functions is not a production-safe rollback.
