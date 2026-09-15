# MASTER-DATA-REHEARSAL-IMPORT-01 — Repeatable OPS v1 Master-Data Rehearsal and Cutover Import

**Status:** Design self-reviewed; awaiting Product Owner approval  
**Date:** 15/09/2026  
**Architecture authority:** OPS_SYSTEM_MAP v1.0 / ARCH-002  
**Parent contracts:** RMVP-01, RMVP-02A, D-037 Atlas Model Convergence  
**Principle:** **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

## 1. Decision

Atlas will not wait for OPS v1 master data to become perfectly stable before testing migration.

Instead, Atlas will use a **repeatable, immutable snapshot import**:

```text
OPS v1 current master snapshot
  -> normalize + fingerprint
  -> preview deterministic import plan
  -> apply to a disposable rehearsal target
  -> cascade master/reference dependencies only
  -> reconcile
  -> staff continue correcting OPS v1
  -> take a fresh full snapshot
  -> run the same importer again
  -> preserve Atlas identities
  -> reconcile to zero unexplained differences
  -> declare master-data cutover
```

The first import is **Migration Rehearsal A**, not authority cutover.

No OPS v1 operational history is migrated. Weekly Menu, Attendance, Pantry, Planning readiness, Need Generation, Confirmed Need, supplier allocation, PO, PXK, Dispatch, and reconciliation history begin in Atlas from go-live onward.

## 2. Chosen architecture

### 2.1 Extend the existing `atlas_legacy` importer — chosen

RMVP-01 already provides the correct migration boundary:

- immutable operator-selected JSON snapshots;
- deterministic SHA-256 over canonical JSON;
- private `atlas_legacy.import_batches`;
- typed `atlas_legacy.master_data_mappings`;
- validation-before-write;
- source/target/mapping/operation counts;
- reconciliation evidence;
- no runtime/live legacy connection.

RMVP-02A already extends the same typed migration evidence through Dish, Recipe, Recipe Version, Recipe Line, and Recipe Line Revision identities.

The rehearsal design therefore **extends the existing importer** into a repeatable pre-cutover importer. It does not create a second ETL domain.

### 2.2 Generic ETL/staging framework — rejected

A generic `source_table/source_key/target_table/target_key` integration framework would duplicate typed migration evidence and weaken business ownership.

### 2.3 Live DB-to-DB synchronization — rejected

FDW, database links, direct cross-project runtime reads, scheduled synchronization, and Retool/browser-driven copy are prohibited. Atlas runtime must remain independent of OPS v1.

## 3. Evidence baseline

### 3.1 OPS v1 current read-only source

Fresh read-only inspection during this design found:

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

Lifecycle distribution:

- Schools: 40 active / 3 inactive.
- Ingredients: 373 active / 3 inactive.
- Dishes: 660 active / 0 inactive.
- Recipes: 1,320 active / 0 inactive.
- Recipe `is_locked`: 1,078 true / 242 false.

Recipe shape is useful for convergence: there are exactly 1,320 distinct `(dish_id, school_type_id)` pairs, no School-specific Recipe, and every Recipe has an explicit School Type. The legacy `is_general=true` flag is set on all current Recipe rows, but the explicit `(Dish, School Type)` pair is the durable business fact Atlas should preserve.

BOM inspection found:

- 4,045 positive lines;
- no missing Ingredient references;
- no missing purchase-unit text;
- no duplicate `(recipe_id, ingredient_id)` pair;
- 1,319 of 1,320 Recipe rows have at least one BOM line.

The one no-BOM Recipe is current source Recipe `3362`, Dish `1983` (`Deact Test`), School Type `2`. The sibling Recipe `3361` for the same Dish/School Type family references inactive Ingredient `1170` (`Deact test`) using purchase Unit text `123`. This is a **source-data blocker cluster**, not an importer exception to silently normalize away.

### 3.2 Catalog reconciliation observed now

The current source and Staging catalogs are close enough for explicit mappings:

- all 17 OPS v1 Ingredient Type names have matching active Atlas Ingredient Type names;
- all 3 OPS v1 Ingredient Shopping Type names have matching active Atlas Ingredient Order Group names;
- OPS v1 School Type `1 / TIỂU HỌC` maps to Atlas `v1-school-type-1`;
- OPS v1 School Type `2 / TRUNG HỌC` maps to Atlas `v1-school-type-2`;
- the Staging-only synthetic School Type is not a migration source target.

Dish Type mapping is explicit by source identity, not fuzzy text:

| OPS v1 Dish Type | Atlas Dish Type |
| --- | --- |
| `1 / Canh` | `soup / Món canh` |
| `2 / Món mặn` | `savory / Món mặn` |
| `3 / Món xào` | `stir_fry / Món xào` |
| `4 / Tráng miệng` | `dessert / Tráng miệng` |
| `5 / Món xế` | `afternoon_snack / Buổi xế` |
| `6 / Nước` | `beverage / Nước` |

### 3.3 Unit reconciliation observed now

OPS v1 currently exposes 18 distinct trimmed purchase-unit strings across Ingredient and BOM facts, while Staging has 16 active Atlas Units.

Most source strings already correspond one-to-one to Atlas names, including distinct `Hũ` and `Hủ`.

Two explicit aliases represent the same reviewed Unit:

- `Kg` → Atlas `unit_code = kg` / `Kilogram`;
- `kg` → Atlas `unit_code = kg` / `Kilogram`.

The source token `123` is not a Unit alias. It occurs on inactive Ingredient `1170 / Deact test` and one BOM row for active Dish `1983 / Deact Test`; it is a current source-data blocker until staff corrects or explicitly removes that test artifact from current master truth.

### 3.4 Atlas Staging current target

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

`atlas_legacy.master_data_mappings` is currently empty on shared Staging, so Staging data must not be mistaken for an already established migration crosswalk.

This is why Rehearsal A should establish the crosswalk on a disposable target first.

## 4. Source authority and Retool evidence

The extraction authority is the **OPS v1 PostgreSQL master relations**, read-only.

Retool is workflow evidence only. The retained apps establish important field meaning:

- Dispatch/export consumes `schools.school_full_name`, `delivery_info`, `contract_type`, and `display_order`;
- current Dispatch ordering uses `display_order`, not `region_code`;
- School defaults use `default_students_num` and `default_teacher_num`;
- Ingredient/Supplier maintenance uses `ingredients`, `suppliers`, and `ingredient_suppliers`;
- Recipe/BOM maintenance uses `dishes`, `recipes`, and `bill_of_materials`;
- the Retool per-100 Recipe workbook importer deletes/recreates active Recipe rows for a `(dish_id, school_type_id)` pair.

That final point is critical: **OPS v1 `recipes.id` is not a stable business identity.** The Atlas Recipe crosswalk must use the stable source business key `(dish_id, school_type_id)`, not the churn-prone Recipe row ID.

No Retool query will be executed as a migration write path.

## 5. Scope

### 5.1 In scope

1. School Types.
2. Customer + Delivery Location facts derived from each OPS v1 School.
3. Schools and School defaults.
4. Units referenced by Ingredient/BOM facts.
5. Ingredient Types.
6. Ingredient Order Groups / OPS v1 Ingredient Shopping Types.
7. Ingredients.
8. Suppliers.
9. Ingredient–Supplier eligibility and priority relationships.
10. Dish Types.
11. Dishes.
12. Canonical typed Recipe roots.
13. Current Recipe composition/BOM as Atlas Recipe Version + line facts.
14. School Dispatch issuer facts from the accepted `contract_type` mapping.

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

Migration may create truthful **Atlas migration evidence**, but it must not fabricate historical Atlas commands/events for actions that happened before Atlas.

## 6. Immutable snapshot contract

A full extraction produces one immutable JSON document:

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

The snapshot checksum is SHA-256 over canonical JSON excluding only the checksum field itself.

### 6.1 Full-snapshot rule

Absence semantics are allowed only for entity/relationship sets listed in `complete_entities`.

A partial/debug export may be previewed but may never infer missing roots or removed relationships.

### 6.2 Extraction safety

Extraction uses deterministic `SELECT` statements only:

- no OPS v1 writes;
- no side-effecting OPS functions;
- no Retool mutation;
- no temporary source tables;
- source IDs/business keys retained;
- Unicode NFC + outer trim only;
- no fuzzy normalization of business spelling.

## 7. Source-to-Atlas mapping

### 7.1 School facts

For each `public.schools.id = N`:

- Customer migration identity: `school:N:customer`.
- Delivery Location migration identity: `school:N:delivery-location`.
- School migration identity: source School `N`.
- `school_full_name`, falling back to `name`, → Customer name.
- `name` → School operator name.
- `delivery_info` → Delivery Location `address_text`.
- `default_students_num` → `default_student_portions`.
- `default_teacher_num` → `default_teacher_portions`.
- `display_order` preserved.
- `is_active` → ACTIVE/INACTIVE.
- `school_type_id` resolves through the persistent School Type mapping.

`region_code` has no current Atlas School target and retained Dispatch has already moved to `display_order`; it is retained as `SOURCE_ONLY_UNMAPPED` evidence.

`contract_type` maps only to the accepted issuer facts:

- `1` → `CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO`;
- `2` → `CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO`.

Issuer address for both accepted mappings:

`ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam`

Any other non-null `contract_type` is a blocker.

### 7.2 School Types

OPS v1 has no independent School Type relation. The extractor builds the source catalog from distinct non-null `(school_type_id, school_type_name)` facts.

Initial reviewed mapping is:

- source `1` → Atlas `v1-school-type-1`;
- source `2` → Atlas `v1-school-type-2`.

After the first mapping, source ID is the identity; later display text changes are `UPDATE`/review evidence, never a new automatic mapping.

### 7.3 Units

The extractor derives the source Unit set from the union of:

- `ingredients.purchase_unit`;
- `bill_of_materials.purchase_unit`.

Source Unit identity is exact NFC+trimmed text.

Distinct business spellings remain distinct unless an explicit reviewed alias exists. `Hũ` and `Hủ` therefore remain separate Atlas Units.

Explicit current aliases:

- `Kg` → Atlas `kg / Kilogram`;
- `kg` → Atlas `kg / Kilogram`.

Multiple source Unit identities may map to one reviewed Atlas Unit. Fuzzy matching is prohibited.

Unknown tokens such as current source `123` are blockers, not new Units.

### 7.4 Ingredient classifications

- `ingredient_type.id` → Atlas Ingredient Type mapping.
- `ingredient_shopping_type.id` → Atlas Ingredient Order Group mapping.

Current names reconcile 17/17 and 3/3 respectively. The first successful import persists source-ID mappings; future imports do not remap by name.

Unknown source IDs/names are blockers. The importer does not create arbitrary classification rows.

### 7.5 Ingredients

`ingredients.id` is stable source identity.

Mapped facts:

- name;
- active/inactive state;
- Ingredient Type;
- Order Group;
- purchase Unit;
- `order_step`.

Atlas technical code is source-derived and name-independent, e.g. `v1-ingredient-<legacy_id>`.

### 7.6 Suppliers

`suppliers.id` is stable source identity. Name maps directly.

OPS v1 has free-form `contact_details`, while Atlas has structured contact name/phone/email. The importer must not guess parsing. Raw `contact_details` is retained as `SOURCE_ONLY_UNMAPPED` evidence until a separate mapping rule is approved.

Atlas technical code is source-derived, e.g. `v1-supplier-<legacy_id>`.

### 7.7 Supplier eligibility

Stable source relationship identity:

```text
ingredient:<ingredient_id>:supplier:<supplier_id>
```

`default_priority` maps to Atlas priority after validation.

`lead_time_days` has no current Atlas target and is reported as `SOURCE_ONLY_UNMAPPED` when present.

Because `ingredient_suppliers` is a complete membership set with no source lifecycle column, absence from a **declared full relationship snapshot** is a real removal fact. The importer may materialize this as an INACTIVE Atlas Supplier Eligibility after preview; it must never physically delete the Atlas relationship.

### 7.8 Dish Types and Dishes

Dish Type mapping uses the explicit six-row table in section 3.2. It is persisted by source Dish Type ID.

`dishes.id` is stable source identity. Import:

- name;
- explicit Dish Type;
- active/inactive state;
- stable source-derived technical code, e.g. `v1-dish-<legacy_id>`.

No Dish is merged by name after a source mapping exists.

### 7.9 Recipe root identity

**Do not use `recipes.id` as the durable migration key.** Retool’s current per-100 workbook import deletes and recreates active Recipe rows for the same Dish/School Type, so the row ID can churn while the business Recipe remains the same.

Stable Recipe source identity is:

```text
dish:<dish_legacy_id>:school-type:<school_type_legacy_id>
```

Current `recipes.id` is retained as `source_record_id` evidence/fingerprint only.

A changed `recipes.id` with the same stable business key must resolve to the same Atlas `recipe_id`.

`recipe_name` has no current Atlas Recipe-root target and is retained as `SOURCE_ONLY_UNMAPPED` evidence.

Legacy flags:

- `is_general=true` is compatibility evidence only; it does not recreate a GENERAL Atlas root.
- `is_locked` is v1 operational/editor history evidence. It must **not** be mapped to Atlas Recipe Version `LOCKED`, because operational history is not being migrated. Current source has 1,078 locked rows, and carrying that flag across would falsely commit Atlas history.
- `is_active` remains source-currentness evidence; current source has all 1,320 Recipe roots active.

### 7.10 Recipe composition/BOM identity

Use a fixed migration basis of **100 portions**, matching the retained v1 per-100 Recipe convention.

Within one stable Recipe root, source composition identity is:

```text
recipe:<stable recipe key>:ingredient:<ingredient_legacy_id>
```

Do not use `bill_of_materials.id` as the durable Atlas Recipe Line key. The current source invariant already guarantees no duplicate `(recipe_id, ingredient_id)` pair, and a Retool overwrite may recreate row IDs.

`bill_of_materials.id` remains row evidence only.

For each composition line:

- Ingredient resolves through persistent mapping;
- purchase Unit resolves through explicit Unit mapping;
- positive `usable_quantity` becomes `quantity_per_basis`;
- note may become line operational note/source evidence when supported;
- unknown, duplicate, non-positive, missing, or invalid Unit/Ingredient facts block apply.

If a previously imported Ingredient line disappears from a declared full composition for the same stable Recipe root, the importer materializes the existing Atlas `REMOVED` line-revision semantics; it does not delete immutable Recipe Line history.

A current Recipe root with zero composition lines is a blocker. Source Recipe `3362` currently demonstrates this condition.

## 8. Persistent identity and repeatability

`atlas_legacy.master_data_mappings` remains the typed crosswalk. It is extended, not replaced.

### 8.1 Mapping key

The durable key remains:

```text
(source_system, object_type, legacy_id)
```

`legacy_id` means **stable migration identity**, which is normally the OPS v1 primary key but is deliberately a composite business key for churn-prone Recipe roots and relationship/line identities.

Once mapped, later snapshots resolve to the same Atlas identity. Names, source row IDs, addresses, defaults, and composition values may change without changing the root mapping.

### 8.2 Additive migration evidence

Repeatable rehearsal needs only minimal additive evidence on the mapping:

- `last_seen_import_batch_id`;
- `last_source_fingerprint`;
- `last_target_version` where the target is versioned.

The original mapping batch remains provenance for when the mapping was first established.

### 8.3 Target drift

If a mapped Atlas target changed outside the importer since the last applied snapshot, a later import returns `TARGET_DRIFT` and does not overwrite it automatically.

Before authority cutover, imported target data is therefore a migration candidate, not a second independently maintained master authority.

## 9. Preview and action semantics

Import is two-step:

```text
immutable snapshot
  -> preview_master_data_snapshot
  -> deterministic plan + plan_checksum
  -> explicit apply using exact snapshot_checksum + plan_checksum
```

Preview writes no target business facts.

Each planned fact receives one action:

- `CREATE` — new root/source identity.
- `UPDATE` — mapped root, governed facts changed.
- `NO_CHANGE` — mapped root, governed facts equal.
- `EXPLICIT_INACTIVATE` — source root explicitly inactive/archived.
- `MISSING_FROM_SOURCE` — previously mapped **root** absent from a declared full snapshot.
- `REMOVE_RELATIONSHIP` — relationship/child absent from a declared complete parent-owned set; materialize as inactive/removed history, never physical delete.
- `TARGET_DRIFT` — Atlas target changed outside importer.
- `BLOCKED` — invalid/ambiguous/missing dependency.
- `SOURCE_ONLY_UNMAPPED` — source fact retained as evidence because Atlas has no approved target fact.

### 9.1 No delete-by-absence for roots

`MISSING_FROM_SOURCE` for a School, Ingredient, Supplier, Dish, or other root never deletes or automatically inactivates the Atlas root. It requires reviewed disposition.

This rule does **not** erase complete-set semantics for Supplier Eligibility or Recipe composition: those use `REMOVE_RELATIONSHIP`, producing explicit inactive/removed Atlas facts.

## 10. Transaction and cascade boundary

### 10.1 Full-snapshot atomic apply

A full planned snapshot apply is one controlled migration transaction after all blockers are evaluated.

If any `BLOCKED` item would make the target ambiguous or invalid, target business rows are not partially written. Rejected-batch evidence may still be recorded privately as in RMVP-01.

This means the current `Deact Test` blocker cluster is expected to make the first full preview `REJECTED` until staff corrects it or an explicit reviewed source-data disposition is made. That is desirable evidence, not a reason to weaken validation.

### 10.2 Cascade means master dependency cascade only

```text
Catalog mappings
  -> Customer / Delivery Location / School
  -> Ingredient / Supplier
  -> Supplier Eligibility
  -> Dish / Dish Type
  -> stable typed Recipe roots
  -> current Recipe composition
  -> authoritative readback + reconciliation
```

No Weekly Menu, Attendance, Need, allocation, PO, PXK, Dispatch, or other operational aggregate is generated.

### 10.3 Recipe materialization

Imported current Recipes must become usable Atlas planning master facts.

The private migration path may materialize the current composition through the same RMVP-02A validation invariants and produce a `RELEASED_FOR_PLANNING` current Recipe Version. `source_evidence` records:

- migration source system;
- snapshot ID/checksum;
- stable Recipe source key;
- current churn-prone v1 `recipes.id` as evidence;
- source fingerprints.

This truthfully records “current OPS v1 master composition imported into Atlas”; it does not pretend to reproduce historic v1 authoring events.

Once an imported Dish is referenced by an approved Atlas Weekly Menu snapshot, the existing committed-use lock must prevent later base Recipe/BOM migration updates. Therefore the final master refresh must complete **before live Atlas Weekly Menu approval**.

## 11. Environment strategy

### 11.1 Rehearsal A — now

Do not apply the full source first to shared Staging. Shared Staging contains partial/synthetic facts and operational fixtures that can confuse identity/drift checks and may already exercise Recipe commitment logic.

Use a disposable Atlas database from current migrations (local reset or dedicated Supabase branch):

1. extract current OPS v1 full master snapshot read-only;
2. preview all mappings/deltas/blockers;
3. return source-data findings to staff;
4. once blockers are resolved, apply the exact reviewed snapshot/plan;
5. verify authoritative readback and dependency cascade;
6. generate Rehearsal A reconciliation artifacts;
7. replay identical snapshot and prove `NO_CHANGE`/idempotency.

### 11.2 Rehearsal B — after importer stabilizes

Run the same importer against Atlas Staging only after deciding how existing synthetic/partial fixtures are isolated or reset. This is a separate hosted-write authorization.

### 11.3 Final refresh — immediately before master cutover

1. freeze OPS v1 master edits for a short window;
2. take a fresh full snapshot with the same extractor contract;
3. preview with the same importer version;
4. require zero unexplained blockers and target drift;
5. apply using exact snapshot/plan checksums;
6. reconcile source counts, mappings, relationships, compositions, and fingerprints;
7. declare Atlas master data authoritative;
8. disable routine OPS v1 master import except approved incident recovery;
9. configure/rehearse the real Google Weekly Menu source;
10. begin Atlas operational facts from go-live onward.

## 12. Reconciliation contract

Every preview/apply produces machine-readable and human-readable evidence with:

- snapshot identity/checksum/export time/extractor version;
- source counts by entity;
- target counts before/after;
- mapping counts;
- action counts by entity/action;
- every blocker with source identity/field;
- every `MISSING_FROM_SOURCE` root;
- every `REMOVE_RELATIONSHIP` child/relationship;
- every `TARGET_DRIFT` finding;
- every `SOURCE_ONLY_UNMAPPED` field/count;
- sampled source→Atlas trace records;
- catalog and Unit reconciliation;
- Dish/Recipe/BOM completeness;
- source/target aggregate fingerprints;
- final gate.

Gates:

- `REJECTED` — blocker/ambiguity prevents apply.
- `REHEARSAL_ACCEPTED` — rehearsal applied/replayed successfully; reviewed `SOURCE_ONLY_UNMAPPED` evidence may remain.
- `CUTOVER_READY` — zero unexplained blockers, zero unexplained target drift, complete stable identity reconciliation, and final snapshot replay evidence.

## 13. Security and mutation boundary

- OPS v1 remains **STRICT READ ONLY**.
- Retool remains unchanged.
- No browser role executes migration functions.
- No public `atlas_api` migration endpoint is added.
- `atlas_legacy` remains private migration evidence.
- Hosted apply is an explicit operator/deployment action, never an automatic schedule.
- Snapshot files contain no secrets/credentials.
- The importer cannot connect back to OPS v1 after extraction.
- Normal Atlas runtime never depends on legacy IDs or `atlas_legacy`.

## 14. Failure and rollback

Before authority cutover, the rehearsal database is disposable. Failed imports are corrected by fixing source data, extraction, or reviewed mapping rules and replaying cleanly when needed.

Repeated import to the same target is permitted only through persistent crosswalk + drift checks.

After Atlas master-data authority cutover or after Atlas operational facts reference imported identities:

- do not remap/delete stable target identities;
- corrections use normal versioned Atlas commands;
- importer is no longer routine authority;
- rollback is a reviewed forward correction/restore, not a legacy overwrite.

## 15. Acceptance criteria for implementation

Implementation is acceptable only when:

1. A full current OPS v1 snapshot is extracted with zero source writes.
2. Equivalent source content produces the same canonical checksum regardless of query row order.
3. Preview is non-writing and deterministic.
4. Any blocker prevents partial full-snapshot business writes.
5. Applying/replaying the same accepted snapshot creates no duplicate target facts.
6. A later snapshot with changed names/defaults/priorities updates the same Atlas roots.
7. Source primary-key continuity is proven for School, Ingredient, Supplier, and Dish.
8. Recipe identity continuity is proven across source `recipes.id` churn using `(dish_id, school_type_id)` business identity.
9. Recipe Line continuity is proven across BOM row-ID churn using stable Recipe+Ingredient identity.
10. Unknown catalog/reference values block before writes.
11. Missing source roots never delete/inactivate automatically.
12. Removed Supplier Eligibility/BOM membership is represented explicitly without physical deletion.
13. Manual Atlas drift is detected and not overwritten.
14. All 660 current Dishes and 1,320 typed Recipe roots are accounted for — never silently dropped.
15. All 4,045 current BOM lines are accounted for.
16. Current Recipe `3362` / Dish `1983` no-BOM condition is surfaced.
17. Current invalid Unit token `123` / Ingredient `1170` condition is surfaced.
18. All 846 Ingredient–Supplier relationships are reconciled.
19. Current 17 Ingredient Types, 3 Order Groups, 6 Dish Types, and 2 source School Types reconcile through explicit catalog mappings.
20. Retool, Live OPS data, and operational Atlas tables remain untouched by Rehearsal A.
21. A later fresh snapshot can converge via legitimate actions while preserving target identities.

## 16. Implementation decomposition after design approval

Implementation should be split into bounded tasks:

1. **Snapshot Extractor + Contract** — read-only OPS v1 extraction, canonical snapshot schema/checksum, source diagnostics.
2. **Repeatable RMVP-01 Import Core** — preview/apply, persistent mapping reuse, last-seen/source fingerprints, drift detection, School/Ingredient/Supplier/catalog/Unit facts.
3. **Recipe/Dish/BOM Extension** — explicit Dish Type mapping, stable Recipe business key, stable composition key, RMVP-02A materialization.
4. **Reconciliation + Rehearsal Runner** — reports, disposable target, full Rehearsal A evidence and replay.
5. **Hosted Staging Rehearsal** — separate explicit authorization after disposable-target certification.
6. **Final Cutover Refresh** — separate explicit authorization during the agreed OPS v1 master-data freeze window.

## 17. Non-decisions preserved

This design does **not**:

- merge PR #286;
- authorize production-entrypoint cutover;
- configure the real Google Weekly Menu source;
- write Atlas Staging;
- mutate Live OPS v1;
- mutate Retool;
- implement importer code yet.

Those remain separate gates.
