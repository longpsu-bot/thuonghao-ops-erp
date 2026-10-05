# Atlas Roadmap

**Purpose:** Concise delivery order and current status. Detailed contracts, decisions and implementation records remain the scope authority.

**Current repository baseline:** `e533f4c0c174389d209fbe361b725e12adaeeb4b`

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
- ✅ Exact-day Shopping List XLSX export and quantity-only local import proposal

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

### Persistent Workspace v2

- ✅ D-048 production implementation merged in PR #351
- ✅ Persistent mounted workbenches with local context, guarded close/sign-out and bounded Need → Procurement handoff
- 🟡 Connected hosted operator certification remains pending

## Current gate — connected hosted rehearsal

### Observed Staging state

Atlas Staging project: `rnzxmxiiqgtdevzregff`

Verified on 5 October 2026 under ATLAS-STAGING-PARITY-REHEARSAL-01:

```text
migration tip:         20261005032608_atlas_shopping_list_export_read
migration lineage:     91 / 91 repository migrations; no additional gap
catalog/security:      verified; 115 Atlas API functions
business-data writes:  0; all 113 Atlas table fingerprints unchanged
hosted commit:         e533f4c0c174389d209fbe361b725e12adaeeb4b
hosted target:         rnzxmxiiqgtdevzregff
operator rehearsal:    pending approved operator sign-in
```

The [connected Staging app](https://thuonghao-ops-erp.pages.dev/) already serves the baseline through the existing Cloudflare Pages integration. Managed identity, reference and historical review facts exist; no new seed layer is needed. See [parity and rehearsal evidence](../testing/atlas-staging-connected-rehearsal.md) for verification limits and the pending matrix.

### Current sequence

```text
✅ Staging parity + read-only verification
→ ✅ persistent connected Staging deployment
→ 🟡 approved operator sign-in
→ connected Admin → Planning → Procurement / PO / PXK rehearsal
→ bounded disposition of observed findings + Product/Architecture review
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

- ↘️ Attendance XLSX-assisted bulk authoring
- ↘️ Multi-day Shopping List UI beyond the current exact-day workbench
- ↘️ `DISH-RICE-01` Menu-derived rice accompaniment until Product semantics are defined
- ↘️ Conditional supplier-removal semantics until a concrete operator case requires it
- ↘️ Production/QA and Dispatch expansion
- ↘️ Any additional compatibility retirement that is not required by the normal operator path

## Environment boundary

- Atlas Staging parity is verified; **freeze readiness remains NOT READY** until the connected operator rehearsal and Product/Architecture review pass.
- Live OPS project `qnthofvccilhnefdcxnz` is a forbidden Atlas deployment target.
- OPS v1 / Retool remains operational continuity and workflow evidence, not Atlas architecture authority.

## Update rule

Keep this roadmap short. Record only current delivery order, completed major gates, active blockers and explicitly deferred work. Historical PR-by-PR detail belongs in implementation records and Git history, not in the active roadmap.
