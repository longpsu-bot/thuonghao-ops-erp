# MVP Morning Chaos Simulation Review

## Purpose

This review stress-tests the approved MVP operating model across a synthetic 02:00–08:00 morning. It checks whether existing Planning, Procurement, supplier/warehouse evidence, Dispatch, exception, and return concepts remain coherent when changes and shortages overlap.

The accompanying Atlas page `mvp-operations-simulation` is a fixture-backed, read-only review surface. It introduces no command, persistence, business ownership, or production-data behavior.

## Simulation assumptions

- Service date: 15 July 2026.
- Resources: 10 schools, 2 wholesale customers, 4 suppliers, 1 warehouse, and 3 independently operated trips.
- The fixture contains 13 requirements and 31 requirement lines.
- Released source references and quantities are immutable. A late change creates a distinct Planning release and requirement linked to the original.
- Procurement may revise fulfilment allocation while preserving the original requirement quantity.
- Supplier fulfilment evidence and Warehouse Stock Release evidence are both valid physical-evidence types. Warehouse evidence is not mandatory for supplier-direct fulfilment.
- The simulation is deterministic and in-memory. It does not represent production concurrency, persistence, RLS, or integration behavior.

## 02:00–08:00 timeline

| Time | Event | Existing owner |
| --- | --- | --- |
| 02:00 | Released Planning requirements enter the operating view | Planning |
| 02:20 | Procurement allocations cover school and wholesale demand | Procurement |
| 03:05 | School 05 adds 4 kg after the original 10 kg release | Planning |
| 03:20 | A linked revision release and requirement are recorded | Planning |
| 03:35 | Supplier shortage affects School 10 line 2 | Procurement |
| 03:50 | Allocation is revised to 12 kg supplier-direct and 8 kg warehouse fallback | Procurement |
| 04:10 | Supplier evidence covers 12 kg; Warehouse release evidence covers only 5 kg | Supplier receiving / Warehouse |
| 04:20–04:22 | Trips A and B are prepared independently and concurrently | Dispatch |
| 05:00 | Trip A departs on plan | Dispatch |
| 05:42 | Trip B departs 32 minutes late | Dispatch |
| 06:35 | School 06 rejects 4 kg; exception and return evidence are recorded | Destination follow-up / Dispatch |
| 07:15 | Trip C remains loaded but cannot depart with School 10 line 2 uncovered | Dispatch |
| 08:00 | Review closes with 3 kg still lacking physical fulfilment evidence | Procurement |

## Disruptions and expected ownership response

### Late School 05 change

Planning preserves the original requirement and records a separate, linked release for the additional 4 kg. Procurement fulfils the added requirement through the normal allocation path. Dispatch consumes both released requirements without rewriting either.

### School 10 supplier shortage and warehouse fallback

Procurement records the allocation revision. The supplier proves 12 kg; Warehouse controls and proves its 5 kg physical release against the planned 8 kg fallback. The remaining 3 kg stays visible and Procurement owns the next fulfilment decision. Dispatch does not invent stock or alter allocation.

### Concurrent trip preparation

Trips A and B retain separate plans, vehicles, stops, loads, departure timestamps, and outcomes. Trip B's 32-minute delay does not mutate Trip A.

### Destination rejection and return

School 06 rejects 4 kg. Dispatch records destination exception and return evidence; the requirement quantity, procurement allocation, and Warehouse evidence remain unchanged. The return resolves the Dispatch closure condition without resolving upstream facts on another owner's behalf.

## Observed behavior

- Immutable source trace remains available from demand source through Planning release, Confirmed Need, Purchase Handoff, fulfilment allocation, evidence, trip, and destination outcome.
- Supplier-direct and warehouse-backed fulfilment can coexist on one requirement line.
- Evidence readiness is line-specific and does not become ready when only part of an allocation has evidence.
- Trips progress independently, and lateness is derived from planned and actual departure timestamps.
- Attention can be grouped for Planning, Procurement, supplier receiving, Warehouse, Dispatch, and destination follow-up without transferring ownership to the review page.
- At 08:00, Trip C and the 3 kg shortage remain explicitly unresolved.

## Object sufficiency

The existing core objects are sufficient for this MVP simulation: released Planning requirement/source trace, Procurement fulfilment allocation, physical fulfilment evidence, Dispatch plan/trip/load/stop, delivery confirmation, delivery exception, and return evidence.

No new core workflow object or business owner is justified by the fixture. The timeline, lateness, owner grouping, and end-of-window state are derived review concepts.

## Clarification required before persistence

The current in-memory read model correctly identifies a partially evidenced allocation as not ready. The command boundary should be made equally explicit before authoritative persistence: departure must not become possible merely because every allocation portion has some evidence when the total evidenced quantity is still below the allocated or required quantity. This is a command-validation clarification, not an ownership contradiction.

Canonical persisted identifiers and audit linkage for Planning revisions and Procurement allocation revisions also remain future implementation concerns. The fixture uses explicit references to prove the required trace shape.

## Genuinely missing concept

None for the bounded MVP review. Production-grade concurrency, idempotency, persisted audit history, supplier evidence capture, and access control remain implementation work under their approved domain boundaries; they are not new business concepts introduced by this simulation.

## Operator-attention findings

- Operators need one read-only view that keeps source trace, evidence readiness, trip state, and outcome together.
- Open and resolved attention should remain distinguishable.
- The next owner must be derived from the unresolved fact, not assigned by Dispatch or by the review page.
- A shortage must display both allocated and evidenced quantities so a partial fallback cannot appear complete.
- Planned and actual departure times must remain visible together.

## Unresolved state at 08:00

`DR-S10-L2` requires 20 kg. Supplier evidence proves 12 kg and Warehouse Stock Release evidence proves 5 kg, leaving 3 kg uncovered. Trip C is loaded but has not departed. Procurement owns the next fulfilment decision; Warehouse may only release stock it actually controls, and Dispatch remains blocked from treating the line as ready.

## Risks

- Fixture behavior does not prove database transaction or concurrent-update safety.
- Manually constructed fixture snapshots can drift from future command rules unless kept under test.
- A future UI could accidentally imply ownership transfer if owner labels are treated as editable assignments.
- The command/read-model readiness clarification must be resolved before persistence work.

## Recommendation

Accept the morning simulation as a coherent MVP review baseline and mark the roadmap item complete. Preserve the page as fixture-backed and read-only. Carry the departure/readiness validation clarification into the future authoritative command implementation without changing current domain boundaries.

## Migration and rollback

No database migration, production data change, API change, or rollback procedure is required. Rollback is removal of the fixture, read model, Atlas page registration, tests, and this review document.
