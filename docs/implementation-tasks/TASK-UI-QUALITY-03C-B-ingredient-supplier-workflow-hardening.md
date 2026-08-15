# UI-QUALITY-03C-B — Ingredient/Supplier Operator Workflow Hardening

**Status:** Implemented on bounded draft branch; independent Product/Architecture review pending

**Starting `main`:** `d9b8348a0394f2b924878e90ad6ab93aa200d9e6`

**Branch:** `codex/ui-quality-03c-b-ingredient-supplier-workflow-hardening`

**Backend contract:** existing `RMVP-01.v1`; unchanged

## Bounded capability

Harden the connected Ingredient and Supplier catalog jobs without redesigning their accepted Application structure. The existing `Nguyên liệu` and `Nhà cung ứng` tabs, prominent search, Ingredient status filter, compact tables, detail drawers, Ingredient-contextual Supplier-priority drawer and distinct Ingredient lifecycle confirmation remain.

The Application changes are limited to:

- render every currently filtered Ingredient inside the existing bounded table scroll surface instead of silently slicing the result to 60 rows;
- require `Xem thay đổi` before create/update Ingredient, create/update Supplier and replace Ingredient Supplier priorities;
- capture small workflow-specific local snapshots so `Lưu` uses the exact reviewed business payload and reviewed expected version;
- invalidate Review on return/edit, cancel, close, refresh, stale rejection, unknown outcome or abandoned tab/context;
- lock further writes after an unknown transport outcome or successful command with failed authoritative readback;
- require authoritative refresh before recovery and authoritative readback before success is claimed.

No generic Preview/workflow framework or backend Preview API is introduced.

## Operator behavior

### Ingredient and Supplier authored facts

```text
Edit or create
→ Xem thay đổi
→ local human-readable Before/After Review
→ Lưu
→ existing authoritative RMVP-01.v1 command exactly once
→ authoritative readback
→ reconciled success
```

Creation Review has no fabricated Before object and labels the reviewed object `Nguyên liệu mới` or `Nhà cung ứng mới`. Update Review carries the stable object ID and authoritative expected version internally while displaying only human business facts. Material draft edits invalidate the prior snapshot.

### Ingredient Supplier priorities

The existing Ingredient-contextual editor retains zero-to-six assignments, active-Supplier selection for new assignments, unique Supplier identity, unique priority and integer priorities from 1 through 6. Review shows the complete current list and complete intended resulting list with Supplier names. One `Lưu` invokes `atlas_api.replace_ingredient_supplier_priorities` exactly once with the reviewed Ingredient version and reviewed Supplier ID/priority list.

### Ingredient lifecycle

Lifecycle remains a separate consequential action. `Ngừng dùng`, `Kích hoạt` and `Lưu trữ` continue through the existing confirmation, including the warning that deactivation or archival removes current Supplier-priority assignments. There is no additional `Xem thay đổi` modal for lifecycle.

## Write-outcome safety

- Known backend rejection never claims success and never retries.
- `STALE_VERSION` preserves the affected draft for reference, invalidates Review, locks another Save and requires authoritative refresh. Refresh closes the affected surface; the stale draft never inherits a newer version automatically.
- Unknown transport outcome sends no second command, invalidates Review, locks all workbench mutation and requires `Tải lại dữ liệu chính thức`.
- Command success followed by failed authoritative readback sends no second command, does not claim reconciliation and uses the same mutation lock.
- Successful authoritative refresh clears the affected editor/review/lifecycle surface and requires any further change to restart from current official data.

## Database, security and environment delta

- zero migrations, tables, triggers, roles, capabilities, policies, grants, functions, APIs or contract versions;
- no change to `masterDataApi` or master-data models;
- no Supabase file change and no local Supabase rerun required for this Application/docs-only slice;
- no Atlas Staging deployment or mutation;
- no live OPS mutation;
- no Retool mutation;
- no Planning, Procurement, Warehouse, Attendance, Menu, Pantry, Need Generation, Confirmed Need or XLSX change.

## Verification and rollback

Focused frontend coverage uses a 75-Ingredient synthetic catalog and proves all matching rows remain rendered/reachable, both catalog tabs and search/filter behavior remain, authored forms have no direct Save, invalid drafts block Review, Review shows exact business values, return preserves drafts, later edits require fresh Review, Save uses the exact reviewed payload/version once, Supplier-priority guardrails remain, lifecycle remains separate, and stale/unknown/readback-failure recovery never retries.

Responsive Review checks cover approximately 1280 px and 650 px. The Review modal is height-bounded with hidden horizontal overflow; the existing table scroll and drawer structure remain.

There is no migration or data rollback. Application rollback is removal of this bounded UI/docs change; any command already accepted by PostgreSQL remains an authoritative audited business action and must not be undone through browser state.

Hosted GitHub CI is expected to remain blocked before runner execution by the account billing/spending limit. Workflows are unchanged. The PR remains draft and must not merge before independent Product/Architecture review.

## Workflow disposition

Workflow preserved:

- separate Ingredient and Supplier catalog jobs;
- current tabs/search/filter/catalog/detail mental model;
- Ingredient-contextual Supplier priorities and max-six/uniqueness rules;
- existing Ingredient lifecycle business action and consequence confirmation;
- existing `RMVP-01.v1` backend authority.

Workflow improved:

- no hidden result truncation;
- exact Review-before-Save for authored changes;
- safe stale and unknown-outcome recovery;
- authoritative readback before reconciliation.

Workflow intentionally changed:

- authored Ingredient, Supplier and Supplier-priority changes require Review before Save, as approved by the Product Owner through the canonical operator-workbench rule merged in PR #195.
