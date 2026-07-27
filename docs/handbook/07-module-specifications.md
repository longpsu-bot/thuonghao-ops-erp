# OPS ERP Handbook
## 07 — Module Specifications

**Document ID:** OPS-HANDBOOK-007  
**Status:** Baseline draft  
**Authority:** Module ownership and boundaries  
**Review required:** Yes — architecture review required before implementation  

---

## 1. Purpose

This document defines the first-level modules of OPS ERP and what each module owns. It prevents business concepts from being duplicated across screens, SQL functions, or React components.

---

## 2. Module ownership rule

Each module owns its business concepts, write commands, validation rules, and audit events. Other modules may read through approved APIs or views but must not write directly into another module's internal tables.

---

## 3. Initial modules

| Module | Owns | Does not own |
|---|---|---|
| Identity and Access | users, roles, permissions | business quantities |
| Core Master Data | customers, schools, ingredients, units, suppliers, dishes | operational transactions |
| Demand | catering and wholesale demand documents | recipe math, procurement commitments |
| Recipes | recipe versions and recipe lines | one-time substitutions |
| Adjustments | substitutions, overrides, additions, removals | permanent recipe definitions |
| Requirement Calculation | raw/effective/orderable requirements, traces, warnings | supplier commercial commitments |
| Procurement | supplier assignment, purchase plans, purchase orders | customer delivery confirmation |
| Fulfilment | dispatch, delivery, shortages, returns | supplier master data |
| Reporting and Control | read models, exception reporting | authoritative writes |
| Legacy Adapters | controlled v1 read access | v3 business ownership |

---

## 4. Identity and Access

### Responsibilities

- user accounts;
- staff roles;
- access scopes;
- school/customer-level access;
- permission checks;
- account activation and deactivation.

### Backend authority

Permissions must be enforced by backend policies and RPC checks, not only by hiding UI controls.

---

## 5. Core Master Data

### Responsibilities

- customer and school records;
- delivery locations;
- ingredients;
- units;
- dishes;
- suppliers;
- supplier-ingredient eligibility.

### Design rule

Master data should be stable and reusable across catering, wholesale, procurement, and fulfilment.

---

## 6. Demand

### Responsibilities

- demand documents;
- demand lines;
- catering menu demand;
- wholesale ingredient demand;
- demand status lifecycle;
- demand source identity.

### Boundary

Demand records what the customer or school needs. It does not decide which supplier will provide the item.

---

## 7. Recipes

### Responsibilities

- recipe definitions;
- recipe versions;
- recipe lines;
- recipe applicability;
- recipe activation and locking.
- transactional full-draft BOM replacement;
- validation, Planning release, and successor correction;
- traceable recipe copy and reviewed draft-only workbook import.

### Boundary

Recipes define standard conversion from dish to ingredient. One-time substitutions and operational overrides belong to Adjustments.

The current connected boundary supports only a general Recipe root or one scoped by School Type. More specific applicability and precedence remain Requirement Planning decisions. Import may create draft proposal state but may not validate or release it automatically.

---

## 8. Adjustments

### Responsibilities

- substitutions;
- pantry additions;
- removals;
- quantity overrides;
- adjustment reasons;
- adjustment audit.

### Boundary

Adjustments change a specific operational context. They do not rewrite standard recipes unless explicitly promoted through a controlled recipe-change process.

---

## 9. Requirement Calculation

### Responsibilities

- recipe explosion;
- direct ingredient demand conversion;
- adjustment application;
- aggregation;
- unit normalization;
- rounding;
- orderable quantity calculation;
- warning generation;
- source trace.

### Boundary

The calculation module produces requirements. Procurement decides supplier commitments.

---

## 10. Procurement

### Responsibilities

- supplier eligibility;
- supplier assignment;
- purchase plan;
- purchase order release;
- supplier confirmation;
- procurement correction.

### Boundary

Procurement may not silently change demand or recipes. Changes to source requirements must be explicit corrections or approved adjustments.

---

## 11. Fulfilment

### Responsibilities

- dispatch planning;
- dispatch release;
- delivery confirmation;
- shortage recording;
- fulfilment correction;
- customer-facing dispatch documents.

### Boundary

Fulfilment records what was prepared, dispatched, and delivered. It does not own supplier assignment.

---

## 12. Reporting and Control

### Responsibilities

- read models;
- exception dashboards;
- audit review;
- reconciliation views;
- management reporting.

### Boundary

Reporting must not be the source of truth for operational changes.

---

## 13. Legacy Adapters

### Responsibilities

- controlled views over OPS v1 objects;
- migration support;
- historical reference;
- v1-to-v3 mapping.

### Boundary

Legacy adapters are temporary. New OPS ERP modules must not be designed around Retool state or v1 UI implementation details.

---

## 14. Required module documents later

Each implemented module should eventually have:

- `README.md`;
- business rules;
- API contracts;
- UI states;
- test cases;
- migration notes;
- Codex instructions if module-specific behavior is complex.

---

## 15. Open module questions

1. Should inventory be a full module in MVP or reserved until after procurement/dispatch stabilizes?
2. Should customer portal belong inside Demand or become a future external channel module?
3. Should QA/food safety be a separate module or part of Fulfilment initially?
