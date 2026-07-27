# RMVP-02A connected Dishes, Recipes, and BOM

## Decision and boundary

RMVP-02A connects the Vietnamese `Công thức` workspace to the existing private Atlas recipe foundation. It reuses `atlas_admin.dishes`, `recipes`, `recipe_versions`, `recipe_lines`, and `recipe_line_revisions`; it creates no new business relation, role, module, or operating stage.

The supported recipe root scopes are:

- one general Recipe per Dish;
- one Recipe per active School Type and Dish.

Customer-, School-, date-, and menu-specific applicability remain future decisions. Requirement Planning still owns applicability precedence and recipe use. RMVP-02A only governs reusable upstream recipe master data.

## Lifecycle and lineage

A Dish is created as `DRAFT` and can move through `ACTIVE` and `INACTIVE`; it is never deleted by this slice. The RMVP-03A correction extends the same existing Dish commands with authoritative `dish_type_id`. New Dishes and later type changes require an active `atlas_admin.dish_types` row. `dish_category` remains transitional descriptive text and does not drive Menu behavior. Historical Dishes may remain unmapped until reviewed. A Recipe root can be `ACTIVE` or `INACTIVE`.

A Recipe Version follows:

```text
DRAFT → VALIDATED → RELEASED_FOR_PLANNING → LOCKED
```

Only a `DRAFT` composition can be replaced. The replacement is one transactional command over the full BOM, including the positive basis quantity and a concise reason. Draft composition is bounded JSON on the existing Recipe Version because a draft is editable proposal state, not yet an authoritative BOM fact.

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

Every write uses the `RMVP-02A.v1` envelope, server-resolved actor identity, global scope, optimistic version checks, idempotent command receipts, one Admin domain event, one audit event, and authoritative workbench readback. `anon` and `service_role` execute no Atlas API.

## OPS v1 workbook import

The browser accepts only `.xlsx` workbooks and recognizes the narrow OPS v1 Vietnamese headers:

- recipe sheet: `Tên món`, `Loại công thức`, `Tên công thức`;
- BOM sheet: `Tên món`, `Loại công thức`, `Tên nguyên liệu`, `Định lượng/100 suất`, `Đơn vị mua (tham khảo)`.

The review step normalizes decimal commas, resolves only existing active School Types, Ingredients, and Units, reports row-level errors, sorts canonical rows, and calculates SHA-256. It does not auto-create reference data.

The apply command revalidates canonical JSON and checksum, rejects missing or ambiguous references before target writes, creates only Dish/Recipe/Recipe Version draft state, and records source counts, target counts, inserted/updated/skipped/rejected counts, reconciliation, and typed `atlas_legacy.master_data_mappings`. Recipe Line Revision mapping is added only when a later explicit validation materializes that immutable fact. An identical checksum replays without duplicate target writes.

Retool export `D:\Project\OPS v2\OPS - Công thức.json` was inspected as read-only legacy evidence. Its SHA-256 was `E50AB600E98C1AC683BD449C8B2C859846C0BF5E5AE2A5A807BBE827B03852E9`. Atlas does not execute or depend on that export.

## UI boundary

The connected React page supports:

- Dish catalog creation, editing, and lifecycle changes;
- general and School Type Recipe roots;
- initial and successor drafts;
- complete BOM editing with explicit removal;
- validation and planning release;
- traceable copy preview of the complete source BOM and apply;
- workbook review, checksum, errors, counts, and apply.

The normal build requires an authenticated Supabase session and the typed reviewed RPC registry. Review mode uses deterministic browser-only sample data and displays the existing non-persistence notice. It never represents review actions as persisted.

## Rollback and production boundary

This task performs no hosted Supabase, production data, OPS v1/v2, or Retool mutation.

On a disposable pre-cutover database, rollback is a local reset to the prior migration set. Once Recipe Versions or Planning evidence are referenced, rollback must be a forward migration that preserves all stable identities, immutable revisions, mappings, events, and audit facts. Dropping the new columns or functions is not a production-safe rollback.
