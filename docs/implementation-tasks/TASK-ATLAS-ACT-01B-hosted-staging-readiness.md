# TASK-ATLAS-ACT-01B — Hosted Staging Repository Readiness

**Status:** Proposed implementation handoff; not authorized until ATLAS-ACT-01A is accepted and merged

**Required baseline:** exact `main` SHA resulting from merged ATLAS-ACT-01A

**Architecture:** [ATLAS-ACT-01 Hosted Staging and Connected-UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

## 1. Objective

Prepare the repository for a separately managed Atlas staging project without creating, linking or mutating any hosted project during implementation.

The task delivers:

- explicit local/staging browser configuration;
- live OPS target denial;
- protected manual deployment tooling;
- exact-head CI verification;
- hosted catalog/Auth verification;
- focused tests and a runbook.

It adds no business capability.

## 2. Environment behavior

```text
local
→ existing loopback Supabase behavior remains supported

staging
→ explicit hosted configuration only
→ manual protected deployment and verification become available

production
→ rejected until a later accepted production contract
```

Browser-visible variables:

```text
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
```

Validation:

- `local` accepts only loopback URLs;
- `staging` accepts only HTTPS non-loopback URLs;
- unknown or missing values fail closed;
- embedded URL credentials fail closed;
- errors do not echo supplied values;
- invalid configuration creates no Supabase client;
- the shell displays the active environment;
- no management, service-role, database or test credential can enter the frontend bundle.

## 3. Protected GitHub Environment

Exact environment name:

```text
atlas-staging
```

Variables:

```text
ATLAS_STAGING_PROJECT_REF
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
ATLAS_STAGING_TEST_EMAIL
```

Secrets:

```text
ATLAS_STAGING_SUPABASE_ACCESS_TOKEN
ATLAS_STAGING_DB_PASSWORD
ATLAS_STAGING_TEST_PASSWORD
```

The repository stores names and placeholders only.

## 4. Deployment safety and CI efficiency

Initial staging deployment is `workflow_dispatch` only.

Before hosted mutation, tooling must prove:

1. the requested commit is an exact commit on `main`;
2. Frontend CI and Supabase Full Integration succeeded for that exact commit;
3. all protected values exist;
4. the target project reference is syntactically valid and matches the approved staging reference;
5. the target is not `qnthofvccilhnefdcxnz`;
6. migration files are ordered and checkout is clean;
7. production and Retool credentials are absent.

The deployment workflow must **not** repeat the complete local pgTAP and browser suite. It reuses exact-head CI certification and performs only bounded deployment preflight, migration application and hosted verification.

If exact-head certification cannot be verified automatically, the workflow fails closed rather than rerunning or bypassing it.

Diagnostics redact tokens, passwords, connection strings, JWTs and keys.

## 5. Deployment command

Provide one bounded staging deployment command or script that:

- refuses local, production, unknown and live OPS targets;
- accepts only protected environment values;
- uses repository migration history as sole schema authority;
- uses only flags supported by the pinned Supabase CLI;
- applies migrations in order and stops on first failure;
- verifies migration history and safe Atlas catalog fingerprints afterward;
- creates no data unless a separately approved package is explicitly invoked.

After hosted deployment, rollback is a reviewed forward corrective migration.

## 6. Hosted verifier

Provide one default read-only staging verifier.

Minimum checks:

- target is not the live OPS project;
- project API is reachable;
- migration history matches the deployed repository commit;
- `atlas_api` and exact API/catalog fingerprints match authority;
- expected Atlas runtime roles exist;
- private tables remain unavailable to browser roles;
- `anon` cannot execute authenticated APIs;
- a staging user can sign in when protected test credentials are supplied;
- the Auth subject maps to the expected staging Actor;
- one approved non-destructive read succeeds;
- sign-out clears the session;
- no credential is logged.

Writes belong to a separately reviewed rehearsal command/package, not the default verifier.

## 7. Data-package boundary

ATLAS-ACT-01B documents and validates package interfaces but installs no hosted data during implementation.

Packages:

1. identity;
2. foundation reference/Planning policy;
3. synthetic rehearsal data.

No package may contain production credentials, copied Retool payloads, supplier allocation, Purchase Handoff, purchase orders or downstream facts.

## 8. Expected path categories

The implementation prompt must freeze an exact manifest before editing.

Allowed categories:

- existing environment and connection modules/tests;
- shell environment indicator;
- `.env.example` and `.gitignore` where required;
- one staging deployment script;
- one hosted verification script;
- one protected staging workflow;
- package scripts without dependency changes;
- focused configuration/security tests;
- staging runbook and implementation record;
- roadmap status.

Prohibited without a reported conflict:

- business migrations and pgTAP catalogs;
- business API/client/workbench behavior;
- Procurement, Warehouse and Dispatch modules;
- accepted architecture/decision documents;
- Retool exports;
- production data, credentials and Edge Functions.

## 9. Tests

Focused tests cover:

- valid local and staging configuration;
- unknown environment rejection;
- local/hosted URL mismatch;
- malformed or credential-bearing URL rejection;
- missing publishable key and safe error redaction;
- no client creation after invalid configuration;
- secret-name prohibition in browser config/build;
- exact protected environment names;
- live OPS project denylist;
- production rejection;
- exact-head CI check requirement;
- no hosted job on ordinary pull requests or pushes.

Local validation:

```text
pnpm ops:workspace
pnpm format
pnpm typecheck
pnpm test
pnpm build
git diff --check
```

Run existing Supabase Integration only if changed connection or workflow paths trigger it. Do not add a second duplicate integration run to the deployment workflow.

## 10. Documentation

Create:

```text
docs/runbooks/atlas-staging-deployment.md
docs/implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness-implementation.md
```

The runbook separates:

- repository readiness;
- cost confirmation and project creation;
- protected environment configuration;
- first deployment;
- data-package installation;
- hosted acceptance;
- incident handling and forward correction;
- pause/deletion ownership.

## 11. Completion report

Report:

- exact baseline/head and manifest;
- configuration and protected-name contracts;
- live OPS denylist;
- exact-head CI reuse mechanism;
- deployment and verification commands;
- tests and CI;
- confirmation that no hosted project was created, linked, seeded or mutated;
- confirmation that no Retool, OPS v1/v2, business API/migration, credential, Edge Function, CMD-03 or downstream resource changed.

## 12. Explicit exclusions

ATLAS-ACT-01B must not:

- create a Supabase project or branch;
- obtain cost confirmation;
- link or deploy to a hosted project during implementation validation;
- create hosted Auth users or install data packages;
- modify Retool or live OPS;
- deploy Edge Functions;
- choose production;
- change business SQL, APIs or lifecycle;
- implement CMD-03, Purchase Handoff, supplier allocation or purchase orders;
- add or upgrade dependencies, Node, pnpm, Supabase CLI or Actions.
