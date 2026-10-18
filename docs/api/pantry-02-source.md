# PANTRY-02 Pantry Source API Contract

**Current operator model — 18 October Owner amendment:** exactly two creation
choices, Bổ sung (`planning_identified_supplement`) and Hàng đặt riêng
(`school_requested_supplement`). The second label supersedes earlier wording
below; UUIDs/codes and immutable snapshots stay unchanged. New scopes are ADDITIVE.
COMPLETE is historical compatibility, never an advanced/new-line option. Existing
current bindings are not auto-flipped; the [closeout audit](../implementation-tasks/TASK-ATLAS-B1-PRODUCT-MODEL-CLOSEOUT.md)
records the two effective Staging scopes needing controlled reconciliation.
R+B is a derived operational subtotal; H remains separate, and the final human
Confirmed Need quantity owns PO/PXK coverage. No Recipe/BOM change is implied.

## B1 two-source forward amendment — 18 October 2026

The connected #401 Pantry workbench now uses the existing authored-purpose
`PANTRY-02.v3` Preview and consequential Save contract. See the
[contract delta and validation record](../implementation-tasks/TASK-ATLAS-B1-PANTRY-TWO-SOURCE.md).
No public endpoint or lifecycle is added. The existing purpose-free v4 contract
remains callable; its neutral rows are never automatically reclassified.

The stable source grain is batch + date + School + derived Delivery Location +
Ingredient + Purpose. Purpose is immutable source identity. Different Purposes
may each author the same Ingredient; same-Purpose duplicates remain blockers.
Preview comparison joins, canonical ordering, signatures and stable Save conflict
targets include Purpose. Omission invalidates only the omitted source, and
restoring a grain reuses its UUID. All old approval snapshots remain unchanged.

The operator selects `Bổ sung` (`planning_identified_supplement`) or
`Đặt theo yêu cầu nhà trường` (`school_requested_supplement`) once for newly added
lines. The UI obtains the exact active reference ID from the backend catalog;
PostgreSQL validates it and applies its existing note rule. The browser cannot
author Purpose metadata, Location or Unit. Existing categories, including neutral
and inactive historical references, display their actual saved classification.
Notes remain optional for the existing Foundation package's two OPTIONAL
categories; no migration rewrites catalog policies or historical note evidence.

The Owner's 18 October UI simplification keeps only `Nguồn của dòng mới` in the
creation toolbar. Newly represented School/date rows use the existing ADDITIVE
default; the UI does not offer a calculation-mode selector. Saved School/date
modes, including COMPLETE, remain unchanged and are displayed as read-only facts.
Choosing a source category never changes an existing calculation mode. This is
the connected vnext interaction policy; the D-044 backend contracts remain valid.

Exact v3 retries use the existing receipt-first v4 authorization boundary before
mutable impact checks. New intents still require the same consequential correction
guards, source signature and expected version. The separate School/date modes
remain unchanged: ADDITIVE combines Recipe and both direct contributions;
COMPLETE excludes Recipe demand for that School/date. Existing source-line and
snapshot references provide downstream provenance; no stored summary is added.

Migration: `20261018072142_pantry_b1_two_source_identity.sql`. V1–v4 remain
available. The legacy non-vnext workbench explicitly retains v4 requests; only
the accepted vnext interaction selects authored v3. No hosted migration is applied.

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

`PANTRY-02.v2` remains a forward-compatible implicit-`ADDITIVE` contract. The
caller does not send `school_date_modes`; the backend derives exactly one
`ADDITIVE` fact for each School/date represented by positive rows before entering
the common consequential Save boundary. This internal projection does not change
the v2 receipt, checksum, idempotency, stale-version, stale-signature, replay, or
`NO_CHANGE` semantics.

One transaction performs complete replacement, server derivation of Delivery Location and Unit, all Purpose/reference/blocker validation, stable-line handling, deterministic validation, immutable every-and-only approval snapshot creation, and current snapshot establishment. The browser cannot author Location, Unit, Purpose status, lifecycle, readiness, currentness, or routing. The response contains the authoritative Pantry workbench, automatic Planning preflight, and `CURRENT`, `OUTDATED`, or `NOT_GENERATED` downstream currentness as applicable.

Exact replay returns the original durable response, changed reuse conflicts, stale version/signature requires refresh and a new intent, and already-completed identical content returns `NO_CHANGE`. Prior positive and explicit-zero snapshots remain immutable. The six v1 APIs remain exact and callable for the connected UI coexistence window; their behavior and assertions are not weakened. See [PLANNING-CONTRACT-01](../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md).

The public v2 `requested_at` records client intent and permits no more than 60
seconds of positive clock skew. After acceptance, all internally derived Pantry
Save, Validate, Approve, and correction commands use PostgreSQL transaction
time. The six v1 timestamp validators are unchanged.

## D-044 forward amendment — Direct Ingredient Need mode

`PANTRY-02.v3` at the existing preview, Save, and workbench names adds
`school_date_modes`, containing exactly one `ADDITIVE | COMPLETE` choice for every
School/date represented by positive direct lines. The backend continues to derive
Delivery Location and Unit. Purpose remains explanatory and is not composition
authority.

The mode is stored privately at Pantry batch + School + date and copied into the
immutable approval snapshot. Existing snapshots with no mode remain valid and are
read as `ADDITIVE`; no history is backfilled. `COMPLETE` is available only through
the v3 consequential Save and means that exact School/date requires no Recipe,
Weekly Menu, or Attendance contribution. The common Pantry workbench remains the
only normal direct-Ingredient input surface; no separate wholesale UI or recipient
is added.

For `PANTRY-02.v3`, a blocker-free `REPLACEMENT` of an `APPROVED` Pantry batch may
return `preview.can_save = true` when the Actor holds `planning.pantry.write`. This
only makes the proposal eligible for the separate Planning correction-impact read;
`get_planning_source_correction_impact` remains the downstream Save-permission gate
and may still return `save_allowed = false`. The `PANTRY-02.v1` compatibility
preview retains its original lifecycle behavior and remains ineligible while the
current batch is `APPROVED`.

## Owner amendment — purpose-free direct entry (`PANTRY-02.v4`, 16 October 2026)

Implementation status: in progress; not deployed or certified. The Owner explicitly
removed the Purpose input and made Pantry line notes optional. This forward
contract applies only to the existing `preview_pantry_source` and consequential
`save_pantry` APIs. Reads and the authored-purpose v1/v2/v3 contracts remain
callable with their existing validation and lifecycle rules.

V4 rows contain only service date, School, Ingredient, exact quantity, optional
note and source references. Purpose, Location, Unit, lifecycle and other derived
fields are rejected. The backend inserts one fixed neutral reference classification
meaning “direct entry / purpose not specified”, with `OPTIONAL` notes. It is
technical metadata, not an operator-selected purpose. Blank or whitespace-only
notes normalize to SQL NULL. The neutral row is visible in the existing reference
catalog; legacy callers may explicitly select it, but existing Purpose rows and
`REQUIRED` / `PROHIBITED` rules are unchanged.

The original v4 command remains the receipt and idempotency identity. Separate
normalized legacy-compatible rows feed the existing Save children; separately
enriched canonical rows determine signatures. Neither normalization merges nor
deduplicates rows. Preview, correction-impact dates and Save use the same
normalization. Pantry correction proposals include the explicit closed
`source_contract_version: "PANTRY-02.v4"` marker; other source kinds reject it.
Existing exact source-impact comparisons and ADDITIVE / COMPLETE modes remain.

No current line or immutable historical snapshot is backfilled. Explicitly saving
legacy content may change its classification to the neutral reference; preview
and signature expose that change and the existing correction gates still apply.
Command correction/reopen reasons remain required where their existing contracts
require them; optional line notes do not relax audit reasons. Capabilities, scope,
School/date/Unit derivation, quantities, routing and composition are unchanged.

Acceptance requires purpose-spoof rejection, optional blank-note Save, exact
preview/impact/Save signature agreement, legacy note rules, unchanged history,
stale signatures and exact replay/conflict after a later Source Save and Need
release. No hosted write is authorized by this amendment.

The compatibility test also exposed a pre-existing D-044 omission:
`request_planning_input_need_generation` still used the three-source-only
`rmvp_03b_bindings_current` check. The amendment replaces only that call with
`direct_need_evaluation_ready` under the identical evaluation/date arguments.
This existing helper retains exact current snapshot/version/member coverage and
accepts only valid COMPLETE-only evidence when catering sources are absent.
Authentication, locking, receipts and all other request logic are unchanged.
