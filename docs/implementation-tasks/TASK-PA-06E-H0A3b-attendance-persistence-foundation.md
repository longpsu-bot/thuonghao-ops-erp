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
- Focused pgTAP: `supabase/tests/pa_06e_h0a3b_attendance_persistence_foundation.sql`
- Supabase Integration workflow command immediately after the H0A3a focused suite
- This task, its decision, and minimal roadmap/register/parent-task references

The focused test contains 126 assertions. It proves the exact four-relation schema and approved columns; generated UUID identities; arbitrary inclusive periods; DRAFT-first insertion in every non-DRAFT state; exact transitions and version behavior; same-state working source refreshes; source immutability during all six lifecycle transitions; frozen same-state protection; working-only line mutation; stable line identity; exact integer and zero portions; inactive-School policy deferral; exact approval completeness; every individual copied snapshot field; wrong-version, cross-batch, invalid, missing, extra, and duplicate rejection; immutable old and new snapshots; restrictive indexed foreign keys; `atlas_owner` ownership; forced RLS with zero policies; fail-closed privileges and search paths; the unchanged 18-function API registry; and zero role or capability seeds.

## Exclusions

No Attendance RPC, read API, import parser, synchronization, idempotency rule, same-signature rule, drift behavior, issue, warning, acknowledgement, reason, event, audit, receipt, default portion, omitted-day policy, active-School policy, Weekly Menu mutation, Planning Input Set, readiness, Need Generation calculation, ingredient calculation, Confirmed Need, downstream module, React, generated type, package, seed, Retool change, OPS v1 change, `public`, `ops_v2`, hosted Supabase, deployment, credential, production-data, backfill, or migration execution is part of H0A3b. H0A4 and every later task remain unstarted.

## Migration and rollback

The migration is additive and seeds no production row. Before operational data or dependent migrations exist, an unshipped migration may be reverted normally. After use, do not delete or rewrite approval history: revoke an unsafe path if necessary and forward-fix through another reviewed migration. Every operational foreign key uses `ON DELETE RESTRICT`.

## Validation record

- canonical workspace preflight at baseline `6c6f09e8f2993defe4a041a15caea9f20ea15cb9`: pass;
- `pnpm install --frozen-lockfile`: pass; dependencies already current;
- local Supabase reset with `--no-seed`: pass; every migration replayed through H0A3b;
- focused `supabase test db supabase/tests/pa_06e_h0a3b_attendance_persistence_foundation.sql --local`: pass, 126/126 assertions;
- registered database regressions: H0A1 59/59, H0A2 88/88, H0A3a 103/103, PA-05G 82/82, and PA-05C-H3 37/37 pass after the H0A3b migration;
- `supabase db diff --local --schema atlas_planning,atlas_admin,atlas_core`: pass; no schema changes found after reset;
- affected-schema database lint: completes with only the documented pre-existing `atlas_core.pa_05d_safe_date` volatility warning and no error;
- catalog audits: four relations and four guards are `atlas_owner` owned; all four relations have enabled and forced RLS with zero policies; unexpected table, function, and Atlas default grants are zero; no Attendance sequence exists; all 12 operational foreign keys are restrictive with zero missing leading indexes; the `atlas_api` registry remains exactly 18 functions; and role/capability row counts remain zero;
- `pnpm format`, `pnpm typecheck`, `pnpm test`, and `pnpm build`: pass; 41 test files and 265 assertions pass, with only the existing Vite chunk-size advisory;
- cached and uncached `git diff --check`: pass;
- exact allowed-file-scope and no-forbidden-surface audits: pass;
- current Supabase CLI documentation and installed 2.109.1 help reviewed; local-only execution used and no hosted project was linked or touched; and
- publication and exact-head GitHub Actions results are recorded on the draft pull request after they run.
