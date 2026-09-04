# Atlas Dish creation: business information only

## Scope and authority

Owner-approved task, under OPS System Map v1.0, starting from
`cb7500b8d79cdb6fa58ac900643a1ee2c6d89d76`. One agent; no delegation.

The normal creation form contains Tên món, Loại món, optional Nhóm mô tả,
optional Ghi chú vận hành, and Lưu món ăn. Code, ordering, and participation
controls are removed completely. The submitted payload contains only these
business fields. Authoritative affected Dish identity remains the primary
selection source; legacy review readback selects only a single newly returned
identity. The browser-only review adapter mirrors the new creation defaults.

## Backend and compatibility

The forward migration replaces only `atlas_api.create_dish(jsonb)` and its
comment. It preserves ownership, privileges, RLS, authorization, request hashing,
receipts, audit, events, lifecycle, and the v1 signature.

- Omitted code becomes `dish-` plus all 36 characters of
  `pg_catalog.gen_random_uuid()::text`, generated after receipt replay resolution.
  The existing unique constraint remains authoritative. No numbering subsystem
  or name-derived identity is introduced.
- Omitted ordering becomes `0`; omitted demand participation becomes `true`.
- Explicit code/ordering/participation remain supported for controlled callers.
  The audit found explicit codes in `verify-local-rmvp02a-recipes.mjs`,
  `verify-local-rmvp02b-adjustments.mjs`, and
  `verify-local-planning-assembly-acceptance.mjs`, including code-based lookup.
  Snapshot import is a separate controlled path and is unchanged.
- `requires_need_generation` remains persisted and still affects legacy Recipe
  validation and Need Generation. Existing false values are not backfilled.
  Normal new Dishes default true and participate once active, on an approved
  Menu, and backed by a valid released Recipe.
- Creation remains DRAFT. Initial Recipe Save, duplicate active normalized-name
  conflict, Recipe locks, and inactive-Dish planning blockers remain unchanged.

No calculation, Change Order, adjustment authorization, Menu authority,
Attendance, Pantry, Confirmed Need, Procurement, Warehouse, Dispatch, Retool,
staging configuration, or released historical fact changes are included.

## Acceptance and evidence

Frontend regressions verify the absence of all three controls, the exact
business-only payload, both affected-ID and legacy-readback selection, conflict
retention, and successful initial Recipe Save on the new identity.

Database regressions verify each omitted field independently, generated code
uniqueness/readback/stability, exact replay, explicit compatibility, existing
duplicate constraints, initial Recipe activation, and inactive planning denial.

- Frontend RED: 3 failures / 19 assertions on the original implementation.
- Database RED: RMVP-02A 11 failures / 40; Issue 213 10 failures / 18.
- Frontend GREEN: workbench and Recipe API, 23 assertions.
- Database GREEN: RMVP-02A 40, Issue 213 18, UI-QUALITY-03A 21, and
  PLANNING-CONTRACT-01 195 assertions; 274 total.
- Typecheck passed. Touched supported files are checked with Prettier; SQL uses
  the existing migration style and `git diff --check`.

Docker Desktop could not start due to inaccessible local runtime sockets.
Focused SQL ran through `psql` against disposable loopback PostgreSQL 17.6 with
pgTAP 1.3.4 outside the repository. Baseline loading required temporary owner
EXECUTE grants on three existing Dispatch functions for native function
validation; their original ACLs were restored and checked before tests. No
repository migration or test was weakened for this setup.

An additional whole-platform security check passed 21/22 assertions. CAT-22's
native-environment grant count/hash mismatch (1636 versus 1641) was reproduced
identically with the original `create_dish` body and the new body. GitHub Actions
remains authoritative for the full Supabase environment, Frontend CI, and Qodana.
The Draft PR must not merge until CI and product/architecture review pass.

The Supabase PR smoke job now includes the three focused Dish/Recipe suites so
these regressions run on Draft PRs as well as on later review updates.

## Migration, rollback, and operational boundary

No table, column, role, policy, or grant changes; no backfill or hosted database
writes. Generated codes remain in persisted rows. Rollback, if later required,
is a forward function replacement preserving all Dish identities, receipts,
Recipe evidence, and history; do not drop the compatibility columns. Restoring
the old mandatory payload contract would also require coordinating the UI.

This task authorizes a Draft PR only, with no merge or deployment. Local tests
use rolled-back synthetic data. Staging, live OPS, and Retool receive zero writes.
