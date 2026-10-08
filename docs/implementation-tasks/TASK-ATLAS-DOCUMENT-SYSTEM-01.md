# ATLAS-DOCUMENT-SYSTEM-01

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
- [ ] Run exporter/guard/snapshot/note/breakdown/import compatibility and Shopping
      List regressions, full frontend tests, format, typecheck, build and whitespace.
      Review the branch, commit, push, open one Draft PR and record CI.

Prohibited: `docs/current-context.md`, `docs/architecture/roadmap.md`, Backend 02C
files, Supabase functions/migrations, business calculations, lifecycle/authority
changes, live data, new major dependencies and unrelated UI polish.

## Document matrix

| Document                  | Current implementation        | Business authority                                   | Current format      | Target format                  | Grouping                                                           | Filename                               | Status treatment                                           | Signatures                                 | Print QA            | Tests                          | Acceptance                          |
| ------------------------- | ----------------------------- | ---------------------------------------------------- | ------------------- | ------------------------------ | ------------------------------------------------------------------ | -------------------------------------- | ---------------------------------------------------------- | ------------------------------------------ | ------------------- | ------------------------------ | ----------------------------------- |
| SHOPPING_LIST             | confirmedNeedShoppingList     | Complete saved/current Confirmed Need                | V2 A+ XLSX          | unchanged                      | source School ID order                                             | unchanged PhieuDiCho period V2         | working paper                                              | unchanged                                  | regression specimen | full V2 suite                  | accepted baseline / preserved       |
| PO                        | purchaseOrderExports          | Released PO revision, supplier/note/School snapshots | XLSX + PDF          | same                           | supplier/date; School + location IDs; Ingredient + Unit + note     | snapshot supplier/date/official number | released / superseded, revision and replacement references | no new commitment/sign-off                 | pending             | exporter + snapshot guards     | pending owner visual review         |
| PXK                       | schoolDispatchReleaseExports  | Immutable School/date/location release               | XLSX + PDF          | same                           | one release per sheet, date/frozen School order                    | snapshot School/date/official number   | released / superseded, predecessor reference               | existing received/delivered/prepared areas | pending             | PXK exporter guards            | pending owner visual review         |
| DISPATCH                  | grouped School PXK exporter   | Same bounded released PXK snapshots                  | grouped XLSX        | same                           | date, frozen School order/name, number; distinct releases retained | PXK-GROUPED date range                 | status on every sheet                                      | existing PXK areas                         | pending             | grouped ordering/collisions    | no Trip/Vehicle/Warehouse expansion |
| ATTENDANCE_IMPORT         | planningInputsWorkbook parser | Existing School code + date, explicit Preview/Save   | XLSX import / paste | compatible blank XLSX template | existing selected week; no generated source facts                  | attendance import selected week        | import template / not saved                                | none                                       | pending             | unchanged parser compatibility | pending owner visual review         |
| GENERATED_PURCHASE_REVIEW | generatedPurchaseReviewExport | Read-only generated evidence/recommendations         | XLSX                | same                           | supplier ID, School/location IDs, Ingredient/Unit IDs              | ban-du-kien service date               | DỰ KIẾN — CHƯA XÁC NHẬN                                    | reviewer working space only                | pending             | preliminary export suite       | pending owner visual review         |

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
- Focused initial verification: six files / 66 tests passed, including Attendance
  download without Preview/Save. Added further guard/determinism cases afterward.
  Full frontend verification and final CI results are recorded below when available.
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
