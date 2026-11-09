# Atlas BOM reconciliation — 9 November 2026

Owner instruction: reconcile OPS v1 and update Atlas DB. This opens a new bounded
Staging task after the closed 5 November delivery; it does not reopen its one-off
imports. Source OPS v1 and Production remain read-only. Warehouse and Supplier
commitment cancellation remain excluded.

## Fresh read-only baseline

Atlas Staging `rnzxmxiiqgtdevzregff` retains 138 migrations ending
`20261105090000`, 738 mapped Dishes, 1,476 typed Recipe contexts, 1,471 READY
and five BLOCKED contexts. The three native adjustment roots/revisions remain.
Source `qnthofvccilhnefdcxnz` has 768 Dishes, 1,536 Recipes and 4,587 base BOM rows.
Its current-date system view contains 1,526 contexts and 4,660 effective lines.

At explicit Atlas date `2026-11-09`, exact 100-portion rational comparison by
source Ingredient identity and controlled Unit gives 907 MATCH, 564 DIFFERENCE,
55 source contexts without Atlas mapping, and five Atlas contexts absent from
the source effective view. Only approved kg/Kilogram and Hủ/Hũ aliases apply;
there is no inferred numeric Unit conversion. The five absent contexts remain
`2034/1,2034/2,2041/1,2041/2,2065/2`; no effective Recipe is fabricated.

Fresh source rules contain five global Ingredient replacements, 471 active
system rules, 112 active School replacements and 17 inactive records. These
observations are not authorization to activate the history archive wholesale.
Private snapshots, original source view definitions and exact comparison rows
are retained outside Git at
`C:/Users/HOME/.codex/outputs/atlas-bom-reconciliation-2026-11-09/`.
Source and target reads are separate read-only transactions, not one atomic
cross-project snapshot and not historical equivalence certification.

Affected School scope is1,962 contexts across17 Schools:3 MATCH,1,862 DIFFERENCE,
40 missing mappings and57 BLOCKED. Those57 are `SCHOOL_INACTIVE` for Schools
11/20/21, confirmed inactive in the source too; they must not be reactivated.
This uses the original `v_effective_bom_dish_v2` definition narrowed only at its
School-preserving join and exact affected contexts. Original ranking and recursion
are retained. The two additional source history rows are actual quantity orders
568/569 for Dish2095/Ingredient1231, effective6 November:7.5kg/10kg per100
portions for types1/2; Atlas currently retains5kg. Archive refresh alone does not
activate these orders.

## First bounded correction: missing Dish closure

Reuse the existing Planning catch-up, SQL package and protected manual workflow.
The reviewed scope is exactly 29 active source Dish IDs:
`2098,2099,2101,2102,2103,2104,2105,2106,2107,2108,2109,2110,2111,2113,2114,2115,2116,2117,2119,2120,2122,2123,2124,2125,2126,2129,2130,2133,2134`.
The source test Dish1983 is excluded. Dish2111 has no current effective output;
empty composition receives the established roots-only policy, never a fabricated
released Recipe. The exact preview decides actual dependency eligibility.

Expected code files: the existing hosted workflow, its focused contract test,
the session-local catch-up package and its pgTAP suite.
Only missing Dish/typed Recipe/BOM roots and required unmapped master dependencies
may be created. Existing dependencies remain references. Explicit Dish scope now
excludes the historical School name/order reconciliation; the unscoped historical
path retains its existing behavior. Before Apply the workflow
rejects any plan containing UPDATE, including unrelated School-order drift. It
retains exact-main, migration parity, immutable snapshot/plan/Actor, same-snapshot
replay, transactional readback and protected operational/unrelated fingerprints.

Acceptance: reviewed preview has no blocked dependencies or existing-master
updates; Apply is APPLIED with REPLAYED, unchanged protected facts, and source/
plan checksum equality; fresh canonical readback accounts for every selected
typed context. Existing Recipe identities, revisions, released documents, native
rules, weekday defaults and prior receipts remain intact. No schema migration or
grant change. Recovery is reviewed forward correction, never deleting imported
history. Targeted workflow checks run locally; GitHub Actions owns routine full
validation before merge/Apply. Actual hosted results will be recorded here.

Initial Preview42547849758 at86e91263 succeeded without business writes but
proposed11 School-order UPDATEs, so its plan was not accepted for Apply. The
new no-UPDATE guard would reject it. The correction excludes School actions for
explicit Dish scopes and protects all School rows instead. Regression checks
cover preview, apply, exact replay and byte-identical School preservation.

Focused runner/planner/workflow checks:50 passed. Local pgTAP:151 passed after
the scoped correction. The disposable stack retained one prior history receipt;
the initial run also showed three preexisting fixture-count failures plus the two
expected new regression failures. The clean-fixture rerun removed that single
local receipt only inside the test transaction and rolled back; it did not reset
the stack or change hosted data. The existing receipt remains after the test.

Corrected Preview42548374987 at3b0454b5 succeeded with no School action and no
UPDATE. It proposes29 Dishes,58 typed roots,55 Recipe Versions,93 stable lines
and revisions,17 Ingredients,3 Suppliers and21 eligibility rows. Existing
dependencies remain NO_CHANGE. Plan checksum
`2d64811efb56842d41bf10318173ecc5a2ba5d8ed5d2f038b727bb322cb816a9`;
snapshot checksum
`55fb11afc3ba5b73b45657f25b29de450638e680b2dd027831f087ffb1541d77`.
The separately mistyped-SHA Preview42548362954 failed checkout validation before
business/transport execution; it is not a passing preview or a data operation.

PR460 merged as `f4672f98265548a83a7e69732c94c693f374d3c6` after independent
review and exact-head Frontend42548344035 / Full42548344143 PASS. Main
Frontend42549607837 / Full42549607836 must pass before the guarded Apply.

## Four faithful global replacements

The [bounded adoption contract](../api/atlas-staging-global-replacements.md)
admits only actual source orders7/11/12/14 from9 November. It preserves original
source dates in evidence, uses a rollback-only importer/canonical Preview and
binds reviewed source plus full target fingerprints before exactly4 roots,
4 revisions and1 receipt. Order13 and view-derived adjustments remain excluded.
The new pgTAP wrapper is registered as command133 in the shared full certification;
the existing132 commands remain. Integrated local validation passes131 Vitest
checks and31 pgTAP assertions. Review corrected the workflow entrypoint, moved
executed-CI verification before installation/privileged transport, and required
exact OPS-v1 mappings plus active canonical School-Type identities. All findings
are closed in independent whole-branch rereview; other-source-only and mixed-key
regressions preserve the authority boundary. Hosted adoption and final comparisons
remain pending.

## Remaining reconciliation

Existing mapped-context differences require source-rule and stable-line
reconciliation through the canonical resolver before append-only adoption.
Unknown Recipe3529 kitchen facts, source addresses and cooking groups must not
be guessed. Actual staff acceptance and Production cutover are outside this task.

A fresh single-source transaction also compared the system view against the
system-only `sys_out` CTE extracted unchanged from the School view (before any
School layer, with identical active-Ingredient eligibility). Of1,526 contexts,
two differ: Dish1802/types1 and2. The system view recursively applies system
non-ADD chains, while the School view's system stage is a single pass. These
source outputs are not one consistent rule authority. Preserve the original
definitions and resolve intended business semantics before any affected adoption;
do not change Atlas precedence or manufacture School exceptions to force parity.
