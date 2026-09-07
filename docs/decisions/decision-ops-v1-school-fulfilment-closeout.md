# Decision D-044 — School Fulfilment Closeout

**Status:** Accepted

**Date:** 2026-09-07

**Authority:** Product Owner-approved OPS v1 replacement boundary

**Implementation:**
[OPS-V1-SCHOOL-FULFILMENT-CLOSEOUT-01](../implementation-tasks/TASK-OPS-V1-SCHOOL-FULFILMENT-CLOSEOUT-01.md)

## Decision

Atlas closes the minimum School fulfilment path through one shared operational
recipient and explicit immutable commitments:

```text
School direct and/or Recipe-derived Need
→ Confirmed Need
→ explicitly saved supplier allocation
→ explicitly released supplier PO
→ explicitly released School/date/location Phiếu xuất kho
```

School is the operational recipient for both catering and direct/wholesale Need.
Historical customer identifiers remain compatibility references derived and checked
from School; they are not a second operator choice.

## Direct Ingredient Need

The existing Pantry aggregate remains the common direct-Ingredient source. Purpose
explains why a line is direct. Composition authority is one closed
`ADDITIVE | COMPLETE` fact per Pantry batch, School, and service date:

- `ADDITIVE` composes `RECIPE_DERIVED + PANTRY_DIRECT`;
- `COMPLETE` uses `PANTRY_DIRECT` alone and requires no Menu, Attendance, or Recipe.

This grain prevents contradictory line modes and permits one batch and one School to
use different modes on different dates. Historical missing mode is interpreted as
`ADDITIVE`; immutable historical evidence is not rewritten.

## Correction and supplier commitment

A downstream commitment freezes its own snapshot, not upstream reality. Legitimate
Confirmed Need correction appends successor facts even after a School-catering PO or
PXK is released. Exact contribution membership and fingerprints derive allocation,
PO, and PXK currentness; a new allocation remains an explicit Save.

A positive affected supplier/date receives a complete replacement PO root with
direct predecessor lineage. The old released PO remains current while the
replacement is Draft. Explicit replacement release assigns a new number and
atomically supersedes the predecessor; neither document is rewritten.

If a supplier becomes zero, Atlas derives `CANCELLATION_REQUIRED`, leaves the old PO
released and active, creates no zero-line document, makes Procurement not current,
and blocks PXK. No cancellation command is authorized by this decision.

## School PXK

PXK preview is derived and read-only. Explicit release at
`service_date + school_id + delivery_location_id` creates an immutable official
header, lines, display snapshots, and exact Confirmed Need/allocation/PO lineage.
After correction, explicit successor release creates a new number and only then
supersedes the previous PXK. Released and superseded PXKs remain exportable.

PXK readiness requires current Confirmed Need, explicitly saved current allocation,
and complete current released PO coverage. It does not require receiving, stock,
lots, balances, reservations, picking, cross-dock, DispatchPlan, trip, vehicle,
driver, or load evidence.

## Consequences

- Normal new direct/wholesale Application behavior converges on School Direct Need.
- Historical wholesale and DispatchPlan/Trip APIs remain callable for compatibility.
- New PXK tables are private, forced-RLS relations; browser access is only through
  bounded read/release APIs and capabilities.
- Rollback is forward-only: disable entry points while preserving immutable release
  evidence.
- This decision authorizes no stock management, supplier-cancellation execution,
  hosted deployment, or live/Retool mutation.
