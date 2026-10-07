# OPS ERP Current Context

**Status:** Active project memory

**Last updated:** 2026-10-07

**Authority:** Working context summary

**Accepted business baseline:** `010871bebb43f3883c77c5b9bf6954282053c93d` (merged PR #355).

**Planning/Procurement:** Business/application contract freeze **Owner-approved**; [canonical freeze](architecture/planning-procurement-business-freeze.md). Documentation task completes after its PR is approved/merged. UI/document polish remains open.

**Review required:** No — update whenever project direction, active scope, environment boundary, or blocking Product decisions change.

---

## 1. Project identity and objective

- Product name: OPS ERP
- Internal codename: Project Atlas
- Repository: `longpsu-bot/thuonghao-ops-erp`
- Source of truth: GitHub repository
- Primary stack: React + TypeScript + Supabase/PostgreSQL
- Delivery approach: workflow-led, contract-constrained, backend-authoritative, Codex-assisted

Atlas replaces OPS v1 incrementally with the smallest stable system that preserves daily catering operations, improves control, remains maintainable and transferable, and avoids unnecessary ceremony or cost.

The Application objective is explicit: **keep the operator surface aggressively simple while the backend carries required safety, audit, concurrency, calculation and recovery complexity.**

---

## 2. Governing architecture

Atlas uses `OPS_SYSTEM_MAP` v1.0:

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

The active cross-domain principle is:

> **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

[ATLAS-MODEL-PRINCIPLE-01](decisions/decision-atlas-model-convergence.md) and the [authority map through Procurement](architecture/atlas-authority-map-through-procurement.md) are implemented repository authority.

Operational gradient:

```text
upstream authored facts and generated support
→ derived current state
→ explicit human decisions
→ explicit external commitments
```

Do not add persisted lifecycle/status machinery where current state can be deterministically derived. Do not expose generated support objects as separate operator jobs unless a real business decision requires it.

PostgreSQL owns business facts, calculations, invariants, authorization, currentness, concurrency, idempotency, transaction boundaries and immutable evidence. React renders shaped contracts and coordinates interaction; it does not reconstruct ERP authority.

OPS v1 / Retool remains behavioral evidence only. Preserve its useful operational simplicity, but do not copy direct browser SQL, client-owned rules, destructive historical rewrites or optimistic success without authoritative readback.

---

## 3. Current repository status through Procurement

The Owner approved `PLANNING_PROCUREMENT_BUSINESS_FREEZE = APPROVED` after the completed connected rehearsal, Shopping List V2 A+ hosted acceptance and PR #355 merge. The [canonical freeze](architecture/planning-procurement-business-freeze.md) pins business authority, exact write/read/currentness boundaries and the journey through Procurement. It preserves the existing model-convergence result and current API amendments; it adds no lifecycle, schema or application behavior.

Shopping List `ATLAS_SHOPPING_LIST_V2` / **A+** is accepted: complete identity/currentness validation, quantity-only local proposals, **0 immediate import writes**, explicit Save required. [Design Language v3](ui/atlas-design-language-v3.md) and **11 persistent workbench owners** are current. Workspace switching retains each owner's local work/date; close/sign-out use owner guards; navigation writes no business facts.

Menu acceptance covers approved September reads and sync entry point; PO acceptance covers connected released-order read/retained context; PXK/reconciliation are smoke evidence. The freeze records the later Owner acceptance and supersedes earlier pending-status observations without rewriting historical evidence. UI/document presentation and behavior-preserving implementation remain open; Warehouse has not started.

---

## 4. Current operator workflow

Planning:

```text
Weekly Menu / Attendance / Pantry
Edit → Lưu
        ↓
automatic backend readiness/currentness
        ↓
Tạo nhu cầu / Cập nhật nhu cầu
        ↓
atomic generation + bound evidence
        ↓
Confirmed Need
Edit quantities / Shopping List local proposals → explicit Lưu
→ Tiếp tục phân bổ NCC (navigation only)
```

Procurement:

```text
Current saved Confirmed Need (quantity authority)
Generated review / supplier recommendations (advisory)
→ exact supplier allocation decision
→ Save
→ prepare purchase orders atomically (Need release + Handoff + split promotion + PO support)
→ review DRAFT PO
→ release each supplier PO explicitly
```

Recipe:

```text
Create Dish
→ two canonical typed Recipe roots generated
→ author/save Recipe
→ approved Menu use derives normal base lock
→ later change through Change Order
```

SYSTEM_DISH Change Orders use exact Dish + canonical School Type for Preview/Create/Supersede. School-specific paths retain exact School context.

---

## 5. UI/UX and engineering discipline

Current UI rules:

1. A first-time operator should understand the job, work context and main action quickly.
2. One business action is visually dominant at a normal state.
3. `Lưu` preserves authored work; genuine downstream commitments remain separate explicit actions.
4. Backend deterministic work stays internal instead of becoming operator ceremony.
5. Evidence/history/support detail uses progressive disclosure unless needed for the current task.
6. Vietnamese should read as natural operational language, not backend terminology.
7. React may restrict an action further because of dirty/invalid/busy/unknown-outcome state, but may never promote an action the backend denies.

Engineering complexity is also subject to the model principle. Preserve necessary safeguards for concurrency, unknown outcomes and commitments, but do not turn every UI interaction into another protocol or add acceptance/test infrastructure without demonstrated risk.

**Hosted review/test data should be minimal and purpose-built.** Do not build a miniature copy of the full catering business model merely to exercise the UI. Reuse existing Staging identity/reference data where safe, and create only the smallest business facts required for the operator journey being reviewed. Missing canonical business data should be handled as a reconciliation need, not by inventing a larger synthetic seed graph.

Storybook is developer/component evidence, not the preferred Product Owner review surface. Product review should use the persistent connected hosted Atlas Staging web app once the environment is reconciled and verified.

---

## 6. Current environment boundary

### Repository

Business baseline `main`: `010871bebb43f3883c77c5b9bf6954282053c93d`. PR #355 is merged. The hosted [connected app](https://thuonghao-ops-erp.pages.dev/) build manifest matches this clean SHA and Staging target.

### Atlas Staging

Project: `rnzxmxiiqgtdevzregff`

Read-only migration-ledger verification on 7 October 2026:

```text
migration count: 92
migration tip:   20261006112515_atlas_recipe_purchase_unit_read
```

Connected rehearsal and Shopping List acceptance are complete within the [freeze evidence limits](architecture/planning-procurement-business-freeze.md#21-accepted-hosted-evidence). This task writes no Staging data and deploys no migration; future deployment/data reconciliation remains separately controlled.

### Live OPS / Retool

Live OPS project `qnthofvccilhnefdcxnz` is a forbidden Atlas deployment target and remains operational continuity only. Retool remains unchanged and is evidence, not Atlas architecture authority.

---

## 7. Immediate roadmap

```text
PLANNING-PROCUREMENT-BUSINESS-FREEZE-01 → Owner review / PR merge
→ ATLAS-BACKEND-CONVERGENCE-02B → 02C → 02D (separate bounded tasks)
→ sufficiently certified backend baseline → Warehouse new-domain task

Parallel product lanes after freeze PR:
staff usage ~5–10 working days → ATLAS-UX-POLISH-02
ATLAS-DOCUMENT-SYSTEM-01 → PO / PXK / Dispatch / Attendance-import presentation
→ later document presentation freeze
```

The merged [#353 / 02A audit](architecture/atlas-backend-convergence-02a-audit.md) governs convergence. Business freeze does not authorize 02B; start it only after the freeze PR and separate bounded approval. Allocation precision asymmetry requires evidence before consolidation. No broad rewrite, migration squash or compatibility retirement without complete proof. Product tracks may run in parallel; their completion is not a prerequisite for 02B absent a real dependency. Restoring bug/security/performance fixes and compatible UX/document refinements remain permitted under the freeze's Class A–D change control.

---

## 8. Preferred delivery cycle for the next domain

For new capabilities such as Warehouse:

```text
Mission / capability / domain ownership
→ concrete operator job
→ lightweight workflow/UI exploration
→ genuine human decision boundary
→ minimum contract
→ authoritative backend
→ connected hosted UI
→ operator review
→ next thin vertical slice
```

Do not build an entire backend domain before proving its operator command boundaries, and do not build an entire frontend domain with the intention of adding authority later.

---

## 9. Update rule

Keep this file concise and current. Update it when the authoritative repository baseline, active roadmap, environment boundary or blocking Product decisions materially change.

Historical implementation reports, acceptance artifacts and old decision execution notes remain historical evidence and should not be rewritten merely to make the past look like the current state.
