# Need generation and Unit-label execution — 21 October 2026

Owner-authorized implementation of the [approved plan](../superpowers/plans/2026-10-21-need-generation-unit-label-improvements.md).
Source base `cb7f6098a80b00c846d5a45cf6edce2e6e231bde`; canonical E: checkout,
bounded branch `fix/need-runtime-unit-labels`. Preserve OPS_SYSTEM_MAP v1.0,
explicit facts and decisions, backend authority and frozen issued documents.
OPSv1, Retool and synced project sources remain read-only.

Implementation is under validation. This report does not yet certify deployment
or the new hosted original/correction journey.

## Bounded changes

Generation completion, exact quantities, receipts, source membership, currentness,
rollback, immutability and authorization remain acceptance requirements. Generation
probes now retain finite runtime observations and sample count/median/range without
the former 7/8-second cutoff or four-second target. Correction maintenance and
unrelated read/lock protections are unchanged. Existing provider constraints still
apply; this does not promise unlimited HTTP execution.

Migration `20261021082539` materializes the exact released contributions within
the initial Confirmed Need revision INSERT. No authority is reused across
statements or requests. Original source/identity predicates, arithmetic, grouping,
policy resolution, locks and triggers remain; the correction branch and existing
generic-plan setting are unchanged.

Migration `20261021083329` carries nullable descriptive Unit names through both
reconciliation scope readers, the comparator and grouped totals. Captured issued
names take precedence at detail and Unit-total grain. Missing captured names stay
missing; conflicting captured names yield no summary name. PO-only additions
cannot rename an issued Unit total. Identity remains `(ingredient_id, unit_id)`.
Current and compatibility UI reuse the existing formatter and local search;
malformed optional metadata fails closed. No master lookup or history backfill.

## Evidence and measurement limits

The original hosted 19-line/two-School generation took **14,630 ms** after two
failed attempts; [the baseline](artifacts/hosted-journey-2026-10-21/runtime-baseline.json)
preserves those results. The new scale fixture has **304 contributions / 248 lines**.
These are different workloads; do not compare them as a percentage improvement.

An initial actual nested plan reopened release membership **75,392 times** and
visited **11,459,584 rows**, with **528,965 buffer hits** in the proposal INSERT.
The first proposal-only candidate used **304 scans / 46,208 visits / 176,957 hits** in that paired
diagnosis. Profiled INSERT time was 2,231.486 ms before / 351.644 ms after; full
profiled generation was 5,098.508 / 3,353.988 ms. Nested times overlap.

Subsequent planner states changed that result: the original definition also
selected the 304-scan plan, while the proposal-only candidate reproduced
**75,392 / 150,784 / 226,176 scans** across three sequential generations. That
candidate was rejected before release. Materializing the released source rows
directly addresses the repeated join; the retained profiles and paired samples
record the revised candidate separately.
[The disposable profiler](../../scripts/profile-local-need-proposal.mjs) preserves
actual nested plans and checks scan count; its parser has focused tests. The
source boundary prevents repeated base-table work within that INSERT; these
plans alone do not establish a universal end-to-end latency improvement.

The revised executed plans read membership **304 / 608 / 912 times**, bounded
by retained source history in each statement rather than target × source pairs.
The rejected candidate used **75,392 / 150,784 / 226,176**. The matching INSERT
profiles fell from 2,255 / 5,296 / 8,389 ms to 55 / 95 / 88 ms; these overlapping
diagnostic timings are not additive or hosted latency promises. Actual scan
evidence is retained [before](artifacts/need-generation-improvement/source-join-before.json)
and [after](artifacts/need-generation-improvement/source-join-after.json).

Final paired sampling used a new equivalent empty clone for each trial, with
three fresh daily generations per clone and alternating build order. Every
baseline function body was checked exactly against canonical main. All **30**
generations and valid-path semantic assertions passed. The clones preserve the
same workload and accumulating three-day history, without prior rollback heaps.

| Database-command observation |                 Before |                Revised |
| ---------------------------- | ---------------------: | ---------------------: |
| Fresh clones / generations   |                 5 / 15 |                 5 / 15 |
| Median                       |           3,859.730 ms |           3,003.547 ms |
| Minimum–maximum              | 2,887.561–5,525.819 ms | 2,659.390–3,678.188 ms |

[Every sample and first-generation observation](artifacts/need-generation-improvement/fresh-comparison.json)
is preserved. These small local samples support an improvement in this scenario;
they do not establish p95, cold-cache behavior or a hosted service guarantee.
The earlier single-database sampler reused rollback heaps and did not isolate
storage/statistics carryover; it was stopped after that experimental-design
problem was identified. Its slow successes, actual cutoff failures and deliberate
cancellations remain [separate observations](artifacts/need-generation-improvement/earlier-observations.json).

Early paired runs overlapped local test-worker failures and diagnostic work.
They include a 67.240-second successful generation and are retained as contended.
A subsequent baseline attempt reached an existing internal 120-second cutoff;
it failed receipt/completion checks and is not counted as success. The earlier candidate
then passed all **43** full scale assertions with three fresh generations at
**3,282.609 / 3,522.343 / 4,371.617 ms**. Further controlled samples are recorded
alongside their outcomes, not filtered by speed. Its later failure also remains
recorded. The obsolete sampler was deliberately cancelled after diagnosis, not
to declare it fast or successful.

Staging has `jit=off`; the local container defaults to `jit=on`. Matching this
setting alone did not eliminate the old outliers, so JIT is not identified as
their cause. Final paired samples use Staging's observed setting for both builds;
no global or hosted setting was changed. PostgreSQL documents [cost-based JIT
selection](https://www.postgresql.org/docs/17/jit-decision.html), which is one
reason to retain runtime settings with measurements.

Local profiling used PostgreSQL 17 in the existing Docker container and only
owned database `atlas_need_runtime_20261021`. No unrelated stack/database was
reset. The cloned diagnostic schema has a historical migration-metadata mismatch
(130 recorded versions despite an already installed read function); it is not
clean-install certification. Required CI installs all source migrations anew.
Contemporaneous local resource snapshots cannot explain past hosted latency;
hosted CPU/I/O/memory/lock-wait correlation remains unknown.

## Focused correctness and review

- Reordered/slow generation probe regression: valid 14,630 ms result RED → GREEN;
  negative/nonfinite observations and business failures still rejected.
- Unit summary/detail rendering and malformed metadata: RED → GREEN.
- Independent review found preview metadata could rename issued totals: two
  failing SQL cases RED → GREEN; comparator suite **25/25 PASS**.
- Actual current/compatibility scopes, master rename, missing captured names,
  immutable PXK and relational authorization: **144/144 PASS**.
- Initial focused UI run: **226 tests passed**, two worker-startup errors under
  concurrent load; affected files rerun sequentially with pending/unknown tests:
  **155 tests / 6 files PASS**. No skipped test or increased timeout.
- Existing generation stays RUNNING through authoritative readback, prevents a
  duplicate and recovers UNKNOWN without resubmission: PASS, no controller change.

Independent whole-change review found no weakened owner, definer, empty search
path, privilege lease, arithmetic, source/history or security boundary. Its Unit
total provenance finding was fixed with the failing cases above. Final required
CI, guarded deployment and full fresh disposable/hosted journeys remain pending.

The final fresh source review also verified the revised initial source join's
multiplicity, null behavior and location selection, and found one tooling issue:
psql renders a bare boolean as `t`, while the profiler required `true`. The real
psql boundary failed before a SQL text cast and passed afterward; the complete
three-generation CLI now passes with the retained-history scan bound. No further
Critical or Important source finding remained. All **1,043 assertions across 12
focused SQL files pass**, including revised full scale, effective composition,
zero demand, atomic boundaries, receipt/security catalog, membership/history,
initial/corrected materialization and concurrency/authorization regressions.
The final focused frontend suite passes **377 tests / 23 files**; TypeScript,
UI boundary, formatting and whitespace checks pass. Normal full GitHub CI remains
the integration gate.

Source `51364404` Frontend CI `39580741934` passes. Executed Full Integration
`39580763655` reaches the connected reconciliation UI and fails its old oracle:
the UI correctly shows captured `kg`, while the test still expects
`v1-unit-disposable-kg`. Exact statuses and quantities match. The corrected oracle
uses the independently frozen document's Unit name, additionally pins backend
Unit-name metadata and rejects visible technical codes; no quantity, scope,
document or history assertion is removed. Changed-source certification is pending.

Staging authenticated `statement_timeout=0` remains the explicitly disclosed
prior rehearsal lease. This change does not alter it; anon 3s, authenticator
statement/lock 8s and existing function protections remain distinct. Decide the
longer-term operational resource policy using measured outcomes, not a forced
eight-second restoration.

Executed Full Integration `39583917118` on `037ca347` passes, including the
connected reconciliation oracle. Frontend `39583917194` passes 3,181 assertions
(with two existing skips) but fails an unhandled Mantine transition callback
after jsdom teardown in the compatibility reconciliation test. Local unmodified
focused execution did not reproduce the race. Test-scoped controlled timers now
settle transitions inside React act before cleanup, assert no remaining timers,
and restore real timers in finally. Focused 16 tests across two files pass;
product behavior and assertions are unchanged. Fresh normal CI remains required.
