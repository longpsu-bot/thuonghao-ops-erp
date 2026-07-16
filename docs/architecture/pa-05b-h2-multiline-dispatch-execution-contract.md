# PA-05B-H2 — Multi-line Dispatch execution correction

**Status:** Proposed implementation contract; documentation only  
**Scope:** Supplier-direct wholesale Slice 1 load, departure, and successful-delivery correction  
**Authority:** ARCH-001, ARCH-002, PA-01 through PA-05E, PA-05A, the Dispatch and Delivery Domain Contract, and the approved supplier-direct ownership boundary  
**Implementation issue:** #91  
**Implementation instructions:** `docs/implementation-tasks/TASK-PA-05B-H2-multiline-dispatch-execution.md`

## 1. Executive decision

PA-05D and PA-05E now create authoritative multi-line requirements, allocations, supplier purchase orders, and evidence lineage. The current PA-05B Dispatch execution subset was implemented and tested around one confirmed load line per stop.

That earlier boundary is no longer sufficient:

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

PA-05B-H2 adds no public function, authoritative table, business domain, or runtime role. The reviewed `atlas_api` surface remains exactly 15 functions.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ load, depart, and successfully deliver every released line with exact physical evidence

Business Domain
→ Dispatch

Business Objects
→ DispatchLoad / DispatchLoadLine / DispatchLoadLineApplication
→ DispatchTrip / DispatchStop
→ DeliveryConfirmation / DeliveryConfirmationLine

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
2. `record_dispatch_departure` proves that each stop has at least one load, but not that every current allocation line is loaded exactly; it also authorizes from a sampled first stop.
3. `confirm_successful_delivery` rejects a stop containing more than one confirmed load line.

The correction aligns existing Dispatch commands with already approved line-level objects. It is not a generalized workflow or new feature family.

## 4. Public surface and contract version

The PostgreSQL signatures remain unchanged:

```sql
atlas_api.confirm_dispatch_load(request jsonb) returns jsonb
atlas_api.record_dispatch_departure(request jsonb) returns jsonb
atlas_api.confirm_successful_delivery(request jsonb) returns jsonb
```

The revised Dispatch execution requests use:

```text
contract_version = PA-05B-H2.v1
```

The two Evidence commands continue to use `PA-05B.v1` unchanged.

Atlas has no connected write client, live deployment, or production data depending on the old one-line Dispatch payloads. The old shapes are rejected rather than retained as a second path.

All three commands keep the standard ten-field envelope:

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

One private PA-05B-H2 validator may be added. It must not change PA-05B Evidence behavior.

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

Bounds and identity:

- `lines`: 1–100 objects;
- `evidence_applications`: 1–100 objects per line;
- requirement-line revision IDs are unique;
- allocation-line revision IDs are unique;
- evidence-application IDs are unique across the complete request;
- all quantities are positive.

`expected_version` is the current Dispatch Trip version.

### 5.2 Trip, stop, plan, and version rules

After deterministic locks, prove:

- the trip belongs to the selected plan and is `ASSIGNED` or `LOADED`;
- the selected stop belongs to the trip and is `PENDING`;
- the stop points to the selected current released Dispatch Requirement revision;
- the plan contains the exact requirement/allocation revision membership;
- stop customer/location matches the authoritative requirement;
- the actor is authorized for the stop customer/location/trip tuple;
- no current confirmed load exists for the trip/requirement/allocation scope.

The first successful stop load changes the trip from `ASSIGNED` to `LOADED`. Later stop loads keep the trip `LOADED`. Every successful load command increments the trip version once and the selected stop version once.

### 5.3 Raw cardinality and source lineage

Require equality across:

```text
stable requirement-root lines
= raw children under selected requirement revision
= stable allocation-root lines
= raw children under selected allocation revision
= submitted load lines
= fully valid exact-lineage load lines
```

Every revision child must point to a stable child owned by the same selected root. Extra cross-wired children fail closed even when legitimate rows remain complete.

For every line, prove the complete current PA-05D/PA-05E chain:

```text
wholesale source
→ Confirmed Need revision and approval snapshot
→ Purchase Handoff and demand reference
→ Dispatch Requirement line revision
→ Fulfilment Allocation line revision
→ released supplier PO line revision
```

Require exact customer, destination, service date, supplier, ingredient, unit, and quantity lineage:

```text
requested
= theoretical
= confirmed
= snapshot approved
= demand-reference approved
= handoff
= required
= allocated
= loaded
```

Allocation source must be `SUPPLIER_PO`, allocation line status must be `READY_FOR_EVIDENCE`, and relevant references must remain active.

### 5.4 Evidence reconciliation

For every submitted evidence application, prove:

- application is `VALID`;
- supplier evidence is `VALID`;
- application points to the selected allocation line revision;
- evidence PO-line revision belongs to the same allocation line revision;
- supplier, ingredient, unit, destination, and service-date lineage match;
- existing valid load consumption plus submitted bridge quantity does not exceed the application quantity.

For each load line:

```text
sum(submitted applied_to_load_quantity)
= loaded_quantity
= allocated_quantity
= required_quantity
```

No partial, excess, split, missing, duplicate, converted, rounded, substituted, under-evidenced, invalid-evidence, over-consumed, or cross-wired load is accepted.

### 5.5 Atomic output

Create exactly:

- one confirmed `dispatch_loads` root;
- one `dispatch_load_lines` row per selected allocation line;
- exact `dispatch_load_line_applications` bridges;
- one completed command receipt;
- one `DispatchLoadConfirmed` domain event;
- one audit event;
- one safe response containing all created identifiers and resulting versions.

Update exactly once per successful command:

- trip status to `LOADED`, version +1;
- selected stop `PENDING` → `LOADED`, version +1.

Do not mutate Planning, Procurement, or Evidence facts.

## 6. Command 2 — `record_dispatch_departure`

### 6.1 Exact payload

```json
{
  "dispatch_trip_id": "uuid",
  "departed_at": "timestamptz"
}
```

No unknown fields are accepted. `departed_at` must not precede a confirmed load time and must not be in the future. `expected_version` is the current Dispatch Trip version.

### 6.2 Trip-wide authorization

Departure acts on the entire trip. Before receipt registration, authorize every distinct trip-stop tuple:

```text
customer_id + delivery_location_id + dispatch_trip_id
```

One unauthorized tuple rejects the whole command without a receipt or mutation. A trip-scoped actor may authorize all stops. Customer- or location-scoped actors must cover every stop independently.

### 6.3 Full-line departure revalidation

After deterministic locks, prove:

- trip is `LOADED` and not previously departed;
- every stop in the selected trip is `LOADED`;
- every stop points to exactly one compatible plan requirement/allocation membership;
- every stop has exactly one current confirmed load for that membership;
- every current confirmed load on the trip belongs to one selected-trip stop and membership;
- no extra load root exists outside the selected trip's stops/memberships;
- for each load, raw load lines = current allocation lines = fully valid exact-lineage load lines;
- every current allocation line is loaded exactly once at full quantity/unit;
- every load-line bridge remains valid and sums exactly to loaded quantity;
- every source evidence/application remains valid and exact;
- no evidence application is over-consumed across confirmed loads;
- no missing, extra, duplicate, voided, superseded, or cross-wired child exists.

Do not require every membership in the overall plan to be on this trip; one plan may contain multiple trips. Validate the selected trip and its stops only.

### 6.4 Atomic output

Update exactly once:

- trip `LOADED` → `IN_TRANSIT`, set `departed_at`, version +1;
- every selected-trip stop `LOADED` → `IN_TRANSIT`, version +1.

Create one completed receipt, one `DispatchDeparted` event, one audit event, and one safe response.

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

No unknown fields are accepted. `lines` contains 1–100 unique load-line objects. `expected_version` is the current Dispatch Trip version.

### 7.2 Preconditions

After deterministic locks, prove:

- trip is `IN_TRANSIT` or `PARTIALLY_DELIVERED` and has departed;
- selected stop belongs to the trip and is `IN_TRANSIT`;
- no current valid delivery confirmation exists for the stop;
- confirmed time is at or after departure and not in the future;
- raw current confirmed load lines for the stop = submitted lines = fully valid load lines;
- every submitted load line belongs to a current confirmed load for the selected trip and stop;
- no extra, missing, duplicate, cross-wired, or already-confirmed load line exists;
- delivered quantity is positive and exactly equals loaded quantity;
- delivered unit exactly equals loaded unit;
- returned and exception quantities are zero for every line.

This remains a successful-only path. Partial delivery, failure, refusal, return, and exception handling require separate future contracts.

### 7.3 Atomic output

Create exactly:

- one valid `delivery_confirmations` root;
- one `delivery_confirmation_lines` row per current confirmed load line;
- one completed command receipt;
- one `SuccessfulDeliveryConfirmed` domain event;
- one audit event;
- one safe response containing confirmation and line identifiers.

Update exactly once:

- selected stop `IN_TRANSIT` → `DELIVERED`, version +1;
- trip version +1 and status:
  - `DELIVERED` when every trip stop is delivered;
  - otherwise `PARTIALLY_DELIVERED`.

Multiple stops are confirmed sequentially using the current trip version returned by the preceding command.

## 8. Runtime and authorization boundary

Retain `atlas_dispatch_command_runtime`:

- `NOLOGIN`, `NOINHERIT`;
- owner of the same three Dispatch execution functions;
- no new runtime role;
- no Atlas schema `CREATE` after temporary ownership operations;
- no sequence `USAGE` or `UPDATE`;
- fixed empty `search_path`;
- no dynamic SQL;
- explicit revoke-first API execute boundary;
- narrowly extended read/lock access only where full PO/evidence lineage requires it;
- no Planning, Procurement, or Evidence mutation;
- no Warehouse, Storage, reporting-write, legacy, or external-service authority.

Keep the existing capabilities:

```text
dispatch_load.confirm
dispatch_departure.record
delivery_success.confirm
```

Do not add a generic bulk-command capability.

## 9. Idempotency, versions, locks, and concurrency

Use the existing receipt, request-hash, replay, conflict, safe-error, event, and audit infrastructure.

Required behavior:

- exact replay returns the original complete response and IDs;
- changed nested lines/applications under the same command identity returns `IDEMPOTENCY_CONFLICT`;
- stale trip version returns `STALE_VERSION`;
- deterministic post-receipt failure stores one safe failed receipt;
- failed commands create no domain rows, domain events, or audit events;
- root and child locks follow deterministic UUID order;
- trip root locking serializes load/departure/delivery transitions;
- existing unique constraints remain the final race-safety backstop;
- structural concurrency proof is sufficient for this correction; no new two-session harness is required.

## 10. Simplification gate

Reuse the existing authoritative tables.

Allowed additions:

- one private version-specific validator if required;
- narrowly required execute/grant/RLS adjustments;
- command-specific SQL replacing the three existing function bodies;
- focused pgTAP fixtures and documentation.

Do not add:

- a public function;
- an authoritative table, view, trigger, sequence, queue, or job;
- a generic batch, load, delivery, workflow, repository, or event-sourcing framework;
- partial loading or partial delivery;
- return, exception, cancellation, or trip-closure processing;
- plan/trip/stop creation;
- Warehouse or mixed-source implementation;
- UI or deployment work.

Every new helper, grant, policy, or test mechanism must identify the exact invariant it protects and why existing behavior is insufficient.

## 11. Verification contract

Add:

```text
supabase/tests/pa_05b_h2_multiline_dispatch_execution.sql
```

Update existing PA-05B pgTAP requests for the three revised functions to `PA-05B-H2.v1` array payloads. Keep Evidence scenarios on `PA-05B.v1`.

The combined tests must prove:

- exactly 15 reviewed functions; no new public function or runtime role;
- hardened Dispatch ownership, fixed search paths, no dynamic SQL, and no new cross-domain write authority;
- atomic three-line load into one root, including one line backed by multiple applications;
- exact raw/stable/submitted/valid cardinality;
- replay, conflict, stale version, version increments, and structural race safety;
- old single-line payload rejection;
- missing, duplicate, extra, partial, excess, wrong-unit, invalid-evidence, under-applied, over-consumed, and cross-wired load failures;
- fully loaded multi-stop departure;
- missing coverage, extra load, broken bridge, invalidated evidence, or over-consumption departure failures;
- first-stop-only authorization rejection and full/trip scope success;
- one multi-line stop confirmation with exact lines;
- sequential multi-stop successful delivery using current trip versions;
- missing, duplicate, extra, cross-wired, wrong-unit, non-exact, return, exception, pre-departure, and duplicate-confirmation failures;
- all PA-04 through PA-05E regression suites and the new H2 suite pass;
- local reset, database lint, workspace, format, typecheck, application tests, build, and whitespace checks pass.

## 12. Explicit non-goals

PA-05B-H2 adds no:

- PA-05F plan/trip/stop authoring;
- PA-05G acceptance test;
- React integration or generated type;
- live Supabase deployment or hosted-project command;
- production data, credentials, seed/reference data, Retool, or OPS v1 mutation;
- Warehouse, Storage, Edge Function, Production/QA, Finance, exception, return, or generic workflow behavior.

## 13. Completion boundary

After PA-05B-H2, the existing Dispatch execution commands can safely consume the multi-line outputs of PA-05D and PA-05E.

```text
PA-05B-H2 — multi-line Dispatch execution correction
→ PA-05F — Dispatch plan/trip/stop setup
→ PA-05G — command-authored source-to-delivery acceptance
→ PA-06 — React connection
```
