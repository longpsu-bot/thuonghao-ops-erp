# Positive Correction Fast Path Implementation Plan

> **For agentic workers:** Execute this bounded hotfix inline, with an independent review before handoff.

**Goal:** Restore D-046/D-047 correction below the existing authenticated 8000 ms timeout after #368.

**Architecture:** Resolve ordinary immediate predecessor contributions through the existing indexed theoretical-line and batch identity. Invoke the unchanged private zero-ancestry helper only when an immediate predecessor is an active zero observation. Preserve current-revision filters, singleton read selection and all zero-demand and correction guards.

**Tech Stack:** PostgreSQL, Supabase CLI, pgTAP, repository Node certification harnesses.

**Spec:** Product hotfix request supplied on 12 October 2026; BR-048 and the H0C zero-demand clarification; D-046 and D-047.

## Global Constraints

- One new forward migration; never edit `20261012024511_atlas_zero_demand_generation_policy.sql`.
- No timeout, API, RLS, owner, lifecycle, calculation, downstream, dependency, frontend, Retool, OPS v1 or Staging changes.
- Open one Draft PR; do not merge or deploy. Product review remains required.

## Bounded implementation and checks

- [x] Verify the authorized clean checkout and branch from `28ea8559bf436bf67df0b04c3e7abd955a8b52cc`.
- [x] Run `node scripts/test-local-planning-final-closeout.mjs` before the fix and capture the failure and protected timing.
- [x] Modify `supabase/tests/planning_final_closeout.sql`: replace the private zero helper with a transaction-local throwing definition before the real positive-only correction; retain all 17 assertions and the 8-second timeout.
- [x] Add complete forward definitions in `supabase/migrations/20261012064517_atlas_positive_correction_fast_path.sql` for the materializer, membership guard and RMVP-04 read payload. Restore indexed direct hot joins with a `CASE`-guarded zero fallback; retain singleton latest-revision read lookup. Review current-source consistency; it requires no change.
- [x] Extend `supabase/tests/atlas_zero_demand_generation_policy.sql` with a consecutive-zero predecessor/recovery case using real commands and immutable source evidence.
- [x] Run focused zero-demand, materialization, correction, D-046, D-047 and security suites; run the exact final-closeout harness, requiring 17/17 and normal p95 below 4000 ms.
- [x] Run `pnpm certify:supabase:full-integration` unchanged; record its complete result.
- [x] Document the root cause, performance, security review, migration/rollback and paired future Staging apply in `docs/implementation-tasks/TASK-ATLAS-POSITIVE-CORRECTION-FAST-PATH.md`.
- [x] Obtain independent code review and prepare the Draft PR handoff.

**Publication:** Commit, push and open one Draft PR. Confirm GitHub frontend validation; stop for Product review. The PR and final chat report record publication and GitHub results.
