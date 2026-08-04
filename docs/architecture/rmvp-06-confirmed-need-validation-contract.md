# RMVP-06 — Connected Confirmed Need Validation Contract

**Status:** Accepted architecture contract

**Approved:** 2026-08-04

**Contract version:** `RMVP-06.v1`

**Owning domain:** Planning

**Approved baseline:** `9ddc6030c85cc3c076ab74ee0bd1af4f123dcae7`

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

The accepted callable is:

```text
atlas_api.validate_confirmed_needs(request jsonb) returns jsonb
```

It uses:

```text
contract: RMVP-06.v1
capability: confirmed_need_validation.validate
runtime: atlas_confirmed_need_review_runtime
scope: active GLOBAL
source family: NEED_GENERATION only
```

Validation answers:

> Is the entire current Confirmed Need batch complete, current, governed, reviewed, and eligible to be presented for approval?

Validation does not approve, release, create Purchase Handoff, assign suppliers, create purchase orders, mutate stock, or create Dispatch facts.

A governed blocked result is a completed business evaluation, not a technical command failure:

```text
valid command + authoritative evaluation + blockers
→ validation_status = BLOCKED
→ immutable attempt, observations, issues, receipt, event and audit
→ batch remains DRAFT_REVIEW or REOPENED
→ batch version does not change
```

A successful validation is one atomic lifecycle transition:

```text
expected batch version N
→ locked complete-batch recheck
→ immutable successful attempt and exact complete membership
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
| Technology | One JSONB RPC, one unbound capability, no new role, three private evidence relations, one batch pointer, forced RLS, revoke-first grants, immutable guards, and focused pgTAP. |

## 3. Scope boundary

RMVP-06 applies only to:

```text
source_kind = NEED_GENERATION
batch_status in (DRAFT_REVIEW, REOPENED)
```

It includes:

- request validation and actor authorization;
- exact idempotency and replay;
- deterministic locks and authoritative reread;
- complete-batch evaluation;
- immutable validation attempts;
- one observation row for every current stable line;
- immutable blocking and warning issues;
- the `VALIDATED` transition on success;
- authoritative readback through the existing RMVP-05 workbench;
- the minimum Vietnamese UI action and status presentation.

It excludes:

- approval and approval-snapshot creation;
- release for Purchase Handoff;
- reopening and corrected rematerialization;
- CMD-03 and Purchase Handoff;
- Procurement, Warehouse, and Dispatch;
- production capability bindings;
- hosted deployment, Retool changes, production data, and production policy seed.

Partial validation is not allowed. The PA-05D direct-wholesale path remains unchanged.

## 4. Public API and authorization

Exactly one public function is authorized for RMVP-06B:

```text
atlas_api.validate_confirmed_needs(request jsonb) returns jsonb
```

The implementation must be:

- `VOLATILE`;
- fixed empty `search_path`;
- `SECURITY DEFINER`;
- owned by `atlas_confirmed_need_review_runtime`;
- executable only by `authenticated`;
- revoked from `PUBLIC`, `anon`, and `service_role`;
- static SQL/PLpgSQL with no caller-authored identifiers or dynamic SQL.

A separate validation-preview API is rejected. Complete-batch validation is already the authoritative evaluation and has no separate operator decision to preview.

The exact capability is:

```text
confirmed_need_validation.validate
```

RMVP-06B creates it as `PLANNING`, `ACTIVE`, and unbound. Every call requires:

- exact JWT subject equality with `requested_by_auth_subject`;
- an active human Actor mapping;
- an active role membership with the exact capability;
- active `GLOBAL` scope;
- a `NEED_GENERATION` Confirmed Need batch.

No production role or Actor receives the capability in RMVP-06B.

The existing `atlas_confirmed_need_review_runtime` is reused because validation operates on the same aggregate and workbench as RMVP-05. This reuse does not authorize future approval or release.

## 5. Command envelope and outcomes

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

The payload contains only `confirmed_need_batch_id`. `expected_version` must equal the current batch version. The reason code is exactly `BATCH_VALIDATION_REQUESTED`.

### 5.2 Validated outcome

```text
success = true
validation_status = VALIDATED
prior version = N
new version = N + 1
prior status = DRAFT_REVIEW or REOPENED
new status = VALIDATED
blocking count = 0
```

The command commits:

- one validation attempt;
- one complete validation-line membership set;
- zero or more warnings;
- the current successful-validation pointer;
- the batch status/version transition;
- one receipt, domain event, and audit event;
- authoritative workbench readback.

### 5.3 Blocked outcome

```text
success = true
validation_status = BLOCKED
prior version = N
new version = N
status unchanged
blocking count > 0
```

The command commits:

- one validation attempt;
- one observation row for every current stable line;
- blockers and warnings;
- one receipt, `ConfirmedNeedValidationFailed` event, and audit event;
- authoritative workbench readback.

It does not set the current successful-validation pointer or change the batch status/version.

### 5.4 Command failure

Malformed requests, authorization failure, unsupported source kind, invalid lifecycle state, stale expected version, idempotency conflict, and internal execution failure return `success: false` and create no validation-attempt business evidence.

## 6. Validation evidence model

RMVP-06B adds exactly:

```text
atlas_planning.confirmed_need_validation_attempts
atlas_planning.confirmed_need_validation_lines
atlas_planning.confirmed_need_validation_issues
confirmed_need_batches.current_confirmed_need_validation_attempt_id
```

No generic validation engine, workflow aggregate, polymorphic reference, or JSON-only lineage substitute is authorized.

### 6.1 Validation attempts

One append-only row represents each completed `VALIDATED` or `BLOCKED` evaluation.

Minimum attributes:

- validation-attempt ID and batch ID;
- attempt number unique within the batch;
- source kind;
- evaluated and resulting batch versions;
- prior and resulting statuses;
- outcome;
- line, blocker, and warning counts;
- deterministic validation fingerprint;
- validating Actor and timestamp;
- command, correlation, reason code, and reason note.

Outcome constraints:

```text
VALIDATED → resulting version = evaluated version + 1
BLOCKED   → resulting version = evaluated version
```

### 6.2 Validation-line observations

Every completed attempt has exactly one observation row for every current stable line evaluated by the command.

Every observation always binds:

- validation attempt and validation-line IDs;
- batch and stable-line IDs;
- controlled Unit ID;
- observed current-revision count;
- observed current-decision count;
- observed eligible-policy count;
- observed source-membership count;
- deterministic line sort position.

The following observed bindings are nullable because a blocked evaluation must be able to prove that they were missing or ambiguous:

- current line-revision ID;
- current line-decision ID;
- Planning policy root/revision ID;
- Need Generation run/version/release-snapshot ID;
- theoretical quantity;
- confirmed quantity;
- Planning tick count;
- exact source-membership total.

Nullable observation fields are evidence of what the validator found; they are not authorization to omit required business facts from a successful validation.

Outcome-dependent constraints are mandatory:

```text
BLOCKED
→ nullable bindings are permitted
→ counts and issue rows explain missing, duplicate, ambiguous, or invalid facts

VALIDATED
→ current revision count = 1
→ current decision count = 1
→ eligible policy count = 1
→ every revision, decision, policy, Unit, source-release, quantity, tick, and membership binding is non-null
→ exact contribution membership is nonempty and complete
→ theoretical and confirmed quantities are nonnegative and policy-representable
```

A validated attempt must fail closed if its complete non-null binding set cannot be inserted under relational constraints.

The relation does not duplicate atomic contribution rows. It binds the exact current revision whose contribution membership remains revision-owned and immutable.

### 6.3 Validation issues

One immutable issue row belongs to one validation attempt and optionally one validation-line observation.

Minimum attributes:

- issue ID and attempt ID;
- validation-line ID for line-specific issues;
- batch and stable-line IDs when applicable;
- severity `BLOCKING` or `WARNING`;
- stable issue code;
- safe operator message;
- deterministic sort order.

A later attempt creates a new issue set; prior attempts and issues remain immutable.

### 6.4 Current successful-validation pointer

`confirmed_need_batches.current_confirmed_need_validation_attempt_id` points only to a `VALIDATED` attempt whose resulting version equals the current batch version. Blocked attempts never become the current validated pointer.

### 6.5 Fingerprint

A deterministic SHA-256 fingerprint supplements relational membership. It never replaces the exact validation-line observations, FKs, counts, and outcome constraints.

## 7. Canonical rule registry

### 7.1 Command failures

These are not persisted validation issues:

- batch not found;
- unsupported source kind;
- unsupported lifecycle state;
- stale expected version;
- invalid request, Actor, capability, or scope;
- idempotency conflict;
- internal failure.

### 7.2 Blocking issue codes

| Code | Meaning |
| --- | --- |
| `NO_CURRENT_LINES` | The batch has no current stable lines. |
| `CURRENT_LINE_SET_INVALID` | Current-line uniqueness or complete membership is invalid. |
| `CURRENT_REVISION_MISSING` | A stable line has no exact current revision. |
| `CURRENT_REVISION_AMBIGUOUS` | A stable line resolves more than one current revision. |
| `CURRENT_DECISION_MISSING` | A current line has no explicit Planning decision. |
| `CURRENT_DECISION_AMBIGUOUS` | A current line resolves more than one current decision. |
| `DECISION_REVISION_MISMATCH` | The current decision does not bind the exact current revision and stable line. |
| `SOURCE_RELEASE_NOT_CURRENT` | The bound Need Generation run/release is missing, invalidated, unreleased, or no longer current. |
| `CONTRIBUTION_MEMBERSHIP_INVALID` | Revision-owned membership is empty, duplicated, incomplete, or contains an ineligible source member. |
| `THEORETICAL_TOTAL_MISMATCH` | Contribution total does not equal the immutable revision theoretical quantity. |
| `CONTROLLED_UNIT_INACTIVE` | The controlled Unit is not active at validation. |
| `PLANNING_POLICY_MISSING` | No eligible policy revision exists. |
| `PLANNING_POLICY_AMBIGUOUS` | More than one eligible policy revision exists. |
| `PLANNING_POLICY_NOT_ELIGIBLE` | The decision-bound policy revision is ineffective or not historically eligible. |
| `DECISION_POLICY_MISMATCH` | The committed decision does not bind the exact eligible policy revision and Planning step. |
| `CONFIRMED_QUANTITY_INVALID` | Confirmed quantity is negative, nonfinite, or not exactly representable by the committed Planning step. |
| `ADJUSTMENT_REASON_INCOMPLETE` | An adjusted decision lacks required reason evidence. |
| `SOURCE_BLOCKER_PRESENT` | The exact released upstream evidence has a governed blocker. |
| `CURRENT_FACTS_CHANGED` | A mutable critical fact changed before the authoritative reread completed. |

A historical decision's recorded batch version need not equal the latest batch version. Currency is determined by exact current pointers and revision, decision, source, Unit, and policy bindings.

### 7.3 Warning codes

| Code | Meaning |
| --- | --- |
| `ZERO_CONFIRMED_QUANTITY` | A completely reviewed line has an exact confirmed quantity of zero. |
| `UPSTREAM_WARNING_RETAINED` | The exact released source contains a governed nonblocking warning relevant to the batch or line. |

No production large-variance threshold is authorized. Warnings do not block validation.

## 8. Locking and concurrency

After request validation, authorization, and idempotency admission, use this deterministic order:

```text
1. Confirmed Need batch — FOR UPDATE
2. stable lines ordered by confirmed_need_line_id — FOR UPDATE
3. controlled Units ordered by unit_id — FOR SHARE
4. Planning policy roots ordered by ID — FOR SHARE
5. Planning policy revisions ordered by ID — FOR SHARE
6. Need Generation run — FOR SHARE
7. release snapshot and release members ordered by ID — FOR SHARE
8. authoritative reread of current revisions, decisions, and contributions
```

The command reruns every critical rule after locks and before the first business write. `SERIALIZABLE` isolation and a generic lock framework are not required.

## 9. Idempotency, events, and audit

The existing command-receipt convention is reused.

- Same key and canonical request returns the original `VALIDATED` or `BLOCKED` response.
- Same key and a different request returns `IDEMPOTENCY_CONFLICT`.
- Replay creates no additional attempt, observation, issue, receipt, event, audit, or version increment.
- Replay remains the original historical result even if the aggregate later advances.

Events:

```text
ConfirmedNeedsValidated
ConfirmedNeedValidationFailed
```

`ConfirmedNeedValidationFailed` means a completed evaluation found blockers. It is not a technical-exception event.

Event/audit evidence includes the batch, prior/resulting lifecycle, versions, attempt ID, fingerprint, line/blocker/warning counts, bounded affected line IDs or issue codes, Actor, command, correlation, reason, and timestamp. It must not copy confidential private-row payloads.

## 10. Read model and UI

Extend `get_confirmed_need_review`; do not create a separate read API or screen.

Add:

- latest validation attempt, number, and outcome;
- evaluated and resulting versions;
- validated by/at when successful;
- fingerprint and issue counts;
- grouped latest issues and line markers;
- `validation_allowed` and exact disabled reason;
- `editing_allowed`;
- authoritative lifecycle status.

Vietnamese vocabulary:

| Meaning | Label |
| --- | --- |
| Validate action | `Kiểm tra toàn bộ` |
| Successful validation | `Đã kiểm tra` |
| Blocked validation | `Chưa đạt điều kiện kiểm tra` |
| Blocking issues | `Vấn đề cần xử lý` |
| Warnings | `Cảnh báo` |
| Successful read-only banner | `Đã kiểm tra; chờ phê duyệt` |

After successful validation, quantity editing, preview, and confirmation are disabled. Approval and release controls remain absent until RMVP-07. A blocked attempt leaves editing available. Late validation responses must not overwrite a newer load or operator intent.

## 11. Security and Supabase boundary

- Browser roles receive no direct private-relation grants.
- `authenticated` receives execute only on the shaped API.
- The runtime receives the minimum explicit verbs and RLS policies.
- New private relations have RLS enabled and forced.
- `PUBLIC`, `anon`, `authenticated`, and `service_role` receive no direct relation privileges.
- Every security-definer function has a fixed empty search path.
- No role uses `BYPASSRLS`.
- No dynamic SQL uses caller-authored identifiers.
- No exposed-schema or Data API configuration change is authorized.
- Existing bounded `PGRST002` schema-readiness handling is not broadened.

## 12. Direct-wholesale compatibility

RMVP-06 changes none of:

- `PA-05D.v1`;
- direct-wholesale pass-through equality;
- wholesale Confirmed Need creation, approval snapshots, or release;
- the existing Planning command runtime;
- direct-wholesale Purchase Handoff creation;
- downstream supplier-direct acceptance.

Focused compatibility assertions are mandatory.

## 13. RMVP-06B implementation boundary

RMVP-06B is authorized after this accepted contract merges. It may add:

- one migration;
- one public API function;
- one capability;
- zero new roles;
- three private validation relations;
- one nullable batch pointer;
- bounded helpers, constraints, indexes, immutable/deferred guards, grants, and RLS policies;
- existing receipt/event/audit reuse;
- RMVP-05 workbench extension;
- one focused registered pgTAP suite;
- focused frontend/API tests;
- one deterministic browser fixture and verifier;
- bounded CI path updates.

Draft smoke remains:

```text
platform security catalog
+ RMVP-06 focused pgTAP
+ deterministic identity/fixture
+ short review → confirm → validate journey
```

Full Integration remains the ready-for-review merge gate:

```text
all registered suites
+ RMVP-04 → CMD-15 → RMVP-05 → RMVP-06 journey
```

RMVP-06B must prove both blocked observations with nullable incomplete bindings and successful validation with complete non-null exact bindings.

It must not implement approval, release, reopen, corrected rematerialization, CMD-03, Purchase Handoff, Procurement, Warehouse, Dispatch, production policy thresholds, production capability binding, hosted Supabase changes, Retool changes, or deployment.
