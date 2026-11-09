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
Frontend42549607837 / Full42549607836 passed before the guarded Apply.

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
regressions preserve the authority boundary. Actual execution follows below.

## Executed Staging delivery

Only `rnzxmxiiqgtdevzregff` was written. No permanent schema, grant, RLS, API or
resolver change;138 migrations remain. Recovery is reviewed forward correction.
Do not rerun completed one-offs against fresh snapshots or delete their history.

| Operation                                                   | Verified result                                                                                                                             | Actual receipt                         |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| Core Apply42551175136 at `f4672f98`                         | APPLIED/REPLAYED;29 Dishes,58 typed roots,55 versions,93 lines/revisions,17 Ingredients,3 Suppliers,21 eligibilities; all Schools preserved | `806b7702-718e-4e48-8e57-a909274db084` |
| Archive Preview42552213316 / Apply42552673234 at `f4672f98` | 605 records/17 inactive, matched readback/REPLAYED;117 protected tables; zero native activation                                             | `d9483ae5-9c32-4893-80a5-5f80d3ceeb19` |
| Global Preview42554715147 / Apply42555155022 at `0cff3f32`  | Preview rolled back; Apply APPLIED/REPLAYED; exactly4 roots/4 revisions;305 effective lines;1,534 contexts;117 protected tables             | `6a81d3f7-1650-4547-a52d-ea168f17866a` |

Core plan checksum:
`091bef3b619660ec85530a8e997e242a38bebc0275f56af4935e91794b58d430`;
snapshot `114304184acca53398f9286c5c89fa598f670d90a6efbd6922b36808f51d6447`.
Archive reviewed content:
`adb9c65107a576df9a16499a14612b66fde720daf7eb1dac3ea6db6e18955af3`;
Apply snapshot `728ff38cd81d168173e591b8d2d89aaa7e064af3f7709339bbe48a448639f2a5`.
Global reviewed combined content:
`16c893655c6e5be0b252c4688d6fc054a157face186b0b3b88a109531c511095`;
source `1d01740618df6075d23f57269d50743969c98e23fd20638de275da8e069fe78f`,
target `ce829b9754a4ea3c5b5e3a8d097325b9eb6468f5992ab6dcb9c1c56e45beb707`,
Apply snapshot `fc39a29c390570ee68539c3396857e59166469f4bdca2da1020f9d8259a36408`.
The global Preview's transient receipt rolled back; it is not an Apply receipt.

PR461 merged as `0cff3f3219a7c014e24a4b4ac006cb1180a9193e` after exact-head
Frontend42551059756 / Full42551059760 passed. Exact-main Frontend42552893081 /
Full42552893037 passed before hosted execution. Earlier cancelled/Smoke runs
are not Full certificates. Independent core readback:767 mapped Dishes,
418 mapped Ingredients,51 Schools. Weekly Menu read-only acceptance resolved
158 rows/546 assignments across24 Schools, without Save or Approve.

## Owner correction — Recipe3529

Owner subsequently confirmed pork mince. Source Recipe3529 is Dish2071/type2;
source BOM still says beef1037. The existing authenticated Atlas UI created a
SYSTEM_DISH REPLACE from9 November indefinitely, beef1037→current pork1208
(Nạc vai heo xay), retaining5.5kg/100 portions. Type1 already uses1208, also
adopted by source global14. The four other ingredients, Units, quantities,
stable line identity and released base Recipe remain unchanged.

Actual adjustment `389b8d1c-1465-421f-934b-3784e107fcd6`, revision
`179488c0-0134-4e08-a92f-8cb51c03ea81`, created
`2026-11-09T03:29:42.047342Z` by existing authenticated Staging Actor
`a1010000-0000-4000-8000-000000000001`. This new Owner-authorized Atlas fact
has null legacy source/record identity; it is not historic imported issuance.
Saved UI and canonical readback show pork5.5kg. Native roots/revisions are8/8;
prior7/7 remain byte-identical. All16 mapped-master fingerprint groups and82
operational tables are unchanged. Type1 on8/9 November and type2 on8 November
are unchanged; only current type2 meat/new lineage change. A single-query117-table
read timed out without writes; the Owner proof is82 operational tables plus16
master groups, not a117-table certificate.

The reviewed normal-auth CLI prototype remains unmerged/unexecuted on
`codex/atlas-recipe3529-owner-correction-20261109` at `bceaa305`. The existing
product command completed delivery; no redundant CLI/API/permission is shipped.

## Final independent comparison

Fresh source/target system reads at03:46 UTC:1,534 mapped typed contexts,
1,526 READY/8 BLOCKED; **1,195 MATCH,331 DIFFERENCE,0 missing and8 source
absent**. After core closure alone:962/564/0/8; initial:907/564/55/5.
One final difference (`2071|2`) is the explicit Owner pork fact;330 others remain
unresolved. Eight source-empty contexts:
`2034/1,2034/2,2041/1,2041/2,2065/2,2111/1,2111/2,2129/2`.
Do not fabricate effective Recipes for them.

The same1,962 affected-School contexts were recaptured across17 Schools with the
preserved source definition/join narrowing: **0 MATCH,1,905 DIFFERENCE,0 missing,
57 BLOCKED**. School11/20/21 remain inactive in both systems. The three former
matches (`24|1636|1`, `24|1638|1`, `24|1797|1`) use1029 in the source School
view; Atlas now applies actual global1029→1067. This remains a source-layer
semantic conflict, not full School parity. No School rule was invented to force
parity. Source batches/target reads are separate read-only transactions, not an
atomic cross-project or historical certification. Final private snapshots and
saved UI evidence remain alongside baseline evidence outside Git.

## Comparison dialog separator

Owner requested a line between “Trước điều chỉnh” and “Sau điều chỉnh”.
`ChangeOrderDialogs.tsx` adds one decorative `border.default` separator, vertical
from md and horizontal for stacked phone tables. Equal widths, commands,
labels, permissions and payloads remain intact. Independent rendered review
passes at1366/1440/1920,768 and390px without overflow. The four existing action
Review tests pass with one worker; initial cold execution timed out three at
the existing5s limit. No timeout/assertion/configuration was weakened. Prettier
and diff whitespace checks pass. Latest-head Frontend CI remains the integration
gate; local checks do not substitute for it.

## Remaining reconciliation

Existing mapped-context differences require source-rule and stable-line
reconciliation through the canonical resolver before append-only adoption.
Recipe3529 is resolved by the Owner fact above. Source addresses and cooking
groups must not be guessed. Actual staff acceptance and Production cutover remain
outside scope. Order13 still creates27 duplicate-final contexts across14 Dishes;
quantity orders568/569 are archived but not adopted. Remaining system/School
differences need a separately bounded business decision.

A fresh single-source transaction also compared the system view against the
system-only `sys_out` CTE extracted unchanged from the School view (before any
School layer, with identical active-Ingredient eligibility). Of1,526 contexts,
two differ: Dish1802/types1 and2. The system view recursively applies system
non-ADD chains, while the School view's system stage is a single pass. These
source outputs are not one consistent rule authority. Preserve the original
definitions and resolve intended business semantics before any affected adoption;
do not change Atlas precedence or manufacture School exceptions to force parity.
