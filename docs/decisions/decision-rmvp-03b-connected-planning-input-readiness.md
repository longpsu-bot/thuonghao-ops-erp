# Decision RMVP-03B — Connected Planning Input Readiness

- **Status:** Proposed — awaiting Product Owner approval
- **Date:** 2026-07-31
- **Owner:** Product Owner
- **Domain:** Planning
- **Contract version:** `RMVP-03B.v1`
- **Scope:** Command/event, read model, API, and Vietnamese operator-UX
  decisions only
- **Parent authority:** [PD-01.4 Planning Domain Input Readiness](../architecture/planning-domain-input-readiness-contract.md)
- **Connected architecture:** [RMVP-03B Connected Planning Input Readiness](../architecture/rmvp-03b-connected-planning-input-readiness.md)
- **Canonical proposed API registry:** [RMVP-03B Planning Input Readiness API](../api/rmvp-03b-planning-input-readiness.md)

## Context

The Planning Input Set root, immutable evaluations, immutable issues, closed
lifecycle, exact Weekly Menu and Attendance bindings, and the exact Pantry
binding now exist in merged private persistence.

PANTRY-RDY-02 merged through PR #163 as
`70c380f49c148a1207574aabc5aefcb44cf30074`. It intentionally added no
command, capability, public API, event, audit contract, or React behavior.

RMVP-03A and PANTRY-02 provide source workbenches, but their reads do not
project the persisted Planning Input Set. The old in-memory readiness prototype
is lower-authority evidence and conflicts with the merged three-source
persistence in source shape, period semantics, and version ownership. It must
not govern the connected implementation.

The following registry closes the remaining proposed product and architecture
choices. It does not authorize implementation or claim Product Owner approval.

## Canonical proposed decision registry

This is the sole complete canonical registry for R3B-P01 through R3B-P12.

### R3B-P01 — Operator selector and root resolution

The authoritative selector is the exact inclusive pair:

```text
period_start
period_end
```

Both are ISO dates and `period_start <= period_end`. A Monday-start week is a
UI convenience only. The UI may default to or offer a shortcut for the current
Monday-through-Sunday week, but it must always submit and display the exact
inclusive pair.

The shaped read resolves an existing Planning Input Set only by exact
`(period_start, period_end)`. Read does not create a root. If none exists, it
returns explicit root absence. The first successful evaluation command creates
the one root for that exact pair in the same transaction as evaluation version
`1`. A concurrent duplicate exact-period creation is resolved through locking
and the existing unique period constraint, not by creating another root.

The root remains global Planning evidence. School, customer, delivery location,
source root, source version, and evaluator are not root-grain fields and must
not split it.

### R3B-P02 — Exact source candidate selection

Evaluation receives exact source root/version/snapshot IDs selected from the
dedicated backend-shaped readiness read. The browser never authors source
status, approval, coverage, currentness, result, issue, or count authority.

For each source family, the read returns every exact current approved snapshot
whose source period overlaps the selected period, ordered deterministically by
source period and typed IDs. Each candidate contains:

- the exact typed source root ID;
- the exact positive approved source version;
- the exact approval snapshot ID;
- source-period start and end;
- current lifecycle/latest-approval evidence;
- approval actor and time;
- coverage classification; and
- source-current/stale classification.

For each source family, the backend applies exactly this matrix:

| Current candidate evidence                                       | `selection_state` | `selected`                                   |
| ---------------------------------------------------------------- | ----------------- | -------------------------------------------- |
| Zero current approved overlapping candidates                     | `MISSING`         | Null                                         |
| Exactly one candidate                                            | `SELECTED`        | That exact candidate, selected automatically |
| Multiple candidates without one valid supplied selection         | `AMBIGUOUS`       | Null                                         |
| Multiple candidates with one exact supplied current candidate    | `SELECTED`        | That supplied candidate                      |
| A well-formed supplied prior-read candidate is no longer current | `STALE`           | The stale prior selection for display only   |

The backend does not choose among multiple candidates by approval time, row
order, UUID, or “latest row wins.” The operator may select one candidate from
the backend-returned multiple-candidate list, then the client re-reads using
that exact triple so the backend can return new `allowed_actions`. Exactly one
candidate requires no redundant operator selection.

If no candidate exists, the family is null and evaluation may create the
corresponding missing-source blocker. Null is accepted only when the backend's
current candidate discovery also returns `MISSING`; a caller cannot omit an
available candidate to force a `NOT_READY` result. Multiple same-type
snapshots are never combined for coverage.

The exact command families are:

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

Each family is either the complete typed triple or null. A malformed or
ownership-mismatched selection is rejected. A well-formed prior-read selection
that is no longer current is returned by the shaped read as `STALE`, with all
actions fail-closed until refresh. A stale or ambiguous selection submitted to
the evaluation command fails without creating or advancing an evaluation.
`AMBIGUOUS` and `STALE` always disable evaluation.
React cannot submit generic source types, status strings, issues, counts,
hashes, or JSON-only lineage.

### R3B-P03 — Readiness evaluation command

One transactional command evaluates readiness.

It locks or creates the exact-period root, validates the optimistic root and
current-evaluation expectations, locks and revalidates each selected source
candidate, computes the complete blocker/warning set, computes `READY` or
`NOT_READY`, creates the first or exact next immutable evaluation, creates
every-and-only immutable issue row, and advances the root current-evaluation
pointer and status where the lifecycle permits.

The caller cannot select:

- `planning_input_set_id` for a new period;
- evaluation ID or version;
- evaluation result;
- issue code, severity, message, context, or count;
- source status, coverage, or currentness; or
- root next status.

First evaluation requires expected root state `ABSENT`. Re-evaluation requires
exact expected state `NOT_READY` or `INVALIDATED` and the exact current
evaluation ID/version. `READY` and `NEED_GENERATION_REQUESTED` cannot be
re-evaluated directly.

The command is idempotent through the shared command receipt, uses optimistic
concurrency plus deterministic row locking, and returns the complete
authoritative readiness workbench. Exact replay returns the stored original
response and IDs. Changed reuse fails with `IDEMPOTENCY_CONFLICT`.

### R3B-P04 — Need Generation request command

One command performs only:

```text
READY -> NEED_GENERATION_REQUESTED
```

It locks the exact root and expected current evaluation, validates exact
expected status/evaluation ID/version, requires the evaluation result `READY`
and zero blockers, derives the exact Weekly Menu, Attendance, and Pantry
root/version/snapshot triples from that immutable evaluation, revalidates those
backend-derived bindings as current approved evidence, retains the same
evaluation ID/version, updates the root status, and writes one receipt, one
handoff domain event, and one audit event.

The browser does not repeat source triples in the request. Any evaluation or
source-currentness difference fails closed and requires refresh.

The command creates no Need Generation run, run attempt, input snapshot,
Recipe/BOM resolution, theoretical line, Pantry contribution, or downstream
fact. `NEED_GENERATION_REQUESTED` is only the persisted handoff marker that a
separately approved Need Generation command may later consume.

### R3B-P05 — Explicit invalidation command

One command permits only:

```text
READY -> INVALIDATED
NEED_GENERATION_REQUESTED -> INVALIDATED
```

`NOT_READY -> INVALIDATED` is rejected.

The closed invalidation reason taxonomy is:

| Reason code                         | Permitted current state                | Backend condition                                                                                                                                                    | Reason note                                |
| ----------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `UPSTREAM_SOURCE_CHANGED`           | `READY` or `NEED_GENERATION_REQUESTED` | At least one evaluation-bound Menu, Attendance, or Pantry approval is no longer the exact current approved source evidence                                           | Optional; null or nonblank normalized text |
| `PLANNING_REVIEW_CORRECTION`        | `READY` or `NEED_GENERATION_REQUESTED` | Accountable operator requests a new readiness decision while current source evidence may still be current                                                            | Mandatory nonblank normalized text         |
| `NEED_GENERATION_REQUEST_WITHDRAWN` | `NEED_GENERATION_REQUESTED` only       | No `atlas_planning.need_generation_runs` row exists for the exact `planning_input_set_id` and exact current `planning_input_evaluation_id`, regardless of run status | Mandatory nonblank normalized text         |

No `OTHER` reason exists. A reason code used outside its permitted state or
without its backend condition fails as `INVALIDATION_REASON_MISMATCH`.
Whitespace-only mandatory notes fail as `REASON_NOTE_REQUIRED`.

Any Need Generation run for the exact set and evaluation means the handoff was
consumed, including a run later invalidated or released. Withdrawal then fails
closed as `NEED_GENERATION_HANDOFF_ALREADY_CONSUMED`. The invalidation command
does not update, invalidate, supersede, or delete that run. Other invalidation
reasons remain available only under their independently defined conditions and
also create no Need Generation mutation.

The backend resolves the accountable Actor from the authenticated subject and
uses transaction time as authoritative occurrence time. The request timestamp
remains request evidence only.

The command retains the exact current evaluation and issues, changes only the
root status and update time, creates one durable receipt, emits one event and
one audit event, and returns authoritative readback. Exact replay is safe;
changed reuse, stale state, and stale current-evaluation expectations fail
closed.

### R3B-P06 — Closed function registry

The proposed public surface is closed to:

1. `atlas_api.get_planning_input_readiness_workbench(request jsonb)`;
2. `atlas_api.evaluate_planning_input_readiness(request jsonb)`;
3. `atlas_api.request_planning_input_need_generation(request jsonb)`; and
4. `atlas_api.invalidate_planning_input_readiness(request jsonb)`.

The selected design adds a dedicated readiness workbench read. It does not
extend `get_planning_inputs_workbench`.

The dedicated read is the only authoritative Planning Input Set readiness read.
The existing RMVP-03A `readiness` member remains a two-source source-workbench
comparison and must not compete with or authorize this lifecycle.

The complete function details exist only in the
[canonical RMVP-03B API registry](../api/rmvp-03b-planning-input-readiness.md).
No fifth function, preview function, generic transition function, per-source
readiness read, or competing authoritative readiness read is proposed.

### R3B-P07 — Capability and scope model

Reads reuse the existing capability:

```text
planning.inputs.read
```

All three commands use at most one new capability:

```text
planning.input_readiness.write
```

The capability controls evaluation, request, and invalidation as one bounded
Planning readiness-write authority. Lifecycle and reason rules continue to
limit what an authorized actor may do.

The proposal adds zero roles, runtime roles, scope kinds, or delegated-actor
models. All four functions require the existing active `GLOBAL` Planning
scope. The shaped read uses `atlas_read_runtime`; commands use
`atlas_planning_command_runtime`.

UI visibility and `allowed_actions` are not authorization. Every command
resolves the active Actor and repeats capability and scope checks.

### R3B-P08 — Command envelopes and concurrency

All commands use `RMVP-03B.v1` and exactly this common envelope:

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

The root has no aggregate version, so the contract does not invent one.
Concurrency uses the exact root status plus current evaluation ID/version.

For expected state `ABSENT`, both current-evaluation expectations must be null.
For every existing state, both must be present and exact. The receipt's
existing nullable `expected_version` stores
`expected_current_evaluation_version`; it remains null for first evaluation.

Evaluation payload is:

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

Request payload is:

```json
{
  "planning_input_set_id": "uuid",
  "period_start": "YYYY-MM-DD",
  "period_end": "YYYY-MM-DD"
}
```

The request command consumes expected root status `READY`, expected current
evaluation ID/version, and the exact immutable source triples stored on that
evaluation. It loads and revalidates those triples under lock; the browser
supplies no duplicate source-binding claim.

Invalidation payload is:

```json
{
  "planning_input_set_id": "uuid",
  "period_start": "YYYY-MM-DD",
  "period_end": "YYYY-MM-DD"
}
```

Evaluation has fixed `reason_code = READINESS_EVALUATION_REQUESTED` and null
`reason_note`. Request has fixed
`reason_code = NEED_GENERATION_HANDOFF_REQUESTED` and null `reason_note`.
Invalidation uses only the R3B-P05 reason taxonomy.

The authenticated JWT subject must equal `requested_by_auth_subject`. No
browser actor ID is accepted.

Stale root status, current evaluation, period/root identity, or source
candidate returns a non-retryable stale error and writes nothing; the operator
must refresh and create a new command intent. Only
`RETRYABLE_CONCURRENCY_FAILURE` is retryable with the exact immutable request.

Transport uncertainty is never success. The client must replay the exact
command identities or refresh authoritative state; it must not create a new
downstream intent on an unknown outcome.

Every success returns:

```text
success
contract_version
command_id
correlation_id
idempotency_status
affected_aggregate_ids
new_versions.current_evaluation_version
emitted_event_ids
audit_event_ids
safe_operator_message
warnings
blockers
authoritative_readback
```

### R3B-P09 — Events, receipts, and audit

Every accepted command creates or replays one shared
`atlas_core.command_receipts` record. The Planning Input Set does not duplicate
command ID, correlation ID, idempotency key, request hash, receipt status,
event envelope, audit envelope, reason, or actor history.

The exact proposed domain event names are:

| Event                                  | Aggregate          | Required payload summary                                                                                                                                          |
| -------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PlanningInputReadinessEvaluated`      | `PlanningInputSet` | Set ID, exact period, prior/next root status, evaluation ID/version/result, all present typed source triples, blocking/warning counts                             |
| `PlanningInputNeedGenerationRequested` | `PlanningInputSet` | Set ID, exact period, `READY -> NEED_GENERATION_REQUESTED`, retained evaluation ID/version, all three exact source triples derived from that immutable evaluation |
| `PlanningInputReadinessInvalidated`    | `PlanningInputSet` | Set ID, exact period, prior status, `INVALIDATED`, retained evaluation ID/version, invalidation reason code, backend-detected stale source types when applicable  |

`PlanningInputSet` has no aggregate version. Domain-event
`aggregate_version` and audit `aggregate_version_before/after` therefore remain
null rather than inventing a root version. Exact evaluation versions and
status changes are stored in safe payload/before/after summaries.

Each command writes one matching audit event in the same transaction with:

- source domain `PLANNING`;
- aggregate type and ID;
- command receipt, command, and correlation IDs;
- resolved actor;
- fixed or selected reason code and permitted reason note;
- exact safe before/after status, period, evaluation, source, and count
  evidence;
- source interface `atlas_api`; and
- transaction occurrence time.

The read model derives request and invalidation history from these shared
events/audits. No new history relation or duplicate root fields are proposed.

### R3B-P10 — Read model

`get_planning_input_readiness_workbench` is decision-first and returns:

1. exact period selector and resolution status;
2. exact root ID/status/created/updated evidence or explicit absence;
3. current evaluation ID/version/result, counts, evaluator, and evaluation
   time;
4. exact Menu, Attendance, and Pantry selected binding and candidate arrays;
5. source period, approval, current/stale, coverage, and ambiguity state;
6. positive-line Pantry evidence or explicit zero-line evidence;
7. blockers before warnings, with immutable issue IDs/codes/messages and typed
   context;
8. backend `allowed_actions`, action-specific disabled reasons, and permitted
   invalidation reason codes;
9. one bounded combined history of immutable evaluations and request and
   invalidation events;
10. exact history pagination metadata; and
11. explicit historical null-Pantry classification.

The top-level decision is one of:

```text
NOT_EVALUATED
NOT_READY
READY
NEED_GENERATION_REQUESTED
INVALIDATED
```

Each source selection state is one of:

```text
SELECTED
MISSING
AMBIGUOUS
STALE
```

Coverage is `COVERS`, `DOES_NOT_COVER`, or `NOT_APPLICABLE`. Pantry evidence
kind is `POSITIVE_LINES`, `EXPLICIT_ZERO_LINES`, or `MISSING`.

Source currency is calculated against current source roots and latest approval
pointers at read time. It does not rewrite historical evaluation evidence.

The optional read selector contains `history_limit` and `history_cursor`.
`history_limit` defaults to `25`, has minimum `1` and maximum `50`, and fails
validation outside that range. `history_cursor` is null for the first page or
an opaque backend-authored cursor from the preceding response.

```json
{
  "history_limit": 25,
  "history_cursor": "opaque backend cursor or null"
}
```

The response contains one `history_items` collection plus:

```json
{
  "history_next_cursor": "opaque cursor or null",
  "history_has_more": false
}
```

History uses the total backend-owned order
`(occurred_at DESC, history_kind_rank ASC, history_item_id DESC)`. Fixed kind
rank is Evaluation, Need Generation request, then invalidation. The first page
establishes a high-water tuple; the opaque cursor binds the exact period, that
high-water tuple, and the last returned tuple. This pages all three immutable
history kinds without duplicates, ambiguous cross-collection offsets, or
silent omission. Current root, current evaluation, current source evidence,
issues, decision, and `allowed_actions` are returned independently of
historical pagination.

`allowed_actions` contains only backend-derived:

```text
can_evaluate
can_request_need_generation
can_invalidate
invalidation_reason_codes
disabled_reasons
```

Visibility is not authorization. Commands independently revalidate all rules
under lock.

### R3B-P11 — Vietnamese operator UX

The connected UX adds one `Sẵn sàng đầu vào` tab to the existing `Nguồn kế
hoạch` workbench. It adds no navigation item or parallel application.

The tab must answer:

> **Có thể yêu cầu tạo nhu cầu cho giai đoạn này không?**

It contains:

- inclusive `Từ ngày` and `Đến ngày` selectors;
- a `Dùng cả tuần đang chọn` convenience;
- three cards named `Thực đơn tuần`, `Sĩ số`, and `Pantry`;
- automatic backend selection when exactly one candidate exists;
- backend-returned candidate selection only when a source has multiple
  candidates;
- current readiness status;
- blocker-first `Lỗi chặn`;
- separate `Cảnh báo không chặn` with no acknowledgement control;
- Evaluate, Request, and Invalidate actions;
- authoritative refresh and stale-state handling;
- a paginated `Lịch sử đánh giá` drawer/panel using the same read and opaque
  cursor for combined evaluation/request/invalidation history;
- explicit Pantry label
  `Đã xác nhận không có bổ sung Pantry — 0 dòng`; and
- explicit historical null-Pantry labeling.

Status labels are `Chưa đánh giá`, `Chưa sẵn sàng`, `Sẵn sàng`, `Đã yêu cầu
tạo nhu cầu`, and `Đã vô hiệu hóa`.

React disables lifecycle actions only from backend `allowed_actions`. Local
candidate choice or mandatory-note completeness may keep an action unavailable
until a refreshed backend response enables it, but React does not infer that
the lifecycle permits the action.

After success, React adopts only authoritative readback. A stale response
forces refresh. A retryable response preserves the exact request. A transport
error states that outcome is unknown.

React must not:

- calculate readiness;
- select `READY`/`NOT_READY`;
- author issue codes, severity, messages, or counts;
- infer source approval, currentness, coverage, or zero-additions evidence;
- repeat source triples in the Need Generation request; the backend derives
  them from the expected immutable evaluation;
- choose a hidden latest source;
- select a lifecycle transition;
- treat visibility as authorization; or
- claim that a Need Generation run or quantity was created.

Safe Vietnamese messages are bounded by the connected architecture and API
contract and must not expose internal database or security detail.

### R3B-P12 — Historical and downstream boundary

Historical evaluations created before PANTRY-RDY-02 remain immutable and may
have a null Pantry family. They remain queryable and visibly classified as
historical, but they cannot authorize a new Need Generation request.

`NOT_READY` may be re-evaluated directly. `INVALIDATED` may be re-evaluated
directly. `READY` and `NEED_GENERATION_REQUESTED` require explicit
invalidation before a successor evaluation.

No Weekly Menu, Attendance, or Pantry approval/reopen operation automatically
evaluates or invalidates readiness. No source-side readiness trigger is
authorized.

RMVP-03B creates no Pantry contribution, Recipe/BOM calculation, Need
Generation run, run input snapshot, theoretical line, Confirmed Need, Purchase
Handoff, Procurement, Warehouse, Dispatch, Wholesale, OPS v1/v2, Retool,
hosted Supabase, or production-data mutation.

The separate Pantry Need Generation amendment remains not started.

## Alternatives considered

| Subject          | Selected                                                 | Rejected                                          | Reason                                                                   |
| ---------------- | -------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------ |
| Period selector  | Exact inclusive start/end with week convenience          | Monday week as root authority                     | Preserves approved exact-period grain.                                   |
| Source selection | Exact backend-read triples with explicit ambiguity       | Silent server “latest” or browser-authored status | Makes evidence reviewable and stale-safe without transferring authority. |
| Read surface     | Dedicated readiness workbench                            | Extend RMVP-03A or create multiple reads          | Avoids competing authority and supports exact period plus history.       |
| Capability       | One readiness-write capability                           | Three action capabilities or new role             | Minimum bounded authorization delta; lifecycle remains backend enforced. |
| Root concurrency | Status plus current evaluation ID/version                | Invent root version                               | Persistence intentionally has no root version.                           |
| History          | Shared receipts/events/audits plus immutable evaluations | New relation or duplicated root fields            | Reuses established evidence and respects the zero-relation ceiling.      |
| Source change    | Explicit invalidation                                    | Automatic upstream triggers                       | Preserves domain ownership and historical evidence.                      |

## Future implementation ceiling

If all proposed decisions are approved, a later bounded implementation may
propose no more than:

- one migration;
- four `atlas_api` functions;
- one new capability;
- zero relations;
- zero views;
- zero roles or runtime roles;
- zero scope kinds;
- zero automatic source triggers;
- zero new readiness lifecycle states;
- reuse of existing Planning/read runtimes, receipts, events, audits, Actor
  resolution, and global scope; and
- one bounded integration into the existing Planning Inputs module.

This ceiling does not itself authorize any implementation.

## Decision and registration boundary

R3B-P01 through R3B-P12 remain proposed until the Product Owner explicitly
approves them. This decision:

- is not Accepted;
- does not add D-027;
- does not modify D-026;
- does not authorize an issue, migration, API, capability, grant, React
  change, hosted action, PR-ready state, or merge; and
- does not change the accepted PANTRY-RDY-01 or PANTRY-RDY-02 semantics.

The documentation-only rollback is a normal Git revert and has no schema,
data, deployment, or operational effect.
