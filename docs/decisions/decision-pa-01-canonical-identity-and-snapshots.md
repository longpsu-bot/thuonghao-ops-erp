# Decision — PA-01 canonical identity, snapshots, and evidence authority

**Status:** Proposed for PA-01 architecture review
**Date:** 2026-07-15
**Contract:** `docs/architecture/pa-01-atlas-persistence-contract.md`

## Context

The approved Atlas contracts and in-memory prototypes prove the Planning, Procurement, Warehouse, and Dispatch ownership model, but their fixture identifiers and local state arrays are not a production persistence contract. The MVP vertical-slice review found that independent modules do not yet share canonical identifiers. The morning chaos simulation also proved that post-release Planning changes, Procurement allocation revisions, partial physical evidence, concurrent trips, and destination returns must remain explicit without silently rewriting history.

No PostgreSQL schema, migration, authorization policy, or backend command should be designed until those identity and snapshot rules are agreed.

## Decision

1. **Define canonical identity before migrations.** Every aggregate, operational line, immutable revision/snapshot, evidence record/application, command, and event receives an opaque immutable canonical ID. Business dimensions, document numbers, trace codes, and legacy IDs are attributes or scoped references, not primary identity.
2. **Preserve released operational snapshots.** Downstream released work stores canonical upstream references and immutable snapshots of the facts needed to execute and explain the commitment, including quantity, unit, item description, destination, supplier/allocation decision, rule/version, and release actor/time.
3. **Use explicit correction paths.** Pre-release correction updates a versioned draft with audit. Post-release change creates a revision, additive delta, cancellation, reversal, or compensating record. It never overwrites the released snapshot. The School 05 late `+4 kg` case is an additive linked Planning release; the original `10 kg` remains unchanged.
4. **Keep read models derived and non-authoritative.** Control Board, workbenches, attention queues, readiness, lateness, reconciliation, and operating-day trace are reproducible from domain-owned facts. React does not own hidden operational state or safety gates.
5. **Keep physical evidence source-owned.** Procurement allocates fulfilment but does not manufacture supplier, cross-dock, Warehouse, delivery, or return evidence. Evidence is append-only and corrections supersede or void with reason. Quantity applications link evidence to exact allocation-line revisions and prevent double counting.
6. **Require sufficient evidence before departure.** Dispatch departure is authoritative only when every loaded requirement portion has valid source-owned evidence whose applied quantity is sufficient for the allocated and loaded quantity. A record's existence is not enough.
7. **Require separate production-migration approval.** PA-01 authorizes documentation only. Schema, migrations, RLS, RPCs, Edge Functions, backend integration, legacy extraction, data copy, dual write, cutover, and production changes require separately approved work.

## Consequences

- PA-02 can map explicit aggregates and cross-domain line identities instead of copying fixture keys or OPS v1 composite keys.
- Released Planning, PO, receipt, stock, Warehouse release, Dispatch, and delivery history remains interpretable after master-data or upstream corrections.
- Independent Dispatch trips can progress concurrently without sharing one aggregate lock.
- Evidence readiness can be calculated per allocation portion without reusing one physical quantity twice.
- Read models may evolve without becoming a second write path.
- Additional storage is required for immutable snapshots, revisions, evidence applications, idempotency records, and audit events.
- UUID version, physical namespace, status constraint strategy, document numbering, evidence-file storage, transaction isolation, precision, and migration mapping remain PA-02 decisions within this contract's boundaries.

## Rejected alternatives

- Reusing composite date/school/dish/ingredient keys as operational identity.
- Treating fixture or legacy IDs as Atlas primary keys.
- Updating released documents in place after upstream change.
- Persisting workbench action flags or attention ownership as authoritative workflow state.
- Letting Procurement or Dispatch create another source's physical evidence.
- Allowing departure because an evidence row exists while its valid applied quantity is insufficient.
- Copying Retool state, UI logic, or current OPS v1 schema shapes into the target architecture.

## Implementation boundary

This decision creates no database object, API, authorization behavior, file storage, backend integration, production-data mutation, or migration. The first implementation authority remains a separately reviewed PA-02 schema and security design.
