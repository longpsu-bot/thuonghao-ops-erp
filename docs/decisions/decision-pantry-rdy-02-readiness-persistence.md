# Decision PANTRY-RDY-02 — Pantry-Bound Readiness Persistence

- **Status:** Implemented and locally validated on the bounded task branch;
  pending draft-PR review and merge
- **Decision date:** 2026-07-31
- **Owner:** Planning
- **Governing decision:** D-026
- **Approved baseline:** `9e3f7d6afce1d66757c939645f8d45f99210f20b`
- **Branch:** `backend/pantry-rdy-02-readiness-persistence`
- **Migration:**
  `20260730231951_pantry_rdy_02_readiness_persistence.sql`
- **Controlling amendment:**
  [PANTRY-RDY-01 Planning Input Readiness Amendment](../architecture/pantry-rdy-01-planning-input-readiness-amendment.md)

## Decision

PANTRY-RDY-02 makes the accepted three-source readiness contract executable
without changing the Planning Input Set grain, lifecycle, warning calculation,
security surface, or downstream handoff boundary.

`atlas_planning.planning_input_evaluations` gains exactly three nullable typed
Pantry fields:

- `pantry_need_batch_id`;
- `pantry_need_batch_version`; and
- `pantry_need_approval_snapshot_id`.

The family is either wholly null or wholly present with a positive version.
When present, one composite `ON DELETE RESTRICT` foreign key binds the exact
snapshot, batch, and approved batch version. The Pantry snapshot relation gains
only the supporting unique ownership triple, and the evaluation relation gains
only the corresponding leading partial index.

Historical evaluations are not backfilled. Their null Pantry fields remain
queryable immutable evidence.

## Readiness and request enforcement

The existing Planning Input Set request guard and deferred readiness-integrity
guard are replaced in place. The evaluation and issue immutability guards are
unchanged.

Every new `READY` evaluation and every new
`READY -> NEED_GENERATION_REQUESTED` transition now requires:

- the exact current approved Weekly Menu snapshot;
- the exact current approved Attendance snapshot;
- the exact current approved Pantry snapshot;
- full evaluated-period containment by all three sources; and
- zero blocking issues.

Current Pantry means the batch is `APPROVED`, its current version equals the
bound approved version, and its latest-approval pointer equals the bound
snapshot. Reopened, superseded, stale, non-current, partially covering, or
missing Pantry evidence fails closed.

Both positive-line approval and explicit zero-line approval are eligible. The
zero-line form remains controlled-absence evidence with
`no_additions_confirmed = true`, `line_count = 0`, and zero snapshot lines. The
readiness guards do not inspect Pantry Purpose, Unit, quantity, supplier,
Warehouse routing, or snapshot-line contents.

## Issue and lifecycle decision

The blocking catalog gains only:

- `MISSING_PANTRY_APPROVAL_SNAPSHOT`; and
- `PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD`.

Issue context gains only `PANTRY`. The shared blockers and three
Menu/Attendance warnings remain unchanged.

The lifecycle remains:

```text
first evaluation -> NOT_READY or READY
NOT_READY -> successor NOT_READY or READY
INVALIDATED -> successor NOT_READY or READY
READY -> NEED_GENERATION_REQUESTED or INVALIDATED
NEED_GENERATION_REQUESTED -> INVALIDATED
```

There is no automatic source invalidation. A historical null-Pantry `READY` or
`NEED_GENERATION_REQUESTED` root must be explicitly invalidated before a
Pantry-bound successor evaluation. A historical null-Pantry evaluation cannot
authorize a new request.

## Security and object delta

PANTRY-RDY-02 adds zero relations, views, functions, triggers, source-side
triggers, APIs, capabilities, roles, runtime roles, memberships, scope kinds,
policies, grants, seeds, backfills, packages, generated types, or application
paths.

The existing four readiness guards remain `atlas_owner` owned,
invoker-security, fixed to an empty `search_path`, and unavailable to
`PUBLIC`, `anon`, `authenticated`, and `service_role`. Existing RLS, policy,
API, role, capability, and grant totals are unchanged.

## Verification decision

The three canonical independently runnable readiness suites remain the sole
test owners:

- structure/security: `29 -> 36`;
- evaluation/source integrity: `45 -> 59`; and
- lifecycle/issues/invalidation: `48 -> 57`.

The readiness total is `122 -> 152`. The registered database workflow remains
34 unique suite files and advances from 1,981 to 2,011 assertions. No fourth
readiness suite or workflow-path change is introduced.

## Migration and rollback

The migration is additive, seeds no row, and performs no backfill. Before
operational use, an unshipped migration can be reverted through a local rebuild
to the prior migration. After use, rollback requires a reviewed forward
migration that preserves immutable readiness and Pantry approval history before
removing the binding constraint, foreign key, index, and columns. Historical
evidence must never be deleted or rewritten.

## Exclusions

PANTRY-RDY-02 creates no command or UI for RMVP-03B, Pantry Need Generation
contribution, Recipe/BOM calculation, Need Generation run, Theoretical Need,
Confirmed Need, Purchase Handoff, Procurement, Warehouse, Dispatch, Wholesale,
hosted Supabase mutation, production-data mutation, OPS v1/v2 mutation, or
Retool mutation.
