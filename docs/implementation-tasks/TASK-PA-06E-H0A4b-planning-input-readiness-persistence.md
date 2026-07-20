# TASK-PA-06E-H0A4b — Planning Input Readiness Persistence

**Status:** Implemented and locally validated on the task branch; pending draft-PR review

**Issue:** [#127](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/127)

**Task branch:** `backend/pa-06e-h0a4b-readiness-persistence`

**Starting baseline:** `bf67814ae658ec5b853e0abb51e1643b11d57f83`

**Parent task:** [TASK-PA-06E-H0](TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**Controlling design:** [Decision PA-06E-H0A4 — Planning Input Readiness](../decisions/decision-pa-06e-h0a4-planning-input-readiness.md)

**Persistence decision:** [Decision PA-06E-H0A4b — Planning Input Readiness Persistence](../decisions/decision-pa-06e-h0a4b-planning-input-readiness-persistence.md)

## Objective

Persist the accepted H0A4a compatibility gate without reopening its decisions: one stable exact-period Planning Input Set root, immutable sequential evaluations, direct typed Weekly Menu and Attendance approval-snapshot bindings, and immutable evaluation-owned blocker/warning evidence. This task adds no command or browser surface and performs no ingredient calculation.

## Bounded implementation

- add private `atlas_planning.planning_input_sets`, `planning_input_evaluations`, and `planning_input_evaluation_issues` relations with database-generated UUID identities;
- keep one stable root per exact inclusive period, without a root version or School/customer/location/source identity extension;
- require a committed root to point to one exact latest evaluation and retain a contiguous positive root-local evaluation history;
- bind each populated source family through one direct composite FK to the exact immutable H0A3a or H0A3b snapshot/root/version tuple;
- require `READY` to use both exact current approved or handed-off source versions/snapshots, cover the evaluated period, and contain zero blockers;
- require `NOT_READY` to contain at least one blocker and the exact missing, insufficient-period, or stale-binding blocker required by its evidence;
- count issue rows exactly and constrain blocker/warning severity to the accepted ten-code catalog;
- derive the three warnings every-and-only from facts present in both bound snapshot families inside the evaluated period, without inventing completeness, omitted-day, slot, default, or active-School policy;
- enforce the closed lifecycle and re-evaluation matrix with immutable evaluation/issue history and explicit invalidation only;
- use four minimum private invoker-security guards, six private triggers, restrictive typed foreign keys, and leading indexes;
- force RLS on all three relations with zero policies and revoke all relation/function access from `PUBLIC`, `anon`, `authenticated`, and `service_role`; and
- preserve the exact 18-function `atlas_api` registry, fail-closed defaults, earlier migrations/tests, and all upstream history.

## Files and acceptance evidence

- Migration: `supabase/migrations/20260720135755_pa_06e_h0a4b_planning_input_readiness_persistence.sql`
- Structure/security pgTAP: `supabase/tests/pa_06e_h0a4b_planning_input_readiness_structure_security.sql`
- Evaluation/source-snapshot pgTAP: `supabase/tests/pa_06e_h0a4b_planning_input_readiness_evaluation_source_snapshot_integrity.sql`
- Lifecycle/issues/invalidation pgTAP: `supabase/tests/pa_06e_h0a4b_planning_input_readiness_lifecycle_issues_invalidation.sql`
- Three exact Supabase Integration commands after H0A3b and before PA-05G
- This task, the bounded persistence decision, and minimal decision/register/roadmap/parent-task status updates

The three independently runnable suites contain exactly 123 assertions:

- structure/security declares 30 assertions and exclusively owns the exact relation/column/constraint/index/guard/trigger catalog, UUID defaults, ownership, forced RLS, zero policies/privileges/sequences/authorization seeds, forbidden-surface absence, and unchanged API registry;
- evaluation/source-snapshot integrity declares 45 assertions and exclusively owns exact-period root validity/uniqueness, first-evaluation/current-pointer ownership, source-family shape, direct snapshot ownership, current approved/handed-off state, equality/subset containment and overlap failures, restrictive source history, and no pointer or snapshot crossing; and
- lifecycle/issues/invalidation declares 48 assertions and exclusively owns the transition matrix, successor versions, request/invalidation behavior, immutability/nondeletion, result/count consistency, issue classification/context uniqueness, blocker completeness, every-and-only warnings, explicit invalidation, absence of automatic source invalidation, and retained immutable evidence.

Each suite owns its transaction, deterministic noncolliding fixtures, exact plan, `finish()`, and rollback. No shared fixture/helper file or earlier test modification is used.

## Exclusions

No evaluation/request/invalidation RPC, read API, runtime role, capability, membership, policy, reason, event, receipt, audit row, safe-error contract, generated type, React behavior, package, seed, acknowledgement workflow, expected-School/day catalogue, source trigger, Recipe change, Need Generation, H0A5, Theoretical Need, Confirmed Need, Procurement rebalance, Retool/OPS v1 change, `public`/`ops_v2` object, hosted Supabase access, production row, import, backfill, credential, deployment, or infrastructure change is part of H0A4b.

## Migration and rollback

The migration is additive and seeds no row. Before operational data or dependent migrations exist, an unshipped migration can be reverted normally. After use, do not delete or rewrite readiness evaluations, issues, or source snapshot history. Revoke an unsafe path if necessary and forward-fix through another reviewed migration. Every operational FK uses `ON DELETE RESTRICT`.

## Validation record

- canonical workspace preflight at baseline `bf67814ae658ec5b853e0abb51e1643b11d57f83`: pass;
- historical H0A3a working changes preserved separately in the named stash required by Issue #127; never applied to this branch;
- `pnpm install --frozen-lockfile`: pass;
- local Supabase reset through H0A4b: pass;
- independent structure/security suite: pass, `Files=1`, 30/30 assertions, `Result: PASS`;
- independent evaluation/source-snapshot suite: pass, `Files=1`, 45/45 assertions, `Result: PASS`;
- independent lifecycle/issues/invalidation suite: pass, `Files=1`, 48/48 assertions, `Result: PASS`;
- combined H0A4b total: exactly 123 supplemental assertions;
- final reset plus the complete registered 11-file sequence: pass, 638/638 assertions;
- `pnpm format`, `pnpm typecheck`, `pnpm test` (41 files, 265 tests), and `pnpm build`: pass;
- affected-schema database lint: zero errors; structural diff for `atlas_planning`, `atlas_admin`, and `atlas_core`: empty;
- catalog audit: three `atlas_owner` relations, enabled and forced RLS on all three, zero policies, zero relation/default/function grants to API roles or `PUBLIC`, zero sequences, four invoker guards with empty search paths, seven restrictive FKs with zero missing leading indexes, and exactly 18 unchanged `atlas_api` functions;
- forbidden-surface audit: zero readiness roles/capabilities, zero `public`/`ops_v2` readiness relations, and zero H0A4b triggers on H0A3a/H0A3b sources; and
- publication and exact-head GitHub Actions evidence are recorded on the draft pull request after completion.
