# School fulfilment reconciliation API

`atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)` is the read-only authority for comparing current released School-catering purchase commitments with the current released School PXK. Contract: `SCHOOL-FULFILMENT-RECONCILIATION.v1`.

## Request and authorization

The authenticated envelope contains `requested_by_auth_subject`, `correlation_id`, and this exact payload:

```json
{
  "date_start": "2046-09-17",
  "date_end": "2046-09-19",
  "school_ids": [],
  "search": null
}
```

The inclusive range may not exceed 31 days. An empty School array means every authorized School. Search covers School, captured location, PO number, and PXK number. Unknown fields, invalid UUIDs, and malformed dates fail closed. The Actor requires `dispatch.school_release.read` and the existing customer/School/location scope. Only `authenticated` may execute this API; browser and service roles have no direct private-relation grants.

The Product-approved [exact-School amendment](../decisions/decision-atlas-pxk-exact-school-scope.md) routes reconciliation and PXK reads/releases through the same private Dispatch scope predicate. Active/effective `SCHOOL` scopes match exact School identity; a shared default location conveys no other School's authority. Explicit `DELIVERY_LOCATION`, location-derived `CUSTOMER` and `GLOBAL` semantics remain unchanged. The same staff Actor may operate multiple explicitly scoped Schools with the existing task capabilities; no second-person rule or staff-grant change is added. Captured historical locations and frozen PXK evidence remain authoritative after master-default changes.

## Response authority

Rows arise only from current Confirmed Need, current allocation contribution lineage, or a current `RELEASED` PXK. Superseded history alone cannot manufacture a row. Captured operational `delivery_location_id` remains authoritative if the School default later changes.

`comparison_status` is derived in order: `NO_PO`, `NO_PXK`, `INGREDIENT_CHANGED`, `MISMATCH`, `OK`. Comparison is exact at `(ingredient_id, unit_id)` grain. `quantity_totals_by_unit[]` groups display totals by Unit; unlike Units are never combined. Quantities remain lossless strings.

The 21 October Unit-label amendment adds nullable optional `unit_name` to details
and Unit totals. For an issued PXK the name comes from its immutable captured
line; missing historical names remain null, even when today's preview has a name.
Scopes without a PXK use the backend preview's explicit name. Conflicting captured
names produce no summary name; detail evidence remains visible. Labels never
come from PO-only preview rows when any issued PXK line exists for that Unit.
Conflicts are evaluated across captured input lines before detail aggregation.
Labels never participate in comparison or grouping, and no master lookup or backfill rewrites
released documents. Current and compatibility scope readers carry the same fields.

Rows return School/date/location identity, PO and PXK identities, `pxk_state`, operational `blockers[]`, `warnings[]`, exact `details[]`, and immutable PXK `history[]`. Comparison and operational currentness are independent: `OK` does not overrule procurement or PXK blockers. No command receipt, event, approval, resolution, or business fact is written.

The public read constructs one private, server-owned procurement context after envelope, Actor and capability validation. Scope discovery and per-School comparisons reuse that same request-local authority. Whole-family completeness remains independent of the visible School filter; the existing Dispatch predicate still controls returned School rows. The context is rebuilt on every invocation, including after a correction, and is neither a public request field nor a cache across requests. The original three-argument scope helper remains available for internal compatibility; the context-aware helper is private to the read runtime. The eight-second read budget is unchanged.

Rollback removes only the new functions and grants; it preserves PO, PXK, allocation, Need, Identity, and audit history.

For the context-reuse repair, rollback is a reviewed forward migration restoring the prior public-read definition before removing its private helper. It requires no data backfill or business/history changes. Public signature, grants, comparison precedence and command behavior are unchanged.
