# Decision — PA-05D bounded wholesale Planning release

**Status:** Accepted; implementation pending review and merge
**Date:** 2026-07-15  
**Related contract:** `docs/architecture/pa-05d-planning-command-family-contract.md`  
**Implementation issue:** #85

## Context

PA-05B through PA-05B-H1 provide a hardened Evidence/Dispatch command spine and authorized reads, but the supplier-direct wholesale backend still relies on fixtures for the Planning, Procurement, and Dispatch-setup prerequisites.

The full Planning contracts contain generic creation, validation, approval, adjustment, reopening, invalidation, revision, and cancellation workflows. Implementing all of those before one backend vertical slice exists would add horizontal complexity that is not required for the direct-wholesale path.

The PA-04 physical schema already contains the exact wholesale source, Confirmed Need, Purchase Handoff, and Dispatch Requirement records required to preserve Planning ownership and immutable lineage.

## Decisions

1. PA-05D implements exactly four Planning commands:
   - `record_wholesale_source`
   - `release_wholesale_order`
   - `release_purchase_handoff`
   - `release_dispatch_requirement`
2. The commands use contract version `PA-05D.v1` and the existing safe Atlas command envelope.
3. `record_wholesale_source` creates one Draft wholesale order with stable lines and current Draft line revisions.
4. Direct wholesale is a pass-through Planning source. `release_wholesale_order` atomically validates, approves, and releases the order and materializes the exact Confirmed Need approval/release snapshot.
5. For this bounded path, `theoretical_quantity`, `confirmed_quantity`, and released wholesale quantity are equal.
6. The wholesale release actor is recorded as both approval and release actor. Separation of duties is deferred until a broader Planning contract explicitly requires it.
7. `release_purchase_handoff` atomically prepares, validates, and releases one handoff from one released Confirmed Need batch.
8. `release_dispatch_requirement` creates one released Planning delivery obligation from one released handoff revision.
9. Intermediate lifecycle states remain represented by validation inside the commands but are not exposed as separate PA-05D API commands.
10. Each successful command creates one command receipt, one domain event, and one audit event, consistent with the established PA-05B implementation pattern.
11. PA-05D adds `atlas_planning_command_runtime`, a no-login, no-inherit owner for only the four Planning functions.
12. Planning runtime receives no Procurement, Evidence, Dispatch, Warehouse, Storage, or legacy write privilege and no Atlas schema `CREATE` after ownership transfer.
13. No new public read API is added. Existing trace/readiness/blocker/audit reads remain unchanged.
14. Generated aggregate and line IDs remain server-owned and are returned only as allowlisted opaque IDs.
15. The implementation may add only narrow uniqueness/index constraints required to prevent duplicate source, Confirmed Need, or released-requirement creation under concurrency.

## Consequences

### Positive

- Atlas can create the Planning-owned start of the supplier-direct chain without fixture-authored Planning rows.
- The implementation remains small enough to review as one domain-owned command family.
- Planning quantity, destination, service date, and source lineage become immutable downstream inputs.
- Procurement and Dispatch remain unable to manufacture or rewrite Planning facts.
- The backend advances toward a self-authored end-to-end vertical slice without introducing UI or deployment work.

### Costs and limitations

- PA-05D is not the generic Planning workflow used for future school-catering calculations.
- It does not support manual confirmed-need adjustment, reopening, invalidation, revision, additive release, cancellation, or separation-of-duty approval.
- A later Planning task must implement those behaviors before Atlas persists equivalent school-catering workflows.
- Procurement allocation/PO and Dispatch plan/trip setup remain separate missing command families.

## Rejected alternatives

- Implement the entire generic Planning lifecycle before one backend vertical slice.
- Skip Confirmed Need and Purchase Handoff tables and write Dispatch Requirement directly from the wholesale source.
- Let Procurement create Planning release records as part of allocation.
- Add a generic workflow/status engine.
- Create one cross-domain command that writes Planning, Procurement, Evidence, and Dispatch.
- Expose private Planning tables directly to React or Retool.
- Reuse OPS v1 public functions or production records as Atlas authority.
- Connect UI or deploy to hosted Supabase in PA-05D.

## Rollback effect

Before deployment, rollback is removal/reversion of the unshipped documentation and implementation migration. If deployed later, reversal requires a reviewed forward migration that revokes execute, removes the PA-05D functions and Planning-runtime policies/grants in dependency order, and preserves any Planning history already created.

## Next gates

After PA-05D implementation and review:

1. PA-05E implements Procurement allocation and released supplier PO commands.
2. PA-05F implements Dispatch plan/trip/stop setup commands.
3. PA-05G proves a complete backend source-to-delivery acceptance path.
4. PA-06 may connect React after the backend acceptance gate under the current product-owner sequencing decision.
