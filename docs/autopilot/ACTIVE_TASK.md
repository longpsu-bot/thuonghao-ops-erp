# Atlas Autopilot — Active Task

Task: ATLAS-AUTH-SCOPE-ALIGNMENT-01
Status: READY FOR IMPLEMENTER after navigator review
Navigator: Terra/read-only role
Implementer: Sol 6.1 when available
Starting main: 7f8397bad56c90aee5c8e57ced7aef9948c98bcb
Atlas Staging migration tip: 107 — atlas_need_generation_effective_composition
OPS v1 / Retool: read-only evidence; no writes.

## Why this task exists

The cutover audit found authorization behavior that conflicts with the documented least-privilege contract. This is a bounded security/contract-alignment task. It must not reopen Procurement business semantics or PXK document semantics.

## Confirmed navigator findings

A. Generated Purchase Review capability mismatch

atlas_api.get_generated_purchase_review is documented to require procurement.school_catering.read but deployed code checks confirmed_need_review.read. The read already filters rows through school_catering_actor_has_scope.

Required correction: align implementation to the documented Procurement read capability. Preserve relational filtering and zero-write behavior.

B. Dispatch/PXK read paths are accidentally GLOBAL-only

The School Dispatch workbench base read and PO/PXK reconciliation call pa_05b_authorize_actor with null scope targets and return immediately on SCOPE_DENIED. Null targets can only match GLOBAL, so relationally scoped actors never reach the existing exact School/location filter.

Required correction: preserve capability denial, but allow SCOPE_DENIED to fall through to the stronger exact relational filter. GLOBAL remains valid.

C. PXK release has the same unreachable exact scope guard

release_school_dispatch_document first performs null-target generic authorization and then school_dispatch_actor_has_scope(actor, school, location).

Required correction: capability denial still fails; exact School/location scope decides non-GLOBAL access. Do not weaken the exact guard.

D. PO release requires atomic document-wide scope

release_school_catering_purchase_order currently has the null-target GLOBAL precheck but no equivalent relational guard.

Product security rule:

A non-GLOBAL actor may release a PO only when the actor has valid relational scope for every School/delivery-location contribution represented by that entire Supplier/date PO.

Partial document scope denies release of the whole PO. Never expose or issue a partially authorized supplier document. GLOBAL remains valid. Existing procurement.school_catering.write capability, currentness, idempotency, immutable release and numbering semantics remain unchanged.

PO read consistency: preserve the existing whole-document visibility rule. A non-GLOBAL actor may see a Supplier/date PO only when the actor is authorized for every School/delivery-location contribution represented by that PO. Do not return a partially redacted PO; hide/deny the whole document instead.

## Mandatory investigation before editing

Trace current-main and deployed call chains for:
- get_generated_purchase_review
- get_school_catering_purchase_orders and base chain
- release_school_catering_purchase_order
- get_school_dispatch_release_workbench and base chain
- release_school_dispatch_document
- get_school_fulfilment_reconciliation_workbench
- pa_05b_authorize_actor
- school_catering_actor_has_scope
- school_dispatch_actor_has_scope

Do not rewrite the generic authorizer globally. Fix only bounded callers/guards proven inconsistent.

## Required tests

1. Generated Purchase Review:
- Procurement-read capability succeeds.
- Confirmed-Need-read without Procurement-read does not gain access.
- relational scope filters rows; out-of-scope rows stay invisible.
- GLOBAL unchanged.

2. PXK workbench and reconciliation:
- scoped actor sees only allowed School/location rows.
- out-of-scope data is invisible.
- capability denial remains denial.
- GLOBAL unchanged.

3. PXK release:
- exact School/location scoped actor succeeds in local/rollback fixture.
- wrong scope and missing capability are denied.
- GLOBAL unchanged.

4. PO read/release:
- actor covering every constituent School/location can read and release the whole PO.
- actor missing any constituent scope cannot see a partial PO and is denied release of the entire PO.
- no partial commit/exposure.
- GLOBAL unchanged.
- replay/currentness/numbering unchanged.

5. Preparation:
- prepare_school_catering_purchase_orders retains its current whole-batch GLOBAL requirement.

## Change boundary

Preferred result: one forward migration, expected migration 108; tests and affected security/contract docs; no frontend product behavior change unless strictly required.

Do not grant everyone GLOBAL, add broad capabilities, change role membership globally, weaken RLS, change PO/PXK grouping, relax Preparation authorization, touch Warehouse, Attendance XLSX, OPS v1 or Retool, or deploy to Staging before Product review.

## Validation

Require focused allowed/denied pgTAP evidence, security/catalog regression, School-catering PO/PXK/reconciliation suites, Procurement regression, Supabase Full Integration, and exact-head CI. Measure any material performance change; do not raise timeouts.

## Delivery

Create one bounded branch and one Draft PR.

Suggested branch: fix/cutover-auth-scope-alignment-01
Suggested PR: fix(atlas): align Procurement and PXK relational authorization

Do not merge or deploy.

## Stop conditions

Stop if the documented relational contract cannot be satisfied without changing PO/PXK business meaning; a fix requires material privilege broadening; whole-PO scope cannot be proven deterministically; or a current-main wrapper supersedes these findings incompatibly.
