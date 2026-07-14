# MVP vertical-slice operator review

**Status:** Implemented in this PR; pending review and merge

**Scope:** Synthetic in-memory operator and business validation across the Atlas MVP chain

**Authority:** ARCH-001, ARCH-002, the approved Planning, Procurement,
Warehouse Stock Release, and Dispatch contracts, PD-02, and PD-05 ownership
decisions

## Purpose

This review validates Atlas as one operating flow before any persistence or
backend design. It runs realistic synthetic operating-day scenarios from
master-data and demand context through delivery outcome, then uses the observed
flow to decide which objects are operationally relevant.

The main review question was:

> Can Atlas represent one realistic OPS operating day from demand creation to
> delivery outcome without breaking domain ownership, losing traceability, or
> inventing irrelevant operational objects?

At the in-memory prototype boundary, the answer is **yes**. The five scenarios
retain source-to-outcome traceability, preserve ownership, expose blocked work,
and do not require an extra daily workflow object. This conclusion does not
approve persistence, production integration, or operational cutover.

## Scope

The review covers this bounded chain:

```text
Admin master-data reference
→ Planning source
→ Confirmed Need
→ Purchase Handoff
→ Planning-owned DispatchRequirement
→ Procurement-owned FulfilmentAllocation
→ Supplier/cross-dock or WarehouseStockRelease evidence
→ Dispatch plan / trip / load
→ Delivery confirmation, exception, or return
→ Trip closure or operator attention
```

Admin, Planning, Procurement, Warehouse, and Dispatch facts are consumed as
typed in-memory references or existing fixtures. No upstream domain command is
moved into Dispatch, and no production implementation is implied.

## Synthetic scenarios used

| Scenario                         | Demand and destination                                          | Fulfilment evidence                                                                         | Dispatch outcome                                        | Review result                                                      |
| -------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| School catering happy path       | Active school, catering-menu source, 20 kg released requirement | 20 kg supplier cross-dock evidence                                                          | 20 kg loaded and delivered; trip `DELIVERED`            | Passed without WarehouseStockRelease                               |
| School catering mixed fulfilment | One active-school requirement line for 35 kg                    | 25 kg supplier receiving plus 10 kg WarehouseStockRelease                                   | Both portions loaded; 35 kg delivered; trip `DELIVERED` | Passed only when each source portion had evidence                  |
| Wholesale happy path             | Wholesale-order source and customer delivery location, 15 kg    | 15 kg supplier receiving evidence                                                           | 15 kg loaded and delivered; trip `DELIVERED`            | Passed through the shared requirement and Dispatch controls        |
| Exception and return             | Wholesale requirement, 8 kg loaded, destination accepts 3 kg    | Supplier receiving evidence; delivery exception for 5 kg; return handover evidence for 5 kg | Trip `CLOSED_WITH_EXCEPTION`                            | Passed after return evidence resolved the Dispatch path            |
| Blocked operating day            | Active school, 35 kg mixed allocation                           | Supplier 25 kg evidenced; warehouse 10 kg evidence missing                                  | No load and no assigned trip                            | Requirement remained visible with evidence and assignment blockers |

## End-to-end flow map

```text
Demand source
  ├─ school catering menu / controlled Planning source
  └─ wholesale order
        ↓
Confirmed Need line
        ↓ immutable source trace
Purchase Handoff line released to Procurement
        ↓ immutable Planning release
DispatchRequirement line
        ↓ read-only to Procurement and Dispatch
FulfilmentAllocation line(s)
  ├─ SUPPLIER_PO → supplier receiving / cross-dock evidence
  └─ WAREHOUSE_STOCK → WarehouseStockRelease evidence
        ↓ evidence must cover every allocated portion
Dispatch plan → trip assignment → source-backed load
        ↓
Delivery confirmation
  ├─ delivered → trip DELIVERED
  └─ partial / failed → exception → return evidence → CLOSED_WITH_EXCEPTION

Missing evidence or trip assignment
        → operator attention; requirement remains visible
```

The vertical-slice read model presents one row per Planning-owned requirement
line. It answers:

- what demand exists and which source created it;
- who needs it and at which delivery location;
- which Confirmed Need, Purchase Handoff, Planning release, requirement, and
  requirement line provide traceability;
- how Procurement allocated fulfilment;
- which evidence proves each allocation portion;
- what was loaded, delivered, returned, or left as exception quantity;
- what remains unresolved; and
- what blocks the operating day.

## Operator questions answered

1. **What needs to move today?** The Planning requirement, item, quantity,
   unit, destination, and source-of-need are visible together.
2. **Why does it exist?** The row retains the demand source, Confirmed Need,
   Purchase Handoff, Planning release, and stable requirement-line references.
3. **How will it be fulfilled?** Procurement allocation portions remain visible
   as read-only supplier or warehouse decisions.
4. **Is it physically ready?** Each allocation portion shows its evidence type,
   evidence reference, evidenced quantity, and loaded quantity.
5. **What happened in transport?** Trip, loaded, delivered, exception, and
   returned quantities are reconciled in one view.
6. **What needs attention?** Missing physical evidence, mixed-source gaps, and
   missing trip assignment remain in the queue against the original
   requirement.
7. **Can the trip close?** Normal trips close only after complete delivery;
   exception trips close only after the unresolved path has explicit evidence.

## Ownership boundaries confirmed

- **Admin** supplies school/customer and delivery-location reference status. It
  does not own daily demand or Dispatch decisions.
- **Planning** owns the source classification, released requirement, quantity,
  unit, destination, and lineage through Confirmed Need and Purchase Handoff.
- **Procurement** owns the fulfilment allocation and supplier/warehouse split.
  Dispatch reads but cannot revise it.
- **Supplier/cross-dock handling** owns supplier physical evidence.
- **Warehouse** owns WarehouseStockRelease only for warehouse-controlled stock.
  Supplier fulfilment does not require a warehouse release.
- **Dispatch** owns plan, trip, assignment, load, delivery outcome, delivery
  exception, return evidence, and trip closure.
- Return evidence resolves only the Dispatch exception path. It does not create
  Warehouse stock re-entry or stock movement.

Tests also confirm that building the slice read model does not mutate the
Planning requirement or Procurement allocation snapshots, and Dispatch rejects
attempted edits to both upstream facts.

## Objects that behaved as core workflow objects

Object relevance below is an outcome of running the scenarios.

- Planning demand source and released `DispatchRequirementLine` were necessary
  to say what must move, for whom, and why.
- `ConfirmedNeedLine` and `PurchaseHandoffLine` references were necessary for
  traceability across the Planning release boundary.
- `FulfilmentAllocation` and `FulfilmentAllocationLine` were necessary to
  distinguish supplier, warehouse, and mixed fulfilment without moving sourcing
  decisions into Dispatch.
- Source-owned `FulfilmentEvidence` was necessary to prevent unsupported loads.
- `WarehouseStockRelease` was necessary only for the warehouse-stock portion.
- `DispatchPlan`, `DispatchTrip`, `DispatchLoad`, and their lines were necessary
  to represent assignment and physical movement.
- `DeliveryConfirmation`, `DeliveryException`, and `ReturnEvidence` were
  necessary to distinguish successful delivery from evidenced exception
  closure.

## Objects that behaved as derived/read-model concepts

- vertical-slice row and source-to-outcome trace;
- evidence readiness and mixed-portion completeness;
- required, allocated, evidenced, loaded, delivered, returned, and exception
  quantity summaries;
- operator attention item;
- operating-day blocker;
- trip closure readiness.

These concepts help operators decide. They do not own business state and should
be reproduced from authoritative facts when persistence is later approved.

## Objects that should remain internal-only for now

- the synthetic scenario wrapper and fixture-only source bridge;
- evidence-to-allocation matching helpers;
- read-model aggregation helpers;
- fixture actor, driver, vehicle, route, and evidence references;
- status-change and audit-event implementation details that are not required in
  the default operator view.

They support validation but do not justify new user-facing workflow stages.

## Objects or concepts that should remain deferred

- production/kitchen release and QA approval;
- Finance/Accounting, costing, invoicing, and settlement;
- production Warehouse return-to-stock confirmation;
- supplier-performance workflow and external supplier communication;
- route optimization, GPS/live tracking, driver payroll, and fleet maintenance;
- generic workflow-engine objects;
- authentication, authorization, concurrency, idempotency, notification, and
  evidence-file storage;
- Supabase schema, PostgreSQL migrations, RLS, RPCs, Edge Functions, backend
  integration, Retool changes, credentials, and production data.

## Gaps discovered

1. **Independent fixtures do not yet share canonical identifiers.** The current
   Admin, Planning, Procurement, Warehouse, and Dispatch prototypes were built
   as bounded modules. The slice therefore uses typed immutable source bridges
   to connect their concepts. A future approved persistence design must define
   stable cross-domain identifiers and snapshot contracts rather than copy the
   fixture bridge.
2. **Procurement fulfilment allocation remains contract-shaped reference data.**
   The current Procurement implementation does not create the PD-02 fulfilment
   allocation consumed by Dispatch. This review intentionally consumes fixture
   references and does not expand Procurement implementation.
3. **Supplier physical evidence has no production capture workflow.** Supplier
   receiving and cross-dock evidence is sufficient to validate the business
   flow, but its authoritative actor, transaction, and evidence-storage design
   remain unapproved.
4. **The slice is line-oriented.** Multi-line, multi-stop, multi-trip, revision,
   cancellation, and concurrency stress cases remain outside this bounded
   operator checkpoint.
5. **Operator usability still needs human confirmation.** Automated scenarios
   prove consistency and visibility, not that the 02:00–08:00 interaction is
   optimal for real operators.

None of these findings contradicts the approved ownership model. They are
prototype-to-persistence and operator-validation work, not reasons to revise
ARCH-001 or ARCH-002.

## Risks before persistence

- Persisting independently named fixture concepts without an explicit mapping
  would create broken or duplicated lineage.
- Treating the read model as authoritative state would move business rules into
  the UI and recreate hidden workflow logic.
- Using one evidence record to satisfy multiple allocation portions without
  explicit quantity linkage could overstate load readiness.
- Allowing Procurement or Dispatch to manufacture physical evidence would erase
  source ownership.
- Treating Dispatch return evidence as Warehouse stock re-entry would corrupt
  stock custody.
- Designing schema, RLS, RPC, or storage before operator sign-off could freeze
  the wrong screen and transaction boundaries.

## Migration and rollback effects

There is no database, production-data, backend, or Retool migration. Rollback is
limited to reverting the fixture exposure, vertical-slice read model, tests,
this review document, and status wording.

## Recommendation for next step

Accept this checkpoint as the completed in-memory MVP vertical-slice review,
then run a bounded operator walkthrough of the same five scenarios with the
02:00–08:00 team. Record any decision, terminology, missing-evidence, and
attention-queue findings in the repository.

Only after operator acceptance should a separately approved task define stable
cross-domain identifiers, authoritative commands, transaction boundaries,
authorization, persistence, evidence storage, and rollout. The current review
does not authorize that backend work.
