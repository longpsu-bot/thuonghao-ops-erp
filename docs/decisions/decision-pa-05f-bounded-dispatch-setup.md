# Decision — PA-05F bounded Dispatch setup

**Status:** Accepted  
**Date:** 2026-07-16  
**Decision owner:** OPS ERP / Project Atlas product and architecture review  
**Implementation issue:** #95  
**Contract:** `docs/architecture/pa-05f-dispatch-setup-command-family-contract.md`

## Context

PA-05D and PA-05E can create the authoritative requirement, allocation, and released supplier-PO chain. PA-05B-H2 can load, depart, and successfully deliver exact multi-line requirements. Dispatch Plan, Plan Requirement, Trip, and Stop records are still fixture-authored.

The next step must remove that prerequisite without building a routing product, generic workflow engine, or UI.

## Decision

PA-05F will add exactly two Dispatch-owned commands:

```text
create_dispatch_plan
create_or_assign_dispatch_trip
```

The API surface will increase from 15 to 17 reviewed functions.

### Plan creation

`create_dispatch_plan` will atomically:

- accept an exact array of current requirement/allocation revision pairs and their root versions;
- derive one service date from Planning;
- verify complete current Planning, allocation, and released supplier-PO lineage;
- authorize every authoritative customer/location tuple;
- reject a pair already admitted to another non-cancelled plan;
- create one `PLANNED` Dispatch Plan and all initial Plan Requirement memberships.

A separate `admit_requirement_to_dispatch_plan` command is deferred. The first bounded plan is created complete enough for the immediate slice.

### Trip and stop creation

`create_or_assign_dispatch_trip` will atomically:

- accept one current plan, one trip reference, an active driver and/or vehicle reference, and an exact stop-membership array;
- permit a subset of plan memberships so one plan can contain multiple trips;
- derive stop requirement, customer, and delivery-location facts from Planning;
- require unique contiguous stop sequence beginning at 1;
- prevent one active membership from being assigned to more than one non-cancelled/non-voided trip;
- create one `ASSIGNED` trip and all `PENDING` stops;
- increment the plan version once.

There is no separately persisted unassigned trip stage in PA-05F.v1.

## Ownership rationale

```text
Planning
→ owns what, quantity, destination, date, and released snapshots

Procurement
→ owns supplier allocation and released supplier commitment

Dispatch
→ owns plan grouping, assignment references, and stop sequence
```

The new commands may read and lock upstream facts but may write only Dispatch setup facts, command receipts, events, and audit rows.

## Runtime decision

Reuse `atlas_dispatch_command_runtime` rather than creating another role.

Reasons:

- plan/trip/stop setup and load/departure/delivery are one Dispatch-owned authority boundary;
- a second Dispatch runtime would add privilege and policy duplication without a distinct business owner;
- the existing role is already `NOLOGIN`, `NOINHERIT`, fixed-search-path, and constrained by forced RLS;
- new grants can remain verb-specific: insert plan/membership/trip/stop and update only plan version.

The two new functions will be owned by the Dispatch runtime. Any new request validator will be owned by `atlas_owner` and executable only by that runtime.

## Simplification decisions

### No separate admission command

The initial plan and its membership set are one business action. Adding a separate admission command now would create an unnecessary partial plan lifecycle.

### No planned-trip intermediate state

The immediate execution path requires an assignment before load. The command therefore creates an already assigned trip instead of persisting `PLANNED` and requiring another write.

### Multiple trips remain supported

A plan may contain multiple trips. Each trip command consumes a disjoint subset of plan memberships and increments the plan version once.

### No caller-authored destination

Stop customer, location, and requirement revision are derived from the admitted Planning requirement. This avoids duplicate mutable facts and the cross-wiring defect corrected in PA-05B-H2.

### No route windows in v1

The immediate H2 and PA-05G path does not require caller-authored planned arrival windows. Stop window fields remain null. A later operational contract may add controlled scheduling when real workflow evidence requires it.

### No physical-evidence gate at plan creation

Plan creation requires current allocation and released supplier commitments, but not receiving evidence. Evidence remains source-owned and is independently required by the load/departure commands.

### No new authoritative schema

Existing PA-04 tables represent the approved output. No table, column, view, trigger, queue, or workflow abstraction is authorized.

## Rejected alternatives

### Copy OPS v1 dispatch-header replacement behavior

Rejected because OPS v1 confirms day/destination headers and destructively replaces line sets through UI-coupled SQL. Atlas requires stable membership identity, idempotency, optimistic concurrency, audit, and domain ownership.

### One giant source-to-load command

Rejected because it would combine Planning, Procurement, Evidence, and Dispatch decisions and obscure ownership and failure boundaries.

### One command per stop

Rejected for PA-05F.v1 because one assigned trip with its ordered stop set is the business action. Per-stop commands would permit partially defined trips and increase retry complexity.

### Generic route or scheduling engine

Rejected because route optimization, GPS, geography, fleet, and scheduling policy are not required for the supplier-direct backend acceptance path.

### New Dispatch setup runtime role

Rejected because setup and execution share one Dispatch owner and can be isolated with verb-specific grants and policies.

## Consequences

Positive:

- PA-05G can create Dispatch setup without direct fixture inserts;
- Planning destination and Procurement commitment remain immutable inputs;
- multi-destination and multi-trip plans are possible without a routing framework;
- the existing H2 load/departure/delivery commands can consume exact command-authored records;
- API and privilege growth remains bounded.

Tradeoffs:

- plan memberships cannot be added later through a public command;
- reassignment, cancellation, stop resequencing, route windows, and route optimization remain unavailable;
- assignment uses actor/vehicle references rather than HR or fleet master data;
- active-membership uniqueness is enforced transactionally under stable parent locks rather than by a new persisted membership-state concept.

## Follow-on order

```text
PA-05F Dispatch setup
→ PA-05B-H3 successful trip closure
→ PA-05G command-authored backend acceptance
→ PA-06 React connection
```

## Explicit exclusions

No live Supabase deployment, production data, seed data, React, generated types, Retool, OPS v1 mutation, Warehouse, Storage, Edge Functions, exception/return flow, Finance, Production/QA, HR, fleet, GPS, or route optimization is authorized by this decision.