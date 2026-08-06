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

## 2. Source review completed

### Hosted OPS Supabase

Read-only review confirmed:

- project `OPS`, reference `qnthofvccilhnefdcxnz`;
- `ACTIVE_HEALTHY`, region `ap-southeast-1`;
- PostgreSQL `17.6.1.005`;
- no `atlas_api` schema;
- no Atlas Confirmed Need runtime;
- zero Atlas API functions;
- legacy `public` and `ops_v2` application schemas;
- 47 application tables and 108 application functions;
- zero deployed Edge Functions.

No hosted mutation occurred.

### Retool

The four retained production app exports were reviewed. They contain significant direct SQL/RPC, `ops_v2` and component-state orchestration. They are retained as operational evidence and remain unchanged.

No Retool mutation occurred.

### Repository

The exact merged baseline was confirmed. Review covered:

- PA-06A environment and connection authority;
- PA-06B local connection implementation;
- current roadmap and decision register;
- UI catalogue and workbench requirements;
- Atlas shell, connection foundation and shared components;
- Planning Inputs and Confirmed Need modules;
- Admin workbenches;
- common styling, Storybook and UI Review Export;
- merged migration and CI acceptance through RMVP-07B.

### Current Supabase platform guidance

Current official Supabase deployment guidance was checked for:

- separate staging and production projects;
- migration-based environment management;
- CI/CD deployment requirements;
- protected access token, project reference and database-password use;
- optional preview branching rather than mandatory branching;
- explicit Data API exposure/grants on new projects.

No repository or platform feature was implemented from documentation without a separate implementation review.

## 3. Proposed documentation manifest

This package creates:

```text
docs/architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md
docs/decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md
docs/ui/atlas-ui-quality-standard.md
docs/ui/atlas-current-ui-inventory.md
docs/implementation-tasks/TASK-ATLAS-ACT-01A-hosted-staging-ui-architecture.md
docs/implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness.md
docs/implementation-tasks/TASK-UI-QUALITY-01-shared-shell-primitives.md
```

The initial draft does not modify the central roadmap or decision register. Those files should be updated only after Product/Architecture acceptance of this exact package, so the repository does not mark proposed environment and sequencing choices as accepted prematurely.

## 4. Phase plan

### Gate A — Accept architecture

- independent review of the exact documentation head;
- resolve environment, secret-name, UI-scope and sequencing findings;
- mark decisions accepted;
- register the next D-number and update roadmap;
- merge the documentation package.

### Gate B — Repository staging readiness

Implement [TASK-ATLAS-ACT-01B](TASK-ATLAS-ACT-01B-hosted-staging-readiness.md) through Codex from the exact post-architecture `main` SHA.

This gate prepares:

- environment-aware browser configuration;
- protected GitHub Environment contract;
- project-reference denylist;
- manual staging deployment/verification workflow;
- safe runbook and tests.

It creates no hosted project and performs no deployment.

### Gate C — Shared UI primitives

Implement [TASK-UI-QUALITY-01](TASK-UI-QUALITY-01-shared-shell-primitives.md) through Codex as a separate PR.

This gate introduces local tokens and components, proves them in the shell and a representative Planning wrapper, and changes no business API or lifecycle behavior.

ATLAS-ACT-01B and UI-QUALITY-01 may proceed in either order after architecture acceptance, but should remain separate PRs.

### Gate D — External staging activation

After ATLAS-ACT-01B merges:

1. retrieve current project cost for the intended organization;
2. obtain explicit cost confirmation;
3. create the separate staging project;
4. record exact project reference, name, region and health;
5. configure protected GitHub Environment values;
6. run local acceptance and manual migration deployment;
7. verify hosted catalog, Auth, RLS and browser read path;
8. install separately reviewed staging identity/reference/policy/rehearsal packages.

This gate is performed through Supabase management tools and protected workflows, not by Codex alone.

### Gate E — Planning UI consolidation

UI-QUALITY-02 migrates the connected Planning tabs to accepted primitives and standards.

### Gate F — Hosted operator rehearsal

Run the complete Admin-to-Confirmed-Need-release journey plus controlled failure scenarios. Record operator findings, security findings and accepted residual risk.

### Gate G — Downstream decision

Only after all gates above may Product/Architecture decide whether CMD-03 should be the next capability.

## 5. Architecture completion criteria

ATLAS-ACT-01A is complete when:

- the proposed documents are internally consistent;
- the separate-project decision is accepted;
- the live OPS project denylist is accepted;
- environment and protected-secret names are accepted;
- staging data and identity packages have explicit ownership boundaries;
- UI quality standard and sequence are accepted;
- the CMD-03 deferral gate is accepted;
- central roadmap and decision register are synchronized;
- the documentation PR is merged.

## 6. Explicit non-actions

This task performs no:

- hosted project or branch creation;
- cost confirmation;
- migration deployment;
- Auth user creation;
- capability or scope binding;
- reference, policy or rehearsal-data seed;
- browser environment configuration;
- GitHub secret/environment creation;
- React or CSS implementation;
- Retool or OPS v1/v2 change;
- Edge Function deployment;
- production data access;
- CMD-03, Purchase Handoff, supplier assignment or purchase-order work.

## 7. Review focus

Reviewers should specifically challenge:

- whether a separate staging project is the correct economic and operational choice;
- whether the denylist and manual-deployment gates are sufficient;
- whether secret and variable names are minimal and safe;
- whether synthetic data is sufficient for first rehearsal;
- whether the UI standard is too broad or too prescriptive;
- whether UI-QUALITY-01 is small enough to implement safely;
- whether the CMD-03 resume gate is measurable and not merely aspirational.