# Atlas Autopilot Mandate

Status: ACTIVE
Approved by Product Owner: 14 October 2026
Execution horizon: current Atlas cutover program through Warehouse design ready for Product approval.

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
