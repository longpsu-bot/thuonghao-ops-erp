# Atlas / OPS v1 parity observations — 5 November 2026

Owner authorized parity work except Supplier commitment cancellation; Warehouse
remains paused. Comparisons used read-only observations of source OPS
`qnthofvccilhnefdcxnz` and target Atlas Staging `rnzxmxiiqgtdevzregff`.
Subsequent authorized Staging writes are recorded separately below. Source OPS
and Production were never written. This is migration evidence, not staff acceptance.

## Effective composition

Source SYSTEM snapshot: 1,499 Dish/School-Type contexts, 4,611 lines. One Atlas
transaction resolved all 1,476 mapped contexts at explicit date `2026-11-05`:
1,471 READY and five BLOCKED. Comparison aggregates by source Ingredient ID
and controlled Unit, normalizes Atlas quantities to 100 portions with exact
rational arithmetic, and uses approved Kg/kg and Hủ/Hũ aliases. Kilogram is
bound to its actual retained kg mapping; no conversion is guessed.

| SYSTEM outcome                        | Contexts |
| ------------------------------------- | -------: |
| Exact match                           |      909 |
| Difference                            |      562 |
| Source context missing Atlas mapping  |       28 |
| Atlas context absent from source view |        5 |

Of the differences, 44 are quantity-only and 518 change Ingredient/Unit
membership. Missing mappings represent two types of 14 Dishes:
`2098,2099,2101,2102,2103,2104,2105,2106,2107,2108,2109,2110,2113,2114`.
Source-absent Atlas contexts `2034/1,2034/2,2041/1,2041/2,2065/2` correctly
report no eligible released typed Recipe; no composition is fabricated.

The active School override scope contains 2,054 contexts across 17 Schools.
The whole source view timed out safely at ten seconds. Subsequent reads kept
its actual definition and narrowed only the School-preserving `sch_base`
join by exact School, retaining its School-partitioned ranking and recursion.
All 2,054 outputs were captured; no view, source fact or timeout was changed.

| School override affected outcome | Contexts |
| -------------------------------- | -------: |
| Exact match                      |       17 |
| Difference                       |    1,835 |
| Missing Atlas mapping            |      145 |
| Atlas resolution blocked         |       57 |

School reads are sequential read-only snapshots, not a cross-project
transaction. Source CURRENT_DATE views establish only the observed 5 November
result, not arbitrary-date historical equivalence. Atlas uses its canonical
resolver. **History import does not close these differences.** Do not activate
all archived rules or overwrite mapped/released Recipes. Adoption needs an
exact School/Dish/date scope, stable line/native identity, BOM/downstream
Preview and approved append-only correction. Unrestricted staff pilot is
blocked pending scoped data reconciliation.

Raw snapshots, original view definition, exact comparisons and screenshots
remain outside Git at
`C:/Users/HOME/.codex/outputs/atlas-recipe-history-local-2026-11-05/bom-*`.
This report contains no raw source rows.

## Other facts and verification

- Eight reviewed source Ingredient names and corresponding old Atlas names
  were freshly confirmed; all eight target versions are 2. The reused bounded
  correction pins complete 138-migration authority ending `20261105090000`;
  source confirmation is not an apply claim.
- Source has 50 Schools and 34 active configured weekday Schools. Initial Atlas
  has 49 mapped Schools plus one native fixture; 33 configured Schools are
  mapped, and configured School54 is missing. The earlier claim that all 34
  were mapped and School54 was unconfigured was an observation error: the
  original private source already contains its 370/20 Monday-Friday overrides.
  Hosted preview41993048837 correctly stopped before any School command. The
  bounded prerequisite creates only School54 and its Customer/Delivery Location;
  weekday sync retains its no-creation guard. Null remains missing; zero is explicit.
- All 43 source Suppliers have empty `contact_details`. No address is
  recoverable from it. Cooking-group evidence and Recipe3529's kitchen answer
  remain unavailable; do not infer them from names or delivery addresses.
- Multi-day Shopping List already merged through #367. Existing daily-range
  hook/date checks pass 90 tests; the old roadmap deferral is superseded. No
  duplicate feature or ranged Need root is added.
- Weekday checks: 41 new pgTAP, 27 bulk and 77 Attendance. Independent review's
  adapter finding is fixed, with typecheck and independent re-review passing.
  Initial local counts138/10files and21/2files also included ignored historical
  test copies; they are not unique current-code coverage totals.
- Exact catalog delta: one private validator and two runtime privileges
  (validator EXECUTE and new-column UPDATE). Excluding exactly those additions
  reproduces previous 375-function/1,918-grant digests. New totals376/1920;
  RLS and other catalogs unchanged. Catalog plus weekday73 checks pass.
- Attendance's initial regression command passed four current files plus three
  ignored historical copies (241 total; a current-only total is unavailable
  from that retained output). The final real-XLSX/installed-reader suite has
  one unique current file,20 passing checks and independent review approval.
  Subsequent diagnostic commands explicitly exclude `**/.superpowers/**`;
  this changes no repository/CI test configuration. Chromium1440/390px
  inspection covers weekday disclosure/editing, actual file import/zero,
  invalid file and dirty blocking, with no horizontal overflow/page errors.
  The School Storybook write callback is intentionally a no-op; browser
  inspection does not establish persistence. Backend SQL checks do.
- Archive hosting package10 and reused name package22 rolled-back pgTAP checks
  pass. Full routine CI, hosted release/apply and staff acceptance are separate
  gates and must be recorded only after execution succeeds.
- Full CI exposed a stale exact School write-column expectation; its one-line
  update retains exact equality and every other privilege. RMVP01, catalog and
  weekday focused checks pass116; independent scoped review approves.
- Frontend CI at `0ea57fbb` hit its15-minute job cap in `pnpm test`; this is
  not a passing certificate. A controlled current-only School probe found340
  weekday inputs mounted in closed disclosure. Lazy disclosure now mounts none
  until opened and retains drafts through close/reopen. A controlled existing
  App case failed its60-second timeout at100.102seconds before and passes
  at7.847seconds after; the complete related App24/School28 suite passes52/52
  with one worker and ignored copies excluded. This proves the reproduced
  local bottleneck, not that it was the sole global CI bottleneck or a hosted
  speed improvement. No timeouts, tests or business rules were weakened.
  The script subtree independently passes825 checks/45files at two workers.

## Hosted checkpoint before the final factual correction

Exact source `d80a1361` passed Frontend42009379045 and executed
Full42009379140. Staging retains138 migrations ending20261105090000.
Archive apply41992825322 retained603 records/17inactive with exact readback and
receipt replay; read-only verification42008038118 matched the same source
business checksum. These imports do not certify native effective-BOM parity.

School54's bounded prerequisite Apply42012115437 created exactly three roots,
three mappings and receipt `ec55d20a-631f-47aa-85a4-d7496ca9b4aa`, with all117
protected tables preserved, replay and actual authenticated readback. Weekday
Apply42012951054 updated34 Schools with normal authenticated bulk-command replay
and complete School readback. School54's general defaults remain0/0; its five
weekday overrides are370 students/20 teachers. Archive603 and native3/3 remain.

Name-only Preview42013307974 stopped before writes. Fresh source/target reads
showed all eight old target names/version2 and matching Unit/group/order-step/
status facts, but Ingredient1047 had type36/Heo in Atlas and explicit source
type43/Thuỷ hải sản. Both existing typed catalogue mappings are ACTIVE. The
separate factual correction must state this one additional type change, preserve
all other facts, refresh truthful mappings and undergo review/CI before Apply.
No name correction or classification update is claimed at this checkpoint.

## Verified final bounded delivery

All four data deliveries below succeeded. Implementation PRs453,454,455,456
were independently reviewed and merged. The final factual operation used exact source
`6ab5063b3d5c652f96d9aa96819bf61573ccd1bd` passed
[Frontend42018205721](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42018205721)
and executed
[Full42018205722](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42018205722).
Cloudflare published that main. Guarded Staging deploy41992370968 established
all138 migrations; final independent readback retains tip20261105090000.
The subsequent closeout change affects documentation only.

| Delivery                      | Successful Apply                                                                         | Exact source SHA                           | Verified outcome                                                                                                        |
| ----------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Recipe source archive         | [41992825322](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/41992825322) | `539ae033d745d6fc01d8c1332579e7980e597f26` | 603 exact source rows,17 inactive, same-receipt replay, no native activation                                            |
| School54 prerequisite         | [42012115437](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42012115437) | `d80a1361a87b528ce66c8051758d06c8d96a3383` | 3 roots/3 mappings/1 receipt,117-table protection, replay and authenticated readback                                    |
| School weekday defaults       | [42012951054](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42012951054) | `d80a1361a87b528ce66c8051758d06c8d96a3383` | 34 updates through one real authenticated command, replay and all-School readback                                       |
| Ingredient factual correction | [42020808586](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42020808586) | `6ab5063b3d5c652f96d9aa96819bf61573ccd1bd` | 8 names plus only1047's canonical type36→43, all versions/mappings2→3 once, replay and authenticated type/name readback |

Archive receipt: `ac65b864-e842-4d15-8495-ae1ad5d3c861`.
School54 receipt: `ec55d20a-631f-47aa-85a4-d7496ca9b4aa`.
Final factual receipt: `dbf45a1a-a5dc-4aa5-a99b-7b91ad1bea4d`.
All are retained; no import or replay follows the final factual correction.

The factual preview42020490122 explicitly reported all eight old/new names,
versions2, and1047's existing mapped transition Heo36→Thuỷ hải sản43. Both
catalogues were already ACTIVE; no catalogue entry was created. Reviewed plan:
`8ac75d106a6129f767a16cfcdcbd27188c222aef0f260f61cbf8f14561b88816`.
Apply used the same plan/source snapshot, preserved operational and unrelated
master facts across117 protected tables, and refreshed truthful source43 mapping
fingerprints. Independent readback confirms all eight names and mapping versions3,
1047's seafood classification,51 Schools,34 weekday configurations, archive603/17,
and native adjustments/revisions3/3. Quantity, Unit, group, step, status, Recipe
and released rows were not changed by this correction.

At18:07 local time, independent source and target read-only snapshots normalized
all configured School codes and Monday-Friday objects with null omission and
explicit zero. Both had34 configurations, zero inactive configured Schools and
identical content MD5 `f15aab46ef6f552f8c8f06dd8e784979`; the source had no invalid
array shapes. This is an independent equality check at that observation, not a
cross-project transaction or continuous synchronization.
Read-only archive verification42008038118 also retained603/17 and matched the
original source business checksum:
`e045a04fc3dd6590b53a1a68f513a1d28c92db557688a579e6b19b501691e5b7`.

The failed pre-write guards remain part of the record. Weekday mapping guard
caught missing School54; the original unconfigured claim was an observation
error. Two School54 Applies rejected differing full-source plan hashes before
any root/receipt creation; narrowing only source content identity to the exact
normalized dependency closure retained complete-source validation and every
target guard. Full-hash differences did not establish a specific source-row
mutation. Name-only preview then caught1047's actual classification mismatch;
the explicit factual amendment corrected it instead of forging source data or
removing non-name guards. One earlier exact-main Full attempt failed on disposable
PostgREST startup503; the same-commit fresh attempt passed. No failure, skip or
cancellation is counted as success and no assertion, timeout or security check
was weakened.

Final scoped correction evidence includes25 runner/39 pgTAP checks and116
related PostgreSQL checks; source-plan correction includes25 runner/46 pgTAP
checks. GitHub owns the full routine suites. The browser evidence above remains
component-level; real persistence evidence comes from SQL and authenticated
hosted readback, not the Storybook no-op callback.

**Delivery horizon closed; full parity remains unclaimed.** The SYSTEM/School
BOM tables above describe pre-School54-backfill observations. No full post-import
BOM certification or actual staff pilot was performed. Large composition/Unit
differences, missing Dish mappings and factual kitchen/School/week/address/group
prerequisites remain. Reconcile a separately bounded School/Dish/date scope before
unrestricted staff use. Never automatically replay archive rules or recalculate
released documents. Supplier cancellation, Warehouse, external communication and
Production cutover remain excluded. Recovery preserves roots/receipts and uses a
reviewed forward correction.
