# OPS v1 — Weekday attendance defaults

**Status:** Owner-approved deployment; implementation and local verification complete;
independent review, exact-head CI and hosted execution/readback pending.

**Owner authorization:** On 31 October 2026, after reviewing the weekday hotfix and
the standing OPS v1 NO-WRITE boundary, the Owner authorized deployment conditional
on preserving all entered data: “Miễn là không ảnh hưởng các dữ liệu đã nhập thì có
thể triển khai”. This is a bounded exception for this OPS v1 hotfix, not a transfer
of write ownership to Atlas or authorization to repair historical operations.

**Target:** OPS v1 `qnthofvccilhnefdcxnz` only. Atlas Staging/Production, Warehouse,
supplier commitments and existing operational-data correction are outside scope.

**Bounded files:** The manual apply/rollback SQL, reference Retool read queries,
source fixtures, local regression and README under
`integrations/ops-v1/hotfix-20261031-weekday-attendance/`; a small source-file option
in the existing menu-reset concurrency runner; this task record.

## Implementation

Seed student/teacher defaults for Monday–Friday from five supplied workbooks,
34 Schools per day, using retained School IDs. Two optional five-value smallint
arrays preserve explicit zero and retain scalar fallback outside weekdays or
for unconfigured Schools. Two renamed BÌNH MỸ labels are resolved by their unchanged
IDs; no School name or existing scalar default is edited.

The existing insert trigger and two active creation RPCs resolve weekday values.
Menu saves preserve existing attendance when the incoming payload omits it.
Scalar-default synchronization cannot replace configured weekday attendance.

The seven-function migration composes the already-reviewed menu-reset fixes from
Draft #450 with the overlapping attendance change in `fn_save_daily_menus`.
It preserves insert-before-delete Dish synchronization and consistent parent-lock
ordering. The inactive legacy `save_daily_menus` route remains outside scope.
No signature, grant, role, RLS policy, module, calculation or dependency changes.

## Acceptance and preservation proof

- [x] All 170 source rows resolve correctly through direct insert and both RPCs.
- [x] Explicit zero/manual quantities survive menu replay; explicit new edits win.
- [x] Weekend/unconfigured fallback, recurrence and invalid configuration checks pass.
- [x] Nine menu-reset scenarios and combined real two-session concurrency pass.
- [x] A deliberate existing-override corruption aborts and rolls back installation.
- [x] Apply/rollback compare complete existing business-table rows and function security.
- [x] Retool reference queries match source defaults; query rollback is exercised.
- [ ] Independent composed-source review and exact-head Frontend CI pass.
- [ ] Version-controlled migration is applied to the exact approved v1 project.
- [ ] Hosted readback confirms defaults, deployed function revisions and preserved data.
- [ ] Live Retool display query is updated when browser access is available.

Existing November 2–6 orders are not modified. Eleven retained differences from the
supplied workbooks remain unresolved because manually entered versus default-derived
values cannot be inferred safely. No data repair is authorized by this task.

Both migration directions lock existing `public`/`ops_v2` tables briefly, compare
transaction-local before/after fingerprints, exclude only the two new configuration
columns, and abort on any other data change. Existing School fields and all other
entered rows must remain intact. The School webhook continues to read only the
unchanged School identity/display fields.

## Validation and rollback limits

Focused local verification is thirteen PostgreSQL tests plus the composed concurrency
runner. Auth/rebalance are fixture stubs. No hosted transaction journey is used as
a test. GitHub Actions owns routine frontend validation; it is not duplicated locally.

Restore Retool's original query before dropping the new columns. Guarded rollback
restores all seven pre-hotfix functions and removes configuration only; it does not
rewrite orders or recover deleted data. It restores the known pre-fix menu-reset
behavior. Record exact deployment and CI evidence below after execution.
