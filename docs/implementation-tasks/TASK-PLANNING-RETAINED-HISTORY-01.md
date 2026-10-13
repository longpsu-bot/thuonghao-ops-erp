# Purchase Preparation under retained operational history

Starting SHA: `868d79fffc5613b722c0f31c39006e8a6cbc9b43` (merged PR #370).
Branch: `perf/planning-confirmed-release-retained-history-01`.
Scope: one preparation capability, Planning access paths, the related Procurement
Draft query, the existing scale fixture, a disposable benchmark, and this record.
No UI, quantity policy, lifecycle, API envelope, timeout increase, hosted write,
Retool, OPS v1, merge, or deployment is authorized or included.

## Diagnosis

Retained history increases preparation cost, but the preliminary Planning lead
does not explain the continuing slope by itself. In the final matched baseline,
Confirmed Need release costs 8,466.452ms at seven prior days and 8,591.720ms at
fourteen. It remains the largest stage. Its 472 membership guards, 240 validation
guards and 241 approval guards are retained. Across the complete preparation,
canonical evaluation runs 27 times and validated-facts projection 15 times.
Their rechecks/evidence have not been removed, cached, or replaced.

Three concrete access problems were measured:

1. Membership completeness intersects the separate Ingredient and School indexes
   before filtering service date and Unit. At seven days the exact group lookup
   reads eight historical/current rows and filters seven, visiting eight heap
   blocks. The new positive operational-tuple index reaches one exact row.
2. A release partition plan walks the member-ID primary key to preserve grouping
   order, filtering 1,654 unrelated release members. The new release/member-ID
   covering index enumerates only the 236 target release members. The existing
   complete/current partition predicates remain intact.
3. The Draft ready-date supplier query evaluates family projections before its
   JSON ready-date semi-join. At seven days it projects 1,888 families and discards
   1,652 outside the date. EXPLAIN measured 642.586ms and 105,407 shared buffer
   accesses, versus 77.764ms and 13,793 with the redundant typed date predicate.
   The expensive work is now scoped before projection. Complete-command family
   projection calls were 16,992/23,600 at seven/fourteen days before, and 9,912 at
   both depths after. Historical current Handoff/allocation families drive this
   continuing reconstruction cost; no additional business validation is gained
   from projecting other dates and subsequently discarding them.

The profile also found a roughly 55MB external sort in the existing Confirmed
Need source projection, where the complete evaluation is carried into per-line
grouping. This is substantial fixed workload cost, not evidence of the measured
retained-date growth. It is left unchanged because the bounded correction meets
the operating target. No speculative Planning rewrite is included.

## Controlled complete REST results

Each measurement uses a fresh database clone of equivalent committed prior
history, then one target preparation. Before/after share the exact history
snapshot. Prior chains are prepared with production commands and all business
constraints enabled. The same master catalog, including eligibility identities,
is shared across every depth. All ten catalog hashes are identical:
`7290438383af548b7888a60eea6965f6fab5915dc84aceba87b0e67d0959bd02`.

Every prior operating chain has 236 families. The workload uses independent Monday
source windows to satisfy the approved Weekly Menu/Pantry fixture contracts, so
"prior days" denotes operating-day chains, not consecutive calendar dates. The
target date is 2027-04-26. Depth 14 contains 3,304 historical decisions, validation
observations and approval members before the target; each depth has the same four
Schools, 59 Ingredients and twelve Suppliers in the scale catalog. Template
reference rows are also constant and counted separately in the raw results.

All temporary setup objects disappear before measurement. Ordinary ANALYZE runs
at the same boundary. PostgREST restarts consistently to reset its prepared-plan
state; no target preparation warm-up, retry, ignored constraint, or timeout raise
is used. This controls backend plan reuse; it does not certify arbitrary
long-lived pooled sessions. Server/OS caches remain shared, and run ordering is
alternated where practical. These are local synthetic measurements, not Staging
SLA certification.

The target is a real JWT-authenticated public `atlas_api` PostgREST RPC with a
GoTrue-issued operator token. Only local fixture provisioning uses the admin key.
RPC timing includes response parsing and transaction completion. The local direct
PostgREST hop is measured; a separate Kong gateway hop is not included.

| Prior operating days | Before REST ms | After REST ms |
| -------------------- | -------------- | ------------- |
| 0                    | 11,400.819     | 11,689.025    |
| 1                    | 12,140.893     | 12,321.836    |
| 3                    | 12,835.150     | 12,621.401    |
| 7                    | 14,883.823     | 14,565.958    |
| 14                   | 16,131.220     | 14,804.306    |

The final after samples all complete below 15s. Between seven and fourteen prior
days, after latency increases 238.348ms (1.64%), and release changes from
8,541.624ms to 8,474.227ms. The corrected projection count stays constant. This is
evidence of bounded behavior across the tested history range, not a universal
claim for unmeasured history sizes or hardware.

Earlier exploratory results included 18,177.523ms at seven days and an index-only
candidate at 14,840.819ms. They used separately seeded databases before final
catalog normalization and paired snapshots. They are diagnostic leads, not the
final matched comparison or additional passing samples selected for the gate.

### Stage timings at fourteen prior days

Built-in `pg_stat_user_functions` is read after the first preparation and before
replay. Parent times include children; Handoff below subtracts its nested
promotion to avoid counting that stage twice. The public REST total remains the
acceptance measurement.

| Stage                       | After ms   |
| --------------------------- | ---------- |
| Default materialization     | 2,508.123  |
| Confirmed Need release      | 8,474.227  |
| Handoff excluding promotion | 875.246    |
| Allocation promotion        | 1,341.019  |
| PO Draft preparation        | 1,151.401  |
| Other/commit/REST remainder | 454.290    |
| Complete REST               | 14,804.306 |

## Implementation and preserved authority

Forward migration
`20261013042957_atlas_confirmed_need_retained_history_access_paths.sql` adds two
nonunique indexes and changes one Draft-query predicate. The typed inclusive
range is redundant because `v_ready_dates` is built only by
`generate_series(v_date_start,v_date_end)` and is rebuilt under the existing
locks. JSON readiness, current fingerprints, quantities, splits, locks, lineage,
and supplier eligibility remain checked. The migration asserts that replacement
changes no function catalog attribute except its body, including owner, ACL,
security mode and settings.

No integrity function, validation/approval evidence, deferred constraint,
currentness rule, D-046/D-047 rule, zero-demand rule, manual allocation authority,
released commitment or calculation changes. Migration 103 is byte-for-byte
unchanged. There are no new tables, functions, roles, grants, dependencies or UI
files. The private indexes add physical maintenance/storage cost only.

Standalone rollback drops the two new indexes and restores the prior Draft query
through a reviewed forward migration. It removes no business fact or commitment.
Index creation can briefly block writers; deployment remains a separate Product
decision and applies migration 103 before 104. No deployment occurred here.

Read-only Staging migration inspection on 2026-10-13 confirmed 102 migrations,
latest `20261012064517`; `20261012101517` is absent. Staging, Retool and OPS v1 were
not mutated. The 3s anon / 8s authenticated / 8s authenticator defaults and the
single preparation 20s exception remain unchanged. Frontend transport remains 45s.

## Verification record

Every final after-depth preparation produced 236 generated
`PRIORITY_RECOMMENDATION` defaults, zero generated `MANUAL` defaults, 236 promoted
families, twelve PO Drafts and 236 PO lines. Exact public response replay passed
at every depth. Full responses are compared in memory; only response hashes and
bounded observations are retained in the raw JSON artifacts.

The existing combined SQL scale run passes all 31 success assertions, including
exact quantities/lineage and unchanged business/receipt snapshots on replay, in
11,536.364ms. Its subsequent late-failure case still cancels at 20s in existing
Planning integrity work. This long-session limitation was already recorded by
#370 ([prior record](TASK-ATLAS-PREFERRED-SUPPLIER-SCHOOL-FIRST.md)). Rollback does
not remove aborted physical tuples or a backend's cached-plan state; ANALYZE is
not physical cleanup ([PostgreSQL vacuum/statistics](https://www.postgresql.org/docs/17/routine-vacuuming.html),
[plan caching](https://www.postgresql.org/docs/17/plpgsql-implementation.html#PLPGSQL-PLAN-CACHING)). The cancellation stack does not establish
which query consumed the budget. The failure log is retained, and no test or
timeout was weakened to conceal it.

The original scale SQL was split only at its existing second-case comment and
executed in separate psql sessions with a fresh migrated database for each case.
No assertion, constraint or budget changed. All 31 success assertions pass in
11,648.244ms; all eleven late-failure assertions pass in 11,148.218ms, reaching the
controlled PO insert after 236 defaults/promotions and rolling back every business
fact exactly. The exact TAP records are retained alongside the combined failure.

`pnpm certify:supabase:full-integration` passes all 113 certification commands on
the standard repository local stack, including Planning/Procurement SQL suites,
correction/legacy adoption, real-browser Save/reopen, and authenticated public
connection verifiers. An earlier invocation using the custom benchmark stack
stopped at an existing helper's hardcoded standard container; the successful
rerun used the supported standard stack without modifying that helper.
Error-level local security advisors report no issues. Focused Prettier and
`git diff --check` pass; read-only code/benchmark review reports no blockers.
GitHub owns routine Frontend CI. Its approved Supabase workflow runs Smoke for
Draft PRs and reserves Full Integration for ready-for-review, non-Draft updates,
main pushes or manual dispatch. Local Full Integration already passed; its
GitHub job is intentionally skipped on this Draft. Final CI status is reported
with delivery.

The standard integration suites retain coverage of
Save, validation/approval, source/currentness, correction/continuity, zero demand,
Handoff, priority/tie/inactive/no-eligibility behavior, manual authority, released
PO immutability and atomic rollback. The PR stays Draft for Product/architecture
review; no merge or Staging rollout is part of this task.

## Reproduction

Use only a disposable local stack with project ID `atlas-retained-history-01`,
the repository-pinned CLI, copied repository Supabase files, API port 56521 and
database port 56522. Set `SUPABASE_WORKDIR` to that stack's directory and
`ATLAS_LOCAL_DB_CONTAINER=supabase_db_atlas-retained-history-01`. Initialize at
starting SHA/migration 103 before adding the forward migration to after samples.

```powershell
pnpm exec supabase db reset --local --no-seed --version 20261012101517
pnpm benchmark:planning:history init
pnpm benchmark:planning:history seed 14
pnpm benchmark:planning:history before 7
$env:ATLAS_BENCHMARK_MIGRATIONS='["supabase/migrations/20261013042957_atlas_confirmed_need_retained_history_access_paths.sql"]'
pnpm benchmark:planning:history after 7
```

Repeat the last two commands at depths 0, 1, 3 and 14. The runner rejects another
project/container, extra template business artifacts, incorrect observed history
counts, changed role budgets, failed after preparations, incorrect output counts
and non-exact replay. New target databases are recreated from untouched history
snapshots for every call. Stop/remove the task's disposable stack after verification.
