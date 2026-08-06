# TASK-ATLAS-ACT-01A — Hosted Staging and Connected-UI Architecture

**Status:** Complete and accepted; executable work and external activation not started

**Accepted on:** 06/08/2026

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Architecture:** [ATLAS-ACT-01 Hosted Staging and Connected-UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

**Decision:** [Decision ATLAS-ACT-01](../decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md)

## 1. Objective

Define the stabilization phase after connected Confirmed Need release and before CMD-03.

The task closes architecture for:

- a separate hosted Atlas staging project;
- strict coexistence with live OPS v1/v2 and Retool;
- minimal environment, credential, migration and staging-data ownership;
- reuse of exact-head CI rather than duplicated deployment testing;
- connected Admin and Planning UI quality standards;
- bounded handoffs for repository staging readiness and shared UI foundations.

It creates no environment and changes no executable application or database behavior.

## 2. Source review

### Repository

The exact baseline is:

```text
f3197bb5a7b571378a41ae5056a73a84ad57d583
```

Review covered:

- OPS_SYSTEM_MAP and repository governance;
- PA-06A environment/connection authority;
- the local Supabase/Auth connection implementation;
- current migrations and exact-head acceptance through RMVP-07B;
- connected Planning Inputs through Confirmed Need release;
- connected Admin workbenches;
- shell, shared components, Storybook, UI Review Export and component tests.

### Hosted OPS Supabase

Read-only review on 06/08/2026 confirmed:

```text
project: OPS
reference: qnthofvccilhnefdcxnz
region: ap-southeast-1
status: ACTIVE_HEALTHY
PostgreSQL: 17.6.1.005
atlas_api schema: absent
Atlas Confirmed Need runtime: absent
Atlas API functions: 0
legacy tables: 55
legacy views/materialized views: 43
legacy public/ops_v2 functions: 105
active legacy Edge Functions: 8
```

The durable conclusion is that the active legacy project is denied as an Atlas target. No hosted mutation occurred.

### Retool

Reviewed production export hashes:

```text
OPS - Admin (in production).json
  a6d74ca01f7942687e8639ffef73dba5a89c6bcbf653f9454011cec551549350
OPS - Công thức.json
  b38c86ac3b1fed985f6bc07d91c0708cf5aacccc682434ba2498960d1da1b809
OPS - Nguyên liệu và Nhà cung ứng.json
  2fb973cbd6a3900252aa9037a1d4d197551bccc93db60e36512d97f27d903648
OPS - Lên đơn, Đặt hàng (1).json
  6f6ff8d025696d375f354a86126661d20c3e9908d6475d40ecb14ee006b4a371
```

Retool supports the need for dense operational tables, fast filters, explicit save/refresh actions, visible exceptions and concise Vietnamese language. It remains usability evidence only; direct SQL and UI-owned business logic are not copied.

## 3. Exact documentation manifest

```text
docs/architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md
docs/decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md
docs/ui/atlas-ui-quality-standard.md
docs/ui/atlas-current-ui-inventory.md
docs/implementation-tasks/TASK-ATLAS-ACT-01A-hosted-staging-ui-architecture.md
docs/implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness.md
docs/implementation-tasks/TASK-UI-QUALITY-01-shared-shell-primitives.md
docs/architecture/roadmap.md
docs/decisions/decision-register.md
```

The first seven files hold the architecture and handoffs. The roadmap and decision register synchronize accepted D-032 and the stabilization sequence.

## 4. Accepted decisions

1. pause CMD-03 until staging and connected UI acceptance;
2. use one separate long-lived Atlas staging project;
3. deny the live OPS project as an Atlas target;
4. keep Atlas production unselected;
5. require current-cost confirmation before project creation;
6. use repository migrations only;
7. use protected manual deployment initially;
8. deploy only an exact `main` SHA already certified by Frontend CI and Supabase Full Integration;
9. do not rerun the same Full Integration suite inside deployment;
10. use three minimal staging data packages: identity, foundation and rehearsal;
11. use synthetic data by default;
12. deploy no Edge Function in the first staging/UI phase;
13. polish only connected Admin and Planning surfaces;
14. add no external UI framework or speculative design system;
15. introduce shared primitives only after proven repetition;
16. rehearse the complete current connected journey before deciding on CMD-03.

## 5. Follow-on gates

### Gate B — Repository staging readiness

Implement [TASK-ATLAS-ACT-01B](TASK-ATLAS-ACT-01B-hosted-staging-readiness.md) through Codex from the exact post-architecture `main` SHA.

It prepares configuration, project guards, a protected manual deployment workflow, hosted verification and a runbook. It creates or mutates no hosted resource during implementation.

### Gate C — Shared UI foundation

Implement [TASK-UI-QUALITY-01](TASK-UI-QUALITY-01-shared-shell-primitives.md) as a separate PR.

It adds semantic tokens and only proven shared primitives, then adopts them in the shell and one Planning wrapper. It changes no business API, lifecycle, migration or dependency.

ATLAS-ACT-01B and UI-QUALITY-01 may proceed in either order.

### Gate D — External staging activation

After ATLAS-ACT-01B merges:

1. select the Supabase organization;
2. retrieve current project cost;
3. obtain explicit confirmation;
4. create the separate staging project;
5. configure the protected GitHub Environment;
6. deploy an exact certified `main` SHA;
7. verify hosted catalog, Data API, Auth, grants and RLS;
8. install separately reviewed identity, foundation and rehearsal packages.

### Gate E — Connected UI consolidation

- UI-QUALITY-02: Weekly Menu, Attendance, Pantry, Readiness, Need Generation and Confirmed Need;
- UI-QUALITY-03: Schools, Ingredients/Suppliers and Dishes/Recipes.

Unconnected downstream prototypes remain deferred.

### Gate F — Hosted rehearsal and downstream decision

Run the Admin-to-Confirmed-Need-release journey plus blocker, stale, denied-capability, inactive-reference and unknown-outcome scenarios. Resolve material findings, record accepted residual risk and then decide whether CMD-03 may resume.

## 6. Completion evidence

ATLAS-ACT-01A is complete because:

- the architecture, decision, UI standard, inventory and handoffs are internally consistent;
- separate staging and live OPS denial are explicit;
- environment and credential names are minimal;
- deployment reuses exact-head certification;
- staging packages have clear ownership;
- UI scope is limited to connected Admin and Planning;
- shared abstraction follows the two-use rule;
- CMD-03 resume criteria are measurable;
- central authority is synchronized;
- the package remains documentation-only.

## 7. Validation ownership

Because this package is documentation-only:

- formatting, links/diff and repository workspace checks apply;
- existing Frontend CI, UI Review Export and Qodana may run by path policy;
- local Supabase, pgTAP and browser journeys are intentionally unnecessary.

## 8. Explicit non-actions

No:

- hosted project or branch creation;
- cost confirmation;
- migration deployment or hosted linking;
- Auth user, role, scope or capability binding;
- seed installation;
- React, CSS or Storybook implementation;
- Retool or OPS v1/v2 change;
- Edge Function deployment;
- production data access or migration;
- production Atlas selection;
- CMD-03, Purchase Handoff, supplier assignment or purchase-order work.
