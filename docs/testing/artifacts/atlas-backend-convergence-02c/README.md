# 02C evidence reproduction

Use only a **separate disposable local database**, never linked Staging or Live OPS. The evidence runner rejects every container except `supabase_db_atlas-backend-convergence-02c`. Canonical source, fixtures and assertions are reused from the authorized checkout; no new production machinery is added.

1. Read Supabase CLI `start`, `db reset` and `migration list` help.
2. Create a temporary work directory outside the checkout, with `supabase/config.toml` based on the repository config. Set `project_id = "atlas-backend-convergence-02c"`, database port 55422 and separate service ports (replace the `5432` port prefix with `5542`). Leave seeds disabled.
3. Junction/symlink that work directory's `supabase/migrations` to this checkout's canonical migrations. Do not copy a second implementation checkout and do not add a hosted project link.
4. Run `pnpm exec supabase start --workdir <temporary-directory> -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor`. The CLI initializes its own database and chronologically applies the 94 canonical migrations. Verify a healthy isolated container; preserve the normal developer stack.
5. Run `pnpm exec supabase migration list --local --workdir <temporary-directory>` and require exact chronological version/name parity.

From the repository root, in PowerShell:

```powershell
$env:ATLAS_LOCAL_DB_CONTAINER = 'supabase_db_atlas-backend-convergence-02c'
node docs/testing/artifacts/atlas-backend-convergence-02c/reproduce.mjs catalog
node docs/testing/artifacts/atlas-backend-convergence-02c/reproduce.mjs performance
node docs/testing/artifacts/atlas-backend-convergence-02c/reproduce.mjs summary
node docs/testing/artifacts/atlas-backend-convergence-02c/reproduce.mjs regressions
node scripts/test-local-purchase-review.mjs need_generation_operational_scale.sql
node scripts/test-local-purchase-review.mjs pa_05b_supplier_direct_command_subset.sql
```

Run performance alone, before regression/frontend workload. Optional `performance scale` or `performance purchase` repeats just that fixture after a harness change. `summary` recomputes nearest-rank warm percentiles from both raw JSONL files. The complete existing scale suite supplies independent sequential-day timings and integrity assertions. Do not present different fixtures/methods as before/after results. No database change was justified in 02C.

`catalog.sql` is read-only; the verifier also runs in a read-only transaction. `effective-catalog.tsv` has seven sections with headings: FUNCTIONS, RELATIONS, ROLES, SCHEMA_PRIVILEGES, DEFAULT_ACL, POLICIES and INDEXES. Nulls are explicit. `measure.sql` is only temporary instrumentation inside rolled-back synthetic transactions. Its EXPLAIN plans include a temporary result sink, inclusive function cost and post-call deferred checks; they do not expose nested internal joins. Fixture-setup deferred constraints are checked outside measured groups; sample command constraints remain included. Production timeout and all guards remain enabled. Raw command-response hashes vary because generated identities differ; read hashes may vary with correlation/evaluation timestamps. They are observations, not equivalence assertions.

All identifiers/data in performance and pgTAP fixtures are synthetic. Staging exports contain migration names and advisor summaries only, no operator payload or credential. See the [implementation record](../../../implementation-tasks/TASK-ATLAS-BACKEND-CONVERGENCE-02C.md) for classifications, fixture/cardinality limits and open findings.
