# D-038 — Recipe Save and Put-Into-Use Boundary

**Status:** Accepted
**Date:** 2026-08-11
**Owning domain:** Admin / Master Data
**Contract:** `RMVP-02A.v2`

## Decision

The ordinary Recipe operator workflow has exactly two human actions:

1. `Lưu` preserves the complete authored Recipe as editable work and does not release it.
2. `Đưa vào sử dụng` commits the current saved Recipe for future Planning.

PostgreSQL owns draft/root/successor creation, deterministic validation, Recipe Line Revision materialization, release, prior-release locking, currentness, authorization, idempotency, lineage, events, audit, and authoritative readback. React must not chain RMVP-02A.v1 lifecycle functions to manufacture this workflow.

## Contract consequences

- Add exactly `atlas_api.save_recipe(jsonb)` and `atlas_api.release_recipe(jsonb)`.
- Extend the existing workbench read additively for v2 selected Dish/scope context and backend `allowed_actions`, `disabled_reason_codes`, and `disabled_reasons`.
- Keep every RMVP-02A.v1 function physically callable.
- Keep `master_data.recipes.write`, `.validate`, and `.release` distinct. Save uses `.write`; put-into-use uses `.release`; `.validate` remains available for v1 compatibility/internal support rather than becoming a second ordinary operator action.
- Preserve immutable released/locked Recipe Versions, stable Recipe Lines, exact predecessor Recipe Line Revisions, Planning reproducibility, and historical facts.
- Create no business relation, role, capability, scope kind, lifecycle state, dependency, or generic workflow/search framework.

## Application consequences

The default workbench centers Dish search, selected Dish/type, `Áp dụng cho`, editable basis, Ingredient search, and composition. Normal state language is business-oriented. Recipe Version number, status timestamps, predecessor, and immutable identifiers move behind Recipe history/support disclosure.

Copy and workbook import remain secondary utilities with unchanged contracts. Recipe Adjustment/effective-BOM behavior remains unchanged and is deferred to UI-QUALITY-03B.

## Safety and recovery

Backend eligibility is the maximum permission/lifecycle decision. React may only restrict it for dirty, invalid, busy, or unknown-write state. An unknown outcome disables further writes until a manual authoritative refresh; the browser does not automatically retry.

Release affects future Planning selection only. It never recalculates historical Planning facts and creates no Confirmed Need, Procurement, Warehouse, or Dispatch record.

## Rollback

Before operational use, a disposable local database may reset to the prior migration set. After v2 commands have recorded Recipe history, rollback must be forward-only and preserve all Recipe/version/line identities, revisions, receipts, events, and audit evidence. Removing v1 functions or rewriting prior releases is prohibited.
