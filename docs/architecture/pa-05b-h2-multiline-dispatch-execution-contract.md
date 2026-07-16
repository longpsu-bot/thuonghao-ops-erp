# PA-05B-H2 — Multi-line Dispatch execution correction

**Status:** Proposed implementation contract; documentation only  
**Scope:** Supplier-direct wholesale Slice 1 load, departure, and successful-delivery correction  
**Authority:** ARCH-001, ARCH-002, PA-01 through PA-05E, PA-05A, and the Dispatch and Delivery Domain Contract  
**Implementation issue:** #91  
**Implementation instructions:** `docs/implementation-tasks/TASK-PA-05B-H2-multiline-dispatch-execution.md`

## 1. Executive decision

PA-05D and PA-05E now create normal multi-line requirements, allocations, supplier purchase orders, and evidence lineage. The current PA-05B Dispatch execution subset was implemented and tested around one confirmed load line per stop.

That mismatch blocks a real end-to-end slice:

```text
Multi-line Dispatch Requirement
→ multi-line Fulfilment Allocation
→ multi-line supplier PO and evidence
→ one-line load/delivery limitation   ← incompatible
```

PA-05B-H2 corrects the existing Dispatch execution commands before PA-05F authors plan/trip/stop records.

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
→ Planning retains requirement authority
→ Procurement retains allocation and supplier-commitment authority
→ Evidence retains physical-proof authority

Commands / Events
→ confirm_dispatch_load / DispatchLoadConfirmed
→ record_dispatch_departure / DispatchDeparted
→ confirm_successful_delivery / SuccessfulDeliveryConfirmed

Read Model
→ existing authorized reads remain advisory; no new read API

Application
→ no React or Retool integration

Technology
→ one forward-only migration, existing private tables, forced RLS, pgTAP
```

## 3. Why H2 precedes PA-05F

PA-05F will create `DispatchPlan`, `DispatchTrip`, and `DispatchStop` records. Implementing setup first would make the backend look complete while leaving execution unable to process one ordinary multi-line requirement.

The current limitations are concrete:

1. load confirmation creates one load root and one line, then blocks another load in the same scope;
2. departure proves load existence but not exact allocation-line coverage and authorizes from a sampled first stop;
3. successful delivery rejects a stop with another confirmed load line.

H2 corrects those existing command contracts. It does not introduce a generalized workflow.

## 4. Public surface and contract version

The signatures remain unchanged:

```sql
atlas_api.confirm_dispatch_load(request jsonb)
atlas_api.record_dispatch_departure(request jsonb)
atlas_api.confirm_successful_delivery(request jsonb)
```

The revised Dispatch requests use:

```text
contract_version = PA-05B-H2.v1
```

The two Evidence commands remain on `PA-05B.v1`.

Atlas has no connected write client or live deployment depending on the old one-line shapes, so those shapes are rejected rather than maintained as a second path.

## 5. `confirm_dispatch_load`

### Input

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

The request uses exact field allowlists, 1–100 load lines, 1–100 evidence applications per line, unique line/application identities, positive quantities, and a non-future `loaded_at`.

`expected_version` is the current Dispatch Trip version.

### Business invariants

- trip belongs to the plan and is `ASSIGNED` or `LOADED`;
- selected stop belongs to the trip and is `PENDING`;
- stop, plan membership, requirement revision, and allocation revision form one exact scope;
- actor is authorized for the stop customer/location/trip tuple;
- no current confirmed load already exists for that trip/requirement/allocation;
- raw revision children, stable root lines, submitted lines, and fully valid lines have equal cardinality for both requirement and allocation;
- every allocation line is represented exactly once;
- the current PA-05D/PA-05E source chain, released supplier PO line, supplier, ingredient, unit, destination, and service date all match;
- allocation source is `SUPPLIER_PO` and line status is `READY_FOR_EVIDENCE`;
- each evidence application and source evidence is current, valid, exact-lineage, and not over-consumed;
- evidence/source occurrence and application times are not after `loaded_at`;
- each line satisfies:

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
= sum(submitted load-application quantities)
```

Partial, excess, missing, duplicate, split, cross-wired, converted, rounded, substituted, under-evidenced, invalid-evidence, or over-consumed loads fail closed.

### Atomic output

Create one confirmed load root, every exact load line, every exact evidence bridge, one completed receipt, one `DispatchLoadConfirmed` event, one audit event, and one safe response.

The first stop load changes trip `ASSIGNED` → `LOADED`; later stop loads keep `LOADED`. Every successful load command increments the trip once and the selected stop once.

Planning, Procurement, and Evidence facts are not mutated.

## 6. `record_dispatch_departure`

### Input

```json
{
  "dispatch_trip_id": "uuid",
  "departed_at": "timestamptz"
}
```

`departed_at` must be at or after every confirmed load timestamp and not in the future. `expected_version` is the current Dispatch Trip version.

### Business invariants

Departure acts on the entire trip. Before receipt registration, authorize every distinct:

```text
customer_id + delivery_location_id + dispatch_trip_id
```

One unauthorized stop rejects the whole command. A trip-scoped actor may satisfy all tuples; customer/location scopes must cover each stop independently.

After locks, prove:

- trip is `LOADED`, not departed, and current;
- every selected-trip stop is `LOADED`;
- every stop points to one compatible plan requirement/allocation membership;
- every stop has exactly one current confirmed load for that membership;
- every current trip load belongs to a selected-trip stop and membership;
- no extra load root exists outside those scopes;
- for each load, raw load lines = current allocation lines = fully valid exact-lineage load lines;
- every allocation line is loaded exactly once at full quantity/unit;
- every load line remains exactly covered by valid load-application bridges and valid source evidence;
- no application is over-consumed across confirmed loads;
- no missing, extra, duplicate, voided, superseded, or cross-wired child exists.

Do not require every membership in the overall plan to be on this trip; a plan may contain multiple trips.

### Atomic output

Advance trip `LOADED` → `IN_TRANSIT`, set departure time, increment trip once, advance all selected-trip stops to `IN_TRANSIT` with one increment each, and create one receipt/event/audit result.

## 7. `confirm_successful_delivery`

### Input

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

The request uses exact field allowlists, 1–100 unique load-line identities, and positive delivered quantities. `confirmed_at` must be at or after departure and not in the future. `expected_version` is the current Dispatch Trip version.

### Business invariants

- trip is `IN_TRANSIT` or `PARTIALLY_DELIVERED` and has departed;
- selected stop belongs to the trip and is `IN_TRANSIT`;
- selected stop has exactly one current confirmed load for its plan membership;
- no current valid delivery confirmation exists;
- raw current load lines = submitted lines = fully valid load lines;
- every submitted line belongs to the selected trip, stop, and current load;
- no extra, missing, duplicate, cross-wired, or previously confirmed line exists;
- delivered quantity and unit exactly equal the load line;
- return quantity = 0 and exception quantity = 0 for every line.

This remains successful-path-only. Partial delivery, refusal, return, and exception handling require separate future contracts.

### Atomic output

Create one valid delivery confirmation root, one confirmation line per current load line, one receipt, one `SuccessfulDeliveryConfirmed` event, one audit event, and one safe response.

Increment the selected stop once and mark it `DELIVERED`. Increment the trip once; mark it `DELIVERED` when every stop is delivered, otherwise `PARTIALLY_DELIVERED`.

Multiple stops are confirmed sequentially using the current trip version returned by the preceding command.

## 8. Runtime and authorization boundary

Retain `atlas_dispatch_command_runtime`:

- `NOLOGIN`, `NOINHERIT`;
- owner of the same three functions;
- no new runtime role;
- fixed empty `search_path` and no dynamic SQL;
- no schema `CREATE` after temporary ownership work;
- no sequence mutation;
- explicit revoke-first API execute boundary;
- narrowly extended read/lock access only where complete PO/evidence lineage requires it;
- no Planning, Procurement, or Evidence mutation;
- no Warehouse, Storage, reporting-write, legacy, or external-service authority.

Keep the capabilities:

```text
dispatch_load.confirm
dispatch_departure.record
delivery_success.confirm
```

## 9. Command safety

Use existing command receipts, request hashes, actor resolution, authorization, safe errors, events, and audit infrastructure.

- exact replay returns original IDs;
- changed nested payloads conflict;
- stale trip versions fail safely;
- deterministic failures may retain one safe failed receipt;
- failed commands create no load, delivery, domain-event, or audit facts;
- deterministic root/child locks and existing uniqueness constraints provide structural race safety.

## 10. Simplification gate

Reuse existing authoritative tables:

```text
dispatch_loads
→ dispatch_load_lines
→ dispatch_load_line_applications

delivery_confirmations
→ delivery_confirmation_lines
```

Allowed additions are limited to one private version-specific validator, command-specific replacement SQL, narrowly required grants/RLS, focused tests, and documentation.

Do not add a public function, table, view, trigger, sequence, queue, background job, generic batch/load/delivery/workflow/repository abstraction, partial load/delivery, return/exception processing, trip closure, plan/trip/stop creation, Warehouse, UI, or deployment behavior.

## 11. Verification contract

Add:

```text
supabase/tests/pa_05b_h2_multiline_dispatch_execution.sql
```

Update only the three existing PA-05B Dispatch request scenarios to `PA-05B-H2.v1` array shapes. Evidence scenarios remain on `PA-05B.v1`.

Tests must prove:

- API count remains 15 and security ownership does not broaden;
- atomic three-line load, including one line backed by multiple applications;
- exact child cardinality, quantities, versions, replay, conflict, and failure atomicity;
- old one-line shape rejection and negative load/evidence cases;
- fully loaded multi-stop departure and every-stop authorization;
- departure rejection for incomplete/broken/invalid load or evidence lineage;
- atomic multi-line stop delivery and sequential multi-stop delivery;
- negative delivery cases and exact stop/trip statuses/versions;
- PA-04, updated PA-05B, PA-05C, PA-05B-H1, PA-05D, PA-05E, and PA-05B-H2 suites pass;
- local reset, database lint, workspace, format, typecheck, application tests, build, and whitespace checks pass.

## 12. Explicit non-goals

No PA-05F setup, PA-05B-H3 closure, PA-05G acceptance, React/generated type, live Supabase deployment, production data, credentials, seed/reference data, Retool/OPS v1 mutation, Warehouse, Storage, Edge Function, Production/QA, Finance, exception, return, or generic workflow behavior.

## 13. Completion boundary

After H2, the existing Dispatch execution commands can safely consume PA-05D and PA-05E multi-line outputs.

```text
PA-05B-H2 — multi-line Dispatch execution correction
→ PA-05F — Dispatch plan/trip/stop setup
→ PA-05B-H3 — successful trip closure (Issue #93)
→ PA-05G — command-authored source-to-closure acceptance
→ PA-06 — React connection
```
