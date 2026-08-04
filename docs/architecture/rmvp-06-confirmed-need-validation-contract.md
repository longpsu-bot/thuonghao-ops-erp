# RMVP-06 — Connected Confirmed Need Validation Contract

**Status:** Proposed architecture contract; documentation only; Product Owner and independent review required

**Contract version:** `RMVP-06.v1`

**Owning domain:** Planning

**Starting baseline:** `9ddc6030c85cc3c076ab74ee0bd1af4f123dcae7`

**Predecessor:** [RMVP-05 Connected Confirmed Need Review API Contract](../api/rmvp-05-connected-confirmed-need-review.md)

**Decision registry:** [Decision RMVP-06 — Confirmed Need Validation](../decisions/decision-rmvp-06-confirmed-need-validation.md)

**Implementation handoff:** [TASK-RMVP-06A — Confirmed Need Validation Contract](../implementation-tasks/TASK-RMVP-06A-confirmed-need-validation-contract.md)

## 1. Executive decision

RMVP-06 adds one complete-batch Planning validation command after every current Confirmed Need line has explicit RMVP-05 decision evidence.

```text
released Need Generation
→ CMD-15 Draft Confirmed Need
→ line review / quantity confirmation
→ complete-batch validation
→ later approval
→ later release
```

The exact proposed callable is:

```text
atlas_api.validate_confirmed_needs(request jsonb) returns jsonb
```

It uses contract `RMVP-06.v1`, capability `confirmed_need_validation.validate`, active `GLOBAL` scope, and the existing `atlas_confirmed_need_review_runtime`.

Validation answers one question:

> Is the entire current Confirmed Need batch internally complete, current, governed, reviewed, and eligible to be presented for approval?

Validation does not approve, release, create Purchase Handoff, assign suppliers, create purchase orders, mutate stock, or create Dispatch facts.

A governed blocked result is a completed business evaluation, not a technical command failure:

```text
valid command + authoritative evaluation + blockers
→ validation_status = BLOCKED
→ immutable attempt, line membership, issues, receipt, event and audit
→ batch remains DRAFT_REVIEW or REOPENED
→ batch version does not change
```

A successful validation is one atomic lifecycle transition:

```text
expected batch version N
→ locked complete-batch recheck
→ immutable successful attempt and exact line membership
→ batch status = VALIDATED
→ batch version = N + 1
→ batch points to the successful validation attempt
```

## 2. OPS_SYSTEM_MAP placement

| Layer | RMVP-06 placement |
| --- | --- |
| Mission | Release explainable, current and completely reviewed school-catering demand without allowing an incomplete batch to reach approval. |
| Business Capability | Validate the complete current Confirmed Need batch. |
| Business Domain | Planning. |
| Business Object | Existing `ConfirmedNeedBatch`, current stable lines, immutable line revisions, line decisions, source contributions, Planning policies, and append-only validation evidence. |
| Business Contract | Confirmed Need, PA-06E, H0B1, H1A, H1B1, CMD-15, RMVP-04, RMVP-05, and this contract. |
| Command/Event | `validate_confirmed_needs`; `ConfirmedNeedsValidated`; `ConfirmedNeedValidationFailed`. |
| Read Model | Existing Confirmed Need workbench extended with latest validation outcome and issues. |
| Application | Existing Vietnamese `Xác nhận nhu cầu` workbench; no separate validation application. |
| Technology | One JSONB RPC, one unbound capability, no new role, three private evidence relations, one batch pointer, forced RLS, revoke-first grants, immutable guards and focused pgTAP. |

## 3. Boundary

RMVP-06 applies only to:

```text
source_kind = NEED_GENERATION
batch_status in (DRAFT_REVIEW, REOPENED)
```

It does not change the direct-wholesale `PA-05D.v1` path.

RMVP-06 includes:

- exact request validation, actor resolution, capability and scope authorization;
- idempotent complete-batch evaluation;
- authoritative lock and reread;
- immutable validation-attempt evidence;
- one exact validation-line row for every current stable line;
- immutable blocking and warning issue evidence;
- the `VALIDATED` transition on success;
- authoritative readback through the existing RMVP-05 workbench;
- the minimum UI action and status presentation required to operate validation.

RMVP-06 excludes:

- approval and approval snapshot creation;
- release for Purchase Handoff;
- reopening or corrected rematerialization;
- CMD-03 and Purchase Handoff;
- Procurement, Warehouse and Dispatch;
- production capability bindings;
- hosted deployment, Retool changes, production data or policy seed.

Partial validation is not allowed.

## 4. Public API and authorization

### 4.1 Exact callable

Exactly one public function is proposed:

```text
atlas_api.validate_confirmed_needs(request jsonb) returns jsonb
```

The function is:

- `VOLATILE`;
- fixed empty `search_path`;
- `SECURITY DEFINER`;
- owned by `atlas_confirmed_need_review_runtime`;
- executable only by `authenticated`;
- not executable by `PUBLIC`, `anon`, or `service_role`;
- static SQL/PLpgSQL with no caller-authored identifiers or dynamic SQL.

A separate validation-preview API is rejected. Complete-batch validation is already an authoritative evaluation; a preview would duplicate the same read, lock-independent rules and issue result without adding a distinct business decision.

### 4.2 Capability and scope

The exact capability is:

```text
confirmed_need_validation.validate
```

RMVP-06B creates it as `PLANNING`, `ACTIVE`, and unbound.

Every call requires:

- exact JWT subject equality with `requested_by_auth_subject`;
- an active human Actor mapping;
- an active role membership with the exact capability;
- active `GLOBAL` scope;
- a `NEED_GENERATION` Confirmed Need batch.

No production role or actor binding is included.

### 4.3 Runtime decision

RMVP-06 reuses:

```text
atlas_confirmed_need_review_runtime
```

This is the smallest least-privilege boundary because validation operates on the same aggregate and workbench as RMVP-05 and does not cross into another domain. A second runtime would add role, catalog and operational cost without reducing a cross-domain privilege boundary.

Reuse does not authorize future approval or release. RMVP-06B grants only the additional validation-specific relation verbs and batch columns required by this command.

## 5. Command contract

### 5.1 Request

```json
{
  "contract_version": "RMVP-06.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "text",
  "expected_version": 7,
  "requested_by_auth_subject": "uuid",
  "requested_at": "timestamp with time zone",
  "reason_code": "BATCH_VALIDATION_REQUESTED",
  "reason_note": null,
  "payload": {
    "confirmed_need_batch_id": "uuid"
  }
}
```

Rules:

- the payload contains only `confirmed_need_batch_id`;
- `expected_version` is the exact current batch version;
- `reason_code` is exactly `BATCH_VALIDATION_REQUESTED`;
- `reason_note` is optional and bounded by the existing command-envelope convention;
- the same idempotency key plus the same canonical request replays the first outcome;
- the same idempotency key plus a different request returns conflict.

### 5.2 Successful response

```json
{
  "success": true,
  "contract_version": "RMVP-06.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_status": "COMPLETED",
  "validation_status": "VALIDATED",
  "confirmed_need_batch_id": "uuid",
  "prior_batch_status": "DRAFT_REVIEW",
  "new_batch_status": "VALIDATED",
  "prior_batch_version": 7,
  "new_batch_version": 8,
  "validation_attempt_id": "uuid",
  "validation_fingerprint": "sha256-hex",
  "line_count": 42,
  "blocking_issue_count": 0,
  "warning_count": 2,
  "receipt_id": "uuid",
  "event_id": "uuid",
  "audit_id": "uuid",
  "safe_operator_message": "Confirmed Need batch passed complete validation.",
  "authoritative_readback": {}
}
```

### 5.3 Completed blocked response

```json
{
  "success": true,
  "contract_version": "RMVP-06.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_status": "COMPLETED",
  "validation_status": "BLOCKED",
  "confirmed_need_batch_id": "uuid",
  "prior_batch_status": "DRAFT_REVIEW",
  "new_batch_status": "DRAFT_REVIEW",
  "prior_batch_version": 7,
  "new_batch_version": 7,
  "validation_attempt_id": "uuid",
  "validation_fingerprint": "sha256-hex",
  "line_count": 42,
  "blocking_issue_count": 3,
  "warning_count": 1,
  "issues": [],
  "receipt_id": "uuid",
  "event_id": "uuid",
  "audit_id": "uuid",
  "safe_operator_message": "Confirmed Need batch still has issues that must be resolved.",
  "authoritative_readback": {}
}
```

`BLOCKED` is not `success: false`. The database executed the requested evaluation and committed its governed result.

### 5.4 Command failures

These produce `success: false` and no validation-attempt business evidence:

- malformed or noncanonical request;
- missing or mismatched actor subject;
- insufficient capability or scope;
- batch not found;
- unsupported source kind;
- batch not in `DRAFT_REVIEW` or `REOPENED`;
- stale expected version;
- idempotency conflict;
- internal command failure.

Safe responses must not expose SQL, private schemas, policy internals or confidential rows.

## 6. Validation evidence model

RMVP-06B adds exactly three private Planning relations and one nullable batch pointer.

### 6.1 `confirmed_need_validation_attempts`

One append-only row per completed validation evaluation.

Minimum authoritative attributes:

- validation attempt ID;
- Confirmed Need batch ID;
- attempt number unique within the batch;
- source kind;
- evaluated batch version;
- resulting batch version;
- prior and resulting batch status;
- outcome `VALIDATED` or `BLOCKED`;
- exact line count;
- blocking and warning counts;
- validation fingerprint;
- validating Actor;
- evaluated timestamp;
- command ID and correlation ID;
- reason code and note.

A `VALIDATED` attempt requires:

```text
resulting_batch_version = evaluated_batch_version + 1
```

A `BLOCKED` attempt requires:

```text
resulting_batch_version = evaluated_batch_version
```

### 6.2 `confirmed_need_validation_lines`

One immutable membership row for every current stable line in every completed attempt.

Minimum authoritative bindings:

- validation attempt ID and validation-line ID;
- Confirmed Need batch ID and stable line ID;
- exact current line revision ID;
- exact current line decision ID;
- exact Planning policy revision ID;
- exact controlled Unit ID;
- exact Need Generation run/version/release snapshot;
- theoretical quantity and confirmed quantity;
- Planning tick count;
- source-membership count and exact total.

The relation does not duplicate contribution rows. Exact contribution membership remains revision-owned and immutable; the validation line binds the exact revision whose membership is already relationally protected.

### 6.3 `confirmed_need_validation_issues`

One immutable governed issue row per attempt and affected line or batch.

Minimum attributes:

- validation issue ID;
- validation attempt ID;
- validation-line ID when line-specific;
- batch ID and stable line ID when line-specific;
- severity `BLOCKING` or `WARNING`;
- stable issue code;
- safe operator message;
- deterministic sort order.

There is no mutable global issue row. A later attempt records a new issue set and preserves the old result.

### 6.4 Batch pointer

Add:

```text
confirmed_need_batches.current_confirmed_need_validation_attempt_id
```

On successful validation it identifies the exact `VALIDATED` attempt whose resulting version equals the current batch version.

Blocked attempts never become the current validated pointer. The read model obtains the latest attempt separately by batch and attempt number.

### 6.5 Fingerprint

A deterministic SHA-256 fingerprint supplements, but never replaces, the relational line membership. Its canonical input includes ordered validation-line bindings and attempt-level source/batch identity. Approval may use it as a stale-evidence comparison, but must still verify the relational membership and current pointer.

## 7. Validation rules

### 7.1 Command preconditions

The following are command failures, not persisted validation issues:

- batch not found;
- source kind is not `NEED_GENERATION`;
- status is not `DRAFT_REVIEW` or `REOPENED`;
- expected batch version is stale;
- request, actor, capability or scope is invalid.

### 7.2 Persisted blocking issue codes

| Code | Meaning |
| --- | --- |
| `NO_CURRENT_LINES` | The batch has no current stable lines. |
| `CURRENT_LINE_SET_INVALID` | Current-line uniqueness or complete membership is invalid. |
| `CURRENT_REVISION_MISSING` | A stable line has no exact current revision. |
| `CURRENT_DECISION_MISSING` | A current line has no explicit Planning decision. |
| `DECISION_REVISION_MISMATCH` | The current decision does not bind the exact current revision and stable line. |
| `SOURCE_RELEASE_NOT_CURRENT` | The bound Need Generation run/release is missing, invalidated, unreleased or no longer the current source. |
| `CONTRIBUTION_MEMBERSHIP_INVALID` | Revision-owned source membership is empty, duplicated, incomplete or includes an ineligible source member. |
| `THEORETICAL_TOTAL_MISMATCH` | Contribution total does not equal the immutable revision theoretical quantity. |
| `CONTROLLED_UNIT_INACTIVE` | The controlled Unit is not active at validation. |
| `PLANNING_POLICY_NOT_ELIGIBLE` | The decision-bound policy revision is missing, ambiguous, ineffective or not historically eligible. |
| `DECISION_POLICY_MISMATCH` | The committed decision does not bind the exact eligible policy revision and Planning step. |
| `CONFIRMED_QUANTITY_INVALID` | Confirmed quantity is negative, nonfinite or not exactly representable by the committed Planning step. |
| `ADJUSTMENT_REASON_INCOMPLETE` | An adjusted decision lacks its required reason evidence. |
| `SOURCE_BLOCKER_PRESENT` | The exact released upstream evidence contains or has acquired a governed blocking condition. |
| `CURRENT_FACTS_CHANGED` | A mutable critical fact changed between preliminary evaluation and the locked authoritative reread. |

A decision's historical `confirmed_need_batch_version` is not required to equal the latest batch version. Different lines may have been confirmed by separate commands. Currency is determined by the exact current line pointer, revision, decision, source and policy bindings.

### 7.3 Warning issue codes

| Code | Meaning |
| --- | --- |
| `ZERO_CONFIRMED_QUANTITY` | A completely reviewed line has an exact confirmed quantity of zero. |
| `UPSTREAM_WARNING_RETAINED` | The exact released source contains a governed nonblocking warning relevant to the line or batch. |

A large-variance warning is deferred. No production threshold is approved, so RMVP-06B must not invent one.

Warnings never block validation.

## 8. Locking and concurrency

After request validation, authorization and idempotency admission, the command uses this deterministic order:

```text
1. Confirmed Need batch — FOR UPDATE
2. current stable lines ordered by confirmed_need_line_id — FOR UPDATE
3. controlled Units ordered by unit_id — FOR SHARE
4. Planning policy roots ordered by policy root ID — FOR SHARE
5. Planning policy revisions ordered by revision ID — FOR SHARE
6. source Need Generation run — FOR SHARE
7. source release snapshot and release members ordered by ID — FOR SHARE
8. canonical reread of current revisions, decisions and contribution memberships
```

The order extends the RMVP-05 lock boundary rather than introducing another convention. Immutable line decisions and contribution rows do not require mutation locks; their mutable owning pointers and source ancestors are locked first.

After all locks, the command reruns every critical rule before the first business write. `SERIALIZABLE` isolation is not required for this first slice.

## 9. Versioning and lifecycle

### Successful validation

```text
DRAFT_REVIEW or REOPENED at version N
→ append attempt / exact lines / warnings
→ set current validation attempt pointer
→ set status VALIDATED
→ set version N + 1
→ emit event and audit
```

No line, revision, decision, contribution, source or policy payload changes.

### Blocked validation

```text
DRAFT_REVIEW or REOPENED at version N
→ append attempt / exact lines / blockers / warnings
→ status unchanged
→ version unchanged
→ current validated pointer unchanged
→ emit failed-validation event and audit
```

### Later invalidation

RMVP-06B does not implement reopen or rematerialization. Later work must clear the current validation pointer and advance the batch version before changing a validated line set. Prior validation attempts remain immutable. Approval must reject unless the current batch version, current line set and current validation pointer exactly match the successful validation evidence.

## 10. Idempotency

The existing command-receipt model is reused.

- Same key and canonical request: return the original validated or blocked response.
- Same key and different canonical request: `IDEMPOTENCY_CONFLICT`.
- Replay creates no additional attempt, line, issue, receipt, event, audit or version increment.
- Replay remains valid after the aggregate later advances and returns the original outcome.
- A new validation attempt requires a new command ID and idempotency key.

## 11. Events and audit

### `ConfirmedNeedsValidated`

Minimum evidence:

- batch ID and `NEED_GENERATION` source kind;
- prior/resulting status and versions;
- validation attempt ID and fingerprint;
- line count, blocker count `0`, and warning count;
- bounded ordered stable-line IDs;
- actor, command, correlation, reason and timestamp.

### `ConfirmedNeedValidationFailed`

This event means a completed evaluation found blockers. It is not a technical exception.

Minimum evidence:

- batch ID and source kind;
- unchanged status/version;
- validation attempt ID and fingerprint;
- line, blocker and warning counts;
- ordered stable issue codes;
- bounded affected stable-line IDs;
- actor, command, correlation, reason and timestamp.

The audit event contains the same business summary plus safe request/outcome evidence. It does not copy private row payloads.

## 12. Read model and application behavior

RMVP-06 extends the existing `get_confirmed_need_review` workbench. It does not add a separate read API or screen.

Add to the shaped batch result:

- latest validation attempt ID, number and outcome;
- evaluated and resulting versions;
- validated by/at when successful;
- validation fingerprint;
- blocking and warning counts;
- grouped latest issue list and line-specific issue markers;
- `validation_allowed` and exact disabled reason;
- `editing_allowed`;
- authoritative lifecycle status.

Vietnamese UI vocabulary:

| Meaning | Label |
| --- | --- |
| Validate action | `Kiểm tra toàn bộ` |
| Successful validation | `Đã kiểm tra` |
| Blocked validation | `Chưa đạt điều kiện kiểm tra` |
| Blocking issues | `Vấn đề cần xử lý` |
| Warnings | `Cảnh báo` |
| Successful read-only banner | `Đã kiểm tra; chờ phê duyệt` |

After successful validation:

- quantity editing, preview and confirmation are disabled;
- the workbench refreshes from authoritative readback;
- no approval or release button is shown until RMVP-07;
- the UI must not imply that validation is approval or release.

A blocked attempt leaves editing available and displays blockers before warnings. Late validation responses must not overwrite a newer batch load or operator intent.

## 13. Security and Supabase implications

RMVP-06B preserves Atlas's private-schema model:

- browser roles receive no direct private-table grants;
- `authenticated` receives only execute on the shaped API;
- the runtime receives explicit grants and RLS policies for only required verbs;
- all new private relations have RLS enabled and forced;
- `PUBLIC`, `anon`, `authenticated`, and `service_role` receive no direct relation privileges;
- every security-definer function has fixed empty `search_path`;
- no role uses `BYPASSRLS`;
- no dynamic SQL uses caller-authored identifiers.

Current Supabase Data API grant defaults do not alter this private-schema design. RMVP-06B must use explicit function execute grants and must not depend on automatic table exposure. It must not add a schema to the exposed Data API configuration or drop an exposed schema.

Local CI retains bounded handling only for the already reviewed `PGRST002` schema-cache readiness condition; RMVP-06 does not broaden retry behavior.

## 14. Direct-wholesale compatibility

RMVP-06 makes no change to:

- `PA-05D.v1`;
- direct-wholesale pass-through equality;
- wholesale Confirmed Need creation, approval snapshots or release behavior;
- the existing Planning command runtime;
- direct-wholesale Purchase Handoff creation;
- downstream supplier-direct acceptance.

Focused tests must prove the direct-wholesale catalog and behavior remain unchanged.

## 15. RMVP-06B implementation boundary

### Backend

- one migration;
- one public API function;
- one capability;
- zero new database roles;
- three private validation relations;
- one nullable batch pointer;
- required helpers, constraints, indexes and immutable/deferred guards;
- minimum explicit grants and forced-RLS policies;
- existing receipt/event/audit reuse;
- existing RMVP-05 workbench read extension;
- one focused registered pgTAP suite.

### Frontend

- extend Confirmed Need types and API wrapper;
- add the `Kiểm tra toàn bộ` action;
- display latest blocked/validated result and issues;
- enforce read-only state after validation;
- preserve exact decimal-string behavior;
- add focused component/API tests;
- extend the local browser-key acceptance journey.

### CI

Draft smoke:

```text
platform catalog
+ RMVP-06 focused pgTAP
+ deterministic identity/fixture
+ short review → confirm → validate journey
```

Ready-for-review Full Integration:

```text
all registered suites
+ full upstream RMVP-04 → CMD-15 → RMVP-05 → RMVP-06 journey
```

No approval, release, CMD-03 or downstream journey is added.

## 16. Acceptance blueprint

RMVP-06B must prove at minimum:

- exact one-function surface and one unbound capability;
- runtime reuse without role creation or cross-domain privilege;
- browser roles have no private-table access;
- complete valid batch transitions exactly once to `VALIDATED`;
- batch version increments once;
- line/revision/decision quantities do not mutate;
- immutable attempt and exact line membership;
- missing or stale line decision blocks;
- inactive Unit blocks;
- missing, ambiguous or ineligible policy blocks;
- stale source release blocks;
- incomplete contribution membership blocks;
- blocked outcome persists exact issue/event/audit evidence and leaves version/status unchanged;
- warnings do not block;
- success and blocked replay;
- idempotency conflict and stale expected version;
- concurrent critical-fact change fails closed;
- direct-wholesale compatibility;
- zero Purchase Handoff, Procurement, Warehouse or Dispatch writes;
- allowed/disabled UI action, grouped issues and success readback;
- stale async validation result rejection;
- no approval/release action;
- Vietnamese labels and exact decimal strings.

The implementation derives its exact pgTAP plan from the implemented assertion count. This architecture document does not freeze a plan number.
