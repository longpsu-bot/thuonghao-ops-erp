# TASK-UI-QUALITY-02C — Confirmed Need Workflow and XLSX Round-Trip

## Status and outcome

**UI-QUALITY-02C-A:** workflow definition complete on the exact
`UI-QUALITY-02AB-UX` merge baseline
`9818efe4ec1eda7b1b5879494a382921afc758b7`.

**Conclusion:** **Outcome A — the current RMVP-05/06/07 backend contracts are
sufficient.** No Confirmed Need backend prerequisite is required.

**Next task:** `UI-QUALITY-02C-B — Implement Confirmed Need workflow and XLSX
round-trip`.

This document is the single canonical implementation handoff for
`UI-QUALITY-02C-B`. It changes no Application, API, SQL, migration, capability,
lifecycle, hosted environment, Retool application, or production data.

## 1. Authority and evidence

This review follows `OPS_SYSTEM_MAP` v1.0:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command/Event
→ Read Model
→ Application
→ Technology
```

The governing delivery principle is workflow-led, contract-constrained and
backend-authoritative.

The accepted presentation authorities are:

- D-034: table-first Modern Operations visual architecture;
- D-035: happy path first, progressive disclosure, plain Vietnamese operator
  language and one backend-authorized next action; and
- D-036: humans complete authored input or make real commitments while the
  system performs deterministic validation. D-036 explicitly leaves D-030 and
  D-031 authoritative for Confirmed Need.

The review covered the merged RMVP-05 review/preview/confirmation contract,
RMVP-06 complete-batch validation contract, RMVP-07 approval/release contract,
their connected Application implementation and focused migration/test evidence.

Retained OPS v1 PurchasePlanner evidence contributes one useful Application
workflow pattern:

```text
export quantity workbook
→ edit quantity/note in Excel
→ parse the workbook
→ update local working rows and local patches
→ later use the normal Lưu action
```

In that evidence, `js_need_export_template` creates an XLSX quantity template;
`js_import_actual_from_shopping_xlsx` parses it and updates `st_need_rows` plus
`st_need_patches`; and `btn_save_actual` later invokes the normal save query.
Import itself does not perform the database save. Atlas preserves that operator
idea only. It does not copy Retool direct SQL, JavaScript state architecture,
date/name matching, implicit rounding, optimistic authority, page layout, or
database ownership.

## 2. Human job and business vocabulary

The Planning operator's job is to review one current Confirmed Need batch and
make an accountable quantity decision for every line before the batch is
approved and released for later Purchase Handoff consumption.

The normal table must distinguish:

| Meaning                     | Operator presentation                                                                           |
| --------------------------- | ----------------------------------------------------------------------------------------------- |
| Theoretical quantity        | `SL lý thuyết`; deterministic Need Generation result                                            |
| Proposed confirmed quantity | `SL đề xuất`; backend-shaped starting proposal                                                  |
| Operator confirmed quantity | `SL xác nhận`; the operator's draft and, after RMVP-05 confirmation, the authoritative decision |
| Unchanged proposal          | `Chấp nhận đề xuất`; confirmed quantity equals the proposal                                     |
| Adjusted quantity           | A confirmed quantity different from the proposal; show the signed difference                    |
| Reason                      | Controlled Vietnamese label mapped to the existing backend code                                 |
| Note                        | Human explanation when the governed reason or a correction requires it                          |
| Prior decision/correction   | Current decision plus newest-first history under progressive disclosure                         |

The operator must not need batch IDs, revision IDs, decision IDs, fingerprints,
policy revision IDs, internal reason codes, or lifecycle implementation terms
to do normal work.

## 3. Target normal workflow

### 3.1 Exact happy path

```text
Tạo nhu cầu / Cập nhật nhu cầu
→ Xác nhận nhu cầu opens the current materialized batch
→ inspect theoretical and proposed quantities
→ edit directly in the Atlas table
   OR
   Xuất Excel → edit → Nhập Excel → review → Áp dụng vào bảng
→ one shared local Confirmed Need draft
→ review the backend-authoritative preview
→ Xác nhận số lượng through RMVP-05
→ Hoàn tất xác nhận through RMVP-06
→ Phê duyệt lô nhu cầu through RMVP-07
→ Phát hành sang bước lên đơn through RMVP-07
→ RELEASED_FOR_PURCHASE_HANDOFF
```

Not every arrow is a button. Export, import and direct editing are productivity
operations. Preview is a write-free backend check integrated into the quantity
confirmation interaction. Validation executes as the consequence of the human
completion declaration. Approval and release remain distinct commitments.

### 3.2 One canonical local draft

The Application must have one Confirmed Need draft keyed by stable
`confirmed_need_line_id`:

```text
authoritative Confirmed Need readback
                 ↓
       local Confirmed Need draft
          ↙                 ↘
 direct table edit       XLSX import
          ↘                 ↙
       same per-line draft shape
                 ↓
       RMVP-05 preview/confirm
                 ↓
       RMVP-06/07 lifecycle path
```

The draft carries the existing fields only: selected state, exact quantity
string, governed reason code and reason note, together with the authoritative
line/revision/decision bindings already required by RMVP-05. There is no
`ExcelDraft`, `BulkDraft`, spreadsheet aggregate, import business object, import
RPC, or alternate save command.

Export takes its quantity, reason and note values from this shared local draft,
so direct edits made before export are not lost. Import review compares the
workbook candidate with the current shared draft. Applying an accepted import
replaces only the editable draft fields for the corresponding lines and
invalidates any prior preview.

## 4. Normal screen and action hierarchy

The five-second desktop layout is:

```text
Week / service period
→ plain current Confirmed Need state and consequence
→ compact attention/completeness summary
→ dominant quantity table
→ subordinate Xuất Excel / Nhập Excel controls
→ exactly one immediate meaningful next action
→ concise explanation of that action's consequence
```

The table is the main work surface. Do not add dashboard vanity cards. Show
only useful counts such as total, unreviewed, adjusted, blocking and warning
counts. Put technical identity, immutable evidence, fingerprints and lifecycle
history under `Chi tiết`, `Bằng chứng` or `Lịch sử`.

`Xuất Excel` and `Nhập Excel` are secondary productivity actions. They must not
visually compete with `Xác nhận số lượng`, `Hoàn tất xác nhận`, `Phê duyệt lô
nhu cầu`, or `Phát hành sang bước lên đơn`.

Do not create a separate Excel workflow page. After a file is read, show a
bounded import-review panel or dialog on the same workbench. After `Áp dụng vào
bảng`, close that review and return to the normal draft table.

## 5. XLSX export contract

### 5.1 Workbook scope

The first implementation exports one workbook for the entire current Confirmed
Need batch, not the visible filtered subset. It has exactly one primary operator
sheet, `Xác nhận nhu cầu`, plus one hidden metadata sheet, `_ATLAS_META`.

The export loader may page through the existing RMVP-05 read at up to 250 lines
per request. Every page must report the same batch ID and version. Before
download, the client must prove the assembled set has the advertised total,
contains no duplicate stable line ID, and has no gap. A version change or shape
drift during paged assembly aborts export and requests a refresh. Export performs
no business write.

### 5.2 Exact visible columns

The primary sheet contains these visible columns in this order:

| Column         | Classification              | Exact behavior                                          |
| -------------- | --------------------------- | ------------------------------------------------------- |
| `Ngày`         | READ-ONLY REFERENCE         | Service date                                            |
| `Trường`       | READ-ONLY REFERENCE         | Current School display name                             |
| `Điểm giao`    | READ-ONLY REFERENCE         | Current Delivery Location display name                  |
| `Nguyên liệu`  | READ-ONLY REFERENCE         | Current Ingredient display name                         |
| `ĐVT`          | READ-ONLY REFERENCE         | Controlled Unit code/name presentation                  |
| `SL lý thuyết` | READ-ONLY REFERENCE         | Exact theoretical quantity                              |
| `SL đề xuất`   | READ-ONLY REFERENCE         | Exact proposed confirmed quantity                       |
| `SL xác nhận`  | **OPERATOR EDITABLE**       | Current local confirmed quantity draft                  |
| `Chênh lệch`   | READ-ONLY DERIVED REFERENCE | `SL xác nhận − SL đề xuất`; never imported as authority |
| `Lý do`        | **OPERATOR EDITABLE**       | Vietnamese controlled label, never technical code       |
| `Ghi chú`      | **OPERATOR EDITABLE**       | Governed explanation/correction note                    |

Names, dates, Units, ingredients and locations are never editable business
input. The exporter may use cell protection or styling as guidance, but import
security must not depend on Excel protection.

`Chênh lệch` is a presentation value. A writer may emit a formula if available,
but formula support is not an MVP dependency requirement. The importer always
recalculates the signed difference from parsed exact quantities and never trusts
the workbook cell.

For an unreviewed line, `SL xác nhận` starts from `SL đề xuất` and `Lý do` may
remain blank so import can apply the same local default as direct editing. For a
previously decided line, export the current authoritative confirmed quantity,
Vietnamese reason label and current note. Prior history remains in Atlas rather
than being expanded into workbook columns.

### 5.3 Hidden machine identity

Use the smallest deterministic combination:

**Hidden technical columns on `Xác nhận nhu cầu`, one set per data row:**

| Hidden key                 | Purpose                                                               |
| -------------------------- | --------------------------------------------------------------------- |
| `__confirmed_need_line_id` | Stable row identity and deterministic mapping                         |
| `__current_revision_id`    | Detect a changed current quantity revision                            |
| `__current_decision_id`    | Detect a changed current decision; blank represents the exported null |

**Hidden `_ATLAS_META` sheet, one workbook-level value per key:**

| Metadata key                                           | Purpose                                                       |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| `workbook_contract_version` = `CONFIRMED_NEED_XLSX.v1` | Closed template/parser contract                               |
| `confirmed_need_batch_id`                              | Exact exported aggregate identity                             |
| `batch_version`                                        | Whole-batch stale protection                                  |
| `exported_at`                                          | Operator/support evidence only; not an authority or match key |

`current_revision_id` and `current_decision_id` are per-line values and therefore
do not belong only on the metadata sheet. Repeating batch identity/version on
every row is unnecessary. A School name + Ingredient name + date tuple is never
a match key.

## 6. Import contract

### 6.1 Import is every-and-only

The first implementation accepts exactly the current batch exported by Atlas:

```text
same workbook contract
→ same batch identity and version
→ every current stable line exactly once
→ no duplicate identity
→ no unknown identity
→ no missing identity
```

Deleting a row is an error, not a zero quantity. A zero quantity must be written
explicitly in `SL xác nhận`. Adding or duplicating a row is an error. Filtered or
partial workbooks are not accepted in the MVP.

### 6.2 Local parsing and minimum input checks

Import performs only the input checks needed to create the same draft accepted
from direct editing:

- required workbook/sheet/header/metadata shape;
- supported workbook contract version;
- exact batch, line, revision and decision identity checks;
- every-and-only row-set checks;
- unchanged read-only reference values, except `Chênh lệch`, which is ignored
  and recalculated;
- `SL xác nhận` is present and normalizes unambiguously to a finite nonnegative
  decimal with at most fourteen integer and six fractional digits;
- a comma may be normalized to the decimal point only when the text is
  otherwise unambiguous; thousands separators are not inferred;
- no rounding, ceiling, tick alignment, policy selection or corrected quantity
  calculation occurs in the browser; and
- reason/note consistency follows the same local rules as direct editing.

If an Excel numeric cell cannot be converted to an unambiguous accepted exact
decimal string, reject that row and ask the operator to correct the cell. The
authoritative RMVP-05 preview remains responsible for exact Planning-step,
policy, Unit, source-membership and current-evidence validation.

### 6.3 Reason and note mapping

The workbook and normal UI show Vietnamese labels while retaining the existing
backend code vocabulary:

| Vietnamese label             | Existing backend code             | Note rule                                                                                       |
| ---------------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------- |
| `Chấp nhận đề xuất`          | `PROPOSAL_ACCEPTED`               | First unchanged acceptance has no note; a replacement decision still requires a correction note |
| `Điều chỉnh theo bước lượng` | `PLANNING_STEP_ADJUSTMENT`        | No note for a first decision; correction/replacement still requires a note                      |
| `Điều chỉnh vận hành`        | `OPERATIONAL_QUANTITY_ADJUSTMENT` | Note required                                                                                   |
| `Lý do khác`                 | `OTHER`                           | Note required                                                                                   |

For a previously unreviewed line with a blank workbook reason, import uses the
same defaults already offered by direct Atlas editing:

- quantity equals proposal → `PROPOSAL_ACCEPTED`;
- quantity differs from proposal → `PLANNING_STEP_ADJUSTMENT`.

This does not invent a new reason. It reproduces the current direct-edit
`Chấp nhận đề xuất` / `Điều chỉnh số lượng` default. An explicit contradictory
label is an error rather than being silently replaced. A prior decision is a
correction boundary: import retains the exported/current reason unless the
operator changes it, and any replacement requires a nonblank correction note.

Spreadsheet dropdown validation for the four labels is optional. It must not
drive the writer-library choice or become the only validation.

### 6.4 Import review

After parsing, show:

```text
Đã đọc file Excel

Tổng số dòng
Dòng thay đổi
Dòng không thay đổi
Dòng lỗi
```

Each error must identify the worksheet row, the recognizable School/Ingredient
context when safe, the affected field and an actionable Vietnamese message.
For valid changed rows, show at least prior/current draft quantity → imported
quantity, signed difference from proposal, Vietnamese reason and whether a note
is required. This is a local comparison, not an authoritative backend preview.

Any structural, identity or invalid-value error disables `Áp dụng vào bảng`.
There is no partial apply. Do not silently skip invalid, unmatched or
out-of-scope rows.

### 6.5 Meaning of `Áp dụng vào bảng`

`Áp dụng vào bảng` does exactly this:

```text
accepted parsed candidate
→ replace editable fields in the shared local Confirmed Need draft
→ mark affected rows dirty/selected as appropriate
→ invalidate any earlier backend preview
→ return to the normal table
```

It performs zero backend mutation, creates no receipt/event/audit row, uploads
no file and persists no workbook. Import review must be invalidated if the local
draft changes after parsing and before apply; the operator must review the file
again rather than applying a summary calculated against an old draft.

## 7. Stale state and uncertain outcomes

### 7.1 Stale workbook at import

Before allowing apply, compare hidden metadata and every hidden row binding with
a freshly assembled, unfiltered authoritative current-batch read.

Reject the entire workbook when any of these is true:

- unsupported or malformed workbook contract;
- wrong or missing batch ID;
- workbook `batch_version` differs from current batch version;
- any line's current revision or current decision differs;
- missing, duplicate or unknown stable line identity;
- missing/renamed required columns, malformed metadata or unexpected data row;
- changed read-only reference value;
- blank, malformed, negative, nonfinite or over-precision confirmed quantity;
- invalid/contradictory reason or missing required note; or
- any other row error.

The first MVP rejects the whole workbook, not only affected rows. It preserves
the existing local draft and shows:

> File Excel được xuất từ phiên bản dữ liệu cũ. Hãy tải lại và xuất file mới.

Use more specific actionable messages for non-staleness shape/value errors.

### 7.2 Atlas changes after import but before commitment

Import and apply are local, so later authoritative change is still caught by the
existing RMVP-05 expected batch version, expected revision/decision IDs and
preview hash. RMVP-06/07 continue to enforce expected version and current fact
bindings at their own boundaries.

On a stale response:

- never retry a write automatically;
- do not claim that imported changes were committed;
- preserve local entered values where practical, mark them stale and prevent a
  new commitment until authoritative refresh/reconciliation;
- discard late previews/readbacks after newer draft intent; and
- require refresh and explicit operator review, re-export/re-import, or manual
  reconciliation before a new command.

A transport-uncertain mutation keeps the exact existing explicit-retry behavior
for RMVP-05 and the refresh-before-new-command behavior for RMVP-06/07. Local
Excel import itself is never uncertain because it writes nothing.

Dirty local draft, unapplied import review and uncertain-command state should
trigger in-application navigation protection and the practical browser reload /
close warning. Do not persist the workbook merely to implement that warning.

## 8. Lifecycle classification and target presentation

| Current step/action                              | Class                                                             | Human judgment                                                              | Target normal presentation                                                                                 | Existing contract sufficiency                                                                                                                                                           |
| ------------------------------------------------ | ----------------------------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Direct line editing                              | A — Local editing productivity                                    | Prepare a proposed decision                                                 | Main table, immediately editable when backend permits                                                      | Sufficient                                                                                                                                                                              |
| `Xuất Excel` / `Nhập Excel` / `Áp dụng vào bảng` | A — Local editing productivity                                    | Choose a faster editing surface and accept its local changes                | Secondary controls on the same workbench                                                                   | No backend contract needed                                                                                                                                                              |
| `Xem trước xác nhận`                             | D — Deterministic system validation, write-free                   | Review consequences; no separate business commitment                        | Integrate into the `Xác nhận số lượng` review interaction rather than a competing primary lifecycle button | RMVP-05 preview is sufficient                                                                                                                                                           |
| `Xác nhận số lượng`                              | B — Human quantity decision                                       | Accept unchanged proposals and/or adjusted quantities with governed reasons | Primary while the local draft has decisions to commit                                                      | RMVP-05 confirm is sufficient and atomic for each selected set                                                                                                                          |
| `Kiểm tra toàn bộ`                               | C — Human completion declaration with D as its system consequence | “I have finished reviewing this batch.”                                     | Rename to `Hoàn tất xác nhận`; backend validation runs because of this action                              | RMVP-06 is sufficient; it records the invoking human Actor/time, validates the complete batch atomically, freezes editing on success and retains blockers on a governed blocked outcome |
| `Phê duyệt lô nhu cầu`                           | E — Human approval/business commitment                            | Accept the exact completed, successfully validated fact set                 | Separate primary action only in `VALIDATED` when backend-authorized                                        | RMVP-07 is sufficient                                                                                                                                                                   |
| `Phát hành sang bước lên đơn`                    | F — Release/downstream handoff commitment                         | Authorize the exact approval for later Purchase Handoff consumption         | Separate primary action only in `APPROVED` when backend-authorized                                         | RMVP-07 is sufficient                                                                                                                                                                   |
| Refresh, exact retry, stale recovery             | G — Exception/recovery                                            | Reconcile an uncertain or outdated view                                     | Contextual only when required                                                                              | Existing safety contracts are sufficient                                                                                                                                                |

### 8.1 Validate recommendation

`Validate` remains an operator-visible action, but not under the technical label
`Kiểm tra toàn bộ`. Present it as `Hoàn tất xác nhận`.

This is truthful without a contract correction. The human meaning is the
completion declaration “I have finished reviewing this batch.” RMVP-06 requires
an authenticated active human Actor with its exact capability, records that
Actor and time in immutable attempt/event/audit evidence, evaluates the complete
batch and makes editing read-only only on successful `VALIDATED`. A `BLOCKED`
outcome leaves the working status/version unchanged and returns the exact issues
to correct. The system, not the operator, decides whether integrity passes.

The UI must not claim success before authoritative readback and must not imply
that the operator personally performed each deterministic check.

### 8.2 Approval recommendation

Approval remains a separate human action. The accepted current requirement is
D-031/RMVP-07: full-batch approval is explicitly separate from release, binds
the exact complete RMVP-06 success to an immutable every-and-only snapshot, and
requires the independent `confirmed_need_approval.approve` capability.

This is an accepted business commitment, not a conclusion drawn merely from an
existing button. The accepted contract does **not** require the confirmer,
approver and releaser to be different people, does not establish a management
role, and does not impose four-eyes approval. Do not describe or enforce those
requirements in the Application. A later accepted governance decision would be
needed to require distinct Actors.

### 8.3 Release recommendation

Release remains separate and is the genuine downstream handoff commitment. It
authorizes the exact approved batch for later Purchase Handoff consumption and
creates immutable release evidence. It does not create Purchase Handoff, select
a supplier, allocate fulfilment, create a purchase order, or mutate Procurement,
Warehouse or Dispatch.

The confirmation copy must retain that consequence explicitly.

## 9. One-next-action rules

The backend remains the source of eligibility. The Application chooses visual
priority from authoritative allowed actions and local draft state:

| Normal state                                                              | One dominant action                                                | Consequence                                                                                     |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `DRAFT_REVIEW` / `REOPENED`, dirty or uncommitted line decisions          | `Xác nhận số lượng`                                                | Opens/refreshes write-free authoritative preview, then commits only after explicit confirmation |
| `DRAFT_REVIEW` / `REOPENED`, all current lines decided and no dirty draft | `Hoàn tất xác nhận`                                                | Declares review complete; backend returns `VALIDATED` or exact blockers                         |
| Governed validation `BLOCKED`                                             | Correct the highlighted rows, then `Hoàn tất xác nhận`             | No false completion; prior attempt remains evidence                                             |
| `VALIDATED`                                                               | `Phê duyệt lô nhu cầu`                                             | Creates exact immutable approval snapshot                                                       |
| `APPROVED`                                                                | `Phát hành sang bước lên đơn`                                      | Authorizes later Purchase Handoff consumption                                                   |
| `RELEASED_FOR_PURCHASE_HANDOFF`                                           | No further normal action                                           | Show released consequence and subordinate history                                               |
| Stale or unknown write outcome                                            | `Làm mới dữ liệu` or the existing exact retry when explicitly safe | Re-establish authoritative state before any new intent                                          |

Future commands are not shown as disabled teaching controls. When the Actor
lacks the current required capability, show the safe backend explanation rather
than promoting another action.

RMVP-05 currently accepts 1–250 selected lines per preview/confirmation command.
The workbook still covers the entire batch. If more than 250 decisions are
dirty, the UI must present explicit successive selected-set confirmations using
the same `Xác nhận số lượng` command and show remaining progress; it must not
hide multiple writes behind a single fake atomic save. Typical batches at or
below the limit use one confirmation. This is a bounded command-size constraint,
not a second Excel write path.

## 10. Atomicity conclusion

Do not implement browser command chaining such as:

```text
Confirm → Validate → Approve → Release
```

behind one button. Each existing write is already atomic at its truthful human
boundary:

- RMVP-05 commits selected quantity decisions;
- RMVP-06 records completion-triggered complete-batch validation;
- RMVP-07 approval accepts the validated fact set; and
- RMVP-07 release authorizes the approval for later handoff.

Preview is write-free and may be integrated into the confirmation interaction.
Import/apply is local and may precede that same interaction. No new atomic
backend contract is required, so `CONFIRMED-NEED-CONTRACT-01` is not created.

## 11. XLSX dependency conclusion

The installed `read-excel-file` dependency can parse browser-provided XLSX
workbooks, including all sheets and typed string/number/date cells. It is a
reader only and cannot create the required export workbook.

`UI-QUALITY-02C-B` therefore requires root review of exactly one narrowly scoped
XLSX writer dependency. Selection occurs in that implementation task, not here.
The minimum writer capability is:

- create and download an `.xlsx` workbook in the browser;
- create the operator and metadata sheets;
- write strings and numbers without silently rounding accepted draft text;
- set basic widths and number/date formats;
- hide technical columns and the metadata sheet; and
- optionally apply modest protection/style/freeze panes.

Formulas, macros, pivot tables, charts, advanced styling, a generic spreadsheet
framework and Excel-dropdown support are not requirements. Do not select a
large spreadsheet framework merely for presentation.

## 12. Responsive behavior

XLSX work is desktop-first. At 360 px:

- preserve period, current state, attention and the one next action;
- allow `Xuất Excel` and `Nhập Excel` to wrap or move into a subordinate actions
  area;
- use the existing bounded horizontal table scroll rather than page overflow;
- keep import errors readable in a stacked review panel; and
- do not redesign the quantity workflow as cards.

No special mobile file-editing experience is required.

## 13. UI-QUALITY-02C-B implementation boundary

### Objective

Implement the workflow and XLSX contract in this handoff on the existing sixth
Planning Inputs Confirmed Need workbench, without changing backend authority.

### Expected Application scope

- reshape `ConfirmedNeedReviewWorkbench.tsx` to the table-first five-second
  layout and one-next-action rules;
- retain one canonical local draft for direct and imported edits;
- add a bounded Confirmed Need workbook export/import module and focused tests;
- use existing RMVP-05 paged reads to assemble and verify the entire batch;
- use existing RMVP-05 preview/confirm and RMVP-06/07 commands unchanged;
- add import review, full rejection, stale handling and dirty-navigation guards;
- add the minimum responsive styling; and
- add exactly one writer dependency only after root review.

Expected paths should remain within the existing Confirmed Need submodule and
its focused tests, the narrow shared stylesheet if necessary, `package.json`,
`pnpm-lock.yaml`, this handoff/roadmap if implementation evidence requires an
update, and existing integration registration only when technically necessary.
The implementation task must freeze its exact path manifest before editing.

### Required tests

At minimum prove:

- exact full-batch export, stable ordering, visible/hidden columns and metadata;
- paged-read version drift aborts export;
- direct edit and import produce the same local draft/request shape;
- every-and-only row enforcement and whole-workbook rejection;
- stale batch, revision and decision rejection preserves the prior draft;
- deleted, duplicate, unknown and missing rows never become zero or partial
  apply;
- exact decimal parsing, explicit zero, malformed values and no browser
  rounding;
- Vietnamese reason mapping, defaults and governed note requirements;
- import review counts/errors and zero-write `Áp dụng vào bảng`;
- prior preview invalidation after edit/import;
- authoritative stale/unknown-outcome behavior remains intact;
- lifecycle labels, one-next-action visibility and release consequence;
- no import RPC/upload/backend mutation; and
- 360 px has no page-level overflow and retains state/next action.

### Prohibited in UI-QUALITY-02C-B

- SQL, migrations, API/RPC contract changes, lifecycle or capability changes;
- `Excel Save`, `Bulk Save`, `Import Save` or any second business write path;
- browser chaining of RMVP-05/06/07 writes;
- backend-authoritative quantity calculation in React;
- persistence or upload of the workbook;
- filtered-subset or partial import semantics;
- partial application of valid rows from an invalid workbook;
- new spreadsheet aggregate/domain object;
- supplier, PO, Purchase Handoff, Procurement, Warehouse or Dispatch mutation;
- Retool/OPS v1/v2 mutation, hosted deployment or production binding; and
- CMD-03 or `PLANNING-UX-01` work.

## 14. Acceptance answers

1. **Human job:** review every current line, accept or adjust the proposed
   confirmed quantity with governed reason/note, declare the batch complete,
   approve it and release it for later Purchase Handoff consumption.
2. **Happy path:** generation → direct edit or XLSX round-trip → shared draft →
   RMVP-05 preview/confirmation → `Hoàn tất xác nhận` → approval → release.
3. **Visible columns:** exactly `Ngày`, `Trường`, `Điểm giao`, `Nguyên liệu`,
   `ĐVT`, `SL lý thuyết`, `SL đề xuất`, `SL xác nhận`, `Chênh lệch`, `Lý do`,
   `Ghi chú`.
4. **Editable fields:** only `SL xác nhận`, `Lý do`, and `Ghi chú`.
5. **Machine identity:** batch ID/version and workbook version/export time in a
   hidden metadata sheet; stable line/current revision/current decision IDs in
   hidden per-row columns.
6. **Initial import:** every-and-only the current batch.
7. **Whole rejection:** any contract, batch/version, identity/set, structure,
   reference, value or reason/note error.
8. **Backend write on import:** never.
9. **`Áp dụng vào bảng`:** update the shared local draft only and invalidate
   prior preview.
10. **Differences:** signed confirmed-minus-proposed difference in workbook/UI
    and explicit before → after rows in import review.
11. **Reasons:** the four Vietnamese labels map to unchanged existing codes.
12. **Stale workbook:** reject all, preserve current draft, request new export.
13. **Atlas changes after import:** existing expected-version/binding/hash guards
    reject commitment; preserve/mark local work stale and require refresh and
    explicit reconciliation.
14. **Validate visible:** yes, renamed `Hoàn tất xác nhận`.
15. **Validate human meaning:** “I have finished reviewing this batch”; the
    backend performs deterministic integrity validation as the consequence.
16. **Approval separate:** yes.
17. **Approval justification:** accepted D-031/RMVP-07 exact full-batch approval
    snapshot and independent approval capability; no distinct-Actor requirement.
18. **Release separate:** yes, as the authorization for later Purchase Handoff
    consumption.
19. **One next action:** quantity confirmation in dirty Draft, completion in
    clean Draft, approval in Validated, release in Approved, none after Released,
    refresh/recovery only when exceptional.
20. **Backend sufficient:** yes; Outcome A.
21. **Writer dependency:** yes, one narrow writer is required because the
    installed package reads but does not write XLSX.
22. **Next task:** `UI-QUALITY-02C-B — Implement Confirmed Need workflow and
XLSX round-trip`; no backend prerequisite.
