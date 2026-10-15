# Operator C — Confirmed Need correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One authorized operator can atomically save an append-only released School Need quantity correction, explicitly release affected complete PO/Dispatch successors and preserve provably unaffected supplier/day facts and documents.

**Architecture:** Add a closed server preview and atomic existing prepare-plus-Save wrapper. Derive exact full-family continuity from immutable historical Need revision/decision evidence with separate prospective Preparation and official post-release/Handoff gates; preserve unaffected allocation/contribution/split IDs rather than weaken fingerprints. Prelock the complete contributing root set before target locks, then rebuild proof after waits.

**Tech Stack:** Existing PostgreSQL 17/Supabase SQL/pgTAP, React/TypeScript/Chakra 3, Vitest/testing-library, exact RPC transport and existing integration/review harnesses. No dependency, framework or persisted continuity table.

**Spec:** `E:/Project/OPS ERP/thuonghao-ops-erp/docs/superpowers/specs/2026-10-15-operator-confirmed-need-correction-design.md`, human-approved design source `340721a49788163416176db816477168895f3442`.

## Global Constraints

- Release scope: **TASK1_ONLY** after the stored plan/baton authority commit. Task1 baseline, owner probes, authentic public fixture and undefined-RPC RED are authorized; Tasks2–8 remain behind Root/Terra fence/dependency review. No new C business function or migration definition is authorized. Sol6.1 is sole implementer using executing-plans; no new agents or execution-mode question.
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

`get_confirmed_need_correction_preview` returns existing envelope with exact decimal `before/after/delta`, immutable target identities/versions, complete family/contribution/School scope, retained Supplier splits/notes, visible whole-PO impacts, action/disabled reasons and canonical server SHA256 `proposal_fingerprint`. Always disclose `purchase_order_coverage: AUTHORIZED_DOCUMENTS_ONLY`; empty visible list is not no commitment. Hidden PO existence/count/status cannot affect disclosed output, Apply permission or proposal binding. Procurement-read visibility is not an extra correction-write prerequisite.

`correct_confirmed_need` returns existing command outcome/readback plus unchanged run ID, successor selected R/D and batch version, parent/child receipts/events. Outer expected_version must equal payload batch version; prepare uses separate expected run version, Save uses returned reopened version. Reason follows existing governed quantity rules; outer note is nonblank. No quantity arithmetic or trusted evidence in browser.

API methods `previewCorrection(request)`, `correct(request)`; builders `confirmedNeedCorrectionPreviewRequest(...)`, `confirmedNeedCorrectionCommandRequest(...)` with exact types above. Store complete command once for exact retry.

Prefer existing helpers; only narrow seams required by this plan:

- Private canonical quantity evaluator extracted from existing preview, `atlas_confirmed_need_review_runtime` owner: `atlas_core.confirmed_need_confirmation_evaluate(p_batch uuid,p_lines jsonb,p_actor uuid,p_correction boolean) returns jsonb`. Ordinary public preview retains its lifecycle guard and passes FALSE; C paths pass TRUE after closed guards. No browser lifecycle flag, duplicated rules or write-rollback preview.
- Private `atlas_core.confirmed_need_handoff_membership(p_handoff_revision uuid) returns jsonb`, `atlas_confirmed_need_review_runtime` owner, reconstructs original immutable R/D through demand→approval→validation. It provides exactly needed provenance to the existing runtime-owned continuity consumer; no browser/table grants.
- Private `atlas_core.purchase_review_family_continuity(p_family_revision uuid,p_mode text) returns jsonb`, `atlas_procurement_command_runtime` owner; modes PROSPECTIVE/OFFICIAL only; returns applicable/classification/reasons/proof with retained binding separate from raw current source. Exact runtime-only EXECUTE to `atlas_read_runtime`, `atlas_planning_command_runtime`, `atlas_dispatch_command_runtime` and `atlas_confirmed_need_review_runtime` only where their audited caller uses the proof. No browser grants.
- Private `atlas_core.confirmed_need_correction_lock_roots(p_batch uuid) returns jsonb`, `atlas_need_generation_runtime` owner, complete advisory/source/run/CN prefix and backend root identities. Exact EXECUTE to `atlas_confirmed_need_review_runtime` and `atlas_planning_command_runtime`; later domain locking extends existing `atlas_procurement_command_runtime`-owned `atlas_core.purchase_review_lock_allocations(uuid)`, not a duplicate writer.

All private seams use `SECURITY DEFINER` and `search_path=''`; verify owners already have exact table SELECT/row-lock privileges before installation. The plan does not assume a broad table grant. Known necessary addition: existing `atlas_api.prepare_planning_source_correction(jsonb)` EXECUTE to `atlas_confirmed_need_review_runtime`, retaining child JWT/Need-write/release/GLOBAL and wrapper Save capability. Two new exact public EXECUTEs to authenticated; deny PUBLIC/anon/service_role. No other browser/private/table access or memberships. Record any actual missing owner/object privilege for Root technical review, do not broaden silently.

---

### Task 1: Fresh public-path fixture and RED contract

**Files:** authority docs, new local fixture/new three SQL suites. **Consumes:** reviewed plan release and main109. **Produces:** isolated schema-applied 109 `atlas_c_correction_01`, real released history and RED logs.

- [ ] Reverify canonical/origin/fresh main/clean/workspace; read mandatory docs plus Supabase/Postgres/TDD/systematic-debugging/executing-plans. Commit bounded authority before runtime edits.
- [ ] Inspect local container labels/ports and DB inventory. Prove `atlas_c_correction_01` absent, then create it in verified `supabase_db_thuonghao-ops-erp`. Replay schema-only Auth prerequisites and109accepted migration files with explicit `-d atlas_c_correction_01`, ON_ERROR_STOP, hashes/list. No reset/drop/defaultpostgres use or fabricated ledger. Preserve all existing A2/B/default/wait DBs and volumes. Outside-repo TEMP adapter of existing include expander changes only explicit DB target; CI uses incumbent runner.
- [ ] Capture baseline catalog/ACL/membership and confirm A2 column/B API absent. Baseline catalog30 must pass. Probe exact named owner SELECT/row-lock privileges for proposed seams.
- [ ] Seed only synthetic source/master/Actor prerequisites using incumbent fixture patterns. Authenticated public source Save→preflight→Need generation→ConfirmedSave→validate/approve/release→Handoff→Allocation→POgenerate/release→PXKrelease creates tested history. Capture actual response IDs dynamically. SchoolsA/B shareL; C another date. ChangedIngredientI and unchanged J; two affected Suppliers plus unaffected Supplier/date. One Actor has existing capabilities/GLOBAL. Every public fixture step raises unless success IS NOT DISTINCT FROM true; no replica-created approval/Handoff/PO/PXK proof.
- [ ] Add undefined new RPC RED and unchanged ordinary released-Save denial. Save before tuples for all unaffected R/D/alloc/contribution/split/PO/PXK IDs, versions, numbers, fingerprints/content.

```sql
select atlas_api.get_confirmed_need_correction_preview(
  (select request from pg_temp.c_requests where name='increase-preview'));
-- Expected main109 RED: function does not exist, after authentic public fixture succeeds.
```

The TEMP adapter is copied from `scripts/test-local-purchase-review.mjs`: replace only its root resolution with the absolute canonical repository root and its explicit database argument with `atlas_c_correction_01`; keep include validation/fail-on-TAP behavior. After creation, the exact focused commands are:

```powershell
node "$env:TEMP/atlas-c-test-purchase-review.mjs" confirmed_need_correction.sql
node "$env:TEMP/atlas-c-test-purchase-review.mjs" confirmed_need_correction_continuity.sql
node "$env:TEMP/atlas-c-test-purchase-review.mjs" confirmed_need_correction_scale.sql
```

- [ ] Run through TEMP explicit-C include expander; preserve exact RED and setup logs. Do not claim business RED until the public released prerequisite journey works. Commit fixture/test checkpoint.

## Open creation-fence gate — must clear before Task2 code

Terra proved existing locks do not fence an absent/new overlapping root. `atlas_api.execute_need_generation(jsonb)` private-v2 path uses `PLANNING-CONTRACT-01:start:end`; readiness uses distinct `RMVP-03B:start:end`; direct run creation and compatibility materialization do not share a daily mutex. Per-run advisories, enumerated UUIDs, exact-period uniqueness and FK/KEY SHARE locks cannot prevent a new overlapping CN source.

Concrete candidate for Root/Terra review: reuse **exclusive daily** `PLANNING-CONTRACT-01:D:D` transaction advisory keys, acquired for every date in the union of the request and contributing source ranges, ascending date, **before any existing period/run/input/evaluation/CN/Supplier/Handoff/family lock**. A range acquires every daily key, so differently shaped overlapping ranges contend. Existing period-specific mutexes may be reacquired only after this daily prefix. Do not discover another day late: resolve all immutable periods first and, if root/day expansion is observed after waits, reject/retry at the command boundary without acquiring an earlier key under existing row locks.

The following exact creation/mutation/consumption entrypoints must participate before their first old row/advisory lock; nesting must be audited so an old parent cannot call a newly blocking child after holding later locks:

- `atlas_api.evaluate_planning_input_readiness(jsonb)` (input/evaluation creation);
- `atlas_api.execute_need_generation(jsonb)` and its actual current private implementation; `atlas_api.create_need_generation_run(jsonb)` direct compatibility path;
- `atlas_api.create_confirmed_needs_from_generation(jsonb)` and `atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)`, including every actual private-v2/materializer caller found by source/catalog tracing;
- existing public `atlas_api.save_weekly_menu(jsonb)`, `atlas_api.save_attendance(jsonb)`, `atlas_api.save_pantry(jsonb)` and their guarded nested source mutation paths, before locks/mutations that can invalidate/create source membership;
- consuming correction prepare/wrapper, Confirmed Save/release, Allocation Save, Preparation, Handoff release/promotion and PO/PXK currentness release paths whenever they accept this continuity proof. Read-only unlocked previews may project without holding the transaction-wide prefix but must bind/recheck the same source state under the command fence.

At this plan phase this is a **proposed wider lock protocol**, not a claimed proved implementation. Terra is tracing minimal actual materializer callers. Task1 does not change any of them. Before Task2 release, record the complete exact signature/owner/initial-lock table, select the minimum common entrypoints and prove a real absent-root creation race against a concurrent consumer, plus opposite overlapping ranges without deadlock. A late advisory lock added only inside materialization after its caller holds a run/input row is explicitly invalid. Supplier priority's Ingredient FOR UPDATE cannot stand in for this fence.

### Task 2: Immutable continuity and complete root locking

**Files:** C migration; continuity SQL suite; directly affected source/readiness tests. **Consumes:** Task1 historical evidence and Root/Terra clearance of the open daily creation-fence gate. **Produces:** separate prospective/official proof and an audited prelock protocol.

- [ ] Write RED cases reconstructing the original decision from Handoff line → demand snapshot line → approval snapshot's validation attempt → immutable validation observation's decision ID. Test same totals with different R/D, D-040 newR, another School changed in the same family, missing/extra contributors, missing historical evidence, overlapping sources, changed-then-reverted adjacent edges, gaps/cycles. Exact cardinalities and null-safe predicates are required; nullable bool_and cannot prove every line. A valid modern released NEED_GENERATION requires exactly one non-NULL decision and a complete VALIDATED attempt/observation. RMVP06 validated_shape_check215–233 and CURRENT_DECISION_MISSING851–869, plus RMVP07 validation_evidence_complete1933–2010 enforce this. NULL observations are BLOCKED diagnostics, not release authority; both a missing row and a blocked NULL deny continuity. This preserves existing release requirements and adds no confirmation step. The public journey must prove the actual untouched-family authority.
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
- [ ] Derive the complete backend root universe: retained PH families and every contributing current/retained CN/source/run/Handoff root, invalidated predecessors, overlaps and zeros. Acquire all source/advisory keys (including existing `atlas:planning-correction:<run>`) in fixed namespace/kind and identity order, all Need run rows, all CN batch UUIDs, stable lines/revisions/decisions/Unit-policy, complete Ingredient/Supplier evidence, all Handoff batches/revisions/predecessors, then all families/revisions/splits. No target-first child begins before that full prefix. After waits rebuild evidence; reject expanded/changed root sets instead of acquiring an earlier root late.
- [ ] Amend initial locking in eligible prepare, standalone Planning release, Preparation, Handoff release/promotion and release triggers. Audit compatibility with old Save, generation/source correction, Handoff Save, PO and PXK. Preserve Supplier→Handoff→family order; no new earlier root after a later lock. Record the exact acquisition graph before implementation. Extend migration105's CN-only `purchase_review_lock_allocations` to retained PH families with NULL CN-source column and every contributing root, not just the target School/batch.
- [ ] Run actual two-session cases in separate proven-owned C databases: retained PH Save holds Supplier/Handoff/family; CN Save holds a contributing root; overlapping Preparation calls use opposite targets. Observe a real Lock wait before committing the other session; prove fresh rejection or correct serial success, no deadlock and zero partial child effects. Preserve exact final source hashes and responses/counts. Coordination elapsed is not a pure RPC benchmark. Commit GREEN proof/lock checkpoint for Terra.

### Task 3: Closed preview and atomic correction command

**Files:** new CLI migration, correction SQL suite. **Consumes:** Task1 history, Task2 reviewed fence/prelock primitives and current canonical prepare/Save. **Produces:** two public RPCs, shared quantity evaluator, exact grants/receipts.

- [ ] Write RED cases: unknown/null/wrong type envelope/payload; mismatched outer/payload version; wrong JWT/missing each capability/GLOBAL; source/run/batch/line mismatch/stale; bad precision/reason/Unit/policy; WHOLESALE/upstream stale; write permitted without Procurement-read. Preview must change no facts/receipts.
- [ ] Extract canonical quantity evaluator without changing ordinary preview errors/lifecycle. Implement new preview and command with owner/ACL above, not a public bypass flag.
- [ ] Implement exact command order using existing prepare/finish receipt helpers:

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

- [ ] Distinct deterministic child IDs/receipt-derived stage keys; never outer-ID reuse. Exact replay occurs before mutable currentness, including after its own successor or a later correction. A child failure JSON alone cannot roll back prior effects: raise inside the subtransaction. Retryable rollback must not retain success/child evidence.
- [ ] Prove actual late Save failure after potential reopen by changing a real canonical prerequisite; compare run/batch/Handoff/R/D/receipts/events before/after. Positive correction creates only selected successor, no new Need run/Allocation/PO/PXK release. Assert exact/conflicting replay and original response after later correction.

```sql
select is((select response from pg_temp.c_results where name='replay-after-later-correction'),
          (select response from pg_temp.c_results where name='saved-correction'),
          'successful exact replay survives later mutable changes');
```

- [ ] Run new matrix plus ordinary Save/release/planning-correction regressions; commit GREEN command checkpoint with source hash for Terra.

### Task 4: Canonical consumers and explicit affected successors

**Files:** C migration/continuity suite, incumbent Allocation/Preparation/PO/PXK/reconciliation tests, only necessary additive models/copy. **Consumes:** Task 2 proof/prelocks. **Produces:** canonical affected-only handling with exact unaffected identities.

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

- [ ] Write RED tests for the exact two RPC map entries and closed requests, six-place quantity/IDs, outer/payload version equality and unchanged ordinary Save. No browser prepare/Save orchestration. Add only the exact bridge methods/types; run boundary gate immediately.

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

- [ ] Implement builders/parsers and correction state within Confirmed Need's existing dirty owner. Preserve ordinary released-editing guard and13 persistent owners. Quantity/reason edits invalidate preview; selected context/date/School epochs reject late responses. Server owns delta and impact.
- [ ] Build one complete command on explicit Save, retain it for UNKNOWN/retry. Lock edits/close/date/context/module/signout while outcome is unknown. Retry identical ID/time/payload. Stale preserves input but requires fresh preview. Read authoritatively once after success; show success only with certainty and return focus after busy/readback clears.

```ts
await act(() => controller.correct());
const first = api.correct.mock.calls[0][0];
await act(() => controller.retryCorrection());
expect(api.correct.mock.calls[1][0]).toEqual(first);
expect(api.save).not.toHaveBeenCalled();
expect(api.releaseSaved).not.toHaveBeenCalled();
```

- [ ] Test missing capability, server reason, late preview/context, read failure after success, UNKNOWN/exact retry/recovery, dirty date/School/module/signout Cancel/discard and completed-readback focus. Align review mocks with selected dates/Schools and append only selected line. Run tracked API/controller/registry tests excluding mirrors; commit.

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

ATLAS-OPERATOR-CONFIRMED-NEED-CORRECTION-C-01. Human approval of340721 recorded with explicit positive PO/Dispatch successor interpretation and true-zero guard. Phase TASK1_ONLY: baseline/public fixture/RED released after this authority commit; no new C business function/migration. Tasks2–8 require a subsequent reviewed daily-fence/dependency release. Allowed reach is the file map and Tasks 1–8; record the actual CLI migration file once created. Same C branch/PR388, reverified main, frozen385/386/387 not dependencies. No merge/manual deployment/hosted writes/staff grants/real commitments/Warehouse/D. One authorized Actor, existing capability/scope/audit/exception owners. Sole Sol6.1 executing-plans, Root/Terra review; no repeated approval phrase or execution-mode question.
