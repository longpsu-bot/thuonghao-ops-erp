# ATLAS-DOCUMENT-SYSTEM-01

## Hidden parsing metadata follow-up — 9 October 2026

Owner request: make Ingredient IDs and parsing information hidden like Shopping
List. Continue the same branch and Draft PR #360. Scope: existing PO/PXK exporters,
their focused tests, fixture/native QA scripts and affected export documentation.

Plan and acceptance criteria:

- [x] Add hidden row IDs, scope, exact quantity and item/continuation kind after
      the existing print columns in every PO/PXK Excel mode and ZIP member.
- [x] Preserve every aggregated/continued row's immutable source association in
      one very-hidden `_ATLAS_META` sheet with a distinct versioned output contract.
- [x] Keep technical replacement IDs out of visible XLSX/PDF headers while
      retaining readable replacement status and exact references in metadata.
- [x] Preserve frozen business codes, School bands, `Nấu tại`, notes, quantities
      and signature space. Reserve the metadata sheet name for single/grouped PXK.
- [x] Pass focused tests and native Excel open/save/reopen plus PDF review.
- [x] Complete the bounded source review with no actionable findings and prepare
      the follow-up for the existing Draft PR's required GitHub Frontend CI.

No backend/migration/security authority changes, new import workflow, dependencies,
Shopping List V2/A+ edits, hosted data operations, deployment or merge. Metadata
hiding is presentation only. Frontend revert is sufficient rollback. Contract:
[operational document XLSX metadata](../api/operational-document-xlsx-metadata.md).

Validation: 88 focused tests in six files, TypeScript, deterministic generation,
native Excel round trips for six workbooks and all 16 PDF/native pages pass.
Fixture-only evidence:
[hidden parsing specimens](../testing/artifacts/atlas-document-system-01/hidden-parsing-metadata/README.md).
The required Frontend CI remains the final gate on the current PR head; its live
status and revision-specific evidence are recorded on PR #360. Keep the PR Draft
for Owner visual/product acceptance.

## Final PO document identity closeout — 9 October 2026

Owner instruction: continue PR #360 from `a2b753e18543b1cf2d1f4a851d53e18a2fb162e0`.
School bands, Cooking Group authority, `Nấu tại`, frozen supplier notes and PXK
blank working notes are accepted. The following bounded implementation extends
the existing authority; older sections below describe earlier review states.

Plan and acceptance criteria:

- [x] Add nullable explicit Ingredient/Supplier `document_code` fields through
      existing governed Master Data editors and commands. Populate only the exact
      positive numeric suffix of proven `v1-ingredient-<n>` / `v1-supplier-<n>`
      import codes. Leave unrelated/native technical codes untransformed.
- [x] Require nonblank outward supplier/item codes for future official PO release;
      atomically freeze supplier code, Ingredient code/name and Unit code in the
      release successor. Preserve replacement, commitments and exact quantities.
- [x] Read released/superseded labels from snapshots. Derive snapshot completeness;
      retain incomplete historical records for reading but block official
      regeneration with safe Vietnamese copy. Never backfill historical labels.
- [x] All official PO XLSX/PDF modes and supplier/date ZIP consume frozen codes
      and labels, preserving accepted layout, supplier notes and group snapshots.
- [x] RED/GREEN tests cover provenance, explicit/null codes, label/code mutation,
      replacement/predecessor history, missing snapshots and all export modes.
      Run Master Data, supplier-note, Cooking Group, PXK, Shopping and security
      regressions, chronological disposable replay and relevant 02D certification.
- [x] Regenerate and review native specimens; update this existing task and gap
      register. Deliver on the same branch with required exact-head CI tracked
      on the existing Draft PR.

Ownership: backend migration/SQL/API contracts; Admin frontend/model/review
adapter; PO frontend/exporters/native evidence and integration. No existing
migration edits, new workbench, lifecycle, dependency, PXK business change,
Shopping/Need/Allocation change, hosted query/deployment, Live OPS access or merge.
No supplier-address parsing or invented membership data. Missing V1 memberships
are a cutover configuration gate; the existing Need performance finding remains.

Official outward codes are required for this supplier document contract. Native
Masters may retain null until explicitly authored; such records block release.
Historical missing snapshots cannot become reproducible from current masters.
Forward rollback must retain authored codes and released snapshot evidence.

Closeout implementation and review:

- CLI-generated migration `20261009105641_atlas_po_document_identity.sql` adds
  nullable Master codes and immutable release facts. Previous 95 migrations are
  unchanged. Repository count is 96; Staging stays at its Owner-verified 94/tip
  `20261008015340_atlas_backend_convergence_02b_allocation`. No hosted queries or
  writes, Retool changes, Live OPS access, merge or deployment occurred.
- Exact V1 import provenance populates only positive numeric suffixes as text.
  Native codes are explicit. Valid codes are trimmed, single-line, 1–200 Unicode
  characters, excluding technical V1 prefixes, UUID substrings and controls.
  Supplier, sorted Ingredients and exact Units are locked before atomic release
  capture. Backend validation blocks absent codes before commitments are issued.
- Released/superseded reads project immutable labels, codes, School contributions
  and supplier notes; historical incomplete evidence remains readable with safe
  missing labels and `document_snapshot_complete: false`. Official exports fail
  closed. A replacement captures its own current facts and preserves predecessor
  facts. No historical snapshot reconstruction/backfill is allowed.
- Existing Ingredient/Supplier editors and Review show the Vietnamese document
  code labels. Explicit null clears a code; omitted update preserves it. Existing
  write scope, audit, optimistic version and receipt contracts are retained. New
  inputs remain disabled during save/readback/recovery; recovery cannot clear a
  newer draft or a different Actor's pending command.
- Nine focused SQL suites pass 744 assertions: identity 31, PO release/history/
  replacement 132, catalog 28, Master Data 43, Cooking Group 33, PXK 59, supplier
  note 13, Purchase Review 147 and atomic Planning 258. The exact catalogue
  contract passes 111 frontend tests. Catalog remains 115 private forced-RLS
  tables, 118 physical/115 authenticated APIs, 31 capabilities and 663 normal
  policies; 332 private functions, 120 triggers, 1,797 reviewed positive grants.
  No browser table privileges, frontend service role or extra callable APIs.
- Focused frontend regression covers 79 document tests, 33 procurement/PXK
  integration tests, 113 Shopping V2/A+ tests, nine Cooking UI tests and 80 Admin
  editor/model/review/hook/workbench tests. New edge checks preserve 200 Unicode
  characters and complete code-point fragments. Format, typecheck, build and
  whitespace checks pass; the existing bundle-size warning remains.
- Production builders produce 33 byte-deterministic specimens: 16 XLSX, 15 PDF,
  two ZIP; 15 exact-source quantity parity pairs. Native Excel 16.0 checks 16
  workbooks/35 sheets/1,939 exact strings through open/save/reopen. PDF text and
  print review checks 50 documents/119 pages, all rendered and visually reviewed
  in 15 contact sheets. Frozen master mutation, predecessor/replacement, numeric
  V1 codes and 200-character supplier/item codes have dedicated specimens.
- Source/print review closed supplier-note projection, header completeness,
  code-validation parity, editor readback and long-code wrapping/continuation
  findings. It reports no remaining actionable finding in this bounded scope.

[Closeout evidence and reproducible commands](../testing/artifacts/atlas-document-system-01/po-identity-closeout/README.md)
record clean replay, focused results, deterministic/native manifests and final
delivery gates. Exact-final-head GitHub CI is required on the same Draft PR #360
before delivery; Owner product/visual acceptance remains pending.

Authority closeout status: Cooking Group / `Nấu tại` **RESOLVED**; PO label
immutability **RESOLVED**; V1 outward codes **RESOLVED for proven V1-derived
records**; native code is an **explicit governed field**. Missing V1 memberships
are a **CUTOVER_DATA_CONFIGURATION_GATE**. Supplier address remains **OPEN**:
source-only/unmapped `contact_details` is never parsed. Complete V1 fidelity is
not claimed. The unrelated four-second Need target miss remains open with its
eight-second hard guard unchanged. An adjacent pre-existing Admin lifecycle
save/readback guard issue is documented outside this bounded code-save correction.

Local performance evidence is deliberately retained: the first clean cycle passes
all 42 scale assertions (p95 6,595.519 ms). An initial second reset and its two
unchanged retries failed a relative profiling assertion, then the elapsed hard
guard (p95 7,465.438 / 10,808.546 / 9,095.231 ms). A fresh second reset passes all
42 (p95 5,390.429 ms). All failed attempts remain in the closeout artifacts.
The unchanged measured path/call counts exclude a demonstrated new identity
dependency; the cause of local timing variability remains unproven and open.
No Need optimization, test selection change or threshold relaxation occurred.

Final chronological replay: two clean seed-disabled cycles each replay all 96
migrations and pass 53 SQL suites / 3,643 assertions plus five semantic fixtures.
Exact catalog, definition and assertion digests match. Semantic comparison passes
after excluding the existing native-create technical code's embedded random UUID;
all explicit document codes remain compared exactly. Raw cycle evidence retains
that random technical code. `comparison.json` is PASS with no differences.

## Owner cooking-group / School-band amendment — 9 October 2026

Implementation is complete and locally verified on the same
`feat/atlas-document-system-01` branch and Draft PR #360. Owner product/visual
acceptance remains pending; final exact-head GitHub validation is recorded on the
PR's checks and description. Starting main: `343f2b1ee743ee59a382708b7ab94321915e75f2`;
reviewed PR head: `240cd88067903467293e93ce20c277d30b91bd7b`.
The authorized checkout is `D:/Project/Repo/OPS/thuonghao-ops-erp`. It was switched
from the clean unrelated Shopping List branch as explicitly instructed, then
verified clean, at the reviewed head, with latest `origin/main` as an ancestor.

This Owner instruction supersedes the earlier presentation-only prohibition
against backend changes **only** for one Admin-owned optional current School
cooking-group assignment and its immutable released-document snapshots. It does
not approve deployment, V1 data adoption, outward codes or PO label repair.

Implementation scope and acceptance:

- [x] One current Cooking Group master and School membership authority. No
      effective dating, approval lifecycle or per-document group authority.
      Existing Admin capabilities, forced RLS, shaped APIs and command safety.
- [x] Extend existing School Admin with optional controlled `Nấu tại` assignment
      and compact group maintenance; backend remains authoritative.
- [x] Freeze group ID/name on new released PO School contributions and PXK
      headers. Preserve historical rows, School lineage and PXK grain.
- [x] PO School bands replace repeated School cells where identity is established.
      `Ghi chú` uses frozen supplier note, including null/multiline/boundary cases.
      Ingredient comparison keeps necessary School identity.
- [x] PXK School header shows captured `Nấu tại` only when grouped. Blank physical
      row notes retain inspection meanings, writing space and signatures;
      document release note appears once outside the item rows.
- [x] CLI-generated forward migration, chronological disposable replay, Admin
      and snapshot/security pgTAP, relevant 02B/02D and document/Shopping regression.
- [x] Production-builder XLSX/PDF specimens, native Excel open/save/reopen,
      pagination and full visual review; format/typecheck/build/frontend tests.
- [x] Update this record and existing authority gaps truthfully.

Delivery gate: commit/push only the same branch and require exact-final-head
GitHub CI before recommending acceptance. Keep PR Draft for the Owner; do not
merge, deploy or adopt V1 memberships automatically.

Allowed files: new forward migration and focused SQL tests/catalog registrations;
existing Admin API/model/School UI; PO/PXK read types/exporters and their tests;
existing specimen certification tooling; affected API/documentation and evidence.
No Shopping List contract/geometry/import change, Allocation writer/precision,
Need, Recipe, Unit, PO commitment, PXK readiness, replacement/cancellation,
Warehouse, Retool, Live OPS or hosted Staging change.

Staging baseline is Owner-provided and independently verified before this task:
94 migrations, tip `20261008015340_atlas_backend_convergence_02b_allocation`.
This task must not redeploy or rediscover hosted data. Local synthetic verification
does not certify hosted acceptance. Remaining V1 adoption needs retained actual
membership values and reconciliation; missing values must not be guessed.

School Cooking Group / “Nấu tại”: **APPROVED BOUNDED CLASS C AMENDMENT**.
The implementation satisfies the approved current optional membership and minimum
frozen ID/name contract. This records the bounded Owner decision; it does not
grant overall V1 fidelity acceptance or solve the other Class C gaps.

[Current evidence and reproducible commands](../testing/artifacts/atlas-document-system-01/cooking-group-revision/README.md):

- One CLI-generated forward migration,
  `20261009075715_atlas_school_cooking_groups.sql`; the previous 94 files are
  unchanged. Two clean local seed-disabled database resets each replayed all 95
  migrations, passed 52 SQL suites / 3,588 assertions and four semantic fixtures.
  Migration manifests, catalog definitions, assertion digests and business
  evidence match exactly (`comparison.json`: PASS, no differences). These are
  database reset cycles, not a new independent full-volume 02D certification.
- Cooking Group 33, PO 108, PXK 59, security catalog 28, supplier-note 13,
  Admin 43, 02B helpers 124 and Allocation 417 assertions pass. Existing release,
  commitment/replacement, fulfilment, Recipe/Need and Shopping read suites pass.
  School defaults bulk remains covered. Exact catalog contract tests pass 111.
- Source/visual review found and closed uncertain creation recovery and wide-glyph
  print clipping defects. Creation recovery now replays the exact saved command
  and confirms the returned group ID; same-name groups cannot clear a draft.
  Final School/review UI regressions pass 32, final PO/V1/package/output checks
  pass 35 and PXK/output checks pass 13. Shopping V2/A+ regressions pass 113.
- Production builders generated 11 XLSX / 10 PDF / 2 ZIP fixtures with identical
  hashes across two sequential generations. Native Excel 16.0 passes 11 workbooks,
  20 sheets and 206 exact-text checks. All 32 PDF documents / 82 pages have zero
  missing expected strings; all 11 contact sheets plus full-resolution note/PXK
  details were reviewed. No clipping, horizontal cropping, split signatures or
  header-only Dispatch pages; signature handwriting clearance is at least 100 pt.
  Stress pagination and font-face differences remain explicitly reported.
- Format, TypeScript compilation/typecheck, production build and whitespace checks
  pass. A resource-contended local full frontend attempt timed out in unchanged
  Recipe Adjustment UI tests and was stopped; it is retained in `frontend-tests.log`.
  The unchanged file passes all 64 tests in isolation after disposable-database
  cleanup (`recipe-ui-isolated.log`). Normal timeouts/checks are unchanged.
  Full routine frontend validation belongs
  to the required GitHub job on the final PR head; no earlier green head substitutes.
  The first pushed head's full job found four stale general-document assertions
  addressing the old PO quantity/note columns and seven-column bands. Those two
  test files now assert the approved six-column geometry while retaining complete
  notes, exact quantity totals, source immutability and distinct identities; all
  30 assertions pass. This follow-up changes tests/evidence only, so native
  specimens and database replay remain valid. Final CI must validate the new head.

Security: two private forced-RLS tables, three authenticated shaped APIs using
existing GLOBAL Admin capabilities, dedicated runtimes, empty search paths and
idempotent receipts. No new capability/role, direct browser table privilege or
frontend service-role credential. Assignment/deactivation serialize through row
locks and relational guards. School identity, snapshot lineage, released quantities
and existing business commands retain their authority.

Changed areas: the new migration and focused SQL suites/catalog assertions;
`masterDataApi.ts` / `masterDataModel.ts`, RPC registry and review adapter;
School Admin controller/table/compact `SchoolCookingGroupEditor.tsx`; PO/PXK
read types/exporters/tests; existing specimen tooling; API contracts, this task,
the existing authority-gap record and retained test/specimen evidence. No new
persistent workbench or dependency is introduced.

Open findings: actual V1 PO/Dispatch membership values are unavailable; the CSV
has headings only and adoption remains blocked with
`COOKING_GROUP_RECONCILIATION_REQUIRED` for unresolved evidence. Outward codes and
PO Ingredient/Unit label immutability remain open. Local Need scale passes the
unchanged eight-second regression deadline but misses the four-second operator
target (p95 6275.680 / 5961.375 ms); hosted performance was not measured and this
task does not change Need Generation. No remaining Critical/Important source or
print review finding is reported.

Deployment/rollback: zero Staging or Live OPS queries/writes. The Owner-provided
hosted 94-migration baseline is retained. The migration seeds and backfills nothing;
old captured facts stay null/absent and old exports omit `NẤU TẠI`. A future rollback
must be a forward correction disabling maintenance/exposure while preserving
current membership and released snapshots; do not drop captured historical facts.
The disposable local project was stopped and its task-only volumes removed after
evidence collection; unrelated Docker projects were left unchanged.

The sections below preserve prior revision history and its earlier boundaries.

## Prior Owner fidelity revision — 8 October 2026

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

## Owner font legibility follow-up — 8 October 2026

Compared original V1 workbooks printed through native Excel with production PO/PXK
PDFs. V1 body/quantity sizes are approximately 14 pt for PO and 15 pt for PXK;
the prior 10/11 pt PDF body was too small. PO now uses 14 pt body/quantity and
16 pt headers; PXK PDF uses 15 pt, native table/signatures use 16 pt. Preliminary
quantities match its existing 14 pt body. Description space and compact exact
quantity formatting remain preserved.

Wide exact quantities use landscape and native fixed 100% print scale; manual
breaks keep the entire PXK signature block together. Ordinary V1 forms remain
portrait. Native Excel/PDF specimens, measured font comparisons and verification
are in [font-legibility](../testing/artifacts/atlas-document-system-01/font-legibility/README.md).
Larger stress outputs can require more pages. No business/schema/API, snapshot,
Shopping List V2/A+ contract or Class C decision changes. Same PR #360 stays Draft
for Owner acceptance; no merge authorized.

## Security, migration and rollback

BUSINESS CONTRACT CHANGES: 0. DATABASE AUTHORITY CHANGES: 0.
SHOPPING LIST V2 COMPATIBILITY: preserved. RETOOL CHANGES: 0. LIVE OPS CHANGES: 0.
No migration or Supabase writes. Rollback is a frontend presentation revert;
released snapshots and historical business evidence remain untouched.
