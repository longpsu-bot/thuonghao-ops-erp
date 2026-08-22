# TASK-PLANNING-CONTRACT-01 — Atomic Planning completion boundaries

## Status

Implemented on draft branch `codex/planning-contract-01-atomic-planning-boundaries` from required baseline `eae396b104347d5accaffdb373997904248cbad7`. Independent architecture review, draft Supabase Smoke, and merge remain pending. This record does not authorize UI-QUALITY-02AB-UX or deployment.

## Decision implemented

This task implements D-036 using the governing rule:

> Humans approve business commitments. Systems validate deterministic system work.

The backend boundary becomes:

```text
Weekly Menu / Attendance / Pantry consequential Save
→ automatic Planning preflight
→ one Tạo nhu cầu / Cập nhật nhu cầu command
→ readiness + generation + integrity + immutable release
→ existing H0C Confirmed Need materialization/correction
→ human Confirmed Need review / confirmation / approval / release
```

React workbench behavior is intentionally unchanged in this task.

## Contract and public API delta

The additive contracts are:

| Contract       | Public function                                 | Capability                       | Runtime                          |
| -------------- | ----------------------------------------------- | -------------------------------- | -------------------------------- |
| `RMVP-03A.v2`  | `atlas_api.save_weekly_menu(jsonb)`             | `planning.weekly_menu.write`     | `atlas_planning_command_runtime` |
| `RMVP-03A.v2`  | `atlas_api.save_attendance(jsonb)`              | `planning.attendance.write`      | `atlas_planning_command_runtime` |
| `PANTRY-02.v2` | `atlas_api.save_pantry(jsonb)`                  | `planning.pantry.write`          | `atlas_planning_command_runtime` |
| `RMVP-03B.v2`  | `atlas_api.get_planning_input_preflight(jsonb)` | `planning.inputs.read`           | `atlas_read_runtime`             |
| `RMVP-04.v2`   | `atlas_api.execute_need_generation(jsonb)`      | `planning.need_generation.write` | `atlas_need_generation_runtime`  |

No `planning.inputs.complete` capability, replacement capability, production role binding, or new runtime is introduced. Source capabilities remain independent.

## Transaction boundaries

Each source Save authenticates the exact human subject, authorizes only its source capability, acquires one durable top-level receipt, enforces expected version and signature, performs complete canonical replacement with stable line identities, runs deterministic validation, creates an immutable every-and-only completed snapshot, records composite completion evidence, and returns authoritative workbench plus automatic preflight/currentness. Exact completed content is `NO_CHANGE`; exact replay returns the original response.

Automatic preflight is read-only. It discovers the current completed Menu, Attendance, and Pantry evidence, derives all issues, and compares immutable source identities with the current Need input snapshot. It does not accept browser-authored readiness or issue facts and does not create a lifecycle transition.

Atomic Need execution owns one request, idempotency identity, receipt, transaction, and response. Internally it composes the established v1 readiness and Need Generation logic, then invokes the shared private H0C materializer. Deferred cross-aggregate constraints are flushed while released-run and Confirmed Need pointers are mutually current. A blocked preflight produces no partial run, release, or Confirmed Need.

## Correction and history

A successor source Save never edits a prior completed snapshot. If an exact current Need consumed a period contained by the source week, the Save reports `OUTDATED`. The update command invalidates only a safely correctable terminal run, creates its direct successor, preserves immutable input/theoretical/release history, and advances the existing Confirmed Need through the accepted H0C correction boundary. Approved/released Confirmed Need or downstream commitment returns the established safe blocker.

## Persistence, security, and event delta

One forward migration is added:

```text
supabase/migrations/20260809120000_planning_contract_01_atomic_planning_boundaries.sql
```

It adds five public functions and private composition/read helpers. It adds no relation, view, trigger, policy, capability, role, runtime, scope kind, lifecycle state, extension, generic orchestration persistence, or production seed. Existing source aggregates, approval snapshots, readiness evaluations/issues, Need Generation lineage/releases, Confirmed Need revisions/membership, receipts, events, and audits remain authoritative.

All public functions are fixed-empty-search-path security definers. Execution is revoked from `PUBLIC`, `anon`, and `service_role`, and granted only to `authenticated`. Browser roles retain no direct private-relation privileges. React registers typed RPCs only and never uses service-role credentials or automatic write retry.

Composite events are `WeeklyMenuCompleted`, `AttendanceCompleted`, `PantryCompleted`, and `NeedGenerationExecuted`. Established internal lifecycle and H0C events/audits remain durable compatibility evidence. Atomic execution has exactly one top-level receipt even though internal domain evidence is retained.

## Coexistence and retirement

All `RMVP-03A.v1`, `PANTRY-02.v1`, `RMVP-03B.v1`, `RMVP-04.v1`, and `PA-06E-H0C.v1` public functions remain physically callable with exact request/response and grant behavior. The connected UI is not forced to cut over.

UI-QUALITY-02AB-UX must later replace public lifecycle write chains with the v2 source Saves, automatic preflight, and atomic execute command. Only after browser cutover, usage evidence, architecture review, and a separately approved migration may normal-operator execute grants for obsolete lifecycle paths be revoked. Historical APIs/evidence must not be deleted as rollback.

## Migration and rollback effect

The migration is forward-only and creates no data rewrite. Before use, rollback is removal of the undeployed migration. After deployment or command use, rollback must be another reviewed forward migration that revokes the five v2 entry points while preserving receipts, snapshots, evaluations, runs, releases, revisions, events, and audits. Re-enabling v1 UI paths is an application rollback; deleting historical facts is prohibited.

## Verification

The focused pgTAP suite proves source-specific authorization, atomic completion, exact membership/history, replay/conflict/stale/no-change behavior, automatic readiness/currentness, mixed Recipe and Pantry execution, one receipt, H0C grouping/membership, blocker atomicity, direct correction lineage, and security. The exact Pantry and RMVP-03B legacy catalog assumptions acknowledge the additive functions without weakening their historical behavior assertions.

Focused TypeScript tests prove exact registry/version/request construction, one RPC per new adapter call, safe errors, stale handling, transport uncertainty, and no automatic write retry or browser chaining. `scripts/verify-local-planning-contract-01.mjs` uses a publishable browser key and signed synthetic human for all application behavior; administrative fixture provisioning uses only existing disposable local conventions.

## Issue #215 bounded command-clock correction

Planning v2 treats `requested_at` as client-intent evidence and accepts at most
60 seconds of positive client/server clock skew. The tolerance exists only in
`planning_contract_01_validate_command`; malformed timestamps and timestamps
more than 60 seconds ahead of the PostgreSQL transaction clock remain
`VALIDATION_FAILED` with `requested_at` field evidence.

After the public command passes authentication, authorization, envelope
validation, and receipt handling, every server-derived RMVP-03A, PANTRY-02,
RMVP-03B, RMVP-04, and PA-06E-H0C child request uses the authoritative
transaction timestamp. Child validators therefore do not repeatedly depend on
the browser clock. Public v1 commands retain their strict non-future semantics,
and D-037 Confirmed Need v2 remains unchanged.

The correction is forward-only and rewrites no data. Before deployment it may
be removed with the undeployed migration. After use, rollback requires another
reviewed forward migration; receipts, source snapshots, generation releases,
Confirmed Need materialization, events, and audit evidence must be preserved.

## Explicit exclusions

No hosted Supabase, Retool, OPS v1/v2, production data, UI workbench, RMVP-05/06/07 semantics, Purchase Handoff, Procurement, Warehouse, Dispatch, generic workflow engine, queue, service, dependency, or deployment is changed.
