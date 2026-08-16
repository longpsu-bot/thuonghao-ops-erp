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
- ✅ Workflow-led, contract-constrained, backend-authoritative bounded-PR workflow

## ATLAS-ACT-01 — Hosted Staging and Connected-UI Stabilization

Goal: prove the connected Atlas Admin and Planning path in one separate hosted staging environment and make the current operator experience coherent before adding Purchase Handoff.

- ✅ ATLAS-ACT-01A hosted staging and connected-UI architecture — accepted on 06/08/2026; [architecture](atlas-act-01-hosted-staging-ui-consolidation-contract.md), [decision](../decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md), [UI standard](../ui/atlas-ui-quality-standard.md), [current UI inventory](../ui/atlas-current-ui-inventory.md), and [task record](../implementation-tasks/TASK-ATLAS-ACT-01A-hosted-staging-ui-architecture.md)
- ✅ ATLAS-ACT-01B repository staging readiness — complete through PR #175, merged at `9b9f8af3609507876d69a55cc529e9bd17aa56db`; staging-verifier correction complete through PR #176, merged at `844b4640df28f666736f018b8ef81d63fb78d2be`
- ✅ Separate Atlas staging project — project `rnzxmxiiqgtdevzregff` exists and protected deployment succeeded at `844b4640df28f666736f018b8ef81d63fb78d2be`; existing OPS project `qnthofvccilhnefdcxnz` remains forbidden as a target
- ✅ D-033 Mantine 9 UI component foundation — accepted for connected Atlas presentation; Atlas retains business semantics and authority
- ✅ UI-QUALITY-01 Mantine foundation, shared shell and proven primitives — complete through PR #177 at `c98d044f3b880cca02fb8cb95f7c2ebcd0246f78`, with no business behavior change
- ✅ D-034 / UI-VISUAL-01 Atlas Modern Operations visual foundation — complete through PR #179 at `bf0a1af28f689bfb4a81f6b6db96b298006c1794`
- ✅ UI-QUALITY-02A Planning source workbenches — complete through PR #180 at `4a585f980464e4367a0b23ea6184ecf10fd70003` for Weekly Menu, Attendance and Pantry
- ✅ D-035 Atlas Workflow-First Operator UX — accepted Application presentation authority; happy path first, progressive disclosure and one backend-authorized next action
- ✅ UI-QUALITY-02B Planning Input Readiness and Need Generation — complete on `main` at `5e2955b6798d9310b10bf6b0bcafda701ed45992`; its presentation-only workflow reset is now superseded at the command boundary by merged D-036 and PLANNING-CONTRACT-01
- ✅ D-036 Planning workflow simplification — complete through PR #183 at `eae396b104347d5accaffdb373997904248cbad7`; consequential source Save, automatic Readiness, atomic Need Generation/materialization and the Confirmed Need human commitment boundary are accepted
- ✅ D-037 Confirmed Need Save and Release boundary — merged through PR #189 at `e542e263e3bb672eb2967af0b3d54bfd8771df75`; two backend-authoritative human actions, v1 compatibility, no browser lifecycle chaining, no downstream mutation, and XLSX/PDF contract deferral
- ✅ PLANNING-CONTRACT-01 atomic Planning completion boundaries — complete through PR #184 at `f8c5b36a1c9cf24d58f67bf2c82ed7c9d4715889`; additive v2 source Saves, automatic preflight and atomic Need Generation/H0C materialization are merged while v1 remains callable during Application cutover
- ✅ UI-QUALITY-02AB-UX — merged at `9818efe4ec1eda7b1b5879494a382921afc758b7`; cuts Weekly Menu, Attendance, Pantry, Readiness and Need Generation over to the merged v2 workflow without redesigning Confirmed Need
- ✅ UI-QUALITY-02C-A / 02C-B Confirmed Need two-action workflow — merged; XLSX/PDF schema remains deliberately deferred
- ✅ D-038 / UI-QUALITY-03A Recipe creation-and-lock vertical — merged through PR #191 at `0d66a3640811cfeac97d2f986b6c2a3d08da0a4b`; read-only catalog, separate creation, approved-Menu first-use lock, Change Order direction, no React lifecycle chaining, retained v1 compatibility, and no downstream behavior change
- ✅ UI-QUALITY-03B Recipe Change Order first-user redesign — merged through PR #194 at `60316f59638e1c7c625700166e7c78d7b11e242a`
- ✅ UI-QUALITY-03C-A School default portions — merged through PR #195 at `d9b8348a0394f2b924878e90ad6ab93aa200d9e6`; restores compact multi-School inline editing and adds Product Owner-approved local Before/After Review before one atomic `RMVP-01.v2` Save, while preserving the single-School v1 command and backend behavior
- 🟡 UI-QUALITY-03C-B Ingredient/Supplier operator workflow hardening — active from authoritative `main` `d9b8348a0394f2b924878e90ad6ab93aa200d9e6`; preserves the existing tabs/search/catalog/detail structure, removes the hidden 60-result cap, adds exact canonical Review before authored `RMVP-01.v1` writes, restores two predefined private authoritative Ingredient catalogs and API-backed selects, corrects `Nhóm đặt hàng`/rounding wording, retains lifecycle confirmation, and adds stale/unknown/readback recovery with no Planning delta
- ⬜ Hosted operator/security rehearsal — not started; later scope remains Admin reference preparation through Confirmed Need release, including blocker, stale, denied-capability, inactive-reference and unknown-outcome scenarios
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

Planning workflow-correction sequence:

```text
D-036
→ PLANNING-CONTRACT-01
→ UI-QUALITY-02AB-UX
→ UI-QUALITY-02C-A
→ UI-QUALITY-02C-B
→ PLANNING-UX-01: Attendance → Menu → Need Generation → Confirmed Need; typography/rhythm; Preview-before-Save consistency; final XLSX affordance placement
→ ↘️ DISH-RICE-01 — Menu-derived rice accompaniment (recorded only; begin only after Product semantics are defined): Dish label `Ăn kèm cơm`; Menu + current confirmed Attendance + one deduplicated qualifying meal context should eventually derive Rice need. Dish-Type eligibility, one-per-meal semantics, governed rate source, Atlas Rice identity, correction locks and prevention of double counting with fixed/manual Pantry Rice remain unresolved; `0.1 kg/portion` is illustrative only and no Dish/Planning/Pantry/XLSX implementation is authorized by UI-QUALITY-03C-B
→ bounded Attendance and Confirmed Need XLSX contract tasks after Product review
```

Delivery-method shorthand:

```text
workflow discovery
→ minimum contract
→ authoritative backend
→ connected UI
→ operator review
```

This shorthand is discovery and delivery guidance, not a replacement for `OPS_SYSTEM_MAP` authority. Delivery should proceed through thin operational verticals rather than completing speculative capability families before operators can review a connected slice.

Attendance and Confirmed Need must later support XLSX-assisted bulk authoring: export, offline population, import, difference/error review, application to local draft, Preview, and Save; Confirmed Need Release remains a separate commitment. Workbook templates, schemas, parsers, generators, and actual XLSX implementation are not defined by UI-QUALITY-03C-A and remain deferred until PLANNING-UX-01 confirms stable work surfaces.

PLANNING-UX-01 must also correct the verified OPS v1 Attendance operator model. Menu School/date coverage automatically establishes default-derived working Attendance; those rows remain editable and unconfirmed until the operator reviews actual quantities, uses future XLSX assistance if useful, previews changes, and saves. School-default propagation may update only still-default-derived future values, never operator-entered or confirmed facts. The current manual `Tạo từ sĩ số mặc định` ceremony is Product debt, and Need Generation must continue to require confirmed/current Attendance rather than row existence. The normal 2–3-day confirmation timing is operating context, not yet a hard deadline. No Attendance implementation or contract is authorized in UI-QUALITY-03C-A.

Atlas-wide typography and rhythm review remains deferred to PLANNING-UX-01 after the Attendance → Menu → Need Generation → Confirmed Need operator route is reviewed. UI-QUALITY-03C-A changes only the local School table and Review modal layout. No Atlas Staging deployment is part of UI-QUALITY-03C-A.

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
- ✅ PLANNING-CONTRACT-01 atomic Planning completion boundaries — merged through PR #184 at `f8c5b36a1c9cf24d58f67bf2c82ed7c9d4715889`; adds `RMVP-03A.v2`, `PANTRY-02.v2`, `RMVP-03B.v2`, and `RMVP-04.v2` while preserving v1 callability during Application coexistence; [canonical implementation record](../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md)
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
- ⬜ Hosted Supabase action for the merged PLANNING-CONTRACT-01 path — Atlas Staging exists separately, but this v2 Planning contract remains undeployed there until a separately authorized protected deployment
- ⬜ Retool change for this path — unapproved
- ⬜ Production Planning policy seed — unapproved
- ✅ React connection through RMVP-07B — the existing sixth Planning Inputs tab includes complete-batch validation, backend-authorized approval and release, separate confirmations, Actor/time/warning evidence, lifecycle history, late-response guards, and authoritative refresh behavior

Planning completion boundary under merged D-036 and PLANNING-CONTRACT-01:

```text
Weekly Menu / Attendance / Pantry consequential Save
→ automatic Planning Input preflight
→ atomic Need Generation release and Confirmed Need materialization
→ Confirmed Need human review, completion and release
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
- ⬜ PA-06 React connection — historical persistence roadmap item after PA-05G; future connected slices now follow the workflow-led delivery rule below rather than a domain-wide backend-first phase
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

Atlas uses **workflow-led, contract-constrained, backend-authoritative** delivery.

A new operational slice should normally advance through:

```text
Mission / capability / domain ownership
→ concrete operator job and workflow
→ lightweight UI/workflow exploration
→ genuine human decision boundaries
→ minimum business contract
→ authoritative backend boundary
→ connected Application UI
→ operator / product review
→ refinement from observed need
→ next thin vertical slice
```

Workflow/UI exploration is discovery, not business authority. The accepted contract still precedes authoritative implementation, and React never owns backend validation, authorization, calculation, lifecycle, lineage, audit, idempotency, or transaction integrity.

Do not complete a speculative backend domain before proving that operators need the proposed command boundaries, and do not complete a frontend domain with the intention of adding authority later.

For cross-version backend consolidation or lifecycle-boundary changes, use the deeper affected-surface integration gate appropriate to that risk. Ordinary UI-only work should use focused UI validation and existing bounded CI rather than inheriting unnecessary database certification.

The roadmap changes when delivery status changes or the product owner approves a scope change. It is not a substitute for contracts or issues.
