# ATLAS-SHOPPING-LIST-UNIT-DISPLAY-01

Date: 2026-10-07. Starting main: `cffb17189b11e861c5d7dff6e761335940e46a45`.

## Bounded correction

The connected 17 September rehearsal passed `Kilogram` into the frozen ĐVT column: 68.99 pt at 18 pt exceeds the correct 35.5 pt guard. Controlled Unit already carries code `kg`. The defect was the presentation projection, not print geometry or Unit authority.

One pure `shoppingListUnitDisplay` helper in the existing Shopping List contract trims code/name and selects human code before human name. Technical adoption codes, UUIDs, `?`, and control characters are unusable; no usable candidate raises `INVALID_UNIT_DISPLAY`. Export, initial/continuation print measurement, ambiguity checks and import share it. Hidden `__unit_id` remains `controlled_unit.id`.

Allowed changes: the Shopping List contract/export/import, focused regressions, and affected contract wording. Prohibited changes: business semantics, print geometry, quantity precision/policy, lineage/currentness, supplier advice, API signatures, dependencies, migrations, schema/business writes, Retool, live OPS, Backend Convergence and Warehouse.

## Acceptance and verification

- Test-first regression failed with `PRINT_OVERFLOW` before the production fix.
- 90 focused Shopping List/package/precision/service tests passed after the fix: kg/Kilogram, Vietnamese fallback, trim/invalid identity labels, real print overflow/unsupported glyphs, ambiguity, package geometry, unchanged quantities, valid 12.5 quantity edit, visible Unit tamper (`REFERENCE_CHANGED`) and hidden Unit ID tamper (`STALE_IDENTITY`).
- The connected service regression uses kg/Kilogram and checks fresh read, local quantity proposal, unchanged input authority/drafts, and zero Save/Preview/Confirm/Validate/Approve/Release calls.
- Static independent code/architecture review: no findings.
- Staging read-only baseline: 92 migrations, tip `20261006112515`; 17 September batch `a0311e0a-a4de-48b9-a529-fe7464a3352b`, version 3, `DRAFT_REVIEW`, 249 lines.
- UI boundary and focused formatting/whitespace checks pass. Full requested local checks and exact-head CI are in progress.
- Hosted export/import acceptance is pending the corrected automatic branch preview. Freeze recommendation remains HOLD until that path passes.

Local test discovery excludes the ignored `.superpowers` snapshot, which contains copied baseline tests and an absent schema. No tracked test or CI check is disabled. Windows local runs use the threads pool to avoid stalled fork workers.

## Security and rollback

Identity, currentness, complete-workbook validation and explicit Save remain unchanged. Import creates local proposals only; no backend command is added. `partialImport = false`, `importWrites = false`. Frozen geometry, fonts, widths, protection, A3:O tables, F:O lineage and veryHidden metadata remain unchanged.

New migrations, hosted schema changes, business-data writes, Retool changes and live OPS changes: zero. Rollback is a frontend/helper/test/documentation revert; no database rollback is needed. A previously exported workbook whose visible Unit differs from the current resolver must be exported again and is rejected as `REFERENCE_CHANGED`.
