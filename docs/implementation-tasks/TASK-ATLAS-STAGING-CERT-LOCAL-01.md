# ATLAS-STAGING-CERT-LOCAL-01 — Synchronous Local Exact-Head Certification

**Status:** Implementation complete; validated and ready for Draft PR

**Required baseline:** `1a3dba23b3470e07adcb75b4913e9a793e3207f3`

**Branch:** `infra/atlas-local-staging-certification`

## Objective

Keep the protected Atlas Staging deployment usable when hosted GitHub Actions are unavailable, without adding an uncertified path. The caller must explicitly select exactly one certification source:

```text
github → successful exact-head Frontend CI and Supabase Full Integration evidence
local  → synchronous shared frontend and Supabase Full Integration execution
```

Both modes require the requested commit to exist, exact `HEAD`, containment in current `origin/main` and a clean worktree. Local mode refreshes only `refs/remotes/origin/main` from canonical `origin` before each of its two Git-state checks, including the final check immediately before hosted mutation.

## Implementation boundary

The change:

- adds shared repository-owned frontend and Supabase Full Integration entrypoints;
- makes the corresponding GitHub workflows call those entrypoints;
- requires explicit `--certification github|local` on the protected deployment command;
- runs local frontend certification before local Supabase certification and returns directly into the existing deployment path;
- constructs certification subprocess environments from an explicit operating-system/tooling allowlist rather than inheriting workstation credentials;
- captures bounded, redacted Docker and project-local Supabase diagnostics before cleanup when Full Integration fails, while preserving the primary failure;
- preserves the approved Atlas Staging reference, live OPS denylist, credential redaction, browser-key rules, repository migration authority, `atlas_api` exposure, migration-history equality and catalog/security verification;
- performs no hosted mutation as part of implementation or validation.

It changes no business migration, Planning behavior, React UI, Procurement, Warehouse, Dispatch, Retool export, OPS v1/v2 resource, hosted data or Edge Function.

## Shared certification authority

`certify:frontend` owns frozen dependency installation followed by formatting, typecheck, tests and build. `Frontend CI / Format, typecheck, test, build` calls this entrypoint.

`certify:supabase:full-integration` owns the reduced local stack lifecycle, complete ordered pgTAP catalog, fixture preparation and browser-key verification sequence previously embedded in `Supabase Full Integration`. It inspects the pinned CLI version and required flags, stops on the first meaningful failure, captures bounded redacted Docker version/resource/container/log diagnostics before cleanup, and always attempts local cleanup without replacing the certification error. The GitHub Full Integration job and protected local deployment call this same entrypoint.

## Safety evidence

Focused tests prove:

- GitHub success and missing evidence behavior remain fail-closed;
- GitHub mode requires workflow context and never falls back to local;
- missing, unknown and skip-like certification selectors fail;
- wrong HEAD, missing `origin/main` ancestry and dirty worktree fail before either suite;
- failed first or final local `origin/main` refresh fails closed and prevents hosted mutation;
- local subprocesses exclude GitHub, cloud, npm, database, Supabase and staging credentials while retaining required platform/tool variables;
- frontend failure prevents Supabase certification and hosted mutation;
- Supabase failure prevents hosted mutation;
- both local suites must pass in order before link, migration push, exposure verification or hosted verification;
- the exact approved Staging target and live OPS rejection remain intact;
- failure diagnostics run before cleanup, remain bounded/redacted, and cannot replace the primary failure.

## Migration, rollback and operational effects

There is no schema migration and no hosted operational effect in this task. Repository rollback is a normal revert of the scoped scripts, workflow wiring and documentation before any later deployment. Already deployed database history remains forward-only and unchanged.

## Governance amendment

D-032 / ATLAS-ACT-01 retain their accepted 2026-08-06 exact-head GitHub CI history. D-043, accepted on 2026-08-24, records the narrow local synchronous substitute and its fresh-main, no-fallback, protected-boundary conditions.

## Validation record

Validation on the corrected `1a3dba23` baseline:

- `pnpm exec vitest run scripts/atlas-staging-contract.test.mjs` — 62 passed.
- `pnpm certify:frontend` — passed frozen install, formatting, typecheck, full tests, and build.
- `pnpm certify:supabase:full-integration` — passed the complete reduced-stack lifecycle, both resets, ordered pgTAP catalog, fixture preparation, and browser-key verification sequence.
- `git diff --check`, targeted Prettier, and Node syntax checks — passed.

GitHub Actions were not dispatched or rerun. Atlas Staging, live OPS, Retool and every hosted database remain untouched.
