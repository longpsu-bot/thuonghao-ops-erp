# Need Generation and Unit Label Improvement Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Proposed plan only. No application, database, runtime policy or deployment change is made by this document.

**Goal:** Reduce avoidable Need generation work, make operational Unit labels readable, and preserve reliable completion under variable hosted conditions.

**Architecture:** Keep the modular monolith and transactional PostgreSQL commands. Profile the existing generation pipeline before choosing a rewrite. Extend reconciliation with descriptive Unit metadata; retain backend comparison authority, exact quantities and immutable document evidence.

**Tech Stack:** Existing PostgreSQL 17 / Supabase, React, TypeScript, Chakra UI v3, pgTAP and Vitest. No new dependency is proposed.

**Spec:** This plan implements the Owner's 21 October direction and the bounded design below, under [ARCH-002](../../architecture/arch-002-atlas-system-map.md), the [Need contract](../../architecture/planning-domain-need-generation-contract.md), [atomic Planning boundary](../../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md) and [reconciliation contract](../../api/school-fulfilment-reconciliation.md). The latest Owner direction supersedes the earlier eight-second generation acceptance target for this work; it does not relax business or security checks.

## Global constraints

- **FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED.**
- PostgreSQL owns calculations, scope, currentness, authorization, concurrency, idempotency and releases. React coordinates the operator's work.
- Preserve explicit confirmation, Supplier allocation Save, original release, correction and successor release.
- Preserve exact Ingredient/Unit identity, decimal arithmetic, effective Recipe composition, zero-demand rules, source memberships and predecessor lineage.
- Preserve released document contents. No historical backfill from mutable master data.
- OPSv1, Retool and synced references remain read-only. Hosted benchmarking must not repeatedly create operational facts.
- Preserve RLS, ACLs, capability/scope checks, locks, deferred integrity checks and transaction boundaries.
- Preserve the selected compact Chakra UI, persistent workbench owners, dirty/UNKNOWN recovery, keyboard access and commit-driven freshness. No refresh merely on tab activation.
- Performance is an improvement objective, not an arbitrary execution deadline. Record slow successes, failures and variance honestly.
- Paid infrastructure, a new execution architecture or a new business policy requires a separate decision.

## Evidence and limits

Baseline source: main `cb7f6098a80b00c846d5a45cf6edce2e6e231bde`.
The adjacent [runtime baseline](../../testing/artifacts/hosted-journey-2026-10-21/runtime-baseline.json) preserves the sanitized measurements independently of ignored local files.

| Operation                                     | Hosted upstream service time |
| --------------------------------------------- | ---------------------------: |
| Need generation, successful                   |                 **14.630 s** |
| Need generation, earlier rolled-back attempts |              8.042 / 8.020 s |
| Original / corrected Prepare                  |              2.193 / 1.848 s |
| Slowest Orders read                           |                      2.107 s |
| Confirm Need / save correction                |              0.770 / 1.215 s |
| Reallocation Save                             |                      0.427 s |
| Create / release replacement PO               |              0.893 / 1.245 s |
| Replacement dispatches                        |              0.441 / 0.466 s |
| Final reconciliation read                     |                      1.029 s |

The successful generation's origin time was 14.719 s. Its 89 ms difference from upstream time does not explain browser/network latency and does not isolate database execution from service/resource waiting. It suggests prioritizing the hosted backend path, not attributing the delay to JavaScript.

The selected journey had 19 positive Need lines, two positive Schools, 19 explicit Attendance rows and retained history. It completed both original and correction cycles: seven original POs, one replacement PO, two original and two replacement dispatches; all 19 final deltas zero. All 5,277 pre-existing history rows were unchanged. This is one workload, not a fleet-wide percentile.

The 139 RPC calls include 115 reads across operator navigation and retained workbenches. That count alone does not prove unnecessary reads. HTTP 200 alone does not prove business success.

Read-only configuration observation at 07:56 UTC: Staging is ACTIVE_HEALTHY in ap-southeast-1; 131 migrations, tip 20261021050300. Authenticated statement_timeout remains 0 from the authorized rehearsal; anon remains 3s and authenticator statement/lock settings remain 8s. The public generation function already pins force_generic_plan and has no function-specific statement timeout. Function/I/O timing tracking is currently off. A later idle activity snapshot cannot explain resource conditions at 06:47 UTC. Compute size and contemporaneous CPU/I/O pressure have not been verified.

Retool's saved PurchasePlanner, actual-Need Save, Supplier choices, PO summaries, dispatch export and PO/dispatch comparison were reviewed as continuity evidence. Atlas keeps its own approved domain ownership.

## Design and delivery order

| Priority | Bounded batch                                             | Deliverable                                                                                                |
| -------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| P0       | A — measurement and completion policy                     | Trustworthy comparable evidence; remove obsolete generation speed gates without removing functional checks |
| P0       | B — Need generation optimization                          | One proven expensive path repaired at a time, with equivalent outcomes and less database work              |
| P1       | C — reconciliation Unit labels                            | Human labels from appropriate captured evidence; no identity or quantity change                            |
| P2       | D — repeated reads, waiting experience and infrastructure | Only changes justified by an action trace or resource evidence                                             |
| Release  | E — complete journey                                      | Original and correction cycles, frozen-history checks and refreshed runtime record                         |

A comes first. C is independent of B after A and may ship first as a small improvement; a difficult generation diagnosis must not delay a ready label fix. There is no promised wall-clock duration or required percentage speedup.

### Runtime and completion policy

Keep the current Staging rehearsal setting disclosed while measuring. Do not silently restore eight seconds and reintroduce a known failure. Do not turn role-wide unlimited execution into an assumed permanent production policy.

Separate three concerns:

1. **Business completion:** exact valid result, one committed command outcome, traceable readback; slowness alone is not business failure.
2. **Performance:** phase cost, work performed, service time, variability and operator waiting.
3. **Operational protection:** actual provider/transport ceilings, cancellation, lock protection, resource capacity and CI hang watchdogs.

Identify each timeout at the actual authenticated REST path. The existing 45-second Edge-function fetch setting is for source synchronization, not evidence of a Need RPC timeout. A supported operation-specific runtime policy can replace the broad rehearsal setting only after the real REST path proves correct completion and recovery; do not assume changing a nested function setting extends an already-running request.

A browser/network timeout can leave the server outcome unknown. Preserve the existing command identity and reconciliation path; do not automatically create a fresh command. Continue using the server's receipt/currentness evidence to decide whether work committed.

Supabase has documented platform request constraints. If a representative operation reaches an actual transport ceiling after sensible optimization, propose durable server-side execution separately, preserving Actor scope and atomic business commit. A queue, Edge-function bypass or split transaction is not the starting solution.

## Batch A — make measurement useful

**Files to inspect/modify:**

- Modify: `supabase/tests/need_generation_operational_scale.sql`.
- Inspect and narrowly amend generation-related probes in `scripts/verify-staging-planning-performance.mjs`; keep unrelated read/lock tests intact.
- Reuse: `scripts/benchmark-planning-retained-history.mjs`, `scripts/atlas-connected-need-generation.mjs`.
- Update: `docs/implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md` with a clearly dated runtime-policy amendment, and a new runbook `docs/runbooks/need-generation-runtime-observation.md`. Preserve the historical acceptance evidence and distinguish it from this Owner-directed policy.
- Evidence: `docs/testing/artifacts/need-generation-improvement/`.

**Interfaces:** Existing authenticated `atlas_api.execute_need_generation(jsonb) → jsonb`, RMVP-04.v3. No public request field or business response change.

- [ ] Preserve the original 14.630 s baseline and both failed attempts. Keep raw sample count, workload geometry, history depth, source SHA, migration set, environment, role/function settings, start time and business outcome together.
- [ ] Remove the local generation assertion `elapsed_ms < 8000`, its eight-second statement cutoff and the four-second target flag from the generation performance fixture. Retain all quantity, membership, currentness, replay, immutable-history and security assertions. Do not disable the suite or globally alter test timeouts.
- [ ] Replace the removed speed assertion with complete receipt/run/source/quantity assertions for every fresh sample. Keep finite nonnegative elapsed-time validation and all timings as diagnostics. CI's hang watchdog must be separately disclosed and must allow the complete semantic test to finish.
- [ ] Use the existing transaction-local profiler around the public authenticated command. Capture phase boundaries for preflight/source selection, generation/effective composition, validation/release, Confirmed Need materialization, deferred constraint flushes and authoritative readback. Measure trigger self-time and call counts; do not add inclusive nested times together as if independent.

Existing profiler pattern:

```sql
set local track_functions = 'all';
create temp table ng_profile_before as
select funcid, calls, self_time, total_time
from pg_stat_xact_user_functions;
-- Execute the existing fixture's authenticated command.
-- Read transaction-local deltas before the fixture rolls back.
```

- [ ] Keep phase instrumentation in a disposable database or diagnostic copy. If function statistics miss inlined SQL, inspect nested statement plans there. Never EXPLAIN ANALYZE a hosted business-writing command as a read-only probe.
- [ ] Compare the existing 19-line/two-School shape, the established 304-contribution/248-line scale fixture and an existing retained-history fixture. Include zero-portion Schools, two School types, direct additions, effective composition changes and regeneration. Record actual cardinalities; do not substitute a tiny empty database.
- [ ] For each before/after comparison, take five fresh equivalent samples on the same environment, alternating builds where practical. Preserve first-observed and repeated samples separately; do not pretend an idempotent replay measures fresh generation or a warm sample is cold. Report all values and median/range; five samples do not establish p95.
- [ ] Correlate hosted timestamps with available CPU, memory, I/O, temporary-file, connection and lock-wait evidence. Record missing metrics as unknown. Do not infer compute tier or blame hosting from role settings.
- [ ] Publish a ranked phase-cost report and select one bounded root cause for B. If no code inefficiency is established, record that result and move the decision to measured resource capacity.

**Acceptance:** All original semantic checks still execute and pass; slow valid completion is recorded; samples distinguish DB work from service/browser time; diagnosis names evidence and uncertainty. No hosted business write or permanent profiling configuration is required for diagnosis.

## Batch B — reduce proven generation work

**Source map:**

- Dispatcher/compatibility: `atlas_api.execute_need_generation`, `atlas_core.issue_223_execute_need_generation_v2`.
- Preflight: `atlas_core.planning_contract_01_preflight_payload`, direct-Need readiness and source fingerprints.
- Existing commands: evaluate/request readiness, create/validate/release generation, `atlas_core.planning_contract_01_materialize_confirmed_needs`, authoritative workbench readback.
- Relevant source migrations: `20260809120000_planning_contract_01_atomic_planning_boundaries.sql`, `20260920154302_stabilize_need_generation_generic_plans.sql`, `20261012024511_atlas_zero_demand_generation_policy.sql`, `20261014073733_atlas_need_generation_effective_composition.sql`, `20261019074646_atlas_k2_receipt_integrity.sql`.
- Tests: `need_generation_operational_scale.sql`, `atlas_effective_composition_generation.sql`, `atlas_zero_demand_generation_policy.sql`, `planning_contract_01_atomic_planning_boundaries.sql`, and the existing receipt/security tests selected from the changed functions.
- Create one forward migration using the repository's installed CLI; never edit an applied migration or hand-edit hosted function definitions.

**Interfaces:** Preserve the public signature/envelope, returned authoritative workbench, receipt identity and exact legacy compatibility.

- [ ] Map every caller of the measured expensive function and every deferred trigger using it. Write a failing regression demonstrating the specific redundant work or query-plan defect alongside semantic parity.
- [ ] Choose only the first proven cause from A: repeated source/fingerprint work; repeated exact-context effective composition; per-row validation rescanning the same evidence; an inappropriate query plan; or a measured missing index. These are hypotheses, not established findings.
- [ ] Prefer existing statement-local materialization and targeted event-local checks. Reuse immutable input only within a phase where its assumptions remain valid. Revalidate across source/version/lock or write boundaries. Do not cache authority between requests, remove integrity checks or mark a mutable function immutable.
- [ ] Keep the existing generic-plan choice unless paired evidence proves a better scoped alternative. It already addressed one historic fan-out issue; removing it is not an optimization by itself.
- [ ] Verify exact semantic parity for quantities, ordered memberships, effective Recipe revisions, zero demand, policy versions, regeneration, receipts, stale rejection and concurrent source changes. Normalize only nondeterministic IDs/timestamps when comparing independent fixture copies; retain relationship and cardinality checks.
- [ ] Compare the same fixtures before/after. Accept a performance claim only when reduced plans/scans/calls or I/O work and repeatable timing evidence support it. If elapsed changes are within hosting noise, report the structural reduction and label latency benefit unproven.
- [ ] Review and ship this bounded fix before considering another. If the same approach fails twice, preserve the evidence and reconsider the root cause. A fixed eight-second or percentage target is not a reason for another rewrite.

**Acceptance:** Correct complete operation; demonstrably less avoidable work; no security/history/currentness regression. No requirement to finish under an invented number. A performance-only change without convincing benefit does not merge merely because it passes correctness.

## Batch C — carry human Unit labels through reconciliation

**Established defect:** Both reconciliation scope builders and `school_fulfilment_compare` carry only unit_code. The shared response model has no unit_name and the compact table/detail render the raw code. PO and dispatch snapshots already contain human Unit names. A frontend-only lookup or guessed ID-to-label dictionary would hide the missing contract data.

**Files:**

- Forward migration for `atlas_core.school_fulfilment_compare(jsonb,jsonb)`, `atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid)` and `atlas_core.procurement_read_school_fulfilment_reconciliation_scope(date,uuid,uuid,jsonb)`.
- Shared model: `src/modules/atlas/dispatch/schoolFulfilmentReconciliationModel.ts`.
- Existing formatter: `src/modules/atlas/dispatch/schoolDispatchReleaseModel.ts`; widen its structural input to `Pick<SchoolDispatchLine, "unit_code" | "unit_name">` if needed, without changing issued-document fallback behavior.
- Current UI: `src/vnext/atlas/reconciliation/SchoolFulfilmentTable.tsx`, `SchoolFulfilmentDetail.tsx`, `schoolFulfilmentAuthority.ts`, `useSchoolFulfilmentWorkbench.ts`, `schoolFulfilmentReviewFixtures.ts`.
- Bridge exports only if required: `src/vnext/atlas/bridges/schoolDispatch.ts`, `schoolFulfilment.ts`; preserve the exact bridge allowlist.
- Compatibility UI: `src/modules/atlas/dispatch/SchoolFulfilmentReconciliationWorkbench.tsx`.
- Tests: `supabase/tests/school_fulfilment_reconciliation.sql`, `src/vnext/atlas/reconciliation/SchoolFulfilmentWorkbench.test.tsx`, `useSchoolFulfilmentWorkbench.test.tsx`, and existing shared formatter/compatibility tests.
- Update: `docs/api/school-fulfilment-reconciliation.md`.

**Interface addition:**

```ts
export type SchoolFulfilmentQuantityTotal = {
  unit_id: string;
  unit_code: string;
  unit_name?: string | null; // descriptive evidence, never comparison identity
  po_quantity: string;
  pxk_quantity: string;
  delta_quantity: string;
};
```

- [ ] Add failing SQL/UI cases using a technical code with an actual captured name such as Gói, Hộp or Quả. Cover both summary and expanded detail; retain exact quantities.
- [ ] Carry nullable unit_name through both the current context-aware and compatibility scope paths. For an existing issued PXK use its captured name; for a prospective scope with no PXK use the backend preview's explicit label. A legacy issued snapshot with no captured name stays unavailable/code-only. Do not fill it from today's Unit master or silently select a different document's label.
- [ ] Carry that metadata through the comparison helper and grouped totals while grouping only by unit_id. Define descriptive label selection deterministically; do not use differing labels to split one Unit or equal labels to combine different Units.
- [ ] Render through the existing pure Unit formatter. Normal codes such as kg remain readable; technical codes use the supplied name. Legacy missing metadata keeps the established truthful fallback. Keep technical identity in data and diagnostics.
- [ ] Validate optional metadata as string/null/absent at the authority boundary; malformed values fail closed. Include the human label in existing local search without fetching a new catalogue.
- [ ] Prove changing the current Unit master does not rename a released document. Test two distinct Unit IDs with the same human name, missing historical names, unchanged comparison precedence and no business writes/receipts from this read.
- [ ] Verify current/legacy consumers and compact desktop/narrow layouts; keep keyboard selection/focus, exact decimal formatting and zero deltas.
- [ ] Run focused reconciliation/formatter tests and SQL tests before normal required CI and review.

**Acceptance:** The current hosted rehearsal's non-mass Units are human-readable; identities, totals, blockers and frozen documents remain unchanged. Historical absence is disclosed, not repaired by invention.

## Batch D — improve waiting and repeated reads only with evidence

**Inspect:** `src/vnext/atlas/planning-confirmed/useConfirmedNeedWorkbench.ts`, its tests, `ConfirmedNeedCommandFeedback.tsx`, `src/vnext/atlas/AtlasModuleExit.tsx`, related commit-freshness tests and the RPC transport in `src/modules/atlas/connection/atlasRpc.ts`.

- [ ] Trace one operator action from request to committed readback. Label initial load, post-commit invalidation, contextual handoff and explicit refresh separately.
- [ ] Remove a read only when two requests demonstrably share the same authority revision/scope and one is redundant. Preserve every necessary post-commit refresh, dirty draft and stale-result guard. Do not introduce a global cache or broad controller rewrite.
- [ ] Test pending generation with a deliberately unresolved promise, then resolve it successfully. Repeat with an uncertain transport outcome. The button stays protected against duplicate submission; data is not shown as successful before authoritative readback.
- [ ] If waiting feedback needs improvement, show truthful ongoing work and elapsed time in the existing surface. Do not fabricate phase percentages or replace a valid pending command with an error at eight seconds.
- [ ] If CPU/I/O/connection evidence explains a substantial residual delay, prepare a capacity recommendation with observed limits, estimated cost and expected effect. A larger Supabase instance or region change is a separate Owner decision, not an automatic deployment.
- [ ] Keep only the trace-supported changes; if the existing pending/recovery UI and read counts are correct, record PASS with no code change.

## Batch E — release and prove the complete result

- [ ] Use a latest-main bounded branch for each independent repair. Run focused tests during development; normal required Frontend CI and actually executed Supabase integration, independent review and guarded exact-revision Staging deployment remain release gates.
- [ ] Replay the full original-and-correction journey in a disposable environment, then one explicitly labeled hosted rehearsal at an agreed fresh scope. Do not regenerate or overwrite the already released 21 October evidence to obtain timings.
- [ ] Cover the two School types and a representative full day. Generate/confirm Need, explicitly allocate, Prepare/release PO, issue dispatch, correct one quantity with reason, reallocate, create/release replacement PO and issue both successor dispatches.
- [ ] Require zero reconciliation deltas, correct predecessor links, one command outcome per intent and unchanged original document contents/pre-existing history.
- [ ] Repeat uncertain-outcome recovery and a concurrent source-change rejection in the disposable environment. Download/inspect fresh PO/PXK exports after correction; verify human labels and frozen metadata.
- [ ] Publish the before/after samples and exact source/environment settings. Separate correctness PASS from measured improvement or unproven hosting variance. Do not rerun a successful certification solely to obtain a faster sample.
- [ ] Resolve the temporary role-wide timeout lease deliberately after the real authenticated path proves the replacement policy. If role-wide 0 must remain for continued functional testing, disclose its scope and remaining resource exposure; do not restore 8s solely to satisfy an old target.
- [ ] Update the stabilization ledger with current evidence and remaining work.

## Completion and exclusions

The improvement cycle is complete when representative valid operations finish reliably, the measured dominant avoidable work is reduced or an evidenced infrastructure decision is presented, current Unit labels are readable, recovery is safe and the original/correction journeys still reconcile with frozen history intact.

This plan authorizes no implementation by itself. No new Warehouse capability, background execution framework, Recipe substitution, data cleanup, broad module split, dependency upgrade or speculative index is included. The source Recipe3529 pork-name/ground-beef discrepancy remains a separate business review item; performance work must not change its facts.

Official references checked 21 October: [Supabase query optimization](https://supabase.com/docs/guides/database/query-optimization), [performance tuning](https://supabase.com/docs/guides/platform/performance), [timeouts](https://supabase.com/docs/guides/database/postgres/timeouts). Use actual installed/runtime behavior when evaluating the transport boundary; a database timeout setting is not a promise of unlimited HTTP execution.
