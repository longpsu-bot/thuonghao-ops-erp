# OPS ERP Current Context

**Status:** Active project memory  
**Last updated:** 2026-07-12  
**Authority:** Working context summary  
**Review required:** No — update continuously as project state changes  

---

## 1. Project identity

- Product name: OPS ERP
- Internal codename: Project Atlas
- Repository: `longpsu-bot/thuonghao-ops-erp`
- Source of truth: GitHub repository
- Primary development approach: architecture-first, UI-led, contract-constrained, Codex-assisted implementation

---

## 2. Current architecture direction

- React + TypeScript frontend
- Supabase + PostgreSQL backend
- Supabase Auth for identity
- PostgreSQL/RPC for authoritative business logic
- Retool retained only for support, diagnostics, or emergency admin where useful
- OPS v1 remains operational during parallel rollout

---

## 3. Current foundation status

Completed baseline documents:

- Vision and Product Charter
- Business Model and Operating Flows
- Business Glossary
- Business Processes
- System Map
- Domain Model
- Module Specifications
- Calculation Specification
- Security Model
- API Contract Standard
- Development Guide
- Rollout and Migration Plan
- Master-data review package
- Vietnamese staff-facing master-data review package

---

## 4. Current accepted principles

1. Business before technology.
2. Architecture before implementation.
3. Use UI-led, contract-constrained design before Supabase schema implementation.
4. GitHub is the source of truth.
5. Codex implements bounded approved tasks.
6. React coordinates; backend decides.
7. Every operational quantity must be explainable.
8. Released documents must not be silently recalculated.
9. OPS v1 and OPS ERP coexist until workflows migrate safely.
10. No calculation behavior may exist as a hidden or hard-coded magic rule.

---

## 5. Current review priorities

Product owner review needed for:

1. Business Processes
2. Calculation Specification
3. Security Model
4. Rollout and Migration Plan
5. Business Glossary Vietnamese labels
6. Master-data review results after staff review

---

## 6. Current practical next prototype

Recommended immediate UI prototype:

```text
Master Data Review Workspace
  → ingredient review
  → unit and conversion review
  → recipe-line review
  → calculation-rule candidate review
```

Reason: staff are already reviewing ingredients, and the calculation engine depends on clean ingredient, unit, and recipe-line assumptions.

---

## 7. Current likely first operational vertical

Recommended first operational workflow after master-data review:

```text
Wholesale order
  → canonical demand
  → requirement review
  → procurement planning
  → dispatch draft
```

Reason: wholesale is a new demand source and can be built with less dependency on full legacy recipe migration.

---

## 8. Current sequencing decision

OPS ERP should use UI-led, contract-constrained design before Supabase schema implementation.

This means:

- UI prototypes are allowed before final schema work;
- UI prototypes must not become hidden business logic;
- each screen must define read data, draft state, validation, warnings, backend commands, and eventual data contracts;
- Supabase schema and RPC implementation should begin only after the relevant workflow, UI states, rule behavior, and API contracts are sufficiently reviewed.

Rationale:

- table design should follow validated workflow needs;
- calculation rules depend on ingredient, unit, and recipe review;
- UI review exposes missing business states earlier than database-first work;
- data contracts prevent React from recreating Retool-style hidden state and JavaScript logic;
- premature schema design risks encoding old OPS v1 assumptions into OPS ERP.

---

## 9. Open blockers before implementation

- exact procurement aggregation level;
- role and permission matrix;
- requirement approval authority;
- correction process after release;
- first workflow ownership boundary between OPS v1 and OPS ERP;
- legacy data classification;
- staff review of ingredients, units, recipe quantities, and calculation-rule candidates.

---

## 10. Update rule

This file should be updated whenever project direction, phase, accepted scope, or blocking decisions change.
