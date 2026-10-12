# Atlas positive correction fast path after #368

**Status:** Implemented; local Full Integration and independent review passed; Draft PR handoff, Product review pending.

**Starting SHA:** `28ea8559bf436bf67df0b04c3e7abd955a8b52cc`.

**Branch:** `codex/atlas-positive-correction-fast-path`.

## Scope and root cause

Migration 101 correctly introduced zero-demand semantics and immutable ancestry
recovery, but also replaced direct predecessor contribution lookup with recursive
resolution on ordinary positive correction rows. Nine materializer expressions,
four membership-guard expressions, and two RMVP-04 workbench expressions invoked
the helper. Repeated deferred membership checks amplified this work in the
304-contribution / 248-group D-046/D-047 closeout fixture. Atomicity survived, but
the real correction could not complete under authenticated `statement_timeout =
8000 ms`.

The forward migration
`20261012064517_atlas_positive_correction_fast_path.sql` replaces only those 15
lookup expressions in three complete effective function definitions:

- `atlas_core.planning_contract_01_materialize_confirmed_needs`;
- `atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total`;
- `atlas_core.rmvp_04_workbench_payload`.

The twelve hot join predicates restore the existing indexed
`theoretical_need_line_id` predecessor relationship inside the exact batch. A
second contribution-ID branch uses `CASE` to invoke the unchanged ancestry helper
only for an `ACTIVE` zero immediate predecessor; null arguments skip it entirely.
Current-revision filters remain unchanged, and historical existence guards retain
their complete checks. The membership completeness check reuses its already joined
predecessor's nonnull destination instead of resolving that predecessor again.

The two workbench lookups retain a singleton direct selection with latest
`revision_number DESC` and contribution-ID tie-breaking, avoiding duplicate grouped
audit rows after human-adjustment history. `COALESCE` returns that direct identity
without evaluating the guarded zero fallback; null predecessor/batch arguments skip
both branches. Positive missing evidence remains subject to the existing fail-closed
guards and never triggers recursive lookup.

`pa_06e_h0b1b_confirmed_need_current_source_consistency` was reviewed: it contains
no ancestry-helper call. Its positive partition selection and source/identity
checks remain unchanged. All other #368 helper call sites are the 15 replaced
expressions; the recursive helper itself remains unchanged.

No frontend, dependency, public API, timeout, lifecycle, rounding precedence,
decision, source fingerprint, downstream authority, RLS policy, table or index is
changed. Migration 101 is unchanged. Retool, OPS v1 and Atlas Staging are untouched.

## Regression evidence

The exact final-closeout harness provides protected correction profiling,
rollback/checkpoint proofs, real 8-second authenticated correction, and browser
proofs. Its pgTAP fixture now substitutes a throwing zero-helper definition inside
the rolled-back transaction. All 17 existing assertions must still pass, proving
that positive correction, deferred guards, and authoritative readback do not invoke
zero ancestry. Test instrumentation restores exact schema/role access before the
real command; rollback restores the original helper.

The zero-demand suite retains all prior 71 assertions and adds one rolled-back
real-command subcase for `positive → zero → zero → positive`. A changed Menu in a
zero School produces a second zero run without omitting predecessor facts; later
Attendance Save and atomic reactivation recover all four original stable identities
and destinations, retain all four generations, and replay exactly. Deferred
constraints remain enabled and are explicitly flushed. The original Hùng Vương
4 + 1 + 4 fixture, mixed/initial zero, Pantry-positive, destination guard,
downstream immutability and atomic certainty cases remain intact.

| Measurement                      | Before                               | After lookup correction           |
| -------------------------------- | ------------------------------------ | --------------------------------- |
| Protected correction RPC samples | 34390.778 / 37705.614 / 35304.483 ms | 5821.117 / 5837.209 / 5580.274 ms |
| Correction median                | 35304.483 ms                         | 5821.117 ms                       |
| Normal generation p95            | 2701.027 ms                          | 3528.287 ms                       |

The timing comparison uses the same disposable fixture and existing protected
maintenance policy; authenticated timeout remains 8000 ms. The exact
`node scripts/test-local-planning-final-closeout.mjs` command exits 0: 17/17 pgTAP,
protected persistence and local browser Save/reopen proof all pass. The real
correction retains one successor/receipt, 248 current lines, 248 historical null
proposal pairs, exact fingerprints, zero fabricated decisions and zero Handoff.
The browser separately proves one explicit Save creates the expected 248 real
human decisions, including one quantity adjustment; this does not change the
correction's zero-decision proof.

Focused suites: seven SQL suites pass 624 assertions, including the expanded
zero-demand suite at 72/72. The unchanged exact
`pnpm certify:supabase:full-integration` command exits 0 with
`Supabase Full Integration certification passed.` All SQL, upgrade, closeout,
acceptance, connected-application and cleanup checks completed. Its repeated
closeout probes measured 5385.055 / 5320.628 / 5493.092 ms (median 5385.055 ms),
normal generation p95 3005.960 ms, and unchanged authenticated 8000 ms policy.

Independent review of the final migration, tests and contract clarification found
no actionable defects. No frontend source is affected; routine format/typecheck/
test/build validation is owned by the Draft PR's GitHub Actions run.

## Security, migration and rollback

All three functions preserve signatures, existing owners, security posture,
fixed empty search paths and function ACLs. The migration captures and restores
the exact existing `postgres` runtime memberships and schema CREATE privileges,
including absent memberships. It adds no function, role, capability, policy or
public grant and rewrites no business row. Current-source and downstream guards,
`NO_COMMITTED_CHANGE`, unknown-outcome handling and receipt replay are unchanged.

Before merge, rollback is discarding this branch. After any separately authorized
apply, use a reviewed forward correction retaining BR-048 and every immutable
run/revision/contribution/receipt. Never edit migration 101 or delete operational
history. No data rollback or backfill is required by this migration.

Atlas Staging has not applied migration 101. After this hotfix merges, a separately
authorized deployment should apply migration 101 and this forward correction
together, only after Full Integration is green. This task performs no deployment
and does not merge its Draft PR. Product review remains the final gate.
