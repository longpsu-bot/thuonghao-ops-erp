# UI Catalogue

**Status:** Baseline draft  
**Authority:** UI inventory and screen planning  
**Review required:** Later, before React screen implementation  

---

## 1. Purpose

This file records planned OPS ERP screens and UI patterns. It prevents screens from being invented independently of business workflows.

---

## 2. UI design principle

Screens should support business decisions. They should not duplicate backend business logic.

React may preview, organize, and validate user input for usability. Backend functions remain authoritative for operational decisions.

OPS ERP uses a UI-led, contract-constrained design sequence:

```text
workflow question
    → React screen prototype
    → visible state and warning design
    → data/API contract
    → conceptual data model
    → Supabase schema and RPC implementation
```

The React prototype is allowed to come first, because the planner screen will reveal many unanswered questions about calculation logic, table shape, workflow status, and review actions.

However, React-first does not mean UI-only or UI-authoritative. The prototype must expose questions and contracts; it must not become the hidden calculation engine.

Each significant screen must define:

- read data;
- local draft state;
- validation state;
- warning and blocking state;
- user actions;
- backend command boundary;
- eventual data/API contract.

---

## 3. Planned screen groups

### Foundation

- login;
- app shell;
- navigation;
- user profile;
- access denied;
- system status.

### Planning

- planner workspace;
- planning overview;
- demand source review;
- requirement review;
- adjustments and exceptions;
- supplier assignment preview;
- procurement readiness;
- planning summary.

### Master Data

- master-data review workspace;
- customers/schools;
- delivery locations;
- ingredients;
- suppliers;
- supplier-ingredient relationships;
- dishes;
- units.

### Demand

- catering demand review;
- wholesale order list;
- wholesale order detail;
- demand document history.

### Requirements

- unified requirement review;
- requirement warnings;
- substitution editor;
- quantity override editor;
- trace viewer.

### Procurement

- procurement planning board;
- supplier assignment;
- purchase order draft;
- released purchase order viewer;
- supplier confirmation.

### Fulfilment

- dispatch planning;
- dispatch document;
- delivery confirmation;
- shortage recording.

### Control

- audit timeline;
- exception dashboard;
- reconciliation reports.

---

## 4. First recommended operational prototype

The first high-value operational React prototype is:

```text
Planner Workspace
```

Rationale:

- the planner is the daily decision center of OPS ERP;
- it converts demand into actionable requirement readiness;
- it reveals what calculation outputs staff need to see;
- it reveals what table/schema design must support;
- it exposes status, approval, exception, and correction states early;
- it prevents the project from over-focusing on data input screens before the operational flow is understood;
- it can be prototyped with mock data while still defining strong data/API contracts.

The Planner Workspace should show:

- planning period;
- demand sources;
- school/customer;
- ingredient;
- source demand;
- raw quantity;
- adjusted/effective quantity;
- orderable quantity;
- warning state;
- substitution/override indicators;
- supplier assignment status;
- procurement readiness;
- trace details.

---

## 5. Planner prototype guardrails

The first React planner prototype should use mock data or static fixtures.

It may:

- display realistic demand, requirement, warning, and supplier-assignment examples;
- include filter, grouping, selection, detail panel, and summary behavior;
- simulate user actions such as review, flag, override draft, substitution draft, and ready-for-procurement state;
- use fixture-based calculation outputs to reveal UI and data-contract needs.

It must not:

- create Supabase migrations;
- create production RPCs;
- make authoritative calculations;
- encode hidden business rules that are not documented;
- silently decide supplier assignment;
- create purchase orders or dispatch documents;
- recreate Retool-style hidden state and JavaScript business logic.

---

## 6. Supporting prototype

The Master Data Review Workspace remains a supporting prototype.

It is important because planner accuracy depends on clean ingredient, unit, supplier, and recipe-line data. However, it should not displace the Planner Workspace as the first operational prototype.

Reference:

```text
docs/ui/master-data-review-workspace.md
```

---

## 7. UI standards to define later

- table density;
- Vietnamese labels;
- date format;
- quantity formatting;
- warning severity display;
- approval actions;
- unsaved changes pattern;
- export pattern;
- print layout.