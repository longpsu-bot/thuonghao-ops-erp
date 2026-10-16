# Atlas Autopilot Mandate

Status: ACTIVE
Approved by Product Owner: 14 October 2026
Execution horizon: preserve the failed bounded Need trial in Draft #388; stop pending an explicitly scoped next task. Warehouse remains paused.

## Bounded trial verdict — 16 October 2026

**FAIL / STOP — investigational preservation only.** Candidate `dd3d3207` is applied in migration `f6d56125`; the one historical helper body changes, with all 497 metadata/ACL entries unchanged. Old/new 29 rowset properties agree and 588 focused assertions pass. The single unchanged strict31 run fails at the first Preparation 20-second limit: **0/8 completed cycles, 0/20 final assertions**, full rollback. The Handoff-lock interruption frame is not cost attribution; the bottleneck remains insufficiently isolated and no full-command performance gain is demonstrated. No further execution/profile/optimization or acceptance retry is authorized. Preserve Draft #388 against main, all earlier evidence/DBs and the candidate as investigational work. A future bounded transaction-wide Preparation repeated-call/lock-path diagnosis is an actionable handoff, not autoexecution. [Current validation](../testing/operator-confirmed-need-correction-c-01-validation.md).

UI #392 is separately preserved at `34c85ea87a61fdcfedf33d08e38a4715e9eaeea5`; combined integration is NOT performed. Only ConfirmedNeedWorkbench and ProcurementOrdersStage overlap in production. Preserve the compact UI/toolbar/PO exports and guards in any future approved semantic integration; no whole-file overwrite, PR-base change or migration reorder. #385–#387 remain parked, Warehouse paused, hosted read-only and OPSv1/Retool NO-WRITE. No merge/deployment.

## Owner bounded remediation — 16 October 2026

The Owner now explicitly authorizes one delivery-focused Need correction trial after the UX checkpoint. Preserve PR #392 at `4600c3476fc98f607e60daf0ef4ce286bb5321ea` and work on the original Draft #388 branch from `49375b4e`. This supersedes the earlier dd3 cancellation for this trial only. Apply exactly reviewed helper candidate `dd3d320775996e0d3077b9e449abfda1979b3762fc97a07c02b5c59fde12c3d4` to `confirmed_need_historical_validation_complete(uuid,uuid)`; signature, Review owner, STABLE/SECDEF/empty path and ACL remain. No other runtime body or UI change.

Acceptance: meaningful old/new controlled-rowset property parity, genuine captured historical TRUE, unchanged current/history/02b/null/count/SUM semantics; fresh task-owned exact original 109 migrations plus the whole amended C file atomically, exact global/schema/function metadata parity and only one body delta; focused affected suites; then ONE unchanged genuine 250-family/eight-cycle/all-20 strict run at existing 8s/20s/1s entry and disclosed nested 5s limits, timed guards and one existing 13-relation ANALYZE prerequisite. No new profiling, fixture weakening, timeout increase or optimization chain. Stop at the first final scale failure and report PASS/FAIL with root cause and actionable handoff. At most two targeted repairs for the same development failure; repeated failure escalates.

Standing Owner rules: delivery and measurable business value; bounded scope/acceptance/completion; mandatory failure stops; focused development separate from certification; preserve incomplete PRs/evidence; explicit PASS/FAIL/BLOCKED accountability. Security/Product hard stops remain. Keep #388 Draft, #385–#387 parked, Warehouse paused, hosted read-only and OPSv1/Retool NO-WRITE. No merge/deploy. Any later local combined UI preview must retain the compact C workbenches/new Need toolbar and both separate PR reviews; do not repoint PR #388 to the feature branch or overwrite #392 UI.

## Control plane

GitHub repository longpsu-bot/thuonghao-ops-erp is the shared handoff surface between the OPS Product/Architecture conversation and the local Atlas implementation checkout.

Do not rely on chat memory as implementation authority. Read repository authority first.

Normal cycle:

Terra navigation/investigation
→ Product/Architecture decision
→ Sol 6.1 implementation
→ Terra read-only audit
→ Product review
→ exact-head CI
→ merge
→ Atlas Staging deploy/acceptance where applicable
→ next ACTIVE_TASK

If Terra or Sol 6.1 are unavailable by name, preserve the same role separation: navigator is read-only; implementer owns bounded code changes.

## Roles

OPS Product/Architecture may sequence work, interpret approved contracts, review GitHub/Staging/v1/Retool, approve bounded implementation, merge green reviewed PRs, deploy approved forward migrations to Atlas Staging, run bounded acceptance, and advance routine tasks without repeated micro-approval.

Terra is read-only. It may inspect repository, Supabase, Retool and evidence; trace contracts/call graphs; identify blast radius; challenge assumptions; and audit Sol output. Terra must not edit files, create migrations, push, deploy, or invent Product policy.

Sol 6.1 is the preferred implementer. It may create a bounded task branch, edit code/migrations/tests/docs, run focused validation, push, and open a Draft PR. It must stop on a new business-policy choice, destructive migration need, materially broader architecture contradiction, material privilege broadening, or production-data correction.

## One staff member per operational task

`ONE_STAFF_PER_OPERATIONAL_TASK` is the Product Owner's operating constraint recorded on 14 October 2026. Ordinary flows must work with one authorized Actor per task; that Actor may hold the existing task capabilities and explicit scopes for multiple Schools. Capability, relational scope, immutable evidence and audit attribution remain mandatory. This fact does not assign users, grant privileges or automatically grant GLOBAL scope, and does not waive already approved exception/override approvals, separation rules or staff-grant review gates. Do not invent a second-person or maker/checker step for an ordinary task.

## Hard Product stops

Stop for explicit Product Owner approval before:

1. introducing or changing business meaning where more than one reasonable policy exists;
2. creating paid or Production infrastructure;
3. first production write-ownership transfer from OPS v1 to Atlas;
4. issuing irreversible real supplier PO/PXK commitments;
5. destructive Production data correction/deletion;
6. materially broadening operator/security authority;
7. final Warehouse business-design approval before implementation.

Routine GitHub, CI, Staging migration, rollback-only acceptance, documentation and bounded defect correction are within the standing mandate.

## Environment boundary

Atlas Staging: rnzxmxiiqgtdevzregff — test/rehearsal target; controlled writes permitted under an approved task.
OPS v1 Supabase: qnthofvccilhnefdcxnz — hard no-write from Atlas tasks.
Retool — operational continuity/evidence only; no mutation unless separately authorized.
Atlas Production — not yet an approved target. Creation is a hard stop.

## Governing architecture

Use OPS_SYSTEM_MAP v1.0 and FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.

Do not add persisted lifecycle/status machinery where state is derivable. Do not create a second business authority merely to simplify a consumer.

## Active-task protocol

Before implementation, read:

1. AGENTS.md
2. docs/autopilot/ATLAS-AUTOPILOT.md
3. docs/autopilot/ACTIVE_TASK.md
4. the contracts/decisions named by the active task

ACTIVE_TASK.md is the bounded implementation baton. Re-read it after main moves. Historical reports remain evidence, not current authority.
