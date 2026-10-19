# ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01

Authority: [Issue 400](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400),
[Owner decision](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389#issuecomment-6236671930),
and the explicit 19 October 2026 implementation brief. This authorizes only B2
and supersedes the inherited B1-only baton for this branch. No hosted writes,
merge, deployment, real supplier commitment, C, Dispatch or Warehouse changes.

Starting SHA: `689398e12f3911182862c76a964434c8776b6bec`.
Branch: `feat/atlas-b2-po-ingredient-code-optional`.
Draft base: `fix/atlas-ci-auth-01-test-boundary`; stop if an ancestor advances.

## Contract delta (before implementation)

| Boundary               | Existing behavior                                                                                            | Approved behavior                                                                                                     |
| ---------------------- | ------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| Ingredient Master Data | Nullable code; current Chakra editor already says optional internal code                                     | Preserve nullable Create/Edit, omission/update/null semantics and generated technical identity                        |
| Supplier Master Data   | Outward code required at PO release                                                                          | Unchanged                                                                                                             |
| PO release             | Missing Ingredient code blocks release                                                                       | Null Ingredient code permitted; required descriptive, Supplier and source facts still validated                       |
| Released snapshots     | Frozen Ingredient code/name/Unit and Supplier identity                                                       | Preserve every old snapshot; new Ingredient code may be null                                                          |
| PO read completeness   | Requires Ingredient code                                                                                     | Null code is not incomplete; required outward facts and nonnull corrupted historical evidence still fail closed       |
| PO XLSX/PDF            | Official XLSX item-code column already hidden; PDF already omits it; preliminary summary visibly contains it | Preserve official geometry and hidden historical facts; omit visible preliminary code and allocate its width to names |
| Historical official PO | Rebuilt from frozen revision facts                                                                           | Same renderer, ordering, dimensions, hidden values, metadata and original official number                             |

### Historical decision gate

At the starting SHA, both official XLSX sheet builders explicitly hide column B;
the PDF has no item-code column. Existing presentation tests verify both facts.
Therefore new official documents already have the approved visible columns.
Retain the hidden column as compatibility evidence, allowing null for new lines.
Keep `_ATLAS_META`, `DOCUMENT`, `ROW_SOURCE` and all source identities unchanged.
Preliminary summary is not issued evidence and may remove its visible code column.
No historical evidence, document-version authority or commitment semantics need
to change. Compare historical worksheet models and PDF definitions before/after.

### Exact backend amendment and dependencies

One new forward-only migration amends these existing functions in place:

- `atlas_api.release_school_catering_purchase_order(jsonb)` —
  `atlas_procurement_command_runtime`; preserve migration 108 whole-PO scope,
  existing locks, source fingerprints, receipts, numbering and replacement rules.
- `atlas_core.freeze_school_catering_po_line_output()` —
  `atlas_procurement_command_runtime`; allow a null code while freezing exact
  name, Unit, supplier note and migration 101 School/cooking/location breakdown.
- `atlas_api.get_school_catering_purchase_orders(jsonb)` —
  `atlas_read_runtime`; keep the existing private v2 base and its authorization,
  currentness and exact source read. Remove only null Ingredient-code blockers.

Preserve owners, ACLs, empty search paths and forced RLS. No table, column,
public API, capability, lifecycle, generic version selector or data backfill.
Supplier-code validity remains unchanged. Nonnull invalid internal code evidence
remains a corruption error, distinct from missing Supplier identity.
Master-data Create/Edit commands and snapshot immutability guards are unchanged.
Normal and complete replacement release use the same amended command/trigger.

### Allowed frontend changes

`purchaseOrderExports.ts` accepts a nullable frozen Ingredient code; official
templates retain their existing hidden compatibility column and source metadata.
`generatedPurchaseReviewExport.ts` removes the preliminary summary code column;
detail has no code column already. Review adapter eligibility and operator errors
follow the Supplier/internal distinction. Inspect the model, current Procurement
components and Ingredient editor; change them only if they contradict this delta.
Existing Ingredient optional copy needs regression verification, not another field.

### Acceptance and certification

Use an independent disposable database, never reset the existing local database
or apply to hosted Atlas. Cover native Ingredient creation without manual code;
null-code normal release/read/export; missing/invalid Supplier code with no
number/partial commitment; immutable predecessor and complete null-code
replacement with distinct number; corrupt/missing required evidence; retained
scope, stale, replay, rollback and supplier eligibility tests.

Frontend covers preliminary summary/detail, all four official workbook/PDF modes,
both ZIP formats, exact quantities, notes, long Vietnamese names, School order,
A4 geometry, hidden lineage and historical reproduction. Required exact-head
GitHub jobs: Frontend CI, Supabase Smoke and actually executed Full Integration.
SKIPPED is not PASS. Keep failure evidence and stop after two same-root failures.

### Forward and rollback effects

Replay the new migration only on the expected predecessor definitions, with
guarded anchors and preserved function security. A second application must be
safe or explicitly rejected atomically without partial amendments. Rollback is
another reviewed forward migration: never drop or rewrite accepted snapshots.
Restoring the old null-code requirement after new releases would strand valid
issued documents, so retain nullable export/read compatibility even if release
or new preliminary presentation is disabled. No hosted rollback is authorized.

## Evidence

[Local verification and retained failures](../testing/atlas-b2-po-ingredient-code-optional.md)
record the implemented contract and actual results. Final exact-head CI and
source-review conclusions belong to the Draft PR report. Neither local tests
nor green CI constitute Product acceptance.
