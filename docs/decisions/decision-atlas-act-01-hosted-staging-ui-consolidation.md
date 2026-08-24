# Decision ATLAS-ACT-01 — Hosted Staging and Connected-UI Consolidation

**Status:** Accepted

**Accepted on:** 06/08/2026

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Contract:** [ATLAS-ACT-01 Hosted Staging and Connected-UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

**UI standard:** [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md)

## 1. Context

Atlas now has a connected local Admin and Planning path through Confirmed Need release. The next possible business slice is CMD-03/Purchase Handoff, but the Product Owner selected a stabilization gate first:

```text
separate hosted staging
+ connected UI consolidation
+ operator and security rehearsal
before downstream purchasing expansion
```

The live OPS project remains the production OPS v1/v2 and Retool boundary. It has no Atlas schema, runtime or API and must not become the Atlas staging target.

## 2. Accepted decisions

| ID      | Decision                 | Accepted direction                                                                                                                                                                                                                                                                                                                                          | Rationale                                                                                                                                                                |
| ------- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| ACT-P01 | Delivery sequence        | Pause CMD-03 until staging and connected UI acceptance complete.                                                                                                                                                                                                                                                                                            | Prevents adding another handoff before the implemented path is usable and supportable.                                                                                   |
| ACT-P02 | Staging topology         | Use one separate long-lived Atlas staging Supabase project.                                                                                                                                                                                                                                                                                                 | It is the simplest durable shared environment and isolates Atlas from live OPS.                                                                                          |
| ACT-P03 | Live OPS boundary        | Explicitly deny project `qnthofvccilhnefdcxnz` as an Atlas target.                                                                                                                                                                                                                                                                                          | The project contains active legacy schemas, functions, Edge Functions and Retool dependencies.                                                                           |
| ACT-P04 | Production topology      | Do not select or create Atlas production in this phase.                                                                                                                                                                                                                                                                                                     | Production requires later migration, ownership, support and cutover decisions.                                                                                           |
| ACT-P05 | Project creation         | Retrieve current cost and require explicit confirmation immediately before creation.                                                                                                                                                                                                                                                                        | Architecture cannot approve an unknown future charge.                                                                                                                    |
| ACT-P06 | Schema authority         | Use repository migrations only; prohibit Dashboard DDL.                                                                                                                                                                                                                                                                                                     | Preserves reproducibility and GitHub as source of truth.                                                                                                                 |
| ACT-P07 | Deployment trigger       | Use a protected manual staging deployment initially.                                                                                                                                                                                                                                                                                                        | Keeps external mutation deliberate while the runbook is proven.                                                                                                          |
| ACT-P08 | Exact-head certification | Deploy only an exact clean `main` SHA certified immediately before mutation. GitHub deployment uses successful exact-head Frontend CI and Supabase Full Integration evidence; an explicitly selected local deployment synchronously runs the shared substantive frontend and Supabase Full Integration authorities. No fallback or uncertified mode exists. | Preserves the same safety properties when hosted Actions are unavailable without trusting durable evidence or duplicating either suite inside one deployment invocation. |
| ACT-P09 | Target verification      | Check the approved staging reference and explicitly reject the live OPS reference before hosted commands.                                                                                                                                                                                                                                                   | Converts coexistence into an executable guard.                                                                                                                           |
| ACT-P10 | Browser configuration    | Use explicit `local`/`staging` environment, Supabase URL and publishable key; reject production and secret-bearing configuration.                                                                                                                                                                                                                           | Prevents environment confusion and secret leakage.                                                                                                                       |
| ACT-P11 | Data packages            | Separate identity, foundation and rehearsal packages; use synthetic data by default.                                                                                                                                                                                                                                                                        | Keeps staging data minimal, reviewable and inexpensive to reset.                                                                                                         |
| ACT-P12 | Edge Functions           | Deploy no Edge Function for initial staging/UI acceptance.                                                                                                                                                                                                                                                                                                  | The connected current journey is database/API based and needs no hosted function.                                                                                        |
| ACT-P13 | UI scope                 | Consolidate only connected Admin and Planning surfaces before CMD-03.                                                                                                                                                                                                                                                                                       | Avoids polishing unconnected Procurement, Warehouse and Dispatch prototypes that will change later.                                                                      |
| ACT-P14 | UI dependencies          | Add no external UI framework, table library or global state library in the first pass.                                                                                                                                                                                                                                                                      | Existing React/CSS/Storybook foundations are sufficient and cheaper to maintain.                                                                                         |
| ACT-P15 | UI abstraction           | Introduce a shared primitive only when at least two real current surfaces need it, except shell-level primitives.                                                                                                                                                                                                                                           | Prevents a speculative design-system project.                                                                                                                            |
| ACT-P16 | UI sequence              | Shared shell/proven primitives → connected Planning → connected Admin → staging rehearsal.                                                                                                                                                                                                                                                                  | Keeps each PR bounded and prioritizes the daily operator path.                                                                                                           |
| ACT-P17 | State authority          | Present one backend-authoritative current state and keep immutable history separate.                                                                                                                                                                                                                                                                        | Prevents contradictory lifecycle messaging and client-authored eligibility.                                                                                              |
| ACT-P18 | Acceptance               | Require hosted platform/Auth/security evidence and the full Admin-to-Confirmed-Need-release rehearsal.                                                                                                                                                                                                                                                      | Makes the stabilization gate measurable.                                                                                                                                 |
| ACT-P19 | Downstream gate          | Resume CMD-03 only after staging, UI-QUALITY-01/02/03 and operator/security acceptance.                                                                                                                                                                                                                                                                     | Keeps further technology work subordinate to product readiness.                                                                                                          |

## 3. Consequences

### Positive

- Atlas gains a shared hosted environment without risking OPS v1 continuity.
- Real Auth, RLS, migration and browser behavior are tested before production.
- Existing UI investment is retained while repeated patterns become reusable only when proven.
- Operator feedback arrives before Purchase Handoff and Procurement expansion.
- Exact-head GitHub evidence is reused when available; explicit local certification executes each shared substantive suite once and continues directly into protected deployment.

### Costs and constraints

- A separate project has a separately confirmed cost.
- Staging needs small identity, foundation and rehearsal packages.
- UI consolidation is delivered in bounded PRs rather than one rewrite.
- CMD-03 is intentionally delayed until the gate passes.

## 4. Non-decisions

This decision does not select:

- current Supabase price or billing organization;
- final staging project name or region;
- Atlas production project or frontend host;
- production identities, role bindings or data migration;
- whether masked OPS data will later be approved;
- deployment of any Edge Function;
- CMD-03, Purchase Handoff or Procurement behavior;
- a third-party UI framework.

## 5. Authorized follow-on boundary

After this documentation package merges:

- ATLAS-ACT-01B may prepare repository staging configuration and guarded deployment tooling without hosted mutation;
- UI-QUALITY-01 may implement the shared shell and only proven shared primitives;
- staging project creation still requires the Supabase organization, current price and explicit confirmation;
- CMD-03 remains blocked until the accepted staging/UI/rehearsal gate is complete.
