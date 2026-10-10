# School Cooking Group / School-band revision evidence

This directory extends the retained 02D certification workflow for PR #360's
bounded cooking-group amendment. Historical 94-migration evidence in
`atlas-backend-convergence-02d` remains unchanged.

The two final cycles use official `supabase db reset --local --no-seed` on the
explicitly disposable project `atlas-document-system-360-cooking`, outside the
canonical checkout, followed by chronological replay of all 95 repository migrations.
These are fresh **database reset cycles**; they are not represented as independent
full-platform volume-discard cycles. Neither hosted project is queried or modified.

Set `ATLAS_LOCAL_DB_CONTAINER=supabase_db_atlas-document-system-360-cooking` and run
`node docs/testing/artifacts/atlas-document-system-01/cooking-group-revision/reproduce.mjs 1`
after the first reset has completed successfully, then repeat for `2` after the
second reset. Run `reproduce.mjs compare` after both have completed. The reset
observations retain the command, project, seed setting, and exit status; raw CLI
logs stay in the task-owned temporary project because local status can contain keys.

The wrapper reuses the 02C effective catalog query, current platform verifier,
02D supplementary catalog/semantic projections, retained 02B regression inventory,
and canonical local SQL runner. It adds the new Admin suite and PO/PXK/supplier-note
coverage, plus cooking-group semantic projections. Every suite runs sequentially
and rolls back its synthetic fixture. Include expansion and the import suites'
ordinary pgTAP preamble follow the existing wrapper; there is no production dependency
repair or schema baseline. Scale retains its eight-second statement deadline and
four-second operator target and runs first without parallel CPU-heavy validation.

`cycle-1.json`, `cycle-2.json`, and `comparison.json` compare exact migration
version/name manifests, effective catalog bytes, supplementary definition hashes,
all ordered suite TAP plans and assertion digests, and stable business evidence.
Full effective catalog manifests stay in the disposable temporary project; their
byte hashes and deterministic comparison are retained here. `--resume` only reuses
an already successful contiguous suite prefix in the same reset cycle and reruns
the failed suite and every remaining suite. Final comparison requires every suite.
Three older current-platform table-count assertions were updated from 113 to 115
for the two authorized tables; their exact domain/security assertions remain active.
Generated UUIDs/timestamps are excluded only from cross-cycle semantic equality;
all original identity/source/currentness assertions remain active. PXK cooking
snapshots use fixed synthetic group IDs; Admin group creation UUIDs are asserted by
the API/security tests and represented by name/activity/version in repeatability
evidence.

The focused logs additionally record 33 Admin, 108 PO, 59 PXK, 28 platform catalog,
43 RMVP-01 Admin, 13 supplier-note, 124 02B helper, 417 02B allocation, and 27 School
default assertions. These are local SQL acceptance evidence, not hosted or native
print acceptance. Native document evidence and final frontend validation are recorded
by the parent task.

The final catalog contains 115 private forced-RLS tables, 118 physical APIs,
115 authenticated APIs, 31 capabilities, 663 normal policies, 328 private functions,
115 triggers, and 1,790 reviewed positive grants. New browser table privileges,
roles, and capabilities remain zero. The forward migration seeds/backfills nothing;
rollback must retain frozen document facts.

`scale-performance.json` preserves both isolated scale measurements. The unchanged
eight-second statement regression deadline passes all 42 assertions in both
cycles. The four-second operator target is **MISSED**: p95 6275.680 ms and
5961.375 ms. This is an open local performance limitation; hosted performance was
not measured and Need Generation is not changed by this revision. The normal
catalog counts 663 policies; Pantry's total-policy assertion counts 664 because it
also includes the existing unit-isolation test policy.

## Native specimens and review

Safe synthetic fixtures for the Owner's 9 October 2026 amendment to the existing
[Draft PR #360](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/360). The
[task record](../../../../implementation-tasks/TASK-ATLAS-DOCUMENT-SYSTEM-01.md)
and [authority gaps](../../../../open-questions/atlas-document-system-v1-authority-gaps.md)
remain the decision records. No Staging deployment, Live OPS read/write, Retool
mutation, or V1 data import is part of this evidence.

`manifest.json` records production-builder files, source exact quantities, visible
cells, print geometry and hashes. Eleven XLSX workbooks, ten production PDFs and
two ZIPs cover ordinary/grouped Schools, two Schools sharing one group, all PO
modes, frozen supplier notes (null, multiline and 500-character wide-glyph stress),
and PXK ordinary/grouped/13-item/multipage inspection forms. The 13-item comparison
uses names, Units and exact quantities retained in the earlier repository specimen;
release and group facts are synthetic. It is not a production membership sample.

Regenerate sequentially before native QA:

```powershell
node scripts/certify-atlas-document-system.mjs docs/testing/artifacts/atlas-document-system-01/cooking-group-revision --cooking-revision
node scripts/certify-atlas-document-system.mjs docs/testing/artifacts/atlas-document-system-01/cooking-group-revision --cooking-revision --verify-determinism
& scripts/certify-atlas-document-system-excel.ps1 -OutputDirectory docs/testing/artifacts/atlas-document-system-01/cooking-group-revision
python scripts/review-atlas-document-system.py docs/testing/artifacts/atlas-document-system-01/cooking-group-revision
```

Native Excel creates separate `native-qa` copies, exports each sheet to PDF, saves
and reopens, compares quantity text/format and verifies the clean specimen hashes.
Python requires PyMuPDF/Pillow and checks visible text, pagination, signatures and
writing clearance before rendering every page to contact sheets. Final Excel 16.0
QA passes all 11 workbooks / 20 sheets / 206 exact-text checks, with normal
open/save/reopen, unchanged clean hashes and zero horizontal page breaks.
All 32 native/production PDF documents / 82 pages have zero missing expected
strings, no split signatures or header-only Dispatch pages, and at least 100 pt
signature handwriting clearance. All 11 contact sheets and full-resolution note
and PXK details were inspected. Wide-glyph note clipping is fixed; refreshed note
fragments stay inside their row borders. Source and visual re-review found no
remaining Critical/Important findings. XLSX text preservation alone is not print QA.

Ordinary PO native sheets use one page per mode; production `all` uses three pages.
The 32-item long-name/500-character stress PO uses native 17/4/3 pages for
ingredient/School/summary and 16 production PDF pages in total. Comparable PXK
13-item native and production output uses two pages, including a protected
signature page. Forty-item stress PXK uses two native/four production pages.
Excel TNR and production PDF Roboto retain their existing font-face differences;
pagination is reported separately. Exact source quantities and ten
XLSX/production-PDF parity pairs pass. All 23 clean specimen hashes are identical
across two sequential generations (`determinism-report.json`).

Fixture ZIP timestamp normalization uses the existing package codec, including
embedded XLSX timestamps. It changes fixture bytes only. Shopping List V2/A+
production code, protection and accepted geometry remain unchanged; its automated
regressions are required separately.

## V1 reconciliation and open facts

`v1-reconciliation.csv` supplies School identity, PO grouping, Dispatch grouping,
match/conflict, proposed Atlas group and resolution columns. It has **no data
rows**, because actual retained memberships are not available in this repository.
V1 adoption is blocked. Populate it from authorized read-only retained evidence;
report disagreement as `COOKING_GROUP_RECONCILIATION_REQUIRED`. Never infer a group
from a School name, address, delivery text, issuer, contract type or note.

The Owner-provided hosted baseline remains 94 migrations ending at
`20261008015340_atlas_backend_convergence_02b_allocation`. The CLI-generated forward
migration is `20261009075715_atlas_school_cooking_groups.sql`. No historical PO/PXK
row is backfilled. Later group edits, reassignment and removal preserve captured
group pairs, School identities and exact released quantity lineage. Outward codes
and mutable released PO Ingredient/Unit labels remain open authority gaps.

## Frontend delivery checks and cleanup

Final local format, typecheck, production build and whitespace checks pass.
Shopping V2/A+ passes 113 tests; final School/review UI passes 32, PO/output passes
35 and PXK/output passes 13. The earlier full local frontend attempt was stopped
after unchanged Recipe Adjustment timeouts under concurrent validation; its log
is retained. That file passes all 64 tests in isolation after cleanup, with normal
timeouts. The required GitHub full frontend suite must pass on the final PR head;
its exact commit and run are recorded in PR #360's description/checks.

General document presentation/quantity regressions pass 30 tests
(`document-regressions.log`). The first full GitHub job caught four old PO column
and band-position assertions in those files. They now target the approved six
columns, preserve full note/text and exact-quantity/identity guarantees, and assert
the practical note/description/quantity widths. No production builder changed in
this correction, so native specimens and SQL replay remain valid.

After comparison passed, the explicitly disposable local project was stopped
using its exact project ID and `--no-backup`. Its task-only volumes were removed;
unrelated Docker projects were left unchanged. To reproduce, create/start the
separate disposable project with the canonical migration/test/local directory
junctions, project ID shown above, seed disabled and unused local ports before
running the reset cycles. No linked or hosted command is needed.

Committed diagnostic logs normalize line endings and remove trailing alignment
padding so the required diff-whitespace check remains active. Their assertions
and results are unchanged; raw log copies stay in the task-owned temporary project.
