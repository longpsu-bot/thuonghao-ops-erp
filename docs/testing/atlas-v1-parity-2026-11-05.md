# Atlas / OPS v1 parity observations — 5 November 2026

Owner authorized parity work except Supplier commitment cancellation; Warehouse
remains paused. Source OPS `qnthofvccilhnefdcxnz` and target Atlas Staging
`rnzxmxiiqgtdevzregff` were read-only for these observations. This is migration
evidence, not Production or staff acceptance.

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
- Source has 50 Schools, 34 active configured weekday Schools, all 34 mapped.
  Atlas has 49 mapped Schools. New active source School54 is unconfigured and
  is not created by weekday sync. Null remains missing; zero is explicit.
- All 43 source Suppliers have empty `contact_details`. No address is
  recoverable from it. Cooking-group evidence and Recipe3529's kitchen answer
  remain unavailable; do not infer them from names or delivery addresses.
- Multi-day Shopping List already merged through #367. Existing daily-range
  hook/date checks pass 90 tests; the old roadmap deferral is superseded. No
  duplicate feature or ranged Need root is added.
- Weekday checks: 41 new pgTAP, 27 bulk and 77 Attendance; 138 focused frontend
  checks. Independent review's adapter finding is fixed, with 21 focused
  checks, typecheck and independent re-review passing.
- Exact catalog delta: one private validator and two runtime privileges
  (validator EXECUTE and new-column UPDATE). Excluding exactly those additions
  reproduces previous 375-function/1,918-grant digests. New totals376/1920;
  RLS and other catalogs unchanged. Catalog plus weekday73 checks pass.
- Attendance XLSX regression241 checks; final real-XLSX/installed-reader
  rendered suite20 checks and independent review pass. Chromium1440/390px
  inspection covers weekday disclosure/editing, actual file import/zero,
  invalid file and dirty blocking, with no horizontal overflow/page errors.
  The School Storybook write callback is intentionally a no-op; browser
  inspection does not establish persistence. Backend SQL checks do.
- Archive hosting package10 and reused name package22 rolled-back pgTAP checks
  pass. Full routine CI, hosted release/apply and staff acceptance are separate
  gates and must be recorded only after execution succeeds.
