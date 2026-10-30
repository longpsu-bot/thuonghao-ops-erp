# Change Order live temporal labels — 30 October 2026

## Scope and authorization

The Owner approved fixing stale Change Order temporal labels without a page
reload, followed by verification on Atlas Staging in Google Chrome. Reuse the
existing THUẬN GIAO / TRỊNH HOÀI ĐỨC rehearsal and its finite 20 October rule.
No additional business issuance is needed for this presentation/read repair.

Canonical checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`; clean `main` at
`249f7ae37b744b02c800446441aa60dc5c59d3d0`, matching fetched `origin/main`.
Branch: `codex/change-order-live-date`. The workspace script's historical
D-drive warning does not supersede the Owner-authorized E-drive checkout.

Allowed scope: the Change Order registry wiring, controller, focused controller
and owner integration tests, this record and the current-date API clarification.
No status derivation in React, API/schema/migration/RLS change, new dependency,
historical BOM or quantity change, operational regeneration, Production, OPS v1,
Retool or Warehouse work.

## Diagnosis

The normal owner always passes its retained workspace `seed` as `initialDate`.
The controller uses that value for ledger reads and explicitly disables its
existing Vietnam-midnight timer whenever it is supplied. A long-lived workspace
therefore reads an obsolete explicit date, despite the approved current-date
ledger contract. Separately, a successful daily read refreshes `data` but leaves
the selected detail holding the previous row object and its old temporal flags
and action ceilings.

The repair must keep operational workbench date ownership unchanged. Normal
Change Order reads use the current Vietnam-local date; backend responses continue
to own `temporal_state`, `is_effective_now` and action eligibility. Clean active
owners refresh through the existing 30-second day check. Hidden-owner activation
does not itself issue a read. Dirty drafts, frozen reviews, cancellation work,
pending writes and UNKNOWN locks retain their existing protections.

## Acceptance and checks

- A retained old workspace seed cannot control the normal ledger's read date.
- On a Vietnam-local day transition, a clean active owner adopts the refreshed
  backend row in both its directory and selected detail without page reload.
- Updated action permissions come from that row; no business command is issued
  by time refresh. Existing guarded work is retained and requires explicit
  recovery when the day changes.
- Focused tests include stale-seed integration and selected-detail midnight
  refresh, plus existing dirty/review/cancel/hidden/UNKNOWN/session guards.
- Required latest-head Frontend CI and independent product/architecture review
  pass before merge. Verify automatic frontend publication and the existing
  finite rule in hosted Chrome, retaining the two-School scope and frozen
  PO/PXK evidence.

Red checks reproduced both causes: the normal owner requests the retained
12 September date even when the current Vietnam date is 13 September; separately,
backend data becomes EXPIRED while `selected.temporal_state` stays ACTIVE.
The initial two-file green run passed all 45 tests. An added pending-inspection
case then reproduced a retained loading flag when the day changed during a BOM
read; resetting that flag accompanies invalidation of the old request.

The final regression covers completed and in-flight effective inspection:
the selected backend state, effectiveness and cancellation ceiling update,
the previous day's result clears, late results cannot restore it and no business
command is issued.

Final local checks: all 75 tests pass across `useChangeOrderWorkbench`,
`AtlasOperatorOwners`, `AtlasVNextApp` and `AtlasPersistentWorkspace`, using
Vitest's `vmThreads` pool with one worker on this Windows host. Formatting and
`git diff --check` pass. Independent read-only product/architecture review found
no critical or important issues. The existing 294-row downstream fingerprint
also matches the preceding rehearsal before frontend publication. Latest-head
CI, merge/publication and hosted Chrome results remain the release gates.

## Rollback and limits

Frontend-only revert restores prior registry/controller behavior. There is no
database migration or business-data rollback. Historical effect dates and the
already issued immutable rule are not edited. Simulated midnight tests provide
deterministic rollover evidence; hosted checks must clearly distinguish actual
Chrome observations from simulated-clock tests.
