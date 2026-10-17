# Issue 395 — Option A proof-sharing trial

Status: **CERTIFICATION IN PROGRESS / RELEASE BLOCKED**. One strategy only. The Owner must receive the final gate results before any disposition. No merge or deployment is authorized.

## Source and scope

The [execution ledger](../implementation-tasks/TASK-ATLAS-C388-OPTION-A-01.md) records canonical-checkout verification, approved authority and integration. Main is `3667966a3f6703a6585f07ba619969ec851ca7b8`; pinned C is `a443daf15dd9891611b387349268795efbce7d5c`; #392 is frozen at `6f9f288c76cfa48691fca2f4968ce03185502bb2`. Dependency merge `7027bcc` retains main's Autopilot documents; the two governance conflicts are resolved only on the new task branch. No SQL/UI conflict occurred. Existing #388 remains Draft and conflicting against main; neither its branch nor #392 was updated. Combined #392 integration is not certified.

Runtime candidate `3c6f98579521214643ccc1ba69de3ba5a500edfe` changes exactly one existing body: `atlas_core.purchase_review_continuity_context(uuid)`. The diff is against pinned C, not an unrelated inner validation-query rewrite. C's original SHA-256 `7d5a0a96f141c23adad51781827051df04a1a545fc513617abf9eccd7f6302c3` remains recoverable from the pinned Git object and previous evidence. No other historical migration was edited. C was verified absent from both the local migration registry and Staging's read-only registry before amendment.

## Actual proof and phase boundary

The existing source path is `purchase_review_confirmed_source_universe(uuid)` / `purchase_review_confirmed_batch_sources(uuid)` → `purchase_review_confirmed_sources(date,date)` → canonical evaluation and validated-facts projection. `purchase_review_correction_roots(uuid)` discovers the complete raw roots; `purchase_review_correction_context(uuid)` adds current sources. Neither body changes.

Previously the continuity context called `confirmed_need_handoff_membership(uuid)` for each discovered Handoff revision. The candidate lifts that unchanged helper's bindings into one materialized relational set, resolves each distinct batch/attempt through the unchanged `confirmed_need_historical_validation_evidence(uuid,uuid)`, expands exact facts once per pair, joins members and aggregates separately for each Handoff revision. Missing revisions/members still yield incomplete proof. Raw duplicated bindings are counted before aggregation. UUID member order and family/group keys remain identical.

`confirmed_need_historical_validation_complete(uuid,uuid)` retains every captured observation, R/D authorization, Unit, policy, run/release, missing/NULL, raw multiplicity, member count and SUM predicate. `confirmed_need_retained_release_evidence(uuid)` is unchanged. Both `purchase_review_family_continuity(uuid,text)` and `(uuid,text,jsonb)` retain all adjacent-edge, cycle/gap, exact source fingerprint, split and membership checks. PROSPECTIVE and OFFICIAL remain distinct.

The sharing seam is one STABLE statement with one snapshot and no lock/writes. It expires when that invocation returns. Existing readiness overloads `(uuid)` and `(uuid,jsonb)` are unchanged. Correction rechecks after its ordered lock waits; reopen/Save invalidates earlier source proofs. Planning release writes new validation/approval/release evidence; Handoff writes new revisions/member bindings; promotion writes changed allocation support. Each later consumer invokes a fresh context. PO readiness/frontier/coverage retain their existing official map and `(date,jsonb)` overloads. No context is carried through these writes, across public commands or between row triggers.

The deferred RMVP-07 approval/snapshot guards still run for each queued row, and still request full retained-release evidence at the approved lifecycle point. This strategy does not eliminate that amplification. Trigger definitions, enforcement, locks, idempotency, authorization, currentness and all public signatures remain unchanged.

## Fresh local checks

All seven original suites passed **588/588**: correction 103, continuity 137, consumers 58, catalog 31, PO 155, RMVP-07 67 and D-037 37. The additional phase-context suite passed **9/9**: exact incumbent-helper parity plus missing lines/identity/approval, duplicate raw demand, NULL release time/Unit and changed captured quantity. Existing changed→reverted, history corruption, scope and released-document tests remain intact.

The 497-function comparison identifies only the allowlisted source-body difference. Owner/ACL/configuration/SECDEF/volatility and all role, membership, schema and 117 protected relation images match exactly. The standalone local installation has 40 roles/40 memberships; this infrastructure count differs from preserved Actions' 42/44 and is not evidence of a runtime grant change. Every focused session restored its complete protected images. A disposable-clone ownership setup error was repaired without changing roles or Atlas privileges; previously passing suites were not rerun during that setup repair.

Three real competing-session public holders were exercised: PH allocation Save, correction containing the contributing CN Save, and overlapping Preparation. Each produced an observed blocking lock wait, `RETRYABLE_CONCURRENCY_FAILURE`, successful exact retained-request retry after release, and identical protected images after rollback. No deadlock occurred in these schedules; this is not an exhaustive proof of every schedule.

A separate small-fixture UNKNOWN trial retained the exact original request, discarded the command response, observed server commit independently, terminated that command transport and recovered via exact receipt replay. Protected images did not change on recovery. The initial recovery probe's `status`/`outcome` receipt-column typo is preserved as a failed harness result; the independent recovery-only trial repaired that typo and passed. This trial is distinct from scale acceptance and uses the small fixture's own quantities.

## Operational and performance gates

The local same-host baseline failed at the **initial Pantry Save's deferred guard flush**, before generation or corrected Preparation: 8-second public timeout; 8,923 ms process wall time including client overhead. It is an invalid Preparation comparison, not a measured Option A speedup or slowdown. Its complete rollback/catalog parity passed. No local scale retry or timeout increase was made.

One deliberate fresh-runner certification is [Actions run 39019375636](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39019375636), pinned to runtime candidate `3c6f985`. It installs pinned C, verifies the one-body/497-function parity, then runs the seven original suites plus nine additions. Its Tier 2 derivative retains all 20 original final assertions and adds eight checks after each of two complete ten-operation journeys: quantities 101 then 102, Handoff/whole PO/PXK successor counts, exact unrelated identities and original complete-command budgets. The original eight-cycle oracle SHA-256 remains `be82e771b059fe78c2b6353642a820c8a824257c9fe441241fa92963751589cb`; it runs once only after both operational journeys pass.

Preserved before measurements: 14,706.715 ms corrected Preparation baseline; prior lateral candidate 17,515.069 ms first complete operational Preparation, followed by second Preparation timing out at 20 seconds. These are separate historical runner executions. A fresh result cannot establish a causal percentage gain across those hosts, caches and instrumentation. The 236-family <15-second Procurement benchmark remains separate and was not rerun or substituted.

Fresh first/second/stress results and complete-command timings: **pending the single run above**. Limits remain 8 seconds public / 20 seconds Preparation / 1 second lock entry, with unchanged disclosed nested 5-second settings and constraint flushes included in complete-command measurements.

## Integration, rollback and decision

Exact-head Frontend CI and Supabase Smoke are separate checks on Draft [PR 396](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/396). **Full Supabase Integration is skipped**; no HTTP/browser acceptance or combined #392 certification is claimed. The independent reviewer found no remaining SQL/phase/oracle defect after the identified workflow/runner issues were repaired.

No data migration/backfill is needed for Option A. Before any hosted application, rollback means reverting only the reviewed unapplied C body delta to its preserved pinned definition. A future applied migration must remain immutable and would require a separately authorized forward repair. Disposable test data is contained in the task-owned, network-isolated container; existing local stacks and dirty source documents are preserved. Staging was read only for migration verification. OPS v1, Retool and Production received no writes.

Final verdict and specific Owner decision: **pending measured operational results; no further optimization strategy authorized**.
