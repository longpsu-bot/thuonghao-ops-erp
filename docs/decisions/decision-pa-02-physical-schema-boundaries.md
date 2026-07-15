# Decision — PA-02 physical schema boundaries

**Status:** Proposed for PA-02 architecture review

**Date:** 2026-07-15
**Contract:** `docs/architecture/pa-02-physical-schema-and-constraint-design.md`

## Context

PA-01 established canonical identity, immutable released facts, explicit revision and compensation, source-owned physical evidence, quantity applications, transactional commands, derived read models, and a legacy boundary. Atlas now needs a reviewed physical PostgreSQL direction before a migration, RLS policy, RPC, generated database type, or backend/client integration is safe to create.

The current TypeScript domains and fixtures prove the required vocabulary and operator decisions, but their arrays, fixture IDs, embedded histories, and action flags are not database tables. OPS v1 and Retool remain legacy evidence and must not dictate the target schema.

## Decision

1. **Use explicit Atlas namespaces.** The target direction is `atlas_core`, `atlas_admin`, `atlas_planning`, `atlas_procurement`, `atlas_evidence`, `atlas_warehouse`, `atlas_dispatch`, `atlas_audit`, `atlas_reporting`, and `atlas_legacy`. Domain tables are private by default. The dedicated evidence namespace prevents supplier receiving/cross-dock evidence from appearing Procurement-owned; only the authorized physical-source command may create it.
2. **Use opaque database-generated UUIDs.** Canonical primary keys use PostgreSQL `uuid`. The first migration recommendation is database-generated UUIDv4 through `gen_random_uuid()` because it is supported by the current Supabase/PostgreSQL baseline without a new extension. IDs carry no chronology or business meaning. A future UUIDv7 change requires a supported generator and separate ADR; it must not change identity semantics.
3. **Use domain-local status constraints.** Most fixed lifecycle values use `text` with named `check` constraints. Operator-managed/effective-dated vocabularies use reference tables. Atlas will not create one PostgreSQL enum shared across domains or one generic workflow/status engine.
4. **Use exact typed physical facts.** Operational quantities use `numeric(20,6)` with explicit unit FKs; conversion factors use `numeric(24,12)`; instants use `timestamptz`; the Asia/Bangkok operating day uses a separate `service_date date`. Binary floating point is prohibited for authoritative quantities.
5. **Preserve the line and revision spine physically.** Stable line IDs connect Planning source through theoretical need, Confirmed Need, Purchase Handoff, Dispatch Requirement, Fulfilment Allocation, PO/warehouse request, evidence application, Dispatch load, and destination outcome. Exact released line-revision IDs are carried where execution depends on a snapshot. Typed bridges replace weak `source_type/source_id` pairs where the targets are known.
6. **Make evidence application mandatory.** A valid evidence row is not enough. An immutable `atlas_evidence.evidence_applications` row must apply a positive quantity from one source-owned evidence fact to one exact fulfilment-allocation-line revision. Transactional command logic prevents evidence over-application, duplicate application, implicit movement after reallocation, and load/departure against insufficient or voided evidence.
7. **Keep read models derived.** Control Board, workbenches, attention queues, evidence readiness, stock availability, operating-day trace, and diagnostics are views or typed read RPCs over authoritative facts. They are not writable workflow tables. Safety-critical stock, departure, and exception gates never depend on a stale materialized view or React state.
8. **Sequence connected implementation by risk.** The first connected schema slice is one supplier-direct wholesale ingredient line through Planning approval/release, Purchase Handoff, fulfilment allocation, PO, supplier receiving evidence/application, Dispatch load, and delivery. Warehouse stock is the second bounded slice and adds reservation, pick, custody release, evidence application, and atomic stock movement.
9. **Do not migrate yet.** PA-02 is documentation only. No migration or SQL object is authorized until PA-02 is reviewed and approved and the open gates—numbering, rounding, service date, file metadata/storage, idempotency, locking, RLS exposure, migration inventory, and exact first-slice scope—are resolved.

## Consequences

- Domain ownership is visible in schema and grant boundaries instead of depending on UI convention.
- Supplier physical evidence cannot be mistaken for Procurement commercial confirmation or Warehouse stock.
- Stable roots and lines remain queryable while immutable revisions explain exactly what downstream actors used.
- Evidence quantity can be reconciled and protected from double counting across allocations and loads.
- Released Planning, PO, receipt, stock, load, and destination history cannot be silently recalculated from current master data.
- More tables and joins are required than in the in-memory prototypes; typed views/RPCs hide that complexity from operator screens.
- UUIDv4 may have less B-tree locality than a supported UUIDv7 implementation, but it avoids an unapproved extension/runtime dependency. Index and table growth must be measured before changing the strategy.
- RLS, grants, function security, command authorization, idempotency retention, and exact isolation remain the next design gate rather than being improvised inside the first migration.

## Rejected alternatives

- Using `ops3_*`, OPS v1 table names, or Retool page/query state as the target schema.
- Encoding date, school, ingredient, document number, or trace code in a primary key.
- Reusing composite business keys as cross-domain operational identity.
- Using a generic polymorphic `source_type/source_id` for links that can have typed FKs.
- Updating released rows/snapshots in place.
- Treating supplier confirmation as physical receiving evidence.
- Letting Procurement or Dispatch create another source's physical evidence.
- Treating one evidence row as sufficient without a quantity application to an exact allocation revision.
- Persisting `readyToLoad`, `canApprove`, attention owner, or other workbench flags as authoritative state.
- Making Warehouse release mandatory for supplier-direct fulfilment.
- Letting Dispatch return evidence create Warehouse stock re-entry.
- Creating a shared generic workflow engine or universal status table.
- Exposing domain tables directly to React or placing a service-role credential in the client.

## Next gate

After PA-02 approval, PA-03 should define authorization capabilities, RLS/grants, exposed schemas, security-invoker views, command execution privileges, integration/emergency access, audit visibility, idempotency behavior, locking/isolation, structured errors, and security tests. PA-03 remains a design task unless a separate instruction explicitly authorizes migrations.

## Implementation boundary

This decision creates no database object, migration, SQL file, RLS policy, RPC, Edge Function, generated type, Supabase client, backend integration, credential, production-data change, legacy extraction, Retool change, React behavior, fixture behavior, or runtime command. Documentation rollback is a normal Git revert.
