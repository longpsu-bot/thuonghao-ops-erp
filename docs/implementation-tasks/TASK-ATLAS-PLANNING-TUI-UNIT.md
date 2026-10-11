# Túi Unit vocabulary amendment

Owner decision: 11 October 2026, supplement to Planning master catchup.

`Túi` is an independent controlled Unit: `COUNT`, decimal scale `0`, status `ACTIVE`. The existing SHA256 naming algorithm derives `v1-unit-67df33ade68a`. It is distinct from `Gói`, `Cái` and `Bịch`; no conversion or alias is introduced. Existing `Kg`/`kg` → `kg` and `Hủ`/`Hũ` → `Hũ` normalization remains unchanged. Unknown future labels still produce `UNSUPPORTED_UNIT`.

The snapshot normalizer, retained reference importer and backend rehearsal/import validator accept this exact addition. Migration `20261011162800_atlas_planning_tui_count_unit.sql` replaces the existing validator with the same function body plus the single approved label. It creates no Unit rows, changes no privileges, and leaves hosted data untouched. The protected import path creates the controlled Unit with its normal stable mapping.

The Staging count-policy package includes Túi among its fifteen exact imported COUNT Units, with the existing step `1` and effective date `2026-09-14`. It requires the Unit to exist with the approved meaning before configuring its policy, rejects conflicting policies and preserves exact replay. The closeout verifier expects those fifteen policies plus the unchanged kilogram policy. Run the package only after the protected import has made Túi available; no generic COUNT fallback is permitted.

Source Ingredient `1215` and Dish `2062` Recipes `3510`/`3511` resolve their `Túi` labels to the same Unit. Each source BoM quantity remains `100`; no unit conversion or mismatch adoption is needed. Snapshot regressions verify the exact hash, type, scale, lifecycle, shared reference and quantity preservation.

The accompanying Owner decision also preserves active source Recipe roots with zero BoM rows. Normalized roots retain `source_record_id`; diagnostic `SOURCE_RECIPE_EMPTY` has severity `INFO`, field `composition`, and the exact source Recipe ID in `detail`. No lines are invented. Protected catchup handles these roots without creating Recipe Versions or lines; backend readiness continues to reject unavailable compositions. Missing dependencies, invalid source values and unknown Units remain blockers.

Validation consists of focused snapshot/importer and Staging policy/closeout tests, `atlas_planning_tui_count_unit.sql` validator regressions, and the protected catchup regression suite. Database execution is delegated to full integration CI when local PostgreSQL is unavailable. A rollback requires a forward reviewed migration restoring the previous allowlist; it must not delete an imported Unit or any lineage that already references it.
