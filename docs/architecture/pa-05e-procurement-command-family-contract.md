# PA-05E — Bounded Procurement command family

**Status:** Approved implementation contract; implemented on the Issue #88 branch pending review and merge
**Scope:** Supplier-direct wholesale Slice 1, from released Dispatch Requirement to released supplier purchase orders  
**Authority:** ARCH-001, ARCH-002, PA-01 through PA-05D, PA-05A, Procurement contracts, and the amended Dispatch/Delivery boundary  
**Implementation issue:** #88  
**Implementation instructions:** `docs/implementation-tasks/TASK-PA-05E-procurement-command-family.md`
**Migration:** `supabase/migrations/20260716023909_pa_05e_procurement_command_family.sql`
**pgTAP:** `supabase/tests/pa_05e_procurement_command_family.sql` (78 assertions)

## 1. Executive decision

PA-05E adds the Procurement-owned prerequisite between Planning release and the already implemented Evidence/Dispatch execution path:

```text
Released Dispatch Requirement
→ supplier-direct Fulfilment Allocation
→ released Supplier Purchase Order
```

PA-05E adds exactly two public commands:

1. `atlas_api.allocate_supplier_direct_fulfilment(request jsonb)`
2. `atlas_api.release_supplier_purchase_order(request jsonb)`

No public read API is added. The reviewed `atlas_api` surface becomes exactly 15 functions.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ allocate released demand to suppliers and release supplier commitments

Business Domain
→ Procurement

Business Objects
→ FulfilmentAllocation
→ FulfilmentAllocationRevision
→ FulfilmentAllocationLine / LineRevision
→ PurchaseOrder
→ PurchaseOrderRevision
→ PurchaseOrderLine / LineRevision

Business Contract
→ Procurement owns fulfilment source, supplier commitment, ordered quantity,
  and released supplier-document snapshots

Commands / Events
→ allocate_supplier_direct_fulfilment / SupplierDirectFulfilmentAllocated
→ release_supplier_purchase_order / SupplierPurchaseOrderReleased
```

Planning remains authoritative for item, required quantity, unit, destination, service date, and source lineage. Procurement consumes those released facts and may not rewrite them. Evidence later proves physical supplier fulfilment. Dispatch later plans and executes transport.

## 3. Bounded v1 simplification decision

PA-05E.v1 supports only exact supplier-direct allocation:

- every released requirement line is covered exactly once;
- one allocation portion per requirement line;
- allocated quantity equals required quantity;
- allocated unit equals required unit;
- each allocation line names one active supplier;
- no Warehouse, mixed, partial, split, substitute, rounded, or over-allocated source;
- one released PO per supplier represented in one allocation revision;
- each supplier PO contains every current allocation line for that supplier.

This deliberately avoids generic allocation and purchasing frameworks. More complex sourcing remains deferred until an approved operational invariant requires it.

## 4. Shared command envelope

Both functions use the established Atlas safe command envelope with:

- `contract_version = PA-05E.v1`;
- `command_id`;
- `correlation_id`;
- `idempotency_key`;
- `expected_version`;
- `requested_by_auth_subject`;
- `requested_at`;
- `reason_code` and optional `reason_note`;
- exact allowlisted `payload`.

Use existing PA-05B/PA-05D patterns for subject resolution, actor status, capability, relational scope, command receipts, exact replay, idempotency conflict, deterministic failure retention, optimistic concurrency, locks, safe responses, domain events, and audit events. PA-05E validation must not change prior contract behavior.

## 5. Command 1 — allocate supplier-direct fulfilment

### 5.1 Input

Exact payload:

```json
{
  "dispatch_requirement_revision_id": "uuid",
  "lines": [
    {
      "dispatch_requirement_line_revision_id": "uuid",
      "supplier_id": "uuid",
      "allocated_quantity": 10,
      "unit_id": "uuid"
    }
  ]
}
```

No unknown top-level or line fields are accepted. `lines` must contain 1–100 objects.

### 5.2 Preconditions

The command must lock and re-read the authoritative chain and prove:

- the Dispatch Requirement root exists and is `RELEASED`;
- the selected revision belongs to that root, is current, and is `RELEASED`;
- release actor/time and destination snapshots are present;
- customer and delivery location are active and relationally consistent;
- every stable requirement line has exactly one line revision under the selected revision;
- every submitted line references exactly one selected requirement line revision;
- submitted lines cover all selected requirement line revisions exactly once;
- no duplicate requirement line revision exists in the payload;
- every supplier is active;
- ingredient and unit references remain active;
- each allocated quantity is positive and equals the authoritative required quantity;
- each submitted unit equals the authoritative unit;
- ingredient, unit, quantity, handoff revision, Confirmed Need revision, approval snapshot, purchase-demand reference, wholesale revision, customer, destination, and service date remain one exact PA-05D source chain;
- no Fulfilment Allocation already exists for the Dispatch Requirement root.

`expected_version` is the current Dispatch Requirement root version.

### 5.3 Atomic output

Create exactly:

- one `fulfilment_allocations` root linked to the Dispatch Requirement root;
- one current base `fulfilment_allocation_revisions` row;
- one stable allocation line per requirement line;
- one current allocation line revision per stable line;
- one completed command receipt;
- one `SupplierDirectFulfilmentAllocated` domain event;
- one audit event;
- one safe response containing the allocation root/revision and line IDs.

Use the approved Slice 1 status vocabulary:

- allocation root: `READY_FOR_DISPATCH`;
- allocation revision: `READY_FOR_DISPATCH`;
- allocation line revision: `READY_FOR_EVIDENCE`.

The command creates no PO, Evidence, Dispatch plan/trip/stop, load, delivery, Warehouse, or reporting fact.

## 6. Command 2 — release supplier purchase order

### 6.1 Input

Exact payload:

```json
{
  "fulfilment_allocation_revision_id": "uuid",
  "supplier_id": "uuid",
  "document_number": "text"
}
```

`document_number` is trimmed, non-empty, and at most 200 characters. Unknown fields are rejected.

### 6.2 Preconditions

The command must lock and re-read the authoritative chain and prove:

- the allocation root exists and is `READY_FOR_DISPATCH`;
- the selected allocation revision belongs to the root, is current, and is `READY_FOR_DISPATCH`;
- the revision points to one released Dispatch Requirement chain;
- all current allocation line revisions remain `READY_FOR_EVIDENCE`;
- the selected supplier is active and appears on at least one current allocation line revision;
- every selected supplier line belongs to the selected allocation revision;
- each selected supplier line preserves exact requirement-line lineage;
- ingredient, unit, allocated quantity, required quantity, delivery location, and service date reconcile exactly;
- customer/location scope is singular and matches the released requirement;
- no current released PO already exists for this allocation revision and supplier;
- `document_number` is unused under the existing global uniqueness rule.

`expected_version` is the current Fulfilment Allocation root version. Releasing one supplier PO does not mutate or increment the allocation root because other suppliers may still require separate POs; uniqueness is enforced by supplier/allocation lineage rather than a generic workflow state.

### 6.3 Atomic output

For the selected supplier, create exactly:

- one `purchase_orders` root with `RELEASED_TO_SUPPLIER` status;
- one current base `purchase_order_revisions` row with `RELEASED_TO_SUPPLIER` status;
- one stable PO line for every current allocation line belonging to that supplier;
- one PO line revision per stable line;
- active supplier-name and delivery-location snapshots;
- one completed command receipt;
- one `SupplierPurchaseOrderReleased` domain event;
- one audit event;
- one safe response containing PO root/revision and line IDs.

PO line values copy the authoritative allocation/requirement facts exactly. The command creates no receiving evidence, evidence application, Dispatch plan/trip/stop, load, delivery, invoice, payment, price, tax, or Finance fact.

## 7. Runtime and authorization

Create `atlas_procurement_command_runtime`:

- `NOLOGIN`, `NOINHERIT`;
- owns only the two PA-05E functions;
- temporary ownership-transfer permissions are removed afterward;
- no Atlas schema `CREATE` privilege afterward;
- no sequence `USAGE` or `UPDATE` privilege;
- verb-specific relation grants and RLS policies only;
- reads required Admin/Core/Planning lineage;
- writes only approved Procurement rows, command receipts, domain events, and audit events;
- no Planning mutation;
- no Evidence, Dispatch, Warehouse, Storage, reporting-write, legacy, or external-service authority.

Capabilities:

- `supplier_direct_fulfilment.allocate`;
- `supplier_purchase_order.release`.

Both are owned by `PROCUREMENT`. Resolve authenticated subject, actor, capability, and relational customer/location scope server-side. Delegation and management-override shortcuts are rejected.

## 8. Concurrency, idempotency, and failure behavior

Use deterministic lock order:

1. actor/security vocabulary as needed;
2. customer and delivery location;
3. active supplier rows in UUID order;
4. Dispatch Requirement root/revision/lines;
5. Planning source-lineage rows needed for proof;
6. Fulfilment Allocation root/revision/lines;
7. existing supplier PO lineage and document number checks;
8. command receipt completion, event, and audit writes.

Required behavior:

- exact replay returns the stored response and IDs;
- same command identity with a different payload returns `IDEMPOTENCY_CONFLICT`;
- stale expected version returns `STALE_VERSION`;
- deterministic post-receipt failures retain one safe failed receipt;
- failed commands create no domain rows, domain events, or audit events;
- concurrent duplicate allocation, supplier/allocation PO, or document-number attempts produce one valid result and one safe failure.

## 9. Persistence and simplification gate

Use existing PA-04 Procurement tables. Do not add authoritative tables.

A new index or constraint is allowed only when it protects a named and tested invariant such as:

- one allocation root per Dispatch Requirement;
- one stable allocation line per requirement line and portion sequence;
- one current allocation revision per root;
- one released supplier PO per allocation revision and supplier;
- globally unique non-null document number;
- one current PO revision per root;
- one PO stable line per allocation line.

Before implementation completion, produce a complexity inventory for every new helper, index, constraint, grant, policy, and event. Remove anything without a direct PA-05E invariant or immediate PA-05G use.

Do not add a generic allocation engine, workflow engine, document engine, repository abstraction, event-sourcing layer, queue, trigger, background job, read API, or reporting view.

## 10. Verification contract

A dedicated PA-05E pgTAP suite must prove:

- exactly 15 reviewed API functions;
- two hardened PA-05E definers owned by Procurement runtime;
- correct API-role execute boundary;
- no direct API-role private access;
- no cross-domain Procurement runtime mutation;
- no non-Procurement runtime mutation of Procurement facts;
- authentication, actor, subject, capability, scope, delegation, exact payload shape, line bounds, and active references fail closed;
- allocation exact coverage, quantity/unit equality, full lineage, stale version, duplicate allocation, replay, conflict, and concurrent duplicate safety;
- PO selected-supplier filtering, all-supplier-line coverage, cross-supplier isolation, snapshot fidelity, unique supplier/allocation pair, document uniqueness, replay, conflict, and concurrency;
- cross-wired Planning/allocation lineage fails before Procurement/event/audit writes;
- allocation creates no PO, Evidence, or Dispatch execution fact;
- PO creates no Evidence or Dispatch execution fact;
- one completed receipt, one domain event, and one audit event per successful command;
- deterministic failures create no misleading event/audit state;
- all PA-04 through PA-05D regression suites pass.

## 11. Explicit non-goals

PA-05E does not add:

- partial/split allocation or multiple portions per requirement line;
- Warehouse or mixed fulfilment;
- substitutions, conversion, rounding, supplier ranking, or automatic supplier selection;
- prices, taxes, currency, payment terms, invoice, Finance, or approval hierarchy;
- PO amendment, cancellation, acknowledgement, or receipt workflow;
- Dispatch plan/trip/stop setup;
- new Evidence/load/departure/delivery commands;
- UI, generated types, seed data, live deployment, credentials, production data, Retool changes, or OPS v1 mutation.

## 12. Completion boundary

After PA-05E, the authoritative backend path is complete through supplier commitment:

```text
Wholesale source
→ Planning release chain
→ supplier-direct allocation
→ released supplier PO
```

PA-05F remains responsible for Dispatch plan/trip/stop setup. PA-05G then proves the full source-to-delivery backend path using commands rather than fixture-authored operational prerequisites.
