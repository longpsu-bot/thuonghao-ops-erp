# Planner Workspace UI Specification

**Status:** Proposed UI contract  
**Authority:** First operational planning workspace prototype  
**Review required:** Yes — product owner review required before Codex implementation  
**Implementation stage:** Mock-data React prototype only  

---

## 1. Purpose

The Planner Workspace is the first high-value operational UI for OPS ERP.

Its purpose is to help planning staff convert demand signals into reviewed, actionable operational quantities before procurement and dispatch.

This workspace is more critical than a pure data input page because it represents the daily decision center of OPS ERP.

Master-data review remains important, but it should support the planner rather than become the first operational center of the product.

---

## 2. Design position

The Planner Workspace follows the project sequencing principle:

```text
UI-led, contract-constrained design before Supabase schema implementation
```

This means:

- the first version may use mock data or static fixtures;
- the UI must define screen states and action boundaries;
- no business calculation may be hidden in React;
- preview calculations are allowed only as non-authoritative UI behavior;
- final calculation, release, and audit behavior must eventually belong to backend commands;
- no Supabase migrations or RPCs should be created from this document until the contract is reviewed.

---

## 3. Scope

### In scope for first prototype

The first prototype should cover the planning decision flow from demand to orderable requirement readiness.

Recommended tabs or sections:

1. Planning Overview
2. Demand Sources
3. Requirement Review
4. Adjustments and Exceptions
5. Supplier Assignment Preview
6. Procurement Readiness
7. Planning Summary

### Out of scope for first prototype

The first prototype should not implement:

- production Supabase tables;
- Supabase RPCs;
- permanent data writes;
- released purchase orders;
- released dispatch documents;
- final accounting or inventory movements;
- hidden calculation logic in frontend code.

---

## 4. Primary user

Primary user:

```text
Planning staff / ERP admin
```

Secondary users:

- management reviewer;
- purchasing staff;
- warehouse/dispatch reviewer;
- product owner during workflow review.

---

## 5. Core business questions

The Planner Workspace must help staff answer:

1. What demand exists for the selected service date or planning period?
2. Which demand comes from catering, wholesale, pantry additions, or manual adjustments?
3. What ingredient requirements are calculated?
4. Which rows require review because of warnings, missing data, or unusual quantities?
5. Which quantities have substitutions or overrides?
6. Which requirements are ready for supplier assignment?
7. Which requirements are blocked from procurement?
8. What is the planning status before purchase and dispatch work begins?

---

## 6. Suggested layout

### 6.1 Header controls

The header should include:

- service date or date range;
- school/customer filter;
- demand source filter;
- planning status filter;
- warning severity filter;
- search by ingredient, dish, school, supplier, or source document;
- refresh or reload mock data action.

### 6.2 Planning status cards

Status cards should show:

- total demand sources;
- total ingredient requirement rows;
- rows ready for procurement;
- rows with warnings;
- rows blocked;
- rows with substitutions;
- rows with quantity overrides;
- rows missing supplier assignment.

### 6.3 Main planning table

The main table should include:

| Field | Purpose |
|---|---|
| Service date | Date of planned service |
| School / customer | Operational recipient |
| Demand source | Catering, wholesale, pantry, manual, correction |
| Source reference | Menu, order, adjustment, or document reference |
| Dish / source item | Dish or direct ingredient source |
| Ingredient | Ingredient being planned |
| Ingredient group | Planning group |
| Recipe basis quantity | Quantity from source rule or recipe line |
| Raw quantity | Pre-adjustment quantity |
| Adjustment indicator | Substitution, override, add, remove, factor |
| Effective quantity | Quantity after operational adjustments |
| Orderable quantity | Quantity after order-step or packaging treatment |
| Unit | Planning or purchase unit |
| Supplier status | Assigned, missing, suggested, conflict |
| Warning state | OK, warning, blocking |
| Review status | Not reviewed, reviewed, approved, blocked |
| Trace action | Open calculation trace |

---

## 7. Tabs and behavior

### 7.1 Planning Overview

Purpose:

- summarize the current planning period;
- highlight operational blockers;
- guide staff toward what needs attention first.

Should show:

- cards by planning status;
- warning count by type;
- demand source mix;
- readiness by school/customer;
- top ingredients by quantity or exception count.

### 7.2 Demand Sources

Purpose:

- show where the planner rows come from;
- avoid treating the planner as a black box.

Should support grouped views by:

- catering menu demand;
- wholesale orders;
- pantry additions;
- manual demand;
- correction demand.

Each source should expose:

- source identity;
- source owner;
- source date;
- source status;
- whether it contributes to requirements;
- blocking issues.

### 7.3 Requirement Review

Purpose:

- central working table for planning staff;
- identify quantities that are ready, suspicious, or blocked.

Required row actions:

- mark row reviewed;
- open trace viewer;
- open warning details;
- open substitution candidate;
- open quantity override candidate;
- open supplier assignment preview.

For prototype, these actions may open mock side panels.

### 7.4 Adjustments and Exceptions

Purpose:

- keep substitutions, overrides, and exception decisions visible;
- avoid silent changes to operational quantities.

Should show:

- substitution candidates;
- applied substitutions;
- quantity override candidates;
- missing reason notes;
- high quantity warnings;
- missing supplier warnings;
- ambiguous herb/condiment calculation treatment.

### 7.5 Supplier Assignment Preview

Purpose:

- preview supplier assignment implications before procurement release;
- keep supplier selection visible but not final.

Should show:

- assigned supplier;
- suggested supplier;
- missing supplier;
- supplier conflicts;
- ingredient-supplier relationship status;
- purchase unit compatibility.

Prototype must not release purchase orders.

### 7.6 Procurement Readiness

Purpose:

- determine whether the planning set is ready for purchasing.

Readiness statuses:

```text
READY
NEEDS_REVIEW
BLOCKED
PARTIAL_READY
```

Blocking examples:

- missing recipe;
- missing unit conversion;
- inactive ingredient;
- missing supplier;
- invalid quantity;
- unreviewed substitution;
- override without reason;
- ambiguous calculation method.

### 7.7 Planning Summary

Purpose:

- summarize what will move to procurement later;
- create review confidence before backend implementation.

Should show:

- rows ready for procurement;
- rows blocked;
- unresolved warnings;
- affected schools/customers;
- affected suppliers;
- export preview expectation.

---

## 8. Required UI states

Every screen must define and display these states:

| State | Meaning |
|---|---|
| Empty | No planning data for filter |
| Loading | Data is being loaded |
| Loaded | Data is available |
| Dirty | User has unsaved local changes |
| Validating | UI is checking draft edits |
| Warning | Non-blocking issue exists |
| Blocking | Action cannot proceed |
| Reviewed | User reviewed row or group |
| Ready | Row or group can move forward |
| Error | Data load or action failed |

---

## 9. Warning model

Warning severity:

```text
INFO
WARNING
BLOCKING
```

Initial warning types:

- missing recipe;
- inactive recipe;
- inactive ingredient;
- missing unit conversion;
- missing supplier;
- invalid quantity;
- unusually high quantity;
- substitution without replacement quantity;
- override without reason;
- rounding excess above tolerance;
- ambiguous herb/condiment treatment;
- source demand not reviewed.

Warnings must be visible at:

- row level;
- group level;
- planning-period summary level.

---

## 10. Calculation trace panel

The planner must include a trace viewer, even in mock form.

Trace should show:

- source demand line;
- recipe or direct ingredient basis;
- raw quantity calculation;
- usage-specific treatment;
- adjustment records;
- unit conversion;
- rounding or orderable treatment;
- supplier assignment basis;
- final planning status.

The trace viewer enforces the rule:

```text
No calculated quantity without explanation.
```

---

## 11. Draft actions and backend command boundaries

The prototype may show these actions but must treat them as future backend commands:

| UI action | Future backend command boundary |
|---|---|
| Mark row reviewed | review requirement row/group |
| Apply quantity override | create quantity override with reason |
| Apply substitution | create substitution and suppress source requirement atomically |
| Assign supplier | create or replace supplier assignment |
| Mark planning set ready | validate planning set readiness |
| Release to procurement | future controlled release command, not in first prototype |

React may draft these actions locally, but final behavior must be backend-authoritative.

---

## 12. Prototype data contract draft

The prototype should use fixture objects shaped like future API read models.

### 12.1 Planning row fixture

```ts
type PlanningRow = {
  planningRowId: string;
  serviceDate: string;
  schoolId?: string;
  schoolName?: string;
  customerId?: string;
  customerName?: string;
  demandSourceType: 'CATERING_MENU' | 'WHOLESALE_ORDER' | 'PANTRY_ADD' | 'MANUAL_DEMAND' | 'CORRECTION';
  sourceReference: string;
  dishName?: string;
  ingredientId: string;
  ingredientName: string;
  ingredientGroup?: string;
  rawQuantity: number;
  effectiveQuantity: number;
  orderableQuantity?: number;
  unit: string;
  supplierStatus: 'ASSIGNED' | 'MISSING' | 'SUGGESTED' | 'CONFLICT';
  supplierName?: string;
  warningSeverity: 'OK' | 'INFO' | 'WARNING' | 'BLOCKING';
  warningCodes: string[];
  reviewStatus: 'NOT_REVIEWED' | 'REVIEWED' | 'APPROVED' | 'BLOCKED';
  hasSubstitution: boolean;
  hasOverride: boolean;
  traceId: string;
};
```

### 12.2 Planning summary fixture

```ts
type PlanningSummary = {
  serviceDateFrom: string;
  serviceDateTo: string;
  totalRows: number;
  readyRows: number;
  warningRows: number;
  blockingRows: number;
  missingSupplierRows: number;
  substitutionRows: number;
  overrideRows: number;
  readinessStatus: 'READY' | 'NEEDS_REVIEW' | 'BLOCKED' | 'PARTIAL_READY';
};
```

---

## 13. Acceptance criteria for UI prototype

The mock UI prototype is acceptable when:

- planner opens without Supabase dependency;
- user can filter by date, school/customer, demand source, warning severity, and status;
- user can inspect demand source grouping;
- user can inspect requirement rows;
- user can open a mock calculation trace;
- warning states are visible and meaningful;
- blocked rows cannot be presented as ready;
- draft actions do not pretend to persist production data;
- screen contract is clear enough to inform future Supabase read models and RPC commands.

---

## 14. Codex implementation boundary

Codex may build a React mock UI from this specification only after product owner acceptance.

Codex must not:

- create Supabase migrations;
- create Supabase RPCs;
- connect to production OPS v1 tables;
- implement authoritative calculation logic in React;
- release purchase orders or dispatch documents;
- introduce hidden business rules.

Codex may:

- create static mock fixtures;
- create typed front-end models;
- create table, filter, tabs, cards, and side-panel components;
- create non-persistent draft states;
- create mock warning and trace displays;
- document proposed API contracts separately.

---

## 15. Product-owner review questions

1. Should the planner start from one service date, one week, or a custom date range?
2. Should the first planner focus on school catering, wholesale, or both together?
3. Which staff role owns planning review?
4. Which warnings should block moving to procurement?
5. Should supplier assignment be shown in the first planner prototype or deferred?
6. Should procurement readiness be grouped by school, supplier, ingredient, or date?
7. What is the minimum export/print expectation from the planner?
8. Which existing OPS v1 screen is the closest operational comparison: Actual Needs, Purchase Planner, or Dispatch Planner?
