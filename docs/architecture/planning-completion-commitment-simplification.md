# Planning Completion and Commitment Simplification

**Status:** Accepted architecture impact of D-036

**Date:** 09/08/2026

**Decision:** [D-036 — Planning Completion and Commitment Boundaries](../decisions/decision-atlas-planning-completion-commitment-boundaries.md)

## Outcome

Atlas will simplify the Planning command surface at the Business Contract /
Command boundary before changing Application presentation:

> **Humans approve business commitments. Systems validate deterministic system work.**

The target preserves backend authority, immutable snapshots, typed lineage,
security, receipts, events, audit, retries, and correction history. It removes
normal operator clicks whose only purpose is to advance a backend lifecycle.

## Authority and evidence reviewed

The review followed `OPS_SYSTEM_MAP` v1.0 from Mission through Business
Contract and Command/Event before considering the connected UI. It covered:

- D-023 through D-031, D-034, and D-035;
- `RMVP-03A.v1`, `PANTRY-02.v1`, `RMVP-03B.v1`, `RMVP-04.v1`, and
  `PA-06E-H0C.v1`/CMD-15;
- the accepted Weekly Menu, Attendance, Pantry, readiness, Need Generation,
  and Confirmed Need architecture and persistence decisions;
- the merged RMVP-03A, PANTRY-02, RMVP-03B, PANTRY-NG-02, RMVP-04, and CMD-15
  migrations and focused tests;
- the current Planning implementation records, adapters, tabs, and visible
  command labels as presentation evidence only; and
- repository-retained OPS v1/Retool evidence read-only.

The retained evidence establishes a direct operational pattern:

- Weekly Menu uses an explicit week, imports/previews source data, then confirms
  a save whose changed School/days have downstream Planning consequences.
- Attendance supports bulk save/defaults/correction with explicit dates and
  downstream impact visibility.
- Pantry loads date/School/Ingredient rows, edits quantity/note, and saves
  changed rows into the theoretical-needs flow.
- downstream Planning accepts a direct saved quantity correction and refreshes
  derived consequences.

That evidence does not establish separate human validation or approval roles
for Weekly Menu, Attendance, or Pantry. It also does not authorize Retool's
public writes, browser-owned Unit mapping, hidden rebalance reactions,
destructive behavior, or client orchestration as Atlas architecture.

## Current flow

```text
Weekly Menu: edit/import → Save Draft → Validate → Approve
Attendance: create/edit/import → Save Draft → Validate → Approve
Pantry: edit → Save Draft → Validate → Approve
                         ↓
Planning Input Readiness: Evaluate → Request Need Generation
                         ↓
Need Generation: Create → Validate → Release → CMD-15 Materialize
                         ↓
Confirmed Need: review/correct → validate → approve → release
```

The current backend correctly owns calculation, validation, snapshots,
lifecycles, currentness checks, idempotency, events, audit, and lineage. The
problem is that deterministic substeps are exposed as if each were a human
business decision.

## Target flow

```text
Weekly Menu / Attendance / Pantry
edit → Save
       ├─ backend validates and persists one current completed source version
       ├─ backend creates immutable completion and audit evidence
       └─ downstream currentness/readiness changes immediately
                         ↓
Tạo nhu cầu preflight
automatic READY or BLOCKED with contextual source exceptions
                         ↓
Tạo nhu cầu | Cập nhật nhu cầu
one atomic backend operation:
derive readiness → generate → integrity-validate → release → materialize/correct
                         ↓
Confirmed Need
human reviews/corrects → human completes/releases for Purchase Handoff
```

The normal success message for a source is conceptually:

> Saved. This version is now used by downstream Planning.

If no derived result exists, the completed source is immediately available to
the automatic Need Generation preflight. If a current derived result already
exists and its immutable input lineage differs, that result is no longer
current even though its historical evidence remains valid.

When a Save changes lineage already consumed by a current derived result, the
normal consequence is:

> Nhu cầu cần cập nhật.

## Commitment-boundary classification

Categories:

- **A — Human input completion:** a person commits authored operational facts.
- **B — Human business decision:** a person makes a real approval or commitment.
- **C — System validation:** deterministic invariant or integrity work.
- **D — System derivation:** deterministic calculation, snapshot publication,
  or materialization.
- **E — Exception / correction:** needed only after failure, change, or recovery.

<!-- prettier-ignore -->
| Current command | Category | Human click justified? | Proposed future behavior | Surface disposition |
| --- | --- | --- | --- | --- |
| `save_weekly_menu_draft` | A | Yes, as **Save**, not as draft administration | Atomically validate, persist the current completed Menu, create immutable completion evidence, and return downstream consequence | Superseded by a versioned public completion command |
| `validate_weekly_menu` | C | No | Execute inside Weekly Menu Save | Merged; backend-internal |
| `approve_weekly_menu` | A | No separate click; its snapshot effect belongs to completion | Create the immutable current source snapshot inside Weekly Menu Save | Merged; old public command retired after cutover |
| `reopen_weekly_menu` | E | Only when correcting consumed/history-bearing input | Start a reasoned successor correction and complete it through one later Save; do not rewrite an old snapshot | Superseded by contextual correction semantics |
| `create_attendance_draft_from_defaults` | D | Optional as an editing convenience, never as lifecycle completion | Return non-writing defaults/prefill for local editing; authority begins only at Save | Superseded by a read/preview helper |
| `save_attendance_draft` | A | Yes, as **Save** | Atomically validate, persist the current completed Attendance, create immutable completion evidence, and return downstream consequence | Superseded by a versioned public completion command |
| `validate_attendance` | C | No | Execute inside Attendance Save | Merged; backend-internal |
| `approve_attendance` | A | No separate click; its snapshot effect belongs to completion | Create the immutable current source snapshot inside Attendance Save | Merged; old public command retired after cutover |
| `reopen_attendance` | E | Only for correction | Start a reasoned successor correction and complete it through one later Save | Superseded by contextual correction semantics |
| `save_pantry_draft` | A | Yes, as **Save**, including explicit no-additions completion | Atomically validate references/Unit/Purpose/zero evidence, persist the current completed Pantry source, and snapshot it | Superseded by a versioned public completion command |
| `validate_pantry` | C | No | Execute inside Pantry Save | Merged; backend-internal |
| `approve_pantry` | A | No separate click; its snapshot effect belongs to completion | Create positive-line or explicit zero-line immutable completion evidence inside Pantry Save | Merged; old public command retired after cutover |
| `reopen_pantry` | E | Only for correction | Start a reasoned successor correction and complete it through one later Save | Superseded by contextual correction semantics |
| `evaluate_planning_input_readiness` | C | No | Derive readiness automatically from the three current completed source snapshots | Removed from normal public command surface; internal/preflight |
| `request_planning_input_need_generation` | D | No independent judgment exists | Bind readiness and handoff inside the one Need Generation execution | Merged into the new generation command |
| `invalidate_planning_input_readiness` | E | Not in normal flow; support/correction only | Derive staleness from source-currentness and retain a narrow audited exception path only where manual correction evidence is required | Internal or contextual support; not a primary action |
| `create_need_generation_run` | D | Yes only as the single **Tạo nhu cầu/Cập nhật nhu cầu** intent | Become the entry to one atomic generation operation rather than the first lifecycle step | Merged into one versioned public execution command |
| `validate_need_generation_run` | C | No | Run deterministic integrity validation in the generation transaction | Merged; backend-internal |
| `release_need_generation_run` | D | No human business commitment exists at theoretical release | Create immutable release evidence in the generation transaction after all invariants pass | Merged; backend-internal |
| `invalidate_need_generation_run` | E | Not in normal flow; only correction/recovery | Preserve old evidence and create/prepare the successor through **Cập nhật nhu cầu**; retain a narrow support command for unsafe or blocked corrections | Contextual support or internal substep |
| `CMD-15 create_confirmed_needs_from_generation` | D | No | Materialize or correct Confirmed Need inside the same atomic generation operation | Merged; private/internal callable after cutover |

No current Planning command in this table is a category-B human business
decision. The first category-B boundary after generation is Confirmed Need
approval/release for Purchase Handoff. Human quantity confirmation inside
Confirmed Need is the preceding review/decision work.

## Affected contracts

| Existing authority       | Required `PLANNING-CONTRACT-01` delta                                                                                                                                                                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RMVP-03A.v1`            | Add versioned consequential Save commands for Weekly Menu and Attendance; internalize validation/snapshot creation; replace reopen-as-lifecycle with successor correction; preserve previews and shaped reads.   |
| `PANTRY-02.v1`           | Add a versioned consequential Pantry Save with positive-line and explicit zero-line completion; internalize validation/snapshot creation; preserve typed reference authority.                                    |
| `RMVP-03B.v1`            | Retain typed source discovery, ambiguity/missing/stale diagnosis, immutable evaluations/issues, and history; replace normal Evaluate/Request lifecycle commands with automatic preflight/currentness derivation. |
| `RMVP-04.v1`             | Replace Create/Validate/Release as public sequential commands with one versioned generate-or-update command and one authoritative workbench/preflight read.                                                      |
| `PA-06E-H0C.v1` / CMD-15 | Preserve exact grouping, source membership, correction lineage, and Confirmed Need materialization rules while making materialization an internal sub-operation of the new atomic generation command.            |
| RMVP-05/06/07            | No redesign in D-036. Confirmed Need remains the human review/completion/release boundary; existing validation and commitment contracts remain authoritative until separately amended.                           |

Applied `v1` migrations and contracts remain historical implementation
authority. Their public behavior must not be silently redefined in place; the
later task introduces explicit versioned contracts and forward migrations.

## Capability and role implications

No accepted current business requirement requires different operators for
Weekly Menu write, Attendance write, Pantry write, and input approval. The
future normal capability model is therefore:

<!-- prettier-ignore -->
| Current capability | Proposed meaning after cutover |
| --- | --- |
| `planning.inputs.read` | Retain for source workbenches, automatic preflight, blockers, history, and currentness. |
| `planning.weekly_menu.write` | Supersede in normal role bindings with one `planning.inputs.complete` capability. |
| `planning.attendance.write` | Supersede in normal role bindings with one `planning.inputs.complete` capability. |
| `planning.pantry.write` | Supersede in normal role bindings with one `planning.inputs.complete` capability. |
| `planning.inputs.approve` | Unnecessary for normal source completion; retire from these source commands after migration. |
| `planning.input_readiness.write` | Unnecessary as an operator capability; readiness evaluation/currentness becomes backend-owned. |
| `planning.need_generation.write` | Replace with one `planning.need_generation.execute` capability authorizing **Tạo/Cập nhật nhu cầu**, not lifecycle administration. |
| `confirmed_need_generation.materialize` | Remove from normal application-role assignment; retain only the minimum internal runtime privilege needed by the composite generation transaction, then retire the independent public command grant. |
| Confirmed Need review/confirmation/approval/release capabilities | Unchanged by D-036 because they govern the first real human review and commitment boundary. |

`PLANNING-CONTRACT-01` must define the exact capability codes and transition
plan. It must not bind new capabilities to production roles merely because the
metadata exists.

## Atomic transaction boundaries

### Source completion

Each source family has one independently atomic Save transaction. It must:

1. authorize the actor and exact completion capability;
2. acquire or replay one idempotency receipt and enforce expected version and
   checksum/current-source concurrency;
3. canonicalize and deterministically validate all submitted facts and current
   typed references;
4. persist the stable root and complete working-line replacement;
5. create the immutable completed-source snapshot and exact line membership;
6. advance the authoritative current-source pointer/version;
7. append the source-completed event and audit evidence; and
8. return authoritative readback with downstream currentness and the message
   that Need must be updated when applicable.

If downstream currentness can be proven by comparing the latest completed
source identities with the immutable generation input snapshot, the read model
should derive staleness instead of mutating the released run. Any persisted
currentness projection is non-authoritative unless updated in the same commit.

The browser must not call Save → Validate → Approve behind one button.

### Need Generation and materialization

The future generate-or-update command is one transaction and one top-level
command outcome. It must:

1. lock and re-read the current completed Menu, Attendance, and Pantry evidence;
2. derive exact readiness and return all blockers without accepting
   browser-authored readiness;
3. select the calculation contract, Recipes, versions, line revisions, and
   destination/source evidence;
4. create the complete successor run and all atomic contribution and issue
   evidence;
5. run every integrity check and refuse release when any blocker exists;
6. create the immutable theoretical-Need release and exact line/issue membership;
7. call a private/internal form of CMD-15 to create or correct Confirmed Need;
8. advance current/successor pointers without changing historical payloads; and
9. commit the receipt, events, audit, authoritative readback, and all evidence
   together—or commit none of them.

Existing lifecycle events may remain as system-generated evidence inside the
same transaction, or a later contract may add one composite event while
retaining the historical event catalog. There is one public command receipt and
no browser chaining. Transport uncertainty is resolved by exact replay of that
one frozen request.

## Correction and staleness behavior

Normal correction is:

```text
Save successor upstream source
→ prior released source and generation evidence remain immutable
→ latest-source identity no longer matches current generation input lineage
→ current derived result reads OUTDATED / correction required
→ operator sees Cập nhật nhu cầu
→ one atomic successor generation and Confirmed Need correction
→ predecessor and contribution lineage remain exact
```

The update command may correct a linked Confirmed Need only inside its existing
permitted boundary, such as `DRAFT_REVIEW` or `REOPENED`. An approved or released
Confirmed Need follows its separately governed reopen/review/reapproval path.
An existing Purchase Handoff or later Procurement/Dispatch commitment blocks
silent correction and requires a future domain-owned correction contract.

Source Save never mutates a prior source snapshot, Need Generation release,
Confirmed Need revision, approval snapshot, release, or downstream document.

## Readiness application placement

After backend cutover, normal readiness belongs in the `Tạo nhu cầu` preflight:

- `READY` proceeds through the one generation action;
- `MISSING`, `AMBIGUOUS`, or `STALE` shows the affected source and correction;
- blockers remain prominent;
- immutable evaluation, source-binding, invalidation, and history evidence
  remains under exception/support detail.

The separate `Sẵn sàng đầu vào` primary tab should therefore be absorbed into
`Tạo nhu cầu`, not retained as a normal destination. It may survive temporarily
during versioned migration and may remain available to support users as a
non-primary diagnostic view. UI changes wait for the backend contract.

## Audit and history preservation

Simplification does not delete or weaken:

- stable aggregate and line identities;
- source versions and immutable completion/approval snapshots;
- command receipts and exact replay semantics;
- domain events and audit events;
- immutable readiness evaluations, source bindings, issues, and history;
- Need Generation input snapshots, calculation revisions, Recipe selections,
  Recipe-line uses, theoretical contributions, issues, and release membership;
- Confirmed Need stable lines, revisions, contribution memberships, decisions,
  validation observations, approvals, releases, and predecessor chains; or
- released historical snapshots and downstream references.

Backend functions remain revoke-first, fixed-search-path, least-privilege,
subject-bound, scope-authorized, and protected by private-schema RLS. React
receives no service-role credential and no direct private-relation access.

## Migration compatibility considerations

`PLANNING-CONTRACT-01` must use forward-only, versioned change:

1. add new completion, preflight/currentness, and generate-or-update contracts;
2. reuse existing immutable persistence where its meaning remains exact and add
   only the minimum currentness/supersession evidence that cannot be derived;
3. treat an exact current `APPROVED` source snapshot as eligible completed input
   without fabricating history; require an operator Save for legacy
   `DRAFT`/`VALIDATED` data that lacks completion evidence;
4. retain old readiness evaluations and released runs as historical evidence;
   do not backfill Pantry/source bindings or rewrite their results;
5. do not auto-release pre-cutover `GENERATED` or `VALIDATED` runs; classify them
   for audited invalidation/support recovery or restart under the new command;
6. cut application-role capability bindings and public execute grants so only
   one normal command surface owns writes at a time;
7. move old lifecycle APIs to unbound compatibility/support status, then revoke
   normal public execution only after the new path and rollback procedure are
   proven; and
8. update API contracts, migrations, security catalog, pgTAP, browser acceptance,
   TypeScript registry/adapters, and documentation in the same bounded change.

Applied migrations are never edited. Rollback after operational use is a
reviewed forward migration that restores a callable contract without deleting
receipts, events, audit, versions, snapshots, or released history.

## Explicit non-goals

D-036 and this impact note do not:

- change SQL, migrations, RPCs, React, tests, dependencies, or generated types;
- deploy or mutate hosted Supabase, production data, OPS v1, or Retool;
- redesign Confirmed Need quantity review, validation, approval, release, or
  reopen behavior;
- define Purchase Handoff, supplier selection, Procurement, Warehouse,
  Dispatch, Production, Quality, or Finance correction;
- introduce a generic workflow engine, approval framework, asynchronous
  orchestration service, or new business stage; or
- authorize UI-QUALITY-02A-UX, UI-QUALITY-02C, or implementation before the
  versioned backend contract is accepted and merged.

## Smallest recommended sequence

### 1. PLANNING-CONTRACT-01 — backend contract simplification

Define and implement the versioned atomic boundary for:

- consequential Weekly Menu, Attendance, and Pantry Save;
- automatic readiness/currentness and exact preflight blockers;
- one generate-or-update command that atomically generates, validates, releases,
  and materializes/corrects Confirmed Need;
- successor correction, staleness, idempotency, transaction, event/audit,
  capability, security, migration, rollback, and compatibility behavior; and
- focused database/API/browser acceptance proving no partial result and no
  historical mutation.

This is the exact prerequisite for Application changes.

### 2. UI-QUALITY-02AB-UX — align the source-to-generation workflow

After `PLANNING-CONTRACT-01` merges:

- show one consequential Save in Weekly Menu, Attendance, and Pantry;
- remove normal Validate/Approve/Reopen lifecycle administration;
- absorb normal Readiness into `Tạo nhu cầu` preflight while retaining
  contextual ambiguity/blocker/support detail;
- show only **Tạo nhu cầu** or **Cập nhật nhu cầu** for the atomic backend
  command; and
- preserve exact retry, stale refresh, unsaved-edit protection, audit/history,
  accessibility, and D-034/D-035 presentation rules.

This combines the waiting `UI-QUALITY-02A-UX` source implications with the
Readiness/Need Generation correction so one UI cannot straddle two contracts.

### 3. UI-QUALITY-02C — Confirmed Need workflow-first UI

Proceed only after source completion and generation semantics are stable. Keep
Confirmed Need as the first human review/commitment surface and do not reopen
the upstream lifecycle design there.

### 4. PLANNING-UX-01 — end-to-end Planning consolidation

Review the complete source → generation → Confirmed Need journey, terminology,
navigation, exception recovery, and handoff comprehension after the three
bounded changes above are merged.
