# OPS ERP Current Context

**Status:** Active project memory

**Last updated:** 2026-08-11

**Authority:** Working context summary

**Current authoritative `main`:** `e542e263e3bb672eb2967af0b3d54bfd8771df75`

**Review required:** No — update whenever project direction, active scope, environment boundary, or blocking Product decisions change.

---

## 1. Project identity

- Product name: OPS ERP
- Internal codename: Project Atlas
- Repository: `longpsu-bot/thuonghao-ops-erp`
- Source of truth: GitHub repository
- Primary development approach: **workflow-led, contract-constrained, backend-authoritative, Codex-assisted**

Atlas is intended to replace OPS v1 incrementally with the smallest stable system that preserves daily catering operations, improves process control, remains maintainable and transferable, and avoids unnecessary complexity or cost.

The Application objective is now explicit: **keep the operator surface aggressively simple while allowing the backend to carry the necessary safety and workload complexity.**

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

The authority order is unchanged. Business architecture defines ownership and boundaries; technology remains subordinate.

Before freezing a detailed command contract, prove the operator job, necessary information, meaningful exceptions and genuine human decision boundaries through lightweight workflow/UI exploration.

Workflow sketches, fixtures, mock screens and prototypes are discovery artifacts, not authoritative Application behavior.

The connected React Application follows accepted contracts and read models. React coordinates interaction and renders authoritative results; it does not own ERP authority.

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
→ operator / Product review
→ refinement from observed need
→ next thin vertical slice
```

Do not build an entire backend domain before proving its operator command boundaries, and do not build an entire frontend domain with the intention of adding authority later.

For later domains such as Warehouse, prefer one operational slice at a time: receiving workflow → exploration → contract → backend → connected UI → operator review, then proceed to discrepancy handling, stock intake, or another proven need.

---

## 4. Backend gatekeeper / operator-surface rule

The backend is the **gatekeeper and workload manager serving the operator**.

Backend authority includes:

- authentication and authorization;
- authoritative validation and calculations;
- currentness/concurrency;
- lifecycle integrity;
- audit, lineage and immutable evidence;
- idempotency and recovery;
- transaction integrity;
- internal workload partitioning/chunking.

Normal UI exposes:

- the operator's business job;
- current work context;
- meaningful exceptions;
- authored facts;
- genuine business decisions/commitments;
- necessary corrections or safety acknowledgements.

A backend state does not automatically deserve a visible UI state. API limits, versions, fingerprints, capability codes, checksums, internal validation stages and other implementation detail remain out of the normal reading flow.

React may make a backend-authorized action stricter because of local dirty/invalid/busy/unknown-outcome state, but it must never promote an action that the backend denies.

---

## 5. Current UI/UX acceptance rules

ATLAS-UI-STANDARD-02 refines D-034/D-035 without rewriting their history.

Current workbench rules are:

1. A first-time operator should understand the job, scope, editable target and main action within approximately five seconds.
2. Every table-oriented workbench has useful text search/filter unless a documented reason shows search has no value.
3. Work context is visible; users should not infer what they are working on from table rows or technical IDs.
4. One business action is visually dominant at a normal state.
5. `Lưu` preserves authored work; downstream commitment uses a separate action only when it is a genuine human business decision.
6. Backend deterministic work remains internal rather than becoming extra operator ceremony.
7. Evidence/history/support detail uses progressive disclosure unless it is directly needed for the current task.
8. Vietnamese is authored as natural operational language, not translated from backend terminology.
9. Normal body text is approximately 14–15 px, table text 13–14 px, labels 13–14 px, helper text 12–13 px, and normal desktop controls approximately 38–40 px; touch targets are approximately 44 px where practical.
10. Use spacing, hierarchy and dividers before adding nested bordered cards.
11. Export affordances may exist before XLSX/PDF contracts are finalized; do not freeze speculative file schemas while read models and templates are still moving.
12. Green CI is necessary but not sufficient Product acceptance.

OPS v1 / Retool remains useful workflow evidence for explicit Save, fast search, dense practical tables, direct Vietnamese task language and familiar operator sequences. It is not architecture authority; do not copy direct SQL, JavaScript state authority, client-side calculations, hidden chained write authority or Retool component structure.

---

## 6. Current technical/environment boundary

- React + TypeScript: connected Application UI
- Supabase + PostgreSQL: authoritative backend and persistence
- Supabase Auth: identity
- PostgreSQL/RPC: authoritative validation, authorization, lifecycle, calculations, lineage, audit, idempotency and transaction integrity
- GitHub: source of truth and bounded delivery workflow
- Atlas Staging: separate hosted non-production environment
- OPS v1 / Retool: retained operational continuity and workflow evidence

Read-only environment check on 11/08/2026:

```text
Atlas Staging rnzxmxiiqgtdevzregff
migrations:              33
atlas_api:               present
atlas_api functions:     79

Live OPS qnthofvccilhnefdcxnz
atlas_api:               absent
atlas_admin:             absent
Atlas roles:             0
```

Atlas Staging is therefore not automatically assumed to match the current repository head. Hosted deployment remains a separate controlled action.

Live OPS remains a forbidden Atlas deployment target.

---

## 7. Planning status

Current Planning governance and implementation:

- D-034 — Atlas Modern Operations UI: visual direction.
- D-035 — Workflow-First Operator UX: happy-path-first Application presentation.
- D-036 — Planning Completion and Commitment Boundaries: source Save, deterministic preflight and atomic Need Generation boundary.
- PLANNING-CONTRACT-01 — merged at `f8c5b36a1c9cf24d58f67bf2c82ed7c9d4715889`.
- UI-QUALITY-02AB-UX — merged at `9818efe4ec1eda7b1b5879494a382921afc758b7`.
- D-037 / UI-QUALITY-02C-B — merged through PR #189 at `e542e263e3bb672eb2967af0b3d54bfd8771df75`.

Current human-facing Planning intent:

```text
Weekly Menu / Attendance / Pantry
Edit → Lưu
        ↓
automatic backend readiness/currentness
        ↓
Tạo nhu cầu / Cập nhật nhu cầu
        ↓
atomic backend generation + validation + release + Confirmed Need materialization
        ↓
Confirmed Need
Edit quantities → Lưu → Chuyển sang lên đơn
```

For Confirmed Need, backend readback authoritatively controls Save/Release eligibility; React may only restrict further. Release creates no Purchase Handoff, supplier assignment or purchase order yet.

---

## 8. Immediate roadmap

Current Product/UI stabilization order:

```text
ATLAS-UI-STANDARD-02
→ UI-QUALITY-03A Recipe / BOM first-user redesign
→ UI-QUALITY-03B Recipe Change Order first-user redesign
→ UI-QUALITY-03C remaining connected Admin consolidation
→ PLANNING-UX-01 / cross-flow operator review
→ hosted operator/security rehearsal
→ explicit decision on CMD-03 / Purchase Handoff
```

The Recipe/BOM and Recipe Change Order jobs are intentionally separate thin slices. Do not combine them into one broad Admin rewrite.

The immediate Recipe/BOM redesign must begin from the operator job and use v1 only as workflow evidence. It should not preserve version/validation/successor mechanics in the normal UI merely because those mechanics exist in the backend.

CMD-03, supplier allocation, purchase-order creation, Warehouse, Production/QA and Dispatch expansion remain deferred until the current stabilization gates are accepted.

---

## 9. Complexity and validation discipline

Do not design hypothetical capability families, lifecycle states, APIs, tables, abstractions, search frameworks, export frameworks or test frameworks merely because they may eventually be useful.

For cross-version backend consolidation or lifecycle-boundary changes, use the bounded integration discipline established by Planning, including affected SQL suites, browser-key journey verification and one ready-state Full Integration where warranted.

UI-only work should use focused UI tests, typecheck, format/build, UI Review Export, accessibility/interaction review and the existing bounded CI appropriate to the changed surface.

If a UI task reveals that the backend contract itself forces false human ceremony, stop the UI task and correct the workflow/business boundary instead of chaining lifecycle commands in React.

The objective is fewer correction loops and simpler operator work, not more testing or framework infrastructure.

---

## 10. Update rule

Keep this file concise and current. Update it when the authoritative baseline, delivery method, active roadmap, environment boundary or blocking Product decisions materially change.

Historical recovery files, completed implementation records and old decisions remain historically accurate rather than being rewritten to match later methodology.
