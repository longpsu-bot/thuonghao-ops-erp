# PA-05F — Bounded Dispatch setup command family

**Status:** Approved implementation contract; implementation not started  
**Scope:** Supplier-direct wholesale Slice 1, from physically ready Dispatch requirements to assigned trips and exact stops  
**Authority:** ARCH-001, ARCH-002, PA-01 through PA-05E, PA-05B-H2, PA-05A, the Dispatch and Delivery Domain Contract, and Issue #95  
**Implementation issue:** #95  
**Implementation instructions:** `docs/implementation-tasks/TASK-PA-05F-dispatch-setup-command-family.md`

## 1. Executive decision

PA-05F removes the remaining fixture-authored prerequisite before supplier-direct Dispatch execution while preserving the approved dependency:

```text
DispatchRequirement
+ FulfilmentAllocation
+ current valid FulfilmentEvidence
→ DispatchPlan
→ assigned DispatchTrip
→ exact DispatchStops
```

For the supplier-direct Slice 1, `FulfilmentEvidence` means current valid supplier receiving/cross-dock evidence that has been validly applied to every exact allocation-line revision at full quantity.

PA-05F adds exactly two public commands:

1. `atlas_api.create_dispatch_plan(request jsonb)`
2. `atlas_api.create_or_assign_dispatch_trip(request jsonb)`

Contract version:

```text
PA-05F.v1
```

The reviewed `atlas_api` surface increases from exactly 15 to exactly 17 functions. No public read function is added.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ group physically ready delivery obligations into a Dispatch plan
→ assign exact plan requirements to an executable trip and stop sequence

Business Domain
→ Dispatch

Business Objects
→ DispatchPlan
→ DispatchPlanRequirement
→ DispatchTrip
→ DispatchStop

Business Contract
→ Planning owns item, quantity, destination, service date, and release snapshots
→ Procurement owns fulfilment allocation, supplier assignment, and released supplier commitment
→ the physical source owns receiving/cross-dock evidence and its valid application
→ Dispatch owns plan grouping, trip assignment references, and stop sequence
→ Dispatch consumes upstream facts without rewriting them

Commands / Events
→ create_dispatch_plan / DispatchPlanCreated
→ create_or_assign_dispatch_trip / DispatchTripAssigned

Read Model
→ no new public read API
→ existing trace, readiness, blocker, and audit reads remain advisory

Application
→ none in PA-05F

Technology
→ one forward-only PostgreSQL/Supabase migration
→ existing least-privilege Dispatch runtime
→ exact grants, forced-RLS policies, and focused pgTAP
```

## 3. Why PA-05F is required

PA-05D and PA-05E author the Planning and Procurement records. Existing PA-05B Evidence commands author supplier receiving evidence and exact evidence applications. PA-05B-H2 can execute atomic multi-line loading, full-trip departure, and multi-line delivery. Its tests still create Dispatch Plan, Plan Requirement, Trip, and Stop rows directly as rolled-back fixtures.

PA-05F makes those records command-authored while retaining the approved ownership and dependency:

```text
Planning says what, how much, where, and when.
Procurement says how and from which supplier it will be fulfilled.
The physical source proves that the allocation is actually ready.
Dispatch groups and transports only those physically ready obligations.
```

OPS v1 Retool remains business evidence only. Its dispatch-confirmation path creates day/destination headers and destructively refreshes line sets. Atlas preserves the operational intent while replacing UI-coupled replacement SQL with idempotent, versioned, auditable commands and source-owned evidence.

## 4. Bounded v1 simplification

PA-05F.v1 implements the minimum setup needed by PA-05B-H2 and PA-05G:

- one plan command atomically creates the plan and its initial requirement memberships;
- there is no separate `admit_requirement_to_dispatch_plan` command;
- the plan command discovers and validates current evidence; the caller does not choose evidence IDs;
- every selected allocation line must be fully covered by current valid evidence applications;
- one trip command atomically creates an already assigned trip and its exact stops;
- there is no persisted `PLANNED` trip awaiting a second assignment command;
- a plan may contain multiple trips;
- each selected plan requirement belongs to at most one non-cancelled/non-voided trip;
- stop destination values are derived from Planning, never supplied by the caller;
- caller-authored route windows are deferred;
- PA-05F reads and locks Evidence but never creates, changes, supersedes, voids, or consumes it;
- PA-05B-H2 independently revalidates Evidence again at load and departure.

This avoids a generic routing, scheduling, assignment, evidence, or workflow engine.

## 5. Shared command envelope and result

Both functions use the established exact Atlas envelope:

```json
{
  "contract_version": "PA-05F.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "non-empty text",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "non-future timestamptz",
  "reason_code": "non-empty text",
  "reason_note": null,
  "payload": {}
}
```

Use the existing safe success/error shape, subject resolution, actor and capability validation, relational scope checks, canonical request hash, command receipt, replay/conflict handling, optimistic concurrency, deterministic locks, domain event, and audit event patterns.

Every first successful execution creates exactly:

- one completed command receipt;
- one domain event;
- one audit event;
- one safe response.

Exact replay returns the original response and IDs. Same command identity with a changed canonical request returns `IDEMPOTENCY_CONFLICT`. Deterministic post-receipt failures may retain one safe failed receipt. Transient concurrency failures must roll back the in-progress receipt.

## 6. Command 1 — `create_dispatch_plan`

### 6.1 Capability and scope

Capability:

```text
dispatch_plan.create
```

The actor must be authorized for every distinct authoritative Planning customer/location tuple represented by the selected memberships. Authorization happens before receipt registration. `GLOBAL`, matching `CUSTOMER`, or matching `DELIVERY_LOCATION` scope may satisfy a tuple. Delegation and management-override shortcuts are not supported.

### 6.2 Exact input

```json
{
  "plan_reference": "PLAN-2026-07-16-A",
  "dispatch_wave": "MORNING",
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

Rules:

- envelope `expected_version = 1` because the Dispatch Plan root is new;
- `plan_reference` is trimmed, non-empty, and at most 200 characters;
- `dispatch_wave` is nullable; when present it is trimmed, non-empty, and at most 100 characters;
- `requirements` contains 1–100 objects;
- unknown top-level and nested fields are rejected;
- each revision ID is a valid UUID;
- each named upstream expected version is positive;
- requirement revision IDs, allocation revision IDs, and exact pairs are unique in the request;
- caller does not supply service date, customer, location, quantity, supplier, evidence ID, status, actor, or generated ID.

### 6.3 Authoritative preconditions

Before receipt registration, resolve and authorize every authoritative destination. After deterministic locks, independently re-read and prove for every pair:

#### Planning requirement

- one Dispatch Requirement root exists;
- root status is `RELEASED`;
- root version equals `expected_dispatch_requirement_version`;
- selected revision belongs to the root, is current, and is `RELEASED`;
- release actor/time and destination snapshots are present;
- source of need is `WHOLESALE`;
- customer and delivery location are active and the location belongs to the customer;
- stable requirement-line count equals raw selected-revision child count equals fully valid source-lineage count;
- every requirement line preserves the exact PA-05D wholesale → Confirmed Need → approval snapshot → Purchase Handoff → Dispatch Requirement chain.

#### Procurement allocation and supplier commitment

- one Fulfilment Allocation root exists and belongs to the same requirement root;
- root status is `READY_FOR_DISPATCH`;
- root version equals `expected_fulfilment_allocation_version`;
- selected revision belongs to the root, is current, and is `READY_FOR_DISPATCH`;
- stable allocation-line count equals raw selected-revision child count equals fully valid allocation-line count;
- every current allocation line uses `SUPPLIER_PO`, `READY_FOR_EVIDENCE`, and `portion_sequence = 1`;
- every requirement line is covered exactly once;
- ingredient, unit, and allocated quantity exactly equal Planning;
- every allocation line belongs to exactly one current released supplier Purchase Order line/revision;
- PO root/revision are `RELEASED_TO_SUPPLIER` and current;
- supplier, ingredient, ordered quantity, unit, destination, and service date reconcile exactly;
- active supplier, ingredient, and unit references remain valid.

#### Source-owned physical evidence

For every selected current allocation-line revision:

- at least one current valid `evidence_applications` row exists;
- every application points to that exact allocation-line revision;
- every application has `application_status = VALID` and has no current valid successor that supersedes it;
- every source `supplier_receiving_evidence` row has `evidence_status = VALID` and has no current valid successor that supersedes it;
- source evidence points to the exact current released PO-line revision for that allocation line;
- source supplier equals the allocation supplier and PO supplier;
- source and application ingredient/unit lineage equals the allocation and requirement line;
- the sum of current valid applied quantity for the allocation line equals its allocated quantity exactly;
- the sum of all current valid applications of each source evidence row does not exceed that evidence row’s quantity;
- no non-voided Dispatch load or valid load-application bridge already consumes the selected requirement/allocation pair.

Missing, partial, excess, voided, superseded, stale, cross-wired, wrong-supplier, wrong-PO, wrong-item, wrong-unit, or over-applied evidence blocks plan creation.

#### Plan scope

- all selected requirements have one identical authoritative service date;
- no selected exact requirement/allocation pair is already admitted to another Dispatch Plan whose status is not `CANCELLED`;
- the supplied plan reference is unused.

### 6.4 Atomic output

Create exactly:

- one `atlas_dispatch.dispatch_plans` root:
  - derived `service_date`;
  - caller `plan_reference`;
  - optional `dispatch_wave`;
  - `plan_status = PLANNED`;
  - `version = 1`;
  - initiating actor as creator;
- one `dispatch_plan_requirements` row per exact selected pair;
- one completed command receipt;
- one `DispatchPlanCreated` domain event;
- one audit event;
- one safe response containing plan ID/version, derived service date, and membership IDs.

The command reads and locks current Evidence but creates no trip, stop, Evidence, load, departure, delivery, exception, return, or closure fact.

## 7. Command 2 — `create_or_assign_dispatch_trip`

### 7.1 Capability and scope

Capability:

```text
dispatch_trip.assign
```

The actor must be authorized for every distinct authoritative customer/location tuple represented by the selected stop memberships. The target driver does not authorize the initiating command.

### 7.2 Exact input

```json
{
  "dispatch_plan_id": "uuid",
  "trip_reference": "TRIP-2026-07-16-A",
  "driver_actor_id": null,
  "vehicle_reference": "TRUCK-01",
  "planned_departure_at": null,
  "stops": [
    {
      "dispatch_plan_requirement_id": "uuid",
      "stop_sequence": 1
    }
  ]
}
```

Rules:

- envelope `expected_version` is the current Dispatch Plan version;
- `trip_reference` is trimmed, non-empty, and at most 200 characters;
- `driver_actor_id` is nullable;
- when present, the driver is active and has actor type `HUMAN` or `DELEGATED_DRIVER`;
- `vehicle_reference` is nullable; when present it is trimmed, non-empty, and at most 200 characters;
- at least one active driver or non-empty vehicle reference is required;
- `planned_departure_at` is nullable; when present it is a valid timestamptz;
- `stops` contains 1–100 objects;
- unknown top-level and nested fields are rejected;
- each membership ID is unique;
- stop sequences are positive, unique, contiguous, and begin at 1;
- caller does not supply customer, delivery location, requirement revision, evidence ID, stop status, plan status, route window, actor scope, or generated ID.

### 7.3 Authoritative preconditions

Before receipt registration, resolve each selected membership to one authoritative Planning destination and authorize every tuple. After deterministic locks, re-read and prove:

- one Dispatch Plan exists, remains `PLANNED`, and has the expected version;
- every selected plan-requirement membership belongs to that plan;
- each membership still points to one current released requirement and one current ready allocation belonging to that requirement;
- each allocation retains exact current released supplier-PO coverage;
- every selected allocation line remains fully covered by current valid source-owned evidence using the same evidence rules as plan creation;
- no non-voided load or valid load-application bridge already exists for a selected membership;
- each selected requirement customer/location remains active and relationally valid;
- every membership has the same service date as the plan;
- no selected membership is already represented by a stop under a trip in the same plan whose status is not `CANCELLED` or `VOIDED`;
- the trip reference is unused;
- the assignment reference remains valid after locks.

Multiple trip commands may consume disjoint membership subsets from one plan. PA-05F does not require all plan memberships to be assigned in one command.

### 7.4 Derived stop facts

For each stop:

- `dispatch_requirement_revision_id` comes from the selected plan membership;
- `customer_id` and `delivery_location_id` come from the Planning requirement root;
- `stop_sequence` comes from the validated request;
- `stop_status = PENDING`;
- `version = 1`;
- `planned_window_start` and `planned_window_end` are null in PA-05F.v1.

No caller-authored destination or route-window value is accepted.

### 7.5 Atomic output

Create/update exactly:

- one `dispatch_trips` root under the plan:
  - `trip_status = ASSIGNED`;
  - `version = 1`;
  - validated driver and/or vehicle reference;
  - optional planned departure timestamp;
- one `dispatch_stops` row per selected membership in `PENDING`, version `1`;
- increment the Dispatch Plan version exactly once while retaining `plan_status = PLANNED`;
- one completed command receipt;
- one `DispatchTripAssigned` domain event;
- one audit event;
- one safe response containing plan version, trip ID/version, and stop IDs/versions.

The command reads and locks current Evidence but creates no load, Evidence, departure, delivery, exception, return, or closure fact. It does not create or modify actor scope, delegation, HR, or fleet records.

## 8. Runtime and authorization boundary

Reuse:

```text
atlas_dispatch_command_runtime
```

The role remains `NOLOGIN`, `NOINHERIT` and owns:

- the three PA-05B-H2 Dispatch execution functions;
- the two PA-05F Dispatch setup functions.

PA-05F may add only the missing privileges needed to:

- read and row-lock approved Admin, Planning, Procurement, PO, Evidence, and Dispatch lineage;
- insert Dispatch Plan, Plan Requirement, Trip, and Stop rows;
- update the selected Dispatch Plan version;
- use command receipts and append one domain/audit event per command.

Requirements:

- fixed empty `search_path`;
- static SQL only;
- revoke-first API execute boundary;
- `authenticated` executes only the reviewed 17 functions;
- `anon` and `service_role` execute none;
- API roles receive no direct private relation or sequence access;
- no Atlas schema `CREATE` after ownership transfer;
- no sequence `USAGE` or `UPDATE`;
- no Planning, Procurement, Evidence, Warehouse, reporting, legacy, Storage, Retool, or OPS v1 mutation authority.

A private PA-05F request validator may be added only when existing version-specific validators cannot represent the exact nested shapes without changing PA-05B-H2 behavior. It must be owned by `atlas_owner` and executable only by `atlas_dispatch_command_runtime`.

## 9. Concurrency and locking

Global order:

```text
receipt/security
→ Admin references
→ Planning roots/revisions/children
→ Procurement roots/revisions/children and PO lineage
→ Evidence sources/applications
→ Dispatch plan/memberships/trips/stops
→ event/audit
```

### Plan creation

- authorize every tuple before receipt registration;
- lock selected requirement roots in UUID order;
- lock selected allocation roots in UUID order;
- lock relevant current revisions/children and released PO lineage deterministically;
- lock relevant source evidence and evidence applications deterministically;
- lock existing Dispatch plan/membership rows for the selected pairs;
- re-read versions, statuses, destinations, line cardinalities, evidence coverage, and membership absence;
- stable upstream roots serialize competing admissions.

### Trip creation

- authorize every selected membership tuple before receipt registration;
- lock the Dispatch Plan root first, then re-enter the global upstream order for the selected immutable memberships;
- lock selected Planning, Procurement, PO, and Evidence lineage deterministically;
- lock selected plan memberships in UUID order;
- lock existing plan trips/stops in deterministic order;
- re-read plan version, upstream current state, evidence readiness, assignment, and unassigned membership set;
- increment plan once and insert the trip/stops atomically.

`40001`, `40P01`, or an explicitly classified scope/membership/evidence race is retryable and must leave no durable receipt or partial Dispatch setup.

## 10. Persistence and simplification gate

Use only existing PA-04 Dispatch setup tables:

- `dispatch_plans`;
- `dispatch_plan_requirements`;
- `dispatch_trips`;
- `dispatch_stops`.

Do not add a table, column, view, trigger, sequence, queue, job, generic routing engine, scheduling engine, assignment framework, evidence framework, workflow engine, document framework, repository abstraction, or event-sourcing layer.

Do not add a separate admission command, an unassigned trip stage, reassignment, cancellation, route optimization, GPS, live tracking, driver payroll, fleet maintenance, vehicle master data, fuel, caller-authored stop destination, or caller-authored route windows.

Do not add or alter an Evidence command. PA-05F only reads and locks existing supplier evidence and applications.

An index or constraint may be added only for a named race or uniqueness invariant that cannot be protected by existing constraints plus stable parent locks. The implementation must stop and report before adding a new authoritative concept.

The final implementation report must inventory every helper, constraint/index, grant, policy, and event and explain the invariant it protects and why existing objects are insufficient.

## 11. Verification contract

Create:

```text
supabase/tests/pa_05f_dispatch_setup_command_family.sql
```

The suite must prove:

### Surface and security

- exactly 17 reviewed `atlas_api` functions;
- both PA-05F functions are `SECURITY DEFINER`, use an empty fixed search path, and are owned by `atlas_dispatch_command_runtime`;
- no dynamic SQL;
- exact authenticated execute boundary;
- no anon/service-role execute;
- no direct API-role private relation or sequence access;
- no new runtime role;
- no Atlas schema `CREATE` or sequence mutation;
- no cross-domain mutation by the Dispatch runtime;
- no other runtime gains unauthorized Dispatch setup writes.

### Plan command

- one multi-requirement, multi-destination, same-service-date, fully evidenced plan succeeds atomically;
- service date is derived from Planning;
- exact requirement/allocation/PO/evidence lineage and cardinality are preserved;
- every and only submitted pair is admitted;
- authorization covers every authoritative destination before receipt registration;
- mixed dates, duplicate pair, stale named version, inactive reference, missing/revised PO, missing/partial/voided/superseded/over-applied/cross-wired evidence, malformed child cardinality, cross-wired requirement/allocation/PO, pre-existing active plan membership, existing load, and duplicate plan reference fail closed;
- exact replay returns original IDs;
- changed nested request conflicts;
- failed commands create no plan, membership, event, or audit row.

### Trip command

- one assigned multi-stop trip succeeds from a fully evidenced subset of plan memberships;
- a second trip consumes a disjoint subset and increments the plan version once;
- stop destination and requirement revision are derived exactly from Planning membership;
- evidence invalidated after planning blocks trip creation;
- no assignment, inactive/wrong-type driver, malformed vehicle reference, duplicate or non-contiguous stop sequence, duplicate membership, membership from another plan, already assigned membership, existing load, stale plan version, upstream lineage change, and cross-wired destination fail closed;
- exact replay and nested conflict are safe;
- failed commands create no trip, stop, event, or audit row and do not increment the plan.

### Boundary and regression

- plan creation creates no trip, stop, Evidence, load, delivery, or closure fact;
- trip creation creates no Evidence, load, departure, delivery, or closure fact;
- PA-05B Evidence behavior remains unchanged;
- PA-05B-H1 runtime-hardening expectations remain valid;
- PA-05B-H2 can consume command-authored plan/trip/stop outputs without changing its public behavior.

## 12. Validation economy

Follow `AGENTS.md` validation ownership.

During development, run only focused checks needed to implement and debug PA-05F.

Near completion, run locally:

1. one clean Supabase reset;
2. PA-05F pgTAP;
3. PA-05B supplier-direct pgTAP because PA-05F consumes Evidence/application semantics;
4. PA-05B-H1 runtime-hardening pgTAP;
5. PA-05B-H2 pgTAP;
6. any predecessor suite directly edited for cumulative API/runtime expectations;
7. `git diff --check`.

Do not run the routine full frontend suite locally. Push the branch, open a draft PR, and allow GitHub Actions to own frozen install, workspace validation, formatting, typecheck, full application tests, build, Storybook, artifacts, diff validation, and Qodana. Do not claim those checks passed until completed results are observed.

## 13. Stop conditions

Stop and report rather than improvise if:

- existing tables cannot represent the approved plan, assigned trip, or stop output;
- exact Planning/Procurement/released-PO/current-Evidence lineage cannot be proven;
- stable parent locks cannot serialize active plan admission or one-trip-per-membership safety;
- PA-05B-H2 requires a different stop shape or mandatory planned windows;
- implementation would require a public admission, reassignment, cancellation, or update command;
- implementation requires Planning, Procurement, or Evidence mutation;
- a new authoritative table, column, or public function appears necessary.

## 14. Explicit non-goals

PA-05F does not add:

- Evidence recording, application, correction, supersession, or voiding;
- load, departure, delivery, exception, return, or trip closure behavior;
- PA-05B-H3 or PA-05G;
- React or generated Supabase types;
- live Supabase deployment or hosted mutation;
- seed/reference data or production data;
- credentials;
- Retool or OPS v1 changes;
- Warehouse, Storage, Edge Functions, Production/QA, Finance, HR, or fleet behavior.

## 15. Completion boundary

After PA-05F, Atlas can command-author the path through executable Dispatch setup in the approved order:

```text
Wholesale source
→ Planning release chain
→ supplier-direct allocation and released POs
→ source-owned supplier evidence and exact applications
→ Dispatch Plan
→ assigned Dispatch Trip
→ exact Dispatch Stops
```

PA-05B-H3 then adds successful trip closure. PA-05G remains a pure command-authored source-to-closure acceptance gate.