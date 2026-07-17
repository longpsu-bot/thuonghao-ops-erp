# PA-05C-H2 — Current Command Timeline Scope Contract

**Status:** Implemented on the PA-05C-H2 task branch; pending review and merge
**Domain:** Reporting / Read  
**Issue:** #102
**Migration:** `supabase/migrations/20260717042323_pa_05c_h2_current_command_timeline_scope.sql`
**Verification:** `supabase/tests/pa_05c_h2_current_command_timeline_scope.sql` (46 rolled-back assertions)

## Purpose

PA-05C implemented `atlas_api.get_command_audit_timeline(jsonb)` before the current Planning, Procurement, Dispatch setup, and trip-closure commands existed.

The public read contract remains correct: every selected event aggregate must resolve to authoritative relational scope; unresolved or mixed scope fails closed; only authorized, allowlisted fields are returned.

The private helper `atlas_core.pa_05c_aggregate_scope(text, uuid)` is stale. It recognizes an older uppercase subset, while merged commands now emit CamelCase aggregate types such as `WholesaleOrder`, `FulfilmentAllocation`, `DispatchPlan`, and `DispatchTrip`.

PA-05C-H2 updates only this private scope resolver and the minimum read-only privileges needed by it.

## OPS_SYSTEM_MAP

```text
Mission
→ let authorized operators inspect the complete Atlas operating history

Business Capability
→ retrieve one bounded source-to-trip-closure command/audit timeline

Business Domain
→ Reporting / Read

Business Object
→ existing receipts, events, audits, and their owning aggregates

Business Contract
→ every selected aggregate resolves to every authoritative scope tuple
→ unsupported or mixed scope fails closed

Command / Event
→ none

Read Model
→ existing get_command_audit_timeline

Application
→ none

Technology
→ one read-only migration, one private helper replacement, focused pgTAP
```

## Public boundary

Keep the existing public function, selector contract, response shape, `PA-05C.v1` version, and 100-event limit.

The reviewed `atlas_api` surface remains exactly **18 functions**.

Do not add, remove, rename, overload, or change the signature of any public function.

## Supported aggregate vocabulary

Support the exact current aggregate types:

```text
WholesaleOrder
PurchaseHandoff
DispatchRequirement
FulfilmentAllocation
PurchaseOrder
SupplierReceivingEvidence
EvidenceApplication
DispatchPlan
DispatchTrip
DispatchLoad
DeliveryConfirmation
```

Retain compatibility with the existing aliases:

```text
SUPPLIER_RECEIVING_EVIDENCE
EVIDENCE_APPLICATION
DISPATCH_TRIP
DISPATCH_STOP
DISPATCH_LOAD
DELIVERY_CONFIRMATION
DISPATCH_REQUIREMENT
```

Unknown aggregate names remain unsupported. Do not accept arbitrary case-folded or normalized names.

## Canonical scope rule

For each supported aggregate, return every authoritative tuple represented by it:

```text
customer_id
delivery_location_id
dispatch_trip_id when currently admitted to a trip
public_reference
```

Use existing relationships, never event payload summaries.

| Aggregate | Required path to authoritative scope |
| --- | --- |
| `WholesaleOrder` | wholesale → Confirmed Need → Handoff → Dispatch Requirement → Plan membership → Stop/Trip when present |
| `PurchaseHandoff` | Handoff batch/current revision → Dispatch Requirement → Plan membership → Stop/Trip when present |
| `DispatchRequirement` | requirement/current revision → Plan membership → Stop/Trip when present |
| `FulfilmentAllocation` | allocation/current revision → requirement → exact Plan membership → Stop/Trip when present |
| `PurchaseOrder` | PO/current lines → allocation lines/root → requirement → Plan membership → Stop/Trip when present |
| `SupplierReceivingEvidence` | Evidence → released PO line → allocation line/root → requirement → Plan membership → Stop/Trip when present |
| `EvidenceApplication` | application → allocation line/root → requirement → Plan membership → Stop/Trip when present |
| `DispatchPlan` | plan memberships → requirements → trips/stops |
| `DispatchTrip` | trip → stops → requirements |
| `DispatchStop` alias | stop → trip → requirement |
| `DispatchLoad` | load → trip and requirement |
| `DeliveryConfirmation` | confirmation → stop/trip → requirement |

Before a trip exists, an upstream aggregate may resolve to customer/location with a null trip.

When an aggregate spans multiple customers, locations, or trips, return all tuples. Never sample, truncate, or use `LIMIT 1`. The existing timeline must continue rejecting mixed relational scope.

For a completed single-trip supplier-direct correlation, all supported aggregates must resolve to the same customer/location/trip tuple.

Use stable operator-safe references where available: customer order reference, PO document number, Evidence reference, plan reference, or trip reference. Otherwise use the aggregate ID text.

## Security boundary

Reuse `atlas_read_runtime`.

The helper remains:

- stable;
- `SECURITY INVOKER`;
- fixed `search_path = ''`;
- fully qualified static SQL;
- owned by `atlas_owner`;
- executable only by `atlas_read_runtime`.

Add only missing schema `USAGE`, relation `SELECT`, and SELECT-only forced-RLS policies required by the exact joins.

Do not grant write, sequence, schema-CREATE, or command-runtime authority. `authenticated`, `anon`, and `service_role` receive no direct private relation or helper access.

## Verification

Add:

```text
supabase/tests/pa_05c_h2_current_command_timeline_scope.sql
```

The suite must prove:

- API surface remains exactly 18 functions;
- helper ownership, security mode, search path, static SQL, and private execution;
- read runtime has no write, sequence, or schema-CREATE authority;
- every current aggregate type and retained alias resolves to the expected tuple;
- current CamelCase command, correlation, and aggregate selectors succeed;
- a complete same-trip correlation is readable by GLOBAL and matching DISPATCH_TRIP scope;
- missing scope, mixed location/trip, and unsupported aggregate fail closed;
- all selected rows within the 100-event bound are returned;
- prohibited internals are absent;
- reads create no receipt, event, audit, or domain mutation.

Retain the original PA-05C suite. Change it only for narrow cumulative expectations when necessary.

## Simplicity gate

Expected change:

```text
one private resolver replacement
+ minimum SELECT grants/RLS
+ one focused pgTAP suite
+ narrow documentation updates
```

Do not add a public function, registry table, dynamic SQL, graph engine, persisted scope cache, materialized view, trigger, queue, job, runtime role, application adapter, UI, generated type, or seed data.

Stop and report if existing relationships cannot derive current scope, if mixed-scope rejection must be weakened, or if the public timeline signature/shape must change.

## Validation economy

Near completion run locally:

1. one clean Supabase reset;
2. PA-05C-H2 pgTAP;
3. existing PA-05C pgTAP;
4. PA-05B-H1 pgTAP only when read-runtime privileges change;
5. `git diff --check`.

GitHub Actions owns routine repository/frontend validation. Do not wait for Actions after opening the draft implementation PR.

## Exclusions

No write-command change, PA-05G implementation, API-count change, React/UI, live deployment, production data, credentials, seed data, Retool/OPS v1 mutation, Warehouse, Storage, Edge Function, Finance, Production/QA, exception/return flow, or generic framework.

## Implementation outcome

PA-05C-H2 replaces only `atlas_core.pa_05c_aggregate_scope(text, uuid)`. The helper remains stable, `SECURITY INVOKER`, owned by `atlas_owner`, fixed to an empty `search_path`, and executable only by `atlas_read_runtime` among API/runtime roles.

The implementation adds the five previously missing read-runtime `SELECT` grants and matching SELECT-only forced-RLS policies for:

- `atlas_planning.confirmed_need_batches`;
- `atlas_planning.purchase_handoff_batches`;
- `atlas_planning.purchase_handoff_revisions`;
- `atlas_procurement.fulfilment_allocations`;
- `atlas_dispatch.dispatch_plan_requirements`.

The public `PA-05C.v1` timeline body, selector contract, response shape, allowlist, and 100-event bound are unchanged. The reviewed `atlas_api` surface remains exactly 18 functions. No contract deviation or public/write-side change was required.
