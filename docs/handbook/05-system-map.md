# OPS ERP Handbook
## 05 — System Map

**Document ID:** OPS-HANDBOOK-005  
**Status:** Baseline draft  
**Authority:** Architectural structure  
**Review required:** Yes — architecture review required before implementation  

---

## 1. Purpose

This document defines the high-level system map for OPS ERP. It translates the business operating model into major system areas without committing to detailed database schema or UI design.

---

## 2. System principle

OPS ERP is a modular monolith built on:

- React and TypeScript for the frontend;
- Supabase and PostgreSQL for the backend;
- GitHub as the source of truth;
- Codex as bounded implementation assistant.

Retool may remain as a support and diagnostic layer, but it is not the primary OPS ERP product.

---

## 3. High-level map

```text
Identity and Access
        ↓
Core Master Data
        ↓
Demand Sources
   ├── Catering Menu Demand
   ├── Wholesale Ingredient Demand
   ├── Pantry Additions
   └── Manual Adjustments
        ↓
Canonical Demand
        ↓
Recipe Resolution
        ↓
Effective Requirement Engine
        ↓
Requirement Review
        ↓
Procurement
        ↓
Receiving / Preparation
        ↓
Fulfilment and Dispatch
        ↓
Reporting, Audit, and Controls
```

---

## 4. Major system areas

### 4.1 Identity and Access

Owns users, roles, permissions, and access control.

### 4.2 Core Master Data

Owns stable reference data such as customers, schools, ingredients, suppliers, units, and dishes.

### 4.3 Demand

Owns business requests from catering and wholesale sources.

### 4.4 Recipes

Owns recipe versions and recipe lines used to convert catering dish demand into ingredient demand.

### 4.5 Adjustments

Owns substitutions, additions, removals, and quantity overrides.

### 4.6 Requirement Calculation

Owns derived ingredient requirements, traceability, warnings, aggregation, and orderable quantity calculation.

### 4.7 Procurement

Owns supplier assignment, purchase planning, purchase release, and supplier commitment tracking.

### 4.8 Fulfilment

Owns preparation, dispatch, delivery, shortage handling, and fulfilment confirmation.

### 4.9 Reporting and Control

Owns read models, dashboards, audit review, and exception monitoring.

### 4.10 Legacy Adapters

Own controlled read access to OPS v1 data during the coexistence period. Legacy adapters must prevent v3 modules from depending directly on messy v1 internals.

---

## 5. External systems

### 5.1 Google Sheets

Current source for menu planning. May remain during early migration but should eventually become either an import source or be replaced by native OPS ERP screens.

### 5.2 Retool

Current OPS v1 operational interface. In OPS ERP, Retool should be limited to admin, emergency support, and diagnostic utilities.

### 5.3 Supabase

Primary backend platform for authentication, database, RLS, database functions, and selected Edge Functions.

### 5.4 GitHub

Source of truth for documentation, code, migrations, instructions, and project history.

### 5.5 Codex

Implementation assistant that works from bounded tasks and repository instructions.

---

## 6. Data ownership rule

Each business concept must have one owning module. Other modules may read through approved views or API contracts but must not duplicate ownership.

Example:

- Demand owns customer requests.
- Recipes own recipe definitions.
- Requirement Calculation owns derived effective requirements.
- Procurement owns supplier commitments.
- Fulfilment owns dispatch and delivery execution.

---

## 7. API boundary principle

The frontend should call approved API contracts and backend commands. It should not directly encode business rules that are authoritative to operations.

Preferred access pattern:

```text
React UI
  → Typed client function
  → Supabase RPC or approved view
  → Domain tables and audit
```

---

## 8. Legacy coexistence map

```text
OPS v1 Retool / Google Sheets
        ↓
Existing Supabase public / ops_v2 objects
        ↓
OPS ERP legacy adapter views
        ↓
OPS ERP v3 modules
```

OPS ERP must not depend directly on Retool state, UI transformers, or temporary frontend logic.

---

## 9. Review questions

1. Which current OPS v1 workflows must remain operational during first rollout?
2. Which data should be referenced from v1 first instead of migrated immediately?
3. Should wholesale start entirely in OPS ERP while catering remains partly in OPS v1?
4. Which staff roles must access both v1 and v3 during coexistence?

---

## 10. Implementation note

This map is not a database design. Database schema must be derived later from the domain model and module specifications.
