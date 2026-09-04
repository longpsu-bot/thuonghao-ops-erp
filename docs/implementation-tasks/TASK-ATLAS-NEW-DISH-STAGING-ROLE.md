# Atlas new-dish UX and Staging testing-role package

Status: local bounded implementation; Identity proposal unapplied.

Baseline: `a398c22d7ed2846deb9c06d56cd8fa03056ef84f` on verified branch `codex/atlas-new-dish-staging-role`. Authority: explicit task approval, ARCH-002 / OPS_SYSTEM_MAP v1.0, D-038, RMVP-02A.v1/v2, and RMVP-02B.v1.

## Scope and findings

Only the Admin Dish/Recipe workbench, its focused tests, the Staging Identity manifest/installer/package tests, and affected documentation change. No migration, API contract, new capability, lifecycle, calculation, RLS, Planning/Procurement behavior, Warehouse work, hosted write, deployment, live OPS, or Retool change is authorized.

Local component reproduction uses the review adapter with an authoritative-style lock readback for the existing selected Dish. It demonstrated:

- Catalog `Xem` changed the Dish heading without loading its Recipe context, so creation could display another Dish's composition and lock warning.
- Opening `Tạo món mới` left the previous locked Recipe editor and warning beside the new-dish form.
- Starting a new Dish bypassed the dirty Recipe context confirmation.

Catalog selection now refreshes the complete context before changing the selected identity. The new-dish drawer temporarily replaces the prior Recipe editor with guidance; cancel retains that identity and its lock and clears the creation error. Beginning a new Dish asks before replacing dirty Recipe work. Successful creation clears the old search filter so the created selection remains visible. Focused regressions also reproduced the hidden new selection under the old filter and the duplicate-code notice persisting after cancel before fixing them.

The existing `create_dish` command and selection handoff are retained. Tests cover both `affected_aggregate_ids.dish_id` and the legacy returned-Dish fallback, then the new identity's initial `save_recipe`. The latest `create_dish` migration checks normalized-code uniqueness and returns `CONFLICT`; it does not check approved-Menu use. The duplicate-code response stays distinct from the prior Dish's operational lock, retains the entered form, and does not invoke Recipe Save. No new backend defect was demonstrated; this is local component/contract evidence, not a hosted rehearsal or new database integration certification.

## Unapplied Identity 1.1.0 proposal

Keep schema version 1 and the `.v1.json` filename. Advance package version and Auth `managed_by` marker from 1.0.0 to 1.1.0. Preserve all 17 prior capability bindings, Actor, Auth identity, role, membership, and the single existing GLOBAL scope. Append only:

| Existing capability                    | Deterministic role-capability ID       |
| -------------------------------------- | -------------------------------------- |
| `master_data.recipe_adjustments.read`  | `a1010000-0000-4000-8000-000000000027` |
| `master_data.recipe_adjustments.write` | `a1010000-0000-4000-8000-000000000028` |

The installer allowlist and exact count become 19; unsupported package versions and inconsistent managed-version markers fail validation. Generated reconciliation remains insert-if-absent and requires existing active capability catalog entries. It creates no capability and deletes or updates no database grant. Matching old bindings replay; missing new bindings are inserted; unexpected bindings/scope/content fail closed. Verification requires the exact 19-grant set. All unrelated roles and grants remain outside the package.

This task explicitly amends the adjustment-capability omission in the historical HOSTED-PLANNING-REHEARSAL-01A package record. Foundation remains unchanged at 1.1.0. Existing Planning correction capabilities remain granted; released-PO correction remains contractually blocked. Recipe adjustment permission does not reopen normal base editing or rewrite released operational snapshots.

Applying this package requires a separate authorized hosted action after review/merge and the existing exact-commit/environment gates. No installer, deployment, or hosted verification command was executed here. Before any future application, review the actual hosted binding identities for exact-match compatibility.

## Acceptance and validation

- Locked Dish → new form → `create_dish` → new identity → initial Recipe Save.
- Duplicate-code failure retains the form without presenting the prior operational lock as the creation failure.
- Cancel restores the existing lock; existing locked Recipe Save remains disabled.
- Catalog navigation aligns Dish/composition/lock; dirty context/tab/new-dish cancellation preserves edits.
- Manifest, allowlist, version handling, generated SQL, and exact-set verification agree while preserving prior grants and scope.

Focused command: `pnpm exec vitest run src/modules/admin/DishRecipeAdminWorkbench.test.tsx scripts/atlas-staging-package.test.mjs`.

Results: the initial regression run failed for the stale lock/form context, catalog selection, missing dirty guard, and old package version. The final run included the two focused files plus `recipeApi.test.ts` and `recipeModel.test.ts`: **44 tests passed across 4 files**. Changed-file Prettier and `git diff --check` passed. A structural comparison against reviewed main confirmed that every prior Identity field and all 17 bindings are unchanged apart from the two version markers and two appended grants. Validation used local component adapters and generated SQL tests, with no database reset or hosted execution.

Broad frontend validation belongs to `Frontend CI / Format, typecheck, test, build`; no full Windows integration rerun is required by this diff.

## Security, migration, and rollback

No schema migration or backend authorization change. Existing backend capability, scope, concurrency, idempotency, approved-Menu locks, and released-history protections remain authoritative. The package grants only the two existing reviewed testing capabilities to the same synthetic role.

Before application, rollback is a source revert. After a separately authorized application, reverting the manifest alone does not revoke grants: reconciliation is insert-only and the old exact-set verifier would reject 19 bindings. Revocation of precisely the two added bindings would require a separately reviewed and authorized procedure preserving business/audit history. No such rollback is executed or automated here.
