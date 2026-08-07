# TASK-UI-QUALITY-01 — Shared Shell and Proven Primitives

**Status:** Proposed implementation handoff; not authorized until ATLAS-ACT-01A is accepted and merged

**Required baseline:** exact `main` SHA resulting from merged ATLAS-ACT-01A

**UI authority:** [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md)

**Inventory:** [Atlas Current UI Inventory](../ui/atlas-current-ui-inventory.md)

## 1. Objective

Create a small reusable UI foundation for the existing Atlas application without redesigning workflows or building a speculative design system.

The task standardizes semantic tokens, shell hierarchy and only the shared presentation patterns already repeated in current connected surfaces. It proves them in:

- the Atlas application shell; and
- one representative Planning Inputs wrapper.

Full Planning and Admin polish remain UI-QUALITY-02 and UI-QUALITY-03.

## 2. Implementation ceiling

This task may change only:

- local CSS variables and shared styles;
- existing shared React presentation components;
- focused stories/fixtures and tests;
- the Atlas shell;
- the outer shell of one representative Planning surface;
- UI implementation documentation.

It adds:

```text
zero migrations
zero APIs
zero capabilities, roles or scopes
zero lifecycle states or business events
zero business read-model fields
only the D-033-approved Mantine foundation dependencies: `@mantine/core`, `@mantine/hooks`, and required official Vite/PostCSS build support
```

## 3. Two-use rule

A shared abstraction may be created only when:

- at least two connected current surfaces need the same semantic behavior; or
- it is a shell-level primitive used by the application frame.

Do not prebuild components for future Procurement, Warehouse, Dispatch or hypothetical screens.

Reuse or evolve `WorkbenchComponents.tsx` rather than creating a parallel component family.

## 4. Candidate foundation

The exact implementation prompt must inspect current usage and select the smallest coherent subset from:

- `WorkbenchHeader`;
- `Panel`/`SectionPanel`;
- `StatusChip`;
- `NoticeBanner` or one `OperationalState` with variants;
- `ActionGroup`;
- `ConfirmationDialog`;
- `ResponsiveTable` wrapper;
- `EvidenceSummary`;
- `LifecycleTimeline` only if at least two current consumers adopt it.

Loading, empty, blocking, stale, unknown-outcome, read-only and access-denied states should normally be variants of one operational-state component rather than separate component families.

The PR must explain why every introduced primitive has current consumers.

## 5. CSS foundation

Define only the semantic custom properties required by the selected components:

- type and spacing scale;
- control heights and radii;
- borders, surfaces and focus outline;
- text, muted and disabled text;
- information, success, warning, blocking and unknown-outcome semantics;
- table header, row and selection states;
- content width and breakpoints.

D-033 supersedes the previous no-UI-framework restriction only for the exact bounded Mantine 9 foundation (`@mantine/core`, `@mantine/hooks`) and its required official Vite/PostCSS build support. Do not introduce another CSS framework, CSS-in-JS runtime, utility framework or design-system package.

Do not rewrite the entire stylesheet. Add clear token/component sections and preserve unrelated modules.

## 6. Shell proof

The Atlas shell should consistently present:

- application identity;
- current environment/prototype label using existing authorized configuration;
- connection/auth state where already available;
- primary navigation;
- page/workbench hierarchy;
- access-denied and configuration/system states through shared presentation.

This task does not add hosted configuration or deployment behavior.

## 7. Planning proof

Adopt the selected foundation only in the outer `PlanningInputsWorkbench` shell or another non-destructive Planning wrapper.

Prove:

- standard header and context;
- section spacing;
- action grouping;
- status/notice treatment;
- bounded responsive layout;
- keyboard/focus behavior.

Do not rewrite child Weekly Menu, Attendance, Pantry, Readiness, Need Generation or Confirmed Need modules in this PR.

Do not change tabs, API calls, local draft semantics, lifecycle transitions, business labels or command behavior.

## 8. Dialog and table proof

If `ConfirmationDialog` is selected, prove:

- semantic labeling;
- focus entry and return;
- Escape/cancel before submission;
- disabled confirm while busy;
- no command on open;
- long Vietnamese consequence text.

If `ResponsiveTable` is selected, prove:

- semantic table headers;
- contained horizontal scroll;
- visible focus/selection;
- narrow container behavior;
- no fake loading/empty rows;
- no page-wide overflow at 360 px.

Do not adopt a third-party grid or virtualizer.

## 9. Stories and tests

Create stories/fixtures only for introduced components and their real variants, including long Vietnamese text and a narrow container.

Focused tests cover:

- semantic headings and labels;
- one authoritative current status;
- action hierarchy and disabled reason;
- unknown-outcome refresh language without retry;
- selected dialog/table behavior;
- shell navigation regression;
- no business RPC or request-shape change;
- no service credential or private-table access.

Run:

```text
pnpm ops:workspace
pnpm format
pnpm typecheck
pnpm test
pnpm build
Storybook build where configured
UI Review Export
git diff --check
```

No Supabase migration or pgTAP change is expected.

## 10. Visual and accessibility review

Review the shell and representative Planning wrapper at:

```text
360 px
768 px
1280 px
```

Record:

- hierarchy and overflow;
- primary action visibility;
- keyboard order and visible focus;
- selected dialog/table behavior;
- long Vietnamese text;
- accepted remaining debt.

Do not claim module-wide polish from this representative proof.

## 11. Expected path boundary

The implementation prompt must freeze an exact manifest before editing.

Expected categories:

- `src/modules/atlas/WorkbenchComponents.tsx` and focused tests/stories;
- `src/modules/atlas/AtlasApp.tsx` and focused tests;
- outer `PlanningInputsWorkbench` shell and focused tests;
- `src/styles.css` or narrowly approved shared CSS files;
- Storybook files required by selected components;
- UI implementation record and roadmap status.

Do not touch:

- business migrations or pgTAP catalogs;
- API adapters/request contracts;
- child workbench business logic;
- Procurement, Warehouse or Dispatch modules;
- accepted architecture/decision files;
- Retool, production data or dependencies.

## 12. Completion report

Report:

- exact baseline, branch, commit and PR;
- exact changed-path manifest;
- selected tokens and primitives with current consumers;
- shell and representative adoption;
- story/fixture inventory;
- focused/full test and build results;
- responsive and keyboard/focus notes;
- UI Review Export status;
- explicit zero business migration/API/contract/dependency delta;
- deferred UI-QUALITY-02 and UI-QUALITY-03 work.

## 13. Explicit exclusions

UI-QUALITY-01 must not:

- create or connect hosted Supabase;
- add deployment tooling;
- add another UI framework, grid, global state library or CSS runtime beyond the exact D-033-approved Mantine foundation;
- build unused primitives;
- redesign all Planning tabs;
- change backend eligibility, disabled codes or confirmations;
- add automatic retry;
- polish unconnected downstream prototypes;
- add CMD-03, Purchase Handoff, supplier allocation or purchase orders;
- modify Retool, credentials or deployment resources.
