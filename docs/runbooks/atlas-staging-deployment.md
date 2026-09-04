# Atlas Staging Deployment Runbook

**Scope:** Protected activation of a separately created Atlas staging project after ATLAS-ACT-01B is accepted and merged.

**Protected GitHub Environment:** `atlas-staging`

This runbook does not authorize Atlas production, the live OPS project, copied Retool payloads, production data, or an automatic deployment. Project cost confirmation and project creation are external actions performed only after this repository-readiness PR is accepted and merged.

## 1. Repository readiness

ATLAS-ACT-01B provides a fail-closed browser environment reader, shared live-target guard, exact-head certification, guarded migration deployment, read-only verifier, and one manual GitHub Actions workflow. Repository migrations remain the only schema authority.

Before activation, confirm the chosen commit:

- is a full SHA contained in `main`;
- is checked out exactly with a clean worktree;
- has an explicitly selected certification source;
- in `github` mode, passed `Frontend CI / Format, typecheck, test, build` and `Supabase Integration / Supabase Full Integration` for that SHA;
- in `local` mode, synchronously passes the shared substantive frontend and Supabase Full Integration entrypoints in the same deployment invocation.

No missing, automatic-fallback, skip, or manually authored certificate mode exists. The GitHub deployment workflow proves workflow evidence through the built-in `GITHUB_TOKEN` and does not rerun either suite. Local mode fetches only `refs/remotes/origin/main` from canonical `origin`, verifies exact HEAD, refreshed `origin/main` containment and worktree cleanliness, runs both suites, then fetches and verifies the same complete Git state again immediately before the protected path.

## 2. Current-cost confirmation and project creation

After this PR is accepted and merged, the Product Owner and authorized Supabase organization owner must:

1. retrieve the current project price and region availability;
2. record explicit cost confirmation;
3. create one long-lived, non-production Atlas staging project;
4. record its project reference and region;
5. confirm it is not the live OPS project `qnthofvccilhnefdcxnz`.

No repository command in this task creates a project, Supabase branch, credential, Auth user, or hosted resource.

## 3. Protected GitHub Environment setup

Create a protected GitHub Environment named exactly `atlas-staging`. Apply the repository's required reviewers and deployment protections.

Configure variables with these exact names:

```text
ATLAS_STAGING_PROJECT_REF
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
ATLAS_STAGING_TEST_EMAIL
```

Configure secrets with these exact names:

```text
ATLAS_STAGING_SUPABASE_ACCESS_TOKEN
ATLAS_STAGING_DB_PASSWORD
ATLAS_STAGING_TEST_PASSWORD
ATLAS_STAGING_SUPABASE_SECRET_KEY
```

`VITE_ATLAS_ENVIRONMENT` must be `staging`. The URL must be the HTTPS hostname derived from the protected project reference. The publishable key may be a supported `sb_publishable_` key or legacy anonymous JWT. Never use `sb_secret_`, service-role, management, database, or test credentials in browser variables. `ATLAS_STAGING_SUPABASE_SECRET_KEY` is server-only and is required solely by the Identity installer for Supabase Auth administration.

## 4. First migration deployment

Dispatch `Atlas Staging Deploy` manually and provide the exact full `main` SHA. The workflow uses:

```text
pnpm atlas:staging:deploy -- --commit-sha <full-main-sha> --certification github --preflight
pnpm atlas:staging:deploy -- --commit-sha <full-main-sha> --certification github
```

For an authorized local deployment when hosted Actions are unavailable, use one invocation from the exact clean `origin/main` commit:

```text
pnpm atlas:staging:deploy -- --commit-sha <full-main-sha> --certification local
```

Local mode requires Node 24, pnpm 11, the repository-pinned Supabase CLI, Docker and enough resources for the complete local integration suite. It performs frozen dependency installation, formatting, typecheck, frontend tests, build, the complete Supabase Full Integration authority and final Git-state revalidation before any hosted link or migration command. Do not run local preflight and then treat its result as durable evidence; a later deployment invocation certifies again.

Preflight is non-mutating. The guarded deployment revalidates exact-head certification, inspects repository-pinned Supabase CLI help, links only the ephemeral protected workflow checkout to the already verified staging reference, applies ordered repository migrations with `supabase db push --linked`, stops on the first failure, and then runs the verifier's read-only platform phase. After the migration push, the guarded Management API step reads the project's existing Data API schema list and appends `atlas_api` only when absent; it preserves every existing exposed schema and verifies the resulting configuration. The protected access token therefore requires Data API configuration read/write scope for deployment and read scope for verification. The access token is supplied only through the process environment; no CLI login profile is written.

The platform phase reads complete hosted migration versions directly from `supabase_migrations.schema_migrations` through the pinned CLI's JSON output and requires exact equality with the complete repository set. It verifies that Management API configuration exposes `atlas_api`, then performs an actual anonymous Data API RPC and accepts only the expected PostgreSQL `42501` permission denial; missing schema/function, schema-cache, and transport failures are verification failures. The repository target authority is 92 `atlas_api` signatures and owners, security-definer/empty-search-path posture, exact grants, and the CAT-22 normal-policy count and digest. The current pre-deployment hosted Staging observation remains 90 `atlas_api` functions until repository migrations are deployed; it is not rewritten as current repository authority. The platform phase separately requires exactly one isolated `atlas_admin.units / rmvp_05_unit_lock` policy and does not require identity or foundation data that cannot exist before the first schema deployment.

Local script testing may use `--dry-run`. Dry-run performs no process execution and makes no network request:

```text
pnpm atlas:staging:deploy -- --commit-sha <synthetic-full-sha> --certification github --dry-run
pnpm atlas:staging:verify -- --dry-run
```

## 5. Identity, foundation, and rehearsal packages

HOSTED-PLANNING-REHEARSAL-01A defines two repository-owned packages and does not install either one as part of its implementation PR.

- **Identity `atlas-staging-identity@1.1.0` (prepared, unapplied)** manages the same protected synthetic Auth user, Actor/Auth mapping, Admin/Planning role, membership, and reviewed `GLOBAL` scope. Its 19 existing capabilities preserve the previous 17 grants and add only `master_data.recipe_adjustments.read` and `master_data.recipe_adjustments.write`. See the [bounded new-dish and testing-role proposal](../implementation-tasks/TASK-ATLAS-NEW-DISH-STAGING-ROLE.md). This repository version does not establish the installed hosted version.
- **Foundation `atlas-staging-foundation@1.1.0`** manages one synthetic School-catering Customer, one default Delivery Location, one School Type, one School whose creation defaults are zero Student/Teacher portions, one `kg` Unit, two OPTIONAL-note Pantry purposes, one active 0.01 kg Planning quantity-policy revision, and the exact H0A5b calculation-contract root/revision. After School creation, Student/Teacher defaults are operator-owned state: Foundation replay preserves their current values and School version and does not create School audit/business evidence. An exact unreferenced legacy REQUIRED version-1 managed Pantry purpose may transition once to OPTIONAL version 2; unexpected or referenced state fails closed.
- **Synthetic rehearsal** contains synthetic transactional scenarios only through Confirmed Need release.

Ingredient, Supplier, ingredient-supplier priority, Dish, Recipe/BOM, portion-default preparation, Weekly Menu, Attendance, Pantry batches, Need Generation, and Confirmed Need decisions remain rehearsal-authored through connected operator workflows. Each package is separately reviewed, environment-qualified, deterministic, and explicitly invoked. No all-purpose seed is permitted. Copied Retool payloads and unapproved production data are prohibited. Supplier allocation, CMD-03, Purchase Handoff, purchase orders, Warehouse facts, and Dispatch facts are prohibited.

After the package PR is reviewed, merged, and separately authorized for hosted mutation, install from the exact merged `main` SHA in a clean checkout, Identity first:

```text
pnpm atlas:staging:identity:install -- --commit-sha <exact-merged-main-sha>
pnpm atlas:staging:foundation:install -- --commit-sha <exact-merged-main-sha>
```

Both commands require explicit staging configuration, an exact URL/project-reference match, the fixed approved Atlas Staging reference, protected credentials, exact `HEAD`, containment in `origin/main`, and a clean worktree. The Identity command reconciles only its deterministic Auth user before insert-only database reconciliation. Matching rows replay safely; an identifier, natural-key, content, capability, or scope mismatch fails closed. The Foundation command is separately invokable, requires the managed Actor, and has the same matching-row-or-fail behavior; its deterministic H1A policy revision is inserted as `DRAFT` and activated with complete evidence in the same transaction, as required by the approved lifecycle. Foundation also owns the one fixed H0A5b Need Generation calculation-contract root/revision, including exact formula, numeric precision/scales, PostgreSQL coercion, current-revision binding, deterministic approval evidence, and fail-closed root/revision conflicts. Neither command deploys migrations or installs transactional rehearsal facts. `--dry-run` plans the qualified package and performs no process or network execution.

For local-only certification, start local Supabase and supply an `@local.test` email and local-only password through the two protected test variables, then run:

```text
pnpm local:staging-packages:certify
```

The command resets the local database without a seed, runs Identity, proves conflicting managed Need Generation calculation root/revision state fails closed, and proves Foundation first-install creates the School at `0/0`. It then changes the School to `100/10` through the authoritative `RMVP-01.v2` workflow, installs isolated local-only Weekly Menu/Attendance/Pantry preservation fixtures, and replays Foundation twice. Both replays must preserve the complete School and source rows, School version `2`, and existing School audit/domain evidence; keep exactly one exact calculation-contract root/revision; create no downstream facts; preserve omitted capabilities; prove anonymous denial; and prove the approved authenticated School read.

For the clean cross-module gate, run `pnpm local:planning-assembly:verify`. It performs exactly one local reset and uses public APIs—not SQL business fixtures—for the synthetic Admin, Recipe, Weekly Menu, Attendance, Pantry, Need Generation, and Confirmed Need journey. Its only non-product fixture is a temporary read-only JSON baseline used to prove final Foundation replay preservation. Do not run this command against a hosted project.

## 6. Read-only hosted acceptance

After the identity and foundation packages are separately approved and installed, run the default full verifier:

```text
pnpm atlas:staging:verify
```

It is read-only with respect to hosted state. It validates and links the local protected checkout to the staging reference, then confirms complete machine-readable migration-set equality and exact catalog/security identity authority; exact managed Identity and Foundation state; reachable API; configured and live `atlas_api`; the specific anonymous authorization denial; protected-user sign-in; exactly one active Actor mapping for the Auth subject; one successful approved `get_school_master_data` read returning the single managed School; and session clearing after sign-out. It prints no URL, project reference, email, key, password, token, JWT, or database connection string. Use `--platform-only` before package installation. That phase accepts either zero application roles or exactly the repository-managed active Atlas Staging Identity role, so it remains valid after approved Identity installation without accepting arbitrary, inactive, substituted, or additional roles. It does not require Foundation records, package verification, or Auth sign-in.

Synthetic business rehearsal is a separate approved package/workflow and is not performed by the default verifier.

Successful hosted verification hands off to `ATLAS-STAGING-UI-ACCESS-01`, which publishes the controlled persistent connected Staging frontend. Only after that staff-access gate exists does `HOSTED-PLANNING-REHEARSAL-01B` execute the hosted operator/security rehearsal. The resulting acceptance evidence precedes any explicit Product/Architecture decision to resume CMD-03 or Purchase Handoff.

```text
01A merge
→ protected Identity installation
→ protected Foundation installation
→ read-only hosted verification
→ ATLAS-STAGING-UI-ACCESS-01
→ HOSTED-PLANNING-REHEARSAL-01B
→ CMD-03 decision
```

Mandatory local package certification and the separate hosted-mutation authorization are the 01A evidence gates. GitHub Actions exact-head certification is not an unconditional prerequisite for package installation unless root separately requires it.

## 7. Incident handling

Stop immediately when any of these occur:

- exact-head evidence is missing or ambiguous;
- project reference and URL disagree;
- the live OPS reference or hostname is encountered;
- a protected value is missing or unsafe;
- migration history differs from repository authority;
- a catalog, role, RLS, API, Auth, Actor, read, or sign-out check fails;
- diagnostics appear to contain a credential.

Do not bypass certification, retry an unknown write automatically, repair history ad hoc, change Dashboard DDL, or redirect the workflow to another environment. Preserve the workflow run, sanitized error category, requested SHA, and responsible operator for review.

## 8. Reviewed forward corrective migration

Hosted database rollback uses a reviewed forward corrective migration. Do not delete or edit an already deployed migration, run manual hosted DDL, or use `migration repair` without a separately accepted incident decision. The corrective change must preserve operational and audit history, pass normal CI, and be dispatched from a newly certified exact `main` SHA.

## 9. Project pause or deletion ownership

Only the Product Owner and authorized Supabase organization owner may approve project pause or deletion after confirming retention, audit-evidence, operator-access, and cost obligations. Repository maintainers may disable the GitHub Environment or workflow access during an incident, but that does not authorize deletion. The live OPS project, OPS v1/v2, Retool, and production data remain outside this runbook.
