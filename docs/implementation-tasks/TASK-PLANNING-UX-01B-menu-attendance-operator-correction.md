# PLANNING-UX-01B — Menu and Attendance operator correction

## Status

Implemented and locally validated on branch
`feat/planning-ux-01b-menu-attendance-review` from exact baseline
`3376be46c9f061a91a662873faf67024fd50b233`.

## Outcome

The Planning Application now follows the operator sequence:

```text
Thực đơn: chỉnh sửa / đồng bộ → Xem thay đổi → Lưu
Sĩ số: mở với giá trị làm việc → tìm / sửa → Xem thay đổi → Lưu
```

Save is unavailable until the current draft has a successful authoritative
Preview. A material edit, workbook preparation, Google synchronization, or
bulk-paste preparation clears the prior Review. Save submits the exact
backend-canonical rows returned by the reviewed Preview.

## Attendance working rows

`default_attendance_preview` remains a non-writing authoritative read model.
The Application automatically composes the working table by loading the
Menu-covered default rows first and then overlaying persisted active Attendance
for matching School/service-date pairs. Persisted values, including explicit
zero, therefore win. Defaults fill only missing covered pairs.

When no Attendance has been persisted, defaults appear immediately without a
setup action. A clean authoritative refresh may adopt changed School defaults;
a dirty local operator edit remains protected by the existing discard guard and
is not silently replaced. Later School-default changes do not rewrite persisted
Attendance.

The normal `Tạo từ sĩ số mặc định` action is removed. Attendance adds fast
accent-insensitive fuzzy School search. Blank quantities remain invalid working
values rather than becoming zero.

## Review presentation

Menu Review shows School, service date, Dish Type, prior Dish, proposed Dish,
and whether the assignment is added, removed, or changed. Attendance Review
shows School, service date, and student/teacher quantities before and after.
Technical comparison counts and signatures remain available only in a closed
support disclosure.

## XLSX disposition

The provisional Attendance `Chọn workbook` affordance is removed from the
normal surface until `PLANNING-XLSX-01`. Existing generic parsing utilities are
not deleted or promoted into a final Product contract. Weekly Menu's accepted
Google Sheet and workbook preparation paths remain available, but neither path
counts as operator Review.

## Contract and environment boundary

This change is Application-only. It adds no migration, relation, column,
trigger, job, scheduler, API, Preview API, lifecycle state, capability, backend
orchestration, dependency, or generated type. Existing `RMVP-03A.v1` Preview
and `RMVP-03A.v2` consequential Save contracts remain authoritative.

Atlas Staging, live OPS, Retool, Edge Functions, hosted data, DISH-RICE-01,
Procurement, and Warehouse were not mutated or started.

## Verification

- Focused Planning workbench: 18 tests passed.
- Focused Planning model: 9 tests passed.
- Broader Planning-input and Atlas shell regression: 17 files / 118 tests
  passed.
- Typecheck passed.
- Repository formatting check passed.
- Production build passed with the existing non-blocking large-chunk advisory.
- `git diff --check` passed.
- Hosted CI: `BLOCKED BEFORE RUNNER — GitHub billing/spending limit`.
