# TASK-PA-06E-H0A5a — Need Generation Run and Theoretical-Lineage Decision

**Status:** Documentation decision completed on the task branch; validation and draft-PR evidence recorded below

**Issue:** [#129](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/129)

**Task branch:** `docs/pa-06e-h0a5a-need-generation-decision`

**Starting baseline:** `9a3c9896d4ffd0c3eaae4a931d5b57607feb788c`

**Parent task:** [TASK-PA-06E-H0](TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**Decision:** [Decision PA-06E-H0A5](../decisions/decision-pa-06e-h0a5-need-generation-lineage.md)

## 1. Objective

Close every run, input, calculation, Recipe-selection, Unit, atomic-lineage, predecessor, issue, lifecycle, release, and future-test decision that blocked a separately authorized H0A5b persistence foundation.

This is a documentation and architecture-decision task only. It does not implement H0A5 persistence or create a command/read surface.

## 2. Governing boundary

The task follows OPS_SYSTEM_MAP v1.0 and the authority order in Issue #129. Merged H0A2–H0A4 decisions, migrations, and tests override the older Need Generation prototype and retained OPS v1/Retool behavior.

The task treats the following prototype assumptions as non-authoritative and superseded:

- `planningInputSetVersion` on a versionless H0A4b root;
- generic `readinessSnapshotId` instead of exact evaluation ID/version;
- entry from `READY` rather than only `NEED_GENERATION_REQUESTED`;
- first-active-Recipe selection without SchoolType precedence;
- JavaScript `number` arithmetic and per-portion shortcuts without the Recipe basis;
- concatenated `sourceTraceId` identity;
- aggregated/effective-needs view rows as theoretical contribution identity; and
- mutable run-line status as release evidence.

## 3. Decision closure delivered

### Run and readiness

- One accepted generation attempt creates one distinct positive-version run for one exact Planning Input Set and exact current H0A4b evaluation.
- The run inherits the Planning Input Set period and cannot combine sets or evaluations.
- Generation requires root `NEED_GENERATION_REQUESTED`, exact current `READY` evaluation, zero readiness blockers, and both exact source bindings still current.
- Recalculation creates a new successor after predecessor invalidation. Runs form one nonforking, acyclic, Planning-Input-Set-local chain.
- Only the current terminal run may validate or release.

### Immutable input and fixed calculation

- One immutable run input snapshot binds the exact Planning Input Set/evaluation/version, exact Menu and Attendance triples inherited from readiness, one mandatory calculation-contract revision, exact Recipe/RecipeVersion/RecipeLine/RecipeLineRevision uses, and every used future conversion revision.
- The fixed formula is `(student portions + teacher portions) × quantity_per_basis ÷ basis_portions`.
- PostgreSQL `numeric` is authoritative; source operands are multiplied then divided without an intermediate typmod cast and coerced once to `numeric(20,6)`.
- Rule/conversion factors use `numeric(24,12)` where applicable; invalid, negative, non-finite, or overflowing results fail closed; no epsilon applies.
- Zero portions create warning-bearing `ACTIVE` zero lines, never removal.

### Recipe and Unit

- Exact eligible SchoolType Recipe takes precedence over one eligible general Recipe; caller or row order never selects.
- Eligibility requires an active Need-Generation Dish, active Recipe, exact current `RELEASED_FOR_PLANNING` version, positive basis, complete exact composition, and active Ingredient/Unit references for new generation.
- Historical `LOCKED` versions interpret old runs only.
- H0A5 output remains in each exact RecipeLineRevision source Unit. H0A5b adds no conversion family or production conversion values; differing Units fail closed pending a separately approved typed immutable conversion family.

### Atomic lineage and correction

- One Theoretical Need line is one atomic Menu-snapshot-line + Attendance-snapshot-line + selected Recipe/Version + stable RecipeLine/exact revision + Ingredient + source Unit + calculation revision + optional conversion revision combination.
- The line uses direct typed source anchors and bounded typed run-use relations; generic source registries, JSON, hashes, names, tokens, and concatenated IDs are rejected.
- Quantity and Ingredient corrections on the same stable RecipeLine have exactly one predecessor; a new stable RecipeLine has none.
- `ACTIVE` and `REMOVED` are the only dispositions. `REMOVED` is exact zero, has one predecessor, and requires exact released H0A2 `REMOVED` evidence.
- Forks, same-run/unrelated predecessors, split, merge, cross-anchor wiring, and silent prior-`ACTIVE` omission block release.

### Issues, lifecycle, and release

- The decision defines a closed 34-code Need Generation classification catalog. Every condition except `ZERO_ACTIVE_THEORETICAL_QUANTITY` is blocking.
- Need Generation does not copy H0A4 warnings or add acknowledgement, waiver, override, or operator-editable issue mutation.
- Lifecycle is exactly `GENERATED`, `VALIDATED`, `RELEASED_FOR_CONFIRMATION`, and `INVALIDATED` with only the five requested transitions and one version increment per valid transition.
- Invalidation preserves run, input, line, issue, and release evidence; no upstream trigger invalidates automatically; successor generation is explicit.
- Release creates a separate immutable header, every-and-only line membership, and every-and-only issue membership for the exact released run version. H0B1 consumes typed release rows without editing H0A5.

## 4. Documentation files

The bounded change creates exactly:

- `docs/decisions/decision-pa-06e-h0a5-need-generation-lineage.md`;
- `docs/implementation-tasks/TASK-PA-06E-H0A5a-need-generation-decision.md`.

It minimally amends only:

- `docs/architecture/planning-domain-need-generation-contract.md`;
- `docs/architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md`;
- `docs/implementation-tasks/TASK-PA-06E-H0-school-catering-persistence-materialization.md`;
- `docs/architecture/pa-02-physical-schema-and-constraint-design.md`;
- `docs/decisions/decision-register.md`;
- `docs/architecture/roadmap.md`.

No other file belongs to H0A5a.

## 5. Future H0A5b physical and test boundary

H0A5b must separately authorize and name the minimum private families for run control, one input snapshot, fixed calculation-contract revision, typed Recipe uses, immutable Theoretical Need lines, typed sources, issues, release header/lines/issues, and nonforking run/line predecessor keys. The source-unit slice creates no conversion family.

Before coding, the H0A5b issue must declare exact filenames and exact `plan(N)` counts for four independently runnable, non-overlapping suites:

1. H0A5 structure/security;
2. H0A5 run/input/recipe/calculation integrity;
3. H0A5 theoretical-line/source/predecessor/release integrity; and
4. H0A5 lifecycle/issues/invalidation/history.

Each suite owns its transaction, deterministic noncolliding fixtures, exact plan, `finish()`, rollback, one exact-path workflow command, `Files=1`, exact assertion count, and `Result: PASS`. H0A1–H0A4 tests remain unchanged.

## 6. Exclusions

No SQL, migration, pgTAP, workflow, RPC, trigger, role, capability, policy, event, reason, receipt, API/read surface, generated type, TypeScript, React, package, lockfile, Retool export, OPS v1 schema, hosted Supabase access, production data, credential, deployment, Confirmed Need, Procurement, Warehouse, Dispatch, QA, Production, Finance, H0A5b, H0B1, or H0C behavior is part of this task.

The historical stash described as `preserve-local-h0a3a-edits-before-issue-127` remains unrelated and must not be applied, modified, dropped, compared as task evidence, or included.

## 7. Acceptance criteria

- [x] Exact run grain and one-successor-per-attempt control model are closed.
- [x] `NEED_GENERATION_REQUESTED` and exact current H0A4b evaluation/source currentness are mandatory.
- [x] The immutable run input snapshot uses typed relational evidence and supersedes prototype version/snapshot assumptions.
- [x] The proportional-per-basis formula, student/teacher sum, numeric types, arithmetic order, final cast, overflow, zero, and no-rounding boundaries are closed.
- [x] Exact SchoolType-over-general Recipe precedence and eligibility are closed.
- [x] Source Unit is selected and the future conversion boundary is fail-closed without production values.
- [x] Atomic theoretical contribution identity and typed source shape are closed without aggregation or a generic registry.
- [x] One-to-one predecessor, `ACTIVE`/`REMOVED`, fork/split/merge, and silent-omission rules are closed.
- [x] Exact issue ownership/catalog/severity and no-acknowledgement boundary are closed.
- [x] Lifecycle, version behavior, explicit invalidation, successor generation, and no automatic triggers are closed.
- [x] Separate immutable release header, line membership, issue membership, and H0B1 typed consumption are closed.
- [x] All nine required alternatives are selected or rejected.
- [x] Four exclusive future H0A5b invariant families are assigned.
- [x] Security, migration, rollback, and downstream boundaries remain explicit.
- [x] Only the eight authorized documentation files change.

## 8. Validation record

Final local validation and exact changed-file evidence:

- canonical workspace and baseline: passed before editing at `9a3c9896d4ffd0c3eaae4a931d5b57607feb788c`;
- Issue #129 was open with `atlas:ready`, no matching branch/PR existed, and the issue moved to `atlas:working` when work began;
- the historical H0A3a stash was located by message and never applied or included;
- `pnpm install --frozen-lockfile`: passed with the lockfile already current under pnpm 11.7.0;
- `pnpm format`: passed;
- direct Prettier checks for both new documents and the replaced Need Generation contract: passed; the repository has no broader configured Markdown-format or documentation-link script, and the minimally amended parent documents retain their established table layout;
- `pnpm typecheck`: passed;
- `pnpm test`: passed, 41 files and 265 tests;
- `pnpm build`: passed; Vite retained its existing nonblocking chunk-size advisory;
- local Markdown target resolution for all eight changed documents and `git diff --check`: passed;
- exact eight-file documentation-only scope audit: passed, with no migration, pgTAP, workflow, API/RPC, role/capability, generated type, application, package/lockfile, Retool, OPS v1, hosted, data, credential, deployment, or H0A5b implementation path; and
- publication and exact-head GitHub Actions evidence: recorded on the draft PR after completion.

## 9. Migration and rollback

H0A5a has no database migration, hosted execution, production-data effect, or deployment rollback. Documentation rollback is a normal Git revert. Any later H0A5b migration must state its own additive/forward-fix boundary and preserve released calculation history after use.
