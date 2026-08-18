# TASK-ATLAS-STAGING-ALIGN-01 — Atlas Staging Planning Alignment

**Status:** Accepted — Atlas Staging aligned to accepted repository baseline

**Alignment date:** 2026-08-18

**Authoritative deployed commit:** `6d2a2651f7aebf8e9cdba6a17432a35f9dee31a0`

**Primary disposition:** `ATLAS-STAGING-ALIGN-01 — ATLAS STAGING ALIGNED TO ACCEPTED REPOSITORY BASELINE`

**Next task:** `HOSTED-PLANNING-REHEARSAL-01`

## 1. Boundary and authority

This record closes the bounded hosted schema/API alignment gate after `PLANNING-ACCEPTANCE-01`. It records deployment of the already accepted repository authority to the dedicated Atlas Staging project. It does not add Product behavior, change any business contract, install rehearsal data, certify hosted operator behavior, authorize production, or begin Purchase Handoff/Procurement.

The deployment followed the repository-authoritative [Atlas Staging Deployment Runbook](../runbooks/atlas-staging-deployment.md) and preserved the project method:

```text
OPS_SYSTEM_MAP v1.0
→ workflow-led, contract-constrained, backend-authoritative
→ repository migrations as schema authority
→ exact-head certification before hosted mutation
→ protected Staging deployment
→ read-only platform verification
```

Target project:

```text
Atlas Staging: rnzxmxiiqgtdevzregff
```

Forbidden live OPS target:

```text
qnthofvccilhnefdcxnz
```

## 2. Exact-head certification

The deployed commit was the exact `main` SHA:

```text
6d2a2651f7aebf8e9cdba6a17432a35f9dee31a0
```

The Product Owner verified successful exact-head GitHub Actions evidence before deployment:

- Frontend CI #523 — `Format, typecheck, test, build`: **SUCCESS**.
- Supabase Integration #249 — `Supabase Full Integration`: **SUCCESS**.

The Supabase Full Integration chain passed its mandatory browser-key Planning sequence, including RMVP-04 through RMVP-07, fresh D-037 Save/Release, and `local:planning-contract-01:verify`.

The exact-head certification was obtained during a short Product Owner-authorized public-visibility window because private-repository GitHub Actions were blocked by the account billing/spending limit. This was a one-off infrastructure override, not a change to repository governance or a standing permission to make Atlas public. The repository was returned to **PRIVATE** after the protected deployment.

## 3. Protected deployment

GitHub Actions `Atlas Staging Deploy #3` was manually dispatched for the exact certified commit and completed **SUCCESS**.

The accepted workflow performed:

```text
protected preflight
→ exact-head certification revalidation
→ target/live-OPS guard
→ linked ordered repository migration deployment
→ Data API atlas_api exposure verification
→ read-only platform verification
```

No manual Dashboard DDL, migration repair, direct substitute migration path, Edge Function deployment, or live OPS fallback was used.

## 4. Migration alignment

Pre-deployment Atlas Staging state:

- 33 managed migrations;
- newest version `20260805202517`;
- hosted history was an exact ordered prefix of repository authority.

The deployment applied the exact missing 11 migrations:

1. `20260809120000_planning_contract_01_atomic_planning_boundaries`
2. `20260811011339_confirmed_need_save_release_boundary`
3. `20260811064000_ui_quality_03a_recipe_lock_forward`
4. `20260811064724_ui_quality_03a_recipe_workflow`
5. `20260814010928_ui_quality_03b_recipe_adjustment_operator_workbench`
6. `20260814045038_ui_quality_03b_recipe_adjustment_corrections`
7. `20260814152310_ui_quality_03b_derived_ingredient_units`
8. `20260814205439_ui_quality_03c_a_school_defaults_bulk_editor`
9. `20260815165003_ui_quality_03c_b_authoritative_ingredient_catalogs`
10. `20260817025156_planning_contract_02a_recipe_replacement_evidence`
11. `20260817045218_planning_contract_02b_selective_confirmation_continuity`

Post-deployment invariant:

```text
repository migrations = 44
hosted managed migrations = 44
newest hosted version = 20260817045218
```

No remote-only, duplicate, repaired, malformed, or missing migration was observed.

## 5. Hosted platform result

Fresh read-only post-deployment catalog observation:

- 10 Atlas schemas;
- 103 base tables;
- 2 views;
- 309 total `pg_proc` entries across Atlas schemas;
  - 266 non-trigger functions;
  - 43 trigger functions;
- 90 `atlas_api` functions;
- 602 Atlas policies;
- 103/103 Atlas base tables with forced RLS;
- 0 public base tables;
- 0 Atlas Staging Edge Functions.

These counts are diagnostic observations. The repository's current security-catalog pgTAP remains authority for exact catalog identity, signatures, ownership, roles, grants, RLS posture, policy digest, and the isolated unit-lock policy.

The successful protected deployment also completed the runbook's read-only platform verification, including configured/live `atlas_api` exposure and the expected anonymous authorization denial rather than a schema-cache, missing-function, or transport failure.

## 6. Planning structures now hosted

`PLANNING-CONTRACT-02A` structures are present, including:

- Recipe replacement predecessor/successor selection references on theoretical Need lines;
- the private governed Recipe-replacement removal helper.

`PLANNING-CONTRACT-02B` structures are present, including:

- `atlas_planning.confirmed_need_line_decision_continuity`;
- `atlas_core.planning_contract_02b_removed_business_fact_count(...)`;
- the merged private selective carry/invalidation support required by D-040.

This proves hosted structure alignment only. It does not substitute for the next hosted operator/security rehearsal.

## 7. Data-package boundary

No separate hosted package was installed as part of this alignment:

- no identity package;
- no foundation/reference package;
- no synthetic rehearsal package;
- no production data;
- no copied Retool payload;
- no supplier allocation;
- no Purchase Handoff;
- no purchase order;
- no Warehouse fact;
- no Dispatch fact.

These remain separately governed work.

## 8. Live OPS and Retool isolation

Fresh post-deployment read-only verification of live OPS confirmed:

- 0 Atlas schemas;
- 0 Atlas relations;
- 0 `atlas_api` functions;
- 46 existing public base tables;
- the eight pre-existing OPS Edge Functions remained present and unchanged.

Retained OPS v1 Retool exports were reviewed read-only as context only:

- `OPS - Công thức.json` retains `SystemChangeOrder` and `Nguyên liệu bị ảnh hưởng` operator evidence;
- `OPS - Lên đơn, Đặt hàng (1).json` retains the separate `PurchasePlanner` downstream purchasing surface.

No Retool mutation occurred. Retool SQL/JavaScript remains legacy operational evidence, not Atlas backend authority.

## 9. Acceptance limit

This alignment establishes:

> Atlas Staging is structurally aligned to the accepted repository Planning baseline.

It does **not** establish:

- hosted operator workflow acceptance;
- hosted Actor/capability rehearsal success;
- installed identity/foundation/rehearsal packages;
- production readiness;
- Procurement readiness;
- authorization to begin CMD-03 / Purchase Handoff.

The next gate is therefore:

```text
HOSTED-PLANNING-REHEARSAL-01
```

That task must prove the hosted Admin/Planning operator and security journey through Confirmed Need release before any explicit Product/Architecture decision to expand into Purchase Handoff or downstream Procurement.