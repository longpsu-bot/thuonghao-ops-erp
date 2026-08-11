# TASK-UI-QUALITY-02C — Confirmed Need Workflow Correction

## Status and outcome

**Correction:** D-037 and the Product Owner correction for draft PR #189
supersede the earlier UI-QUALITY-02C-A/02C-B assumptions below wherever they
conflict. The earlier material is retained only as historical review evidence.

The corrected implementation adds `RMVP-05.v2` Save and `RMVP-07.v2` Release,
keeps v1 APIs callable, and presents exactly `Lưu` and `Chuyển sang lên đơn` as
normal human write actions. React performs no RMVP-05 → RMVP-06 or RMVP-07
approve → release chaining.

The Confirmed Need XLSX round-trip, workbook schema, hidden metadata, parser,
writer, and tests are removed. `Xuất Excel` and `Xuất PDF` are disabled
placeholders until the workbench read model and final export contract are
approved. `write-excel-file` is removed; `read-excel-file` remains because
merged Planning and Recipe features still use it. `@mantine/dates` and `dayjs`
remain for the Vietnamese service-week date picker.

Corrected normal flow:

```text
Edit → Lưu → continue working if needed → Chuyển sang lên đơn
```

The workbench prominently shows the service week, School scope, total row count,
saved/unsaved/released state, text search, structured School/date filters,
editable confirmed quantity, concise reasons, and one dominant action. Batch
IDs, versions, fingerprints, capability codes and API names are not normal UI.

Exact-head follow-up correction: Save and Release availability now comes from backend-derived `allowed_actions` with safe disabled reasons. React may only apply stricter local gates. Full Integration separately runs the unchanged v1 compatibility journey and a fresh D-037 fixture so their lifecycle mutations cannot contaminate each other.

### Superseded first-time operator notes from the original PR #189 draft

The implemented presentation is governed by a first-time Planning employee,
not by knowledge of internal architecture:

- `Xác nhận nhu cầu` resolves the current Confirmed Need automatically from
  Planning preflight `current_need` for the selected service week. Normal UI
  never asks for a batch ID or exposes an editable technical identifier.
- Week, school and optional service date are the primary working context. The
  school/date controls filter only the on-screen review; XLSX export continues
  to cover the authoritative whole batch.
- Unchanged quantities display `Chấp nhận đề xuất` without row-selection,
  reason and note controls. Adjustment fields appear when a quantity changes or
  when correction is required.
- `Xác nhận số lượng` obtains the write-free backend preview automatically.
  Blocking issues are shown as corrections. A successful check opens one simple
  final summary with `Xác nhận` and `Quay lại`; there is no preview
  acknowledgement checkbox and no chained write.
- Authentication and authorization remain backend-enforced. The normal flow
  adds no human authentication step and displays only a plain access-denied
  message when access is actually rejected.

The remaining human-visible lifecycle steps are intentionally still distinct:
`Xác nhận số lượng` → `Hoàn tất xác nhận` → `Phê duyệt` → `Phát hành`.
Any consolidation of those backend commitments is a separate contract decision,
not React command chaining.

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

`Chênh lệch` is a presentation value. Import never trusts that cell. Its display
may be derived from canonical exact quantities without requiring the writer to
emit a formula. Formula support is not an MVP dependency requirement and no
formula result becomes business authority.

For an unreviewed line, `SL xác nhận` starts from `SL đề xuất` and `Lý do` may
remain blank so import can apply the same local default as direct editing. For a
previously decided line, export the current authoritative confirmed quantity,
Vietnamese reason label and current note. Prior history remains in Atlas rather
than being expanded into workbook columns.

### 5.3 Exact-decimal export rule

Every exported quantity starts from the canonical exact decimal string held by
the authoritative readback or shared local draft. The selected writer must
round-trip every accepted Atlas quantity without forcing it through an
imprecise JavaScript `number`.

For quantity cells, implementation may either:

- serialize the canonical decimal safely as text; or
- use a writer-native exact numeric representation after proving exact
  round-trip for the accepted Atlas quantity domain.

It must not use this path when conversion can alter the value:

```text
canonical decimal string
→ Number(...)
→ XLSX numeric cell
```

Excel number formatting, formulas and styling are subordinate to exact
round-trip correctness. This rule applies to `SL lý thuyết`, `SL đề xuất`, `SL
xác nhận` and any other quantity-bearing value written for later equality or
integrity checking.

### 5.4 Hidden machine identity

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

All quantity-bearing XLSX numeric cells must be captured as their source decimal
text before JavaScript floating-point conversion. Configure the installed
`read-excel-file` reader with its `parseNumber` option, or an equivalent exact
mode, so the parser returns the numeric cell XML value as an exact decimal
string rather than a JavaScript `number`.

The required path is:

```text
XLSX numeric source
→ exact source decimal string
→ Atlas local exact-decimal parser/normalizer
→ shared local Confirmed Need draft
```

The prohibited path is:

```text
XLSX numeric source
→ JavaScript Number
→ string
```

This requirement covers `SL lý thuyết`, `SL đề xuất`, `SL xác nhận` and any
other quantity-bearing numeric value used for equality or integrity checking.
Atlas must capture exact text before comparing a read-only workbook quantity
with authoritative readback or normalizing an editable quantity.

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

`SL xác nhận` is normalized and validated from the captured exact string. It may
be explicit zero, must be nonnegative, and may have at most fourteen integer and
six fractional digits. Atlas never rounds it in the browser. If the exact source
text cannot be normalized unambiguously under that contract, reject the row and
ask the operator to correct the cell.

The existing reader's numeric parser configuration provides the required exact
source string. Do not add `decimal.js` or another numeric dependency merely for
XLSX import. The authoritative RMVP-05 preview remains responsible for exact
Planning-step, policy, Unit, source-membership and current-evidence validation.

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

The release confirmation and released-state consequence must retain that
boundary explicitly. Confirmed Need Release does not need to calculate, predict
or display the exact future rounded purchase quantity. It must, however, make
the operator-facing distinction explicit: `SL xác nhận` is not necessarily
`SL đặt mua`. The later Purchase Handoff determines and explains any purchase
quantization before purchase commitment.

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
workbooks, including all sheets and typed string/number/date cells. Its
`parseNumber` option can return source numeric XML values as exact decimal
strings before JavaScript `number` conversion, so it remains sufficient for the
import boundary without a second decimal/numeric dependency. It is a reader
only and cannot create the required export workbook.

`UI-QUALITY-02C-B` therefore requires root review of exactly one narrowly scoped
XLSX writer dependency. Selection occurs in that implementation task, not here.
The minimum writer capability is:

- create and download an `.xlsx` workbook in the browser;
- create the operator and metadata sheets;
- write accepted canonical decimal quantities as safe text or through a proven
  writer-native exact numeric representation without a lossy JavaScript
  `number` conversion;
- set basic widths and number/date formats;
- hide technical columns and the metadata sheet; and
- optionally apply modest protection/style/freeze panes.

Formulas, macros, pivot tables, charts, advanced styling, a generic spreadsheet
framework and Excel-dropdown support are not requirements. Do not select a
large spreadsheet framework merely for presentation.

## 12. Quantity-step authority and downstream purchase quantization

Retained PurchasePlanner evidence rounds imported Actual Needs upward to an
`order_step` before saving. UI-QUALITY-02C-B must not reproduce that legacy
arithmetic in the Confirmed Need browser.

Confirmed Need owns the Planning quantity decision and its accepted Planning
quantity policy. The UI and XLSX importer must:

- retain the operator's exact confirmed quantity;
- never round, ceil, truncate or normalize it to a purchase/order step;
- never implement `ceilToStepSafe()` or equivalent authoritative arithmetic;
- send the unchanged exact local draft through existing RMVP-05 preview and
  confirmation; and
- allow the backend effective Planning policy and `planning_step` to accept or
  reject the value.

The UI may display the backend-provided Planning step and explain a rejection,
but it must not calculate or substitute an authoritative corrected quantity.
For example, with Planning step `0.01 kg`, an entered `10.234 kg` remains
`10.234 kg`; Atlas does not silently change it to `10.24 kg`. The authoritative
preview may reject it as nonrepresentable.

The Confirmed Need workbench must expose the exact Planning-confirmed quantity
and, where useful for review or error explanation, the applicable
backend-provided Planning step. It must not present a purchase step, purchase
proposal or purchase-rounding difference as if Confirmed Need owned those
values.

Purchase/order-step rounding is a separate downstream requirement owned by
Purchase Handoff / Procurement. Preserving OPS v1 replacement capability still
requires a later accepted path with this behavior:

```text
Confirmed Need exact quantity
→ later Purchase Handoff
→ effective purchase step
→ upward purchase quantization
→ purchasable quantity
→ visible nonnegative rounding difference
```

For example, `10.23 kg` at purchase step `0.50 kg` proposes `10.50 kg` with a
visible `+0.27 kg` difference. Purchase quantization must never reduce the
proposal below Confirmed Need.

When that downstream boundary is implemented, the operator-facing Purchase
Handoff must visibly expose the complete transformation before any purchase
commitment:

```text
confirmed quantity
→ purchase step
→ rounded purchase proposal
→ rounding difference
```

The Purchase Handoff commitment review must show these four values side by side:

1. confirmed quantity;
2. effective purchase step;
3. rounded purchase proposal; and
4. signed rounding difference.

The effective step, before quantity, after quantity and signed difference must
be understandable together before the operator makes any purchase commitment.
No quantity transformation may be hidden in a backend command, client
calculation, exported document or derived read model. Backend authority does not
remove the requirement to explain its result to the operator.

PR #188 and UI-QUALITY-02C-B do not implement this downstream behavior, do not
move CMD-03 forward and must not claim complete replacement of v1 step rounding.
The requirement must remain preserved when CMD-03 / Purchase Handoff resumes.

## 13. Vietnamese date presentation and responsive behavior

### 13.1 Vietnamese calendar and date presentation

For every operator-facing calendar or date picker introduced or materially
touched by UI-QUALITY-02C-B:

- month names and weekday names are Vietnamese;
- Monday is the first day of the week for service-week/calendar contexts;
- visible business dates use `dd/MM/yyyy`, unless the existing surrounding
  Atlas surface consistently requires `dd-MM-yyyy`;
- API and business values remain local calendar ISO dates `YYYY-MM-DD`;
- service dates are never derived through UTC serialization or shifted across a
  UTC/local boundary; and
- the local-calendar week behavior already fixed in Planning remains intact.

Examples include `Thứ hai`, `Thứ ba`, `Chủ nhật`, `10/08/2026` and `Tháng 8 năm
2026`. Where Atlas controls the presentation, do not expose English calendar
chrome such as `Mon`, `Tue`, `August` or `Today`.

If browser-native `<input type="date">` cannot reliably guarantee Vietnamese
picker chrome across the supported browser environment, use the smallest
localized implementation practical within the already accepted UI stack. Do
not casually add a second date framework. If another date-picker dependency
appears necessary, stop and return the exact need for root review before adding
it. Backend date semantics, API shapes and service-period contracts remain
unchanged.

### 13.2 Responsive behavior

XLSX work is desktop-first. At 360 px:

- preserve period, current state, attention and the one next action;
- allow `Xuất Excel` and `Nhập Excel` to wrap or move into a subordinate actions
  area;
- use the existing bounded horizontal table scroll rather than page overflow;
- keep import errors readable in a stacked review panel; and
- do not redesign the quantity workflow as cards.

No special mobile file-editing experience is required.

## 14. UI-QUALITY-02C-B implementation boundary

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
- configure exact source-decimal XLSX parsing before JavaScript `number`
  conversion and preserve exact decimals during export;
- add import review, full rejection, stale handling and dirty-navigation guards;
- preserve Vietnamese local-calendar/date presentation and Monday-first service
  weeks for any date control introduced or materially touched;
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
- exact source-decimal parsing before JavaScript `number`, explicit zero,
  malformed values and no browser rounding;
- exact export/import round-trip at the accepted fourteen-integer/six-fraction
  boundary without `Number(...)` precision loss;
- Vietnamese reason mapping, defaults and governed note requirements;
- import review counts/errors and zero-write `Áp dụng vào bảng`;
- prior preview invalidation after edit/import;
- authoritative stale/unknown-outcome behavior remains intact;
- lifecycle labels, one-next-action visibility and release consequence;
- Vietnamese visible date formatting, Vietnamese rendered weekday/month names,
  Monday-first week behavior and no UTC/local service-date shift;
- no import RPC/upload/backend mutation; and
- 360/768/1280 layouts remain usable, with no page-level overflow at 360 px and
  state/next action retained.

### Prohibited in UI-QUALITY-02C-B

- SQL, migrations, API/RPC contract changes, lifecycle or capability changes;
- `Excel Save`, `Bulk Save`, `Import Save` or any second business write path;
- browser chaining of RMVP-05/06/07 writes;
- backend-authoritative quantity calculation in React;
- quantity conversion through JavaScript `number` before exact XLSX text is
  captured, or lossy canonical-string → `Number(...)` → XLSX export;
- `decimal.js` or another numeric dependency merely for XLSX import;
- Planning-browser purchase-step rounding, `ceilToStepSafe()` or an equivalent
  authoritative corrected-quantity calculation;
- persistence or upload of the workbook;
- filtered-subset or partial import semantics;
- partial application of valid rows from an invalid workbook;
- new spreadsheet aggregate/domain object;
- supplier, PO, Purchase Handoff, Procurement, Warehouse or Dispatch mutation;
- a new date framework without separate root review of a proven need;
- Retool/OPS v1/v2 mutation, hosted deployment or production binding; and
- CMD-03 or `PLANNING-UX-01` work.

## 15. Acceptance answers

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
    installed package reads but does not write XLSX; the writer must preserve
    exact decimal round-trip without lossy JavaScript `number` conversion.
22. **Next task:** `UI-QUALITY-02C-B — Implement Confirmed Need workflow and XLSX
round-trip`; no backend prerequisite.
23. **Exact numeric import:** every quantity-bearing numeric cell is captured as
    source decimal text through `parseNumber` or equivalent exact mode before
    JavaScript floating-point conversion.
24. **Dates:** Vietnamese operator presentation, Monday-first service weeks,
    local ISO business values and no UTC-derived service-date shifting.
25. **Step ownership:** Confirmed Need retains exact Planning quantities and
    backend Planning-step authority; later Purchase Handoff / Procurement owns
    upward purchase quantization and its visible nonnegative difference.
26. **Transformation visibility:** Confirmed Need Release does not predict the
    future purchase quantity, but states that `SL xác nhận` is not necessarily
    `SL đặt mua`; before any purchase commitment, later Purchase Handoff must
    show side by side the confirmed quantity, effective purchase step, rounded
    purchase proposal and signed rounding difference, with no invisible quantity
    transformation.
