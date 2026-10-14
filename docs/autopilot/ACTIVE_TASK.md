# Atlas Autopilot — Active Task

Task: ATLAS-PXK-EXACT-SCHOOL-SCOPE-01
Status: APPROVED — bounded implementation in progress
Navigator: Terra/read-only role
Implementer: Sol 6.1
Starting main: fbafca0cb404231e5930df079703f869fb9b29fb
Atlas Staging: rnzxmxiiqgtdevzregff — migration 108; no hosted probes or deployment by implementer
OPS v1 / Retool: strict no-write

## Accepted authority

The Product Owner approved exact-School PXK scope on 14 October 2026 and clarified one staff member per task. [ATLAS-PXK-EXACT-SCHOOL-SCOPE-01](../decisions/decision-atlas-pxk-exact-school-scope.md) records the accepted interpretation before runtime implementation. `SCHOOL` matches only the target School ID; a shared default location grants no other School's authority.

One Actor may hold the existing task read/release capabilities and explicit scopes for multiple Schools. No two-person rule, new role/capability, actual staff membership change or automatic GLOBAL grant is introduced. Existing `DELIVERY_LOCATION`, location-derived `CUSTOMER`, `GLOBAL`, scope status and effective-time semantics remain unchanged.

## Scope and allowed files

- One forward SQL migration after 108: replace the existing private Dispatch scope helper's SCHOOL branch and route PXK base-workbench/reconciliation row filters through it. Release already uses it.
- `supabase/tests/school_dispatch_release.sql` and `school_fulfilment_reconciliation.sql`: authenticated rollback cases and existing fixture reuse. Relevant PO and security/catalog regression checks may be adjusted only for exact intended catalog fingerprints; counts and grants must stay unchanged.
- This baton, accepted decision/register, affected Dispatch/reconciliation API contracts and migration-108 decision compatibility addendum. Record accurate evidence/readiness without rewriting historical 108 acceptance.
- No UI, dependency, runtime configuration, general framework, unrelated source or hosted data changes.

Preserve helper signature, owner, SECURITY DEFINER, empty search path, ACL/RLS and existing read/Dispatch runtimes. Stop on an unexpected permission gap rather than broaden grants. Do not alter shared school-catering/generic authorizers, whole-PO authorization, Preparation GLOBAL, document grouping, snapshots, lifecycles or numbering.

## Required validation

Write failing authenticated RPC rollback tests before runtime changes, then prove:

1. School A scope allows A and denies B sharing location L across PXK read/reconciliation/release; wrong-scope release writes no receipt/document/event.
2. The same Actor with both existing capabilities and explicit A+B scopes operates both Schools, with release attribution to that Actor and no handoff.
3. Each missing capability denies access; explicit L/Customer/GLOBAL scope behavior remains valid.
4. Wrong location, cross-Customer, inactive/revoked/expired/future scopes fail closed.
5. Default changes cannot confer B; exact A keeps captured historical location and frozen PXK content.
6. Replay, immutable numbering, successor/currentness and Preparation/whole-PO regression remain unchanged.
7. Focused Dispatch/reconciliation/PO/catalog suites pass; catalog counts/grants and security posture remain exact; exact-head CI and independent Terra review pass.

Use only a newly created disposable local database for development; preserve pre-existing volumes. No timeout increase or hosted probe rerun merely for evidence.

## Delivery and gates

One bounded branch and one Draft PR from latest main. Push a fixed SHA with RED/GREEN logs and focused counts for independent review. No merge/deployment by implementer; protected Staging migration/rollback acceptance requires a later reviewed plan and clearance. OPS v1/Retool, Production, real supplier/PXK commitments and Warehouse remain excluded.

Previous correction ATLAS-AUTH-SCOPE-ALIGNMENT-01 was merged/deployed at `d254c099098a1f004f4eaaf78092f1aab9c32bd3` and passed 43 hosted rollback checks with zero persistent probes. [PR #381](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/381) recorded acceptance and merged at the starting main above after independent review and exact-head Frontend/Full Integration passed. See [migration 108 evidence](../testing/atlas-auth-scope-alignment-staging-108.md). This new task implements the separately approved policy.
