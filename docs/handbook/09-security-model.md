# OPS ERP Handbook
## 09 — Security Model

**Document ID:** OPS-HANDBOOK-009  
**Status:** Baseline draft  
**Authority:** Security, access, and data protection model  
**Review required:** Yes — role review required before authentication implementation  

---

## 1. Purpose

This document defines the initial security model for OPS ERP.

Security must be designed before implementation because the system will contain operational, supplier, customer, and pricing-sensitive information.

---

## 2. Security principle

Frontend hiding is not security.

Permissions must be enforced by:

- Supabase Auth;
- PostgreSQL Row Level Security where appropriate;
- backend functions and RPC validation;
- audit records for sensitive actions.

---

## 3. Initial role model

Candidate roles:

| Role | Purpose |
|---|---|
| ADMIN | Full configuration and emergency access |
| MANAGEMENT | Read broad operational data and approve key actions |
| PLANNING | Manage menu, demand, attendance, and requirement review |
| PURCHASING | Manage supplier assignment and purchase orders |
| WAREHOUSE | Receiving, preparation, stock-related workflows |
| DISPATCH | Dispatch and delivery workflows |
| QA | Quality assurance and food-safety records |
| CLIENT_SCHOOL | Future customer/school limited access |
| READ_ONLY | View-only internal access |

---

## 4. Access scopes

Access may be scoped by:

- role;
- module;
- customer;
- school;
- region;
- date range;
- document status;
- action type.

---

## 5. Sensitive actions

Sensitive actions must require explicit permission and audit:

- create or edit user roles;
- change master data;
- modify recipe versions;
- apply quantity override;
- apply substitution;
- approve requirements;
- release purchase orders;
- cancel purchase orders;
- release dispatch documents;
- correct released documents;
- change supplier assignment after approval;
- export sensitive data.

---

## 6. Authentication

Initial authentication should use Supabase Auth.

Allowed login methods should be decided before implementation:

- email/password;
- magic link;
- Google login;
- invited staff accounts.

For MVP, invited staff accounts are preferred.

---

## 7. Authorization

Authorization must be checked in backend functions for write actions.

The React frontend may use permission metadata to simplify the UI, but backend validation remains authoritative.

---

## 8. Row Level Security

RLS should be applied where it materially protects data access.

Tables containing user, customer, operational, or supplier-sensitive data should not be broadly exposed to frontend clients.

The preferred pattern is:

```text
Frontend
  → approved view or RPC
  → backend permission check
  → internal domain tables
```

---

## 9. Service role rule

The Supabase service-role key must never be placed in frontend code, browser-accessible environment variables, or public repositories.

Service-role operations may only run in controlled backend contexts.

---

## 10. Audit model

Audit records should capture:

- actor;
- timestamp;
- operation;
- affected entity;
- previous value where practical;
- new value where practical;
- reason;
- source interface;
- request identifier if available.

---

## 11. Emergency access

Emergency admin access must be possible but should be limited, auditable, and reviewable.

Emergency actions should not become the normal operating workflow.

---

## 12. Offboarding

When staff leave the company, access should be disabled promptly.

The system should preserve historical audit attribution rather than deleting user identities used in prior transactions.

---

## 13. Review questions

1. Which exact staff members or positions belong to each role?
2. Should schools/customers have portal access in MVP or later?
3. Which actions require management approval?
4. Should purchase order release require a second approver?
5. Which exports are sensitive?
6. What emergency access procedure should management accept?

---

## 14. Implementation note

Codex must not implement authentication or authorization without reading this document and any future module-specific permission matrix.
