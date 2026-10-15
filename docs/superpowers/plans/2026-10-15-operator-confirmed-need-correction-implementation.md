# Operator C — Confirmed Need correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One authorized operator can atomically save an append-only released School Need quantity correction, explicitly release affected complete PO/Dispatch successors and preserve provably unaffected supplier/day facts and documents.

**Architecture:** Add a closed server preview and atomic existing prepare-plus-Save wrapper. Derive exact full-family continuity from immutable historical Need revision/decision evidence with separate prospective Preparation and official post-release/Handoff gates; preserve unaffected allocation/contribution/split IDs rather than weaken fingerprints. Prelock the complete contributing root set before target locks, then rebuild proof after waits.

**Tech Stack:** Existing PostgreSQL 17/Supabase SQL/pgTAP, React/TypeScript/Chakra 3, Vitest/testing-library, exact RPC transport and existing integration/review harnesses. No dependency, framework or persisted continuity table.

**Spec:** `E:/Project/OPS ERP/thuonghao-ops-erp/docs/superpowers/specs/2026-10-15-operator-confirmed-need-correction-design.md`, human-approved design source `340721a49788163416176db816477168895f3442`.

## Global Constraints

- Release scope: **TASK2_ONLY** after the authority amendment. Task1 is locally committed at `f452195156ad11d8f217fe4efd9770762cc12ff9`; Root/Terra reviewed the concrete fence/root/bridge design and released Task2 private proof, early fences, narrowly retained-RELEASED guard support and focused tests. Tasks3–8 remain technical checkpoints; no new public C APIs, atomic wrapper or UI implementation yet. Sol6.1 is sole implementer using executing-plans; no new agents or execution-mode question.
- Human approval15October: “if this mean PO/Dispatch can still re released after need correction then approve”. Valid affected positive POs use explicit complete replacements; Dispatch explicit successors; old released documents preserved. True zero and Supplier-transfer remnants retain existing cancellation-required frontier. No promise every zero/unsupported case can release, no automatic release chain/cancellation/supplemental policy.
- Canonical checkout `E:/Project/OPS ERP/thuonghao-ops-erp`, existing C branch/PR388. Fresh origin/main at planning is `d102b2f1b083005d6553867fa5ccdf8c988a0316` (accepted 109); reverify before code. A2/B are separate frozen Drafts, not dependencies; no copied helpers/schema.
- No merge, manual deployment or hosted database writes. Automatic Pages previews are separate. No Production/v1/Retool mutations, staff assignment/grants, Warehouse/operatorD or real commitments.
- One Actor may hold existing capabilities/scopes for ordinary work; no second-person requirement. Existing exception owners/audit remain.
- Valid current released NEED_GENERATION only; upstream-source-stale/WHOLESALE/supplier-direct/ambiguous chains fail closed. No Need-run regeneration or source bypass.
- “Raw Handoff fingerprints remain different and immutable.” Keep raw source projection/writer expected-source binding; separate derived applicability only.
- “Prospective eligibility alone never makes an official document current.” During REOPENED, missing current Handoff is pending, never zero.
- Existing Supplier eligibility guards stay at their approved Save/readiness/release boundaries; do not add current Master Data eligibility as a new historical PO/PXK stale reason.
- Keep authenticated 8s and Preparation-only 20s, exact quantities/Unit identities/snapshots/RLS/ordinary editing guards. No timeout increase, table/lifecycle/status/capability/role/dependency additions.
- Fresh owned C schema-applied 109 DB; preserve all existing DBs/volumes. No fabricated migration ledger. Authentic public business commands must create tested immutable history, not replica/private-helper fabrication.

## Authority and file reach

Authority-only stored-plan/baton commit precedes Task1 fixture/tests: record approval quotation/meaning and reviewed spec; `TASK1_ONLY` for the released baseline/fixture/RED scope; Tasks2–8 remain gated on reviewed fence/dependencies and an exact later release. Current bounded unrelated CI focus repair remains separately recorded, not C business authority.

Create migration with `pnpm exec supabase migration new operator_confirmed_need_correction`; record actual CLI-generated version/file (not a fixed global 110). Only the new forward file changes database definitions; historical migrations stay untouched.

Create `supabase/local/confirmed_need_correction_fixture.sql` and `supabase/tests/confirmed_need_correction.sql`, `confirmed_need_correction_continuity.sql`, `confirmed_need_correction_scale.sql`. Reuse existing public request/fixture primitives; no general runner/framework. Modify directly affected existing suites: `school_catering_planning_correction.sql`, `purchase_review_confirm_release.sql`, `purchase_preparation_release_projection.sql`, `purchase_preparation_source_ambiguity.sql`, `supplier_allocation_released_read.sql`, `school_catering_purchase_orders.sql`, `school_dispatch_release.sql`, `school_fulfilment_reconciliation.sql`, exact catalog `atlas_current_platform_security_catalog.sql`.

Application reach:

- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts`, `.test.ts`, `confirmedNeedModel.ts`, `reviewConfirmedNeedApi.ts`.
- `src/modules/atlas/connection/atlasRpc.ts`, `.test.ts`: only two exact entries.
- `src/vnext/atlas/bridges/confirmedNeed.ts`: two bounded business methods/types, not legacy release controls.
- `src/vnext/atlas/planning-confirmed/useConfirmedNeedWorkbench.ts`, `.test.tsx`; `ConfirmedNeedWorkbench.tsx`, `.test.tsx`; `ConfirmedNeedTable.tsx`; `ConfirmedNeedSupportDetail.tsx`; `ConfirmedNeedCommandFeedback.tsx`, `.test.tsx`; `confirmedNeedReviewFixtures.ts`.
- New small colocated `ConfirmedNeedCorrectionDialog.tsx`, `.test.tsx` in that directory; no new global state owner.
- Only required additive currentness parsing/copy: `src/modules/atlas/procurement/schoolCateringProcurementModel.ts`, `purchaseReviewApi.ts`, `procurementOperatorCopy.ts`; `src/modules/atlas/dispatch/schoolDispatchReleaseModel.ts`, `schoolFulfilmentReconciliationModel.ts` and direct tests; `src/vnext/atlas/reconciliation/schoolFulfilmentAttention.ts`/`schoolFulfilmentAuthority.ts` if needed.
- Existing `src/vnext/atlas/AtlasConvergence.test.tsx` and legacy `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx` only direct changed interface/dirty journey coverage; preserve ordinary behavior.

Registries: `scripts/certify-supabase-full-integration.mjs`, `scripts/atlas-staging-contract.test.mjs`, existing `scripts/test-local-purchase-review.mjs`, exact nested `scripts/verify-local-school-catering-procurement.mjs` only if reused SQL gains local includes; `scripts/check-atlas-vnext-ui-boundary.mjs`/`.test.mjs` only an exact reviewed business-only bridge entry if necessary. No broad gate allowance.

Docs: current ACTIVE_TASK/spec/threeAPI contracts, stored approved plan, `docs/testing/atlas-operator-confirmed-need-correction-c-01.md` plus selected sanitized artifacts under matching `docs/testing/artifacts/` folder. No old108/109 package/evidence rewrite, producer/UI redesign/config/workflow/package changes.

## Concrete interface contract

Two `atlas_api` functions `(request jsonb) returns jsonb`, SECURITY DEFINER, empty search_path, `atlas_confirmed_need_review_runtime` owner; contract `CONFIRMED-NEED-CORRECTION.v1`:

```ts
type CorrectionPayload = {
  need_generation_run_id: string;
  expected_need_generation_run_version: number;
  confirmed_need_batch_id: string;
  expected_confirmed_need_batch_version: number;
  confirmed_need_line_id: string;
  expected_current_revision_id: string;
  expected_current_decision_id: string;
  proposed_confirmed_quantity: string;
  reason_code: ConfirmedNeedLineRequest["reason_code"];
  reason_note: string | null;
};
type CorrectionPreviewRequest = {
  contract_version: "CONFIRMED-NEED-CORRECTION.v1";
  requested_by_auth_subject: string;
  correlation_id: string;
  payload: CorrectionPayload;
};
type CorrectionCommandRequest = Omit<CorrectionPreviewRequest, "payload"> & {
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_at: string;
  reason_code: "CONFIRMED_NEED_CORRECTION_SAVED";
  reason_note: string;
  payload: CorrectionPayload & { proposal_fingerprint: string };
};
```

`get_confirmed_need_correction_preview` returns existing envelope with exact decimal `before/after/delta`, immutable target identities/versions, complete Need family/contribution/School scope, authorized Procurement details/whole-PO impacts, action/disabled reasons and canonical server SHA256 `proposal_fingerprint`. Gate ALL allocation Supplier identities/splits/notes and PO details by existing `procurement.school_catering.read` plus their exact existing family/whole-PO predicate. A Need-only reader still receives complete Need facts and may correct with existing write capabilities; use constant `procurement_details_coverage: AUTHORIZED_DETAILS_ONLY`, including an empty list. Inaccessible Procurement rows must change neither disclosed data nor the Need proposal fingerprint or correction eligibility. Bind only canonical Need source/version/revision/decision/quantity/reason facts; optional downstream details are not accepted allocation decisions. Test absent/denied Procurement capability/scope and identical preview/digest/write behavior with versus without inaccessible Supplier/PO rows. Always disclose `purchase_order_coverage: AUTHORIZED_DOCUMENTS_ONLY`; empty visible list is not no commitment. Hidden PO existence/count/status cannot affect disclosed output, Apply permission or proposal binding. Procurement-read visibility is not an extra correction-write prerequisite.

`correct_confirmed_need` returns existing command outcome/readback plus unchanged run ID, successor selected R/D and batch version, parent/child receipts/events. Outer expected_version must equal payload batch version; prepare uses separate expected run version, Save uses returned reopened version. Reason follows existing governed quantity rules; outer note is nonblank. No quantity arithmetic or trusted evidence in browser.

API methods `previewCorrection(request)`, `correct(request)`; builders `confirmedNeedCorrectionPreviewRequest(...)`, `confirmedNeedCorrectionCommandRequest(...)` with exact types above. Store complete command once for exact retry.

Prefer existing helpers; only narrow seams required by this plan:

- Private canonical quantity evaluator extracted from existing preview, `atlas_confirmed_need_review_runtime` owner: `atlas_core.confirmed_need_confirmation_evaluate(p_batch uuid,p_lines jsonb,p_actor uuid,p_correction boolean) returns jsonb`. Ordinary public preview retains its lifecycle guard and passes FALSE; C paths pass TRUE after closed guards. No browser lifecycle flag, duplicated rules or write-rollback preview.
- Private `atlas_core.confirmed_need_historical_validation_complete(p_batch uuid,p_attempt uuid) returns boolean`, review-owned STABLE SECURITY DEFINER/empty path, no runtime/browser EXECUTE beyond its owner. Set-based frozen observation completeness is shared by the historical bridge and retained-release eligibility, avoiding whole-batch JSON projection in each integrity trigger.
- Private `atlas_core.confirmed_need_retained_release_evidence(p_batch uuid) returns jsonb`, same review-only posture: a set-based unambiguous revision→decision map from complete successful same-batch release/snapshot/attempt/observation chains. Multiple identical bindings are harmless; multiple distinct decisions for one revision yield no authority.
- Private `atlas_core.confirmed_need_historical_validation_evidence(p_batch uuid,p_attempt uuid) returns jsonb`, owner `atlas_confirmed_need_review_runtime`, SECURITY DEFINER/empty path: validate the exact frozen attempt belongs to the batch, outcome VALIDATED, no blocking issues, complete observation cardinalities and each captured non-NULL R/D. Reuse existing `atlas_core.rmvp_07_validated_facts_projection(uuid,uuid)` inside that owner context, not by granting its EXECUTE alone to procurement: C02 proves the existing projection is SECURITY INVOKER and procurement lacks validation SELECT. Do not use `rmvp_07_validation_evidence_complete(uuid,uuid,bigint)` as historical proof; it intentionally checks today's mutable current pointer/DRAFT state. Return only frozen attempt/observation facts and exact captured revision/contribution identity. No browser/table grant; exact EXECUTE to `atlas_procurement_command_runtime` only.
- Private `atlas_core.confirmed_need_handoff_membership(p_handoff_revision uuid) returns jsonb`, owner `atlas_procurement_command_runtime`, reads existing permitted Handoff/demand/approval/snapshot rows and calls that narrow review bridge. C02 proves review-runtime lacks Handoff line/demand SELECT, so it cannot own this cross-domain query without forbidden table grants. Group distinct `(batch,attempt)` and invoke the whole-batch bridge once per pair, not per contribution/family. Backend-only resolved-context reuse after locks can follow existing106 overload patterns if measured cost needs it; no public trusted context, persistent cache or generic framework. Snapshot lines themselves store R/Ingredient/quantity/Unit but no School/destination. Use the exact referenced immutable `confirmed_need_line_revisions`/`confirmed_need_line_revision_contributions` (which capture customer, School, location, date, Units and source IDs), not the projection's current stable-line School/destination or current Master defaults. Missing captured identity fails closed.
- Private `atlas_core.purchase_review_family_continuity(p_family_revision uuid,p_mode text) returns jsonb`, `atlas_procurement_command_runtime` owner; modes PROSPECTIVE/OFFICIAL only; returns applicable/classification/reasons/proof with retained binding separate from raw current source. Exact runtime-only EXECUTE to `atlas_read_runtime`, `atlas_planning_command_runtime`, `atlas_dispatch_command_runtime` and `atlas_confirmed_need_review_runtime` only where their audited caller uses the proof. No browser grants.
- Private `atlas_core.purchase_review_correction_context(p_batch uuid) returns jsonb`, owner `atlas_procurement_command_runtime`, SECURITY DEFINER/empty path: complete backend Need source universe using existing review-owned `purchase_review_confirmed_source_universe(uuid)` (already EXECUTABLE by procurement), retained PH membership via the frozen review bridge, all contributing batch/run IDs and per-pair proof. Procurement cannot SELECT Need runs; root IDs come from permitted batch/captured revision evidence and existing guarded source projections, then the Need-generation-owned locker reads its own run/input/evaluation tables. Exact context EXECUTE to `atlas_need_generation_runtime` and existing `atlas_confirmed_need_review_runtime`/`atlas_planning_command_runtime` writers only; no browser/table grant. This is one C-specific resolved context, not a generic framework or persistent cache. The scalar continuity helper may consume a private backend-only resolved-context overload to avoid whole-batch projection per family; no request field can supply it.
- Private `atlas_core.confirmed_need_correction_lock_roots(p_batch uuid) returns jsonb`, `atlas_need_generation_runtime` owner, complete advisory/source/run/CN prefix and backend root identities. Exact EXECUTE to `atlas_confirmed_need_review_runtime` and `atlas_planning_command_runtime`; later domain locking extends existing `atlas_procurement_command_runtime`-owned `atlas_core.purchase_review_lock_allocations(uuid)`, not a duplicate writer.

The private data-reading seams above use `SECURITY DEFINER` and `search_path=''`; the separately specified daily advisory helper is explicitly `SECURITY INVOKER`, owner `atlas_owner`. verify owners already have exact table SELECT/row-lock privileges before installation. The plan does not assume a broad table grant. Known necessary private locking bridge: exact existing `atlas_core.purchase_review_lock_allocations(uuid)` EXECUTE to `atlas_need_generation_runtime`, after extending its current CN-only Supplier→family loop to complete Supplier→retained/current PH→family. Its existing supplier helper only locks evidence; it does not add current eligibility or Procurement-read requirements. This is a row-lock delegation under the unchanged prepare JWT/Need-write/release/GLOBAL checks, not a table/membership/operator grant. Known necessary wrapper addition: existing `atlas_api.prepare_planning_source_correction(jsonb)` EXECUTE to `atlas_confirmed_need_review_runtime`, retaining child JWT/Need-write/release/GLOBAL and wrapper Save capability. Two new exact public EXECUTEs to authenticated; deny PUBLIC/anon/service_role. No other browser/private/table access or memberships. Record any actual missing owner/object privilege for Root technical review, do not broaden silently.

---

### Task 1: Fresh public-path fixture and RED contract

**Files:** authority docs, new local fixture/new three SQL suites. **Consumes:** reviewed plan release and main109. **Produces:** isolated schema-applied 109 `atlas_c_correction_02`, real released history and RED logs.

- [ ] Reverify canonical/origin/fresh main/clean/workspace; read mandatory docs plus Supabase/Postgres/TDD/systematic-debugging/executing-plans. Commit bounded authority before runtime edits.
- [ ] Inspect local container labels/ports and DB inventory. Prove `atlas_c_correction_02` absent, then create it in verified `supabase_db_thuonghao-ops-erp`. Replay schema-only Auth prerequisites and109accepted migration files with explicit `-d atlas_c_correction_02`, ON_ERROR_STOP, hashes/list. No reset/drop/defaultpostgres use or fabricated ledger. Preserve all existing A2/B/default/wait DBs and volumes. Outside-repo TEMP adapter of existing include expander changes only explicit DB target; CI uses incumbent runner.
- [ ] Capture baseline catalog/ACL/membership and confirm A2 column/B API absent. Baseline catalog30 must pass. Probe exact named owner SELECT/row-lock privileges for proposed seams.
- [ ] Seed only synthetic source/master/Actor prerequisites using incumbent fixture patterns. Authenticated public source Save→preflight→Need generation→ConfirmedSave→validate/approve/release→Handoff→Allocation→POgenerate/release→PXKrelease creates tested history. Capture actual response IDs dynamically. SchoolsA/B shareL; C another date. ChangedIngredientI and unchanged J; two affected Suppliers plus unaffected Supplier/date. One Actor has existing capabilities/GLOBAL. Every public fixture step raises unless success IS NOT DISTINCT FROM true; no replica-created approval/Handoff/PO/PXK proof.
- [ ] Add undefined new RPC RED and unchanged ordinary released-Save denial. Save before tuples for all unaffected R/D/alloc/contribution/split/PO/PXK IDs, versions, numbers, fingerprints/content.

```sql
select atlas_api.get_confirmed_need_correction_preview(
  (select request from pg_temp.c_requests where name='increase-preview'));
-- Expected main109 RED: function does not exist, after authentic public fixture succeeds.
```

The TEMP adapter is copied from `scripts/test-local-purchase-review.mjs`: replace only its root resolution with the absolute canonical repository root and its explicit database argument with `atlas_c_correction_02`; keep include validation/fail-on-TAP behavior. After creation, the exact focused commands are:

```powershell
node "$env:TEMP/atlas-c-test-purchase-review.mjs" confirmed_need_correction.sql
node "$env:TEMP/atlas-c-test-purchase-review.mjs" confirmed_need_correction_continuity.sql
node "$env:TEMP/atlas-c-test-purchase-review.mjs" confirmed_need_correction_scale.sql
```

- [ ] Run through TEMP explicit-C include expander; preserve exact RED and setup logs. Do not claim business RED until the public released prerequisite journey works. Commit fixture/test checkpoint.

## Open CN-publication fence gate — must clear before Task2 code

Assembled-catalog tracing narrows School CN publication to `atlas_api.execute_need_generation(jsonb)` → `atlas_core.issue_223_execute_need_generation_v2(jsonb)` → `atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)` (ordinary and zero-adoption branches), plus public compatibility `atlas_api.create_confirmed_needs_from_generation(jsonb)` → the same materializer. Readiness/direct run creation/source Saves do not publish CN. Do not automatically patch those nonproducer APIs; audit known-root lock compatibility separately.

Proposed minimum primitive: `atlas_core.confirmed_need_correction_lock_days(p_start date,p_end date) returns void`, owner `atlas_owner`, `VOLATILE SECURITY INVOKER`, `search_path=''`. Validate non-NULL ordered dates within existing caller range contracts, then acquire exclusive transaction advisories `PLANNING-CONTRACT-01:D:D` for every contained day, ascending date. Only exact runtime EXECUTE is proposed: `atlas_need_generation_runtime`, `atlas_planning_materialization_runtime`, `atlas_planning_command_runtime`, `atlas_confirmed_need_review_runtime`, `atlas_procurement_command_runtime`, `atlas_dispatch_command_runtime`; revoke PUBLIC/anon/authenticated/service_role. No table/role/capability grants. Shared days serialize range-versus-day sources even when no current run exists.

Exact early callgraph before existing period/run/input/evaluation/Admin/CN/domain locks:

- execute parent before its old period/run/batch locks, covering both ordinary and zero-adoption nested materialization;
- standalone compatibility materializer after authentication/outer receipt replay but before Admin KEY SHARE, input/evaluation or run rows;
- Preparation and direct School Handoff before target locks;
- new correction; `atlas_api.validate_confirmed_needs(jsonb)`, `atlas_api.approve_confirmed_needs(jsonb)`, `atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb)` and `atlas_api.release_confirmed_needs(jsonb)` before their CN locks; PO/PXK writing continuity consumers before target locks, including every nested parent. Validate/approve take CN then run FOR SHARE today, which otherwise inverts a correction run FOR UPDATE→CN sequence.

A deep materializer call may only reacquire keys already held by its execute parent. Never acquire a new blocking day lock inside a parent already holding a run/input/CN row. Resolve immutable complete periods first; if post-wait universe expands days, reject/retry at the outer boundary rather than acquire an earlier key late. Preserve whole-parent rollback on nested materializer failure. Pure shaped reads do not take blocking day fences. Wholesale remains outside this policy; guard-rejected overlaps remain rejected.

Before Task2 release, review exact signatures/owners/first-lock anchors for all callers. Prove actual Prepare versus public materializer new-contributor race, ordinary and zero nested execute plus standalone compatibility, range-versus-day, overlapping Preparation, compatible known CN/Handoff writers and late nested failure rolling back the entire parent. Existing per-run/advisory/FK KEY SHARE/unique snapshot constraints do not replace this absent-root fence. Complete known-root ordering and fresh checks still apply. Ordinary `save_confirmed_needs` has no established late run-row wait in assembled main109; the historical FOR SHARE anchor belongs to releaseV2, not Save. Do not add an ordinary Save fence without a real conflicting edge. Direct run creation locks input-set→evaluation→run→source rows, so any new complete-root helper must lock required input-set/evaluation rows before runs. Source Save guards take per-run advisory→CN→Handoff before source DML; do not invent the reverse Menu→per-run order. Task1 changes no producer/consumer functions.

### Assembled main109 first-lock anchors and authority

Line numbers below refer to the saved C02 `pg_get_functiondef` byte image (`%TEMP%/atlas-c02-current-entrypoints.json`), not historical migration line guesses. Exact anchors are independently listed in `%TEMP%/atlas-c02-entrypoint-lock-anchors.json`.

| Exact SQL entry                                                                                                                  | Owner / retained authority                                                                                                                                           | New prefix must precede                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `atlas_api.execute_need_generation(jsonb)` → `atlas_core.issue_223_execute_need_generation_v2(jsonb)`                            | `atlas_need_generation_runtime`; existing `planning.need_generation.write`, JWT/scope/outer receipt                                                                  | private body98 period advisory,124 run FOR UPDATE; daily fence after NEW receipt, complete input/evaluation prefix before124; both zero and ordinary paths                                       |
| `atlas_api.create_confirmed_needs_from_generation(jsonb)` → `atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)` | `atlas_planning_materialization_runtime`; existing `confirmed_need_generation.materialize` and full existing source-scope guard or validated internal parent context | materializer237 first Admin KEY SHARE,312 input-set KEY SHARE,314 evaluation KEY SHARE,317 run FOR UPDATE,335 CN FOR UPDATE; execute parent must already hold full day prefix before nested call |
| `atlas_api.validate_confirmed_needs(jsonb)`                                                                                      | `atlas_confirmed_need_review_runtime`; `confirmed_need_validation.validate`, existing GLOBAL, receipt                                                                | 68 CN FOR UPDATE;121+ run/source FOR SHARE                                                                                                                                                       |
| `atlas_api.approve_confirmed_needs(jsonb)`                                                                                       | same owner; `confirmed_need_approval.approve`, existing GLOBAL, receipt                                                                                              | 68 CN FOR UPDATE;114+ run/source FOR SHARE                                                                                                                                                       |
| `atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb)`                                                                  | same owner; `confirmed_need_release.release`, existing GLOBAL, receipt                                                                                               | 69 CN FOR UPDATE;115+ run/source FOR SHARE                                                                                                                                                       |
| `atlas_api.release_confirmed_needs(jsonb)`                                                                                       | same owner; `confirmed_need_release.release`, existing GLOBAL, receipt                                                                                               | 48 CN FOR UPDATE;83 lines FOR UPDATE; all nested lifecycle parents reenter held prefix                                                                                                           |
| `atlas_api.prepare_school_catering_purchase_orders(jsonb)`                                                                       | same owner; existing release+Procurement write, complete existing Need scope and nested GLOBAL requirements                                                          | 49 target CN FOR UPDATE after receipt46–48                                                                                                                                                       |
| `atlas_api.release_school_catering_purchase_handoff(jsonb)`                                                                      | `atlas_planning_command_runtime`; release capability plus complete existing School/Need scope                                                                        | 94 CN FOR UPDATE,97/100 Need KEY SHARE,102 Handoff FOR UPDATE; after auth71–85/receipt88–91                                                                                                      |
| `atlas_api.create_school_catering_purchase_order_drafts(jsonb)`                                                                  | `atlas_procurement_command_runtime`; existing Procurement write and full represented scopes                                                                          | 95 date/supplier advisory before Supplier120→Handoff122→family138; after auth/receipt                                                                                                            |
| `atlas_api.create_school_catering_purchase_order_replacement(jsonb)`                                                             | same owner; existing Procurement write/whole-PO scope                                                                                                                | 80 date/supplier advisory,97 Supplier→99 Handoff→109 family SHARE; resolve canonical target date without locking first                                                                           |
| `atlas_api.release_school_catering_purchase_order(jsonb)`                                                                        | same owner; Procurement write/whole-PO scope61–67 and receipt71–74                                                                                                   | 86 date/supplier advisory,108 Supplier→110 Handoff→120 family SHARE                                                                                                                              |
| `atlas_api.release_school_dispatch_document(jsonb)`                                                                              | `atlas_dispatch_command_runtime`; `dispatch.school_release.release` plus exact109 School/location scope78–82, receipt86–89                                           | 91 dispatch advisory,93 source locker,98 release row FOR UPDATE                                                                                                                                  |

Proposed row modes after the daily/advisory prefix: existing required Admin/source KEY SHARE references in canonical UUID order; all required planning input-set/evaluation rows KEY SHARE before any run row; all known run rows FOR UPDATE, then all CN batches FOR UPDATE; exact line/revision/decision locks at their established command boundary; complete Supplier evidence before Handoff/family locks using existing lock helpers. This is stronger than a bare family loop and preserves direct run creator's input-set→evaluation→run order. Input-set row locks must precede any later evaluation/run wait. Keep Source Save's actual per-run-advisory→CN→Handoff→source-DML order; no fabricated Menu-first order.

PO writers acquire the daily fence, then preserve incumbent Supplier→Handoff→family locking. PXK release acquires the daily fence, then preserves incumbent `school_dispatch_lock_sources` family→PO locking; do not invent Supplier/Handoff locks for PXK. Neither calls the Need-root locker or acquires later Need run/CN row locks. Their official continuity check is a pure read after all incumbent waits, requiring the released current Need and successful successor Handoff. Ordinary released Need Save is already denied; correction/publication/lifecycle writers share the early day fence, and existing source invalidators take CN→Handoff before their source DML. Retain those exact predicates/locks and test invalidation versus domain waits; no new root-locker EXECUTE to procurement/dispatch. This avoids an invented cross-domain prelock protocol/table grant. Pure proof never waits on a Need row while holding domain locks.

The complete actual overlap graph and absent-root tests remain Task2 acceptance obligations, not pre-code conditions or a declaration of proven compatibility. Pure reads never acquire the blocking prefix; unauthorized/replayed requests return before it. The proof is narrow support-identity continuity; every other currentness dimension remains unchanged. Any producer/consumer parent that already holds a later lock must move prefix acquisition up, not acquire it late in a child.

### Existing public lifecycle probe and narrow retained-release support

The main109 C02 rollback-only authentic existing-public probe (captured in session tool trace and the retained initial15-case RED) showed: prepare succeeds without changing four current RELEASED revisions; one-line Save appends only its selected DRAFT revision and retains three RELEASED R/D identities; standalone validation succeeds, but approval returns `VALIDATION_EVIDENCE_INCOMPLETE`. A read-only diagnostic confirms `rmvp_07_validation_evidence_complete` FALSE. From the saved REOPENED savepoint, exact `RMVP-07.v2` release returns `INTERNAL_COMMAND_FAILURE`/unknown; assembled V2 explicitly raises23514 when that same evidence predicate is false. This is a public lifecycle support gap, not a permission bypass or proof V2 currently works. The earlier TEMP V2 request used the wrong contract and returned VALIDATION_FAILED; only the corrected exact-contract report is lifecycle evidence. The diagnostic itself exited0 and rolled back. Its raw JSON/log path was inadvertently overwritten by a post-slice rerun and is not recoverable as original evidence. Retained baseline `%TEMP%/atlas-root-c02-retained-release-baseline-red-20261015.log` has SHA256 `aa05dd0db66d8ddb213dc286f48ae66b058f85286ec15d952fa19f96e5505dc7`; the original15-case RED reports8failures, including V2false and intact three R/D pairs. Stage-suffixed post-slice diagnostics are separate; never relabel them baseline. Independent postflight remained empty.

Task2 preserves DRAFT eligibility and adds retained RELEASED eligibility only where exact immutable prior **successful same-batch release→approval snapshot→VALIDATED attempt→single observation** proves the same stable line/R/D and complete captured facts. Current canonical source/evaluation, exact new complete validation, snapshot membership and fingerprint comparisons remain mandatory. Apply this shared evidence at `atlas_core.rmvp_07_validation_evidence_complete(uuid,uuid,bigint)` and the intermediate APPROVED branch of `atlas_planning.rmvp_07_approval_release_integrity()`; its final RELEASED checkpoint already accepts the status. Existing updates continue only DRAFT→APPROVED→RELEASED, leaving untouched released revisions intact. Never downgrade or append unchanged revisions. Resolve distinct prior `(batch,attempt)` once or use set-based release/snapshot/observation joins, not a whole-batch projection per line/trigger; preserve250-family8s/Preparation20s budgets.

Authenticated positives must release V2 directly from saved DRAFT_REVIEW/REOPENED (or incumbent Preparation); never validate first and then call V2 from VALIDATED. Standalone validate→approve is the baseline diagnostic, not a promised corrected operator path. Keep V1 retained-Handoff conflict and approved-snapshot guards unchanged; initial fixture V1 after approval remains valid. Negative proof must reject RELEASED status without exact prior release authority, another batch/line/R/D, missing/blocked/duplicate observation or stale source, and preserve rollback/history identities.

### Task 2: Immutable continuity and complete root locking

**Files:** C migration; continuity SQL suite; directly affected source/readiness tests. **Consumes:** Task1 historical evidence and Root/Terra technical clearance recorded in the Task2 authority amendment; actual wait/cycle/rollback proofs remain acceptance work. **Produces:** separate prospective/official proof and an audited prelock protocol.

- [ ] Write RED cases reconstructing the original decision from Handoff line → demand snapshot line → approval snapshot's validation attempt → immutable validation observation's decision ID. Test same totals with different R/D, D-040 newR, another School changed in the same family, missing/extra contributors, missing historical evidence, overlapping sources, changed-then-reverted adjacent edges, gaps/cycles. Exact cardinalities and null-safe predicates are required; nullable bool_and cannot prove every line. A valid modern released NEED_GENERATION requires exactly one non-NULL decision and a complete VALIDATED attempt/observation. RMVP06 validated_shape_check215–233 and CURRENT_DECISION_MISSING851–869, plus RMVP07 validation_evidence_complete1933–2010 enforce this. NULL observations are BLOCKED diagnostics, not release authority; both a missing row and a blocked NULL deny continuity. This preserves existing release requirements and adds no confirmation step. The public journey must prove the actual untouched-family authority.
- [ ] Add public mixed-status lifecycle RED described above, then narrow both retained-RELEASED checkpoints through exact successful prior release evidence; prove direct V2 succeeds with unchanged R/D retained and forged/missing evidence fails. Preserve V1 guards and ordinary released-Save denial.
- [ ] Implement full set comparison of stable family/date/location/Ingredient/Unit, every immutable R/D, captured School/customer/destination/source facts and exact quantity. Compare complete retained Supplier split IDs, quantities, ratios, origins and notes. Traverse every adjacent predecessor; no skipped edge, endpoint shortcut or physical line reparenting. A traversal bound fails closed.

```sql
not exists (
 select 1 from historical_membership h
 full join current_membership c using (confirmed_need_line_id)
 where h.confirmed_need_line_id is null or c.confirmed_need_line_id is null
    or row(h.revision_id,h.decision_id,h.school_id,h.customer_id,
           h.delivery_location_id,h.unit_id,h.quantity,h.source_facts)
       is distinct from
       row(c.revision_id,c.decision_id,c.school_id,c.customer_id,
           c.delivery_location_id,c.unit_id,c.quantity,c.source_facts)
)
```

- [ ] Return derived classifications only: EXACT_CURRENT, PROSPECTIVE_UNCHANGED, OFFICIAL_CONTINUITY, CORRECTION_PENDING, AUTHORITATIVE_ZERO, SOURCE_UNAVAILABLE. PROSPECTIVE checks complete current CN facts before Planning release/new Handoff. OFFICIAL additionally requires current released Need, complete approval/release and successful explicit successor Handoff. During REOPENED, absent current Handoff is pending. Zero requires complete authoritative evidence, never missing or ambiguous source. Raw projection/fingerprint stays unchanged.
- [ ] Derive the complete backend root universe: retained PH families and every contributing current/retained CN/source/run/Handoff root, invalidated predecessors, overlaps and zeros. Acquire all source/advisory keys (including existing `atlas:planning-correction:<run>`) in fixed namespace/kind and identity order, all contributing planning input-set/evaluation rows before Need run rows, then all CN batch UUIDs, immutable R/D evidence by plain reads or compatible KEY SHARE only (no early FOR UPDATE before Supplier FK parents), complete Ingredient/Supplier evidence, all Handoff batches/revisions/predecessors, then all families/revisions/splits. No correction/Preparation/Handoff target-first child begins before that full prefix. PO/PXK writers use the narrower domain protocol above, never this Need-root locker. After all waits rebuild raw context and independently resolve current/origin/revision run references, owning input-set/evaluation/run IDs and day bounds; batch/family IDs alone are insufficient. Reject earlier-root expansion or days outside the held prefix, never acquire them late. Root enumeration is raw overlapping NEED_GENERATION batches plus retained/current allocation/PH links, independently of shaped source-universe omission, continuity, quantities/zeros or Procurement visibility. Use shaped sources only for authoritative facts.
- [ ] Amend initial locking in eligible prepare, standalone Planning release, Preparation, Handoff release/promotion and release triggers. Audit compatibility with old Save, generation/source correction, Handoff Save, PO and PXK. Preserve Supplier→Handoff→family order; no new earlier root after a later lock. Record the exact acquisition graph before implementation. Extend migration105's CN-only `purchase_review_lock_allocations` to retained PH families with NULL CN-source column and every contributing root, not just the target School/batch.
- [ ] Run actual two-session cases in separate proven-owned C databases: retained PH Save holds Supplier/Handoff/family; CN Save holds a contributing root; overlapping Preparation calls use opposite targets. Observe a real Lock wait before committing the other session; prove fresh rejection or correct serial success, no deadlock and zero partial child effects. Preserve exact final source hashes and responses/counts. Coordination elapsed is not a pure RPC benchmark. Commit GREEN proof/lock checkpoint for Terra.

### Task 3: Closed preview and atomic correction command

**Files:** new CLI migration, correction SQL suite. **Consumes:** Task1 history, Task2 reviewed fence/prelock primitives and current canonical prepare/Save. **Produces:** two public RPCs, shared quantity evaluator, exact grants/receipts.

**Technical release:** Root authorized Task3 after Terra cleared fixed `b54eaf0` private/full-file checkpoint and the required genuine public publication/PH Save/CN Save/zero-parent-rollback/opposite Preparation wait proofs. Standalone CMD15 publishes CN from an existing staged run, not a new run; overlapping Preparations correctly serialize and both succeed without new PO work. Preserved harness mistakes are not feature RED. Task4 consumers/UI remain later checkpoints;250-family/history budgets remain Task7, not claimed here. Implement this task as the sole Sol6.1 writer under the human-approved design; no extra human approval or execution-choice roundtrip.

**Exact bridge authority (before grant):** Root cleared `atlas_core.confirmed_need_correction_procurement_details(uuid,date,uuid,uuid,uuid)`, Proc-owned STABLE SECDEF/empty path, only Review EXECUTE. Owner SELECT on the eight existing allocation/PO/Supplier relations and EXECUTE on capability authorizer, incumbent location-family scope and whole-PO scope helpers were probed TRUE. Resolve Actor only from outer JWT. Capability success/SCOPE_DENIED then exact family predicate; independently whole-PO scope/current revision family links/frozen official labels. Denied/hidden arrays have constant authorized-only coverage and no extra flags/counts. Public preview appends after Need digest/action, command never calls it. No new table/browser/membership grant.

**Source-current technical authority (before grant):** Exact `atlas_core.confirmed_need_correction_source_current(uuid)` is Read-owned STABLE SECDEF/empty path, Review-only EXECUTE, boolean from captured run period/ID/version and existing authoritative preflight CURRENT/exact current-Need identity/version (including107 effective composition). No public source payload or Procurement dependency, no table grant. Capture/restore Read's transient authoring membership/schema privileges inside the same migration. Review's existing Need-run SELECT was independently probed TRUE. Prove guarded upstream source drift and hidden PO noninterference; reapply the complete file to a fresh baseline before acceptance.

**Measured details-owner amendment (before redefinition):** School-scope RED exposed the absent Procurement Schools RLS policy; the invoker predicate is TRUE as postgres and FALSE under Procurement. Root verified the existing read functions, eight relation SELECTs, three helper EXECUTEs and School SELECT policy under `atlas_read_runtime`. Supersede only the new details bridge's owner with Read; keep the exact signature/STABLE SECDEF/empty path and sole Review EXECUTE. No RLS/table/human authority expansion. Record this actual RED→GREEN rather than masking it with a School policy grant.

- [x] Write RED cases: unknown/null/wrong type envelope/payload; mismatched outer/payload version; wrong JWT/missing each capability/GLOBAL; source/run/batch/line mismatch/stale; bad precision/reason/Unit/policy; strict NEED_GENERATION target filter/upstream stale (positive Wholesale journey not attempted); write permitted without Procurement-read. Preview must change no facts/receipts.
- [x] Extract canonical quantity evaluator without changing ordinary preview errors/lifecycle. Implement new preview and command with owner/ACL above, not a public bypass flag.
- [x] Implement exact command order using existing prepare/finish receipt helpers:

```text
closed envelope/JWT/all capabilities+scope
 -> outer receipt lookup: exact stored replay OR conflicting replay rejection
 -> NEW only: Task2 approved daily fence + complete canonical prelocks; fresh target/source/proposal checks
 -> one exception subtransaction:
      prepare(existing command, deterministic child stage 'prepare')
      require success or raise controlled rollback sentinel
      Save(existing command, stage 'save', returned reopened batch version)
      require success; force deferred constraints before success
 -> failure: rollback all new child facts/receipts/events; finish allowed outer failure only
 -> success: finish outer with exact authoritative readback
```

- [x] Distinct deterministic child IDs/receipt-derived stage keys; never outer-ID reuse. Exact replay occurs before mutable currentness, including after its own successor or a later correction. A child failure JSON alone cannot roll back prior effects: raise inside the subtransaction. Retryable rollback must not retain success/child evidence.
- [x] Prove actual late Save failure after potential reopen by changing a real canonical prerequisite; compare run/batch/Handoff/R/D/receipts/events before/after. Positive correction creates only selected successor, no new Need run/Allocation/PO/PXK release. Assert exact/conflicting replay and original response after later correction.

```sql
select is((select response from pg_temp.c_results where name='replay-after-later-correction'),
          (select response from pg_temp.c_results where name='saved-correction'),
          'successful exact replay survives later mutable changes');
```

- [x] Run new matrix plus ordinary Save/release/planning-correction regressions; commit GREEN command checkpoint with source hash for Terra.

### Task 4: Canonical consumers and explicit affected successors

**Files:** same C migration/continuity suite and affected incumbent Allocation/Preparation/PO/PXK/reconciliation SQL tests only. No TS/model/UI/transport/registration reach in this phase. **Consumes:** Task 2 proof/prelocks. **Produces:** canonical affected-only handling with exact unaffected identities.

**Technical release:** Root authorized Task4 only after Terra cleared fixed Task3 `3287c27d0f23ddb5e5cbe24fe3bafe88fc028cf6` (83+70+45). Commit this boundary before runtime edits. Use one owning-backend continuity context per source batch/read and resolved three-argument family proof; report exact required Read EXECUTE/callers for technical clearance before adding any grant. Proc-owned callers need no new grant. Include direct public PO Draft/replacement/release filters, not only shared staleness, and PXK's direct old-Handoff/current split joins; preserve all unrelated captured dimensions. Restore four prior Task2 comment arrows separately, with explicit UTF-8; no baseline replay solely for comments. A2/B remain independent unmerged Drafts; narrow anchored amendments must not silently erase their later combined changes. Tasks5–8 remain held.

- [ ] Capture public-path RED: a selected I correction must not force unrelated J/Supplier/day replacement; pending Handoff absence must not become cancellation-required. Save exact allocation revision/contribution/split and PO/PXK IDs, versions, fingerprints, numbers and frozen contents before/after.
- [ ] Use PROSPECTIVE in `purchase_review_allocation_ready` including its `(uuid,jsonb)` overload, `purchase_review_preparation_allocation_ready`, default materializer and Preparation status. Retain insert-only defaults, manual splits/notes, existing eligibility boundary and Preparation GLOBAL. Unchanged retained PH can cover current facts before releases; changed families require explicit allocation Save.
- [ ] Use OFFICIAL in promotion to skip persistence/version/event changes for a proven unchanged PH family after explicit releases. Preserve contribution/split identity and interval School coverage. Changed families follow existing Save/promotion. Never replace raw writer fingerprints with an old fingerprint.
- [ ] Wire confirmed-allocation read/source routing; PO stale/date coverage/commitment/frontier; and PXK preview's direct old-Handoff is_current/status gates, exact split-ID joins, workbench/reconciliation and duplicate-current guard. All must share the official proof or explicit pending classification. This proof bridges only renewed supporting Handoff identity: preserve every other existing PO/PXK fingerprint dimension and predicate (captured routing/grouping, PO revision, destination and complete source provenance). Test semantic routing/PO-revision changes remain affected; never use family continuity to ignore them. Keep whole-PO authorization independent, exact School scope 109 and no new current-Master eligibility test for historical official staleness.
- [ ] Execute real correction→existing Allocation Save→Preparation→complete affected PO replacement→explicit PO release→explicit PXK successor. Cover increase/decrease, multi-Supplier transfer, equal Supplier totals with changed School lineage. Zero or an orphaned Supplier obligation remains at the existing cancellation frontier. Assert old released content and unaffected IDs/numbers/versions/fingerprints exact; no automatic release.

```sql
select is((select document_ids from pg_temp.c_observed where phase='after'),
          (select document_ids from pg_temp.c_observed where phase='before'),
          'unaffected PO/PXK identities survive support renewal');
```

- [ ] Run affected incumbent allocation convergence, purchase review, Handoff, source ambiguity/release projection/released read, PO/PXK/reconciliation/notes. Record exact TAP plans and failures. Commit backend checkpoint/hash for Terra while frontend work begins.

### Task 5: Exact transport and recovery controller

**Files:** API/model/registry/bridge/review adapter and tests; current Confirmed Need controller/test. **Consumes:** Task3 envelopes/readback. **Produces:** one preview, one atomic command and exact-request recovery under the existing dirty owner.

- [x] Write RED tests for the exact two RPC map entries and closed requests, six-place quantity/IDs, outer/payload version equality and unchanged ordinary Save. No browser prepare/Save orchestration. Add only the exact bridge methods/types; run boundary gate immediately.

```ts
expect(invoker.invoke).toHaveBeenCalledWith(
  "atlas_api.correct_confirmed_need",
  request,
);
expect(invoker.invoke).not.toHaveBeenCalledWith(
  "atlas_api.prepare_planning_source_correction",
  expect.anything(),
);
```

- [x] Implement builders/parsers and correction state within Confirmed Need's existing dirty owner. Preserve ordinary released-editing guard and13 persistent owners. Quantity/reason edits invalidate preview; selected context/date/School epochs reject late responses. Server owns delta and impact.
- [x] Build one complete command on explicit Save, retain it for UNKNOWN/retry. Lock edits/close/date/context/module/signout while outcome is unknown. Retry identical ID/time/payload. Stale preserves input but requires fresh preview. Read authoritatively once after success; show success only with certainty and return focus after busy/readback clears.

```ts
await act(() => controller.correct());
const first = api.correct.mock.calls[0][0];
await act(() => controller.retryCorrection());
expect(api.correct.mock.calls[1][0]).toEqual(first);
expect(api.save).not.toHaveBeenCalled();
expect(api.releaseSaved).not.toHaveBeenCalled();
```

- [x] Test missing capability, server reason, late preview/context, read failure after success, UNKNOWN/exact retry/recovery, dirty date/School/module/signout Cancel/discard and completed-readback focus. Align review mocks with selected dates/Schools and append only selected line. Run tracked API/controller/registry tests excluding mirrors; commit.

### Task 6: Incumbent correction dialog and browser proof

**Files:** workbench/table/detail/feedback, one colocated correction dialog/test and existing review fixtures/stories. **Consumes:** controller/server preview. **Produces:** explicit Vietnamese operator review/Save with separate existing release actions.

- [ ] Read incumbent v3/A+/Chakra, scoped Impeccable and Vietnamese-copy guidance before UI edits. RED accessible flow: released row action “Điều chỉnh nhu cầu”, ordinary editor disabled, exact before/after/delta, full family/School scope, visible PO review, explicit “Lưu điều chỉnh”. No redesign/init/dependency.
- [ ] Show canonical human labels or controlled warnings, never technical UUID/code or false zero. Resolve a preview-only current Unit name without A2 schema/helper. Always disclose authorized-documents-only coverage, including an empty list; do not imply no commitments. Genuine zero shows its cancellation guard.
- [ ] Use incumbent focus/accessible labels/dirty dialog recipes. Cancel preserves form; Discard clears it. Retain date/context guards and return focus after busy clears. For jsdom exit transitions use existing wait closed→animationcancel→removal pattern where needed; no sleep, hidden query or larger timeout.
- [ ] Extend only existing in-memory review APIs/fixtures for positive/zero/pending/UNKNOWN/retry cases. Run affected workbench/dialog/controller/feedback and legacy Confirmed Need caller tests. Root browser QA at1280/1440/1920 uses `atlas-vnext-review.html`, not connected index; verify positive Save/scope/zero/dirty Cancel-discard/UNKNOWN/focus/no overflow. Freeze UI during captures; run one final Impeccable scan. Producers remain unchanged, so no native export recertification.

### Task 7: Historical consumer/export, scale, catalog and registration

**Files:** new scale/continuity suites, exact catalog, incumbent registry/contract tests and existing official export tests. **Consumes:** final public journey/backend. **Produces:** focused local evidence and exact-head CI reach.

- [ ] Read actual old released PO/PXK snapshots through their authenticated official consumer after replacement/successor, feed them into unchanged existing export producers, and compare frozen School/Supplier/number/exact quantity/lineage. Raw database hashes alone are insufficient. Use existing ExcelJS cell/metadata and PDF producer checks, without A2/A4 copies or whole-page/native print claims.
- [ ] Build genuine current 50 Schools × 5 Ingredients=250 whole families through public generation/release. Small fixture owns mixed-Supplier/document correctness. Measure preview, selected atomic correction, prospective readiness and official reads separately with actual family counts and predecessor-chain lengths. Preparation is measured separately at its existing 20s budget; other required authenticated paths retain 8s.

```sql
set local statement_timeout='8s';
set local lock_timeout='1s';
set local role authenticated;
select clock_timestamp() as started_at \gset c_preview_
select atlas_api.get_confirmed_need_correction_preview(
 (select request from pg_temp.c_requests where name='scale-preview'));
select extract(epoch from clock_timestamp()-:'c_preview_started_at'::timestamptz)*1000
 as elapsed_ms;
```

- [ ] Keep separate timing statements. Preserve any failure, profile repeated source/proof work and optimize only backend-resolved reuse after locks; do not reduce 250 families or increase timeout. Report local workload limits, no hosted-scale certification.
- [ ] Prove a fresh owned `atlas_c_correction_forward_01` absent, install 109 baseline, verify catalog then apply full C transaction once. Record committed LF blob and actual applied byte hashes separately if CRLF differs, with normalized byte equality. A migration failure rolls back DDL/transient authoring grants; final memberships/SET=false must match baseline.
- [ ] Explain exact function/EXECUTE catalog changes, including PUBLIC ACL not covered by CAT22. Assert owners/security/path and private browser denial; new public authenticated-only. Update exact CAT14/15/17/18/21/22 counts/digests only from explained clean rows. No table/policy/trigger/capability/role or unrelated catalog change. Prefer reusing an existing helper over creating an unnecessary new layer; catalog counts follow actual minimal implementation.
- [ ] Register all three SQL suites in `DATABASE_TESTS_BEFORE_BROWSER` and its existing purchase-review include-expanding group. Search every caller of reused SQL that gains local includes, including nested procurement verifier; use the existing expander, no new runner/config. Reproduce caller-registration RED before correction.

```ts
for (const file of [
  "confirmed_need_correction.sql",
  "confirmed_need_correction_continuity.sql",
  "confirmed_need_correction_scale.sql",
])
  expect(commands).toContainEqual({
    command: "node",
    args: ["scripts/test-local-purchase-review.mjs", file],
  });
```

- [ ] Run `pnpm exec vitest run scripts/atlas-staging-contract.test.mjs scripts/check-atlas-vnext-ui-boundary.test.mjs --exclude '**/.superpowers/**'`, exact changed API/controller/dialog/models/official-export tests, `pnpm typecheck`, `pnpm ui:vnext:check`, exact-file Prettier and post-commit `git diff --check origin/main..HEAD`. Keep exact TAP/test counts from tracked sources. No local routine full suite. Root owns existing manual local-only Full Integration on fixed Draft head.

### Task 8: Evidence and fixed Draft review

**Files:** ACTIVE_TASK, stored reviewed plan/spec/three contracts and one bounded validation report/artifact folder. **Consumes:** actual RED/GREEN, catalog/wait/scale/browser/export evidence. **Produces:** single implemented C Draft at fixed review SHA, not merge/deployment authority.

- [ ] Record actual files, byte hashes, schema-versus-ledger distinction, counts and limits, exact real waits, catalog delta, repaired failures and remaining material concerns. Preserve original failures; no fabricated pass or credentials/full business rows/whole workbooks.
- [ ] State forward-only migration/no backfill or destructive data change. Local synthetic transactions roll back; preserve all existing DBs/volumes. Hosted repair would need a separately approved forward corrective migration; dropping immutable facts or client rollback of commitments is not a rollback plan. No hosted action in this task.
- [ ] Mark actual implemented contracts only after proof. ACTIVE_TASK becomes IMPLEMENTED—Draft review/exact-head CI pending; hosted remains 109 and no-merge/manual-deploy/hosted-write brief boundary remains. Deferred A2/B/Warehouse/D are not approved or copied.
- [ ] Format/links/NFC, complete diff and post-commit range whitespace; push PR388 Draft and attach. Report fixed SHA/files/logs/sanitized artifacts/exact CI statuses. Root/Terra fixed-head audit and exact-head Frontend/Smoke/Full are required; do not ready/merge/deploy/grant staff/issue real commitments.

## Canonical references

- Accepted D-044 `docs/decisions/decision-ops-v1-school-fulfilment-closeout.md:42` and approved `docs/superpowers/specs/2026-09-07-ops-v1-school-fulfilment-closeout-design.md:99`/4.1.
- Prepare `20260823090858_issue_222_closed_loop_planning_corrections.sql:765`; D-044 reopen `20260907110000_school_need_downstream_correction.sql:84`; Save `20260811011339_confirmed_need_save_release_boundary.sql:437`; preview `20260803102941_rmvp_05_connected_confirmed_need_review.sql:791` (all under supabase/migrations).
- Historical decision projection `20260805202517_rmvp_07_connected_confirmed_need_approval_release.sql:1490–1510`; Handoff raw projection/new lines `20260831090000_school_catering_handoff_allocation.sql:774/1102`; promotion `20260903072648_purchase_review_confirm_release.sql:793`.
- PH NULL lock omission `20261013082420_atlas_purchase_preparation_release_projection.sql` `$allocation_locks$`; defaults `20261012101517_atlas_preferred_supplier_default_preparation.sql`.
- PO stale `20260831120000_school_catering_purchase_orders.sql:279`; frontier `20260908225248_purchase_preparation_replacement_frontier.sql:13`; PXK direct source/split/fingerprint/duplicate seams `20260907130000_school_dispatch_release.sql:191/228/304/344–347/792–807`. Later migrations remain current-definition authority.
- Current ordinary released UI guard `src/vnext/atlas/planning-confirmed/useConfirmedNeedWorkbench.ts:383`; upstream Menu/Attendance/Pantry `planningCorrectionApi.ts` union stays unchanged.

## Spec coverage / review checkpoints

| Requirement                                                                  | Deliverable                                              |
| ---------------------------------------------------------------------------- | -------------------------------------------------------- |
| Positive complete replacement/explicit PXK successor, transfer/zero frontier | Tasks 1,4,7 public journey and old official export       |
| Closed preview/atomic prepare+Save/no new run                                | Tasks 1–2,5                                              |
| Exact/conflicting replay before mutable checks and after later correction    | Task3 public receipt/child-count tests                   |
| Exact full immutable family/R/D and every adjacent edge                      | Task2 null-safe membership/edge matrix                   |
| Prospective before release, official after released Need+successor Handoff   | Tasks 3–4 readiness/pending/currentness matrix           |
| Complete roots before target locks, PH NULL gap, fresh after-wait proof      | Task2 graph audit, absent-root fence race and real waits |
| Raw fingerprints/all other dimensions retained; exact unaffected IDs         | Tasks 3–4 tuple/hash and changed-routing negatives       |
| Canonical Allocation/PO/PXK/read/reconciliation/release consumers            | Task 4                                                   |
| One Actor/capability/scope/precise runtime EXECUTE/catalog                   | Tasks 1–2,7                                              |
| Dirty/context/focus/UNKNOWN/original retry/server authority                  | Tasks 5–6                                                |
| Fresh109/no A2B/genuine history/50Schools250families/8s+Prep20s              | Tasks 1,7                                                |
| Include callers/Draft/exact CI/no hosted writes                              | Tasks 7–8                                                |

Backend freezes after Tasks2 and3–4 go to Terra while Sol handles UI; final fixed SHA audit covers all deltas. Root may own isolated wait/browser evidence, never simultaneous source writes. Concrete technical stops are missing immutable evidence, incompatible earlier-root acquisition requiring wider caller reach, exact owner/object privilege gaps beyond named runtime EXECUTE or measured need for persisted support. Report the actual object/call path/failing assertion, not a generic permission request. Never substitute totals-only continuity, broad grants, source bypass or larger timeout.

## Prepared baton

ATLAS-OPERATOR-CONFIRMED-NEED-CORRECTION-C-01. Human approval of340721 recorded with explicit positive PO/Dispatch successor interpretation and true-zero guard. Phase TASK2_ONLY: Task1 locally committed; reviewed private proof/fence/retained-release support and tests released by Root after this authority amendment. No public C APIs/wrapper/UI yet; Tasks3–8 remain technical checkpoints. Allowed reach is the file map and Tasks 1–8; record the actual CLI migration file once created. Same C branch/PR388, reverified main, frozen385/386/387 not dependencies. No merge/manual deployment/hosted writes/staff grants/real commitments/Warehouse/D. One authorized Actor, existing capability/scope/audit/exception owners. Sole Sol6.1 executing-plans, Root/Terra review; no repeated approval phrase or execution-mode question.

## Task2 first-slice checkpoint — not complete Task2 acceptance

CLI file `supabase/migrations/20261015065552_operator_confirmed_need_correction.sql` first proof slice has LF/applied SHA256 `c3f6f97861aec0009d35e152a94e41e43ab57b8446ba7f856417e6a69fcf6d4b` (zero CRLF pairs). Fresh proven-absent `atlas_c_correction_forward_01` replayed109 original d102 Git blob files, no CLI ledger; baseline catalog30/30, then this forward slice applied once. `%TEMP%/atlas-c-forward01-task2-retained-slice-proof.json` records29/29 focused GREEN, exact global membership/role/schema ACL equality and independent zero Actor/Needline/receipt/PO/PXK residue. Catalog121API/352private/1859 targetgrants: three exact private proofs and one procurement→historical bridge EXECUTE only; tables117/policies674/triggers126/capabilities31/authenticated APIs118 unchanged. No new public C API.

The positive lifecycle case explicitly saves both current allocation families through authenticated existing commands before direct V2 release; this preserves strict existing allocation readiness and proves only the retained-RELEASED lifecycle repair. It does not claim unaffected allocation IDs yet. Wrong/missing/NULL historical attempt, historical supersession, exact ACLs and a public same-R/new-D denial are covered. Source/schema authoring failures rolled back transactionally; global equality was checked on failure and success. Fence/root/continuity consumers, actual waits and250-family performance remain Task2/later acceptance work, with no timing-budget success claim.

Root/Terra technical refinement after first-slice review: standalone Need-owned prepare may execute the existing proc-owned allocation locker through the one exact private EXECUTE above. Lock complete Supplier evidence, then PH batch/revision rows FOR UPDATE before family rows, avoiding a later PH lock upgrade while an incumbent PH Save holds KEY SHARE and waits on a family. Need-owned root locking never joins PH/allocation tables or locks immutable Need R/D FOR UPDATE; those reads remain in their existing owner boundaries. Actual old-PH Save/FK wait and source-rebind races remain acceptance tests, not claimed proofs.

## Task2 fence/root checkpoint — still partial acceptance

After first slice `26877d4`, authority `d397293` records the exact Need→existing proc locker EXECUTE. Current migration LF SHA256 is `da7d0b2f9cc3b16888bfe97d48461935171d878e37bb615dd3f43c314e9373bb`. The full file retains one outer BEGIN/COMMIT with transient authoring membership/schema ACL restoration inside it. On owned forward01, development suffixes installed transactionally; final complete-file fresh forward remains pending. Focused suite45/45 passes. Catalog121APIs/356private/1874targetgrants, unchanged117tables/674policies/126triggers/31capabilities/auth118; independent Actor/Needline/receipt/PO/PXK residue0. `%TEMP%/atlas-c-forward01-prefix-checkpoint.json` confirms eight private/domain bodies source↔database identical and all captured global memberships/role/config/schemaACLs unchanged. Exact13 existing entrypoints preserve every catalog attribute except reviewed bodies; ordinary Save and pure reads are untouched.

Meaningful owner-boundary failure: new Handoff-membership test43 failed `permission denied for table confirmed_need_releases` under procurement. No table grant. Root approved extending only Review's historical bridge with sorted exact prior released approval-snapshot IDs for that batch/attempt, joined through source-kind/approval/release versions, complete snapshot membership and validated fingerprint. Procurement matches its already-readable snapshot ID to the bridge metadata; no current release pointer is historical authority. That one previously frozen bridge body changes for the actual failing test; the frozen boolean and retained-R map bodies remain unchanged. Historical invalidated Handoff now reconstructs every original R/D; missing history is unavailable, not zero.

Root's real two-session existing-public prepare→validate proof captures baseline Lock/transactionid (expected early-fence RED) and patched Lock/advisory (GREEN) before A commits. B then returns `STALE_CONFIRMED_NEED_BATCH` actual7/expected6 with0child events/audits and all Need/validation/approval/release/allocation/PO/PXK counts unchanged; global roles/memberships unchanged. Reports `%TEMP%/atlas-root-c-prepare-validate-baseline-red.json` / `atlas-root-c-prepare-validate-patched-green.json`; owned wait01/wait02 preserved. Coordination637.601/655.789ms is not pure RPC timing. Actual publication, PH Save and root-rebind races, derived family continuity/consumer reach and250-family budgets remain pending.

## Task2 applicability checkpoint — partial, not consumer acceptance

The next private slice introduces Procurement-owned `purchase_review_continuity_context(uuid)` and resolved `purchase_review_family_continuity(uuid,text,jsonb)` behind the planned scalar entrypoint. Only owning backend code builds the context; no public context parameter, cache table, browser or speculative consumer grant. One historical whole-batch projection per Handoff revision is shared across families when a consumer reuses the context. Exact canonical batch/family fact digests include every captured Need R/D/source dimension; retained contributions and complete Supplier split rows retain their IDs, quantities, ratios, origins and notes. Traversal checks every adjacent predecessor and exact revision numbering, rejecting missing/cyclic paths; visited identity detection replaces an arbitrary128-history rejection. CN-origin official applicability also binds current released Handoff membership to those exact canonical facts, rather than count any current Handoff.

Forward01 suite70/70 GREEN includes unchanged shared-family prospective proof, whole changed-family rejection, reopened official pending, real public all-School zero Save, full retained facts and exact private owner/ACL posture. Resolved-context negative cases intentionally alter internal test contexts and are not claimed as a real successful successor journey. Missing-predicate RED9/56 and an actual missing adjacent-numbering guard RED are preserved in `%TEMP%/atlas-c-forward01-family-continuity-red.log` / `atlas-c-forward01-family-edges-red.log`; final log `atlas-c-forward01-family-continuity-70.log`. Current LF migration hash `4538232b46ee0b45f5ea0b822af4ecf26e64a5839709f6314b39922921a1164f`. Full-file fresh forward, authentic unchanged identity through successor consumers and scale remain separate obligations.

Root's additional actual public waits passed in separately owned databases: ordinary source publication introduces a new run, blocks Preparation on the advisory fence and produces fresh root-expansion retryable rejection (wait04); PH allocation note Save blocks prepare and produces fresh domain conflict (wait06); ordinary CN Save blocks prepare and produces fresh version conflict (wait07). Every B has0child effects; old PO/PXK facts/global role memberships remain exact, and only legitimate A writes persist. TEMP reports named in the active baton record these facts and setup/harness limitations. No timing certification is inferred from coordinated waits, and zero-adoption/standalone materialization/opposite Preparation races are not yet claimed.

Clean complete-file follow-up: fresh proven-absent forward02 replayed109 original Gitblob files and then the complete current LF migration once, one outer transaction. `%TEMP%/atlas-c-forward02-full-migration-proof.json` records exit0 and exact global/schema-ACL before/after equality; `atlas-c-forward02-private-applicability-proof.json` records70/70 GREEN, three new bodies identical to source and zero business residue. Catalog121APIs/359private/117tables/31capabilities remains within the stated private-function reach; raw675policies include the incumbent Unit-lock policy excluded by the existing catalog674 count. This closes the prior complete-file-forward limitation for this exact hash, not remaining consumer/history/scale obligations. Root separately passed unchanged zero-demand suite72/72 including staged-zero adoption and late parent failure/replay; its temporary pgTAP schema USAGE is rolled back, with independent0residue/global equality. Standalone positive materialization wait remains a distinct gate.

## Task3 local GREEN checkpoint — not consumer acceptance

Final LF and applied byte image: `ce1f52211f26653a91ded2af96b22dfda2db5c453d79788deceb2a81f215a81a` (zero CRLF pairs). The complete file applied exactly once, one transaction, after109 original Gitblob migrations and catalog30 on fresh owned `atlas_c_correction_forward_04`; no fabricated ledger. Preserve all prior databases. Reports `%TEMP%/atlas-c-forward04-main109-initialize.json`, `atlas-c-forward04-full-migration-proof.json` and `atlas-c-forward04-source-acl-postflight-proof.json` capture exact source/application, global/schema ACL parity, six body comparisons, Read's eight existing SELECTs/three helper EXECUTEs and zero business residue. Observed catalog123APIs/364private/1889targetgrants,117tables/674policies/126triggers/31capabilities; authenticated APIs120, anon/service0. These are observations, not a passing final CAT-22 expectation; its precise final integration update remains pending. No table/RLS/operator grant or A2/B dependency.

Final public matrix83/83, continuity70/70 and affected107suite45/45 PASS on forward04. Logs `%TEMP%/atlas-c-forward04-confirmed_need_correction.log`, `atlas-c-forward04-confirmed_need_correction_continuity.log`, `atlas-c-forward04-effective-composition-pgtap-green.log`. The107 suite's initial failure was missing authenticated pgTAP schema USAGE, not a business assertion; the TEMP include adapter grants USAGE inside the rollback transaction only. Independent postflight confirms USAGE false and complete global/schema ACL equality. Its two new assertions prove the existing delegation on public baseline generation and explicitly synthetic effective-change DML, preserving the existing fixture's qualification. Earlier forward03 ordinary Save/release37, review41 and Planning correction23 passed at `ddfbc544dd8e4d5b86989855f47c8ec463f96a9a417944f634af1cfdb580148d`; `%TEMP%/atlas-c-forward03-focused-results.json` records the earlier247 total including then76+70. The only subsequent runtime change is explicit preview disabled reasons/coalesced action boolean; do not label those101 as final-hash reruns.

The matrix covers closed outer/payload/type/null/UUID-shaped-number/timestamp boundaries, mismatched JWT, stale run/batch/R/D, no-change before reopen, exact precision, every existing capability/GLOBAL, authorized-only optional Procurement/whole-PO scope, display-name nonbinding, real late canonical Save failure, retryable rollback, receipt/child identity, exact/conflicting replay after its own successor and later ordinary Save. Captured SQL failures use the house outcome envelope with known NO_COMMITTED_CHANGE and recovery read; transport UNKNOWN/controller handling remains later work. The original disabled-reason RED is `%TEMP%/atlas-c-task3-disabled-reason-red.log`; the final83 passes after adding the controlled reason. Three initial new negative assertions expected the wrong incumbent error names and were corrected after tracing the canonical validator; those mismatches are not feature RED.

Additional bounded TEMP QA (not tracked CI regression claims):

- Hidden PO absence→genuine public4PO/3PXK creation: `%TEMP%/atlas-c-task3-hidden-po-proof-02.{sql,log,json}`,8/8. Whole Need-only preview JSON and complete Need facts are equal; exact constant authorized-only coverage/empty arrays, no hidden count/flag. SQL SHA256 `df099c5669f827569aae8238e3710fb772fde56f1d2a04b4bcf3328525f88b8e`, frozen fixture `d40df72e4bf795d846e9b8afe5db6634d9041836b78464a3f6c37f9540721430`. The first TEMP split was mistakenly after Draft creation; its expected0/actual4 harness failure is preserved, not a hidden-data feature failure.
- Genuine public source Save→generation→Need Save/allocation/validation/approval/release→public Recipe adjustment: `%TEMP%/atlas-c-task3-recipe-drift-public.{sql,log,json}`,13/13. Same exact run/CN/R/D stays released while inherited preflight changes CURRENT→OUTDATED; both new C endpoints reject STALE_CONFIRMED_NEED_SOURCE. SQL SHA256 `e6c5ce54f725c8689f3a68b2c2014bcab4c7c06f943fb6cdd930ea1042751da0`. Root's separately owned recipe10 source proof is retained. This is the public adjustment proof; the tracked107 DML is not.

Both TEMP proofs ran at the prior `ddfbc…` source, before the disabled-reason-only change. No proposal/authorization/write implementation changed afterward. Actual late Save UNIT_INACTIVE is induced by an explicitly test-only rollback trigger; it exercises the real canonical prerequisite and all-child rollback, not a manufactured successful history. Initial error-envelope permission failure was fixed by reusing existing `d037_error`, not granting another helper. School-scope RED exposed the initially chosen Procurement owner's missing Schools RLS policy; the preauthorized Read-owner amendment fixed that existing read boundary without RLS/table grants.

The first source/ACL report accidentally hashed UTF-8 source after default cp1252 decoding/re-encoding (`da85d65c…`), not applied bytes. Its original is preserved as `%TEMP%/atlas-c-forward04-source-acl-postflight-proof-original-misdecoded-hash.json`; the corrected report records actual LF/applied `ce1f522…` and repeats six source/database comparisons with explicit UTF-8. The separate full-file application report always recorded the correct bytes; no migration/source/reapply change was needed.

Task3 is ready for fixed-SHA technical review only. Task4 consumer wiring, actual unaffected allocation/PO/PXK identity through corrected release/successor, authenticated historical re-export, UI/UNKNOWN recovery and250-family/long-history budgets remain later obligations. WHOLESALE cannot pass the strict NEED_GENERATION target filter; no positive Wholesale fixture was fabricated. No merge, manual deployment, hosted DB write or real commitment is authorized/performed. Existing automatic Pages preview behavior is separate.

Task4 exact Read delegation, Root cleared before grant: EXECUTE only existing Proc-owned STABLE SECDEF/empty-path `atlas_core.purchase_review_continuity_context(uuid)` and `atlas_core.purchase_review_family_continuity(uuid,text,jsonb)` to `atlas_read_runtime`. Independent fresh04 probe confirms Read currently lacks both. Read-owned allocation workbench, PO commitment/currentness and PXK preview build one materialized trusted context per distinct owning source batch/read and pass the three-argument proof per family; the INVOKER PO-stale helper inherits its incumbent caller. No scalar two-argument, Dispatch, browser or service grant; no table/RLS/membership/Actor authority. Proc-owned writers/readiness/defaults/promotion use owner privileges. Existing public capability/family/whole-PO scope boundaries remain mandatory; no public context input.

Task4 resolved PO reuse, Root cleared before definitions/grants: new private `atlas_core.school_catering_po_draft_is_stale(uuid,uuid,jsonb)` retains atlas_owner/STABLE INVOKER/empty path, exact EXECUTE Read+Proc; new `atlas_core.school_catering_po_commitment_state(uuid,uuid,jsonb)` retains Read/STABLE SECDEF/empty path, exact EXECUTE Proc only (Read owner implicit). Deny PUBLIC/anon/authenticated/service_role, no Dispatch3 grant. Existing two-argument signatures/ACLs remain and build a fresh backend map for standalone callers; Dispatch retains the incumbent two-argument Read boundary. Official PO read resolves context once per distinct source batch for its date range and keys the map by exact current family revision. Writers never reuse pre-lock maps; unrelated PO revision/routing/quantity/split/frozen predicates remain. This adds exactly two private functions and the stated runtime EXECUTEs, no table/RLS/membership/Actor grant or public trusted map/cache/framework.

Task4 resolved School consumers, Root cleared before definitions: owner-only `atlas_core.school_dispatch_release_preview(date,uuid,uuid,jsonb)` and `atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid,jsonb)`, both Read/STABLE SECDEF/empty path, deny PUBLIC/anon/authenticated/service_role and no runtime EXECUTE grants. Existing three-argument entries retain signatures/ACLs; Dispatch uses its existing fresh post-lock Read wrapper. Read-owned workbench/reconciliation resolves one context per distinct owning source batch/date and passes private maps per scope. Preserve complete-family coverage, all-School interval windows before School filtering, exact R/D/contribution/split/covered quantity/current PO revision evidence and duplicate guard. A failed/unavailable family cannot simply disappear from a ready preview. These add exactly two private functions; no public map input, persistent cache or Actor authority.

Task4 measured ordinary-path cost repair, Root cleared before definition: extract `atlas_core.purchase_review_correction_roots(uuid)`, Proc/STABLE SECDEF/empty path, exact EXECUTE Need runtime only (Proc owner implicit), deny PUBLIC/anon/authenticated/service_role; no Review/Planning/Read grant. Existing context's raw period-overlap/CN/retained-PH closure and allocation-ID fingerprint are sufficient for locking; shaped sources are not root authority. Existing `purchase_review_correction_context(uuid)` retains its complete shape and resolves/deduplicates source universe once per raw batch. Both lockers use pure roots for initial/fresh checks with unchanged lock order/run/set/evaluation/period/batch/family/allocation expansion rejection. No trusted mode flag/cache or proof shortcut. Preserve the incumbent exact seven authoritative reconstructions; ordinary regression found23 already at Task3 and eager Task4 reached26. Resolve frozen context/promotion only on actual retained PH support mismatch. Prove closure equivalence and zero/incomplete/invalidated/overlapping roots; Root will rerun actual wait edges on final source. This adds one private function/exact Need EXECUTE, no other authority.

## Task4 checkpoint and later integration obligations

Task4 local backend is GREEN and awaiting fixed-SHA review. The current complete LF/applied migration hash is `b4df9fc0b5585d5c3bfeed1acf0cc5bdf7bb887cabd25ee0bf63bc4b26e1b709`; the [active baton](../../autopilot/ACTIVE_TASK.md#task4-local-backend-checkpoint--review-only) records exact1155 focused assertions, fresh109→C atomic/global parity, six final real waits, preserved failures and the comment-only source-image qualification. No SQL bytes changed during Root's race reruns. Five new private functions and all exact EXECUTEs match the prior technical authorizations; no public context input or additional human authority.

Task7 must include `supabase/tests/confirmed_need_correction_consumers.sql` alongside the existing correction/continuity suites in the existing include-expanding runner/certification lists and exact caller tests. It also includes `scripts/test-local-purchase-review.mjs` and existing `scripts/atlas-staging-contract.test.mjs` runner/caller assertions for a bounded fail-closed TAP completeness fix: a captured TEMP run emitted84 assertions against plan92 and the existing presence-only plan gate could report exit0. Add a focused84/92 negative plus complete positive; require exact assertion count/plan with no weakened business assertions or new runner/framework. The corrected Task4 TEMP adapters already fail incomplete plans; original incomplete evidence remains preserved. This runner maintenance remains Task7, not a premature registration of RED suites.

Task4's exact seven authoritative reconstruction regression remains unchanged. The PXK source-text interval oracle follows the approved private four-argument implementation and also asserts the incumbent three-argument entry delegates; it retains contribution-range and no-ratio checks. The new47-case public consumer suite preserves true-zero Handoff rejection and tests cancellation from released Need evidence rather than inventing a successful empty/partial Handoff. Pending copy (`PO_SOURCE_NOT_READY`) must be mapped in the later UI phase without interpreting every existing `REPLACEMENT_REQUIRED` as permission/instruction to replace.

## Task5 released after Task4 review

Terra cleared fixed76a4b48; Root releases only Task5 transport/builders/parsers/existing dirty-owner recovery. Exact file reach and outcome/lock requirements are in the [active baton](../../autopilot/ACTIVE_TASK.md#task5-technical-release--transport-and-existing-dirty-owner-only). No new dialog, dirty owner, command framework or browser prepare+Save orchestration. SQL remains frozen at b4df9fc0; Tasks6–8/push/hosted actions remain held. All actual legacy/review ConfirmedNeedApi callers must implement the exact new methods rather than optional unsafe fallbacks. Root/Terra review the local Task5 GREEN commit before UI work.

Task7 performance qualification: `school_catering_procurement_date_current(date)` still nests scalar commitment wrappers perSupplier/PO and may reconstruct retained contexts despite top-level resolved maps. Measure full official paths with250 families and predecessor chains before claiming whole-RPC reuse; any necessary bounded backend reuse is a later measured technical repair, not part of Task5.

## Task5 local GREEN handoff

The [Task5 baton checkpoint](../../autopilot/ACTIVE_TASK.md#task5-local-transportcontroller-checkpoint--review-only) records exact two-route transport, closed quantity/R/D binding, existing-owner recovery and in-memory dated caller reach. Focused10-file266 PASS is a prior source image; final three changed API/fixture/controller files111 PASS after the later ordinary-Save/exact-replay test and simulator derived-kind/count update. These overlapping totals must not be added. Final typecheck/boundary/format/whitespace pass. Missing-method/typed-membership RED and two test-authoring failures remain qualified. SQL b4df is unchanged; no push/hosted action.

Task6 still requires real UI focus fallback after the released trigger unmounts, controlled Vietnamese C/pending messages rather than English backend text/raw codes, and actual new C module/signout/browser journeys. Task5 proves existing owner contracts/controller transitions and a still-connected return target only. Root/Terra review the fixed local Task5 commit before any Task6 code.

## Task5 review finding — range correction only

Terra's fixed-bf1bd5e review found the new correction actions/late preview could bypass the existing invalid-range fence while the old released workbench remained loaded. Root releases a bounded controller/test RED→GREEN repair only; [baton authority](../../autopilot/ACTIVE_TASK.md#task5-review-correction--invalid-operator-range) names the exact gap. Preserve form/exact request and existing recovery/dirty semantics. Task6 remains held and SQL b4df stays unchanged.

The bounded Task5 review repair also preserves sticky original UNKNOWN through authentication/client/capability failures on exact retry before receipt lookup. These errors describe the retry's absence of writes, not the original command's outcome. Retain original request and locks until authoritative original resolution; no new response privilege/framework. Add focused committed-loss/retry-denial/exact-success regressions and report any definitive failed-receipt recovery limitation separately.

## Task5 failed-original-receipt technical exception

After controller-only ff87d66, Root/Terra authorize the [exact protocol repair](../../autopilot/ACTIVE_TASK.md#task5-failed-receipt-protocol-exception--authority-before-sql): only two post-begin terminal C failure payloads get stored receipt_id/FAILED_NON_RETRYABLE; all early/inconclusive/retryable responses remain unmarked. Existing transport retains two strings; only the C parser recognizes exact contract/name/command/UUID/NO_COMMITTED_CHANGE/retryable=false resolution. No generic success inference/new function/grant/table/status/framework. Add real receipt/replay/zero-child plus malformed/early-marker negatives and fresh main109→full C forward06/global parity before fixed review. Existing b4df wait evidence remains historical to the unchanged business/fence logic; the new full-file hash must be recorded separately. Task6 remains held.

## Task5 stale-target review correction — authority before code

Root/Terra identified a further fixed-ff87d66 recovery gap: editing quantity/reason clears STALE despite retaining the old target, and a stale preview response returns EDITING. This bounded Task5 repair preserves STALE and feedback across edits, invalidates the preview, and blocks another preview/Save until successful recoverCorrection rebinds fresh run/batch/R/D identity. Classify C-specific STALE_* preview responses as STALE, preserve operator input, and prove Save-stale/edit and preview-stale/fresh-target recovery with focused RED/GREEN. Do not broaden the ordinary stale helper, SQL exception reach, dirty owners or Task6 authority.

## Task5 three-finding repair checkpoint — review only

The [active baton](../../autopilot/ACTIVE_TASK.md#task5-review-repairs--local-green-checkpoint) records the ff87 invalid-range/sticky-UNKNOWN clearance and authority-first failed-receipt/stale-target repairs. Final tracked controller/parser/transport154 PASS, fresh original109 catalog30 PASS, complete-file atomic forward06 and11 exact affected SQL plans1166 PASS. The new LF/applied hash is67820cb240ff42fc96c45833c3a877e776093bc14490d58f35332f5977480d6d; all492 function metadata/ACLs match05,491 bodies exact, only the two authorized correct_confirmed_need terminal metadata payloads differ. Global/schema parity and zero residue are proved after all suites. Existing b4df wait evidence is retained with its actual source hash. Prior7/149 frontend and2/102 backend RED, plus two run-binding test-setup failures, remain qualified separately.

Only exact terminal original receipt evidence can resolve prior UNKNOWN on failure; early/inconclusive/retryable errors remain locked. STALE survives form edits and requires fresh same-context review/rebinding before preview. Human authority/current-run/ordinary Save guards are unchanged. Task5 awaits fixed-head Terra review; no Task6 UI, push or hosted action is released by this checkpoint.
