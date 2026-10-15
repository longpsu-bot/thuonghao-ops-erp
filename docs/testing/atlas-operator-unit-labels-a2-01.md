# Operator Unit labels — A2 validation

Date: 15 October 2026

Starting main: `d102b2f1b083005d6553867fa5ccdf8c988a0316`.
Authority-only commit: `00c56868a15676f8e0f6a9ce54ec1a3f238c64f9`.
Status: prepared for independent Draft review and exact-head CI; no merge, deployment or hosted database write authorized.

## Contract and implementation

The [dated API amendment](../api/school-catering-procurement.md#operator-unit-labels-and-draft-school-projection--15-october-2026) governs A2. Current Confirmed Need, both Allocation routes, Generated Review and Draft PO presentation prefer a valid human Unit name, then a valid human legacy code. Technical-only or missing labels use `Chưa có tên đơn vị`. Active and retained legacy tables, detail panels, validation messages and preliminary exports use the same validity rule. Controlled UUIDs, codes, exact quantities and source evidence remain unchanged.

One forward migration adds nullable `unit_name_snapshot` without default or backfill. Existing ordinary/replacement release captures the current name under existing locks; the existing immutable guard/trigger protects it, including historical nulls. Released/superseded screens and PO PDF/XLSX exports use only frozen evidence. A human frozen legacy code such as `kg` remains valid. The existing nonblank frozen-code requirement is retained **and** a usable human frozen name/code is required for official export. Thus a technical but nonblank code plus frozen `Cái` can export; frozen `Cái` cannot repair a null/Unicode-blank controlled-code snapshot. Incomplete historical labels remain readable and use the existing incomplete-evidence export blocker; no new release prohibition/state exists.

Draft School projection calls the existing canonical positive-overlap helper for the displayed revision's exact supplier split, including stale Drafts. Official School evidence remains snapshot-only. Simulated future release captures supplied names and derives the same export flags/blocker; its single-School Draft breakdown now retains the represented School and exact supplier quantity rather than unrelated template quantities. Historical released fixtures retain their legacy `kg` evidence without fabricated names.

The approved [Shopping List resolver/import contract](../implementation-tasks/TASK-ATLAS-SHOPPING-LIST-UNIT-DISPLAY-01.md) stays code-first and unchanged. A1/A3/A4 changes from separate Draft PR #385 are not included. This branch does not alter A4 metrics, fonts or column widths, quantity arithmetic, currentness, numbering, scope, capabilities, RLS, runtime ownership or grants. Migration 110 is local source work only; hosted Atlas remains at accepted 109. Historical reports, deployment packages and hosted full-row digests are not rewritten or re-certified.

## Focused RED/GREEN proof

Actual producer tests first reproduced printing the technical code instead of frozen `Cái` and allowing technical-only historical evidence. The Unit-height tests then reproduced 28/30pt rows for a two-line `Kilogram`; the existing conservative wrapping helper now contributes to row-height maxima and first-row pagination reservation in detail and summary views. Font, columns, total width, canonical text and the School-height algorithm remain unchanged.

Read-model pgTAP RED on migration 109 exposed the missing column, Draft labels/School projection, capture and immutability. Follow-up negative controls reproduced the valid-name/missing-code completeness regression before restoring the original guard. Nullable-field assertions use null-safe equality and exact line counts. Historical official null-backfill denial is checked against the exact released revision, not only Draft rows. Current read tests rename a Unit while comparing every other row field unchanged; public Draft coverage excludes a zero-overlap School and stale Drafts retain their original split. The synthetic journey separately proves release success/replay while incomplete labels disable export; legacy `kg` and frozen `Cái` are positive controls.

Final tracked-source frontend results: **368 assertions / 16 files PASS**. The seven display/export/helper/simulator files pass 139 assertions; nine legacy/controller/API/Shopping List files pass 229. Existing tests now expect supplied `Kilôgam` where appropriate; COUNT fixtures pair their unchanged count code with the coherent human name. Quantity, focus-origin, draft, scope and replay assertions remain. Local runs use the CLI exclusion `**/.superpowers/**` solely to avoid ignored local reference copies matching path filters. Earlier collected-reference logs are retained but are not final coverage counts; no tracked test discovery/configuration or real suite is skipped. Type checking passes, and the final Impeccable layout scan returned no findings.

Final rolled-back local database results: **531 assertions PASS**:

| Existing suite                         | Assertions |
| -------------------------------------- | ---------: |
| School catering purchase orders        |        173 |
| Purchase review / Confirmed Allocation |        196 |
| Exact platform security catalog        |         30 |
| School catering Handoff Allocation     |         88 |
| Released Supplier Allocation read      |         13 |
| PO document identity                   |         31 |

The exact catalog expectation remains unchanged. Local development applied the migration transaction to the owned disposable database and iterated the reviewed completeness guard; fresh full migration integration is left to GitHub CI. No hosted migration, hosted fixture, staff assignment, real supplier commitment or Production/v1/Retool write was performed. Raw RED/GREEN, fixture diagnostics and final tracked-source logs remain in the session TEMP evidence; durable native reports below contain no credentials.

## Native Unit-cell proof

[Native open/save/reopen report](artifacts/atlas-operator-unit-labels-a2-01/excel-report.json): three production ExcelJS workbooks, 233 exact text/identity/quantity checks, source files unchanged. [Unit layout report](artifacts/atlas-operator-unit-labels-a2-01/unit-layout-report.json): all nine native Unit cells pass the unchanged 0.5pt printed clearance minimum (observed minimum 1.67998pt); all nine production PDFMake Unit cells retain full canonical text and safe geometry using a conservative 1pt inset. The short-School fixture contains frozen `Cái`, `Miếng` and `Kilogram`, technical frozen codes, deliberately different current Master names and exact `0.100001` quantities. No current name or technical code prints; every exact quantity remains.

Root inspected all six native/PDFMake first-page images. Final regeneration after the restored code guard uses producer SHA256 `88fefbc8392800b885ca74775fc681cd0a1691e120377a7558de1681d33e06a7` and helper SHA256 `313f8c370b1919534c8a231370ac89c7163dbd491ba185696b233fa25fe89205`. [Final image comparison](artifacts/atlas-operator-unit-labels-a2-01/final-png-comparison.json) confirms byte-identical rendered pages to those inspected. Selected [native detail](artifacts/atlas-operator-unit-labels-a2-01/native-details_ing-page-1.png) and [PDFMake summary](artifacts/atlas-operator-unit-labels-a2-01/pdfmake-sum-page-1.png) show the tested cells. Some labels wrap; no abbreviation, font shrinking or source-text alteration was introduced.

This is bounded Unit-cell proof, not whole-page certification or a guarantee for arbitrary labels/Office environments. The separate A4 School evidence and known unrelated page/header limitations remain historical. Any later hosted 110 acceptance needs a separately authorized guarded plan; this Draft does not authorize deployment or change the pending Warehouse Product choices.
