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
```

`VITE_ATLAS_ENVIRONMENT` must be `staging`. The URL must be the HTTPS hostname derived from the protected project reference. The publishable key may be a supported `sb_publishable_` key or legacy anonymous JWT. Never use `sb_secret_`, service-role, management, database, or test credentials in browser variables.

## 4. First migration deployment

Dispatch `Atlas Staging Deploy` manually and provide the exact full `main` SHA. The workflow uses:

```text
pnpm atlas:staging:deploy -- --commit-sha <full-main-sha> --preflight
pnpm atlas:staging:deploy -- --commit-sha <full-main-sha>
```

Preflight is non-mutating. The guarded deployment revalidates exact-head certification, inspects repository-pinned Supabase CLI help, links only the ephemeral protected workflow checkout to the already verified staging reference, applies ordered repository migrations with `supabase db push --linked`, stops on the first failure, and then runs the verifier's read-only platform phase. After the migration push, the guarded Management API step reads the project's existing Data API schema list and appends `atlas_api` only when absent; it preserves every existing exposed schema and verifies the resulting configuration. The protected access token therefore requires Data API configuration read/write scope for deployment and read scope for verification. The access token is supplied only through the process environment; no CLI login profile is written.

The platform phase reads complete hosted migration versions directly from `supabase_migrations.schema_migrations` through the pinned CLI's JSON output and requires exact equality with the complete repository set. It verifies that Management API configuration exposes `atlas_api`, then performs an actual anonymous Data API RPC and accepts only the expected PostgreSQL `42501` permission denial; missing schema/function, schema-cache, and transport failures are verification failures. The catalog check uses the approved security-catalog pgTAP authority for exact schema names, database-role posture, all 79 API signatures and owners, security-definer/empty-search-path posture, exact grants, and the CAT-22 policy digest. Counts are diagnostic only. This phase does not require identity or foundation data that cannot exist before the first schema deployment.

Local script testing may use `--dry-run`. Dry-run performs no process execution and makes no network request:

```text
pnpm atlas:staging:deploy -- --commit-sha <synthetic-full-sha> --dry-run
pnpm atlas:staging:verify -- --dry-run
```

## 5. Identity, foundation, and rehearsal packages

ATLAS-ACT-01B defines interfaces only and installs no package.

- **Identity** contains staging Auth subjects, active Atlas Actors, roles, scopes, and only current capabilities.
- **Foundation** contains approved reference data and the Planning policy required by connected Admin and Planning.
- **Synthetic rehearsal** contains synthetic transactional scenarios only through Confirmed Need release.

Each package is separately reviewed, environment-qualified, and explicitly invoked. No all-purpose seed is permitted. Copied Retool payloads and unapproved production data are prohibited. Supplier allocation, CMD-03, Purchase Handoff, purchase orders, Warehouse facts, and Dispatch facts are prohibited.

## 6. Read-only hosted acceptance

After the identity and foundation packages are separately approved and installed, run the default full verifier:

```text
pnpm atlas:staging:verify
```

It is read-only with respect to hosted state. It validates and links the local protected checkout to the staging reference, then confirms complete machine-readable migration-set equality and exact catalog/security identity authority; reachable API; configured and live `atlas_api`; the specific anonymous authorization denial; protected-user sign-in; exactly one active Actor mapping for the Auth subject; one approved `get_operator_blockers` read; and session clearing after sign-out. It prints no URL, project reference, email, key, password, token, JWT, or database connection string.

Synthetic business rehearsal is a separate approved package/workflow and is not performed by the default verifier.

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
