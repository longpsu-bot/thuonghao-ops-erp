# RMVP-03A Planning Inputs API Contract

## Resilient local Menu candidate — 06/10/2026

ATLAS-PRODUCT-CORRECTIONS-01 retains parsed Menu rows locally when individual
cells cannot resolve. Valid neighboring cells remain inspectable; rejected cells
remain explicit unresolved rows, never blank assignments, deletions or omitted
rows. This local candidate is not persisted or approved Menu authority.

Source evidence retains exact row number/reference, slot, resolved School/date
where available, and original Dish/School/date source text independently of the
normalized lookup values. Parser diagnostics use the existing `UNKNOWN_DISH`,
`AMBIGUOUS_DISH`, `UNKNOWN_SCHOOL` and `INVALID_SERVICE_DATE` vocabulary. Invalid
calendar dates remain unresolved. Structural/header ambiguity still rejects the
new matrix with no candidate rows; an earlier unresolved candidate and its dirty
state survive failed, malformed or structurally invalid resynchronization.

Local blockers prevent Preview, consequential Save and correction preparation,
including direct controller calls. Once the source is corrected, the same Google
sync action requests authoritative Preview; backend blockers also retain the
local candidate and prevent Save. Only a fully valid canonical week proceeds to
one atomic `save_weekly_menu`, with the existing canonical signature, expected
signature/version, idempotency, authoritative readback, transport recovery and
governed correction boundaries. No partial persistence, RPC envelope, backend
command, schema, lifecycle or security change is introduced.

## Menu slot / Dish identity correction — 01/10/2026

MENU-SLOT-DISH-DECOUPLING-01 explicitly replaces the earlier typed-only Dish
resolution and Weekly Menu eligibility rule. Canonical row and RPC envelopes
remain unchanged: School + service date + `menu_slot_code` + `dish_id`.
The Sheet column establishes the contextual slot; the cell establishes canonical
Dish identity. A valid assignment requires an active School, a date within the
week, an active supported slot, an active Dish, and unique School/date/slot.
Neither a matching nor a non-null legacy `dishes.dish_type_id` is required.
The physical `dish_types` catalog and Admin/Recipe classification consumers remain.

The shared parser normalizes NFC, trims and lowercases using the existing safe
Vietnamese normalization. It resolves active Dishes by exact code first, then
by globally unique exact name. Only multiple same-name active records may use
exactly one legacy slot match as transitional compatibility; zero or multiple
slot matches produce `AMBIGUOUS_DISH`. No matches produce `UNKNOWN_DISH`.
No array-order selection, Dish creation, master merge or non-blocking compatibility
warning is introduced. Unique-name resolution never consults legacy classification.

Parser results retain the canonical rows and add source-cell evidence plus
`diagnostics` (code, source row number/reference, slot code/name and raw
source value) and `compatibilityResolutions`. Unresolved Dish diagnostics stop
connected Google sync before Preview/Save. Backend Preview blockers stop Save.
The shared authoritative `atlas_core.rmvp_03a_menu_issues(date,jsonb)` removes only
`UNMAPPED_DISH_TYPE` and `DISH_TYPE_MISMATCH`; slot, Dish, School/date, uniqueness,
Recipe-readiness and effective-BOM checks retain their existing severity/semantics.
Recipe authority still uses actual Dish + School Type, independently of slot.

The Chakra Menu strip presents grouped Vietnamese issue-code summaries and
collapsed, scroll-bounded source details. Raw backend English issue messages are
never the operator fallback. The table and Google sync retry remain accessible;
#340 one-action fetch → parse → Preview → consequential Save → readback and
replacement/removal notifications remain intact. See the
[task and duplicate audit](../implementation-tasks/TASK-MENU-SLOT-DISH-DECOUPLING.md).

## Import integrity correction — AUD-001/002 (17/09/2026)

School resolution uses one normalized code match first and a name match only when unique. Multiple code/name matches or blank identities remain unresolved for the existing Preview blockers, never resolved by reference-array order. An explicit `Mã trường` / `school_code` column is code-only; the historical mixed-value `Tên trường` column and unlabeled Attendance paste retain unique-code-first fallback to unique names. This is shared by Google Menu matrices, Menu workbook parsing, Attendance workbook and Attendance paste; no new Menu workbook UI is added.

Header parsing retains all source positions. Multiple recognized columns for a single School/date/Attendance field, duplicate normalized Dish Type headings, and alias collisions are blocking structural errors with zero candidate rows. Empty and presentation-only headings do not become business fields. Backend Preview/Save/checksum contracts, stable IDs, Attendance zero/blank rules, and the then-current typed Dish resolution were unchanged by that amendment. The Menu slot / Dish identity correction above now supersedes typed-only resolution.

## Approved transport amendment — 16/09/2026

The owner approved the existing Apps Script Web App as the Weekly Menu transport in place of Google service-account OAuth. `GOOGLE_SERVICE_ACCOUNT_JSON` is no longer used by the current reader. The server uses `GOOGLE_APPS_SCRIPT_WEBAPP_URL` and `GOOGLE_APPS_SCRIPT_SECRET`, supplied through the protected Staging workflow. The existing browser request/response, user authentication, Planning capability enforcement, configured source authority, parser, backend Preview and explicit Save behavior remain unchanged.

The Web App reads only its server-configured spreadsheet and `Tuần DD-MM-YYYY!A3:I500`. Dates use the spreadsheet timezone; source/week/request evidence is checked and the ContentService redirect is followed without forwarding credentials. Existing v1 school/dish webhooks are preserved, with the new read event routed before the legacy write fallback. No schema, business fact, lifecycle or downstream command is added. The owner also clarified that Google Sheet is the only menu-authoring workflow; this task adds no Weekly Menu XLSX import/export UI.

The detailed deployment/security/rollback contract is `integrations/google-apps-script/weekly-menu/README.md`; implementation evidence is in `docs/implementation-tasks/TASK-WEEKLY-MENU-WEBAPP-01.md`. Older service-account notes below describe the original implementation and are superseded only for this transport.

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

The public v2 `requested_at` records client intent and permits no more than 60
seconds of positive clock skew. Once accepted, the internal Save, Validate,
Approve, and correction commands use PostgreSQL transaction time. The v1
command timestamp contract is unchanged.

The backend may compose the established v1 implementation internally, but a browser invokes only the one consequential Save. It must not chain Save Draft, Validate, and Approve. Existing v1 functions and grants remain callable during the UI coexistence window. See [PLANNING-CONTRACT-01](../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md).

For the current Weekly Menu operator path, `Đồng bộ Google Sheet` composes the
read-only Edge fetch with `parseMenuMatrix`, automatically calls the v1 canonical
Preview, requires `preview.can_save`, and submits the complete canonical rows
and signatures through this v2 consequential Save. It adopts the authoritative
readback after a successful command. Preview remains backend validation, not a
separate operator approval stage; the UI exposes no Menu Review/Save action or
Atlas Menu authoring. A consequential Save's downstream blocker is handled by
the existing correction-impact read and only its authorized preparation action.
Transport uncertainty triggers authoritative readback without an automatic Save
retry. Attendance retains its existing operator Review/Save path. This UI
composition adds no RPC, Edge write, schema change, or API envelope change.

The current normal Attendance UI automatically overlays persisted active Attendance on Menu-covered default-derived working rows. Persisted values, including explicit zero, win; defaults fill only missing covered School/date pairs and remain unconfirmed until Review and consequential Save. The former manual `Tạo từ sĩ số mặc định` setup action is superseded by [PLANNING-UX-01B](../implementation-tasks/TASK-PLANNING-UX-01B-menu-attendance-operator-correction.md). The lower-level default-creation API remains callable support compatibility and does not represent a required operator stage.

## Dish lifecycle and Recipe readiness amendment

Every ACTIVE assigned Dish is checked for eligible released Recipe availability
and effective composition readiness, regardless of the legacy
`requires_need_generation` value. Missing Recipe and blocked composition retain
`RECIPE_NOT_READY` and `EFFECTIVE_BOM_BLOCKED` warnings. Existing inactive-Dish
future-planning blockers, Menu approval rules, and Attendance behavior remain
unchanged. Committed inactive references are handled by Need Generation's
explicit blocker/correction path; they are never silently omitted.
