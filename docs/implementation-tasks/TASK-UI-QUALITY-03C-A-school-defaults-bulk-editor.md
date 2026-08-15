# UI-QUALITY-03C-A — School Default-Portion Bulk Editor

**Status:** Implemented on bounded draft branch; independent Product/Architecture review pending

**Starting `main`:** `60316f59638e1c7c625700166e7c78d7b11e242a`

**Branch:** `codex/ui-quality-03c-a-school-defaults-bulk-editor`

**Contracts:** additive `RMVP-01.v2`; `RMVP-01.v1` unchanged

## Bounded capability

Restore the established School default-count job as one compact bulk inline editor. The operator searches or filters Schools, directly edits Student and/or Teacher defaults on one or more rows, reviews the exact pending Before/After changes, and performs one explicit Save from Review. The Application owns only local draft and Review-snapshot coordination; PostgreSQL owns authorization, complete validation, deterministic locking, optimistic concurrency, atomicity, idempotency, version increments, and audit/domain evidence.

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
- blank, negative, fractional, or out-of-range values are visibly invalid and block `Xem thay đổi`;
- `Hủy thay đổi` restores all current authoritative readback values;
- the Edit state has no direct `Lưu`; `Xem thay đổi` opens a bounded local Review of all dirty Schools, including rows hidden by current filters;
- Review shows each School's authoritative current Student/Teacher values beside the proposed values and takes no backend action;
- one stable, deterministically ordered local snapshot holds the exact School IDs, expected versions, and Before/After values; returning, discarding, refreshing, materially editing, stale rejection, or unknown outcome invalidates it;
- one `Lưu` from Review sends exactly the reviewed dirty Schools and row-specific `expected_version` values in one API invocation;
- successful Save performs authoritative refresh and clears reconciled dirty state;
- known stale rejection states that no School changed, closes and invalidates Review, preserves drafts, and offers reload/review;
- unknown transport outcome performs no automatic retry, invalidates Review, locks inputs and mutation, and requires authoritative refresh and a fresh Review before another Save.

## Database and security delta

- one forward-only migration;
- one public `atlas_api` function;
- zero tables, private relations, views, triggers, capabilities, roles, runtime roles, scope kinds, policies, policy families, batch aggregates, or read APIs;
- existing `atlas_master_data_command_runtime`, `master_data.schools.write`, receipt functions, School update grants/RLS, and RMVP-01 change recorder reused;
- `authenticated` execute only; `anon`, `service_role`, and `PUBLIC` denied;
- empty `search_path` security-definer pattern retained.

## Verification and rollback

Focused frontend coverage proves inline editing, absence of `Xem và sửa` and direct Edit-state Save, search/filter behavior, filter-safe multi-row Review, exact Before/After facts, stable reviewed payload and row-specific versions, validation, return/discard behavior, one bulk API call, authoritative refresh, known stale invalidation, unknown-outcome mutation locking, and responsive modal bounds.

Focused pgTAP proves function security, capability reuse, two-School atomic success, exact version increments, unchanged-School preservation, one-field preservation, payload rejection, missing/stale all-or-nothing behavior, no failed-command change evidence, idempotent replay, per-School events/audits, and actual `RMVP-01.v1` callability. RMVP-01, RMVP-03A Attendance compatibility, and the current platform/security catalog remain regression gates.

Disposable rollback is `supabase db reset --local`. Any deployed rollback would be a forward migration that removes only the additive v2 entry point after callers return to v1; it must not rewrite School facts, receipts, events, or audit evidence.

Hosted GitHub CI remains blocked before runner execution by the account billing/spending limit. No workflow is changed.

No Atlas Staging deployment, live OPS mutation, Retool mutation, production data change, or stash operation is authorized or performed.

## Workflow disposition

Workflow preserved:

- School defaults are maintained as one compact multi-School editing job;
- only Student/Teacher defaults are authored;
- one atomic authoritative backend Save commits the changes;
- search and School Type filtering remain;
- no per-row Save is introduced.

Workflow improved:

- Atlas replaces direct SQL/Retool JavaScript authority with one atomic authorized backend command;
- concurrency, idempotency, and audit are authoritative;
- search/filter and human School context remain;
- the operator reviews the exact human-readable pending changes before commitment, and stale/unknown outcomes invalidate Review safely.

Workflow intentionally changed:

- Preview / Review is now required between editing and Save, explicitly approved by the Product Owner on 15/08/2026.

Future requirement recorded only: Attendance and Confirmed Need must later support XLSX export/import assistance that applies reviewed imports to local drafts before `Xem thay đổi` and `Lưu`; Confirmed Need `Chuyển sang lên đơn` remains separate. XLSX templates, workbook schemas, parsers, generators, storage, RPCs, tests, and actual implementation remain deferred until PLANNING-UX-01. Atlas-wide typography also remains deferred.

Verified OPS v1 Attendance requirement recorded for that future Planning review: Menu assignment seeds default-derived working Attendance only for covered School/service dates; seeded values are not confirmation. School-default changes may refresh only still-default-derived future quantities, while operator-entered and confirmed facts are protected. Atlas's manual `Tạo từ sĩ số mặc định` interaction is identified as Product debt; normal confirmation occurs close to service, commonly about 2–3 days beforehand, but no hard deadline is defined. Need Generation semantics remain unchanged and continue to require confirmed/current Attendance. UI-QUALITY-03C-A performs no Attendance, Planning, XLSX, trigger, scheduler, migration, or API implementation.

Global typography remains deferred to PLANNING-UX-01. Ingredient/Supplier consolidation is explicitly outside this slice.
