# Issue #222 — Closed-loop Planning source corrections

**Status:** Implemented on stacked Draft branch
**Decision:** D-042
**Parent:** Issue #223 / D-041 daily Need authority
**Contract:** `PLANNING-CORRECTION.v1`

## Outcome

Weekly Menu, Attendance, and Pantry now use the same backend-owned correction loop. Proposed consequential-Save facts are canonicalized and compared with the current approved facts. Only dates with a material Menu assignment, School portion, or approved direct Pantry fact difference enter the impact model; notes and source references do not manufacture downstream impact.

Each affected date is classified as `SAFE_NOT_GENERATED`, `SAFE_REGENERATE`, `PLANNING_RELEASE_CORRECTION_REQUIRED`, `LEGACY_RANGE_CORRECTION_REQUIRED`, `BLOCKED_BY_PURCHASE_HANDOFF`, or `BLOCKED_BY_DOWNSTREAM_COMMITMENT`. The existing source Saves re-evaluate that model under deterministic Need, Confirmed Need, and Handoff locks. If any date is not safe, the entire Save returns without changing the source.

## Correction boundary

The single correction command governs one exact Need/Confirmed Need chain with expected versions and the normal receipt, idempotency, event, and audit pattern.

- A released Confirmed Need with no active Handoff is moved to existing `REOPENED`; its current validation/approval/release authority pointers are cleared while immutable approval snapshots, releases, actors, timestamps, lines, decisions, Need evidence, and history remain unchanged.
- A Draft/Reopened historical multi-day chain is explicitly invalidated as one whole range. It is never split and no daily replacement is created.
- Multiple overlapping ranges are returned and corrected independently.
- An active Purchase Handoff blocks ordinary Planning correction. Planning-owned PA-05D Purchase Demand Reference and Dispatch Requirement lineage remains part of that Handoff boundary; the later-domain blocker begins only when a Procurement `fulfilment_allocations` root exists for a derived Dispatch Requirement, including historical allocations retained after Handoff invalidation.

After an allowed source Save, existing D-041 date fingerprints make only the materially changed daily Needs `OUTDATED`. The operator regenerates those dates explicitly and reviews the resulting Confirmed Need normally.

## Security and surface

The migration adds no table, role, capability, lifecycle status, scope, dependency, Procurement write, or browser data access. The impact read uses `planning.inputs.read` and `atlas_read_runtime`. The correction command always requires existing `planning.need_generation.write`; immediately before a released Confirmed Need is reopened it additionally requires the same Actor to hold D-037's existing `confirmed_need_release.release`. Draft/Reopened legacy invalidation remains Need-authority-only. The narrow Confirmed Need reopen write stays isolated in the existing Confirmed Need review runtime. To classify the first authoritative later-domain fact, `atlas_planning_command_runtime` receives only `USAGE` on `atlas_procurement`, `SELECT` on `atlas_procurement.fulfilment_allocations`, and one SELECT RLS policy on that table. Public execution remains authenticated-only, with fixed empty search paths and private helpers inaccessible to browser roles.

## Migration and rollback

Migration `20260823090858_issue_222_closed_loop_planning_corrections.sql` adds two public functions, private comparison/enforcement helpers, and stable wrappers around the three existing consequential Saves. The original Save bodies are moved without behavioral edits and remain private.

Rollback before production use is code rollback: restore the three Save function identities/bodies to `atlas_api`, drop the two public correction functions and private helpers, and restore the prior API catalog. The migration creates no data relation and rewrites no business row. After operators use the correction command, its receipt/event/audit records and any `REOPENED` or `INVALIDATED` transitions are authoritative history and must not be deleted by rollback.

## Explicit exclusions

Purchase Handoff change orders, Procurement/Receiving/Warehouse/Dispatch correction, automatic regeneration, generic workflow orchestration, hosted Staging cleanup, live OPS changes, and Retool changes remain out of scope.
