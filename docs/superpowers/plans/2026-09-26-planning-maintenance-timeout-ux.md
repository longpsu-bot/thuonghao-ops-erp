# Planning maintenance timeout and operation feedback

**Authority:** Owner task approved on 2026-09-26. Starting main: `1afda8735b5cd5bdf948a7d53225449a565f6b95`.

**Goal:** Unblock D046 certification with a protected 60-second statement policy and give synchronous Need Generation honest operation feedback.

**Design:** Share the management SQL envelope between rollback and persistence. Keep the public command, synthetic authenticated subject, RLS, receipts and one-shot readback. Add ephemeral reusable operation feedback to the existing Planning interaction; no database lifecycle or progress records.

## Implementation sequence

- [x] RED/GREEN: correction performance tests accept statements below 60000 ms independently, reject invalid policy/timing, preserve three rollback checkpoints and receipt attribution.
- [x] Share transaction-local policy and public-command SQL; persistence commits only a completed successful response after deferred checks. Restore 60s after nested command settings. Report normal policy independently as 8000 ms. No global configuration writes.
- [x] RED/GREEN: fake-timer operation feedback tests for 2s/15s, elapsed display, success/failure/unknown, duplicate prevention and cleanup. Integrate only Need Generation/Update Need and retain authoritative response/readback semantics.
- [x] Update protected workflow and rollout/UX documentation, including the post-merge owner sequence and later reuse candidates.
- [x] Run focused Planning, closeout, browser/controller, security and performance tests, typecheck, changed-file formatting and whitespace checks. Run the full local Supabase integration once.
- [ ] One independent final review; address findings. Commit, push one bounded Draft PR and inspect GitHub CI. Do not merge.

## Boundaries

Allowed: protected D046 scripts/tests/workflow, shared client operation presentation, the existing connected Need Generation workbench/tests, associated documentation.

Prohibited: hosted workflows/mutations/deployment, Retool/OPS v1 writes, PR #286 merge/candidate changes, RLS/API/role/lifecycle/calculation changes, historical receipt edits, automatic command retries, broad module refactors, new dependencies. No migration is expected.

## Acceptance

Three future hosted rollback probes must each execute the same protected public command, satisfy the existing strict business proof and submitted receipt attribution, and independently preserve the original checkpoint. RPC and constraint-flush durations are distinct; no utilization percentage is a correctness gate. Persistence uses one command identity, one invocation and authoritative readback.

The initiating UI action immediately loads and rejects duplicates. After 2 seconds it shows the action and elapsed time; after 15 seconds calm informational copy appears. The accessible status region announces state changes without ticking every second. Success requires authoritative command/readback evidence; unknown outcomes remain blocked pending reconciliation. No fake progress or persisted running state.

## Validation note

Focused suites and typecheck passed. Full local integration was attempted; an unchanged legacy-adoption CLI query failed to connect to the local Docker PostgreSQL port. The direct Docker/psql correction harness passed three protected rollback probes; protected persistence and browser Save/reopen also passed. PR CI is tracked in the PR. One independent read-only final review found no actionable issues.
