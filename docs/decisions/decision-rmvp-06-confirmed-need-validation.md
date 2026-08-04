# Decision RMVP-06 — Confirmed Need Validation

**Status:** Proposed for Product Owner approval

**Date:** 2026-08-04

**Starting baseline:** `9ddc6030c85cc3c076ab74ee0bd1af4f123dcae7`

**Contract:** [RMVP-06 Connected Confirmed Need Validation](../architecture/rmvp-06-confirmed-need-validation-contract.md)

## 1. Decision summary

Atlas will implement complete-batch Confirmed Need validation as one idempotent Planning command after RMVP-05 line decisions and before later approval.

```text
atlas_api.validate_confirmed_needs(request jsonb) returns jsonb
contract: RMVP-06.v1
capability: confirmed_need_validation.validate
runtime: atlas_confirmed_need_review_runtime
scope: active GLOBAL
```

Validation adds append-only attempt, exact line-membership and issue evidence. A blocked result is a completed business evaluation that commits evidence while leaving the batch in its working state and at the same version. A successful result transitions the batch to `VALIDATED` and increments the version once.

## 2. Canonical decision registry

| ID | Question | Alternatives | Selected answer | Rationale | Implementation consequence | Exclusions | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RMVP06-V01 | Exact API surface | One command; preview + command; generic lifecycle endpoint | One command: `validate_confirmed_needs(jsonb)`, `RMVP-06.v1` | Validation is already an authoritative evaluation; a second preview would duplicate the same complete-batch work. | One public RPC and one wrapper/action. | Approval, release and reopen APIs. | Proposed |
| RMVP06-V02 | Capability | `confirmed_need_validation.validate`; `confirmed_need_batch.validate`; `confirmed_need.validate` | `confirmed_need_validation.validate` | Matches the bounded RMVP-05 action-capability vocabulary and names the business capability rather than a table. | One active unbound Planning capability. | Production role/actor binding. | Proposed |
| RMVP06-V03 | Runtime | Reuse review runtime; new validation runtime; generic lifecycle runtime | Reuse `atlas_confirmed_need_review_runtime` | Same aggregate and workbench; no cross-domain authority; avoids role proliferation. | Add only validation-specific grants/policies to the existing runtime. | Approval/release authority. | Proposed |
| RMVP06-V04 | Validation evidence | Batch metadata; attempt only; attempt + lines; attempt + lines + issues | Append-only attempt + exact validation lines + immutable issues, plus one batch pointer | Approval must prove the exact validated line/revision/decision set; batch metadata or digest alone is insufficient. | Three relations and one pointer. | Generic workflow/validation engine; JSON-only lineage. | Proposed |
| RMVP06-V05 | Issue persistence | Recomputed only; mutable current issues; append-only issues | Append-only issues owned by each validation attempt | Preserves blocked history and exact operator evidence without mutable meaning. | Latest-attempt issues shown in workbench; old attempts remain historical. | Mutable global issue table. | Proposed |
| RMVP06-V06 | Failed-validation semantics | Roll back; technical failure; separate commit; completed blocked evaluation | Completed business evaluation with `validation_status = BLOCKED` | The command succeeded in evaluating the batch; blockers are business results, not infrastructure errors. | Commit attempt/lines/issues/receipt/event/audit atomically; no batch transition/version increment. | Autonomous transaction or separate connection. | Proposed |
| RMVP06-V07 | Successful versioning | No increment; increment before attempt; increment atomically | Version `N → N+1` atomically with `VALIDATED` and pointer | Approval must identify an exact validated aggregate version. | Attempt binds evaluated N and resulting N+1. | Line/revision/decision mutation. | Proposed |
| RMVP06-V08 | Rule registry | Broad generic validator; explicit issue codes; UI-only checks | Explicit backend issue-code registry | Deterministic behavior, stable tests and safe operator messages. | Blocking/warning codes are canonical in contract and tests. | Unapproved variance threshold. | Proposed |
| RMVP06-V09 | Lock order | Serializable; ad hoc locks; extend RMVP-05 order | Batch → lines → Units → policies → source → authoritative reread | Protects mutable aggregate pointers and external eligibility while matching the current Confirmed Need family. | Ordered row locks; no serializable isolation. | Cross-domain locks and generic lock framework. | Proposed |
| RMVP06-V10 | Idempotency | Best-effort retry; new attempt on replay; receipt replay | Existing exact request-hash receipt replay | Same repository command convention and deterministic evidence count. | Both validated and blocked results replay exactly. | Generic retry of business failures. | Proposed |
| RMVP06-V11 | Events | Success only; generic validation event; parent event pair | `ConfirmedNeedsValidated` and `ConfirmedNeedValidationFailed` | Already defined by the parent Confirmed Need contract and distinguishes completed outcomes. | One domain event and audit event per completed attempt. | Technical exception event as business evidence. | Proposed |
| RMVP06-V12 | Application surface | Separate screen; new read API; extend current workbench | Extend existing RMVP-05 workbench and tab | Validation is the next action on the same aggregate and operator context. | Add action, latest outcome, issues and read-only state. | Approval/release controls. | Proposed |
| RMVP06-V13 | Validation invalidation | Mutate validation; delete old evidence; explicit future transition | Preserve old attempt; later working-state transition clears current pointer and advances version | Historical validation must remain explainable; approval must reject stale evidence. | RMVP-06B prepares the pointer/invariants only. | Reopen/rematerialization implementation. | Proposed |
| RMVP06-V14 | Direct-wholesale compatibility | Apply to both source kinds; alter PA-05D; school catering only | `NEED_GENERATION` only; PA-05D unchanged | Current objective is the connected school-catering path, and wholesale has an existing bounded contract. | Compatibility assertions remain mandatory. | Wholesale refactor. | Proposed |
| RMVP06-V15 | Test architecture | Only focused tests; only full suite; two-tier | Focused draft smoke plus all-suite/full journey certification | Keeps draft feedback affordable while preserving merge authority. | New focused pgTAP and browser journey; Full Integration remains merge gate. | Frozen assertion plan before implementation. | Proposed |

## 3. Product Owner approval requested

Approval of this document means acceptance of the following business meaning:

1. Validation is complete-batch, not line-by-line or partial.
2. `BLOCKED` means the evaluation completed but the batch is not eligible for approval.
3. Warnings may remain after successful validation.
4. Validation does not approve or release demand.
5. Validation evidence is immutable and separately traceable from approval evidence.
6. Successful validation increments the batch version once.
7. Blocked validation does not increment the batch version.
8. Approval must later consume the exact current successful validation attempt.
9. The existing Confirmed Need review runtime is reused.
10. No production role receives the new capability in this slice.

## 4. Deferred decisions

The following remain outside RMVP-06:

- approval capability/runtime and snapshot execution for connected school catering;
- release capability/runtime and released-snapshot binding;
- reopen behavior;
- corrected rematerialization after validation/approval/release;
- CMD-03 school-catering Purchase Handoff;
- production warning thresholds;
- production capability bindings;
- hosted deployment and seed data.

## 5. Supabase and legacy boundary

RMVP-06 is repository-only.

The hosted OPS Supabase project remains legacy production evidence and is not a deployment target for this task. Retool remains workflow evidence only. No Retool query, resource, page or application is changed.
