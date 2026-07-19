# TASK-PA-06E-H0A1 — School, Customer, and Delivery-Location Foundation

**Status:** Implemented and locally validated on the task branch; pending draft-PR review

**Issue:** [#117](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/117)

**Task branch:** `backend/pa-06e-h0a1-school-location-foundation`

**Parent task:** [TASK-PA-06E-H0](TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**Decision:** [Decision PA-06E-H0A1 — School and Delivery-Location Ownership](../decisions/decision-pa-06e-h0a1-school-delivery-location-ownership.md)

## Objective

Add the minimum private Admin references and relational authorization scope needed for a later genuine school-catering Planning line. This task does not create Planning lineage, calculation, confirmation, or public API behavior.

## Bounded implementation

- widen `atlas_admin.customers.customer_type` to exactly `WHOLESALE` and `SCHOOL_CATERING` while retaining all existing rows and IDs;
- retain `atlas_admin.delivery_locations` as customer-owned service locations and add the composite key required to prove same-customer school ownership;
- add private `atlas_admin.school_types` and `atlas_admin.schools` references with database-generated UUIDs, stable lowercase codes, lifecycle/version controls, and `ON DELETE RESTRICT` foreign keys;
- require each school to belong to a `SCHOOL_CATERING` customer and to name a default delivery location owned by that customer;
- add nullable `atlas_core.actor_scopes.school_id`, the `SCHOOL` scope kind, exact target checks, and active-scope uniqueness;
- force RLS on both new tables, grant no direct browser/API access, add no policies, functions, roles, capabilities, or seed rows.

The existing delivery-location timezone default remains `Asia/Bangkok`. Synthetic school fixtures explicitly use `Asia/Ho_Chi_Minh`; the task does not change the global default.

## Files and acceptance evidence

- Migration: `supabase/migrations/20260719115318_pa_06e_h0a1_school_customer_location_foundation.sql`
- Focused pgTAP: `supabase/tests/pa_06e_h0a1_school_customer_location_foundation.sql`
- Decision and dependency/status references in the bounded PA-06E-H0 documentation set

The focused test must prove Wholesale compatibility, school ownership integrity, same-customer default-location integrity, lifecycle and display-order rules, prior and new scope behavior, forced RLS and ownership, fail-closed grants/default privileges, indexed foreign keys, no role/capability seeds, and the unchanged exact 18-function `atlas_api` surface.

## Exclusions

No Menu, Attendance, Recipe/BOM, Need Generation, Theoretical Need, Confirmed Need, quantity policy, command/RPC, read API, capability, role, React, generated type, package, OPS v1, `public`, `ops_v2`, Retool, hosted Supabase, credential, deployment, or production-data change is part of H0A1.

## Migration and rollback

The migration is additive and seeds no production row. Before operational school data exists, an unshipped migration may be reverted normally. After use, do not delete school history or restore the Wholesale-only constraint destructively; revoke any unsafe path and forward-fix with a reviewed additive migration. Every new operational foreign key uses `ON DELETE RESTRICT`.

## Validation record

- `pnpm install --frozen-lockfile`: pass; lockfile and installed dependencies were already current.
- local Supabase start and `supabase db reset --local`: pass; all migrations replayed through H0A1.
- focused `supabase test db supabase/tests/pa_06e_h0a1_school_customer_location_foundation.sql --local`: pass, 59/59 assertions.
- `pnpm format`: pass.
- `supabase db diff --local --schema atlas_admin,atlas_core`: pass; no schema changes found after reset.
- affected-schema database lint: no errors. It reports one pre-existing warning in `atlas_core.pa_05d_safe_date` about an `IMMUTABLE` routine containing a `STABLE` expression; H0A1 does not alter that function.
- independent catalog inspection: both new tables are owned by `atlas_owner`, have RLS enabled and forced, and have zero policies; API-role direct DML and exposed default-ACL entries are zero; all four H0A1 foreign keys are indexed; role/capability seed counts remain zero; the exact 18-function `atlas_api` registry is unchanged.

Full routine frontend validation remains owned by GitHub Actions on the draft pull request.
