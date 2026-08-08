# UI-QUALITY-02A — Planning Source Workbenches

**Status:** Implemented, rendered-reviewed, locally validated and passing draft-PR checks

**Exact baseline:** `bf0a1af28f689bfb4a81f6b6db96b298006c1794`

**Branch:** `codex/ui-quality-02a-planning-sources`

**Draft PR:** [#180](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/180)

**Reviewed implementation head:** `27fe55ab160aeed1b173a943fe9b6cb826d771d2`

**Attendance alignment correction head:** `f53bc1d9ea6196e03c9fce1507dac195eae0d52f`

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

Each local draft area presents `Lưu bản nháp` as the primary local action. Preview, import/sync, defaults, add-row, cancel and reopen remain visually secondary. Validate/approve/reopen are separated from source and draft controls; commitment-producing actions retain explicit Vietnamese text. Eligibility, sequencing and command calls are unchanged.

Rendered lifecycle review covered the actual enabled states. Weekly Menu and Attendance expose preview/save for draft editing, validate for a saved draft, approve for a validated source, and a reason-gated reopen control after approval. Pantry enforces dirty draft → authoritative preview → save → validate → approve → reason-gated reopen; explicit no-additions follows the same preview/save gate. The retained Weekly Menu and Attendance eligibility allows the strong local save and validate actions to be enabled together in `DRAFT`; their separate labelled regions keep editing and lifecycle intent understandable, but the simultaneous emphasis is recorded as deferred product debt below.

## Cards and metrics

Cards added: **zero**. Cards removed: **zero**. The existing authoritative two-source readiness signal remains unchanged. Preview comparison counts remain evidence, not cards. React adds no metric, aggregation or authoritative calculation.

## Icon use

Existing `@phosphor-icons/react@2.1.10` regular-outline icons are reused only for refresh, workbook upload, Google sync, preview, save and Pantry add-row scanning support. Every business action retains visible Vietnamese text and its accessible name. No icon-only business command was introduced.

## Responsive findings

- **1280 px:** the four D-034 shell/workspace/workbench layers remain distinct; source and local-action groups are compact; Weekly Menu, Attendance and Pantry tables dominate their scrolled work surfaces; Attendance quantity columns 3–5 are right-aligned, Pantry Delivery Location/Ingredient/Unit are normally aligned, and Pantry quantity remains right-aligned; zero cards were added; document overflow is 0 px.
- **768 px:** week context remains one compact row, blockers precede ordinary controls, the six workflow destinations retain bounded horizontal scrolling, toolbars wrap by semantic group, and tables retain local scrolling. Attendance row identity remains sticky while its numeric columns stay right-aligned; Pantry columns 3–5 remain non-numeric and its quantity stays right-aligned; document overflow is 0 px.
- **360 px:** context, attention, toolbar groups, work surface, evidence and lifecycle controls retain that operator order. The six Planning destinations remain text-labelled in a bounded horizontal tab strip; actions stack without becoming a repeated card feed; blockers remain above controls; Menu and Attendance row identity stays sticky during local table scrolling; Pantry no-additions remains a labelled valid-evidence state; document overflow is 0 px. The resulting distance to the table and Pantry row-identity limitation are recorded as bounded debt below.

Tables intentionally retain bounded local horizontal scrolling at all narrow widths. Toolbars reorganize by semantic group and lifecycle actions stack by priority on mobile.

## Accessibility findings

Semantic headings, table headers, labels and tab roles remain. The six workflow destinations have a named tablist. Toolbar and lifecycle regions have accessible labels; focus-visible outlines cover new controls and table-row focus; dirty notices remain polite status messages; blocked Pantry load is an explicit alert; issue status includes text and not color alone; decorative icons are hidden from assistive technology; and long Vietnamese labels wrap without converting business actions to icon-only controls. Keyboard review confirmed a visible approximately 3 px blue focus outline on the blocked Pantry retry action. Reduced-motion behavior remains inherited from the accepted D-034 shell.

## Tests and validation

Focused tests added/updated:

- `PlanningInputsWorkbench.test.tsx`: all six destinations, source-workbench selection, lifecycle regions, dirty-state visibility, text-labelled business actions and preview/save gating.
- `PantryWorkbench.test.tsx`: toolbar/lifecycle presentation, text-labelled icon-supported actions and explicit no-additions presentation distinct from ordinary empty data, while retaining existing authority, lifecycle and late-response coverage.

Validation result:

- `pnpm ops:workspace` — passed on the canonical checkout and required branch.
- `pnpm format` — passed.
- `pnpm typecheck` — passed.
- Focused Planning source suites — 2 files / 10 tests passed.
- Focused Atlas shell regression after restoring the exact Google sync label — 1 file / 13 tests passed.
- `pnpm test` — 70 files / 445 tests passed.
- `pnpm build` — passed with the existing non-blocking large-chunk advisory.
- `pnpm build:review` — passed with the existing non-blocking large-chunk advisory.
- `pnpm build-storybook` — passed with existing non-blocking plugin-timing and large-chunk advisories.
- `git diff --check` — passed.

## UI Review Export

Existing Atlas review stories expose Weekly Menu normal/warning/blocker, Attendance editable/warning, Pantry rows/no-additions/access-blocked and mobile Planning source states. Actual rendered review was repeated at 360, 768 and 1280 px against the local review adapter after the Attendance alignment correction. It confirmed the required column alignment, no page overflow, unchanged controls and lifecycle behavior, blocker-first ordering, subordinate evidence/history and no browser console warnings or errors.

On reviewed implementation head `27fe55ab160aeed1b173a943fe9b6cb826d771d2`, draft PR #180 reported:

- **Frontend CI / Format, typecheck, test, build:** passed.
- **UI Review Export / Build UI review artifact:** passed.
- **Qodana:** passed.
- **Supabase Smoke:** passed.
- **Supabase Full Integration:** skipped because PR #180 remains draft.

## Product/UI gate review

**PRODUCT / WORKFLOW VERDICT: PASS WITH DEBT**

Each surface immediately identifies the week, source and authoritative status; current blockers/warnings precede source/editing controls; the table is followed by evidence/history and a distinct lifecycle decision region. Weekly Menu, Attendance and Pantry preserve the accepted business sequence. Debt: in Weekly Menu and Attendance `DRAFT`, unchanged backend/UI eligibility can leave `Lưu bản nháp` and `Xác thực` simultaneously enabled with strong styling, including after a local edit. Their labelled, vertically separated regions and dirty-state notice make the legitimate editing path clear enough for this bounded alignment amendment; changing eligibility or action styling was not one of the two authorized findings.

**LAYOUT VERDICT: PASS WITH DEBT**

Tables remain the dominant operational surfaces where rows exist; filters/source acquisition are compact; lifecycle controls are separated; evidence is subordinate and discoverable; no KPI/card structure was added. Debt: at 360 px, the required context, readiness, exceptions and source controls place the table below the initial viewport, especially for Weekly Menu, so the operator must scroll before row work. This follows the required information sequence and does not hide any action; shortening it requires a broader responsive composition decision outside this correction.

**VISUAL DESIGN VERDICT: PASS**

The dark navigation, white header, warm workspace and white workbench layers remain distinct; radius, elevation, density and typography follow D-034; copper is limited to active cues; semantic colors carry text; existing Phosphor icons support visible Vietnamese labels; and the result does not drift into dashboard cards, BI, Retool or old ERP styling.

**ACCESSIBILITY / USABILITY VERDICT: PASS WITH DEBT**

Semantic headings, labels, table headers, named tabs, visible focus, text-plus-color status and local scrolling remain intact, and the alignment correction restores the semantic distinction between Pantry descriptive and numeric cells. Debt: Pantry's first columns are not sticky, so horizontal scrolling at 360/768 px can move school identity off-screen; Weekly Menu and Attendance preserve row identity with sticky row headers. This is pre-existing table structure, not introduced by the correction, and changing it would require a broader Pantry table redesign.

**IMPLEMENTATION VERDICT: PASS**

The correction adds one Attendance-specific semantic hook, changes only selector scope, preserves Pantry quantity alignment and introduces no data, column, model, calculation, API, lifecycle, permission or behavior change. Required local validation and rendered review passed.

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

The three exact non-blocking product debts are the simultaneous strong save/validate eligibility in Weekly Menu and Attendance drafts, the long pre-table path on 360 px, and non-sticky Pantry row identity during narrow horizontal scrolling. None was introduced by this correction, and addressing them would exceed the instruction to fix exactly the Attendance alignment and implementation-record findings.

UI-QUALITY-02B Planning Input Readiness and Need Generation remain not started. UI-QUALITY-02C Confirmed Need remains not started. Their child workbenches were not materially modified. UI-QUALITY-03, hosted rehearsal and CMD-03 remain not started/deferred as recorded in the roadmap.
