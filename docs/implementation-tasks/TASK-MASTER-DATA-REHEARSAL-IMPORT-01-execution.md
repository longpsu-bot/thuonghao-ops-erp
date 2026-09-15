# MASTER-DATA-REHEARSAL-IMPORT-01 — Task 1 Execution Checkpoint

**Approved baseline:** `fc5b3a002ea660f90f3fdd06282c4bf74fef067b` (Draft PR #290).
**Implementation branch:** `feat/master-data-rehearsal-import-01`.
**Status:** Task 1 implemented. The Product Owner approved the explicit `operator_actor_id` amendment; Task 2 core preview/apply now passes its local database tests. Recipe extension, runner and full certification remain in progress.

## Completed scope

The read-only extractor covers only the ten source relations listed in the approved plan. One fixed SELECT returns the source facts and read-only access proof from the approved OPS v1 project. The transport rejects redirection, unexpected source projects, missing full-source arrays, and insufficient evidence of complete read-only access. Existing read-only bypass-RLS access is checked for completeness; the extractor changes no role, privilege, policy or RLS setting.

Source bigint identifiers and exact decimal quantities are selected as text. Normalization preserves inactive rows and reports invalid or missing references rather than filtering them. Recipe and BOM physical row IDs remain evidence; durable migration keys use Dish + School Type and Recipe + Ingredient respectively. Business fingerprints ignore physical Recipe/BOM row-ID churn, while the immutable snapshot checksum retains that changed evidence.

The approved aliases `Kg`/`kg` converge to `kg`; `Hủ`/`Hũ` converge to `Hũ`. Raw-to-canonical aliases remain explicit evidence. Unknown values, including `123`, remain blockers. Nothing edits current Atlas Unit records.

The CLI requires an explicit snapshot ID and output path, refuses to overwrite an existing file before fetching, verifies the snapshot checksum, and removes a partial output on a handled failure. It returns only counts/checksum/diagnostic totals to the console. It neither reads nor writes an Atlas target.

## Files implemented

- `scripts/ops-v1-master-snapshot-contract.mjs`
- `scripts/ops-v1-master-snapshot-contract.test.mjs`
- `scripts/extract-ops-v1-master-snapshot.mjs`
- `package.json` — one extraction command and explicit format coverage; no dependency change.

## Verification evidence

- Existing source/local-status baseline: 2 files, 34 tests passed.
- Initial contract RED: expected missing contract module.
- First GREEN: 18 contract tests passed.
- File-export RED: 2 expected missing-CLI failures, 18 tests passed.
- File-export GREEN: 20 tests passed.
- Integrity RED: 3 failures for physical duplicate IDs, unfiltered source proof and alias evidence, 20 tests passed.
- Final focused GREEN: 3 files, 57 tests passed (23 new, 34 inherited).
- Changed-file Prettier and `git diff --check`: passed.
- All new fetch/normalization/export tests use synthetic data. No real OPS v1 full export, local database apply, or end-to-end rehearsal has been executed.
- Exact-head GitHub CI status is recorded separately in the implementation PR; local focused tests are not a substitute for the required CI gate.

## Execution-attribution omission — resolved by explicit Product approval

The approved plan currently defines:

```sql
atlas_legacy.preview_master_data_snapshot(snapshot jsonb)
atlas_legacy.apply_master_data_snapshot(snapshot jsonb, expected_plan_checksum text)
```

Neither the plan nor the snapshot contract specifies an Atlas execution actor. However, `20260719140821_pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql` requires non-null `recipe_versions.created_by_actor_id` and `recipe_line_revisions.created_by_actor_id`, with foreign keys to `atlas_core.actors`. Validation/release require corresponding actor and timestamp evidence. SQL role `postgres` alone does not identify an Atlas business actor.

The existing RMVP-02B private adjustment importer explicitly validates `imported_by_actor_id` against an ACTIVE Atlas actor. This proves the attribution requirement is intentional; it does not authorize guessing an actor for the new importer. A staging synthetic operator must not be silently reused as a real migration actor.

Recommended amendment, not implemented: keep the immutable source snapshot independent of the target and add a required private execution context to apply, including an explicit existing active Atlas `operator_actor_id`. Validate that context server-side under the privileged operator boundary, persist the actor with actual execution time/database principal, and bind replay semantics to that context. Preview remains non-writing and does not require invented target identities. Local tests may provision an explicitly synthetic fixture actor in a disposable target; no hosted Auth user or actor is created by this task.

The exact parameter/envelope and retry binding must be approved and added to the spec/plan before database-write implementation. No existing lifecycle check or foreign key may be weakened to work around the omission.

## Preserved boundaries

- Live OPS v1 writes: zero.
- Retool writes: zero.
- Atlas Staging writes: zero.
- No database migration created or applied.
- No existing local Supabase stack reset/stopped; the pre-existing stack remains outside this checkpoint.
- No operational-history import, released-fact rewrite, real Google-source configuration, or cutover.
- Original parent checkout working files unchanged; work is isolated in the task worktree.
- PR #286 and documentation PR #290 are not modified or merged by this checkpoint.

**Gate:** `TASK_1_IMPLEMENTED — IMPORT_EXECUTION_ACTOR_CONTRACT_REQUIRED`.

## Task 2 progress

- Added the approved actor-bound private apply signature; no actorless overload. Missing/inactive Actors and different-Actor replay are rejected.
- Added typed catalog/eligibility mappings and the three planned mapping-evidence fields.
- Non-versioned drift fingerprints are stored in the existing batch reconciliation receipt; no separate ETL schema/table was added.
- Implemented deterministic non-writing preview, actor-bound atomic apply, stable root identity, non-destructive root absence, explicit inactive relationship removal and authoritative readback.
- RED: 8/9 schema assertions failed before the migration. GREEN: 47 new pgTAP assertions; inherited RMVP-01 + core total 90/90 passed.
- Tests run against disposable local project `atlas-master-rehearsal-01`, ports 553xx, in a separate Supabase work directory. The original `thuonghao-ops-erp` stack is not reset or stopped.
- The core deliberately rejects nonempty Recipe/Dish data until the Task 3 extension is installed. This is not yet a complete importer certification.

## Task 3 progress

- Replaced the core fail-closed Recipe extension hooks with typed Dish/Recipe/current-BOM planning and materialization.
- Explicit source-row-ID churn creates no successor; quantity/membership change produces one immutable successor with exact line predecessors. Removed-line tombstones continue through intermediate corrections so reintroduction retains stable identity.
- Uses the existing approved-Menu Dish-use predicate and actual lifecycle/lineage constraints. Locks also protect concurrent approval-snapshot insertion; no new persisted lock flag or operational fact.
- Current imported versions validate/release with the explicitly supplied Actor and truthful import source evidence; v1 `is_locked` is not imported.
- RED: unsupported full Recipe snapshot failed the intended assertion. GREEN: 37 new Recipe pgTAP assertions. New core + Recipe + inherited RMVP-02A total: 126/126 PASS.
- Import runner and full real-source rehearsal/certification have not yet run at this checkpoint.
