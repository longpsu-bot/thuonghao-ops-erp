# RMVP-03A Planning Inputs API Contract

## Boundary

Contract version: `RMVP-03A.v1`

The API exposes one shaped read, two non-writing previews, and nine business commands through `atlas_api`. Clients have no direct table access and must treat authoritative readback as the result of every successful command.

## Read envelope

```json
{
  "contract_version": "RMVP-03A.v1",
  "requested_by_auth_subject": "uuid",
  "correlation_id": "uuid",
  "payload": {}
}
```

The authenticated JWT subject must equal `requested_by_auth_subject`.

The normal `get_planning_inputs_workbench` payload may contain `week_start`. Its shaped `google_sheet_sources` array exposes only source ID, code, name, status, and order. The server-side connector may additionally send `google_connector_source_id`; after the same subject and capability checks, the response includes the active source's spreadsheet ID, sheet pattern, and range template in `google_connector_source`. Unknown or inactive values fail as `GOOGLE_SOURCE_UNAVAILABLE`. React does not request or receive this technical object directly.

## Command envelope

```json
{
  "contract_version": "RMVP-03A.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "bounded-stable-key",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601 timestamp",
  "reason_code": "BOUNDED_REASON",
  "reason_note": "operator explanation",
  "payload": {}
}
```

Commands require exact auth-subject binding, a current actor, the named capability, global scope, a fresh request timestamp, idempotency, and optimistic concurrency. Reopen commands additionally require a non-empty `reason_note`.

## Functions

<!-- prettier-ignore -->
| Function | Capability | Behavior |
|---|---|---|
| `get_planning_inputs_workbench(request jsonb)` | `planning.inputs.read` | Returns the explicit week, active Dish Type catalog, typed Dishes, safe active Google source list, source aggregates, active/invalid lines, issues, command-audit history, approval history, default Attendance preview, and read-only readiness comparison. |
| `preview_weekly_menu_import(request jsonb)` | `planning.inputs.read` | Canonicalizes Menu rows, calculates SHA-256, and returns blockers/warnings without writing. |
| `preview_attendance_import(request jsonb)` | `planning.inputs.read` | Canonicalizes Attendance rows, preserves explicit zero, calculates SHA-256, and returns blockers/warnings without writing. |
| `save_weekly_menu_draft(request jsonb)` | `planning.weekly_menu.write` | Atomically creates or fully replaces one explicit-week working Menu with stable assignment identity. |
| `validate_weekly_menu(request jsonb)` | `planning.weekly_menu.write` | Rechecks current references and moves `DRAFT` to `VALIDATED`. |
| `approve_weekly_menu(request jsonb)` | `planning.inputs.approve` | Moves `VALIDATED` to `APPROVED` with an immutable exact-line snapshot. |
| `reopen_weekly_menu(request jsonb)` | `planning.inputs.approve` | Reasoned reopen from approved/used state, preserving history and advancing version. |
| `create_attendance_draft_from_defaults(request jsonb)` | `planning.attendance.write` | Creates menu-aware School/date defaults after checksum preview. |
| `save_attendance_draft(request jsonb)` | `planning.attendance.write` | Atomically creates or fully replaces explicit Attendance rows with stable identity. |
| `validate_attendance(request jsonb)` | `planning.attendance.write` | Rechecks current references and moves `DRAFT` to `VALIDATED`. |
| `approve_attendance(request jsonb)` | `planning.inputs.approve` | Moves `VALIDATED` to `APPROVED` with an immutable exact-line snapshot. |
| `reopen_attendance(request jsonb)` | `planning.inputs.approve` | Reasoned reopen from approved/used state, preserving history and advancing version. |

## Preview payloads

Weekly Menu row:

```json
{
  "school_id": "uuid",
  "service_date": "YYYY-MM-DD",
  "menu_slot_code": "soup",
  "dish_id": "uuid",
  "source_row_reference": "sheet:2"
}
```

Attendance row:

```json
{
  "school_id": "uuid",
  "service_date": "YYYY-MM-DD",
  "student_portions": 0,
  "teacher_portions": 0,
  "source_row_reference": "sheet:2"
}
```

Preview payloads contain `week_start`, `rows`, and optional `source_signature`. A supplied mismatching signature becomes `CHECKSUM_MISMATCH`.

Successful preview returns:

```json
{
  "success": true,
  "contract_version": "RMVP-03A.v1",
  "correlation_id": "uuid",
  "preview": {
    "week_start": "YYYY-MM-DD",
    "week_end": "YYYY-MM-DD",
    "canonical_rows": [],
    "source_signature": "sha256-hex",
    "source_row_count": 0,
    "row_count": 0,
    "normalized_assignment_count": 0,
    "comparison": {
      "new_assignments": 0,
      "changed_assignments": 0,
      "unchanged_assignments": 0,
      "omitted_prior_assignments": 0,
      "changed_school_days": []
    },
    "issues": { "blockers": [], "warnings": [] },
    "can_save": true
  },
  "safe_operator_message": "..."
}
```

## Save payloads

Menu save requires:

- `week_start`
- `source_type`
- `source_name`
- `source_signature` from preview
- `expected_source_signature` for an existing aggregate, otherwise `null`
- canonical `rows`

Attendance save uses the same fields. Default creation requires `week_start`, preview `source_signature`, and the expected persisted signature.

Canonical signatures exclude source-row labels while persisted canonical rows retain them. An exact canonical draft replacement with identical source metadata returns `idempotency_status: "NO_CHANGE"` and writes no event/audit record. An exact repeated command/idempotency key returns the original `COMPLETED` response.

## Command success

```json
{
  "success": true,
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_status": "COMPLETED",
  "affected_aggregate_ids": {},
  "resulting_version": 1,
  "authoritative_readback": {},
  "safe_operator_message": "..."
}
```

The readback has the same workbench shape as `get_planning_inputs_workbench` for the explicit week.

## Safe failures

Expected failures include:

- `AUTH_SUBJECT_MISMATCH`
- `AUTHENTICATION_REQUIRED`
- `CAPABILITY_DENIED`
- `VALIDATION_FAILED`
- `CHECKSUM_MISMATCH`
- `STALE_SOURCE_SIGNATURE`
- `STALE_VERSION`
- `INVARIANT_VIOLATION`
- `NOT_FOUND`
- `RETRYABLE_CONCURRENCY_FAILURE`
- `GOOGLE_SOURCE_UNAVAILABLE` for the connector-only source lookup

Transport uncertainty is never treated as success. A retryable failure permits retrying the exact request. A stale version or signature requires authoritative refresh and a new reviewed request.

## Security contract

- Function execution: `authenticated` only
- Schema usage: `atlas_api` only for the browser
- Function owners: `atlas_read_runtime` for reads/previews and `atlas_planning_command_runtime` for writes
- `SECURITY DEFINER`, empty `search_path`, exact grants
- Forced RLS on private relations
- No `anon` or `service_role` execution
- No React service-role credential or direct private-schema query

## Google Sheet Edge adapter

Function: `atlas-weekly-menu-google-sync`

JWT verification is enabled. The function accepts only:

```json
{
  "weekly_menu_google_source_id": "uuid",
  "week_start": "YYYY-MM-DD",
  "correlation_id": "uuid"
}
```

It validates a Monday start, authenticates the bearer session, forwards that bearer token to the existing Planning read API, resolves the active source there, derives `Tuần DD-MM-YYYY` and the configured A1 range, and performs a read-only Google Sheets values request.

Successful response:

```json
{
  "success": true,
  "source": {
    "source_id": "uuid",
    "source_code": "text",
    "source_name": "text",
    "sheet_name": "Tuần DD-MM-YYYY",
    "range": "'Tuần DD-MM-YYYY'!A3:Z500"
  },
  "fetched_at": "ISO-8601 timestamp",
  "rows": [],
  "warnings": [],
  "correlation_id": "uuid"
}
```

Rows are untrusted source matrix rows, not Weekly Menu facts. The function has no database write call. It rejects browser-supplied spreadsheet/range authority and classifies session, capability, source, credential, Google authentication, inaccessible spreadsheet, missing sheet, invalid range, empty sheet, response-size, malformed-response, and retryable upstream failures with bounded safe messages. Google credentials exist only in the server-side `GOOGLE_SERVICE_ACCOUNT_JSON` secret.

## Non-goals

The contract does not implement RMVP-03B Planning Input Readiness, start RMVP-04 Need Generation, create Confirmed Need, release Purchase Handoff, perform Purchase Planning, receive Warehouse stock, connect hosted Supabase, or mutate OPS v1/v2/Retool.

## Additive consequential Save contract (`RMVP-03A.v2`)

PLANNING-CONTRACT-01 adds two normal completion commands without redefining any `RMVP-03A.v1` entry point:

| Function                                    | Capability                   | Consequential behavior                                                                                                                                                                                                                       |
| ------------------------------------------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `atlas_api.save_weekly_menu(request jsonb)` | `planning.weekly_menu.write` | Canonicalizes and completely replaces the working Menu, validates it, creates its immutable every-and-only approval snapshot, establishes that snapshot as current, and returns Planning preflight/currentness in one transaction.           |
| `atlas_api.save_attendance(request jsonb)`  | `planning.attendance.write`  | Canonicalizes and completely replaces explicit Attendance rows, including zero portions, validates them, creates the immutable completed snapshot, establishes it as current, and returns Planning preflight/currentness in one transaction. |

Both use the existing Atlas command envelope with `contract_version: "RMVP-03A.v2"`, one top-level receipt, exact replay, changed-reuse conflict, expected aggregate version, and expected/source signature checks. Their payloads retain the corresponding v1 Save fields. A material Save returns `COMPLETED`; identical already-completed content returns `NO_CHANGE`. Historical snapshots and stable line identities are retained.

The backend may compose the established v1 implementation internally, but a browser invokes only the one consequential Save. It must not chain Save Draft, Validate, and Approve. Existing v1 functions and grants remain callable during the UI coexistence window. See [PLANNING-CONTRACT-01](../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md).
