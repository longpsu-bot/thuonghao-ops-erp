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
- Master Data Review Workspace UI spec
- Planner Workspace UI spec

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

1. Planner Workspace UI spec
2. Business Processes
3. Calculation Specification
4. Security Model
5. Rollout and Migration Plan
6. Business Glossary Vietnamese labels
7. Master-data review results after staff review

---

## 6. Current practical next prototype

Recommended immediate UI prototype:

```text
Planner Workspace React prototype
  → planning overview
  → demand source review
  → requirement review
  → adjustments and exceptions
  → supplier assignment preview
  → procurement readiness
  → planning summary
```

Reason: the planner is the daily operational decision center. It converts demand into actionable requirement readiness and exposes the workflow states that future data contracts, schema design, calculation rules, and backend commands must support.

The Planner Workspace should be created in React first because screen design will answer many unresolved questions about:

- what calculation outputs staff need to see;
- what warning and blocking states are operationally meaningful;
- how raw, adjusted, final, and orderable quantities should be presented;
- where traceability is needed;
- what table definitions must eventually support;
- what backend command boundaries are required;
- what belongs in master data versus transaction state.

This first React prototype must use mock data or static fixtures. It must not create Supabase migrations, production RPCs, or authoritative calculation logic.

The Master Data Review Workspace remains a supporting prototype. It is important, but it should not displace the planner as the first operational prototype.

---

## 7. Current likely first operational vertical

Recommended first operational workflow after planner contract review:

```text
Demand sources
  → planner workspace
  → reviewed requirements
  → procurement readiness
  → procurement planning
  → dispatch draft
```

Wholesale remains a strong candidate for the first live demand source because it is newer and has less dependency on full legacy recipe migration. However, the planner should be designed broadly enough to support catering, wholesale, pantry additions, and manual corrections.

---

## 8. Current sequencing decision

OPS ERP should use UI-led, contract-constrained design before Supabase schema implementation.

This means:

- React planner prototype comes before Supabase schema implementation;
- UI prototypes are allowed before final schema work;
- UI prototypes must not become hidden business logic;
- each screen must define read data, draft state, validation, warnings, backend commands, and eventual data contracts;
- Supabase schema and RPC implementation should begin only after the relevant workflow, UI states, rule behavior, and API contracts are sufficiently reviewed.

Rationale:

- table design should follow validated workflow needs;
- calculation rules depend on ingredient, unit, and recipe review;
- planner UI review exposes missing business states earlier than database-first work;
- data contracts prevent React from recreating Retool-style hidden state and JavaScript logic;
- premature schema design risks encoding old OPS v1 assumptions into OPS ERP.

---

## 9. Open blockers before Supabase implementation

- exact procurement aggregation level;
- role and permission matrix;
- requirement approval authority;
- correction process after release;
- first workflow ownership boundary between OPS v1 and OPS ERP;
- legacy data classification;
- staff review of ingredients, units, recipe quantities, and calculation-rule candidates;
- product owner review of Planner Workspace UI contract;
- React planner prototype review.

---

## 10. Update rule

This file should be updated whenever project direction, phase, accepted scope, or blocking decisions change.