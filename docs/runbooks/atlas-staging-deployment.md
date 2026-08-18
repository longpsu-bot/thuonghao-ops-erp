# Atlas Staging Deployment Runbook

**Scope:** Protected activation of a separately created Atlas staging project after ATLAS-ACT-01B is accepted and merged.

**Protected GitHub Environment:** `atlas-staging`

This runbook does not authorize Atlas production, the live OPS project, copied Retool payloads, production data, or an automatic deployment. Project cost confirmation and project creation are external actions performed only after this repository-readiness PR is accepted and merged.

## 1. Repository readiness

ATLAS-ACT-01B provides a fail-closed browser environment reader, shared live-target guard, exact-head certification, guarded migration deployment, read-only verifier, and one manual GitHub Actions workflow. Repository migrations remain the only schema authority.

Before activation, confirm the chosen commit:

- is a full SHA contained in `main`;
- is checked out exactly with a clean worktree;
- passed `Frontend CI / Format, typecheck, test, build` for that SHA;
- passed `Supabase Integration / Supabase Full Integration` for that SHA.

The deployment workflow proves these facts through the built-in `GITHUB_TOKEN`. It does not rerun either complete suite.

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
pnpm atlas:staging:deploy -- --commit-sha <full-main-sha> --preflight
pnpm atlas:staging:deploy -- --commit-sha <full-main-sha>
```

Preflight is non-mutating. The guarded deployment revalidates exact-head certification, inspects repository-pinned Supabase CLI help, links only the ephemeral protected workflow checkout to the already verified staging reference, applies ordered repository migrations with `supabase db push --linked`, stops on the first failure, and then runs the verifier's read-only platform phase. After the migration push, the guarded Management API step reads the project's existing Data API schema list and appends `atlas_api` only when absent; it preserves every existing exposed schema and verifies the resulting configuration. The protected access token therefore requires Data API configuration read/write scope for deployment and read scope for verification. The access token is supplied only through the process environment; no CLI login profile is written.

The platform phase reads complete hosted migration versions directly from `supabase_migrations.schema_migrations` through the pinned CLI's JSON output and requires exact equality with the complete repository set. It verifies that Management API configuration exposes `atlas_api`, then performs an actual anonymous Data API RPC and accepts only the expected PostgreSQL `42501` permission denial; missing schema/function, schema-cache, and transport failures are verification failures. The catalog check uses the approved security-catalog pgTAP authority for exact schema names, database-role posture, all 90 API signatures and owners, security-definer/empty-search-path posture, exact grants, and the CAT-22 normal-policy count and digest. It separately requires exactly one isolated `atlas_admin.units / rmvp_05_unit_lock` policy. This phase does not require identity or foundation data that cannot exist before the first schema deployment.

Local script testing may use `--dry-run`. Dry-run performs no process execution and makes no network request:

```text
pnpm atlas:staging:deploy -- --commit-sha <synthetic-full-sha> --dry-run
pnpm atlas:staging:verify -- --dry-run
```

## 5. Identity, foundation, and rehearsal packages

HOSTED-PLANNING-REHEARSAL-01A defines two repository-owned packages and does not install either one as part of its implementation PR.

- **Identity `atlas-staging-identity@1.0.0`** manages one protected synthetic Auth user, one active Actor and Auth mapping, one minimal Admin/Planning role with the 15 reviewed current capabilities, one active membership, and one reviewed `GLOBAL` scope required by current connected API authorization.
- **Foundation `atlas-staging-foundation@1.0.0`** manages one synthetic School-catering Customer, one default Delivery Location, one School Type, one School with zero portion defaults, one `kg` Unit, the two accepted Pantry purposes, and one active 0.01 kg Planning quantity-policy revision.
- **Synthetic rehearsal** contains synthetic transactional scenarios only through Confirmed Need release.

Ingredient, Supplier, ingredient-supplier priority, Dish, Recipe/BOM, portion-default preparation, Weekly Menu, Attendance, Pantry batches, Need Generation, and Confirmed Need decisions remain rehearsal-authored through connected operator workflows. Each package is separately reviewed, environment-qualified, deterministic, and explicitly invoked. No all-purpose seed is permitted. Copied Retool payloads and unapproved production data are prohibited. Supplier allocation, CMD-03, Purchase Handoff, purchase orders, Warehouse facts, and Dispatch facts are prohibited.

After the package PR is reviewed, merged, and separately authorized for hosted mutation, install from the exact merged `main` SHA in a clean checkout, Identity first:

```text
pnpm atlas:staging:identity:install -- --commit-sha <exact-merged-main-sha>
pnpm atlas:staging:foundation:install -- --commit-sha <exact-merged-main-sha>
```

Both commands require explicit staging configuration, an exact URL/project-reference match, the fixed approved Atlas Staging reference, protected credentials, exact `HEAD`, containment in `origin/main`, and a clean worktree. The Identity command reconciles only its deterministic Auth user before insert-only database reconciliation. Matching rows replay safely; an identifier, natural-key, content, capability, or scope mismatch fails closed. The Foundation command is separately invokable, requires the managed Actor, and has the same matching-row-or-fail behavior; its deterministic H1A policy revision is inserted as `DRAFT` and activated with complete evidence in the same transaction, as required by the approved lifecycle. Neither command deploys migrations or installs transactional rehearsal facts. `--dry-run` plans the qualified package and performs no process or network execution.

For local-only certification, start local Supabase and supply an `@local.test` email and local-only password through the two protected test variables, then run:

```text
pnpm local:staging-packages:certify
```

The command resets the local database without a seed, runs Identity and Foundation first-install plus replay, verifies exact managed state and omitted capabilities, checks that operator-authored/downstream facts remain absent, proves anonymous denial, and proves the approved authenticated School read.

## 6. Read-only hosted acceptance

After the identity and foundation packages are separately approved and installed, run the default full verifier:

```text
pnpm atlas:staging:verify
```

It is read-only with respect to hosted state. It validates and links the local protected checkout to the staging reference, then confirms complete machine-readable migration-set equality and exact catalog/security identity authority; exact managed Identity and Foundation state; reachable API; configured and live `atlas_api`; the specific anonymous authorization denial; protected-user sign-in; exactly one active Actor mapping for the Auth subject; one successful approved `get_school_master_data` read returning the single managed School; and session clearing after sign-out. It prints no URL, project reference, email, key, password, token, JWT, or database connection string. Use `--platform-only` before package installation; that phase continues to require zero application roles and does not require package state.

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
