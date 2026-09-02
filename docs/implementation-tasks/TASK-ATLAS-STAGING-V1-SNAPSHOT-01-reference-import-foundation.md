# ATLAS-STAGING-V1-SNAPSHOT-01 — Controlled OPS v1 Reference Import Foundation

**Status:** Implemented for review; hosted import not executed

**Purpose:** make Atlas Staging reference data realistic enough for multi-School Planning and multi-Supplier Procurement rehearsal without migrating production operations or changing Atlas business contracts.

## Source and target boundary

The source is live OPS v1 project `qnthofvccilhnefdcxnz`. It is read through the dedicated `OPS_V1_READONLY_DATABASE_URL` secret only. The extractor accepts no SQL input and executes one fixed `REPEATABLE READ READ ONLY` transaction over the six required `public` tables. It verifies `transaction_read_only = on`, a non-superuser/non-bypass role, required table reads, and absence of non-read table privileges before accepting the snapshot.

The only permitted target is Atlas Staging project `rnzxmxiiqgtdevzregff`. The target guard also rejects the live OPS project explicitly and requires source and target identities to differ. Target writes use the existing Supabase Management SQL convention and one transaction. This package creates no schema, relation, API, capability, role, scope kind, lifecycle, migration, Auth identity, or Edge Function.

## Imported objects

The transformer produces only:

- School Types;
- one Customer and one Delivery Location for every importable School;
- Schools;
- purchase Units required by active Ingredients;
- mappings from OPS v1 Ingredient Types to the existing Atlas catalog;
- mappings from OPS v1 shopping groups to the existing Atlas Ingredient Order Group catalog;
- active Ingredients;
- Suppliers, with business names only;
- Supplier Eligibilities derived from active-Ingredient `ingredient_suppliers` relationships.

It excludes Dishes, Recipes/BOM, School recipe changes, menus, attendance, Pantry, all Planning and Procurement operational facts, purchase assignments/orders, Warehouse, Dispatch, audit history, Auth data, Actor/role bindings, and supplier contact details.

## Deterministic identity and ownership

The importer implements RFC 4122 UUIDv5-compatible SHA-1 generation with Node built-in crypto and namespace:

```text
6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7
```

Domain names are source-ID-based, including `school:<id>`, `customer:school:<id>`, `delivery-location:school:<id>`, `school-type:<id>`, `ingredient:<id>`, `supplier:<id>`, `supplier-eligibility:<ingredient_id>:<supplier_id>`, and `unit:<exact-trimmed-label>`. Codes use lowercase Atlas-compatible forms such as `v1-school-21` and `v1-ingredient-153`. Display names never determine identity.

The package owns only its deterministic IDs and `v1-` codes, plus Supplier Eligibilities carrying the fixed import reason. It updates allowed fields only when materially different, advances versions only for material changes on versioned rows, never deletes a disappeared source row, and does not touch unrelated Atlas-only rows.

## Field mapping

| OPS v1 source                                     | Atlas target                                                           |
| ------------------------------------------------- | ---------------------------------------------------------------------- |
| School `school_full_name`, falling back to `name` | Customer and School display name; Delivery Location display name basis |
| School `delivery_info`                            | `delivery_locations.address_text`                                      |
| fixed staging policy                              | `delivery_locations.timezone_name = Asia/Ho_Chi_Minh`                  |
| School `display_order`                            | `schools.display_order`                                                |
| School `school_type_id` and `school_type_name`    | deterministic School Type                                              |
| School `default_students_num`                     | `schools.default_student_portions`                                     |
| School `default_teacher_num`                      | `schools.default_teacher_portions`                                     |
| Ingredient `name`                                 | `ingredients.ingredient_name`                                          |
| Ingredient `purchase_unit`                        | controlled Atlas purchase Unit                                         |
| Ingredient `ingredient_type_id`                   | exact-name existing Atlas Ingredient Type                              |
| Ingredient `shopping_type_id`                     | exact-name existing Atlas Ingredient Order Group                       |
| Ingredient `order_step`                           | `ingredients.order_step`                                               |
| Supplier `name`                                   | `suppliers.supplier_name`                                              |
| `ingredient_suppliers.default_priority`           | `supplier_eligibilities.priority`                                      |

All 17 current OPS v1 Ingredient Type names exactly match the existing 17-row Atlas catalog. All three current OPS v1 shopping-group names exactly match the existing Atlas order-group catalog. These existing Atlas IDs are reused; duplicate lookup rows are not created. Lookup drift is a validation failure rather than a guessed mapping.

## Null and unit policy

A School missing either required default portion quantity is skipped as one complete Customer/Location/School bundle and reported as `MISSING_REQUIRED_DEFAULT_PORTIONS`. Null is never converted to zero, and no Customer or Delivery Location orphan is created.

`Kg` and `kg` resolve to the existing Atlas `kg` Unit. The currently observed remaining labels are kept distinct and represented as staging-only `COUNT` purchase Units with integer scale: `Bịch`, `Bó`, `Cái`, `Cây`, `Chai`, `Cốc`, `Gói`, `Hộp`, `Hũ`, `Hủ`, `Lon`, `Miếng`, `Ổ`, `Quả`, and `Trái`. No conversion factor or cross-label equivalence is implied. In particular, `Hủ` and `Hũ` remain different identities. Any unapproved label blocks transformation instead of being guessed.

This COUNT translation is limited to Staging reference rehearsal. It does not approve a future production conversion or package-unit model.

## Supplier Eligibility translation

Each valid active-Ingredient relationship becomes one deterministic active Eligibility. Priority is copied exactly. `effective_from` is the explicit historical sentinel `2000-01-01`, `effective_to` is null, and the reason is:

```text
Imported from OPS v1 reference snapshot; source relationship has no effective dating.
```

`lead_time_days` is not mapped. Duplicate pairs block transformation. Equal per-Ingredient priorities are reported and block apply because Atlas enforces one active Supplier per Ingredient priority.

## Privacy and reporting

The real snapshot exists only in process memory. It is never written to the repository, a temporary snapshot file, logs, or a GitHub Actions artifact. The extractor selects no supplier contact column. Reports contain aggregate source, transformation, skip, Procurement-usefulness, and target-comparison counts only. Credentials and database URLs pass through the established redactor on failure.

Dry-run is the default. It extracts, transforms, validates, performs a read-only Atlas target comparison, prints aggregates, and makes no target write. Apply additionally requires `--apply` and exact `--target-project-ref rnzxmxiiqgtdevzregff`, rejects blockers/conflicts, reconciles in one transaction, then rereads Atlas Staging and requires a fully reconciled result.

## Protected workflow

The manual workflow is `Atlas Staging OPS v1 Reference Import` in `.github/workflows/atlas-staging-v1-reference-import.yml`. It uses the protected `atlas-staging` environment, requires an exact current-main `commit_sha`, always runs dry-run, and runs apply only when the dispatcher selects `apply`.

Required protected values:

- variable `ATLAS_STAGING_PROJECT_REF`;
- variable `VITE_SUPABASE_URL`;
- secret `ATLAS_STAGING_SUPABASE_ACCESS_TOKEN`;
- secret `OPS_V1_READONLY_DATABASE_URL` for a dedicated OPS v1 read-only database role.

The implementation PR does not execute this workflow or mutate either hosted project.

## Migration, rollback, and follow-up

There is no migration or schema rollback. Apply is additive/updating only and preserves unrelated rows and source-disappearance drift. Destructive correction/reset is not part of this package; unexpected hosted state must stop for review rather than trigger retry, deletion, or manual repair.

Explicit follow-ups:

- `ATLAS-STAGING-V1-SNAPSHOT-02` — Dish, Recipe, and BOM semantic unit;
- `ATLAS-STAGING-RESET-01` — separately governed destructive reset/reseed capability.

`PROCUREMENT-UX-CLOSEOUT-01` remains a separate later UI change after a reviewed and merged reference import.
