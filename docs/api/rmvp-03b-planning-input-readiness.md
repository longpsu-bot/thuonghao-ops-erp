# RMVP-03B Planning Input Readiness API Contract

- **Status:** Proposed — awaiting Product Owner approval
- **Contract version:** `RMVP-03B.v1`
- **Domain:** Planning
- **Canonical proposed decisions:** [Decision RMVP-03B](../decisions/decision-rmvp-03b-connected-planning-input-readiness.md)
- **Connected architecture:** [RMVP-03B Connected Planning Input Readiness](../architecture/rmvp-03b-connected-planning-input-readiness.md)

## 1. Boundary

This is the sole canonical proposed function registry for connected Planning
Input Readiness.

The closed surface contains one shaped read and three transactional commands:

```text
atlas_api.get_planning_input_readiness_workbench(request jsonb)
atlas_api.evaluate_planning_input_readiness(request jsonb)
atlas_api.request_planning_input_need_generation(request jsonb)
atlas_api.invalidate_planning_input_readiness(request jsonb)
```

No function exists until a later approved implementation merges. This contract
does not modify the implemented PA-06A registry or the API Contracts Catalogue.

## 2. Common envelopes

### 2.1 Read envelope

```json
{
  "contract_version": "RMVP-03B.v1",
  "requested_by_auth_subject": "uuid",
  "correlation_id": "uuid",
  "payload": {
    "period_start": "YYYY-MM-DD",
    "period_end": "YYYY-MM-DD",
    "source_selection": {
      "weekly_menu": "complete typed triple or null",
      "attendance": "complete typed triple or null",
      "pantry": "complete typed triple or null"
    }
  }
}
```

`source_selection` is optional on the first read. If supplied, each member must
be a complete candidate triple returned by an authoritative prior read for the
same exact period. The read writes no state.

### 2.2 Command envelope

```json
{
  "contract_version": "RMVP-03B.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "nonblank text, max 200 characters",
  "requested_by_auth_subject": "uuid",
  "requested_at": "valid non-future ISO-8601 timestamp",
  "expected_root_status": "ABSENT|NOT_READY|READY|NEED_GENERATION_REQUESTED|INVALIDATED",
  "expected_current_evaluation_id": "uuid or null",
  "expected_current_evaluation_version": "positive integer or null",
  "reason_code": "closed action-specific code",
  "reason_note": "normalized text or null",
  "payload": {}
}
```

The backend requires exact JWT-subject equality, resolves an active Actor,
checks capability plus active `GLOBAL` scope, and never accepts a
browser-authored actor ID.

For `ABSENT`, both evaluation expectations are null. For an existing root,
both are present and exact. The Planning Input Set has no version; the contract
does not add or simulate one.

### 2.3 Typed source triples

```json
{
  "weekly_menu": {
    "weekly_menu_id": "uuid",
    "weekly_menu_version": 1,
    "weekly_menu_approval_snapshot_id": "uuid"
  },
  "attendance": {
    "attendance_batch_id": "uuid",
    "attendance_version": 1,
    "attendance_approval_snapshot_id": "uuid"
  },
  "pantry": {
    "pantry_need_batch_id": "uuid",
    "pantry_need_batch_version": 1,
    "pantry_need_approval_snapshot_id": "uuid"
  }
}
```

Each source family is a complete object or null. Status, approval flags,
periods, issue codes, issue counts, line counts, and Pantry evidence kind are
not command input authority.

## 3. Canonical function registry

### 3.1 `atlas_api.get_planning_input_readiness_workbench(request jsonb)`

- **Contract version:** `RMVP-03B.v1`
- **Required capability:** existing `planning.inputs.read`
- **Scope:** existing active `GLOBAL` scope
- **Request selector:** exact inclusive `period_start`, `period_end`, and
  optional exact `source_selection`
- **Authoritative aggregate:** read-only projection of the exact-period
  Planning Input Set when present; explicit root absence otherwise
- **Exact IDs and versions consumed:** optional selected Weekly Menu,
  Attendance, and Pantry triples; current source root/version/latest-snapshot
  pointers; exact current Planning Input evaluation identity/version
- **Response/readback:** the complete workbench shape in section 4, including
  source candidates, selected evidence, current decision, issues, backend
  actions, immutable evaluations, and request/invalidation history
- **Side effects:** none
- **Receipt:** none
- **Event:** none
- **Audit:** none
- **Safe failures:** malformed/invalid period, auth-subject mismatch,
  authentication/actor failure, capability denial, scope denial, malformed or
  foreign-period selection, ownership-mismatched selection, and bounded
  internal read failure
- **Test ownership:** future RMVP-03B pgTAP read/security/shape assertions;
  readiness adapter/model tests; connected workbench period, candidate,
  action, history, stale, and safe-message tests

The read returns all current approved overlapping candidates in deterministic
order. It does not silently select among multiple candidates. A supplied
candidate is selected only when it is one of the exact currently returned
candidates for the same period. A well-formed typed candidate from a prior read
that is no longer current is returned as `STALE`, cannot enable an action, and
is not authoritative current evidence.

### 3.2 `atlas_api.evaluate_planning_input_readiness(request jsonb)`

- **Contract version:** `RMVP-03B.v1`
- **Required capability:** proposed `planning.input_readiness.write`
- **Scope:** existing active `GLOBAL` scope
- **Request payload:**

```json
{
  "period_start": "YYYY-MM-DD",
  "period_end": "YYYY-MM-DD",
  "source_candidates": {
    "weekly_menu": "complete typed triple or null",
    "attendance": "complete typed triple or null",
    "pantry": "complete typed triple or null"
  }
}
```

- **Envelope reason:** fixed
  `reason_code = READINESS_EVALUATION_REQUESTED`; `reason_note = null`
- **Authoritative aggregate:** one exact-period Planning Input Set and its new
  immutable Planning Input Evaluation
- **Exact IDs and versions consumed:** exact current root status/current
  evaluation expectations; all supplied typed source triples; source root
  current versions, lifecycles, latest approval pointers, periods, and exact
  snapshot lines needed for warning derivation
- **Response/readback:** standard command success with
  `affected_aggregate_ids.planning_input_set_id`,
  `planning_input_evaluation_id`,
  `new_versions.current_evaluation_version`, result/count summaries, event and
  audit IDs, safe message, and complete `authoritative_readback`
- **Side effects:** atomically create the root only when absent; create the
  first or exact next immutable evaluation; create every-and-only immutable
  issue rows; set the exact root pointer/status/update time
- **Receipt:** one shared command receipt; scope key is the normalized exact
  period; nullable receipt expected version equals the expected current
  evaluation version; exact replay returns the original response
- **Event:** one `PlanningInputReadinessEvaluated` domain event on
  `PlanningInputSet`
- **Audit:** one same-name Planning audit event with before/after root state,
  exact evaluation/source/count evidence, resolved Actor, command/correlation
  IDs, fixed reason, `atlas_api` source, and transaction time
- **Safe failures:** common envelope/auth/capability/scope failures;
  invalid/duplicate period; `STALE_ROOT_STATE`;
  `STALE_CURRENT_EVALUATION`; `AMBIGUOUS_SOURCE_CANDIDATE`;
  `STALE_SOURCE_CANDIDATE`; `SOURCE_CANDIDATE_OWNERSHIP_MISMATCH`;
  `INVALID_LIFECYCLE_STATE`; `IDEMPOTENCY_CONFLICT`;
  `RETRYABLE_CONCURRENCY_FAILURE`; invariant failure; bounded internal command
  failure
- **Test ownership:** future RMVP-03B pgTAP atomic root/evaluation/issue,
  candidate, currentness, containment, warning, lifecycle, receipt,
  event/audit, replay/conflict/concurrency, RLS/grant/runtime, and non-mutation
  assertions; adapter and connected UX action/readback tests

The caller cannot send a result, status, issue, severity, message, count,
evaluation ID/version, or new root ID. Missing source families are null and
become backend-computed blockers only when current backend candidate discovery
also returns `MISSING`. Caller omission of an available candidate, or a stale
or ambiguous non-null candidate, fails without creating an evaluation.

### 3.3 `atlas_api.request_planning_input_need_generation(request jsonb)`

- **Contract version:** `RMVP-03B.v1`
- **Required capability:** proposed `planning.input_readiness.write`
- **Scope:** existing active `GLOBAL` scope
- **Request payload:**

```json
{
  "planning_input_set_id": "uuid",
  "period_start": "YYYY-MM-DD",
  "period_end": "YYYY-MM-DD",
  "current_source_bindings": {
    "weekly_menu": "complete typed triple",
    "attendance": "complete typed triple",
    "pantry": "complete typed triple"
  }
}
```

- **Envelope reason:** fixed
  `reason_code = NEED_GENERATION_HANDOFF_REQUESTED`; `reason_note = null`
- **Authoritative aggregate:** the exact Planning Input Set
- **Exact IDs and versions consumed:** set ID and exact period; expected root
  status `READY`; exact current evaluation ID/version; all three exact
  current-evaluation source triples; current source status/version/latest
  approval and containment evidence
- **Response/readback:** standard command success with set ID, retained
  evaluation ID/version, `new_versions.current_evaluation_version` unchanged,
  event/audit IDs, handoff-only safe message, and complete authoritative
  workbench
- **Side effects:** only
  `READY -> NEED_GENERATION_REQUESTED`, root update time, receipt, event, and
  audit; current evaluation and issue rows remain unchanged
- **Receipt:** one shared receipt keyed to the exact Planning Input Set;
  receipt expected version is the expected current evaluation version; exact
  replay returns the original response
- **Event:** one `PlanningInputNeedGenerationRequested` domain event on
  `PlanningInputSet`
- **Audit:** one same-name Planning audit event containing
  `READY -> NEED_GENERATION_REQUESTED`, retained evaluation/source evidence,
  Actor, command/correlation IDs, fixed reason, source interface, and time
- **Safe failures:** common failures; root/period mismatch;
  `STALE_ROOT_STATE`; `STALE_CURRENT_EVALUATION`;
  `CURRENT_EVALUATION_NOT_READY`; `CURRENT_EVALUATION_HAS_BLOCKERS`;
  `HISTORICAL_PANTRY_BINDING_REQUIRED`; `STALE_SOURCE_BINDING`;
  `INVALID_LIFECYCLE_STATE`; `IDEMPOTENCY_CONFLICT`;
  `RETRYABLE_CONCURRENCY_FAILURE`; invariant/internal failure
- **Test ownership:** future RMVP-03B pgTAP exact handoff transition,
  three-source revalidation, null-Pantry rejection, unchanged evaluation,
  receipt/event/audit, replay/concurrency, and physical no-Need-Generation/no-
  downstream-write assertions; adapter and UX request/uncertainty tests

The function does not create or call a Need Generation command. It creates no
run, contribution, calculation, or downstream fact.

### 3.4 `atlas_api.invalidate_planning_input_readiness(request jsonb)`

- **Contract version:** `RMVP-03B.v1`
- **Required capability:** proposed `planning.input_readiness.write`
- **Scope:** existing active `GLOBAL` scope
- **Request payload:**

```json
{
  "planning_input_set_id": "uuid",
  "period_start": "YYYY-MM-DD",
  "period_end": "YYYY-MM-DD"
}
```

- **Envelope reason:** exactly one of:
  `UPSTREAM_SOURCE_CHANGED`, `PLANNING_REVIEW_CORRECTION`, or
  `NEED_GENERATION_REQUEST_WITHDRAWN`; note requirements are defined below
- **Authoritative aggregate:** the exact Planning Input Set
- **Exact IDs and versions consumed:** set ID and exact period; expected
  `READY` or `NEED_GENERATION_REQUESTED`; exact current evaluation ID/version;
  current evaluation bindings and current source evidence when reason is
  `UPSTREAM_SOURCE_CHANGED`
- **Response/readback:** standard command success with set ID, retained
  evaluation ID/version, unchanged
  `new_versions.current_evaluation_version`, event/audit IDs, safe message, and
  complete authoritative workbench
- **Side effects:** only permitted status transition to `INVALIDATED`, root
  update time, receipt, event, and audit; evaluation, bindings, result, issues,
  and history remain immutable
- **Receipt:** one shared receipt keyed to the exact Planning Input Set;
  receipt expected version is the expected current evaluation version; exact
  replay returns the original response
- **Event:** one `PlanningInputReadinessInvalidated` domain event on
  `PlanningInputSet`
- **Audit:** one same-name Planning audit event containing prior/next status,
  retained evaluation, exact reason/note, backend-detected stale source types
  where applicable, Actor, IDs, source interface, and time
- **Safe failures:** common failures; root/period mismatch;
  `STALE_ROOT_STATE`; `STALE_CURRENT_EVALUATION`;
  `INVALID_LIFECYCLE_STATE`; `INVALID_INVALIDATION_REASON`;
  `INVALIDATION_REASON_MISMATCH`; `REASON_NOTE_REQUIRED`;
  `IDEMPOTENCY_CONFLICT`; `RETRYABLE_CONCURRENCY_FAILURE`;
  invariant/internal failure
- **Test ownership:** future RMVP-03B pgTAP two allowed transitions,
  `NOT_READY` rejection, closed reasons, conditional notes, source-change
  proof, retained evidence, receipt/event/audit, replay/concurrency, and no
  downstream mutation assertions; adapter and UX reason/history tests

Reason rules are:

| Reason                              | Allowed state                                                                                                              | Note                               |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `UPSTREAM_SOURCE_CHANGED`           | `READY` or `NEED_GENERATION_REQUESTED`, only when backend comparison proves at least one bound source is no longer current | Null or nonblank normalized text   |
| `PLANNING_REVIEW_CORRECTION`        | `READY` or `NEED_GENERATION_REQUESTED`                                                                                     | Mandatory nonblank normalized text |
| `NEED_GENERATION_REQUEST_WITHDRAWN` | `NEED_GENERATION_REQUESTED` only                                                                                           | Mandatory nonblank normalized text |

## 4. Authoritative workbench response

A successful read returns:

```json
{
  "success": true,
  "contract_version": "RMVP-03B.v1",
  "correlation_id": "uuid",
  "workbench": {}
}
```

Command success returns the same object under
`authoritative_readback`.

The workbench shape is:

```json
{
  "period": {
    "period_start": "YYYY-MM-DD",
    "period_end": "YYYY-MM-DD",
    "inclusive": true,
    "monday_week_convenience": {
      "week_start": "YYYY-MM-DD",
      "week_end": "YYYY-MM-DD"
    }
  },
  "decision": "NOT_EVALUATED|NOT_READY|READY|NEED_GENERATION_REQUESTED|INVALIDATED",
  "root": {
    "planning_input_set_id": "uuid",
    "readiness_status": "NOT_READY|READY|NEED_GENERATION_REQUESTED|INVALIDATED",
    "current_evaluation_id": "uuid",
    "created_at": "timestamp",
    "updated_at": "timestamp"
  },
  "current_evaluation": {
    "planning_input_evaluation_id": "uuid",
    "evaluation_version": 1,
    "evaluation_result": "NOT_READY|READY",
    "blocking_issue_count": 0,
    "warning_count": 0,
    "evaluated_by_actor_id": "uuid",
    "evaluated_by_display_name": "text",
    "evaluated_at": "timestamp",
    "source_bindings": {},
    "issues": {
      "blockers": [],
      "warnings": []
    }
  },
  "source_evidence": {
    "weekly_menu": {},
    "attendance": {},
    "pantry": {}
  },
  "allowed_actions": {
    "can_evaluate": false,
    "can_request_need_generation": false,
    "can_invalidate": false,
    "invalidation_reason_codes": [],
    "disabled_reasons": []
  },
  "evaluation_history": [],
  "request_history": [],
  "invalidation_history": []
}
```

`root` and `current_evaluation` are null when no exact-period root exists.

Each source evidence member contains:

```json
{
  "selection_state": "SELECTED|MISSING|AMBIGUOUS|STALE",
  "coverage": "COVERS|DOES_NOT_COVER|NOT_APPLICABLE",
  "source_current": true,
  "selected": "typed candidate or null",
  "candidates": [],
  "safe_message": "text"
}
```

A candidate contains only its typed triple plus source period, source lifecycle
status, latest-approval/currentness booleans, approval actor/time, line count,
and coverage. Pantry candidates additionally contain:

```json
{
  "pantry_evidence_kind": "POSITIVE_LINES|EXPLICIT_ZERO_LINES",
  "no_additions_confirmed": true,
  "line_count": 0
}
```

`EXPLICIT_ZERO_LINES` requires all accepted zero-line invariants. Missing
Pantry uses `pantry_evidence_kind = MISSING` in the source summary and has no
candidate.

Each issue includes exact immutable issue ID, severity, code, safe message,
input type, School context, and service date where present.

Each evaluation-history entry includes the full immutable evaluation summary,
all three historical binding families including null Pantry when historical,
and every owned issue. Null-Pantry history includes:

```json
{
  "historical_pantry_state": "PRE_PANTRY_NULL_BINDING",
  "can_authorize_need_generation_request": false
}
```

Request and invalidation histories are shaped from shared domain/audit events
and include event/audit IDs, command/correlation IDs, resolved actor display,
occurred time, prior/next status, retained evaluation ID/version, reason code,
and safe reason note. Raw receipt hashes and internal payloads are not exposed.

## 5. Success and idempotency

Command success uses:

```json
{
  "success": true,
  "contract_version": "RMVP-03B.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_status": "COMPLETED",
  "affected_aggregate_ids": {
    "planning_input_set_id": "uuid",
    "planning_input_evaluation_id": "uuid"
  },
  "new_versions": {
    "current_evaluation_version": 1
  },
  "emitted_event_ids": ["uuid"],
  "audit_event_ids": ["uuid"],
  "safe_operator_message": "text",
  "warnings": [],
  "blockers": [],
  "authoritative_readback": {}
}
```

For request/invalidation,
`planning_input_evaluation_id` and `current_evaluation_version` are the retained
current values.

The first accepted intent creates one receipt. Exact replay returns the stored
response and original IDs without a second state change, event, or audit.
Changed reuse of command ID or scoped idempotency key returns
`IDEMPOTENCY_CONFLICT`.

## 6. Safe failures and retry behavior

Safe errors use the existing structured categories:

```text
success = false
contract_version
error_code
safe_message
domain = PLANNING
read_name or command_name
retryable
field_errors
blocking_references
expected values
actual safe values
correlation_id
command_id when applicable
```

Common errors include:

- `AUTH_SUBJECT_MISMATCH`
- `AUTHENTICATION_REQUIRED`
- `ACTOR_UNAVAILABLE`
- `CAPABILITY_DENIED`
- `SCOPE_DENIED`
- `VALIDATION_FAILED`
- `NOT_FOUND`
- `STALE_ROOT_STATE`
- `STALE_CURRENT_EVALUATION`
- `AMBIGUOUS_SOURCE_CANDIDATE`
- `STALE_SOURCE_CANDIDATE`
- `SOURCE_CANDIDATE_OWNERSHIP_MISMATCH`
- `INVALID_LIFECYCLE_STATE`
- `IDEMPOTENCY_CONFLICT`
- `RETRYABLE_CONCURRENCY_FAILURE`
- `INVARIANT_VIOLATION`
- bounded internal read/command failures

Only `RETRYABLE_CONCURRENCY_FAILURE` authorizes exact request retry.
Stale/ambiguous failures require refresh and a new reviewed command intent.
Transport uncertainty has no success response and must never enable a later
action.

Safe messages are Vietnamese at the application boundary and never include
SQL, schema/relation/function internals, role/policy names, raw JWT data,
credentials, or stack traces.

## 7. Security contract

Future implementation must preserve:

- `authenticated` execution only on the four reviewed functions;
- no `anon` or `service_role` execution;
- no browser access to private Planning, Core, or Audit relations;
- `SECURITY DEFINER`, empty `search_path`, exact qualification, and revoke-first
  grants;
- `atlas_read_runtime` ownership for the shaped read;
- `atlas_planning_command_runtime` ownership for the three commands;
- existing forced RLS and least-privilege policies;
- existing Actor resolution and exact auth-subject binding;
- existing `GLOBAL` scope; and
- one proposed readiness-write capability at most.

React must use a typed adapter and must not contain service-role credentials,
direct private-schema queries, readiness calculation, issue calculation, or
lifecycle authority.

## 8. Explicit non-goals

The proposed functions do not:

- alter RMVP-03A or PANTRY-02 source lifecycles;
- create an automatic source trigger;
- acknowledge or waive warnings;
- create a Need Generation run or contribution;
- read Pantry lines into calculation;
- resolve Recipe/BOM evidence;
- create Theoretical Need, Confirmed Need, or Purchase Handoff;
- mutate Procurement, Warehouse, Dispatch, Wholesale, OPS v1/v2, Retool,
  hosted Supabase, or production data; or
- authorize implementation merely by appearing in this document.
