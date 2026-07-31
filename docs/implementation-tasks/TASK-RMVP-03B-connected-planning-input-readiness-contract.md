# TASK-RMVP-03B — Connected Planning Input Readiness Contract

- **Status:** Accepted — implementation not started
- **Product Owner approval:** 31/07/2026
- **Baseline:** `70c380f49c148a1207574aabc5aefcb44cf30074`
- **Branch:** `docs/rmvp-03b-connected-readiness-contract`
- **Scope:** Documentation and product-decision work only
- **Canonical accepted decision:** [Decision RMVP-03B](../decisions/decision-rmvp-03b-connected-planning-input-readiness.md)
- **Canonical accepted API registry:** [RMVP-03B Planning Input Readiness API](../api/rmvp-03b-planning-input-readiness.md)
- **Connected architecture:** [RMVP-03B Connected Planning Input Readiness](../architecture/rmvp-03b-connected-planning-input-readiness.md)

## Objective

Close and record the accepted Command/Event and Read Model authority for the
existing Planning Input Readiness business object before any API or React
implementation.

The contract must answer:

> **Có thể yêu cầu tạo nhu cầu cho giai đoạn này không?**

It must preserve the accepted three-source persistence, immutable history,
closed lifecycle, explicit invalidation, handoff-only request, and downstream
non-mutation boundaries.

## Workspace and authority gate

Before mutation, the task verified:

- repository root
  `D:/Project/Repo/OPS/thuonghao-ops-erp`;
- origin
  `https://github.com/longpsu-bot/thuonghao-ops-erp.git`;
- clean worktree;
- exact `origin/main`
  `70c380f49c148a1207574aabc5aefcb44cf30074`;
- proposed branch absent locally and remotely;
- successful `pnpm ops:workspace`; and
- the repository `AGENTS.md`.

The task branch was created directly from the exact approved baseline.

Authority review covered the parent readiness contracts and decisions,
PANTRY-RDY amendments, merged H0A4b/PANTRY-RDY-02 migrations and tests,
RMVP-03A and PANTRY-02 architecture/API/adapters, Planning capabilities and
runtimes, Actor/scope/receipt/event/audit conventions, connected workbench
boundaries, historical null-Pantry behavior, Need Generation handoff and
persistence, and existing API indexes.

## Delivered documentation boundary

Exactly nine Markdown files are authorized and changed.

Created:

1. `docs/architecture/rmvp-03b-connected-planning-input-readiness.md`
2. `docs/api/rmvp-03b-planning-input-readiness.md`
3. `docs/decisions/decision-rmvp-03b-connected-planning-input-readiness.md`
4. `docs/implementation-tasks/TASK-RMVP-03B-connected-planning-input-readiness-contract.md`

Updated:

5. `docs/architecture/planning-domain-input-readiness-contract.md`
6. `docs/architecture/roadmap.md`
7. `docs/decisions/decision-register.md`
8. `docs/decisions/decision-pantry-rdy-02-readiness-persistence.md`
9. `docs/implementation-tasks/TASK-PANTRY-RDY-02-readiness-persistence.md`

No API index is modified. `docs/api/api-contracts.md` and the implemented
PA-06A registry remain outside this exact boundary because the accepted
RMVP-03B surface is not implemented.

## Contract outcome

The accepted documentation defines:

- exact inclusive period selection with Monday week as convenience only;
- exact-period root resolution without School/customer split;
- deterministic zero/one/multiple/stale candidate selection from one
  backend-shaped read, with automatic selection of an exact single candidate;
- one transactional evaluation command;
- one handoff-only Need Generation request command that derives source triples
  from the expected immutable evaluation;
- one explicitly reasoned invalidation command;
- consumed-handoff protection for withdrawal without Need Generation mutation;
- one dedicated authoritative readiness workbench read;
- bounded combined history with one opaque-cursor pagination scheme;
- one new readiness-write capability at most;
- existing `GLOBAL` scope and Planning/read runtimes;
- exact concurrency through root status plus current evaluation ID/version;
- shared receipts, domain events, and audit events;
- one decision-first read model;
- one fourth `Sẵn sàng đầu vào` tab inside `Nguồn kế hoạch`; and
- immutable historical/null-Pantry and downstream non-mutation boundaries.

The complete accepted product registry exists only in the decision document.
The complete accepted function registry exists only in the API document.

## Future implementation ceiling

Product Owner approval on 31/07/2026 establishes planning authority, not
implementation authorization by this task. A later separately authorized
implementation is bounded to at most:

- one migration;
- four `atlas_api` functions;
- one new capability;
- zero relations;
- zero views;
- zero roles or runtime roles;
- zero scope kinds;
- zero automatic source triggers;
- zero new readiness lifecycle states;
- reuse of existing receipts, events, audits, Actor resolution, global scope,
  `atlas_read_runtime`, and `atlas_planning_command_runtime`; and
- integration into the existing Planning Inputs module.

It may not calculate Need, create a Pantry contribution, or mutate any
downstream operational object.

## Acceptance criteria

- The new decision status is `Accepted`, with Product Owner approval recorded
  as 31/07/2026.
- R3B-P01 through R3B-P12 exist completely only in the new decision document.
- The four-function canonical API registry exists completely only in the new
  API document.
- The accepted contract chooses a dedicated readiness read and identifies the
  existing RMVP-03A comparison as non-authoritative for Planning Input Set
  lifecycle.
- Exact source triples, currentness, containment, zero-additions evidence,
  concurrency, receipts, events, audit, failures, and readback are documented.
- The exact five-case candidate matrix is deterministic: zero is `MISSING`,
  exactly one is automatically `SELECTED`, unresolved multiple is
  `AMBIGUOUS`, an exact current supplied choice is `SELECTED`, and a
  no-longer-current prior choice is `STALE`; `AMBIGUOUS` and `STALE` disable
  evaluation.
- The invalidation taxonomy is closed and note requirements are exact.
- `NEED_GENERATION_REQUEST_WITHDRAWN` requires proof that no Need Generation
  run exists for the exact `planning_input_set_id` and current
  `planning_input_evaluation_id`, regardless of run status; consumed handoff
  fails as `NEED_GENERATION_HANDOFF_ALREADY_CONSUMED` and invalidation mutates
  no run.
- The one read defaults `history_limit` to `25`, enforces range `1..50`, uses
  one backend-authored opaque `history_cursor` over a deterministic combined
  history, returns `history_next_cursor`/`history_has_more`, and always returns
  current decision state independently.
- The request payload contains only set ID and exact period; source triples are
  loaded from the expected immutable evaluation and revalidated under lock.
- Vietnamese UX is blocker-first, history-aware, stale-safe, and driven by
  backend `allowed_actions`; exactly one candidate needs no redundant click
  and additional history pages use the same read.
- Historical null-Pantry evaluations remain immutable and cannot authorize a
  new request.
- Request remains a handoff marker and creates no Need Generation run or
  contribution.
- PANTRY-RDY-02 status is corrected to merged through PR #163 at
  `70c380f49c148a1207574aabc5aefcb44cf30074`.
- D-026 remains unchanged and D-027 records the accepted R3B-P01 through
  R3B-P12 connected-readiness boundary.
- Exactly nine Markdown files change.
- `pnpm ops:workspace`, `pnpm format`, and `git diff --check` pass.

## Validation and test ownership

This documentation task creates no SQL or test. Validation is limited to:

```text
pnpm ops:workspace
pnpm format
git diff --check
```

The canonical API contract assigns future test ownership for read shape,
authorization, transactional evaluation, source currentness, lifecycle,
reasons, receipts/events/audits, historical behavior, replay/concurrency,
adapter behavior, Vietnamese UX, and physical downstream non-mutation. It
specifically assigns pgTAP coverage for unconsumed withdrawal, rejection after
any exact-set/evaluation run including invalidated or released runs, and zero
Need Generation mutation by readiness invalidation.

No existing database test is modified.

## Security review

The accepted contract:

- preserves private-schema isolation and forced RLS;
- accepts no browser actor ID, status, issue, count, or source-currentness
  authority;
- reuses exact auth-subject resolution and global scope;
- proposes one readiness-write capability at most;
- adds no role, runtime role, scope kind, policy, grant, or service-role
  browser access in this task; and
- requires commands to revalidate all read evidence under lock.

UI action visibility remains non-authoritative.

## Migration and rollback effect

There is no migration, schema, data, grant, application, hosted, or production
effect. Rollback is a normal Git revert of the nine documentation files.

Any later implementation must define its own additive migration and
forward-only historical preservation rules.

## Exclusions confirmed

This task does not create or modify SQL, migrations, database functions,
public APIs, grants, capabilities, roles, RLS policies, generated types,
React, CSS, tests, workflows, packages, hosted Supabase, production data,
OPS v1/v2, Retool, Need Generation behavior, Pantry contribution, Recipe/BOM
calculation, Theoretical Need, Confirmed Need, Purchase Handoff, Procurement,
Warehouse, Dispatch, or Wholesale state.

It records Product Owner approval and may be published through the guarded PR
workflow. It does not create an implementation issue or authorize
implementation after merge.
