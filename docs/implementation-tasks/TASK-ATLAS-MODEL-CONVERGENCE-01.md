# ATLAS-MODEL-CONVERGENCE-01 implementation evidence

Status: implementation in progress. Required P0/P1 acceptance is not complete.

## Execution and scope

- Verified baseline: `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`, merged PR [#257](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/257).
- Task branch: `codex/atlas-model-convergence-01`; final reviewed head and Draft PR pending.
- Canonical checkout was explicitly confirmed after preflight found a historical second worktree. Initial checkout was clean; the old branch was retained intact. New task branch starts at the verified baseline.
- Actual lead runtime: `gpt-6-astra / xhigh`, disclosed before user approval. Implementation workers requested `gpt-5.6-sol / xhigh`; no prompt-based runtime change claimed.
- Seven supplied document hashes matched before integration. Formatting changed only Markdown layout. Product direction is approved; packet wording does not constitute a completed implementation/review/deployment.
- Recipe frontend adoption and targeted regression/documentation only. Planning/Procurement production modules, migrations, privileges, dependencies and lifecycle contracts remain outside the change.

## Authoritative paths and compatibility

The frozen contract map uses the existing reference catalog for identity/search and target Dish version, `get_dish_recipe_operator_workbench` for selected effective/base-authoring context, `copy_dish_recipes` for one two-scope copy, and `get_recipe_effective_target_context` for exact effective target identity. Connected adoption evidence is pending integration.

Normal GENERAL fallback, browser effective selection, browser one-version copy and representative-School system context are retirement targets in the UI. Physical compatibility APIs and historical evidence remain retained. Do not interpret this target list as proof of completed adoption until the connected tests below pass.

## Required contract gaps

1. **A07: system-only Preview/Create/Supersede.** Existing adjustment commands require `preview_school_id` and use the retained School compatibility resolver. New system target/context reads do not provide a matching system command envelope. The bounded UI must fail closed; no proxy School, caller-invented field or backend change is authorized. Minimal follow-up: approve one explicit system/School command-context amendment reusing the strict typed resolver, exact preview identity and existing authorization/receipt/locking behavior.
2. **A12: original legacy issuance.** Effective-history tags currently return Actor display name and stored revision creation time with no reliable legacy-issuance discriminator. The adjustment ledger identifies `LEGACY_UNATTRIBUTED` and nulls issuer name but still returns import time. Minimal follow-up: shape nullable original issuer/time consistently from recorded provenance in both reads; preserve immutable records. Frontend must not present importer/time as original business issuance.
3. **Catalog scope:** no whole-catalog effective-Ingredient read exists. Identity/base-labelled search plus lazy authoritative selected detail is within this task. Whole-catalog effective search would require a separately approved bounded read; no fanout or invented API is used to claim completeness.

## Acceptance-to-evidence matrix

Existing SQL/component evidence is reused where sufficient. An existing test listed here is not a new pass until the final exact-head run executes it. Mocked component tests show connected component adoption, while database atomicity/authentication needs disposable SQL/browser-key evidence.

| ID  | Outcome                        | Actual test or artifact                                                                                                                                                    |
| --- | ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R01 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R02 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R03 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R04 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R05 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R06 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R07 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R08 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R09 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R10 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R11 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R12 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R13 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R14 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| R15 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| C01 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| C02 | Pending final-head validation  | supabase/tests/recipe_effective_contract_01.sql — AB/AC system-only snapshot                                                                                               |
| C03 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| C04 | Pending final-head validation  | supabase/tests/recipe_effective_contract_01.sql — missing scope/lock; product-model selector tests                                                                         |
| C05 | Pending final-head validation  | supabase/tests/recipe_effective_contract_01.sql — AF second-scope rollback                                                                                                 |
| C06 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| C07 | Pending final-head validation  | supabase/tests/recipe_effective_contract_01.sql — AG/AH exact replay/content conflict                                                                                      |
| C08 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| C09 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| C10 | Pending final-head validation  | supabase/tests/recipe_effective_contract_01.sql — AI/AK source immutability/later-rule independence                                                                        |
| C11 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A01 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A02 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A03 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A04 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A05 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A06 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A07 | BLOCKED — required backend gap | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A08 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A09 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A10 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A11 | Pending final-head validation  | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| A12 | BLOCKED — required backend gap | Worker connected component/parser evidence pending integration; canonical Recipe SQL reused where applicable                                                               |
| P01 | Pending final-head validation  | planningInputsModel.test.ts persisted/default pair cases; PlanningInputsWorkbench.test.tsx explicit zero/blank; planningInputsWorkbook.test.ts                             |
| P02 | Pending final-head validation  | PlanningInputsWorkbench.test.tsx reviewed Menu Save and Google fetch invalidation; complete canonical filtered Save                                                        |
| P03 | Pending final-head validation  | PantryWorkbench.test.tsx explicit no-additions/review invalidation; supabase/tests/pantry_02_connected_pantry_source.sql                                                   |
| P04 | Pending final-head validation  | supabase/tests/planning_contract_01_atomic_planning_boundaries.sql — PCT01-D01–D15; verify-local-planning-contract-01.mjs                                                  |
| P05 | Pending final-head validation  | supabase/tests/planning_contract_01_atomic_planning_boundaries.sql — PCT01-D19/D20                                                                                         |
| P06 | Pending final-head validation  | supabase/tests/planning_contract_01_atomic_planning_boundaries.sql — PCT02B-09/11/13/21/25/30/33/34/43; continuity SQL                                                     |
| P07 | Pending final-head validation  | supabase/tests/school_catering_planning_correction.sql; SchoolCateringProcurementWorkbench.test.tsx correction-to-commitment journey                                       |
| Q01 | Pending final-head validation  | GeneratedPurchaseReview.test.tsx read/export without commands; supabase/tests/purchase_review_confirm_release.sql before_preview counts                                    |
| Q02 | Pending final-head validation  | ConfirmedSupplierAllocationWorkbench.test.tsx exact source/version/splits; SchoolCateringProcurementWorkbench.test.tsx; supabase/tests/purchase_review_confirm_release.sql |
| Q03 | Pending final-head validation  | supabase/tests/purchase_review_confirm_release.sql rebalance60_40/stale125; connected explicit Apply/Save tests                                                            |
| Q04 | Pending final-head validation  | supabase/tests/purchase_review_confirm_release.sql — new MC-Q04 final-child failure and existing prepare/replay; ConfirmedSupplierAllocationWorkbench.test.tsx             |
| Q05 | Pending final-head validation  | supabase/tests/purchase_review_confirm_release.sql — promotion source/predecessor/exact125; school_catering_handoff_allocation.sql                                         |
| Q06 | Pending final-head validation  | supabase/tests/school_catering_purchase_orders.sql; purchase_review_confirm_release.sql released snapshots; connected stale draft/release tests                            |
| Q07 | Pending final-head validation  | purchaseOrderExports.test.ts unsafe-integer six-decimal and XLSX text preservation; GeneratedPurchaseReview.test.tsx decimal evidence                                      |
| S01 | Pending final-head validation  | supabase/tests/atlas_current_platform_security_catalog.sql; Recipe/adjustment SQL authorization; local browser-key verifiers                                               |
| S02 | Pending final-head validation  | supabase/tests/recipe_effective_contract_01.sql; recipe_active_on_create_lifecycle_correction.sql; RMVP-02A/B SQL                                                          |
| S03 | Pending final-head validation  | New connected Recipe/adjustment fault tests (pending integration); existing preparation readback failure/late result cases                                                 |
| S04 | Pending final-head validation  | Authority map, living documentation corrections, this report, independent review and Staging inventory                                                                     |

## Validation and review

- Baseline database RED: main run [34002629562](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/34002629562) failed Recipe history V/W/Y (22/23/25 of 39). The fixture mixed fixed September boundaries with a wall-clock base release; the history contract excludes boundaries before release. The fixture now uses fixed validation/release timestamps before the scenario boundaries. Assertions and production logic are unchanged; final CI outcome is pending.
- Targeted test-first RED/GREEN: pending worker integration reports.
- Touched-file formatting, TypeScript and whitespace: pending final integration.
- Fresh independent spec/authority and safety/correctness review: pending integrated head.
- Frontend CI: pending Draft PR.
- Supabase Full Integration: pending final reviewed head. Inspected workflow_dispatch runs a reduced disposable local Docker stack, ordered SQL suites and loopback-only authenticated verifiers. No hosted secrets/deployment job is present. Required canonical Recipe, Planning, Procurement and security suites are already registered; MC-Q04 extends an existing registered suite.
- Browser artifacts: pending real component interactions using disclosed synthetic fixtures at desktop and narrow width; not a hosted rehearsal.

## Staging readiness — NOT READY

Read-only connector verification identified Atlas Staging `rnzxmxiiqgtdevzregff`. Metadata observed at **2026-09-06 09:15:35 Asia/Saigon**, coverage at **09:16:14**. Both transactions used `BEGIN READ ONLY`, a 10-second local statement timeout, catalog/aggregate SELECTs and COMMIT. No mutating verifier or business function was called.

| Check                                                                  | Observed result                                                                                                                                                                      |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Migration tip                                                          | `20260904081048_master_data_creation_ux_02`                                                                                                                                          |
| Canonical Recipe APIs                                                  | 0 of 4 present                                                                                                                                                                       |
| Missing repository migration delta                                     | `20260905105253_recipe_effective_contract_01.sql`; `20260905161348_recipe_effective_product_model_correction.sql`; `20260906000923_recipe_active_on_create_lifecycle_correction.sql` |
| Atlas tables / RLS enabled / forced                                    | 107 / 107 / 107                                                                                                                                                                      |
| Inspected direct anon/authenticated table grants                       | None returned                                                                                                                                                                        |
| Canonical School-Type catalog                                          | One active row for each stable code                                                                                                                                                  |
| Active Dish/type contexts                                              | Two per type; both missing roots and not effective-ready; no ambiguities                                                                                                             |
| Existing root shapes                                                   | 2 GENERAL, 1 TYPED                                                                                                                                                                   |
| API owners/search paths/grants                                         | New APIs absent; cannot inspect deployed definitions                                                                                                                                 |
| Data API exposure, intended Actor scope, authenticated browser journey | NOT VERIFIED                                                                                                                                                                         |

These are aggregate metadata observations, not security certification or hosted operability. Missing root/release data is not permission to fabricate BOMs. Disposable CI cannot establish Staging parity. See the [read-only readiness runbook](../runbooks/atlas-model-convergence-staging-readiness.md) for the separate later deployment/reconciliation gate.

## Change, rollback and delivery status

Changed-file inventory and final reviewed SHA are pending integration. No migrations or production database changes are planned; application rollback is a reviewed revert of the bounded frontend/docs change. Historical compatibility APIs remain available, with physical P2 cleanup deferred.

No merge, Ready transition, hosted deployment, hosted fixture, data repair or hosted business write is authorized or performed. The delivery boundary is one Draft PR and evidence for review.
