# UI-QUALITY-02A — Planning Source Workbenches

**Status:** Implemented, rendered-reviewed and locally validated

**Exact baseline:** `bf0a1af28f689bfb4a81f6b6db96b298006c1794`

**Branch:** `codex/ui-quality-02a-planning-sources`

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

## Cards and metrics

Cards added: **zero**. Cards removed: **zero**. The existing authoritative two-source readiness signal remains unchanged. Preview comparison counts remain evidence, not cards. React adds no metric, aggregation or authoritative calculation.

## Icon use

Existing `@phosphor-icons/react@2.1.10` regular-outline icons are reused only for refresh, workbook upload, Google sync, preview, save and Pantry add-row scanning support. Every business action retains visible Vietnamese text and its accessible name. No icon-only business command was introduced.

## Responsive findings

- **1280 px:** the four D-034 shell/workspace/workbench layers remain distinct; source and local-action groups are compact; Weekly Menu, Attendance and Pantry tables dominate their scrolled work surfaces; Pantry derived Location/Unit remain legible; zero cards were added; document overflow is 0 px.
- **768 px:** week context remains one compact row, readiness remains exception-first, the six workflow destinations retain bounded horizontal scrolling, toolbars wrap by semantic group, and tables retain local scrolling (`966 px` Menu content inside approximately `633 px`; no document overflow).
- **360 px:** context, toolbar groups and lifecycle actions stack by priority; every source and lifecycle destination remains reachable; Menu table content remains locally scrollable (`966 px` inside approximately `257 px`); Pantry no-additions remains a labelled valid-evidence state; primary save and current lifecycle action remain discoverable; document overflow is 0 px.

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

Existing Atlas review stories now expose Weekly Menu normal/warning/blocker, Attendance editable/warning, Pantry rows/no-additions/access-blocked and mobile Planning source states. UI Review Export and Storybook production builds pass. Actual rendered review completed at 360, 768 and 1280 px against the local review adapter; GitHub UI Review Export and CI remain pending until the draft PR runs.

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

UI-QUALITY-02B Planning Input Readiness and Need Generation remain not started. UI-QUALITY-02C Confirmed Need remains not started. Their child workbenches were not materially modified. UI-QUALITY-03, hosted rehearsal and CMD-03 remain not started/deferred as recorded in the roadmap.
