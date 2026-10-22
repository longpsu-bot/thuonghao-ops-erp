# Supabase runtime and timeout investigation — 22 October 2026

Status: local repair verified and independently reviewed; normal exact-source CI,
guarded Staging deployment and the hosted journey remain pending.

## Bounded scope and authority

The Owner requests investigation, measured runtimes without arbitrary duration
gates, safe repairs and a complete journey after changes. Preserve
**FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED** and OPS_SYSTEM_MAP
v1. PostgreSQL retains all business authority, atomic commands, exact quantities
and Units, Actor scopes, receipts, idempotency, constraints and released history.
OPSv1 and Retool are read-only references. No supplier message or physical shipment
is authorized. Recipe3529 still needs a factual Owner/kitchen decision.

The smallest repair is a runtime policy, not a claim of faster calculation.
Migration `20261022071412` sets `statement_timeout=0` only on
`atlas_api.execute_need_generation(jsonb)` and ends the temporary authenticated
role-wide exemption by restoring the existing `8s` default. It requests schema
and config reloads. The command body, owner, grants, search path, generic planning,
lock protections and existing Purchase Preparation `20s` exception are retained.
No UI, public payload, lifecycle, dependency, capacity or region change is made.

The deployment verifier requires the exact three Need function settings and the
ordinary authenticated default; all other API configuration rules remain exact.
The existing operational-scale fixture gains two policy assertions and keeps all
43 prior semantic assertions. A missing Need exemption fails before the repair.

## Evidence before changing Staging

Staging is `rnzxmxiiqgtdevzregff`, PostgreSQL 17.6.1.155, 133 migrations with tip
`20261021083329`. Its authenticated role still has the rehearsal `0` timeout;
anon has `3s`, authenticator has statement/lock `8s`, and Need has no function
timeout. The SQL management session's 120-second setting is not evidence of the
authenticated REST policy. JIT is off and max connections is 60.

The initial snapshot shows six backends, no lock wait and no connection pressure
at that instant. It cannot explain previous slow requests. The five authenticated
Need entries in retained `pg_stat_statements` total 40,677.149 ms, mean 8,135.430 ms,
maximum 14,600.716 ms, with 5,814,202 shared hits, 1,158 reads and zero temporary
blocks for that entry. These aggregate multiple source/history states and do not
isolate the latest release. Database-wide temporary bytes are cumulative and
cannot be attributed to Need. Statistics are not reset on Staging.

The inspected 24-hour log window contains no returned statement/lock timeout,
deadlock, connection-exhaustion or out-of-memory message. This does not prove an
absence outside the window or exclude timeouts returned as business failures.
Advisors report 180 unindexed foreign keys, 182 unused indexes and 16 multiple
permissive-policy warnings; these do not establish a bottleneck in this command.
The function-only security model explains expected definer warnings; no blanket
index, RLS or privilege rewrite is justified.

The supplied Retool purchase/actual-need, Supplier selection, PO and dispatch/QA
flows and OPS system-map reference are reviewed without writes. Current Supabase
changelog and official timeout/PostgREST guidance are checked before implementation.

## Local measurements and actual REST proof

The owned disposable databases use the same PostgreSQL build as Staging. An old
template's migration metadata is incomplete: one replayed migration rejects its
already-present anchor. That setup attempt supplies no benchmark. Five canonical
function definitions are copied read-only from Staging into the owned local
database; all 493 function definitions, owners, configurations, definer modes and
ACLs then match Staging (catalog hash `1fb22ad2e738e8bb95707e54a20a5186`). The local
metadata still records 130 migrations; clean GitHub Full remains mandatory.

| Same 304-contribution / 248-Need fixture | Fresh generation observations        | Median       |
| ---------------------------------------- | ------------------------------------ | ------------ |
| Before policy repair                     | 2,834.208 / 2,927.144 / 3,716.909 ms | 2,927.144 ms |
| After policy repair                      | 2,695.772 / 2,961.041 / 3,632.054 ms | 2,961.041 ms |

All 43 original checks pass before; all 45 pass after. The samples establish
correct completion and ordinary variation, not a latency improvement or a tail
percentile. Profiles retain 993 generation-guard and 552 membership-guard calls;
their respective first-run self-times are approximately 874/758 ms before and
831/748 ms after. These checks remain intact. Local sampled CPU during generation
is about one core; it is not a hosted CPU measurement.

An isolated PostgREST `v14.15` instance reuses the local stack configuration and
connects only to the owned database. No hosted diagnostic function is installed.

| Actual authenticated REST observation                                    | Result                                                                   | Elapsed       |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------ | ------------- |
| Ordinary nine-second probe under existing default                        | SQL57014 cancellation                                                    | 8,385.448 ms  |
| Function-specific completion policy, nine-second body                    | HTTP200; lock setting still `8s`                                         | 9,027.882 ms  |
| Function-specific policy, nine-second deferred constraint                | HTTP200; row commits                                                     | 9,012.765 ms  |
| Following ordinary request                                               | statement/lock settings both `8s`; no leak                               | 5.179 ms      |
| Real Need with a 7.5-second wait on its existing scope lock, old default | `RETRYABLE_CONCURRENCY_FAILURE`, `NO_COMMITTED_CHANGE`; counts unchanged | 8,055.721 ms  |
| Identical real Need intent and same lock wait, function-specific policy  | success; exactly 248 Needs / 304 contributions / one run                 | 10,440.471 ms |
| Exact replay                                                             | success; all run/Need/contribution/receipt counts unchanged              | 33.766 ms     |

The lock wait is deliberately below the unchanged eight-second lock protection;
it exercises command completion beyond the ordinary statement default. It is a
local regression probe, not a hosted latency benchmark. An earlier 8,050.952 ms
red attempt is retained: the harness expected raw SQL57014, but the real command
correctly classified it as a retryable, rolled-back business response. The harness
was corrected to assert that real boundary rather than changing the product.

Both temporary REST containers and all local probe functions are removed; the
real-command diagnostic restores its candidate function setting. Fixture data
remains only in the named owned disposable database. No hosted facts are changed
by these probes. A verification clone initially has the wrong local database
owner; correcting only that owned database permits the existing fixture's schema
setup. A broad local test filter also discovers an old ignored `.superpowers`
baseline and reports four obsolete expectations; focused current-source checks
exclude that scratch copy. Neither failure is hidden or used to weaken CI.

## Deployment, hosted journey and remaining evidence

Independent source review reports no Critical or Important implementation issue.
Its Minor rollback finding is corrected: the runbook now explicitly restores the
recorded role policy together with the previous function configuration. Source
review does not substitute for runtime or release certification.

Pending. Before any hosted mutation, retain the 989-row released-document and
493-function/security/migration snapshot. After deployment, compare only the
declared function configuration and authenticated timeout changes; business rows,
function bodies, owners and ACLs must remain unchanged. Rerun official Menu sync,
Need generation/confirmation, allocation, original POs and dispatch, then a labeled
rehearsal correction, reallocation, replacement PO and successor dispatch.

Correlate hosted CPU, memory and I/O charts with request timestamps if dashboard
sign-in becomes available. Without those charts, retain the resource evidence gap
and do not blame Supabase capacity or buy an upgrade. Provider/client boundaries
remain distinct from performance goals. Unknown transport outcomes must reconcile
the original intent; never automatically create another command.

Rollback is a reviewed forward migration restoring only the previous function
configuration and the explicitly recorded pre-deploy role policy. It changes no
business rows. Reverting to the broad rehearsal exemption is an emergency rollback
state, not the desired operating policy. See the
[runtime runbook](../runbooks/need-generation-runtime-observation.md),
[Supabase timeout guidance](https://supabase.com/docs/guides/database/postgres/timeouts)
and [PostgREST hoisted settings](https://docs.postgrest.org/en/v14/references/configuration.html#db-hoisted-tx-settings).
