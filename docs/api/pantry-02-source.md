# PANTRY-02 Pantry Source API Contract

## Boundary

Contract version: `PANTRY-02.v1`

The API exposes exactly two reads/previews and four transactional commands through `atlas_api`. All six require the existing global Planning scope and exact authenticated-subject binding. Clients have no direct access to private Pantry relations and must use authoritative response data after every successful command.

## Envelopes

Read and preview:

```json
{
  "contract_version": "PANTRY-02.v1",
  "requested_by_auth_subject": "uuid",
  "correlation_id": "uuid",
  "payload": {}
}
```

Command:

```json
{
  "contract_version": "PANTRY-02.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "bounded stable key",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601 timestamp",
  "reason_code": "BOUNDED_REASON",
  "reason_note": "operator explanation or null",
  "payload": {}
}
```

Reopen requires a nonblank normalized `reason_note`. Transport uncertainty is never success.

## Exact function registry

<!-- prettier-ignore -->
| Function | Version | Capability | Scope | Request | Response | Aggregate / IDs and versions consumed | Side effects | Event and audit | Safe errors | Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `get_pantry_source_workbench(request jsonb)` | `PANTRY-02.v1` | `planning.inputs.read` | Existing `GLOBAL` | Explicit `week_start` | Week, backend source method, active typed catalogs with derived Location/Unit, current batch, active/invalid lines, issues, backend `allowed_actions`, approval snapshots, audit timeline | Reads the week’s `PantryNeedBatch` and current/historical IDs and versions | None | None | Envelope, auth-subject, capability, scope, invalid/non-Monday week, internal read failure | pgTAP workbench/security; Pantry adapter/component tests; local browser-key read |
| `preview_pantry_source(request jsonb)` | `PANTRY-02.v1` | `planning.inputs.read` | Existing `GLOBAL` | `week_start`, explicit `no_additions_confirmed`, operator rows, optional `claimed_source_signature` | Canonical derived rows, signature, categorized new/changed/unchanged/omitted lines, changed School/dates, blockers/warnings, `can_save` | Reads current batch/version/signature plus current typed School/Location/Ingredient/Unit/Purpose facts | None | None | Closed blocker catalog below, signature mismatch, auth/capability/scope failure | pgTAP canonical/signature/reference/quantity/note tests; frontend preview tests; local preview |
| `save_pantry_draft(request jsonb)` | `PANTRY-02.v1` | `planning.pantry.write` | Existing `GLOBAL` | Expected version, `week_start`, explicit zero fact, preview signature, expected persisted signature, raw operator rows | Standard success envelope and authoritative workbench | Creates or locks one batch; consumes expected batch version/signature; locks affected stable lines and references | Atomic complete replacement; stable upsert; omitted-line invalidation; zero confirmation; command receipt; preserves `DRAFT` or `REOPENED` working status | `PantryDraftCreated` or `PantryDraftReplaced`; one audit event for a material change; none for `NO_CHANGE` or replay | Validation, stale version/signature, invalid lifecycle, idempotency conflict, retryable concurrency, invariant failure | pgTAP replacement/stability/replay/no-change tests; adapter/UI tests; local stable replacement |
| `validate_pantry(request jsonb)` | `PANTRY-02.v1` | `planning.pantry.write` | Existing `GLOBAL` | Expected version, week, expected persisted signature | Standard success envelope and authoritative workbench | Locks current editable batch and active lines; consumes current version/signature/references | Rechecks all authority/invariants; moves `DRAFT` or `REOPENED` to `VALIDATED`; increments once | `PantryValidated`; one audit event | Stale version/signature, invalid lifecycle, invariant/reference failure, auth/capability/scope, idempotency conflict, retryable concurrency | pgTAP lifecycle/stale tests; UI lifecycle test; local validation |
| `approve_pantry(request jsonb)` | `PANTRY-02.v1` | `planning.inputs.approve` | Existing `GLOBAL` | Expected version, week, expected persisted signature | Standard success envelope and authoritative workbench with latest/history snapshots | Locks `VALIDATED` batch, active lines, current references; consumes exact current version/signature | Creates one immutable snapshot and every-and-only active snapshot lines; supports zero-line header; updates latest pointer; increments once | `PantryApproved`; one audit event | Stale version/signature, invalid lifecycle, invariant/reference failure, auth/capability/scope, idempotency conflict, retryable concurrency | pgTAP exact positive/zero snapshots, immutability, forced deferred guards; UI history; local two approvals |
| `reopen_pantry(request jsonb)` | `PANTRY-02.v1` | `planning.inputs.approve` | Existing `GLOBAL` | Expected version, week, expected persisted signature, nonblank reason | Standard success envelope and authoritative workbench | Locks current `APPROVED` batch and consumes exact version/signature/latest snapshot evidence | Moves to `REOPENED`, increments once, preserves all snapshots | `PantryReopened`; one audit event containing reason evidence | Missing reason, stale version/signature, invalid lifecycle, auth/capability/scope, idempotency conflict, retryable concurrency | pgTAP reason/history/reapproval tests; UI reopen gating; local reopen |

No other Pantry function is public.

## Operator row

Accepted caller-authored fields are exactly:

```json
{
  "service_date": "YYYY-MM-DD",
  "school_id": "uuid",
  "ingredient_id": "uuid",
  "pantry_need_purpose_id": "uuid",
  "requested_quantity": "2.500000",
  "note": "normalized text or null",
  "source_request_reference": "optional normalized text",
  "source_row_reference": "optional evidence"
}
```

`delivery_location_id`, `unit_id`, Customer relationship, Purpose metadata/status, lifecycle status, supplier, and Warehouse routing are rejected caller-authority fields.

## Signature

PostgreSQL computes the authoritative SHA-256 signature. It includes:

- week and explicit no-additions fact;
- service date and School;
- backend-derived default Delivery Location;
- Ingredient and backend-resolved purchase Unit;
- Purpose;
- exact quantity;
- normalized note;
- normalized source request reference.

Row ordering, harmless whitespace, Unicode representation, and source-row evidence do not affect it. React does not calculate or decide the signature.

## Workbench

The workbench returns:

- explicit week and fixed backend source method;
- active Purposes ordered by backend display order;
- eligible active Schools with active `SCHOOL_CATERING` Customer and exact active default Delivery Location;
- eligible active Ingredients with exact active purchase Unit;
- safe `PURPOSE_CATALOG_EMPTY` readiness when no active Purpose exists;
- current batch/status/version/signature/zero fact;
- active and invalid stable lines with safe historical display;
- current blockers/warnings;
- backend-derived `can_preview`, `can_save`, `can_validate`, `can_approve`, and `can_reopen`;
- exact latest and historical approval snapshots and lines;
- Pantry command/audit history.

## Stable blocker catalog

The closed safe blocker set covers:

- `INVALID_WEEK_START`, `WEEK_START_NOT_MONDAY`, `INVALID_SERVICE_DATE`, `SERVICE_DATE_OUTSIDE_WEEK`;
- `SCHOOL_REQUIRED`, `INVALID_SCHOOL_ID`, `UNKNOWN_SCHOOL`, `INACTIVE_SCHOOL`, `SCHOOL_CUSTOMER_TYPE_INVALID`, `SCHOOL_CUSTOMER_INACTIVE`;
- `DEFAULT_DELIVERY_LOCATION_MISSING`, `DEFAULT_DELIVERY_LOCATION_INACTIVE`, `DEFAULT_DELIVERY_LOCATION_CUSTOMER_MISMATCH`, `STALE_DEFAULT_DELIVERY_LOCATION`;
- `INGREDIENT_REQUIRED`, `INVALID_INGREDIENT_ID`, `UNKNOWN_INGREDIENT`, `INACTIVE_INGREDIENT`, `ARCHIVED_INGREDIENT`;
- `PURCHASE_UNIT_MISSING`, `PURCHASE_UNIT_INACTIVE`, `STALE_PERSISTED_UNIT`;
- `PURPOSE_REQUIRED`, `INVALID_PURPOSE_ID`, `UNKNOWN_PURPOSE`, `INACTIVE_PURPOSE`, `PURPOSE_CATALOG_EMPTY`;
- `MISSING_REQUIRED_NOTE`, `PROHIBITED_NOTE_PRESENT`, `WHITESPACE_ONLY_NOTE`;
- `QUANTITY_REQUIRED`, `QUANTITY_NOT_POSITIVE`, `QUANTITY_NONFINITE`, `QUANTITY_MALFORMED`;
- `DUPLICATE_ACTIVE_GRAIN`, `NO_ADDITIONS_CONFIRMATION_REQUIRED`, `ACTIVE_LINES_WITH_NO_ADDITIONS`;
- `CALLER_DELIVERY_LOCATION_NOT_ALLOWED`, `CALLER_UNIT_NOT_ALLOWED`, `UNREVIEWED_ROW_FIELD`;
- `SOURCE_SIGNATURE_MISMATCH`, `PERSISTED_SIGNATURE_MISMATCH`, `STALE_VERSION`, `STALE_SOURCE_SIGNATURE`;
- `INVALID_LIFECYCLE_STATE`, `AUTH_SUBJECT_MISMATCH`, `ACTOR_UNAVAILABLE`, `CAPABILITY_DENIED`, `SCOPE_DENIED`, `IDEMPOTENCY_CONFLICT`, `RETRYABLE_CONCURRENCY_FAILURE`, and safe internal failure codes.

Warnings are backend-defined only. The first slice currently emits no frontend-authored warning.

## Success and idempotency

Material commands return the standard Atlas success envelope: command/correlation IDs, affected aggregate IDs, new version, emitted event ID, audit event ID, safe operator message, and authoritative `workbench`.

Exact command replay returns the stored durable response. Reusing the same idempotency key for changed content returns `IDEMPOTENCY_CONFLICT`. Exact canonical save replacement returns `idempotency_status = "NO_CHANGE"` without a new event, audit, or version.

## Security and exclusions

All functions have empty `search_path`, exact qualification, revoked default/public execution, and exact `authenticated` grants. `anon` and `service_role` have no execution. Browser roles have no private relation privileges.

The functions do not call `record_wholesale_source`, `release_wholesale_order`, or any generic demand/source engine. Approval writes no readiness, Need Generation, Confirmed Need, Purchase Handoff, Procurement, Warehouse, Dispatch, or Wholesale object.

## Additive consequential Save contract (`PANTRY-02.v2`)

PLANNING-CONTRACT-01 adds `atlas_api.save_pantry(request jsonb)`. It requires the existing `planning.pantry.write` capability and the `PANTRY-02.v2` command envelope. Its payload is the complete v1 Pantry Save payload: `week_start`, `no_additions_confirmed`, authoritative preview signature, expected persisted signature, and raw operator rows.

One transaction performs complete replacement, server derivation of Delivery Location and Unit, all Purpose/reference/blocker validation, stable-line handling, deterministic validation, immutable every-and-only approval snapshot creation, and current snapshot establishment. The browser cannot author Location, Unit, Purpose status, lifecycle, readiness, currentness, or routing. The response contains the authoritative Pantry workbench, automatic Planning preflight, and `CURRENT`, `OUTDATED`, or `NOT_GENERATED` downstream currentness as applicable.

Exact replay returns the original durable response, changed reuse conflicts, stale version/signature requires refresh and a new intent, and already-completed identical content returns `NO_CHANGE`. Prior positive and explicit-zero snapshots remain immutable. The six v1 APIs remain exact and callable for the connected UI coexistence window; their behavior and assertions are not weakened. See [PLANNING-CONTRACT-01](../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md).

The public v2 `requested_at` records client intent and permits no more than 60
seconds of positive clock skew. After acceptance, all internally derived Pantry
Save, Validate, Approve, and correction commands use PostgreSQL transaction
time. The six v1 timestamp validators are unchanged.
