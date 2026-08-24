# ATLAS-STAGING-CERT-LOCAL-01 — Synchronous Local Exact-Head Certification

**Status:** Implementation complete; delivery blocked by required-baseline Full Integration failure

**Required baseline:** `f7a8d1e71720131ac0ba40f6db8aee355a635897`

**Branch:** `infra/atlas-local-staging-certification`

## Objective

Keep the protected Atlas Staging deployment usable when hosted GitHub Actions are unavailable, without adding an uncertified path. The caller must explicitly select exactly one certification source:

```text
github → successful exact-head Frontend CI and Supabase Full Integration evidence
local  → synchronous shared frontend and Supabase Full Integration execution
```

Both modes require the requested commit to exist, exact `HEAD`, containment in current `origin/main` and a clean worktree. Those Git facts are revalidated after certification and before hosted mutation.

## Implementation boundary

The change:

- adds shared repository-owned frontend and Supabase Full Integration entrypoints;
- makes the corresponding GitHub workflows call those entrypoints;
- requires explicit `--certification github|local` on the protected deployment command;
- runs local frontend certification before local Supabase certification and returns directly into the existing deployment path;
- preserves the approved Atlas Staging reference, live OPS denylist, credential redaction, browser-key rules, repository migration authority, `atlas_api` exposure, migration-history equality and catalog/security verification;
- performs no hosted mutation as part of implementation or validation.

It changes no business migration, Planning behavior, React UI, Procurement, Warehouse, Dispatch, Retool export, OPS v1/v2 resource, hosted data or Edge Function.

## Shared certification authority

`certify:frontend` owns frozen dependency installation followed by formatting, typecheck, tests and build. `Frontend CI / Format, typecheck, test, build` calls this entrypoint.

`certify:supabase:full-integration` owns the reduced local stack lifecycle, complete ordered pgTAP catalog, fixture preparation and browser-key verification sequence previously embedded in `Supabase Full Integration`. It inspects the pinned CLI version and required flags, stops on the first meaningful failure, emits bounded redacted diagnostics and always attempts local cleanup. The GitHub Full Integration job and protected local deployment call this same entrypoint.

## Safety evidence

Focused tests prove:

- GitHub success and missing evidence behavior remain fail-closed;
- GitHub mode requires workflow context and never falls back to local;
- missing, unknown and skip-like certification selectors fail;
- wrong HEAD, missing `origin/main` ancestry and dirty worktree fail before either suite;
- frontend failure prevents Supabase certification and hosted mutation;
- Supabase failure prevents hosted mutation;
- both local suites must pass in order before link, migration push, exposure verification or hosted verification;
- the exact approved Staging target and live OPS rejection remain intact;
- protected diagnostics remain redacted.

## Migration, rollback and operational effects

There is no schema migration and no hosted operational effect in this task. Repository rollback is a normal revert of the scoped scripts, workflow wiring and documentation before any later deployment. Already deployed database history remains forward-only and unchanged.

## Validation record

- `pnpm exec vitest run scripts/atlas-staging-contract.test.mjs` — 57 passed.
- `pnpm certify:frontend` — passed frozen install, formatting, typecheck, full tests and build.
- `pnpm certify:supabase:full-integration` — correctly stopped on the first failure: assertion 56 of `pa_06e_h0cb_materialization_registry_security_catalog.sql` excludes eight `atlas_core.issue_222_*` functions created by required-baseline migration `20260823090858_issue_222_closed_loop_planning_corrections.sql`.

The failing migration and catalog test are unchanged from `origin/main`. Correcting that Planning-owned catalog is prohibited by this task, so commit, push and Draft PR delivery remain blocked pending a separately authorized baseline correction.

GitHub Actions were not dispatched or rerun. Atlas Staging, live OPS, Retool and every hosted database remained untouched.
