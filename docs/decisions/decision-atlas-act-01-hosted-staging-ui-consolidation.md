# Decision ATLAS-ACT-01 — Hosted Staging and UI Consolidation

**Status:** Proposed for Product/Architecture review

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Contract:** [ATLAS-ACT-01 Hosted Staging and UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

**UI standard:** [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md)

## 1. Context

Atlas now has a locally connected Admin and Planning path through Confirmed Need release. The next technical possibility is CMD-03 and Purchase Handoff, but the product owner has selected a stabilization gate first:

```text
hosted staging activation
+ current UI consolidation
+ operator rehearsal
before downstream purchasing expansion
```

The live hosted OPS project remains the production OPS v1/v2 and Retool boundary. It has no Atlas schema, runtime or API. Retool exports demonstrate significant direct SQL/RPC and component-state complexity; they remain evidence, not target authority.

## 2. Proposed decisions

| ID | Decision | Proposed direction | Rationale |
| --- | --- | --- | --- |
| ACT-P01 | Delivery sequence | Pause CMD-03 and downstream feature expansion until hosted staging and current UI certification complete. | Prevents another backend expansion before the implemented path is usable and reviewable by operators. |
| ACT-P02 | Staging topology | Create one separate long-lived Atlas staging Supabase project. | Isolates Atlas migrations, Auth and rehearsal data from live OPS v1/Retool operations. |
| ACT-P03 | Live OPS boundary | Project `qnthofvccilhnefdcxnz` is explicitly denied as an Atlas deployment target. | The project contains legacy production schemas and active Retool dependencies; sharing it would create avoidable coupling and migration risk. |
| ACT-P04 | Production topology | Do not select or create Atlas production during this phase. | Production needs a later data-migration, ownership, support and cutover contract. |
| ACT-P05 | Supabase Branching | Do not require preview branches for first activation; use a separate staging project. | The first need is one durable operator rehearsal environment, not per-PR databases or added cost/lifecycle complexity. |
| ACT-P06 | Project creation | Require explicit current-cost confirmation immediately before project creation. | Project creation is an external cost-incurring action and architecture documentation cannot approve a future price. |
| ACT-P07 | Migration authority | Deploy only repository migrations, in order, after complete local acceptance. | Preserves GitHub and migration history as the schema source of truth. |
| ACT-P08 | Rollback | Use forward-only corrective migrations after hosted deployment. | Avoids deleting migration history or rewriting committed operational/audit evidence. |
| ACT-P09 | Browser configuration | Add explicit `VITE_ATLAS_ENVIRONMENT` alongside URL and publishable key; initially allow only `local` and `staging`. | Prevents accidental environment confusion and unsafe hosted/local mismatches. |
| ACT-P10 | Protected environment | Use GitHub Environment `atlas-staging` with separate browser variables and management/test secrets. | Centralizes approval, identity, credential and audit boundaries without committing values. |
| ACT-P11 | Deployment trigger | Initial hosted staging deployment is manual and project-identity guarded. | Avoids automatic external mutation before the environment and runbook are proven. |
| ACT-P12 | Target denial | Deployment tooling must reject the live OPS project reference even if other credentials are valid. | Converts the coexistence rule into an executable safety invariant. |
| ACT-P13 | Data API exposure | Verify exposed schemas and explicit grants on the new project; browser access remains function-only through `atlas_api`. | New-project Data API defaults may not expose objects automatically, while private-table access would violate Atlas security. |
| ACT-P14 | Staging identities | Use staging-only Supabase Auth users mapped to Atlas Actors, capabilities and scopes. | Prevents shared production identities and preserves backend-owned authorization. |
| ACT-P15 | Seed ownership | Separate identity, reference, Planning-policy and rehearsal-data packages. | Prevents hidden all-purpose seeds and makes data ownership and rollback reviewable. |
| ACT-P16 | Allowed data | Use synthetic data by default; masked legacy data requires a separate explicit approval and source record. | Minimizes privacy and legacy-coupling risk while still enabling realistic rehearsal. |
| ACT-P17 | Edge Functions | Do not deploy the repository Edge Function during the initial database/UI staging phase. | No hosted function is required to certify the current connected path; deployment needs its own credentials and integration contract. |
| ACT-P18 | UI program | Treat UI work as consolidation of existing capabilities, not a business redesign. | Protects merged command/read authority while improving operator usability. |
| ACT-P19 | UI dependencies | Add no external UI framework in the first quality pass. | Existing React/CSS/Storybook foundations are sufficient; a framework migration would broaden cost and risk. |
| ACT-P20 | UI primitives | Standardize local tokens and reusable components before module-by-module polish. | Reduces duplicated presentation logic without one large rewrite. |
| ACT-P21 | UI state authority | Show one authoritative current state and separate immutable history; action eligibility comes from backend read models. | Avoids contradictory lifecycle messages and client-authored business state. |
| ACT-P22 | UI sequence | Implement shared primitives, then Planning, Admin, other prototypes and cross-module certification. | Prioritizes the connected daily workflow and bounds each PR. |
| ACT-P23 | UI acceptance | Require Storybook, component tests, UI Review Export, keyboard/focus review and responsive checks. | Converts subjective polish into repeatable review evidence. |
| ACT-P24 | Staging rehearsal | Certify the Admin-to-Confirmed-Need-release path plus blocker, stale, authorization and unknown-outcome scenarios. | Proves the current slice is operationally usable before adding Purchase Handoff. |
| ACT-P25 | Downstream gate | Resume CMD-03 only after staging activation, UI-QUALITY-01/02 and operator/security acceptance. | Keeps technology work subordinate to product readiness and explicit governance. |

## 3. Consequences

### Positive

- Atlas gains an isolated shared execution environment without risking OPS v1 continuity.
- The team can validate real Auth, RLS, migrations and browser behavior before production.
- Existing UI investment is retained while repeated interaction patterns become reusable.
- Operator feedback occurs before another domain handoff is implemented.
- Staging deployment and UI work remain independently reviewable.

### Costs and constraints

- A separate Supabase project has a separately confirmed cost.
- Staging needs identity, reference, policy and rehearsal-data ownership.
- UI standardization requires several bounded PRs rather than one visual rewrite.
- CMD-03 is intentionally delayed until the stabilization gate passes.

## 4. Non-decisions

This proposal does not decide:

- current Supabase project price or organization billing;
- final staging project name or region before creation approval;
- Atlas production project, hosting or cutover date;
- production user and role assignments;
- production data migration;
- whether masked OPS data will ever be used in staging;
- deployment of `atlas-weekly-menu-google-sync`;
- Vercel or another frontend hosting provider;
- CMD-03, Purchase Handoff or downstream purchasing behavior;
- adoption of a third-party UI framework.

## 5. Acceptance procedure

These decisions become accepted only after independent Product/Architecture review of the exact documentation head. Once accepted:

- register the decision as the next D-number in `decision-register.md`;
- update `docs/architecture/roadmap.md` with the staging/UI gate;
- authorize only the bounded ATLAS-ACT-01B and UI-QUALITY-01 implementation handoffs;
- keep actual project creation subject to a separate cost confirmation and external-action review.