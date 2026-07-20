# TASK-PA-06E-H0A3b — Attendance Persistence Foundation

**Status:** Implemented and locally validated on the task branch; pending draft-PR review

**Issue:** [#123](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/123)

**Task branch:** `backend/pa-06e-h0a3b-attendance-persistence`

**Starting baseline:** `6c6f09e8f2993defe4a041a15caea9f20ea15cb9`

**Parent task:** [TASK-PA-06E-H0](TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**Decision:** [Decision PA-06E-H0A3b — Controlled Attendance Persistence](../decisions/decision-pa-06e-h0a3b-controlled-attendance-persistence.md)

## Objective

Add the minimum private Planning persistence foundation for one stable Attendance batch, stable School/date portion lines, an immutable exact approval snapshot, and immutable snapshot lines. Attendance answers how many student and teacher portions are expected for a School and service date; this task performs no ingredient calculation and exposes no operational command.

## Bounded implementation

- add private `atlas_planning.attendance_batches`, `attendance_lines`, `attendance_approval_snapshots`, and `attendance_approval_snapshot_lines` relations with database-generated UUID identities;
- require one stable root per exact inclusive `period_start`/`period_end` tuple, with `period_end >= period_start` and no weekday or fixed-duration assumption;
- enforce `DRAFT → VALIDATED → APPROVED → USED_FOR_NEED_GENERATION`, the explicit `APPROVED`/used reopen paths, and `REOPENED → DRAFT`;
- require every root to enter as `DRAFT`; allow only same-state `DRAFT` or `REOPENED` refreshes of current-working source/import evidence without a version change; preserve that evidence across every lifecycle transition; and reject same-state frozen mutations;
- advance reopen by exactly one version, preserve version on every other transition, retain established approval history, and require a new snapshot for later-version approval;
- retain stable line identity and batch ownership while allowing School/date, exact nonnegative integer portions including zero, line status, source reference, and update actor/time changes only in `DRAFT` or `REOPENED`;
- preserve typed School history with `ON DELETE RESTRICT` while deferring active/inactive School policy;
- require one immutable approval header per exact positive version and exact immutable copies of every and only `ACTIVE` line;
- reject missing, invalid, extra, altered, duplicate, wrong-version, and cross-batch snapshot membership;
- use typed restrictive composite foreign keys and leading indexes before four minimum private guards; and
- force RLS, create zero policies, expose no API function, preserve fail-closed defaults, and grant no browser/API-role access.

## Files and acceptance evidence

- Migration: `supabase/migrations/20260720051142_pa_06e_h0a3b_attendance_persistence_foundation.sql`
- Structure/security pgTAP: `supabase/tests/pa_06e_h0a3b_attendance_structure_security.sql`
- Lifecycle/mutability pgTAP: `supabase/tests/pa_06e_h0a3b_attendance_lifecycle_mutability.sql`
- Approval-snapshot integrity pgTAP: `supabase/tests/pa_06e_h0a3b_attendance_approval_snapshot_integrity.sql`
- three Supabase Integration workflow commands immediately after the H0A3a focused suite and before PA-05G/PA-05C-H3
- This task, its decision, and minimal roadmap/register/parent-task references

The three independent suites contain 146 supplemental assertions in total. Their ownership is intentionally disjoint:

- `pa_06e_h0a3b_attendance_structure_security.sql` contains 28 assertions and owns only the exact four-relation schema, columns, database-generated UUID identities, exact constraint/constraint-trigger catalog, restrictive typed foreign-key targets and leading indexes, private guard/trigger catalog, `atlas_owner` ownership, forced RLS with zero policies, fail-closed privileges and search paths, the unchanged 18-function API registry, and zero role/capability seeds.
- `pa_06e_h0a3b_attendance_lifecycle_mutability.sql` contains 78 assertions and owns only arbitrary inclusive periods, DRAFT-first insertion, exact lifecycle/version transitions, all six source-preservation transition paths, same-state DRAFT/REOPENED refresh, frozen-state protection, stable root/line identity, working-only line mutation, exact nonnegative integer portions including zero, and inactive-School policy deferral.
- `pa_06e_h0a3b_attendance_approval_snapshot_integrity.sql` contains 40 assertions and owns only exact approval completeness, individual copied snapshot fields, wrong-version/cross-batch/invalid/missing/extra/duplicate rejection, exact root actor/time/snapshot binding, used-version preservation, reopen correction history, later-version approval, and immutable old/new snapshots.

Each file begins its own transaction, installs pgTAP if needed, declares an exact plan, creates only its own noncolliding synthetic fixtures when needed, calls `finish()`, and rolls back. Every suite passes by itself immediately after a clean local database reset; the combined 146 count is supplemental coverage only and is not evidence that any one suite is independently reviewable.

## Exclusions

No Attendance RPC, read API, import parser, synchronization, idempotency rule, same-signature rule, drift behavior, issue, warning, acknowledgement, reason, event, audit, receipt, default portion, omitted-day policy, active-School policy, Weekly Menu mutation, Planning Input Set, readiness, Need Generation calculation, ingredient calculation, Confirmed Need, downstream module, React, generated type, package, seed, Retool change, OPS v1 change, `public`, `ops_v2`, hosted Supabase, deployment, credential, production-data, backfill, or migration execution is part of H0A3b. H0A4 and every later task remain unstarted.

## Migration and rollback

The migration is additive and seeds no production row. Before operational data or dependent migrations exist, an unshipped migration may be reverted normally. After use, do not delete or rewrite approval history: revoke an unsafe path if necessary and forward-fix through another reviewed migration. Every operational foreign key uses `ON DELETE RESTRICT`.

## Validation record

- canonical workspace preflight at baseline `6c6f09e8f2993defe4a041a15caea9f20ea15cb9`: pass;
- `pnpm install --frozen-lockfile`: pass; dependencies already current;
- local Supabase reset with `--no-seed`: pass; every migration replayed through H0A3b;
- independent reset plus `supabase test db supabase/tests/pa_06e_h0a3b_attendance_structure_security.sql --local`: pass, `Files=1`, 28/28 assertions, `Result: PASS`;
- independent reset plus `supabase test db supabase/tests/pa_06e_h0a3b_attendance_lifecycle_mutability.sql --local`: pass, `Files=1`, 78/78 assertions, `Result: PASS`;
- independent reset plus `supabase test db supabase/tests/pa_06e_h0a3b_attendance_approval_snapshot_integrity.sql --local`: pass, `Files=1`, 40/40 assertions, `Result: PASS`;
- final-reset registered database sequence: H0A1 59/59, H0A2 88/88, H0A3a 103/103, H0A3b structure/security 28/28, H0A3b lifecycle/mutability 78/78, H0A3b approval-snapshot integrity 40/40, PA-05G 82/82, and PA-05C-H3 37/37 pass in workflow order after the unchanged H0A3b migration;
- `supabase db diff --local --schema atlas_planning,atlas_admin,atlas_core`: pass; no schema changes found after reset;
- affected-schema database lint: completes with only the documented pre-existing `atlas_core.pa_05d_safe_date` volatility warning and no error;
- catalog audits: four relations and four guards are `atlas_owner` owned; all four relations have enabled and forced RLS with zero policies; unexpected table, function, and Atlas default grants are zero; no Attendance sequence exists; all 12 operational foreign keys are restrictive with zero missing leading indexes; the `atlas_api` registry remains exactly 18 functions; and role/capability row counts remain zero;
- `pnpm format`, `pnpm typecheck`, `pnpm test`, and `pnpm build`: pass; 41 test files and 265 assertions pass, with only the existing Vite chunk-size advisory;
- cached and uncached `git diff --check`: pass;
- exact allowed-file-scope and no-forbidden-surface audits: pass;
- current Supabase CLI documentation and installed 2.109.1 help reviewed; local-only execution used and no hosted project was linked or touched; and
- publication and exact-head GitHub Actions results are recorded on the draft pull request after they run.
