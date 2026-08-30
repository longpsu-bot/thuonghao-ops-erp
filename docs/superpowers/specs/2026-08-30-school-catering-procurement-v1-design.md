# School-Catering Procurement V1 — Connected Design

**Status:** Approved design; ready for implementation planning  
**Date:** 2026-08-30  
**Baseline:** `main` at `9928ced99e9d0430801140ad29f86b716d594e59`  
**Authority:** OPS_SYSTEM_MAP v1.0 / `docs/architecture/arch-002-atlas-system-map.md`  
**Related contracts:** Planning Confirmed Need, Planning Purchase Handoff, Procurement domain, PA-05D, PA-05E, PA-06A application connection  
**Operational evidence:** OPS v1 Retool `PurchasePlanner` plus Live OPS purchase-assignment / PO behavior  
**Target environment:** Atlas Staging only until explicit production authorization

## 1. Goal

Connect the accepted school-catering Planning workflow to Procurement while preserving the proven OPS v1 family/split/rebalance operating model and adding Atlas authority, versioning, traceability, concurrency safety, immutable released documents, and decision-first UX.

The first connected Procurement workstream ends at a released supplier PO and PDF/export readiness:

```text
Planning Confirmed Need
→ school-catering Purchase Handoff
→ Allocation Families
→ supplier split confirmation / rebalance
→ PO drafts
→ released supplier POs
→ PDF/export
```

## 2. Domain boundaries

### Planning owns

- Menu, Attendance, Pantry and Need Generation inputs;
- Confirmed Need quantity and controlled unit;
- school / delivery-location demand context;
- Purchase Handoff release and exact source lineage.

### Procurement owns

- supplier recommendation and supplier decision;
- supplier split quantities and ratios;
- allocation-family revisions;
- PO draft materialization;
- supplier/date PO grouping;
- official PO numbering at release;
- supplier-facing released commitment snapshots.

### React owns

- presentation, filters, selection and local edit state;
- orchestration of backend-authorized next actions;
- PDF/export rendering from authoritative released read models.

React must not reconstruct family totals, supplier eligibility, rebalance rules, lifecycle gates, PO grouping, numbering, or release eligibility from private/raw tables.

### Retool / OPS v1 role

Retool is operator-workflow evidence only. Atlas preserves these proven v1 properties:

- supplier work at a family level instead of raw BOM/source lines;
- `split_qty` + `split_ratio` semantics;
- family-atomic supplier replacement;
- exact family balance before PO creation;
- proportional rebalance when demand changes;
- PO grouping by supplier + service date;
- multi-school PO lines;
- bulk operational actions.

Atlas deliberately does **not** copy:

- direct UI SQL as authority;
- broad public-function posture;
- silently rebuilding committed PO content from current assignments;
- operator-supplied Atlas identifiers/document numbers;
- treating generated POs as supplier-confirmed.

## 3. Locked operator/lifecycle decisions

1. Planning uses one visible action: **`Chuyển sang lên đơn`**.
2. Behind it, Atlas first calls existing `release_confirmed_needs_for_purchase_handoff`, then new `release_school_catering_purchase_handoff`.
3. If the first succeeds and the second fails, the valid `RELEASED_FOR_PURCHASE_HANDOFF` intermediate state remains visible with a safe retry action. No fake cross-command rollback.
4. School-catering demand may split across multiple suppliers.
5. Initial recommendation is one unambiguous highest-priority eligible supplier at 100%; recommendation never writes automatically.
6. Supplier priority is ranking evidence, not capacity or split percentage.
7. Procurement working grain is `service_date + delivery_location_id + ingredient_id + unit_id`.
8. Underlying Purchase Handoff line revisions remain exact contribution lineage.
9. Accepted family allocation must satisfy `sum(split_quantity) = family_demand_quantity` exactly.
10. Accepted split ratios are persisted so later demand changes can produce proportional rebalance **proposals**.
11. PO grouping is one PO per **supplier + service date**, containing multiple schools/delivery locations and ingredients.
12. **`Tạo đơn mua`** creates draft PO revisions only.
13. **`Phát hành cho NCC`** releases one PO as the official supplier commitment.
14. Each PO is one release transaction; bulk release is UI convenience over independent commands.
15. Release success means Atlas recorded the commitment. Email/message delivery is not required for command success in V1.
16. First slice stops at `RELEASED_TO_SUPPLIER`. Supplier acknowledgement/rejection, released-PO revision/cancellation/replacement are deferred.
17. Official PO numbers are generated server-side during release. No operator-entered official number.
18. Atlas-wide direction is backend-generated business codes; UUID remains internal identity. Existing Ingredient/Supplier create APIs requiring manual codes are separate Admin debt and are not part of these Procurement PRs.

## 4. School-catering Purchase Handoff boundary

The existing `release_purchase_handoff` command remains PA-05D wholesale-only and must not be reused for school catering.

New `release_school_catering_purchase_handoff(request jsonb)`:

- consumes one school-catering Confirmed Need batch whose current status is `RELEASED_FOR_PURCHASE_HANDOFF`;
- re-reads the current Confirmed Need release/snapshot/line revisions under lock;
- materializes/reuses the existing Planning `purchase_handoff_*` and `purchase_demand_references` structures;
- writes one current Purchase Handoff revision in `RELEASED_TO_PROCUREMENT` with exact quantity/unit/date/delivery-location lineage;
- creates no Procurement allocation, supplier assignment, PO, Warehouse or Dispatch fact;
- uses existing Planning runtime/auth/idempotency/event/audit conventions.

One Purchase Handoff root is stable per Confirmed Need batch. If a future Planning correction produces a later valid Confirmed Need release for the same batch, this command may create a successor handoff revision rather than a second root. V1 does **not** add a new Planning reopen/correction command; it only makes downstream lineage revision-safe when a later source revision exists.

## 5. Allocation Family model

### 5.1 Candidate family vs persisted aggregate

The Procurement read model derives **candidate families** from current released school-catering Purchase Handoff line revisions. A read must not write.

A persisted `PurchaseAllocationFamily` root is created lazily on the first accepted supplier allocation (manual, bulk-default, or later rebalance confirmation). Therefore an unallocated family may have no persisted family UUID yet; the read model identifies it by its exact business tuple and source fingerprint.

### 5.2 Stable root

Create `atlas_procurement.purchase_allocation_families` with the semantic fields:

- `purchase_allocation_family_id` UUID PK;
- `service_date` date;
- `delivery_location_id` FK;
- `ingredient_id` FK;
- `unit_id` FK;
- `version` bigint;
- `current_purchase_allocation_family_revision_id` nullable current pointer;
- timestamps.

There is exactly one root for each tuple:

```text
(service_date, delivery_location_id, ingredient_id, unit_id)
```

The tuple is globally unique in this table; revision history lives under the root.

### 5.3 Accepted family revision

Create `atlas_procurement.purchase_allocation_family_revisions` for **accepted decisions only**. Read-model recommendations/rebalance proposals are not persisted until confirmed.

Each revision records:

- revision ID and family ID;
- revision number and predecessor revision;
- `is_current`;
- authoritative `family_demand_quantity`;
- canonical `source_fingerprint` of the current contribution set;
- decision origin: `MANUAL`, `DEFAULT_CONFIRMED`, or `REBALANCE_CONFIRMED`;
- confirmed actor/time;
- command ID and created timestamp.

Root `version` increments once for each accepted successor revision, and the current pointer/version are updated atomically.

### 5.4 Contribution lineage

Create `atlas_procurement.purchase_allocation_family_contributions`:

- family revision ID;
- exact `purchase_handoff_line_revision_id`;
- contribution quantity;
- created timestamp.

One handoff line revision appears at most once within a family revision.

Required invariant:

```text
sum(contribution_quantity) = family_demand_quantity
```

The server derives the canonical source fingerprint from the sorted set of current Purchase Handoff line-revision IDs plus authoritative quantities/unit/date/delivery-location context. React never generates this fingerprint.

### 5.5 Supplier splits

Create `atlas_procurement.purchase_allocation_supplier_splits`:

- split ID;
- family revision ID;
- supplier ID;
- `split_quantity`;
- server-calculated `split_ratio`;
- `supplier_eligibility_id` and eligibility version used for validation;
- created timestamp.

Invariants:

- one supplier at most once per family revision;
- all split quantities positive;
- supplier active and eligibility active/effective on service date;
- unit matches family unit;
- exact total balance;
- ratio comes from accepted quantity, never client authority.

## 6. Recommendation and rebalance

### Initial recommendation

For an unallocated candidate family:

- if exactly one eligible supplier has the best (lowest) governed priority, propose it at 100%;
- if none, `NO_ELIGIBLE_SUPPLIER`;
- if the best priority is tied, `AMBIGUOUS_SUPPLIER_PRIORITY`.

No recommendation writes on page load.

### Manual family save

`Lưu phân bổ` sends the complete intended supplier/quantity set for one family. The server re-reads current Purchase Handoff contributions and eligibility, validates exact balance, and writes one accepted revision atomically. There is no authoritative per-split-row save path.

### Bulk default confirmation

`Xác nhận phân bổ đề xuất` carries an explicit bounded list of proposals the operator saw, not a hidden “confirm everything in database” instruction. Each candidate contains the tuple, backend-returned source fingerprint, and recommended supplier ID.

The command revalidates every candidate. Valid untouched candidates are committed together; changed/ambiguous/ineligible/already-manual candidates are skipped and returned as structured exceptions. A skipped business exception does not roll back other valid candidates. Transport/internal failure still rolls back the transaction.

### Rebalance

When current source demand differs from the last accepted family revision, the read model marks the accepted allocation stale and may propose a proportional rebalance using the last accepted ratios.

Example:

```text
100 kg: A 60 / B 40
120 kg proposal: A 72 / B 48
```

Rounding:

- use the governed controlled-quantity precision;
- round all but a deterministic final split;
- final split receives the exact residual;
- total must equal current family demand exactly.

If any previous supplier is no longer eligible, do not redistribute automatically; state becomes `Cần phân bổ lại`.

A rebalance proposal is read-only until operator confirmation creates a `REBALANCE_CONFIRMED` revision.

## 7. Allocation commands and read API

### `save_school_catering_supplier_allocation(request jsonb)`

One family per command. Payload identifies the family tuple, the backend-returned source fingerprint, and complete intended supplier/quantity rows. `expected_version` is `1` for an unpersisted family and otherwise the current family root version.

### `confirm_school_catering_supplier_recommendations(request jsonb)`

Bulk-confirm explicit untouched default proposals returned by the workbench. Bound the list size in the implementation contract (recommended maximum 500).

### `get_school_catering_procurement_workbench(request jsonb)`

Returns candidate/persisted families for a date range with optional delivery-location/status filters, including:

- tuple identity and family UUID/version when persisted;
- school/delivery location, ingredient and unit;
- current authoritative demand and contribution summary;
- current accepted splits/ratios;
- derived stale state;
- rebalance proposal when safe;
- eligible suppliers and priority evidence;
- default recommendation;
- allocation total/delta/status;
- blockers/warnings;
- backend-authorized actions and disabled reasons.

The read API owns family aggregation and recommendation logic.

## 8. PO shared aggregate extension

Do not reuse or generalize PA-05E `fulfilment_allocation_*` for school catering. Preserve PA-05E behavior and tests.

Reuse the shared PO aggregate with these exact backward-compatible schema intentions:

### `purchase_orders`

Add:

- `order_context text NOT NULL DEFAULT 'SUPPLIER_DIRECT_WHOLESALE'` constrained to `SUPPLIER_DIRECT_WHOLESALE | SCHOOL_CATERING`;
- nullable root `service_date date`.

For `SCHOOL_CATERING`, root `service_date` is required and `(supplier_id, service_date)` is unique. Wholesale inserts that omit the new fields continue to default to the existing context.

### `purchase_order_revisions`

Make header `delivery_location_id` and `delivery_location_snapshot` nullable so a school-catering supplier/date PO can contain multiple locations. Existing PA-05E command behavior must continue to populate both for wholesale.

### `purchase_order_lines`

- make existing `fulfilment_allocation_line_id` nullable;
- add nullable FK `purchase_allocation_family_id`;
- enforce XOR: exactly one source FK is non-null.

### `purchase_order_line_revisions`

- make existing `fulfilment_allocation_line_revision_id` nullable;
- add nullable FK `purchase_allocation_supplier_split_id`;
- enforce XOR: exactly one source FK is non-null.

Existing line-revision `delivery_location_id`, `service_date`, ingredient, quantity and unit remain authoritative for school-catering destinations.

## 9. PO draft materialization

### Scope

`Tạo đơn mua` operates on a **service-date range**, matching v1 `app_confirm_purchase_orders(start,end,...)`. School/display filters do not create partial supplier/date commitments.

For each target service date:

- if any current candidate family in the authorized school-catering scope is unallocated, imbalanced or stale, that date is skipped with blockers;
- other fully ready dates in the requested range may still materialize drafts;
- business-skipped dates do not roll back valid ready dates;
- internal/transaction failure rolls back the command.

### Grouping

For each ready date, group current accepted supplier splits by supplier + service date into one PO root. One PO line is created per contributing Allocation Family for that supplier/date. Because family identity already contains delivery location + ingredient + unit, multi-school trace remains exact.

`create_school_catering_purchase_order_drafts(request jsonb)` creates or refreshes only DRAFT school-catering PO revisions. It creates no official document number and no supplier-facing commitment.

### Draft staleness

Staleness is derived. A draft is stale whenever any source family revision/supplier split represented in the draft is no longer current or eligible.

A stale draft cannot release. Regeneration creates a successor draft revision only for affected supplier/date PO roots. Unrelated drafts remain unchanged.

## 10. Official PO numbering and release

### Format

V1 locks the official number to:

```text
PO-YYYYMMDD-NNNN
```

- `YYYYMMDD` is the PO **service date**;
- `NNNN` is a Procurement-owned per-service-date counter, minimum four digits, starting at `0001`;
- format is server-owned and not client-configurable in this workstream;
- gapless numbering is not required.

Use a Procurement-owned transactional counter relation/helper, not a generic cross-domain numbering engine. Number allocation occurs inside successful PO release, under row lock/concurrency protection. Replay returns the original number.

### Release

`release_school_catering_purchase_order(request jsonb)`:

- accepts a current DRAFT PO identity/revision and expected root version;
- does **not** accept `document_number`;
- revalidates source splits/currentness, exact quantities, supplier active/eligible state and draft staleness;
- allocates the official number;
- records released actor/time and immutable current revision;
- moves root to `RELEASED_TO_SUPPLIER`;
- emits one Procurement domain event and audit event.

One PO is the transaction boundary. Bulk release in React invokes independent release calls, so successful POs remain released when another selected PO fails.

Released PO content is immutable in V1. Later Planning/allocation changes do not rewrite it.

## 11. PO read API and export

`get_school_catering_purchase_orders(request jsonb)` returns:

- service-date / supplier PO summary rows;
- current draft/released revision;
- official number when released;
- multi-school/location lines with ingredient, quantity and unit;
- exact source family/split lineage;
- derived staleness;
- release eligibility and disabled reason;
- PDF/export readiness;
- backend-authorized actions.

PDF/export rules:

- released read model is the authoritative source for official output;
- draft preview is allowed only with a visible `DRAFT` watermark/state;
- official PDF is one supplier + service-date document;
- lines retain school/delivery-location and ingredient detail;
- preserve useful v1 supplier/date/line/signature-area content;
- no prices, taxes, invoice/payment or Finance fields;
- ZIP/bulk packaging is a presentation/export utility, not an authoritative domain command;
- email/message sending is not required for release success.

## 12. Operator UX

Procurement has exactly two visible stages.

### `Phân bổ nhà cung ứng`

One table row per candidate Allocation Family.

Core columns:

- Ngày;
- Trường / nơi giao;
- Nguyên liệu;
- Đơn vị;
- Nhu cầu;
- Đã phân bổ;
- Còn lại / vượt;
- số NCC;
- trạng thái.

Fast filters: Chưa phân bổ, Chưa đủ, Đã đủ, Cần phân bổ lại, date/week, schools.

Selecting a family opens an attached split editor. Primary actions are `Lưu phân bổ`, `Xác nhận phân bổ đề xuất`, and `Tạo đơn mua` when backend readiness permits.

### `Đơn mua`

Group rows by service date then supplier. Show supplier, date, line/location count, draft/released state, derived staleness, official number, and next action.

Actions: create/regenerate drafts, inspect draft, release one, multi-select/bulk release convenience, PDF preview/export.

Purchase Handoff is not a visible Procurement tab. Export is not a third lifecycle stage.

Rows/tables are the main work surface; avoid KPI-card-heavy layout.

## 13. Authorization and runtime

Use current Atlas command/read runtime patterns; do not create a new runtime role when the existing Planning/Procurement runtimes can own the functions with narrow grants/RLS.

Capabilities:

- Planning: `purchase_handoff.school_catering.release`;
- Procurement: `school_catering_allocation.write`;
- Procurement: `school_catering_allocation.bulk_confirm`;
- Procurement: `school_catering_purchase_order.create_drafts`;
- Procurement: `school_catering_purchase_order.release`;
- read capabilities following current read-runtime convention.

No runtime gains broad cross-domain mutation authority. Procurement may read Planning release lineage but never mutate Planning facts.

## 14. Error vocabulary

At minimum:

- `SOURCE_CHANGED`;
- `ALLOCATION_IMBALANCED`;
- `SUPPLIER_INELIGIBLE`;
- `NO_ELIGIBLE_SUPPLIER`;
- `AMBIGUOUS_SUPPLIER_PRIORITY`;
- `PO_DRAFT_STALE`;
- `PO_ALREADY_RELEASED`;
- established Atlas `STALE_VERSION`, capability, scope, replay/idempotency errors.

Safe responses do not expose SQL, policy names, runtime roles, JWTs or stack traces.

## 15. Cross-stage acceptance behavior

Cross-stage testing is mandatory because upstream edits feed later stages.

Required flows:

1. Confirmed Need release → school-catering Purchase Handoff → family appears in Procurement.
2. Manual split → exact family balance → accepted revision.
3. Bulk default confirmation → still-valid untouched proposals accepted; invalid candidates skipped visibly.
4. Later valid Purchase Handoff source revision changes family demand → prior accepted allocation becomes stale → ratio-based proposal → operator confirms successor revision.
5. Supplier eligibility change before confirmation → recommendation/save fails closed.
6. Allocation/eligibility change after draft creation and before release → PO release fails closed; only affected supplier/date draft needs regeneration.
7. Range draft command skips a blocked service date while materializing other ready dates.
8. Bulk UI release: one PO may succeed while another fails; successful commitment remains released.
9. Released PO remains immutable after later Planning edits.
10. Existing PA-05E wholesale allocation/PO paths remain green after shared PO extension.

Where the current public Planning API cannot yet create a later corrected Confirmed Need release, pgTAP may construct the minimum rolled-back successor source state through test fixtures/helpers; do **not** add an unrelated Planning reopen command to Procurement V1 merely to make this test reachable.

## 16. Testing and certification

### Database

New pgTAP coverage must prove:

- structure, FKs, XOR lineage and RLS/runtime boundaries;
- family tuple uniqueness and current pointer/version integrity;
- exact contribution total and split total;
- supplier uniqueness, active/effective eligibility, priority behavior;
- manual family replacement and bulk-default partial-business-success semantics;
- source fingerprint/staleness and rebalance residual correctness;
- supplier/date PO draft grouping with multi-location line fidelity;
- range draft behavior with blocked vs ready dates;
- PO draft staleness;
- `PO-YYYYMMDD-NNNN` uniqueness/replay/concurrency;
- independent per-PO release;
- no Planning mutation from Procurement;
- no PA-05E wholesale regression.

### Frontend

Focused Vitest/RTL coverage must prove:

- one-click Planning transition and recoverable second-step failure;
- two-stage Procurement navigation;
- family table/filter/split editor;
- recommendations are read-only until explicit confirm;
- manual split + bulk default result handling;
- stale/rebalance states;
- PO draft/release UI and independent bulk-release results;
- DRAFT vs official PDF/export state.

### Integration

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

Then alter an upstream source/revision and prove the expected family and draft stale/rebalance behavior.

### CI / hosted review

During Codex implementation, use targeted local checks only when they materially shorten feedback. GitHub Actions is the comprehensive format/typecheck/test/build/Supabase-diff gate. Hosted browser acceptance at 1366×768 and 1920×1080 is required for connected UI slices before merge.

## 17. Implementation decomposition

Implement as three sequential PR-sized slices.

### SC-PROC-01 — Backend boundary + Allocation Family foundation

- school-catering Purchase Handoff release;
- Allocation Family persistence/revisions/contributions/splits;
- recommendation/manual save/bulk default-confirm commands;
- allocation workbench read API;
- pgTAP and cross-stage backend tests;
- no connected Procurement UI except generated/connection contract updates required by APIs.

### SC-PROC-02 — Connected Allocation Workbench

- Planning one-click transition + retry;
- connected `Phân bổ nhà cung ứng` workbench;
- family table, attached split editor, filters;
- manual save, bulk default confirmation, stale/rebalance UX;
- browser acceptance;
- no PO lifecycle implementation.

### SC-PROC-03 — PO drafts + release + numbering + export

- backward-compatible shared PO aggregate extension;
- range draft command;
- school-catering PO release command;
- Procurement-owned numbering counter/helper;
- PO read API;
- connected `Đơn mua` stage;
- independent bulk release convenience;
- DRAFT/released PDF/export;
- cross-stage acceptance through released supplier commitment;
- explicit PA-05E wholesale regression.

## 18. V1 non-goals

- supplier capacity modeling;
- automatic percentage split across multiple suppliers;
- supplier scoring/performance optimization;
- pricing, tax, currency, invoice or payment;
- supplier acknowledgement/partial rejection;
- released-PO revision/cancellation/replacement;
- Warehouse receiving;
- Dispatch generation;
- automated supplier email/message delivery;
- generic workflow engine;
- generic numbering engine;
- Retool or Live OPS mutation;
- production deployment;
- Ingredient/Supplier manual-code correction inside Procurement PRs.

## 19. Completion boundary

V1 is accepted when an authorized Staging operator can:

1. finish Confirmed Need and enter Procurement through one Planning action plus a durable Purchase Handoff;
2. see correctly aggregated families with exact underlying Planning lineage;
3. accept a priority-1 default or split one family across multiple eligible suppliers;
4. rebalance safely after upstream demand change while prior ratios remain proposals, not silent writes;
5. reach exact family balance;
6. create supplier/date multi-school PO drafts;
7. independently release eligible POs with server-generated `PO-YYYYMMDD-NNNN` numbers;
8. export supplier-facing released PO PDFs;
9. prove upstream edits do not silently rewrite released commitments;
10. retain PA-05E wholesale behavior and all OPS_SYSTEM_MAP boundaries.
