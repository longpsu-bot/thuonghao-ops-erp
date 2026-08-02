# Atlas Roadmap

**Purpose:** A concise view of delivery order and current status. Contracts and GitHub issues remain the detailed source of scope.

## Status legend

- ✅ Complete or merged baseline
- 🟡 In progress
- ⬜ Not started
- ↘️ Deferred from MVP sequence

## Foundation

- ✅ Repository governance and workspace guard
- ✅ ARCH-001 — OPS ERP Business Architecture
- ✅ ARCH-002 — Atlas System Map
- ✅ Atlas Vision
- ✅ Contract-first and bounded-PR workflow

## PD-01 — Planning

Goal: transform controlled customer and internal inputs into approved demand released to Procurement.

- ✅ Weekly Menu contract and foundation
- ✅ Attendance contract and foundation
- ✅ RMVP-03B Planning Input Readiness — merged and complete through PR #165 at `b7b44923769dc690a51871365a8ef81eed396946`. The bounded delivery has one migration, four APIs, one unbound capability, 20 private helpers, 12 policies, an 84-assertion focused database suite, an exact 67-function browser registry, and 47 focused frontend tests; relation/view/role/runtime/scope/state/trigger and downstream deltas remain zero; [architecture](rmvp-03b-connected-planning-input-readiness.md), [accepted decision registry](../decisions/decision-rmvp-03b-connected-planning-input-readiness.md), [API contract](../api/rmvp-03b-planning-input-readiness.md), and [implementation record](../implementation-tasks/TASK-RMVP-03B-connected-planning-input-readiness-implementation.md)
- ✅ Need Generation contract
- ✅ Need Generation foundation
- ✅ Confirmed Need contract
- ✅ Confirmed Need foundation
- ✅ Purchase Handoff contract
- ✅ Purchase Handoff foundation
- ✅ Planning integration and operator-workflow review
- ✅ RMVP-03A connected Weekly Menu and Attendance — explicit-week preview, checksum-bound draft replacement, stable rows, exact approval snapshots, reasoned reopen/reapproval, and read-only readiness comparison; no downstream Planning write
- ✅ PANTRY-01 Planning-owned Pantry source contract — merged by PR #159 as `dd1c20d13af98cd7804436c54e469f5856d06326`; defines explicit `no_additions_confirmed` zero-line snapshots, server-resolved Ingredient purchase Unit, immutable approval snapshots, and separation from Wholesale, Warehouse and fulfilment routing
- ✅ PANTRY-REF-01 mandatory reference-data dependency — merged by PR #160 on baseline `63c53f3326a6667c1de7004ebda4f24491d06afc`; [contract](pantry-ref-01-reference-data-contract.md) and [decision](../decisions/decision-pantry-ref-01-reference-data.md)
- ✅ PANTRY-02 connected Pantry source — merged through PR #161 at `fbcb0016245028f8e845fe79a1d568e92166ce52` with exactly five private relations, six APIs, one capability, zero roles/scope kinds, server-derived Location/Unit, stable complete replacement, exact positive/zero approval snapshots, and a connected Vietnamese Pantry tab; [architecture](pantry-02-connected-pantry-source.md), [API](../api/pantry-02-source.md), and [implementation record](../implementation-tasks/TASK-PANTRY-02-connected-pantry-source.md)
- ✅ PANTRY-RDY-01 Pantry readiness-binding amendment — Product Owner-approved on 2026-07-29 and present in approved baseline `9e3f7d6afce1d66757c939645f8d45f99210f20b`; requires exact current approved Weekly Menu, Attendance, and Pantry snapshots for new readiness/request decisions, including explicit zero-line Pantry evidence, without renaming RMVP-03B; [amendment](pantry-rdy-01-planning-input-readiness-amendment.md), [decision](../decisions/decision-pantry-rdy-01-planning-input-readiness.md), and [task](../implementation-tasks/TASK-PANTRY-RDY-01-readiness-binding-contract.md)
- ✅ PANTRY-RDY-02 readiness persistence amendment — merged through PR #163 as `70c380f49c148a1207574aabc5aefcb44cf30074`; one migration, zero new relations/APIs/functions/triggers/capabilities/roles/scope kinds/policies/grants/source triggers, and the same three readiness suites at exact plans `36/59/57`; [decision](../decisions/decision-pantry-rdy-02-readiness-persistence.md) and [task](../implementation-tasks/TASK-PANTRY-RDY-02-readiness-persistence.md)
- 🟡 PANTRY-NG-01 direct Pantry Need Generation contract — accepted product and architecture direction under D-028; [amendment](pantry-ng-01-need-generation-direct-ingredient-amendment.md), [canonical decision](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md), and [task record](../implementation-tasks/TASK-PANTRY-NG-01-need-generation-direct-ingredient-amendment.md). PANTRY-NG-02 backend persistence, integrity, existing CMD-15 compatibility, and exact-head GitHub validation are complete in draft PR #167 on exact baseline `249361bc0c4005e2c9a05e7b84a8468dd0ec4956`; see the [implementation record](../implementation-tasks/TASK-PANTRY-NG-02-direct-ingredient-persistence-materialization.md). Connected Need Generation commands/workbench, React, deployment, Pantry fulfilment, Procurement, Warehouse, and Dispatch remain incomplete.
- 🟡 PA-06D quantity truth, operational precision, rounding, rebalancing, and write-fidelity documentation — [contract](pa-06d-quantity-truth-rounding-rebalancing-contract.md); implementation and unresolved product decisions remain unapproved
- 🟡 PA-06E Confirmed Need review, adjustment, revision, and source-correction documentation — [contract](pa-06e-confirmed-need-review-adjustment-revision-contract.md) and [decision](../decisions/decision-pa-06e-confirmed-need-source-correction.md); implementation and pending product decisions remain unapproved
- ✅ PA-06E-H0C/CMD-15 Confirmed Need materialization — merged by PR #144 on exact baseline `5987f1fc9711b7bde094a610e598ff92d71e850d`; [decision](../decisions/decision-pa-06e-h0c-materialization-command-contract.md) and [implementation record](../implementation-tasks/TASK-PA-06E-H0Cb-confirmed-need-materialization-command.md)
- ✅ PA-06E-H1A0 Planning quantity-policy product contract — H1A-P01 through H1A-P10 approved by the product owner on 2026-07-23; [canonical decision registry](../decisions/decision-pa-06e-h1a-planning-quantity-policy.md)
- ✅ PLATFORM-PRE-H1A current test-catalog consolidation — merged by PR #148; the canonical suite remains `plan(22)` and the historical-suite ownership boundary is established; [implementation record](../implementation-tasks/TASK-PLATFORM-PRE-H1A-current-test-catalog-consolidation.md)
- ✅ PA-06E-H1A SQL persistence — merged by PR #150 as `0ba89ff8c3434979eb3e8897a6bcf9bb2171c51f`; exactly two private relations, three private functions, and three triggers; zero role/capability/runtime/policy/grant/API/PA-06A/view/writer/seed delta; 27 registered suites / 1,648 TAP results; [implementation record](../implementation-tasks/TASK-PA-06E-H1A-planning-quantity-policy-persistence.md)
- ✅ PA-06E-H1B1A policy-bound line-decision contract — H1B1-P01 through H1B1-P12 approved as corrected on 2026-07-26; [architecture contract](pa-06e-h1b1-policy-bound-line-decision-contract.md) and [canonical decision registry](../decisions/decision-pa-06e-h1b1-policy-bound-line-decision-evidence.md)
- 🟡 PA-06E-H1B1 policy-bound line-decision persistence — implemented under Issue #153 and pending independent PR review/exact-head CI; exactly one private relation, one nullable pointer, three private functions, six triggers, and 30 registered suites / 1,808 TAP assertions; zero writer/API/runtime grant; [implementation record](../implementation-tasks/TASK-PA-06E-H1B1-policy-bound-line-decision-persistence.md)
- ⬜ PA-06E-H1B2 authorized review/preview/confirmation — unapproved
- ⬜ Hosted Supabase action for this path — unapproved
- ⬜ Retool change for this path — unapproved
- ⬜ Production Planning policy seed — unapproved
- ⬜ React connection for this path — unapproved

Planning completion boundary:

```text
Weekly Menu / Attendance / Pantry / Other controlled sources
→ Planning Input Readiness
→ Need Generation
→ Confirmed Need
→ Purchase Handoff released to Procurement
```

## PD-02 — Procurement

Goal: convert released purchase demand and dispatch requirements into controlled supplier commitments and fulfilment allocations.

- ✅ Procurement domain contract
- ✅ Procurement foundation
- ✅ Procurement integration and operator-workflow review
- ✅ Procurement fulfilment allocation amendment
- ⬜ Production supplier assignment and policy
- ⬜ Purchase allocation split and overage handling
- ⬜ Production purchase orders and external supplier communication
- ⬜ Production supplier confirmation and exception handling
- ⬜ Supplier-performance support

Procurement fulfilment boundary:

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier, warehouse, or future production records physical fulfilment evidence.
Dispatch confirms transport, destination outcome, exception, or return resolution.
```

Procurement owns `FulfilmentAllocation` and `FulfilmentAllocationLine`. It does not own Planning requirement quantities, Warehouse stock release evidence, supplier physical receiving evidence, Dispatch loading, or delivery confirmation.

## PD-03 — Warehouse

Goal: receive, hold, fulfil, pick, and release goods with controlled stock traceability.

- ✅ Warehouse domain contract
- ✅ Warehouse in-memory foundation (goods receipt, discrepancies, stock/lot identity)
- ✅ Warehouse integration and operator-workflow review
- ✅ Warehouse Stock Release contract
- ✅ Warehouse Stock Release in-memory foundation (reservation, picking, custody release, movement posting, on-hand reduction)
- ⬜ Inventory adjustment and stock count

## PD-04 — Admin / Master Data Management

Goal: maintain the master data required for Atlas MVP launch and OPS v1 replacement.

- ✅ Admin / Master Data Management domain contract
- ✅ School info management foundation (in-memory prototype)
- ✅ Ingredients & Suppliers management foundation (in-memory prototype)
- ✅ Dishes & Recipes management foundation (in-memory consolidated workbench)
- ✅ Admin integration and operator-workflow review
- ✅ RMVP-01 connected independent Atlas master data
- ✅ RMVP-02A connected Dish, Recipe Version, and immutable BOM lifecycle
- ✅ RMVP-02B connected Recipe adjustment rules, authoritative preview, and effective BOM

Admin MVP boundary:

```text
Schools
+ Ingredients & Suppliers
+ Dishes & Recipes
= clean master data for Planning, Procurement, and Warehouse
```

Recipe UI decision:

```text
Dishes & Recipes should be one consolidated Atlas workbench.
OPS v1 Retool screen/layer separation is evidence only, not a target domain split.
```

## PD-05 — Dispatch and Delivery

Goal: move Planning-released, Procurement-fulfilled requirements to schools, wholesale customers, kitchens, and other destinations with explicit loading, delivery, exception, and return evidence.

- ✅ Dispatch and Delivery contract
- ✅ Dispatch and Delivery bounded in-memory foundation
- ✅ Dispatch planning and reference assignment prototype
- ✅ Load and delivery confirmation prototype
- ✅ Delivery exception, return evidence, and closure prototype
- ✅ Dispatch integration and operator-workflow review
- ✅ MVP vertical-slice operator review
- ✅ MVP morning chaos simulation

Dispatch boundary:

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier or warehouse evidence proves physical fulfilment.
Dispatch confirms transport, destination outcome, exception, or return resolution.
```

Source-of-need rule:

```text
School catering and wholesale requirements must both converge into Planning-owned DispatchRequirement lines before Procurement fulfilment and Dispatch execution.
WarehouseRelease is only one fulfilment-evidence type, not the mandatory dispatch trigger.
```

## PA — Persistence architecture

Goal: define, review, and incrementally implement the authoritative Atlas persistence boundary without linking or mutating production systems.

- ✅ PA-01 Atlas Persistence Contract — canonical identity, classifications, aggregates, snapshots/revisions, evidence, transactions, authorization, audit, read models, and legacy boundary
- ✅ PA-02 physical schema and constraint design — namespaces, table catalog, line identity, revisions/snapshots, evidence applications, quantity/time rules, transaction matrix, indexes, access preview, read models, legacy staging, and first supplier-direct slice
- ✅ PA-03 authorization, RLS, command surface, and transaction safety design — actor/capability scopes, dedicated API functions, revoke-first grants, RLS, idempotency, optimistic concurrency, locking/isolation, safe errors, reporting/storage/integration security, and first-slice test design
- ✅ PA-04 supplier-direct Slice 1 migration foundation — merged with private schemas, typed traceability, evidence applications, forced RLS, revoke-first privileges, private read models, and local pgTAP verification
- ✅ PA-05A supplier-direct command/RPC contract design — completed on main with business-command names, envelopes, authorization, idempotency, locking, events/audit, and shaped-read contracts
- ✅ PA-05B bounded SQL command implementation — merged with actor/receipt helpers, five evidence-to-delivery commands, one shaped trace, and security/concurrency/invariant tests
- ✅ PA-05C authorized read API wrappers — shaped, capability/scope-filtered readiness, blocker, and audit-timeline functions
- ✅ PA-05B-H1 / issue #82 — runtime-role hardening completed: separate Evidence and Dispatch command owners, read-only read owner, revoke-first access, and effective-privilege pgTAP audit
- ✅ PA-05D bounded Planning command family — completed on `main` with four Planning commands, a dedicated least-privilege runtime, exact source-to-requirement lineage, and focused pgTAP coverage
- ✅ PA-05E bounded Procurement command family — completed on `main` with exact full-line supplier allocation, separate all-lines-per-supplier purchase-order release, a dedicated least-privilege runtime, and 78 focused pgTAP assertions
- ✅ PA-05B-H2 multi-line Dispatch execution correction — merged with atomic multi-line load, full-line trip departure revalidation, Planning-owned destination enforcement, multi-line successful delivery, trip-wide scope authorization, and 128 focused pgTAP assertions
- ✅ PA-05F bounded Dispatch setup command family — implemented with fully evidenced exact-pair plan admission, disjoint assigned-trip subsets, Planning-derived stops, one plan-version increment per trip, the reused hardened Dispatch runtime, and 51 focused pgTAP assertions
- ✅ PA-05B-H3 successful Dispatch trip closure — implemented under Issue #93 with exact trip/stop/membership/load/delivery reconciliation, preserved `DELIVERED` status, one completion stamp/version increment, one closure event, one audit event, and 46 focused pgTAP assertions
- ✅ PA-05C-H2 current command timeline scope — implemented under Issue #102 with the existing private resolver, exact current aggregate vocabulary, same-trip upstream scope resolution, five minimum SELECT/RLS additions, and 46 focused pgTAP assertions
- ✅ PA-05G backend end-to-end acceptance — implemented under Issue #100 with one rolled-back two-line/two-supplier path, all 17 command executions, four authorized read function types, exact 17 receipt/event/audit counts, the unchanged 18-function security boundary, and 82 focused pgTAP assertions
- ⬜ PA-06 React connection — after PA-05G under the product owner's backend-first sequencing decision
- ⬜ Controlled seed/reference data — separately approved after backend acceptance; not required for rolled-back local fixtures
- ⬜ First connected wholesale supplier-direct vertical slice
- ⬜ Legacy migration rehearsal and operator validation
- ⬜ Separately approved staged rollout

Backend completion boundary:

```text
Wholesale source
→ Planning release chain
→ Procurement allocation and supplier PO
→ source-owned supplier evidence and exact applications
→ Dispatch plan/trip/stop setup
→ exact multi-line load
→ full-line departure
→ successful multi-line delivery
→ successful trip closure
→ authorized trace/readiness/blockers/audit
```

Persistence gate:

```text
Approved PA-01 contract
→ PA-02 schema and constraint design
→ PA-03 authorization / RLS / command and transaction safety
→ PA-04 supplier-direct migration foundation and private derived read models
→ PA-05A command/RPC contract design
→ PA-05B bounded Evidence/Dispatch execution commands and security tests
→ PA-05C authorized shaped read API wrappers
→ PA-05B-H1 runtime-role hardening
→ PA-05D Planning command family
→ PA-05E Procurement command family
→ PA-05B-H2 multi-line Dispatch execution correction
→ PA-05F Evidence-gated Dispatch setup command family
→ PA-05B-H3 successful trip closure
→ PA-05C-H2 current command timeline scope compatibility
→ PA-05G backend end-to-end acceptance
→ PA-06 React connection
→ rehearsal and operator validation
→ separately approved production rollout
```

PA-01 through PA-03 are approved documentation and architecture baselines. PA-04 is the merged first executable database foundation. PA-05A, PA-05B, PA-05C, PA-05B-H1, PA-05D, PA-05E, PA-05B-H2, PA-05F, PA-05B-H3, and PA-05C-H2 are completed on `main`; PA-05G is implemented by the bounded acceptance change with 82 focused assertions. The reviewed API proves one command-authored supplier-direct source-to-successful-trip-closure path plus trace, readiness, blockers, and current aggregate-compatible audit reads. Controlled production seed/reference data, legacy rehearsal, deployment, Warehouse, school catering, and broader write-command coverage remain separately approved work.

## Deferred — Production and Quality

Goal: support kitchen execution, portioning, food safety, inspection, waste, and corrective action.

- ↘️ Production domain contract deferred from current MVP sequence
- ↘️ Quality domain contract deferred from current MVP sequence
- ↘️ Production planning and execution deferred from current MVP sequence
- ↘️ Inspection and food-safety controls deferred from current MVP sequence
- ↘️ Waste and exception handling deferred from current MVP sequence

## Deferred — Finance and Reporting

Goal: add costing, invoices, settlement, management reporting, and cross-domain analysis without redefining operational ownership.

- ↘️ Finance contract deferred from current MVP sequence
- ↘️ Cost and price analysis deferred from current MVP sequence
- ↘️ Invoice and settlement deferred from current MVP sequence
- ↘️ Management reporting deferred from current MVP sequence
- ↘️ Cross-domain operational reporting deferred from current MVP sequence

## Delivery rule

A domain advances through:

```text
Contract
→ Issue
→ Bounded implementation PR
→ Validation
→ Review
→ Merge
→ Integration and operator review
```

The roadmap changes when delivery status changes or the product owner approves a scope change. It is not a substitute for contracts or issues.
