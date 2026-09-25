# Need Generation integrity at operational scale

Baseline: `0a272d55792c091b7575bcc036f77e9fd0f5e807`.
Authority: OPS_SYSTEM_MAP v1.0, ARCH-002, D-036 and D-041.
Scope: private Need Generation integrity validation performance; public daily commands, calculation, quantity policy, source selection and Confirmed Need authority are unchanged.

## Observed defect

The approved 14/09/2026 Staging Menu has 471 assignments, approved Attendance has 100 rows, and Pantry explicitly confirms no additions. Daily preflight is READY. Nevertheless, rolled-back execution for 17/09/2026 hits the authenticated eight-second budget. Transaction-local profiling attributes most elapsed time to hundreds of invocations of `pa_06e_h0a5b_need_generation_integrity_guard`; every immutable child repeats full-run joins and set comparisons.

The API maps query cancellation to `RETRYABLE_CONCURRENCY_FAILURE`. This task does not change that public error contract or enable automatic retries. An absent command receipt is not proof that execution never began: rollback removes the receipt too.

## Bounded correction

Patch the current guard definition at the exact line/issue count boundary, preserving all later Recipe and direct-Need amendments. Root, input snapshot, Recipe selection and release-header events retain the complete original guard. No trigger is removed or disabled, and UPDATE/DELETE behavior is unchanged.

Immutable theoretical-line and issue INSERTs first verify exact owned counts. The generated-line count is immutable. Issue counts may grow only through a checked, versioned run UPDATE; that UPDATE retains the complete original guard. A new counted package therefore has a mandatory full run INSERT/UPDATE event, including the original source, quantity, permitted-blocker and history checks. Uncounted later children fail immediately when deferred checks are flushed; flushing early does not authorize later additions.

Recipe-use INSERTs verify their exact selection, Recipe, Version, stable Line and Revision ownership plus complete affected-selection cardinality. Existing unique selection/Line membership and exact revision ownership imply every-and-only composition membership. Release-member INSERTs retain exact composite foreign keys, unique membership and complete immutable run/header cardinality. The header event retains full release metadata checks.

There is no client-settable validation marker, transaction cache, supporting queue, new lifecycle or persisted convenience state. Database settings, roles, grants, RLS, production source data, Retool and Google integrations are not changed.

## Regression and verification plan

Baseline CI run `35295536285` reproduces the actual failure: all source Save/preflight checks pass, then 30-School daily execution fails after 8,000.558 ms with `RETRYABLE_CONCURRENCY_FAILURE`. No partial generation is retained. Earlier test-fixture setup issues were corrected before establishing this RED result.

The operational test creates 600 weekly Menu assignments, 150 Attendance rows and an explicit no-additions Pantry source with all production constraints enabled. One day must yield 480 exact six-decimal contributions and a complete editable 120-row Confirmed Need review under the existing eight-second deadline. Exact replay must retain one run/receipt. Fault injection verifies that forged quantities, omitted Recipe uses and incomplete release membership remain rejected atomically; a subsequent clean request must still succeed.

Four existing Need Generation foundation suites, Pantry generation, daily/atomic Planning and the full integration workflow remain required. No source, API, security assertion or calculation test is relaxed.

## Deployment boundary

This PR is implementation/certification only. A repository merge is not a hosted migration. Keep the PR Draft/unmerged pending owner approval; apply only to Atlas Staging through the protected deployment path after acceptance, then repeat real operator generation/readback. Live OPS v1 and Retool remain untouched. A rollback is a forward migration restoring the previous guard body and its previous performance; no operational data transformation is needed.

## End-to-end materialization boundary

After bounding the generation guard, the 480-contribution test proceeds to materialization. Profiling the same eight-second failed command attributes 3,284 ms to `confirmed_need_revision_membership_total` and 2,275 ms to `confirmed_need_current_source_consistency`; the generation guard is down to 1,668 ms. These are inside the same atomic public command, not a separate operator step.

The migration therefore also bounds those two existing private guards. Source-consistency child events recheck the affected stable line and its revision history; batch events still scan every line after source changes. Membership-total events recheck the affected current-source revision, exact sums, complete membership and predecessor anchors. The original contribution-fact scan remains batch-wide because it also checks live School/customer ownership, which can change outside the affected revision. Historical revision changes retain the original full-batch validation, because historical contribution facts can anchor later revisions. Both functions retain their GLOBAL active-release partition checks on every invocation. Wholesale behavior is unchanged. No guard, constraint or immutable evidence is removed.

Two additional corruption tests cover altered Confirmed Need contribution quantities and omitted materialization membership, with no surviving partial run or batch. Thirty-two operational/adversarial assertions and the existing H0B1b foundation suites protect this expanded execution boundary.

## Current-source event ownership correction — 25/09/2026

After D-047, one owner-authorized rollback-only 14/09 diagnostic completed in
7,781.175 ms. Transaction-local function statistics isolated 4,199.392 ms in
463 invocations of
`pa_06e_h0b1b_confirmed_need_current_source_consistency`: one batch event, 231
stable-line events and 231 current-revision events. The D-047 transition
predicate was not executed on this initial materialization path. Indexed child
partition and source-chain probes were sub-millisecond in direct `EXPLAIN`; the
defect was repeated proof ownership, not a missing index or weaker D-047 rule.

Migration `20260925015857_planning_generation_tail_latency_02.sql` keeps the
complete authoritative source/release/partition proof on batch INSERT and
source-advance UPDATE. A stable-line INSERT validates only its immutable source
identity. A current-revision INSERT validates its exact released source triple,
stable identity, immediate predecessor and affected source-member partition.
UPDATE and historical-revision paths retain the prior broader checks. The
membership-total guard is unchanged and continues to prove nonempty exact
membership, quantities, contribution facts, predecessor provenance and
completeness. No timeout, retry, trigger, constraint, RLS rule, public RPC,
D-046 rule or D-047 rule changes.

The regression suite explicitly proves that inserting a batch and every stable
line and then flushing deferred constraints before revisions fails with the
complete-partition error. It separately proves that a direct source advance,
child replacement and final deferred flush succeed only for a complete valid
source, and rejects a current revision that skips its immediate predecessor.
The 304-contribution/248-group scale test records transaction-local function
timings and requires current-source validation not to dominate the materializer.
After the correction, five independent fresh local runs measured
`2631.646`, `2689.611`, `2737.625`, `3036.337` and `3202.173 ms`: nearest-rank
P50 was `2737.625 ms` and P95 was `3202.173 ms`. The final scale run's three
sequential samples were `3202.173`, `3640.077` and `3941.605 ms`, for P50
`3640.077 ms` and P95 `3941.605 ms`; all remained below the 4,000-ms desired
operator target. These are local diagnostics, not protected Staging evidence.
Protected Staging acceptance remains one-shot and strictly
`generation_ms < 7000`; the five-probe verifier now also reports sorted samples,
P50/P95 and whether the 4,000-ms operator target is met.

Final local verification on 25/09/2026 passed the 42-assertion operational
scale test, the focused H0B1b/H0Cb and D-046/D-047 matrices, all 17 verifier
tests, TypeScript typecheck and `pnpm certify:supabase:full-integration`. The
migration performs no data rewrite. If rollback is required, it must be a
reviewed forward migration restoring the prior private function body; deployed
immutable planning evidence is not modified.
