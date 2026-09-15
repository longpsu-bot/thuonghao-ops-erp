# Master-data rehearsal import — local operator runbook

## Authority and scope

Use the approved `MASTER-DATA-REHEARSAL-IMPORT-01` specification and execution-Actor amendment. The source is an immutable OPS v1 master snapshot. No operational history, live Google Menu configuration, hosted Staging write or production cutover is authorized by this runbook.

`Kg`/`kg` resolve to one `kg` Unit; `Hủ`/`Hũ` resolve to one `Hũ`. Unknown Units remain blockers. No fuzzy spelling or identity matching is allowed.

Recipe source identity is Dish + School Type; line identity is Recipe + Ingredient. Physical Recipe/BOM source IDs remain evidence only. Missing root rows are not deleted; complete-set child removal is represented explicitly. Source-only contact details are retained in snapshot evidence, not guessed into structured contact fields.

## 1. Verify the implementation checkout

Use the task-authorized real Git worktree and pinned Node/pnpm from `package.json`. Verify the remote, branch, exact HEAD, clean tree and `pnpm ops:workspace`. Do not switch, reset, stash or clean another checkout.

The read-only source and target are different projects:

- OPS v1: `qnthofvccilhnefdcxnz`, read-only extraction only.
- Shared Atlas Staging: `rnzxmxiiqgtdevzregff`, forbidden as an apply target in this runner.
- Disposable local project: `atlas-master-rehearsal-01`.

## 2. Isolate the local database

Set `SUPABASE_WORKDIR` to a separate disposable Supabase working directory. Its `supabase/config.toml` must identify `project_id = "atlas-master-rehearsal-01"`. Assign non-conflicting local ports (the rehearsal uses 553xx rather than the existing stack's 543xx) and expose only `atlas_api` as in the repository configuration. Point its migrations/tests/packages/functions at the exact implementation checkout using local directory junctions or equivalent local directory links.

Do not reuse or reset another task's `thuonghao-ops-erp` database. The runner requires both explicit disposable configuration and loopback API/DB status. It has no hosted mode.

Example, after verifying that the environment variable selects the isolated directory:

```powershell
$env:SUPABASE_WORKDIR = '<absolute-disposable-work-directory>'
pnpm exec supabase start
pnpm exec supabase db reset --local --no-seed
```

Creating configuration for this disposable project is local test setup, not an alteration of the shared repository's Supabase project identity. Keep raw source files and local logs outside Git. Do not display CLI status JSON because it includes local keys.

## 3. Extract one immutable source snapshot

The preferred real-source path is the manual **Atlas OPS v1 Master Data Rehearsal Validate** GitHub Actions workflow. Dispatch it only from the workflow definition on current `main` and provide the exact current-main SHA. The job verifies the checked-out SHA against `origin/main` **before dependency installation or repository code execution**. It then injects the existing protected `ATLAS_STAGING_SUPABASE_ACCESS_TOKEN` only into the extraction step.

The GitHub workflow is validate-only: the raw snapshot exists only under `RUNNER_TEMP`, is never uploaded, is removed in the final cleanup step, and is previewed against a disposable local Supabase database created from repository migrations. The workflow copies only the repository `supabase/` tree into `$RUNNER_TEMP/atlas-master-rehearsal-01`, rewrites that disposable copy to the required `project_id = "atlas-master-rehearsal-01"`, exports `SUPABASE_WORKDIR`, and passes the workdir explicitly to local Supabase start/reset/stop. It never rewrites the repository checkout's Supabase identity.

A preview exit code of `2` means the importer executed correctly and rejected the current source facts; the GitHub validation job records that report as a successful validation outcome. Exit code `0` is an unblocked preview. Runtime/safety failures still fail the workflow. The workflow contains no apply path, Atlas Staging project target, Google-source configuration, or hosted database mutation. Using the `atlas-staging` GitHub Environment here grants access to the existing protected secret only; it does not authorize or perform a Staging write.

For local support/debugging only, the same read-only extraction command requires the already-authorized management token through `ATLAS_STAGING_SUPABASE_ACCESS_TOKEN`. Never commit, print or pass the token on a command line. The extractor uses only the fixed `/database/query/read-only` source endpoint and verifies read-only role/table privileges plus unfiltered source completeness.

```powershell
pnpm ops:v1:master:snapshot -- --snapshot-id ops-v1-master-rehearsal-a --output '<private-output>/ops-v1-master-a.json'
```

Choose a new snapshot ID and path for every fresh extraction. Existing files are never overwritten. Preserve the returned checksum, source counts, extractor version and export time. Equivalent business facts with different source Recipe/BOM row IDs preserve business fingerprints, but the snapshot checksum still records changed source evidence.

The normalizer keeps invalid rows and reports them; do not delete, filter or correct records inside the snapshot to force a green gate. Staff corrections belong in OPS v1 and must be captured in a fresh extraction.

## 4. Preview — no target business writes

```powershell
pnpm local:master-data:rehearsal:preview -- --file '<private-output>/ops-v1-master-a.json'
```

Use `--json` for the machine-readable plan, source counts, actions and issues. JSON contains master facts; store it privately, not as a public or committed artifact. The text report deliberately omits raw free-form contact values.

A successful preview prints `Gate: NOT_APPLIED`. This is a diagnostic statement, not a new persisted business lifecycle or import certification. A blocked preview prints `REJECTED`, exits with code 2 and never calls apply.

Review every `BLOCKED`, `TARGET_DRIFT`, `MISSING_FROM_SOURCE`, `REMOVE_RELATIONSHIP` and `SOURCE_ONLY_UNMAPPED` entry. The design-time `Deact Test` / Unit `123` cluster is an example of a legitimate rejection; current staff corrections may change which blockers actually occur. Counts in documentation are observations, not hardcoded filters.

## 5. Apply the exact reviewed plan with an explicit Actor

The existing ACTIVE Atlas Actor must be explicitly supplied. The database records the Actor, database principal and actual execution time. The Actor is execution context, not part of the source snapshot. The runner creates no Actor, Auth user, role or capability.

For synthetic local acceptance only, a rolled-back test or an explicit disposable-fixture SQL setup may provision a clearly named synthetic Actor. Never reuse a hosted synthetic actor for real attribution.

Copy the reviewed preview's 64-character plan checksum:

```powershell
pnpm local:master-data:rehearsal:apply -- --file '<private-output>/ops-v1-master-a.json' --actor-id '<existing-active-Atlas-actor-UUID>' --plan-checksum '<reviewed-plan-SHA256>'
```

The runner previews again, compares the exact reviewed checksum, then calls only the private actor-bound apply. A changed plan requires a new explicit review; it is not silently accepted. Missing/inactive Actors, different-Actor replay, target drift, checksum mismatch and invalid source facts fail closed. A complete accepted apply is atomic and all recipe integrity guards remain active.

The backend materializes supporting Recipe Versions and line revisions and makes valid current recipes available for Planning. It records a truthful current import, not fictitious v1 authoring history. Once approved Atlas Weekly Menu evidence references the Dish, later base Recipe/BOM migration updates are blocked by the existing commitment rule.

## 6. Reconcile and replay

Apply performs authoritative readback. Only successful apply plus reconciled readback produces `REHEARSAL_ACCEPTED`. Re-run preview against the same file; it should contain only `NO_CHANGE` plus explicit reviewed root-absence findings. Copy its current plan checksum and repeat apply using the same Actor. Existing identities, versions and quantities must remain unchanged; the backend returns `REPLAYED`.

A later fresh snapshot uses the same importer/crosswalk. Legitimate changes update the same roots; composition corrections append successors; no disappearance silently deletes an identity. An older already-applied snapshot may be replayed for its receipt, but it must not overwrite newer business facts.

Validate source-to-target counts, mapping counts, canonical Units, Recipe/BOM membership and exact quantities. Check that no operational table was populated by the master import. Keep reconciliation reports and checksums as evidence. Do not commit the raw source snapshot.

## 7. Certification

```powershell
pnpm exec vitest run scripts/ops-v1-master-snapshot-contract.test.mjs scripts/master-data-rehearsal-report.test.mjs scripts/run-local-master-data-rehearsal.test.mjs
pnpm exec supabase test db supabase/tests/rmvp_01_atlas_master_data.sql supabase/tests/rmvp_02a_connected_recipes_bom.sql supabase/tests/master_data_rehearsal_import.sql supabase/tests/master_data_rehearsal_recipe_import.sql --local
pnpm certify:supabase:full-integration
```

Verify `SUPABASE_WORKDIR` before the full integration command: that command resets and later stops its selected local stack. Use the disposable project only. GitHub Frontend CI owns full format/typecheck/test/build validation. No timeout, assertion, policy or security control may be weakened to obtain a pass.

Synthetic tests certify implementation behavior, not the quality of the actual v1 source. Report real-source rejection separately from implementation failures or missing extraction credentials. Never claim a full real-source rehearsal from a synthetic fixture alone.

## Final boundary

This runner never grants `CUTOVER_READY` or hosted-write authority. Shared Staging rehearsal requires separate approval, an explicit fixture-isolation/canonical-Unit plan, and real data reconciliation. Final refresh requires a fresh immutable source snapshot in the agreed master-data freeze window. PR #286 and the real Google Weekly Menu source remain outside this task.
