# PA-05C-H2 — Current Command Timeline Scope Contract

**Status:** Approved implementation contract; documentation prerequisite pending review and merge

**Domain:** Reporting / Read

**Capability:** Return one authorized, bounded command/audit timeline for the complete current supplier-direct command surface.

**Issue:** #102

## 1. Executive decision

PA-05C introduced `atlas_api.get_command_audit_timeline(jsonb)` before the Planning, Procurement, Dispatch-setup, and successful-closure command families were implemented.

The public read remains correct in principle: select one command, correlation, or aggregate; resolve every selected event aggregate to authoritative relational scope; reject unresolved or mixed scope; authorize before shaping; expose only allowlisted fields.

Its private aggregate resolver is now stale. Current commands emit CamelCase aggregate types and new aggregate classes that the original helper does not recognize.

PA-05C-H2 corrects only this private read-scope compatibility boundary. It adds no public function and changes no write command.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ let authorized operators inspect the complete Atlas operating history

Business Capability
→ retrieve one bounded source-to-trip-closure command/audit timeline

Business Domain
→ Reporting / Read

Business Object
→ existing command receipts, domain events, audit events, and owning aggregates

Business Contract
→ every selected aggregate resolves to every authoritative relational tuple
→ unsupported or mixed scope fails closed

Command / Event
→ none

Read Model
→ existing get_command_audit_timeline

Application
→ none

Technology
→ one forward-only read-only migration, private resolver replacement,
  minimum read grants/RLS, and focused pgTAP
```

## 3. Public surface

Keep exactly:

```sql
atlas_api.get_command_audit_timeline(request jsonb) returns jsonb
```

Keep contract version and response shape:

```text
PA-05C.v1
```

The reviewed `atlas_api` surface remains exactly 18 functions.

Do not add, remove, rename, overload, or change the signature of a public function.

The existing selectors remain:

- one `command_id`;
- one `correlation_id`;
- one exact `aggregate_type` plus `aggregate_id`.

The existing 100-event bound and allowlisted response fields remain.

## 4. Private resolver boundary

Replace:

```sql
atlas_core.pa_05c_aggregate_scope(
  aggregate_type text,
  aggregate_id uuid
)
returns table (
  customer_id uuid,
  delivery_location_id uuid,
  dispatch_trip_id uuid,
  public_reference text
)
```

The helper remains:

- `LANGUAGE SQL` unless a demonstrated SQL limitation requires PL/pgSQL;
- `STABLE`;
- `SECURITY INVOKER`;
- fixed `search_path = ''`;
- fully qualified static SQL;
- owned by `atlas_owner`;
- executable only by `atlas_read_runtime`.

Do not introduce dynamic SQL or a generic aggregate registry.

## 5. Supported current aggregate types

Support the exact aggregate types currently emitted by merged commands:

| Aggregate type | Current command events |
| --- | --- |
| `WholesaleOrder` | `WholesaleOrderRecorded`, `WholesaleOrderReleased` |
| `PurchaseHandoff` | `PurchaseHandoffReleased` |
| `DispatchRequirement` | `DispatchRequirementReleased` |
| `FulfilmentAllocation` | `SupplierDirectFulfilmentAllocated` |
| `PurchaseOrder` | `SupplierPurchaseOrderReleased` |
| `SupplierReceivingEvidence` | `SupplierReceivingEvidenceRecorded` |
| `EvidenceApplication` | `EvidenceAppliedToAllocation` |
| `DispatchPlan` | `DispatchPlanCreated` |
| `DispatchTrip` | `DispatchTripAssigned`, `DispatchDeparted`, `SuccessfulDispatchTripClosed` |
| `DispatchLoad` | `DispatchLoadConfirmed` |
| `DeliveryConfirmation` | `SuccessfulDeliveryConfirmed` |

Retain compatibility for existing PA-05C-supported aliases and fixtures:

```text
SUPPLIER_RECEIVING_EVIDENCE
EVIDENCE_APPLICATION
DISPATCH_TRIP
DISPATCH_STOP
DISPATCH_LOAD
DELIVERY_CONFIRMATION
DISPATCH_REQUIREMENT
```

Unknown aggregate names remain unsupported. Do not lower-case or otherwise normalize arbitrary input into an accepted type.

## 6. Canonical scope semantics

For each supported aggregate, return every authoritative tuple represented by that aggregate:

```text
customer_id
delivery_location_id
dispatch_trip_id when currently admitted to a trip
public_reference
```

### 6.1 Root ownership

The authoritative customer/location comes from the Planning `DispatchRequirement` lineage, or from the source `WholesaleOrder` before a requirement exists.

Do not trust snapshots or downstream copies when an authoritative owner row exists.

### 6.2 Downstream trip resolution

For Planning, Procurement, PO, and Evidence aggregates, resolve the trip through the exact current chain when one exists:

```text
source aggregate
→ current Dispatch Requirement root/revision
→ exact Fulfilment Allocation root/revision where applicable
→ Dispatch Plan Requirement membership
→ Dispatch Stop
→ Dispatch Trip
```

For a complete one-trip supplier-direct journey, every aggregate in the shared correlation must resolve to the same customer/location/trip tuple.

Before a trip exists, an upstream aggregate may resolve to customer/location with `dispatch_trip_id = null`.

### 6.3 Multiple scope

If one aggregate currently spans more than one customer, location, or trip, return all tuples.

Do not sample, truncate, use `LIMIT 1`, or choose a preferred tuple.

The existing timeline must continue failing closed when the selected command/correlation/aggregate spans more than one relational scope.

### 6.4 Public reference

Return an operator-safe reference suitable for `public_aggregate_reference`.

Prefer stable business references when available:

- wholesale customer order reference;
- Dispatch Plan reference;
- Dispatch Trip reference;
- supplier PO document number;
- supplier Evidence reference.

Otherwise return a stable existing business ID text. Do not expose private table names or SQL implementation details.

## 7. Required mapping paths

The implementation must prove exact ownership through existing foreign-key lineage.

### `WholesaleOrder`

```text
wholesale_orders
→ confirmed_need_batches
→ purchase_handoff_batches/revisions
→ dispatch_requirement_revisions/root
→ plan memberships/stops/trips when present
```

### `PurchaseHandoff`

```text
purchase_handoff_batches
→ confirmed_need_batches
→ wholesale_orders
→ current handoff revision
→ dispatch_requirement_revisions/root
→ plan memberships/stops/trips when present
```

### `DispatchRequirement`

```text
dispatch_requirements
→ current released revision
→ plan membership
→ stop/trip when present
```

### `FulfilmentAllocation`

```text
fulfilment_allocations
→ dispatch_requirements
→ current allocation revision
→ exact plan membership
→ stop/trip when present
```

### `PurchaseOrder`

```text
purchase_orders
→ current PO revision/lines
→ allocation line/revision
→ allocation root
→ Dispatch Requirement
→ plan membership/stop/trip when present
```

### `SupplierReceivingEvidence`

```text
supplier_receiving_evidence
→ released PO line revision
→ allocation line revision/root
→ Dispatch Requirement
→ plan membership/stop/trip when present
```

### `EvidenceApplication`

```text
evidence_applications
→ allocation line revision/root
→ Dispatch Requirement
→ plan membership/stop/trip when present
```

### `DispatchPlan`

```text
dispatch_plans
→ plan memberships
→ Dispatch Requirements
→ trips/stops
```

### `DispatchTrip`

```text
dispatch_trips
→ stops
→ Dispatch Requirements
```

### `DispatchStop`

```text
dispatch_stops
→ trip
→ Dispatch Requirement
```

### `DispatchLoad`

```text
dispatch_loads
→ trip
→ Dispatch Requirement revision/root
```

### `DeliveryConfirmation`

```text
delivery_confirmations
→ stop/trip
→ Dispatch Requirement
```

## 8. Timeline behavior retained

`get_command_audit_timeline` must continue to:

- resolve the authenticated active actor;
- require `command_audit_timeline.read`;
- reject unbounded or ambiguous selectors;
- resolve every selected domain/audit target before shaping;
- reject any unresolved target as `NOT_FOUND_OR_UNSUPPORTED`;
- reject mixed relational scope as `AMBIGUOUS_SCOPE`;
- authorize the complete resolved tuple;
- return at most 100 ordered domain/audit rows;
- expose one safe command-receipt summary and allowlisted events;
- create no receipt, event, audit, or domain mutation.

Do not change read semantics merely to make PA-05G pass.

## 9. Security and privilege boundary

Reuse:

```text
atlas_read_runtime
```

Add only missing:

- schema `USAGE`;
- relation `SELECT`;
- SELECT-only forced-RLS policies;
- private-helper execute grant.

The read runtime must receive no:

- INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, or TRIGGER privilege;
- sequence USAGE or UPDATE;
- schema CREATE;
- role membership into a command runtime;
- Planning, Procurement, Evidence, Dispatch, Audit, reporting, Storage, legacy, Retool, or OPS v1 write path.

`authenticated`, `anon`, and `service_role` receive no direct private relation or helper access. Public API execute boundaries remain unchanged.

## 10. Verification contract

Add:

```text
supabase/tests/pa_05c_h2_current_command_timeline_scope.sql
```

The focused suite must prove:

### Surface and helper hardening

- exactly 18 reviewed `atlas_api` functions;
- no public function addition or removal;
- helper owner is `atlas_owner`;
- helper is stable, security invoker, fixed-search-path, and static;
- only `atlas_read_runtime` can execute the helper;
- API roles retain no direct private-table/view/sequence access;
- no read-runtime write, sequence, or schema-CREATE authority.

### Current aggregate vocabulary

- each exact current aggregate type resolves to the expected customer/location/trip;
- every retained uppercase alias resolves equivalently;
- current CamelCase command-ID and aggregate selectors succeed;
- an unsupported aggregate remains unsupported.

### Complete same-trip correlation

Using one rolled-back linked source-to-trip fixture and one correlation containing event/audit rows for every current aggregate type:

- the correlation resolves to exactly one canonical tuple;
- a GLOBAL actor succeeds;
- a matching DISPATCH_TRIP-scoped actor succeeds because every upstream aggregate resolves to that trip;
- every selected domain and audit event is present within the 100-event limit;
- shaped output contains no request hash, stored response payload, JWT, credential, service-role, SQL, policy, or stack-trace field.

### Fail-closed behavior

- an actor lacking one required tuple is denied;
- a correlation spanning two locations fails closed;
- a correlation spanning two trips fails closed;
- a target with no supported mapping fails `NOT_FOUND_OR_UNSUPPORTED`;
- no read side effect occurs.

Retain the original PA-05C scenarios. Update them only where a narrow cumulative expectation or current aggregate naming assertion is required.

## 11. Simplicity gate

The expected change is:

```text
one private resolver replacement
+ minimum missing read grants/RLS
+ one focused pgTAP file
+ narrow documentation/status updates
```

Do not add:

- a public function;
- a generic aggregate registry table;
- dynamic SQL;
- a graph engine;
- persisted scope cache;
- a materialized view;
- trigger, queue, or job;
- runtime role;
- write command;
- application adapter;
- UI or generated types;
- seed data.

## 12. Stop conditions

Stop and report if:

- current aggregate scope cannot be derived from existing relationships;
- same-trip canonicalization requires weakening mixed-scope rejection;
- the public timeline signature or response shape must change;
- direct private access must be granted to an API role;
- a table, registry, new public function, or runtime role appears necessary.

## 13. Validation economy

Near completion run locally:

1. one clean Supabase reset;
2. `pa_05c_h2_current_command_timeline_scope.sql`;
3. `pa_05c_authorized_read_api_wrappers.sql`;
4. `pa_05b_h1_runtime_role_hardening_test.sql` when runtime grants/RLS change;
5. `git diff --check`.

Routine frontend/repository validation belongs to GitHub Actions. Do not wait for Actions after opening the draft implementation PR.

## 14. Explicit exclusions

No write command, PA-05G implementation, API count change, React/UI, generated types, live Supabase deployment, production data, credentials, seed data, Retool change, OPS v1 mutation, Warehouse, Storage, Edge Function, Finance, Production/QA, exception/return workflow, or generic framework.