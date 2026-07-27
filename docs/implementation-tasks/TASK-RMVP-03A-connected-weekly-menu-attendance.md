# TASK-RMVP-03A — Connected Weekly Menu and Attendance

## Outcome

Deliver one migration and one connected Vietnamese `Nguồn kế hoạch` workbench for explicit-week Weekly Menu and Attendance preview, draft replacement, validation, exact approval snapshots, reasoned reopen, command-audit and approval history, and read-only readiness comparison.

## Allowed scope

- Existing private Weekly Menu, Attendance, approval snapshot, actor, receipt, event, and audit relations
- Existing `atlas_planning_command_runtime` and `atlas_read_runtime`
- Three reads/previews, nine bounded commands, and four capabilities
- Existing Atlas React shell
- Narrow `.xlsx`/tab-paste parsing using the already pinned workbook dependency
- Focused tests, local browser-key acceptance, documentation, and the existing CI workflows

## Prohibited changes

- No new database table, trigger, role, module boundary, business concept, status, or operating stage
- No generic workbook/CRUD framework
- No automatic creation of missing School or Dish references
- No silent blank-to-zero inference
- No direct browser access to private schemas or service-role credential
- No mutation of prior approval snapshots or silent historical rewrite
- No RMVP-03B Planning Input Readiness write, RMVP-04 Need Generation, Confirmed Need, Purchase Planning, Purchase Handoff, or Warehouse write
- No hosted, production, OPS v1/v2, or Retool mutation
- No second migration or new CI workflow

## Acceptance criteria

- A fresh reset applies exactly one RMVP-03A migration without a table, trigger, or role delta.
- The exact API catalog contains 58 functions and retains the private-schema boundary.
- Exactly four Planning-input capabilities are assigned to the synthetic operator role.
- Authorized shaped reads return one explicit-week workbench; auth substitution and permission denial fail closed.
- Weekly Menu and Attendance previews are non-writing, checksum-backed, reference-strict, and preserve source-row evidence.
- Menu save atomically replaces all five typed slots and preserves stable School/date/slot line identity.
- Attendance default creation is menu-aware; explicit `0` is legitimate and blanks are not inferred.
- Exact save replay returns the original receipt; exact canonical replacement is `NO_CHANGE` with no event/audit write.
- Validation and approval follow inherited lifecycles; approval creates exact immutable line snapshots.
- Reasoned reopen advances version, preserves prior approval evidence, and permits later reapproval with a new snapshot.
- Authorized workbench reads expose expandable command-audit and immutable approval histories.
- Readiness is read-only and true only when both current inputs are approved.
- Connected and review-mode UI cover draft, validated, approved, reopened, blockers, warnings, zero, differing defaults/approved values, permission, retryable concurrency, stale data, session loss, and later disabled boundaries.
- Browser-key acceptance proves the complete Menu/Attendance lifecycle, stable rows, snapshots, replay/no-change, explicit zero, reauthentication, and readiness without a service-role browser credential.
- Documentation states security, Retool evidence mapping, migration/rollback, and production exclusions.

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

The browser can use only `atlas_api`. All 12 functions use exact authenticated execution grants, `SECURITY DEFINER`, and an empty `search_path`. Write functions are owned by the existing least-privilege Planning runtime; reads and previews are owned by the existing read runtime. RLS policies admit only the required operations. Narrow read-only Recipe/effective-BOM access exists solely for validation warnings and adds no cross-domain write path. `anon` and `service_role` execute no RMVP-03A function.

## Migration and rollback

The task adds `20260727150000_rmvp_03a_connected_weekly_menu_attendance.sql`. It adds no relation or role. Local rollback is a rebuild to the prior migration. Any deployed rollback must be a reviewed forward migration that removes only the RMVP-03A functions, policies, grants, and four capability assignments without deleting operational or approval-history data.
