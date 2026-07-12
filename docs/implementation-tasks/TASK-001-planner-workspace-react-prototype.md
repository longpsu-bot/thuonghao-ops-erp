# TASK-001 — React Planner Workspace Prototype

**Status:** Completed as UI exploration; not approved as application structure or final contract  
**Type:** UI prototype  
**Scope:** React only, mock data only  
**Supabase work:** Explicitly out of scope  

---

## 0. Recovery disposition

TASK-001 successfully explored the Requirement Review table, trace drawer, warning/readiness presentation, grouping, Vietnamese display conventions, and fixture/test patterns. It did not establish the Atlas application shell, navigation, page ownership, input flow, or cross-role handoffs.

The output is therefore reclassified as **Requirement Review UI exploration**. Reusable assets are listed in `docs/recovery/2026-07-12-foundation-recovery-register.md`. The next implementation task is `TASK-002-atlas-shell-workflow-prototype.md`.

This disposition prevents the fixture types, local actions, or one-page composition from being treated as approved backend contracts.

---

## 1. Original objective

Build the first React prototype for the OPS ERP Planner Workspace.

The goal is not to create production calculation logic. The goal is to make the planning workflow visible so the team can review:

- what the planner needs to see;
- what calculation outputs are required;
- what warnings and blockers are meaningful;
- what table definitions will eventually be needed;
- what backend commands and API contracts the real system must support.

---

## 2. Business purpose

The planner answers the daily operational question:

```text
What do we need, what is wrong, what is ready, and what can move to procurement?
```

The screen should help staff review demand, requirement lines, exceptions, supplier readiness, and procurement readiness in one place.

---

## 3. Required screen areas

### 3.1 Planning header

Show:

- planning date or planning period;
- source filters;
- school/customer filter;
- demand type filter;
- readiness summary.

### 3.2 Summary cards

Show counts or totals for:

- total demand sources;
- total requirement lines;
- warning lines;
- blocking lines;
- lines with substitutions or overrides;
- lines missing supplier assignment;
- ready-for-procurement lines.

### 3.3 Demand source panel

Show sample source groups:

- catering menu demand;
- wholesale order demand;
- pantry addition;
- manual correction.

Each source should show:

- source type;
- school/customer;
- service date;
- dish or ingredient reference;
- portion/order quantity;
- status.

### 3.4 Requirement review table

Show one row per requirement line.

Suggested columns:

- service date;
- school/customer;
- source type;
- ingredient;
- usage/calculation mode;
- raw quantity;
- adjusted quantity;
- orderable quantity;
- unit;
- warning status;
- supplier status;
- readiness status;
- trace/action button.

### 3.5 Detail drawer or side panel

When a row is selected, show:

- source lineage;
- recipe or direct order basis;
- calculation trace example;
- applied adjustment example;
- warning explanation;
- supplier assignment preview;
- open questions produced by this row.

### 3.6 Exception and action area

Prototype actions only. Do not persist data.

Show buttons or draft actions for:

- mark reviewed;
- flag issue;
- create substitution draft;
- create quantity override draft;
- view trace;
- mark ready for procurement.

Actions may update local mock state only.

---

## 4. Mock data requirements

Use static fixtures in the frontend.

Fixtures should include at least:

1. normal catering recipe requirement;
2. wholesale direct ingredient demand;
3. herb/condiment batch allowance example;
4. missing supplier warning;
5. inactive ingredient warning;
6. substitution example;
7. quantity override example;
8. ready-for-procurement example;
9. blocking warning example;
10. pantry/manual addition example.

Mock data should be realistic enough to expose planning questions, but must not be treated as authoritative business logic.

---

## 5. Explicit non-goals

Codex must not:

- create Supabase migrations;
- create Supabase RPCs;
- connect to production Supabase data;
- implement authoritative calculation logic;
- hard-code hidden business rules beyond explicit mock fixture examples;
- create purchase orders;
- create dispatch documents;
- implement authentication or RLS;
- rewrite unrelated project structure.

---

## 6. Architecture constraints

- React coordinates; backend will decide later.
- Mock calculations are display fixtures, not business logic.
- Every displayed calculation output should have a visible trace example.
- Any inferred behavior must be labeled as prototype/mock.
- UI state must be explicit and reviewable.
- Avoid Retool-style hidden event-chain logic.

---

## 7. Suggested implementation shape

Codex may create:

```text
frontend/src/modules/planner/
  PlannerWorkspacePage.tsx
  components/
  fixtures/
  types.ts
```

If the frontend app shell does not exist yet, Codex should create the smallest possible Vite/React foundation needed for the prototype, without adding unnecessary dependencies.

---

## 8. Acceptance criteria

The prototype is acceptable when:

- a user can see a complete planner workspace page;
- the page uses mock data only;
- demand sources and requirement lines are visible;
- warnings and blockers are visually distinguishable;
- a selected line shows trace details;
- mock actions change only local state;
- no Supabase migration, RPC, or production data access is added;
- the screen reveals clear data/API-contract questions for the next design step.

---

## 9. Corrected follow-up after prototype review

Do not proceed directly to Planner contracts. First execute TASK-002 to establish the Atlas shell, page responsibilities, and connected catering/wholesale workflows. After product-owner review of that workflow, refine one approved page at a time and then derive its state, read, command, warning, permission, and audit contracts. Supabase schema work remains later.