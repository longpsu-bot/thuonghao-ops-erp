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
