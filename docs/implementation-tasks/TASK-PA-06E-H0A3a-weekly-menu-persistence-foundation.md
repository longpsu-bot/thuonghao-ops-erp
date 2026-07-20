# TASK-PA-06E-H0A3a — Weekly Menu Persistence Foundation

**Status:** Implemented and locally validated on the task branch; pending draft-PR review

**Issue:** [#121](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/121)

**Task branch:** `backend/pa-06e-h0a3a-weekly-menu-persistence`

**Starting baseline:** `ada7ff8a0888e0523574002ea96265df34f0bcce`

**Parent task:** [TASK-PA-06E-H0](TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**Decision:** [Decision PA-06E-H0A3a — Controlled Weekly Menu Persistence](../decisions/decision-pa-06e-h0a3a-controlled-weekly-menu-persistence.md)

## Objective

Add the minimum private Planning persistence foundation for one stable Weekly Menu root, stable typed lines, an immutable exact approval snapshot, and immutable snapshot lines. This task records local-only synthetic persistence structure; it exposes and executes no operational command.

## Bounded implementation

- add private `atlas_planning.weekly_menus`, `weekly_menu_lines`, `weekly_menu_approval_snapshots`, and `weekly_menu_approval_snapshot_lines` relations with database-generated UUID identities;
- require one exact inclusive seven-day service period per stable root without assuming a Monday start;
- enforce `DRAFT → VALIDATED → APPROVED → NEED_GENERATION_REQUESTED`, the explicit `APPROVED`/requested reopen path, and `REOPENED → DRAFT`;
- require every root to enter as `DRAFT`; allow same-state `DRAFT` or `REOPENED` refreshes of current-working source/import evidence without requiring a version change; reject that evidence changing during lifecycle transitions or same-state `VALIDATED`, `APPROVED`, and `NEED_GENERATION_REQUESTED` updates; advance reopen to the next working version; and preserve established approval evidence across later transitions;
- keep stable line ownership fixed to one Weekly Menu while allowing School/date/slot/Dish correction only in `DRAFT` or `REOPENED`;
- require trimmed lowercase nonblank menu-slot evidence without seeding or hard-coding a catalogue;
- require one snapshot per exact positive menu version and one exact snapshot line per stable active line;
- reject missing, invalid, extra, altered, duplicate, or cross-menu snapshot membership;
- retain earlier approval snapshots after reopen and later-version approval;
- use typed restrictive foreign keys and matching indexes before private trigger guards; and
- force RLS, create no policies, expose no API function, and grant no browser/API-role access.

## Files and acceptance evidence

- Migration: `supabase/migrations/20260719165444_pa_06e_h0a3a_weekly_menu_persistence_foundation.sql`
- Focused pgTAP: `supabase/tests/pa_06e_h0a3a_weekly_menu_persistence_foundation.sql`
- Supabase Integration workflow command immediately after the H0A2 focused suite
- This task, its decision, and minimal roadmap/register/parent-task references

The focused test contains 103 assertions. It proves the exact four-relation schema, database-generated identities, non-Monday seven-day service periods, exact same-state `DRAFT` and `REOPENED` source/import refreshes without version changes, transition-time and immutable-state evidence protection, source and version constraints, DRAFT-first insertion for every non-DRAFT state, legitimate lifecycle transitions with unrelated evidence unchanged, canonical trimmed lowercase nonblank slot storage and uniqueness, typed assignments, stable ownership, working-line mutability, exact active-line approval completeness, snapshot immutability, historical snapshot retention, restrictive indexed foreign keys, forced RLS, fail-closed privileges, unchanged API registry, and zero role or capability seeds.

## Exclusions

No Weekly Menu RPC, read API, import command, edit command, approval command, authorization, reason, warning, issue, event, slot catalogue, same-signature behavior, Google Sheet identity, legacy write, downstream rebalance, Attendance, readiness, Need Generation, Confirmed Need, Procurement, Warehouse, Dispatch, React, generated type, package, Retool change, OPS v1 change, `public`, `ops_v2`, hosted Supabase, deployment, credential, production-data, or migration/backfill action is part of H0A3a. H0A3b and every later task remain unstarted.

## Migration and rollback

The migration is additive and seeds no production row. Before operational data or dependent migrations exist, an unshipped migration may be reverted normally. After use, do not delete approval history: revoke an unsafe path if necessary and forward-fix through another reviewed migration. Every operational foreign key uses `ON DELETE RESTRICT`.

## Validation record

- canonical workspace preflight at baseline `ada7ff8a0888e0523574002ea96265df34f0bcce`: pass;
- `pnpm install --frozen-lockfile`: pass; dependencies already current;
- local Supabase reset with `--no-seed`: pass; every migration replayed through H0A3a;
- focused `supabase test db supabase/tests/pa_06e_h0a3a_weekly_menu_persistence_foundation.sql --local`: pass, 103/103 assertions;
- registered database regressions: H0A1 59/59, H0A2 88/88, PA-05G 82/82, and PA-05C-H3 37/37 all pass after the H0A3a migration;
- `supabase db diff --local --schema atlas_planning,atlas_admin,atlas_core`: pass; no schema changes found after reset;
- affected-schema database lint: completes with the documented pre-existing `atlas_core.pa_05d_safe_date` volatility warning and no error; local security/performance advisors: pass with no issues;
- `pnpm format`, `pnpm typecheck`, `pnpm test`, and `pnpm build`: pass; 41 test files and 265 assertions pass;
- cached and uncached `git diff --check`: pass;
- current Supabase configuration review: PostgreSQL 17, only `atlas_api` exposed, no seed execution, and no hosted action;
- OPS v1 Retool/schema review: legacy menu import and downstream rebalance treated as read-only evidence and not copied; and
- publication and GitHub Actions results are recorded on the draft pull request after they run.
