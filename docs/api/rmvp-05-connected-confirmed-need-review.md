# RMVP-05 Connected Confirmed Need Review API Contract

**Status:** Implemented on a draft branch; exact-head GitHub validation and merge pending

**Contract version:** `RMVP-05.v1`

**Owning domain:** Planning

**Capabilities:** `confirmed_need_review.read`, `confirmed_need_quantities.preview`, and `confirmed_need_quantities.confirm`

**Runtime:** `atlas_confirmed_need_review_runtime` (`NOLOGIN NOINHERIT`)

## 1. Boundary

RMVP-05 connects the released RMVP-04 result and existing CMD-15 Draft Confirmed Need to explicit, immutable Planning quantity decisions:

```text
released Need Generation
→ CMD-15 Draft Confirmed Need
→ authorized review
→ write-free exact preview
→ explicit confirmation
→ append-only H1B1 decisions
```

It reuses the existing Confirmed Need aggregate, current line revisions, revision contribution memberships, H1A policy revisions, H1B1 decision rows and pointers, and common receipt/event/audit infrastructure. It adds no business relation, view, lifecycle state, scope kind, sequence, trigger, production policy seed, approval, release, Purchase Handoff, Procurement, Warehouse, or Dispatch fact.

## 2. Public surface and authorization

Exactly three `jsonb → jsonb` functions are public:

1. `atlas_api.get_confirmed_need_review(request jsonb)`
2. `atlas_api.preview_confirmed_need_confirmation(request jsonb)`
3. `atlas_api.confirm_need_quantities(request jsonb)`

All three are fixed-search-path security definers owned by `atlas_confirmed_need_review_runtime`. Execute is revoked from `PUBLIC`, `anon`, and `service_role`, then granted only to `authenticated`.

Every call requires exact equality between the JWT subject and `requested_by_auth_subject`, an active human Actor, the operation's exact active capability, and active `GLOBAL` scope. Browser roles receive no private-schema or relation access. The runtime has no login, inheritance, superuser, `BYPASSRLS`, schema `CREATE` after setup, or mutation rights in Procurement, Warehouse, Dispatch, Retool, `public`, or `ops_v2`.

## 3. Review read

### 3.1 Request

```json
{
  "contract_version": "RMVP-05.v1",
  "requested_by_auth_subject": "uuid",
  "correlation_id": "uuid",
  "payload": {
    "confirmed_need_batch_id": "uuid",
    "filters": {
      "service_date": "YYYY-MM-DD or null",
      "school_id": "uuid or null",
      "delivery_location_id": "uuid or null",
      "ingredient_id": "uuid or null",
      "decision_state": "UNREVIEWED|CONFIRMED|null"
    },
    "line_offset": 0,
    "line_limit": 100
  }
}
```

`filters` is optional. Offset defaults to `0`. Limit defaults to `100` and must be `1..250`. The read creates no receipt, event, audit, or business mutation.

### 3.2 Shaped response

The `workbench` contains batch identity, `NEED_GENERATION` source kind, lifecycle status and version, exact Need Generation run/version/release snapshot, service period, total/unreviewed/confirmed/adjusted counts, blockers before warnings, backend-derived allowed actions and disabled reasons, pagination, current lines, and returned-line decision history.

Each line contains its stable line ID, current revision ID/number, service date, Customer, School, Delivery Location, Ingredient, controlled Unit, theoretical quantity, proposed confirmed quantity, current decision identity/number/kind, authoritative confirmed quantity after, exact eligible policy root/revision/number/step/status/effective interval, source membership count, stale flag, blockers, warnings, and newest-first immutable decision history.

Quantities and Planning steps are returned as exact decimal strings. A proposal is not authoritative confirmation until the stable line's current-decision pointer identifies an H1B1 decision.

Review and confirmation are allowed only for `DRAFT_REVIEW` or `REOPENED` batches with current released-source bindings, nonempty current memberships, and exactly one effective policy per line.

## 4. Write-free preview

### 4.1 Request

The preview uses the read authentication envelope:

```json
{
  "contract_version": "RMVP-05.v1",
  "requested_by_auth_subject": "uuid",
  "correlation_id": "uuid",
  "payload": {
    "confirmed_need_batch_id": "uuid",
    "expected_batch_version": 1,
    "lines": [
      {
        "confirmed_need_line_id": "uuid",
        "expected_current_revision_id": "uuid",
        "expected_current_decision_id": null,
        "proposed_confirmed_quantity": "10.250000",
        "reason_code": "PROPOSAL_ACCEPTED",
        "reason_note": null
      }
    ]
  }
}
```

The selected list must contain `1..250` unique stable lines. The backend orders it by stable UUID. The frontend transports authoritative and draft quantities as strings; the backend accepts an exact JSON number or string only when its text is a nonnegative finite decimal with at most fourteen integer and six fractional digits.

Preview takes no lock and writes no state. It rereads the batch, current revision and decision, exact source membership, released source binding, and every effective H1A candidate. Each selected line must resolve exactly one `ACTIVE` or historically eligible `RETIRED` policy revision for its exact Unit and service date.

Representability is exact:

```text
confirmed quantity = whole planning tick count × exact Planning step
```

There is no rounding, ceiling, truncation, epsilon comparison, or JavaScript numeric calculation.

### 4.2 Decision semantics

When the entered quantity equals the current proposal:

- `decision_kind = UNCHANGED_PROPOSAL_ACCEPTED`;
- `reason_code = PROPOSAL_ACCEPTED`;
- first decision note is null;
- no successor quantity revision is required.

When it differs:

- `decision_kind = ADJUSTED_QUANTITY_CONFIRMED`;
- allowed reasons are `PLANNING_STEP_ADJUSTMENT`, `OPERATIONAL_QUANTITY_ADJUSTMENT`, and `OTHER`;
- the latter two require a nonblank note;
- exactly one direct successor quantity revision is required.

Every replacement decision requires a nonblank correction note and binds the exact current decision as predecessor. Decision-only replacement may keep the current quantity revision.

### 4.3 Response and hash

The nested `preview` returns success/error code, batch and expected/actual version, deterministically ordered lines, current bindings, theoretical/proposal/confirmed quantities, derived kind, normalized reason/note, exact policy evidence, whole tick count, successor requirement, membership count and hash, line and aggregate blockers/warnings, a SHA-256 preview hash, and `write_certainty = NO_WRITE`.

The hash binds the contract, batch/version, ordered authoritative bindings, exact quantity outcome, policy, tick, and source-membership evidence. Any material change makes a later command preview differ.

## 5. Confirmation command

### 5.1 Request

```json
{
  "contract_version": "RMVP-05.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "nonblank text",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601 timestamp",
  "reason_code": "CONFIRMED_NEED_QUANTITIES_CONFIRMED",
  "reason_note": null,
  "payload": {
    "confirmed_need_batch_id": "uuid",
    "preview_hash": "64 lowercase hexadecimal characters",
    "lines": []
  }
}
```

The line payload is identical to the preview selection. The browser cannot author Actor identity, decision kind, tick count, policy identity/step, revision or decision number, predecessor, generated IDs, next version, event, or audit evidence.

### 5.2 Transaction

The command starts or replays the standard receipt, locks the batch and selected stable lines in UUID order, reruns the same canonical preview over current revisions, decisions, memberships and policies, and requires both current expected version and exact preview-hash equality.

For each adjusted line it supersedes only permitted current-revision metadata, creates one direct current successor with the confirmed quantity, and copies the prior revision's exact contribution memberships without recalculation. An unchanged line keeps its current revision. The transaction appends one complete H1B1 decision per selected line, advances every current-decision pointer, increments the batch version exactly once without changing `DRAFT_REVIEW`/`REOPENED`, emits one `ConfirmedNeedQuantitiesConfirmed` domain event, writes one audit event, completes one receipt, flushes deferred integrity guards, and returns authoritative review readback. It commits all effects or none.

Success reports the batch/new version, created successor and superseded revision IDs, created decision IDs, advanced stable-line IDs, unchanged/adjusted counts, receipt/event/audit IDs, safe message, and authoritative workbench.

Exact replay returns the stored original response and IDs without duplicate effects. Changed command or idempotency reuse returns `IDEMPOTENCY_CONFLICT`. The application never automatically retries a write and retains the exact uncertain command for explicit retry.

## 6. Safe failures

Common Atlas validation, authentication, capability, scope, stale-version, idempotency, and concurrency errors apply. Narrow RMVP-05 failures are:

- `CONFIRMED_NEED_BATCH_NOT_FOUND`
- `CONFIRMED_NEED_BATCH_NOT_REVIEWABLE`
- `STALE_CONFIRMED_NEED_BATCH`
- `STALE_CONFIRMED_NEED_LINE`
- `STALE_CONFIRMED_NEED_DECISION`
- `MISSING_PLANNING_QUANTITY_POLICY`
- `AMBIGUOUS_PLANNING_QUANTITY_POLICY`
- `QUANTITY_NOT_REPRESENTABLE`
- `INVALID_DECISION_REASON`
- `REASON_NOTE_REQUIRED`
- `PREVIEW_MISMATCH`

Safe failures report write certainty, whether the local Draft may be preserved, whether exact retry is safe, and `get_confirmed_need_review` as the authorized refresh. Raw SQL, private payloads, policy internals, credentials, and role internals are not returned.

## 7. Verification

`supabase/tests/rmvp_05_connected_confirmed_need_review.sql` uses a real RMVP-04-created, validated and released multi-line run and actual CMD-15 materialization. Its exact `plan(37)` covers shaped read, missing/ambiguous policy fail-closed behavior, exact step/precision preview, preview non-mutation, mixed unchanged/adjusted confirmation, revision and membership behavior, decisions and pointers, version/event/audit/receipt atomicity, replay/conflict, stale failure, authorization denials, and predecessor-linked replacement history.

`scripts/verify-local-rmvp05-confirmed-need-review.mjs` is GitHub-only. Draft smoke uses its deterministic disposable RMVP-05 batch for short browser-key review, mixed exact preview, confirmation, exact replay, and authoritative decision readback without calling RMVP-04. Full integration selects its upstream mode after the real RMVP-04/CMD-15 browser journey and additionally verifies correction-note enforcement and replacement confirmation.
