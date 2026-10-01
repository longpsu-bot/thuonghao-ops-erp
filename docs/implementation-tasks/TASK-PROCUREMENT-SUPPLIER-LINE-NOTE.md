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

## Post-#342 migration-order stabilization

PR #341 was rebased onto `origin/main` at
`4ad1740203a7dc7a767a4eaec02cb3b847cb8b94` without conflicts. The supplier-note
migration is now `20261001094403_procurement_supplier_line_note.sql`, after
`20261001081941_menu_slot_dish_decoupling.sql`. The obsolete earlier filename
is removed; there is exactly one supplier-note migration. Its SQL content is
byte-identical to the reviewed PR #341 migration (Git blob
`0e041123c0f65a7b132f88ede2aeb2288a92f07a`). No Planning code, business contract,
runtime privilege, or supplier-note behavior changes in this stabilization.

Validate a fresh local migration replay in this order, supplier-note and related
Procurement pgTAP, the local school-catering Procurement verifier, focused
Procurement frontend and XLSX/PDF tests, UI boundary, typecheck, targeted
Prettier, whitespace and workspace checks. Frontend CI and Supabase Smoke must
pass on the updated Draft PR before the owner merge gate.

Hosted deployment remains a separate phase after the owner merges #341.
Neither migration is deployed by this stabilization; hosted Staging, Retool,
and live OPS writes remain zero. Do not deploy #342 alone while #341 remains
unmerged. Rollback and historical-null behavior above are unchanged.

Local stabilization results (2026-10-01): fresh migration replay passed;
supplier-note/allocation/PO pgTAP passed 201 assertions on a clean database;
purchase-review pgTAP passed 147 assertions through the repository include-expanding
runner; the authenticated local Procurement verifier passed; 14 Procurement
frontend/export files passed 220 tests; UI boundary, typecheck, targeted Prettier
and whitespace checks passed. Run the rolled-back pgTAP suites before the
authenticated verifier, which leaves synthetic local fixture data. Direct CLI
execution of the purchase-review suite cannot mount its `../local` includes;
use `node scripts/test-local-purchase-review.mjs purchase_review_confirm_release.sql`.
The authority-map's existing table formatting is outside this stabilization's
targeted formatting scope. Workspace verification passed with the historical
D: path warning; the owner explicitly authorized this E: checkout.
