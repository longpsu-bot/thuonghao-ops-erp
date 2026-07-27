# RMVP-03A — Connected Weekly Menu and Attendance

## Outcome

RMVP-03A connects one Vietnamese `Nguồn kế hoạch` workbench to the existing Weekly Menu and Attendance persistence foundations. Operators work against an explicit Monday-start week, review canonical import evidence, save a draft, validate, approve, reopen with a reason, and inspect preserved command-audit and approval history. The workbench is a source-readiness surface; it does not calculate ingredient demand or write any downstream Planning document.

## Authority and bounded scope

This change implements the approved Weekly Menu and Attendance lifecycles without changing their aggregate boundaries, states, calculation precedence, or downstream contracts.

- One migration adds APIs, capabilities, grants, and RLS policies.
- No table, trigger, database role, module, or operating stage is added.
- Existing `atlas_planning.weekly_menus`, stable assignment lines, Attendance batches/lines, and immutable approval snapshot relations remain authoritative.
- Existing `atlas_planning_command_runtime` owns writes and `atlas_read_runtime` owns shaped reads.
- React calls only the reviewed `atlas_api` functions through the authenticated browser adapter.
- OPS v1/v2, Retool, hosted Supabase, production data, Need Generation, Confirmed Need, Purchase Planning, and Warehouse are not mutated.

## Operator workflow

The active Atlas navigation item is `Nguồn kế hoạch`. The page has only two operational tabs:

1. `Thực đơn tuần`
2. `Sĩ số`

The selected week is always visible as a Monday-start period. Changing weeks with unsaved edits requires confirmation. Browser close/refresh also warns about unsaved work.

Weekly Menu uses a compact School/date grid with the five existing slot codes:

- `soup` — Món canh
- `savory` — Món mặn
- `stir_fry` — Món xào
- `dessert` — Tráng miệng
- `afternoon_snack` — Buổi xế

Attendance uses one compact School/date row with explicit student and teacher quantities. `0` is a legitimate explicit quantity. Blank or invalid input is never inferred as zero.

Both tabs expose:

- authoritative status, version, source, checksum, issues, command-audit history, and approval history;
- non-writing workbook or bulk-paste preview;
- explicit save, validate, approve, and reasoned reopen actions;
- safe stale-version, stale-checksum, permission, retryable-concurrency, session-loss, and transport messages;
- read-only comparison readiness after both inputs have approved snapshots.

Later navigation entries remain disabled. RMVP-03A does not create a fourth daily operating stage: it connects source preparation within Requirement Planning.

## Import and canonical evidence

The browser parser is deliberately narrow.

Weekly Menu accepts `.xlsx` columns for `Tên trường`, `Ngày`, and the five Vietnamese menu-slot labels. Harmless cover sheets and leading rows are allowed, including the current shape with headers on row 3, and the selected sheet name is preserved in source evidence. Attendance accepts `Tên trường`, `Ngày`, `Số suất học sinh`, and `Số suất giáo viên`; the explicitly tested legacy aliases `Sĩ số học sinh` and `Sĩ số giáo viên` are also accepted. The same Attendance rows may be pasted as tab-separated text.

The parser:

- resolves only existing School and Dish references;
- preserves unresolved references as blockers instead of dropping them;
- supports Excel date cells and explicit `dd/mm/yyyy`/ISO dates;
- preserves source-row references for operator review;
- removes harmless blank rows;
- normalizes text to Unicode NFC;
- sends all rows to a backend preview before any save.

The backend preview returns source and normalized row counts, canonical rows with source references, a SHA-256 signature, new/changed/unchanged/omitted comparison counts, changed School/day summaries, blockers, and warnings. The checksum is over business content and is independent of input order, blank rows, and source-row labels. Save requires the exact preview signature plus the expected persisted signature when replacing an existing draft. The browser checksum is review assistance; PostgreSQL recomputes and decides the authoritative signature.

Exact canonical replacement is a successful `NO_CHANGE` with no event or audit write. Exact command replay returns the original durable receipt and aggregate identity.

## Stable lines and lifecycle

Draft replacement is full and atomic.

- Existing School/date/slot Weekly Menu assignment identity is reused.
- Existing School/date Attendance line identity is reused.
- Omitted working rows are invalidated rather than deleted.
- Save is permitted only in `DRAFT` or `REOPENED`.
- Validation rechecks current references and blockers.
- Approval is permitted only from `VALIDATED`.
- Approval copies the exact active line set into a new immutable snapshot.
- Reopen requires a non-empty reason, preserves prior approval evidence, and advances the working version by exactly one.
- A resaved reopened aggregate returns to `DRAFT`; later validation and approval create a new snapshot for the later version.

Lifecycle transitions preserve the inherited import-evidence fields. In particular, `updated_at` remains an import-refresh timestamp and is not changed by validation, approval, or reopen.

## Attendance defaults and readiness

`create_attendance_draft_from_defaults` is menu-aware. When a Weekly Menu exists, it creates default rows only for the distinct active School/date pairs in that selected menu week. It does not use today implicitly and does not create rows for unrelated Schools or dates.

The shaped read compares the two current source aggregates without writing readiness or downstream state. `ready` is true only when both the Weekly Menu and Attendance are approved and exposes the exact latest approval snapshot identifiers. Coverage differences remain visible warnings.

## Retool evidence mapping

The reviewed OPS v1 Retool export is evidence, not authority. RMVP-03A retains four useful operator safeguards found there:

- import is previewed before a write;
- the week/date scope is explicit;
- unknown references are visible instead of silently accepted;
- quantities are not written directly from browser parsing.

Atlas replaces Retool's client-driven writes with one reviewed backend command per business action, optimistic concurrency, idempotency receipts, domain events, audit events, RLS, and authoritative readback.

## Security

Exactly four capabilities are added:

- `planning.inputs.read`
- `planning.weekly_menu.write`
- `planning.attendance.write`
- `planning.inputs.approve`

All 12 API functions are `SECURITY DEFINER` with an empty `search_path`. `authenticated` has only schema usage and exact function execution. `anon` and `service_role` execute none of these APIs. Private schemas remain unavailable to the browser.

The write runtime has only the relation privileges and RLS policies required for the two aggregates, their snapshots, authorization receipts, and Planning audit/event evidence. It receives narrow read-only access to existing Dish, Recipe, Ingredient, Unit, Recipe-line, and Recipe-adjustment evidence solely so validation can call the existing RMVP-02B effective-BOM resolver and surface warnings; it receives no cross-domain write privilege and no raw audit-detail read. Command readback reaches audit history only through the date-bounded shaped workbench builder owned by the existing read runtime. Deferred inherited snapshot guards are forced and restored inside each writing command so they execute under the narrow runtime before control returns to the browser.

RMVP-03B Planning Input Readiness and RMVP-04 Need Generation remain explicit future boundaries. This task neither persists readiness nor starts a generation run.

## Migration and rollback

Migration:

`supabase/migrations/20260727150000_rmvp_03a_connected_weekly_menu_attendance.sql`

Rollback is a controlled database rollback or rebuild to the preceding migration. No production rollback is performed by this task. If a forward compensating migration is required later, it must revoke the 12 exact API grants, remove the RMVP-03A RLS policies and functions, remove the four capability assignments/capabilities, and revoke only the added runtime privileges. Existing Weekly Menu, Attendance, and approval history data must not be deleted.

## Validation evidence

- Fresh local migration reset
- 44 focused RMVP-03A pgTAP assertions
- 22 exact current-platform catalog assertions
- Browser-key acceptance covering preview, save, durable replay, no-change, validation, approval, reopen/reapproval, stable lines, explicit zero, reauthentication, and final readiness
- Focused API/model/workbook/connected-review UI tests
- Typecheck and review/production builds
