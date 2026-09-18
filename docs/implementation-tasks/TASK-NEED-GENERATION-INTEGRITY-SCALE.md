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
