# Atlas Roadmap

**Purpose:** Concise delivery order and current status. Detailed contracts, decisions and implementation records remain the scope authority.

**Accepted business baseline:** `010871bebb43f3883c77c5b9bf6954282053c93d` (PR #355).

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
- ✅ [Planning–Procurement Business Freeze](planning-procurement-business-freeze.md) — Owner-approved business/application contract; documentation closeout pending this PR's approval/merge

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
- ✅ Shopping List V2 A+ hosted acceptance: whole-workbook quantity-only local proposals; explicit Save remains required

Normal Planning route:

```text
Menu / Attendance / Pantry
→ consequential Save
→ derived readiness/currentness
→ Need Generation
→ Confirmed Need decision
→ Save → Tiếp tục phân bổ NCC (navigation only)
→ exact Allocation Save → atomic purchase preparation
→ independent supplier PO release
```

### Procurement

- ✅ Generated purchase review remains advisory
- ✅ Exact saved supplier splits are explicit human decisions
- ✅ Rebalance is advisory until Apply + Save
- ✅ Purchase preparation composes release/Handoff/promotion/PO-draft support atomically
- ✅ PO draft/successor support is generated
- ✅ PO freshness/release eligibility is derived
- ✅ Each official PO release is an explicit supplier commitment with immutable released content

### Persistent Workspace v2

- ✅ D-048 production implementation merged in PR #351
- ✅ Persistent mounted workbenches with local context, guarded close/sign-out and bounded Need → Procurement handoff
- ✅ Eleven operator-job owners and connected hosted workspace acceptance; [D-048](../decisions/decision-atlas-persistent-workspace.md) ownership preserved

## Current gate — business freeze record

### Accepted connected baseline

Atlas Staging project: `rnzxmxiiqgtdevzregff`

Current technical identifiers verified read-only on 7 October 2026; the Owner supplied completed connected rehearsal and Shopping List acceptance:

```text
migration tip:         20261006112515_atlas_recipe_purchase_unit_read
migration lineage:     92 hosted / 92 repository migrations
hosted commit:         010871bebb43f3883c77c5b9bf6954282053c93d
hosted target:         rnzxmxiiqgtdevzregff
operator rehearsal:    accepted through Procurement; PO read/context and PXK/reconciliation smoke limits retained
Shopping List:         ATLAS_SHOPPING_LIST_V2 / A+; accepted hosted import/discard; no immediate business writes
presentation baseline: Atlas Design Language v3; 11 persistent workbench owners
```

The [connected Staging app](https://thuonghao-ops-erp.pages.dev/) serves the accepted main baseline. The [canonical freeze](planning-procurement-business-freeze.md#21-accepted-hosted-evidence) records the later completed Owner acceptance and supersedes the dated pending rehearsal status without rewriting historical observations. This documentation task performs no business writes or deployment.

### Current sequence

```text
✅ Staging parity + read-only verification
→ ✅ persistent connected Staging deployment
→ ✅ connected Planning / Procurement rehearsal + Shopping List V2 A+ acceptance
→ ✅ Product decision: PLANNING_PROCUREMENT_BUSINESS_FREEZE = APPROVED
→ 🟡 PLANNING-PROCUREMENT-BUSINESS-FREEZE-01 documentation approval/merge
→ parallel product and backend lanes below
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

## Parallel / next lanes after freeze PR

- ⬜ Staff usage of Atlas v3 for approximately **5–10 working days** → `ATLAS-UX-POLISH-02`, using observed workflow/legibility evidence.
- ⬜ `ATLAS-DOCUMENT-SYSTEM-01` → PO, PXK, Dispatch, Attendance/import templates, common layout/branding/signature/header/footer and grouped-export rules → later document presentation freeze.
- ⬜ `ATLAS-BACKEND-CONVERGENCE-02B` → `02C` → `02D`, under separate bounded approvals and the merged [#353 / 02A audit](atlas-backend-convergence-02a-audit.md). First prove equivalence; investigate allocation precision before consolidation; retire nothing without complete compatibility proof.

UI and document tracks may proceed in parallel with backend convergence; their completion is not a prerequisite for 02B absent an actual dependency. Business freeze does not authorize 02B–02D implementation. Class A–D [change control](planning-procurement-business-freeze.md#23-change-control-after-freeze) governs all tracks. Design Language v3 and A+ are current presentation baselines, open to compatible explicit review; business semantics remain frozen.

## Next domain after backend certification

### Warehouse

⬜ Warehouse has not started.

Start only after the freeze PR and a backend baseline sufficiently certified for the new Warehouse domain boundary. This record designs no Warehouse contract or stock behavior; existing bounded School PXK is not Warehouse implementation.

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

- ↘️ Attendance XLSX-assisted bulk authoring
- ↘️ Multi-day Shopping List UI beyond the current exact-day workbench
- ↘️ `DISH-RICE-01` Menu-derived rice accompaniment until Product semantics are defined
- ↘️ Conditional supplier-removal semantics until a concrete operator case requires it
- ↘️ Production/QA and Dispatch expansion
- ↘️ Any additional compatibility retirement that is not required by the normal operator path

## Environment boundary

- Planning/Procurement business freeze is Owner-approved; repository closeout completes after this documentation PR's approval/merge. Accepted hosted evidence has the limits stated in the canonical freeze.
- Live OPS project `qnthofvccilhnefdcxnz` is a forbidden Atlas deployment target.
- OPS v1 / Retool remains operational continuity and workflow evidence, not Atlas architecture authority.

## Update rule

Keep this roadmap short. Record only current delivery order, completed major gates, active blockers and explicitly deferred work. Historical PR-by-PR detail belongs in implementation records and Git history, not in the active roadmap.
