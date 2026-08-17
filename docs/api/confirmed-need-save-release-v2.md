# Confirmed Need Save and Release v2 API Contract

**Status:** Implemented on draft PR #189

**Owning domain:** Planning

## Save — `RMVP-05.v2`

`atlas_api.save_confirmed_needs(request jsonb) returns jsonb`

The closed command envelope uses reason `CONFIRMED_NEED_SAVED`, the current expected batch version, and one nonempty unique array of actual changed decisions. There is no 250-line command ceiling. Each line carries stable line identity, expected current revision/decision, exact decimal quantity, governed reason, and note.

The command authorizes `confirmed_need_quantities.confirm`, locks and rereads authoritative bindings, applies the existing exact decimal, Planning-step, reason/note, policy, Unit, source-membership, predecessor, and currentness rules, appends immutable decisions and any required successor revisions atomically, increments the batch once, records receipt/event/audit evidence, returns the complete authoritative workbench, and leaves `DRAFT_REVIEW` or `REOPENED` editable. It never validates, approves, releases, or writes downstream.

## Release — `RMVP-07.v2`

`atlas_api.release_confirmed_needs(request jsonb) returns jsonb`

The closed command envelope uses reason `CONFIRMED_NEED_RELEASED`, the current expected saved batch version, and only the batch identity. It authorizes the distinct `confirmed_need_release.release` capability; validation and approval capabilities are not required from the operator.

In one transaction the command locks the complete current batch, executes the unchanged RMVP-06 deterministic registry, rejects incomplete or stale facts, persists the successful validation observations/issues, creates the every-and-only approval snapshot and lifecycle-neutral fingerprint, creates the immutable Planning release, advances the batch through its existing internal states to `RELEASED_FOR_PURCHASE_HANDOFF`, records validation/approval/release events and audits under one outer receipt, and returns complete released readback.

Release creates zero Purchase Handoff, supplier, purchase-order, Procurement, Warehouse, or Dispatch facts. Exact replay returns the original response. An unknown outcome requires authoritative refresh; clients must not automatically retry.

## Compatibility and security

RMVP-05/06/07 v1 functions remain callable. Both v2 functions reuse `atlas_confirmed_need_review_runtime`, fixed empty search paths, JWT-bound human Actor resolution, active GLOBAL scope, revoke-first execution, private forced-RLS persistence, and no browser table access or service-role credential.

## Authoritative action eligibility

Every authoritative workbench readback extends the existing action shape with `allowed_actions.save_confirmed_needs` and `allowed_actions.release_confirmed_needs`, plus matching `disabled_reason_codes` and `disabled_reasons` fields.

Save eligibility requires the active Actor's Save capability and GLOBAL scope plus a current editable `NEED_GENERATION` batch in `DRAFT_REVIEW` or `REOPENED`. Release eligibility requires its distinct active Release capability and scope, the same supported working lifecycle, no Purchase Handoff conflict, and a complete current saved fact set that passes the canonical RMVP-06 evaluation. Released batches authorize neither action.

Disabled messages contain concise Vietnamese operator meaning and expose no role, capability code, lifecycle enum, version, fingerprint, API, or SQL detail. React may make an authorized action stricter for local dirty/validity, unknown-outcome refresh, or busy state, but cannot turn backend `false` into UI `true`. Both commands re-authorize and recheck current facts atomically regardless of readback eligibility.

## Selective-continuity compatibility

PLANNING-CONTRACT-02B changes neither v2 envelope. `save_confirmed_needs` receives only rows actually changed by the operator; untouched `CARRIED_FORWARD` rows retain the original human decision and create no decision/event side effect. Reconfirmation after system invalidation continues the latest historical human chain, while a truly new line starts at decision `1`. `release_confirmed_needs` accepts carried authority only through exact private continuity evidence and snapshots the current successor revision/quantity. Any current `CHANGED`, `NEW`, or `UNREVIEWED` line without valid authority blocks release.
