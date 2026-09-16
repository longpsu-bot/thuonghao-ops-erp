# ATLAS-STAGING-MASTER-LOAD-01

## Authorized outcome

Owner instruction 16/09/2026: complete the current OPS v1 master/reference copy into shared Atlas Staging for replacement testing now, while v1 remains live and staff continue correcting it. This extends the previous local-only runner boundary; it does not authorize production cutover, PR #286, v1 writes, Retool writes or importing operational history.

## Implementation boundaries

1. Finish the pending reviewed source decisions on `fix/master-data-owner-decisions-01`: preserve distinct typed Dishes/Recipes, exclude the exact Deact Test roots with scope guards, set null School defaults to zero, retain the explicit Ingredient 903 correction and canonical Units.
2. Certify and merge repository changes; deploy only repository migrations to the exact approved Staging project using the existing protected workflow.
3. Add a Staging-only GitHub load command, dry-run by default and requiring explicit apply/target confirmation. Source extraction reuses the proven read-only endpoint; target writes use only `rnzxmxiiqgtdevzregff` from certified current main.
4. Adopt the previous reference-import roots by the old namespace UUID + exact source-derived code and relationship identity, not display-name matching. Preserve their existing Atlas IDs. Store the observed pre-import values and fingerprints in a private adoption receipt. Any conflicting unmanaged identity blocks.
5. Generate one truthful MIGRATION Actor for this technical GitHub import package. It has no Auth subject, login, roles or capabilities. The existing private apply still receives and validates that existing active Actor explicitly. Do not impersonate the synthetic HUMAN operator.
6. Preview preparation uses a rolled-back subtransaction: no committed mappings, Actor or business writes. Apply uses the same preparation and exact preview checksum in one transaction, preserving drift/concurrency guards. Reconcile and replay the same snapshot.
7. Canonicalize current Ingredient references through the normal importer; inactivate only the reviewed misspelled Hủ catalogue row once no current Ingredient refers to it. Retain immutable operational references and old Unit history.
8. Preserve all unrelated Staging fixtures, Auth/permissions and operational transactions. Capture and compare operational row counts/fingerprints before and after the import. No reset, truncate, broad delete or cascading cleanup now.
9. Verify source/target quantities, identity counts and the actual authenticated Atlas master/Planning read APIs. Expose the current catalogue for testing without authoring Menu/Attendance/PO/PXK transactions as part of the copy.

## Tests and acceptance

Focused JS tests cover normalization and typed parsing plus the new Staging command's exact-target/main/apply/checksum protections. A transactional pgTAP test covers adoption identity, retained unrelated rows, preview rollback, initial apply/replay, canonical Units and drift rejection. Required exact-head Frontend CI and Supabase Full Integration must pass; smoke alone is not full integration.

Completion means the hosted master-data import is committed, independently read back, repeatable, and visible through the authenticated Atlas reads. A green disposable preview alone is not completion.

## Later final refresh

Keep this Staging database explicitly a rehearsal environment. A final fresh v1 snapshot and retirement of the specific rehearsal-authored dependent facts must be reviewed before production replacement. Existing approved Menu/Recipe commitments are not bypassed by this importer. There is no unrestricted CASCADE or reset command in this task.

## Recorded execution

Baseline: `69e84be7d86b22fa913f84d6895d9189fd9e919e`.
Pre-load hosted state: 73 migrations, zero new-importer mappings; 34 Schools, 360 Ingredients, 37 Suppliers, 828 eligibilities, 2 Dishes and 3 Recipes. Only the existing synthetic HUMAN operator is present before package preparation.
Results are appended after exact-head certification and hosted execution.

### Pre-push verification

- Focused JavaScript: 170/170 passed, eight files including original Staging authority regression.
- New existing-reference/adoption package pgTAP: 23/23 passed.
- Existing master/Recipe plus full physical security-catalog pgTAP: 113/113 passed.
- Source corrections retain their earlier RED/GREEN evidence; hosted runner and workflow failed before implementation, and the SQL package demonstrated the expected missing-adoption fingerprint failures before its additive compatibility migration.
- The integration command assertion is now exactly 92 (91 existing + one new package test); no prior command was removed. Full Integration is required in GitHub before deployment.
- No hosted write has occurred at this pre-push checkpoint.

### Full-source transport correction

The first hosted preview (`35057598020`) stopped with Management API HTTP 413 before target execution. Schema deployment succeeded separately (`35057526128`), bringing Staging to 78 repository migrations; master mappings remain zero. Synthetic payloads did not exercise the actual request size.

The target now uses PostgreSQL wire transport through the exact CLI-linked Staging session pooler, preserving the same session-local SQL, preview rollback, checksum-bound apply and readback. The source still uses the Management API read-only endpoint and protected PAT. The already-existing protected database password remains inside GitHub Actions, never a process argument or log. SQL is streamed to `psql` stdin. TLS uses `verify-full` with the system roots plus the publicly distributed Supabase CA, downloaded by HTTPS and SHA-256 pinned. There is no automatic HTTP fallback, chunked partial apply, retry on uncertain writes, new database object or changed migration rule.

Focused transport/regression checks: 118/118 passed (4 new tests include a 3 MiB SQL payload, wrong-target/link rejection, secret-safe error handling and TLS/argument safety). Required GitHub certification follows on the transport-fix PR. No further hosted master write has occurred at this checkpoint.

## APPLY_INVARIANT_FAILURE correction — 16/09/2026

Failed hosted run `35061815537` rolled back: zero committed import receipts/mappings, and the prior partial dataset remains. Local reproductions identified two preview/apply gaps: (1) approved different-type same-name Dishes passed preview but hit the old global active-name unique index; (2) valid supplier-priority permutations hit the unchanged unique rank index during row-by-row replacement. The original typed-Dish test asserted preview only, not application.

The correction aligns the existing named Dish index and create/update/reactivation/Recipe-Save checks to Dish Type + normalized name. Null/unclassified types remain one uniqueness scope. Stable codes and IDs remain unchanged, same-type collisions remain rejected, and no constraint is disabled. Private apply clears only the changing mapped priority slots inside its already-locked transaction before assigning final ranks; uniqueness remains enforced and no null intermediate value commits.

Private failures now retain bounded SQLSTATE/constraint/table/phase metadata through the Staging wrapper and CLI. Raw SQL messages, detail, data, secrets and stack traces are not logged. No blind retry occurs after failure.

Regression evidence includes real typed-Dish apply + BOM readback, same-type physical rejection, browser typed creation, priority swap with stable relationship IDs, and forced-check rollback/redaction. The authoritative production baseline and released document/Recipe guards remain unchanged. This is a repair of the approved import, not new cutover authorization.

The first repair CI exposed Supabase CLI statement-by-statement migration execution: a top-level LOCK required an explicit transaction. Index lock/drop/rebuild are now one atomic DO statement, also tested without an outer transaction. The local synthetic volume rehearsal separately applied and reconciled 659 Dishes, 1,318 Recipes and 1,977 lines, then rolled back; it does not substitute for actual hosted reconciliation.
