# PA-05D — Bounded Planning command family

**Status:** Approved implementation contract; implemented on the Issue #85 task branch pending review
**Scope:** Supplier-direct wholesale Slice 1, from wholesale source to released Dispatch Requirement  
**Authority:** ARCH-001, ARCH-002, PA-01 through PA-05B-H1, PA-05A, the Confirmed Need and Purchase Handoff contracts, and the amended Dispatch/Delivery boundary  
**Implementation issue:** #85  
**Implementation instructions:** `docs/implementation-tasks/TASK-PA-05D-planning-command-family.md`
**Migration:** `supabase/migrations/20260715163344_pa_05d_planning_command_family.sql`
**Verification:** `supabase/tests/pa_05d_planning_command_family.sql` (60 rolled-back assertions)

## 1. Executive decision

PA-05D implements the missing Planning-owned beginning of the supplier-direct wholesale backend:

```text
Wholesale customer source
→ released wholesale order
→ released pass-through Confirmed Need
→ released Purchase Handoff
→ released Dispatch Requirement
```

The callable surface is exactly:

1. `atlas_api.record_wholesale_source(request jsonb) returns jsonb`
2. `atlas_api.release_wholesale_order(request jsonb) returns jsonb`
3. `atlas_api.release_purchase_handoff(request jsonb) returns jsonb`
4. `atlas_api.release_dispatch_requirement(request jsonb) returns jsonb`

Contract version: `PA-05D.v1`.

PA-05D creates no Procurement allocation, purchase order, physical evidence, dispatch plan, trip, stop, load, delivery, read API, UI, deployment, seed data, or OPS v1 change.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ capture and release exact wholesale demand for downstream fulfilment

Business Domain
→ Planning

Business Objects
→ WholesaleOrder
→ ConfirmedNeedBatch / ConfirmedNeedLine
→ PurchaseHandoff
→ DispatchRequirement

Business Contract
→ Planning owns item, quantity, destination, service date, and release snapshots
→ downstream domains consume but never rewrite those facts

Commands / Events
→ record_wholesale_source / WholesaleOrderRecorded
→ release_wholesale_order / WholesaleOrderReleased
→ release_purchase_handoff / PurchaseHandoffReleased
→ release_dispatch_requirement / DispatchRequirementReleased

Read Model
→ no new public read API
→ existing trace, readiness, blocker, and audit reads remain approved advisory surfaces
→ authoritative writes continue to lock and re-read domain tables

Application
→ none in PA-05D

Technology
→ PostgreSQL/Supabase migration, SECURITY DEFINER functions, least-privilege runtime role, RLS, pgTAP
```

## 3. Why PA-05D is required

PA-05B and PA-05C implement the latter half of the supplier-direct path: physical Evidence, load, departure, successful delivery, trace, readiness, blockers, and audit reads. Their tests currently create Planning, Procurement, and Dispatch-setup prerequisites directly as rolled-back fixtures.

PA-05D removes the first prerequisite gap. Its output becomes immutable input to Procurement and later to Dispatch.

OPS v1 Retool and OPS v2 SQL remain business evidence only. Atlas preserves their operational intent—capture daily demand and create purchasing/dispatch inputs—but does not copy their screen/query coupling or broad public-function posture.

## 4. Bounded direct-wholesale simplification

The generic Planning contracts include separate create, validate, adjust, approve, reopen, invalidate, revise, and cancel commands. PA-05D deliberately does not implement that full lifecycle.

For supplier-direct wholesale Slice 1:

- the source is a manually confirmed wholesale customer order, not menu/attendance/BOM calculation;
- every line has an exact ingredient, positive quantity, controlled unit, destination, and service date;
- `release_wholesale_order` validates, approves, and releases atomically;
- it materializes a pass-through Confirmed Need directly in `RELEASED_FOR_PURCHASE_HANDOFF`;
- `theoretical_quantity = confirmed_quantity = released wholesale quantity`;
- the releasing actor is recorded as both approval and release actor for this bounded path;
- `release_purchase_handoff` prepares, validates, and releases atomically;
- `release_dispatch_requirement` creates one released Planning obligation from one released handoff revision.

This shortcut is valid only for direct wholesale. School-catering persistence, manual confirmed-need adjustment, separation of duties, reopening, invalidation, additive revisions, and cancellation require later approved commands.

## 5. Shared command contract

### 5.1 Envelope

All commands require:

```json
{
  "contract_version": "PA-05D.v1",
  "command_id": "<uuid>",
  "correlation_id": "<uuid>",
  "idempotency_key": "<non-empty text, max 200>",
  "expected_version": 1,
  "requested_by_auth_subject": "<uuid>",
  "requested_at": "<non-future timestamptz>",
  "reason_code": "<non-empty text>",
  "reason_note": null,
  "payload": {}
}
```

The server resolves the authenticated subject and actor. Payloads must not accept actor IDs, delegated actors, management overrides, approvals, generated aggregate IDs, table names, or lifecycle status names.

### 5.2 Result

Success follows the established Atlas shape:

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

Failure follows the established safe error shape with `domain: PLANNING`. SQL, policy, role, JWT, credential, service-role, and stack-trace details are never returned.

### 5.3 Atomicity

Every successful command creates exactly:

- one completed command receipt;
- one domain event;
- one audit event;
- one safe response.

Exact replay returns the original response and IDs. Same command ID or scoped idempotency key with a different canonical request returns `IDEMPOTENCY_CONFLICT`. Stale expected version returns `STALE_VERSION`. Multi-line writes are all-or-nothing.

## 6. Command definitions

### 6.1 `record_wholesale_source`

**Capability:** `wholesale_source.record`  
**Scope:** matching customer or delivery location, or `GLOBAL`

Payload:

```json
{
  "customer_id": "<uuid>",
  "delivery_location_id": "<uuid>",
  "customer_order_reference": "<required text, max 200>",
  "service_date": "YYYY-MM-DD",
  "lines": [
    {
      "source_line_number": 1,
      "ingredient_id": "<uuid>",
      "requested_quantity": 10,
      "unit_id": "<uuid>"
    }
  ]
}
```

Rules:

- `expected_version` must be `1`;
- 1–100 lines;
- positive, unique source-line numbers;
- positive quantities;
- active wholesale customer;
- active location belonging to that customer;
- active ingredients and units;
- required non-empty customer reference;
- reject an existing non-cancelled order with the same customer/reference.

Writes:

- one `wholesale_orders` root in `DRAFT`, version `1`;
- stable `wholesale_order_lines`;
- current revision-1 `wholesale_order_line_revisions` in `DRAFT` with command ID;
- `WholesaleOrderRecorded` event and matching audit event.

It creates no downstream Planning object.

### 6.2 `release_wholesale_order`

**Capability:** `wholesale_order.release`  
**Payload:** `{ "wholesale_order_id": "<uuid>" }`  
**Scope:** resolved from the authoritative order

Preconditions:

- root status `DRAFT` and version equals `expected_version`;
- at least one stable line;
- every line has exactly one current Draft revision;
- active customer, matching active location, ingredients, and units;
- positive quantities;
- no prior Confirmed Need batch or downstream fact for this source.

Writes atomically:

1. update the wholesale root to `RELEASED` and increment version once;
2. record approval and release actor/time;
3. update current line revisions to `RELEASED`;
4. create one Confirmed Need batch in `RELEASED_FOR_PURCHASE_HANDOFF`, version `1`;
5. create one stable Confirmed Need line per wholesale line;
6. create released revision-1 Confirmed Need line revisions with exact source, ingredient, unit, and equal theoretical/confirmed/released quantities;
7. create one approval snapshot and exact snapshot lines using the released ingredient name;
8. emit `WholesaleOrderReleased` and matching audit event.

Intermediate `VALIDATED` and `APPROVED` states are proven inside the transaction but not persisted as separate command results in this bounded path.

### 6.3 `release_purchase_handoff`

**Capability:** `purchase_handoff.release`  
**Payload:** `{ "confirmed_need_batch_id": "<uuid>" }`  
**Scope:** resolved through the authoritative wholesale source

Preconditions:

- Confirmed Need batch version equals `expected_version`;
- status `RELEASED_FOR_PURCHASE_HANDOFF`;
- approval and release actor/time present;
- approval snapshot matches the current batch version;
- each stable line has one current released revision and matching snapshot line;
- positive quantity and complete wholesale source, ingredient, unit, date, and destination lineage;
- no existing Purchase Handoff batch for the source batch.

Writes atomically:

- one Purchase Handoff batch in `RELEASED_TO_PROCUREMENT`, version `1`;
- one current `BASE` revision in `RELEASED_TO_PROCUREMENT` with release actor/time and command ID;
- one stable handoff line per Confirmed Need line;
- exact handoff line revisions with quantity, unit, service date, delivery location, and source revision;
- one immutable purchase-demand reference per line;
- `PurchaseHandoffReleased` event and matching audit event.

It creates no supplier assignment, allocation, PO, supplier confirmation, or physical evidence.

### 6.4 `release_dispatch_requirement`

**Capability:** `dispatch_requirement.release`  
**Payload:** `{ "purchase_handoff_revision_id": "<uuid>" }`  
**Scope:** resolved through the authoritative wholesale source and handoff

Preconditions:

- Purchase Handoff root version equals `expected_version`;
- root and selected current revision are `RELEASED_TO_PROCUREMENT`;
- revision has release actor/time;
- every stable handoff line has exactly one line revision and one purchase-demand reference;
- all lines resolve to one wholesale customer, location, and service date;
- customer and location remain valid;
- no current released Dispatch Requirement exists for the selected handoff revision.

Writes atomically:

- one wholesale `DispatchRequirement` root in `RELEASED`, version `1`;
- one current `BASE` requirement revision in `RELEASED`;
- customer name, location name, address, timezone, and optional delivery-window snapshots;
- one stable requirement line per handoff stable line;
- exact requirement line revisions with handoff lineage, ingredient, quantity, and unit;
- `DispatchRequirementReleased` event and matching audit event.

It creates no fulfilment allocation, plan, trip, stop, load, or delivery fact.

## 7. Authorization and runtime boundary

PA-05D introduces:

```text
atlas_planning_command_runtime
```

The role is `NOLOGIN`, `NOINHERIT` and owns only the four PA-05D entry functions.

It may receive only the practical minimum to:

- resolve actors, capabilities, memberships, and scopes;
- use command receipts and existing private command helpers;
- read required Admin customer/location/ingredient/unit references;
- write the approved Planning tables;
- append Planning domain and audit events.

It must not have:

- Atlas schema `CREATE` after function ownership transfer;
- sequence mutation;
- Procurement, Evidence, Dispatch, Warehouse, Storage, reporting-write, or legacy privileges;
- membership in another command runtime;
- broad `FOR ALL` RLS policies where verb-specific policies are practical.

`authenticated` receives execute on the four reviewed functions only after public execute is revoked. `anon` and `service_role` receive no execute. API roles retain no direct private relation access. Existing Evidence, Dispatch, and Read runtime privileges must not broaden.

## 8. Shared infrastructure and locking

PA-05D may reuse the tested PA-05B private helpers for parsing, auth resolution, safe errors, authorization, hashing, receipt/replay/conflict handling, and command completion.

It must add a private `PA-05D.v1` request validator and must not change PA-05B or PA-05C public behavior. Avoid broad helper renaming or a generic command framework.

Lock order:

```text
receipt
→ Admin references
→ Planning parent root
→ Planning lines/current revisions in deterministic UUID order
→ new Planning snapshots/downstream roots
→ domain event and audit event
```

Re-read status, version, current-revision state, active references, and lineage after locks. Serialization and deadlock failures are retryable whole-command failures.

## 9. Allowed race-safety constraints

The implementation may add only narrowly justified constraints/indexes for:

- one non-cancelled wholesale order per customer/reference;
- one Confirmed Need batch per wholesale order for this slice;
- one current released Dispatch Requirement per released handoff revision.

Do not add workflow, queue, numbering, orchestration, or generic status tables.

## 10. Verification contract

A dedicated PA-05D pgTAP suite must prove:

### API and privileges

- exactly 13 reviewed `atlas_api` functions;
- all four PA-05D functions are hardened definers owned by Planning runtime, use empty fixed search paths, and contain no dynamic SQL;
- Planning runtime has no Atlas schema `CREATE`, sequence mutation, or non-Planning write privilege;
- Evidence and Dispatch runtimes cannot write Planning facts;
- `authenticated` can execute exactly 13 functions;
- `anon` and `service_role` cannot execute Atlas API functions;
- API roles retain no direct private relation access.

### Authorization and validation

- missing/mismatched/revoked auth subject, inactive actor, missing capability, wrong scope, and unsupported delegation fail closed;
- malformed input, zero or more than 100 lines, duplicate line numbers, inactive references, wrong customer/location relation, and non-positive quantities fail safely.

### Business behavior

- multi-line source creation is atomic;
- replay returns original IDs without duplicates;
- conflicting replay fails;
- duplicate customer-order reference is rejected;
- stale version and wrong lifecycle fail without mutation;
- wholesale release creates exact released Confirmed Need rows and approval snapshot;
- handoff release preserves confirmed/snapshot/source lineage and creates no Procurement fact;
- requirement release preserves customer/location/date/line lineage and creates no allocation or Dispatch execution fact;
- each success creates exactly one receipt, event, and audit row;
- deterministic failure creates no misleading domain/event/audit mutation.

PA-04, PA-05B, PA-05C, and PA-05B-H1 tests must remain green except for narrow cumulative API-count/owner expectations required by the four new functions.

## 11. Explicit exclusions

PA-05D adds no:

- generic Need Generation or school-catering persistence;
- confirmed-need adjustment, reopen, invalidation, revision, or cancellation;
- supplier assignment, fulfilment allocation, PO, or supplier confirmation;
- Dispatch plan, trip, stop, exception, return, or closure setup;
- new Evidence/load/departure/delivery behavior;
- new read API;
- React, generated Supabase type, Edge Function, or Storage;
- controlled seed/reference data;
- live Supabase deployment or hosted-project command;
- production data, credential, Retool change, or OPS v1 mutation;
- Warehouse, Production/QA, Finance, or generic workflow engine.

## 12. Rollback and next gates

Before deployment, rollback is Git removal/reversion of the unshipped migration, tests, and documentation. No hosted database is authorized.

After PA-05D:

```text
PA-05E — Procurement allocation and released supplier PO
→ PA-05F — Dispatch plan/trip/stop setup
→ PA-05G — backend source-to-delivery acceptance
→ PA-06 — React connection under the current backend-first sequencing decision
```
