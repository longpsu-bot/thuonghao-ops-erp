# Decision — PA-05E bounded supplier-direct Procurement

**Status:** Approved; implemented on the Issue #88 branch pending review and merge
**Issue:** #88

## Decision

For supplier-direct wholesale Slice 1, Procurement will implement exactly two authoritative commands:

1. `allocate_supplier_direct_fulfilment`
2. `release_supplier_purchase_order`

The allocation command must cover every released Dispatch Requirement line exactly once, with one supplier and exact required quantity/unit per line. The PO command releases one supplier document at a time and includes every current allocation line belonging to that supplier.

## Why

PA-05D now creates released Planning requirements, while PA-05B Evidence commands require released supplier PO line revisions and supplier-direct allocation line revisions. Fixture-authored Procurement prerequisites are therefore the next missing authoritative boundary.

The selected shape preserves domain ownership:

- Planning owns required item, quantity, unit, customer, location, date, and source snapshots;
- Procurement owns supplier assignment and released supplier commitment;
- Evidence owns physical proof;
- Dispatch owns transport setup and execution.

## Simplification choice

PA-05E.v1 intentionally excludes partial, split, warehouse, and mixed fulfilment. It also excludes supplier auto-selection, conversion, rounding, prices, taxes, invoices, Finance, amendment, cancellation, and acknowledgement workflows.

This keeps the implementation tied to the immediate supplier-direct end-to-end path. Future complexity requires a separate approved operational invariant.

## Allocation semantics

- one allocation root per Dispatch Requirement root;
- one current base allocation revision;
- one stable allocation line per requirement line;
- one allocation portion per requirement line;
- full exact requirement coverage;
- multiple suppliers may appear across different lines;
- every line revision is `READY_FOR_EVIDENCE`;
- allocation root/revision use the existing `READY_FOR_DISPATCH` schema status.

The status vocabulary is retained for compatibility with the approved PA-04 schema and PA-05B consumers. It does not imply that physical supplier evidence already exists.

## PO semantics

- one command call releases one PO for one supplier within one allocation revision;
- all current allocation lines for that supplier must be included;
- callers cannot select or omit individual supplier lines;
- multiple suppliers require separate PO commands;
- one current released PO per allocation revision and supplier;
- document number follows existing global uniqueness;
- supplier and delivery-location text are snapshotted at release;
- releasing one supplier PO does not mutate allocation version/status because other supplier POs may still remain.

## Runtime decision

Create one `atlas_procurement_command_runtime` role, `NOLOGIN` and `NOINHERIT`, owning only the two PA-05E functions. It may read the minimum Admin/Core/Planning lineage and write only approved Procurement, receipt, event, and audit rows. It receives no Planning mutation, Evidence, Dispatch, Warehouse, Storage, reporting-write, legacy, or sequence-mutation authority.

## Rejected alternatives

### Generic fulfilment allocation engine

Rejected because it would introduce split, mixed, warehouse, substitution, and conversion abstractions before an approved operational need.

### One cross-domain command that allocates, releases PO, and records evidence

Rejected because it collapses Procurement and Evidence ownership and obscures physical proof.

### Caller-selected PO lines

Rejected because it permits silent omission of supplier commitments and creates partial supplier-document ambiguity.

### One PO containing multiple suppliers

Rejected because a supplier PO is a commitment to one supplier and must preserve supplier-specific evidence lineage.

### Increment allocation version after each supplier PO

Rejected for PA-05E.v1 because PO release does not change supplier assignment or allocated quantities. Supplier/allocation uniqueness protects duplicate release without creating artificial revision churn.

## Consequences

Positive:

- removes fixture-authored Procurement prerequisites;
- preserves exact Planning lineage;
- supports multiple suppliers without split-line complexity;
- matches existing PA-05B evidence inputs;
- keeps future Warehouse and mixed fulfilment deferred.

Trade-offs:

- no partial allocation or backorder;
- no PO amendment or cancellation;
- no price or commercial terms;
- allocation status wording remains broader than the exact operational meaning.

These trade-offs are accepted for the first executable supplier-direct backend slice.
