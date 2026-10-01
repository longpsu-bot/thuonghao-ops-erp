# TASK: MENU-SLOT-DISH-DECOUPLING-01

Status: implementation complete; Draft PR / CI evidence recorded below.
Owner-authorized baseline: `24af53733a7d3f166a34ba57b02975339a1433c4`.
Branch: `fix/menu-slot-dish-decoupling`. No merge or hosted deployment authorized.

## Scope and authority

Bounded shared Menu parser, existing Weekly Menu validation helper, connected
Chakra Menu blocker presentation, regression tests and affected specifications.
The explicit task supersedes historical typed-only Menu eligibility documented
in RMVP-03A; its current API/architecture amendments record that change.
No table/column/catalog rebuild, classification removal, master mapping/ID merge,
Recipe authoring/quantity/history change, lifecycle change, direct browser table
write, service-role credential, or unrelated visual redesign.

- KEEP EXPLICIT: canonical Dish identity, Weekly Menu `menu_slot_code`, Weekly
  Menu `dish_id`.
- DERIVE / CONTEXT: serving a Dish as savory/snack/dessert comes from its Menu
  assignment and source column.
- LEGACY / RETIRE CANDIDATE: using `dishes.dish_type_id` as Weekly Menu eligibility.
  This does **not** declare classification globally obsolete: Admin and Recipe
  consumers require separate review.

FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED remains authority.

## Resolution and validation

Old invariant: a Dish must have a non-null legacy type equal to the Menu column
catalog type. Corrected invariant: valid active School, date within the week,
valid active slot, valid active canonical Dish, unique School/date/slot.

Source normalization retains NFC + trim + Vietnamese case folding. Resolve:

1. Exactly one active exact Dish code globally; code identity precedes names.
2. Exactly one active exact normalized Dish name globally, regardless of legacy
   classification (including null). Never apply the slot tie-breaker here.
3. Multiple same-name active records: exactly one legacy type ID/code matching
   the slot resolves as transitional compatibility, recorded separately without
   a blocking warning. Zero/multiple slot matches are `AMBIGUOUS_DISH`.
4. No match is `UNKNOWN_DISH`; duplicate codes also fail closed as ambiguous.

No first/last array-order selection. No master records or Recipe roots change.
Parser diagnostics retain code, Sheet row number, slot code/name, source value,
and technical source reference. All source cells support joining backend issue
references to operator evidence. Canonical row/RPC contracts are unchanged.
Connected identity diagnostics stop before Preview/Save; backend Preview
blockers stop before consequential Save.

## Authoritative SQL and security review

Changed function only: `atlas_core.rmvp_03a_menu_issues(date,jsonb)`.
Migration: `20261001081941_menu_slot_dish_decoupling.sql`.

Latest predecessor is the full definition in
`20260727150000_rmvp_03a_connected_weekly_menu_attendance.sql`, amended by
`20260904042117_atlas_dish_creation_defaults.sql` to require Recipe readiness
for every active Dish (independent of legacy `requires_need_generation`).
The forward migration preserves those two newer Recipe predicates and removes
only the `UNMAPPED_DISH_TYPE` and `DISH_TYPE_MISMATCH` union branches.

Inspected callers: shaped Planning workbench/readiness, Menu Preview,
`save_weekly_menu_draft`, `validate_weekly_menu`, and `approve_weekly_menu`.
`atlas_api.save_weekly_menu(jsonb)` delegates to those legacy commands; the same
corrected helper therefore governs Preview and consequential Save. Tests invoke
both the actual Preview wrapper and actual consequential Save.

`CREATE OR REPLACE` retains existing ownership/ACL, stable security-invoker
behavior and empty search path. No new grants, roles, policies, triggers or API
entry points. Unknown/inactive slot, invalid/unknown/inactive Dish, School/date,
assignment uniqueness, Recipe readiness and effective-BOM checks remain intact.
Recipe selection continues using actual Dish + School Type + effective authority.

Migration has no data rewrite. Hosted deployment requires separate approval.
Rollback would be a separately reviewed forward replacement restoring the
predecessor helper (including its newer Recipe checks), never deleting/reworking
Menu history. Such a rollback reintroduces cross-slot/null-type eligibility
blockers and must be assessed against assignments created after deployment.

## Operator behavior and regression proof

One compact Vietnamese alert follows the Google source strip. Causes are grouped
by issue code, with invalid/unknown identity combined as one actionable cause.
Source details use native keyboard-accessible disclosure and a 160px bounded
scroll area: source Dish value, slot name, Sheet row and Vietnamese explanation.
The table stays rendered. Optional source warnings also stay collapsed/bounded.
Existing issue-code language is extracted into the shared Planning model and
reused by the retained workbench and Chakra bridge. Unknown future codes receive
a safe Vietnamese fallback; raw backend English messages never decide copy.

#340 flow remains fetch → parse → Preview → consequential Save → authoritative
readback. No Menu Review/Save button, no blind retry, no direct writes. Existing
replacement/removal notifications remain after confirmed readback; blockers
produce no success notification. Starting another sync clears stale notifications.

Parser regressions cover unique curry under savory/snack simultaneously, null
legacy type, exact-code precedence, reversed duplicate catalogs, curry legacy
compatibility, Sâm bổ lượng unique dessert/snack and duplicate dessert/snack
compatibility, zero/two duplicate slot matches, unknown and inactive-only names.
SQL proves curry savory/snack/both slots, Sâm bổ lượng dessert/snack, null legacy
type, inactive Dish, unknown slot, duplicate assignment, actual consequential
Save retaining both curry slots, both removed blocker codes, and unchanged
Recipe/effective-BOM warnings. Hook/UI tests prove unresolved names never invoke
Preview/Save; backend blockers never Save; 18 repeated English identity issues
become one Vietnamese summary; details contain source value/slot/row; table,
Google strip and retry remain accessible; no Menu Review/Save/success notice.

## Read-only duplicate Dish audit — Staging, 01/10/2026

Project: `rnzxmxiiqgtdevzregff`. Two SELECT-only connector calls inspected schema
and the complete normalized active-name duplicate groups. Normalization:
`lower(btrim(normalize(dish_name, NFC)))`, aligned with parser identity handling.
Result: **2 duplicate groups, 4 active Dishes, 8 active Recipe roots**. Each Dish
has one root for `v1-school-type-1` and one for `v1-school-type-2`. No current or
retained Weekly Menu line or approved snapshot line references any of these four
Dish IDs at audit time. This is an observation, not authority to merge records.

| Name               | Dish ID                              | Dish code    | Legacy type     | Root count | Menu line reference | Approved history reference |
| ------------------ | ------------------------------------ | ------------ | --------------- | ---------- | ------------------- | -------------------------- |
| Cà ri gà + bánh mì | f557aaa2-0a55-4997-c221-4c6777360f14 | v1-dish-1436 | afternoon_snack | 2          | No                  | No                         |
| Cà ri gà + bánh mì | 9bfe7aae-b24a-3afa-9024-436c37c6239a | v1-dish-1984 | savory          | 2          | No                  | No                         |
| Sâm bổ lượng       | a926354b-bf36-fc11-8a31-cb55812ae142 | v1-dish-1814 | dessert         | 2          | No                  | No                         |
| Sâm bổ lượng       | 910b4fb1-5ec0-9106-1196-07e69598b464 | v1-dish-1865 | afternoon_snack | 2          | No                  | No                         |

| Dish code    | School Type      | Active Recipe root ID                |
| ------------ | ---------------- | ------------------------------------ |
| v1-dish-1436 | v1-school-type-1 | fb68168a-cdc2-fa4e-eca1-375dee722e22 |
| v1-dish-1436 | v1-school-type-2 | acbe5b96-2749-f86a-f4e1-02a37745fa7c |
| v1-dish-1984 | v1-school-type-1 | d97c9670-b412-4fe6-3b3a-f52843e648fe |
| v1-dish-1984 | v1-school-type-2 | 2f6ab4e3-acbe-901d-e31a-ce11fc9a7c12 |
| v1-dish-1814 | v1-school-type-1 | b9079e01-7df4-4b88-9b59-b13756bbca83 |
| v1-dish-1814 | v1-school-type-2 | aa05ab84-7f9e-ca18-2259-527cb3710432 |
| v1-dish-1865 | v1-school-type-1 | 7f16f728-c33a-0962-11f3-d334ca44071b |
| v1-dish-1865 | v1-school-type-2 | a50063e4-8c5d-84d8-f404-e2ce6b3a73bb |

Future **DISH-MASTER-CONVERGENCE** owns duplicate canonical identity decisions,
Recipe-root/history reconciliation, historical/current reference assessment and
reviewed mappings. None of these audit records is changed here.

Reproducible read-only audit query:

```sql
with active as (
  select lower(btrim(normalize(dish_name, NFC))) normalized_name, d.*
  from atlas_admin.dishes d where dish_status = 'ACTIVE'
), duplicates as (
  select normalized_name from active group by normalized_name having count(*) > 1
)
select a.normalized_name, a.dish_id, a.dish_code, t.dish_type_code legacy_type,
  (select count(*) from atlas_admin.recipes r where r.dish_id = a.dish_id) root_count,
  (select jsonb_agg(jsonb_build_object('recipe_id', r.recipe_id,
    'school_type', coalesce(st.school_type_code, 'GLOBAL'), 'status', r.recipe_status))
   from atlas_admin.recipes r left join atlas_admin.school_types st using(school_type_id)
   where r.dish_id = a.dish_id) recipe_roots,
  exists(select 1 from atlas_planning.weekly_menu_lines l
    where l.dish_id = a.dish_id) current_or_retained_menu_reference,
  exists(select 1 from atlas_planning.weekly_menu_approval_snapshot_lines l
    where l.dish_id = a.dish_id) historical_approved_reference
from active a join duplicates using(normalized_name)
left join atlas_admin.dish_types t using(dish_type_id)
order by a.normalized_name, a.dish_code;
```

## Validation and limitations

- Red/green: new parser tests failed on cross-slot identity/null type/code precedence
  and missing diagnostics before correction. Old pgTAP cross-type/null eligibility
  assertions failed after expectations changed and passed after migration.
  New hook/UI tests failed before the blocker summary and stop-before-Preview fix.
- Focused tests: parser **16/16 PASS**, shared model **14/14 PASS**, hook **36/36 PASS**, Chakra UI **34/34 PASS** (100 total).
- Fresh local-only reset applied baseline migrations plus this forward migration;
  no #341 migration participated. Previous local DB was backed up at
  `C:/Users/HOME/.codex/attachments/menu-slot-before-reset.dump` before reset.
- RMVP-03A pgTAP: **77/77 PASS** on clean local DB.
- Planning atomic command boundaries: **258/258 PASS**.
- `pnpm local:rmvp03a:verify`: **PASS** after synthetic local School/master and
  two Dish fixtures. Initial read hit the local authenticated 8s timeout with JIT
  enabled; a direct JIT-off read completed in 17.299ms. Browser acceptance used
  temporary local-only `authenticated jit=off`; the original role configuration
  was restored in `finally`. Timeout was never raised; no shipped/hosted setting
  changed. This verifier proves functional browser-key behavior, not hosted
  performance. First fixture insert was rejected by the lowercase Dish-code
  constraint and corrected locally. Node's existing module-type warning remains.
- `pnpm ui:vnext:check`: PASS. `pnpm typecheck`: PASS.
- Targeted Prettier: PASS; `git diff --check`: PASS; `pnpm ops:workspace`: PASS. The workspace script retains a historical D: path warning; the owner explicitly authorized this verified E: checkout.
- The existing Supabase Integration workflow now explicitly runs the expanded
  RMVP-03A test alongside the existing atomic Planning command suite.
- No independent subagent was spawned (owner requested one agent/off).
  Product/architecture approval remains the Draft PR review gate.
- No live browser visual screenshot was taken; bounded rendering/accessibility
  behavior is checked by focused Chakra component tests.

## Protected boundaries

PR #341 remains Draft/OPEN at
`76b803130f0d46a385d4fa87dc0caae0fdb9af4f` on
`feat/procurement-supplier-line-note`. No edits, rebase, merge or cherry-pick.
Supabase Staging writes = ZERO. Retool writes = ZERO. OPS v1 writes = ZERO.
Hosted business-data writes = ZERO. Deployment and merge remain owner gates.

## Changed-path manifest

- `.github/workflows/supabase-integration.yml`: run the expanded Menu regression suite.
- `docs/api/rmvp-03a-planning-inputs.md`: current resolution/validation/diagnostic amendment.
- `docs/architecture/rmvp-03a-connected-weekly-menu-attendance.md`: explicit slot/identity amendment.
- `docs/ui/atlas-current-ui-inventory.md`: current source-strip/blocker presentation.
- `docs/implementation-tasks/TASK-MENU-SLOT-DISH-DECOUPLING.md`: this evidence and read-only audit.
- `src/modules/atlas/planning-inputs/planningInputsWorkbook.ts`: canonical resolver and source evidence.
- `src/modules/atlas/planning-inputs/planningInputsWorkbook.test.ts`: parser identity regressions.
- `src/modules/atlas/planning-inputs/planningInputsModel.ts`: shared Vietnamese issue-code language.
- `src/modules/atlas/planning-inputs/planningInputsModel.test.ts`: known/future-code safe language.
- `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`: reuse extracted issue mapping.
- `src/vnext/atlas/bridges/planning.ts`: business-only source evidence type bridge.
- `src/vnext/atlas/planning/usePlanningSources.ts`: stop unresolved identities before Preview, retain evidence.
- `src/vnext/atlas/planning/usePlanningSources.test.tsx`: no-Preview/Save and blocker regressions.
- `src/vnext/atlas/planning/PlanningMenuStage.tsx`: grouped summary/bounded source detail.
- `src/vnext/atlas/planning/PlanningSourcesWorkbench.tsx`: remove repeated Menu error paragraphs.
- `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`: operator blocker UX regressions.
- `supabase/migrations/20261001081941_menu_slot_dish_decoupling.sql`: one helper replacement.
- `supabase/tests/rmvp_03a_connected_weekly_menu_attendance.sql`: SQL Preview/Save/invariant regressions.

## Review / integration gate

Draft PR targets `main`; do not merge. Frontend CI and Supabase Integration are
reported from live GitHub checks in the final delivery report. Any generated
Cloudflare preview is review evidence only, not permission for Staging deployment.
Product review must verify real Google source resolution and the compatibility
choices against the canonical Dish catalog before a separate deployment approval.
