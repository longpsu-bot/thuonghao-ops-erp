# PA-05D — Bounded Planning command family

**Status:** Proposed implementation contract; documentation only  
**Scope:** Supplier-direct wholesale Slice 1 Planning source-to-dispatch-requirement command family  
**Authority:** ARCH-001, ARCH-002, PA-01 through PA-05B-H1, PA-05A, the Confirmed Need and Purchase Handoff contracts, and the amended Dispatch/Delivery boundary  
**Implementation issue:** #85  
**Next gate:** One bounded SQL implementation PR after this contract is approved

## 1. Executive decision

PA-05D adds the missing Planning-owned beginning of the supplier-direct wholesale Slice 1 backend. It does not add a generic Planning workflow. It implements one deliberately narrow path:

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

PA-05D creates no Procurement allocation, purchase order, physical evidence, dispatch plan, trip, stop, load, delivery, UI, deployment, seed data, or OPS v1 change.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ capture and release exact wholesale demand for downstream fulfilment

Business Domain
→ Planning

Business Object
→ WholesaleOrder
→ ConfirmedNeedBatch / ConfirmedNeedLine
→ PurchaseHandoff
→ DispatchRequirement

Business Contract
→ Planning owns what is required, quantity, destination, service date, and release snapshots
→ downstream domains consume but never rewrite these facts

Command / Event
→ record_wholesale_source / WholesaleOrderRecorded
→ release_wholesale_order / WholesaleOrderReleased
→ release_purchase_handoff / PurchaseHandoffReleased
→ release_dispatch_requirement / DispatchRequirementReleased

Read Model
→ no new public read API; existing trace/readiness APIs remain authoritative read surfaces

Application
→ none in PA-05D

Technology
→ PostgreSQL/Supabase migration, SECURITY DEFINER functions, least-privilege runtime role, RLS, pgTAP
```

## 3. Why this command family is required

PA-05B and PA-05C implement the latter half of the supplier-direct path: Evidence records what physically arrived, Dispatch records load/departure/delivery, and authorized reads expose trace/readiness/blockers/audit. Their tests currently construct Planning, Procurement, and Dispatch-setup prerequisites directly as rolled-back fixtures.

The backend therefore cannot yet author its own source-to-requirement chain. PA-05D removes the first prerequisite gap while preserving business ownership:

```text
Planning output
→ becomes the immutable input to Procurement
→ later becomes the immutable input to Dispatch
```

OPS v1 Retool and the current OPS v2 SQL remain business evidence only. Their operational intent—capture daily demand, confirm purchasing inputs, and materialize dispatch outputs—is preserved, but their screen/query coupling and broad public-function posture are not copied into Atlas.

## 4. Bounded simplification for direct wholesale

The full Planning contracts support generic creation, validation, adjustment, approval, reopening, invalidation, and revision workflows. PA-05D intentionally does not expose that complete lifecycle.

For supplier-direct wholesale Slice 1:

- the customer order is a manually confirmed direct source, not a menu/attendance/BOM calculation;
- every recorded line is an exact ingredient, positive quantity, controlled unit, destination, and service date;
- `release_wholesale_order` performs validation, approval, and release atomically;
- the command materializes a pass-through Confirmed Need in final `RELEASED_FOR_PURCHASE_HANDOFF` state;
- `theoretical_quantity` equals `confirmed_quantity` equals the released wholesale line quantity;
- the releasing actor is both approval and release actor for this bounded path;
- `release_purchase_handoff` performs preparation, validation, and release atomically;
- `release_dispatch_requirement` creates one released Planning delivery obligation from one released handoff revision.

This is a slice-specific shortcut, not a replacement for the school-catering Planning lifecycle. Separate commands remain required before Atlas persists calculated school-catering demand, manual confirmed-need adjustments, reopening, invalidation, additive revisions, or cancellations.

## 5. Shared request and result contract

### 5.1 Request envelope

All four commands use contract version `PA-05D.v1` and require:

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

The server resolves the authenticated subject and actor. Caller actor IDs, delegated actors, management overrides, approvals, table names, status names, and generated aggregate IDs are not accepted in payloads.

### 5.2 Success result

A success response follows the existing Atlas command shape:

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

Generated root, line, revision, and snapshot IDs are returned only as allowlisted opaque IDs needed by the next command or diagnostics.

### 5.3 Failure result

Failures use the existing safe command error envelope:

```text
success: false
error_code
safe_message
domain: PLANNING
command_name
retryable
field_errors
blocking_references
expected_version
actual_version
correlation_id
command_id
```

No SQL, table, policy, role, JWT, credential, stack trace, or service-role information is returned.

## 6. Command contract: `record_wholesale_source`

### 6.1 Purpose

Create one Draft wholesale source root and its stable lines/current line revisions. This records customer demand only; it does not approve or release demand.

### 6.2 Required capability and scope

- Capability: `wholesale_source.record`
- Owning domain: `PLANNING`
- Required relational scope: matching `customer_id` or `delivery_location_id`, or `GLOBAL`

### 6.3 Payload

```json
{
  "customer_id": "<uuid>",
  "delivery_location_id": "<uuid>",
  "customer_order_reference": "<required non-empty text, max 200>",
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

The `lines` array must contain 1–100 entries. `source_line_number` values must be positive and unique in the request.

### 6.4 Validation

The command rejects:

- missing, malformed, empty, or oversized payload fields;
- a customer that is not active or not `WHOLESALE`;
- an inactive delivery location or a location that does not belong to the customer;
- an inactive ingredient or unit;
- non-positive quantity;
- duplicate source-line numbers;
- an existing non-cancelled wholesale order with the same customer and customer-order reference;
- `expected_version` other than `1` for this create command;
- unsupported delegation/override fields.

### 6.5 Writes

Atomically create:

- one `atlas_planning.wholesale_orders` row in `DRAFT`, version `1`;
- one `wholesale_order_lines` row per payload line;
- one current `wholesale_order_line_revisions` row per line with revision `1`, status `DRAFT`, and the command ID;
- one `WholesaleOrderRecorded` domain event;
- one matching audit event;
- one completed command receipt.

No Confirmed Need, Purchase Handoff, Dispatch Requirement, Procurement, Evidence, or Dispatch row is created.

### 6.6 Idempotency scope and event

- Receipt scope: customer + normalized customer-order reference
- Event type: `WholesaleOrderRecorded`
- Aggregate type: `WholesaleOrder`
- Aggregate version: `1`

## 7. Command contract: `release_wholesale_order`

### 7.1 Purpose

Validate and release one Draft wholesale order and atomically materialize the exact pass-through Confirmed Need release consumed by Purchase Handoff.

### 7.2 Required capability and scope

- Capability: `wholesale_order.release`
- Owning domain: `PLANNING`
- Scope: customer/location resolved from the authoritative order

### 7.3 Payload

```json
{
  "wholesale_order_id": "<uuid>"
}
```

`expected_version` must equal the current wholesale-order root version.

### 7.4 Preconditions

The command requires:

- order status `DRAFT`;
- at least one current Draft line revision;
- every stable line has exactly one current line revision;
- active wholesale customer, active matching delivery location, active ingredients, and active units;
- all quantities remain positive;
- no prior Confirmed Need batch for the order;
- no downstream handoff, allocation, PO, evidence, or dispatch facts for this source.

### 7.5 Writes

Atomically:

1. update the wholesale order to `RELEASED`;
2. record approval and release actor/time on the order;
3. increment the wholesale-order root version exactly once;
4. update current wholesale line revisions from `DRAFT` to `RELEASED`;
5. create one Confirmed Need batch in `RELEASED_FOR_PURCHASE_HANDOFF`, version `1`;
6. create stable Confirmed Need lines mapped one-to-one to wholesale stable lines;
7. create current Confirmed Need line revisions with:
   - revision number `1`;
   - exact wholesale line-revision reference;
   - `theoretical_quantity = confirmed_quantity = requested_quantity`;
   - exact ingredient and unit;
   - status `RELEASED`;
8. create one approval snapshot for approved version `1`;
9. create one snapshot line per Confirmed Need line using the ingredient name captured at release;
10. append one `WholesaleOrderReleased` domain event and one audit event;
11. complete the command receipt with the generated Confirmed Need IDs.

### 7.6 Deliberate simplification

The command does not persist intermediate `VALIDATED` or `APPROVED` states. It proves those checks inside the same transaction and records the final immutable release. This is valid only for the direct-wholesale pass-through path.

### 7.7 Event

- Event type: `WholesaleOrderReleased`
- Aggregate type: `WholesaleOrder`
- Aggregate version: the new wholesale-order version
- Payload summary includes the generated Confirmed Need batch ID, released line count, service date, customer ID, and location ID.

## 8. Command contract: `release_purchase_handoff`

### 8.1 Purpose

Create and release one Procurement-facing Purchase Handoff from one released direct-wholesale Confirmed Need batch.

### 8.2 Required capability and scope

- Capability: `purchase_handoff.release`
- Owning domain: `PLANNING`
- Scope: customer/location resolved through the authoritative wholesale source

### 8.3 Payload

```json
{
  "confirmed_need_batch_id": "<uuid>"
}
```

`expected_version` must equal the current Confirmed Need batch version.

### 8.4 Preconditions

The command requires:

- batch status `RELEASED_FOR_PURCHASE_HANDOFF`;
- approval and release actor/time present;
- an approval snapshot matching the expected batch version;
- each stable Confirmed Need line has one current released line revision and one matching snapshot line;
- each released quantity is positive for this direct-wholesale slice;
- exact wholesale source revision, ingredient, unit, service date, and destination lineage;
- no existing Purchase Handoff batch for the Confirmed Need batch.

### 8.5 Writes

Atomically create:

- one Purchase Handoff batch in `RELEASED_TO_PROCUREMENT`, version `1`;
- one current `BASE` Purchase Handoff revision in `RELEASED_TO_PROCUREMENT` with release actor/time and command ID;
- one stable handoff line per Confirmed Need line;
- one handoff line revision with exact quantity, unit, service date, delivery location, and source Confirmed Need revision;
- one immutable purchase-demand reference per handoff line revision linking the approved snapshot line and exact wholesale source revision;
- one `PurchaseHandoffReleased` domain event;
- one audit event;
- one completed command receipt.

The command creates no supplier assignment, fulfilment allocation, PO, supplier confirmation, or physical evidence.

### 8.6 Event

- Event type: `PurchaseHandoffReleased`
- Aggregate type: `PurchaseHandoff`
- Aggregate version: `1`

## 9. Command contract: `release_dispatch_requirement`

### 9.1 Purpose

Create one Planning-owned released delivery obligation from one current released Purchase Handoff revision.

### 9.2 Required capability and scope

- Capability: `dispatch_requirement.release`
- Owning domain: `PLANNING`
- Scope: customer/location resolved through the authoritative wholesale source and handoff

### 9.3 Payload

```json
{
  "purchase_handoff_revision_id": "<uuid>"
}
```

`expected_version` must equal the Purchase Handoff batch root version.

### 9.4 Preconditions

The command requires:

- handoff root and revision status `RELEASED_TO_PROCUREMENT`;
- the selected revision is current and has release actor/time;
- every stable handoff line has exactly one line revision in the selected revision;
- every handoff line has a purchase-demand reference and exact source lineage;
- all lines resolve to the same wholesale customer, delivery location, and service date;
- customer and location are still valid at release time;
- no current released Dispatch Requirement already exists for the handoff revision.

### 9.5 Writes

Atomically create:

- one `DispatchRequirement` root with source `WHOLESALE`, status `RELEASED`, version `1`;
- one current `BASE` requirement revision with status `RELEASED`;
- customer name, location name, address, timezone, and optional delivery-window snapshots;
- one stable requirement line per handoff stable line;
- one requirement line revision with exact handoff revision, ingredient, quantity, and unit;
- one `DispatchRequirementReleased` domain event;
- one audit event;
- one completed command receipt.

The command creates no fulfilment allocation, dispatch plan, trip, stop, load, or delivery row.

### 9.6 Event

- Event type: `DispatchRequirementReleased`
- Aggregate type: `DispatchRequirement`
- Aggregate version: `1`

## 10. Authorization and runtime boundary

PA-05D introduces one no-login, no-inherit role:

```text
atlas_planning_command_runtime
```

It owns only the four PA-05D entry functions.

It may receive only the practical minimum needed to:

- resolve actors, capabilities, memberships, and scopes;
- use command receipts and existing private command helpers;
- read required Admin customer/location/ingredient/unit references;
- write the approved Planning tables for these four commands;
- insert Planning domain and audit events.

It must not have:

- `CREATE` on any Atlas schema after function ownership transfer;
- Procurement, Evidence, Dispatch, Warehouse, Storage, or legacy write privileges;
- sequence mutation privileges;
- direct membership in another command runtime;
- broad `FOR ALL` RLS policies where verb-specific policies are practical.

`authenticated` receives execute on the four reviewed functions only after all public execute is revoked. `anon` and `service_role` receive no execute. API roles retain no direct private table, view, or sequence privileges.

## 11. Shared command infrastructure

PA-05D may reuse the existing private PA-05B helpers where their behavior is already generic and tested:

- safe UUID/bigint/numeric/timestamp parsing;
- current auth-subject resolution;
- safe command errors;
- actor and capability/scope authorization;
- canonical request hashing;
- command receipt begin/replay/conflict handling;
- command completion.

PA-05D must add a private request validator for `PA-05D.v1`; it must not change the `PA-05B.v1` validator or the behavior of the nine existing API functions.

The private helper names are implementation history, not public business contracts. Avoid renaming or generalizing them in this task unless compilation requires a narrowly reviewed compatibility wrapper.

## 12. Transactions, locks, and concurrency

Each command is one short statement transaction under `read committed`.

Lock order:

```text
1. command receipt
2. Admin customer/location/ingredient/unit references
3. Planning source root
4. Planning stable lines and current revisions in UUID order
5. Planning downstream root/snapshots created by the command
6. audit and domain events
```

Rules:

- acquire parent/root locks before child rows;
- lock multiple rows in deterministic UUID order;
- re-read status, version, current revision, active references, and lineage after locks;
- stale expected version returns `STALE_VERSION` with no domain write;
- exact replay returns the stored safe response;
- same key or command ID with a different request returns `IDEMPOTENCY_CONFLICT`;
- all multi-line writes succeed or fail together;
- serialization/deadlock failures are retryable whole-command failures;
- deterministic validation failures are safe non-retryable results;
- one successful command creates one receipt, one domain event, and one audit event.

## 13. Database constraints allowed in PA-05D

The implementation may add only constraints/indexes required to make the approved command contract race-safe, including:

- one active/non-cancelled wholesale order per `(customer_id, customer_order_reference)`;
- one Confirmed Need batch per wholesale order for this slice;
- one current released Dispatch Requirement per released Purchase Handoff revision.

Any additional schema object requires explicit justification in the PR description. Do not introduce generic workflow, status, numbering, queue, or orchestration tables.

## 14. Required errors

At minimum, tests must cover:

- `VALIDATION_FAILED`
- `AUTHENTICATION_REQUIRED`
- `AUTH_SUBJECT_MISMATCH`
- `ACTOR_NOT_FOUND`
- `AUTH_SUBJECT_INACTIVE`
- `ACTOR_INACTIVE`
- `CAPABILITY_DENIED`
- `SCOPE_DENIED`
- `DELEGATION_NOT_SUPPORTED`
- `STALE_VERSION`
- `IDEMPOTENCY_CONFLICT`
- `INVARIANT_VIOLATION`
- `RETRYABLE_CONCURRENCY_FAILURE`
- `INTERNAL_COMMAND_FAILURE`

Messages must be safe and expressed in business terms.

## 15. Verification contract

A dedicated PA-05D pgTAP file must prove:

### Callable and privilege boundary

- the API function count becomes exactly 13;
- the four functions are `SECURITY DEFINER`, owned by `atlas_planning_command_runtime`, use an empty fixed search path, and use no dynamic SQL;
- Planning runtime has no schema `CREATE`, sequence mutation, or non-Planning domain writes;
- Evidence and Dispatch runtimes gain no Planning write privilege;
- `anon` and `service_role` cannot execute Atlas API functions;
- `authenticated` can execute exactly the 13 reviewed functions;
- API roles retain no direct private relation access.

### Authorization and envelope

- missing/mismatched/revoked auth subject, inactive actor, missing capability, and wrong scope fail closed;
- malformed, unbounded, unsupported delegation, empty lines, duplicate line numbers, and non-positive quantities fail safely.

### Business behavior

- multi-line wholesale source creation is atomic;
- exact replay returns the original IDs and creates no duplicates;
- same key/different payload conflicts;
- duplicate customer-order reference is rejected;
- wholesale release rejects stale version or wrong lifecycle;
- wholesale release creates exact released Confirmed Need rows and approval snapshot;
- handoff release preserves confirmed/snapshot/source lineage and creates no supplier/PO fact;
- requirement release preserves customer/location/date and line lineage and creates no allocation/Dispatch execution fact;
- each successful command creates one receipt, one domain event, and one audit event;
- deterministic failure creates no misleading domain/event/audit mutation;
- the existing supplier-direct trace can consume the generated Planning chain after later Procurement/Dispatch fixture completion.

### Regression

Run PA-04, PA-05B, PA-05C, and PA-05B-H1 tests unchanged except narrow cumulative API-count/owner expectations where required.

## 16. Explicit exclusions

PA-05D adds no:

- generic Need Generation command;
- school-catering menu, attendance, recipe, or BOM persistence;
- confirmed-need adjustment, reopen, invalidation, additive revision, or cancellation command;
- supplier assignment, fulfilment allocation, purchase order, or supplier confirmation;
- Warehouse schema or stock behavior;
- supplier physical evidence command beyond existing PA-05B;
- dispatch plan, trip, stop, load, departure, delivery, exception, return, or closure command beyond existing PA-05B;
- new read API;
- React or generated Supabase types;
- Edge Function or Storage feature;
- controlled seed/reference data;
- live Supabase deployment or hosted-project command;
- production data, credentials, Retool change, or OPS v1 mutation;
- Production/QA, Finance, or generic workflow engine.

## 17. Rollback and next gates

Before deployment, rollback is a Git revert/removal of the unshipped migration, tests, and docs. No hosted database is authorized.

After PA-05D is reviewed and merged, the next bounded backend tasks are:

```text
PA-05E — Procurement command family
→ allocate_supplier_direct_fulfilment
→ release_supplier_purchase_order

PA-05F — Dispatch setup command family
→ create_dispatch_plan
→ create_or_assign_dispatch_trip and stops

PA-05G — backend end-to-end acceptance
→ source → Planning release → allocation → PO → Evidence
→ load → departure → delivery → trace
```

PA-06 React connection remains after backend acceptance under the product owner's current sequencing decision.