# UI-QUALITY-03C-A — School Default-Portion Bulk Editor

**Status:** Implemented on bounded draft branch; independent Product/Architecture review pending

**Starting `main`:** `60316f59638e1c7c625700166e7c78d7b11e242a`

**Branch:** `codex/ui-quality-03c-a-school-defaults-bulk-editor`

**Contracts:** additive `RMVP-01.v2`; `RMVP-01.v1` unchanged

## Bounded capability

Restore the established School default-count job as one compact bulk inline editor. The operator searches or filters Schools, directly edits Student and/or Teacher defaults on one or more rows, and performs one explicit Save. The Application owns only local draft coordination; PostgreSQL owns authorization, complete validation, deterministic locking, optimistic concurrency, atomicity, idempotency, version increments, and audit/domain evidence.

Only these facts are authored:

- `default_student_portions`;
- `default_teacher_portions`.

## Additive command

`atlas_api.update_school_portion_defaults_bulk(request jsonb)` accepts `RMVP-01.v2` with no top-level aggregate version:

```json
{
  "contract_version": "RMVP-01.v2",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "string",
  "requested_by_auth_subject": "uuid",
  "requested_at": "timestamp",
  "reason_code": "SCHOOL_PORTION_DEFAULTS_BULK_UPDATE",
  "reason_note": "string or null",
  "payload": {
    "changes": [
      {
        "school_id": "uuid",
        "expected_version": 3,
        "default_student_portions": 520,
        "default_teacher_portions": 32
      }
    ]
  }
}
```

The command rejects empty or malformed lists, duplicate or missing Schools, missing/stale row versions, non-integer counts, negative counts, and submitted no-op rows. It authorizes with existing `master_data.schools.write`, registers one receipt through existing idempotency infrastructure, locks all requested Schools in `school_id` order, validates every current version before the first School update, and then updates all rows or none. Each changed School increments exactly once and emits the existing `SchoolPortionDefaultsUpdated` domain and audit meaning under the shared command/correlation context. The response includes authoritative `updated_schools` facts.

The existing `atlas_api.update_school_portion_defaults(request jsonb)` remains physically callable and unchanged as `RMVP-01.v1`.

## Operator behavior

- useful School search and School Type filtering remain;
- the normal table prioritizes School, Type, compact Delivery Location context, Student default, and Teacher default;
- stable School-ID keyed drafts survive when a dirty row is hidden by search/filter;
- blank, negative, fractional, or out-of-range values are visibly invalid and block Save;
- `Hủy thay đổi` restores all current authoritative readback values;
- one `Lưu` sends only dirty Schools and each row's authoritative `expected_version` in one API invocation;
- successful Save performs authoritative refresh and clears reconciled dirty state;
- known stale rejection states that no School changed, preserves drafts, and offers reload/review;
- unknown transport outcome performs no automatic retry, locks inputs and Save, and requires authoritative refresh before another mutation attempt.

## Database and security delta

- one forward-only migration;
- one public `atlas_api` function;
- zero tables, private relations, views, triggers, capabilities, roles, runtime roles, scope kinds, policies, policy families, batch aggregates, or read APIs;
- existing `atlas_master_data_command_runtime`, `master_data.schools.write`, receipt functions, School update grants/RLS, and RMVP-01 change recorder reused;
- `authenticated` execute only; `anon`, `service_role`, and `PUBLIC` denied;
- empty `search_path` security-definer pattern retained.

## Verification and rollback

Focused frontend coverage proves inline editing, absence of `Xem và sửa`, search/filter behavior, filter-safe multi-row dirty state, validation, one bulk API call, dirty-only payloads, row-specific versions, discard, authoritative refresh, known stale behavior, and unknown-outcome mutation locking.

Focused pgTAP proves function security, capability reuse, two-School atomic success, exact version increments, unchanged-School preservation, one-field preservation, payload rejection, missing/stale all-or-nothing behavior, no failed-command change evidence, idempotent replay, per-School events/audits, and actual `RMVP-01.v1` callability. RMVP-01, RMVP-03A Attendance compatibility, and the current platform/security catalog remain regression gates.

Disposable rollback is `supabase db reset --local`. Any deployed rollback would be a forward migration that removes only the additive v2 entry point after callers return to v1; it must not rewrite School facts, receipts, events, or audit evidence.

Hosted GitHub CI remains blocked before runner execution by the account billing/spending limit. No workflow is changed.

No Atlas Staging deployment, live OPS mutation, Retool mutation, production data change, or stash operation is authorized or performed.

## Workflow disposition

Workflow preserved:

- School defaults are maintained as one compact multi-School editing job;
- only Student/Teacher defaults are authored;
- one explicit Save commits the changes.

Workflow improved:

- Atlas replaces direct SQL/Retool JavaScript authority with one atomic authorized backend command;
- concurrency, idempotency, and audit are authoritative;
- search/filter and human School context remain.

Workflow intentionally changed:

NONE.

Global typography remains deferred to PLANNING-UX-01. Ingredient/Supplier consolidation is explicitly outside this slice.
