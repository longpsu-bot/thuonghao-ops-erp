# OPS-V1-SCHOOL-FULFILMENT-CUTOVER-READINESS-01A

## Scope

Implement one read-only School/date/captured-location PO/PXK reconciliation contract, connected Kho workbench, Identity 1.2.0 preparation, local package certification, and post-rehearsal Staging verifier. No hosted mutation, lifecycle change, supplier cancellation, production activation, or Foundation expansion is authorized.

## Acceptance

- Current School-attributed PO coverage uses exact allocation contribution/supplier interval lineage.
- Only current `RELEASED` PXK lines contribute; superseded history stays visible.
- Status order is `NO_PO`, `NO_PXK`, `INGREDIENT_CHANGED`, `MISMATCH`, `OK`.
- Exact Ingredient + Unit details decide status; mixed Units never collapse into a scalar.
- Procurement/PXK blockers remain separate from comparison status.
- The browser receives one reviewed read route and no reconciliation write action.
- Identity 1.2.0 has exactly 21 capabilities; Foundation remains 1.1.0.
- Local certification proves first install, replay, and rolled-back conflict rejection.
- The read-only verifier audits `2046-09-17` through `2046-09-19` and fails closed.

Focused pgTAP, API, component, package, verifier, RPC, and navigation tests precede certification. Rollback drops only new functions/grants and preserves all operational and audit facts.
