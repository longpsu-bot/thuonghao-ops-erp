# TASK-002 — Atlas Application Shell and End-to-End Workflow Prototype

**Status:** Proposed next task  
**Type:** UI workflow prototype  
**Scope:** React and TypeScript, mock data only  
**Supabase work:** Explicitly out of scope

## 1. Objective

Build the Atlas application shell and a navigable mock workflow that proves page responsibilities and handoffs before detailed contracts or backend implementation.

## 2. Governing documents

- `docs/handbook/01-vision-product-charter.md`
- `docs/handbook/02-business-model-and-operating-flows.md`
- `docs/handbook/04-business-processes.md`
- `docs/handbook/07-module-specifications.md`
- `docs/handbook/12-rollout-and-migration-plan.md`
- `docs/ui/atlas-application-map.md`
- `docs/recovery/2026-07-12-foundation-recovery-register.md`

## 3. Required implementation

### Application shell

- persistent primary navigation;
- active-page and workflow-stage indication;
- operating-period context;
- prototype/no-backend indicator;
- responsive desktop operational layout;
- route-level page components.

### Prototype pages

- Operations Home;
- Demand Overview;
- Attendance and Portions;
- Menu Planning;
- Additional Demand;
- Requirement Review;
- Supplier Allocation;
- Purchase Orders;
- Dispatch Planning;
- Operational QA.

Pages outside the two core journeys may be clear placeholders, but their responsibility, owner, input, output, and primary action must be visible.

### Two connected journeys

1. Catering menu + portions through QA.
2. Wholesale ingredient order through QA.

Fixture identity and lineage must remain stable across pages.

### TASK-001 recovery

Reuse, after refactoring:

- requirement table;
- trace drawer;
- status chips;
- exception filtering;
- grouped table behavior;
- Vietnamese display conventions;
- fixture and interaction-test patterns.

## 4. Explicit non-goals

- Supabase schema, migrations, RPCs or credentials;
- production data access;
- authentication/RLS implementation;
- authoritative calculation logic;
- released document generation;
- final visual design system;
- copying Retool source/component structure;
- freezing final read/command contracts.

## 5. Acceptance criteria

- navigation makes every major page discoverable;
- each page states its responsibility and responsible role;
- each page shows its input, output, primary action and handoff;
- catering and wholesale fixtures traverse the full workflow;
- Requirement Review is clearly separate from Supplier Allocation;
- PO release is clearly separate from Dispatch release;
- QA links exceptions back to the responsible stage;
- no hidden calculation is implemented in React;
- focused tests cover navigation and both journeys;
- `pnpm format`, `pnpm typecheck`, `pnpm test`, and `pnpm build` pass.

## 6. Completion outcome

The product owner can evaluate Atlas as an application and workflow, not as an isolated table. The next task may then refine one approved page and derive its explicit state/read/command contracts.
