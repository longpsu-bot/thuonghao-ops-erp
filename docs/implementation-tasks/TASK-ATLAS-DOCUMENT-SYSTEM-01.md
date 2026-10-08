# ATLAS-DOCUMENT-SYSTEM-01

## Current Owner fidelity revision

The 8 October 2026 approved printed-quantity decision is implemented as a
presentation-only continuation of reviewed head `03580da349047881c247601538b3685f817ccbfb`:
trim fractional zeros, normally at most two meaningful decimal places, preserve
and record exact exceptions. The Owner also requested wider item descriptions
and smaller routine quantity columns. [Current specimens, precision ledger and
validation](../testing/artifacts/atlas-document-system-01/quantity-precision/README.md)
supersede earlier padded-quantity specimens for display review. Source precision,
snapshots, calculations, Allocation validation and Shopping List V2/A+ are unchanged.
Same Draft PR #360; Owner acceptance and the existing Class C decisions remain open.

The Owner rejected reviewed head `f3c8b5014e87906399c5cb1035c0b87cf4052f95`:
**DOCUMENT_SYSTEM_V1_FIDELITY = NOT ACCEPTED**. The same branch and
[Draft PR #360](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/360) are revised;
no new Document System task/PR, merge or backend change is authorized here.

Current evidence and complete per-document V1 comparison matrix:
[V1 revision specimens](../testing/artifacts/atlas-document-system-01/v1-revision/README.md).
Exact Owner references were available and read unchanged. The revision restores
six-column PO summary, `Ngày dùng`, compact detail bands/numbered rows, the
seven-column PXK with three separated signing areas, PO selection modes and
supplier/date plus Dispatch date/captured-entity ZIP packaging.

[Class C authority gaps](../open-questions/atlas-document-system-v1-authority-gaps.md)
remain blocked: immutable outward codes, PO label/address authority and V1 cooking
groups. The Owner explicitly approved PO presentation over the unchanged read
while retaining these blocks. Required codes are visibly reported as unavailable;
no UUID-as-code, mutable code lookup, cooking-group heuristic or invented API.

Shopping List V2/A+ remains unchanged. Focused exporter/UI/Shopping regressions,
format, typecheck, build and exact-head GitHub CI are the validation gates;
product acceptance remains the Owner's decision. No live Supabase/Retool operation,
release semantic change or Backend 02C edit. Presentation rollback is a branch
revert; no migration/production rollback is needed.

The sections below record the historical implementation at the rejected reviewed
head. Their old geometry and technical PASS statements are not the current V1
acceptance result; the linked revision record supersedes them.

## Authorization and baseline

One presentation-bounded Draft PR; no automatic merge or global document freeze.
Starting latest `origin/main`: `5f2206e289eae247781148d23e8bc0c8f52acb8f`.
Branch: `feat/atlas-document-system-01`. The owner authorized an isolated worktree
after the original checkout was found occupied by concurrent Backend 02C work.

Authority: ARCH-002, Planning–Procurement business freeze, model convergence,
School-catering Procurement, School Dispatch Release, Planning Inputs, and
`ATLAS_SHOPPING_LIST_V2 / A+`. Retool and supplied workbooks are read-only layout
evidence. No live Retool, Supabase or OPS access is required.

## Bounded design and execution plan

Small print primitives plus document-specific builders. Reuse ExcelJS/pdfmake.
Preserve all source guards, API envelopes, releases, acceptance and stable lineage.
Shopping List retains its specialized codec, geometry and import validator unchanged.

- [x] Add failing presentation tests for exact text, snapshot-ID grouping,
      status, print repetition, footer, deterministic ordering and filenames.
- [x] Implement shared typography, borders, print setup, wrapping/height,
      filename/worksheet sanitation and PDF footer helpers under
      `src/modules/atlas/documents/`; retain document-specific structures.
- [x] Update `procurement/purchaseOrderExports.ts` and
      `dispatch/schoolDispatchReleaseExports.ts`; retain official guards and
      immutable snapshots. Update `generatedPurchaseReviewExport.ts` only for
      common print behavior, wrapping and deterministic ID-based ordering.
- [x] Provide an Attendance import template using existing recognized headings,
      no default quantities and no new acceptance semantics. Test it with the
      unchanged production parser. Only directly related download affordances
      may change; navigation/workbench table design stays outside this task.
- [x] Generate deterministic safe fixture specimens through production builders.
      Inspect native Excel open/save/reopen and actual PDF pagination/rendering.
      Keep native QA copies separate from clean deliverables.
- [x] Run exporter/guard/snapshot/note/breakdown/import compatibility and Shopping
      List regressions, full frontend tests, format, typecheck, build and whitespace.
      Review the branch, commit, push and open one Draft PR. Exact-head CI is
      tracked on [Draft PR #360](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/360);
      integration requires its required Frontend CI to pass.

Prohibited: `docs/current-context.md`, `docs/architecture/roadmap.md`, Backend 02C
files, Supabase functions/migrations, business calculations, lifecycle/authority
changes, live data, new major dependencies and unrelated UI polish.

## Document matrix

| Document                  | Current implementation        | Business authority                                   | Current format      | Target format                  | Grouping                                                           | Filename                               | Status treatment                                           | Signatures                                 | Print QA        | Tests                          | Acceptance                          |
| ------------------------- | ----------------------------- | ---------------------------------------------------- | ------------------- | ------------------------------ | ------------------------------------------------------------------ | -------------------------------------- | ---------------------------------------------------------- | ------------------------------------------ | --------------- | ------------------------------ | ----------------------------------- |
| SHOPPING_LIST             | confirmedNeedShoppingList     | Complete saved/current Confirmed Need                | V2 A+ XLSX          | unchanged                      | source School ID order                                             | unchanged PhieuDiCho period V2         | working paper                                              | unchanged                                  | native/PDF PASS | full V2 suite                  | accepted baseline / preserved       |
| PO                        | purchaseOrderExports          | Released PO revision, supplier/note/School snapshots | XLSX + PDF          | same                           | supplier/date; School + location IDs; Ingredient + Unit + note     | snapshot supplier/date/official number | released / superseded, revision and replacement references | no new commitment/sign-off                 | native/PDF PASS | exporter + snapshot guards     | pending owner visual review         |
| PXK                       | schoolDispatchReleaseExports  | Immutable School/date/location release               | XLSX + PDF          | same                           | one release per sheet, date/frozen School order                    | snapshot School/date/official number   | released / superseded, predecessor reference               | existing received/delivered/prepared areas | native/PDF PASS | PXK exporter guards            | pending owner visual review         |
| DISPATCH                  | grouped School PXK exporter   | Same bounded released PXK snapshots                  | grouped XLSX        | same                           | date, frozen School order/name, number; distinct releases retained | PXK-GROUPED date range                 | status on every sheet                                      | existing PXK areas                         | native/PDF PASS | grouped ordering/collisions    | no Trip/Vehicle/Warehouse expansion |
| ATTENDANCE_IMPORT         | planningInputsWorkbook parser | Existing School code + date, explicit Preview/Save   | XLSX import / paste | compatible blank XLSX template | existing selected week; no generated source facts                  | SiSo_MauNhap_YYYY-MM-DD.xlsx           | import template / not saved                                | none                                       | native/PDF PASS | unchanged parser compatibility | pending owner visual review         |
| GENERATED_PURCHASE_REVIEW | generatedPurchaseReviewExport | Read-only generated evidence/recommendations         | XLSX                | same                           | supplier ID, School/location IDs, Ingredient/Unit IDs              | ban-du-kien service date               | DỰ KIẾN — CHƯA XÁC NHẬN                                    | reviewer working space only                | native/PDF PASS | preliminary export suite       | pending owner visual review         |

## Rulings and authority gaps

- Ruling: authoritative released quantities render as exact text in XLSX, never
  through `Number`; display arithmetic stays BigInt and the same snapshot data
  feeds PDF. This repairs the existing exporter mismatch with the exact-decimal
  API rule without changing accepted quantities or backend authority.
- Ruling: PO grouping uses captured School/location and Ingredient/Unit IDs;
  equal names do not collapse distinct destinations or Units.
- `DOCUMENT_GROUPING_AUTHORITY_GAP`: current bounded exports have no immutable
  company cooking-group identifier. No historical Retool name/contract-type
  heuristic or mutable master-data lookup is introduced.
- PO delivery addresses are not supplied as a typed immutable field by its
  School breakdown contract; no address is reconstructed from current master data.
- PDFs retain the existing embedded Vietnamese-capable Roboto assets. XLSX/native
  Excel uses established Times New Roman. A bundled, licensed Times New Roman PDF
  font is not currently provided; raw OS fonts are not copied into the repository.

## Verification and evidence

Safe specimens: [review artifacts](../testing/artifacts/atlas-document-system-01/README.md).
No production data is included. The artifacts come from production builders with
synthetic fixture facts and fixed source timestamps, never a live connection.

- Native Microsoft Excel 16.0: 12 clean workbooks opened normally, saved as separate
  QA copies, reopened normally; 419 decimal text cells preserved exactly. Clean
  originals were unchanged by native save. No horizontal page breaks/cropping.
- PDF: eight production PDFs plus 28 native worksheet PDFs, 151 physical pages
  rendered into 19 contact sheets. Every page reviewed across implementation and
  independent review. Zero missing expected visible strings across 36 documents.
- Multipage: repeated issuer/identity/status/table headers in native XLSX output;
  PO detail repeats destination per row; preliminary review repeats supplier on
  every summary row and supplier/School/location on every detail row. Eleven
  quantity-bearing review continuation pages passed per-page context checks.
- Signatures: existing PXK roles/instructions in a single 102-point physical row
  with writing space; all five native signature groups passed page-level checks.
  No signature creates a new approval, release or business commitment.
- A valid 492-character, 240-newline supplier note is retained character-for-character
  in bounded continuation rows; quantity appears once per logical line. Actual
  PDF includes both note ends and exact quantities. This fixes the independent
  review's reproduced silent loss of a page-tall row, not just a definition test.
- Determinism: 19 specimens reproduce identical SHA-256 after ZIP timestamp
  normalization. Preserved Shopping uses randomized protection salts: compare
  captured cells/print geometry instead of weakening protection for byte equality.
  Only fixture modified-time is fixed. Shopping's production codec is untouched;
  clean V2/A+ import reports no changed lines.
- Independent code review: both Important findings (tall-note loss and lost
  continuation context), plus the truncated worksheet apostrophe, fixed and
  rechecked. No remaining Critical/Important code or visual findings.
- Focused initial verification: six files / 66 tests passed. Final document,
  Attendance UI and import-boundary checks: four files / 94 tests passed. Shopping
  and Confirmed Need regressions plus Planning Sources: nine files / 220 tests
  passed. The unchanged legacy Planning Inputs suite passed all 38 tests separately.
- Full local frontend run: 187 files / 2,534 tests; 2,531 passed, three failed.
  One filename expectation was corrected and its 11-test suite passed; two existing
  focus/timeout failures under concurrent Windows load passed in serialized suites.
  No assertions or timeouts were weakened. Required GitHub CI owns final full-suite
  validation; its exact-head outcome is maintained in the linked Draft PR.
- First PR CI exposed a direct legacy import from the Attendance stage. The
  download now follows existing composition-root export callbacks through
  `AtlasVNextConnectedApp`, `AtlasVNextApp`, `AtlasWorkbenchRegistry`,
  `PlanningSourcesWorkbench`, and the existing Planning Sources props. The root
  allowlist adds only the template module; direct vNext/business-bridge imports
  remain forbidden and have a regression check. This changes export wiring only,
  with no business bridge or API contract change. `pnpm ui:vnext:check` passed.
- Subsequent full CI passed 2,532 tests (two existing environment-gated skips)
  and found one stale connected-root exporter-key expectation. The expectation
  now includes the authorized Attendance callback, retaining exact key/function
  checks and the no-RPC assertion. Its focused root test passed. Database smoke
  and repository preview checks passed; the final full CI outcome is tracked on
  the Draft PR rather than treating this intermediate run as passing.
- Local format, typecheck and production build passed. Build retains existing
  large-chunk warnings; no dependency or public contract change was introduced.

Final native QA status for PO, PXK, Dispatch, Attendance and preliminary purchase
review: **PASS — owner visual acceptance pending**. SHOPPING_LIST:
**accepted baseline / preserved**. A4 fit-to-width, unlimited vertical pagination,
document-specific header repeats and identity/page footers are configured. Native
Excel owns physical pagination; heuristic manual breaks were removed after they
wasted paper in rendered QA.

Owner findings: PDF retains existing Roboto pending licensed TNR font/owner visual
acceptance. In the large preliminary specimen, the reviewer line occupies its own
final summary page; nonblocking print-efficiency observation. No global
presentation freeze or merge is authorized by technical QA.

## Security, migration and rollback

BUSINESS CONTRACT CHANGES: 0. DATABASE AUTHORITY CHANGES: 0.
SHOPPING LIST V2 COMPATIBILITY: preserved. RETOOL CHANGES: 0. LIVE OPS CHANGES: 0.
No migration or Supabase writes. Rollback is a frontend presentation revert;
released snapshots and historical business evidence remain untouched.
