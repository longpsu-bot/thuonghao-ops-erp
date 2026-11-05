# Attendance XLSX operator access

The Owner-approved [v1 parity closeout](../superpowers/specs/2026-11-05-atlas-v1-parity-closeout.md)
exposes the existing Attendance workbook parser in the Atlas Sĩ số workbench.
This amendment supersedes earlier statements that Attendance XLSX operator
import is deferred. It changes frontend access only; the
[Planning Inputs contract](rmvp-03a-planning-inputs.md), BR-037–039 and
consequential Save remain authoritative.

## Operator flow

1. Select the intended week and open Sĩ số. Download `Tải mẫu sĩ số XLSX`
   or use a compatible workbook containing School, service date, student and
   teacher counts. The existing parser recognizes `Tên trường` or `Mã trường`
   (`school_code`), `Ngày` (`service_date`), `Số suất học sinh` / `Sĩ số học sinh`
   and `Số suất giáo viên` / `Sĩ số giáo viên`.
2. Select a nonempty `.xlsx` file in `Nhập sĩ số XLSX`. School codes resolve
   uniquely against the current workbench catalog; an explicitly coded column
   never falls back to names. Every date must be a real date within the selected
   week. Counts must be nonnegative safe integers. Explicit zero is retained;
   blank counts are rejected. Malformed/empty files, unresolved Schools and
   invalid rows leave the existing working rows intact.
3. A valid import replaces **the whole week's local draft**, regardless of the
   visible School/day filters. It preserves the parser's file/sheet/row source
   references and records the file/sheet as the source name. It does not persist
   data. The chooser is unavailable while there are unsaved changes: Save or
   explicitly discard them through the existing navigation guard first.
4. Choose `Xem thay đổi`. The existing backend Preview canonicalizes rows,
   returns the authoritative checksum and issues, and reviews correction impact.
   Review all omissions as well as changed rows. Choose `Lưu` explicitly to run
   the existing atomic consequential Save with its expected version and canonical
   checksum. No browser checksum becomes write authority.

The existing stale-authority, read-failure, UNKNOWN/missing-readback, concurrency
and downstream correction guards remain in force. A late file read cannot
replace changes made during parsing or rows belonging to another week, owner,
auth session or authority generation. There is no new persistence command,
capability, database migration or dependency. Rollback reverts the frontend
change; persisted Attendance and immutable approval history remain intact.

## Daily Shopping List access

Multi-day operator access already exists in the Confirmed Need date surface
(PR #367). It projects independently authoritative daily contexts and preserves
each day's draft/import identity. This task adds no range root, combined
quantities, bulk commitment or duplicate range navigation. Existing daily Save,
release and XLSX fingerprints remain unchanged.

## Verification and remaining visual check

`attendanceWorkbookImport.test.tsx` renders the real Chakra workbench with a real
XLSX built by the installed ExcelJS library, decoded by the installed browser
reader and existing Attendance parser, and fixture backend contracts. Boundary
cases use deterministic decoded sheets or reader failures. It verifies file selection,
zero/source evidence, canonical Preview and explicit Save separately, rejected
files/rows, dirty protection, recovery locks and late-result cancellation.
Existing parser/hook/workbench regressions cover the surrounding contracts.

Before visual signoff, use a permitted fixture environment at 375px and 1440px:
download the template, fill one complete School/date row (including zero),
remove unused blank-count rows, select it, and inspect the chooser, explanatory
text, table and Review/Save controls for clipping and keyboard focus. Verify an
unknown School, wrong week and malformed workbook preserve visible working
values. Make an unsaved edit and verify the chooser is disabled. Review the
whole-week omission list before any authorized Save. No hosted write or actual
staff acceptance is established by the automated fixture tests.
