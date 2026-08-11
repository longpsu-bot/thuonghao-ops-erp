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
