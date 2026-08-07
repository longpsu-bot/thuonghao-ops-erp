# UI-QUALITY-01 — Mantine Foundation Implementation Record

**Status:** Implemented and locally validated on bounded branch; draft PR and CI pending

**Starting baseline:** `844b4640df28f666736f018b8ef81d63fb78d2be`

**Decision authority:** [D-033 — Atlas UI Component Foundation](../decisions/decision-atlas-ui-component-foundation.md)

## Stopped previous run handling

The stopped hand-built UI attempt remains unchanged in its original dirty worktree on `codex/ui-quality-01-shared-shell-primitives`. This implementation was created in a separate clean worktree and fresh `codex/ui-quality-01-mantine-foundation` branch from exact `origin/main`; no previous uncommitted file was reset, deleted, copied or salvaged.

## Exact changed-path manifest

```text
.storybook/preview.ts
docs/architecture/roadmap.md
docs/decisions/decision-atlas-ui-component-foundation.md
docs/decisions/decision-register.md
docs/implementation-tasks/TASK-UI-QUALITY-01-mantine-foundation-implementation.md
docs/implementation-tasks/TASK-UI-QUALITY-01-shared-shell-primitives.md
package.json
pnpm-lock.yaml
postcss.config.cjs
src/main.tsx
src/modules/atlas/AtlasApp.stories.tsx
src/modules/atlas/AtlasApp.test.tsx
src/modules/atlas/AtlasApp.tsx
src/modules/atlas/WorkbenchComponents.stories.tsx
src/modules/atlas/WorkbenchComponents.test.tsx
src/modules/atlas/WorkbenchComponents.tsx
src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx
src/styles.css
src/theme.ts
```

## Dependency boundary and setup

Runtime dependencies are exactly `@mantine/core@9.2.2` and `@mantine/hooks@9.2.2`. Official Vite/PostCSS support is exactly `postcss@8.5.26`, `postcss-preset-mantine@1.18.0` and `postcss-simple-vars@7.0.1`. All are direct, exact-pinned versions. No other Mantine package, icon package, grid, UI framework, state library or CSS runtime was added.

`src/main.tsx` loads Mantine core styles before Atlas styles and establishes one `MantineProvider`. Storybook uses the same provider and `atlasTheme`. `postcss.config.cjs` follows Mantine's official Vite breakpoint-variable setup.

## Atlas theme

`src/theme.ts` defines the deep-green primary identity, restrained warm-gold support palette, Inter/Segoe UI typography, compact heading scale, small/medium spacing rhythm, restrained radius and compact Button/Paper defaults. Neutral work surfaces and the existing Atlas navigation identity remain visible; the result avoids gradients, glow, decorative icons, oversized type and card-heavy composition.

## Before/after issue inventory

Before: the shell used a fixed 252 px CSS grid with no mobile navigation treatment; page and nested workbench hierarchy were unrelated hand-built blocks; control heights and radii varied; review, access and load states used competing notice patterns; tabs and the desktop sidebar risked narrow-screen overflow.

After: Mantine `AppShell` owns the frame and breakpoint behavior; a mobile header and labeled Burger expose the same navigation; `NavLink` gives one active/disabled treatment; one page header and one nested workbench header establish h1/h2 hierarchy; shared Alert-based operational states provide text labels and live-region behavior; outer Planning context, readiness and tabs are bounded and horizontally contained.

Remaining generated-UI risks were reviewed: the proof surfaces do not add gradients, hero spacing, decorative KPI cards, large radii, excessive shadows or default-blue Atlas identity. Existing child modules still contain inconsistent controls, bordered regions and status treatments; those are intentionally deferred rather than hidden.

## Primitives and consumers

Mantine primitives used: `MantineProvider`, `AppShell`, `NavLink`, `Burger`, `Stack`, `Group`, `Box`, `Text`, `Title`, `NativeSelect`, `Divider`, `Paper`, `Button` and `Alert`.

Atlas semantic primitives:

- `WorkbenchHeader`: shell-level page identity in `AtlasApp` and nested h2 context in the outer `PlanningInputsWorkbench`.
- `OperationalState`: read-only review state in the Atlas shell plus access, loading and system-error states in the outer Planning wrapper. Its unknown-outcome variant represents the existing connected refresh-before-retry semantic and is covered by focused story/test evidence.
- `Chip`, `Panel`, `CompactTable`: public APIs and native DOM behavior retained for all connected and prototype consumers. They were not converted to Mantine because doing so would force unrelated test/provider churn and a broad table migration.

No speculative confirmation, responsive-table, evidence-summary, lifecycle-timeline or action-group abstraction was added.

## Shell and Planning adoption

The Atlas shell now uses a compact responsive Mantine frame while preserving every current destination, disabled future destination, review scenario, connection/auth panel and local/staging non-production label. Mobile navigation closes after selection and returns keyboard focus to the visible Burger control. No connection or session implementation changed.

The outer Planning wrapper adds a nested h2 header, Mantine Paper context/readiness regions, a Mantine primary authoritative-refresh action, bounded tab navigation and shared access/loading/system-error treatment. Weekly Menu, Attendance, Pantry, Readiness, Need Generation and Confirmed Need child behavior, labels, APIs, requests, lifecycle rules and command eligibility are unchanged.

## Stories and accessibility evidence

Storybook adds the Planning shell proof plus shared heading, operational-state, unknown-outcome and long-Vietnamese narrow-container stories. Focused tests cover the shared theme, h1/h2 hierarchy, access-denied live region, long Vietnamese guidance and refresh-only unknown outcomes. Atlas tests retain navigation, environment, auth and review-mode regression coverage and assert one page-level h1.

Responsive review targets are 360, 768 and 1280 px. Keyboard review covers the mobile navigation control, navigation order, disabled future destinations, review scenario, period selection, authoritative refresh and tabs. Mantine supplies focus mechanics, supplemented by a visible Atlas focus outline for legacy native controls. Status meaning includes a text label and does not rely on color. Reduced-motion CSS disables introduced motion.

## Validation and review status

- Focused Vitest: 16/16 passing across the new shared presentation and Atlas shell suites.
- Typecheck: passing.
- Full Vitest: 69 files and 442 tests passing.
- Production build and review-mode build: passing; the existing large-chunk advisory remains non-blocking.
- Storybook static build: passing; only non-blocking bundle-size and plugin-timing advisories were reported.
- Format, workspace verification and diff whitespace check: passing.
- UI Review Export and PR CI: pending draft PR.
- Browser findings at 360/768/1280: no horizontal document overflow; one h1 and the expected nested h2 hierarchy at every width; mobile header below 768 px and 252 px desktop navigation from 768 px; long operational-state content wraps; focus remains visible and returns to the mobile navigation control after selection.

## Deferred debt and zero-delta statement

UI-QUALITY-02 retains complete connected Planning polish: child form/control normalization, tables, issue/history density and full narrow-screen certification. UI-QUALITY-03 retains connected Admin list/detail and form consolidation. Hosted rehearsal and CMD-03 remain deferred by D-032.

This change has zero migration, RLS, RPC, API, request-shape, read-model, business-contract, lifecycle, capability, permission, authoritative-calculation, hosted-data, hosted-Supabase, live OPS or Retool delta.
