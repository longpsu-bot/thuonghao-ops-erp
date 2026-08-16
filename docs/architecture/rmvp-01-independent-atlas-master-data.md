# RMVP-01 independent Atlas master data

## Decision and boundary

RMVP-01 establishes a fresh Atlas-owned PostgreSQL foundation for Schools, Ingredients, Suppliers, purchase units, and ingredient supplier priorities. Atlas is independent of OPS v1/v2, Retool, and any hosted legacy database. No Atlas runtime has a live legacy connection, and no legacy system is mutated.

The existing Admin master-data relations remain authoritative. The migration extends those relations rather than creating competing school, ingredient, supplier, or eligibility tables. UI-QUALITY-03C-B restores two predefined private Admin catalogs, `atlas_admin.ingredient_types` and `atlas_admin.ingredient_order_groups`, and adds their foreign-key identities to `atlas_admin.ingredients`. These are explicit business catalogs, not a generic taxonomy. Released Planning, Procurement, Evidence, and Dispatch facts keep their recorded identities and quantities; master-data changes do not silently recalculate them.

## One-way snapshot import

`pnpm local:master-data:import -- --file <explicit-json-path>` accepts one operator-selected JSON export. The script requires local Supabase, calculates a deterministic SHA-256 checksum over canonical JSON, and invokes `atlas_legacy.import_master_data_snapshot(jsonb)`.

The importer is not in `atlas_api`. Only the local `postgres` database operator can execute it. It validates duplicate source identities, typed references, supplier/rank uniqueness, priority range, the six-supplier maximum, and exact active Ingredient catalog display names after trim/case normalization before writing target data. Valid classification text resolves to the authoritative catalog IDs and canonical Vietnamese names; unknown values are explicit reconciliation blockers and never create catalog rows. A rejected batch records validation evidence and an explicit rejected-record count but performs no target writes. A completed batch stores source counts, typed mapping counts, target counts, inserted/updated/skipped/rejected operation counts, and reconciliation. The same source-system/snapshot/checksum replays the stored result with every source record counted as skipped; reusing a snapshot identifier with different content is rejected.

`atlas_legacy.master_data_mappings` uses explicit typed foreign keys for each supported object. It is migration evidence, not a polymorphic master-data model or ongoing integration framework.

## Runtime and API security

`atlas_master_data_command_runtime` is `NOLOGIN NOINHERIT`. It owns the RMVP-01 write entry functions:

- `update_school_portion_defaults`
- `update_school_portion_defaults_bulk`
- `create_ingredient`
- `update_ingredient`
- `set_ingredient_lifecycle`
- `create_supplier`
- `update_supplier`
- `replace_ingredient_supplier_priorities`

It has no Atlas schema `CREATE`, no role inheritance, and no unrelated domain relation privilege. RMVP-02A later grants this same runtime bounded `SELECT`/`INSERT`/`UPDATE` access to the two private `atlas_legacy` evidence relations for transactional reviewed Recipe import; it still cannot execute the RMVP-01 operator snapshot importer or delete legacy evidence. `atlas_read_runtime` owns shaped reads and remains table-`SELECT` only. All API functions are security definers with an empty search path, `PUBLIC` execution is revoked, and only `authenticated` can execute the reviewed entry points. Actor resolution, active capability, and global scope are checked server-side. Writes use expected versions, idempotent receipts, audit events, and domain events.

The retired `atlas_command_runtime` retains zero Atlas privilege. `anon` and `service_role` have no Atlas API execution, while API roles have no private relation access.

### Additive bulk School-default compatibility

UI-QUALITY-03C-A adds `atlas_api.update_school_portion_defaults_bulk(request jsonb)` as `RMVP-01.v2`. One request contains only changed Schools, with each row carrying its own `school_id`, `expected_version`, `default_student_portions`, and `default_teacher_portions`. PostgreSQL validates and authorizes the complete request, locks every School in stable identity order, checks every version, and then updates all rows or none. One operator Save creates one command receipt and one existing `SchoolPortionDefaultsUpdated` domain/audit record per changed School under the same command and correlation context.

The original `atlas_api.update_school_portion_defaults(request jsonb)` remains unchanged and callable as `RMVP-01.v1`. The bulk command reuses `master_data.schools.write`, `atlas_master_data_command_runtime`, the existing School relations, receipt/idempotency infrastructure, and RMVP-01 change-recording machinery. It adds no table, private relation, capability, role, scope kind, policy family, trigger, batch aggregate, or read API.

### Authoritative Ingredient classification compatibility

UI-QUALITY-03C-B keeps `atlas_api.get_ingredient_supplier_master_data`, `atlas_api.create_ingredient`, `atlas_api.update_ingredient`, and `atlas_api.set_ingredient_lifecycle` on `RMVP-01.v1`. The shaped read adds active `ingredient_types` and `ingredient_order_groups` plus each Ingredient's authoritative IDs and joined display names. Compatibility fields `ingredient_type` and `shopping_type` remain shaped as canonical catalog names.

Create/update accept authoritative UUID identities. A legacy caller may instead submit `ingredient_type` and `shopping_type`; each value must resolve to one exact catalog display name after the existing trim/case normalization. Unknown text, inactive new assignment, invalid IDs, or conflicting ID/text pairs are rejected without implicit catalog creation. Existing inactive references remain readable and may be preserved on the same Ingredient, while activation requires complete active catalog references. The correction reuses `master_data.read`, `master_data.ingredients.write`, the existing runtimes and the existing public function names; it adds no capability, role, public API, catalog-write API, trigger, Planning behavior, or browser table access.

## Authority cutover and rollback

Import does not itself cut operational authority over. The operator must review the stored reconciliation and explicitly declare Atlas authoritative before directing users away from the legacy source. Until that declaration, the legacy export is source evidence and Atlas is a candidate target.

Before authority cutover, rollback is a fresh local database reset followed by correction of the explicit snapshot. After authority cutover or after downstream Atlas facts reference imported master identities, do not delete or rewrite those identities. Correct data through versioned Atlas commands, or restore the whole Atlas database from a reviewed backup under an approved incident procedure.

The migration rollback effect is destructive to the new columns, API functions, runtime, and migration evidence. It is therefore appropriate only for a disposable pre-cutover database. Production rollback requires a forward migration and preservation of traceability.
