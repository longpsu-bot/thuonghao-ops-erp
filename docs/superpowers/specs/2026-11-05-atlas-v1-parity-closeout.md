# Atlas v1 parity closeout

Owner instruction, 5 November 2026: execute the identified parity work except
supplier commitment/PO cancellation. This explicitly supersedes the earlier
task-only sequencing for the capabilities below. Warehouse remains paused.

## Scope and decisions

1. Release the reviewed source-history archive and import surviving OPS v1
   Change Orders into Atlas Staging through an exact-main, preview-first guarded
   runner. Keep source read-only, retain inactive rows and unknown attribution,
   preserve native adjustments, immutable operational facts and replay evidence.
2. Compare mapped effective Recipe output with read-only OPS v1 evidence for
   explicit School/Dish/type/date contexts. Report missing references, quantity,
   Unit and composition differences; never silently activate archive rows.
3. Finish the existing eight-Ingredient-name forward-correction package after
   compatibility review, fresh preview and exact-plan apply. Recipe3529 and
   unavailable address/group evidence require factual confirmation; retain
   blockers rather than inventing data or addresses from free text.
4. Add Monday-Friday School attendance defaults, with current School defaults
   as fallback. Existing explicit saved attendance, including zero, wins. Use
   existing governed School commands, capabilities, optimistic concurrency and
   attendance proposal/save flow; no business lifecycle changes.
5. Expose Attendance XLSX authoring through existing parser/backend Preview and
   Save. Extend Shopping List multi-day operator access only through independent
   daily authoritative contexts; never introduce a new multi-day Need root,
   partial hidden Save, cross-day quantity mixing or bulk PO release.
6. Prepare a bounded staff pilot with named scope, prerequisites and acceptance
   evidence. Real staff participation and factual kitchen answers are pending
   user information, not fabricated test outcomes. No messages to staff or
   suppliers, real supplier commitments or Production cutover.

## Release boundaries

Canonical checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`. Use bounded branches
from latest main and normal review/CI; exact-source Staging deployment and data
apply may follow successful review and checks within this instruction. Preserve
unrelated open PRs and all historical releases. No new dependencies, domain
boundaries, supplier cancellation, Warehouse, direct OPS v1 writes or Production
data/schema edits. Frontend coordinates; PostgreSQL remains authoritative.

## Acceptance

Each feature has focused tests and independent review, then exact-head CI before
integration. Hosted archive apply reconciles counts/checksum, proves identical
replay and unchanged native/operational facts. Effective BOM comparison accounts
for every selected context and retains genuine deltas. Weekday defaults validate
closed weekdays and nonnegative integers, preserve zero and fallback, and never
rewrite approved attendance. XLSX import retains unknown-reference and malformed
file blockers, dirty-state/version/UNKNOWN guards and explicit Save. Multi-day
navigation preserves each day's identity, draft and release boundaries. Pilot
completion requires actual staff acceptance; automated rehearsal alone is not a
completed pilot. Record merged/deployed/applied/accepted states separately.
