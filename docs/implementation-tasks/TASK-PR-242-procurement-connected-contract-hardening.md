# PR #242 — Procurement connected-contract hardening

**Status:** Implemented on Draft branch

**Decisions:** D-037, D-042

**Contracts:** `RMVP-07.v2`, `SCHOOL-CATERING-HANDOFF.v1`, `SCHOOL-CATERING-PROCUREMENT.v1`

## Outcome

The Confirmed Need v2 eligibility helper and Release command now distinguish active Purchase Handoffs from retained D-042 correction history. `INVALIDATED` and `REOPENED` Handoff roots no longer produce `PURCHASE_HANDOFF_CONFLICT`; corrected Planning release can therefore complete and the existing school-catering Handoff command reuses the same root with a `SUPERSEDING` revision. Active wholesale Handoffs and released school-catering supplier POs retain their existing blockers.

The two school-catering Procurement reads now serialize precision-sensitive quantities and ratios as fixed-scale decimal strings. The change is applied only to public response envelopes, after the existing backend read implementations have completed, so Allocation Family fingerprints and all authoritative PostgreSQL numeric calculations remain unchanged.

## Security

No table, role, capability, scope kind, browser table grant, or public API is added. The existing two shaped reads remain owned by `atlas_read_runtime`, callable only by `authenticated`, and inaccessible to `anon` and `service_role`. Their prior implementations become private compatibility functions in `atlas_core`; direct execution is revoked from browser roles. Confirmed Need functions retain `atlas_confirmed_need_review_runtime`, fixed empty search paths, and their existing authorization and RLS boundaries.

## Verification

- `school_catering_handoff_allocation.sql` verifies exact string quantities and ratios at unallocated, recommended, and persisted-allocation read paths.
- `school_catering_purchase_orders.sql` compares every string `ordered_quantity` with its authoritative PostgreSQL value.
- `d037_confirmed_need_save_release_boundary.sql` exercises the public corrected Planning release and public Handoff release against one retained invalidated root, then proves one current `SUPERSEDING` revision.
- `school_catering_planning_correction.sql` retains the DRAFT-PO stale behavior, wholesale blocker, and released school-catering PO blocker.

## Migration and rollback

Migration `20260901181519_procurement_connected_contract_hardening.sql` replaces two existing function bodies, preserves their owners and grants, privately relocates the two prior read implementations, and installs one recursive response shaper. It creates or rewrites no business row.

Before hosted use, rollback is a normal code/migration rollback that restores the preceding function definitions and public read functions. After corrected releases or Handoff revisions are created, their receipts, validation/approval/release evidence, Handoff revision lineage, events, and audit records are authoritative history and must not be deleted.

## Exclusions

PR #241 UI changes, recommendation labels, action hierarchy, UI Review Export, Retool, live OPS, production data, Warehouse, Dispatch, Finance, and released-PO correction remain outside this task.
