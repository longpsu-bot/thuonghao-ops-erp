# Supabase runtime and timeout investigation — 22 October 2026

Status: complete. Reviewed PR432 is merged as `db7bfe24`; exact-source Frontend,
executed Full, guarded Staging deployment and the complete hosted original /
correction / replacement journey pass. Both successor dispatch PDFs pass exact
data checks and visual review across all four pages. Runtimes are observations,
not an acceptance deadline or a claim of faster calculation.

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

PR [432](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/432) first passes
Frontend `39740528154`. Executed Full `39740529183` fails at the correction
certification helper's old function-timeout allowlist, which recognizes only
Purchase Preparation. That legitimate policy guard is updated to recognize exactly
Need's `0` as well. An isolated real-SQL probe reproduces the failure, then accepts
only the approved pair and rejects a wrong Need value, an unrelated API exemption,
a wrong Preparation value and a missing Need signature. Every probe rolls back.
The helper's unit check now counts actual invocations separately from its new
quoted catalog lookup. All 120 affected current-source tests pass. No operational
timer, assertion, workflow or business check is removed. Corrected exact-source
Frontend `39742477815` and executed Full `39742477901` pass at `db7bfe24`.
After merge, main Frontend `39744739590` and Full `39744739402` also pass.
Guarded Staging deployment `39744741438` succeeds with 134 migrations, tip
`20261022071412`. Automatic Cloudflare publication serves the clean certified
`db7bfe24` build at the existing app URL with the correct Staging origin.
No hosting setting or new Wrangler login is used in this release.

The post-migration comparison proves all 989 existing document rows and all
7,205 existing history rows unchanged. All 493 function bodies, owners, ACLs,
definer/volatility/parallel/language modes are retained. Only the declared Need
configuration and authenticated default change. Relation/RLS/policy/schema ACL
and role-membership fingerprints are identical.

### Actual-app journey and preserved history

The hosted rehearsal uses service date **20 October 2026**, official Menu week
19–25 October, THUẬN GIAO and TRỊNH HOÀI ĐỨC at 100 student / zero teacher portions
each. The other 17 Schools have explicit zero portions. The existing 38 Attendance
rows for 21/23 October retain their source references and every fact except the
expected source-save timestamp refresh; 19 new rows bring the weekly total to 57.
The initial attempt to select 24 October finds no official Menu for these Schools;
20 October is selected rather than inventing source data. No Recipe is substituted.

The actual app completes official Google Menu sync, Attendance preview/save,
readiness, one first-attempt Need generation, confirmation, qualified priority
allocation, original PO preparation, seven PO releases and two original dispatch
releases. The single generation retains 254 atomic contributions and 21 confirmed
Need lines, zero blocking issues. Zero-portion warnings remain visible; they are
not silently discarded. Both original reconciliations match all 21 detail lines.

An explicitly labeled hosted rehearsal correction changes only THUẬN GIAO
Thanh long from **6 to 7 kg**. The app preserves the old allocation until the
operator applies its balanced 7 kg proposal and saves. It creates the complete
12-line AN THÀNH ĐÔ replacement PO and releases it, then explicitly releases two
successor dispatches. The second School's quantities stay unchanged; its dispatch
source lineage now points to the replacement PO. There is no second generation
or hidden reissue. Original allocation acceptance is part of the preparation
command; correction allocation uses one explicit Save. Replacement creation uses
its existing command, without a second generic Prepare action.

| Evidence                | Original                        | Successor                       |
| ----------------------- | ------------------------------- | ------------------------------- |
| AN THÀNH ĐÔ PO          | `PO-20261020-013002365B8C4E8C`  | `PO-20261020-B7CFAC3D1BFA4A9F`  |
| THUẬN GIAO dispatch     | `PXK-20261020-DB01163D02A84421` | `PXK-20261020-155B2DC47FF14591` |
| TRỊNH HOÀI ĐỨC dispatch | `PXK-20261020-C628A54847FE466D` | `PXK-20261020-BDAF4035D4E642DB` |

The final app shows **Cần xử lý 0 · Khớp 2**. All 21 detail deltas are exactly
zero. THUẬN GIAO totals are 20.9 kg / 300 Quả / 100 Cái; TRỊNH HOÀI ĐỨC totals
are 29.6 kg / 10 Quả / 100 Cốc. Unit identity and captured descriptive snapshots
are retained; the UI and exports show human labels rather than internal codes.

The fresh assertion verifier passes **631 checks**: exactly eight PO roots with
seven current released / one superseded, four dispatches with two current, exact
replacement/predecessor and revision/source lineage, unchanged Supplier/Ingredient/
Unit snapshots, exact six-decimal source coverage and only one quantity delta.
The original rehearsal's 128 document rows retain their frozen contents. Only
the affected original PO's status/version/update timestamp and the two original
dispatch statuses change, as declared in advance. All 7,205 pre-existing history
rows still match their full-row hashes. Security fingerprints and the final
ordinary role settings match the declared post-deployment policy. All 23 distinct
command receipts complete without an error, including eight PO releases and four
dispatch releases; preparation's existing child receipts are included.

### Both actual dispatch PDFs

Both successor PDFs are downloaded through the actual app's Export PDF controls.
Text assertions compare all nine THUẬN GIAO and twelve TRỊNH HOÀI ĐỨC rows against
the authoritative final reconciliation: exact Ingredient, human Unit and quantity.
They verify document/date/School/note, no internal Unit codes, one issuer-address
prefix, continuation content and the three signature blocks once on the final
page with the last two rows. All four rendered pages are visually inspected:
Vietnamese text, headers, row borders, quantities and signatures are readable,
without clipping or overlap. Both documents have two pages.

| PDF                      | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| THUẬN GIAO successor     | `502989621ba918b27b9c8ca0555d1b7404886f8480a5c2d88a5534ee1cd73d0b` |
| TRỊNH HOÀI ĐỨC successor | `36ffafd30da066b874ad5a3030b334997c4a6b20d442fa4fc53063579eaa24a8` |

The first original dispatch's rehearsal note contains a trailing `i`. It is
preserved as frozen history; both successor notes are checked before release
and contain the intended label. No quantity, source or Unit is affected.

### Hosted request observations

The captured window is **22 October 08:03:56–08:25:29 UTC** (15:03:56–15:25:29
UTC+7). All **125 POST RPC requests return HTTP200**, with no failed receipt.
The 18 OPTIONS requests are separate from these counts. The table records
Supabase's upstream-service-time header in milliseconds; these are neither
click-to-visible browser wall times nor CPU self-times. Origin time includes
additional gateway work. Waiting between operator actions is not execution time.

| Step                                              | Upstream observations (ms)              | Origin observations (ms)                |
| ------------------------------------------------- | --------------------------------------- | --------------------------------------- |
| Menu preview / save                               | 402 / 727                               | 625 / 944                               |
| Attendance preview / save                         | 173 / 2,141                             | 231 / 2,320                             |
| Need generation, first and only attempt           | **4,451**                               | **4,620**                               |
| Original Need confirmation / labeled correction   | 665 / 1,302                             | 721 / 1,361                             |
| Original allocation acceptance + PO preparation   | 2,402                                   | 2,556                                   |
| Seven original PO releases, sequential            | 295 / 115 / 164 / 176 / 385 / 281 / 186 | 439 / 169 / 210 / 223 / 443 / 324 / 237 |
| Original dispatches, THUẬN GIAO / TRỊNH HOÀI ĐỨC  | 1,153 / 424                             | 1,301 / 484                             |
| Correction allocation save                        | 654                                     | 1,300                                   |
| Complete replacement PO creation / release        | 1,083 / 2,951                           | 1,156 / 3,010                           |
| Successor dispatches, THUẬN GIAO / TRỊNH HOÀI ĐỨC | 1,526 / 593                             | 1,587 / 649                             |

The exact retained Need `pg_stat_statements` entry increases from five to six
calls and by **4,419.263 ms database execution**, 1,124,243 shared hits and 29 reads,
with no temporary blocks. This is one measured operation against fresh hosted
inputs, not a percentage improvement over other dates/history. The management
activity sample collected afterward is already post-completion and cannot
establish Need's active CPU or lock wait.

Read timing still varies: 13 preflights span 55–1,913 ms, 13 Need-review reads
423–1,488 ms, 14 allocation reads 261–3,557 ms, 29 PO reads 346–3,693 ms, 19 dispatch
reads 314–3,735 ms and eight reconciliation reads 395–4,927 ms upstream. These
small, mixed cold/warm/source-state samples are not a tail percentile or a load
test. The inspected server log window has no returned timeout/OOM/deadlock or
connection-exhaustion event. Its one SQL42P01 event is our read-only management
query using the wrong receipt schema, not a journey command. A later management
column-name mistake and a verifier's initially missing joined School label are
corrected; neither causes an app write or changes the pass criteria.

### Chrome resource inspection and remaining limits

The Owner's signed-in Chrome session provides Atlas Staging's dashboard; their
OPS production recipe-editor tab is left untouched. Staging is Nano / `t3.nano`
in Singapore. The 14:58–15:08 UTC+7 range covering Need displays CPU 6.25%, memory
usage 423.34 MB and commitment 1.17 GB. The 14:26–15:26 range covering the full
journey displays CPU 15.30%, memory usage 379.44 MB, commitment 1.27 GB, IOPS 4 and
disk throughput 68 KB/s. These are dashboard headline values with unspecified
aggregation, not per-request peaks or causal attribution. The baseline graph
includes nonzero Swap; zero memory/I/O pressure is not established.

IOPS and throughput initially fail to load and later populate for the full-hour
range. Database Connections and Disk Usage tiles still fail to load. Free-plan
metrics retain one day, so the prior 21 October 06:xx UTC slow operations cannot
be correlated now. Chrome's later screenshot capture times out; DOM metric
snapshots are retained, and no later graph image or visual peak analysis is
claimed. No capacity/region/paid-plan change is justified by these observations.

The scoped command policy removes the reproduced ordinary statement-deadline
failure while retaining lock protection; it does not remove provider/client
transport limits or prove every historical slow request explained. An unknown
outcome must reconcile the original intent, never automatically generate another.
Further runtime work should capture a fresh slow request's timestamps, database
plan/waits and resource samples before selecting a query/index or capacity change.
Keep the current correctness and history checks. Recipe3529's pork-named / ground-
beef source discrepancy still requires the Owner/kitchen's factual decision.
No Supplier message, physical shipment, OPSv1/Retool write, new credential or
business/security/architecture redesign occurs in this cycle.

Private raw snapshots, request arrays, exact assertion results, downloaded PDFs,
all rendered pages and the final app screenshot remain in
`.git/runtime-timeout-20261022/`. Diagnostic local databases remain owned test
artifacts; the temporary REST containers/functions are already removed. Evidence
files are not uploaded to a public service.

Rollback is a reviewed forward migration restoring only the previous function
configuration and the explicitly recorded pre-deploy role policy. It changes no
business rows. Reverting to the broad rehearsal exemption is an emergency rollback
state, not the desired operating policy. See the
[runtime runbook](../runbooks/need-generation-runtime-observation.md),
[Supabase timeout guidance](https://supabase.com/docs/guides/database/postgres/timeouts)
and [PostgREST hoisted settings](https://docs.postgrest.org/en/v14/references/configuration.html#db-hoisted-tx-settings).
