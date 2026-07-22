# TASK-PA-06E-H0Ca — Materialization Command Contract

**Status:** Architect-owned documentation implementation in progress

**Issue:** [#137](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/137)

**Baseline:** `68edd07527697113bd9d6c5306d917b66adb88ce`

**Branch:** `docs/pa-06e-h0ca-materialization-command-contract`

**Decision:** [Decision PA-06E-H0C](../decisions/decision-pa-06e-h0c-materialization-command-contract.md)

## Objective

Close the command, authorization, runtime, limits, events, audit, receipt, safe-error, and future test-ownership decisions required before implementing the Need Generation to Draft Confirmed Need materialization boundary.

This task is documentation only. It changes no PostgreSQL, Supabase, Retool, application code, generated type, package, credential, deployment, or production data.

## Architectural correction

PA-06A is the canonical registry of executable application functions. H0Ca does not add a planned-but-unimplemented function to that registry.

H0Ca reserves the next identity and accepts its complete pre-implementation contract:

```text
CMD-15
atlas_api.create_confirmed_needs_from_generation(jsonb)
PA-06E-H0C.v1
confirmed_need_generation.materialize
```

The canonical and physical boundary remains exactly 18 functions during H0Ca. H0Cb must implement, secure, test, and append CMD-15 to PA-06A in the same change, transitioning both the registry and database to 19 together.

## Delivered architecture scope

- Reserve CMD-15 without renumbering CMD-01 through CMD-14 or READ-01 through READ-04.
- Accept the exact request, success fields, safe errors, events, version semantics, replay behavior, and failure certainty in the H0C decision.
- Select active authenticated HUMAN Planning actors for v1.
- Require complete-set authorization across GLOBAL, CUSTOMER, SCHOOL, or DELIVERY_LOCATION scopes.
- Select deterministic destination capture from the School's valid same-customer default location.
- Prevent corrected materialization from silently following later default-location changes.
- Close initial and corrected materialization behavior against merged H0A5/H0B1 persistence.
- Preserve seven-part stable identity, no-conversion grouping, immutable revision membership, exact totals, and current-release partition enforcement.
- Select `atlas_planning_materialization_runtime` as the dedicated least-privilege runtime.
- Preserve the PA-05D runtime and its four functions exactly.
- Close hard size and timeout limits.
- Close receipt, replay, deterministic failure, event, and audit behavior.
- Reserve four focused H0Cb test families without assigning assertion counts.

## Registry state

During H0Ca:

```text
PA-06A canonical registry = 14 writes + 4 reads = 18
physical atlas_api surface = 18
reserved next identity = CMD-15
```

At successful H0Cb merge:

```text
PA-06A canonical registry = 15 writes + 4 reads = 19
physical atlas_api surface = 19
```

H0Cb must prove those values at one exact head. It must not publish a registry entry without the executable secured function or deploy a function without its canonical entry.

## Security boundary

The future runtime is `NOLOGIN`, `NOINHERIT`, owns only CMD-15, has no schema `CREATE`, no sequence mutation, and is not a member of another runtime.

It may later receive only narrow helper, source-read, Confirmed Need write, event, and audit privileges. It receives no Purchase Handoff, Procurement, Evidence, Warehouse, Dispatch, Storage, reporting-write, `public`, `ops_v2`, Retool, or legacy privilege.

`authenticated` may later receive execute only on the implemented CMD-15 signature after revoke-first hardening. `PUBLIC`, `anon`, and `service_role` receive no execute. API roles retain no direct private-relation access.

## Accepted hard limits

| Limit | Value |
|---|---:|
| Inclusive run period | 14 days |
| Distinct Schools | 500 |
| Active release members | 25,000 |
| Operational groups | 15,000 |
| Lock timeout | 5 seconds |
| Statement timeout | 120 seconds |

No internal retry loop is approved.

## Future H0Cb boundary

H0Cb may implement only the accepted command contract through a bounded migration and focused pgTAP. It may add the exact function, capability, dedicated runtime, minimum grants and policies, request validator/helper code where justified, receipt/event/audit behavior, and the canonical PA-06A CMD-15 entry.

H0Cb must not add a read surface, Planning policy, decision evidence, validation, approval, release, Purchase Handoff, Procurement, Warehouse, Dispatch, React, Retool, hosted execution, or production data.

## Future test ownership

H0Cb owns exactly four independent families:

1. canonical registry, request validator, capability, runtime, grants, policies, and forbidden surfaces;
2. initial materialization, grouping, exact quantities/membership, response, receipt/event/audit, replay, and limits;
3. corrected materialization, stable-line reuse/new identity, Ingredient move, immutable history, source advancement, and one-version increment;
4. safe errors, authorization/scope, removal/zero/split/merge/conversion/downstream blockers, stale state, and concurrency.

The H0Cb issue must fix exact `plan(N)` values before implementation.

## Documentation scope

This task creates only:

- `docs/decisions/decision-pa-06e-h0c-materialization-command-contract.md`;
- `docs/implementation-tasks/TASK-PA-06E-H0Ca-materialization-command-contract.md`.

It intentionally leaves the PA-06A executable registry and roadmap unchanged until H0Cb changes executable status.

No SQL, pgTAP, workflow, TypeScript, React, package, lockfile, generated type, Retool export, OPS v1 artifact, credential, or deployment file belongs in H0Ca.

## Validation and publication

GitHub Actions owns full repository validation. Documentation review must prove:

- the H0C decision contains one complete reserved CMD-15 contract;
- PA-06A and the physical API remain exactly 18 during H0Ca;
- H0Cb alone owns the atomic transition to 19;
- existing command/read IDs are unchanged;
- H0C decisions are closed without executable scope;
- PA-05D behavior is unchanged;
- hosted Supabase and Retool are untouched.

## Exclusions

H0Cb, H1A, H1B1, H1B2, application connection, validation, approval, release, Purchase Handoff, Procurement, Warehouse, Dispatch, QA, Production, Finance, hosted deployment, and production rollout are not started by H0Ca.

Documentation rollback is a normal Git revert.
