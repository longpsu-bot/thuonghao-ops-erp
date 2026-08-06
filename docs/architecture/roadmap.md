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

## ATLAS-ACT-01 — Hosted Staging and Connected-UI Stabilization

Goal: prove the connected Atlas Admin and Planning path in one separate hosted staging environment and make the current operator experience coherent before adding Purchase Handoff.

- ✅ ATLAS-ACT-01A hosted staging and connected-UI architecture — accepted on 06/08/2026; [architecture](atlas-act-01-hosted-staging-ui-consolidation-contract.md), [decision](../decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md), [UI standard](../ui/atlas-ui-quality-standard.md), [current UI inventory](../ui/atlas-current-ui-inventory.md), and [task record](../implementation-tasks/TASK-ATLAS-ACT-01A-hosted-staging-ui-architecture.md)
- ⬜ ATLAS-ACT-01B repository staging readiness — explicit local/staging configuration, live OPS denylist, protected manual deployment, exact-head CI reuse, hosted verification and runbook; creates no hosted project during implementation
- ⬜ Separate Atlas staging project — current Supabase cost and organization confirmation required immediately before creation; existing OPS project `qnthofvccilhnefdcxnz` is forbidden as a target
- ⬜ UI-QUALITY-01 shared shell and proven primitives — no new dependencies or business behavior
- ⬜ UI-QUALITY-02 connected Planning consolidation — Weekly Menu through Confirmed Need release
- ⬜ UI-QUALITY-03 connected Admin consolidation — Schools, Ingredients/Suppliers and Dishes/Recipes
- ⬜ Hosted operator/security rehearsal — Admin reference preparation through Confirmed Need release, including blocker, stale, denied-capability, inactive-reference and unknown-outcome scenarios
- ↘️ CMD-03 / Purchase Handoff and downstream purchasing expansion — deferred until the staging, UI and rehearsal gate is accepted

Stabilization sequence:

```text
exact-head local certification
→ repository staging readiness
→ separate cost-confirmed Atlas staging
→ connected Planning and Admin UI consolidation
→ hosted operator/security rehearsal
→ explicit Product/Architecture decision on CMD-03
```

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
- ✅ PANTRY-NG-01 / PANTRY-NG-02 direct Pantry Need Generation lineage — the accepted D-028 amendment and its backend persistence, integrity, and CMD-15 compatibility merged through PR #167 at `4cc9bddb8f77c962d2c557affee5a7d3f58e75e2`; [amendment](pantry-ng-01-need-generation-direct-ingredient-amendment.md), [canonical decision](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md), and [implementation record](../implementation-tasks/TASK-PANTRY-NG-02-direct-ingredient-persistence-materialization.md)
- ✅ RMVP-04 connected Need Generation — merged through PR #168 at `d497c8921d64fb555baea8e207a27f63925934a7` with one exact-period Planning workbench, create/validate/release/invalidate commands, existing CMD-15 connection, and a fifth Vietnamese Planning Inputs tab; [API contract](../api/rmvp-04-connected-need-generation.md) and [implementation record](../implementation-tasks/TASK-RMVP-04-connected-need-generation.md). Procurement, Warehouse, Dispatch, hosted deployment, and production rollout remain outside scope.
- ✅ RMVP-05 connected Confirmed Need review and quantity confirmation — merged through PR #169 at `9ddc6030c85cc3c076ab74ee0bd1af4f123dcae7` with one shaped review, write-free exact preview, idempotent H1B1 confirmation command, and sixth Vietnamese Planning Inputs tab; [API contract](../api/rmvp-05-connected-confirmed-need-review.md) and [implementation record](../implementation-tasks/TASK-RMVP-05-connected-confirmed-need-review.md). Validation, approval, release, CMD-03, downstream domains, hosted deployment, production policy seed, and Retool remain outside that implementation.
- ✅ RMVP-06A Confirmed Need complete-batch validation contract — accepted through PR #170 with one future validation API, one unbound capability, runtime reuse, append-only attempts/observations/issues, blocked-outcome evidence, successful `VALIDATED` transition, and a bounded RMVP-06B handoff; [architecture](rmvp-06-confirmed-need-validation-contract.md), [decision](../decisions/decision-rmvp-06-confirmed-need-validation.md), and [task](../implementation-tasks/TASK-RMVP-06A-confirmed-need-validation-contract.md)
- ✅ RMVP-06B connected Confirmed Need validation — merged through PR #171 at `c4d7970399f6b1c147700925f03e84efdafb0747` with one command, three immutable evidence relations, the complete 19-blocker/two-warning registry, additive read-only validation UI, 65 focused pgTAP assertions, all registered database suites, and complete browser verification; [API](../api/rmvp-06-connected-confirmed-need-validation.md) and [implementation record](../implementation-tasks/TASK-RMVP-06B-connected-confirmed-need-validation.md). Approval, release, reopen, CMD-03, downstream domains, hosted deployment, production capability binding, and Retool remain excluded.
- ✅ RMVP-07A Confirmed Need approval and release architecture — accepted on baseline `c4d7970399f6b1c147700925f03e84efdafb0747`; defines separate full-batch approval and release commands, two unbound capabilities, immutable RMVP-06 attempt-fingerprint history, a distinct lifecycle-neutral validated-fact projection for approval/release, source-qualified WHOLESALE compatibility, reuse of existing approval snapshots, one future `NEED_GENERATION` release relation, exact command/read/disabled-reason surfaces, additive Vietnamese workbench behavior, and a bounded RMVP-07B handoff; [architecture](rmvp-07-confirmed-need-approval-release-contract.md), [decision](../decisions/decision-rmvp-07-confirmed-need-approval-release.md), and [task](../implementation-tasks/TASK-RMVP-07A-confirmed-need-approval-release-contract.md)
- ✅ RMVP-07B connected Confirmed Need approval and release implementation — merged through PR #173 at `f3197bb5a7b571378a41ae5056a73a84ad57d583` with separate complete-batch approval and release commands, two unbound capabilities, exact RMVP-06 evidence binding, lifecycle-neutral drift protection, immutable approval/release evidence, WHOLESALE compatibility, additive Vietnamese workbench actions and complete exact-head certification; [API](../api/rmvp-07-connected-confirmed-need-approval-release.md) and [implementation record](../implementation-tasks/TASK-RMVP-07B-connected-confirmed-need-approval-release.md). Reopen, CMD-03, Purchase Handoff creation, downstream domains, hosted deployment, production bindings, and Retool remain excluded.
- 🟡 PA-06D quantity truth, operational precision, rounding, rebalancing, and write-fidelity documentation — [contract](pa-06d-quantity-truth-rounding-rebalancing-contract.md); implementation and unresolved product decisions remain unapproved
- 🟡 PA-06E Confirmed Need review, adjustment, revision, and source-correction documentation — [contract](pa-06e-confirmed-need-review-adjustment-revision-contract.md) and [decision](../decisions/decision-pa-06e-confirmed-need-source-correction.md); implementation and pending product decisions remain unapproved
- ✅ PA-06E-H0C/CMD-15 Confirmed Need materialization — merged by PR #144 on exact baseline `5987f1fc9711b7bde094a610e598ff92d71e850d`; [decision](../decisions/decision-pa-06e-h0c-materialization-command-contract.md) and [implementation record](../implementation-tasks/TASK-PA-06E-H0Cb-confirmed-need-materialization-command.md)
- ✅ PA-06E-H1A0 Planning quantity-policy product contract — H1A-P01 through H1A-P10 approved by the product owner on 2026-07-23; [canonical decision registry](../decisions/decision-pa-06e-h1a-planning-quantity-policy.md)
- ✅ PLATFORM-PRE-H1A current test-catalog consolidation — merged by PR #148; the canonical suite remains `plan(22)` and the historical-suite ownership boundary is established; [implementation record](../implementation-tasks/TASK-PLATFORM-PRE-H1A-current-test-catalog-consolidation.md)
- ✅ PA-06E-H1A SQL persistence — merged by PR #150 as `0ba89ff8c3434979eb3e8897a6bcf9bb2171c51f`; exactly two private relations, three private functions, and three triggers; zero role/capability/runtime/policy/grant/API/PA-06A/view/writer/seed delta; 27 registered suites / 1,648 TAP results; [implementation record](../implementation-tasks/TASK-PA-06E-H1A-planning-quantity-policy-persistence.md)
- ✅ PA-06E-H1B1A policy-bound line-decision contract — H1B1-P01 through H1B1-P12 approved as corrected on 2026-07-26; [architecture contract](pa-06e-h1b1-policy-bound-line-decision-contract.md) and [canonical decision registry](../decisions/decision-pa-06e-h1b1-policy-bound-line-decision-evidence.md)
- ✅ PA-06E-H1B1 policy-bound line-decision persistence — merged before RMVP-05 with one private relation, one nullable pointer, three private functions, six triggers, and no writer/API/runtime grant; [implementation record](../implementation-tasks/TASK-PA-06E-H1B1-policy-bound-line-decision-persistence.md)
- ✅ PA-06E-H1B2 authorized review/preview/confirmation — implemented and merged through RMVP-05; [exact API](../api/rmvp-05-connected-confirmed-need-review.md)
- ⬜ Hosted Supabase action for this path — governed by accepted ATLAS-ACT-01; separate staging only, explicit current-cost confirmation required
- ⬜ Retool change for this path — unapproved
- ⬜ Production Planning policy seed — unapproved
- ✅ React connection through RMVP-07B — the existing sixth Planning Inputs tab includes complete-batch validation, backend-authorized approval and release, separate confirmations, Actor/time/warning evidence, lifecycle history, late-response guards, and authoritative refresh behavior

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
