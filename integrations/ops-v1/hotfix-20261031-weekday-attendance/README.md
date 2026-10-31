# OPS v1 weekday attendance — 31 October 2026

The Owner approved hosted deployment provided all previously entered data stays
intact. Target only OPS v1 `qnthofvccilhnefdcxnz`. These manual migrations live
outside Atlas's migration directory and are never deployed to Atlas.

## Behavior and scope

Two optional checked `smallint[]` columns on `schools` hold five student/teacher
defaults, Monday at index 1 through Friday at index 5. Seed values match the five
supplied Attendance workbooks, joined by their retained School IDs. Explicit zero
is valid. Weekends and unconfigured Schools retain their scalar defaults.

New daily orders use these defaults through the existing insert trigger and both
active order-creation RPCs. Existing orders retain their stored attendance; menu
resynchronization without explicit attendance also preserves those values.
Explicit attendance edits still win. Changing scalar School defaults cannot
overwrite configured weekday attendance. Changing weekday configuration affects
subsequently created orders; it does not backfill existing orders.

`fn_save_daily_menus` also retains the reviewed menu-reset repair from #450:
unchanged Dish rows survive, missing Dishes are inserted before obsolete Dishes
are removed, and existing order locks remain in place. The combined migration
updates seven existing functions and creates no new function, role, grant or RLS
policy. It preserves the inactive legacy `save_daily_menus` function unchanged.

## Existing-data protection

Apply and rollback acquire short-lived SHARE locks and fingerprint every ordinary
table in `public` and `ops_v2` before changing anything. Postflight compares row
counts and complete existing row values, excluding only the two new configuration
columns on `schools`. Any mismatch aborts the entire transaction. Existing
function owners, ACLs, security modes, search paths and argument/return attributes
are checked unchanged. Source guards reject unknown function revisions.

The only permanent row writes are the 34 School configuration updates. Existing
School fields, attendance, menus, Need overrides, procurement and documents are
not backfilled. The eleven retained November 2–6 differences are left intact.
The existing School-sync webhook remains enabled; its hosted source reads only
`id,name,display_order`, whose values do not change in this migration.

Locks time out after five seconds and statements after sixty seconds. Do not
remove preservation/source guards to force deployment through contention or drift.

## Verification

```powershell
python -X utf8 integrations/ops-v1/hotfix-20261031-weekday-attendance/regression.py
node integrations/ops-v1/hotfix-20261031-menu-reset/concurrency.mjs integrations/ops-v1/hotfix-20261031-weekday-attendance/apply.sql
```

The thirteen isolated PostgreSQL tests cover 170 source rows through three
creation paths, explicit zero/manual edits, all five Retool query dates, next-week
recurrence, weekends, unconfigured Schools, invalid arrays, scalar synchronization,
drift rejection and exact rollback. They also run all nine existing menu-reset
scenarios and deliberately corrupt an override inside a migration to prove the
whole installation rolls back. The combined real two-session concurrency check
retains its previous lock ordering and unrelated override preservation.

Tests create and remove a uniquely named local database. No hosted business command
is run for testing. Fixtures stub Auth/rebalance and do not certify production
allocation math, hosted load or the external webhook's execution.

## Apply and rollback

Commit and publish this exact SQL, pass independent review and required CI, then
apply `apply.sql` through Supabase's migration tool against the approved project.
Do not separately apply the overlapping menu-reset migration afterwards.

The source baseline includes the already-deployed menu-reset migration
`20261031065646`. The first weekday attempt rejected that intervening source
change before any DDL/data write; all 55 business-table fingerprints remained
identical. The guard and rollback were then rebased on that deployed source.

After the DB migration, replace Retool's `get_school_attendance` query with the
supplied same-name SQL to show weekday defaults before an order exists. Preserve
the actual live query before editing. Backend autofill does not depend on this
display query. Local browser use must be enabled to perform the Retool UI edit.

For rollback, restore Retool's original read query first (the retained reference is
`get_school_attendance.rollback.sql`), then apply the guarded DB `rollback.sql`.
Rollback removes the two configuration columns and restores the pre-weekday seven
functions, retaining the already-deployed menu-reset repair. It never rewrites existing
orders or recovers previously deleted data. Defaults already stored on new orders
remain stored. Any later function revision requires a separately reviewed rollback.

Deployment evidence and the explicit Owner exception to Atlas's standing v1
NO-WRITE boundary are recorded in the accompanying implementation task.
