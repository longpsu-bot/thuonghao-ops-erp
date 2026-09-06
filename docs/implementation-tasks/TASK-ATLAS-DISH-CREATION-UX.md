# Atlas Dish creation and lifecycle demand authority

## Scope and authority

Owner-approved task under OPS System Map v1.0, continued on PR #254 from
`30561813854ef06008b21317bac25cbf24fb0745`. One agent; no delegation.
The approved continuation establishes ACTIVE Dish + approved Menu + eligible
valid released Recipe as the demand participation rule. Deactivation is the
business lifecycle control; `requires_need_generation` is legacy metadata.

The normal creation form contains Tên món, Loại món, optional Nhóm mô tả,
optional Ghi chú vận hành, and Lưu món ăn. It submits only these business fields.
Affected Dish identity remains the primary selection source; legacy review
readback selects only a single newly returned identity. The browser-only review
adapter mirrors creation defaults.

## Backend and contracts

The unmerged, undeployed migration
`20260904042117_atlas_dish_creation_defaults.sql` is amended in the same PR.
It changes exactly these functions:

- `atlas_api.create_dish(jsonb)`: omitted code generates a complete opaque UUID
  after authorization/replay resolution; ordering defaults to 0; omitted flag
  defaults true; explicit true remains accepted; explicit false returns
  `VALIDATION_FAILED` with field feedback and no Dish insertion.
- `atlas_api.create_need_generation_run(jsonb)`: removes the legacy flag skip
  while retaining inactive-Dish validation and every Recipe/Attendance check.
- `atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()`: permits valid
  legacy-false selections and requires explicit selection or blocker evidence
  for every Menu Dish. Historical `v_initial_check` boundaries remain intact.
- `atlas_core.rmvp_02b_resolve_effective_composition(date,uuid,uuid,jsonb,uuid,uuid)`:
  Dish eligibility depends on ACTIVE status, not the legacy flag.
- `atlas_core.rmvp_03a_menu_issues(date,jsonb)`: checks Recipe readiness for
  every active assigned Dish, including legacy false.
- `atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)`: approved
  Menu references establish daily source presence regardless of the flag;
  inactive references still reach the explicit generator blocker.

The five existing demand functions use guarded exact-fragment replacements,
following repository migration precedent. Unknown predecessor bodies fail closed.
Signatures, owners, privileges, RLS, authorization, receipts and audit remain
unchanged. No table/column removal or historical row backfill occurs. Remaining
readback/import and legacy Recipe-authoring references to the column are outside
this bounded demand-participation change and cannot exclude a valid released
Recipe from demand. The later approved RECIPE-EFFECTIVE lifecycle correction
supersedes the original creation note: normal creation is `ACTIVE` at version 1,
and Recipe Save does not mutate Dish lifecycle.

Affected contracts: RMVP-02A creation, RMVP-02B effective composition, RMVP-03A
Menu readiness, RMVP-04 daily generation, and the Planning-domain persistence
contract. No quantity formula, Recipe selection precedence, Pantry, Attendance,
rounding, Confirmed Need, Procurement, Warehouse, Dispatch or Retool change.

## Acceptance and verification

- Creation tests cover omitted defaults, explicit true, rejected false without
  insertion/coercion, generated identity, replay, uniqueness and name stability.
- RMVP-04 uses a persisted false Dish with approved Menu and released Recipe;
  existing exact quantity, lineage, ambiguity and materialization assertions
  remain unchanged. Metadata remains false throughout.
- PLANNING-CONTRACT-01 checks active legacy-false Recipe resolution and daily
  source readiness without Pantry demand, missing Attendance as an explicit
  blocker, and later deactivation against the same approved Menu evidence.
- RMVP-03A checks missing-Recipe and blocked-composition warnings for legacy false.
- Issue 213 preserves normal future-planning inactive denial. Frontend tests
  preserve the exact business-only payload without a flag field.

Continuation RED: 18 failed assertions / 387 across RMVP-02A (2/42), RMVP-04
(11/87), PLANNING-CONTRACT-01 (3/196), and RMVP-03A (2/62). Failures reproduced
against predecessor functions before their changes.

Continuation GREEN: RMVP-02A 42, RMVP-02B 62, RMVP-03A 62, RMVP-04 87,
PLANNING-CONTRACT-01 196, Issue 213 18, UI-QUALITY-03A 21: 588 SQL assertions.
Focused frontend workbench/Recipe API: 23 assertions. Typecheck, touched supported
Prettier files, and whitespace checks are required before push.

Focused SQL uses disposable loopback PostgreSQL 17.6 with pgTAP 1.3.4 outside the
repository because Docker Desktop cannot start. Native bootstrap required
temporary owner EXECUTE grants on three baseline Dispatch functions; original
ACLs were restored before tests. No repository security control was weakened.
The earlier native whole-platform grant-catalog mismatch was reproduced unchanged
on both prior and PR code; GitHub Linux Supabase remains the broad authority.

## Migration, rollback, and operational boundary

The migration only replaces functions and a comment. No data migration, role,
policy, grant, column, or hosted database write. A later rollback requires forward
function replacements preserving identities, receipts and evidence; restoring
old payload requirements also requires coordinating the UI. Restoring legacy
flag exclusion would reverse the approved business rule and is not an automatic
rollback strategy.

After targeted GREEN and single-agent product/architecture review, push the same
PR and mark Ready to trigger GitHub Linux Full Integration. Do not merge or deploy.
Local test fixtures roll back. Staging, live OPS, and Retool receive zero writes.
