# School-Catering Procurement V1 — Connected Design

**Status:** Approved design for implementation planning  
**Date:** 2026-08-30  
**Baseline:** `main` at `9928ced99e9d0430801140ad29f86b716d594e59`  
**Authority:** OPS_SYSTEM_MAP v1.0 / `docs/architecture/arch-002-atlas-system-map.md`  
**Related contracts:** Planning Confirmed Need, Planning Purchase Handoff, Procurement domain, PA-05E wholesale Procurement, PA-06A application connection  
**Operational evidence:** OPS v1 Retool `PurchasePlanner` and Live OPS purchase-assignment / PO behavior  
**Target environment:** Atlas Staging only until explicit production authorization

## 1. Goal

Connect the accepted Planning workbench to a school-catering Procurement workflow that preserves the proven OPS v1 supplier-family splitting and rebalance behavior while enforcing Atlas ownership, auditability, concurrency safety, immutable released documents, and decision-first UX.

The first connected slice ends at a released supplier purchase order and PDF/export readiness.

```text
Planning Confirmed Need
→ released school-catering Purchase Handoff
→ Procurement Allocation Families
→ supplier split confirmation / rebalance
→ PO drafts
→ released supplier POs
→ PDF/export
```

## 2. Governing boundaries

### Planning owns

- Menu, Attendance, Pantry and Need Generation inputs;
- Confirmed Need quantity and controlled unit;
- school / delivery-location demand context;
- Purchase Handoff release and exact source lineage.

### Procurement owns

- supplier recommendation and supplier decision;
- supplier splits and split ratios;
- allocation-family revisions;
- PO draft materialization;
- supplier/date PO grouping;
- official PO numbering at release;
- supplier-facing released commitment snapshots.

### React owns

- presentation;
- filters, selection and local edit state;
- orchestration of backend-authorized next actions;
- PDF/export rendering from released authoritative read models.

React must not reconstruct authoritative family totals, supplier eligibility, rebalance rules, lifecycle gates, PO grouping, numbering or release eligibility from raw tables.

### Retool / OPS v1 role

Retool is operator-workflow evidence only. Atlas intentionally preserves these v1 operational properties:

- supplier work at a family level rather than raw recipe/BOM lines;
- `split_qty` + `split_ratio` semantics;
- family-atomic supplier replacement;
- exact family balance before PO creation;
- proportional rebalance when demand changes;
- PO grouping by supplier + service date;
- multi-school PO lines;
- bulk operational actions.

Atlas intentionally does **not** copy these v1 implementation properties:

- direct UI SQL as authority;
- broad public-function grants;
- silently rebuilding already committed PO content from current assignments;
- operator-supplied system identifiers;
- treating a generated PO as already supplier-confirmed.

## 3. Locked operating decisions

1. Planning uses a **one-click operator transition**. `Chuyển sang lên đơn` first releases Confirmed Need for Purchase Handoff, then materializes/releases the school-catering Purchase Handoff. If the second step fails, the valid intermediate state remains visible and retryable.
2. School-catering demand **may split across multiple suppliers**.
3. Atlas recommends the **highest-priority currently eligible supplier at 100%**, but no recommendation becomes authoritative until the operator confirms it.
4. Supplier priority is ranking evidence, **not a capacity percentage**. Atlas must not invent split percentages.
5. The Procurement working grain is an **Allocation Family** rather than each raw Purchase Handoff line.
6. Allocation Family identity is:
   `service_date + delivery_location_id + ingredient_id + unit_id`.
7. All underlying Purchase Handoff lines remain preserved as family contributions; aggregation never destroys Planning lineage.
8. Supplier splits must balance the family exactly before PO draft creation.
9. A family persists both split quantities and split ratios so later demand changes can produce proportional rebalance proposals.
10. PO grouping is **one PO per supplier + service date**, containing multiple schools / delivery locations and ingredients.
11. `Tạo đơn mua` creates **draft PO snapshots**. It does not create a supplier commitment.
12. `Phát hành cho NCC` is a separate command that creates the official supplier commitment.
13. Each PO is its own release transaction. Bulk release is application convenience over independent PO-release commands.
14. Release success means Atlas has recorded the official commitment. External email/message delivery is not part of the transactional success condition in V1.
15. The first slice stops at `RELEASED_TO_SUPPLIER`. Supplier acknowledgement, partial acceptance, rejection, cancellation, replacement and released-PO revision are deferred.
16. Official PO numbers are generated **server-side at release**, never typed by operators.
17. Atlas-wide direction: system/business codes are generated by the owning backend. UUID remains the internal identity. Existing Ingredient/Supplier create APIs requiring manual codes are separate Admin debt and are not expanded into this Procurement PR.

## 4. Allocation Family model

### 4.1 Stable aggregate

`PurchaseAllocationFamily` is the stable Procurement identity for one service-date / destination / ingredient / unit tuple.

Required stable identity:

- `purchase_allocation_family_id` UUID;
- `service_date`;
- `delivery_location_id`;
- `ingredient_id`;
- `unit_id`;
- created timestamp.

A unique invariant prevents two live families for the same exact tuple.

### 4.2 Family revision

`PurchaseAllocationFamilyRevision` is an immutable accepted/proposed Procurement snapshot.

It records at minimum:

- family revision ID;
- family ID;
- revision number;
- predecessor revision ID when applicable;
- authoritative family demand quantity;
- Purchase Handoff source fingerprint / version context;
- decision state;
- decision origin;
- confirmed actor/time when authoritative;
- command ID;
- created timestamp.

The family root points to one current authoritative revision through existing Atlas current-revision conventions or an equivalent narrowly enforced invariant.

### 4.3 Family contributions

`PurchaseAllocationFamilyContribution` records every exact Purchase Handoff line revision contributing to one family revision.

Required invariant:

```text
sum(contribution_quantity) = family_demand_quantity
```

Contribution rows preserve at least:

- Purchase Handoff batch/revision/line revision lineage;
- Confirmed Need lineage reachable through the handoff;
- contribution quantity;
- ingredient/unit/date/delivery-location equality proof.

### 4.4 Supplier splits

`PurchaseAllocationSupplierSplit` is an immutable supplier decision row belonging to an accepted family revision.

It records:

- family revision ID;
- supplier ID;
- split quantity;
- split ratio;
- recommendation/decision origin;
- supplier eligibility evidence/version used for validation;
- created timestamp.

Invariants:

- supplier appears at most once per family revision;
- every split quantity is positive;
- every supplier is active and eligible for the ingredient on the service date;
- split unit equals the family controlled unit;
- `sum(split_quantity) = family_demand_quantity` exactly;
- split ratios are server-calculated from accepted quantities.

Untouched recommendations are **not persisted** as authoritative splits.

## 5. Supplier recommendation and rebalance

### 5.1 Initial recommendation

For an unallocated family, the read model proposes:

- exactly one highest-priority eligible supplier, if unambiguous;
- proposed split = 100% of current family demand.

If no eligible supplier exists, return `NO_ELIGIBLE_SUPPLIER`.

If the highest priority is ambiguous under governed priority semantics, return `AMBIGUOUS_SUPPLIER_PRIORITY` rather than choosing arbitrarily.

### 5.2 Manual family save

The operator may keep the default supplier or split across multiple eligible suppliers.

`Lưu phân bổ` is family-atomic. The payload sends the intended supplier/quantity rows for one family. The backend re-reads current demand and eligibility and persists one complete successor family revision only if the whole family is valid.

There is no authoritative per-split-row save path.

### 5.3 Bulk default confirmation

`Xác nhận phân bổ đề xuất` confirms untouched priority-1 recommendations in a selected scope.

The backend processes each candidate family independently under the same validation contract. Families that changed, became ambiguous/ineligible, already contain a manual allocation, or no longer match the proposal are skipped and returned as exceptions.

No automatic write occurs on page load.

### 5.4 Rebalance

When authoritative family demand changes before PO release, Atlas uses the last accepted split ratios to produce a **proposal**, not an automatic authoritative rewrite.

Example:

```text
old demand: 100 kg
A = 60 kg / 60%
B = 40 kg / 40%

new demand: 120 kg
proposal:
A = 72 kg
B = 48 kg
```

Rounding rule:

- apply the governed controlled-quantity precision to all splits except the deterministic final split;
- the final split receives the exact residual;
- the final sum must equal family demand exactly.

If any prior supplier is no longer eligible, no automatic redistribution occurs. The family becomes `Cần phân bổ lại`.

## 6. Purchase Order model

Atlas reuses the existing `atlas_procurement.purchase_orders`, `purchase_order_revisions`, `purchase_order_lines` and `purchase_order_line_revisions` aggregate instead of building a second school-catering PO subsystem.

### 6.1 Backward-compatible extension

PA-05E wholesale behavior must remain valid and tested.

The shared PO aggregate receives only the minimum extensions required for school catering:

- a constrained PO context distinguishing existing wholesale commitments from school-catering commitments;
- school-catering supplier/date root identity sufficient to prevent duplicate current roots;
- header-level delivery location may be absent for school-catering multi-location POs;
- each school-catering PO line carries authoritative delivery location and service date;
- stable PO lines reference either the existing wholesale fulfilment-allocation line **or** one school-catering Allocation Family, never both;
- PO line revisions reference either the existing wholesale fulfilment-allocation line revision **or** one accepted school-catering supplier split, never both;
- explicit XOR constraints preserve referential integrity instead of generic polymorphic text lineage.

Wholesale command contracts continue to provide their existing single-destination snapshots and line lineage.

### 6.2 Draft identity

A school-catering PO root represents one supplier + service date.

A draft revision contains every current accepted supplier split for that supplier/date within the selected materialization scope, grouped into one PO line per Allocation Family.

Because an Allocation Family already includes destination + ingredient + unit + date, the PO line remains exactly traceable to one family and supplier decision.

### 6.3 Draft staleness

Draft staleness is derived, not a separately editable workflow flag.

A draft is stale when any source family revision / supplier split represented in the draft is no longer current.

A stale draft cannot be released.

`Tạo lại đơn cần cập nhật` creates a successor draft revision only for affected supplier/date PO roots.

Unrelated supplier/date drafts are preserved.

### 6.4 Released PO

`Phát hành cho NCC` validates one PO draft and then:

- allocates the official PO number server-side;
- records the immutable released revision/snapshot;
- records actor/time;
- emits domain/audit events;
- moves the PO to `RELEASED_TO_SUPPLIER`.

Released PO content is never regenerated by the first slice.

## 7. Automated numbering

Official PO numbering is backend-owned and transactional.

Requirements:

- request payload does not accept `document_number`;
- drafts may use UUID/internal non-official references only;
- official number is assigned only during successful release;
- uniqueness is database-enforced;
- replay returns the original number;
- concurrent release cannot allocate the same number twice;
- cancelled/aborted transactions may leave gaps; gaplessness is not a V1 requirement;
- formatting belongs to Procurement and is not implemented as a generic cross-domain numbering engine.

A suitable initial human-readable shape is `PO-YYYYMMDD-NNNN`, but the implementation may use the existing Atlas numbering convention if one is already canonical at execution time. The semantic requirement is automated, unique, immutable, auditable numbering at release.

The same design direction applies later to Ingredient, Supplier and other business codes, but those Admin corrections are out of this Procurement slice.

## 8. Commands

All commands use the established Atlas command envelope, authenticated subject resolution, capability checks, relational scope checks, idempotency receipts, optimistic concurrency, deterministic locking, safe responses, domain events and audit events.

### Planning

#### `release_school_catering_purchase_handoff(request jsonb)`

Consumes a Confirmed Need batch already in `RELEASED_FOR_PURCHASE_HANDOFF` and atomically materializes/releases the school-catering Purchase Handoff to Procurement.

It creates no supplier assignment or PO.

The existing `release_confirmed_needs_for_purchase_handoff` remains the first command behind the one-click Planning action.

### Procurement

#### `save_school_catering_supplier_allocation(request jsonb)`

Persists one complete accepted family revision with its exact contributions and supplier splits.

#### `confirm_school_catering_supplier_recommendations(request jsonb)`

Bulk-confirms untouched valid priority-1 proposals in a bounded service-date/school scope and returns exceptions for skipped families.

#### `create_school_catering_purchase_order_drafts(request jsonb)`

Materializes or refreshes only required school-catering PO draft roots/revisions for a selected service-date range from accepted balanced allocations.

It creates no released supplier commitment and no official number.

#### `release_school_catering_purchase_order(request jsonb)`

Re-validates one current non-stale PO draft, assigns its official number, records the release snapshot and moves the PO to `RELEASED_TO_SUPPLIER`.

Bulk release in React invokes this command independently per selected eligible PO.

## 9. Read APIs

### `get_school_catering_procurement_workbench(request jsonb)`

Primary allocation read model. It returns:

- selected scope / service period;
- Allocation Family rows;
- family identity and authoritative quantity;
- school/delivery location, ingredient and controlled unit;
- contribution lineage summary and explain detail;
- current accepted supplier splits;
- previous ratios when relevant;
- priority-1 recommendation;
- eligible supplier choices and priority evidence;
- allocation total, remaining quantity and state;
- stale/rebalance proposal state;
- blockers/warnings;
- backend-authorized next actions and disabled reasons.

React does not aggregate raw Purchase Handoff lines.

### `get_school_catering_purchase_orders(request jsonb)`

Primary PO read model. It returns:

- supplier/date PO summaries;
- current draft/released revision;
- official number when released;
- lines with school/delivery location, ingredient, quantity and unit;
- source family/split lineage;
- derived staleness;
- release eligibility and disabled reason;
- PDF/export readiness;
- backend-authorized next actions.

No raw private Procurement tables are exposed to the frontend.

## 10. Operator UX

Procurement has exactly two visible work stages.

### 10.1 `Phân bổ nhà cung ứng`

Primary table: one row per Allocation Family.

Recommended columns:

- Ngày;
- Trường / nơi giao;
- Nguyên liệu;
- Đơn vị;
- Nhu cầu;
- Đã phân bổ;
- Còn lại / vượt;
- số NCC;
- trạng thái.

Fast filters:

- Chưa phân bổ;
- Chưa đủ;
- Đã đủ;
- Cần phân bổ lại;
- selected schools;
- date/week.

Selecting a family opens an attached split editor, not a separate navigation page.

Primary actions:

- `Lưu phân bổ` for the selected/manual family;
- `Xác nhận phân bổ đề xuất` for untouched default recommendations;
- `Tạo đơn mua` when the selected materialization scope is fully balanced and current.

Rows are the product. Avoid KPI-card-heavy presentation.

### 10.2 `Đơn mua`

Primary grouping: service date → supplier PO rows.

Shows:

- supplier;
- service date;
- line count;
- school/location count;
- draft/released state;
- stale/current state;
- official number when released;
- next action.

Primary actions:

- `Tạo đơn mua` / `Tạo lại đơn cần cập nhật`;
- inspect draft;
- `Phát hành cho NCC`;
- multi-select / `Phát hành tất cả đơn sẵn sàng` as application convenience;
- PDF preview/export.

Purchase Handoff is not a visible Procurement tab. PDF/export is not a third lifecycle stage.

## 11. PDF / export

V1 initial delivery mechanism is PDF/export, not external-message integration.

Rules:

- released PO read model is authoritative source;
- draft preview may exist but must be visibly marked `DRAFT` and cannot masquerade as an official document;
- official PDF uses the immutable released PO number/revision;
- output is one document per supplier + service date;
- lines remain organized by school/delivery location and ingredient;
- preserve useful OPS v1 operator information such as supplier identity, service date, school destinations, ingredient, purchase unit, quantity and acknowledgement/signature area;
- no prices, taxes, invoice/payment or Finance fields in V1;
- bulk download/ZIP may package multiple already-renderable released POs, but package creation is not an authoritative domain command.

No supplier email/message sending is required for release success in this slice.

## 12. Authorization and runtime

Use existing Atlas domain runtime patterns.

Preferred capability set:

- Planning: `purchase_handoff.school_catering.release`;
- Procurement: `school_catering_allocation.write`;
- Procurement: `school_catering_allocation.bulk_confirm`;
- Procurement: `school_catering_purchase_order.create_drafts`;
- Procurement: `school_catering_purchase_order.release`;
- read capabilities as required by the existing read-runtime convention.

Do not create another command runtime role if the existing Planning and Procurement command runtimes can safely own these functions with narrow relation grants and RLS policies.

No runtime may gain broad cross-domain mutation authority.

## 13. Error and blocker vocabulary

At minimum:

- `SOURCE_CHANGED`;
- `ALLOCATION_IMBALANCED`;
- `SUPPLIER_INELIGIBLE`;
- `NO_ELIGIBLE_SUPPLIER`;
- `AMBIGUOUS_SUPPLIER_PRIORITY`;
- `PO_DRAFT_STALE`;
- `PO_ALREADY_RELEASED`;
- established Atlas `STALE_VERSION`, capability, scope, replay and idempotency errors.

Safe operator responses must not expose SQL, policies, runtime roles, JWTs or internal stack traces.

## 14. Cross-stage behavior

Cross-stage behavior is a first-class acceptance requirement.

Required flows include:

1. Planning release → Purchase Handoff → family appears in Procurement.
2. Manual supplier split → family balances → PO drafts become creatable.
3. Bulk default confirmation → only still-valid untouched recommendations are confirmed.
4. Planning quantity changes before PO release → affected family becomes stale/rebalance-needed → previous ratios generate a proposal → operator confirms → only affected supplier/date PO drafts become stale/regenerated.
5. Supplier eligibility changes before allocation confirmation → recommendation/confirmation fails closed.
6. Supplier eligibility/source allocation changes after draft creation but before release → PO release fails closed as stale/ineligible.
7. One PO release succeeds while another selected PO fails; successful released POs remain released.
8. Released PO is unaffected by later Planning edits; no silent rewrite occurs.
9. Revisit earlier Planning stages and confirm downstream recalculation/staleness behavior is correct rather than preserving invalid Procurement decisions.

## 15. Testing and certification

### Database

Dedicated pgTAP coverage must prove:

- new schema constraints and XOR lineage;
- family identity uniqueness;
- exact contribution sum;
- exact split balance;
- supplier uniqueness per family revision;
- eligibility/effective-date enforcement;
- priority recommendation behavior;
- manual family replacement semantics;
- proportional rebalance + residual correctness;
- source-change staleness;
- PO draft grouping by supplier + service date;
- multi-school line fidelity;
- draft staleness;
- server-generated official numbering uniqueness/replay/concurrency;
- independent per-PO release;
- no mutation of Planning facts;
- no regression to PA-05E wholesale commands.

### Frontend

Focused Vitest/RTL coverage must prove:

- two-stage Procurement navigation;
- family filters/table/split editor;
- default recommendations are display-only until confirmation;
- manual split validation uses backend readback, not frontend authority;
- stale/rebalance states;
- bulk default confirmation exception handling;
- PO draft/release UI and independent bulk-release result handling;
- draft vs released PDF/export presentation;
- Planning one-click transition and recoverable intermediate handoff failure.

### Integration

Prefer cross-stage integration tests over isolated happy-path-only tests whenever an upstream output feeds a later stage.

At minimum exercise:

```text
Planning inputs
→ Need Generation
→ Confirmed Need
→ Purchase Handoff
→ Allocation Family
→ supplier split
→ PO draft
→ PO release
```

Then edit an upstream quantity and prove the expected family and draft staleness/rebalance behavior.

### CI / review

During Codex implementation, use only targeted local checks that materially shorten feedback. GitHub Actions remains the comprehensive format/typecheck/test/build/Supabase-diff gate. Hosted browser acceptance is required for the connected Procurement workbench at 1366×768 and 1920×1080 before merge.

## 16. Implementation decomposition

To control review risk and credit usage, implement in three sequential PR-sized slices.

### SC-PROC-01 — Backend boundary and Allocation Family foundation

Deliver:

- school-catering Purchase Handoff release command;
- Allocation Family persistence/revisions/contributions/supplier splits;
- recommendation + manual save + bulk default-confirm commands;
- allocation workbench read API;
- pgTAP and cross-stage backend tests;
- no Procurement React UI yet beyond any minimal connection types required by generated contracts.

### SC-PROC-02 — Connected allocation workbench

Deliver:

- Planning one-click transition/retry behavior;
- connected `Phân bổ nhà cung ứng` workbench;
- family table, attached split editor, filters, manual save, bulk default confirmation;
- stale/rebalance UI;
- browser acceptance;
- no PO release yet.

### SC-PROC-03 — PO drafts, release, numbering and export

Deliver:

- shared PO aggregate backward-compatible extension;
- school-catering draft materialization command;
- school-catering PO release command;
- automated official numbering;
- PO read API;
- connected `Đơn mua` workbench;
- independent bulk release convenience;
- released PO PDF/export;
- cross-stage acceptance through released supplier commitment;
- PA-05E wholesale regression coverage.

Each slice must remain independently reviewable. Do not combine unrelated Admin code-number automation into these PRs.

## 17. Explicit V1 non-goals

- supplier capacity modeling;
- automatic percentage split among multiple suppliers;
- supplier scoring/performance optimization;
- pricing, tax, currency, invoice or payment;
- supplier acknowledgement/partial rejection;
- released-PO revision/cancellation/replacement;
- warehouse receiving;
- dispatch generation;
- automated email/message sending;
- generic workflow engine;
- generic numbering engine;
- Retool mutation;
- Live OPS mutation;
- production deployment;
- manual Ingredient/Supplier code correction in the Procurement PRs.

## 18. Acceptance boundary

School-Catering Procurement V1 is accepted when an authorized operator can, using Atlas Staging:

1. finish Confirmed Need and use one Planning action to enter Procurement through a durable Purchase Handoff;
2. see correctly aggregated Allocation Families with exact underlying Planning lineage;
3. accept a priority-1 default or split one family across multiple eligible suppliers;
4. rebalance safely after an upstream demand change while preserving accepted ratios as a proposal;
5. reach exact family balance across the selected scope;
6. create supplier/date multi-school PO drafts;
7. review and independently release eligible POs with server-generated official numbers;
8. export supplier-facing released PO PDFs;
9. prove that upstream edits do not silently rewrite released supplier commitments;
10. retain all existing PA-05E wholesale behavior and architecture boundaries.

That is the completion boundary for the first connected Procurement workstream.