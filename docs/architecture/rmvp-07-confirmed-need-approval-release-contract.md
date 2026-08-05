# RMVP-07 — Confirmed Need Approval and Release Contract

**Status:** Accepted architecture contract; documentation only

**Accepted baseline:** `c4d7970399f6b1c147700925f03e84efdafb0747`

**Product and architecture authorization:** 05/08/2026

**Contract version:** `RMVP-07.v1`

**Owning domain:** Planning

**Business capability:** approve one exact validated Confirmed Need batch and release one exact approval snapshot for Purchase Handoff

**Related authority:**

- [Planning Domain Confirmed Need Contract](planning-domain-confirmed-need-contract.md)
- [RMVP-06 Confirmed Need Validation Contract](rmvp-06-confirmed-need-validation-contract.md)
- [PA-06E Confirmed Need Review, Adjustment, Revision, and Source-Correction Contract](pa-06e-confirmed-need-review-adjustment-revision-contract.md)
- [Planning Domain Purchase Handoff Contract](planning-domain-purchase-handoff-contract.md)
- [Decision RMVP-07 — Confirmed Need Approval and Release](../decisions/decision-rmvp-07-confirmed-need-approval-release.md)
- [TASK-RMVP-07A — Confirmed Need Approval and Release Contract](../implementation-tasks/TASK-RMVP-07A-confirmed-need-approval-release-contract.md)

## 1. Executive decision

Atlas keeps the existing Planning lifecycle and makes the next two transitions explicit and independent:

```text
DRAFT_REVIEW | REOPENED
→ RMVP-06 complete-batch validation
→ VALIDATED
→ RMVP-07 approval of that exact validated batch
→ APPROVED
→ RMVP-07 release of that exact approval snapshot
→ RELEASED_FOR_PURCHASE_HANDOFF
→ separately authorized CMD-03 / Purchase Handoff
```

RMVP-07 does not merge approval and release, does not create Purchase Handoff, and does not assign a supplier or create a purchase order.

Approval answers:

> Does Planning accept the exact complete batch that passed validation?

Release answers:

> Is that exact immutable approval authorized to become the sole eligible Planning source for Purchase Handoff?

The two commands use separate capabilities. Production role bindings remain separately unauthorized. Atlas does not impose a mandatory different-person or four-eyes rule in this contract; a small operating team may bind both capabilities to one Actor, while every action remains separately authorized and audited.

RMVP-06's `validation_fingerprint` remains the immutable fingerprint of the validation attempt, including the attempt's evaluated batch version and prior lifecycle status. RMVP-07 never describes or uses that value as a post-transition recomputable fingerprint. Approval and release instead use the separate lifecycle-neutral validated-fact projection defined in section 4.1.

## 2. OPS_SYSTEM_MAP placement

| Layer               | RMVP-07 placement                                                                                                                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mission             | Convert reviewed and validated demand into an explainable, immutable Planning commitment without silently creating Procurement facts.                                                                                                       |
| Business capability | Approve a complete validated Confirmed Need batch; release one exact approval for Purchase Handoff.                                                                                                                                         |
| Business domain     | Planning owns both transitions. Procurement remains downstream and unchanged.                                                                                                                                                               |
| Business object     | Existing `ConfirmedNeedBatch`, current line revisions and decisions, immutable validation attempt, lifecycle-neutral validated-fact projection, approval snapshot and snapshot lines; one future append-only Confirmed Need release record. |
| Business contract   | `RMVP-07.v1`, the Confirmed Need parent contract, RMVP-05 review, RMVP-06 validation, PA-06E correction rules, and Purchase Handoff.                                                                                                        |
| Command/event       | `ApproveConfirmedNeeds` / `ConfirmedNeedsApproved`; `ReleaseConfirmedNeedsForPurchaseHandoff` / `ConfirmedNeedsReleasedForPurchaseHandoff`.                                                                                                 |
| Read model          | Additive approval/release state and evidence in the existing Confirmed Need workbench.                                                                                                                                                      |
| Application         | Existing Vietnamese `Xác nhận nhu cầu` Planning Inputs tab; no separate approval application.                                                                                                                                               |
| Technology          | Future PostgreSQL commands own authorization, locking, fingerprint checks, snapshots, release evidence, versions, receipts, events, audit and readback.                                                                                     |

## 3. Accepted API and capability registry

RMVP-07 adds exactly two future public functions:

| Function                                                                              | Capability                        | Authoritative aggregate | Purpose                                                                            |
| ------------------------------------------------------------------------------------- | --------------------------------- | ----------------------- | ---------------------------------------------------------------------------------- |
| `atlas_api.approve_confirmed_needs(request jsonb) returns jsonb`                      | `confirmed_need_approval.approve` | `ConfirmedNeedBatch`    | Approve one exact `VALIDATED` batch and create one immutable approval snapshot.    |
| `atlas_api.release_confirmed_needs_for_purchase_handoff(request jsonb) returns jsonb` | `confirmed_need_release.release`  | `ConfirmedNeedBatch`    | Release the exact current approval snapshot and create immutable release evidence. |

Both functions use `RMVP-07.v1` and the standard Atlas command envelope. The envelope is closed: no additional top-level or payload field is accepted.

Approval request:

```json
{
  "contract_version": "RMVP-07.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "bounded-string",
  "expected_version": 3,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601 timestamp",
  "reason_code": "CONFIRMED_NEED_APPROVAL_REQUESTED",
  "reason_note": null,
  "payload": {
    "confirmed_need_batch_id": "uuid"
  }
}
```

Release request uses the same shape and payload, with the exact reason code:

```json
{
  "contract_version": "RMVP-07.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "bounded-string",
  "expected_version": 4,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601 timestamp",
  "reason_code": "CONFIRMED_NEED_RELEASE_REQUESTED",
  "reason_note": null,
  "payload": {
    "confirmed_need_batch_id": "uuid"
  }
}
```

For both commands:

- `idempotency_key` is trimmed, nonblank and at most 200 characters;
- `expected_version` is a positive integer;
- `requested_at` is a valid non-future `timestamptz`;
- `reason_note` is either JSON `null` or a trimmed string of 1 to 500 characters;
- approval accepts only `CONFIRMED_NEED_APPROVAL_REQUESTED`;
- release accepts only `CONFIRMED_NEED_RELEASE_REQUESTED`; and
- the payload contains exactly `confirmed_need_batch_id`.

The browser supplies only command identity, expected version, reason and batch ID. It cannot author:

- the Actor;
- current lifecycle or resulting lifecycle;
- validation attempt or validation fingerprint;
- line membership or line-revision identity;
- decision, policy or source bindings;
- approval snapshot or snapshot-line identity;
- approved quantities;
- release identity;
- resulting version;
- receipt, event or audit identity; or
- action eligibility.

The existing `atlas_confirmed_need_review_runtime` is reused. No database role is added. The two capabilities are active but unbound; no production Actor, role or scope binding is created by documentation or future migration-time seed.

## 4. Full-batch authority

Approval and release are complete-batch actions.

- Partial approval is prohibited.
- Partial release is prohibited.
- The exact complete current stable-line set is approved.
- Every approval snapshot contains one and only one snapshot line for every current stable Confirmed Need line.
- An unchanged line remains bound to its exact current revision; approval does not create a quantity revision.
- Warnings may remain visible and do not block approval or release unless a later approved policy reclassifies them as blockers.
- No warning-acknowledgement relation or workflow is added.
- Zero confirmed quantity remains a warning under RMVP-06. RMVP-07 may approve and release it as part of the complete batch; later CMD-03 must separately define whether zero lines are excluded or blocked when creating Purchase Handoff.

### 4.1 Fingerprint separation and lifecycle-neutral projection

The two fingerprints have different meanings and must never be substituted for each other:

| Evidence                             | Exact meaning                                                                                                                                   | Post-transition recomputation                                                                                    |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| RMVP-06 `validation_fingerprint`     | Immutable validation-attempt snapshot containing `evaluated_batch_version`, `prior_batch_status`, ordered line observations and ordered issues. | Prohibited as an approval or release equality test because lifecycle/version advancement necessarily changes it. |
| RMVP-07 `validated_fact_fingerprint` | SHA-256 of the lifecycle-neutral `RMVP-07-VALIDATED-FACTS.v1` projection accepted by approval.                                                  | Required at approval and release from current facts under locks.                                                 |

The exact lifecycle-neutral projection is:

```text
projection_version = RMVP-07-VALIDATED-FACTS.v1
confirmed_need_batch_id
ordered_lines by confirmed_need_line_id, each containing:
  line_sort_position
  confirmed_need_line_id
  service_date
  customer_id
  school_id
  delivery_location_id
  ingredient_id
  current_confirmed_need_line_revision_id
  current_confirmed_need_line_decision_id
  controlled_unit_id
  planning_quantity_policy_id
  planning_quantity_policy_revision_id
  need_generation_run_id
  need_generation_run_version
  need_generation_release_snapshot_id
  theoretical_quantity as canonical decimal text
  confirmed_quantity as canonical decimal text
  planning_tick_count as canonical decimal text
  source_membership_count
  source_membership_total as canonical decimal text
  ordered_source_members by confirmed_need_line_revision_contribution_id, each containing:
    confirmed_need_line_revision_contribution_id
    need_generation_release_snapshot_line_id
    theoretical_need_line_id
    source_theoretical_quantity as canonical decimal text
    controlled_contribution_quantity as canonical decimal text
ordered_issues using RMVP-06 severity/code/line ordering, each containing:
  issue_sort_position
  confirmed_need_line_id or null
  severity
  issue_code
```

Mutable batch status/version, attempt ID/number, Actor, timestamps, command/correlation IDs and operator display messages are excluded. Exact Unit, policy, decision, source, quantity, tick and membership facts are included. Eligibility changes to Unit, policy or source evidence are represented by the recomputed closed issue set. Approval requires zero projected blockers; warnings remain included and nonblocking.

The canonical JSON object is hashed as lowercase SHA-256 over its UTF-8 `jsonb::text` representation after every array has the ordering above. Approval builds one projection from the immutable successful RMVP-06 observations/issues and their exact relational bindings, builds the same projection from current facts under locks, and requires equality. It then stores the resulting `validated_fact_fingerprint` on the approval snapshot. Release rebuilds the current projection and compares it with that stored approval fingerprint. Neither command creates another RMVP-06 attempt.

### 4.2 Exact result, failure and replay shapes

Approval success returns exactly these fields:

```json
{
  "success": true,
  "contract_version": "RMVP-07.v1",
  "command_name": "approve_confirmed_needs",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_status": "COMPLETED",
  "confirmed_need_batch_id": "uuid",
  "source_kind": "NEED_GENERATION",
  "prior_batch_status": "VALIDATED",
  "resulting_batch_status": "APPROVED",
  "prior_batch_version": 3,
  "resulting_batch_version": 4,
  "confirmed_need_validation_attempt_id": "uuid",
  "validation_attempt_fingerprint": "64 lowercase hex characters",
  "validated_fact_fingerprint": "64 lowercase hex characters",
  "confirmed_need_approval_snapshot_id": "uuid",
  "approved_version": 4,
  "approved_line_count": 12,
  "warning_count": 1,
  "approved_by_actor_id": "uuid",
  "approved_at": "ISO-8601 timestamp",
  "receipt_id": "uuid",
  "event_id": "uuid",
  "audit_id": "uuid",
  "safe_operator_message": "The complete Confirmed Need batch was approved and is awaiting release.",
  "authoritative_readback": {}
}
```

Release success returns exactly these fields:

```json
{
  "success": true,
  "contract_version": "RMVP-07.v1",
  "command_name": "release_confirmed_needs_for_purchase_handoff",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_status": "COMPLETED",
  "confirmed_need_batch_id": "uuid",
  "source_kind": "NEED_GENERATION",
  "prior_batch_status": "APPROVED",
  "resulting_batch_status": "RELEASED_FOR_PURCHASE_HANDOFF",
  "prior_batch_version": 4,
  "resulting_batch_version": 5,
  "confirmed_need_approval_snapshot_id": "uuid",
  "validated_fact_fingerprint": "64 lowercase hex characters",
  "confirmed_need_release_id": "uuid",
  "source_approved_batch_version": 4,
  "resulting_released_batch_version": 5,
  "released_line_count": 12,
  "warning_count": 1,
  "released_by_actor_id": "uuid",
  "released_at": "ISO-8601 timestamp",
  "receipt_id": "uuid",
  "event_id": "uuid",
  "audit_id": "uuid",
  "safe_operator_message": "The approved Confirmed Need batch was released for later Purchase Handoff creation.",
  "authoritative_readback": {}
}
```

All UUID and timestamp values are JSON strings; versions/counts are JSON integers; `authoritative_readback` is the exact additive workbench object committed into the receipt. A safe failure for either command returns exactly:

```text
success = false
contract_version = RMVP-07.v1
command_name
error_code
safe_message
domain = PLANNING
retryable
field_errors = []
blocking_references = []
expected_version
actual_version, omitted when unknown
correlation_id
command_id
write_certainty = NO_APPROVAL_EVIDENCE | NO_RELEASE_EVIDENCE
local_draft_may_be_preserved = false
exact_retry_safe = retryable
refresh_read = get_confirmed_need_review
```

Exact replay returns the byte-for-byte stored original success or failure response, including the original `idempotency_status`, IDs, timestamps and authoritative readback. It does not recompute current readback and does not create a second `REPLAYED` response shape. Reuse of a command ID or scoped idempotency key with a different canonical request returns `IDEMPOTENCY_CONFLICT` and no business write.

## 5. Approval contract

### 5.1 Preconditions

`approve_confirmed_needs` accepts only a `NEED_GENERATION` batch that satisfies all of the following under authoritative locks:

1. the caller resolves to one active human Actor through the JWT subject;
2. the Actor has active `GLOBAL` scope and `confirmed_need_approval.approve`;
3. the batch exists and is exactly `VALIDATED`;
4. `expected_version` equals the current batch version;
5. the batch points to one exact current successful RMVP-06 validation attempt;
6. that attempt belongs to the batch, has outcome `VALIDATED`, and its resulting version equals the current batch version;
7. its blocker count is zero;
8. its complete observed line count equals the complete current stable-line count;
9. every current line has exactly one current revision and one current decision bound to the same revision, policy, Unit, source release, confirmed quantity, planning ticks and exact membership recorded by validation;
10. the current `RMVP-07-VALIDATED-FACTS.v1` projection equals the lifecycle-neutral projection reconstructed from the successful attempt's immutable observations, issues and exact relational bindings;
11. no approval snapshot already represents the current validated version, except exact idempotent replay; and
12. no downstream Purchase Handoff exists for a later or incompatible release.

Approval does not rerun RMVP-06 as a second validation attempt. It verifies that the exact successful validation evidence is still current and complete.

### 5.2 Transaction

One successful transaction:

1. begins or exactly replays the standard command receipt;
2. locks the batch, current successful validation attempt, stable lines, current revisions, current decisions, policy revisions, controlled Units and exact released source evidence in deterministic order;
3. reconstructs the lifecycle-neutral projection accepted by the successful attempt, recomputes the current projection, and rejects changed facts without attempting to recompute the lifecycle-bound RMVP-06 fingerprint;
4. creates one `confirmed_need_approval_snapshots` row bound to the exact validation attempt and stores the exact `validated_fact_fingerprint` accepted by approval;
5. creates one `confirmed_need_snapshot_lines` row for every current stable line, binding the exact current line revision, Ingredient, confirmed quantity and Unit;
6. records the snapshot as the batch's current approval authority and clears the batch's RMVP-06 current-validation pointer because the immutable snapshot binding now owns that lineage;
7. sets every included current line revision from `DRAFT` to controlled lifecycle metadata `APPROVED` without changing its immutable quantity/source payload;
8. changes batch status `VALIDATED → APPROVED`;
9. increments the batch version exactly once;
10. records approval Actor/time on the batch;
11. appends `ConfirmedNeedsApproved`, one audit event and one completed receipt; and
12. returns authoritative workbench readback.

The snapshot's approved version is the resulting `APPROVED` batch version. It also binds the successful validation attempt whose resulting version was the command's expected source version.

### 5.3 Approval rejection

Rejected approval creates no snapshot, snapshot line, lifecycle change, line metadata change, domain event or audit event. Safe failures include:

```text
UNSUPPORTED_CONTRACT_VERSION
AUTH_SUBJECT_MISMATCH
ACTOR_NOT_AUTHORIZED
CONFIRMED_NEED_BATCH_NOT_FOUND
UNSUPPORTED_SOURCE_KIND
INVALID_LIFECYCLE_STATE
STALE_VERSION
CURRENT_VALIDATION_MISSING
CURRENT_VALIDATION_NOT_SUCCESSFUL
CURRENT_VALIDATION_NOT_CURRENT
VALIDATION_EVIDENCE_INCOMPLETE
CURRENT_FACTS_CHANGED
APPROVAL_ALREADY_EXISTS
IDEMPOTENCY_CONFLICT
```

## 6. Approval snapshot authority

The existing approval snapshot and snapshot-line relations remain the authority. Future implementation may add only the minimum exact bindings required by this contract:

- `confirmed_need_approval_snapshots.source_kind`;
- `confirmed_need_approval_snapshots.confirmed_need_validation_attempt_id`;
- `confirmed_need_approval_snapshots.validated_fact_fingerprint`;
- `confirmed_need_batches.current_confirmed_need_approval_snapshot_id`; and
- restrictive composite ownership and version constraints needed to prove the snapshot, batch and successful validation attempt belong together.

The snapshot and snapshot lines are append-only and undeletable. They do not query a mutable latest line later. They retain the exact approved revision and quantity even after a future reopen or successor approval.

Approval evidence does not itself authorize CMD-03. Only a `NEED_GENERATION` release record does.

### 6.1 Closed source-family compatibility

The additive columns, FKs, pointers and guards are source-qualified. They must preserve this exact alternative-family matrix:

| Source family     | Approval snapshot validation binding                                         | `validated_fact_fingerprint`          | New batch approval/release pointers                                                                                                            | RMVP-07 release row                                           |
| ----------------- | ---------------------------------------------------------------------------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `WHOLESALE`       | Must remain `NULL`.                                                          | Must remain `NULL`.                   | Both remain `NULL`; neither is required by status.                                                                                             | Prohibited and not required.                                  |
| `NEED_GENERATION` | Must be non-`NULL` and bind the exact successful attempt for the same batch. | Must be non-`NULL` lowercase SHA-256. | Current approval required in `APPROVED` and `RELEASED_FOR_PURCHASE_HANDOFF`; current release required only in `RELEASED_FOR_PURCHASE_HANDOFF`. | Required exactly once for the current approval when released. |

The snapshot's `source_kind` must participate in a composite FK to `(confirmed_need_batch_id, source_kind)`. The validation binding must use a restrictive composite owner key containing validation-attempt ID, batch ID and `NEED_GENERATION`. Existing PA-05D snapshots are backfilled as `WHOLESALE` with null RMVP-07 fields; no PA-05D row is rewritten semantically.

For `NEED_GENERATION`, the exact pointer matrix is:

| Batch status                    | Current validation pointer                       | Current approval pointer        | Current release pointer        |
| ------------------------------- | ------------------------------------------------ | ------------------------------- | ------------------------------ |
| `DRAFT_REVIEW` / `REOPENED`     | `NULL`                                           | `NULL`                          | `NULL`                         |
| `VALIDATED`                     | Exact successful attempt required                | `NULL`                          | `NULL`                         |
| `APPROVED`                      | `NULL`; lineage is retained by approval snapshot | Exact current approval required | `NULL`                         |
| `RELEASED_FOR_PURCHASE_HANDOFF` | `NULL`; lineage is retained by approval snapshot | Exact current approval required | Exact current release required |

For `WHOLESALE`, all three new/current RMVP-06/RMVP-07 pointers may remain null in `RELEASED_FOR_PURCHASE_HANDOFF`; the existing PA-05D version-1 batch, approval snapshot and atomic behavior remain valid.

## 7. Release contract

### 7.1 Preconditions

`release_confirmed_needs_for_purchase_handoff` accepts only a batch that satisfies all of the following under locks:

1. the caller resolves to one active human Actor;
2. the Actor has active `GLOBAL` scope and `confirmed_need_release.release`;
3. the batch exists and is exactly `APPROVED`;
4. `expected_version` equals the current approved batch version;
5. the batch points to one exact current approval snapshot;
6. the snapshot belongs to the batch and its approved version equals the current batch version;
7. the snapshot is bound to the exact successful validation attempt used for approval;
8. the snapshot has every-and-only one line for every current stable line;
9. each snapshot line still identifies the exact current `APPROVED` line revision and confirmed quantity;
10. the approval snapshot's `validated_fact_fingerprint` equals the recomputed current `RMVP-07-VALIDATED-FACTS.v1` fingerprint;
11. no current release already exists for that approval snapshot, except exact replay; and
12. no incompatible Purchase Handoff already exists.

A source correction or other authoritative fact change after approval blocks release. Release never silently chooses a newer calculation, line revision, decision, policy or source snapshot.

### 7.2 Transaction

One successful transaction:

1. begins or exactly replays the command receipt;
2. locks the batch, current approval snapshot, snapshot lines and the exact approval-bound validation/source facts in deterministic order;
3. confirms every release precondition and the unchanged lifecycle-neutral approval fingerprint;
4. inserts one immutable `confirmed_need_releases` record naming `source_kind = NEED_GENERATION`, the exact approval snapshot, source version, resulting version, Actor/time and command;
5. records that release as the batch's current release authority;
6. sets every included current line revision from controlled metadata `APPROVED` to `RELEASED` without changing immutable payload;
7. changes batch status `APPROVED → RELEASED_FOR_PURCHASE_HANDOFF`;
8. increments the batch version exactly once;
9. records release Actor/time on the batch;
10. appends `ConfirmedNeedsReleasedForPurchaseHandoff`, one audit event and one completed receipt; and
11. returns authoritative workbench readback.

Release does not create:

- `PurchaseHandoffBatch`;
- Purchase Handoff lines or revisions;
- `PurchaseDemandReference`;
- supplier assignment;
- purchase order;
- warehouse or dispatch fact; or
- Procurement authority.

A later CMD-03 contract must consume the exact current `confirmed_need_release_id` and its approval snapshot. It must reject a reopened, stale, superseded or incompatible release.

### 7.3 Release rejection

Rejected release creates no release record, lifecycle change, line metadata change, event or audit. Safe failures include:

```text
UNSUPPORTED_CONTRACT_VERSION
AUTH_SUBJECT_MISMATCH
ACTOR_NOT_AUTHORIZED
CONFIRMED_NEED_BATCH_NOT_FOUND
UNSUPPORTED_SOURCE_KIND
INVALID_LIFECYCLE_STATE
STALE_VERSION
CURRENT_APPROVAL_MISSING
CURRENT_APPROVAL_NOT_CURRENT
APPROVAL_EVIDENCE_INCOMPLETE
APPROVAL_FACTS_CHANGED
RELEASE_ALREADY_EXISTS
PURCHASE_HANDOFF_CONFLICT
IDEMPOTENCY_CONFLICT
```

## 8. Release evidence

Future implementation adds exactly one private Planning relation:

```text
confirmed_need_releases
```

Minimum immutable fields are:

- `confirmed_need_release_id`;
- `confirmed_need_batch_id`;
- `source_kind`, constrained exactly to `NEED_GENERATION`;
- `confirmed_need_approval_snapshot_id`;
- source approved batch version;
- resulting released batch version;
- released Actor and timestamp;
- command ID; and
- created timestamp.

The batch receives the nullable pointer `confirmed_need_batches.current_confirmed_need_release_id` under the source/status matrix in section 6.1.

Required invariants include:

- one release per approval snapshot;
- one command per release record;
- typed composite ownership FK from `(confirmed_need_batch_id, source_kind)` to the batch;
- restrictive batch/snapshot source-family ownership and version agreement;
- current batch release pointer agrees with `RELEASED_FOR_PURCHASE_HANDOFF` status and resulting version;
- immutable and undeletable release evidence; and
- no direct browser access.

The relation is not Purchase Handoff. It is the Planning-owned authority that a later CMD-03 may consume.

## 9. Idempotency, concurrency and lock order

Both commands use standard Atlas receipt behavior:

- exact command replay returns the original response and IDs;
- reuse of a command ID or idempotency key with a changed request fails with `IDEMPOTENCY_CONFLICT`;
- stale versions fail before business writes;
- the server owns Actor identity and resulting timestamps;
- no automatic frontend retry is permitted after an unknown mutation outcome;
- the UI must first refresh authoritative readback before offering a manual retry.

Deterministic lock order is:

```text
Confirmed Need batch
→ current validation / approval authority
→ stable lines ordered by confirmed_need_line_id
→ current revisions ordered by confirmed_need_line_revision_id
→ current decisions
→ controlled Units
→ Planning policy roots and revisions
→ Need Generation run, release snapshot and release members
→ approval snapshot lines where applicable
→ current release pointer where applicable
```

## 10. Security and separation of authority

- Both functions are fixed-empty-search-path `SECURITY DEFINER` functions.
- Execute is revoked from `PUBLIC`, `anon` and `service_role` and granted only to `authenticated`.
- Private Planning relations remain forced-RLS and revoke-first.
- Browser roles receive no table privilege.
- The existing Confirmed Need runtime receives only the exact helper execution and relation privileges required by the two commands.
- `confirmed_need_approval.approve` and `confirmed_need_release.release` are independent capabilities.
- No production role membership is seeded.
- RMVP-07 does not require the approving and releasing Actors to differ. A later governance decision may impose four-eyes approval without changing the lifecycle or evidence model.

## 11. Read model and Vietnamese operator behavior

The existing `get_confirmed_need_review` function remains contract `RMVP-05.v1` and is extended additively. No second read API is added.

The exact additive JSON fields and types are:

| JSON path                                                            | Type                                            | Meaning                                                                                                                |
| -------------------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `allowed_actions.approve_confirmed_needs`                            | boolean                                         | True only when every approval check passes for the authenticated Actor.                                                |
| `allowed_actions.release_confirmed_needs_for_purchase_handoff`       | boolean                                         | True only when every release check passes for the authenticated Actor.                                                 |
| `disabled_reason_codes.approve_confirmed_needs`                      | string or null                                  | First matching code from the closed approval registry below.                                                           |
| `disabled_reason_codes.release_confirmed_needs_for_purchase_handoff` | string or null                                  | First matching code from the closed release registry below.                                                            |
| `disabled_reasons.approve_confirmed_needs`                           | string or null                                  | Safe Vietnamese display message for the approval code.                                                                 |
| `disabled_reasons.release_confirmed_needs_for_purchase_handoff`      | string or null                                  | Safe Vietnamese display message for the release code.                                                                  |
| `approval.current_snapshot_id`                                       | UUID string or null                             | Current `NEED_GENERATION` approval authority.                                                                          |
| `approval.approved_version`                                          | integer or null                                 | Resulting `APPROVED` batch version.                                                                                    |
| `approval.source_validated_version`                                  | integer or null                                 | Successful validation's resulting version.                                                                             |
| `approval.validation_attempt_id`                                     | UUID string or null                             | Exact successful attempt bound by the approval.                                                                        |
| `approval.validation_attempt_fingerprint`                            | 64-character string or null                     | Immutable RMVP-06 attempt fingerprint; display/audit only.                                                             |
| `approval.validated_fact_fingerprint`                                | 64-character string or null                     | Lifecycle-neutral projection fingerprint accepted by approval.                                                         |
| `approval.approved_actor`                                            | `{ "id": UUID string, "name": string }` or null | Backend-shaped Actor identity.                                                                                         |
| `approval.approved_at`                                               | ISO-8601 string or null                         | Approval timestamp.                                                                                                    |
| `approval.line_count`                                                | integer                                         | Snapshot-line count, zero when no current approval.                                                                    |
| `approval.warning_count`                                             | integer                                         | Warning count accepted by the bound validation.                                                                        |
| `release.current_release_id`                                         | UUID string or null                             | Current RMVP-07 release evidence.                                                                                      |
| `release.approval_snapshot_id`                                       | UUID string or null                             | Exact approval snapshot released.                                                                                      |
| `release.source_approved_version`                                    | integer or null                                 | Source `APPROVED` batch version.                                                                                       |
| `release.resulting_released_version`                                 | integer or null                                 | Resulting released batch version.                                                                                      |
| `release.released_actor`                                             | `{ "id": UUID string, "name": string }` or null | Backend-shaped Actor identity.                                                                                         |
| `release.released_at`                                                | ISO-8601 string or null                         | Release timestamp.                                                                                                     |
| `facts_changed_since_validation`                                     | boolean or null                                 | Null without successful validation lineage; otherwise current projection differs from the validation-bound projection. |
| `facts_changed_since_approval`                                       | boolean or null                                 | Null without current approval; otherwise current projection differs from `approval.validated_fact_fingerprint`.        |
| `lifecycle_history`                                                  | array                                           | Newest-first immutable validation, approval and release entries.                                                       |

Each `lifecycle_history` item contains exactly `evidence_kind` (`VALIDATION`, `APPROVAL` or `RELEASE`), `evidence_id` (UUID string), `outcome` (string), `source_version` (integer), `resulting_version` (integer), `actor` (`{id,name}`), `occurred_at` (ISO-8601 string), `reason_code` (string) and `warning_count` (integer). No approval/release field is inferred client-side from lifecycle status.

The approval disabled registry is closed and evaluated in this exact precedence; the first matching row wins:

| Priority | Code                                      | Condition                                                                                                         | Vietnamese display message                               |
| -------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| 1        | `APPROVAL_UNSUPPORTED_SOURCE_KIND`        | `source_kind <> NEED_GENERATION`                                                                                  | `Luồng nguồn này không dùng bước phê duyệt RMVP-07.`     |
| 2        | `APPROVAL_ALREADY_COMPLETED`              | Status is `APPROVED` or `RELEASED_FOR_PURCHASE_HANDOFF`.                                                          | `Lô nhu cầu đã được phê duyệt.`                          |
| 3        | `APPROVAL_BATCH_NOT_VALIDATED`            | Status is not `VALIDATED`.                                                                                        | `Lô nhu cầu chưa ở trạng thái đã kiểm tra.`              |
| 4        | `APPROVAL_CAPABILITY_REQUIRED`            | Actor lacks active `GLOBAL` approval capability.                                                                  | `Bạn không có quyền phê duyệt lô nhu cầu.`               |
| 5        | `APPROVAL_VALIDATION_MISSING`             | Current successful-validation pointer is null.                                                                    | `Không tìm thấy bằng chứng kiểm tra hiện hành.`          |
| 6        | `APPROVAL_VALIDATION_NOT_CURRENT`         | Attempt is not successful, not owned by the batch, or its resulting version is not the current validated version. | `Bằng chứng kiểm tra không còn là bằng chứng hiện hành.` |
| 7        | `APPROVAL_VALIDATION_EVIDENCE_INCOMPLETE` | Observation/issue counts, complete membership or exact bindings fail.                                             | `Bằng chứng kiểm tra chưa đầy đủ.`                       |
| 8        | `APPROVAL_VALIDATED_FACTS_CHANGED`        | Lifecycle-neutral current projection differs from validation evidence.                                            | `Dữ liệu đã thay đổi; không thể phê duyệt.`              |
| 9        | `APPROVAL_PURCHASE_HANDOFF_CONFLICT`      | A later or incompatible Purchase Handoff exists.                                                                  | `Đã có bàn giao mua hàng không tương thích.`             |

The release disabled registry is also closed and uses this exact precedence:

| Priority | Code                                   | Condition                                                                   | Vietnamese display message                           |
| -------- | -------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------- |
| 1        | `RELEASE_UNSUPPORTED_SOURCE_KIND`      | `source_kind <> NEED_GENERATION`                                            | `Luồng nguồn này không dùng bước phát hành RMVP-07.` |
| 2        | `RELEASE_ALREADY_COMPLETED`            | Status is `RELEASED_FOR_PURCHASE_HANDOFF`.                                  | `Lô nhu cầu đã được phát hành.`                      |
| 3        | `RELEASE_BATCH_NOT_APPROVED`           | Status is not `APPROVED`.                                                   | `Lô nhu cầu chưa được phê duyệt.`                    |
| 4        | `RELEASE_CAPABILITY_REQUIRED`          | Actor lacks active `GLOBAL` release capability.                             | `Bạn không có quyền phát hành lô nhu cầu.`           |
| 5        | `RELEASE_APPROVAL_MISSING`             | Current approval pointer is null.                                           | `Không tìm thấy bản phê duyệt hiện hành.`            |
| 6        | `RELEASE_APPROVAL_NOT_CURRENT`         | Snapshot ownership or approved version differs from the current batch.      | `Bản phê duyệt không còn là bản hiện hành.`          |
| 7        | `RELEASE_APPROVAL_EVIDENCE_INCOMPLETE` | Snapshot membership, validation binding or exact line bindings fail.        | `Bằng chứng phê duyệt chưa đầy đủ.`                  |
| 8        | `RELEASE_APPROVED_FACTS_CHANGED`       | Current lifecycle-neutral projection differs from the approval fingerprint. | `Bản phê duyệt không còn phù hợp; cần rà soát lại.`  |
| 9        | `RELEASE_PURCHASE_HANDOFF_CONFLICT`    | An incompatible Purchase Handoff exists.                                    | `Đã có bàn giao mua hàng không tương thích.`         |

When an action is allowed, its disabled code and message are both null. Existing `allowed_actions`, `disabled_reasons`, quantity editing, preview and confirmation fields remain additive and backward compatible; editing remains disabled after `VALIDATED`.

Required Vietnamese labels are:

| Technical meaning | Vietnamese UI                                       |
| ----------------- | --------------------------------------------------- |
| Approval action   | `Phê duyệt lô nhu cầu`                              |
| Approved state    | `Đã phê duyệt; chờ phát hành`                       |
| Release action    | `Phát hành sang bước lên đơn`                       |
| Released state    | `Đã phát hành sang bước lên đơn`                    |
| Approval stale    | `Dữ liệu đã thay đổi; không thể phê duyệt.`         |
| Release stale     | `Bản phê duyệt không còn phù hợp; cần rà soát lại.` |

The release confirmation explains that the action does **not** select suppliers or create purchase orders.

The same sixth Planning Inputs tab remains the application surface. No approval dashboard, workflow inbox, generic task engine or new navigation item is added.

## 12. Correction and reopen boundary

RMVP-07 does not implement `reopen_confirmed_needs`.

A future reopen command must:

- be explicit and reasoned;
- preserve all prior approval snapshots and release records;
- clear only current approval/release pointers and controlled batch/line lifecycle metadata;
- never delete or mutate released evidence;
- block CMD-03 while the batch is reopened; and
- require review, validation, approval and release again.

An upstream source change may make approval or release ineligible immediately, but it never auto-executes reopen.

## 13. Implementation ceiling

A separately authorized RMVP-07B implementation is bounded to:

- exactly two new `atlas_api` functions;
- exactly two active unbound capabilities;
- zero new database roles or runtime roles;
- zero new lifecycle states or scope kinds;
- zero new views or materialized views;
- exactly one new private Planning relation, `confirmed_need_releases`;
- minimum source-qualified additive columns, pointers, constraints, indexes, policies, projection helpers and triggers required to bind approval to validation and release to approval;
- additive extension of the existing Confirmed Need read model and sixth Planning Inputs tab;
- focused pgTAP, frontend and browser-key verification; and
- no production seed or hosted deployment.

Implementation must preserve direct-wholesale `PA-05D.v1` behavior through the exact alternative-family matrix in section 6.1. It must not broaden either command to `WHOLESALE`. The first connected RMVP-07 implementation is `NEED_GENERATION` only.

## 14. Verification requirements

The later implementation must prove at minimum:

### Structure and security

- exact API names, versions, owners, security mode, search path, grants and revokes;
- exact capability names and no production bindings;
- exact request reasons, response fields, replay behavior and disabled-reason registries;
- source-qualified approval binding, release relation and pointer constraints;
- existing WHOLESALE snapshots with null validation binding/fingerprint and null RMVP-07 pointers remain valid;
- forced RLS, immutable evidence and browser denial;
- unchanged runtime-role count; and
- exact current platform catalog reconciliation.

### Approval behavior

- authorization and source-kind rejection;
- non-`VALIDATED` rejection;
- stale-version rejection;
- missing, failed, stale or incomplete validation rejection;
- proof that the RMVP-06 attempt fingerprint is retained but never recomputed after lifecycle advancement;
- lifecycle-neutral projection equality and changed-fact rejection;
- exact complete snapshot creation;
- exact validation-attempt binding;
- exact `validated_fact_fingerprint` storage;
- one version increment;
- controlled line metadata transition only;
- receipt/event/audit atomicity;
- replay and idempotency conflict; and
- warnings remain visible but nonblocking.

### Release behavior

- authorization and non-`APPROVED` rejection;
- stale-version and missing/current-approval rejection;
- incomplete snapshot or changed lifecycle-neutral projection rejection;
- exactly one release record bound to the exact approval snapshot;
- one version increment;
- controlled line metadata transition only;
- no Purchase Handoff or downstream relation mutation;
- receipt/event/audit atomicity;
- replay and idempotency conflict; and
- exact released readback.

### Direct-wholesale compatibility

- PA-05D still creates a `WHOLESALE` batch directly in `RELEASED_FOR_PURCHASE_HANDOFF`, version `1`;
- its approval snapshot keeps null validation binding and null lifecycle-neutral fingerprint;
- it requires no RMVP-07 current approval/release pointer and no `confirmed_need_releases` row;
- source-qualified guards do not reinterpret the PA-05D status/version combination; and
- the existing PA-05D command, tests, Purchase Handoff and downstream behavior remain unchanged.

### Application behavior

- action visibility is backend-derived;
- approval refreshes to `APPROVED` and disables itself;
- release refreshes to `RELEASED_FOR_PURCHASE_HANDOFF` and disables itself;
- late responses are discarded after newer intent;
- unknown mutation outcomes require refresh before retry; and
- no browser-authored snapshot, release, Actor or version data.

## 15. Explicit exclusions

RMVP-07A authorizes no implementation and no external mutation. It excludes:

- SQL migrations, APIs, functions, grants, RLS or generated types;
- React or CSS changes;
- capability or Actor production binding;
- hosted Supabase mutation or branch;
- Retool or OPS v1/v2 change;
- production data or policy seed;
- Edge Function or deployment;
- reopen or source-correction command implementation;
- CMD-03 or Purchase Handoff creation;
- supplier assignment, allocation or purchase order;
- Procurement, Warehouse or Dispatch mutation;
- partial approval or release;
- mandatory distinct approving/releasing Actors;
- warning acknowledgement workflow;
- generic workflow, task, case-management or notification infrastructure; and
- automatic downstream correction or document rewriting.

## 16. Next authorization

After this documentation baseline merges, a separate RMVP-07B task may implement the exact bounded contract. Its implementation prompt must pin the resulting `main` SHA and must not add reopen, CMD-03, production bindings, hosted deployment or downstream behavior.
