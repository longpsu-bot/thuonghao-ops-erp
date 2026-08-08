# UI-VISUAL-01 — Atlas Modern Operations Visual Foundation

**Status:** Implemented, rendered-reviewed and locally validated on bounded branch; draft PR pending

**Exact baseline and starting head:** `c98d044f3b880cca02fb8cb95f7c2ebcd0246f78`

**Branch:** `codex/ui-visual-01-modern-operations-foundation`

**Decision authority:** [D-034 — Atlas Modern Operations UI Visual Architecture](../decisions/decision-atlas-modern-operations-ui-visual-architecture.md)

PR #178 was closed unmerged and was not used as implementation authority. No commit, CSS or branch content from PR #178 was cherry-picked, copied or mechanically reused.

## Exact changed-path manifest

```text
docs/architecture/roadmap.md
docs/decisions/decision-atlas-modern-operations-ui-visual-architecture.md
docs/decisions/decision-register.md
docs/implementation-tasks/TASK-UI-VISUAL-01-modern-operations-foundation.md
docs/ui/atlas-ui-quality-standard.md
package.json
pnpm-lock.yaml
src/modules/atlas/AtlasApp.stories.tsx
src/modules/atlas/AtlasApp.tsx
src/modules/atlas/WorkbenchComponents.tsx
src/styles.css
src/theme.ts
```

`WorkbenchComponents.tsx` is the one optional narrow shared-presentation path: its read-only state now consumes the approved `atlasAmber` theme family instead of the superseded `atlasGold` key. No component behavior changed.

## Dependency delta

Exactly one runtime dependency was added and exact-pinned through pnpm:

```text
+ @phosphor-icons/react@2.1.10
```

No font, second icon library, CSS framework, grid, chart, state library or other package was added.

## Previous and final visual foundation

The accepted UI-QUALITY-01 baseline used Mantine 9 with a deep-green corporate primary, warm-gold support palette, a deep-green sidebar, pale green-neutral page surfaces and the existing connected shell/primitives. D-034 retains the single Mantine theme and all existing semantic components while changing corporate structure and action authority to ink navy.

The final shell hierarchy is:

```text
dark ink-navy navigation
→ white/light global review or connection header
→ warm-stone page workspace
→ white rounded operational workbench
→ local tabs, filters, table/form, evidence and action
```

The deliberate palette is corporate ink navy `#253246`, dark navigation `#1C2735`, selected/hover navy `#303E51`, workspace `#F4F1EB`, white surface `#FFFFFF`, soft surface `#F8F6F2`, border `#DDD8CF`, text `#22272E`, muted text `#626B74`, copper `#B66A3C` / text-safe copper `#A35B35`, amber `#D5A13D` with dark warning text `#714A0B`, success `#31745B`, information/focus `#2F6594`, danger `#B53E2E` and light dark-surface focus `#F2C66D`.

Mantine `sm` radius is 6 px, `md` is 9 px and `lg` is 10 px. Controls use the 6 px language; primary workbenches use 10 px; internal operational panels use 8–9 px. Workbenches use a subtle border and `0 2px 10px` low-elevation shadow; nested operational sections do not receive competing elevation. Stronger existing shadows remain limited to true drawers/overlays.

## Icon mapping

All icons use Phosphor regular outline weight, `currentColor` and verified package exports:

| Existing navigation level | Phosphor icon   | Size  |
| ------------------------- | --------------- | ----- |
| Tổng quan                 | `House`         | 19 px |
| Dữ liệu gốc group         | `Database`      | 16 px |
| Lập nhu cầu group         | `ClipboardText` | 16 px |
| Kế hoạch mua hàng         | `ShoppingCart`  | 19 px |
| Kho                       | `Warehouse`     | 19 px |

Existing sub-navigation remains quieter and text-only. No destination, route, permission or state was added. Navigation text remains the accessible name; icons are `aria-hidden`.

## Composition rules implemented

D-034 records cards as signals for authoritative completeness, attention, blocking or one critical decision total, with zero to three normal and no browser-invented metric. UI-VISUAL-01 adds no card or metric. Existing summaries remain existing evidence/summary presentation and detailed connected workbench recomposition is deferred to UI-QUALITY-02.

The shell and connected workbenches now reinforce table-first composition: a dominant white workbench sits inside the warm workspace, inner sections use dividers and soft surfaces, and Planning nested surfaces lose competing elevation. No connected Planning behavior or broad workbench layout was rewritten.

## Shared CSS consumer audit

Before editing, shared selectors were mapped across:

- Atlas shell: `AtlasApp.tsx`, connection/review headers and shared workbench primitives;
- connected Planning: `PlanningInputsWorkbench` plus Pantry, Readiness, Need Generation and Confirmed Need consumers;
- connected Admin: School, Ingredient/Supplier, Dish/Recipe and Recipe Adjustment workbenches;
- legacy Planner: `PlannerWorkspacePage` and its header, summary, source, table and exception components;
- shared/prototype workbenches: `WorkbenchComponents`, Atlas pages and Procurement/Warehouse/Dispatch prototypes.

Old corporate green structure/action styling was changed to navy. Genuine success green, warning amber, danger red and information blue remain semantic. Warning text uses a darker shade. Shared selectors were overridden by semantic purpose so dark headers, selected navigation, white workbenches and soft internal surfaces retain appropriate foreground contrast.

## Responsive, accessibility and visual review

Review targets are 360 px, 768 px and 1280 px. The Storybook evidence covers shell hierarchy, active/dark navigation, top-level icons, warm workspace, white workbench, long Vietnamese labels, success, warning, blocking/error, read-only/information and the mobile shell.

Rendered findings:

- **1280 px:** full dark sidebar, white review header, warm workspace and white 10 px-radius workbench read as four distinct levels; connected Planning and School Admin retain dominant tables; document overflow is 0 px; active navigation is `#303E51` with copper indicator; one h1 remains.
- **768 px:** the shell uses the compact header/navigation breakpoint, preserves 16 px page margins and gives the Planning workbench approximately 722 px; document overflow is 0 px; the dense table and six workflow tabs scroll only inside their bounded containers; focus returns to the menu control after selection.
- **360 px:** the shell, long Vietnamese labels, header controls and workbench stack by priority with 10 px page margins; document overflow is 0 px; the 966 px table and 773 px tab row remain locally scrollable; primary state and action remain visible.
- **State evidence:** success renders green text plus explicit approved labels; warning uses dark `#714A0B` text plus explicit messages; blocking/error uses red plus explicit alert text; read-only/information remains explicitly labelled.
- **Legacy Planner consumer:** the global palette produces a navy header, copper separator, amber selected control, readable table and 0 px page overflow. Its pre-existing seven-item prototype summary strip remains visible debt; no metric was added or reinterpreted here, and connected workbench/card recomposition remains deferred by the task boundary.

Accessibility review confirms explicit text for every reviewed state, decorative navigation icons hidden from assistive technology while text labels remain, one h1, mobile navigation focus return, reduced-motion rules and no page-wide 360 px overflow. WCAG contrast calculations for reviewed pairs are: text/white 15.02:1, text/warm 13.33:1, navigation text/navy 11.06:1, selected-nav text 10.86:1, navy button text 12.94:1, warning text/soft warning 7.39:1, copper text/white 5.12:1, copper text/warm 4.54:1, light focus/white 6.16:1, light focus/warm 5.46:1 and light-amber focus on dark surfaces 6.76:1 or higher.

## Validation

- `pnpm ops:workspace` — passed on the canonical checkout and bounded branch.
- `pnpm format` — passed.
- `pnpm typecheck` — passed.
- `pnpm test` — 69 files / 442 tests passed. Two earlier collection-only timeouts were traced to CPU contention from local visual-review servers; the exact required command passed after those local servers were stopped.
- Focused Atlas shell/shared presentation — 16/16 tests passed.
- `pnpm build` — passed; existing non-blocking large-chunk advisory retained.
- `pnpm build:review` — passed; existing non-blocking large-chunk advisory retained.
- `pnpm build-storybook` — passed; existing non-blocking plugin-timing and large-chunk advisories retained.
- `git diff --check` — passed.

## Scope and deferral

This task has zero business capability, business object, contract, command, event, read-model, calculation, migration, RLS, RPC, API, request, model, lifecycle, permission, hosted Supabase, hosted data, live OPS or Retool delta. It performs no deployment and no hosted mutation.

UI-QUALITY-02 remains deferred until D-034 / UI-VISUAL-01 is reviewed and accepted. UI-QUALITY-03, hosted rehearsal and CMD-03 remain not started/deferred as recorded in the roadmap.
