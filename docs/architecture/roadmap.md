# Atlas Roadmap

**Purpose:** Concise delivery order and current status. Detailed contracts, decisions and implementation records remain the scope authority.

**Current repository baseline:** `11408a0b0ed5d3938321c90f38fd8a2f9c1ad587`

## Status legend

- ✅ Complete / merged
- 🟡 Current gate
- ⬜ Not started
- ↘️ Deferred / separately governed

## Governing direction

- ✅ ARCH-001 — OPS ERP Business Architecture
- ✅ ARCH-002 — Atlas System Map
- ✅ Atlas Vision
- ✅ Workflow-led, contract-constrained, backend-authoritative delivery
- ✅ [ATLAS-MODEL-PRINCIPLE-01](../decisions/decision-atlas-model-convergence.md) — **facts explicit, state derived, supporting objects generated**
- ✅ [Authority map through Procurement](atlas-authority-map-through-procurement.md)

Normal delivery shorthand:

```text
operator job
→ minimum contract
→ authoritative backend
→ connected UI
→ operator/Product review
```

Do not create persisted lifecycle/status machinery or operator ceremony merely because an object can conceptually have a state.

## Repository implementation through Procurement

### Master Data / Recipe

- ✅ Master Data foundation and connected Admin workflows
- ✅ Recipe/BOM authoring and Change Orders
- ✅ Canonical typed Recipe roots generated with Dish creation
- ✅ Effective Recipe contract and atomic two-scope Dish copy — PR #257
- ✅ ATLAS-MODEL-CONVERGENCE-01 — PR #258 merged as `11408a0b0ed5d3938321c90f38fd8a2f9c1ad587`
- ✅ Repository convergence acceptance: **56 / 56 PASS**
- ✅ A07 true SYSTEM_DISH command context incorporated into #258; component PR #259 closed as superseded
- ✅ A12 per-revision legacy issuance truth incorporated into #258; component PR #260 closed as superseded

### Planning

- ✅ Weekly Menu
- ✅ Attendance, including default-derived working proposals and explicit zero
- ✅ Pantry, including explicit no-additions
- ✅ Derived Planning readiness/currentness
- ✅ Atomic Need Generation and bound calculation/source evidence
- ✅ Selective Confirmed Need continuity
- ✅ Confirmed Need Save and Release boundary

Normal Planning route:

```text
Menu / Attendance / Pantry
→ consequential Save
→ derived readiness/currentness
→ Need Generation
→ Confirmed Need decision
→ Release / Chuyển sang lên đơn
```

### Procurement

- ✅ Generated purchase review remains advisory
- ✅ Exact saved supplier splits are explicit human decisions
- ✅ Rebalance is advisory until Apply + Save
- ✅ Purchase preparation composes release/Handoff/promotion/PO-draft support atomically
- ✅ PO draft/successor support is generated
- ✅ PO freshness/release eligibility is derived
- ✅ Each official PO release is an explicit supplier commitment with immutable released content

## Current gate — Atlas Staging parity and hosted review

### Observed Staging state

Atlas Staging project: `rnzxmxiiqgtdevzregff`

Latest read-only observation on 6 September 2026:

```text
migration tip:                    20260904081048_master_data_creation_ux_02
new effective Recipe APIs:        0 / 4
canonical School Types active:    2 / 2
active Dishes:                    2
canonical typed Recipe contexts:  0 / 4 ready roots
legacy/general Recipe roots:      2
synthetic-type Recipe roots:      1
```

The managed Staging identity/foundation records are already present. Do not create another elaborate seed/package layer merely to make the UI reviewable.

### Current sequence

```text
🟡 Staging migration + Recipe-data reconciliation audit
→ separately authorized protected migration/data action
→ read-only hosted verification
→ persistent connected Atlas Staging web app
→ Product Owner review on the hosted app
→ bounded UI/UX PR from observed findings
→ connected Admin → Planning → Procurement rehearsal
→ PLANNING-PROCUREMENT-FREEZE-01
→ Warehouse
```

### Review-data rule

Hosted review data should be **minimal and purpose-built**:

- reuse existing managed Staging identity/reference data where safe;
- create only the smallest business facts needed for the operator journey under review;
- do not recreate the full catering business model as a synthetic seed graph;
- do not invent canonical Recipe content merely to satisfy code paths;
- distinguish missing business data from missing technical support;
- prefer operator-authored review facts over increasingly elaborate fixture packages.

Storybook and GitHub Pages are developer/mock evidence only. The preferred Product Owner review surface is the persistent connected hosted Atlas Staging application.

## Next domain after freeze

### Warehouse

⬜ Warehouse has not started.

Start only after Planning/Procurement is frozen and the hosted connected path is reviewed.

Use thin operational slices:

```text
receiving job
→ workflow exploration
→ minimum receiving contract
→ authoritative backend
→ connected hosted UI
→ operator review
```

Do not pre-build a generic warehouse-management lifecycle.

## Deferred / separately governed

- ↘️ Attendance and Confirmed Need XLSX-assisted bulk authoring
- ↘️ `DISH-RICE-01` Menu-derived rice accompaniment until Product semantics are defined
- ↘️ Conditional supplier-removal semantics until a concrete operator case requires it
- ↘️ Production/QA and Dispatch expansion
- ↘️ Any additional compatibility retirement that is not required by the normal operator path

## Environment boundary

- Atlas Staging is non-production and remains **NOT READY** until the current parity/reconciliation gate is completed.
- Live OPS project `qnthofvccilhnefdcxnz` is a forbidden Atlas deployment target.
- OPS v1 / Retool remains operational continuity and workflow evidence, not Atlas architecture authority.

## Update rule

Keep this roadmap short. Record only current delivery order, completed major gates, active blockers and explicitly deferred work. Historical PR-by-PR detail belongs in implementation records and Git history, not in the active roadmap.
