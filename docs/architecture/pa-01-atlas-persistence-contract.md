# PA-01 — Atlas Persistence Contract

**Status:** Proposed architecture contract; documentation only
**Scope:** Authoritative persistence boundaries for the approved Atlas MVP
**Authority:** AGENTS.md, ARCH-001, ARCH-002, approved domain contracts and decisions, the MVP vertical-slice review, and the MVP morning chaos simulation
**Next task:** PA-02 physical schema design, separately approved

## 1. Purpose and binding rules

This contract defines what Atlas must persist, which domain owns it, how identity and released history survive corrections, where atomic commands begin and end, and which read models remain derived. It is the architecture gate before any PostgreSQL migration, table, view, function, RLS policy, RPC, Edge Function, generated database type, or backend integration.

The binding persistence rules are:

1. Stable opaque identity is separate from business meaning and document display numbers.
2. Every cross-domain operational line keeps its own stable identity and explicit upstream references.
3. A released fact is immutable. Later action creates a revision, additive delta, cancellation, reversal, or compensating record.
4. Downstream work stores immutable snapshots where later master-data or upstream changes would otherwise rewrite an operational commitment.
5. Physical evidence remains owned by the process that observed or released the goods.
6. One evidence quantity cannot be counted against more than its recorded quantity or against the same allocation portion twice.
7. Important multi-record business actions execute as one authoritative transaction and append their audit event in that transaction.
8. Read models are reproducible and non-authoritative. React holds interaction state only.
9. Dispatch departure is rejected unless every loaded requirement portion has sufficient, valid physical fulfilment evidence.
10. This contract authorizes no production migration or backend implementation.

## 2. Source baseline and prototype-to-persistence mapping

The approved contracts define business authority. Current TypeScript domains and fixtures prove lifecycle, trace, and operator decisions but are not a physical schema specification.

Important prototype mappings are:

| Prototype shape                                                       | Persistence interpretation                                                                                                                                                                         |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| IDs such as `DR-S10-L2`, `PHL-*`, and `FAL-*`                         | Fixture references only; production records use opaque canonical IDs and may also carry human-readable references.                                                                                 |
| Arrays such as `changes`, `approvedSnapshots`, and `releaseSnapshots` | Separate append-only event/snapshot records, not mutable JSON history owned by React.                                                                                                              |
| `*Workbench` functions                                                | Derived read models. Their action flags never become authoritative stored state.                                                                                                                   |
| `MvpVerticalSlice*` and `MvpMorningChaos*`                            | Application-only review projections. Persist their source facts, not the synthetic wrapper or computed rows.                                                                                       |
| `DispatchDeliveryState`                                               | In-memory composition of independently owned aggregates, not one database aggregate or transaction.                                                                                                |
| Prototype `DispatchRequirement.requirementStatus` after release       | Cross-domain progress projection only. Persistence keeps Planning release/revision state authoritative and derives allocation, fulfilment, Dispatch, and delivery progress from downstream owners. |
| `SupplierReceivingEvidence` and cross-dock fixtures                   | Source-owned physical evidence contract awaiting a production capture workflow. They are not Procurement confirmations.                                                                            |
| Current string status unions                                          | Contract vocabulary. PA-02 selects physical constraint representation without changing approved lifecycles.                                                                                        |

No tracked OPS v1 `schema.sql` or Retool export package exists in this checkout. Existing contract compatibility notes are therefore the only legacy evidence used by PA-01. Before a migration mapping is approved, a separate inventory must identify the exact legacy export, extraction date, source system, owner, and completeness.

## 3. Canonical identity contract

### 3.1 Identifier classes

Atlas uses four distinct identifier classes.

| Class                     | Contract                                                                                                                                                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Canonical primary ID      | Server-generated, opaque, immutable UUID for a business record. UUID version and generation function are finalized in PA-02. IDs are never recycled or derived from names, dates, or composite business keys. |
| Cross-domain reference ID | The canonical ID of an upstream aggregate, line, immutable snapshot, or evidence application. A cross-domain reference never points only to a display number or composite key.                                |
| Human-readable reference  | A trace code, document number, external order reference, or operator label used for search and communication. It is unique only within its declared scope and is not a primary key.                           |
| Legacy source reference   | Immutable tuple of source system, source object type, source ID, extraction/import batch, and optional source version. It supports migration reconciliation only and never becomes Atlas identity.            |

All canonical IDs, revision IDs, snapshot IDs, line IDs, evidence IDs, command IDs, event IDs, and audit IDs are immutable.

### 3.2 Objects requiring stable canonical IDs

Stable IDs are required for:

- customer, school, school group/type, service calendar/rule, and delivery location;
- ingredient, unit, unit-conversion rule, supplier, supplier eligibility, and supplier policy;
- dish, recipe, recipe version, BOM/recipe line, variant, change set, and review evidence;
- every Planning source document and line, Planning Input Set, Need Generation run, theoretical line, Confirmed Need batch/line, Purchase Handoff batch/line, Planning release, and Dispatch Requirement/line;
- supplier assignment, Purchase Allocation batch/line, Fulfilment Allocation/line, Purchase Order/revision/line, and supplier confirmation;
- Receiving Session/line, discrepancy, Goods Receipt/line, stock lot/position, reservation, pick list/line, Warehouse Stock Release/line, handoff evidence, and stock movement;
- source-owned fulfilment evidence and its quantity applications;
- Dispatch Plan, Trip, Stop, Load/line, Delivery Confirmation/line, Delivery Exception, Return Evidence, and attached evidence metadata;
- every release snapshot, revision, command receipt, idempotency record, domain event, status change, and audit record.

The cross-domain spine is line-oriented:

```text
Planning source line
→ theoretical need line
→ confirmed need line
→ purchase handoff line
→ dispatch requirement line
→ purchase / fulfilment allocation line
→ PO line or warehouse request
→ physical-evidence application
→ dispatch load line
→ delivery confirmation line / exception / return
```

Each arrow carries canonical IDs. Descriptions, dates, destinations, quantities, units, suppliers, and statuses remain attributes or immutable snapshots.

### 3.3 Revisions, snapshots, lines, commands, and events

- An aggregate has an immutable root ID and a monotonically increasing concurrency `version`.
- A released document belongs to a stable document series and has a distinct immutable `revision_id`. The current prototype's `purchaseOrderId + version` and similar pairs map to this series/revision distinction.
- Each release creates an immutable `snapshot_id` containing the released revision, line revisions, material descriptions, quantities, units, destination or supplier facts, actor, and time.
- A business line has a stable `line_id`. A changed post-release representation receives a new `line_revision_id` linked to the previous line revision. A genuinely new additive line receives a new `line_id` linked to the triggering source or original line.
- Every authoritative call has a `command_id`, a caller-provided or integration-provided `idempotency_key` where required, and a `correlation_id` spanning its events and downstream requests.
- Every emitted event has its own immutable `event_id`; an event references the command, aggregate, aggregate version, actor, and source domain.

### 3.4 Human-readable references

Human-readable values include document numbers, `trace_code`, Planning release reference, PO number, trip reference, supplier document reference, customer order reference, and evidence reference. They may be searchable and may be immutable after release, but they do not replace canonical IDs. Document-number format, sequencing scope, and gap policy remain a PA-02 decision.

## 4. Persistence classification

The classifications below are logical. PA-02 may group closely owned records physically but may not change authority or lifecycle.

### 4.1 Admin, master data, and Planning

| Object                                                            | Classification                                         | Owner / persistence note                                                                                              |
| ----------------------------------------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| Customer / School                                                 | Authoritative persisted aggregate                      | Admin; active/inactive and effective-dated. A school may reference a customer/group.                                  |
| SchoolGroup, SchoolType, ServiceCalendar, ServiceDayRule          | Authoritative persisted child/entity                   | Admin reference entities; stable IDs and effective periods where applicable.                                          |
| DeliveryLocation                                                  | Authoritative persisted aggregate                      | Admin; independently deactivatable and cross-domain referenced. Released work snapshots the address and instructions. |
| SchoolOperationalProfile                                          | Authoritative persisted child/entity                   | Owned by School; future-facing settings only.                                                                         |
| Ingredient                                                        | Authoritative persisted aggregate                      | Admin.                                                                                                                |
| Unit                                                              | Authoritative persisted aggregate                      | Admin reference data.                                                                                                 |
| IngredientUnitProfile                                             | Authoritative persisted child/entity                   | Owned by Ingredient.                                                                                                  |
| UnitConversionRule                                                | Authoritative persisted aggregate                      | Admin; scoped, effective-dated, versioned, and auditable.                                                             |
| Supplier                                                          | Authoritative persisted aggregate                      | Admin master identity; Procurement owns commitments.                                                                  |
| IngredientSupplierEligibility                                     | Authoritative persisted aggregate                      | Admin relationship with its own identity and effective period.                                                        |
| DefaultSupplierPolicy / SupplierPreference                        | Authoritative persisted aggregate                      | Admin guidance only; never a supplier commitment.                                                                     |
| Dish                                                              | Authoritative persisted aggregate                      | Admin/Recipe governance.                                                                                              |
| Recipe                                                            | Authoritative persisted aggregate                      | Recipe governance; associated with Dish.                                                                              |
| RecipeVersion                                                     | Immutable snapshot/reference after release             | Draft is governed within Recipe; released/locked version is immutable.                                                |
| RecipeLine / BOMLine and school-type variant                      | Authoritative persisted child/entity                   | Owned by a RecipeVersion; immutable with a released version.                                                          |
| RecipeChangeSet                                                   | Authoritative persisted aggregate                      | Governance correction/revision package.                                                                               |
| RecipeReviewEvidence                                              | Append-only evidence record                            | Admin recipe-review scope only; does not grant QA/Production approval.                                                |
| WeeklyMenu and lines                                              | Authoritative persisted aggregate / children           | Planning source with approved snapshots.                                                                              |
| AttendanceBatch and lines                                         | Authoritative persisted aggregate / children           | Planning source with approved snapshots.                                                                              |
| Direct ingredient request, pantry need, wholesale order and lines | Authoritative persisted aggregate / children           | Controlled source facts. Exact source-specific shapes are finalized in their implementation contracts.                |
| `DemandSource`, source bridge, and fixture source metadata        | Internal type only                                     | Type/projection helpers; persist the actual source aggregate and source reference instead.                            |
| PlanningInputSet and input references                             | Authoritative persisted aggregate / immutable children | Persists the evaluated versions and readiness decision.                                                               |
| Planning readiness issues                                         | Authoritative persisted child/entity                   | Persist blockers/warnings needed to explain a command decision; current action flags remain derived.                  |
| NeedGenerationRun                                                 | Authoritative persisted aggregate                      | One controlled calculation run.                                                                                       |
| NeedGenerationInputSnapshot                                       | Immutable snapshot/reference                           | Exact input, rule, recipe/BOM versions used by the run.                                                               |
| TheoreticalNeedLine and calculation trace                         | Authoritative persisted child/entity                   | Persisted calculation output; immutable after release.                                                                |
| ConfirmedNeedBatch and lines                                      | Authoritative persisted aggregate / children           | Planning-approved demand gate; line ID is the downstream demand identity.                                             |
| ConfirmedNeedAdjustment                                           | Append-only evidence record                            | Quantity adjustment evidence linked to the line and version.                                                          |
| PurchaseHandoffBatch and lines                                    | Authoritative persisted aggregate / children           | Planning-owned release boundary.                                                                                      |
| PurchaseDemandReference                                           | Immutable snapshot/reference                           | Child of handoff line; preserves approved Planning quantity and trace.                                                |
| Planning release / DispatchRequirement and lines                  | Authoritative persisted aggregate / children           | Planning-owned delivery obligation and immutable release snapshot.                                                    |
| Issues used only for fixture validation                           | Internal type only                                     | Persist only domain-relevant unresolved/resolved issue evidence; UI validation helpers are not tables.                |

### 4.2 Procurement and physical fulfilment

| Object                                    | Classification                                              | Owner / persistence note                                                       |
| ----------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------ |
| SupplierAssignment                        | Authoritative persisted child/entity                        | Procurement decision linked to released demand.                                |
| PurchaseAllocationBatch and lines         | Authoritative persisted aggregate / children                | Procurement supplier-allocation review and approval.                           |
| PurchaseAllocation approved snapshot      | Immutable snapshot/reference                                | Preserves approved assignment and quantities.                                  |
| FulfilmentAllocation and lines            | Authoritative persisted aggregate / children                | Procurement decision for supplier, warehouse, mixed, or future source.         |
| PurchaseOrder and lines                   | Authoritative persisted aggregate / children                | Released supplier commitment with immutable revisions/snapshots.               |
| PurchaseOrderDraft type alias             | Internal type only                                          | A lifecycle state of PurchaseOrder, not a separate persisted business concept. |
| SupplierConfirmation                      | Append-only evidence record                                 | Commercial response to a released PO; does not prove physical receipt.         |
| ProcurementRevision / SupplierReplacement | Append-only audit/event record plus immutable revision link | Preserves old commitment and creates a new explicit revision path.             |
| Supplier receiving evidence               | Append-only evidence record                                 | Owned by the authorized receiving process that observed the goods.             |
| Supplier cross-dock evidence              | Append-only evidence record                                 | Owned by the authorized cross-dock/receiving process.                          |
| EvidenceApplication                       | Authoritative persisted child/entity                        | Links one evidence quantity portion to exactly one FulfilmentAllocationLine.   |
| Future ProductionRelease                  | Deferred/not persisted                                      | Reserved source type only; Production/QA are outside MVP implementation.       |

### 4.3 Warehouse

| Object                             | Classification                               | Owner / persistence note                                                             |
| ---------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------ |
| ReceivingPlan                      | Derived database view/read model             | Expected arrivals from released, supplier-confirmed POs.                             |
| ReceivingSession and lines         | Authoritative persisted aggregate / children | Warehouse receiving transaction and observed quantities.                             |
| WarehouseDiscrepancy               | Authoritative persisted child/entity         | Observed shortage, overage, damage, document, or unit issue.                         |
| GoodsReceipt and lines             | Immutable snapshot/reference                 | Released Warehouse receipt evidence; corrections create correction/reversal records. |
| StockLot / StockPosition           | Authoritative persisted aggregate            | Warehouse custody identity. Balance is derived from movements.                       |
| StockMovement                      | Append-only evidence record                  | Authoritative inventory ledger; posted movements are immutable.                      |
| StockReservation                   | Authoritative persisted aggregate            | Concurrency-sensitive reservation against a stock lot/position.                      |
| PickList and PickLine              | Authoritative persisted aggregate / children | Warehouse execution evidence.                                                        |
| WarehouseStockRelease and lines    | Authoritative persisted aggregate / children | Warehouse custody-release evidence for warehouse allocation portions.                |
| WarehouseHandoffEvidence           | Append-only evidence record                  | Proves custody handoff, not destination delivery.                                    |
| OnHandStock                        | Derived database view/read model             | Sum of posted movements minus active reservations according to approved rules.       |
| InventoryAdjustment and StockCount | Authoritative persisted aggregate / children | Approved Warehouse concepts but later bounded capability; no PA-01 implementation.   |

### 4.4 Dispatch, delivery, audit, and projections

| Object                                                                                                                    | Classification                               | Owner / persistence note                                                              |
| ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------- |
| DispatchPlan                                                                                                              | Authoritative persisted aggregate            | Groups requirement and allocation references for a service date/wave.                 |
| DispatchTrip                                                                                                              | Authoritative persisted aggregate            | Independent execution/concurrency boundary.                                           |
| DispatchStop                                                                                                              | Authoritative persisted child/entity         | Owned by DispatchTrip.                                                                |
| DriverAssignment / VehicleAssignment                                                                                      | Authoritative persisted child/entity         | Reference assignment only; no HR, payroll, or fleet ownership.                        |
| DispatchLoad and lines                                                                                                    | Authoritative persisted aggregate / children | Source-backed physical load confirmation.                                             |
| DeliveryConfirmation and lines                                                                                            | Authoritative persisted aggregate / children | Destination outcome and quantity reconciliation.                                      |
| DeliveryEvidence metadata                                                                                                 | Append-only evidence record                  | Reference metadata only; file-storage implementation deferred.                        |
| DeliveryException                                                                                                         | Authoritative persisted aggregate            | Explicit unresolved/resolved destination problem.                                     |
| ReturnEvidence                                                                                                            | Append-only evidence record                  | Dispatch resolution evidence; never creates Warehouse stock re-entry.                 |
| DispatchStatusChange / domain status changes                                                                              | Append-only audit/event record               | Status transition evidence, not mutable arrays.                                       |
| Domain audit events                                                                                                       | Append-only audit/event record               | Shared envelope, source-domain owned. Not full event sourcing.                        |
| Control Board                                                                                                             | Derived database view/read model             | Current React rows are fixture-only and must be replaced by source-backed derivation. |
| Domain workbench rows and attention queues                                                                                | Derived database view/read model             | Current TypeScript builders are prototypes of derived queries/RPC results.            |
| MVP vertical-slice row                                                                                                    | Application-only projection                  | Synthetic review composition; do not persist.                                         |
| MVP morning-chaos scenario, timeline wrapper, resource wrapper, trip target, and row                                      | Application-only projection                  | Test/review data only. Real commands/events supply future operating-day trace.        |
| Fixture actors, routes, vehicles, evidence labels, and command result wrappers                                            | Internal type only                           | No standalone persistence unless a later master-data contract promotes them.          |
| QA/Production execution, Finance/Accounting, route optimization, GPS, payroll, fleet maintenance, generic workflow engine | Deferred/not persisted                       | Outside PA-01 and the MVP implementation boundary.                                    |

## 5. Aggregate boundaries

The transaction boundary is one aggregate unless the named command explicitly coordinates multiple aggregates atomically. Cross-domain commands reference upstream immutable versions and never update upstream aggregates.

| Aggregate root                | Owned children / immutable references                                                          | Lifecycle and commands                                                     | Transaction, concurrency, archive/cancel, forbidden mutation                                                                                                                                                                        |
| ----------------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Customer/School               | Profile, group/type/calendar references, status/change evidence; DeliveryLocation by reference | Create/update profile, set status/type/service rule/location               | One School per command; `version` required. Inactivate, never delete when referenced. Cannot cancel daily demand or rewrite released destinations.                                                                                  |
| DeliveryLocation              | Address, instructions, effective status                                                        | Create/update/deactivate                                                   | Independent version because location status may change without School edit. Released documents keep snapshots.                                                                                                                      |
| Ingredient                    | Unit profile, status changes; Unit and conversion refs                                         | Create/update/status/unit profile                                          | Archive/inactivate only. Cannot rewrite released recipe, PO, receipt, stock, or delivery descriptions.                                                                                                                              |
| UnitConversionRule            | Scope, factor, effective period, reason                                                        | Create/revise/deactivate                                                   | New effective revision for used rules. Cannot recalculate released quantities silently.                                                                                                                                             |
| Supplier                      | Profile/status; eligibility/policy by reference                                                | Create/update/status                                                       | Inactivate for future use. Cannot alter released PO supplier facts.                                                                                                                                                                 |
| IngredientSupplierEligibility | Ingredient/Supplier refs, effective period                                                     | Set/revise eligibility                                                     | Versioned relation. Cannot become a supplier assignment or commitment.                                                                                                                                                              |
| Dish                          | Profile/status and Recipe references                                                           | Create/update/status                                                       | Inactivate for future menus; preserve historical use.                                                                                                                                                                               |
| Recipe                        | Versions, lines, variants, locks, change sets/review evidence                                  | Draft/version/line/validate/release/lock/change-set commands               | Release/lock makes version immutable. New RecipeVersion for correction. Cannot approve QA or rewrite Planning output.                                                                                                               |
| WeeklyMenu                    | Menu lines, issues, approval snapshots, events                                                 | Import, validate, edit, approve, reopen, request generation                | One menu/version transaction. Reopen creates new working version while old snapshot remains. No downstream recalculation.                                                                                                           |
| AttendanceBatch               | Attendance lines, issues, approval snapshots, events                                           | Import, validate, edit, approve, reopen, mark used                         | Same protections as WeeklyMenu.                                                                                                                                                                                                     |
| PlanningInputSet              | Input references, readiness issues, readiness snapshot                                         | Evaluate, request generation, invalidate                                   | Atomically records exact upstream versions and result. Cannot edit menu/attendance.                                                                                                                                                 |
| NeedGenerationRun             | Input snapshot, theoretical lines, issues, release snapshot                                    | Generate, validate, release, invalidate                                    | Generation and line creation are one transaction. Released run immutable; new run after invalidation. Cannot edit recipes or confirm demand.                                                                                        |
| ConfirmedNeedBatch            | Confirmed lines, adjustments, issues, approval/release snapshots                               | Create, adjust, validate, confirm/approve, reopen, release                 | Batch command is atomic; line updates check batch `version`. Released snapshot remains. Cannot assign supplier.                                                                                                                     |
| PurchaseHandoffBatch          | Handoff lines, source snapshots, issues, release snapshots                                     | Prepare, validate, release, reopen/invalidate                              | Release and events atomic. Released lines are immutable; later Planning change creates revision/new handoff. Cannot carry supplier/PO fields.                                                                                       |
| DispatchRequirement           | Requirement lines, Planning release snapshot, revision links                                   | Create/release/revise/cancel                                               | Planning-owned. A late additive change creates a new linked released requirement/line. Allocation, fulfilment, Dispatch, and delivery progress are derived from downstream owners; Procurement and Dispatch never update this root. |
| PurchaseAllocationBatch       | Allocation lines, supplier assignments, approval snapshots                                     | Create, assign/revise supplier, validate, approve, release to PO drafting  | One batch version. Reopen before new edits; preserve approval snapshots. Cannot change Planning quantity.                                                                                                                           |
| FulfilmentAllocation          | Allocation lines and revision links                                                            | Allocate, revise, validate/mark ready                                      | Procurement-owned. Revision is atomic and preserves prior split. Cannot create physical evidence or change requirement quantity/destination.                                                                                        |
| PurchaseOrder                 | Lines, supplier confirmations, revision/cancellation/release snapshots                         | Create draft, validate, release, record confirmation, revise/reopen/cancel | One PO revision per transaction. Released revision immutable. Cancellation is terminal for that revision. Cannot create receipt or stock.                                                                                           |
| ReceivingSession              | Receiving lines and discrepancies; immutable PO snapshot refs                                  | Create/start/record line/discrepancy/validate/reopen/cancel                | Warehouse transaction; optimistic version on session. Cannot rewrite PO or Planning facts.                                                                                                                                          |
| GoodsReceipt                  | Immutable receipt lines and correction/reversal links                                          | Release receipt, correct/reverse by new command                            | Release receipt and accepted stock creation must be atomic where stock is created immediately. No silent edit or deletion.                                                                                                          |
| StockLot/Position             | Source receipt refs; movements and reservations by reference                                   | Create from receipt, hold/release hold, move location                      | Stock-affecting commands lock/check the stock version. Archive only after zero balance and retention rules.                                                                                                                         |
| StockReservation              | Stock/fulfilment refs and reservation lifecycle                                                | Create/validate/release/cancel                                             | Atomic availability check and reservation. Cannot exceed available stock.                                                                                                                                                           |
| PickList                      | Pick lines and reservation refs                                                                | Create/validate/start/record/ready/reopen/cancel                           | Independent version. Cannot create Dispatch route/delivery.                                                                                                                                                                         |
| WarehouseStockRelease         | Release lines, handoff evidence, stock movement refs                                           | Create/validate/evidence/release/post movement/correct                     | Custody release plus negative StockMovement should be one authoritative command in production, or a transactionally enforced state machine with no externally visible gap. Cannot confirm destination delivery.                     |
| DispatchPlan                  | Requirement/allocation snapshot refs                                                           | Create/revise/cancel before departure                                      | Plan groups work; trips remain separate aggregates. Cannot alter allocation.                                                                                                                                                        |
| DispatchTrip                  | Stops, assignments, departure/closure state                                                    | Assign, assign references, depart, close/cancel/void                       | One trip/version. Concurrent trips do not share a write lock. Departure and closure check all linked loads/evidence/outcomes.                                                                                                       |
| DispatchLoad                  | Load lines and evidence-application refs                                                       | Confirm/correct before departure                                           | Atomic load confirmation. Immutable after departure except explicit correction/void flow. Cannot manufacture evidence.                                                                                                              |
| DeliveryConfirmation          | Lines and evidence refs                                                                        | Confirm destination outcome/correct by supersession                        | One stop outcome transaction; quantities reconcile to load. No Warehouse mutation.                                                                                                                                                  |
| DeliveryException             | Exception quantity, reason, resolution refs                                                    | Record/resolve/supersede                                                   | Never delete. Resolution requires owned evidence.                                                                                                                                                                                   |
| ReturnEvidence                | Exception/load refs and evidence metadata                                                      | Record/supersede                                                           | Append-only fact. Warehouse must separately receive returned stock.                                                                                                                                                                 |

### 5.1 Lifecycle and event requirements by aggregate

The detailed status names remain those in the approved domain contracts. At minimum, each root persists the following lifecycle and emits the corresponding source-domain event family:

| Aggregate root                                        | Lifecycle summary                                                                                  | Minimum emitted events                                                                                                                                                        |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Customer/School, DeliveryLocation                     | Active ↔ inactive with effective revisions                                                         | Created, profile/location updated, activated/deactivated, override recorded.                                                                                                  |
| Ingredient, Supplier, Eligibility, UnitConversionRule | Active ↔ inactive; effective revision/supersession                                                 | Created, profile/rule changed, eligibility changed, activated/deactivated.                                                                                                    |
| Dish                                                  | Draft → active → inactive                                                                          | Created, profile updated, activated/deactivated.                                                                                                                              |
| Recipe                                                | Draft version → validated → released → locked; successor revision                                  | Draft/version/line/change-set created or changed, validated, released, locked/unlocked.                                                                                       |
| WeeklyMenu                                            | Draft → validated → approved → generation requested; reopen                                        | Imported, validated/failed, line edited, approved, reopened, generation requested.                                                                                            |
| AttendanceBatch                                       | Draft → validated → approved → used; reopen                                                        | Imported, validated/failed, line edited, approved, reopened, marked used.                                                                                                     |
| PlanningInputSet                                      | Not ready → ready → generation requested; invalidated                                              | Evaluated, passed/failed, invalidated, generation requested.                                                                                                                  |
| NeedGenerationRun                                     | Generated → validated → released; invalidated/new run                                              | Generated, validated/failed, released for confirmation, invalidated.                                                                                                          |
| ConfirmedNeedBatch                                    | Draft review → validated → approved → released; reopen                                             | Created, adjusted, validated/failed, approved, reopened, released.                                                                                                            |
| PurchaseHandoffBatch                                  | Prepared → validated → released; reopen/invalidated                                                | Prepared, validated/failed, released, reopened, invalidated.                                                                                                                  |
| DispatchRequirement                                   | Draft → released; revised/additive/superseded/cancelled by Planning                                | Released and additive revision/supersession/cancellation recorded. Allocation, fulfilment, Dispatch, and outcome are derived cross-domain progress, not Planning-root events. |
| PurchaseAllocationBatch                               | Prepared → validated → approved → PO drafting; reopen                                              | Created, supplier assigned/revised, validated/failed, approved, released to drafting.                                                                                         |
| FulfilmentAllocation                                  | Draft → allocated → validated/ready → evidence pending/recorded; revised                           | Created, line allocated, revised, ready for evidence.                                                                                                                         |
| PurchaseOrder                                         | Draft → validated → released → supplier response/receiving ready; revised/reopened/cancelled       | Draft created, validated/failed, released, confirmation response, replacement/revision, reopened, cancelled.                                                                  |
| ReceivingSession                                      | Prepared → in progress → validated → receipt released; reopen/cancel                               | Created, started, line/discrepancy recorded, validated/failed, reopened/cancelled.                                                                                            |
| GoodsReceipt                                          | Draft/validated → released; corrected/reversed by successor record                                 | Receipt released, correction/reversal recorded.                                                                                                                               |
| StockLot/Position                                     | Pending/available → reserved/picked/released; hold/quarantine/adjustment states                    | Created, held/released from hold, moved; quantity changes are emitted through StockMovement events.                                                                           |
| StockReservation                                      | Prepared → validated → reserved/released to pick; cancel                                           | Created, validated, reserved/released to pick, cancelled.                                                                                                                     |
| PickList                                              | Prepared → validated → picking → ready/released; reopen/cancel                                     | Created, validated, picking started, line recorded, ready, reopened/cancelled.                                                                                                |
| WarehouseStockRelease                                 | Draft → validated → released → movement posted; correction/reversal                                | Created, validated, handoff evidence recorded, goods released, movement posted, corrected/reopened/cancelled.                                                                 |
| DispatchPlan                                          | Planned → assigned/loaded/in transit → delivered/exception; cancel/void before protected execution | Created, revised/cancelled/voided, trip outcome observed.                                                                                                                     |
| DispatchTrip                                          | Planned → assigned → loaded → in transit → delivered/closed with exception                         | Assigned, driver/vehicle assigned, departed, completed/cancelled/voided.                                                                                                      |
| DispatchLoad                                          | Draft/confirmed → protected after departure; corrected/voided explicitly                           | Load confirmed, corrected or voided.                                                                                                                                          |
| DeliveryConfirmation                                  | Destination outcome recorded; superseding correction only                                          | Stop confirmed, confirmation superseded/voided.                                                                                                                               |
| DeliveryException                                     | Open → resolved with evidence; superseded/voided explicitly                                        | Exception recorded, resolution recorded, correction/void recorded.                                                                                                            |
| ReturnEvidence                                        | Valid → superseded/voided                                                                          | Return evidence recorded, superseded, or voided.                                                                                                                              |

Every aggregate command rejects a stale expected version. Archive is available only for inactive reference/master data and completed records after the retention policy allows it; archive never means delete. Operational cancellations and voids are explicit status facts with reason, actor, and event.

## 6. Snapshot rules

### 6.1 Reference only, snapshot only, or both

| Downstream fact                                                                                           | Storage rule at release                                                                                                                                                                                                |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mutable master-data relationship used only for current validation                                         | Canonical foreign key reference only before release.                                                                                                                                                                   |
| Planning quantity, unit, service/delivery date, destination, source trace                                 | Both canonical references and immutable release snapshot.                                                                                                                                                              |
| Ingredient, unit, dish, supplier, school/customer, and delivery-location descriptions printed or acted on | Both canonical reference and released description snapshot.                                                                                                                                                            |
| Recipe/BOM used for calculation                                                                           | Canonical RecipeVersion/BOM line references plus immutable calculation-input snapshot and rule version.                                                                                                                |
| Confirmed Need and Purchase Handoff                                                                       | Canonical upstream line IDs plus immutable approved/released quantity, unit, and trace snapshot.                                                                                                                       |
| Supplier/warehouse fulfilment split                                                                       | Canonical FulfilmentAllocation revision/line IDs plus immutable allocated source, quantity, unit, and source-reference snapshot consumed by Dispatch.                                                                  |
| PO commercial terms                                                                                       | Supplier/location/unit refs plus immutable supplier name, delivery terms, dates, instructions, quantity/unit, and document revision snapshot. Pricing is included only when an approved future contract introduces it. |
| Warehouse receipt/release evidence                                                                        | Canonical PO/allocation/stock IDs plus immutable observed quantity, unit, source owner, actor, time, and evidence reference.                                                                                           |
| Dispatch destination                                                                                      | DeliveryLocation and customer/school refs plus immutable address, instructions, destination name, service date, and approved override evidence.                                                                        |
| Delivery/return evidence                                                                                  | Canonical trip/stop/load/exception IDs plus immutable quantity, unit, actor, occurrence time, and evidence metadata.                                                                                                   |

### 6.2 Effect of upstream correction

Changing current master data affects new work only. Released downstream rows continue to show their stored snapshot. A correction creates one of the explicit records in section 7 and may create a derived attention item for downstream owners. It never updates released snapshots in place.

If a corrected upstream revision has not yet been acted on, the downstream owner may cancel and rebuild its draft. If a supplier commitment, receipt, stock movement, load, departure, or destination outcome already exists, the owning domain must use its revision, reversal, exception, or compensating path.

## 7. Revision, supersession, and morning-chaos rules

### 7.1 Definitions

- **Correction:** A pre-release edit to a working draft. It increments optimistic version and appends audit evidence but does not create a released revision.
- **Revision:** A post-release replacement or change represented by a new immutable revision linked to the previous revision.
- **Additive delta:** A new released line/requirement linked to an earlier release without superseding it. Downstream totals include both. The School 05 late `+4 kg` chaos case uses this rule.
- **Supersession:** A new revision explicitly replaces a prior revision for future action. The prior record remains historical and cannot be selected for new work.
- **Cancellation:** An explicit terminal fact stating the revision must no longer be used. It does not erase downstream history and may require compensating action.
- **Reversal/compensation:** A new physical or ledger record that offsets an already posted receipt, stock movement, release, or other irreversible evidence.

Every revision stores `revision_id`, series/root ID, revision number, revision kind, prior/superseded revision ID where applicable, reason, actor, time, command/correlation IDs, and affected line revision links.

### 7.2 Required behaviors

- Late attendance or quantity change after Planning release creates a new linked Planning release/Dispatch Requirement revision or additive delta. The original quantity and snapshot remain unchanged.
- A Planning change after Confirmed Need or Purchase Handoff release creates new Planning approval/handoff revisions. It does not rewrite Procurement work.
- PO allocation/supplier changes preserve the prior allocation and released PO snapshots. A changed supplier commitment creates a new PO revision or cancellation/replacement.
- Fulfilment allocation revision preserves each prior split. Evidence already recorded stays linked to the allocation revision/line it observed; it is not moved to the new split.
- Dispatch requirement revision preserves the original requirement. Dispatch consumes only explicitly active released revisions and displays linked additive/superseding records.
- Historical snapshots remain unchanged after every correction, revision, cancellation, or supersession.
- A unique active-revision invariant prevents two superseding revisions from both becoming current. Additive deltas are explicitly marked and are not treated as superseding revisions.

## 8. Evidence contract

### 8.1 Common evidence envelope

Each evidence record is source-domain owned and contains:

- immutable evidence ID and evidence kind;
- source domain/process and owning aggregate/line ID;
- subject item ID plus released item/unit description snapshot;
- observed/released quantity and unit with approved precision;
- actor ID/type and occurred-at timestamp;
- recorded-at timestamp when different from occurrence;
- supplier, warehouse, stock lot, trip, stop, or destination references as applicable;
- external document/evidence reference and optional file metadata;
- command, correlation, and idempotency IDs;
- status `VALID`, `SUPERSEDED`, or `VOIDED` with correction reason and superseding evidence ID.

Evidence is append-only. Metadata correction or quantity correction creates a superseding evidence record; the original becomes non-current but remains visible. Void is allowed only with explicit authority and reason. A superseding record never changes the original occurrence timestamp or actor attribution.

File contract metadata may include logical attachment ID, media type, original filename, byte size, checksum, capture source, and storage locator token. PA-01 does not choose buckets, object paths, signed-URL policy, retention technology, or upload implementation.

### 8.2 Quantity application and double-count prevention

Each physical evidence record has one or more immutable `EvidenceApplication` children:

```text
EvidenceApplication
- evidence_application_id
- evidence_id
- fulfilment_allocation_revision_id
- fulfilment_allocation_line_id
- applied_quantity
- applied_unit
- validity status / supersession link
```

Rules:

1. An active application points to exactly one allocation line and its exact revision.
2. Sum of active applications for one evidence record must not exceed the evidence quantity after unit normalization.
3. Sum of valid evidence applied to an allocation line is the only quantity counted as physically fulfilled.
4. Duplicate application of the same evidence to the same allocation line is rejected by identity/idempotency constraints.
5. A single evidence record may cover multiple allocation lines only through separate application quantities whose sum stays within the recorded quantity.
6. Reallocation does not move evidence. New allocation revisions require new applications only when the evidence fact genuinely applies and the source owner explicitly records that link.

### 8.3 Evidence ownership

| Evidence                     | Owner                                   | Required linkage and correction rule                                                                                                                            |
| ---------------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Supplier receiving evidence  | Authorized receiving process/actor      | PO line and supplier-source allocation line; observed quantity, supplier document, actor/time. Supersede/void by receiving authority.                           |
| Supplier cross-dock evidence | Authorized cross-dock/receiving process | Supplier-source allocation line and handoff/staging reference. It is not Warehouse stock unless Warehouse separately receives it.                               |
| Warehouse receiving evidence | Warehouse                               | Receiving Session/line and PO line; released Goods Receipt is immutable. Correct by receipt correction/reversal.                                                |
| Warehouse Stock Release      | Warehouse                               | Warehouse allocation line, stock lot, pick/release line, handoff evidence, and negative stock movement. Correct by explicit reversal/adjustment; never by edit. |
| Delivery evidence            | Dispatch/destination-authorized actor   | Stop, load line, delivered quantity, receiver/handover metadata. Correct by superseding confirmation/evidence.                                                  |
| Delivery Exception           | Dispatch                                | Stop/load line, exception quantity, type, reason, actor/time; resolution remains explicit.                                                                      |
| Return Evidence              | Dispatch/authorized return actor        | Exception and load line, returned quantity, handoff reference. It resolves Dispatch only; Warehouse separately records custody re-entry.                        |

## 9. Authoritative commands and transaction boundaries

All commands resolve the actor server-side where possible, validate capability, accept `command_id` and correlation context, append audit/event records in the same transaction, and return affected IDs plus new versions. `Idem` below means an idempotency key is mandatory. `Ver` means the expected aggregate version is mandatory.

| Command                                | Owner; inputs                                                                                                             | Preconditions                                                                                                                                                   | Atomic records changed; event                                                                                                                                              | Idem / Ver; failure behavior                                                                 |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Confirm need (`ApproveConfirmedNeeds`) | Planning; batch ID, expected version, actor context                                                                       | Validated, no blockers, source run released                                                                                                                     | Confirmed Need status/lines, approval snapshot, audit; `ConfirmedNeedsApproved`                                                                                            | Idem + Ver. Any failed line/permission rolls back all.                                       |
| Release Planning requirement           | Planning; approved demand/release IDs, line snapshots, destination/service date                                           | Approved source revisions; active destination or authorized override                                                                                            | Planning release, DispatchRequirement/lines, snapshot, audit; `DispatchRequirementReleased`                                                                                | Idem + source/batch Ver. No partial line release.                                            |
| Release Purchase Handoff               | Planning; batch ID/version                                                                                                | Validated, no blockers, Confirmed Need revision still matches                                                                                                   | Batch/lines, release snapshot, audit; `PurchaseHandoffReleasedToProcurement`                                                                                               | Idem + Ver. Roll back on stale source.                                                       |
| Create/release PO                      | Procurement; approved allocation revision, supplier, lines/terms, expected versions                                       | Approved allocation; eligible active supplier; released-source snapshot; draft validates without blockers                                                       | PO draft/revision, lines, release snapshot, audit; `PurchaseOrderDraftCreated` and, on release, `PurchaseOrderReleasedToSupplier`                                          | Idem + allocation/PO Ver. Entire PO action is atomic; it creates no Warehouse record.        |
| Revise/cancel PO                       | Procurement; current PO revision/version, affected lines, replacement supplier/quantity where applicable, reason          | Lifecycle permits correction; prior supplier response/evidence impact is known; actor has released-commitment authority                                         | New PO revision or cancellation snapshot, revision links, audit; `SupplierReplacementRecorded`, `PurchaseOrderReopened`, or `PurchaseOrderCancelled`                       | Idem + PO Ver. Prior release remains immutable; any validation failure rolls back.           |
| Record supplier PO confirmation        | Procurement; released PO revision, response status/lines, supplier reference, reason for partial/rejected/change response | PO released; response attributable; referenced lines belong to revision                                                                                         | SupplierConfirmation, PO readiness/status, issue/revision requirement, audit; `SupplierConfirmed`, `SupplierPartiallyConfirmed`, or `SupplierRejected`                     | Idem + PO Ver. It never creates physical receiving evidence.                                 |
| Allocate fulfilment                    | Procurement; requirement revision/lines, source portions, PO/warehouse request refs                                       | Requirement released; split reconciles; sources valid                                                                                                           | FulfilmentAllocation/lines/revision/audit; `FulfilmentAllocationCreated`                                                                                                   | Idem + requirement/allocation Ver. No evidence, trip, or stock write.                        |
| Revise fulfilment allocation           | Procurement; current allocation version, new split, reason                                                                | Prior allocation active; evidence/departure rules allow revision; affected owners identified                                                                    | New allocation revision/lines, supersession/additive links, audit; `FulfilmentAllocationRevised`                                                                           | Idem + Ver. Prior evidence and allocation remain unchanged.                                  |
| Record supplier evidence               | Receiving/cross-dock owner; PO/allocation line, quantity/unit, evidence metadata                                          | Supplier-source allocation active; actor authorized; quantity/unit valid                                                                                        | Source evidence, applications, audit; `SupplierReceivingEvidenceRecorded` or cross-dock event                                                                              | Idem + allocation revision check. Duplicate returns prior result; conflict rolls back.       |
| Confirm Warehouse receipt              | Warehouse; session/version, observed lines, discrepancies, accepted quantities                                            | PO released/confirmed for receiving; immutable PO snapshot matches; quantities reconcile                                                                        | Receiving lines/discrepancies, Goods Receipt, accepted stock/initial movement where approved, audit; `GoodsReceiptReleased`                                                | Idem + session/PO Ver. All stock creation rolls back if receipt release fails.               |
| Release Warehouse stock                | Warehouse; reservation/pick/release versions, allocation line, quantities, handoff evidence                               | Available traced stock; pick ready; warehouse allocation matches; no hold/expiry blocker                                                                        | WarehouseStockRelease/lines, evidence applications, negative StockMovement, stock/reservation versions, audit; `GoodsReleasedFromWarehouse` / `ReleaseStockMovementPosted` | Idem + all stock aggregate versions. Insufficient or stale stock rolls back everything.      |
| Create Dispatch plan                   | Dispatch; service date/wave, active requirement/allocation revision IDs                                                   | Requirements released; allocations present; destination rules satisfied                                                                                         | Plan and immutable upstream refs, audit; `DispatchPlanCreated`                                                                                                             | Idem + source revision checks. No upstream mutation.                                         |
| Assign Dispatch trip                   | Dispatch; plan version, trip/stop assignments, driver/vehicle refs                                                        | Plan active; requirements not assigned incompatibly                                                                                                             | Trip/stops/assignments, plan refs, audit; `DispatchTripAssigned`                                                                                                           | Idem + Plan/Trip Ver. Concurrent unrelated trips proceed independently.                      |
| Confirm load                           | Dispatch; trip version, requirement, load lines, exact evidence application IDs                                           | Trip assigned; every allocation portion has valid sufficient evidence; loaded quantity ≤ applied evidence and allocation                                        | DispatchLoad/lines, Trip/Stop status, audit; `DispatchLoadConfirmed`                                                                                                       | Idem + Trip/allocation/evidence versions. One invalid line rolls back the full load command. |
| Record departure                       | Dispatch; trip ID/version and departure time                                                                              | Trip loaded; every stop has a confirmed load; every loaded requirement portion still has sufficient valid evidence; no evidence void/supersession creates a gap | Trip/stops and Dispatch execution status/timestamp, audit; `DispatchDeparted`. Planning-owned requirement state is not updated.                                            | Idem + Trip Ver and evidence validation. Any gap blocks departure with no state change.      |
| Confirm delivery                       | Dispatch or authorized destination actor; stop/trip version, delivered/returned/exception quantities, evidence            | Trip in transit; load line exists; evidence present; line outcomes reconcile exactly to loaded quantity                                                         | DeliveryConfirmation/lines/evidence metadata, Stop/Trip state, audit; `DeliveryStopConfirmed`                                                                              | Idem + Trip/Stop Ver. No partial confirmation transaction.                                   |
| Record exception                       | Dispatch; stop/load line, quantity, type, reason/evidence                                                                 | Load exists; exception quantity valid and not already resolved elsewhere                                                                                        | DeliveryException and audit; `DeliveryExceptionRecorded`                                                                                                                   | Idem + Stop/Exception Ver. Does not edit Planning, Procurement, or Warehouse.                |
| Record return evidence                 | Dispatch/authorized return actor; exception, load line, quantity, handoff metadata                                        | Exception exists; returned quantity does not exceed unresolved quantity                                                                                         | ReturnEvidence, exception resolution state, Stop status, audit; `ReturnEvidenceRecorded`                                                                                   | Idem + Exception Ver. Does not create stock or stock movement.                               |
| Close trip                             | Dispatch; trip ID/version, reason when closing with exception                                                             | Every stop delivered or explicitly resolved; all quantities reconcile; required exception/return evidence valid                                                 | Trip/Plan and Dispatch-owned outcome records, closure audit; `DispatchTripCompleted`. Requirement outcome remains a derived read-model fact.                               | Idem + Trip Ver. Any unresolved line rolls back closure.                                     |

Transaction isolation is finalized in PA-02. Baseline direction is ordinary row-version checks plus row locks for most aggregate commands, with stronger serialization or equivalent retry-safe locking for stock reservation/release and other quantity-allocation races. A serialization/concurrency failure returns a structured retryable error and never a partial outcome.

## 10. Authorization capability model

Capabilities are enforced by backend commands and read access; UI visibility is advisory.

| Role / actor                      | Read scope                                                                                             | Writable commands                                                                                                                                   | Prohibited / override / correction authority                                                                                                                                                                  | Audit visibility                                                            |
| --------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Admin / master-data administrator | Admin plus downstream usage references needed for impact warnings                                      | Master-data create/update/status, recipe governance, role setup when separately authorized                                                          | No daily demand, allocation, stock, trip, or delivery mutation. May propose emergency override; cannot bypass quantity/evidence invariants. May correct Admin evidence.                                       | Full Admin audit; cross-domain summaries, not sensitive details by default. |
| Planning                          | Planning sources through released requirements; relevant master refs and downstream status read-only   | Menu/attendance/readiness/generation/Confirmed Need/Purchase Handoff/Dispatch Requirement commands                                                  | No supplier, physical evidence, stock, trip, or destination outcome. Planning lead capability required for post-release revision/override.                                                                    | Full Planning audit and downstream trace status.                            |
| Procurement                       | Released Planning demand; supplier master/eligibility; physical evidence and Dispatch status read-only | Assignment, allocation, PO, supplier-response, and allocation-revision commands                                                                     | No Planning quantity change, source evidence manufacture, stock movement, load, or delivery. Procurement lead capability required for released-commitment revision/cancel.                                    | Full Procurement audit and cross-domain evidence trace.                     |
| Warehouse / receiving             | Supplier commitments, allocation portions, Warehouse stock and downstream handoff status               | Supplier/cross-dock evidence when acting as receiving owner; receiving, discrepancy, stock, reservation, pick, Warehouse release, movement commands | No supplier commercial decision, Planning change, trip, delivery, QA approval, or Finance action. Warehouse supervisor corrects/voids Warehouse evidence.                                                     | Full Warehouse/evidence audit and relevant upstream trace.                  |
| Dispatch                          | Released requirements, allocations, valid evidence, location snapshots, Dispatch state                 | Plan, trip, assignment, load, departure, delivery, exception, return, closure                                                                       | No allocation, evidence manufacture for another source, stock, Planning, PO, QA, or Finance mutation. Dispatch supervisor corrects destination evidence and approves exception closure where policy requires. | Full Dispatch audit and upstream trace.                                     |
| Driver / reference actor          | Only assigned trip/stops and minimum evidence context                                                  | Submit delegated departure/delivery/exception/return evidence requests when explicitly enabled                                                      | Cannot directly update aggregates, reassign trip, allocate, release stock, or close exceptions outside delegated capability. Identity may remain a reference until an approved auth contract promotes it.     | Own submissions and assigned-trip history.                                  |
| Management / read-only            | Broad operational and audit read according to sensitive-data scope                                     | No routine writes; separately granted approval/override commands only                                                                               | Override requires reason and never bypasses immutable history, evidence sufficiency, stock non-negativity, or reconciliation. Can authorize source-owner correction but does not edit evidence directly.      | Broad cross-domain audit, overrides, and cancellations.                     |
| System / integration actor        | Only declared adapter/API scope                                                                        | Idempotent import, synchronization, or evidence commands explicitly granted to its integration identity                                             | No interactive admin rights, no broad table write, no service-role use from React. Corrections use the same supersession commands as humans.                                                                  | Its own complete command/event history; security admins can review all.     |

Evidence correction belongs to the source owner. Management may authorize or co-approve a correction but must not replace the original actor/source attribution. Emergency Admin access is separately permissioned, reasoned, time-bounded where possible, and audited.

## 11. Audit strategy

Append-only audit evidence is mandatory for:

- every status transition, release, reopen, invalidation, supersession, void, and cancellation;
- quantity adjustment/revision and before/after unit-normalized values;
- supplier, PO, fulfilment allocation, or warehouse allocation revision;
- master-data status/effective-period changes affecting future operations;
- destination/location override and any override of an inactive reference;
- evidence correction, void, supersession, or application change;
- stock reservation, receipt, release, reversal, and adjustment;
- trip departure and closure, especially `CLOSED_WITH_EXCEPTION`;
- privileged export, emergency access, and management override when implemented.

Minimum audit envelope:

```text
audit_event_id
source_domain
aggregate_type / aggregate_id
aggregate_version_before / aggregate_version_after
event_type
command_id / correlation_id / idempotency_key
actor_id / actor_type / delegated_actor_id
occurred_at / recorded_at
reason_code / reason_note
before_summary / after_summary or immutable version references
source_interface / integration_reference
override_authority when applicable
```

Sensitive commands append the audit event in the same transaction. Audit events are never used as the only current-state store and PA-01 does not require full event sourcing.

## 12. Derived read models

Operational read models must reflect committed command results immediately on the next read. Regular views or stable RPC results are preferred for live workbenches; materialized views are unsuitable for departure, stock, or exception gates unless synchronously refreshed in the same transaction, which is not the baseline recommendation.

| Read model                    | Authoritative sources and derivations                                                                                                                                       | Recommended delivery / refresh                                                                                                                 |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Control Board                 | Planning issues/releases, Procurement allocation/PO issues, receiving/evidence gaps, stock release blockers, Dispatch exceptions; derives owner, age, priority, next action | Database view(s) behind a typed RPC result; read-time/current. Current hard-coded React queue is application-only.                             |
| Planning workbench            | Weekly Menu, Attendance, PlanningInputSet, NeedGenerationRun, Confirmed Need, Purchase Handoff, snapshots/issues                                                            | Domain-specific database views/RPC results; current after each command.                                                                        |
| Procurement attention queue   | Released handoff/requirements, supplier eligibility, allocations, PO status, supplier response, evidence gaps                                                               | Database view; current. It shows physical evidence read-only.                                                                                  |
| Warehouse receiving           | Released/confirmed PO snapshots, Receiving Sessions/lines, discrepancies, Goods Receipts                                                                                    | Database view/RPC result; current.                                                                                                             |
| Warehouse Stock Release       | Stock movement ledger, active reservations, picks, release/evidence applications                                                                                            | Database view/RPC result; current and transactionally consistent.                                                                              |
| Dispatch morning control      | Requirement and allocation revisions, evidence applications, trips/stops/loads, confirmations/exceptions/returns                                                            | Stable RPC result or database view set; current. Must derive `evidenceReady` per allocation line and total requirement.                        |
| MVP operating-day trace       | Cross-domain canonical line IDs, snapshots, evidence, trip and destination outcomes                                                                                         | Database view or read-only RPC composed from domain-owned sources; current. Synthetic scenario wrappers are not persisted.                     |
| Owner-grouped attention queue | Unresolved source facts plus deterministic owner mapping                                                                                                                    | Database view/RPC; current. Owner is derived, not editable workflow state.                                                                     |
| Audit timeline                | Domain audit/event records joined to immutable snapshots                                                                                                                    | Database view/RPC; current with access filtering.                                                                                              |
| QA/diagnostic                 | Integrity diagnostics such as broken trace, duplicate active revision, evidence over-application, and reconciliation errors                                                 | Admin-only diagnostic RPC/view. No QA operational workflow or QA approval state is introduced. Retool may consume it later as support tooling. |

Action flags such as `canApprove`, `readyToLoad`, `nextAvailableAction`, lateness, uncovered quantity, closure readiness, and attention ownership are derived. They are never hidden authoritative state in React.

## 13. Soft delete, archive, and temporal rules

- Master data uses active/inactive status and optional effective periods. Referenced master data is never physically deleted.
- Operational aggregates are never soft-deleted as a substitute for cancellation. They use lifecycle status, archive visibility, and immutable audit.
- Archive hides completed/inactive records from default work queues after retention policy permits; it does not break foreign keys or trace.
- Effective periods use an unambiguous interval convention selected in PA-02; overlapping active rules for the same scope are rejected unless precedence explicitly allows them.
- Delivery-location deactivation blocks new release/plan use unless an authorized override is recorded. Existing releases retain location snapshots.
- Supplier eligibility and unit conversions are effective-dated. Procurement validates the rule effective at its decision/release time and snapshots the result.
- Recipe/BOM versions have validity/release periods. Need Generation records the exact version and rules used.
- Posted stock movements, released documents, evidence, audit events, and referenced operational records cannot be deleted.
- Actor/user deactivation preserves historical attribution.
- Timestamps are stored as absolute instants. `service_date` is a separate Asia/Bangkok business date; local dispatch windows retain an explicit timezone/offset contract.

## 14. Legacy migration boundary

OPS v1 and Retool are evidence, not the Atlas target model.

### May migrate or reference

- schools/customers, delivery locations, ingredients, units, suppliers, supplier eligibility, dishes, recipes, and BOM lines after deduplication, identity assignment, status/effective-date review, and unit validation;
- selected open operational records only when a cutover workflow requires them and an explicit owner approves the transform;
- historical document references needed for audit or customer/supplier lookup;
- legacy IDs only as `LegacySourceReference` records linked to canonical Atlas IDs.

### Must be transformed

- daily orders/menu/attendance into controlled Planning source aggregates and versions;
- actual need overrides into source/adjustment/audit records with clear quantity semantics;
- composite-key requirements into stable canonical line identities and source trace;
- purchase assignments/POs into explicit allocation, commitment, revision, and snapshot shapes;
- dispatch/receiving history into source-owned physical and destination evidence only when the source is complete enough to reconcile.

### Should remain historical or should not be copied

- Incomplete historical operational data may remain read-only in OPS v1/archive with adapter references rather than becoming low-trust Atlas facts.
- Retool temporary state, component state, JavaScript transformers, event handlers, helper queries, duplicate cached outputs, UI-only flags, obsolete triggers/helpers, credentials, service keys, and unverified derived data are not copied.
- No current table, trigger, function, or Retool page is adopted as an Atlas aggregate merely because it exists.

### Coexistence and authorization

Only one system owns writes for a workflow at a time. Adapters are read-only unless a separately approved integration command owns an explicit handoff. Migration rehearsal uses immutable extraction batches, counts, mapping reports, reconciliation, and rollback criteria. This document authorizes no production extraction, schema change, data copy, dual write, or cutover.

## 15. Persistence risks and open PA-02 decisions

| Topic                       | PA-01 direction                                                                                          | Decision still required before implementation                                                                                            |
| --------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Canonical IDs               | Opaque server-generated UUIDs; immutable and separate from display refs                                  | UUID version/generator, offline/import generation policy, and collision/ordering expectations.                                           |
| Status representation       | Lifecycles are domain-specific contracts                                                                 | PostgreSQL enum vs text/check vs controlled lookup. Prefer schema-change-friendly constraints; do not create one generic workflow table. |
| Schema namespaces           | Logical ownership follows Admin, Planning, Procurement, Warehouse, Dispatch, Audit/Reporting, API/Legacy | Physical schema names and whether some modules share a schema. Existing `ops3_*` names are provisional.                                  |
| Evidence files              | Persist append-only metadata and checksum/locator contract                                               | Storage provider/bucket, malware checks, access URLs, retention, deletion/legal-hold policy, and offline capture.                        |
| Isolation and concurrency   | Optimistic versions everywhere; locking/serialization for stock and allocation races                     | Exact isolation level, lock ordering, retry policy, and deadlock tests.                                                                  |
| Idempotency                 | Mandatory for release, evidence, movement, departure, delivery, and integration commands                 | Key scope, retention period, canonical response replay, and conflict error contract.                                                     |
| Legacy IDs                  | Source references only                                                                                   | Exact source inventory, mapping ownership, duplicate handling, and historical retention.                                                 |
| Document numbering          | Human-readable immutable reference separate from UUID                                                    | Series scope, format, sequence gaps, revision suffix, and offline issuance.                                                              |
| Time and service date       | Absolute timestamps plus Asia/Bangkok service date                                                       | Cutoff policy, DST-safe implementation for future regions, and late-arrival date attribution.                                            |
| Quantity precision/rounding | Decimal quantities, explicit unit, rule version, no binary float; evidence applications reconcile        | Precision/scale by unit role, rounding mode/boundary, conversion tolerance, and overage policy.                                          |
| Multi-line/multi-trip       | Lines are stable; Trips are independent; portions link through load/evidence applications                | Partial load/departure policy, one requirement across trips, reloading after return, and final reconciliation constraints.               |
| Production/QA and Finance   | Reserved references only; no current ownership expansion                                                 | Future contracts, schemas, approvals, costing, invoices, and accounting integration.                                                     |

Additional risks are incomplete legacy evidence, accidental persistence of fixture identifiers, treating attention ownership as editable state, evidence correction that bypasses application reconciliation, and using asynchronous/materialized read models for safety-critical command gates.

## 16. Recommended implementation sequence

1. **PA-02 schema design:** map every authoritative aggregate, immutable snapshot, event, evidence/application, and cross-domain line reference; resolve the open physical decisions above; add no UI behavior.
2. **Authorization and RLS design:** produce the capability-to-command/read matrix, internal-table exposure rules, integration identities, emergency access, and test cases before frontend access.
3. **Command/RPC implementation:** start with identity, idempotency, audit envelope, optimistic concurrency, and one bounded command chain; keep business writes behind commands.
4. **Seed/reference data:** controlled units, statuses/check vocabularies, roles/capabilities, and minimal reviewed master data; never seed production credentials or copy unreviewed legacy rows.
5. **First connected vertical slice:** one wholesale direct-ingredient line through controlled Planning approval, Purchase Handoff, Procurement/PO, supplier-direct evidence, Dispatch load, and delivery. This follows the approved rollout direction and avoids requiring recipe migration. Add the warehouse-stock evidence path as the next bounded slice before operational cutover.
6. **Migration rehearsal:** immutable OPS v1 extraction, source-to-canonical mapping, duplicate/data-quality report, dry-run counts, trace sampling, rollback rehearsal, and no production write ownership change.
7. **Operator validation:** run the five vertical-slice scenarios and the 02:00–08:00 chaos cases against the connected environment, including School 05 additive revision, School 10 partial fallback, concurrent trips, rejection/return, and blocked departure.
8. **Staged rollout:** pilot with one explicitly owned workflow, parallel reconciliation, monitored rollback window, operator acceptance, then separately approve each additional write-owner transfer.

PA-02 must not begin until this contract and its companion decision record are reviewed. Production migration and rollout require separate approvals after schema, authorization, command, reconciliation, and operator evidence exist.

## 17. Scope exclusions and migration effect

PA-01 adds no Supabase migration, PostgreSQL object, RLS policy, RPC, Edge Function, generated database type, Supabase client, backend integration, credential, production-data operation, Retool change, React behavior, fixture behavior, or domain command. It does not modify ARCH-001 or ARCH-002 and does not implement Production/QA, Finance/Accounting, route optimization, GPS, payroll, fleet maintenance, or a generic workflow engine.

There is no database migration or rollback effect. Documentation rollback is a normal Git revert. No production system is changed.
