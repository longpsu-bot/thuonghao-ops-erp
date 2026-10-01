# PROCUREMENT-SUPPLIER-LINE-NOTE-01

## Scope and authority

Add one optional supplier-facing instruction to each exact supplier allocation
split and carry it into the supplier Purchase Order. The approved
[Procurement API contract](../api/school-catering-procurement.md) and
[authority map](../architecture/atlas-authority-map-through-procurement.md)
remain the governing context. This task does not add a lifecycle, module,
capability, role, generic note service, or separate Save action.

**KEEP EXPLICIT:** `supplier_note` on the immutable supplier split is part of
the human allocation decision. **DERIVE:** exact split lineage determines
whether a PO Draft is stale after a note-only successor. **GENERATE:** the PO
line's `supplier_note_snapshot` is frozen from its exact split by the backend.
No persisted `has_note` state is introduced.

## Contract

- Existing `CONFIRMED-SUPPLIER-ALLOCATION.v1` and
  `SCHOOL-CATERING-PROCUREMENT.v1` requests remain callable. Each split may omit
  `supplier_note`, supply `null`, or supply a string. Omission means `null`.
- The backend trims surrounding whitespace, stores blank as `null`, preserves
  useful internal spaces and line breaks, and rejects values over 500 characters
  without truncation or partial writes.
- A note-only Save creates an immutable allocation successor. Recommendation
  candidates start blank. Applying a proposal retains the current note for any
  supplier still present, starts a new supplier blank, and removes the note with
  a removed supplier.
- Confirmed Need to Handoff promotion copies the note exactly. PO Draft,
  regeneration, release and replacement paths copy it through the exact split
  reference. Released and superseded snapshots are never recalculated.
- Allocation and PO shaped reads expose the note. Official supplier XLSX/PDF
  display the PO line snapshot; preliminary generated review is unchanged.

## Boundaries and verification

One additive migration adds nullable split and PO line text columns and bounded
checks, and updates only the affected writers, promotion, shaped reads and PO
line freeze guard. Historical rows stay null. Browser roles retain shaped API
access only; forced RLS and runtime ownership/search paths remain in place.
No hosted Staging, Retool, OPS v1 or hosted business data is written by this task.

Focused validation covers compatibility, normalization, note-only successors,
idempotency, promotion, PO currentness, immutable released history, replacement,
UI Save/readback, official exports, local Supabase integration, typecheck and
the Atlas UI boundary. Frontend CI is the PR validation gate.

Rollback after use must preserve accepted split notes and issued PO snapshots.
The UI/command extension can be disabled with a forward change, but dropping
the columns would lose historical business facts and is not a safe rollback.
