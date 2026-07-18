# PA-05C-H3 — Evidence Readiness Current Command Context

**Status:** Implemented on the PA-05C-H3 task branch; pending review and merge

**Domain:** Reporting / Read

**Issue:** #110

**Blocked consumer:** #109 (PA-06C)

**Migration:** `supabase/migrations/20260718084742_pa_05c_h3_evidence_readiness_current_command_context.sql`

**Verification:** `supabase/tests/pa_05c_h3_evidence_readiness_current_command_context.sql`

## Purpose

PA-06C orientation found a bounded stale-recovery gap. `record_supplier_receiving_evidence(jsonb)` guards `purchase_orders.version`, while `apply_supplier_evidence_to_allocation(jsonb)` guards `fulfilment_allocations.version`. READ-02 already exposes Evidence readiness but did not return those authoritative root IDs and direct current versions.

A stale command response may include `actual_version`, but that value is diagnostic. It does not prove which current revision, stable line, line revision, supplier, ingredient, unit, service date, or destination now belongs to the root. Audit history is likewise historical evidence, not a current aggregate refresh.

PA-05C-H3 therefore extends the existing bounded read:

```text
atlas_api.get_dispatch_evidence_readiness(request jsonb)
```

It adds current command-building context without adding a discovery API, queue, capability, browser table read, or nineteenth RPC. Both write commands continue to lock and revalidate all authoritative state.

## OPS_SYSTEM_MAP

```text
Mission
→ make Atlas operations safe, maintainable, and transferable

Business Capability
→ refresh reviewed Supplier Evidence command context after stale rejection

Business Domain
→ Reporting / Read

Business Object
→ Fulfilment Allocation and Purchase Order current lineage

Business Contract
→ bounded authorized snapshot; current lineage only; contradictions fail closed

Command / Event
→ none

Read Model
→ existing READ-02 Evidence readiness

Application
→ future PA-06C Supplier Evidence & Readiness workbench

Technology
→ one PostgreSQL function replacement and rolled-back pgTAP
```

## Public contract

The public function name, `jsonb` signature, `PA-05C.v1` envelope, `dispatch_evidence_readiness.read` capability, authorization model, and advisory-only semantics are unchanged. The reviewed `atlas_api` surface remains exactly **18 functions**.

READ-02 still requires exactly one selector:

- `dispatch_trip_id`;
- `dispatch_requirement_revision_id`; or
- `wholesale_order_line_revision_id`.

The wholesale source-line selector supports both initial PA-06C load and refresh after `STALE_VERSION`.

Every existing readiness-item field remains. Each item adds:

```json
{
  "command_context": {
    "fulfilment_allocation": {
      "fulfilment_allocation_id": "uuid",
      "fulfilment_allocation_version": 2,
      "fulfilment_allocation_status": "READY_FOR_DISPATCH",
      "fulfilment_allocation_revision_id": "uuid",
      "fulfilment_allocation_revision_status": "READY_FOR_DISPATCH",
      "fulfilment_allocation_line_id": "uuid",
      "fulfilment_allocation_line_revision_id": "uuid",
      "supplier_id": "uuid",
      "ingredient_id": "uuid",
      "unit_id": "uuid",
      "allocated_quantity": 10
    },
    "purchase_commitments": [
      {
        "purchase_order_id": "uuid",
        "purchase_order_version": 3,
        "purchase_order_status": "RELEASED_TO_SUPPLIER",
        "purchase_order_revision_id": "uuid",
        "purchase_order_revision_status": "RELEASED_TO_SUPPLIER",
        "purchase_order_line_id": "uuid",
        "purchase_order_line_revision_id": "uuid",
        "supplier_id": "uuid",
        "ingredient_id": "uuid",
        "ordered_quantity": 10,
        "unit_id": "uuid",
        "service_date": "2026-07-18",
        "delivery_location_id": "uuid"
      }
    ]
  }
}
```

This is additive shaped JSON. It does not expose supplier, ingredient, customer, PO, or allocation datasets outside the selected readiness lineage.

## Stable current-lineage rules

One READ-02 invocation observes one PostgreSQL statement snapshot. The function remains `STABLE`; the selector authorization, readiness facts, root versions, current revisions, and nested lineages are derived within that bounded invocation.

### Fulfilment Allocation

For the stable allocation line behind each readiness item, the function requires exactly one lineage satisfying all of these predicates:

1. the allocation root belongs to the selected Dispatch Requirement;
2. the stable allocation line belongs to that root and the selected stable requirement line;
3. the allocation revision belongs to the root and has `is_current = true`;
4. its `revision_kind` is not `CANCELLATION`;
5. the allocation-line revision belongs to that current revision and stable allocation line;
6. its `line_status` is not `SUPERSEDED`;
7. its Dispatch Requirement line revision belongs to the same stable requirement line and requirement root.

The root's `version` and `allocation_status` are read directly. Supplier, quantity, and unit come from the current allocation-line revision; ingredient comes from its exact Dispatch Requirement line revision.

Historical allocation-line revisions remain eligible as the existing readiness rows so historical Evidence references keep their READ-02 meaning. Their nested `command_context`, however, resolves through the stable allocation line to only the current allocation revision and current line revision.

### Purchase commitments

A Purchase Order commitment is current and relevant only when:

1. its stable PO line refers to the same stable allocation line;
2. the PO root status is `RELEASED_TO_SUPPLIER` or `SUPPLIER_CONFIRMED`;
3. its PO revision has `is_current = true`, is not a cancellation, and has the same active status vocabulary;
4. the current PO line revision belongs to that current PO revision and stable PO line;
5. it refers to the exact current allocation-line revision;
6. supplier, ingredient, and unit match the current allocation lineage;
7. revision and line service dates match the selected Dispatch Requirement;
8. revision and line destinations match the selected Dispatch Requirement.

Commitments inside an item are ordered by `purchase_order_id`, current revision ID, stable line ID, and line-revision ID. Readiness items retain their existing allocation-line-revision ordering. No timestamp maximum, unordered `LIMIT 1`, or sampled join is used.

PA-05E's `purchase_order_lines_allocation_line_key` invariant assigns a stable allocation line to at most one PO. Therefore an individual item's array is currently zero-or-one. When one selected requirement line is split across multiple stable allocation portions, each readiness item returns its own matching commitment and the response preserves all such items deterministically; no commitment is collapsed. The array shape keeps empty-state handling explicit without weakening that approved invariant.

## Empty, multiple, superseded, and contradictory behavior

- Zero active current commitments return `purchase_commitments: []`; existing readiness status, blockers, and warnings are preserved.
- One active commitment returns one array element.
- Multiple legitimate commitments across split stable allocation portions return through their respective readiness items in deterministic order; none is collapsed into a sampled row.
- Cancelled and superseded allocation/PO revisions are never presented as current command context.
- A missing current allocation lineage or an active current PO lineage that contradicts the allocation, requirement date, or destination fails the whole read with `CURRENT_LINEAGE_CONFLICT` and the safe message `Current Evidence command context is internally inconsistent.` No partial `readiness_items` are returned.

## Authorization and least privilege

The function remains `SECURITY DEFINER`, owned by no-login `atlas_read_runtime`, and fixed to an empty `search_path`. SQL is static and all object references are qualified.

Existing PA-05B/PA-05C/PA-05C-H2 grants and SELECT-only forced-RLS policies already cover the exact Allocation and PO roots, revisions, lines, and line revisions. PA-05C-H3 adds no grant or policy. `atlas_read_runtime` retains no write, sequence, schema-CREATE, or command-runtime authority. `anon`, `authenticated`, and `service_role` retain no direct private-table access; only `authenticated` can execute the shaped READ-02 function.

## Stale recovery

The approved client sequence is:

```text
STALE_VERSION
→ keep the operator draft
→ refresh READ-02 with the known wholesale_order_line_revision_id
→ take the matching current root version and exact current lineage from command_context
→ require operator review
→ create a new command_id and idempotency_key
→ submit the newly reviewed command
```

The stale response's `actual_version` and READ-04 history must not substitute for this refresh. READ-02 remains advisory and does not authorize or guarantee the later write.

## Compatibility and scope

The change is backward compatible for existing clients because all previous fields and selectors remain and the contract version is unchanged. Clients that do not read `command_context` continue to consume the prior shape.

This is not discovery: a caller must possess one existing bounded selector, capability, and relational scope. It is not a queue: no work item is stored, prioritized, assigned, or mutated. It adds no frontend, command behavior, table, column, dependency, hosted access, or production data.

## Verification and Issue #109 gate

The focused pgTAP suite proves the 18-function surface, selector and response compatibility, authorization denials, exact current Allocation/PO lineages, deterministic zero/one/multiple behavior, supersession, historical Evidence visibility, safe contradiction handling, least privilege, and successful stale recovery for both guarded roots using versions sourced from READ-02.

Issue #109 remains blocked until Issue #110 is merged and its authoritative GitHub Actions validation passes. A draft PA-06C command intent must not be built from `actual_version` or audit history.

## Rollback/removal

Before deployment, rollback is a Git revert/removal of this migration and its tests/docs. If deployed later, reversal requires a reviewed forward migration that restores the prior READ-02 body and comment. No table data or schema object needs conversion because this change adds no table, column, helper, grant, policy, or public function.
