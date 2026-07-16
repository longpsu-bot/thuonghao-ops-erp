# PA-05B-H2 — Multi-line Dispatch execution correction

**Status:** Proposed implementation contract; documentation only  
**Scope:** Supplier-direct wholesale Slice 1 load, departure, and successful-delivery correction  
**Authority:** ARCH-001, ARCH-002, PA-01 through PA-05E, PA-05A, the Dispatch and Delivery Domain Contract, and the approved supplier-direct ownership boundary  
**Implementation issue:** #91  
**Implementation instructions:** `docs/implementation-tasks/TASK-PA-05B-H2-multiline-dispatch-execution.md`

## 1. Executive decision

PA-05D and PA-05E now create authoritative multi-line requirements, allocations, and supplier commitments. The current PA-05B Dispatch execution subset was implemented and tested around one confirmed load line per stop.

That earlier boundary is no longer sufficient for the approved backend path:

```text
Multi-line Dispatch Requirement
→ multi-line Fulfilment Allocation
→ multi-line supplier PO and evidence
→ one-line load/delivery limitation   ← incompatible
```

PA-05B-H2 corrects the existing Dispatch execution behavior before PA-05F authors plan/trip/stop records and before PA-05G claims backend acceptance.

The corrected path is:

```text
Multi-line requirement/allocation/evidence
→ one atomic multi-line DispatchLoad per stop requirement
→ full-line departure revalidation across every stop
→ one atomic multi-line DeliveryConfirmation per stop
```

PA-05B-H2 adds no public function and no authoritative table. The reviewed `atlas_api` surface remains exactly 15 functions.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ load, depart, and successfully deliver every released line with exact physical evidence

Business Domain
→ Dispatch

Business Objects
→ DispatchLoad
→ DispatchLoadLine
→ DispatchLoadLineApplication
→ DispatchTrip
→ DispatchStop
→ DeliveryConfirmation
→ DeliveryConfirmationLine

Business Contract
→ Dispatch confirms exact source-backed transport quantities
→ Planning remains authoritative for required item, quantity, unit, destination, and service date
→ Procurement remains authoritative for supplier allocation and purchase commitment
→ Evidence remains authoritative for physical supplier proof and its application

Commands / Events
→ confirm_dispatch_load / DispatchLoadConfirmed
→ record_dispatch_departure / DispatchDeparted
→ confirm_successful_delivery / SuccessfulDeliveryConfirmed

Read Model
→ no new read API; existing trace, readiness, blockers, and audit reads remain advisory

Application
→ no React or Retool integration

Technology
→ one forward-only PostgreSQL migration, existing private tables, forced RLS, pgTAP
```

## 3. Why PA-05B-H2 precedes PA-05F

PA-05F will create `DispatchPlan`, `DispatchTrip`, and `DispatchStop` records. Creating those prerequisites first would make the backend look more complete while leaving the actual execution chain unable to handle a normal multi-line requirement.

The current PA-05B behavior has three material limitations:

1. `confirm_dispatch_load` creates one load root and one load line, then rejects another current load for the same trip/requirement/allocation.
2. `record_dispatch_departure` proves that each stop has at least one load, but not that every current allocation line is loaded exactly.
3. `confirm_successful_delivery` rejects a stop containing more than one confirmed load line.

The correction is not a new domain or generalized framework. It aligns the existing Dispatch commands with the already approved line-level business objects and upstream multi-line contracts.

## 4. Public surface and contract version

The existing PostgreSQL signatures remain unchanged:

```sql
atlas_api.confirm_dispatch_load(request jsonb) returns jsonb
atlas_api.record_dispatch_departure(request jsonb) returns jsonb
atlas_api.confirm_successful_delivery(request jsonb) returns jsonb
```

The revised Dispatch execution requests use:

```text
contract_version = PA-05B-H2.v1
```

The two Evidence commands continue to use `PA-05B.v1`.

This is an intentional pre-integration contract correction. Atlas has no React write client, live deployment, or production data depending on the old one-line Dispatch payload. The old single-line payload shapes are not retained as a second execution path.

All three commands continue to use the standard ten-field envelope:

```text
contract_version
command_id
correlation_id
idempotency_key
expected_version
requested_by_auth_subject
requested_at
reason_code
reason_note
payload
```

A private PA-05B-H2 validator may be added for these three functions. It must not change PA-05B Evidence command behavior.

## 5. Command 1 — `confirm_dispatch_load`

### 5.1 Exact payload

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

No unknown top-level, line, or evidence-application fields are accepted.

Bounds:

- `lines`: 1–100 objects;
- `evidence_applications`: 1–100 objects per line;
- line revision IDs are unique within the request;
- evidence application IDs are unique across the complete request;
- all quantities are positive.

`expected_version` is the current Dispatch Trip root version.

### 5.2 Preconditions

After deterministic locks, the command must prove:

#### Trip, stop, plan, and membership

- the trip exists, belongs to the selected plan, and is `ASSIGNED`;
- the selected stop belongs to the trip and is `PENDING`;
- the stop points to the selected current released Dispatch Requirement revision;
- the plan contains the exact requirement/allocation revision membership;
- the stop customer/location equals the authoritative requirement customer/location;
- the actor is authorized for the stop customer/location/trip tuple;
- no current confirmed load already exists for the trip/requirement/allocation scope.

#### Raw child cardinality

The following counts must be equal:

```text
current stable requirement lines under the requirement root
= raw selected-revision requirement line children
= current stable allocation lines under the allocation root
= raw selected-revision allocation line children
= submitted load lines
= fully valid exact-lineage load lines
```

Every selected-revision child must point to a stable child owned by the same selected root. Extra cross-wired children fail closed even when every legitimate line is also present.

#### Exact Planning and Procurement lineage

For every line:

- requirement line revision belongs to the selected requirement revision and stable requirement line;
- allocation line revision belongs to the selected allocation revision and stable allocation line;
- stable allocation line points to the same stable requirement line;
- allocation source is `SUPPLIER_PO`;
- allocation line status is `READY_FOR_EVIDENCE`;
- ingredient, unit, and quantity reconcile through the full PA-05D/PA-05E source chain;
- requested = theoretical = confirmed = approved = handoff = required = allocated = loaded quantity;
- customer, delivery location, and service date remain singular and exact;
- current supplier PO line/revision belongs to the same allocation line revision and remains released;
- supplier and destination references remain active.

#### Exact Evidence lineage and consumption

For every submitted evidence application:

- the application exists and is `VALID`;
- the source supplier evidence exists and is `VALID`;
- the source evidence PO line revision belongs to the same allocation line revision;
- supplier, ingredient, unit, and quantity lineage match the load line;
- the application is not duplicated in the request;
- existing valid load consumption plus submitted consumption does not exceed the application quantity.

For each load line:

```text
sum(submitted applied_to_load_quantity)
= loaded_quantity
= allocated_quantity
= required_quantity
```

No partial, excess, split, missing, duplicate, converted, rounded, substituted, or cross-wired load is accepted.

### 5.3 Atomic output

Create exactly:

- one `dispatch_loads` row in `CONFIRMED` state;
- one `dispatch_load_lines` row per selected allocation line;
- one or more `dispatch_load_line_applications` rows per load line, matching the request;
- one completed command receipt;
- one `DispatchLoadConfirmed` domain event;
- one audit event;
- one safe response containing root/line/application identifiers and resulting versions.

Update exactly once:

- trip `ASSIGNED` → `LOADED`, version +1;
- stop `PENDING` → `LOADED`, version +1.

Do not create or mutate Planning, Procurement, Evidence, departure, delivery, Warehouse, or Finance facts.

## 6. Command 2 — `record_dispatch_departure`

### 6.1 Exact payload

```json
{
  "dispatch_trip_id": "uuid",
  "departed_at": "timestamptz"
}
```

No unknown fields are accepted. `departed_at` must be valid, not before any confirmed load time, and not in the future.

`expected_version` is the current Dispatch Trip root version.

### 6.2 Authorization rule

The command acts on the entire trip. Authorization must therefore cover every selected relational tuple, not a sampled first stop.

Before receipt registration, resolve every unique tuple:

```text
customer_id + delivery_location_id + dispatch_trip_id
```

Call the existing authorization boundary for each tuple. One unauthorized stop fails the complete command with no receipt or mutation. A trip-scoped actor may satisfy every tuple through the trip scope. A customer- or location-scoped actor must cover every stop independently.

### 6.3 Full-line departure revalidation

After deterministic locks, prove:

- trip is `LOADED` and not previously departed;
- every plan membership has exactly one trip stop;
- every stop is `LOADED`;
- every stop has exactly one current confirmed load for its requirement/allocation membership;
- no extra load root exists outside plan membership;
- for each load, raw load lines = current allocation lines = fully valid exact-lineage load lines;
- every current allocation line is loaded exactly once at full quantity/unit;
- every load-line evidence bridge remains valid and sums exactly to loaded quantity;
- every source evidence/application remains valid and exactly linked;
- no evidence application is over-consumed across confirmed loads;
- no missing, extra, duplicate, voided, superseded, or cross-wired child exists.

### 6.4 Atomic output

Update exactly once:

- trip `LOADED` → `IN_TRANSIT`, `departed_at`, version +1;
- every stop `LOADED` → `IN_TRANSIT`, version +1.

Create exactly one completed receipt, one `DispatchDeparted` domain event, one audit event, and one safe response.

## 7. Command 3 — `confirm_successful_delivery`

### 7.1 Exact payload

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

No unknown fields are accepted. `lines` contains 1–100 unique load-line objects.

`expected_version` is the current Dispatch Trip root version.

### 7.2 Preconditions

After deterministic locks, prove:

- trip is `IN_TRANSIT` or `PARTIALLY_DELIVERED` and has departed;
- selected stop belongs to the trip and is `IN_TRANSIT`;
- no current valid delivery confirmation exists for the stop;
- confirmed time is at or after departure and not in the future;
- raw confirmed load lines for the stop = submitted lines = fully valid load lines;
- every submitted load line belongs to a current confirmed load for the selected trip and stop;
- no extra, missing, duplicate, or cross-wired load line exists;
- delivered quantity is positive and exactly equals loaded quantity;
- delivered unit exactly equals loaded unit;
- returned and exception quantities are zero for every line.

This command remains successful-path-only. Partial delivery, failure, refusal, return, or exception requires a separately approved future command family.

### 7.3 Atomic output

Create exactly:

- one current `delivery_confirmations` root for the stop;
- one `delivery_confirmation_lines` row per current confirmed load line;
- one completed command receipt;
- one `SuccessfulDeliveryConfirmed` domain event;
- one audit event;
- one safe response with confirmation and line IDs.

Update exactly once:

- stop `IN_TRANSIT` → `DELIVERED`, version +1;
- trip version +1 and status:
  - `DELIVERED` when every trip stop is delivered;
  - otherwise `PARTIALLY_DELIVERED`.

## 8. Runtime and authorization boundary

Retain `atlas_dispatch_command_runtime`:

- `NOLOGIN`, `NOINHERIT`;
- owner of the same three Dispatch execution functions;
- no new runtime role;
- no Atlas schema `CREATE` after any temporary ownership operation;
- no sequence `USAGE` or `UPDATE`;
- no dynamic SQL;
- fixed empty `search_path`;
- existing API execute boundary remains explicit and revoke-first;
- read/lock access may be narrowly extended only where full PO/evidence lineage requires it;
- no Planning, Procurement, or Evidence mutation;
- no Warehouse, Storage, reporting-write, legacy, or external-service authority.

Keep the existing capabilities:

```text
dispatch_load.confirm
dispatch_departure.record
delivery_success.confirm
```

Do not introduce a generic bulk-command capability.

## 9. Idempotency, versions, locks, and concurrency

Use the existing receipt, request-hash, replay, conflict, safe-error, event, and audit infrastructure.

Required behavior:

- exact replay returns the original complete response and IDs;
- same command identity with different nested lines/applications returns `IDEMPOTENCY_CONFLICT`;
- stale trip version returns `STALE_VERSION`;
- deterministic failure after receipt registration stores one safe failed receipt;
- failed commands create no domain rows, domain events, or audit events;
- root and child locks follow deterministic UUID order;
- trip root locking serializes load/departure/delivery transitions;
- existing unique constraints remain the final race-safety backstop;
- no two-session test harness is required in this bounded correction, but tests must prove the structural locks and constraints used.

## 10. Simplification gate

PA-05B-H2 must reuse the existing authoritative tables.

Allowed additions:

- one private version-specific validator if required;
- narrowly required execute/grant/RLS adjustments;
- command-specific SQL replacing the existing three functions;
- focused pgTAP fixtures and documentation.

Not allowed:

- a public function;
- an authoritative table, view, trigger, sequence, queue, or background job;
- a generic batch-command framework;
- a generic load, delivery, workflow, repository, or event-sourcing abstraction;
- partial loading;
- partial delivery;
- return or exception processing;
- trip closure command;
- plan/trip/stop creation;
- Warehouse or mixed-source implementation;
- UI or deployment work.

Every new helper, grant, policy, or test mechanism must identify the exact invariant it protects and why existing behavior is insufficient.

## 11. Verification contract

Add a focused suite:

```text
supabase/tests/pa_05b_h2_multiline_dispatch_execution.sql
```

Update the existing PA-05B pgTAP requests for the three revised functions to use `PA-05B-H2.v1` and one-element arrays where the original scenarios remain useful. Do not rewrite the Evidence scenarios.

The combined tests must prove at minimum:

### Surface and security

- exactly 15 reviewed `atlas_api` functions remain;
- no new public function or runtime role;
- all three functions remain hardened definers owned by `atlas_dispatch_command_runtime`;
- fixed empty search paths and no dynamic SQL;
- API roles retain no direct private access;
- no cross-domain write authority is added.

### Multi-line load

- three-line exact load succeeds atomically into one load root;
- one load line may consume more than one valid evidence application exactly;
- line and bridge counts are exact;
- trip/stop versions increment once;
- replay adds no rows;
- changed nested payload conflicts;
- old single-line payload shape fails;
- missing, duplicate, extra, partial, excess, wrong-unit, inactive/invalid evidence, under-applied, over-consumed, and cross-wired cases fail before domain/event/audit writes.

### Departure

- fully loaded multi-stop trip departs;
- missing allocation line, extra load line, missing bridge, invalidated evidence, under-covered load, or over-consumed application blocks departure;
- actor authorized only for the first stop cannot depart a wider trip;
- trip-scoped or fully scoped actor succeeds;
- trip and all stop versions update once.

### Multi-line delivery

- one stop with multiple load lines creates one confirmation and exact confirmation lines;
- multiple stops may be confirmed sequentially using current trip versions;
- missing, duplicate, extra, cross-wired, wrong-unit, non-exact delivered, return, exception, pre-departure, and duplicate-confirmation cases fail closed;
- stop/trip versions and statuses reconcile exactly.

### Regression

- PA-04 passes;
- updated PA-05B passes;
- PA-05C passes;
- PA-05B-H1 passes;
- PA-05D passes;
- PA-05E passes;
- PA-05B-H2 passes;
- local reset, database lint, workspace, format, typecheck, application tests, build, and whitespace checks pass.

## 12. Explicit non-goals

PA-05B-H2 adds no:

- PA-05F Dispatch plan/trip/stop authoring;
- PA-05G acceptance test;
- React integration or generated type;
- live Supabase deployment or hosted-project command;
- production data, credentials, seed/reference data, Retool, or OPS v1 mutation;
- Warehouse, Storage, Edge Function, Production/QA, Finance, exception, return, or generic workflow behavior.

## 13. Completion boundary

After PA-05B-H2, the already implemented Dispatch execution commands can consume the multi-line outputs of PA-05D and PA-05E safely.

The remaining backend sequence is:

```text
PA-05B-H2 — multi-line Dispatch execution correction
→ PA-05F — Dispatch plan/trip/stop setup
→ PA-05G — command-authored source-to-delivery acceptance
→ PA-06 — React connection
```
