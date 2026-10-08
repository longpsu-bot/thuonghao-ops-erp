# 02D reproduction and evidence boundaries

Use the explicitly authorized canonical checkout. This directory wraps existing Supabase replay, 02C catalog/verifier, pgTAP and full-integration command registries. It is not a schema baseline or a replacement bootstrap engine. No historical migration, production function, contract, document layout or hosted setting changes.

## Independent clean cycles (PowerShell)

Verify clean current main, origin, branch and `pnpm ops:workspace` before task edits. Read the repository authority and the Supabase CLI version/help for `start`, `stop`, `db reset`, `migration list` and `test db`. This certification used CLI 2.111.0 and PostgreSQL 17.6. Do not link a hosted project. Never use `stop --all`, a normal developer project or another task's checkout.

Create a fresh temporary Supabase directory outside Git. Refuse an existing path until its ownership/state is inspected:

```powershell
$taskDir = Join-Path $env:TEMP 'atlas-backend-convergence-02d'
if (Test-Path -LiteralPath $taskDir) { throw 'Inspect existing disposable path before reuse.' }
New-Item -ItemType Directory -Path (Join-Path $taskDir 'supabase') | Out-Null
$taskConfig = (Get-Content supabase/config.toml -Raw).
  Replace('project_id = "thuonghao-ops-erp"', 'project_id = "atlas-backend-convergence-02d"').
  Replace('5432', '5552')
Set-Content -LiteralPath (Join-Path $taskDir 'supabase/config.toml') -Value $taskConfig -Encoding utf8
foreach ($taskLink in @('migrations', 'tests', 'local', 'packages', 'functions')) {
  New-Item -ItemType Junction -Path (Join-Path $taskDir "supabase/$taskLink") `
    -Target (Join-Path (Get-Location) "supabase/$taskLink") | Out-Null
}
$env:SUPABASE_WORKDIR = $taskDir
$env:ATLAS_LOCAL_DB_CONTAINER = 'supabase_db_atlas-backend-convergence-02d'
$taskExclusions = 'realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
```

Seeds are disabled in the canonical configuration. Keep database, Auth, PostgREST and Kong for real authenticated API checks. Existing reference/import fixtures are synthetic; do not extract Live OPS data. Check ports 55520–55529 are free before start. Inspect project-specific Docker containers/volumes and require none before the first start.

For each cycle, execute **sequentially**, checking each exit status before continuing:

```powershell
pnpm exec supabase start --workdir $taskDir -x $taskExclusions *> (Join-Path $taskDir 'replay-1.log')
if ($LASTEXITCODE) { throw 'BOOTSTRAP_MIGRATION_FAILURE: preserve the original log.' }
pnpm exec supabase migration list --local --workdir $taskDir
node docs/testing/artifacts/atlas-backend-convergence-02d/reproduce.mjs 1
if ($LASTEXITCODE) { throw 'Cycle 1 contract/evidence gate failed.' }
pnpm exec node docs/testing/artifacts/atlas-backend-convergence-02d/authenticated-api.mjs 1
if ($LASTEXITCODE) { throw 'Disposable Auth/API gate failed.' }
pnpm exec supabase stop --project-id atlas-backend-convergence-02d --no-backup
if ($LASTEXITCODE) { throw 'Disposable discard failed.' }
$taskVolumes = docker volume ls --filter name=atlas-backend-convergence-02d --format '{{.Name}}'
$taskContainers = docker ps -a --filter name=atlas-backend-convergence-02d --format '{{.Names}}'
if ($taskVolumes -or $taskContainers) { throw 'Independent replay requires complete disposable discard.' }
pnpm exec supabase start --workdir $taskDir -x $taskExclusions *> (Join-Path $taskDir 'replay-2.log')
if ($LASTEXITCODE) { throw 'BOOTSTRAP_MIGRATION_FAILURE: preserve the original log.' }
pnpm exec supabase migration list --local --workdir $taskDir
node docs/testing/artifacts/atlas-backend-convergence-02d/reproduce.mjs 2
if ($LASTEXITCODE) { throw 'Cycle 2 contract/evidence gate failed.' }
node docs/testing/artifacts/atlas-backend-convergence-02d/reproduce.mjs compare
if ($LASTEXITCODE) { throw 'Semantic repeatability gate failed.' }
pnpm exec node docs/testing/artifacts/atlas-backend-convergence-02d/authenticated-api.mjs 2
if ($LASTEXITCODE) { throw 'Disposable Auth/API gate failed.' }
pnpm exec supabase stop --project-id atlas-backend-convergence-02d --no-backup
```

The second start performs fresh platform initialization and chronological migration application after removal of every project volume, including Auth state. No fixtures or custom roles survive from the first cycle. The configuration and canonical-file junctions are the only shared inputs.

Run scale before other CPU-heavy work. Preserve the existing 8-second deadline, 4-second operator target and every assertion. An operator-target miss is retained as a measurement, not relabeled PASS or a reason to optimize in 02D.

Do not run Auth/reference provisioning concurrently with catalog/SQL suites: provisioning adds authorization facts and legitimately changes capability counts. SQL fixtures roll back; Auth/API checks run afterwards and persist only in the disposable project. Master import suites rely on the official CLI's pgTAP session preamble; the wrapper supplies that extension/search path inside their rolled-back test transaction. This is test infrastructure, not manual migration dependency repair.

`reproduce.mjs <cycle> --evidence-only` may refresh only the three readout projections after all 51 suite results are successful. It requires exact ordered suite names, successful exits, valid TAP plans and assertion digests. It reruns the full three selected fixtures and the catalog/ledger verifier; it does not certify a skipped suite. Normal reproduction uses the complete commands above.

## What is compared

- `cycle-1.json` / `cycle-2.json`: complete migration version/name manifests; exact byte-equivalence with the existing seven-section 02C effective manifest and read-only verifier; supplementary effective catalog counts/hashes; every suite's exit, TAP plan and assertion-description digest; stable semantic command outcomes, exact Recipe/Unit facts, source mappings/fingerprints/checksums, D-047 provenance, released PO/PXK content and receipt/event/audit counts.
- `catalog-extra.sql`: schema owner/ACL identities, all columns/types/defaults, constraints, trigger definitions, view bodies, role memberships and default ACL contents. Full supplementary definitions remain in temporary JSON files; their deterministically ordered hashes are committed compact evidence. Compare requires the recorded project-specific discard and absence of all project containers/volumes. On mismatch, compare both temporary files and report every changed row before any certification.
- `semantic-evidence.sql`: business-key projections appended before the final rollback of the unchanged complete purchase, PXK and Recipe import fixtures. PO/PXK arrays are sorted by their complete serialized tuples to resolve tied business keys without dropping facts. UUID-generated roots, timestamps, document-number UUID suffixes and per-command fingerprint hashes are not cross-cycle equality targets. Source fingerprint/currentness/expected-version correctness remains asserted by the original tests. School/location UUIDs inside PO breakdowns are fixed synthetic reference identities, not random generated facts.
- `authenticated-api-*.json`: results from the existing full-integration registry's 15 relevant command entries, including real local password sign-in and browser-key RPCs. No SQL JWT simulation is described as hosted acceptance.
- `document-business-output.test.ts`: repeated output-data/PDF-definition generation leaves issued input facts unchanged. Existing Shopping List proposal/no-command, released-only PO, snapshot/note/School breakdown, exact quantity/Unit and PXK export tests supply the other business-output checks. Binary timestamps/visual geometry are not equality criteria.

Raw CLI status/start logs may contain local keys: retain them outside Git and do not print them. SQL/API diagnostics are sanitized with the existing redactor. The PR retains compact observations rather than credentials, raw reference payloads or binary documents.

## Frontend validation

```powershell
pnpm format
pnpm typecheck
pnpm test --exclude '**/.superpowers/**' --maxWorkers=2
pnpm build
pnpm exec vitest run docs/testing/artifacts/atlas-backend-convergence-02d/document-business-output.test.ts src/modules/atlas/procurement/purchaseOrderExports.test.ts src/modules/atlas/dispatch/schoolDispatchReleaseExports.test.ts src/modules/atlas/planning-inputs/confirmed-needs/shoppingListService.test.ts src/modules/atlas/planning-inputs/confirmed-needs/shoppingListContract.test.ts --exclude '**/.superpowers/**' --maxWorkers=1
pnpm exec prettier --check docs/implementation-tasks/TASK-ATLAS-BACKEND-CONVERGENCE-02D.md docs/testing/artifacts/atlas-backend-convergence-02d/*.md docs/testing/artifacts/atlas-backend-convergence-02d/*.mjs docs/testing/artifacts/atlas-backend-convergence-02d/*.json docs/testing/artifacts/atlas-backend-convergence-02d/*.ts
git diff --check
pnpm ops:workspace
```

The local exclusion removes only an existing ignored historical checkout, no tracked test. GitHub's unchanged `Frontend CI / Format, typecheck, test, build` runs the full suite on the exact final PR head. Record local failures separately from CI; never weaken timeouts/assertions.

Hosted Staging certification is **NOT RUN** and requires separately authorized deployment plus real connected acceptance. Discard/replay is the disposable rollback. After operational use, preserve immutable facts and use reviewed restoration/forward correction.
