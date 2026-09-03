# Purchase Review Confirm Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task. The user requires one implementation agent and exactly two read-only audit agents; no delegated implementation.

**Goal:** Implement generated paper review → saved Need → saved supplier allocation → Handoff promotion → official PO release.

**Architecture:** Extend the existing Allocation Family source lineage, retain Handoff-only PO authority, and reuse existing Planning completeness, immutable decisions, exact split, receipt and release primitives. New shaped reads and a versioned pre-Handoff Save avoid changing legacy command meanings. Backend commitment preparation keeps internal lifecycle coordination out of React.

**Tech Stack:** React19, TypeScript7, existing Mantine9/ExcelJS4, PostgreSQL17/Supabase2.111.0, pgTAP and Vitest.

**Spec:** `docs/superpowers/specs/2026-09-03-purchase-review-confirm-release-design.md`

## Execution ledger — 2026-09-03

The detailed task checklist below records the original TDD sequence; this ledger records actual delivery evidence. Delivery uses one implementation commit plus a bounded CI-verifier follow-up instead of intermediate slice commits; no working change was placed on `main`.

- [x] Task1: verified/authorized checkout and branch; local B1 boundary regression passes6 assertions. Historical Staging cause is not claimed proven.
- [x] Task2: read-only generated review, canonical confirmed source bridge, strict typed source/contribution lineage and scope-filtered read models implemented.
- [x] Task3: exact explicit confirmed allocation Save, source/version/replay guards, retained stale splits and advisory rebalance implemented.
- [x] Task4: release prerequisites, atomic Handoff promotion and backend commitment preparation implemented; fresh shadow migration and483 targeted database assertions pass.
- [x] Task5: four typed APIs and separate Retool-v1-based XLSX preview implemented; both sheets visually rendered and exact quantity/blank correction tests pass.
- [x] Task6: same-date navigation-only Planning continuation, source-aware supplier editor, coherent synthetic journey, focus/currentness/recovery behavior implemented;310 focused frontend tests and typecheck pass.
- [x] Task7 local evidence: six populated states × five viewport sizes show no page overflow; keyboard focus checked; internal Storybook documentation diagnostic disclosed; both final read-only audits clear; API/decision/rollback evidence updated.
- [x] Task7 publication: committed, pushed and opened the single unmerged [Draft PR251](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/251). The first CI run passed Frontend CI and found a local fixture transport issue during Smoke; the bounded follow-up is covered by a red-first helper regression. Final head/check status is reported on the PR; broad GitHub validation is not replaced by local evidence.

Full evidence and reproducible commands: [implementation record](../../implementation-tasks/TASK-PURCHASE-REVIEW-CONFIRM-RELEASE-01.md).

## Global implementation constraints

- Base `93af319d3a9e133614e2221202c114c0d586018e`; branch `feat/purchase-review-confirm-release-v1`; work in the explicitly authorized verified checkout.
- Generated recommendation/worksheet writes zero operational records or acceptance events.
- No Warehouse, released-PO amendment, wholesale behavior change, hosted/live/Retool writes, new allocation tables, major dependencies or capabilities.
- Existing private schemas, forced RLS, empty search paths, Actor/scope checks, exact quantities, immutable history and idempotency remain mandatory.
- Confirmed Need Save retains exact strings, maximum two-decimal editing, reasons/notes and stale/unknown guards.
- One implementation agent; audits are read-only. Use focused checks locally; GitHub Actions owns broad validation. Deliver one unmerged Draft PR.

## File map

- Schema/functions: `supabase/migrations/20260903072648_purchase_review_confirm_release.sql`.
- New backend behavior: `supabase/tests/purchase_review_confirm_release.sql` and `supabase/tests/purchase_handoff_clock_skew.sql`.
- Existing backend compatibility: `supabase/tests/school_catering_handoff_allocation.sql`, `supabase/tests/school_catering_purchase_orders.sql`, `supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql`, `supabase/tests/d037_confirmed_need_save_release_boundary.sql`, `supabase/tests/atlas_current_platform_security_catalog.sql`.
- Synthetic setup/verification: `supabase/local/purchase_review_confirm_release_fixture.sql`, `scripts/verify-local-school-catering-procurement.mjs`, `scripts/certify-supabase-full-integration.mjs`.
- API/model: `src/modules/atlas/procurement/purchaseReviewApi.ts`, `purchaseReviewApi.test.ts`, `schoolCateringProcurementModel.ts`, and `src/modules/atlas/connection/atlasRpc.ts`, `atlasRpc.test.ts`.
- Worksheet: `src/modules/atlas/procurement/GeneratedPurchaseReview.tsx`, `GeneratedPurchaseReview.test.tsx`, `generatedPurchaseReviewExport.ts`.
- Workbenches: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx`, `SupplierSplitPanel.tsx`, `AllocationFamilyTable.tsx`, their existing tests, `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx`, its tests, `PlanningInputsConfirmedNeedTab.test.tsx`, `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`, its tests, and `src/modules/atlas/AtlasApp.tsx`, its tests/stories.
- Review fixtures: `src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.ts`, `schoolCateringProcurementFixtures.ts`, `src/modules/atlas/planning-inputs/reviewPlanningInputsApi.ts` and `src/styles.css`.
- Contracts: `docs/api/school-catering-procurement.md`, `docs/api/confirmed-need-save-release-v2.md`, `docs/decisions/decision-register.md` and this spec/plan.

## Task 1 — Baseline and B1 reproduction

Consumes: existing Handoff v1 envelope. Produces: controlled timestamp regression, without a claimed historical Staging diagnosis.

- [x] Verify authorized checkout, clean tree, exact main and create branch; run parallel read-only domain/UI audits.
- [x] Read approved contracts and record/self-review design. Start only local reduced Supabase; apply missing existing baseline migrations without reset.
- [ ] Write `purchase_handoff_clock_skew.sql` with the actual Handoff request shape. Compare authenticated requests at server time−1second, +1second, +60seconds and +61seconds; malformed UUID/extra payload still fails. The missing-batch fixture isolates envelope acceptance: accepted envelope returns `NOT_FOUND`, not `VALIDATION_FAILED`.

```sql
select is((atlas_api.release_school_catering_purchase_handoff(
  pg_temp.handoff_request(transaction_timestamp()+interval '1 second')))->>'error_code',
  'NOT_FOUND', 'bounded browser clock skew reaches authoritative source validation');
```

- [ ] Run `pnpm exec supabase test db supabase/tests/purchase_handoff_clock_skew.sql --local`; observe the expected validation failure before migration changes.
- [ ] Implement only the reproduced Handoff timestamp tolerance (+60seconds), preserving request identity and backend timestamps. Rerun that suite; document the limit of B1 evidence.

## Task 2 — Read models and typed source lineage

Consumes: current generation release, `rmvp_06_canonical_evaluation`, saved decisions and source membership. Produces: private `purchase_review_confirmed_projection(date,uuid,uuid,uuid)` and `purchase_review_supplier_advice(date,uuid,numeric)`; public `get_generated_purchase_review` and `get_confirmed_supplier_allocation_workbench`.

- [ ] Add backend tests before implementation: missing public read fails; generated100 with unique supplier proposes100; a tie/no eligibility yields unresolved; read leaves revisions/Handoffs/POs/receipts/events unchanged; confirmed incomplete returns the exact blocker.

```sql
select is((select count(*) from atlas_procurement.school_catering_allocation_family_revisions),
  (select allocation_count from pg_temp.before_preview), 'preview never persists allocation');
select is(review #>> '{rows,0,family_quantity}', '100.000000', 'generated source remains100');
```

- [ ] Run `pnpm exec supabase test db supabase/tests/purchase_review_confirm_release.sql --local` and capture expected missing-feature failures.
- [ ] Add source-kind/default/XOR columns, typed confirmed contribution references, uniqueness and integrity checks to the existing four-table aggregate. Existing rows default to Handoff without rewriting their evidence.
- [ ] Implement private source bridge under the Confirmed Need runtime with exact quantity strings, lifecycle-neutral fingerprint, saved batch version and canonical completeness. Implement shared backend supplier advice, authorization-filtered public reads and precise execute grants/revocations. Keep `school_catering_family_projection` Handoff-only.
- [ ] Run the new targeted suite plus `school_catering_handoff_allocation.sql`; verify historical Handoff reads still pass. Commit this tested slice with its contracts.

## Task 3 — Explicit saved confirmed allocation

Consumes: confirmed projection and existing split invariants. Produces: `save_confirmed_supplier_allocation(request jsonb)` under `CONFIRMED-SUPPLIER-ALLOCATION.v1`.

- [ ] Extend real-command tests: confirmed120, A72/B48 saves one confirmed-source revision and no Handoff/PO; malformed/duplicate/ineligible/imbalanced/incomplete input rejects without writes; exact replay returns same revision; stale expected version/fingerprint rejects.

```sql
select is(saved #>> '{family,source_kind}', 'CONFIRMED_NEED', 'saved allocation is pre-Handoff');
select is((select sum(allocated_quantity) from atlas_procurement.school_catering_allocation_supplier_splits
  where family_revision_id=(saved#>>'{family,family_revision_id}')::uuid),120::numeric,
  'supplier decisions exactly equal saved Need');
```

- [ ] Run new suite and observe failures before adding the command/persistence adapter.
- [ ] Reuse exact split validation and immutable revision inserts with explicit source adapter. Require source batch/version, source fingerprint, Actor/scope, expected family version and supplier evidence locks. Store exact confirmed line-revision/decision evidence; append receipt/domain/audit results.
- [ ] Change confirmed Need120→125 through existing Save. Assert retained72/48 and stale read; advisory75/50 changes nothing until explicit Save. Also assert10060/40→12072/48.
- [ ] Run new suite and existing allocation tests; commit the tested command slice.

## Task 4 — Release readiness, promotion and official PO boundary

Consumes: saved current confirmed allocation. Produces: guarded existing Planning release, atomic Handoff successor promotion, `prepare_school_catering_purchase_orders` (`PURCHASE-COMMITMENT.v1`).

- [ ] Add failing tests for incomplete/stale/ineligible allocation release blockers, direct v1/v2 release bypass, Handoff-only PO gating and exact75/50 promotion. Assert predecessor remains unchanged and draft/released quantities equal75/50.

```sql
select is(promoted.source_kind,'PURCHASE_HANDOFF','only real Handoff promotes authority');
select is(promoted.predecessor_revision_id,confirmed.family_revision_id,'promotion appends successor');
select is((select count(*) from atlas_procurement.purchase_orders where document_number is not null),
  0::bigint,'draft preparation does not issue official numbers');
```

- [ ] Run new cross-stage suite; observe failures for the new readiness/promotion expectations.
- [ ] Add lifecycle-neutral readiness helper, early release/read action checks and transition guard for NEED_GENERATION only. Expected guard failures return safe Vietnamese validation errors, not unknown outcomes. Verify approval/validation lifecycle changes alone do not stale source evidence.
- [ ] Add private Procurement-owned promotion helper: lock/recheck exact source membership, saved splits and supplier eligibility, compare real Handoff contribution IDs/quantities, append committed successors and audit events under the Handoff receipt. Old Handoff command integrates atomically and keeps replay compatibility.
- [ ] Add explicit Handoff source-kind gating to PO readiness, staleness, draft creation, release and defensive line guards. Leave released export and numbering unchanged.
- [ ] Add atomic preparation API coordinating existing authorized commands using backend timestamps and durable outer receipt. Abort/rollback on any child failure; return authoritative outcomes and permit safe continuation from already completed stages.
- [ ] Update release regression prerequisites to create valid confirmed allocations; do not weaken existing assertions or disable guards. Update exact API/trigger security catalog and certification registration.
- [ ] Run new suites plus affected Confirmed Need, Handoff/allocation, correction and PO suites; commit when green.

## Task 5 — Exact typed API and generated worksheet

Consumes: new shaped reads/commands. Produces: connected API methods/types and `GeneratedPurchaseReview` with separate worksheet export.

- [ ] Write API tests for exact version/envelope/quantity strings and zero generated-read mutations. Write worksheet tests for warning banner, supplier/School grouping, unresolved rows, exact quantities and correction column.

```tsx
await user.click(screen.getByRole("button", { name: "In bản dự kiến" }));
expect(await screen.findByText("DỰ KIẾN — CHƯA XÁC NHẬN")).toBeVisible();
expect(saveAllocation).not.toHaveBeenCalled();
expect(releasePurchaseHandoff).not.toHaveBeenCalled();
```

- [ ] Run targeted Vitest files and observe missing-feature failures.
- [x] Extend RPC registry/allowlist and typed API without changing old contracts. Build separate XLSX from generated exact strings, based on the inspected Retool v1 exporter documented in the spec. Reuse the existing ExcelJS dependency/download primitive; preserve the released PO data guard. No supplier rules or Number-based quantity calculations in React. Export tests initially failed for the missing XLSX function/button, then passed (12 tests including unchanged official export tests).
- [ ] Run new tests and unchanged `purchaseOrderExports.test.ts`; render/visually verify the worksheet. Commit tested slice.

## Task 6 — Five-step operator workflow and currentness

Consumes: API and worksheet. Produces: navigation-only Planning continuation, same-date Procurement allocation and backend commitment preparation.

- [ ] Write tests that clean saved Planning continuation navigates with the exact working date and invokes neither release nor Handoff. Confirm existing Save payload/reasons/two-decimal behavior remains unchanged.
- [ ] Write Procurement tests for incomplete saved Need blocker, clear confirmed/allocated/remaining quantities, participants-only editing, stale retained splits/advisory proposal, source-aware trace, authoritative Save/preparation reload and unknown-outcome lock.

```tsx
expect(screen.getByText("Nhu cầu đã xác nhận")).toBeVisible();
expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
expect(onContinueToProcurement).toHaveBeenCalledWith("2026-09-03");
```

- [ ] Run affected tests red, then integrate generated preview into Planning's secondary utilities. Pass selected date through `PlanningInputsWorkbench`/`AtlasApp`; replace the old release-first primary rail emphasis.
- [ ] Switch normal Procurement to the confirmed workbench/new Save, retain legacy Handoff rows and order mode. Preparation invokes the backend command and uses existing durable outcome/readback/retry safeguards. Preserve focus, panel close return, responsive layout and one primary action.
- [ ] Adapt synthetic review API/fixtures to model source kinds and cross-stage state without implying production persistence. Update stories to the new navigation and intermediate states.
- [ ] Run focused Planning/Procurement/Atlas Vitest and typecheck; commit tested slice.

## Task 7 — QA, documentation and Draft PR

Consumes: tested integrated flow. Produces: exact-head reviewable branch and one unmerged Draft PR.

- [ ] Run real-command acceptance generated100→confirmed120→72/48→confirmed125→stale→75/50→Handoff successor→official drafts→release. Verify unrelated School/date, exact replay, immutable released snapshots and no preview writes.
- [ ] Browser inspect synthetic/local populated six states at1366×768,1920×1080,900×900,650×900,360×800. Measure page overflow, keyboard/focus and product-console errors; record actual results only.
- [ ] Update API contracts/decision-register amendment and this plan's checked steps with evidence, migration rollback boundary and B1 limitation.
- [ ] Run new/affected pgTAP, existing Confirmed Need/Handoff/allocation/PO regression suites, affected Vitest, `pnpm typecheck`, Prettier on touched supported files, and `git diff --check`.
- [ ] Self-review exact diff/security and acceptance coverage. Commit, push only meaningful changes, open Draft PR titled `PURCHASE-REVIEW-CONFIRM-RELEASE-01: align purchase planning with operator workflow`, leave unmerged, inspect CI and report actual branch/base/head, architecture/API/migrations, tests/QA and exact blockers.

## Plan self-review

- Spec coverage: tasks1–4 cover backend lineage, security, B1 and full cross-stage acceptance; tasks5–6 cover immutable print and PR249/250 operator behavior; task7 covers hosted boundary, evidence and delivery.
- Signature consistency: public read/Save/preparation names and version strings above are the sole new contracts; legacy Handoff/PO APIs remain distinct.
- No deferred design placeholders; test expectations above use literal independently checked quantities. Any implementation adjustment must update the spec/plan and remain inside this approved capability.
