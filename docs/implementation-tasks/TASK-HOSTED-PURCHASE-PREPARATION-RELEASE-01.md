# Hosted Purchase Preparation release correction

Starting authority: `d2b89b30454791009e1fe4fd6f040bddfbf3887e`.
Branch: `perf/staging-purchase-preparation-release-01`.
Scope: private Planning/Procurement release-support queries, migration 105,
regression coverage, and a separate protected deployment-verifier correction.
No lifecycle, calculation, API payload, supplier-default policy, UI, Retool,
OPS v1, released commitment or timeout-budget change.

## Hosted diagnosis

One authenticated rollback-only management transaction profiled Staging project
`rnzxmxiiqgtdevzregff`, subject
`a1010000-0000-4000-8000-000000000101`, batch
`69661e86-abb3-4bf4-88a5-4717fe18c472`, service date `2026-10-12`, version 2.
It used `SET LOCAL statement_timeout='60s'`, `lock_timeout='5s'`, and
`track_functions='all'`, asserted clean business preconditions, invoked the
unmodified public preparation under `authenticated`, forced deferred constraints,
captured transaction-local function statistics and executed `ROLLBACK`.
No role, global or function timeout configuration was altered. Management
statement timing is distinct from PostgREST's hoisted 20-second RPC budget.

The command took **27,156.572 ms**, plus **217.248 ms** for final deferred checks:
**27,373.820 ms** total. The prior normal hosted rehearsal timed out at 20 seconds.

| Stage                                       | Hosted baseline ms | Corrected disposable ms |
| ------------------------------------------- | -----------------: | ----------------------: |
| Default materialization                     |          5,665.095 |               1,337.054 |
| Confirmed Need release                      |         14,202.438 |               5,887.132 |
| Handoff excluding nested promotion          |          2,640.037 |                 440.902 |
| Allocation promotion                        |          3,529.035 |               1,093.421 |
| PO Draft creation                           |          1,030.893 |                 509.887 |
| Final deferred checks                       |            217.248 |                 273.658 |
| Complete command plus final deferred checks |     **27,373.820** |           **9,589.028** |

Function times are inclusive; the Handoff row subtracts nested promotion to avoid
double counting. Release also includes its internal constraint flushes. Outer
authorization, receipts and frontier work account for the remaining time. A
rollback-only profile cannot measure durable COMMIT/WAL acknowledgment.

Dominant repeated work:

- Confirmed-source universe: **11 calls / 13,178.064 ms**, including nine
  batch-source calls / 11,320.842 ms and two full-universe calls / 1,871.155 ms.
- Canonical evaluation: **27 calls / 3,995.313 ms**. Validated-facts projection:
  **15 calls / 4,116.432 ms**. These overlap source time; do not add them to it.
- Allocation readiness: four calls / 4,548.984 ms. Allocation locking: two calls /
  2,744.088 ms. Release guard: one call / 2,781.421 ms.
- Membership guards: 472 calls / 4,846.306 ms; current-source guards: 475 calls /
  1,178.754 ms; validation integrity: 240 calls / 1,685.267 ms; approval/release
  integrity: 241 calls / 962.636 ms. These checks remain unchanged.

This is accumulated repeated work, not a single 20-second source query. A
read-only inline query comparison on the real batch took 662.271 ms before and
463.776 ms with scalar outcome grouping, with exactly equal JSON results. The
original sort spilled **55,320 KB** and read/wrote **13,829 / 13,855** temp blocks;
the narrowed sort used **415 KB** in memory and zero temp blocks. All existing
access-path indexes were present. No additional index was justified.

## Correction and currentness

Migration `20261013082420_atlas_purchase_preparation_release_projection.sql`:

1. Projects the canonical outcome before expanding facts. Every evaluation,
   validated fact, family quantity, contribution and fingerprint remains exact.
2. Adds two private resolved-readiness overloads by retaining the existing SQL
   predicates. Default materialization shares its initial locked-evidence
   universe with preparation readiness, then shares the freshly recomputed
   post-write universe with strict readiness. When no default is generated, a
   fresh universe is still required before strict readiness.
3. Locks persisted allocation supplier evidence using one grouped split query,
   in the existing Ingredient/date/location/Unit order, followed by family-root
   locking. It no longer reconstructs Planning sources just to identify locks,
   or repeats supplier-split aggregation once per family.

The focused public-command regression demonstrates **7 source reconstructions,
19 canonical evaluations and 11 validated-facts projections**, compared with
11 / 27 / 15 before. Four redundant source reconstructions are removed: two
lock-identification calls and two materialization readiness calls.

Currentness/concurrency review: **PASS under the existing writer protocol**.
Callers hold the batch lock; same-batch allocation and Handoff writers acquire
that lock before changing evidence. Other-batch changes cannot produce a
successful strict readiness result with different lineage. The existing source
ambiguity rejection, post-write full-universe refresh, supplier priority locks,
fresh release/Handoff readiness and all integrity triggers remain active.
The new overloads accept no browser calls and are owned only by the existing
Procurement runtime. RLS, capabilities and public signatures are unchanged.
Independent source review found no actionable regression; a new two-session wait
test was not added because the supported protocol did not establish a new race.

## Results and validation

The final existing 236-family suite passes all **31 success/replay assertions**
and **11 controlled late-failure assertions**. Normal preparation: 9,315.370 ms;
final deferred checks: 273.658 ms; total: **9,589.028 ms**. The controlled PO
rejection completes in **10,834.435 ms**, observes all 236 generated defaults and
promoted families, and restores the exact business and accepted-child-receipt
snapshot. An initial development version timed out in repeated per-family split
aggregation; the final grouped lock query corrects that measured path.

Disposable output: **236 PRIORITY_RECOMMENDATION defaults, 0 MANUAL defaults,
236 promoted Handoff families, 12 Draft POs, 236 PO lines**. Exact replay returns
the identical original response and adds no business fact or receipt.

Focused seven-assertion projection/equivalence/security test and the affected
Planning/Procurement suites pass: Save/release boundary, validation, approval,
Handoff/allocation, Planning correction, PO immutability, selective continuity,
source ambiguity, zero demand, D-046 proposal and D-047 transition. The existing
Purchase Review suite passes 187 assertions, including priority changes,
inactive suppliers, ties, absent priority/eligibility and manual overrides.
The whole-platform catalog passes with exactly two new private owner execution
grants and updated exact private-function/grant digests. Fresh local migration
application through 105 and catalog verification also pass.
Local Supabase security advisors report no issues.

Frontend implementation is unchanged. Focused tooling tests pass; GitHub Actions
owns routine Frontend CI and the full Supabase Integration run on the Draft PR.
An initial broad Vitest filename filter also matched ignored historical
`.superpowers` copies; scoped repository tests exclude those copies, without
altering tracked CI configuration or weakening a check.

## Deployment tooling

Run `38365179982` applied 103/104, then its generated catalog verifier rejected
the governed `prepare_school_catering_purchase_orders(jsonb)` configuration as
`ATLAS_API_SECURITY_MODE_MISMATCH`. The same read-only verifier reproduced this
error on real Staging. HTTP 400 was a SQL rejection, not evidence that successful
Management API status changed. The HTTP helper remains unchanged.

The separate tooling correction accepts exactly the two-item configuration
`search_path=""` plus `statement_timeout=20s` for that exact API signature only.
Other API defaults and the Need Generation exception remain strict. The corrected
read-only catalog verifier passes on real Staging without deploying migration 105.

## Rollout and rollback boundary

Staging remains at **104**, latest `20261013042957`, with the target batch at
**DRAFT_REVIEW / version 2 / zero allocation families, Handoffs and POs** after
all diagnostics. Migrations 103/104 are untouched; no persistent Staging business
command was rerun. Nothing was deployed or merged. Retool and OPS v1 are unchanged.

Important Product-review discrepancy: the hosted rollback-only command produced
**17 Draft POs**, and a read-only recommendation count independently found 17
distinct preferred Suppliers across the 236 families. The requested 12-PO gate
matches the disposable fixture, not current Staging Supplier facts. Do not alter
eligibility or consolidation semantics to force that count. Resolve the gate
before the one authorized persistent rehearsal after review, merge and deployment.

After approval, the real workload must still prove success under the existing
20-second budget and exact replay. Disposable timing is not corrected hosted
acceptance. A forward rollback can restore the original three query bodies and
remove the two private overloads; it must retain any accepted business facts.
This migration changes no table, index, business data, status or public contract.

Evidence: `docs/testing/artifacts/hosted-purchase-release-01/before-profile.json`,
`scale-final.log`, `purchase_preparation_release_projection.sql.log`, and
`validation-summary.json`.
