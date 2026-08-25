# TASK-PLANNING-UX-02 — Planning operator workflow consolidation

**Status:** Implemented for review

**Scope:** Connected Planning presentation only

## Objective

Present the approved Planning domain sequence as four operator tasks without exposing Need Generation as a peer navigation boundary. Keep Supabase/PostgreSQL authority, atomic execution, immutable lineage, idempotency, correction history, RBAC, receipts, audit, and Confirmed Need release safety unchanged.

## Implemented projection

- Sidebar: `Lập nhu cầu`.
- Page: `Lập nhu cầu theo tuần`.
- Tabs: `Thực đơn`, `Sĩ số`, `Nhu cầu bổ sung`, `Xác nhận nhu cầu`.
- `Xác nhận nhu cầu` owns the daily backend preflight projection and exposes only contextual `Tạo nhu cầu`, `Cập nhật nhu cầu`, or `Mở xác nhận` actions.
- Raw Need Generation and Confirmed Need lifecycle values are translated to Vietnamese business language. Exact run/version history remains under support/history disclosure.
- The normal quantity table remains Confirmed Need. Theoretical Recipe and Pantry contributions appear only as support detail and aggregate under the existing complete operational identity.
- Attendance default warnings use School and portion values; technical source references are support-only.
- Menu workbook and Google Sheet ingestion move under `Nhập thực đơn`; Google configuration warnings appear only after selecting Google Sheet.

## Duplicate investigation

The accepted contracts and focused regression evidence distinguish three layers:

1. Need Generation persists atomic Recipe/Pantry theoretical contributions.
2. `get_need_generation_workbench` groups them by service date, customer, School, delivery location, Ingredient, and Unit.
3. Confirmed Need owns the normal operational row for the same complete business identity and retains plural contribution membership.

The reported duplicate was a frontend presentation problem: the theoretical workbench was a peer screen beside the operational Confirmed Need projection. No duplicate-root persistence or backend grouping defect was found. No migration or write-command change is included.

## Safety and rollback

`execute_need_generation`, all existing reads and v1 compatibility APIs, `save_confirmed_needs`, and `release_confirmed_needs` are unchanged. There is no schema, RLS, role, capability, hosted Staging, Production, Retool, Procurement, Purchase Handoff, or CMD-03 change. Rollback is a normal Git revert of the React, tests, styles, and documentation changes.
