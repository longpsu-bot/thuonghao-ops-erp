# OPS ERP Handbook
## 12 — Rollout and Migration Plan

**Document ID:** OPS-HANDBOOK-012  
**Status:** Baseline draft  
**Authority:** Rollout and coexistence strategy  
**Review required:** Yes — product owner review required before implementation sequencing  

---

## 1. Purpose

This document defines how OPS ERP should be introduced without disrupting the existing OPS v1 operations.

---

## 2. Rollout principle

OPS ERP should be built in parallel with OPS v1. Workflows should migrate module by module only after the target workflow is stable, tested, and accepted.

---

## 3. Legacy principle

Do not migrate data simply because it exists.

Each legacy object must be classified as:

- MIGRATE;
- REFERENCE;
- TRANSFORM;
- REBUILD;
- ARCHIVE;
- DISCARD.

---

## 4. Sequencing principle

OPS ERP should use a **UI-led, contract-constrained design sequence** before final Supabase schema implementation.

This is not loose UI-first development.

UI prototypes may come before final schema work, but every prototype must identify:

- read data;
- draft state;
- validation state;
- warning and blocking state;
- user actions;
- backend commands;
- calculation preview versus authoritative calculation;
- audit and trace requirements;
- eventual data/API contracts.

The intended sequence is:

```text
Business workflow definition
    ↓
Staff-facing documentation and review
    ↓
UI / screen prototype
    ↓
State model and data contract review
    ↓
Conceptual data model
    ↓
Supabase schema and RPC design
    ↓
Implementation and testing
```

This avoids freezing database assumptions before the workflow, screen states, staff behavior, and calculation rules are sufficiently understood.

It also avoids recreating Retool-style complexity inside React. UI prototypes must expose business states and contracts; they must not become the owner of hidden business logic.

Supabase remains the target backend platform, but table design should follow validated workflow, UI state, and API contract needs rather than leading them prematurely.

---

## 5. Recommended rollout phases

### Phase 0 — Foundation

- repository setup;
- handbook;
- decision register;
- business rule register;
- open questions;
- AGENTS.md;
- project governance.

### Phase 1 — Business architecture

- business model;
- glossary;
- process maps;
- operating roles;
- review of open business questions.

### Phase 2 — Master data and rule review

- ingredient master-data review;
- unit and conversion review;
- recipe-line review;
- calculation-rule candidate review;
- Vietnamese staff-facing review package.

RMVP-02A implements the local connected Dish/Recipe/BOM slice for this phase. Its OPS v1 workbook path is reviewed, checksum-bound, reference-strict, and draft-only; it is not an authority cutover.

### Phase 3 — UI and workflow prototype

- React app shell;
- navigation model;
- screen flows;
- role-based page access draft;
- form states;
- table states;
- warning and blocking states;
- save/release/correction states;
- export/reporting expectations.

This phase may use mock data or static fixtures. It should not require final Supabase schema.

### Phase 4 — Data contracts and API design

- screen-to-data requirements;
- read models;
- command contracts;
- validation errors;
- calculation trace shape;
- audit event shape;
- permission checks.

### Phase 5 — Supabase technical foundation

- schema design;
- migrations;
- Supabase Auth;
- RLS policies;
- RPC command implementation;
- typed API layer;
- testing framework.

### Phase 6 — First vertical workflow

Recommended first operational vertical:

```text
Wholesale order
    → canonical demand
    → requirement review
    → procurement planning
    → dispatch draft
```

Wholesale is a good first operational vertical because it is a new workflow and does not require full recipe migration.

Before this operational vertical, the recommended immediate prototype is the Master Data Review Workspace because the requirement engine depends on clean ingredients, units, recipe-line treatment, and calculation-rule candidates.

### Phase 7 — Catering integration

- legacy menu adapter;
- recipe adapter or migration;
- attendance integration;
- recipe calculation;
- adjustment workflow;
- requirement review.

### Phase 8 — Procurement and dispatch migration

- supplier assignment;
- purchase order release;
- dispatch release;
- correction flow;
- v1/v3 reconciliation.

### Phase 9 — Production adoption

- selected live workflow;
- staff training;
- rollback plan;
- parallel run;
- production acceptance.

---

## 6. Coexistence rule

Only one system may own writes for a workflow at a given time.

Examples:

- OPS v1 may continue to own catering menu sync during early rollout.
- OPS ERP may own wholesale orders from the start.
- OPS ERP may initially read v1 master data through adapters.
- A reviewed Recipe workbook may be copied one way into Atlas draft state while OPS v1 remains operational; neither system gains live write-through access to the other.

---

## 7. Migration candidates

### Likely reference first

- schools;
- ingredients;
- suppliers;
- dishes;
- current recipe data.

### Likely transform later

- daily orders;
- menu data;
- recipes and BOM lines;
- Recipe workbook proposals may be imported earlier only as versioned Atlas drafts with typed reconciliation and explicit later validation/release.
- actual need overrides;
- purchase assignments;
- dispatch records.

### Likely discard or avoid migrating

- Retool temporary state;
- UI-specific transformers;
- obsolete helper queries;
- duplicate cached outputs unless needed for history.

---

## 8. Rollback principle

Every production rollout must have a rollback path.

Rollback may mean:

- return workflow ownership to OPS v1;
- disable new UI module;
- preserve created records but stop new writes;
- run correction script under controlled review.

---

## 9. Acceptance criteria for workflow migration

A workflow may migrate to OPS ERP when:

- business process is documented;
- staff-facing review materials are accepted where applicable;
- UI workflow is usable;
- UI state model is explicit;
- permissions are defined;
- data ownership is clear;
- data contracts and API commands are reviewed;
- Supabase schema and RPCs are tested;
- tests exist for critical rules;
- export/reporting needs are met;
- rollback path exists;
- product owner accepts pilot results.

---

## 10. Review questions

1. Which workflow should OPS ERP own first: wholesale, requirements review, procurement, or dispatch?
2. Which OPS v1 data must be visible in OPS ERP on day one?
3. Which workflow failure would be most damaging operationally?
4. How long should v1 and OPS ERP run in parallel?
5. Which staff can pilot the first workflow?
6. Which screens should be prototyped before Supabase schema work starts?
7. Which screen states are advisory only, and which must map to authoritative backend commands?

---

## 11. Implementation note

Codex must not begin Supabase schema implementation or production migration work until the relevant workflow documentation, UI flow, state model, data contracts, ownership boundary, and review questions are explicitly documented.
