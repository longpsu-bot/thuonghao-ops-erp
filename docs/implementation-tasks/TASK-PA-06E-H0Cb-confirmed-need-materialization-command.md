# TASK-PA-06E-H0Cb — Confirmed Need Materialization Command

**Status:** Implemented; focused local validation complete; pending exact-head GitHub Actions and independent governance review

**Issue:** [#143](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/143)

**Baseline:** `7f1132a5fda24912c7c01f81e63877eed390fa71`

**Branch:** `backend/pa-06e-h0cb-confirmed-need-materialization-command`

**Decision:** [Decision PA-06E-H0C](../decisions/decision-pa-06e-h0c-materialization-command-contract.md)

## Objective

Implement the accepted Need Generation → Draft Confirmed Need boundary as one bounded PostgreSQL command slice. The command consumes one exact immutable released generation result and atomically creates or rematerializes one Planning-owned Confirmed Need Batch without adding a read model, decision, approval, release, downstream fact, application change, or hosted action.

## Exact executable catalog

H0Cb creates exactly:

1. `atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb) returns jsonb`;
2. `atlas_api.create_confirmed_needs_from_generation(jsonb) returns jsonb`.

CMD-15 uses:

```text
contract version: PA-06E-H0C.v1
capability: confirmed_need_generation.materialize
authoritative aggregate: Confirmed Need Batch
initial event: ConfirmedNeedsCreated
correction event: ConfirmedNeedsRematerialized
```

The PA-06A canonical registry and physical `atlas_api` catalog both advance atomically from 18 to exactly 19 executable functions. No prior command or read is renumbered.

## Request and bounded response

The exact payload is:

```json
{
  "need_generation_run_id": "uuid",
  "need_generation_run_version": 1,
  "confirmed_need_batch_id": null
}
```

Null batch ID is initial creation; non-null batch ID is direct-successor correction. The response exposes only the run and batch aggregate IDs, their versions, standard event/audit IDs, and exactly seven committed counts:

- created/reused/retired Confirmed Need lines;
- created revisions and revision contributions;
- current revisions;
- superseded revisions.

It exposes no generated line, revision, membership, source, authorization, Menu, Attendance, or Recipe ID arrays.

## Initial materialization

The implementation:

- requires one exact run/version in `RELEASED_FOR_CONFIRMATION` with its immutable release snapshot;
- locks and rereads Admin, typed Recipe/source, Planning Input, generation, release, and Theoretical Need evidence in deterministic order;
- requires a complete nonempty active release, positive quantities, active references, same-customer active destination, and no Unit conversion;
- authorizes the complete active contribution set across `GLOBAL`, exact `CUSTOMER`, `SCHOOL`, or captured `DELIVERY_LOCATION` scope;
- groups by service date + Customer + School + captured destination + Ingredient + Unit;
- creates one `NEED_GENERATION` batch in `DRAFT_REVIEW`, version 1;
- creates one stable line and current Draft revision per group;
- sets theoretical quantity and non-authoritative Draft proposal to the exact PostgreSQL numeric membership sum;
- records complete immutable contribution membership, one completed receipt, one domain event, and one audit event.

## Corrected materialization and history

Correction is allowed only for an exact `NEED_GENERATION` batch in `DRAFT_REVIEW` or `REOPENED`, with exact expected batch version and one direct released successor in the same input set, period, and linear chain.

Every retained group receives a new current Draft revision bound to the new controlled-current source, even when its total is unchanged. Replaced current revisions become `SUPERSEDED` and noncurrent. Exact seven-part stable identities are reused; genuinely new identities create revision 1.

An exact one-to-one predecessor-backed Ingredient correction moves its contribution to the new Ingredient identity without mutating the old line. If that accepted move empties the old group, the old line remains immutable history with no current revision. General removal, split/merge, ambiguous predecessor mapping, Unit conversion, default-destination drift, and proposal carry-forward are rejected.

The batch controlled-current source advances and the batch version increments exactly once. H0Cb never reopens, validates, approves, or releases a batch.

## Runtime and security

`atlas_planning_materialization_runtime` is `NOLOGIN`, `NOINHERIT`, owns only CMD-15, has no schema `CREATE`, no sequence mutation, and is not a member of another runtime.

Its privileges are limited to:

- existing PA-05B auth/authorization/receipt helpers and the private validator;
- exact H0A1–H0A5b source reads and deterministic row locks;
- Confirmed Need insert plus controlled batch current-source/version and revision current/status updates;
- receipt completion and append-only Planning event/audit writes.

It has no Purchase Handoff, Procurement, Evidence, Warehouse, Dispatch, reporting-write, legacy, `public`, or `ops_v2` privilege. RLS policies are verb-specific; no `FOR ALL` or API-role table policy is added. `authenticated` receives execute only on CMD-15; `PUBLIC`, `anon`, and `service_role` do not.

The contribution relation has exactly two `PERMISSIVE` policies, both solely for `atlas_planning_materialization_runtime`: `pa_06e_h0cb_contribution_select` is `SELECT` with `USING (true)`, and `pa_06e_h0cb_contribution_insert` is `INSERT` with `WITH CHECK (true)`. It has no contribution `UPDATE`, `DELETE`, `FOR ALL`, API-role, service-role, PA-05D runtime, or other-runtime policy.

## Limits and failure certainty

Exact limits are 14 inclusive days, 500 Schools, 25,000 active release members, 15,000 operational groups, five-second lock timeout, and 120-second statement timeout. There is no internal retry loop.

Malformed envelope, unresolved/inactive subject, inactive/non-human actor, capability denial, and complete-set scope denial occur before an accepted receipt. Deterministic failures after receipt acquisition persist one `FAILED_NON_RETRYABLE` response and create no domain/audit event. Serialization, deadlock, lock timeout, and statement timeout roll back the transaction and return `RETRYABLE_CONCURRENCY_FAILURE` for exact-request retry.

The implementation supports the common Atlas command errors and all fifteen H0C-specific safe codes fixed by Decision H0C.

## Test ownership

H0Cb adds exactly four pgTAP suites:

| Suite                                  |    Plan |
| -------------------------------------- | ------: |
| Registry, security, runtime, catalog   |      64 |
| Initial materialization                |      80 |
| Corrected materialization and history  |     104 |
| Errors, authorization, and concurrency |     112 |
| **Total**                              | **360** |

The suites execute real CMD-15 initial and corrected transactions with target invariant triggers active. They cover grouping, captured destination, exact totals, immutable membership/history, retained and retired identities, all four scope kinds, deterministic failed receipts, lifecycle/source/identity errors, bounded response/event/audit payloads, replay, grant/policy catalog, limits, and concurrency fences.

Prior behavioral plans and fixtures remain unchanged. Only explicitly identified exact executable API-catalog assertions advance from 18 to 19 and exact signature arrays gain CMD-15. Under the controlling Issue #143 architect amendment, the single H0B1b persistence-only zero-policy assertion is replaced by one exact current-state catalog assertion for the two contribution policies; `plan(52)` and the other 51 H0B1b assertions remain unchanged.

## Validation and CI

Local task validation requires:

- clean-scope review and `pnpm ops:workspace`;
- seedless `supabase db reset --local --no-seed`;
- the affected H0B1b structure/security suite at `52/52` after the contribution-policy transition;
- the four H0Cb suites together at `360/360`;
- exact catalog audit for 19 functions, the two-function H0Cb catalog, runtime owner/flags, execute boundary, policies, and forbidden grants;
- Markdown/SQL formatting checks and `git diff --check`.

GitHub Actions owns the authoritative 23-file, `1498/1498` Supabase Integration regression together with Frontend CI, Qodana, and UI Review Export.

## Rollback and open risk

The migration is additive and no hosted or production action is part of H0Cb. Before operational use, rollback may remove CMD-15, its exact capability, policies/grants, and runtime together. After receipts or Confirmed Need data are created in a deployed environment, rollback requires separately approved data-preserving handling; released operational documents must never be silently recalculated or discarded.

H0Cb intentionally leaves H1 decision evidence, authorized review/preview, validation, approval, release, Purchase Handoff, Procurement, Warehouse, Dispatch, React, hosted Supabase, Retool, and production rollout for separate approval.
