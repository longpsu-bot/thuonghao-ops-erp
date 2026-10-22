# Need generation runtime observation

Correct completion is the functional gate. Record runtime; do not reject a valid
generation solely because it exceeds an arbitrary latency target.

Use the existing `supabase/tests/need_generation_operational_scale.sql` fixture in
a disposable database, with all migrations and normal integrity/authorization
checks. It retains exact 304-contribution/248-line geometry, replay, receipts,
source membership, failed-package rollback and immutable-history assertions.
Elapsed values, sample count, median, minimum and maximum are diagnostics.

Compare the same source geometry, retained history and environment before/after.
Keep initial and subsequent generations separate; idempotent replay is not a
fresh-generation benchmark. Small samples do not establish a tail percentile.
Record failed attempts too, their business result and whether anything committed.

The fixture already profiles function calls and self-time transaction-locally.
For deeper diagnosis, use nested EXPLAIN in the owned disposable database only.
EXPLAIN ANALYZE runs writes: never use it as a read-only hosted command probe.
Nested/inclusive times overlap; do not add them as independent phase costs.
Remove diagnostic function changes and restore profiling settings afterward.

For the 304-contribution fixture, run the retained diagnostic against an empty,
owned local database with the appropriate migration revision installed:

```text
node scripts/profile-local-need-proposal.mjs supabase_db_<local-project> atlas_<disposable-database> <report.json>
```

It executes only synthetic setup and three fresh authenticated generations, rolls back,
retains the actual nested plans beside the report, and checks release-member
scan count rather than elapsed time. The database must be disposable; the tool
cannot connect to a hosted project. Run the complete semantic fixture separately.
An earlier planner state reopened membership 75,392 times; after local table
statistics changed, the original definition also selected the 304-scan plan.
Preserve both observations. Statement materialization prevents the observed
inlining fan-out; do not present it as a universal latency improvement.

The current bounded optimization materializes the exact released contributions
within the initial revision INSERT. Policy, locks, rounding,
lineage, stale-source rejection, deferred constraints and authoritative readback
remain unchanged, as does the correction branch. No proof or cache survives
between statements or requests. The first proposal-only candidate was rejected:
it could still reopen the released contribution join in other planner states.

Record server/upstream time independently of browser wall time. Correlate CPU,
I/O, memory, lock waits and connection pressure at the same timestamps when
available; missing resource metrics are unknown, not an excuse to blame hosting.

The temporary Staging role-wide exemption is replaced by migration
`20261022071412`: only `atlas_api.execute_need_generation(jsonb)` receives
`statement_timeout=0`; `authenticated` returns to its existing `8s` default.
PostgREST hoists the function setting across the request transaction, including
deferred constraints. The existing Purchase Preparation `20s` exception and lock
protections remain. These are operational settings, not latency acceptance goals.
Provider/client limits can still end a request; this does not promise unlimited
hosted execution. Never automatically submit a fresh command after a transport
timeout; reconcile the existing intent first.

Before deployment, verify the actual authenticated REST path on an owned local
database with the deployed PostgREST configuration. A nine-second ordinary probe
must cancel, a scoped probe and its deferred guard must complete, and a following
ordinary request must still observe `8s`. Exercise the real Need command while
holding its existing scope advisory lock for less than the unchanged lock timeout:
the old default must fail with no committed change; the function policy must
complete the identical intent beyond eight seconds and replay without duplicates.
Keep these test-only probes out of hosted schemas and product functions. Retain
the observed durations and transaction counts; do not turn them into speed gates.
After guarded deployment, verify the exact catalog settings, run the full hosted
original/correction/replacement journey and compare released-history snapshots.

Rollback uses a reviewed forward migration restoring the prior function
definition. It changes no business rows. Preserve original PO/PXK snapshots and
repeat the complete original/correction journey after a deployed change.
