# Decision D-037 — Confirmed Need Save and Release Boundary

**Status:** Accepted

**Date:** 11/08/2026

## Decision

The normal Confirmed Need workflow has exactly two human write actions:

```text
Edit → Save → continue working if needed → Release to ordering
```

`Lưu` records the operator's submitted line decisions atomically, preserves immutable correction/audit evidence, returns authoritative readback, leaves the batch editable, and releases nothing downstream.

`Chuyển sang lên đơn` is the human commitment. One backend command requires the current complete saved batch, performs deterministic complete-batch validation, creates the existing immutable validation and approval evidence internally, records the Planning release atomically, and returns released authoritative readback. It does not select suppliers or create Purchase Handoff, purchase-order, Warehouse, or Dispatch facts.

The backend remains the gatekeeper and workload manager. React must not chain RMVP-05, RMVP-06, and RMVP-07 lifecycle calls or partition a human action into API-sized groups.

## Contract amendment

D-037 amends D-030 and D-031 only at the normal human action boundary. Their exact validation rules, immutable evidence, lifecycle integrity, idempotency, currentness, authorization separation, lineage, transaction safety, and downstream exclusions remain authoritative.

Additive functions are:

- `atlas_api.save_confirmed_needs(jsonb)` — `RMVP-05.v2`, capability `confirmed_need_quantities.confirm`.
- `atlas_api.release_confirmed_needs(jsonb)` — `RMVP-07.v2`, capability `confirmed_need_release.release`.

All RMVP-05/06/07 v1 APIs remain physically callable for compatibility. No production capability binding, hosted Supabase deployment, Retool change, or live OPS mutation is authorized.

## Exports

The Confirmed Need XLSX round-trip is deferred until the workbench read model and final export schema are approved. `Xuất Excel` and `Xuất PDF` remain disabled affordances only; this decision approves no workbook schema, hidden metadata, PDF template, or file-generation infrastructure.
