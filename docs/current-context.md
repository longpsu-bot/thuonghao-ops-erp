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
- Primary development approach: architecture-first, Codex-assisted implementation

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

---

## 4. Current accepted principles

1. Business before technology.
2. Architecture before implementation.
3. GitHub is the source of truth.
4. Codex implements bounded approved tasks.
5. React coordinates; backend decides.
6. Every operational quantity must be explainable.
7. Released documents must not be silently recalculated.
8. OPS v1 and OPS ERP coexist until workflows migrate safely.

---

## 5. Current review priorities

Product owner review needed for:

1. Business Processes
2. Calculation Specification
3. Security Model
4. Rollout and Migration Plan
5. Business Glossary Vietnamese labels

---

## 6. Current likely first vertical

Recommended first vertical workflow:

```text
Wholesale order
  → canonical demand
  → requirement review
  → procurement planning
  → dispatch draft
```

Reason: wholesale is a new demand source and can be built with less dependency on full legacy recipe migration.

---

## 7. Open blockers before implementation

- exact procurement aggregation level;
- role and permission matrix;
- requirement approval authority;
- correction process after release;
- first workflow ownership boundary between OPS v1 and OPS ERP;
- legacy data classification.

---

## 8. Update rule

This file should be updated whenever project direction, phase, accepted scope, or blocking decisions change.
