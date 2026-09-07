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

## Response authority

Rows arise only from current Confirmed Need, current allocation contribution lineage, or a current `RELEASED` PXK. Superseded history alone cannot manufacture a row. Captured operational `delivery_location_id` remains authoritative if the School default later changes.

`comparison_status` is derived in order: `NO_PO`, `NO_PXK`, `INGREDIENT_CHANGED`, `MISMATCH`, `OK`. Comparison is exact at `(ingredient_id, unit_id)` grain. `quantity_totals_by_unit[]` groups display totals by Unit; unlike Units are never combined. Quantities remain lossless strings.

Rows return School/date/location identity, PO and PXK identities, `pxk_state`, operational `blockers[]`, `warnings[]`, exact `details[]`, and immutable PXK `history[]`. Comparison and operational currentness are independent: `OK` does not overrule procurement or PXK blockers. No command receipt, event, approval, resolution, or business fact is written.

Rollback removes only the new functions and grants; it preserves PO, PXK, allocation, Need, Identity, and audit history.
