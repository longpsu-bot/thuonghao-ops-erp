# TASK-RMVP-01 — Atlas database and connected master data

## Outcome

Deliver one independently deployable Atlas migration plus connected Vietnamese Master Data experiences for:

- Schools and default student/teacher portions
- Ingredients and purchasing attributes
- Predefined authoritative Ingredient Type and Ingredient Order Group catalogs
- Suppliers and contact information
- Atomic per-ingredient supplier priorities
- Controlled one-way legacy snapshot import and reconciliation

## Allowed scope

- `atlas_admin`, `atlas_core`, `atlas_audit`, `atlas_api`, and the private `atlas_legacy` migration-evidence schema
- One new `NOLOGIN NOINHERIT` role: `atlas_master_data_command_runtime`
- Two master-data reads and seven master-data write commands
- Existing Atlas React navigation and Admin workbenches
- Local import/provisioning/acceptance scripts, focused tests, and existing CI workflow

## Prohibited changes

- No hosted or production database mutation
- No direct live OPS v1/v2 or Retool dependency
- No additional daily operating stage or module-boundary change
- No generic CRUD/import framework
- No delete of referenced ingredient history
- No RLS bypass, service-role browser credential, or direct private-table browser access
- No second migration or new CI workflow

## Acceptance criteria

- Fresh `supabase db reset --local` applies exactly one RMVP-01 migration.
- Valid explicit snapshot imports, reports inserted/updated/skipped/rejected counts, reconciles, and replays idempotently.
- Missing references and duplicate/invalid priorities reject without partial target writes.
- Ingredient classifications resolve to authoritative catalog IDs; unknown, inactive-new and conflicting ID/text submissions reject without implicit catalog creation.
- The exact runtime/grant/RLS/function catalog passes focused and whole-platform security tests.
- An authenticated, capable global actor can read and update schools, ingredients, suppliers, and priorities.
- Invalid, denied, stale, conflicting, and lost-session outcomes remain safe and actionable.
- Successful writes have one receipt, one Admin domain event, one audit event, and authoritative readback.
- The UI supports loading, empty, ready, editing, validation, permission-denied, stale, save-success, retry, and session-loss states.
- Local acceptance signs in, changes master data, refreshes, signs out, signs in, and verifies persistence.

## Verification

Focused local checks:

```bash
pnpm exec supabase db reset --local
pnpm exec supabase test db supabase/tests/rmvp_01_atlas_master_data.sql --local
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm local:master-data:import -- --file supabase/local/rmvp_01_master_data_snapshot.example.json
pnpm local:master-data:import -- --file supabase/local/rmvp_01_master_data_snapshot.example.json
pnpm local:auth:provision
pnpm local:rmvp01:verify
pnpm typecheck
pnpm test
pnpm build
```

GitHub Actions owns the routine frozen install, formatting, typecheck, test, build, whitespace, and local Supabase integration suite on the pull request.
