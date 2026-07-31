# TASK-PANTRY-RDY-02 — Pantry-Bound Readiness Persistence

- **Status:** Merged through PR #163 as
  `70c380f49c148a1207574aabc5aefcb44cf30074`
- **Approved baseline:** `9e3f7d6afce1d66757c939645f8d45f99210f20b`
- **Branch:** `backend/pantry-rdy-02-readiness-persistence`
- **Migration:**
  `20260730231951_pantry_rdy_02_readiness_persistence.sql`
- **Decision:**
  [Decision PANTRY-RDY-02](../decisions/decision-pantry-rdy-02-readiness-persistence.md)

## Objective

Bind every new target-state `READY` evaluation and every new Need Generation
request to one exact current approved Weekly Menu, Attendance, and Pantry
snapshot while preserving immutable history, the closed readiness lifecycle,
and the handoff-only boundary.

## Delivered boundary

- exactly three nullable Pantry binding columns;
- one all-null-or-all-present positive-version check;
- one supporting Pantry snapshot ownership unique constraint;
- one composite `ON DELETE RESTRICT` Pantry ownership foreign key;
- one leading partial Pantry binding index;
- two Pantry blocker codes and `PANTRY` issue context;
- in-place replacement of the request and deferred integrity guards;
- no change to the evaluation or issue guards;
- in-place amendment of the three canonical readiness suites;
- fixture-only compatibility updates in the five downstream H0A5/H0B1 suites
  that construct active `READY` evaluations; and
- eight bounded documentation files, including this implementation record.

No relation, view, function, trigger, source trigger, API, capability, role,
runtime role, membership, scope kind, policy, grant, seed, backfill, package,
generated type, React path, or workflow path is added.

The downstream updates add one deterministic current approved zero-line Pantry
snapshot and its explicit evaluation binding per suite. Their plans, business
assertions, contract ownership, Need Generation schemas, and Need Generation
behavior remain unchanged. Full regression requires these operational
`READY` fixtures to satisfy the now-authoritative three-source readiness
contract.

## Acceptance evidence

The test plans change exactly:

| Suite                               |  Before |   After |   Delta |
| ----------------------------------- | ------: | ------: | ------: |
| Structure and security              |      29 |      36 |      +7 |
| Evaluation and source integrity     |      45 |      59 |     +14 |
| Lifecycle, issues, and invalidation |      48 |      57 |      +9 |
| **Readiness total**                 | **122** | **152** | **+30** |

The registered workflow remains 34 unique database suites. Its exact assertion
arithmetic changes from 1,981 to 2,011.

Focused pgTAP proves:

- exact Pantry columns, family constraint, ownership unique/FK, and index;
- zero readiness seed/backfill and zero source-side readiness triggers;
- current positive-line and explicit zero-line approval evidence;
- ownership, current approval, equality/subset containment, and Pantry coverage;
- exact missing/coverage/stale blocker completeness for `NOT_READY`;
- rejection of missing, reopened, stale, superseded, or insufficient Pantry for
  `READY` and request;
- unchanged Menu/Attendance warning derivation;
- queryable immutable null-Pantry history;
- explicit invalidation followed by a Pantry-bound successor evaluation;
- unchanged lifecycle transitions; and
- request handoff without a Need Generation run or downstream write.

The unchanged platform-security suite retains `plan(22)` and the existing
object, privilege, policy, grant, trigger, capability, role, and API totals.

## Security review

The new foreign key is restrictive and has a matching leading index. The
migration grants no privilege and exposes no browser surface. The two replaced
guards preserve `atlas_owner` ownership, invoker security, empty search paths,
and the prior execution revocations. React and public API authority are
unchanged.

## Migration and rollback

The migration is additive and contains no row write. A disposable local
rollback is a rebuild to the prior migration. After operational use, rollback
must be a reviewed forward migration that preserves immutable readiness and
Pantry approval history; no historical evaluation may be rewritten or deleted.

## Exclusions confirmed

The task does not begin RMVP-03B commands/UI or the Pantry Need Generation
amendment. It creates no Need Generation, Theoretical Need, Confirmed Need,
Purchase Handoff, Procurement, Warehouse, Dispatch, Wholesale, hosted
Supabase, production-data, OPS v1/v2, Retool, React, or public API mutation.
