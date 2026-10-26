# Atlas Roadmap

**Reviewed:** 26 October 2026 (Asia/Bangkok). Repository baseline: `c9641522721430def56eea96750c364cdc06584a`, latest verified `origin/main`.

**Purpose:** Current delivery order and evidence boundaries. Approved contracts and explicit Owner instructions govern scope. This task reconciles documentation only; Warehouse remains paused.

## Governing direction

ARCH-001, ARCH-002, the [Atlas Vision](atlas-vision.md), [authority map through Procurement](atlas-authority-map-through-procurement.md), and [Planning–Procurement business freeze](planning-procurement-business-freeze.md) remain authority. Apply **FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED** and workflow-led, contract-constrained, backend-authoritative delivery. Later approved amendments retain their bounded scope; this update changes no business contract.

**Merged** means repository implementation; **deployed** requires an exact target/revision record; **accepted** means only the recorded operator journey and checks. Green Draft CI establishes neither merge nor deployment. This is a dated review, not a live environment inspection.

## Merged repository baseline

| Area                           | Repository state at reviewed main                                                                                                                                                                                                                                      |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Master Data / Recipes          | Connected catalogues, Recipe/BOM authoring, adjustments, effective composition and traceability. Model convergence #258 and effective composition for Need #377 are merged. Recipe3529 still needs a factual Owner/kitchen decision.                                   |
| Planning                       | Menu synchronization, Attendance, Pantry sources, derived readiness/currentness, Need Generation, Confirmed Need, Shopping List V2 A+, and traceable correction/successor support. Pantry displays Bổ sung and Hàng đặt riêng under the approved two-source amendment. |
| Procurement / School documents | Explicit supplier splits and Save, advisory recommendation/rebalance, atomic purchase preparation, immutable supplier PO release, replacement POs, School PXK successors, reconciliation and exports. School PXK does not establish Warehouse receipt or stock.        |
| Persistent workspace           | Thirteen persistent workbench owners (#358), guarded drafts/close/sign-out and the later selected C presentation. Older eleven-owner acceptance remains historical evidence.                                                                                           |
| Backend convergence            | 02B (#357), 02C (#359), and 02D clean-bootstrap/disposable authenticated-API certification (#361) merged. Their dated records retain performance failures, failed attempts and certification limits; these are no longer pending roadmap gates.                        |
| Operational documents          | PO/PXK document and School cooking-group work merged in #360, followed by October export and actual-app PDF repairs. This does not certify every future document/template or physical dispatch.                                                                        |
| Latest changes                 | Scoped Need runtime policy (#432), recorded hosted closeout (#433), action layout/Allocation hierarchy/typography (#434–#436), and optional weekly additions (#437) are merged. Merge supplies no deployment evidence for #434–#437.                                   |

[02B](../implementation-tasks/TASK-ATLAS-BACKEND-CONVERGENCE-02B.md), [02C](../implementation-tasks/TASK-ATLAS-BACKEND-CONVERGENCE-02C.md), [02D](../implementation-tasks/TASK-ATLAS-BACKEND-CONVERGENCE-02D.md), and [document-system](../implementation-tasks/TASK-ATLAS-DOCUMENT-SYSTEM-01.md) records preserve the original source-qualified results.

The [optional-additions amendment](../implementation-tasks/TASK-ATLAS-OPTIONAL-WEEKLY-ADDITIONS.md) merged through [#437](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/437): daily Need can use backend-verified Pantry absence when no batch exists. Existing unfinished batches still block; removing saved additions still requires reviewed Save. Frontend and executed Full Integration passed on final source `96e82ac7`. The PR records no hosted migration application or deployment.

## Last recorded deployed and accepted Staging baseline

| Evidence boundary     | Last recorded result                                                                                                                                                                                                                                               |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Target / application  | Atlas Staging `rnzxmxiiqgtdevzregff`; [connected app](https://thuonghao-ops-erp.pages.dev/). OPS v1 is not an Atlas deployment target.                                                                                                                             |
| Exact deployed source | `db7bfe24`, 22 October; guarded [deployment 39744741438](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39744741438), 134 migrations, tip `20261022071412`; automatic app publication recorded.                                                     |
| Certification         | Exact-main Frontend and executed Full Integration passed. The scoped Need policy restores ordinary authenticated eight-second protection and retains lock/security checks; Need runtime is observed without an arbitrary duration gate.                            |
| Hosted acceptance     | Original → correction → reallocation → replacement PO → successor dispatch: two Schools, all 21 detail deltas zero, 631 assertions and both actual PDFs over four rendered pages pass. All 7,205 pre-existing history rows and frozen original contents preserved. |
| Limits                | Bounded Staging evidence; no real Supplier communication, physical shipment or Production cutover. Resource observations justify no capacity change or general speedup claim. Later main/Draft work is not implied deployed.                                       |

Sources: [22 October runtime/journey closeout](../testing/supabase-runtime-timeouts-2026-10-22.md), [earlier journey/export closeout](../testing/journey-closeout-2026-10-21.md). Current deployment parity was not re-inspected on 26 October; verify it before a separately authorized release or pilot.

## Current review queue

Verified on GitHub on 26 October: both remain **open Drafts, unmerged**. Independent source/render review is reported on each PR; Product acceptance and integration remain separate gates.

| PR                                                                | Bounded change                                                                                                             | Exact-head Frontend CI                                                                                           | Deployment                              |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| [#438](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/438) | Procurement status hierarchy and warning/error surfaces                                                                    | PASS at `baef3078`; [run 40205644208](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40205644208) | No deployment evidenced for this Draft. |
| [#439](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/439) | Truthful pending/failed PXK counts, desktop Change Order reason/actions and bounded desktop readability/error improvements | PASS at `d7802b22`; [run 40244573064](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40244573064) | No deployment evidenced for this Draft. |

Older open Drafts, including #385–#388/#396 and earlier UI prototypes, remain preserved. Assess exact compatibility and already-merged replacements before any disposition. Historical FAIL/BLOCKED evidence is not converted to PASS by the later bounded journey; do not automatically merge, rerun or discard those Drafts.

## Next priorities — planning, not execution authorization

1. **Complete Product review of #438/#439.** Resolve only demonstrated remaining issues; retain exact-head CI and compatibility review before integration. This documentation task does not merge them.
2. **Establish one accepted release and explicit deployment parity.** On separate authorization, record the selected combined source, required certification, Staging migration tip, app artifact revision and rollback. Include #437's migration/UI dependency; do not label current main deployed without evidence.
3. **Prepare a bounded staff pilot of the existing Planning–Procurement workflow.** The earlier approximately 5–10 working-day proposal remains a planning estimate, not a scheduled/completed pilot. Agree scope, staff, data, document acceptance and completion criteria before starting; use observed friction to prioritize improvements.
4. **Resolve factual data and cutover decisions.** Recipe3529's pork-name/ground-beef discrepancy needs the Owner/kitchen's factual answer. Preserve source history. Production adoption requires explicit scope/ownership approval, reconciliation, staff readiness and rollback; this roadmap authorizes none of those writes or commitments.

[ACTIVE_TASK.md](../autopilot/ACTIVE_TASK.md) defines the sole active task and stop condition: documentation update and review handoff. The priorities above do not start another task.

## Warehouse — PAUSED by Owner, 26 October

**Do not work on Warehouse yet.** No Warehouse discovery, design revision, contract, migration, implementation, benchmark, deployment or automatic promotion is active. The existing [minimum receiving packet](warehouse-receiving-minimum-design.md) retains four UNDECIDED Product groups and an [unapproved implementation decision](../decisions/decision-atlas-warehouse-receiving-minimum.md). Leave them unchanged. Warehouse is not the next executable task; future work requires explicit Owner reactivation and existing approval gates.

## Deferred / separately governed

Attendance XLSX-assisted authoring, multi-day Shopping List UI, DISH-RICE-01 semantics, supplier-removal/cancellation policy, Dispatch expansion, Production/QA, Finance/Accounting and optional compatibility retirement remain outside this task. No broad performance/capacity program or old correction stress loop is activated.

## Historical evidence and environment boundaries

The accepted pre-freeze baseline remains `010871bebb43f3883c77c5b9bf6954282053c93d` (#355), followed by freeze #356. The 7 October observation recorded 92 hosted/repository migrations, tip `20261006112515_atlas_recipe_purchase_unit_read`, and the then eleven-owner hosted acceptance. These dated facts remain in the [canonical freeze](planning-procurement-business-freeze.md#21-accepted-hosted-evidence) and Git history; they are not current deployment claims. The 21 October and 22 October journeys retain their distinct 22-delta and 21-delta evidence without combining them.

For this documentation task, hosted systems are read-only. OPS v1 `qnthofvccilhnefdcxnz` and Retool remain NO-WRITE; Atlas Production is not an approved target. Preserve immutable quantities, source lineage, capability/scope checks, RLS, receipts and historical documents. Use minimal purpose-built review data only within separate authorization; do not invent Recipe facts to make a journey pass.

## Update rule

Keep the current roadmap concise. Separate merged, deployed and accepted evidence with date, revision, target and source. Preserve failed/limited evidence in implementation/testing records and Git history. Never promote queued priorities or dated historical instructions into execution authority.
