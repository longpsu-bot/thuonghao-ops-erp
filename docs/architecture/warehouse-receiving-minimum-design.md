# Warehouse receiving — minimum Product review packet

Date: 14 October 2026

Task: ATLAS-WAREHOUSE-RECEIVING-DESIGN-01

Packet status: READY FOR PRODUCT REVIEW

Business choices: PROPOSED — all four groups UNDECIDED

Implementation: NOT AUTHORIZED

This packet asks which single receiving job Atlas should support first. It does not activate the older Warehouse prototype, define a database/API, or approve stock operations. Product must resolve the four groups below and explicitly approve the resulting minimum design before implementation. Merging this packet does not provide that approval.

## Approved authority, historical proposals and completed prerequisites

- [ARCH-002](arch-002-atlas-system-map.md) assigns supplier commitment to Procurement, physical receiving/stock evidence to Warehouse, delivery execution to Dispatch, food-safety decisions to QA and accounting treatment to Finance. [The model mandate](../autopilot/ATLAS-AUTOPILOT.md) requires explicit facts, derived state and generated supporting objects.
- Approved business rules [BR-007/008/012/018/019/045](../business-rules/business-rule-register.md) preserve released history, source trace, stable identity, backend authorization and the independence of School PXK from stock/receiving. They do not select the first receiving job or its confirmation prerequisite.
- Historical proposals: [Warehouse receiving](warehouse-domain-contract.md) and [stock release](warehouse-stock-release-domain-contract.md) still label themselves Draft/pending review. The receiving draft proposes supplier-confirmed commitment as a prerequisite; the stock draft describes controlled-stock outbound release. These are review inputs, not accepted connected persistence authority, and their broad lifecycles are not activated here. Product must decide the minimum slice rather than inherit a draft rule silently.
- Ordinary tasks must work with one authorized Actor. Capability, relational scope and audit remain mandatory, as do already approved exception/override/staff-grant gates. One staff member does not imply automatic GLOBAL access or permission to decide another domain's exception.
- The connected [School Procurement API](../api/school-catering-procurement.md) releases an immutable `RELEASED_TO_SUPPLIER` revision. That means a supplier-facing commitment, not recorded supplier acceptance or Warehouse readiness. Replacement release preserves the old revision and marks the predecessor superseded; zero-allocation cancellation remains a separate unresolved process.
- [PD-03 conformance](pd-03-warehouse-integration-conformance-review.md) retains a pending-review status and describes in-memory behavior. The [fixture](../../src/modules/warehouse/warehouseFixtures.ts) separately invokes `RecordSupplierConfirmation`; [its integration test](../../src/modules/atlas/warehouseIntegration.test.ts) rejects `RELEASED_TO_SUPPLIER` as receiving-ready (`PO_NOT_READY` in the prototype). This demonstrates the prototype's separate confirmation step, not an accepted connected prerequisite. It proves no connected authorization, persistence or concurrency behavior. Its statuses and commands are not a new implementation specification.
- Current migration 109, formal A/B/C and the single released-allocation HTTP read are accepted within their documented bounds. See the [closed read gate](../runbooks/school-fulfilment-cutover-readiness.md#current-read-only-gate--14-october-2026) and [parsed evidence](../testing/evidence/atlas-cutover-released-allocation-read-staging-109.json). These certify existing Planning/Procurement/PXK reads, not Warehouse receiving, production activation or three-sample Preparation performance.

## Four Product choice groups

No option is selected or recommended where the operating facts are unknown. Product may choose a narrower alternative and state its boundaries explicitly.

### 1. First site/job and evidence versus stock — UNDECIDED

Question: Where does the first operator physically receive goods, what decision must that person finish, and does that completion establish inventory?

| Concrete option                                                         | Consequence to approve                                                                                                                                                       |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| One named central receiving site; record physical receipt evidence only | Proves arrival/acceptance against Procurement without establishing available stock, reservations, picks or movements. Subsequent stock creation remains separately approved. |
| One named central receiving site; receipt plus controlled stock         | Requires explicit stock identity, custody location, accepted quantity and hold rules in the first slice. Scope is larger than receipt evidence alone.                        |
| One named School/kitchen direct-delivery job; evidence only             | Product must identify who observes the arrival and which domain owns the resulting evidence. Do not assume central-Warehouse custody or destination delivery confirmation.   |

Needed operating facts: actual first site and receiver, one representative supplier delivery, whether goods enter company custody, whether later work needs an on-hand balance, and the ordinary task's endpoint. No site, staff identity or assignment is created by this packet.

### 2. Supplier confirmation, exact revision and arrivals — UNDECIDED

Question: What Procurement evidence makes that job eligible, and how are several arrivals bound to the correct commitment?

| Concrete option                                                                      | Consequence to approve                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Add a separately approved Procurement confirmation capability before receiving       | Procurement records supplier acceptance against an exact released revision; Warehouse consumes that evidence. Confirmation capture and authority need their own bounded design.                                                                                          |
| Use a controlled external supplier-confirmation record as Procurement-owned evidence | Product must define the evidence reference, who records it, how it binds to the released revision/lines and how changes are handled. A supplier document alone cannot silently become an authoritative confirmation.                                                     |
| Permit receiving without prior supplier confirmation                                 | Requires explicit Product selection of this eligibility rule; assess any actual approved architecture/contract amendment needed. The historical draft's prerequisite alone does not mandate an amendment. PO release still cannot be relabeled as supplier confirmation. |

For the selected option, Product must answer: which exact current released PO revision/line and quantity authority govern first arrival (ordered or separately supplier-confirmed, according to the selected policy); whether multiple partial arrivals are allowed; whether the remainder is merely outstanding or explicitly closed; how excess/duplicate arrivals are recognized; and what happens if a PO is superseded between planning, arrival and commit. Options include blocking new receipt against a superseded revision pending Procurement resolution, or accepting a specifically authorized historical-delivery exception with preserved references. Neither behavior is approved here. No receipt may silently migrate to a successor PO, double-count earlier arrivals or rewrite released Procurement history.

### 3. Observed facts, quantity/Unit and exceptions — UNDECIDED

Question: Which physical observations are mandatory in the chosen job, and which mismatches can the receiver complete versus escalate?

| Concrete option                                               | Consequence to approve                                                                                                                                                                                                      |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Exact ordered-Unit receiving with quantity/condition evidence | Define received, accepted and rejected observations, when an outstanding amount counts as shortage, required document/time/location references and any applicable lot/expiry facts. No implicit conversion or substitution. |
| Include controlled pack/Unit-conversion evidence              | Requires the conversion authority, exact ratio/source, quantity precision and retained original observations before this wider slice can be approved.                                                                       |
| Include substitutes or conditional acceptance                 | Requires explicit Procurement/QA ownership and the exact permitted exception and evidence; matching totals cannot authorize a different Ingredient or food-safety decision.                                                 |

Product must classify shortage, overage, damage, wrong Ingredient, Unit mismatch, missing supplier document, missing lot/expiry and suspected quality issue as blocking, record-and-escalate, or permitted under a named existing approval. Specify required reason/evidence and the owning responder for each included exception. Warehouse records physical facts; Procurement resolves supplier commitment, QA owns food-safety/quality decisions, Finance owns commercial treatment and Dispatch owns delivery execution. Missing facts cannot be inferred as zero, accepted or approved. Numerical identities and any rounding/conversion policy must be agreed before a backend contract is written.

### 4. Commit, correction, capability and scope — UNDECIDED

Question: Which one operator action commits the physical record, what does it authorize downstream, and how is a later mistake corrected?

| Concrete option                                                                        | Consequence to approve                                                                                                                                                   |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| One explicit evidence commit by the authorized receiver                                | One Actor can finish the routine task. Define the immutable observation/source boundary and downstream effect; the action does not imply stock or supplier confirmation. |
| Working evidence followed by an explicit final commitment by the same authorized Actor | Adds a deliberate final review boundary if the real job needs it. It must not become an invented second-person approval or persisted status workflow.                    |
| Receipt commitment also creates stock, if group 1 selects stock                        | Define one atomic outcome and stock evidence; failures cannot leave a receipt claiming an uncreated stock effect or vice versa.                                          |

Product must choose the correction boundary: reasoned successor evidence referencing the original, or an explicit compensating/reversal path where committed effects require it. Released history cannot be silently edited. Also decide which operational capability permits read, record, commit and correction; what exact site/School/customer/location relationships constrain those actions; and who owns any exception approval. This packet assigns no capability names, roles, memberships, scope grants or users. Do not reuse PXK/Procurement authority merely because an existing Actor can call those APIs.

Any future backend design must enforce approved authorization, exact source/currentness and version checks, idempotency, concurrency, atomicity and safe unknown-outcome handling. These are existing platform constraints, not permission to implement them now. An ordinary Actor may perform the selected authorized actions without a handoff; exceptional approval remains with its already approved owner.

## Candidate operator walkthrough — for discussion only

Using one representative delivery selected by Product: the authorized receiver identifies the exact eligible Procurement revision and arrival/site, reviews expected lines, records the actual observations, sees unresolved discrepancies and owning escalation, then performs the chosen explicit commit. Readback explains what was committed and what remains unresolved. A later correction preserves the original evidence and source references. This is a review scenario, not a new list of lifecycle states or API commands.

Before implementation, Product review should walk through one ordinary delivery, a partial second arrival, a wrong Unit/Ingredient, a held quality case, a superseded PO, a duplicate/unknown commit outcome, an out-of-scope Actor and a correction after commitment. The agreed result of each becomes acceptance criteria in the later bounded implementation contract; no test fixture or live receiving fact is created now.

## Approval record required

For each group record the selected option or explicit alternative, actual operating facts, included/excluded exceptions, owner and date. Resolve cross-group dependencies: receipt-only cannot advertise available stock, a partial arrival is not automatically a shortage, and PO release alone is not supplier confirmation. Identify any change to an actual approved contract separately from choosing among historical draft proposals. Then explicitly approve the minimum design and issue a bounded implementation baton. Until that record exists, [the decision remains PROPOSED](../decisions/decision-atlas-warehouse-receiving-minimum.md).

No stock engine, reservation/picking/release, route/driver/trip, destination delivery, QA execution, Finance, supplier-confirmation implementation, database/API/UI, lifecycle changes, staff assignment or hosted/Production write is authorized by this packet. OPS v1/Retool remain read-only evidence. Existing School PXK stays independent of Warehouse stock/receiving.
