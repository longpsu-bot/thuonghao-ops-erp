# Proposed decision — minimum Warehouse receiving

Date: 14 October 2026

Task: ATLAS-WAREHOUSE-RECEIVING-DESIGN-01

Status: PROPOSED — READY FOR PRODUCT REVIEW; not accepted

Product approval: NOT RECORDED

Implementation: HARD STOP

## Purpose and authority

The [minimum receiving packet](../architecture/warehouse-receiving-minimum-design.md) turns the next [roadmap](../architecture/roadmap.md#warehouse) step into four concrete Product choice groups. Approved authority remains ARCH-002, business rules, the current connected Procurement API and the active Autopilot mandate. The older Warehouse receiving/stock-release contracts retain Draft/pending-review labels; PD-03 conformance and fixtures demonstrate in-memory behavior, not approved connected persistence. This proposal does not elevate those drafts, amend accepted contracts or approve new business policy.

Existing approved constraints are one authorized Actor per ordinary task, mandatory backend capability/scope/audit, explicit domain ownership and preservation of released history. Existing exception/override/staff-grant gates remain in force. Current School PXK does not require stock or receiving. Connected `RELEASED_TO_SUPPLIER` is not evidence of supplier acceptance or Warehouse readiness; the older in-memory fixture is not connected authority.

## Product selection record

| Group                              | Required Product selection                                                                                                               | Current result |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| 1. First job and effect            | Name the first site/custody/receiver job and choose receipt evidence only or receipt plus stock.                                         | UNDECIDED      |
| 2. Procurement eligibility         | Resolve supplier-confirmation evidence/authority, exact current released revision, partial/repeated arrivals and superseded commitments. | UNDECIDED      |
| 3. Observed facts and exceptions   | Define required quantities/Unit/evidence, discrepancy treatment and owning exception approvals.                                          | UNDECIDED      |
| 4. Commit and correction authority | Choose the explicit commitment/effect and history-preserving correction boundary; specify capability and relational scope.               | UNDECIDED      |

The packet provides alternatives and consequences without selecting operating policy. Approval must record the chosen alternative, actual facts, included/excluded exceptions, owner and date for every group. Assess and record any actual approved architecture/contract amendment required; diverging from a historical draft alone is not an automatic amendment requirement. Merging this proposal, green CI or completing the preceding read certification does not constitute business-design approval.

## Consequences while proposed

Only documentation and review are authorized. No new statuses, persisted workflow, capability/role/scope grant, staff assignment, database/API/UI/prototype modification, live fixture, real commitment or hosted/Production/v1/Retool write follows. Existing historical drafts and 108/109 acceptance evidence remain unchanged. Warehouse implementation requires final explicit Product approval and a separately bounded implementation baton.
