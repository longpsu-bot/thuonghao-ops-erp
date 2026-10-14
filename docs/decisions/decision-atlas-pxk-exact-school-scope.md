# PXK and reconciliation SCHOOL scope matches exact School identity

**Decision:** ATLAS-PXK-EXACT-SCHOOL-SCOPE-01

**Status:** Product-approved on 14 October 2026; bounded implementation authorized

**Baseline:** main `fbafca0cb404231e5930df079703f869fb9b29fb`; Atlas Staging migration 108

## Product decision

The Product Owner selected exact-School authorization for PXK and reconciliation and clarified that there is one staff member per task. A `SCHOOL` scope authorizes only that School ID. Sharing the scoped School's default delivery location does not authorize another School.

Capability and scope are separate requirements. PXK reads and reconciliation still require `dispatch.school_release.read`; release still requires `dispatch.school_release.release`. One Actor may hold both capabilities and explicit scopes for several Schools and perform those authorized actions for each School. This introduces no second-person, maker/checker, handoff, new role or new capability requirement. It grants no actual staff membership or automatic `GLOBAL` scope.

Explicit `DELIVERY_LOCATION`, `CUSTOMER` and `GLOBAL` scopes retain their existing semantics. Customer coverage continues to derive from the target delivery location's Customer; this decision does not introduce a new ownership policy. All scope kinds retain active status and effective-time boundaries.

## Bounded implementation

One forward migration after 108 changes only the existing private Dispatch helper's `SCHOOL` interpretation and routes PXK base-workbench and reconciliation read filters through that helper. PXK release already calls it. Preserve its signature, owner, security-definer posture, empty search path, runtime grants, browser restrictions and RLS behavior.

The generic `school_catering_actor_has_scope` and `pa_05b_authorize_actor`, whole-PO authorization and Preparation's `GLOBAL` requirement remain unchanged. There are no new public functions, relations, roles, capabilities, scope kinds, grants or RLS policies. An unexpected permission gap requires review; it does not authorize broader privileges.

## Historical evidence and compatibility

Exact School identity continues to authorize that School's captured operational location after its master default changes. A default change never confers another School's scope. Released PXK content, captured location, lineage, number, issuer facts and history remain immutable; read/release scope is checked against the target School/location. Existing explicit location/customer/global operators retain their coverage.

This decision amends the inherited Dispatch compatibility limitation in [ATLAS-AUTH-SCOPE-ALIGNMENT-01](decision-atlas-cutover-auth-scope-alignment.md). Migration 108's acceptance remains historical evidence of its approved boundary; it is not rewritten as proof of this later policy.

## Validation and rollout

Authenticated rollback RPC tests must first reproduce School A accessing School B at shared location L, then prove A-only read/reconciliation/release, multi-School single-Actor operation, missing capabilities, explicit L/Customer/GLOBAL controls, wrong location/cross-Customer denial, inactive/revoked/expired/future scopes, captured-location stability, zero writes on denial and unchanged replay/numbering/currentness/successor behavior. Catalog counts, grants and security posture remain exact.

Implementation is reviewed in one Draft PR with focused local tests and exact-head CI. No hosted probe/deployment, OPS v1/Retool write, Production use, real supplier/PXK commitment or Warehouse implementation is authorized by this implementation task. Hosted rollout requires the separately reviewed protected Staging plan. Rollback after deployment is a reviewed forward migration preserving evidence and least privilege, not restoration of cross-School default-location access.
