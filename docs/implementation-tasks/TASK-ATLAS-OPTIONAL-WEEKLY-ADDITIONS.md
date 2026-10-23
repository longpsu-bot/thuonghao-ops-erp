# Optional weekly additions — 23 October 2026

**Status:** Owner-approved policy amendment; implemented and independently reviewed;
GitHub validation pending.

The Owner rejected a recurring “nothing to add” confirmation and explicitly
requested implementation. For daily Need, an untouched Pantry week means no
optional additions. There is no weekly confirmation, empty Save, fabricated
approval, placeholder line or implicit clearing of an existing source.

This supersedes PANTRY-02's mandatory explicit-zero rule only for a daily period
with no overlapping Pantry batch of any status. Existing batches retain their
complete transactional Save, exact approval bindings and correction safeguards.
Historical multi-day readiness and unmarked pre-Pantry null bindings retain
their existing behavior. Recipe Need still requires current Menu and Attendance.

## Implementation boundary

- `planning_input_evaluations.pantry_absent` is immutable backend evidence,
  defaulting false for historical rows. Only READY daily evaluations with exact
  Menu/Attendance bindings, a wholly null Pantry triple and verified absence
  may set it. No request may author this flag.
- The existing evaluator retains exact warning rows, receipts and audit events.
  Snapshot integrity retains null-safe binding equality. Live readiness and
  freshness separately recheck absence; a later addition makes old Need outdated.
- All first-Pantry-creation and Need entry points use a shared week lock before
  checking absence or consequential source impact. Existing authentication,
  capabilities, RLS, optimistic concurrency and idempotency remain intact.
- Reads add `source_evidence.pantry.optional_absent`; history distinguishes
  `OPTIONAL_ABSENT` from non-authorizing `PRE_PANTRY_NULL_BINDING`.
- The active vnext workbench removes the weekly checkbox and bulk-clear
  transition. Removing saved rows is reviewed and saved explicitly. An empty
  replacement retains the existing technical `no_additions_confirmed=true`
  payload and immutable zero snapshot. Adding after saved zero works normally.
- An untouched empty draft stays clean. An existing unfinished empty batch can
  still be completed through review and Save; it cannot silently become absent.
- Public v1–v4 Pantry payloads remain compatible. The legacy reference authoring
  workbench is unchanged; it no longer represents a mandatory daily Need step.

## Scope and validation

One forward migration, active Planning UI/controller, readiness labels, affected
tests/fixtures and this contract amendment. No Recipe arithmetic, quantities,
Purpose identities, module boundaries, statuses, permissions, released document
content, dependency, hosted data or deployment changes.

Focused SQL coverage includes absence generation, exact retry, unchanged intent,
immutable lineage, warnings, no-source blocking, historical-null rejection,
later-addition freshness and unfinished-source blocking. Existing Pantry,
readiness, generation, correction and whole-platform security suites remain
required, together with frontend tests, desktop fixture inspection and CI.

Local evidence: all main migrations plus the exact forward migration install in
a fresh disposable database. The 29 new assertions and 716 affected existing SQL
assertions pass, including exact whole-platform security fingerprints. The 121
focused frontend tests, typecheck, formatting and Vietnamese copy validation pass.
Independent review's two first-source correction gaps were reproduced and fixed:
impact covers all absence-based dates in the week, and legacy first-root creation
delegates to the existing full correction enforcer. Desktop review confirms
removal still displays its prior saved quantity and requires Save.
Three disposable two-session races pass: Need then Save, Save then Need, and Need
then legacy draft creation. Both commands wait on the shared week lock and retain
the correct source/absence binding after execution. These use local synthetic
fixtures; no hosted business writes were performed.

Rollback must preserve new absence-based evidence: revert UI behavior and use a
reviewed forward migration after assessing affected runs. Do not delete, backfill
or reinterpret immutable evaluations or operational documents.
