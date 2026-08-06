# Atlas Current UI Inventory

**Status:** Proposed ATLAS-ACT-01A inventory

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Purpose:** identify current connected surfaces, reusable foundations and bounded UI-quality slices without redefining business behavior

## 1. Evidence basis

This inventory uses:

- current repository structure and component tests;
- [Atlas Operations Workbench Requirements](atlas-workbench-requirements.md);
- [UI Catalogue](ui-catalogue.md);
- merged Admin and Planning implementation records;
- UI Review Export and Storybook capability;
- retained Retool exports as workflow-density evidence only.

It is not a pixel-level visual audit. That occurs during each implementation slice through Storybook, UI Review Export and operator review.

## 2. Current application foundation

| Area | Current evidence | Assessment |
| --- | --- | --- |
| App shell and navigation | `src/modules/atlas/AtlasApp.tsx` and related tests | Functional shell exists; environment, page hierarchy and cross-module action language need consolidation. |
| Connection/Auth | `src/modules/atlas/connection/` | Strong local-only Auth/RPC safety boundary; staging environment identity remains unimplemented. |
| Shared components | `src/modules/atlas/WorkbenchComponents.tsx` | Useful compact primitives exist, but the surface is too small for the repeated state, dialog, evidence, timeline and responsive-table needs now present. |
| Global styling | `src/styles.css` | Broad styling exists in one large shared file; semantic tokens and component contracts are not yet explicit. |
| Storybook | repository Storybook configuration and stories | Available quality mechanism; shared operational states require fuller story coverage. |
| UI Review Export | GitHub workflow | Established visual-review artifact; should become a required gate for every quality slice. |
| Test foundation | module component tests and full Vitest | Strong behavior regression foundation; accessibility/responsive assertions need expansion. |

## 3. Current workbench groups

### 3.1 Planning Inputs shell

Primary path:

```text
src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx
```

Responsibilities:

- period/context selection;
- connected Planning tabs;
- shared Planning navigation and status context;
- composition of Weekly Menu, Attendance, Pantry, Readiness, Need Generation and Confirmed Need.

Quality observations:

- highest-value shell for current operators;
- repeated controls and status presentation across child tabs;
- must preserve exact tab-level APIs and late-response protections;
- should be migrated after shared primitives are proven.

Priority: **UI-QUALITY-02 / highest**.

### 3.2 Weekly Menu and Attendance

Primary paths:

```text
src/modules/atlas/planning-inputs/weekly-menu/
src/modules/atlas/planning-inputs/attendance/
```

Current strengths:

- explicit period and approval lifecycle;
- connected backend authority;
- deterministic tests;
- source readiness visibility.

Quality needs:

- aligned form/control layout;
- shared approval/history treatment;
- consistent empty, warning, stale and read-only language;
- table behavior at narrow widths;
- clearer draft-versus-approved evidence.

Priority: **UI-QUALITY-02**.

### 3.3 Pantry

Primary paths:

```text
src/modules/atlas/planning-inputs/pantry/
```

Current strengths:

- first-class Planning source;
- explicit zero-line approval behavior;
- backend-resolved references and Unit;
- connected Vietnamese workbench.

Quality needs:

- clearer purpose/reference fields;
- consistent line editing and issue presentation;
- approved zero-line state distinct from empty/missing;
- evidence summary and lifecycle history using shared primitives.

Priority: **UI-QUALITY-02**.

### 3.4 Planning Input Readiness

Primary paths:

```text
src/modules/atlas/planning-inputs/readiness/
```

Current strengths:

- exact source bindings;
- blocker/warning classification;
- evaluate/request/invalidate controls;
- backend-derived authority.

Quality needs:

- exception-first hierarchy;
- concise source-binding summary;
- reduced visual competition between history, issues and actions;
- standardized disabled-action reasons;
- responsive source cards/table.

Priority: **UI-QUALITY-02**.

### 3.5 Need Generation

Primary paths:

```text
src/modules/atlas/planning-inputs/need-generation/
```

Current strengths:

- complete exact-period connected journey;
- create, validate, release and invalidate behavior;
- exact lineage and CMD-15 materialization visibility.

Quality needs:

- one current run/lifecycle treatment;
- clearer distinction between run facts, issues and materialization evidence;
- shared action group and confirmation dialog;
- evidence/timeline consolidation;
- dense group/line tables inside bounded responsive wrappers.

Priority: **UI-QUALITY-02**.

### 3.6 Confirmed Need

Primary paths:

```text
src/modules/atlas/planning-inputs/confirmed-needs/
```

Current strengths:

- review and quantity confirmation;
- complete-batch validation;
- separate approval and release;
- exact current-state message;
- backend-derived actions and disabled reasons;
- Actor/time/warning evidence;
- lifecycle history;
- late-response and refresh-before-retry behavior.

Quality needs:

- normalize current status, notices, action group and confirmation dialogs as shared primitives;
- improve line-table density and row evidence detail;
- translate technical lifecycle-history kinds for primary display while retaining codes;
- align issue ordering and read-only presentation with other Planning tabs;
- certify narrow-screen behavior.

Priority: **UI-QUALITY-02 / reference implementation for authoritative lifecycle behavior**.

## 4. Admin workbenches

### 4.1 Schools

Primary paths:

```text
src/modules/atlas/admin/schools/
```

Quality needs:

- shared master-data list/detail shell;
- consistent create/edit/read-only modes;
- field-level validation and notices;
- responsive list/detail behavior;
- reference/effective-state presentation.

Priority: **UI-QUALITY-03**.

### 4.2 Ingredients and Suppliers

Primary paths:

```text
src/modules/atlas/admin/ingredients-suppliers/
```

Quality needs:

- clearer separation of Ingredient, Supplier and relationship data without creating separate applications;
- dense relationship tables with stable identity columns;
- consistent active/inactive status and validation;
- shared dialog and evidence treatment.

Priority: **UI-QUALITY-03**.

### 4.3 Dishes and Recipes

Primary paths:

```text
src/modules/atlas/admin/dishes-recipes/
```

Current architectural direction:

- one consolidated workbench;
- immutable Recipe Version/BOM lineage;
- adjustment/effective-BOM behavior;
- draft import and successor correction.

Quality needs:

- stronger hierarchy between Dish, Recipe Version, BOM, adjustment and effective result;
- reduced visual overload from multiple related states;
- consistent version/snapshot evidence;
- bounded tables and detail drawers/panels;
- clearer primary action for the current lifecycle state.

Priority: **UI-QUALITY-03 / high complexity**.

## 5. Other existing operational prototypes

Current repository modules include Procurement, Warehouse, Dispatch, Evidence and cross-domain traces/queues.

These surfaces are important for future MVP completion, but they do not yet own the next quality priority because the currently connected rehearsal gate stops at Confirmed Need release.

Quality work here must remain presentation-only until their connected backend slices are separately authorized.

Priority: **UI-QUALITY-04**.

## 6. Cross-cutting strengths

The current UI already has several important foundations worth preserving:

- React + TypeScript module boundaries;
- connected RPC adapter and Auth subject authority;
- backend-safe result shaping;
- no automatic write retry;
- substantial component-test coverage;
- Vietnamese operator labels;
- exception and lifecycle concepts visible in the workbenches;
- Storybook and exportable review artifacts;
- module-level late-response protection in connected flows.

The UI quality program should consolidate these strengths rather than replace the application structure.

## 7. Cross-cutting debt

### 7.1 Component duplication

Repeated patterns appear across module workbenches:

- title/context/action headers;
- notices and safe error messages;
- lifecycle/status text;
- disabled-action reasons;
- confirmation sections/dialogs;
- Actor/time/version evidence;
- issue lists;
- loading/empty/read-only states;
- history lists;
- responsive table wrappers.

These patterns need shared local components and semantic CSS tokens.

### 7.2 Large module components

Several workbenches combine transport orchestration, local draft management, lifecycle handling and substantial rendering in one file.

UI quality work may extract presentation components and hooks only when:

- business behavior remains unchanged;
- the changed-path boundary is explicit;
- existing tests remain authoritative;
- extraction is local to the quality slice;
- no generic state-management framework is added.

### 7.3 Global stylesheet concentration

A large common stylesheet contains much of the application presentation. The first quality slice should introduce semantic variables and component sections without forcing a full CSS architecture rewrite.

Splitting CSS files is allowed only where it improves ownership and build clarity without changing runtime dependencies.

### 7.4 State-language inconsistency

Connected modules have evolved at different times. Loading, disabled, stale, blocked, read-only and successful messages may differ in hierarchy and wording.

The UI standard establishes one cross-module state vocabulary while preserving backend-safe messages and domain-specific labels.

### 7.5 Responsive and accessibility evidence

Current behavior tests are strong, but systematic evidence at `360`, `768` and `1280` pixels, keyboard traversal, dialog focus, live regions and semantic table behavior is incomplete.

These become explicit quality gates.

## 8. Retool comparison boundary

Retool evidence shows operational density, query orchestration and the range of workflows currently performed. It should inform:

- which fields operators need visible;
- which exceptions need fast access;
- which source and document links matter;
- where current manual work is concentrated.

It must not be copied as:

- page structure;
- component hierarchy;
- JavaScript state model;
- direct SQL from the browser;
- authorization design;
- visual styling.

## 9. Proposed UI sequence

| Slice | Scope | Proof point |
| --- | --- | --- |
| UI-QUALITY-01 | Shared shell, tokens and primitives | Atlas shell plus one representative Planning wrapper use the primitives with no business delta. |
| UI-QUALITY-02 | Planning Inputs and Confirmed Need | Complete connected Planning journey has consistent states, actions, tables, evidence and responsive behavior. |
| UI-QUALITY-03 | Admin master data | Schools, Ingredients/Suppliers and Dishes/Recipes share a consistent master-data workbench pattern. |
| UI-QUALITY-04 | Other operational prototypes | Procurement, Warehouse, Dispatch and Evidence presentation aligns without adding connected authority. |
| UI-QUALITY-05 | Cross-module certification | Accessibility, responsive review, language consistency and operator walkthrough close remaining debt. |

## 10. Acceptance inventory output

Each quality slice must publish:

- exact surfaces reviewed;
- before/after issue inventory;
- changed-path manifest;
- shared components introduced or reused;
- behavior tests retained or added;
- Storybook stories;
- UI Review Export result;
- responsive review notes;
- keyboard/focus/accessibility result;
- explicit zero business migration/API/contract delta;
- deferred issues and next slice ownership.