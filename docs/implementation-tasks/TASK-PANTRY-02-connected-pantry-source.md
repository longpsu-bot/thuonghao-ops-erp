# TASK-PANTRY-02 — Connected Pantry Source

## Outcome

Implement the approved Planning-owned Pantry source from manual capture through immutable approval snapshot in one bounded migration and one connected Vietnamese source tab.

## Baseline and branch

- Approved baseline: `63c53f3326a6667c1de7004ebda4f24491d06afc`
- Branch: `feat/pantry-02-connected-pantry-source`
- Migration: `20260729032653_pantry_02_connected_pantry_source.sql`
- Contract: `PANTRY-02.v1`

## Delivered boundary

- Exactly five private Pantry relations
- Exactly six public Pantry APIs
- Exactly one capability: `planning.pantry.write`
- Zero new roles and zero new scope kinds
- Existing read and Planning command runtimes
- Manual Atlas source only
- Third `Nguồn kế hoạch` source tab with a bounded Pantry submodule
- Empty production Purpose catalog plus rolled-back, review-only, and loopback-only fixtures
- Exact lifecycle, stable replacement, zero-additions, snapshots, events, audit, idempotency, optimistic concurrency, and safe errors

## Acceptance evidence

- Clean local migration reset succeeds.
- PANTRY-02 pgTAP uses exact `plan(46)` and passes.
- Current platform security catalog uses exact `plan(22)` and passes with:
  - 96 private tables and forced RLS on all 96;
  - 19 capabilities;
  - 64 public APIs;
  - 126 private functions;
  - 75 triggers;
  - 433 policies;
  - 1,094 positive target grants;
  - 64 exact `authenticated` API executions;
  - zero `anon` or `service_role` API executions.
- Focused registry/API/component suite passes 26 assertions.
- TypeScript project typecheck passes.
- Loopback browser-key acceptance reaches:

```text
DRAFT v1
→ corrected DRAFT v2 with stable line UUID
→ VALIDATED v3
→ APPROVED v4 with one-line snapshot
→ REOPENED v5
→ zero-additions DRAFT v6 with prior line INVALID
→ VALIDATED v7
→ APPROVED v8 with zero-line successor snapshot
```

- Local physical assertions prove two immutable snapshots, one preserved historical snapshot line, eight domain events, eight audit events, and no downstream Planning or fulfilment mutation.

## Security review

All relations are private with forced RLS. Browser roles have no direct access. The six functions are fixed-search-path definers with exact grants. Read/preview use the existing read runtime; commands and the commit-time integrity guard use the existing Planning command runtime. No Admin, Procurement, Evidence, Warehouse, or Dispatch write privilege is added.

The deferred exact-snapshot guard is runtime-owned so it retains least-privilege private access when fired by PostgreSQL at transaction commit. Temporary schema-create authority used for ownership transfer is revoked in the same migration.

React supplies only raw operator fields. PostgreSQL derives Location and Unit, owns signatures and lifecycle decisions, and returns allowed actions.

## Migration and rollback

The single migration is forward-only operational history. Local rollback is a reset to the preceding migration. Any deployed rollback requires a reviewed forward migration that preserves or remaps working/snapshot evidence before removing the bounded objects. PANTRY-02 authorizes no hosted deployment.

## Validation commands

```bash
pnpm ops:workspace
pnpm exec supabase --version
pnpm exec supabase status
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/pantry_02_connected_pantry_source.sql --local
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm local:auth:provision
pnpm local:master-data:import -- --file supabase/local/rmvp_01_master_data_snapshot.example.json
pnpm local:pantry02:verify
pnpm test src/modules/atlas/connection/atlasRpc.test.ts src/modules/atlas/planning-inputs/pantry/pantryApi.test.ts src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx
pnpm format
pnpm typecheck
git diff --check
```

GitHub Actions owns the routine frozen install, full frontend test/build, review export, Qodana, and whitespace validation on the draft pull request.

## Exclusions confirmed

No production Purpose seed, hosted Supabase mutation, Edge Function, OPS v1/v2 mutation, Retool mutation, production data import, credential, dependency, workbook/Google/recurring import, generic source/workflow framework, Purpose administration, readiness persistence, Need Generation contribution, Confirmed Need, Purchase Handoff, supplier selection, Purchase Order, receiving, stock, Warehouse routing, Dispatch, or Wholesale command is included.

The next Pantry work remains a separately named readiness amendment.
