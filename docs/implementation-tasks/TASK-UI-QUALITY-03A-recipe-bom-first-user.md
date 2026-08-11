# UI-QUALITY-03A — Recipe/BOM First-User Vertical

**Status:** Implemented on bounded draft branch; Product/Architecture review pending
**Baseline:** `057a30ef30121fc50ef983acd91704d2bca8e82c`
**Decision:** D-038
**Contract:** `RMVP-02A.v2`

## Bounded capability

Make the normal connected Recipe job understandable without Recipe Version lifecycle knowledge: find a Dish, select `Áp dụng cho`, edit basis/composition through Ingredient search, `Lưu`, and later `Đưa vào sử dụng`.

## Acceptance delivered

- Two additive atomic backend commands; no React lifecycle chain.
- Backend-authoritative Save/put-into-use eligibility with natural Vietnamese disabled reasons.
- New Recipe, existing draft, and post-release successor Save cases preserve identity, basis, exact lineage, idempotency, and prior immutability.
- Put-into-use internally validates/materializes and releases for future Planning without historical recalculation.
- Dish and Ingredient text search; visible selected Dish/type/scope; editable basis and quantities.
- Only `Lưu` and `Đưa vào sử dụng` compete in normal editing; dominant action follows dirty/saved state.
- Recipe history and technical version evidence use progressive disclosure.
- Copy/import remain secondary; Recipe Adjustment/effective-BOM behavior is unchanged.
- Unknown write outcome requires manual authoritative refresh and is never auto-retried.

## Verification

- Focused Recipe/API/model/RPC UI suite: 34 tests passed.
- New v2, retained v1 RMVP-02A, and exact platform catalog pgTAP suites: 68 assertions passed; the adjacent Planning security regression suite brings the focused database total to 152.
- Browser-key local Recipe journey: Save-new, Save-existing, internal validation/release, successor lineage, prior immutability, and reauthentication readback passed.
- Responsive review passed at 360, 768, and 1280 px with no page-wide overflow; the narrow BOM table retains local horizontal scrolling.
- Full frontend validation passed: formatting, typecheck, 466 tests, production build, Storybook build, and whitespace check.

## Security and scope review

Save uses `master_data.recipes.write`; put-into-use uses `master_data.recipes.release`; the existing validation capability remains separate and callable through v1. No role names are interpreted in React. No new role, capability, schema, table, RLS policy, npm dependency, or hosted binding is introduced.

No Recipe Adjustment, Planning calculation, Confirmed Need, Procurement, Warehouse, Dispatch, Retool, live OPS, or hosted Atlas behavior is changed.

## Migration and rollback

The forward migration adds two public functions, eight private helpers, and replaces the existing workbench function in place with v1/v2 dispatch. All existing v1 functions remain callable. Disposable local rollback is database reset; any deployed rollback must be forward-only and preserve immutable Recipe lineage and audit evidence.
