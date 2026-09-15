# MASTER-DATA-REHEARSAL-IMPORT-01 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a repeatable, fail-closed OPS v1 master-data snapshot/import pipeline that can be rehearsed now and rerun at cutover while preserving Atlas identities and excluding operational history.

**Architecture:** Reuse the strict read-only OPS v1 extraction pattern and private `atlas_legacy` migration boundary. Add a canonical immutable snapshot, non-writing preview, checksum-bound atomic apply, persistent mapping reuse/drift detection, then extend the same plan to Dish/Recipe/BOM current-state migration. Rehearsal A runs only against a disposable local Atlas database.

**Tech Stack:** Node.js 24, pnpm 11.7, Vitest 4, PostgreSQL/Supabase CLI 2.111, PL/pgSQL, JSONB, pgTAP, existing RMVP-01/RMVP-02A contracts.

**Spec:** `docs/superpowers/specs/2026-09-15-master-data-rehearsal-import-design.md`

## Global Constraints

- OPS_SYSTEM_MAP v1.0 / ARCH-002 governs the work.
- Preserve **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**.
- Live OPS v1 `qnthofvccilhnefdcxnz` is STRICT READ ONLY; extraction must prove SELECT and no INSERT/UPDATE/DELETE/TRUNCATE privileges on every source table used.
- Atlas Staging `rnzxmxiiqgtdevzregff` receives zero writes in this plan; Rehearsal A is local/disposable only.
- Retool receives zero writes and remains workflow evidence only.
- Do not migrate Weekly Menu, Attendance, Pantry, Need Generation, Confirmed Need, allocations, PO, PXK, Dispatch, reconciliation, or operational history.
- Do not add a browser/public migration endpoint; migration functions stay private under `atlas_legacy`.
- Do not add generic ETL, FDW, live DB links, scheduled sync, or runtime legacy dependencies.
- Full-snapshot root absence never deletes or auto-inactivates a root.
- Complete child/relationship-set absence may create explicit inactive/REMOVED history only where the spec permits it.
- `kg` is the only kilogram Unit. Raw `Kg` and `kg` canonicalize to source token `kg` and Atlas `unit_code = kg` / `Kilogram`.
- `Hũ` is the only canonical jar spelling. Raw `Hủ` and `Hũ` canonicalize to source token `Hũ`; no separate active `Hủ` Unit may survive cutover preparation.
- Unit aliases are explicit only; no fuzzy normalization beyond the approved alias table.
- Source Unit token `123` is a blocker, not a Unit.
- Recipe root identity is `dish:<dish_legacy_id>:school-type:<school_type_legacy_id>`, never `recipes.id`.
- Recipe composition identity is stable Recipe business key + Ingredient identity, never `bill_of_materials.id`.
- Any full-snapshot blocker prevents partial target business writes.
- Keep PR #286 untouched; production entrypoint cutover is outside this plan.
- Do not weaken RLS, immutable Recipe revisions, or approved-Weekly-Menu committed-use locks.

- Approved apply amendment: explicit existing ACTIVE `operator_actor_id uuid`, recorded as execution context outside the immutable source snapshot. Missing/inactive actors and different-actor replays block; no fabricated identity or hosted account creation.

## File Structure

- Create `scripts/ops-v1-master-snapshot-contract.mjs` — canonical normalization, identities, Unit aliases, checksum and diagnostics.
- Create `scripts/ops-v1-master-snapshot-contract.test.mjs` — deterministic snapshot Vitest coverage.
- Create `scripts/extract-ops-v1-master-snapshot.mjs` — strict read-only extraction CLI writing one JSON file.
- Create `supabase/migrations/20260915153000_master_data_rehearsal_import.sql` — repeatable RMVP-01 preview/apply core.
- Create `supabase/tests/master_data_rehearsal_import.sql` — preview/apply, drift, absence, relationship removal, Unit and security tests.
- Create `supabase/migrations/20260915160000_master_data_rehearsal_recipe_import.sql` — Dish/Recipe/BOM extension.
- Create `supabase/tests/master_data_rehearsal_recipe_import.sql` — stable Recipe/BOM identity and successor tests.
- Create `scripts/master-data-rehearsal-report.mjs` and `.test.mjs` — deterministic reconciliation formatting.
- Create `scripts/run-local-master-data-rehearsal.mjs` and `.test.mjs` — local-only preview/apply runner.
- Modify `scripts/certify-supabase-full-integration.mjs` and `package.json`.
- Create `docs/runbooks/master-data-rehearsal-import.md`.

Do not modify the existing `atlas-staging-v1-reference-*` target-apply workflow in this implementation.

---

### Task 1: Canonical OPS v1 Snapshot Contract and Read-Only Extractor

**Files:**

- Create: `scripts/ops-v1-master-snapshot-contract.mjs`
- Create: `scripts/ops-v1-master-snapshot-contract.test.mjs`
- Create: `scripts/extract-ops-v1-master-snapshot.mjs`
- Modify: `package.json`

**Interfaces:**

- Consumes the approved read-only OPS v1 project and current master tables.
- Produces `buildOpsV1MasterSnapshotSql()`, `canonicalizeUnitSourceLabel()`, `normalizeOpsV1MasterSnapshot()`, `checksumOpsV1MasterSnapshot()`, and `extractOpsV1MasterSnapshot()`.
- CLI: `pnpm ops:v1:master:snapshot -- --output <path> --snapshot-id <id>`.

- [ ] **Step 1: Write failing Unit and stable-identity tests**

```js
expect(canonicalizeUnitSourceLabel("Kg")).toBe("kg");
expect(canonicalizeUnitSourceLabel("kg")).toBe("kg");
expect(canonicalizeUnitSourceLabel("Hủ")).toBe("Hũ");
expect(canonicalizeUnitSourceLabel("Hũ")).toBe("Hũ");
expect(() => canonicalizeUnitSourceLabel("123")).toThrow(/UNSUPPORTED_UNIT/);
expect(recipeLegacyId({ dishId: 1983, schoolTypeId: 1 })).toBe(
  "dish:1983:school-type:1",
);
```

Also assert `recipeLineLegacyId()` uses stable Recipe key + Ingredient ID and ignores BOM row ID.

- [ ] **Step 2: Run focused tests RED**

```bash
pnpm exec vitest run scripts/ops-v1-master-snapshot-contract.test.mjs
```

Expected: FAIL because the new contract module does not exist.

- [ ] **Step 3: Implement explicit Unit aliases**

```js
const UNIT_ALIASES = new Map([
  ["Kg", "kg"],
  ["kg", "kg"],
  ["Hủ", "Hũ"],
  ["Hũ", "Hũ"],
]);
```

Canonicalize NFC + trim first. Hash/code generation for count Units must use the canonical label, so `Hủ` cannot create a second Unit. Canonical `kg` uses the existing Atlas `kg / Kilogram` identity.

- [ ] **Step 4: Write failing source-SQL safety tests**

Assert extraction covers exactly these source relations: `schools`, `ingredient_type`, `ingredient_shopping_type`, `ingredients`, `suppliers`, `ingredient_suppliers`, `dish_types`, `dishes`, `recipes`, `bill_of_materials`.

Assert source fields include lifecycle/default/relationship facts (`contract_type`, `region_code`, `is_active`, `archived_at`, `contact_details`, `lead_time_days`, `default_priority`, `is_locked`, purchase Unit, BOM note and primary keys).

- [ ] **Step 5: Implement the read-only source guard and SQL**

Follow `scripts/atlas-staging-v1-reference-source.mjs`: require project `qnthofvccilhnefdcxnz`, role `supabase_read_only_user`, SELECT on all ten tables, and no INSERT/UPDATE/DELETE/TRUNCATE table privilege. Never invoke legacy functions.

- [ ] **Step 6: Write failing normalization/checksum tests**

Cover row-order-independent checksum, NFC/trim stability, derived School Types, canonical Unit union from Ingredient+BOM, explicit catalog IDs, Recipe key continuity across `recipes.id` churn, BOM line continuity across BOM-ID churn, inactive roots retained, and zero-BOM Recipe diagnostics.

- [ ] **Step 7: Implement normalized envelope and SHA-256**

```js
{
  contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
  source_system: "OPS_V1",
  snapshot_id,
  exported_at,
  extractor_version,
  complete_entities,
  records,
  source_counts,
  source_fingerprints,
  source_diagnostics,
  snapshot_checksum,
}
```

Sort every complete entity by stable migration identity before hashing. Exclude only `snapshot_checksum` from the checksum input.

- [ ] **Step 8: Implement file-only CLI and package script**

Require `--output` and `--snapshot-id`; write one immutable JSON file and never connect to Atlas. Add `"ops:v1:master:snapshot": "node scripts/extract-ops-v1-master-snapshot.mjs"`.

- [ ] **Step 9: Run focused tests GREEN and commit**

```bash
pnpm exec vitest run scripts/ops-v1-master-snapshot-contract.test.mjs
git add package.json scripts/ops-v1-master-snapshot-contract.mjs scripts/ops-v1-master-snapshot-contract.test.mjs scripts/extract-ops-v1-master-snapshot.mjs
git commit -m "feat(atlas): add read-only v1 master snapshot contract"
```

---

### Task 2: Repeatable RMVP-01 Preview/Apply Core

**Files:**

- Create: `supabase/migrations/20260915153000_master_data_rehearsal_import.sql`
- Create: `supabase/tests/master_data_rehearsal_import.sql`
- Modify: `scripts/certify-supabase-full-integration.mjs`

**Interfaces:**

- Consumes `OPS-V1-MASTER-SNAPSHOT.v1` from Task 1.
- Produces private `atlas_legacy.preview_master_data_snapshot(snapshot jsonb)` and `atlas_legacy.apply_master_data_snapshot(snapshot jsonb, expected_plan_checksum text, operator_actor_id uuid)`.
- Adds `last_seen_import_batch_id`, `last_source_fingerprint`, `last_target_version` to `atlas_legacy.master_data_mappings`.

- [ ] **Step 1: Write schema/security tests RED**

```sql
select has_column('atlas_legacy','master_data_mappings','last_seen_import_batch_id');
select has_column('atlas_legacy','master_data_mappings','last_source_fingerprint');
select has_column('atlas_legacy','master_data_mappings','last_target_version');
select has_function('atlas_legacy','preview_master_data_snapshot',array['jsonb']);
select has_function('atlas_legacy','apply_master_data_snapshot',array['jsonb','text','uuid']);
```

Prove `anon`, `authenticated`, and `service_role` cannot execute the functions or read private migration tables.

- [ ] **Step 2: Run database test RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/master_data_rehearsal_import.sql --local
```

- [ ] **Step 3: Add minimal repeatability evidence**

Add the three mapping columns, `last_seen_import_batch_id` FK, fingerprint-format checks, and only the batch metadata needed to bind snapshot contract/extractor version/complete entities/`plan_checksum`. Keep the existing batch/mapping tables; do not create parallel ETL tables.

- [ ] **Step 4: Write preview behavior tests RED**

Use one clean synthetic snapshot covering School Type, Customer, Location, School, Unit, Ingredient catalogs, Ingredient, Supplier and Supplier Eligibility. Assert preview writes zero rows and returns deterministic actions: `CREATE`, `UPDATE`, `NO_CHANGE`, `EXPLICIT_INACTIVATE`, `MISSING_FROM_SOURCE`, `REMOVE_RELATIONSHIP`, `TARGET_DRIFT`, `BLOCKED`, `SOURCE_ONLY_UNMAPPED`.

Also assert `123` blocks, `Kg`/`kg` yield one kilogram target, and `Hủ`/`Hũ` yield one `Hũ` target.

- [ ] **Step 5: Implement deterministic non-writing preview**

Preview must validate envelope/checksum/full-set declarations, resolve persistent mappings first, compare source fingerprints and target versions, sort the plan by object type + stable identity, and return a SHA-256 `plan_checksum` without any INSERT/UPDATE/DELETE.

- [ ] **Step 6: Write atomic apply/replay tests RED**

Assert wrong plan checksum, blocker, or target drift produces zero business writes. A clean apply creates facts/mappings atomically; exact replay creates no duplicates; later changed names/defaults/priorities update the same Atlas IDs; explicit inactive state uses normal lifecycle; missing roots are not auto-inactivated; removed Supplier Eligibility becomes INACTIVE, not deleted.

- [ ] **Step 7: Implement checksum-bound apply**

`apply_master_data_snapshot` must recompute preview internally, compare `expected_plan_checksum`, lock mapped targets in deterministic order, re-check target versions, then apply the whole accepted plan transactionally. Update last-seen/fingerprint/target-version evidence only after success.

Apply the approved source mapping exactly:

- Source School `N` owns migration identities `school:N:customer`, `school:N:delivery-location`, and School legacy ID `N`.
- Source School Type ID `1` maps to Atlas `v1-school-type-1 / TIỂU HỌC`; source ID `2` maps to `v1-school-type-2 / TRUNG HỌC`. Any new/ambiguous source School Type blocks until a reviewed mapping is added.
- Ingredient Type and Ingredient Shopping Type are initially resolved by the currently reviewed exact catalog names, then persisted by source numeric ID; later display-name drift does not create a second catalog mapping.
- Customer name = `school_full_name` falling back to `name`; School name = `name`; Delivery Location `address_text` = `delivery_info`.
- Preserve School defaults, `display_order`, School Type mapping and explicit active/inactive lifecycle. `region_code` is `SOURCE_ONLY_UNMAPPED`.
- `contract_type = 1` sets issuer `CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO`; `contract_type = 2` sets issuer `CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO`; any other value blocks. Use the accepted issuer address `ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam`.
- Ingredient legacy ID = source `ingredients.id`; preserve name, explicit lifecycle, Ingredient Type, Order Group, canonical purchase Unit and `order_step`; technical code is `v1-ingredient-<id>`.
- Supplier legacy ID = source `suppliers.id`; import name as ACTIVE current master truth and technical code `v1-supplier-<id>`. Preserve free-form `contact_details` only as `SOURCE_ONLY_UNMAPPED`; do not guess phone/email/name fields.
- Supplier Eligibility identity = `ingredient:<ingredient_id>:supplier:<supplier_id>`; map `default_priority`; retain non-null `lead_time_days` as `SOURCE_ONLY_UNMAPPED`.

- [ ] **Step 8: Prove Unit canonicalization in apply tests**

After apply, require exactly one active `unit_code = 'kg'`. Raw `Hủ` and `Hũ` fixture Ingredients must reference one canonical `Hũ` `unit_id`. The importer must create no new active `Hủ` Unit. Do not mutate the current hosted Staging `Hủ` row in this task; hosted cleanup remains separately authorized.

- [ ] **Step 9: Add the pgTAP file to full integration ordering**

Insert `master_data_rehearsal_import.sql` immediately after `rmvp_01_atlas_master_data.sql` in `DATABASE_TESTS_BEFORE_BROWSER`.

- [ ] **Step 10: Run targeted inherited tests GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/rmvp_01_atlas_master_data.sql --local
pnpm exec supabase test db supabase/tests/master_data_rehearsal_import.sql --local
pnpm local:rmvp01:verify
```

- [ ] **Step 11: Commit Task 2**

```bash
git add supabase/migrations/20260915153000_master_data_rehearsal_import.sql supabase/tests/master_data_rehearsal_import.sql scripts/certify-supabase-full-integration.mjs
git commit -m "feat(atlas): add repeatable master-data rehearsal import core"
```

---

### Task 3: Dish, Recipe and BOM Current-State Import

**Files:**

- Create: `supabase/migrations/20260915160000_master_data_rehearsal_recipe_import.sql`
- Create: `supabase/tests/master_data_rehearsal_recipe_import.sql`
- Modify: `scripts/certify-supabase-full-integration.mjs`

**Interfaces:**

- Extends the same Task 2 preview/apply functions; do not add another public importer.
- Stable Recipe legacy key: `dish:<dish_legacy_id>:school-type:<school_type_legacy_id>`.
- Stable line legacy key: `recipe:<stable recipe key>:ingredient:<ingredient_legacy_id>`.

- [ ] **Step 1: Write Recipe row-ID churn tests RED**

Import one Dish with two typed Recipe roots, then replay a snapshot with changed source `recipes.id` and BOM row IDs but identical canonical composition. Assert the same Atlas `recipe_id` and current `recipe_version_id` remain; row-ID churn alone creates no successor.

- [ ] **Step 2: Implement stable Recipe/BOM key helpers**

Current source Recipe/BOM row IDs become source evidence only. Persist mapping keys using the stable business identities above.

- [ ] **Step 3: Write current-source semantics tests RED**

Cover `is_general=true` not creating GENERAL roots, source `is_locked=true` not importing fake Atlas LOCKED history, fixed basis = 100, unknown typed references blocking, zero-line Recipe blocking, non-positive quantity blocking, and duplicate Recipe+Ingredient blocking.

- [ ] **Step 4: Implement Dish/Recipe preview planning**

Dish Type resolves only by the approved mapping: source `1 ? soup`, `2 ? savory`, `3 ? stir_fry`, `4 ? dessert`, `5 ? afternoon_snack`, `6 ? beverage`. Any other source Dish Type blocks. Dish uses source `dishes.id` and code `v1-dish-<id>`. Recipe lookup resolves persistent stable-key mapping first; if absent, it may reuse only an exact importer-owned/uncommitted `(dish_id, school_type_id)` root. Never merge by name.

- [ ] **Step 5: Write composition-change successor tests RED**

From an imported `RELEASED_FOR_PLANNING` version, import a later snapshot that changes one quantity, removes one Ingredient and adds one Ingredient. Assert Recipe root unchanged, exactly one successor version, predecessor preserved, removed Ingredient gets `REMOVED` revision, new Ingredient gets a stable line/revision, and prior immutable evidence remains readable.

- [ ] **Step 6: Implement migration materialization through RMVP-02A invariants**

Set `source_evidence.source_kind = "OPS_V1_MASTER_SNAPSHOT"` with source system, snapshot ID/checksum, stable Recipe key and current source Recipe row ID. Materialize valid current BOM facts and release the imported current version for Planning without fabricating legacy author/editor audit history.

- [ ] **Step 7: Write committed-use lock test RED**

Create approved Weekly Menu snapshot evidence for the Dish, then preview a changed Recipe composition. Expected: `BLOCKED` before any Recipe/version/line write.

- [ ] **Step 8: Reuse the existing committed-use lock**

Use the existing authoritative approved-Menu/Dish lock boundary; do not add a parallel persisted flag.

- [ ] **Step 9: Add pgTAP ordering and run targeted tests GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql --local
pnpm exec supabase test db supabase/tests/master_data_rehearsal_import.sql --local
pnpm exec supabase test db supabase/tests/master_data_rehearsal_recipe_import.sql --local
pnpm local:rmvp02a:verify
```

- [ ] **Step 10: Commit Task 3**

```bash
git add supabase/migrations/20260915160000_master_data_rehearsal_recipe_import.sql supabase/tests/master_data_rehearsal_recipe_import.sql scripts/certify-supabase-full-integration.mjs
git commit -m "feat(atlas): extend rehearsal import to recipes and BOM"
```

---

### Task 4: Local Rehearsal Runner and Reconciliation Report

**Files:**

- Create: `scripts/master-data-rehearsal-report.mjs`
- Create: `scripts/master-data-rehearsal-report.test.mjs`
- Create: `scripts/run-local-master-data-rehearsal.mjs`
- Create: `scripts/run-local-master-data-rehearsal.test.mjs`
- Modify: `package.json`
- Create: `docs/runbooks/master-data-rehearsal-import.md`

**Interfaces:**

- Consumes normalized snapshot JSON and local Supabase only.
- Produces `formatMasterDataRehearsalReport(result)`, preview/apply CLI, and deterministic JSON/text reconciliation.

- [ ] **Step 1: Write report tests RED**

Require stable sections: Snapshot, source counts, action counts by entity, blockers, target drift, missing roots, relationship removals, source-only unmapped, Unit canonicalization, Recipe/BOM completeness and Gate.

- [ ] **Step 2: Implement deterministic report formatter**

Gate values are exactly `REJECTED`, `REHEARSAL_ACCEPTED`, or `CUTOVER_READY`. A synthetic fixture alone can never justify `CUTOVER_READY`.

- [ ] **Step 3: Write runner guard tests RED**

Assert default mode is preview-only; `--apply` requires an explicit flag and local Supabase proof; hosted refs are rejected; runner always previews first; apply submits the exact returned plan checksum; post-apply preview/readback must reconcile; exact replay is allowed.

- [ ] **Step 4: Implement local-only runner**

Follow the temp-SQL pattern in `scripts/import-local-master-data-snapshot.mjs` and `runPinnedSupabase`.

```bash
pnpm local:master-data:rehearsal:preview -- --file C:/secure/rehearsal/ops-v1-master.json
pnpm local:master-data:rehearsal:apply -- --file C:/secure/rehearsal/ops-v1-master.json --apply --actor-id <existing-active-Atlas-actor-UUID>
```

The runner accepts only an explicit file and never fetches live OPS itself.

- [ ] **Step 5: Add package scripts**

```json
"local:master-data:rehearsal:preview": "node scripts/run-local-master-data-rehearsal.mjs",
"local:master-data:rehearsal:apply": "node scripts/run-local-master-data-rehearsal.mjs --apply"
```

Add new scripts/docs to the explicit formatting manifest where required.

- [ ] **Step 6: Write Rehearsal A runbook**

The runbook sequence is fixed:

```text
1. verify clean exact repo commit
2. start/reset disposable local Supabase without seed
3. extract read-only OPS v1 full snapshot to local ignored path
4. preview only
5. inspect blockers/reconciliation
6. apply only if zero blockers/drift
7. replay exact snapshot
8. verify stable IDs/no duplicates
9. run RMVP-01/RMVP-02A reads
10. preserve report, not raw credentials/secrets
```

State that current `Deact Test` / Unit `123` evidence is expected to make the current live snapshot preview `REJECTED` until source data is corrected. Filtering the bad rows is prohibited.

- [ ] **Step 7: Run focused runner/report tests GREEN**

```bash
pnpm exec vitest run scripts/master-data-rehearsal-report.test.mjs scripts/run-local-master-data-rehearsal.test.mjs
```

- [ ] **Step 8: Commit Task 4**

```bash
git add package.json scripts/master-data-rehearsal-report.mjs scripts/master-data-rehearsal-report.test.mjs scripts/run-local-master-data-rehearsal.mjs scripts/run-local-master-data-rehearsal.test.mjs docs/runbooks/master-data-rehearsal-import.md
git commit -m "feat(atlas): add local master-data rehearsal runner"
```

---

### Task 5: Full Local Certification and Rehearsal-A Evidence

**Files:**

- Modify only when a certification failure identifies a bounded defect in Tasks 1-4.
- Never commit the raw OPS v1 snapshot.

**Interfaces:**

- Consumes the exact implementation branch plus an explicit local snapshot file.
- Produces fresh local certification and reconciliation evidence; no hosted mutation.

- [ ] **Step 1: Run all new Vitest tests**

```bash
pnpm exec vitest run scripts/ops-v1-master-snapshot-contract.test.mjs scripts/master-data-rehearsal-report.test.mjs scripts/run-local-master-data-rehearsal.test.mjs
```

- [ ] **Step 2: Run targeted database tests from a fresh reset**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/rmvp_01_atlas_master_data.sql --local
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql --local
pnpm exec supabase test db supabase/tests/master_data_rehearsal_import.sql --local
pnpm exec supabase test db supabase/tests/master_data_rehearsal_recipe_import.sql --local
```

- [ ] **Step 3: Run inherited acceptance and full Supabase certification**

```bash
pnpm local:rmvp01:verify
pnpm local:rmvp02a:verify
pnpm certify:supabase:full-integration
```

Do not reduce coverage, assertions or timeouts to make certification pass.

- [ ] **Step 4: Extract current live source read-only**

```bash
pnpm ops:v1:master:snapshot -- --snapshot-id ops-v1-master-rehearsal-a --output <local-ignored-path>/ops-v1-master.json
```

Verify source counts and read-only role proof. Do not commit the snapshot.

- [ ] **Step 5: Preview current Rehearsal A**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm local:master-data:rehearsal:preview -- --file <local-ignored-path>/ops-v1-master.json
```

With current source facts, expected gate is `REJECTED` because Recipe `3362` has no BOM and Unit token `123` is invalid. That is correct fail-closed behavior, not an importer failure.

- [ ] **Step 6: Prove clean synthetic apply/replay separately**

Run a clean full synthetic snapshot twice and verify stable School/Ingredient/Supplier/Dish/Recipe IDs, no duplicate facts, one active `kg`, one canonical `Hũ` for both source spellings, and zero operational-table population.

- [ ] **Step 7: Run repository hygiene checks**

```bash
pnpm exec prettier --check package.json scripts/ops-v1-master-snapshot-contract.mjs scripts/ops-v1-master-snapshot-contract.test.mjs scripts/extract-ops-v1-master-snapshot.mjs scripts/master-data-rehearsal-report.mjs scripts/master-data-rehearsal-report.test.mjs scripts/run-local-master-data-rehearsal.mjs scripts/run-local-master-data-rehearsal.test.mjs docs/runbooks/master-data-rehearsal-import.md docs/superpowers/specs/2026-09-15-master-data-rehearsal-import-design.md docs/superpowers/plans/2026-09-15-master-data-rehearsal-import.md
git diff --check
```

Expected: PASS.

- [ ] **Step 8: Commit only certification-driven fixes, if any**

If certification required no code change, do not create an empty commit. If a defect is found, fix only that bounded defect, add its regression test, rerun the failed gate, then commit the smallest change.

- [ ] **Step 9: Stop before hosted Staging**

Final local implementation gate:

```text
MASTER_DATA_REHEARSAL_IMPORT_LOCALLY_CERTIFIED
NEXT_GATE: EXPLICIT_AUTHORIZATION_FOR_HOSTED_STAGING_REHEARSAL
```

Do not write Atlas Staging, configure the real Google Weekly Menu source, freeze OPS v1 master data, or perform final cutover in this plan.

---

## Plan Self-Review Checklist

- Every approved spec requirement has an implementation/test task.
- Unit rules are exact: `Kg`/`kg` → one `kg`; `Hủ`/`Hũ` → one `Hũ`; `123` → blocker.
- Stable Recipe identity never uses `recipes.id`.
- Stable Recipe Line identity never uses BOM row ID.
- Full-snapshot blockers prevent partial writes.
- Root absence is non-destructive.
- Supplier/BOM relationship removals create explicit inactive/REMOVED history, never physical deletes.
- Preview is non-writing and checksum-bound to apply.
- Target drift is fail-closed.
- No public migration API is introduced.
- No operational-history migration is included.
- Rehearsal A is local/disposable only.
- Hosted Staging and final cutover remain separate authorization gates.
