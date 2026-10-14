# Atlas Autopilot — Active Task

Task: ATLAS-WAREHOUSE-RECEIVING-DESIGN-01
Status: READY FOR PRODUCT REVIEW — documentation only; all four Product choices undecided
Navigator: Terra/read-only role
Implementer: Sol 6.1
Starting main: f6686c7952024b499fcd3499cbcb38948ab15a5d
Atlas Staging: rnzxmxiiqgtdevzregff — migration 109; no hosted action in this task
OPS v1 / Retool / Production: no writes or commitments

## Previous read gate accepted — 14 October 2026

[PR #383](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/383) merged at starting main with a tree identical to reviewed source `64491061df79bf9c8349d5f397d57c06a8fe9edb`. Source Frontend 38568664899 and Full Integration 38568760358 passed. Root's protected [actual HTTP read 38570792340](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38570792340) passed against deployed business `8e68c2ce2cf766279d020210e9b53b457048db22` using verifier starting main: 236 distinct families, 4,973.201109 ms, full actual-row PostgreSQL MD5 `48e433c45fac665d873103542408a484`, unchanged source/receipt/audit fact digest `d55edbee74200aa3e02e8fc94ca8787d` (matching acceptance 105).

Root independently confirmed 36 probe-relation checks / zero probes, 17 real Draft POs and unchanged fingerprint `cefbff23b30cbc15dac0b890a956d884`. This is one successful hosted observation, not a load test or three-sample performance certification. Main Frontend 38570729098 and Full Integration 38570728987 were still running at handoff; no pass is asserted here. The formal A/B/C gate 38566354791 and 109's 48-case rollback acceptance remain complete; do not rerun them or rewrite historical 108/109 evidence.

## Authorized document packet

Prepare the smallest one-operator receiving design for Product review under the active Autopilot horizon. First record this baton and the completed read gate in a separate commit, before design files. Approved constraints and existing authority must be distinguished from proposed choices. All four Product groups remain explicitly UNDECIDED:

1. First receiving site/job and physical receipt evidence versus stock creation.
2. Procurement supplier-confirmation gap, exact current released revision, partial arrivals and superseded orders.
3. Observed physical facts, quantity/Unit evidence and owning exception rules.
4. Commit/correction boundary, capability and relational scope.

Offer concrete alternatives, consequences and questions without selecting business policy where operating facts are unknown. Ordinary work must be possible for one authorized Actor; capabilities, scope, audit and approved exception owners remain mandatory. `RELEASED_TO_SUPPLIER` does not establish supplier confirmation or `READY_FOR_WAREHOUSE_RECEIVING`. The in-memory prototype is exploratory evidence only, not connected authority or a lifecycle to copy.

## Allowed files and checks

- This baton.
- `docs/runbooks/school-fulfilment-cutover-readiness.md`: close the actual read gate.
- `docs/testing/evidence/atlas-cutover-released-allocation-read-staging-109.json`: durable parsed report from Root's saved evidence.
- `docs/architecture/warehouse-receiving-minimum-design.md`.
- `docs/decisions/decision-atlas-warehouse-receiving-minimum.md`.
- `docs/decisions/decision-register.md`: PROPOSED link only.
- `docs/architecture/roadmap.md`: Warehouse design gate pointer only.

Read AGENTS, mandate, README, vision, business-rule/decision registers and the existing Warehouse receiving/stock-release contracts, PD-03 conformance review, ARCH-002, roadmap, School Procurement API and fixture prototype. Run focused formatting, whitespace and local-link validation only; no tests for prose and no new test framework.

## Delivery and hard stop

Fresh bounded branch from verified latest main, Draft PR and fixed-SHA Terra audit; Root owns routine integration. The packet may become READY FOR PRODUCT REVIEW, while every business choice remains PROPOSED. Final explicit Warehouse Product design approval is a HARD STOP before any implementation.

No lifecycle/status machinery, role grants, staff assignments, database/API/UI/prototype edits, hosted action, fixture creation, Production/v1/Retool write or real commitment is authorized. Preserve released history, existing drafts and exception ownership. No Warehouse backend or connected UI work follows automatically from merging this documentation.

## Packet and focused verification

The [minimum design](../architecture/warehouse-receiving-minimum-design.md) and [PROPOSED decision](../decisions/decision-atlas-warehouse-receiving-minimum.md) separate approved authority from historical Draft Warehouse contracts and in-memory prototype evidence. No Product option is selected. The [closed read gate](../runbooks/school-fulfilment-cutover-readiness.md) links the durable parsed report, which equals Root's saved report. Focused formatting, whitespace and local-link/anchor checks pass; no tests or hosted actions were needed for this prose-only task. Fixed-SHA Terra audit and PR CI remain integration gates, not Warehouse business-design approval.
