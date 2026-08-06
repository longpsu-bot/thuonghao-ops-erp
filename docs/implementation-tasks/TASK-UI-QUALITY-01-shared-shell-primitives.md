# TASK-UI-QUALITY-01 — Shared Shell and Primitives

**Status:** Proposed implementation handoff; not authorized until ATLAS-ACT-01A is accepted and merged

**Required baseline:** exact `main` SHA resulting from merged ATLAS-ACT-01A

**UI authority:** [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md)

**Inventory:** [Atlas Current UI Inventory](../ui/atlas-current-ui-inventory.md)

**Architecture:** [ATLAS-ACT-01 Hosted Staging and UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

## 1. Objective

Create a small, reusable local UI foundation for the existing Atlas application without redesigning business workflows or migrating every module in one PR.

The task standardizes shell hierarchy, semantic tokens and shared operational state components, then proves them in:

- the Atlas application shell; and
- one representative Planning Inputs wrapper or non-destructive shell-level surface.

It does not perform the full Planning module polish; that belongs to UI-QUALITY-02.

## 2. Implementation ceiling

UI-QUALITY-01 may add or revise only:

- local CSS variables and shared component styles;
- reusable React presentational components;
- Storybook stories;
- shared component and shell tests;
- the Atlas shell and one representative Planning wrapper to prove adoption;
- UI quality implementation documentation.

It adds:

```text
zero database migrations
zero API functions
zero capabilities
zero roles or scopes
zero lifecycle states
zero business events
zero business read-model fields
zero dependencies
```

## 3. Required primitives

Implement the smallest coherent set supported by the reviewed codebase:

```text
WorkbenchHeader
SectionPanel or normalized Panel
StatusChip or normalized Chip
NoticeBanner
ActionGroup
FormField shell
ConfirmationDialog
ResponsiveTable wrapper
EvidenceSummary
LifecycleTimeline
LoadingState
EmptyState
ReadOnlyState
ErrorState
```

Reuse or evolve existing `WorkbenchComponents.tsx` rather than creating parallel duplicate component families.

A component may remain private to the shared module until a second real use demonstrates a broader public API.

## 4. CSS foundation

Define semantic local custom properties for:

- type scale;
- spacing scale;
- control heights;
- radii;
- borders/dividers;
- surfaces/elevation;
- focus outline;
- text and muted text;
- information, success, warning, blocking and unknown-outcome semantics;
- table header/row/selection;
- responsive content width and breakpoints.

Do not introduce a CSS framework, CSS-in-JS runtime, utility framework or design-system package.

Do not rewrite the full stylesheet. Organize the minimum component/tokens sections needed for the accepted primitives and prove that existing unrelated modules remain visually and behaviorally stable.

## 5. Shell behavior

The Atlas shell must consistently show:

- application identity;
- current environment label;
- current authenticated/connection state where already available;
- primary navigation;
- page/workbench title hierarchy;
- prototype/staging notice where required by current configuration;
- access-denied and system-state presentation through shared states.

UI-QUALITY-01 must not add hosted configuration or staging deployment behavior. When ATLAS-ACT-01B is not yet merged, environment presentation may use the existing configuration state or a fixture-safe label without adding new environment variables.

## 6. Representative Planning proof

Migrate only the outer shell/presentation of one representative Planning surface, preferably `PlanningInputsWorkbench`, to prove:

- standard workbench header;
- section/panel spacing;
- action grouping;
- status/notice treatment;
- bounded responsive container;
- keyboard/focus behavior.

Do not rewrite child Weekly Menu, Attendance, Pantry, Readiness, Need Generation or Confirmed Need modules in this PR.

Do not change tab ownership, API calls, state transitions, business labels or command behavior.

## 7. State component requirements

Shared state components must distinguish:

```text
loading
no object selected
no records
legitimate zero-line state
warning
blocking
stale
unknown write outcome
read-only
access denied
configuration error
transport error
```

The shared component API must allow domain-safe text supplied by the caller. It must not invent a global backend error registry or expose raw diagnostics.

Unknown write outcome must never present an automatic retry action.

## 8. Dialog and focus requirements

`ConfirmationDialog` must prove:

- semantic dialog labeling;
- focus entry;
- tab containment or equivalent safe keyboard behavior;
- Escape/cancel behavior before submission;
- focus return to the invoking control;
- disabled confirmation while busy;
- no command on dialog open;
- long Vietnamese consequence text support.

Do not convert existing working inline confirmations across all modules in this slice. Provide the primitive and use it only in the representative proof if behavior can remain exact.

## 9. Responsive table requirements

The wrapper must prove at minimum:

- semantic table remains intact;
- horizontal scroll is contained;
- focus and selected row are visible;
- sticky identity columns do not cover content;
- narrow container state works;
- loading/empty states are not fake data rows;
- no page-wide horizontal overflow at 360 px.

Do not adopt a third-party grid or virtualizer.

## 10. Storybook requirements

Provide stories for shared primitives covering:

- default;
- long Vietnamese text;
- disabled/read-only;
- warning/blocking/unknown outcome;
- narrow container;
- dense table;
- dialog open/focus state;
- evidence summary and lifecycle history.

Stories use synthetic data only.

## 11. Test requirements

Focused tests must cover:

- semantic headings and labels;
- one authoritative current status;
- action hierarchy and disabled reason;
- unknown-outcome refresh language without retry;
- dialog focus/cancel/confirm behavior;
- table wrapper semantics;
- environment/prototype label behavior already authorized by the current connection contract;
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
Storybook build
UI Review Export workflow
git diff --check
```

No Supabase migration or pgTAP change is expected. Existing Supabase Integration must remain green if triggered by shared connection or shell paths.

## 12. Visual review requirements

Review the Atlas shell and representative Planning wrapper at:

```text
360 px
768 px
1280 px
```

Record:

- hierarchy;
- overflow;
- action visibility;
- focus behavior;
- table containment;
- long Vietnamese text;
- light/dark system behavior only if already supported;
- accepted remaining debt.

Do not claim module-wide polish from the representative proof.

## 13. Expected changed-path boundary

The implementation prompt must publish an exact manifest before editing.

Expected categories:

- `src/modules/atlas/WorkbenchComponents.tsx` and focused tests/stories;
- `src/modules/atlas/AtlasApp.tsx` and focused tests;
- the outer `PlanningInputsWorkbench` shell and focused tests only;
- `src/styles.css` or narrowly approved local shared CSS files;
- Storybook stories/config only where required;
- UI implementation record;
- roadmap status after merge.

Do not touch:

- business migrations or pgTAP catalogs;
- business API adapters/request contracts;
- module-specific backend logic;
- Confirmed Need command behavior;
- Procurement, Warehouse or Dispatch business logic;
- accepted architecture/decision files;
- Retool or OPS v1/v2;
- dependencies or lockfile unless an unexplained existing formatter change must be reverted rather than accepted.

## 14. Completion report

The draft PR must report:

- exact baseline, branch, commit and PR;
- exact changed-path manifest;
- token and primitive inventory;
- shell and representative adoption;
- Storybook story inventory;
- focused/full test and build results;
- responsive review notes at three widths;
- keyboard/focus review;
- UI Review Export status;
- explicit zero business migration/API/contract/dependency delta;
- deferred UI-QUALITY-02 work.

## 15. Explicit exclusions

UI-QUALITY-01 must not:

- create or connect hosted Supabase;
- add environment deployment tooling;
- add a UI framework, table library, global state library or CSS runtime;
- redesign all Planning tabs;
- change business labels already accepted by domain/API contracts unless correcting a documented inconsistency;
- change allowed actions or disabled codes;
- change command confirmation scope;
- add automatic retry;
- add CMD-03, Purchase Handoff, supplier allocation or purchase orders;
- modify Retool, production data, credentials or deployment resources.