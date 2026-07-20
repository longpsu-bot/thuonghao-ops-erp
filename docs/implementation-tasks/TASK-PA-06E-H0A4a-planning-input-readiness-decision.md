# TASK-PA-06E-H0A4a — Planning Input Readiness Decision Closure

**Status:** Documentation complete on task branch; pending independent review
**Issue:** GitHub Issue #125
**Base:** `main` at `2bbb9242487895940278b3c7416995d56188a91f`
**Branch:** `docs/pa-06e-h0a4a-readiness-decision`

## 1. Objective

Close the Planning Input Set/readiness design decisions required before any H0A4 persistence work. Reconcile approved Planning contracts with merged H0A3a/H0A3b snapshot structures and retained OPS v1 evidence. Produce documentation only.

## 2. Authority and evidence reviewed

Repository authority was applied in this order:

- product charter, architecture, roadmap, decision register, and business-rule register;
- PA-01 through PA-03 and PA-06E/H0 parent contracts and decisions;
- Weekly Menu, Attendance, Planning Input Readiness, and Need Generation contracts;
- H0A3a/H0A3b decisions, tasks, migrations, and focused pgTAP suites;
- the existing TypeScript readiness prototype and tests; and
- the retained OPS v1 observations recorded in Issue #125 and the H0 parent architecture.

The merged upstream evidence establishes stable source roots, positive working versions, immutable approval snapshots, exact snapshot/root/version ownership, immutable snapshot lines, and preservation of prior approval evidence after later versions.

The prototype is non-authoritative. Its generic `PlanningInputReference`, equality-only period check, mutable issue refresh, and invalidation-time source replacement are specifically superseded by this decision.

## 3. Decisions closed

H0A4a selects:

- one stable Planning Input Set root per exact inclusive evaluated period;
- a new immutable positive evaluation version for each permitted evaluation of that root;
- direct typed relational bindings to at most one exact Weekly Menu approval snapshot and at most one exact Attendance approval snapshot;
- full source-period containment of the evaluated period, not period equality;
- immutable evaluation-owned blocking/warning issues and historical queryability;
- the closed `NOT_READY`, `READY`, `NEED_GENERATION_REQUESTED`, `INVALIDATED` lifecycle and complete allowed-transition matrix;
- explicit later command-driven invalidation with no automatic cross-domain triggers;
- the exact blocking and warning classifications in the decision/contract;
- nonblocking visible warnings with acknowledgement explicitly deferred; and
- a handoff-only request state that performs no downstream calculation or materialization.

## 4. Future H0A4b persistence boundary

H0A4b is not authorized by this task. A future issue must specify exact allowed files, migration/rollback effects, physical names, commands, authorization, reasons/events, safe errors, and exact tests.

At minimum, that issue must predeclare three independently runnable pgTAP suites:

| Proposed suite file                                                                             | Exclusive invariant ownership                                                                                                                                                         | Required execution evidence                                                                                                                             |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `supabase/tests/pa_06e_h0a4b_planning_input_readiness_structure_security.sql`                   | schema/constraint presence, positive/unique version structure, direct typed FK structure, RLS/grants/private posture                                                                  | own transaction/fixtures, exact `plan(N)`, `finish()`, rollback, exact-path `supabase test db ... --local`, `Files=1`, exact assertions, `Result: PASS` |
| `supabase/tests/pa_06e_h0a4b_planning_input_readiness_evaluation_source_snapshot_integrity.sql` | exact-period root grain, typed snapshot/root/version ownership, at-most-one binding per type, containment, `READY` bindings, no multi-snapshot coverage, current-evaluation ownership | same independent evidence contract                                                                                                                      |
| `supabase/tests/pa_06e_h0a4b_planning_input_readiness_lifecycle_issues_invalidation.sql`        | full transition matrix, version/pointer behavior, immutable history/issues, exact classifications, request gate, explicit invalidation, no automatic source triggers                  | same independent evidence contract                                                                                                                      |

Every invariant must belong to exactly one suite. The H0A4b issue must replace `N` with one exact assertion count per suite before implementation. H0A4b must add its own files and must not weaken or modify earlier migration tests.

## 5. Allowed files and actual scope

Only the Issue #125 allowlist is changed:

- `docs/decisions/decision-pa-06e-h0a4-planning-input-readiness.md` (new);
- `docs/implementation-tasks/TASK-PA-06E-H0A4a-planning-input-readiness-decision.md` (new);
- `docs/architecture/planning-domain-input-readiness-contract.md`;
- `docs/architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md`;
- `docs/implementation-tasks/TASK-PA-06E-H0-school-catering-persistence-materialization.md`;
- `docs/decisions/decision-register.md`; and
- `docs/architecture/roadmap.md`.

## 6. Prohibited changes confirmed

This task adds no migration, SQL, trigger, function, RPC, RLS policy, role, grant, generated type, API registry entry, event contract, React/runtime behavior, package, hosted Supabase/Retool access, production-data mutation, ingredient calculation, Recipe/BOM edit, Need Generation run, Theoretical Need, Confirmed Need, Procurement rebalance, or warning-acknowledgement mechanism.

## 7. Documentation acceptance

- [x] Root grain and period immutability are explicit.
- [x] Evaluation version/history and exact current pointer are explicit.
- [x] Direct typed source-snapshot binding replaces generic references.
- [x] Containment semantics and one-snapshot-per-type limit are explicit.
- [x] Closed statuses and every valid transition are enumerated; all others are rejected.
- [x] Exact blocking/warning classifications and deferred acknowledgement are explicit.
- [x] Request is a handoff only; H0A5 consumes immutable evidence without editing it.
- [x] Required alternatives are compared and selected.
- [x] Future test-suite ownership and evidence requirements are predefined.
- [x] Parent H0 contract/task, decision register, and roadmap are reconciled.

## 8. Validation record

Local validation on 2026-07-20:

| Command | Result |
| --- | --- |
| `pnpm install --frozen-lockfile` | PASS — lockfile unchanged |
| `pnpm format` | PASS |
| `pnpm typecheck` | PASS |
| `pnpm test` | PASS — 41 files, 265 tests |
| `pnpm build` | PASS — Vite emitted the existing nonblocking large-chunk advisory |
| `git diff --check` | PASS |
| `git diff --cached --check` | PASS after staging the exact seven-file allowlist |

Final local results and exact-head GitHub workflow results are recorded in the draft pull request and Issue #125 evidence comment. GitHub Actions remains the owner of the full routine frontend validation suite.

## 9. Migration and rollback effect

There is no migration or runtime effect. Rollback is documentation-only: revert this bounded documentation commit. No database, hosted service, Retool resource, production row, or downstream document requires reversal.
