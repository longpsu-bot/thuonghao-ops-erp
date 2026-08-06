# TASK-ATLAS-ACT-01B — Hosted Staging Repository Readiness Implementation

**Status:** Implemented on bounded branch; pending review and merge

**Starting baseline:** `0f34f724ddafc5b1c8eab4136d2ef8c6262d8091`

**Branch:** `codex/atlas-act-01b-hosted-staging-readiness`

## Objective and authority

This implementation prepares the repository for a future separately created Atlas staging Supabase project. It creates, links, seeds, deploys to, or mutates no hosted project during implementation. It adds no business capability and changes no migration, pgTAP catalog, business API, lifecycle, Retool resource, OPS v1/v2 resource, Edge Function, or downstream module.

The accepted ATLAS-ACT-01 contract, D-032 decision, PA-06 environment/connection contracts, merged migrations/tests, and existing React connection behavior were inspected before editing. Repository-pinned Supabase CLI `2.109.1` help confirmed the implemented `link --project-ref --password`, `db push --linked --password`, `migration list --linked --password`, and read-only `db query --linked` surfaces.

## Exact changed-path manifest

```text
.env.example
package.json
src/modules/atlas/connection/environment.ts
src/modules/atlas/connection/environment.test.ts
src/modules/atlas/connection/supabaseClient.ts
src/modules/atlas/connection/supabaseClient.test.ts
src/modules/atlas/connection/security.test.ts
src/modules/atlas/connection/AtlasConnectionPanel.tsx
src/modules/atlas/connection/AtlasConnectionPanel.test.tsx
src/modules/atlas/AtlasApp.tsx
src/modules/atlas/AtlasApp.test.tsx
docs/architecture/roadmap.md
.github/workflows/atlas-staging-deploy.yml
scripts/atlas-staging-contract.mjs
scripts/atlas-staging-contract.test.mjs
scripts/deploy-atlas-staging.mjs
scripts/verify-atlas-staging.mjs
docs/runbooks/atlas-staging-deployment.md
docs/implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness-implementation.md
```

`AtlasApp.tsx` and its focused test are included because the connected shell renders `AtlasConnectionPanelView` directly; the wrapper alone cannot display the environment label there.

## Implemented behavior

- One browser environment reader supports exactly `local` and `staging`; missing, blank, `production`, and unknown modes fail closed.
- Local remains loopback-only. Staging is HTTPS, non-loopback, exact Supabase project-host syntax, credential-free, internally consistent, and live-OPS denied.
- Browser keys accept supported publishable keys and legacy anonymous JWTs. Secret keys, service-role JWTs, malformed keys, and unrelated browser credentials are denied without echoing values.
- Invalid configuration creates no Supabase client. The existing no-retry client, Auth-session, late-response, RPC registry, and backend-authorization boundaries remain unchanged.
- The connected shell shows only `Local · non-production`, `Atlas staging · non-production`, or a safe non-production configuration-error label.
- One staging-specific shared script contract owns protected names, live-OPS denial, target validation, redaction, and exact-head GitHub evidence verification.
- Deployment uses ordered repository migrations only, installs no data package, and deploys no Edge Function.
- The default verifier is read-only and performs platform, catalog/security, Auth/Actor, approved-read, and sign-out checks. The first-deployment path invokes its platform-only phase before separately reviewed data packages exist.
- One `workflow_dispatch` workflow uses protected environment `atlas-staging`, built-in `GITHUB_TOKEN`, frozen install, minimal read permissions, exact SHA checkout, exact-head certification reuse, and no local Supabase startup or duplicate full suite.

## Security and rollback

The live OPS denylist is exactly `qnthofvccilhnefdcxnz`. Deployment and verification reject both the exact reference and derived hostname and reject reference/URL mismatch. Diagnostics redact known protected values, database URLs, publishable/secret keys, JWTs, and bearer tokens. No credential value is stored in the repository.

There is no implementation-time database rollback because no hosted or local schema mutation is part of this change. A later hosted correction must be a reviewed forward migration. Code rollback is a revert of this bounded commit.

## Validation

Required local validation:

```text
pnpm ops:workspace
pnpm format
pnpm typecheck
pnpm test
pnpm build
git diff --check
```

All staging script tests mock or avoid network, process, and CLI boundaries. No test contacts Supabase.
