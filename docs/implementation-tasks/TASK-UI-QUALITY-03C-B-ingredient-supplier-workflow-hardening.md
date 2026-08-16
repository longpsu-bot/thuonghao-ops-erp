# UI-QUALITY-03C-B — Ingredient/Supplier Operator Workflow Hardening

**Status:** Implemented on bounded draft branch; independent Product/Architecture review pending

**Starting `main`:** `d9b8348a0394f2b924878e90ad6ab93aa200d9e6`

**Branch:** `codex/ui-quality-03c-b-ingredient-supplier-workflow-hardening`

**Backend contract:** existing `RMVP-01.v1` public functions; additively corrected Ingredient catalog authority

## Bounded capability

Harden the connected Ingredient and Supplier catalog jobs without redesigning their accepted Application structure. The existing `Nguyên liệu` and `Nhà cung ứng` tabs, prominent search, Ingredient status filter, compact tables, detail drawers, Ingredient-contextual Supplier-priority drawer and distinct Ingredient lifecycle confirmation remain.

The Application changes are limited to:

- render every currently filtered Ingredient inside the existing bounded table scroll surface instead of silently slicing the result to 60 rows;
- require `Xem thay đổi` before create/update Ingredient, create/update Supplier and replace Ingredient Supplier priorities;
- capture small workflow-specific local snapshots so `Lưu` uses the exact reviewed business payload and reviewed expected version;
- invalidate Review on return/edit, cancel, close, refresh, stale rejection, unknown outcome or abandoned tab/context;
- lock further writes after an unknown transport outcome or successful command with failed authoritative readback;
- require authoritative refresh before recovery and authoritative readback before success is claimed.
- replace authored Ingredient classification text with API-backed authoritative selects;
- label the operational grouping `Nhóm đặt hàng` and `order_step` as `Mức làm tròn khi đặt hàng`;
- canonicalize reviewed drafts so trim-only, blank-only, same-ID and equivalent numeric representations do not become business writes.

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

- one forward migration adds exactly two private Admin tables, `ingredient_types` and `ingredient_order_groups`, and exactly two nullable UUID foreign-key columns on `ingredients` for historical compatibility;
- the two catalogs each contain only UUID identity, stable code, Vietnamese display name, display order and active/inactive status; they are predefined and have no catalog-write API or UI;
- the existing shaped read and three existing Ingredient command functions are replaced in place; their public names, `RMVP-01.v1`, runtime owners, capabilities and browser grants remain;
- one private importer-core identity is retained behind the original local-only importer name, producing one additional private function but no public API;
- exact final object delta: +2 ordinary tables, +2 Ingredient columns, +2 foreign keys, +4 indexes, +4 RLS policies, +8 positive target grants, +1 private function, 0 roles, 0 capabilities, 0 triggers and 0 public API functions;
- `masterDataModel` gains additive catalog/read-shape types; `masterDataApi` invocation names remain unchanged;
- local clean reset, focused pgTAP, RMVP-01 compatibility, affected downstream suites, platform security catalog and database lint are required;
- no Atlas Staging deployment or mutation;
- no live OPS mutation;
- no Retool mutation;
- no Planning, Procurement, Warehouse, Attendance, Menu, Pantry, Need Generation, Confirmed Need or XLSX change.

## Verification and rollback

Focused frontend coverage uses a 75-Ingredient synthetic catalog and proves all matching rows remain rendered/reachable, both catalog tabs and search/filter behavior remain, authoritative API catalogs supply the two selects, authored forms have no direct Save, invalid drafts block Review, Review shows exact business names and Vietnamese decimals, return preserves drafts, later material edits require fresh Review, Save uses the exact canonical reviewed payload/version once, no-op representations open no Review and issue no command, Supplier-priority guardrails remain, lifecycle remains separate, and stale/unknown/readback-failure recovery never retries.

Responsive Review checks cover approximately 1280 px and 650 px. The Review modal is height-bounded with hidden horizontal overflow; the existing table scroll and drawer structure remain.

Application rollback is removal of the bounded UI change; any command already accepted by PostgreSQL remains an authoritative audited business action and must not be undone through browser state.

Migration rollback is appropriate only for a disposable local/pre-cutover database because dropping the two catalogs or foreign keys would discard restored classification identity. Any deployed rollback must be a reviewed forward migration that preserves referenced Ingredient history. No deployment is part of this task.

## Deferred Product requirement — DISH-RICE-01

`DISH-RICE-01 — Menu-derived rice accompaniment` is recorded only; it is not implemented here. The preferred Dish operator label is `Ăn kèm cơm`, not `uses_rice`, because it is distinct from Rice appearing inside a Recipe/BOM. Read-only OPS v1 evidence shows `Gạo thơm lài` classified as `Thực phẩm khô - gia vị` / `Hàng đặt riêng` and repeated scheduled Pantry quantities such as 65 kg for TÂN BÌNH; these are workflow evidence only and are not copied into Atlas. A later bounded Product/Planning contract must define how Menu + confirmed/current Attendance + the Dish flag derives one deterministic Rice need per intended meal context, how multiple qualifying Dishes are deduplicated, the governed Rice-per-portion rate source, authoritative Atlas Rice Ingredient identity, lock/correction semantics, and how derived Rice avoids double counting fixed/manual Pantry Rice. The illustrative `0.1 kg/portion` is not approved or frozen. No Dish schema, RMVP-02A/B, Planning, Pantry, XLSX or Rice behavior changes in UI-QUALITY-03C-B.

Hosted GitHub CI is expected to remain blocked before runner execution by the account billing/spending limit. Workflows are unchanged. The PR remains draft and must not merge before independent Product/Architecture review.

## Workflow disposition

Workflow preserved:

- separate Ingredient and Supplier catalog jobs;
- current tabs/search/filter/catalog/detail mental model;
- Ingredient-contextual Supplier priorities and max-six/uniqueness rules;
- existing Ingredient lifecycle business action and consequence confirmation;
- existing `RMVP-01.v1` backend authority.
- Pantry remains a separate authored workflow.

Workflow improved:

- no hidden result truncation;
- exact Review-before-Save for authored changes;
- safe stale and unknown-outcome recovery;
- authoritative readback before reconciliation.
- Ingredient Type is again controlled material vocabulary;
- `Nhóm đặt hàng` is again the controlled operational review/routing group;
- order-step wording expresses rounding meaning;
- formatting-only edits no longer create fake business writes.

Workflow intentionally changed:

- authored Ingredient, Supplier and Supplier-priority changes require Review before Save, as approved by the Product Owner through the canonical operator-workbench rule merged in PR #195.
