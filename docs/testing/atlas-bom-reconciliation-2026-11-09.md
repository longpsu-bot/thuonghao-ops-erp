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
Frontend42549607837 / Full42549607836 both passed before guarded Apply42551175136.
Apply returned APPLIED and REPLAYED, with source/plan equality and protected
operational/unrelated facts unchanged. Receipt
`806b7702-718e-4e48-8e57-a909274db084`; plan
`091bef3b619660ec85530a8e997e242a38bebc0275f56af4935e91794b58d430`;
snapshot `114304184acca53398f9286c5c89fa598f670d90a6efbd6922b36808f51d6447`.
Independent readback confirms767 mapped Dishes,418 mapped Ingredients,51 Schools,
native3 roots/3 revisions and138 migrations. Fresh canonical readback has1,534
typed contexts:1,526 READY and8 source-empty/unready roots. All55 previously
missing effective contexts now MATCH; the fresh system comparison is962 MATCH,
564 DIFFERENCE, zero missing mapping and8 source-absent contexts. The three newly
empty contexts are2111/types1+2 and2129/type2; no composition was invented.

## Archive refresh

Preview42552213316 and Apply42552673234 ran at exact certified mainf4672f98.
Apply retained605 surviving source records/17 inactive, exact605 readback and
REPLAYED, preserving117 protected tables with zero native-adjustment writes.
Receipt `d9483ae5-9c32-4893-80a5-5f80d3ceeb19`; reviewed content
`adb9c65107a576df9a16499a14612b66fde720daf7eb1dac3ea6db6e18955af3`;
apply snapshot `728ff38cd81d168173e591b8d2d89aaa7e064af3f7709339bbe48a448639f2a5`.
Earlier603-record receipts remain intact. This refresh does not activate rules.

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

PR461's exactcf2e803d passed Frontend42551059756 and Full42551059760, then
merged as0cff3f3219a7c014e24a4b4ac006cb1180a9193e. Actual data adoption remains
conditional on that main's certification and separately reviewed hosted Preview.

## Owner-confirmed Recipe3529

After initially requesting that the ambiguous Recipe remain unchanged, the Owner
explicitly clarified **“thịt heo xay nha”**. That later confirmation governs.
Dish2071's Type2 base uses beef1037 at5.5kg/100; Type1 already uses current pork
mince1208 at the same quantity. The [bounded correction](../api/staging-recipe3529-owner-correction.md)
adds one normal authenticated SYSTEM_DISH replacement from9 November; it does
not edit the released base, source v1 or shared Dish name. Quantity, other lines,
Type1 and pre-date composition remain fixed. This is an intentional new Owner
decision, not fabricated legacy history or a source-to-target parity defect.
Hosted Preview/Apply remain pending.

## Remaining reconciliation

Existing mapped-context differences require source-rule and stable-line
reconciliation through the canonical resolver before append-only adoption.
Source addresses and cooking groups must not be guessed. Actual staff acceptance
and Production cutover are outside this task. The Recipe3529 question is now
resolved by the Owner's later confirmation above.

A fresh single-source transaction also compared the system view against the
system-only `sys_out` CTE extracted unchanged from the School view (before any
School layer, with identical active-Ingredient eligibility). Of1,526 contexts,
two differ: Dish1802/types1 and2. The system view recursively applies system
non-ADD chains, while the School view's system stage is a single pass. These
source outputs are not one consistent rule authority. Preserve the original
definitions and resolve intended business semantics before any affected adoption;
do not change Atlas precedence or manufacture School exceptions to force parity.
