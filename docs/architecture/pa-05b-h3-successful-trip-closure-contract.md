# PA-05B-H3 — Successful Dispatch Trip Closure Contract

**Status:** Approved implementation contract; documentation prerequisite merged

**Domain:** Dispatch and Delivery

**Capability:** Close one fully delivered and fully reconciled Dispatch Trip as a successful completed transport execution.

**Architecture baseline:** ARCH-001, ARCH-002, PA-05A, PA-05B, PA-05B-H1, PA-05B-H2, and PA-05F.

## OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ finalize a successful Dispatch Trip only after every admitted obligation is delivered and reconciled

Business Domain
→ Dispatch

Business Object
→ DispatchTrip

Business Contract
→ delivery confirmation proves stop-level destination outcome
→ trip closure proves the whole trip is complete and internally reconciled

Command / Event
→ close_successful_trip / SuccessfulDispatchTripClosed

Read Model
→ no new read API

Application
→ none in PA-05B-H3

Technology
→ one forward-only Supabase migration, existing Dispatch runtime, RLS/grants, focused pgTAP
```

## Required callable surface

Add exactly:

```sql
atlas_api.close_successful_trip(request jsonb) returns jsonb
```

Contract version: `PA-05B-H3.v1`.

The reviewed `atlas_api` surface increases from 17 to exactly 18 functions. Add no other public function.

## Exact command envelope

Use the established ten-field command envelope:

```json
{
  "contract_version": "PA-05B-H3.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "text",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "timestamp",
  "reason_code": "text",
  "reason_note": null,
  "payload": {
    "dispatch_trip_id": "uuid",
    "completed_at": "timestamp"
  }
}
```

Allow exactly the two payload fields above. Reject unknown fields.

## Authorization

Capability:

```text
dispatch_trip.close_successful
```

Owning domain: `DISPATCH`.

The caller must:

- resolve to the authenticated active subject and active actor;
- hold the required capability;
- have scope for every authoritative customer/location tuple represented by the selected trip;
- not rely on management override or delegated authorization shortcuts.

Authorize every tuple before receipt registration and revalidate the complete authoritative scope after deterministic locks.

## Preconditions

The command accepts one current Dispatch Trip and must prove all of the following independently.

### Trip root

- `dispatch_trip_id` exists;
- caller `expected_version` equals the current trip version;
- trip belongs to one existing Dispatch Plan;
- trip status is `DELIVERED`;
- `departed_at` is non-null;
- `completed_at` on the trip is null;
- requested `completed_at` is valid, non-future, and not earlier than `departed_at`;
- assigned driver, when present, remains an active permitted actor;
- driver and/or vehicle assignment remains present as required by the established Dispatch contract.

### Plan and membership

- the parent plan and every selected trip stop remain connected to exact PA-05F Plan Requirement memberships;
- each membership retains one current released Planning requirement and one current supplier-direct allocation;
- stop customer/location equals the Planning-owned destination;
- every delivery location belongs to its customer;
- every stop on the trip is included exactly once in the closure proof;
- no stop from another trip is included.

### Stops

- at least one stop exists;
- every stop status is `DELIVERED`;
- no stop is `PENDING`, `LOADED`, `IN_TRANSIT`, `EXCEPTION`, `RETURNED`, `CANCELLED`, or `VOIDED`;
- every stop has one exact current confirmed load for its admitted requirement/allocation pair;
- every stop has one exact successful delivery confirmation for that load;
- delivery confirmation time is non-future, at or after trip departure, and not after requested `completed_at`.

### Load and delivery-line reconciliation

For every current confirmed load on the trip:

- raw load-line count is positive;
- raw load-line count equals the current exact Planning/Procurement lineage count;
- raw load-line count equals successful delivery-confirmation line count;
- every load line belongs to the selected trip, exact stop, exact Planning requirement revision, and exact allocation revision;
- every delivery line belongs to the one successful confirmation for that stop and load;
- ingredient, unit, loaded quantity, and successfully delivered quantity reconcile exactly;
- no missing, extra, duplicate, cross-wired, voided, superseded, partial, excess, return, exception, or unresolved line is accepted;
- no competing successful confirmation exists for the same current load line.

### Trip-wide cardinality

Require fail-closed equality between:

```text
raw trip stop count
= valid exact-membership stop count
= delivered stop count
= successful confirmation root count
```

and, per stop:

```text
raw current load-line count
= valid exact-lineage load-line count
= successful delivery-confirmation line count
```

An additional cross-wired child row under the selected trip, stop, load, or confirmation must block closure rather than be ignored.

## Atomic output

On first successful execution:

- update only the selected Dispatch Trip;
- preserve `trip_status = DELIVERED`;
- set `completed_at` to the requested timestamp;
- increment trip version exactly once;
- set the normal update timestamp where supported by the existing schema;
- create one completed command receipt;
- create one `SuccessfulDispatchTripClosed` domain event;
- create one matching audit event;
- return one safe response containing trip ID, new trip version, completion time, event ID, and audit ID.

Do not update the plan, stops, loads, delivery confirmations, Planning, Procurement, or Evidence facts.

## Command safety

Use established PA-05B patterns for:

- exact envelope and payload validation;
- JWT/auth-subject resolution;
- capability and relational scope;
- delegation rejection;
- idempotency and canonical hashing;
- exact replay and changed-request conflict;
- optimistic version check;
- deterministic locking;
- authoritative post-lock re-read;
- safe errors;
- receipt, domain-event, and audit-event atomicity.

Exact replay returns the original IDs and version without another update or event.

Deterministic failures may retain one safe failed receipt but create no domain, event, or audit rows.

Serialization, deadlock, or post-authorization scope races must roll back the in-progress receipt and return `RETRYABLE_CONCURRENCY_FAILURE`; they must not become durable non-retryable receipts.

## Runtime and security boundary

Reuse:

```text
atlas_dispatch_command_runtime
```

Do not create another runtime role.

The runtime must:

- remain `NOLOGIN`, `NOINHERIT`;
- own this function plus the existing PA-05B-H2 and PA-05F Dispatch functions;
- use fixed empty `search_path` and fully qualified static SQL;
- receive only missing read/lock privileges and the exact trip update privilege already required by Dispatch execution;
- retain no Atlas schema `CREATE` privilege after ownership transfer;
- retain no sequence mutation privilege;
- have no Planning, Procurement, Evidence, Warehouse, reporting, Storage, legacy, Retool, or OPS v1 mutation authority.

The authenticated API role may execute the reviewed 18-function surface only. `anon` and `service_role` may execute none. API roles retain no direct private-relation or sequence access.

## Simplicity gate

Use existing tables only. The command should require no new authoritative table, column, view, trigger, sequence, queue, or job.

Do not add:

- exception or return closure;
- cancellation or reopening;
- trip amendment;
- plan closure;
- Finance settlement;
- driver payroll, vehicle utilization, GPS, fleet, fuel, or route optimization;
- a generic lifecycle or reconciliation framework;
- a workflow engine, repository abstraction, event-sourcing layer, or state-machine framework;
- a read API, UI, generated types, Storage, Edge Function, seed data, deployment, Retool change, or OPS v1 mutation.

Add an index or constraint only when a named closure race cannot be protected by the existing trip-root lock and existing uniqueness constraints.

## Verification requirements

Add:

```text
supabase/tests/pa_05b_h3_successful_trip_closure.sql
```

The focused pgTAP suite must prove:

### Surface and security

- exactly 18 reviewed Atlas API functions;
- the new function is a hardened volatile security definer owned by the Dispatch runtime;
- fixed empty search path and no dynamic SQL;
- exact authenticated execute boundary;
- no anon/service-role execution;
- no direct API-role private relation/sequence access;
- no new runtime role, schema CREATE, sequence mutation, or cross-domain mutation authority;
- private helper ownership/execution is hardened if one command-specific helper is necessary.

### Successful closure

- a command-authored PA-05D → PA-05E → Evidence → PA-05F → PA-05B-H2 path closes successfully;
- trip remains `DELIVERED`;
- `completed_at` is set exactly;
- trip version increments exactly once;
- one completed receipt, one event, and one audit event are created;
- exact replay returns the original response without duplicate mutation or facts;
- changed reuse conflicts.

### Fail-closed behavior

Reject without trip mutation, event, or audit fact when:

- trip is missing, stale, not delivered, already completed, not departed, or has no stops;
- completion timestamp is invalid, future, before departure, or before a delivery confirmation;
- driver assignment is invalid where applicable;
- one stop is not delivered;
- one stop or membership is cross-wired;
- one current load is missing, extra, voided, or tied to another stop/pair;
- one delivery confirmation is missing, duplicated, unsuccessful, cross-wired, or tied to another load;
- one delivery line is missing, extra, duplicated, partial, excessive, wrong-unit, wrong-item, returned, excepted, or unresolved;
- raw and valid child cardinalities differ;
- actor lacks capability or any destination scope;
- post-lock authorization or child identity changes.

### Regression

- PA-05B Evidence behavior remains unchanged;
- PA-05B-H1 runtime hardening remains valid;
- PA-05B-H2 load/departure/delivery behavior remains unchanged;
- PA-05F command-authored setup records are accepted as prerequisites;
- existing read functions continue to represent the delivered trip without relying on closure as a write safety gate.

Use rolled-back synthetic data only. No persistent seed data.

## Validation economy

Follow `AGENTS.md`.

During implementation run only focused checks needed to develop PA-05B-H3.

Near completion run locally:

1. one clean local Supabase reset;
2. PA-05B-H3 pgTAP;
3. PA-05B supplier-direct pgTAP only where shared receipt/runtime helpers are affected;
4. PA-05B-H1 runtime-hardening pgTAP;
5. PA-05B-H2 pgTAP;
6. PA-05F pgTAP;
7. any predecessor suite directly edited for cumulative API expectations;
8. `git diff --check`.

Do not run the routine full frontend suite locally. Push a draft PR and delegate frozen install, workspace, formatting, typecheck, application tests, production build, Storybook build, artifacts, diff validation, and Qodana to GitHub Actions. Do not wait for Actions after opening the draft PR.

## Stop conditions

Stop and report instead of improvising if:

- existing trip/load/delivery tables cannot represent successful closure;
- closure requires changing delivery semantics or trip status vocabulary;
- exact trip-wide reconciliation cannot be proven;
- a new authoritative table or column is required;
- exception, return, reopening, or plan closure is required;
- Planning, Procurement, or Evidence mutation is required;
- a new public function beyond `close_successful_trip` is required.
