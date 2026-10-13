# Atlas preferred-Supplier defaults and School-first tables

Product-approved correction dated 2026-10-12. Starting main:
`063b40be86dd00a3a26f1a1a8cc0ef8b32964f83` (PRs #368 and #369).
Branch: `fix/atlas-preferred-supplier-default-school-first`.
Delivery status: the source-reuse follow-up removes the repeated projection defect.
Three independent fresh authenticated REST samples pass the 15-second target;
warm/cumulative latency variability remains an explicit Product review concern.
PR #370 remains Draft; merge and deployment are not authorized.

## Source-reuse follow-up — authorized 2026-10-13

Base remote authority: `f475d79c466415f195e4ad88fe2a842bdbb03a93`. Product explicitly
authorized the bounded internal correction, testing, commit and push on the same
branch/PR. The prior handoff and measurements below remain historical evidence.

The old individual-Save writer reconstructed the entire date once for every
missing default. This was the proven scaling defect, not allocation insert cost.
The retained correction resolves the full current source universe after Supplier
locks, reuses it for generated defaults, and refreshes it once at the end to
recheck only generated families. Count-one resolution includes other batches and
incomplete sources; batch, version, exact quantity and fingerprint must agree.
It never chooses a batch/UUID/order winner and adds no broader Planning lock policy.

Production functions changed:

- `purchase_review_confirmed_source_universe(uuid)` is a new private Confirmed
  Need-owned read bridge returning every current source in the batch period.
- `purchase_review_persist_resolved_allocation(...)` holds the existing writer
  body, including its validation, locks, Supplier priority, notes, exact splits,
  revision/contribution history and audit lineage. Its extra input is the private
  authoritative full source array, not caller-supplied quantity authority.
- `purchase_review_persist_allocation(...)` retains its seven-argument contract
  and delegates with a null source array, preserving normal resolution after locks.
- `purchase_review_materialize_default_allocations(...)` captures after Supplier
  locks, uses that one persistence body, and rejects changed/overlapping generated
  sources with one final full-universe check before returning.

The existing unmerged/undeployed migration 103 is amended in place. No Planning
release, Handoff, promotion, PO body, public payload, table, index, lifecycle,
dependency or frontend file changes in this follow-up. The 20s function limit,
8s authenticated default, 45s frontend transport and existing lock budget remain.
Security catalog: 342 private functions and 1,838 positive grants, exactly two
new function-owner grants plus Procurement execution on the source bridge.
The resolved writer is an invoker accessible only to its Procurement owner.
The bridge has the existing Confirmed Need runtime owner, empty search path and
Procurement-only external execution. Existing RLS/table policies are unchanged.

### Fresh public-command evidence

Each sample resets and migrates the disposable local database, creates the same
4-School × 59-Ingredient workload with 12 reused Suppliers, publicly saves all
236 Confirmed Need decisions, commits setup and refreshes ordinary statistics.
Measurement is the real `atlas_api.prepare_school_catering_purchase_orders`
authenticated PostgREST request through the local API gateway, including response
and transaction completion. There is no internal-helper certification path,
warm-up preparation, retry or raised limit in these three samples.

| Sample | Complete REST latency | Exact replay | Result                                                          |
| ------ | --------------------- | ------------ | --------------------------------------------------------------- |
| 1      | 13,032.933ms          | 43.661ms     | 236 defaults / 236 promoted families / 12 Draft POs / 236 lines |
| 2      | 13,425.855ms          | 55.470ms     | 236 defaults / 236 promoted families / 12 Draft POs / 236 lines |
| 3      | 12,467.960ms          | 50.846ms     | 236 defaults / 236 promoted families / 12 Draft POs / 236 lines |

All generated defaults are `PRIORITY_RECOMMENDATION`, with zero MANUAL defaults.
[Independent REST results](../testing/artifacts/atlas-preferred-supplier-school-first/source-reuse/independent-rest-samples.json)
retain raw timings/counts. An additional successful REST preparation reused the
existing scale invariant assertions: all quantity, preferred-Supplier, origin,
fingerprint, contribution/Handoff/PO lineage, no-partial/no-duplicate and exact
replay/fact/receipt assertions passed. Its 15-second assertion failed while both
20-second assertions passed: [full 24-assertion record](../testing/artifacts/atlas-preferred-supplier-school-first/source-reuse/rest-scale-invariants.tap).
This additional warm-path failure is retained, not a successful certificate.

Controlled late REST rejection took **11,612.137ms**. Nontransactional observation
recorded one PO insert attempt, all 236 default revisions and all 236 current
promoted families. The entire business snapshot was unchanged after rejection;
only the failed outer receipt was added and all accepted child receipts rolled
back. [Rollback result](../testing/artifacts/atlas-preferred-supplier-school-first/source-reuse/late-rest-rollback.json).

The real overlapping-chain regression passes 9 assertions: independent one-day
and seven-day input sets share approved sources and expose 472 current families.
The batch-only view exposes 236; both the canonical projection and resolved writer
reject the overlaps without an allocation. The fixture adds only optional source
reuse, with all business triggers active; the existing normal fixture is retained.
The test is registered in the existing include-aware full-integration runner.

A separate concurrent REST proof pauses allocation insertion with a test-only
advisory latch, then commits the other overlapping batch after cache capture.
All 236 writes were observed before the final refreshed check rejects with the
existing public `CONFIRMED_ALLOCATION_NOT_READY` response. Durable family/Handoff
counts are zero and Confirmed Need remains `DRAFT_REVIEW`.
[Concurrent-source result](../testing/artifacts/atlas-preferred-supplier-school-first/source-reuse/concurrent-source-refresh.json).
Test-only latches/functions/sequences were removed; subsequent local resets retain
only repository migrations. No production advisory lock was added.

### Remaining performance evidence and validation

The unchanged checkpoint reproduced cancellation at 20,061.120ms in per-family
`purchase_review_confirmed_projection`. A preliminary source-reuse profile removed
those calls: materialization 1,958.503ms and 472 persistence calls (including
promotion) 788.447ms. Its successful body/guard total was 13,639.950ms. This profile
predates the final after-lock/final-refresh strengthening; final materialization
was not separately instrumented.

Retaining earlier synthetic operating days in the same database produced complete
REST latencies **12,897.504 / 16,026.502 / 17,911.614ms**. All three succeeded and
replayed exactly, but the latter two exceed the 15s target. [Cumulative results](../testing/artifacts/atlas-preferred-supplier-school-first/source-reuse/cumulative-rest-samples.json)
are additional scaling evidence, not independent fresh-fixture certification.
The long single-session SQL fixture also had 20s cancellations after reaching
Handoff or in existing Planning integrity checks. It is not certified as passing.
No timeout, test or assertion was weakened to hide these results.

The next measured hotspot is existing Confirmed Need release/integrity work:
the preliminary complete profile attributed 8,091.023ms to release, with repeated
membership/validation/approval guard work visible. No Planning optimization is
retained. Reliable latency on warm/cumulative operational history requires Product
review or a separately bounded investigation; this follow-up stops at the approved
source-resolution correction.

Procurement currentness/regression: **187/187**, including priority changes,
inactive Supplier, tie/no priority/no eligibility, manual override, late rollback
and released-PO immutability. Requested frontend tests: **108/108** across the
three current files and preserved local baseline copies; semantic no-op Save,
baseline restore, UNKNOWN handling and exit behavior pass. No frontend file changed.
Independent source/security/code review found the cache-wait window, which was
corrected and exercised by the concurrent proof; no actionable finding remains.

Final standard backend integration and current-head GitHub Actions results are
recorded at delivery. Routine full frontend validation remains CI-owned.
Forward rollback restores the prior seven-argument persistence body and
materializer before removing the two new seams, or restores the four pre-#370
functions before removing all five helpers. Accepted facts/commitments remain.
Staging, Retool and OPS v1 are untouched; no hosted database command was issued.

## Checkpoint handoff — authorized 2026-10-13

Continue on branch `fix/atlas-preferred-supplier-default-school-first` in existing
Draft PR #370. Fetch the checkpoint before making changes; do not create a new PR,
merge, mark Ready, deploy Staging, or modify Retool/OPS v1. The report below records
the pre-push remote authority and measurements; the new checkpoint publishes the
retained local revision, not a passing performance certificate.

Retained: semantic no-op Save correction, generated 236-family fixture and full
correctness/replay/late-failure assertions, the API-only 20s setting and revised
15s complete-command target. Rejected projection optimization remains reverted.
All published backend bodies are intact. Preserve the canonical global family
ambiguity check in any separately approved projection-reuse follow-up.

The performance gate is still blocked; release, Handoff, PO preparation, successful
replay and controlled late rollback were not reached. Full integration was not
run for this revision. Resolve the performance decision before completing those
acceptance gates. Do not substitute the reverted experiment's measurements for
the published-backend results.

The isolated local stack was stopped and temporary Supabase configuration restored.
Staging remains at migration 102. For the scale SQL harness, use an isolated migrated
local database and `ATLAS_LOCAL_DB_CONTAINER`, then run
`node scripts/test-local-purchase-review.mjs purchase_preparation_scale.sql`.
It explicitly emulates PostgREST timeout hoisting; actual REST timing includes the
whole transaction and must also satisfy the approved target.

## Revised Purchase Preparation budget — Product decision 2026-10-13

This decision supersedes the earlier 7-second certification margin and the
interpretation of the authenticated role's 8-second infrastructure default as a
Purchase Preparation Product contract. Need Generation retains its separately
approved performance requirement.

| Layer                                | Current contract                           |
| ------------------------------------ | ------------------------------------------ |
| Global authenticated role            | 8s, unchanged                              |
| Global anonymous role                | 3s, unchanged                              |
| Purchase Preparation RPC             | Function-specific 20s hard statement limit |
| Certified 236-family operator target | Complete public command below 15,000ms     |
| Frontend RPC transport               | 45s, unchanged                             |
| Lock policy                          | Existing bounded policy, unchanged         |

Only `atlas_api.prepare_school_catering_purchase_orders(jsonb)` receives the
exception. PostgREST hoists its function setting before executing the statement;
a direct SQL caller must apply the setting before its top-level statement to
reproduce that transport behavior. Other reads, Saves and validation commands
retain their role safeguard. Owners, signatures, capabilities and function bodies
remain those at published head `2f185644b8b64387294192519d5128ffb744193a`.
The unmerged/undeployed migration 103 is revised in place with one ALTER FUNCTION;
no migration 104 or Planning rewrite is introduced.

Execution plan:

- Retain the approved semantic no-op Save correction and deterministic fixture.
- Configure only the public Purchase Preparation function; verify the role defaults
  and function setting, and use actual authenticated PostgREST requests locally.
- Run three independent fresh 236-family samples, each with zero allocations and
  valid current defaults, without retries or discarded warm-up preparations.
- All three below 15s permits correctness, replay, controlled late rollback,
  currentness and required integration validation. A 15–20s result requires Product
  review; a 20s timeout requires a new bounded performance decision. Neither
  outcome authorizes restoring the rejected optimization or changing Planning.
- Preserve Staging migration 102 and the published Draft PR head. Stop for a final
  local Product review before any commit/push.

References: [Supabase timeouts](https://supabase.com/docs/guides/database/postgres/timeouts),
[PostgREST hoisted function settings](https://docs.postgrest.org/en/stable/references/transactions.html#hoisted-function-settings).

## Local review — 20-second exception experiment

**TASK_STATUS: BLOCKED — published backend exceeds the provisional 20-second budget.**

**BASE_SHA:** `2f185644b8b64387294192519d5128ffb744193a`.
Only the API function's setting changed: migration 103 adds six lines (comments,
one ALTER FUNCTION); existing production function bodies modified: 0; function
configuration modified: 1; new private helpers: 0. Public signatures/payloads,
locks, owner/ACL, global role settings and Planning production code are unchanged.

Three independent fresh local databases used published function bodies, 236
positive current families, zero initial allocations and valid unique defaults.
The setup's seven checks passed in each (two configuration and five business
preconditions). Each sample made exactly one authenticated PostgREST HTTP prepare
request, without a retry or preparation warm-up. Local PostgREST v14.15 applied
the function's 20s setting while authenticated stayed 8s and anon stayed 3s.
Sample three used function profiling. Its profiling setup was corrected before
any preparation request; its business call still used authenticated HTTP.

| 236_PERFORMANCE    | HTTP elapsed ms | Result                            |
| ------------------ | --------------: | --------------------------------- |
| Sample 1           |      20,587.010 | SQLSTATE 57014, statement timeout |
| Sample 2           |      20,282.675 | SQLSTATE 57014, statement timeout |
| Sample 3, profiled |      20,330.380 | SQLSTATE 57014, statement timeout |
| Max                |      20,587.010 | No successful completion          |
| Median             |      20,330.380 | No successful completion          |

HTTP timing includes transport and cancellation response overhead; these are
20-second database cancellations, not successful 20-second command durations.

**PROJECTION_PROFILE:** the historical published 8s sample recorded 13 completed
source projections / 7,662.005ms and 10 writer calls / 5,908.132ms. With the 20s
exception, the published backend recorded 36 / 19,452.791ms and 33 /
17,624.338ms respectively. Writer self time was 59.236ms. Supplier advice was
31.357ms; source and default-evidence locks totaled 30.003ms. Nested totals
overlap. The cancellation stack was materializer → allocation persistence →
validated facts → canonical evaluation. The larger budget allowed more families
but retained the repeated whole-source projection hotspot.

| Validation              | Current local result                                                                                                                                  |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| NO_OP_SAVE              | PASS: 18 selected semantic cases; 38 outside the focused filter                                                                                       |
| 236_MATERIALIZATION     | FAIL: 0 durable defaults after cancellation; exact quantity/origin success assertions not reached                                                     |
| HANDOFF / PO            | NOT REACHED; sample three retained 0 Handoffs and 0 POs for the scale batch/date                                                                      |
| REPLAY                  | NOT REACHED: there is no successful durable preparation response to replay                                                                            |
| ROLLBACK                | Timeout cleanup observed: 0 allocations and Draft Review in all three samples. Controlled late PO failure NOT REACHED                                 |
| CURRENTNESS             | Priority change, inactive, tie, no priority, no eligible, manual override and released-PO cases NOT RE-RUN; published baseline evidence is historical |
| FULL_INTEGRATION        | NOT RUN: complete-path performance gate failed                                                                                                        |
| Formatting / whitespace | PASS; no tests or timeouts weakened                                                                                                                   |

NARROWED_DIFF before the handoff-note addition: **10 files, +2,037/−26** against BASE_SHA, including new SQL files.

Fixture reduction: 858 → 819 lines, deterministic generation retained; scale test
838 lines with all prior 40 assertions plus two configuration checks (42 total).
The follow-up production delta remains six migration lines. No new table/index,
Planning function, API payload, shared script, workflow, Retool or OPS v1 change.

Staging was checked read-only: **102 migrations**, latest
`20261012064517_atlas_positive_correction_fast_path`. Draft PR #370 remains open,
unmerged and at `2f185644b8b64387294192519d5128ffb744193a`. No commit, push,
Ready transition or deployment occurred.

Next bounded option for Product review: reuse canonical source projections once
inside Procurement materialization, preserving global family ambiguity rejection
and one allocation writer. This would affect only materializer/writer definitions
and at most one private seam in migration 103, plus the focused scale tests.
The published `purchase_review_persist_allocation` compatibility path must remain
identical, and Planning release/validation/Handoff/PO bodies remain untouched.
This proposal is not implemented; the reverted experiment cannot be restored
without repairing its ambiguity regression and renewed approval.

## Historical performance evidence — superseded gate, reverted experiment

Before the 13 October Product timeout decision, the published backend was measured
with the authenticated 8-second default: 8,110.892ms, 8,089.833ms and 8,103.219ms,
all cancellations. Its profile recorded 13 source projections / 7,662.005ms and
10 allocation-writer calls / 5,908.132ms inclusive. Source/Supplier/master locks
were approximately 15.450ms. Nested totals overlap.

The subsequently approved projection-reuse experiment was reverted. It completed
materialization in 1,013.513ms and 236 writer calls in 379.712ms, then timed out at
8,099.870ms in existing Confirmed Need release integrity work. It also did not
preserve the canonical global count-one ambiguity check across overlapping
current batches. Neither its implementation nor its results certify this retained
revision. No second optimization or Planning rewrite was retained.

The retained frontend correction compares the exact derived or persisted manual
baseline, including backend-compatible notes. Clean Open/Close performs no Save;
restoring the baseline disables Save. Previous complete focused runs passed
62/64 with two unchanged School-picker 5-second timeouts; those tests and workflow
were not modified. Fresh focused results and the current 20-second experiment are
reported separately below. The scale fixture uses deterministic generated rows,
4 Schools × 59 Ingredients and 12 reused Suppliers, with complete guarded lineage.

The change removes ordinary per-row Supplier confirmation when current master
data already supplies a deterministic default, and makes School identity lead
both operating tables. It implements the approved amendment to
[PA06D-11](../decisions/decision-pa-06d-quantity-truth-and-write-fidelity.md),
[BR-049](../business-rules/business-rule-register.md), and the existing
[Procurement contract](../api/school-catering-procurement.md).

## Product semantics

- Complete current positive Confirmed Need with no persisted allocation and one
  unique ACTIVE/effective lowest non-null priority Supplier has a derived 100%
  default. The read keeps `splits` empty and `state = UNALLOCATED`; the UI presents
  the backend recommendation as the resolved normal case (`Đủ`, default-priority
  label, and `Thay đổi`).
- No eligible Supplier blocks. Missing effective priority and best-priority ties
  remain unresolved; Supplier name, UUID and row order never decide allocation.
- Exact persisted overrides, multi-Supplier splits and supplier notes take
  precedence. Existing stale/rebalance rules remain explicit.
- One-day preparation rechecks authoritative source and current Supplier facts,
  materializes missing defaults atomically through the existing writer, and
  continues through strict Planning release, Handoff promotion and PO drafting.
  It creates no separate operator confirmation action or per-row receipt.
- Priority changes before materialization follow current effective master data.
  Changes afterward do not silently replace accepted allocations or rewrite
  released Supplier commitments. Existing correction/replacement boundaries stay.
- Allocation reads retain 1–7 day context with independent dated defaults.
  Multi-day preparation remains unavailable. Standalone Planning release still
  writes no Procurement fact and retains its persisted-allocation prerequisite.

## Changed files and boundaries

Backend: one forward migration,
`supabase/migrations/20261012101517_atlas_preferred_supplier_default_preparation.sql`,
and the existing purchase-review/security-catalog SQL tests. It adds three private
coverage, materialization and lock helpers; it updates existing allocation
persistence, preparation status, confirmed allocation read and preparation RPC.
No table, enum, public API, capability, dependency or browser table grant is added.

Frontend: the Procurement table, detail and workbench; their tests and review
fixtures/stories; the new shared presentation helper
`src/vnext/atlas/procurement/procurementAllocationPresentation.ts`; Confirmed Need
table/tests/fixtures/stories; and the existing unresolved-exit integration test's
row-action selector. It reuses the Atlas provider, tokens and table contracts.
Supplier selection remains backend-owned. Exact quantity parsing/editing, Save,
reload, Shopping List, reason requirements and unknown-outcome rules are retained.

Documentation updates the existing Procurement/Planning API contracts, convergence
decision/authority map, PA06D-11, QRR-016 and decision/business-rule registers.
There is no parallel architecture or generic workflow.

## Acceptance evidence

| Requirement                                          | Evidence                                                                                                                                                                                       |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Workbench read is write-free                         | `complete_positive_read_is_write_free` compares family, revision, receipt, Handoff and PO counts before/after repeated complete positive reads; persisted splits remain empty.                 |
| Unique default progresses to purchase preparation    | `derived_default_prepare` succeeds with exact authoritative quantities; default history carries the outer preparation command and is promoted through real Handoff to PO drafts.               |
| Current Supplier facts win over stale browser advice | `derived_priority_change` and `derived_inactive` begin from earlier advice, change priority/activity, then prove preparation selects the current safe Supplier.                                |
| Manual override wins                                 | `derived_manual_mixed` retains the exact explicit `72.000000 + 48.000000` split and materializes only the other missing family.                                                                |
| Tie/no priority/no eligibility stay unresolved       | `derived_tie`, `derived_no_priority` and `derived_no_eligible` reject preparation with zero partial allocation/Handoff/PO business writes.                                                     |
| Preparation is atomic                                | `derived_po_failure` reaches the final PO write, then proves rollback of materialized defaults, release, Handoff, drafts, events and child receipts.                                           |
| Released PO stays immutable after priority changes   | `released-priority-read` and `released-priority-reprepare` succeed; released roots, revisions/lines and exact grouped Supplier quantities compare byte-for-byte with their original snapshots. |
| Range contract remains                               | One-day reads expose preparation; seven-day reads preserve dated rows and return no preparation authority.                                                                                     |
| School-first tables                                  | Both tables begin with sticky sortable School/location, then an independent Ingredient cell; tests cover default School → Ingredient sorting and exact trimmed name deduplication.             |
| Ordinary 236-row case needs no per-row work          | 12/10 synthetic fixture renders 236 safe defaults, `Cần xử lý 0 · Đã đủ 236`, direct Supplier names, `Mặc định #1`, `Đủ` and `Thay đổi`; search and exception filters retain their behavior.   |
| Keyboard/focus retained                              | At 390px, focused Confirmed Need quantity starts at x=239, exactly beside the pinned School cell's right edge, and fits the visible viewport.                                                  |

## Validation at the published head

Focused backend checks pass: purchase review 187/187, platform security 29/29,
Handoff allocation 88/88, purchase orders 135/135, Planning correction 23/23,
Handoff clock skew 6/6, atomic Planning boundaries 258/258, zero-demand 72/72,
allocation convergence 417/417, and final closeout 17/17 plus its authenticated
browser Save/reopen and performance probes.

Formatting, typecheck, build, vNext boundary and diff whitespace checks pass.
`pnpm test --maxWorkers=2` passes all 214 files and 2,962 tests, including the
current Procurement/Confirmed Need, Save/reload, UNKNOWN and exit-lock suites.
`pnpm certify:supabase:full-integration` passes the complete ordered SQL catalog,
both local resets, authenticated browser Save/reopen proof, performance checks,
all local journey verifiers and final stack cleanup. Generation performance p95
is 2,919.908ms against the existing 4,000ms target. No tests or timeouts are
disabled or weakened.

Local test discovery initially included an ignored `.superpowers` baseline copy;
its code/test directories were temporarily preserved under `node_modules` for
repository validation and restored afterward, without changing their contents or
dependency junction. These local snapshots can affect future unfiltered test
discovery; they are not part of the tracked repository or CI. The initial high-parallelism
run exceeded unrelated test time budgets during concurrent validation. The final
full frontend command limits worker concurrency to two and retains all tests and
timeouts. Two deterministic exit-test selectors were updated for the approved
default action label; their UNKNOWN/retryable assertions remain unchanged.

Independent review found and resolved alternate eligible-Supplier search,
exact text deduplication, pinned-cell focus visibility and explicit owner-SET
membership regression coverage. No actionable product/architecture findings remain.

## Browser evidence

All six captures use the actual workbenches and explicitly labeled synthetic
12/10 fixtures through a temporary plain local Vite harness. The Procurement
fixture contains 236 rows; Confirmed Need contains six representative equal and
distinct School/destination identities. These are local acceptance evidence,
not new Staging observations. No hosted RPC was called.

- [Confirmed Need, 1440×900](../testing/artifacts/atlas-preferred-supplier-school-first/confirmed-need-1440x900.png)
- [Supplier Allocation, 1440×900](../testing/artifacts/atlas-preferred-supplier-school-first/procurement-1440x900.png)
- [Confirmed Need, 1366×768](../testing/artifacts/atlas-preferred-supplier-school-first/confirmed-need-1366x768.png)
- [Supplier Allocation, 1366×768](../testing/artifacts/atlas-preferred-supplier-school-first/procurement-1366x768.png)
- [Confirmed Need, 390×844](../testing/artifacts/atlas-preferred-supplier-school-first/confirmed-need-390x844.png)
- [Supplier Allocation, 390×844](../testing/artifacts/atlas-preferred-supplier-school-first/procurement-390x844.png)
- [Browser assertions and geometry](../testing/artifacts/atlas-preferred-supplier-school-first/browser-evidence.json)

Desktop rows remain about 52–53px and narrow rows about 57px. School identity stays
pinned during horizontal scrolling. Both surfaces have separate Ingredient cells,
zero page errors and zero hosted RPC calls. Storybook's existing focus
instrumentation raised `Illegal invocation` in the Confirmed Need story; the
plain Vite harness renders the same components/fixtures without that preview
instrumentation. No dependency or production behavior was changed to suppress it.

## Security, rollback and delivery

Existing owners, empty search paths, forced RLS, capability/scope checks,
fingerprints, exact equality, receipts, replay and retryable/unknown handling
remain authoritative. Private helper execution is limited to the required
runtime owners. The permanent `postgres → atlas_owner` SET membership is retained;
temporary runtime SET/CREATE memberships are removed. The security test now checks
the exact membership catalog row, independently of effective role ability.

Forward rollback restores the four prior function definitions before removing
the three private helpers. Accepted allocation/Handoff/PO facts must be retained;
rollback never deletes materialized history or changes released commitments.
Historical migrations were not edited.

Retool and OPS v1 are untouched. Atlas Staging is not deployed. Mantine retirement,
new tables/dependencies and unrelated module cleanup are outside this task.
Delivery is one Draft PR, unmerged, followed by Product review.
