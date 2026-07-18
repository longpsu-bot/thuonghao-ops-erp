# PA-06A — Application Connection Contract

**Status:** Proposed documentation contract; pending review
**Baseline:** `59640c33ec3eb759c28659991a751261cdb352ab`
**Scope:** Application contract and operator workflow planning only
**Canonical API registry:** This document is the sole PA-06A source for the exact 18-function application-facing registry.

## 1. Decision

PA-06A defines how a staff-facing React application may coordinate the accepted Atlas backend without becoming authoritative for business rules.

The accepted boundary remains exactly:

- 14 write commands;
- four authorized reads;
- authenticated subject resolution and active-actor checks on the server;
- capability and relational scope enforcement on the server;
- exact payload allowlists;
- optimistic concurrency;
- command identity and idempotency;
- domain events and audit events;
- safe operator responses;
- no browser access to private Atlas relations;
- no browser service-role credential.

PA-06A changes no backend contract, lifecycle, migration, grant, RLS policy, production data, Retool application, or hosted environment.

The first connected slice remains a decision for PA-06C. **Supplier Evidence & Readiness is the leading hypothesis only for an isolated known-context pilot.** It is not approved as a production work queue because the current read boundary does not discover Purchase Orders or allocation lines.

## 2. Authority and reviewed repository artifacts

Authority is applied in the order required by `AGENTS.md`:

1. approved repository documentation;
2. migrations and pgTAP;
3. application code;
4. discussion and memory.

Primary reviewed sources include:

- `AGENTS.md`;
- `README.md`;
- `docs/handbook/01-vision-product-charter.md`;
- `docs/decisions/decision-register.md`;
- `docs/business-rules/business-rule-register.md`;
- `docs/architecture/arch-001-ops-erp-business-architecture.md`;
- `docs/architecture/arch-002-atlas-system-map.md`;
- `docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md`;
- `docs/architecture/pa-05b-supplier-direct-command-implementation.md`;
- `docs/architecture/pa-05c-authorized-read-api-wrappers.md`;
- `docs/architecture/pa-05c-h2-current-command-timeline-scope-contract.md`;
- `docs/architecture/pa-05d-planning-command-family-contract.md`;
- `docs/architecture/pa-05e-procurement-command-family-contract.md`;
- `docs/architecture/pa-05f-dispatch-setup-command-family-contract.md`;
- `docs/architecture/pa-05b-h2-multiline-dispatch-execution-contract.md`;
- `docs/architecture/pa-05b-h3-successful-trip-closure-contract.md`;
- `docs/architecture/pa-05g-backend-end-to-end-acceptance-contract.md`;
- their merged migrations and focused pgTAP suites.

Current frontend artifacts are:

- page configuration: `src/modules/atlas/atlasConfig.ts`;
- React shell: `src/modules/atlas/AtlasApp.tsx`;
- shared workbench primitives: `src/modules/atlas/WorkbenchComponents.tsx`;
- package baseline: `package.json`;
- active local-fixture UI requirements: `docs/ui/atlas-workbench-requirements.md`;
- superseded workflow note: `docs/ui/atlas-three-stage-workflow.md`.

The phrase “five-page prototype” is imprecise. The active requirements document identifies a control board plus five daily work pages. The separate three-stage prototype note is explicitly superseded.

## 3. OPS_SYSTEM_MAP application capability map

| Mission | Business capability | Domain | Business object | Registry entries | Operator workflow | Application workbench |
|---|---|---|---|---|---|---|
| Convert an accepted wholesale source into authoritative released demand | Record and release wholesale demand | Planning | Wholesale Order, Confirmed Need Batch | CMD-01, CMD-02 | Capture exact customer demand, then release it | Planning Source & Release |
| Hand released demand to Procurement and delivery planning | Release Purchase Handoff and Dispatch Requirement | Planning | Purchase Handoff, Dispatch Requirement | CMD-03, CMD-04 | Verify released lineage and issue downstream Planning contracts | Planning Source & Release |
| Commit exact released demand to suppliers | Allocate supplier-direct fulfilment and release supplier POs | Procurement | Fulfilment Allocation, Purchase Order | CMD-05, CMD-06 | Assign all requirement lines exactly and release supplier commitments | Procurement Commitment |
| Prove physical supplier fulfilment | Record and apply supplier Evidence | Evidence | Supplier Receiving Evidence, Evidence Application | CMD-07, CMD-08, READ-02, READ-03 | Record a supplier document, apply exact quantities, inspect readiness | Supplier Evidence & Readiness |
| Prepare evidence-gated transport | Create a Dispatch Plan and assigned Trip/Stops | Dispatch | Dispatch Plan, Trip, Stop | CMD-09, CMD-10, READ-02, READ-03 | Admit fully evidenced obligations and assign exact stops | Dispatch Setup |
| Execute and close successful transport | Load, depart, deliver, and close | Dispatch | Dispatch Load, Trip, Stop, Delivery Confirmation | CMD-11 through CMD-14, READ-01 through READ-04 | Reconcile physical quantities and complete the trip | Dispatch Execution |
| Explain authoritative outcomes | Trace, readiness, blockers, and audit | Reporting / Audit | Authorized projections over accepted aggregates | READ-01 through READ-04 | Explain source, quantity, state, command outcome, and actor evidence | Trace & Audit panel |

## 4. AGENTS.md three-stage baseline reconciliation

`AGENTS.md` defines the active baseline as:

1. Requirement Planning;
2. Purchase Planning;
3. Warehouse Receiving.

PA-06A does not silently replace that baseline. It makes the following explicit decision:

- CMD-01 through CMD-04 belong within **Requirement Planning**.
- CMD-05 and CMD-06 belong within **Purchase Planning**.
- Supplier-direct Evidence in CMD-07 and CMD-08 does **not** belong to Warehouse Receiving. The accepted business contract assigns the fact to the Evidence domain and expressly excludes Warehouse mutation.
- Dispatch setup and execution do not belong to Warehouse Receiving.
- Therefore, the accepted supplier-direct wholesale path is a **bounded extension to the three-stage baseline**, not a redefinition of Warehouse Receiving and not a new generic ERP workflow model.

This leaves a documentation governance tension: the three-stage baseline is valid for its original active scope but is not a complete application map for the accepted supplier-direct wholesale path. Changing `AGENTS.md` is outside PA-06A. A later architecture-governance change should update the baseline only after product and architecture review.

The existing local prototype’s “Warehouse Receiving” page must not be relabeled or connected to supplier Evidence merely to fit the three-stage navigation.

## 5. Common command and read rules

### 5.1 Shared write envelope

Every write command accepts exactly:

```json
{
  "contract_version": "command-family version",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "non-empty text, max 200",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "non-future timestamptz",
  "reason_code": "non-empty text",
  "reason_note": null,
  "payload": {}
}
```

The frontend coordinates these values. The backend remains authoritative for actor resolution, capability, scope, lifecycle, lineage, quantity, version, idempotency, events, and audit.

### 5.2 Shared write success

Successful commands return the established categories:

```text
success
command_id
correlation_id
idempotency_status
affected_aggregate_ids
new_versions
emitted_event_ids
audit_event_ids
safe_operator_message
warnings
blockers
```

Some commands return one additional allowlisted value, such as `derived_service_date` or `completed_at`; those fields are recorded in the entry below.

### 5.3 Shared safe error

Safe errors use:

```text
success = false
error_code
safe_message
domain
command_name
retryable
field_errors
blocking_references
expected_version
actual_version
correlation_id
command_id
```

Common classes include authentication or subject failure, `CAPABILITY_DENIED`, `SCOPE_DENIED`, `VALIDATION_FAILED`, `INVARIANT_VIOLATION`, `STALE_VERSION`, `IDEMPOTENCY_CONFLICT`, `RETRYABLE_CONCURRENCY_FAILURE`, command-specific reconciliation or evidence errors, and `INTERNAL_COMMAND_FAILURE`.

The application must not show raw SQL, policies, roles, JWT content, credentials, stack traces, or service-role information.

### 5.4 Exact replay and changed reuse

For every write entry:

- the first accepted request creates one command receipt;
- exact replay returns the stored original response and original IDs;
- changed reuse of the same command ID or scoped idempotency key returns `IDEMPOTENCY_CONFLICT`;
- exact retry after a retryable concurrency failure reuses the entire immutable request;
- an operator edit creates a new command intent with a new command ID and idempotency key.

### 5.5 Read behavior

Reads are bounded, authorized, shaped, read-only projections. They create no receipt, event, audit event, task, or lifecycle state. They are advisory and never command safety gates. Read transport failures may be retried normally, but reads have no write-command replay, idempotency, stale-version, or concurrency semantics.

## 6. Canonical Atlas API registry

No other PA-06A document may restate these exact payloads, selectors, affected-ID keys, version keys, or command semantics. Other documents reference the stable IDs below.

<a id="cmd-01"></a>
### CMD-01 — `atlas_api.record_wholesale_source(jsonb)`

- **Contract version:** `PA-05D.v1`
- **Required capability:** `wholesale_source.record`
- **Payload:**

```json
{
  "customer_id": "uuid",
  "delivery_location_id": "uuid",
  "customer_order_reference": "text",
  "service_date": "YYYY-MM-DD",
  "lines": [
    {
      "source_line_number": 1,
      "ingredient_id": "uuid",
      "requested_quantity": 10,
      "unit_id": "uuid"
    }
  ]
}
```

- **Authoritative aggregate:** Wholesale Order.
- **IDs and versions consumed:** active wholesale `customer_id`; matching active `delivery_location_id`; active `ingredient_id` and `unit_id` per line; `expected_version = 1`.
- **IDs and versions returned:** `affected_aggregate_ids.wholesale_order_id`; `wholesale_order_line_ids`; `wholesale_order_line_revision_ids`; `new_versions.wholesale_order_version = 1`.
- **Lifecycle transition:** creates one Wholesale Order in `DRAFT`, version 1, and Draft line revisions.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus duplicate active customer reference and inactive or mismatched reference invariants.
- **Stale-version behavior:** not a refresh conflict; any `expected_version` other than 1 is validation failure because the root is new.
- **Retryable-concurrency behavior:** exact request may be retried on `RETRYABLE_CONCURRENCY_FAILURE`.
- **Exact replay:** returns the original order and line IDs.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `WholesaleOrderRecorded` and one audit event; READ-04 can use command, correlation, or Wholesale Order aggregate context.
- **Next permitted operator action:** CMD-02 after reviewing the recorded Draft and carrying version 1.

<a id="cmd-02"></a>
### CMD-02 — `atlas_api.release_wholesale_order(jsonb)`

- **Contract version:** `PA-05D.v1`
- **Required capability:** `wholesale_order.release`
- **Payload:** `{"wholesale_order_id":"uuid"}`
- **Authoritative aggregate:** Wholesale Order; the transaction also creates a Confirmed Need Batch and approval snapshot.
- **IDs and versions consumed:** `wholesale_order_id`; current Wholesale Order `expected_version`.
- **IDs and versions returned:** `wholesale_order_id`; `confirmed_need_batch_id`; `confirmed_need_line_ids`; `confirmed_need_line_revision_ids`; `confirmed_need_approval_snapshot_id`; `confirmed_need_snapshot_line_ids`; `new_versions.wholesale_order_version`; `confirmed_need_batch_version = 1`.
- **Lifecycle transition:** Wholesale Order `DRAFT → RELEASED`; creates Confirmed Need Batch `RELEASED_FOR_PURCHASE_HANDOFF`, version 1.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus incomplete source lines, inactive references, prior downstream need, or duplicate Confirmed Need.
- **Stale-version behavior:** `STALE_VERSION` returns the current Wholesale Order version; refresh and review before a new intent.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original released order, Confirmed Need, snapshot, and line IDs.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `WholesaleOrderReleased` on `WholesaleOrder`; READ-04 can show the command and aggregate history.
- **Next permitted operator action:** CMD-03 using the returned Confirmed Need Batch ID and version 1.

<a id="cmd-03"></a>
### CMD-03 — `atlas_api.release_purchase_handoff(jsonb)`

- **Contract version:** `PA-05D.v1`
- **Required capability:** `purchase_handoff.release`
- **Payload:** `{"confirmed_need_batch_id":"uuid"}`
- **Authoritative aggregate:** Purchase Handoff.
- **IDs and versions consumed:** `confirmed_need_batch_id`; current Confirmed Need Batch `expected_version`.
- **IDs and versions returned:** `purchase_handoff_batch_id`; `purchase_handoff_revision_id`; `purchase_handoff_line_ids`; `purchase_handoff_line_revision_ids`; `purchase_demand_reference_ids`; `new_versions.purchase_handoff_version = 1`.
- **Lifecycle transition:** creates Purchase Handoff `RELEASED_TO_PROCUREMENT`, version 1.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus incomplete released snapshot, cross-wired source lineage, inactive references, or prior handoff.
- **Stale-version behavior:** `STALE_VERSION` returns the current Confirmed Need Batch version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original handoff, revision, lines, and demand references.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `PurchaseHandoffReleased`; READ-04 supports the Purchase Handoff aggregate.
- **Next permitted operator action:** CMD-04 using the returned Handoff revision ID and Handoff root version 1.

<a id="cmd-04"></a>
### CMD-04 — `atlas_api.release_dispatch_requirement(jsonb)`

- **Contract version:** `PA-05D.v1`
- **Required capability:** `dispatch_requirement.release`
- **Payload:** `{"purchase_handoff_revision_id":"uuid"}`
- **Authoritative aggregate:** Dispatch Requirement.
- **IDs and versions consumed:** `purchase_handoff_revision_id`; current Purchase Handoff root `expected_version`.
- **IDs and versions returned:** `dispatch_requirement_id`; `dispatch_requirement_revision_id`; `dispatch_requirement_line_ids`; `dispatch_requirement_line_revision_ids`; `new_versions.dispatch_requirement_version = 1`.
- **Lifecycle transition:** creates one wholesale Dispatch Requirement `RELEASED`, version 1.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus cross-wired or multi-scope handoff lineage, inactive destination, or duplicate current requirement.
- **Stale-version behavior:** `STALE_VERSION` returns the current Handoff root version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original requirement, revision, and line IDs.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `DispatchRequirementReleased`; READ-04 supports the Dispatch Requirement aggregate.
- **Next permitted operator action:** CMD-05 using the returned requirement revision, exact line revisions, and requirement version 1.

<a id="cmd-05"></a>
### CMD-05 — `atlas_api.allocate_supplier_direct_fulfilment(jsonb)`

- **Contract version:** `PA-05E.v1`
- **Required capability:** `supplier_direct_fulfilment.allocate`
- **Payload:**

```json
{
  "dispatch_requirement_revision_id": "uuid",
  "lines": [
    {
      "dispatch_requirement_line_revision_id": "uuid",
      "supplier_id": "uuid",
      "allocated_quantity": 10,
      "unit_id": "uuid"
    }
  ]
}
```

- **Authoritative aggregate:** Fulfilment Allocation.
- **IDs and versions consumed:** current released requirement revision and every exact line revision; active suppliers and units; current Dispatch Requirement `expected_version`.
- **IDs and versions returned:** `fulfilment_allocation_id`; `fulfilment_allocation_revision_id`; `fulfilment_allocation_line_ids`; `fulfilment_allocation_line_revision_ids`; `new_versions.fulfilment_allocation_version = 1`.
- **Lifecycle transition:** creates allocation root/revision `READY_FOR_DISPATCH`, version 1; line revisions `READY_FOR_EVIDENCE`.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus missing or duplicate line coverage, quantity/unit mismatch, cross-wired Planning lineage, inactive supplier, or prior allocation.
- **Stale-version behavior:** `STALE_VERSION` returns current Dispatch Requirement version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original allocation IDs.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `SupplierDirectFulfilmentAllocated`; READ-04 supports the Fulfilment Allocation aggregate.
- **Next permitted operator action:** CMD-06 once for each supplier represented by the returned allocation revision.

<a id="cmd-06"></a>
### CMD-06 — `atlas_api.release_supplier_purchase_order(jsonb)`

- **Contract version:** `PA-05E.v1`
- **Required capability:** `supplier_purchase_order.release`
- **Payload:** `{"fulfilment_allocation_revision_id":"uuid","supplier_id":"uuid","document_number":"text"}`
- **Authoritative aggregate:** Purchase Order.
- **IDs and versions consumed:** current allocation revision; selected active supplier; unique document number; current Fulfilment Allocation `expected_version`.
- **IDs and versions returned:** `purchase_order_id`; `purchase_order_revision_id`; `purchase_order_line_ids`; `purchase_order_line_revision_ids`; `fulfilment_allocation_id`; `fulfilment_allocation_revision_id`; `new_versions.purchase_order_version = 1`; unchanged `fulfilment_allocation_version`.
- **Lifecycle transition:** creates one supplier PO `RELEASED_TO_SUPPLIER`, version 1; allocation root is not incremented.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus duplicate supplier/allocation PO, duplicate document number, missing selected supplier lines, or lineage mismatch.
- **Stale-version behavior:** `STALE_VERSION` returns current allocation version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original supplier PO and line IDs.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `SupplierPurchaseOrderReleased`; READ-04 supports the Purchase Order aggregate.
- **Next permitted operator action:** CMD-07 for each returned PO line when physical supplier evidence exists.

<a id="cmd-07"></a>
### CMD-07 — `atlas_api.record_supplier_receiving_evidence(jsonb)`

- **Contract version:** `PA-05B.v1`
- **Required capability:** `supplier_receiving_evidence.record`
- **Payload:**

```json
{
  "purchase_order_line_revision_id": "uuid",
  "supplier_id": "uuid",
  "ingredient_id": "uuid",
  "unit_id": "uuid",
  "evidence_quantity": 10,
  "evidence_reference": "text",
  "occurred_at": "timestamptz"
}
```

- **Authoritative aggregate:** Supplier Receiving Evidence.
- **IDs and versions consumed:** exact released PO line revision; matching supplier, ingredient, and unit; current Purchase Order `expected_version`.
- **IDs and versions returned:** `supplier_receiving_evidence_id`; `purchase_order_id`; `new_versions.purchase_order_version` containing the guarded current PO version.
- **Lifecycle transition:** creates one `VALID` supplier evidence record; the Purchase Order is not mutated.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus duplicate evidence reference, non-positive or future evidence, stale PO, or mismatch with the released supplier commitment.
- **Stale-version behavior:** `STALE_VERSION` returns current Purchase Order version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original evidence ID.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `SupplierReceivingEvidenceRecorded`; READ-02, READ-03, and READ-04 may show the resulting evidence context.
- **Next permitted operator action:** CMD-08 using the returned Evidence ID and an exact allocation-line revision.

<a id="cmd-08"></a>
### CMD-08 — `atlas_api.apply_supplier_evidence_to_allocation(jsonb)`

- **Contract version:** `PA-05B.v1`
- **Required capability:** `supplier_evidence_application.apply`
- **Payload:**

```json
{
  "supplier_receiving_evidence_id": "uuid",
  "fulfilment_allocation_line_revision_id": "uuid",
  "unit_id": "uuid",
  "applied_quantity": 10,
  "occurred_at": "timestamptz"
}
```

- **Authoritative aggregate:** Evidence Application.
- **IDs and versions consumed:** current valid Evidence; exact allocation-line revision; matching unit; current Fulfilment Allocation `expected_version`.
- **IDs and versions returned:** `evidence_application_id`; `supplier_receiving_evidence_id`; `fulfilment_allocation_id`; `new_versions.fulfilment_allocation_version` containing the guarded current allocation version.
- **Lifecycle transition:** creates one `VALID` Evidence Application; the allocation root is not incremented.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus `EVIDENCE_VOIDED`, `EVIDENCE_OVER_APPLIED`, duplicate current application, or supplier/item/unit lineage mismatch.
- **Stale-version behavior:** `STALE_VERSION` returns current allocation version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original application ID.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `EvidenceAppliedToAllocation`; READ-02 and READ-03 expose readiness and blockers; READ-04 supports the Evidence Application aggregate.
- **Next permitted operator action:** repeat CMD-07/CMD-08 as needed, then use READ-02. CMD-09 is permitted only after every selected line is fully and currently evidenced.

<a id="cmd-09"></a>
### CMD-09 — `atlas_api.create_dispatch_plan(jsonb)`

- **Contract version:** `PA-05F.v1`
- **Required capability:** `dispatch_plan.create`
- **Payload:**

```json
{
  "plan_reference": "text",
  "dispatch_wave": "text or null",
  "requirements": [
    {
      "dispatch_requirement_revision_id": "uuid",
      "fulfilment_allocation_revision_id": "uuid",
      "expected_dispatch_requirement_version": 1,
      "expected_fulfilment_allocation_version": 1
    }
  ]
}
```

- **Authoritative aggregate:** Dispatch Plan.
- **IDs and versions consumed:** exact released requirement/allocation pairs and their named current versions; envelope `expected_version = 1` for the new Plan.
- **IDs and versions returned:** `dispatch_plan_id`; `dispatch_plan_requirement_ids`; `new_versions.dispatch_plan_version = 1`; top-level `derived_service_date`.
- **Lifecycle transition:** creates Plan `PLANNED`, version 1, and exact memberships.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus duplicate reference/membership, mixed dates, stale named upstream versions, missing or partial evidence, released-PO mismatch, or existing load/membership.
- **Stale-version behavior:** named upstream version mismatch is a safe stale/invariant failure; the new Plan envelope remains version 1.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns the original Plan and membership IDs.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `DispatchPlanCreated`; READ-04 supports the Dispatch Plan aggregate.
- **Next permitted operator action:** CMD-10 using the returned Plan ID and Plan version 1.

<a id="cmd-10"></a>
### CMD-10 — `atlas_api.create_or_assign_dispatch_trip(jsonb)`

- **Contract version:** `PA-05F.v1`
- **Required capability:** `dispatch_trip.assign`
- **Payload:**

```json
{
  "dispatch_plan_id": "uuid",
  "trip_reference": "text",
  "driver_actor_id": "uuid or null",
  "vehicle_reference": "text or null",
  "planned_departure_at": "timestamptz or null",
  "stops": [
    {
      "dispatch_plan_requirement_id": "uuid",
      "stop_sequence": 1
    }
  ]
}
```

- **Authoritative aggregate:** Dispatch Trip; the parent Plan version also changes.
- **IDs and versions consumed:** current Plan ID/version; exact unassigned membership IDs; valid driver and/or vehicle assignment.
- **IDs and versions returned:** `dispatch_plan_id`; `dispatch_trip_id`; `dispatch_stop_ids`; `new_versions.dispatch_plan_version`; `dispatch_trip_version = 1`; `dispatch_stop_versions` as objects containing stop ID and version.
- **Lifecycle transition:** creates Trip `ASSIGNED`, version 1; Stops `PENDING`, version 1; increments Plan once while retaining `PLANNED`.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus invalid assignment, duplicate/non-contiguous stop sequence, already assigned membership, stale evidence, duplicate trip reference, or cross-wired membership.
- **Stale-version behavior:** `STALE_VERSION` returns current Plan version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns original Trip/Stop IDs and versions.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `DispatchTripAssigned`; READ-02, READ-03, and READ-04 support the Trip context.
- **Next permitted operator action:** CMD-11 for each assigned Stop after physical load review.

<a id="cmd-11"></a>
### CMD-11 — `atlas_api.confirm_dispatch_load(jsonb)`

- **Contract version:** `PA-05B-H2.v1`
- **Required capability:** `dispatch_load.confirm`
- **Payload:**

```json
{
  "dispatch_trip_id": "uuid",
  "dispatch_stop_id": "uuid",
  "dispatch_requirement_revision_id": "uuid",
  "fulfilment_allocation_revision_id": "uuid",
  "loaded_at": "timestamptz",
  "lines": [
    {
      "dispatch_requirement_line_revision_id": "uuid",
      "fulfilment_allocation_line_revision_id": "uuid",
      "loaded_quantity": 10,
      "unit_id": "uuid",
      "evidence_applications": [
        {
          "evidence_application_id": "uuid",
          "applied_to_load_quantity": 10,
          "unit_id": "uuid"
        }
      ]
    }
  ]
}
```

- **Authoritative aggregate:** Dispatch Load.
- **IDs and versions consumed:** exact Trip/Stop/membership/revision chain; exact load lines and Evidence Application bridges; current Trip `expected_version`.
- **IDs and versions returned:** `dispatch_trip_id`; `dispatch_stop_id`; `dispatch_load_id`; `dispatch_load_line_ids`; `dispatch_load_line_application_ids`; `new_versions.dispatch_trip_version`; `dispatch_stop_version`; `dispatch_load_version = 1`.
- **Lifecycle transition:** creates one confirmed multi-line load; Trip becomes or remains `LOADED`; selected Stop becomes `LOADED`; Trip and Stop increment once.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus `LOAD_RECONCILIATION_FAILED`, `EVIDENCE_INSUFFICIENT`, destination/membership mismatch, duplicate load, and quantity/unit/lineage mismatch.
- **Stale-version behavior:** `STALE_VERSION` returns current Trip version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns original load, line, bridge IDs, and versions.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `DispatchLoadConfirmed`; READ-01, READ-02, READ-03, and READ-04 can expose the resulting state.
- **Next permitted operator action:** CMD-11 for other Stops; CMD-12 only when every Trip Stop is fully loaded.

<a id="cmd-12"></a>
### CMD-12 — `atlas_api.record_dispatch_departure(jsonb)`

- **Contract version:** `PA-05B-H2.v1`
- **Required capability:** `dispatch_departure.record`
- **Payload:** `{"dispatch_trip_id":"uuid","departed_at":"timestamptz"}`
- **Authoritative aggregate:** Dispatch Trip.
- **IDs and versions consumed:** Trip ID; all exact current Stops/loads/evidence are re-read; current Trip `expected_version`.
- **IDs and versions returned:** `dispatch_trip_id`; all `dispatch_stop_ids`; `new_versions.dispatch_trip_version`; `dispatch_stop_versions` as an object keyed by Stop ID.
- **Lifecycle transition:** Trip `LOADED → IN_TRANSIT`; all Stops `LOADED → IN_TRANSIT`; each increments once.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus `DEPARTURE_BLOCKED`, incomplete or extra loads, invalid evidence, destination/scope changes, or time before loading.
- **Stale-version behavior:** `STALE_VERSION` returns current Trip version.
- **Retryable-concurrency behavior:** exact request retry only; scope or stop-set race is retryable.
- **Exact replay:** returns original departure result and versions.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `DispatchDeparted`; all four reads can show the result.
- **Next permitted operator action:** CMD-13 per Stop after destination receipt.

<a id="cmd-13"></a>
### CMD-13 — `atlas_api.confirm_successful_delivery(jsonb)`

- **Contract version:** `PA-05B-H2.v1`
- **Required capability:** `delivery_success.confirm`
- **Payload:**

```json
{
  "dispatch_trip_id": "uuid",
  "dispatch_stop_id": "uuid",
  "confirmed_at": "timestamptz",
  "received_by_reference": "text or null",
  "notes": "text or null",
  "lines": [
    {
      "dispatch_load_line_id": "uuid",
      "delivered_quantity": 10,
      "returned_quantity": 0,
      "exception_quantity": 0,
      "unit_id": "uuid"
    }
  ]
}
```

- **Authoritative aggregate:** Delivery Confirmation.
- **IDs and versions consumed:** exact Trip/Stop/current confirmed load and every load line; current Trip `expected_version`.
- **IDs and versions returned:** `dispatch_trip_id`; `dispatch_stop_id`; `delivery_confirmation_id`; `delivery_confirmation_line_ids`; `new_versions.dispatch_trip_version`; `dispatch_stop_version`.
- **Lifecycle transition:** creates one valid successful confirmation; selected Stop becomes `DELIVERED`; Trip becomes `PARTIALLY_DELIVERED` or `DELIVERED`; Trip and Stop increment once.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus `DELIVERY_RECONCILIATION_FAILED`, missing/extra lines, wrong quantities or units, non-zero return/exception, invalid time, or prior confirmation.
- **Stale-version behavior:** `STALE_VERSION` returns current Trip version.
- **Retryable-concurrency behavior:** exact request retry only.
- **Exact replay:** returns original confirmation and line IDs and versions.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `SuccessfulDeliveryConfirmed`; all four reads can show delivered state.
- **Next permitted operator action:** repeat CMD-13 for remaining Stops; CMD-14 only when the Trip is fully `DELIVERED`.

<a id="cmd-14"></a>
### CMD-14 — `atlas_api.close_successful_trip(jsonb)`

- **Contract version:** `PA-05B-H3.v1`
- **Required capability:** `dispatch_trip.close_successful`
- **Payload:** `{"dispatch_trip_id":"uuid","completed_at":"timestamptz"}`
- **Authoritative aggregate:** Dispatch Trip.
- **IDs and versions consumed:** delivered Trip ID and current `expected_version`; every Stop, membership, load, and successful confirmation is reconciled.
- **IDs and versions returned:** `affected_aggregate_ids.dispatch_trip_id`; top-level `completed_at`; `new_versions.dispatch_trip_version`.
- **Lifecycle transition:** preserves `DELIVERED`, sets completion time, increments Trip once.
- **Warnings and blockers:** successful v1 response returns empty arrays.
- **Safe errors:** common errors plus `NOT_FOUND`, `TRIP_NOT_READY`, `TRIP_RECONCILIATION_FAILED`, and `DELIVERY_RECONCILIATION_FAILED`.
- **Stale-version behavior:** `STALE_VERSION` returns current Trip version.
- **Retryable-concurrency behavior:** exact request retry only; closure races are retryable.
- **Exact replay:** returns original completion time and Trip version.
- **Changed idempotency reuse:** `IDEMPOTENCY_CONFLICT`.
- **Audit and trace visibility:** emits `SuccessfulDispatchTripClosed`; READ-01 and READ-04 expose the completed path and closure event.
- **Next permitted operator action:** no further successful-path write is defined; use READ-01 and READ-04 for review.

<a id="read-01"></a>
### READ-01 — `atlas_api.get_supplier_direct_trace(jsonb)`

- **Contract version:** `PA-05B.v1`
- **Required capability:** `supplier_direct_trace.read`
- **Selector payload:** `{"wholesale_order_line_revision_id":"uuid"}`
- **Authoritative aggregate:** no mutation; completed supplier-direct source-line context.
- **IDs and versions consumed:** one known Wholesale Order line revision ID and authenticated subject.
- **IDs and versions returned:** public order/PO/Trip references; opaque IDs for source, requirement, allocation, PO line, Evidence, application, Trip, Stop, load line, and Delivery Confirmation; stage statuses; service date, customer/location, item/unit; allocated/applied/loaded/delivered quantities.
- **Lifecycle transition:** none.
- **Warnings and blockers:** returns shaped warnings and blockers; current completed-path response normally returns empty arrays and trace-level evidence checks.
- **Safe errors:** validation, authentication/capability/scope denial, no completed trace, or internal safe failure.
- **Stale-version behavior:** not applicable; advisory point-in-time read.
- **Retryable-concurrency behavior:** not applicable; ordinary read transport retry only.
- **Exact replay:** not applicable; repeated read may observe newer committed state.
- **Changed idempotency reuse:** not applicable.
- **Audit and trace visibility:** this is the completed-path trace; it creates no audit fact.
- **Next permitted operator action:** open READ-04 for authoritative command/audit history; no write is authorized by the read itself.

<a id="read-02"></a>
### READ-02 — `atlas_api.get_dispatch_evidence_readiness(jsonb)`

- **Contract version:** `PA-05C.v1`
- **Required capability:** `dispatch_evidence_readiness.read`
- **Selector payload:** exactly one of `dispatch_trip_id`, `dispatch_requirement_revision_id`, or `wholesale_order_line_revision_id`.
- **Authoritative aggregate:** no mutation; bounded readiness context.
- **IDs and versions consumed:** one known bounded selector and authenticated subject.
- **IDs and versions returned:** selector and authorized scope; per-line Trip/Stop/requirement/allocation IDs; unit; allocated, loaded, and applied Evidence quantities; Evidence references/status; application status; readiness status; additive `command_context` with the current Fulfilment Allocation root/version/revision/stable line/line revision and all exact active current PO commitment root/version/revision/line lineages.
- **Lifecycle transition:** none; `advisory_only = true`.
- **Warnings and blockers:** per-line statuses include `READY`, `MISSING_EVIDENCE`, `PARTIAL_EVIDENCE`, `VOIDED_OR_SUPERSEDED_EVIDENCE`, `NOT_LOADED`, and `DELIVERED`, with safe warning/blocker arrays.
- **Safe errors:** `VALIDATION_FAILED`, `UNBOUNDED_OR_AMBIGUOUS_SELECTOR`, `NOT_FOUND`, `CURRENT_LINEAGE_CONFLICT`, authentication/capability/scope denial, or `INTERNAL_READ_FAILURE`.
- **Stale-version behavior:** after CMD-07 or CMD-08 returns `STALE_VERSION`, the application may refresh this read with its known `wholesale_order_line_revision_id`, require a new review, and create a new command intent using the matching authoritative version from `command_context`; it must not promote diagnostic `actual_version` or audit history into an expected version.
- **Retryable-concurrency behavior:** not applicable.
- **Exact replay:** not applicable.
- **Changed idempotency reuse:** not applicable.
- **Audit and trace visibility:** creates no event; its opaque IDs may be used for authorized READ-04 selectors where supported.
- **Next permitted operator action:** operator reviews readiness and the exact current command context; the application may create a new candidate CMD-07/CMD-08 intent from the matching lineage after review. The read never authorizes the command. See `docs/architecture/pa-05c-h3-evidence-readiness-current-command-context.md`.

<a id="read-03"></a>
### READ-03 — `atlas_api.get_operator_blockers(jsonb)`

- **Contract version:** `PA-05C.v1`
- **Required capability:** `operator_blockers.read`
- **Selector payload:** exactly one of `dispatch_trip_id`; `{service_date, customer_id}`; or `{service_date, delivery_location_id}`.
- **Authoritative aggregate:** no mutation; bounded operator observation.
- **IDs and versions consumed:** one known Trip or one known date plus customer/location selector.
- **IDs and versions returned:** authorized scope, blocker count, blocker type/severity/source domain/safe message, affected opaque IDs, public Trip reference, suggested owning team, and observation time.
- **Lifecycle transition:** none; blocker rows are not persisted tasks.
- **Warnings and blockers:** types include `NO_SUPPLIER_EVIDENCE`, `EVIDENCE_PARTIAL`, `EVIDENCE_VOIDED`, `NOT_LOADED`, `DEPARTURE_BLOCKED`, `DELIVERY_PENDING`, and `DELIVERY_COMPLETED`.
- **Safe errors:** `VALIDATION_FAILED`, `UNBOUNDED_OR_AMBIGUOUS_SELECTOR`, `NOT_FOUND`, authentication/capability/scope denial, or `INTERNAL_READ_FAILURE`.
- **Stale-version behavior:** not applicable.
- **Retryable-concurrency behavior:** not applicable.
- **Exact replay:** not applicable.
- **Changed idempotency reuse:** not applicable.
- **Audit and trace visibility:** creates no task or audit fact.
- **Next permitted operator action:** navigate to a known-context detail workbench or escalate to the suggested owning team; this is not a global queue API.

<a id="read-04"></a>
### READ-04 — `atlas_api.get_command_audit_timeline(jsonb)`

- **Contract version:** `PA-05C.v1`
- **Required capability:** `command_audit_timeline.read`
- **Selector payload:** exactly one of `command_id`; `correlation_id`; or complete `{aggregate_type, aggregate_id}`.
- **Authoritative aggregate:** no mutation; one authorized command/correlation/current aggregate scope.
- **IDs and versions consumed:** known command, correlation, or supported current aggregate ID.
- **IDs and versions returned:** authorized scope and public aggregate reference; safe command-receipt summary; domain events; audit events; event limit 100.
- **Lifecycle transition:** none.
- **Warnings and blockers:** no workflow blockers are created; unsupported, unbounded, unresolved, or mixed-scope selectors fail closed.
- **Safe errors:** `VALIDATION_FAILED`, `UNBOUNDED_OR_AMBIGUOUS_SELECTOR`, `NOT_FOUND_OR_UNSUPPORTED`, `AMBIGUOUS_SCOPE`, authentication/capability/scope denial, or `INTERNAL_READ_FAILURE`.
- **Stale-version behavior:** not applicable; events are a point-in-time timeline.
- **Retryable-concurrency behavior:** not applicable.
- **Exact replay:** not applicable.
- **Changed idempotency reuse:** not applicable.
- **Audit and trace visibility:** this is the allowlisted audit view. Supported current aggregate vocabulary includes Wholesale Order, Purchase Handoff, Dispatch Requirement, Fulfilment Allocation, Purchase Order, Supplier Receiving Evidence, Evidence Application, Dispatch Plan, Dispatch Trip, Dispatch Load, and Delivery Confirmation.
- **Next permitted operator action:** inspect the owning workbench using already-known authorized context; the timeline does not authorize a write.

## 7. Explicit client ownership matrix

| Concern | Client coordination owner | Required behavior | Business authority that remains server-side |
|---|---|---|---|
| Authentication session | Authentication boundary | Subscribe to session state, expose signed-in/signed-out/expired state, stop submission after expiry | Valid subject, active actor, capability, scope |
| Requested authenticated subject | API invocation boundary, derived from active session | Copy the session subject into `requested_by_auth_subject`; never accept an arbitrary actor ID as a substitute | Subject-to-actor resolution and mismatch rejection |
| `command_id` | Immutable command intent | Generate once per submit intent with browser UUID support; preserve for exact retry | Receipt uniqueness and replay/conflict classification |
| `correlation_id` | Visible operator journey/workbench context | Generate or inherit one journey ID across related commands; show it in outcome/history | Relational authorization and event scope |
| `idempotency_key` | Immutable command intent | Generate once, persist with the unsent/in-flight request, never reuse after an edit | Scoped uniqueness, request hash, replay/conflict result |
| `expected_version` | Authoritative workbench state | Store only a version returned by a command or approved read/context; never infer a changed version | Optimistic check, locking, current version |
| `requested_at` | Immutable command intent | Capture once when intent is finalized; preserve on exact retry | Non-future validation and receipt timing |
| `reason_code` | Action form/confirmation | Require an operator-facing reason vocabulary selected for the approved workflow | Whether a reason is accepted by the contract |
| `reason_note` | Action form/confirmation | Include the field on every command; preserve `null` versus text | Audit persistence and allowlisting |
| Exact retry | API invocation boundary | Re-send the byte-equivalent logical request after a retryable result or uncertain transport outcome | Whether the request is replay, conflict, or still in progress |
| Stale-state refresh | Workbench refresh coordinator | Preserve draft; use an approved read if it can reload the authoritative context; otherwise stop and report the read gap | Current aggregate details and next valid transition |
| Retryable-concurrency recovery | Outcome coordinator | Offer “Retry same request”; do not change payload, version, IDs, or timestamp | Transaction retryability |
| Response version propagation | Authoritative workbench state | Replace carried versions immediately from `new_versions`; preserve unchanged guarded versions exactly | Version increment and aggregate mutation |
| Post-command refresh | Workbench refresh coordinator | Refresh only through READ-01 through READ-04 when an approved selector is available | Read authorization and data shaping |
| Warnings and blockers | Safe outcome model | Render verbatim safe messages and structured items; do not reinterpret as permissions | Business meaning, severity, lifecycle |
| Session expiry | Authentication boundary | Disable submit; preserve a local draft if safe; require reauthentication and a new review before a new intent | Session validity and actor resolution |
| Unauthorized recovery | Authentication/outcome boundary | Distinguish signed-out, inactive subject/actor, and capability denial; do not offer a bypass | Capability enforcement |
| Scope-denied recovery | Outcome boundary | Show the bounded denial and stop; do not broaden the selector or fall back to direct tables | Customer/location/Trip scope |

### 7.1 Stale state rule

`STALE_VERSION` is not a retryable concurrency result.

The application must:

1. preserve the operator draft;
2. display expected and actual version;
3. disable blind resubmission;
4. refresh through an approved read only when that read returns enough authoritative context;
5. require review and a new command intent;
6. stop explicitly when the current read surface cannot reload the aggregate.

An `actual_version` field alone is not an authoritative aggregate refresh.

### 7.2 Exact replay presentation

Exact replay is a successful terminal result and should be presented as:

> Already completed — the original authoritative result was returned.

The UI must not imply that another mutation or event occurred.

## 8. State-management and dependency decision

Current runtime dependencies contain React and React DOM only. No Supabase browser client is installed.

PA-06A adds no dependency. For a later approved PA-06B:

- a single `@supabase/supabase-js` dependency is the leading minimal client option because it owns browser-safe Auth session refresh and RPC invocation;
- one client instance and one narrow typed `atlasApi` adapter are sufficient;
- React Context may carry Auth session state if more than one workbench needs it;
- workbench command state should use local `useState` or `useReducer`;
- browser `crypto.randomUUID()` is sufficient for command/correlation identity;
- the existing page-state navigation remains sufficient for the first slice;
- no Redux, Zustand, query library, form framework, router, workflow engine, or generic repository layer is justified.

Every later implementation construct must pass the five-question simplicity gate recorded in `docs/implementation-tasks/TASK-PA-06A-application-connection-contract.md`.

## 9. Evidence-based first connected-slice comparison

Ratings are relative within the accepted supplier-direct scope. “Read sufficiency” means production operator entry without private-table access.

| Candidate | Operator value | Backend completeness | Current read sufficiency | Fixture dependence without new read | Commands | Screens | Stale/retry complexity | Auth complexity | Implementation effort | Rollback risk | Training value |
|---|---|---|---|---|---:|---:|---|---|---|---|---|
| Wholesale Source Recording & Release | Medium: captures new wholesale demand | High for creation/release | Low: no approved customer/location/item discovery or source detail reload | High | 2 | 1 | Medium | Medium | Medium | Low | High for command identity and release |
| Supplier Allocation & PO Release | High for buyers | High | Low: no released-requirement queue, supplier picker, or allocation detail read | High | 2 | 1 | Medium–high | Medium | Medium–high | Medium | High for versions and supplier grouping |
| Supplier Evidence & Readiness | High for Evidence and Dispatch operators | High | Medium only after PO/allocation IDs are known; READ-02/03/04 are strong afterward | High | 2 plus 2–3 reads | 1–2 | Medium | Medium | Medium | Low–medium | Very high for command/read integration and blockers |
| Dispatch Load through Closure | Very high operational value | High | Low at entry: no execution queue or complete Trip detail read | High | 4 | 2 | High | High | High | Medium | High but too broad for a first UI PR |

### 9.1 Decision

**Leading hypothesis:** Supplier Evidence & Readiness.

Evidence for the hypothesis:

- it demonstrates authenticated command and read integration;
- two commands are enough to create visible authoritative evidence;
- READ-02 provides per-line readiness;
- READ-03 provides safe operator blockers;
- READ-04 provides command/audit visibility;
- stale version, exact replay, retryable concurrency, capability denial, and scope denial can be demonstrated coherently;
- it does not require another write-command family.

Hard limitation:

- no current read discovers POs awaiting Evidence or authorized allocation-line choices;
- no current read provides a production Evidence work queue;
- therefore the slice may proceed only as an **isolated fixture-context pilot** until a separately approved bounded discovery read exists.

A PA-06C proposal must stop and seek a backend-read decision before claiming production queue behavior.

## 10. Deferred decisions

PA-06A intentionally defers:

- any new discovery or reference-data read;
- PA-06B dependency installation;
- hosted Atlas project or branch creation;
- Auth configuration;
- Vercel or DNS setup;
- generated Supabase types;
- production data or seed strategy;
- document/PDF generation;
- returns, exceptions, cancellation, reopening, or mixed fulfilment;
- Warehouse, school-catering, Finance, Production/QA, HR, payroll, fleet, GPS, fuel, and route optimization;
- any change to Issue #105 or the live OPS v1 project.
