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

## Remaining reconciliation

Existing mapped-context differences require source-rule and stable-line
reconciliation through the canonical resolver before append-only adoption.
Unknown Recipe3529 kitchen facts, source addresses and cooking groups must not
be guessed. Actual staff acceptance and Production cutover are outside this task.
