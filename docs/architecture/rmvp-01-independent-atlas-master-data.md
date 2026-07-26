# RMVP-01 independent Atlas master data

## Decision and boundary

RMVP-01 establishes a fresh Atlas-owned PostgreSQL foundation for Schools, Ingredients, Suppliers, purchase units, and ingredient supplier priorities. Atlas is independent of OPS v1/v2, Retool, and any hosted legacy database. No Atlas runtime has a live legacy connection, and no legacy system is mutated.

The existing Admin master-data relations remain authoritative. The migration extends those relations rather than creating competing school, ingredient, supplier, or eligibility tables. Released Planning, Procurement, Evidence, and Dispatch facts keep their recorded identities and quantities; master-data changes do not silently recalculate them.

## One-way snapshot import

`pnpm local:master-data:import -- --file <explicit-json-path>` accepts one operator-selected JSON export. The script requires local Supabase, calculates a deterministic SHA-256 checksum over canonical JSON, and invokes `atlas_legacy.import_master_data_snapshot(jsonb)`.

The importer is not in `atlas_api`. Only the local `postgres` database operator can execute it. It validates duplicate source identities, typed references, supplier/rank uniqueness, priority range, and the six-supplier maximum before writing target data. A rejected batch records validation evidence and an explicit rejected-record count but performs no target writes. A completed batch stores source counts, typed mapping counts, target counts, inserted/updated/skipped/rejected operation counts, and reconciliation. The same source-system/snapshot/checksum replays the stored result with every source record counted as skipped; reusing a snapshot identifier with different content is rejected.

`atlas_legacy.master_data_mappings` uses explicit typed foreign keys for each supported object. It is migration evidence, not a polymorphic master-data model or ongoing integration framework.

## Runtime and API security

`atlas_master_data_command_runtime` is `NOLOGIN NOINHERIT`. It owns only the seven RMVP-01 write entry functions:

- `update_school_portion_defaults`
- `create_ingredient`
- `update_ingredient`
- `set_ingredient_lifecycle`
- `create_supplier`
- `update_supplier`
- `replace_ingredient_supplier_priorities`

It has no Atlas schema `CREATE`, no role inheritance, and no unrelated domain relation privilege. RMVP-02A later grants this same runtime bounded `SELECT`/`INSERT`/`UPDATE` access to the two private `atlas_legacy` evidence relations for transactional reviewed Recipe import; it still cannot execute the RMVP-01 operator snapshot importer or delete legacy evidence. `atlas_read_runtime` owns shaped reads and remains table-`SELECT` only. All API functions are security definers with an empty search path, `PUBLIC` execution is revoked, and only `authenticated` can execute the reviewed entry points. Actor resolution, active capability, and global scope are checked server-side. Writes use expected versions, idempotent receipts, audit events, and domain events.

The retired `atlas_command_runtime` retains zero Atlas privilege. `anon` and `service_role` have no Atlas API execution, while API roles have no private relation access.

## Authority cutover and rollback

Import does not itself cut operational authority over. The operator must review the stored reconciliation and explicitly declare Atlas authoritative before directing users away from the legacy source. Until that declaration, the legacy export is source evidence and Atlas is a candidate target.

Before authority cutover, rollback is a fresh local database reset followed by correction of the explicit snapshot. After authority cutover or after downstream Atlas facts reference imported master identities, do not delete or rewrite those identities. Correct data through versioned Atlas commands, or restore the whole Atlas database from a reviewed backup under an approved incident procedure.

The migration rollback effect is destructive to the new columns, API functions, runtime, and migration evidence. It is therefore appropriate only for a disposable pre-cutover database. Production rollback requires a forward migration and preservation of traceability.
