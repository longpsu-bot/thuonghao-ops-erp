# TASK-RMVP-03B-02 — Implement Connected Planning Input Readiness

- **Status:** Implemented on draft PR; pending independent review and merge
- **Product Owner authorization:** 01/08/2026
- **Exact baseline:** `ba949ff1e0641f0439ff4eb3eea43cd623d14959`
- **Branch:** `codex/rmvp-03b-connected-readiness`
- **Migration:** `20260731212845_rmvp_03b_connected_planning_input_readiness.sql`
- **Authorized manifest:** exactly 27 paths
- **Accepted authority:** [Decision RMVP-03B](../decisions/decision-rmvp-03b-connected-planning-input-readiness.md)
- **API contract:** [RMVP-03B Planning Input Readiness API](../api/rmvp-03b-planning-input-readiness.md)
- **Architecture:** [RMVP-03B Connected Planning Input Readiness](../architecture/rmvp-03b-connected-planning-input-readiness.md)

## Objective

Implement R3B-P01 through R3B-P12 as one authoritative connected Planning
Input Readiness capability. PostgreSQL owns candidate selection evidence,
readiness evaluation, lifecycle eligibility, concurrency, receipts, events,
audits, and safe readback. React may coordinate the operator experience only
after the database checkpoint passes.

Pantry Need Generation is outside this task. Requesting Need Generation is a
handoff marker and must not create or mutate a run, contribution, calculated
quantity, Confirmed Need, Procurement, Warehouse, Dispatch, Wholesale, or any
other downstream fact.

## Delivery checkpoints

### Checkpoint A — Database authority

The database/API implementation uses existing readiness roots, evaluations,
issues, source snapshots, Actor/authentication subject resolution, GLOBAL
scope, shared receipts, domain events, audit events, and Need Generation run
evidence. It adds no competing readiness relation or read model.

The exact public surface is:

1. `atlas_api.get_planning_input_readiness_workbench(request jsonb)`
2. `atlas_api.evaluate_planning_input_readiness(request jsonb)`
3. `atlas_api.request_planning_input_need_generation(request jsonb)`
4. `atlas_api.invalidate_planning_input_readiness(request jsonb)`

The read is owned by `atlas_read_runtime`; the three commands are owned by
`atlas_planning_command_runtime`. All four are fixed-search-path
`SECURITY DEFINER`, executable only by `authenticated`, and explicitly denied
to `PUBLIC`, `anon`, and `service_role`.

Migration delta:

- exactly four `atlas_api` functions and no overloads;
- exactly one capability, `planning.input_readiness.write`, with no production
  application-role binding;
- 20 bounded `atlas_core.rmvp_03b_*` `SECURITY INVOKER` helpers with an empty
  search path;
- 12 RLS policies over existing relations;
- least-privilege runtime grants, including read-only Need Generation evidence;
- zero relations, views, roles, runtime roles, scope kinds, lifecycle states,
  triggers, seeds, backfills, or dependencies.

The command runtime can insert and update the readiness root, insert immutable
evaluations and issues, and read the existing shared evidence needed for
authoritative readback. It cannot update or delete evaluations or issues and
has no Need Generation mutation privilege. The read runtime remains
SELECT-only. Browser roles retain zero direct private-relation access and no
runtime receives Atlas schema-creation privilege.

The new focused suite is
`supabase/tests/rmvp_03b_connected_planning_input_readiness.sql` with exact
`plan(84)`. It owns the four APIs, selection matrix, three-source evidence,
authorization, command envelopes, receipts/replay/conflict, events/audits,
invalidation reasons, consumed-handoff protection, history pagination, safe
failures, and API-level downstream non-mutation. The three established
persistence suites retain their exact plans `36`, `59`, and `57`; no existing
persistence invariant has changed.

The whole-platform security catalog remains `plan(22)` and records expected
post-migration totals of 96 ordinary tables, two views/materialized views, 68
physical `atlas_api` functions, 20 capabilities, 445 RLS policies, 146 private
functions, 75 triggers, and nine Atlas database roles. Local synthetic
identity receives the new capability solely for disposable verification.

Checkpoint A passed after a fresh local reset. The exact assertion totals are
`36/59/57` for the established readiness persistence suites, `84` for the
focused RMVP-03B suite, and `22` for the whole-platform security catalog. The
local synthetic-identity provision and assertion passed twice, proving
idempotency. Workspace and whitespace checks passed, and frontend files were
untouched throughout the checkpoint.

### Checkpoint B — Connected React workbench

After Checkpoint A passes, the existing Planning Inputs module receives one
internal `readiness/` submodule and exactly one fourth `Sẵn sàng đầu vào`
tab. It consumes only the authoritative API readback, preserves exact retry
requests without automatic retry, and does not import or modify the obsolete
two-source readiness prototype. The existing Weekly Menu/Attendance
comparison remains visibly non-authoritative.

Checkpoint B implements those boundaries in seven new readiness files and six
existing Atlas integration/style files without adding a navigation item or
dependency. The browser RPC registry is exactly 67 functions. Focused Vitest
passes 47 tests: API adapter `4`, authoritative model `6`, connected workbench
`8`, RPC registry/transport `17`, and Atlas shell integration `12`.

## Receipt, lifecycle, and non-mutation evidence

RMVP-03B uses bounded request validation and hashing helpers instead of
changing the shared PA-05B helper semantics. Exact replay returns the stored
response and identifiers; changed reuse fails as `IDEMPOTENCY_CONFLICT`.
Evaluation supports the accepted absent-root expectation and exact current
evaluation concurrency.

Request performs only `READY` to `NEED_GENERATION_REQUESTED` and derives all
source bindings from the immutable current evaluation. Invalidation performs
only the two accepted transitions and three accepted reason codes. Withdrawal
fails as `NEED_GENERATION_HANDOFF_ALREADY_CONSUMED` whenever an exact
set/evaluation run exists, including generated, invalidated, and released
runs. Independently valid non-withdrawal invalidation may proceed without
mutating that run.

## Migration and rollback

The migration is additive and preserves all existing readiness and downstream
history. It creates functions, capability metadata, policies, and grants only;
there is no data rewrite or backfill.

Rollback is forward-only: add a later migration that revokes the four API
entry points and their grants, removes the 12 policies and bounded private
helpers, and retires the unbound capability only after confirming no retained
receipt, event, audit, or operator dependency requires it. Never edit or
rename the applied timestamped migration, delete immutable history, or roll
back by mutating hosted systems.

## Security and environment review

- Verification is limited to disposable local Supabase.
- Hosted Supabase, OPS v1/v2, Retool, deployed Edge Functions, production data,
  and credentials are not accessed or mutated.
- The new capability is not bound to a production application role.
- Need Generation relations are read as consumption evidence only.
- No API accepts browser-authored Actor identity or authoritative lifecycle,
  issue, count, or source-currentness facts.

## Open work and risks

- Complete independent exact-head product, architecture, security, and CI
  review on the draft pull request.
- Keep the pull request in draft and do not merge it as part of this task.
