# TASK-RMVP-03A — Connected Weekly Menu and Attendance

## Outcome

Deliver one migration, one read-only Google source Edge adapter, and one connected Vietnamese `Nguồn kế hoạch` workbench for database-backed Dish Types, explicit Google/`.xlsx` source preview, draft replacement, validation, exact approval snapshots, reasoned reopen, command-audit and approval history, and read-only readiness comparison.

## Allowed scope

- Existing private Weekly Menu, Attendance, approval snapshot, actor, receipt, event, and audit relations
- Existing `atlas_planning_command_runtime` and `atlas_read_runtime`
- Existing `atlas_master_data_command_runtime` for extending the existing Dish commands
- Exactly `atlas_admin.dish_types` and `atlas_planning.weekly_menu_google_sources`
- One nullable `dishes.dish_type_id` foreign key and one typed Menu slot-code foreign key
- Exactly one JWT-verified read-only `atlas-weekly-menu-google-sync` function
- Three reads/previews, nine bounded commands, and four capabilities
- Existing Atlas React shell
- Narrow `.xlsx`/tab-paste parsing using the already pinned workbook dependency
- Focused tests, local browser-key acceptance, documentation, and the existing CI workflows

## Prohibited changes

- No relation beyond the two authorized typed configuration relations; no new trigger, role, module boundary, status, or operating stage
- No generic workbook/CRUD framework
- No background sync, Google write-back, OAuth management UI, or direct connector write to business tables
- No automatic creation of missing School or Dish references
- No silent blank-to-zero inference
- No direct browser access to private schemas or service-role credential
- No mutation of prior approval snapshots or silent historical rewrite
- No RMVP-03B Planning Input Readiness write, RMVP-04 Need Generation, Confirmed Need, Purchase Planning, Purchase Handoff, or Warehouse write
- No hosted, production, OPS v1/v2, or Retool mutation
- No second migration or new CI workflow

## Acceptance criteria

- A fresh reset applies exactly one RMVP-03A migration with two tables, one nullable Dish foreign-key column, no trigger delta, and no role delta.
- The exact API catalog contains 58 functions and retains the private-schema boundary.
- Exactly four Planning-input capabilities are assigned to the synthetic operator role.
- Authorized shaped reads return one explicit-week workbench; auth substitution and permission denial fail closed.
- Weekly Menu and Attendance previews are non-writing, checksum-backed, reference-strict, and preserve source-row evidence.
- Dish Type label/order/addition/inactivation changes the shaped read and dynamic Menu grid without a React catalog.
- Dish create/update requires an active `dish_type_id`; historical unmapped Dishes remain readable but cannot be newly assigned.
- Menu preview rejects unknown/inactive slot codes, unmapped Dishes, and cross-type assignments.
- The safe source list exposes only active configured Google sources; browser roles have no direct access.
- The explicit Google action performs authorized source resolution, fetches only matrix rows, uses the shared `.xlsx` parser, previews through PostgreSQL, and never saves automatically.
- Menu save atomically replaces dynamic typed slots and preserves stable School/date/slot line identity.
- Attendance default creation is menu-aware; explicit `0` is legitimate and blanks are not inferred.
- Exact save replay returns the original receipt; exact canonical replacement is `NO_CHANGE` with no event/audit write.
- Validation and approval follow inherited lifecycles; approval creates exact immutable line snapshots.
- Reasoned reopen advances version, preserves prior approval evidence, and permits later reapproval with a new snapshot.
- Authorized workbench reads expose expandable command-audit and immutable approval histories.
- Readiness is read-only and true only when both current inputs are approved.
- Connected and review-mode UI cover draft, validated, approved, reopened, blockers, warnings, zero, differing defaults/approved values, permission, retryable concurrency, stale data, session loss, and later disabled boundaries.
- Browser-key acceptance proves the complete Menu/Attendance lifecycle, stable rows, snapshots, replay/no-change, explicit zero, reauthentication, and readiness without a service-role browser credential.
- Browser-key acceptance additionally proves an active local synthetic source, real Edge handler authorization, deterministic mocked Google fetch, shared parsing, confirmed save, and one database-supplied dynamic Dish Type.
- Documentation states security, source-versus-authority, credential/deployment boundary, Retool evidence mapping, migration/rollback, and production exclusions.

## Verification

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm exec supabase test db supabase/tests/rmvp_03a_connected_weekly_menu_attendance.sql --local
pnpm local:auth:provision
pnpm local:master-data:import -- --file supabase/local/rmvp_01_master_data_snapshot.example.json
pnpm local:rmvp02a:verify
pnpm local:rmvp02a:verify
pnpm local:rmvp03a:verify
pnpm typecheck
pnpm test
pnpm build
pnpm build:review
```

GitHub Actions owns the routine frozen install, formatting, full typecheck/test/build/whitespace suite, local Supabase integration, and review export on the pull request.

## Security review

The browser can use only `atlas_api` plus the JWT-verified Edge route. All 12 APIs use exact authenticated execution grants, `SECURITY DEFINER`, and an empty `search_path`. Write functions are owned by the existing least-privilege Planning runtime; reads and previews are owned by the existing read runtime. Both new relations use forced RLS and exact policies. The Planning runtime has no Admin write and the Admin runtime has no Planning write. The Edge adapter forwards the bearer token, uses only a server-side read-only Google credential, exposes no source secret, and writes no business data. `anon` and `service_role` execute no RMVP-03A API.

## Migration and rollback

The task amends `20260727150000_rmvp_03a_connected_weekly_menu_attendance.sql`. It adds exactly two relations and no role. Local rollback is a rebuild to the prior migration. Any deployed rollback must be a reviewed forward migration that preserves or remaps Dish and Menu references before removing the Edge deployment, Dish foreign key, relations, functions, policies, grants, and capabilities. It must not delete operational or approval-history data.
