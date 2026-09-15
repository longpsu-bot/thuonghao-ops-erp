# MASTER-DATA-REHEARSAL-IMPORT-01 — Repeatable OPS v1 Master-Data Rehearsal and Cutover Import

**Status:** Design ready for Product Owner review  
**Date:** 15/09/2026  
**Architecture authority:** OPS_SYSTEM_MAP v1.0 / ARCH-002  
**Parent contracts:** RMVP-01, RMVP-02A, D-037 Atlas Model Convergence  
**Principle:** **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

## 1. Decision

Atlas will not wait for OPS v1 master data to become perfectly stable before testing migration.

Instead, Atlas will use a **repeatable, immutable snapshot import**:

```text
OPS v1 current master snapshot
  -> normalize and fingerprint
  -> preview deterministic import plan
  -> apply to a disposable rehearsal target
  -> cascade only master/reference relationships
  -> reconcile
  -> staff continue correcting OPS v1
  -> take a fresh full snapshot
  -> run the same importer again
  -> preserve Atlas identities
  -> reconcile to zero unexplained differences
  -> declare master-data cutover
```

The first import is **Migration Rehearsal A**, not authority cutover.

No OPS v1 operational history is migrated. Weekly Menu, Attendance, Pantry, Confirmed Need, Purchase Orders, PXK, Dispatch, Reconciliation, and other operational aggregates begin in Atlas from go-live onward.

## 2. Why this extends the existing model instead of creating a new ETL subsystem

Three approaches were considered.

### A. Extend the existing `atlas_legacy` snapshot importer — chosen

RMVP-01 already provides:

- immutable explicit JSON snapshots;
- deterministic SHA-256 checksums;
- `atlas_legacy.import_batches`;
- typed `atlas_legacy.master_data_mappings`;
- one-way migration only;
- no runtime/live connection to OPS v1;
- validation-before-write and reconciliation evidence.

RMVP-02A already extends typed migration evidence through Dish, Recipe, Recipe Version, Recipe Line, and Recipe Line Revision identities.

The rehearsal importer should evolve this existing mechanism into a **repeatable pre-cutover importer**, not introduce a second integration model.

### B. Generic staging/ETL schema — rejected

A generic `source_table/source_key/target_table/target_key` ETL layer would weaken typed business ownership, duplicate the current mapping evidence, and become an ongoing integration framework Atlas does not need.

### C. Live DB-to-DB synchronization — rejected

FDW, database links, direct cross-project reads, scheduled live sync, or React/Retool-driven copy would recreate the OPS v1 coupling Atlas is intended to remove.

## 3. Evidence baseline

### 3.1 OPS v1 current read-only source

The current live OPS v1 master footprint observed during this design is:

| Source object | Rows |
| --- | ---: |
| Schools | 43 |
| Ingredient Types | 17 |
| Ingredient Shopping Types | 3 |
| Ingredients | 376 |
| Suppliers | 36 |
| Ingredient–Supplier relationships | 846 |
| Dish Types | 6 |
| Dishes | 660 |
| Recipes | 1,320 |
| Bill of Materials lines | 4,045 |

Current Recipe shape is unusually clean and useful for migration: all 1,320 Recipe rows are active, none is School-specific, every row has `school_type_id`, and there are exactly 1,320 distinct `(dish_id, school_type_id)` pairs. The legacy `is_general` flag is true on all rows, but the explicit School Type identity is the fact Atlas should preserve.

BOM validation found 4,045 positive lines with no missing Ingredient or purchase Unit and no duplicate `(recipe_id, ingredient_id)` pair. One of the 1,320 Recipes currently has no BOM line; that must appear as a reconciliation blocker rather than being silently ignored.

### 3.2 Atlas Staging current target

Current Staging is intentionally partial:

| Atlas object | Rows |
| --- | ---: |
| Customers | 34 |
| Delivery Locations | 34 |
| School Types | 3 |
| Schools | 34 |
| Units | 16 |
| Ingredient Types | 17 |
| Ingredient Order Groups | 3 |
| Ingredients | 360 |
| Suppliers | 37 |
| Supplier Eligibilities | 828 |
| Dish Types | 6 |
| Dishes | 2 |
| Recipes | 3 |
| Recipe Versions | 5 |
| Recipe Lines | 4 |
| Recipe Line Revisions | 6 |

This confirms that a rehearsal is valuable now: the School/Ingredient/Supplier side is close enough to exercise identity continuity, while Dish/Recipe/BOM migration still needs the full model.

## 4. Source authority

The migration source is the **OPS v1 PostgreSQL master relations**, read-only.

Retool is workflow evidence, not the extraction authority. The retained apps confirm how staff use the fields:

- `schools.school_full_name`, `delivery_info`, `contract_type`, and `display_order` are operationally consumed by Dispatch/export;
- `default_students_num` and `default_teacher_num` are maintained as School defaults;
- Ingredient/Supplier management is based on `ingredients`, `suppliers`, and `ingredient_suppliers`;
- Recipe tooling is based on `dishes`, `recipes`, and `bill_of_materials`.

No Retool query will be executed as a migration write path.

## 5. Scope

### 5.1 In scope

The snapshot/import contract covers current master/reference facts required for Atlas operations:

1. School Types.
2. Customer + Delivery Location facts derived from each OPS v1 School.
3. Schools and School defaults.
4. Units referenced by Ingredient or BOM purchase-unit text.
5. Ingredient Types.
6. Ingredient Order Groups / OPS v1 Ingredient Shopping Types.
7. Ingredients.
8. Suppliers.
9. Ingredient–Supplier eligibility and priority relationships.
10. Dish Types.
11. Dishes.
12. Canonical typed Recipe roots.
13. Current Recipe composition/BOM as Atlas Recipe Version + line facts.
14. School Dispatch document issuer facts derived from the already accepted `contract_type` mapping.

### 5.2 Explicitly out of scope

The importer must not migrate or synthesize:

- Weekly Menu history;
- Attendance history;
- Pantry operational rows;
- Planning readiness/history;
- Need Generation runs;
- Confirmed Need batches;
- supplier allocations;
- PO/PXK/Dispatch history;
- reconciliation history;
- OPS v1 audit/history tables;
- historical Recipe edit chronology that OPS v1 never represented as Atlas versions.

The importer may create truthful **Atlas migration evidence**, but it must not fabricate historical Atlas commands/events for actions that occurred before Atlas.

## 6. Snapshot contract

A full source extraction produces one immutable JSON document with a new contract version:

```json
{
  "contract_version": "OPS-V1-MASTER-SNAPSHOT.v1",
  "source_system": "OPS_V1",
  "snapshot_id": "ops-v1-master-<UTC timestamp>",
  "exported_at": "<UTC timestamp>",
  "extractor_version": "<repository version>",
  "complete_entities": [
    "schools",
    "ingredient_types",
    "ingredient_order_groups",
    "ingredients",
    "suppliers",
    "supplier_eligibilities",
    "dish_types",
    "dishes",
    "recipes",
    "recipe_lines"
  ],
  "records": {},
  "source_counts": {},
  "source_fingerprints": {}
}
```

The snapshot checksum is calculated over canonical JSON excluding only the checksum itself.

### 6.1 Full-snapshot requirement

Repeated reconciliation is valid only for entity sets listed in `complete_entities`.

A partial/debug export may be previewed but may never infer absence. This prevents a filtered source extract from incorrectly inactivating or flagging unrelated Atlas facts.

### 6.2 Extraction safety

Extraction is read-only and deterministic:

- explicit `SELECT` statements only;
- no Retool mutation;
- no OPS v1 function invocation with side effects;
- no temporary writes to OPS v1;
- source primary keys are preserved as `legacy_id` values;
- all text is normalized to Unicode NFC and outer whitespace only; business spelling is otherwise preserved.

## 7. Source-to-Atlas mapping rules

### 7.1 School facts

For each `public.schools.id = N`:

- Customer source identity: `school:N:customer`.
- Delivery Location source identity: `school:N:delivery-location`.
- School source identity: `N`.
- `school_full_name`, falling back to `name`, becomes Customer name.
- `name` remains the School operator name.
- `delivery_info` maps to Delivery Location `address_text`; retained OPS v1 Dispatch treats it as the address field.
- `default_students_num` → `default_student_portions`.
- `default_teacher_num` → `default_teacher_portions`.
- `display_order` is preserved.
- `is_active` maps explicitly to ACTIVE/INACTIVE.
- `school_type_id` resolves through the persistent School Type crosswalk.

`region_code` is legacy source evidence only in this migration because current Atlas School truth has no equivalent field and retained Dispatch ordering has already moved to `display_order`. It must be reported as intentionally unmapped, not silently discarded.

`contract_type` maps only to the already accepted School document issuer facts:

- `1` → `CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO`;
- `2` → `CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO`.

The existing accepted issuer address remains the associated Atlas School issuer address. Any other `contract_type` is a blocker.

### 7.2 School Types

OPS v1 has no independent School Type master relation. The extractor builds source School Type rows from distinct non-null `schools.school_type_id + school_type_name` facts.

The source ID, not mutable display text, becomes the persistent crosswalk identity after the first successful mapping. Initial resolution is explicit and reviewed; name similarity must never create a new automatic mapping.

### 7.3 Units

OPS v1 stores Units as purchase-unit text rather than a master relation.

The extractor creates a source Unit set from the union of:

- `ingredients.purchase_unit`;
- `bill_of_materials.purchase_unit`.

Unit source identity is the exact NFC+trimmed source string. Distinct spellings such as `Hũ` and `Hủ` remain distinct unless explicitly reconciled by a reviewed mapping decision.

The importer resolves to existing Atlas Units where an exact reviewed mapping exists. It never performs fuzzy merging.

### 7.4 Ingredient classifications

- `ingredient_type.id/name` maps to existing Atlas `ingredient_types`.
- `ingredient_shopping_type.id/name` maps to existing Atlas `ingredient_order_groups`.

The first rehearsal establishes persistent crosswalks from OPS v1 IDs to Atlas catalog IDs. Unknown/mismatched catalogs are blockers. The importer does not create arbitrary classification rows.

### 7.5 Ingredients

`ingredients.id` is the stable source identity.

Mapped facts include:

- name;
- active/archive state;
- Ingredient Type identity;
- Order Group identity;
- purchase Unit identity;
- `order_step`.

Atlas technical codes use stable migration-generated values based on source identity, not editable names, e.g. `v1-ingredient-<legacy_id>`.

### 7.6 Suppliers

`suppliers.id` is the stable source identity. Name and lifecycle map directly.

OPS v1 has one free-form `contact_details` field while Atlas has structured contact name/phone/email. The importer must not guess a parse. Raw `contact_details` is retained in snapshot/reconciliation evidence and classified `SOURCE_ONLY_UNMAPPED` until an explicit mapping rule is separately approved.

Atlas technical codes use stable source-derived values, e.g. `v1-supplier-<legacy_id>`.

### 7.7 Supplier eligibility

Source identity is the composite:

```text
ingredient:<ingredient_id>:supplier:<supplier_id>
```

`default_priority` maps to Atlas priority after validation. The relationship is ACTIVE when explicitly present in the source snapshot.

`lead_time_days` has no current Atlas master target. Non-null values are reported as `SOURCE_ONLY_UNMAPPED`; the migration must not hide this loss.

### 7.8 Dish Types and Dishes

`dish_types.id` establishes the persistent crosswalk to the existing six Atlas Dish Type rows. Unknown Dish Type source IDs/names are blockers.

`dishes.id` is the stable source identity. Name, explicit Dish Type, active/archive state, and stable source-derived technical code are imported. No dish is matched or merged by name after a crosswalk exists.

### 7.9 Recipes and BOM

Current OPS v1 has exactly two typed Recipe roots per Dish: 1,320 active rows for 660 Dishes, each with an explicit `school_type_id` and no School-specific Recipe.

The migration therefore interprets `school_type_id` as the authoritative scope fact. The legacy `is_general=true` flag is compatibility evidence only and does not recreate a GENERAL recipe choice in Atlas.

For each source `recipes.id`:

- map to one Atlas `(dish_id, school_type_id)` Recipe root;
- preserve source Recipe ID in the crosswalk;
- convert current BOM rows into a deterministic canonical composition;
- use a fixed migration basis of **100 portions**, matching the retained v1/Retool per-100 recipe convention;
- resolve Ingredient and Unit through existing crosswalks only;
- reject unknown, duplicate, non-positive, or missing references.

A Recipe with no BOM lines is a blocker. Current source evidence already contains one such Recipe, so Rehearsal A is expected to surface at least that issue until staff resolves it.

## 8. Persistent identity and repeatability

`atlas_legacy.master_data_mappings` remains the typed crosswalk. It is extended, not replaced.

### 8.1 Stable identity rule

The key remains:

```text
(source_system, object_type, legacy_id)
```

Once mapped, later snapshots must resolve to the same Atlas identity. Name/address/contact changes update facts; they do not generate a new root.

### 8.2 Additional import evidence

The current mapping row identifies the batch that established the mapping. Repeatable rehearsal needs additive evidence rather than changing that meaning.

The implementation should add only the minimum required import evidence:

- `last_seen_import_batch_id`;
- `last_source_fingerprint`;
- `last_target_version` where the target object is versioned.

This supports target-drift detection without turning mappings into business state.

### 8.3 Target drift

If an Atlas target has changed since the last import and that change was not produced by the importer, the next rehearsal must return `TARGET_DRIFT` and refuse to overwrite it automatically.

Before cutover, imported candidate master data should therefore be treated as reviewable migration target data, not independently maintained competing authority.

## 9. Preview plan and action semantics

Import is two-step:

```text
snapshot
  -> preview_master_data_snapshot
  -> deterministic plan + plan_checksum
  -> explicit apply with same snapshot_checksum + plan_checksum
```

Preview does not write target business facts.

Each source/target comparison receives exactly one result:

- `CREATE` — new source identity.
- `UPDATE` — mapped identity, changed governed facts.
- `NO_CHANGE` — mapped identity, same governed facts.
- `EXPLICIT_INACTIVATE` — source row explicitly says inactive/archived.
- `MISSING_FROM_SOURCE` — previous mapping absent from a declared full snapshot.
- `TARGET_DRIFT` — target changed outside importer since last applied snapshot.
- `BLOCKED` — invalid/ambiguous/missing dependency.
- `SOURCE_ONLY_UNMAPPED` — source fact intentionally retained as evidence because Atlas has no approved target fact.

### 9.1 No delete-by-absence

`MISSING_FROM_SOURCE` never deletes or automatically inactivates the target.

It is a reconciliation finding requiring explicit reviewed disposition. Explicit source lifecycle fields may inactivate an Atlas master object when the normal Atlas invariant allows it.

## 10. Transaction and cascade boundary

### 10.1 Atomic apply

A full snapshot apply is one controlled migration transaction after all blockers are evaluated.

If any blocking row would cause an ambiguous or invalid target, no target business rows are written. Rejected-batch evidence may still be recorded by the private importer as it is today.

### 10.2 “Cascade” means master-data dependency cascade only

The rehearsal cascade is:

```text
Catalogs
  -> School/Customer/Location
  -> Ingredient/Supplier
  -> Supplier eligibility
  -> Dish/Dish Type
  -> Recipe roots
  -> Recipe composition
  -> authoritative readback + readiness/reconciliation
```

It does **not** generate Weekly Menus, Attendance, Needs, allocations, POs, PXKs, or Dispatch records.

### 10.3 Recipe materialization

For migration/rehearsal, imported current recipes must become valid Atlas planning master facts, not remain unusable staging JSON forever.

The private migration path may create/move the imported Recipe Version through the same validation invariants needed to materialize Recipe Lines/Revisions and produce a `RELEASED_FOR_PLANNING` current fact. Its `source_evidence` must state that it is a migration of the current OPS v1 master snapshot and identify snapshot/checksum/source Recipe ID.

This records the truthful Atlas event “current source master was imported/released for planning”; it does not pretend to recreate historic v1 authoring events.

Once an imported Dish is referenced by an approved Atlas Weekly Menu snapshot, later migration writes to that Dish’s base Recipe/BOM must fail closed under the existing committed-use lock. The final master-data refresh must therefore occur before live Atlas Weekly Menu approval.

## 11. Environment strategy

### Rehearsal A — now

Do not apply the full source to the shared Staging dataset first, because existing synthetic/partial operational fixtures can lock Recipe facts and confuse reconciliation.

Use a disposable Atlas database created from current migrations (local reset or dedicated Supabase branch), then:

1. extract current read-only OPS v1 full master snapshot;
2. preview;
3. apply;
4. run master/read-model verification;
5. generate reconciliation artifacts;
6. send source-data findings back to staff.

### Rehearsal B — after importer stabilizes

Run the same importer on Atlas Staging after deciding how existing synthetic fixtures are isolated/reset. No production authority changes.

### Final refresh — immediately before cutover

1. freeze master-data edits in OPS v1 for the short cutover window;
2. take a fresh full snapshot;
3. run the same extractor/importer version;
4. require zero unexplained blockers/drift;
5. compare source and target counts/mappings/fingerprints;
6. declare Atlas master data authoritative;
7. disable further OPS v1 master import except approved incident recovery;
8. configure and rehearse the real Google Weekly Menu source;
9. begin Atlas operational facts from go-live onward.

## 12. Reconciliation contract

Every preview/apply produces a machine-readable and human-readable report containing:

- snapshot identity/checksum/export time/extractor version;
- source counts by entity;
- target counts before and after;
- mapping counts;
- action counts by entity and action;
- every blocker with source legacy ID and field;
- every `MISSING_FROM_SOURCE` mapping;
- every `TARGET_DRIFT` finding;
- every `SOURCE_ONLY_UNMAPPED` field/count;
- source-to-Atlas sampled trace records;
- Recipe/Dish/BOM completeness;
- aggregate checksum/fingerprint comparison;
- final gate: `REJECTED`, `REHEARSAL_ACCEPTED`, or `CUTOVER_READY`.

A report may be `REHEARSAL_ACCEPTED` with known reviewed source-only fields, but `CUTOVER_READY` requires zero unexplained blockers and zero unexplained target drift.

## 13. Security and mutation boundary

- OPS v1 remains STRICT READ ONLY.
- Retool remains unchanged.
- No browser role can execute migration functions.
- No `atlas_api` public migration endpoint is added.
- `atlas_legacy` remains private.
- Hosted apply requires an explicit operator/deployment action; it is never scheduled automatically.
- Snapshot files must not contain credentials/secrets.
- The importer cannot connect back to OPS v1 after extraction.
- Normal Atlas runtime never depends on legacy IDs or the migration schema.

## 14. Failure and rollback semantics

Before master-data authority cutover, the rehearsal target is disposable. Failed imports are corrected by fixing the extractor/source/reconciliation rule and replaying from a clean target when necessary.

Repeated import to the same target is allowed only through the persistent crosswalk and target-drift checks.

After master-data authority cutover or after any Atlas operational fact references imported identities:

- do not delete/remap stable target identities;
- corrections use normal versioned Atlas commands;
- importer is no longer the routine authority;
- rollback is a reviewed forward correction/restore procedure, not a legacy overwrite.

## 15. Acceptance criteria for the importer implementation

The implementation is acceptable when all of the following are true:

1. A current full OPS v1 snapshot is extracted with zero source writes.
2. Snapshot checksum is deterministic across equivalent extraction order.
3. Preview is non-writing and deterministic.
4. Applying the same snapshot twice creates no duplicate target facts.
5. A later snapshot with changed names/defaults/priorities updates the same Atlas identities.
6. Source primary-key continuity is proven for School, Ingredient, Supplier, Dish, and Recipe.
7. Unknown catalog/reference values block before target writes.
8. Absence from a full snapshot never deletes a target automatically.
9. Manual Atlas drift is detected and not overwritten.
10. All 660 current Dishes and 1,320 typed Recipe roots can be accounted for as imported, blocked, or explicitly excluded — never silently dropped.
11. All 4,045 BOM lines can be accounted for similarly.
12. The currently observed no-BOM Recipe is surfaced explicitly.
13. The current 846 Ingredient–Supplier relationships are reconciled exactly.
14. Retool, Live OPS, and operational Atlas tables remain untouched by the rehearsal.
15. A later fresh snapshot can be imported with only legitimate `CREATE/UPDATE/NO_CHANGE/...` deltas and stable target IDs.

## 16. Implementation decomposition

After Product Owner review, implementation should be split into bounded tasks rather than one large migration patch:

1. **Snapshot Extractor + Contract** — read-only OPS v1 extraction, schema, canonicalization, source checks.
2. **Repeatable RMVP-01 Import Core** — preview/apply, persistent mapping reuse, last-seen/source fingerprint, drift detection, Schools/Ingredients/Suppliers/catalogs.
3. **Recipe/Dish/BOM Extension** — Dish Type/Dish/typed Recipe/BOM current-state import using RMVP-02A invariants.
4. **Reconciliation + Rehearsal Runner** — reports, clean disposable target, full Rehearsal A evidence.
5. **Hosted Staging Rehearsal** — separate explicit authorization after local/disposable certification.
6. **Final Cutover Refresh** — separate explicit authorization during the agreed v1 master-data freeze window.

## 17. Non-decisions preserved

This design does not merge #286, does not authorize production entrypoint cutover, does not configure the real Google Weekly Menu source, does not write Atlas Staging, and does not change live OPS v1 or Retool.

Those remain separate gates.
