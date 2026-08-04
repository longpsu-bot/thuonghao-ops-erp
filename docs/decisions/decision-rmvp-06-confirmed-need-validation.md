# Decision RMVP-06 — Confirmed Need Validation

**Status:** Accepted

**Approved:** 2026-08-04

**Approved baseline:** `9ddc6030c85cc3c076ab74ee0bd1af4f123dcae7`

**Contract:** [RMVP-06 Connected Confirmed Need Validation](../architecture/rmvp-06-confirmed-need-validation-contract.md)

## 1. Decision summary

Atlas will implement complete-batch Confirmed Need validation as one idempotent Planning command after RMVP-05 line decisions and before later approval.

```text
atlas_api.validate_confirmed_needs(request jsonb) returns jsonb
contract: RMVP-06.v1
capability: confirmed_need_validation.validate
runtime: atlas_confirmed_need_review_runtime
scope: active GLOBAL
source family: NEED_GENERATION only
```

Validation adds append-only attempts, one observation row for every current stable line, and immutable issue evidence. A blocked result is a completed business evaluation that commits observations and issues while leaving the batch in its working state and at the same version. A successful result requires complete non-null exact bindings, transitions the batch to `VALIDATED`, and increments the version once.

## 2. Canonical decision registry

| ID | Question | Alternatives | Selected answer | Rationale | Implementation consequence | Exclusions | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RMVP06-V01 | Exact API surface | One command; preview + command; generic lifecycle endpoint | One command: `validate_confirmed_needs(jsonb)`, `RMVP-06.v1` | Validation is already an authoritative evaluation; a second preview would duplicate the complete-batch work. | One public RPC and one wrapper/action. | Approval, release, and reopen APIs. | Accepted |
| RMVP06-V02 | Capability | `confirmed_need_validation.validate`; `confirmed_need_batch.validate`; `confirmed_need.validate` | `confirmed_need_validation.validate` | Names the bounded business capability and matches RMVP-05 action-capability vocabulary. | One active unbound Planning capability. | Production role/Actor binding. | Accepted |
| RMVP06-V03 | Runtime | Reuse review runtime; new validation runtime; generic lifecycle runtime | Reuse `atlas_confirmed_need_review_runtime` | Same aggregate and workbench, with no cross-domain authority; avoids unjustified role proliferation. | Add only validation-specific grants and policies to the existing runtime. | Approval and release authority. | Accepted |
| RMVP06-V04 | Validation evidence | Batch metadata; attempt only; attempt + lines; attempt + lines + issues | Append-only attempt + complete line observations + immutable issues, plus one successful-validation pointer | Approval must prove the exact validated set, while blocked attempts must also represent missing or ambiguous revision, decision, policy, and source facts. | Three relations and one pointer. Every attempt has one observation per current stable line. Observed bindings may be nullable for `BLOCKED`; `VALIDATED` requires a complete non-null exact binding set under outcome-dependent constraints. | Generic workflow/validation engine; JSON-only lineage. | Accepted |
| RMVP06-V05 | Issue persistence | Recomputed only; mutable current issues; append-only issues | Append-only issues owned by each validation attempt | Preserves blocked history and exact operator evidence without mutable meaning. | Latest-attempt issues are shown in the workbench; old attempts remain historical. | Mutable global issue table. | Accepted |
| RMVP06-V06 | Failed-validation semantics | Roll back; technical failure; separate commit; completed blocked evaluation | Completed business evaluation with `validation_status = BLOCKED` | The command succeeded in evaluating the batch; blockers are business results, not infrastructure errors. | Commit attempt, observations, issues, receipt, event, and audit atomically; no lifecycle transition or version increment. | Autonomous transaction or separate connection. | Accepted |
| RMVP06-V07 | Successful versioning | No increment; increment before attempt; increment atomically | Version `N → N+1` atomically with `VALIDATED` and pointer | Approval must identify an exact validated aggregate version. | Attempt binds evaluated N and resulting N+1. | Line, revision, or decision mutation. | Accepted |
| RMVP06-V08 | Rule registry | Broad generic validator; explicit issue codes; UI-only checks | Explicit backend issue-code registry | Deterministic behavior, stable tests, and safe operator messages. | Blocking and warning codes are canonical in the contract and tests. | Unapproved variance threshold. | Accepted |
| RMVP06-V09 | Lock order | Serializable; ad hoc locks; extend RMVP-05 order | Batch → stable lines → Units → policies → source → authoritative reread | Protects mutable aggregate pointers and external eligibility while matching the Confirmed Need family. | Ordered row locks; no serializable isolation. | Cross-domain locks and generic lock framework. | Accepted |
| RMVP06-V10 | Idempotency | Best-effort retry; new attempt on replay; receipt replay | Existing exact request-hash receipt replay | Matches repository command conventions and deterministic evidence counts. | Both validated and blocked outcomes replay exactly. | Generic retry of business failures. | Accepted |
| RMVP06-V11 | Events | Success only; generic validation event; parent event pair | `ConfirmedNeedsValidated` and `ConfirmedNeedValidationFailed` | Already defined by the parent Confirmed Need contract and distinguishes completed outcomes. | One domain event and audit event per completed attempt. | Technical exception event as business evidence. | Accepted |
| RMVP06-V12 | Application surface | Separate screen; new read API; extend current workbench | Extend the existing RMVP-05 workbench and tab | Validation is the next action on the same aggregate and operator context. | Add action, latest outcome, issues, and read-only state. | Approval and release controls. | Accepted |
| RMVP06-V13 | Validation invalidation | Mutate validation; delete old evidence; explicit future transition | Preserve old attempt; a later working-state transition clears the current pointer and advances version | Historical validation must remain explainable; approval must reject stale evidence. | RMVP-06B prepares the pointer and invariants only. | Reopen and rematerialization implementation. | Accepted |
| RMVP06-V14 | Direct-wholesale compatibility | Apply to both source kinds; alter PA-05D; school catering only | `NEED_GENERATION` only; PA-05D unchanged | Current objective is the connected school-catering path, while wholesale has an existing bounded contract. | Compatibility assertions remain mandatory. | Wholesale refactor. | Accepted |
| RMVP06-V15 | Test architecture | Only focused tests; only full suite; two-tier | Focused draft smoke plus all-suite/full-journey certification | Keeps draft feedback economical while preserving merge authority. | New focused pgTAP and browser journey; Full Integration remains the implementation merge gate. | Frozen assertion plan before implementation. | Accepted |

## 3. Product Owner approval

Approval records the following business meaning:

1. Validation is complete-batch, not line-by-line or partial.
2. `BLOCKED` means the evaluation completed but the batch is not eligible for approval.
3. Every completed attempt observes every current stable line.
4. Blocked observations may contain nullable revision, decision, policy, source, and quantity bindings when those facts are missing or ambiguous.
5. A successful validation requires complete non-null exact bindings for every observed line.
6. Warnings may remain after successful validation.
7. Validation does not approve or release demand.
8. Validation evidence is immutable and separately traceable from approval evidence.
9. Successful validation increments the batch version once.
10. Blocked validation does not increment the batch version.
11. Approval must later consume the exact current successful validation attempt.
12. The existing Confirmed Need review runtime is reused.
13. No production role receives the new capability in this slice.

## 4. Deferred decisions

The following remain outside RMVP-06:

- approval capability/runtime and snapshot execution for connected school catering;
- release capability/runtime and released-snapshot binding;
- reopen behavior;
- corrected rematerialization after validation, approval, or release;
- CMD-03 school-catering Purchase Handoff;
- production warning thresholds;
- production capability bindings;
- hosted deployment and seed data.

## 5. Supabase and legacy boundary

RMVP-06 remains repository-only until a separately reviewed implementation and later deployment decision.

The hosted OPS Supabase project is legacy production evidence and is not a deployment target for RMVP-06A or RMVP-06B. Retool remains workflow evidence only. No Retool query, resource, page, or application is changed by this decision.
