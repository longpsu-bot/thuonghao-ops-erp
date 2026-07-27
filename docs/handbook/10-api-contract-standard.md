# OPS ERP Handbook
## 10 — API Contract Standard

**Document ID:** OPS-HANDBOOK-010  
**Status:** Baseline draft  
**Authority:** API and backend-command design standard  
**Review required:** Technical review before implementation  

---

## 1. Purpose

This document defines how OPS ERP APIs, Supabase RPC commands, and read models should be designed.

The goal is to prevent the React frontend from becoming tightly coupled to internal database tables or duplicating business rules.

---

## 2. API principle

A business action should be represented by one intentional command.

Example:

```text
Bad: frontend performs 5 separate table writes to apply a substitution
Good: frontend calls apply_requirement_substitution command once
```

---

## 3. API categories

### Read models

Read-only views or RPCs optimized for screens, reports, and review workflows.

### Commands

Backend-authoritative operations that validate and write business changes.

### Exports

Operations that generate documents or structured data for external use.

### Diagnostics

Admin-only tools used to inspect system health and data issues.

---

## 4. Naming convention

Preferred command naming:

```text
module_action_object
```

Examples:

- demand_create_wholesale_order
- adjustments_apply_substitution
- requirements_recalculate_for_date
- procurement_release_purchase_order
- fulfilment_release_dispatch

---

## 5. Request structure

Commands should accept structured JSON payloads where useful.

Minimum request standard:

- actor context resolved server-side where possible;
- explicit business identifiers;
- reason for sensitive changes;
- idempotency key for important operations if needed;
- client request identifier for audit if available.

---

## 6. Response structure

Command responses should include:

- success flag or status;
- affected entity identifiers;
- warnings;
- validation errors;
- updated version or timestamp;
- human-readable summary where useful.

---

## 7. Validation standard

Validation should occur in the backend for:

- permission;
- document status;
- required fields;
- quantity rules;
- business cut-off rules;
- release rules;
- cross-module invariants.

Frontend validation is allowed for usability but is not authoritative.

---

## 8. Error standard

Errors should be structured and consistent.

Candidate error fields:

- code;
- message;
- severity;
- field;
- entity_id;
- suggested_action;
- details.

---

## 9. Status lifecycle rule

Commands must respect document status lifecycles.

Example:

- draft documents may be edited;
- released documents require correction flow;
- cancelled documents may not be reused as active documents.

For Recipe Versions, the approved connected lifecycle is `DRAFT → VALIDATED → RELEASED_FOR_PLANNING → LOCKED`. Only drafts are mutable. Corrections create a successor with explicit version and line predecessors; release never rewrites an existing planning composition.

---

## 10. Audit rule

Sensitive commands must create audit events in the same backend transaction as the business change.

An atomic collection replacement, such as a draft BOM, must be one command containing the complete reviewed collection. The frontend must not issue per-row table writes.

---

## 11. Versioning

API contracts should be documented before implementation. Breaking changes must update the corresponding contract document and decision register.

---

## 12. Documentation required for each API

Each API contract should document:

- purpose;
- owning module;
- request fields;
- response fields;
- permission required;
- validation rules;
- side effects;
- audit behavior;
- error cases;
- test cases.

---

## 13. Frontend access rule

The React app should use typed client functions to call backend APIs. UI components should not directly embed SQL or Supabase calls to domain tables.

---

## 14. Implementation note

No new API or RPC should be implemented without a documented contract when the operation modifies business data.
