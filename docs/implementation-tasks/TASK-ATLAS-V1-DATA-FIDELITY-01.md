# ATLAS-V1-DATA-FIDELITY-01 — bounded v1 master-data fidelity correction

**Status:** Draft implementation for review. Not merged, not deployed, and not applied to Atlas Staging.

**Date:** 27 October 2026 (Asia/Bangkok).

## Purpose and evidence

Bring the already imported Atlas core master data onto the same factual page as read-only OPS v1 without rebuilding the database or changing stable identities. The source/target comparison found:

- 49/49 Schools, 738/738 Dishes, 1,476/1,476 effective Recipes and 4,493/4,493 Recipe lines present;
- no Recipe-line quantity, operational Unit or note difference;
- 78 intentional BOM-Unit-to-Ingredient-purchase-Unit adoptions, each with retained evidence;
- 357/357 referenced Ingredients with matching operational Unit and order step;
- exactly eight stale Ingredient names in Atlas; and
- imported `v1-*` references shown in several operator-facing labels although they are migration identities, not useful display names.

The eight reviewed name corrections are:

| OPS v1 ID | Current Atlas name      | Reviewed OPS v1 name        |
| --------- | ----------------------- | --------------------------- |
| 931       | Chả giò                 | Chả giò xốp Cholimex 2kg    |
| 962       | Hẹ tươi                 | Hẹ lá                       |
| 1040      | Thịt heo xay            | Thịt vai heo xay            |
| 1041      | Thịt nạc vai            | Nạc vai heo                 |
| 1047      | Tôm thẻ                 | Tôm thẻ size 60 - 70 con/kg |
| 1053      | Ức gà fillet (không da) | Ức phi lê gà                |
| 1067      | Sườn non heo chặt sẵn   | Sườn non heo chặt nhỏ       |
| 1154      | Nạc lưng heo            | Nạc lưng heo (Miếng)        |

## Allowed scope

- Add a manual, preview-first, exact-main Atlas Staging forward-correction workflow for only the eight reviewed Ingredient names.
- Read only those eight OPS v1 Ingredient rows through the management read-only endpoint.
- Preserve Ingredient UUID, code, classification, purchase Unit, order step, status and every Recipe/operational fact.
- Advance the eight Ingredient versions once, refresh their typed mapping fingerprints/target versions and retain one immutable correction receipt if a separately authorized apply occurs.
- Keep imported technical codes searchable while omitting `v1-*` references from Pantry and School operator labels; show the Unit business name when its code is technical.
- Add focused Node, React and transaction-rollback PostgreSQL tests plus normal PR validation.

## Prohibited scope

- No OPS v1 write, broad master reload, reset, cascade, delete or identity replacement.
- No daily Menu, Attendance, Need, Procurement, Dispatch or Warehouse data copy.
- No schema migration, public API or business-rule change.
- No Warehouse or mobile-specific work.
- No automatic Staging apply, frontend publication or Production deployment.

## Safety and acceptance

The package fails closed unless the exact source project, eight legacy IDs, reviewed source names, current Atlas names, complete repository migration sequence, typed identities, current target versions, Ingredient classification, Unit, order step and status all match. Apply additionally requires the exact current `origin/main`, exact Staging target confirmation and a checksum copied from a separately completed and reviewed preview artifact. The recomputed plan binds current mapping bookkeeping and must match that external checksum. Platform fingerprints cover all unrelated master and operational tables; only the eight names, their versions, allowed mapping bookkeeping and one correction receipt may change. Authenticated readback and identical replay are mandatory for any future apply.

Acceptance requires focused tests to prove:

1. the source query is bounded and read-only;
2. source, target, mapping-bookkeeping, full migration history or reviewed-checksum drift is rejected;
3. preview writes nothing;
4. apply updates exactly eight names and no other business fact;
5. replay is idempotent; and
6. operator labels no longer expose imported technical School, Ingredient or Unit codes.

## Rollback and release boundary

Before any hosted apply, repository changes are removable through an ordinary reviewed Git revert. A future hosted correction is auditable forward history and must not be undone by deleting its receipt or restoring an old database. Any factual reversal requires another reviewed forward correction. This task authorizes a Draft PR only; merge and hosted apply remain separate decisions.
