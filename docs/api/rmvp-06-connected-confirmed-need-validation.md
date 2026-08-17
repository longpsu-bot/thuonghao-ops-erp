# RMVP-06 Connected Confirmed Need Validation API Contract

**Status:** Merged through PR #171 at `c4d7970399f6b1c147700925f03e84efdafb0747`

**Contract version:** `RMVP-06.v1`

**Owning domain:** Planning

**Capability:** `confirmed_need_validation.validate`

**Runtime:** reused `atlas_confirmed_need_review_runtime` (`NOLOGIN NOINHERIT`)

## 1. Boundary

RMVP-06 validates one complete current `NEED_GENERATION` Confirmed Need batch after quantity confirmation:

```text
released Need Generation
→ CMD-15 Draft Confirmed Need
→ RMVP-05 immutable line decisions
→ RMVP-06 complete-batch validation
→ VALIDATED, awaiting separately authorized approval
```

It adds one public command, one unbound capability, three private append-only evidence relations, one nullable batch pointer to the successful attempt, and additive readback/UI fields. It adds no approval, approval snapshot, release, reopen command, CMD-03, Purchase Handoff, Procurement, Warehouse, Dispatch, production capability binding, hosted deployment, or Retool behavior.

## 2. Public command

`atlas_api.validate_confirmed_needs(request jsonb) → jsonb` is a fixed-empty-search-path security definer owned by the existing Confirmed Need runtime. Execute is revoked from `PUBLIC`, `anon`, and `service_role` and granted only to `authenticated`. The caller requires an exact JWT-bound active human Actor, active `GLOBAL` scope, and active `confirmed_need_validation.validate` capability.

Request:

```json
{
  "contract_version": "RMVP-06.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "confirmed-need-validation:uuid",
  "expected_version": 2,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601 timestamp",
  "reason_code": "BATCH_VALIDATION_REQUESTED",
  "reason_note": null,
  "payload": {
    "confirmed_need_batch_id": "uuid"
  }
}
```

The browser cannot author line membership, revisions, decisions, source evidence, policy bindings, quantities, issue codes, attempt number, outcome, fingerprint, resulting version/status, Actor identity, event, audit, or receipt evidence.

## 3. Transaction and outcomes

The command begins or replays the standard receipt, locks the batch, then stable lines in UUID order. It evaluates current facts, locks controlled Units, policy roots, policy revisions, the current Need Generation run, current release snapshot, and release members in deterministic order, and rereads the same canonical facts. A changed fingerprint adds `CURRENT_FACTS_CHANGED` and fails closed.

Every accepted invocation appends one attempt and a complete stable-line observation set. Issues are ordered blockers first, then warnings, by stable line and code order.

- `BLOCKED` is a successful governed command outcome. It commits attempt/line/issue evidence, event `ConfirmedNeedValidationFailed`, audit, and receipt, but leaves batch status, version, and successful-attempt pointer unchanged.
- `VALIDATED` is allowed only with zero blockers and complete exact line observations. It atomically sets status `VALIDATED`, increments the batch version once, points the batch to that exact successful attempt, and commits event `ConfirmedNeedsValidated`, audit, and receipt.

Exact command replay returns the stored original response and IDs without duplicate evidence. Changed command or idempotency reuse conflicts. Stale version, authorization, unsupported source, and invalid lifecycle failures create no validation attempt. The frontend never retries validation automatically.

## 4. Complete issue registry

The approved blocking registry is exactly:

```text
NO_CURRENT_LINES
CURRENT_LINE_SET_INVALID
CURRENT_REVISION_MISSING
CURRENT_REVISION_AMBIGUOUS
CURRENT_DECISION_MISSING
CURRENT_DECISION_AMBIGUOUS
DECISION_REVISION_MISMATCH
SOURCE_RELEASE_NOT_CURRENT
CONTRIBUTION_MEMBERSHIP_INVALID
THEORETICAL_TOTAL_MISMATCH
CONTROLLED_UNIT_INACTIVE
PLANNING_POLICY_MISSING
PLANNING_POLICY_AMBIGUOUS
PLANNING_POLICY_NOT_ELIGIBLE
DECISION_POLICY_MISMATCH
CONFIRMED_QUANTITY_INVALID
ADJUSTMENT_REASON_INCOMPLETE
SOURCE_BLOCKER_PRESENT
CURRENT_FACTS_CHANGED
```

The approved warnings are exactly:

```text
ZERO_CONFIRMED_QUANTITY
UPSTREAM_WARNING_RETAINED
```

Cardinality is not collapsed: count `0` maps to the applicable `MISSING` code; count greater than `1` maps to `AMBIGUOUS`; count `1` with invalid or ineligible evidence maps to the applicable mismatch or eligibility code.

## 5. Persistence and read model

Private forced-RLS relations are:

- `confirmed_need_validation_attempts`: outcome, exact evaluated/resulting status and version, counts, fingerprint, Actor/time, command/correlation, and reason;
- `confirmed_need_validation_lines`: complete attempt membership plus observed cardinalities and exact current revision, decision, policy, source, quantity, and tick evidence;
- `confirmed_need_validation_issues`: ordered attempt/batch or line issue evidence constrained to the 19 blockers and two warnings.

All three are immutable and undeletable. Deferred guards require exact line and issue counts, successful pointer/status/version agreement, and complete successful observations. Composite foreign keys bind observations to the exact stable line, revision, decision, policy revision, and released source snapshot.

`validation_fingerprint` is the immutable RMVP-06 attempt fingerprint. Its canonical input includes `evaluated_batch_version` and `prior_batch_status`, so it is not a lifecycle-neutral value and must not be described as directly recomputable after approval or release advances the batch. The accepted RMVP-07 contract defines a separately named lifecycle-neutral validated-fact projection for those later comparisons; RMVP-06 evidence is not rewritten.

`get_confirmed_need_review` remains `RMVP-05.v1` and receives additive fields: authoritative status, editing/validation allowances and disabled reason, latest attempt/outcome/versions/fingerprint/Actor/timestamps/counts, grouped blockers/warnings, and per-line validation markers. After success, editing, preview, confirmation, and repeat validation are read-only; the exact disabled reason is `Lô đã được kiểm tra; chờ phê duyệt.`

## 6. Response

Success returns the outcome, attempt ID/number, evaluated/resulting status and version, fingerprint, exact line/blocker/warning counts, receipt/event/audit IDs, safe message, and authoritative additive workbench readback. `BLOCKED` uses `success = true` and `validation_status = BLOCKED`; business issues are not transport errors.

## 7. Verification

`supabase/tests/rmvp_06_connected_confirmed_need_validation.sql` has exact `plan(65)`. With the bounded deterministic local identity/RMVP-05/RMVP-06 fixture files installed first, it proves the public surface and runtime, forced RLS, browser denial, immutable persistence, corrected registry and canonical ordering, direct-wholesale rejection, governed BLOCKED commit, no blocked version change, distinct missing-versus-ambiguous cardinality branches, stale no-evidence failure, exact successful transition and pointer, deterministic line/count/fingerprint evidence, atomic receipt/event/audit evidence, replay and idempotency conflict, authority-row nonmutation, source lock/reread ordering, fingerprint-change fail-closed behavior, additive readback, and the complete 19+2 evaluator registry.

`scripts/verify-local-rmvp06-confirmed-need-validation.mjs` exercises authenticated browser-key read, complete confirmation where required, validation, exact replay, and readback. Draft smoke uses the deterministic two-line fixture; full integration continues the real RMVP-04 → CMD-15 → RMVP-05 journey.

## 8. Carried decision authority

PLANNING-CONTRACT-02B does not change the RMVP-06 public function, issue registry, lifecycle, response envelope, or validation cardinality rules. A current decision observation is valid when it directly binds the current revision or when exact immutable `CARRIED_FORWARD` evidence authorizes the same human decision for that current direct successor revision. Arbitrary old-revision decisions remain mismatches. Validation counts only current revisions; removed historical stable lines are excluded. Missing/ambiguous effective policy remains fail-closed and cannot be converted into carry.
