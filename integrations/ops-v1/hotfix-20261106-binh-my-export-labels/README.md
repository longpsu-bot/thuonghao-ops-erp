# OPS v1 Bình Mỹ PO / Dispatch label hotfix

Applied to the six Retool query texts in production/main/Latest on 6 November 2026. No Supabase schema or business-data writes were performed.

School 8 is Bình Mỹ Bình Dương; School 9 is Bình Mỹ Củ Chi. Their current master
`name` fields use the newer administrative qualifiers `(P. BÌNH CƠ)` and
`(X. BÌNH MỸ)`, but both `school_full_name` fields contain the same name. The
grouped PO and Dispatch export queries prefer that ambiguous full name, causing
the reported printed output. The hotfix labels only these two exact identities:

- `TIỂU HỌC BÌNH MỸ - BÌNH DƯƠNG`
- `TIỂU HỌC BÌNH MỸ - CỦ CHI`

Normal Dispatch retains its existing `TRƯỜNG` prefix. Existing configured Dispatch
group names still take precedence over the School fallback. IDs, calculations,
quantities, Units, notes, School order, group membership, representative header
IDs, date/School filters, confirmation commands and stored documents are unchanged.
Master names and Atlas are untouched. Staff must reload Retool and export again;
previously downloaded Excel/PDF files keep their old contents.

## Exact scope and source guard

Retool app `eee6beba-176a-11f1-bbee-4b1ba5ff10c1`, page `PurchasePlanner`:

1. `q_po_grouped_school_breakdown_from_po`
2. `q_po_grouped_supplier_agg_from_po`
3. `q_po_grouped_ingredient_breakdown_from_po`
4. `q_dispatch_lines_grouped`
5. `q_dispatch_lines`
6. `q_po_school_breakdown_from_po`

`before.json` retains the exact six query texts copied from the actual Retool
editor. `patch.mjs` generates `after.json`; these are SELECT texts to paste into
Retool, not migrations to execute against Supabase.

Before each Retool replacement, the whole current source was copied and compared
with the corresponding retained source. After Save, the whole source was copied
again and compared with the reviewed patched source. All six exact readbacks
matched. Only eight SQL source lines differ, all export-label expressions.

To regenerate and check the guarded apply/rollback mapping:

```powershell
node integrations/ops-v1/hotfix-20261106-binh-my-export-labels/patch.mjs
```

Consumers of `guardedReplacement(name, current, rollback)` must stop on
`OPS_V1_LABEL_SOURCE_MISMATCH`; do not replace a query somebody else has changed.
For rollback, pass `true` only while current source equals the exact patched text,
then paste the returned original text into that same query and Save. This does
not delete or recalculate any stored document or undo unrelated Retool changes.

## Verification

`regression.mjs` emits JSON containing twelve read-only SQL probes. It binds the
actual retained/patched SELECTs to 2–6 November 2026, comparing all output facts
and unrelated labels, retaining duplicate rows and row order. Dispatch is tested
with no School filter, School 8, School 9 and both. Grouped target detection uses
both entity type and ID, so a group ID cannot masquerade as a School.

```powershell
node integrations/ops-v1/hotfix-20261106-binh-my-export-labels/regression.mjs --baseline
node integrations/ops-v1/hotfix-20261106-binh-my-export-labels/regression.mjs
```

Execute emitted `sql` values through the existing authorized read-only v1 SQL
connection. Successful candidate results require `labels_pass` and `order_pass`
true, and both delta counts zero. `verification.json` records the twelve results.
All target rows must contain the expected label; presence alone is insufficient.
Four retained-source probes were observed failing the expected labels first.

Independent source review found no blocking issue. Six exact apply/rollback
round trips and 39 drift/unknown-query rejection cases passed. The reviewed
probe qualification correction also passed all twelve real-data comparisons.

Fresh Retool user-mode checks exported existing 6 November documents, without
clicking either confirmation/create-document button:

- PO PDF detail by School contains both complete locality labels. Two actual
  rendered pages were visually inspected and the labels are legible and unclipped.
- Grouped Dispatch Excel exported two separate workbooks whose filenames and
  actual shared-string contents contain the respective complete locality labels.
- PO Excel in `Tất cả` mode contains both locality labels in the actual workbook
  contents for the School and Ingredient breakdowns.

Retool's Releases and History panel reports zero releases and states that the
current live version is visible to all users. No separate release publication
is required for this app.

Raw operational exports and rendered images remain outside Git in this chat's
local artifact directory. Routine Frontend CI runs on the audit PR; full local
frontend or Atlas database certification is not relevant to this query-text patch.
