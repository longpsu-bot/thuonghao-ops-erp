# Hosted Atlas UI owner feedback 01

Status: Draft implementation candidate for hosted Product Owner review. Do not merge until the hosted review and required GitHub Actions checks pass.

## Baseline and boundary

- Baseline: `e2d8020b9821b5d3cc0d12aaa261d036cd7dcd28` on `origin/main`.
- Task branch: `feat/hosted-ui-owner-feedback-01`.
- Scope: frontend presentation, interaction, review fixtures, focused tests, and this implementation record.
- Prohibited: Supabase schema, migrations, RPCs, RLS, authoritative calculations, production data, staging writes, and Retool changes.

The approved Recipe product model from PR #257 remains authoritative. Dish creation still produces one active Dish with exactly two canonical typed Recipe roots. Normal authoring does not expose GENERAL. Base and effective Recipes remain distinct. Dish copy remains one atomic two-scope action. Once any approved weekly menu uses a Dish, the entire Dish and both typed Recipes are locked for ordinary editing; subsequent changes use Lệnh điều chỉnh.

## Implemented corrections

- Consolidated the Recipe area into one `Công thức` workbench with Dish search, selected-Dish base authoring, effective detail, create, copy, and import actions. The operator-facing peer tab is `Lệnh điều chỉnh`.
- Made the whole-Dish lock explicit and directed operators to Lệnh điều chỉnh.
- Kept SYSTEM_DISH preview based on Dish plus School Type, with the general/system BOM as the default comparison. After preview, an operator may optionally inspect one active School of the matching School Type; the School-specific authority path still requires a School.
- Aligned adjustment dates, helper text, and modal action areas.
- Replaced the Planning and Procurement school filters with one shared selector. Its committed empty array still means all Schools; zero selected Schools cannot be applied; applying all normalizes to an empty array; subsets remain exact.

## Acceptance and verification

- Recipe navigation exposes no separate `Danh sách` or `Tạo món & công thức` top-level tab.
- Base and effective Recipe content are visibly and semantically separate.
- SYSTEM_DISH preview does not send a School identity. Optional School inspection is inactive until explicitly requested and is limited to active matching-type Schools.
- Planning and Procurement use the same searchable, checkbox-based school selection behavior with an external `Trường / điểm giao` label.
- Focused component tests cover unified Recipe behavior, lock wording, system and school adjustment paths, optional inspection, school-selector draft/apply rules, and Atlas integration.

## Security and rollback

No security boundary or backend authority changed. The UI continues to rely on the existing authenticated APIs and does not add credentials, grants, or client-side authority decisions. There is no migration or data rollback. Application rollback is a reviewed revert of this bounded frontend and documentation change.

## Delivery gate

Publish only as a Draft pull request. GitHub Actions owns the full routine frontend validation. Stop at the hosted Product Owner review gate; do not merge or perform hosted business writes.
