# UI-QUALITY-02A — Planning Source Workbenches

**Status:** Implemented, rendered-reviewed, locally validated and passing draft-PR checks

**Exact baseline:** `bf0a1af28f689bfb4a81f6b6db96b298006c1794`

**Branch:** `codex/ui-quality-02a-planning-sources`

**Draft PR:** [#180](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/180)

**Reviewed implementation head:** `27fe55ab160aeed1b173a943fe9b6cb826d771d2`

**Attendance alignment correction head:** `f53bc1d9ea6196e03c9fce1507dac195eae0d52f`

**Reviewed PR head before workflow-safety correction:** `f3fbf46e764cfb28088f90f51a1587488434d09a`

**Planning-source workflow-safety correction head:** `87919be9b26088767f4070c5a76663f6193e67cb`

**Decision authority:** D-033 and [D-034 — Atlas Modern Operations UI Visual Architecture](../decisions/decision-atlas-modern-operations-ui-visual-architecture.md)

## Exact changed-path manifest

```text
docs/architecture/roadmap.md
docs/implementation-tasks/TASK-UI-QUALITY-02A-planning-sources.md
src/modules/atlas/AtlasApp.stories.tsx
src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx
src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx
src/modules/atlas/planning-inputs/pantry/PantryWorkbench.tsx
src/styles.css
```

No path outside the frozen maximum manifest changed.

## Composition changes

### Weekly Menu

Before, filters, workbook input, Google source selection/sync, preview, save and cancel competed in one undifferentiated toolbar. Source signature, Google fetch evidence and preview evidence preceded the main table, while current blockers appeared below it.

After, the authoritative status remains in the workbench heading; dirty state and current blockers/warnings appear before ordinary controls; filters, source acquisition and local draft actions form three labelled toolbar groups; the existing Dish Type-driven table remains the dominant surface; source, fetch, checksum, preview and history evidence follow in disclosure/support regions; and lifecycle decisions occupy a separate final action row.

### Attendance

Before, defaults, workbook input, preview and save were one flat action row. Source evidence preceded paste/import and the table, while blockers and warnings appeared after the table.

After, dirty state and current exceptions appear first; default/workbook acquisition is distinct from preview/save; paste remains a secondary disclosure; the editable School/date quantity table dominates; numeric values use aligned tabular presentation; source, checksum, preview and history evidence are subordinate; and lifecycle decisions are separated at the end. Explicit zero and existing quantity semantics are unchanged.

### Pantry

Before, add-row, explicit no-additions, preview, save, validate and approve all occupied one toolbar. Source evidence repeated the week above the table, and lifecycle actions competed with local editing actions.

After, catalog blockers and warnings lead; dirty state is compact and explicit; row/no-additions input is distinct from preview/save; the existing Pantry table dominates when rows exist; explicit no-additions has a valid-evidence treatment distinct from empty/missing data; server-derived Location and Unit remain visible; source, preview, invalid-line and history evidence remain support detail; and validate/approve/reopen use a final lifecycle decision area driven by unchanged backend `allowed_actions`.

## Action hierarchy

Each local draft area presents `Lưu bản nháp` as the primary local action only while local changes exist. Preview, import/sync, defaults, add-row, cancel and reopen remain visually secondary. Validate/approve/reopen are separated from source and draft controls; commitment-producing actions retain explicit Vietnamese text. Backend eligibility, sequencing and command calls are unchanged.

Rendered lifecycle review covered the actual enabled states. In dirty Weekly Menu and Attendance drafts, save is actionable and validate is unavailable; after save or local cancel, save becomes unavailable and validate becomes the primary lifecycle action allowed by the existing saved `DRAFT`. Attendance and Pantry now expose `Hủy thay đổi`, which restores their currently loaded authoritative rows and clears only local working state. Pantry retains dirty draft → authoritative preview → save → validate → approve → reason-gated reopen; explicit no-additions follows the same dirty protection and preview/save gate.

All six Planning destination buttons use one guarded tab-change handler. Rejected discard confirmation leaves the current tab and local edit intact; confirmed discard clears only the current source's local state before navigation; clean navigation does not prompt. The week-change and existing `beforeunload` guards now include parent-reported Pantry dirty state.

## Cards and metrics

Cards added: **zero**. Cards removed: **zero**. The existing authoritative two-source readiness signal remains unchanged. Preview comparison counts remain evidence, not cards. React adds no metric, aggregation or authoritative calculation.

## Icon use

Existing `@phosphor-icons/react@2.1.10` regular-outline icons are reused only for refresh, workbook upload, Google sync, preview, save and Pantry add-row scanning support. Every business action retains visible Vietnamese text and its accessible name. No icon-only business command was introduced.

## Responsive findings

- **1280 px:** the four D-034 shell/workspace/workbench layers remain distinct; source and local-action groups are compact; Weekly Menu, Attendance and Pantry tables dominate their scrolled work surfaces; the dirty notice remains a compact 33 px text signal; dirty Menu/Attendance show enabled save with disabled validate; Pantry remains preview-gated; document overflow is 0 px.
- **768 px:** week context remains one compact row, blockers precede ordinary controls, the six workflow destinations retain bounded horizontal scrolling, toolbars wrap by semantic group, and tables retain local scrolling. The dirty notice remains 33 px high, cancellation remains in the local draft group, and save/validate hierarchy remains unambiguous; document overflow is 0 px.
- **360 px:** context, attention, toolbar groups, work surface, evidence and lifecycle controls retain that operator order. The six destinations remain visible Vietnamese text in a bounded horizontal tab strip; the dirty notice wraps to a restrained 51 px rather than becoming an alarm card; local actions stack in editing order; disabled lifecycle actions remain visibly subordinate; no KPI/card UI was added; document overflow is 0 px. The accepted pre-table distance and Pantry row-identity limitation remain bounded debt below.

Tables intentionally retain bounded local horizontal scrolling at all narrow widths. Toolbars reorganize by semantic group and lifecycle actions stack by priority on mobile.

## Accessibility findings

Semantic headings, table headers, labels and tab roles remain. The six workflow destinations have a named tablist and retain visible Vietnamese text. Toolbar and lifecycle regions have accessible labels; focus-visible outlines cover controls and table-row focus; dirty state is announced with text; disabled validation is visible beside the lifecycle heading; cancel remains a text-labelled business action; and no icon-only command was introduced. Rejected tab/week confirmations preserve selection, values and a sensible focused control. Browser/page exit uses the existing native `beforeunload` pattern without custom browser text. Keyboard review confirmed the existing approximately 3 px blue focus treatment on the new local-action path.

## Tests and validation

Focused tests added/updated:

- `PlanningInputsWorkbench.test.tsx`: all six destinations; dirty Menu save/validate hierarchy; rejected dirty tab navigation with preserved edit; clean navigation without confirmation; clean saved-draft validation; Attendance local cancel; parent-visible Pantry dirty state; Pantry tab/week rejection; Pantry-backed `beforeunload`; and explicit no-additions protection.
- `PantryWorkbench.test.tsx`: dirty callback transitions, unmount cleanup, authoritative local cancel, preview/save/validate gating, explicit no-additions presentation, backend-derived fields and unchanged lifecycle/late-response behavior.

Validation result:

- `pnpm ops:workspace` — passed on the canonical checkout and required branch.
- `pnpm format` — passed.
- `pnpm typecheck` — passed.
- Focused Planning source suites — 2 files / 16 tests passed.
- Focused Atlas shell regression after restoring the exact Google sync label — 1 file / 13 tests passed.
- `pnpm test` — 70 files / 451 tests passed.
- `pnpm build` — passed with the existing non-blocking large-chunk advisory.
- `pnpm build:review` — passed with the existing non-blocking large-chunk advisory.
- `pnpm build-storybook` — passed with existing non-blocking plugin-timing and large-chunk advisories.
- `git diff --check` — passed.

## UI Review Export

Existing Atlas review stories expose Weekly Menu normal/warning/blocker, Attendance editable/warning, Pantry rows/no-additions/access-blocked and mobile Planning source states. Actual rendered review was repeated at 360, 768 and 1280 px against the local review adapter after the workflow-safety correction. It confirmed explicit dirty state, rejected discard preservation, clean navigation without a prompt, authoritative local cancel, save/validate gating, Pantry preview/save/lifecycle authority, no page overflow, unchanged D-034 layering and no browser console warnings or errors.

On pre-correction head `f3fbf46e764cfb28088f90f51a1587488434d09a`, draft PR #180 reported:

- **Frontend CI / Format, typecheck, test, build:** passed.
- **UI Review Export / Build UI review artifact:** passed.
- **Qodana:** passed.
- **Supabase Smoke:** passed.
- **Supabase Full Integration:** skipped because PR #180 remains draft.

## Product/UI gate review

**ARCHITECTURE / AUTHORITY: PASS**

The correction is confined to Application-layer local working state. Pantry reports a presentation-only dirty boolean to its parent; its business rows, authority, allowed actions and commands remain in `PantryWorkbench`. No state was moved globally and no backend contract, payload, lifecycle, permission or calculation changed.

**PRODUCT / WORKFLOW: PASS**

Each surface immediately identifies the week, source, authoritative status and local dirty state. Dirty Menu/Attendance validation is unavailable because it would act on the previously saved backend version; save or cancel clears local dirty state before validation becomes available. Pantry dirty state survives at the parent safety boundary, and tab, week and browser/page exit paths no longer silently discard it. Confirmed discard remains explicit and local only. The accepted business sequence is preserved.

**LAYOUT: PASS WITH DEBT**

Tables remain the dominant operational surfaces where rows exist; filters/source acquisition are compact; lifecycle controls are separated; evidence is subordinate and discoverable; no KPI/card structure was added. Debt: at 360 px, the required context, readiness, exceptions and source controls place the table below the initial viewport, especially for Weekly Menu, so the operator must scroll before row work. This follows the required information sequence and does not hide any action; shortening it requires a broader responsive composition decision outside this correction.

**VISUAL DESIGN: PASS**

The dark navigation, white header, warm workspace and white workbench layers remain distinct; radius, elevation, density and typography follow D-034; copper is limited to active cues; semantic colors carry text; existing Phosphor icons support visible Vietnamese labels; and the result does not drift into dashboard cards, BI, Retool or old ERP styling.

**ACCESSIBILITY / USABILITY: PASS WITH DEBT**

Semantic headings, labels, table headers, named tabs, visible focus, text-plus-color status and local scrolling remain intact, and the alignment correction restores the semantic distinction between Pantry descriptive and numeric cells. Debt: Pantry's first columns are not sticky, so horizontal scrolling at 360/768 px can move school identity off-screen; Weekly Menu and Attendance preserve row identity with sticky row headers. This is pre-existing table structure, not introduced by the correction, and changing it would require a broader Pantry table redesign.

**IMPLEMENTATION: PASS**

The correction adds a minimal optional Pantry dirty callback, bounded local reset helpers, one guarded tab handler, combined week/beforeunload protection and UI-only dirty gating. Focused and full regression suites, builds and rendered workflow review pass. No API/model/workbook/Supabase/Retool/dependency file changed.

## Exact deltas and exclusions

- Dependency delta: **zero**; `package.json` and `pnpm-lock.yaml` are unchanged.
- Business capability/object/contract/command/event/read-model/calculation delta: **zero**.
- Planning API/model/workbook delta: **zero**.
- Pantry API/model delta: **zero**.
- Lifecycle and permission delta: **zero**.
- Supabase, migration, RLS, RPC, function, Auth, hosted-data and Atlas Staging delta: **zero**.
- Retool and live OPS delta: **zero**.
- No staging deployment was performed.

## Deferred debt

The only accepted non-blocking product debts are the long pre-table path on 360 px and non-sticky Pantry row identity during narrow horizontal scrolling. Neither was introduced by this correction, and both were explicitly permitted to remain. The previous simultaneous save/validate and silent-unsaved-state findings are corrected and are not deferred debt.

UI-QUALITY-02B Planning Input Readiness and Need Generation remain not started. UI-QUALITY-02C Confirmed Need remains not started. Their child workbenches were not materially modified. UI-QUALITY-03, hosted rehearsal and CMD-03 remain not started/deferred as recorded in the roadmap.
