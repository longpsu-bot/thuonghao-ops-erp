# OPS ERP Current Context

**Status:** Active project memory  
**Last updated:** 2026-08-10
**Authority:** Working context summary  
**Planning contract baseline:** `f8c5b36a1c9cf24d58f67bf2c82ed7c9d4715889`
**Review required:** No — update whenever project direction, active scope, or blocking decisions change.

---

## 1. Project identity

- Product name: OPS ERP
- Internal codename: Project Atlas
- Repository: `longpsu-bot/thuonghao-ops-erp`
- Source of truth: GitHub repository
- Primary development approach: **workflow-led, contract-constrained, backend-authoritative, Codex-assisted**

Atlas is intended to replace OPS v1 incrementally with the smallest stable system that preserves operational continuity, improves process control, remains maintainable and transferable, and avoids unnecessary complexity or cost.

---

## 2. Governing architecture

Atlas continues to use `OPS_SYSTEM_MAP` v1.0:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command/Event
→ Read Model
→ Application
→ Technology
```

This authority order is unchanged. Business architecture defines ownership and boundaries; technology remains subordinate.

The delivery lesson from Planning is narrower: before freezing a detailed command contract, prove the operator job, necessary information, meaningful exceptions, and genuine human decision boundaries through lightweight workflow/UI exploration.

Workflow sketches, fixtures, mock screens, and prototypes are **discovery artifacts**, not authoritative Application behavior.

The connected React Application still follows accepted contracts and read models. React coordinates interaction and renders authoritative results; it does not own ERP authority.

---

## 3. Preferred delivery cycle

For a new capability, prefer:

```text
Mission / capability / domain ownership
→ concrete operator job and workflow
→ lightweight UI/workflow exploration
→ genuine human decision boundaries
→ minimum business contract
→ authoritative backend boundary
→ connected Application UI
→ operator / product review
→ refinement from observed need
→ next thin vertical slice
```

Rules:

- steps involving workflow/UI exploration are discovery, not business authority;
- prototypes may use fixtures or mock data;
- prototypes must not hide authoritative calculations, authorization, or business transitions;
- detailed contracts should be shaped by proven workflow needs before implementation becomes deep;
- the accepted contract precedes authoritative backend and connected Application implementation;
- do not build an entire backend domain before proving its operator command boundaries;
- do not build an entire frontend domain and plan to “add the backend later.”

For later domains such as Warehouse, prefer one operational slice at a time: receiving workflow → exploration → contract → backend → connected UI → operator review, then move to discrepancy handling, stock intake, or another proven need.

---

## 4. Current technical boundary

- React + TypeScript: connected Application UI
- Supabase + PostgreSQL: authoritative backend and persistence
- Supabase Auth: identity
- PostgreSQL/RPC: authoritative validation, authorization, lifecycle, calculations, lineage, audit, idempotency, and transaction integrity
- GitHub: source of truth and bounded delivery workflow
- Atlas Staging: separate hosted non-production environment
- OPS v1 / Retool: retained operational workflow evidence and continuity boundary

Live OPS remains a forbidden Atlas deployment target.

Retool remains useful evidence for simple operator mental models, dense operational work, explicit Save, quick editing, exception handling, and Vietnamese task language. It is not architecture authority. Do not copy direct browser SQL, JavaScript state ownership, client-side calculation authority, hidden write orchestration, implicit authorization, or Retool component structure.

---

## 5. Current accepted product principles

1. Business before technology.
2. Business architecture defines ownership and boundaries.
3. **Workflow-led, contract-constrained, backend-authoritative.**
4. Workflow discovery precedes detailed contract freeze.
5. Accepted contracts precede authoritative implementation.
6. Deliver thin connected operational verticals rather than complete speculative domains.
7. React coordinates; backend decides.
8. Humans approve business commitments; systems validate deterministic system work.
9. Public human actions should normally represent authored operational facts, genuine business decisions/commitments, or necessary exceptions/corrections.
10. Every operational quantity must be explainable.
11. Released history and immutable evidence must not be silently rewritten or recalculated.
12. Authorization, lineage, audit, idempotency, and transaction integrity remain backend responsibilities.
13. Shared abstractions require an actual requirement, security/data-integrity need, realistic recovery need, or multiple proven consumers.
14. Prefer bounded local solutions over generic frameworks when sufficient.
15. Repeated fail → patch → fail cycles should trigger boundary reassessment rather than more patching.
16. OPS v1 and Atlas coexist until workflows migrate safely.

---

## 6. Planning status

The current Planning governance is:

- D-034 — Atlas Modern Operations UI: visual direction.
- D-035 — Workflow-First Operator UX: how Atlas should feel to operate.
- D-036 — Planning Completion and Commitment Boundaries: human versus deterministic system actions.
- PLANNING-CONTRACT-01 — merged at `f8c5b36a1c9cf24d58f67bf2c82ed7c9d4715889`; implements additive v2 consequential source Saves, automatic readiness preflight, and atomic Need Generation/materialization while retaining v1 compatibility during cutover.

Target operator flow:

```text
Weekly Menu / Attendance / Pantry
Edit → Save
        ↓
automatic readiness/currentness
        ↓
Tạo nhu cầu / Cập nhật nhu cầu
        ↓
atomic backend generation + deterministic validation + release + materialization
        ↓
Confirmed Need
human review / correction / commitment / release
```

Confirmed Need remains the first meaningful downstream human quantity-review and commitment boundary.

---

## 7. Immediate roadmap

```text
ATLAS-GOV-01 delivery-governance clarification
→ UI-QUALITY-02AB-UX
→ UI-QUALITY-02C
→ PLANNING-UX-01
```

`UI-QUALITY-02AB-UX` — active in draft PR #185; under root review and not yet accepted/merged. The draft cuts the connected Planning UI over to the merged v2 source-completion, automatic readiness, and atomic generation contracts.

Confirmed Need remains separate under `UI-QUALITY-02C`.

UI-QUALITY-03, hosted rehearsal, CMD-03 / Purchase Handoff, Procurement expansion, Warehouse, Production/QA, and Dispatch continue under separately bounded tasks.

---

## 8. Complexity and validation discipline

Do not design hypothetical capability families, lifecycle states, APIs, tables, abstractions, or test frameworks merely because they may eventually be useful.

For cross-version backend consolidation or lifecycle-boundary changes, validate the affected surface before the first ready-state Full Integration with:

```text
implementation
→ cross-version impact scan
→ current-platform catalog scan
→ all registered relevant SQL suites locally
→ complete affected browser-key journey locally
→ deferred-trigger / PostgREST COMMIT-boundary review where relevant
→ focused frontend/build validation
→ draft CI
→ one ready-state Full Integration
```

This is a targeted lesson from PLANNING-CONTRACT-01, not a universal heavy gate.

UI-only work should use focused UI tests, typecheck, format/build, review export, accessibility/interaction review, and the existing bounded CI appropriate to the changed surface.

The objective is fewer correction loops, not more testing infrastructure.

---

## 9. Update rule

Keep this file concise and current. Update it when the authoritative baseline, delivery method, active roadmap, environment boundary, or blocking product decisions materially change.

Historical recovery files, completed implementation records, and old decisions should remain historically accurate rather than being rewritten to match later methodology.
