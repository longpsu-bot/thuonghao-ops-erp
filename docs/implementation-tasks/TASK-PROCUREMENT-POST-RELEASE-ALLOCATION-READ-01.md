# Post-release Supplier Allocation read latency

Product task dated 13 October 2026. Base:
`d616396cea0c5b076d6ac9f16366165913d39754`. Branch:
`perf/procurement-post-release-allocation-read-01`.

Scope: `atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)`, contract
`CONFIRMED-SUPPLIER-ALLOCATION.v1`. Purchase Preparation is accepted and closed.
Migrations 103, 104, and 105, write paths, Supplier semantics, released POs,
frontend, Retool, and OPS v1 are outside this task.

## Hosted measurements before implementation

Target: Atlas Staging `rnzxmxiiqgtdevzregff`, migration tip
`20261013082420_atlas_purchase_preparation_release_projection` (105).
Released batch `69661e86-abb3-4bf4-88a5-4717fe18c472`, version 5, date 2026-10-12.

Every hosted query ran in `BEGIN READ ONLY` and ended with `ROLLBACK`. The exact
public read was invoked under `authenticated`, asserting the existing active
Atlas subject through the same request contract and JWT subject setting.
The Management SQL diagnostic emulates the authenticated database boundary;
it is not a real HTTP/PostgREST acceptance run. No hosted function, schema,
business fact, receipt, or authentication session was created or changed.

The normal 8-second read cancelled at 7,998.104 ms in the legacy Handoff exclusion
check, after 16 completed source reconstructions. A 60-second diagnostic also
cancelled, after 136 completed reconstructions. A final diagnostic-only 150-second
local transaction setting allowed the existing function to finish at
**105,391.920 ms**, returning **236 rows**, all `BALANCED`, with preparation
`ready=true`, `allowed=true`, and authoritative version 5. This larger setting
was rolled back and is not part of the implementation.

| Function                         | Completed calls | Inclusive total ms |    Self ms |
| -------------------------------- | --------------: | -----------------: | ---------: |
| Public allocation workbench      |               1 |        105,373.071 |    502.365 |
| Confirmed sources                |             239 |        104,254.066 |  3,147.989 |
| Canonical evaluation             |             478 |         68,628.928 | 66,782.768 |
| Validated facts projection       |             239 |         66,753.403 | 26,961.042 |
| Confirmed batch sources          |               1 |            431.910 |      0.403 |
| Supplier advice                  |             236 |             27.873 |     27.873 |
| Handoff family projection        |           2,360 |            185.107 |    174.835 |
| Existing Handoff workbench       |               1 |            444.710 |     22.400 |
| Preparation status               |               1 |            949.827 |      4.429 |
| Preparation allocation readiness |               1 |            435.303 |      3.393 |
| PO date readiness                |               1 |             62.319 |     12.676 |

Inclusive times overlap: validated-facts projection calls canonical evaluation.
They must not be summed. `track_functions=all` adds diagnostic overhead.

Independent stage measurements: Confirmed sources 478.999 ms / 236 families;
batch sources 431.687 ms / 236 families; canonical evaluation 148.453 ms;
validated facts 280.706 ms / 236 lines; Handoff workbench 458.212 ms / 236 rows;
preparation status 934.452 ms. The source `EXPLAIN (ANALYZE, BUFFERS)` completed
in 474.335 ms, with 78,918 shared buffer hits, zero shared reads, and zero
temporary blocks read/written. No spill or missing-index fix was justified by
this evidence. The dominant problem is repeated query execution.

Raw timings, call counts, and the normal-timeout stack are retained in
[hosted-profile.json](../testing/artifacts/supplier-allocation-released-read/hosted-profile.json).
The full response MD5 is `2e0b0deddd883e85ba392b1690924868`; the rows sorted by
family ID have MD5 `48e433c45fac665d873103542408a484` for later equality checks.

## Root cause and scope decisions

1. The workbench always builds current Confirmed Need sources to determine
   completeness, batch identity/version, School identity, and source precedence.
   It then substitutes the real Handoff projection for promoted released rows.
   Release does not bypass the current-source checks.
2. Those metadata/currentness fields and preparation status still use Confirmed
   Need authority. Promoted row quantities, fingerprint, and contributions use
   current Handoff facts. This task preserves both authorities exactly.
3. Using only persisted allocation lineage would need new proof of equivalence
   for corrected/retired/ambiguous sources. It is unnecessary to meet the budget:
   a single fresh canonical source reconstruction costs less than half a second.
4. The historical Handoff loop executes the whole source function again for
   every legacy row, even when the same family already exists in the initial
   source set: 1 initial call + 236 exclusion calls + 2 preparation calls = 239.
   Each source call evaluates the batch twice (directly and inside facts).
5. Preparation status independently rebuilds sources twice, taking about 0.95s.
   It is bounded and retained unchanged, as are its readiness predicates.
6. Historical/current source exclusion therefore repeats the same currentness
   proof for rows already represented by promoted Handoff facts. Reusing the
   fresh initial set removes this repeated proof without trusting stale lineage.
7. Query shape is the demonstrated cause. Supplier advice, eligibility,
   Handoff display, and preparation readiness are not the dominant cost.

## Implementation

Forward migration 106:
`20261013102219_atlas_supplier_allocation_read_source_reuse.sql`.

Only the existing public read body changes. It collects the complete authoritative
source set into a local JSON array once, then uses `jsonb_array_elements` for
the original main loop and legacy exclusion check. It does not cache between
requests, filter before currentness checks, mutate the array when projecting
individual Handoff rows, or trust browser quantities.

The guarded three replacements fail closed if the expected definition changes.
The migration checks that every function catalog field except `prosrc` is
identical after replacement, including owner, ACL, volatility and `search_path`.
The repository's temporary migration role/schema privileges are restored.
There are no new tables, helpers, indexes, persisted states, grants to callers,
public payload fields, or timeout changes.

The read still reconstructs sources three times for a single date: once for
workbench presentation and twice in unchanged preparation status. Multi-day
reads reconstruct once because they have no preparation status. Further
optimization would reopen unrelated predicates without an operational need.

## Local acceptance and regression

The new rolled-back `supplier_allocation_released_read.sql` reuses the existing
236-family scale fixture and establishes its released state locally through
authenticated commands with all integrity triggers enabled. This is synthetic
local setup; hosted Purchase Preparation was never rerun.

On migration 105, all three reads timed out at approximately 8,000 ms. On
migration 106, the final focused run took **1,696.538 / 1,703.388 / 1,675.909 ms**,
each with 236 rows and exactly three source reconstructions. An earlier
candidate run took 2,046.751 / 1,726.236 / 1,702.389 ms.

All 13 scale assertions pass: successful bounded repeated reads, the exact set
of 236 distinct identities, identical full responses, exact quantities/Supplier
splits/notes/fingerprints, full normalized current Handoff contribution lineage
and Confirmed Need lineage, preparation version/readiness, and equality of
before/after business facts, audit evidence and command receipts.

The following existing suites pass (1,149 assertions total):

| Suite                                   | Assertions |
| --------------------------------------- | ---------: |
| Purchase review confirm/release         |        187 |
| Purchase Preparation release projection |          7 |
| Purchase Preparation source ambiguity   |          9 |
| School catering Handoff/allocation      |         88 |
| School catering Planning correction     |         23 |
| School catering purchase orders         |        135 |
| Supplier line note                      |         13 |
| RMVP-06 validation                      |         65 |
| RMVP-07 approval/release                |         67 |
| D-037 Save/release boundary             |         37 |
| Zero-demand generation                  |         72 |
| Platform security catalog               |         29 |
| Allocation convergence                  |        417 |

These preserve pre-release reads, preferred defaults, manual/mixed overrides,
priority changes, ties/inactive/no-priority/no-eligibility cases, source ambiguity
and currentness, post-release display, downstream commitment protection,
multi-day filtering/no-preparation authority, exact residuals, no-op Save and
zero demand. The unchanged School-first frontend is covered by Frontend CI.
The certification-entrypoint test passes all 116 assertions and registers the
new scale regression in Full Integration.

One independent read-only reviewer found no production defect, but identified
that row count alone did not prove distinct identity or exact lineage. The final
focused run includes the strengthened identity-set and contribution assertions.
A separate rolled-back fault probe injected one duplicate family identity and
one corrupted contribution reference into temporary response copies; both
strengthened assertions failed as expected, while the unchanged row count passed.

Local Full Integration was attempted once. All preceding database suites and
the final Planning backend closeout assertions passed; its browser build stopped
because the existing harness uses `.git/closeout-browser-dist`, while `.git` is
a file in this managed worktree. This is an unchanged checkout-specific harness
limitation, not a passing Full Integration result. No checks were weakened or
disabled. The existing `Supabase Integration` workflow supports manual dispatch
on a branch, so Full Integration can run in its ordinary GitHub checkout while
the PR remains Draft. The PR's GitHub checks are the final CI result authority.

## Hosted acceptance and rollback boundary

Staging remains at 105. This task does not claim post-fix hosted latency or
HTTP success: those require Product-approved deployment of 106 and a later
read-only real authenticated PostgREST run for 2026-10-12. Require success,
exactly 236 rows, unchanged sorted row fingerprint/quantities/Suppliers/lineage,
correct released state, and latency below 8 seconds with reasonable margin.
Compare business facts/receipts before and after. Never rerun preparation.

Rollback is a reviewed forward migration restoring the prior function body.
It requires no business-data rollback and must retain all accepted released
batch, Handoff, allocation, 17 Draft PO, and 236 PO-line facts. Do not edit or
remove deployed migrations 103–106. No deployment or merge is authorized here.
