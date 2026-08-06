# TASK-ATLAS-ACT-01B — Hosted Staging Repository Readiness

**Status:** Proposed implementation handoff; not authorized until ATLAS-ACT-01A is accepted and merged

**Required baseline:** exact `main` SHA resulting from merged ATLAS-ACT-01A

**Architecture:** [ATLAS-ACT-01 Hosted Staging and UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

**Decision registry:** [Decision ATLAS-ACT-01](../decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md)

## 1. Objective

Prepare the repository for a separately managed hosted Atlas staging project without creating, linking or mutating any hosted project.

The task delivers environment-aware browser configuration, protected GitHub Environment contracts, guarded manual deployment tooling, hosted verification tooling, tests and a runbook.

It adds no business capability.

## 2. Required outcome

Repository behavior after this task:

```text
local
→ existing loopback Supabase behavior remains supported
→ all current local acceptance gates remain unchanged

staging
→ application accepts only explicit hosted staging configuration
→ protected manual workflow can validate and deploy after external project creation
→ target identity is checked and live OPS project is denied
→ hosted catalog/Auth/read acceptance can be verified safely

production
→ rejected as unsupported until a later accepted production contract
```

## 3. Exact environment contract

Browser-visible variables:

```text
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
```

Initially valid values:

```text
VITE_ATLAS_ENVIRONMENT=local
VITE_ATLAS_ENVIRONMENT=staging
```

Validation requirements:

- `local` accepts only loopback API URLs;
- `staging` accepts only HTTPS non-loopback URLs;
- unknown environment values fail closed;
- missing URL/key fails closed;
- embedded URL credentials fail closed;
- validation errors do not echo supplied values;
- no Supabase client is initialized after validation failure;
- active environment is displayed in the Atlas shell;
- existing local variable behavior remains backward-compatible only where the accepted architecture permits it.

Browser source and build output must statically prohibit:

```text
SERVICE_ROLE_KEY
SECRET_KEY
DATABASE_URL
DB_PASSWORD
SUPABASE_ACCESS_TOKEN
SUPABASE_PROJECT_REF
ATLAS_STAGING_DB_PASSWORD
ATLAS_STAGING_SUPABASE_ACCESS_TOKEN
```

## 4. Protected GitHub Environment

Exact environment name:

```text
atlas-staging
```

Environment variables:

```text
ATLAS_STAGING_PROJECT_REF
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
ATLAS_STAGING_TEST_EMAIL
```

Environment secrets:

```text
ATLAS_STAGING_SUPABASE_ACCESS_TOKEN
ATLAS_STAGING_DB_PASSWORD
ATLAS_STAGING_TEST_PASSWORD
```

Repository documentation and workflows contain names only, never values.

The workflow may map protected secrets to the exact names expected by the pinned Supabase CLI at runtime.

## 5. Deployment safety contract

Initial staging deployment is `workflow_dispatch` only.

Before any hosted command, tooling must prove:

1. all required protected values exist;
2. target project reference is syntactically valid;
3. target project reference equals the approved staging reference supplied to the workflow;
4. target project reference is not `qnthofvccilhnefdcxnz`;
5. repository checkout is the intended reviewed commit;
6. migration files are ordered and worktree is clean;
7. complete local database and browser acceptance passed;
8. no production environment or Retool credential is present.

Diagnostics must redact:

- Supabase access token;
- database password;
- publishable/legacy JWT key;
- connection string;
- bearer token;
- Auth password;
- service-role or secret key.

The implementation must inspect the pinned CLI `--help` output and use only flags supported by the repository version. Do not upgrade the CLI or dependencies.

## 6. Deployment command behavior

Provide one bounded repository command or script for staging migration deployment.

It must:

- refuse local, unknown and live OPS targets;
- use protected environment variables only;
- perform local acceptance before hosted action;
- use the repository migration history as the sole schema source;
- apply migrations in the approved CLI-supported manner;
- stop on first failure;
- perform a read-only hosted catalog verification afterward;
- report project reference only where safe and necessary;
- report safe object counts/fingerprints, not credentials or data;
- create no seed data unless a separately approved staging package is explicitly invoked.

Rollback is documented as a forward corrective migration.

## 7. Hosted verification command

Provide one staging acceptance verifier.

Minimum checks:

- target project is not the live OPS project;
- project API is reachable;
- `atlas_api` schema and exact API registry/fingerprint match repository authority;
- expected Atlas runtime roles exist;
- expected migrations are applied;
- private domain tables are unavailable to browser roles;
- `anon` does not execute authenticated APIs;
- protected staging user can sign in when test credentials are supplied;
- Auth subject resolves to the expected staging Actor;
- one approved non-destructive read succeeds;
- sign-out clears the local session;
- no credential is logged.

The verifier is read-only unless a separately reviewed rehearsal package authorizes isolated staging writes.

## 8. Workflow requirements

Preserve `.github/workflows/supabase-integration.yml` as the authoritative local integration gate.

Add a separate staging workflow or a clearly isolated staging job only if the architecture and repository conventions support it.

Required sequence:

```text
checkout exact commit
→ frozen install
→ local Supabase start/reset
→ all registered pgTAP suites
→ all current browser acceptance journeys
→ stop local stack
→ target denylist and protected-value checks
→ manual hosted migration deployment
→ hosted catalog verification
→ hosted Auth/read verification
```

No hosted job runs automatically on ordinary pull requests or pushes during the first activation phase.

## 9. Expected changed-path categories

The implementation prompt must freeze an exact manifest before editing.

Allowed categories:

- existing environment and connection modules/tests;
- Atlas shell environment indicator;
- `.env.example` and `.gitignore` only where required;
- one staging deployment script;
- one hosted verification script;
- protected staging workflow;
- package scripts without dependency changes;
- focused static/configuration tests;
- staging runbook;
- implementation record;
- roadmap status after implementation.

Prohibited paths unless a conflict is reported and separately approved:

- `supabase/migrations/` business migrations;
- business-domain API/client/workbench behavior;
- Procurement, Warehouse or Dispatch modules;
- accepted architecture and decision documents;
- Retool exports;
- production data or credentials;
- Edge Functions.

## 10. Test requirements

Focused tests must cover:

- accepted local environment;
- accepted staging environment;
- unknown environment rejection;
- local/hosted mismatch rejection;
- staging/loopback mismatch rejection;
- malformed and credential-bearing URL rejection;
- missing publishable key rejection;
- safe error redaction;
- no client creation after invalid configuration;
- browser-variable secret prohibition;
- exact GitHub Environment and protected-name contract;
- live OPS project denylist;
- production environment rejection;
- no automatic retry of business writes.

Complete validation:

```text
pnpm ops:workspace
pnpm format
pnpm typecheck
pnpm test
pnpm build
fresh local Supabase reset
all registered pgTAP suites
all current browser acceptance journeys
git diff --check
```

## 11. Documentation requirements

Create:

```text
docs/runbooks/atlas-staging-deployment.md
docs/implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness-implementation.md
```

Update only the accepted files required for environment configuration, scripts, workflow registration and roadmap status.

The runbook must separate:

- repository readiness;
- external cost confirmation/project creation;
- protected environment configuration;
- first migration deployment;
- staging identity/data-package installation;
- acceptance verification;
- incident handling and forward correction;
- pause/deletion ownership.

## 12. Completion report

The draft PR report must include:

- exact starting baseline and head;
- exact changed-path manifest;
- environment variable contract;
- GitHub Environment variable/secret names;
- live OPS denylist evidence;
- deployment and verification commands;
- tests and CI status;
- confirmation that no hosted project was created, linked or mutated;
- confirmation that no Retool, OPS v1/v2, business migration/API, production data, credential, capability binding, Edge Function, CMD-03 or downstream resource changed.

## 13. Explicit exclusions

ATLAS-ACT-01B must not:

- create a Supabase project or branch;
- obtain cost confirmation;
- link to a hosted project during implementation validation;
- deploy repository migrations to a hosted project;
- create hosted Auth users;
- install identity/reference/policy/rehearsal data;
- modify Retool or live OPS;
- deploy Edge Functions;
- choose a production target;
- change business SQL/APIs/lifecycles;
- implement CMD-03, Purchase Handoff, supplier allocation or purchase orders;
- add a dependency or upgrade Node, pnpm, Supabase CLI or Actions.