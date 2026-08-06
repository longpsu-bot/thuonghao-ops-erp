# RMVP-07 Connected Confirmed Need Approval and Release API Contract

**Status:** Implemented on `codex/rmvp-07b-connected-confirmed-need-approval-release` from exact baseline `c871a8f08867377e921ced865c258040107d6628`; draft PR validation pending

**Contract version:** `RMVP-07.v1`

**Owning domain:** Planning

**Capabilities:** `confirmed_need_approval.approve`, `confirmed_need_release.release`

**Runtime:** reused `atlas_confirmed_need_review_runtime` (`NOLOGIN NOINHERIT`)

## 1. Boundary

RMVP-07 implements the accepted complete-batch `NEED_GENERATION` lifecycle:

```text
VALIDATED
→ approve_confirmed_needs
→ APPROVED
→ release_confirmed_needs_for_purchase_handoff
→ RELEASED_FOR_PURCHASE_HANDOFF
```

Approval accepts the exact complete fact set that passed RMVP-06 validation. Release authorizes that immutable approval as the sole eligible source for a later CMD-03 Purchase Handoff. Release creates no Purchase Handoff, supplier assignment, purchase order, Procurement, Warehouse, or Dispatch fact.

The direct `WHOLESALE` PA-05D path remains unchanged. Its version-1 released batch may keep a `WHOLESALE` approval snapshot with null RMVP-07 validation binding/fingerprint and no RMVP-07 approval or release pointer.

## 2. Public commands

Exactly two public functions are added:

```text
atlas_api.approve_confirmed_needs(request jsonb) returns jsonb
atlas_api.release_confirmed_needs_for_purchase_handoff(request jsonb) returns jsonb
```

Both accept the same closed envelope:

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

Release uses `CONFIRMED_NEED_RELEASE_REQUESTED`. Extra or missing fields are rejected. The browser cannot author lifecycle state, evidence membership, facts, fingerprints, Actor identity, timestamps, events, audits, receipts, or resulting versions.

Approval success has exactly the fields frozen in the RMVP-07A contract: `success`, command/contract/correlation/idempotency identity, batch source and prior/resulting state/version, exact RMVP-06 attempt identity/fingerprint, lifecycle-neutral fact fingerprint, approval snapshot/version/line/warning evidence, Actor/time, receipt/event/audit IDs, safe message, and authoritative readback.

Release success has exactly the corresponding frozen fields: `success`, command/contract/correlation/idempotency identity, batch source and prior/resulting state/version, approval snapshot and fact fingerprint, release identity/source/resulting version/line/warning evidence, Actor/time, receipt/event/audit IDs, safe message, and authoritative readback.

Safe failures use the exact closed RMVP-07 shape and `NO_APPROVAL_EVIDENCE` or `NO_RELEASE_EVIDENCE`. Exact receipt replay returns the byte-for-byte original stored response with `idempotency_status = COMPLETED`; conflicting command or scoped key reuse returns `IDEMPOTENCY_CONFLICT` without a business write.

## 3. Approval transaction and fact binding

Approval resolves and authorizes the JWT-bound active human Actor, begins the standard receipt, rejects non-`NEED_GENERATION` sources, locks the batch and dependent facts deterministically, and requires the exact current successful RMVP-06 attempt at the current `VALIDATED` version with zero blockers and complete observations/issues.

The command reconstructs `RMVP-07-VALIDATED-FACTS.v1` from immutable validation evidence and separately recomputes it from locked current facts. The projection contains the exact stable-line, location, Ingredient, controlled Unit, revision, decision, policy, Need Generation release, quantity, tick, source membership, contribution, blocker, and warning facts. It excludes lifecycle/version, attempt identity, Actors, timestamps, command IDs, and display messages. Lowercase SHA-256 over canonical UTF-8 `jsonb::text` becomes the `validated_fact_fingerprint`.

On equality, approval creates one immutable snapshot bound to the exact RMVP-06 attempt and every-and-only one snapshot line per stable line, changes only line lifecycle metadata `DRAFT → APPROVED`, advances the batch once, moves current authority from validation to approval, and commits `ConfirmedNeedsApproved`, audit, receipt, and authoritative readback atomically. The original RMVP-06 `validation_fingerprint` is never changed or reinterpreted.

## 4. Release transaction

Release separately authorizes `confirmed_need_release.release`, requires the exact current `APPROVED` snapshot/version and complete exact snapshot membership, and recomputes the same lifecycle-neutral projection under locks. Any difference from the approval-bound fingerprint returns `APPROVAL_FACTS_CHANGED` without release evidence.

Success inserts one immutable `confirmed_need_releases` row, changes only line lifecycle metadata `APPROVED → RELEASED`, advances the batch once, sets the current release pointer, and commits `ConfirmedNeedsReleasedForPurchaseHandoff`, audit, receipt, and authoritative readback atomically. It deliberately creates zero Purchase Handoff or downstream rows.

## 5. Persistence and read model

The migration adds one private forced-RLS relation, `atlas_planning.confirmed_need_releases`, with source-qualified typed ownership, one-release-per-approval and one-release-per-command uniqueness, sequential source/resulting versions, immutable rows, and undeletable evidence.

Existing approval snapshots gain `source_kind`, the exact RMVP-06 attempt binding, and `validated_fact_fingerprint`. Confirmed Need batches gain source-qualified current approval and release pointers. Deferred guards enforce the accepted `NEED_GENERATION` pointer matrix while explicitly preserving the alternate `WHOLESALE` shape.

`atlas_api.get_confirmed_need_review` remains `RMVP-05.v1`. Its workbench is extended additively with backend-derived approval/release action booleans, exact closed disabled codes and Vietnamese messages, typed approval and release evidence, validation/approval drift flags, and newest-first validation/approval/release history. History ties are ordered by resulting lifecycle version so one transaction remains deterministically release → approval → validation.

## 6. Security

Both functions are fixed-empty-search-path security definers owned by the reused runtime. Execute is revoked from `PUBLIC`, `anon`, and `service_role` and granted only to `authenticated`. Each command requires an active JWT-bound human Actor, active `GLOBAL` scope, and its separate active capability. The migration creates the two capabilities without production role or Actor bindings.

Private relations use forced RLS and exact runtime select/insert/immutability-lock policies. Browser roles receive no table privileges. The runtime receives only the column and relation privileges needed for this lifecycle and no new Procurement, Warehouse, or Dispatch write privilege. React contains no service-role credential and trusts backend eligibility rather than inferring it from status.

## 7. Verification and exclusions

`supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql` has exact `plan(67)` and proves the surface, security, WHOLESALE compatibility, approval/release atomicity, drift rejection, evidence immutability, response/replay contracts, zero downstream delta, and additive read model. The RMVP-06 catalog suite retains its original plan and changes only its exact policy count from six to nine for the three approved validation-evidence immutability-lock policies.

`scripts/verify-local-rmvp07-confirmed-need-approval-release.mjs` exercises authenticated browser-key approval, exact replay, release, exact replay, final UI readback, and zero downstream delta. Draft smoke uses the deterministic fixture; Full Integration extends the actual RMVP-04 → CMD-15 → RMVP-05 → RMVP-06 path.

Reopen, CMD-03 Purchase Handoff creation, supplier selection, purchase orders, downstream domain changes, hosted Supabase, production capability binding, Retool, credentials, and deployment remain excluded.
