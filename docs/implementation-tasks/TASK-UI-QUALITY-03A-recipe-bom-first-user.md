# UI-QUALITY-03A — Recipe Creation and Lock Workflow

**Status:** Implemented on bounded draft branch; Product/Architecture review pending
**Baseline:** `057a30ef30121fc50ef983acd91704d2bca8e82c`
**Decision:** D-038
**Contract:** `RMVP-02A.v2`

## Bounded capability

Restore the retained OPS v1 business workflow in Atlas: current-effective catalog, separate Dish/Recipe creation (with copy as a helper), and a separate Change Order destination after first committed approved-Menu use. Remove the incorrect ordinary Save → put-into-use → successor-maintenance workflow.

## Acceptance delivered

- `Danh sách` is the default read-only catalog with Dish name/type, current Recipe scope/basis/Ingredients/status, Dish/Ingredient text search, `Xem`, and clear creation/adjustment guidance. Stable Dish codes remain backend identity and search/support evidence; the normal catalog does not present them as operator-facing metadata.
- `Tạo món & công thức` is separate, retains Ingredient search, and exposes one human commitment: `Tạo`/`Lưu`.
- Save makes valid composition Planning-eligible and remains editable only while the Dish has never appeared in an approved Weekly Menu snapshot.
- An approved snapshot line is the authoritative Atlas committed-use evidence. Readback exposes the locked state/reason; every still-callable RMVP-02A base Recipe/BOM composition mutation reuses one Dish-wide predicate under the same transaction lock as Weekly Menu approval and denies before business writes.
- `update_dish`, `set_dish_lifecycle`, and `set_recipe_lifecycle` retain their accepted RMVP-02A administrative contracts; approved-Menu evidence does not route them through RMVP-02B Change Order.
- Locked inputs are read-only and direct the operator to `Điều chỉnh` with the safe Vietnamese reason.
- Recipe Copy is a search/select/preview modal that fills the current unsaved creation form and closes; it is not a top-level maintenance command and creates no backend draft on its own.
- Dirty Dish/scope/navigation changes require confirmation; page unload uses the native dirty-form warning.
- Normal UI contains no Recipe Version, validation, release, successor, or lifecycle action.
- Existing RMVP-02A.v1 and v2 release/support APIs remain physically callable. React chains no lifecycle commands.
- Recipe Adjustment/effective-BOM behavior is unchanged and UI-QUALITY-03B remains unstarted.

## Evidence

- Retool `BoMCreation`: distinct creation workbench, Recipe copy inside creation, `is_locked` readback, and locked composition controls.
- Retool `SystemChangeOrder`: `Thay thế`, `Thay đổi định lượng`, `Thêm nguyên liệu`, and `Bỏ nguyên liệu`.
- Retool `overrideDish` and `overrideSchoolWise`: separate Dish/School override jobs.
- Live OPS (read-only): `daily_order_dishes` insert locks all Recipe rows for the Dish; locked base BOM writes are rejected and directed to Change Orders.
- Atlas equivalent: immutable `weekly_menu_approval_snapshot_lines.dish_id` created by Weekly Menu approval. Recipe release only establishes Planning eligibility and is not committed approved-Menu use.

## Required verification

- Focused Recipe UI/API/model tests cover read-only catalog, Dish/Ingredient search, distinct creation, copy helper, one-command Save, backend-denied lock, Change Order direction, dirty navigation, and unknown-outcome refresh.
- Corrected UI-QUALITY-03A pgTAP covers exact approved-Menu lock evidence; the complete locked Recipe/BOM denial matrix with no successor or base mutation; legitimate post-use Dish details and Dish/Recipe-root lifecycle administration; immutable Recipe composition and Planning facts; unchanged adjustment/downstream counts; security; and v1 compatibility.
- Retained RMVP-02A regression, platform/security catalog, browser-key Recipe journey, full frontend validation, responsive review, and exact-head draft CI are required before ready-for-review consideration.

## Scope and rollback

No Recipe Adjustment, Planning calculation, Confirmed Need, Procurement, Warehouse, Dispatch, Retool, live OPS, or hosted Atlas mutation is authorized. No dependency is added. Disposable local rollback is reset; deployed rollback is forward-only and preserves Recipe/version/line, approved Menu, Planning, event, receipt, and audit evidence.
