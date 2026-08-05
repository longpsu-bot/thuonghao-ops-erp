# TASK-RMVP-07B — Connected Confirmed Need Approval and Release

## Status

Implemented on branch `codex/rmvp-07b-connected-confirmed-need-approval-release` from exact accepted baseline `c871a8f08867377e921ced865c258040107d6628`. Local validation is recorded below; draft pull-request validation remains authoritative for the routine full frontend gate.

## Outcome

RMVP-07B connects the accepted `NEED_GENERATION` lifecycle as two separate complete-batch Planning commands:

```text
VALIDATED → APPROVED → RELEASED_FOR_PURCHASE_HANDOFF
```

Approval binds one exact immutable RMVP-06 success to one every-and-only approval snapshot. Release binds that exact approval to one immutable Planning release for later CMD-03 consumption. Release creates no Purchase Handoff and no downstream operational fact.

## Exact changed-path manifest

```text
.github/workflows/supabase-integration.yml
package.json
docs/api/api-contracts.md
docs/api/rmvp-07-connected-confirmed-need-approval-release.md
docs/architecture/roadmap.md
docs/implementation-tasks/TASK-RMVP-07B-connected-confirmed-need-approval-release.md
scripts/verify-local-rmvp07-confirmed-need-approval-release.mjs
src/modules/atlas/connection/atlasRpc.test.ts
src/modules/atlas/connection/atlasRpc.ts
src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx
src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx
src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.test.ts
src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts
src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel.ts
src/modules/atlas/planning-inputs/confirmed-needs/reviewConfirmedNeedApi.ts
supabase/local/rmvp_06_browser_fixture.sql
supabase/migrations/20260805202517_rmvp_07_connected_confirmed_need_approval_release.sql
supabase/tests/atlas_current_platform_security_catalog.sql
supabase/tests/pa_06e_h0b1b_confirmed_need_structure_security_catalog.sql
supabase/tests/pa_06e_h1a_planning_quantity_policy_structure_security.sql
supabase/tests/pa_06e_h1b1_line_decision_structure_security.sql
supabase/tests/pantry_ng_02_direct_ingredient_persistence_materialization.sql
supabase/tests/rmvp_03b_connected_planning_input_readiness.sql
supabase/tests/rmvp_04_connected_need_generation.sql
supabase/tests/rmvp_06_connected_confirmed_need_validation.sql
supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql
```

No accepted RMVP-07A architecture or decision document changed.

## Migration and object delta

One forward migration adds:

- exactly two public `atlas_api` functions and 12 private support/integrity functions; the existing RMVP-05 read function is replaced in place with additive shaping;
- exactly one private relation, `atlas_planning.confirmed_need_releases`;
- three additive approval-snapshot columns, two additive batch authority pointers, source-qualified keys, and the exact WHOLESALE/NEED_GENERATION pointer constraints;
- seven explicit supporting indexes, seven integrity/immutability triggers, and 15 exact runtime RLS policies;
- one lifecycle-neutral canonical projection/fingerprint, immutable evidence, deterministic locks, receipts, events, audits, and authoritative readback.

The delta is exactly two APIs and two active unbound capabilities. It adds zero database roles, runtime roles, application roles, scope kinds, lifecycle states, views, materialized views, sequences, production bindings, source triggers, or downstream facts.

## Historical current-catalog reconciliation

A fresh seedless reset proved eight historical exact-current-catalog expectations stale. RMVP-06 expected six select/insert policies across its three validation evidence relations; RMVP-07 correctly adds one update-denying immutability-lock policy to each, so the actual and expected count is now nine. H1B1 expected two policies on its decision relation and 77 public APIs; RMVP-07 adds one update-denying immutability-lock policy there and exactly the two accepted APIs, so those exact expectations are now three and 79 and the two RMVP-07 names are asserted explicitly. H1A's final whole-API count is likewise updated to 79 with the exact two new names asserted. H0B1B's exact contribution-policy catalog now includes the named RMVP-07 update-denying immutability lock. RMVP-03B's current-catalog sentinels now assert the exact RMVP-07 relation, capabilities, and APIs alongside the unchanged RMVP-06 identities. RMVP-04's relation sentinel now names the one RMVP-07 release relation alongside the three RMVP-06 evidence relations. Pantry-NG's closed whole-platform sentinels now enumerate every RMVP-07 relation, private helper, capability, policy, API, ordinary trigger, and deferred trigger beside the unchanged RMVP-06 catalog. The whole-platform catalog pins the same exact identities, counts, and digests. All eight suites retain their original plans and all historical behavior/equality assertions. No pattern-based relaxation or security weakening was introduced.

## Application and local fixture

The existing sixth Vietnamese Planning Inputs tab registers both commands and displays only backend-authorized actions:

```text
Phê duyệt lô nhu cầu
Đã phê duyệt; chờ phát hành
Phát hành sang bước lên đơn
Đã phát hành sang bước lên đơn
```

Approval and release use separate explicit confirmations. Release states that it neither selects suppliers nor creates a purchase order. The workbench shows Actor/time, retained warning count, lifecycle history, and backend disabled codes/messages. It refreshes authoritative readback after writes, discards late results after batch/reload/edit/new intent, never automatically retries, and requires a refresh after an unknown mutation outcome.

The existing `rmvp_06_browser_fixture.sql` is minimally extended to bind validation, approval, and release capabilities to the disposable synthetic role. No second RMVP-07 fixture exists and no production binding is added.

## Security and WHOLESALE compatibility

The two security-definer APIs retain an empty search path and are executable only by `authenticated`; `PUBLIC`, `anon`, and `service_role` are revoked. JWT Actor, active human status, active `GLOBAL` scope, and separate capability checks remain backend-authoritative. Forced RLS, browser table denial, narrow runtime grants, immutable rows, and deferred ownership/pointer checks protect lifecycle evidence.

PA-05D WHOLESALE remains the accepted alternative family: it may be released at version 1, its approval snapshot uses `source_kind = WHOLESALE` with null validation binding/fingerprint, it requires neither RMVP-07 pointer nor release row, and its existing Purchase Handoff/downstream behavior is unchanged.

## Verification record

Completed locally:

- fresh seedless migration rebuild through the final RMVP-07 source and a final fixture-clearing reset;
- all 51 database-suite files registered in the Full Integration workflow, including current-platform catalog 22/22, H1B1 64/64, PA-05D 69/69, RMVP-05 41/41, PA-05G 78/78, and current-command-context 35/35;
- RMVP-07 exact `plan(67)` — 67/67 passing;
- RMVP-06 compatibility `plan(65)` — 65/65 passing;
- database lint passing with no RMVP-07 finding and only four pre-existing immutable/stable warnings;
- authenticated browser-key approval, exact replay, release, exact replay, authoritative readback, and zero downstream delta;
- focused Atlas RPC/API/workbench Vitest — 45/45 passing;
- full Vitest — 66 files and 386/386 tests passing;
- workspace identity, Prettier format check, TypeScript typecheck, production build, and `git diff --check` passing.

CI remains authoritative for the routine frozen install/format/typecheck/test/build gate and the draft/full Supabase journeys.

## Migration and rollback effects

The migration is local-only in this task and is not deployed. It preserves existing records by defaulting pre-existing approval snapshots to `WHOLESALE`, then applies source-qualified integrity. New approval/release evidence is append-only and intentionally undeletable.

Rollback is forward-only. A corrective migration must first prove that no `NEED_GENERATION` batch points to approval/release evidence and that no later consumer depends on `confirmed_need_releases`; it may then remove additive read/API grants, triggers/policies, pointers/constraints, relation, helpers, and unbound capabilities. Rewriting or deleting committed lifecycle evidence is not an ordinary rollback path.

## Exclusions and open risk

Reopen, CMD-03, Purchase Handoff creation, Procurement/Warehouse/Dispatch changes, supplier selection, purchase orders, hosted Supabase, production data or capability binding, Retool, credentials, Edge Functions, rollout, and deployment remain excluded.

The principal remaining delivery risk is external validation: GitHub Actions and product/architecture review must pass before the draft PR is ready for merge. This task does not merge the PR.
