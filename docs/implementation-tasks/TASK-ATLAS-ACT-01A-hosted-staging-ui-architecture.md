# TASK-ATLAS-ACT-01A — Hosted Staging and UI Consolidation Architecture

**Status:** Proposed documentation package; implementation and external activation not started

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Architecture:** [ATLAS-ACT-01 Hosted Staging and UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

**Decision registry:** [Decision ATLAS-ACT-01](../decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md)

## 1. Objective

Define the stabilization phase after connected Confirmed Need release and before CMD-03.

The task closes architecture for:

- a separate hosted Atlas staging project;
- strict coexistence with live OPS v1/v2 and Retool;
- environment, credential, migration and staging-data ownership;
- hosted acceptance and operator rehearsal;
- current Atlas UI quality standards and implementation sequence;
- bounded follow-on handoffs for repository staging readiness and shared UI primitives.

It creates no environment and changes no executable application or database behavior.

## 2. Source review completed

### 2.1 Merged repository baseline

The exact merged baseline is:

```text
f3197bb5a7b571378a41ae5056a73a84ad57d583
```

Review covered:

- OPS_SYSTEM_MAP and repository governance;
- PA-06A environment and application-connection contracts;
- PA-06B local Supabase/Auth connection implementation;
- the current roadmap and decision authority;
- Atlas shell, connection modules and shared components;
- connected Planning Inputs through Confirmed Need release;
- Admin workbenches;
- Storybook, UI Review Export and component-test foundations;
- current migrations and exact-head acceptance through RMVP-07B.

Current repository facts relevant to this phase:

- browser environment validation is intentionally local-only;
- the application has connected Admin and Planning surfaces through Confirmed Need release;
- hosted Atlas configuration, staging identities and staging data packages do not exist;
- repeated UI patterns now justify a small shared quality foundation;
- CMD-03 and Purchase Handoff creation remain unimplemented and deferred.

### 2.2 Hosted OPS Supabase

Read-only review on 06/08/2026 confirmed:

```text
project: OPS
reference: qnthofvccilhnefdcxnz
region: ap-southeast-1
status: ACTIVE_HEALTHY
PostgreSQL: 17.6.1.005
atlas_api schema: absent
atlas_confirmed_need_review_runtime: absent
Atlas API functions: 0
```

Current legacy inventory observed:

```text
public tables: 46
ops_v2 tables: 9
total legacy tables: 55
public views/materialized views: 29
ops_v2 views/materialized views: 14
total legacy views/materialized views: 43
public functions: 90
ops_v2 functions: 15
total legacy functions: 105
public RLS-enabled tables: 16
ops_v2 RLS-enabled tables: 0
forced-RLS legacy tables: 0
active Edge Functions: 8
```

Active Edge Function slugs observed:

```text
upsert-daily-order
update-order-dishes
save-assignments
upsert_actual_need_overrides
delete-assignments
sync-dishes-to-gsheet
ops_dishes_sync_gsheet
qa-po-dispatch-email
```

These values are read-only inventory evidence and may change with ongoing OPS v1 operations. The durable architectural fact is that the project is active legacy production and is denied as an Atlas staging target.

No hosted mutation occurred.

### 2.3 Retool evidence

The four retained production exports were reviewed with these exact SHA-256 values:

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

Evidence extracted for UI architecture:

- staff use dense operational tables;
- date, week, school, status and search filters are central;
- inline editing, explicit save, refresh and export actions are common;
- Vietnamese task language and immediate feedback matter;
- exceptions and unresolved rows require fast visibility;
- significant direct SQL/RPC and component-state orchestration exists.

Retool informs operator ergonomics only. The package does not copy direct SQL, direct table access, UI-owned business calculations, hidden state orchestration or Retool page structure.

No Retool mutation occurred.

## 3. Exact documentation manifest

The package contains exactly seven Markdown files:

```text
docs/architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md
docs/decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md
docs/ui/atlas-ui-quality-standard.md
docs/ui/atlas-current-ui-inventory.md
docs/implementation-tasks/TASK-ATLAS-ACT-01A-hosted-staging-ui-architecture.md
docs/implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness.md
docs/implementation-tasks/TASK-UI-QUALITY-01-shared-shell-primitives.md
```

The draft intentionally does not yet modify:

```text
docs/architecture/roadmap.md
docs/decisions/decision-register.md
```

Those central authority files are synchronized only after independent review accepts the exact architecture head, preventing proposed deployment and sequencing choices from appearing accepted prematurely.

## 4. Decisions proposed for acceptance

The package proposes:

1. pause CMD-03 and downstream purchasing expansion;
2. use one separate long-lived Atlas staging project;
3. deny live OPS project `qnthofvccilhnefdcxnz` as an Atlas target;
4. keep Atlas production unselected;
5. require current-cost confirmation immediately before project creation;
6. keep repository migrations as sole schema authority;
7. use a protected GitHub Environment named `atlas-staging`;
8. begin with manual, project-identity-guarded deployment;
9. separate staging identity, reference, Planning-policy and rehearsal packages;
10. use synthetic data by default;
11. deploy no Edge Function in the initial staging/UI phase;
12. consolidate existing React/CSS components without a UI framework dependency;
13. implement shared primitives before module-specific polish;
14. certify the connected Planning path in hosted staging before resuming CMD-03.

## 5. Phase plan

### Gate A — Independent architecture acceptance

- review exact documentation head;
- challenge topology, cost boundary, environment names, seed ownership and UI scope;
- correct material findings only;
- register the accepted decision as the next D-number;
- update the roadmap;
- merge the documentation package.

### Gate B — Repository staging readiness

Implement [TASK-ATLAS-ACT-01B](TASK-ATLAS-ACT-01B-hosted-staging-readiness.md) through Codex from the exact post-architecture `main` SHA.

It prepares:

- environment-aware browser configuration;
- protected GitHub Environment contracts;
- live OPS project denylist;
- manual staging deployment and verification tooling;
- focused tests and a runbook.

It creates or mutates no hosted resource.

### Gate C — Shared UI foundation

Implement [TASK-UI-QUALITY-01](TASK-UI-QUALITY-01-shared-shell-primitives.md) as a separate PR.

It provides:

- semantic CSS tokens;
- shared workbench/state/evidence/dialog/table primitives;
- shell adoption;
- one representative Planning wrapper adoption;
- Storybook and responsive/accessibility evidence.

It changes no business API, lifecycle, migration or dependency.

ATLAS-ACT-01B and UI-QUALITY-01 may proceed in either order after Gate A, but remain separate review units.

### Gate D — External staging activation

After ATLAS-ACT-01B merges:

1. select the Supabase organization;
2. retrieve current project cost;
3. obtain explicit cost confirmation;
4. create the separate staging project;
5. record exact project name, reference, region and health;
6. configure protected GitHub Environment variables and secrets;
7. run guarded migration deployment;
8. verify hosted catalog, Data API, Auth, grants, RLS and browser access;
9. install separately reviewed identity, reference, policy and rehearsal packages.

This gate is performed through Supabase management and protected repository workflows, not by Codex alone.

### Gate E — Planning UI consolidation

Derive and implement UI-QUALITY-02 after the shared primitives are accepted. It covers Weekly Menu, Attendance, Pantry, Readiness, Need Generation and Confirmed Need without changing backend contracts.

### Gate F — Hosted operator rehearsal

Run the Admin-to-Confirmed-Need-release journey plus controlled blocker, stale, capability-denial, inactive-reference and unknown-outcome scenarios.

Record:

- operator findings;
- security findings;
- support and recovery gaps;
- accepted residual risk;
- go/no-go decision for downstream expansion.

### Gate G — Downstream decision

Only after the prior gates may Product/Architecture decide whether CMD-03 should resume.

## 6. Architecture completion criteria

ATLAS-ACT-01A is complete when:

- all seven documents are internally consistent;
- the separate-project topology is accepted;
- the live OPS denylist is accepted;
- environment and protected-name contracts are accepted;
- staging data packages have explicit ownership;
- the UI quality standard and sequencing are accepted;
- the CMD-03 resume gate is measurable;
- central roadmap and decision register are synchronized;
- the documentation PR is merged.

## 7. Testing and validation ownership

Because the package is documentation-only, required CI is limited to repository-owned documentation and frontend checks triggered by the paths:

- formatting;
- workspace verification;
- links/diff where available;
- existing Frontend CI;
- UI Review Export;
- Qodana.

No local Supabase start, reset, pgTAP or browser journey is required because no executable path changes.

## 8. Explicit non-actions

This task performs no:

- hosted project or branch creation;
- cost confirmation;
- migration deployment or hosted linking;
- Auth user creation;
- capability, role or scope binding;
- reference, policy or rehearsal-data installation;
- browser environment implementation;
- GitHub Environment or secret creation;
- React, CSS or Storybook implementation;
- Retool, OPS v1 or OPS v2 change;
- Edge Function deployment;
- production data access or migration;
- production Atlas selection;
- CMD-03, Purchase Handoff, supplier assignment or purchase-order work.

## 9. Review focus

Independent review should challenge:

- whether a separate long-lived staging project is economically justified;
- whether manual guarded deployment is sufficiently safe and not overbuilt;
- whether the environment variable and secret-name sets are minimal;
- whether synthetic data is sufficient for the first rehearsal;
- whether UI-QUALITY-01 is small enough to avoid a design-system rewrite;
- whether the UI standard protects operator usability without freezing every pixel;
- whether the staging and UI gates are objectively measurable;
- whether CMD-03 is deferred long enough to prove usability but not indefinitely.
