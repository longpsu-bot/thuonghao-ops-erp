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

## 4. Recommended rollout phases

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

### Phase 2 — System architecture

- system map;
- domain model;
- module specs;
- calculation specification;
- security model;
- API standards.

### Phase 3 — Technical foundation

- React app shell;
- Supabase project configuration;
- authentication;
- layout;
- navigation;
- typed API layer;
- testing framework.

### Phase 4 — First vertical workflow

Recommended first vertical:

```text
Wholesale order
    → canonical demand
    → requirement review
    → procurement planning
    → dispatch draft
```

Wholesale is a good first vertical because it is a new workflow and does not require full recipe migration.

### Phase 5 — Catering integration

- legacy menu adapter;
- recipe adapter or migration;
- attendance integration;
- recipe calculation;
- adjustment workflow;
- requirement review.

### Phase 6 — Procurement and dispatch migration

- supplier assignment;
- purchase order release;
- dispatch release;
- correction flow;
- v1/v3 reconciliation.

### Phase 7 — Production adoption

- selected live workflow;
- staff training;
- rollback plan;
- parallel run;
- production acceptance.

---

## 5. Coexistence rule

Only one system may own writes for a workflow at a given time.

Examples:

- OPS v1 may continue to own catering menu sync during early rollout.
- OPS ERP may own wholesale orders from the start.
- OPS ERP may initially read v1 master data through adapters.

---

## 6. Migration candidates

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
- actual need overrides;
- purchase assignments;
- dispatch records.

### Likely discard or avoid migrating

- Retool temporary state;
- UI-specific transformers;
- obsolete helper queries;
- duplicate cached outputs unless needed for history.

---

## 7. Rollback principle

Every production rollout must have a rollback path.

Rollback may mean:

- return workflow ownership to OPS v1;
- disable new UI module;
- preserve created records but stop new writes;
- run correction script under controlled review.

---

## 8. Acceptance criteria for workflow migration

A workflow may migrate to OPS ERP when:

- business process is documented;
- permissions are defined;
- data ownership is clear;
- tests exist for critical rules;
- staff workflow is usable;
- export/reporting needs are met;
- rollback path exists;
- product owner accepts pilot results.

---

## 9. Review questions

1. Which workflow should OPS ERP own first: wholesale, requirements review, procurement, or dispatch?
2. Which OPS v1 data must be visible in OPS ERP on day one?
3. Which workflow failure would be most damaging operationally?
4. How long should v1 and v3 run in parallel?
5. Which staff can pilot the first workflow?

---

## 10. Implementation note

Codex must not begin production migration work until the workflow ownership boundary is explicitly documented.
