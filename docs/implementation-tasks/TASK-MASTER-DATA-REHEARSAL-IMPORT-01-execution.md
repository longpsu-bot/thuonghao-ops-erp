# MASTER-DATA-REHEARSAL-IMPORT-01 — Execution record

**Approved design baseline:** `fc5b3a002ea660f90f3fdd06282c4bf74fef067b` (#290).
**Implementation branch / Draft PR:** `feat/master-data-rehearsal-import-01` / #292.
**Status:** Tasks 1–4 implemented and focused checks passed; full exact-head certification and real-source rehearsal status are recorded below as they become available.

## Task 1 — immutable source contract

Added `ops-v1-master-snapshot-contract.mjs`, its tests, and the explicit source-export CLI. The fixed query reads only the ten approved OPS v1 master relations. Source IDs and exact decimal quantities are selected as text. It requires dedicated read-only role/table-privilege and unfiltered-source proof. It changes no source role, grant, RLS setting or business data.

Normalization preserves inactive roots and invalid records for explicit diagnostics. Recipe identity is Dish + School Type, line identity is Recipe + Ingredient. Physical source-row churn remains evidence but does not change business fingerprints. The reviewed Unit aliases converge `Kg`/`kg` to `kg` and `Hủ`/`Hũ` to `Hũ`; invalid tokens such as `123` remain blockers.

TDD evidence: missing-contract RED → 18 GREEN; file-export RED 2 → 20 GREEN; integrity RED 3 → 23 GREEN. Inherited source/local-status tests add 34, for 57 affected tests passed at the Task 1 checkpoint. Source-export tests use synthetic data.

## Approved execution-Actor correction

The Product Owner approved the explicit private signature:

```sql
atlas_legacy.apply_master_data_snapshot(
  snapshot jsonb,
  expected_plan_checksum text,
  operator_actor_id uuid
)
```

The Actor is required execution context outside the immutable source snapshot. The backend validates an existing ACTIVE Atlas Actor and stores actual attribution, database principal and execution time. Missing/inactive Actors and different-Actor exact replay fail closed. No Actor is guessed from the SQL role and no hosted Auth account or synthetic operator is created or borrowed.

## Task 2 — repeatable core

Added one version-controlled migration and pgTAP suite. Extended the existing typed crosswalk with catalog/eligibility FKs and the three planned continuity fields. Full target fingerprints, including non-versioned Units/catalogs, are stored in the existing batch reconciliation receipt rather than a new ETL table.

Implemented deterministic non-writing preview, exact checksum/Actor-bound atomic apply, preserved root identity, explicit inactive relationship removal, non-destructive root absence, external target-drift detection and authoritative post-write readback.

TDD evidence: initial schema RED 8/9 failed as intended; 47 new core assertions GREEN. Inherited RMVP-01 plus core: 90/90 PASS. Tests ran only on the disposable local project.

## Task 3 — Dish / Recipe / BOM

Added a second migration and Recipe suite. Current Recipes materialize through existing immutable lifecycle and line-revision constraints with actual import attribution. Source `is_locked` is never copied into fictitious Atlas history.

A changed source physical ID alone creates no version. Composition changes create one successor with exact prior-version and line-revision links. Removed lines are explicit zero-quantity REMOVED revisions. Tombstones are retained through successive corrections so later reintroduction preserves stable line identity. The existing approved-Menu Dish-use predicate blocks base changes; locks also serialize actual commitment evidence.

TDD evidence: initial full Recipe snapshot RED → 30 GREEN; correction/reintroduction and invalid-data coverage extended the Recipe suite to 37 assertions. Core + Recipe + inherited RMVP-02A: 126/126 PASS. A self-review found that source Dish Type IDs could be supplied with contradictory catalog codes; a dedicated regression failed before the correction and passed afterward. That regression is included in the final Recipe suite.

## Task 4 — local runner and reporting

Added explicit local preview/apply runner, deterministic text/JSON reporting, focused tests and a runbook. The runner requires `SUPABASE_WORKDIR`, exact disposable project `atlas-master-rehearsal-01`, loopback API/DB proof, an immutable input file, and an explicitly reviewed plan checksum plus Actor for apply. It creates no identity/account and has no hosted execution mode.

Preview success is reported as `NOT_APPLIED`, never as migration acceptance. Only actual apply plus authoritative readback yields `REHEARSAL_ACCEPTED`. The runner never grants `CUTOVER_READY`. Human text reports omit raw free-form contact values; machine-readable reports remain private master-data evidence.

TDD evidence: missing runner/report modules RED → 10 GREEN. Actual CLI rehearsal exposed the pinned Supabase CLI's array response rather than the older `rows` envelope. Two decoder regressions failed before the correction and passed afterward. Final runner/report count: 12 tests passed.

## Actual disposable CLI rehearsal

The independent local project uses ports 553xx and a separate Supabase work directory; the existing `thuonghao-ops-erp` stack remains untouched. Its migrations/tests point at this exact implementation worktree.

Executed the real preview/apply/readback/replay runner against a clean full synthetic master snapshot, not mocked SQL. Explicit synthetic fixture Actor: `aa920000-0000-4000-8000-000000000001`.

The first apply returned `COMPLETED` and reconciled; replay returned `REPLAYED` and reconciled. Authoritative counts after both commands: 1 School, 4 Ingredients, 1 Dish, 2 typed Recipes, 2 Recipe Versions, 3 line revisions, 1 import batch. Weekly Menus = 0 and Need Generation runs = 0. No duplicate root/version appeared on replay. Private local JSON/text evidence is retained outside Git.

This certifies synthetic behavior only; it is not a real OPS v1 source rehearsal.

## Real source and hosted boundary

The approved real-source route is GitHub Actions rather than a copied local secret. `.github/workflows/atlas-master-data-rehearsal-validate.yml` is manual-only, uses the existing `atlas-staging` environment solely to access `ATLAS_STAGING_SUPABASE_ACCESS_TOKEN`, verifies the requested checkout is exact current `origin/main` before dependency installation or repository-code execution, and injects the secret only into the read-only extraction step.

The workflow writes the raw snapshot only under `RUNNER_TEMP`, never uploads it, deletes it during final cleanup, starts a disposable local Supabase target, and executes preview only. It contains no apply flag, Atlas Staging target reference, deploy command, Google-source configuration, or hosted database mutation. The workflow cannot be used until its definition and importer are present on current `main`; that preserves the existing secret boundary against unmerged branch code.

Until that workflow runs successfully on a certified current-main commit, do not claim a real-source snapshot, current full reconciliation, or cutover readiness from synthetic evidence. Shared Staging remains excluded from all apply commands.

## Safety

- Live OPS v1 business/schema writes: zero.
- Retool writes: zero.
- Atlas Staging writes: zero.
- Executable migrations applied only to the disposable local database.
- Existing local main stack not reset, stopped or mutated by the importer.
- No operational-history import, released-fact rewrite or Google-source configuration.
- PR #286 and documentation PR #290 not changed or merged.
- Implementation changes remain on Draft PR #292; no merge is authorized.
