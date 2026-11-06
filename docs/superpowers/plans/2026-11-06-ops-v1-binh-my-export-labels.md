# OPS v1 Bình Mỹ export label hotfix

**Authorization:** Owner, 6 November 2026: use the D: checkout, branch from latest
`origin/main`, preserve the previous branch, inspect live v1 Supabase and Retool,
and fix PO/Dispatch labels. This is a v1 presentation hotfix, outside Atlas.

**Baseline:** `f4aeeebfaecba04ca4dfaf8f7db8cc16e6ee1c9f`.
Branch: `codex/ops-v1-binh-my-document-labels`.

**Goal:** Printed/exported PO and Dispatch distinguish School 8 as
`TIỂU HỌC BÌNH MỸ - BÌNH DƯƠNG` and School 9 as
`TIỂU HỌC BÌNH MỸ - CỦ CHI`, in grouped and normal modes.

**Evidence:** Live project `qnthofvccilhnefdcxnz` has distinct School IDs 8/9,
but both `school_full_name` values are `TRƯỜNG TIỂU HỌC BÌNH MỸ`.
Retool's three grouped PO queries prefer that value after removing `TRƯỜNG`.
Grouped Dispatch does the same for its two export-name fields; normal Dispatch
uses the full-name field. The two literal expected-label checks failed before
the fix. Current School names/addresses and prior v1-ID reconciliation confirm
8 = Bình Dương and 9 = Củ Chi.

**Scope:** Six SELECT query texts in the live `PurchasePlanner` page of Retool
app `eee6beba-176a-11f1-bbee-4b1ba5ff10c1`, plus the retained source, guarded patch,
read-only regression generator and evidence under
`integrations/ops-v1/hotfix-20261106-binh-my-export-labels/`.

**Prohibited:** Supabase writes/schema migrations, master-name edits, confirmation
commands, quantity/Unit/note changes, entity identity/group membership/representative
header changes, permissions, dependencies, Atlas changes and supplier communication.
Existing configured Dispatch group labels keep their precedence.

- [x] Verify the authorized checkout, preserve the old branch and create the new branch.
- [x] Inspect live v1 data and actual Retool query sources; reproduce ambiguous labels.
- [x] Retain all six exact query sources for rollback.
- [x] Add only ID-scoped export labels; reject source drift before replacement.
- [x] Run the actual before/after SELECTs read-only, comparing every non-label
      field and every unrelated School label, including Dispatch School filters.
- [x] Independently review the bounded patch before changing Retool.
- [x] Apply the reviewed query texts, read them back, and verify real exports.

Publication and the required Frontend CI result are tracked on the audit PR.

**Rollback:** Replace only a query still equal to its retained patched source
with its exact `before.json` text. Stop on source drift. Neither application nor
rollback edits saved documents or database facts. Previously downloaded files
remain unchanged; staff must export again to obtain corrected labels.

**Delivery:** All six query texts were saved and matched exact readback. Fresh
user-mode exports of existing 6 November documents contain the two complete
labels in PO PDF and both PO/Dispatch Excel. Two actual PO PDF pages were rendered
and visually checked. Retool reports zero releases and explicitly confirms the
current live version is visible to all users. No database/master/document writes
or creation/confirmation commands were performed. See the hotfix README and
`verification.json` for source-qualified evidence.
