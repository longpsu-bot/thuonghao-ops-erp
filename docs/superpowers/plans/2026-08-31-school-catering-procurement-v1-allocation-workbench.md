# School-Catering Procurement V1 — Connected Allocation Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the accepted Planning workbench to the SC-PROC-01 backend and deliver the two-stage Procurement shell with a production-quality `Phân bổ nhà cung ứng` workbench, including manual family splits, bulk default confirmation, and stale/rebalance handling.

**Architecture:** The browser consumes only the shaped SC-PROC-01 read/command APIs. Planning keeps one visible `Chuyển sang lên đơn` action but orchestrates two durable backend commands with recoverable intermediate state. Procurement presents Allocation Families as the operator grain; React owns temporary split editing and filtering but never recomputes authoritative demand, recommendation, eligibility, balance, or lifecycle rules.

**Tech Stack:** React 19, TypeScript 7, Mantine 9, Supabase JS through existing `atlasRpc`, Vitest 4, Testing Library, Vite 8, existing Atlas CSS/theme/review-mode patterns.

**Spec:** `docs/superpowers/specs/2026-08-30-school-catering-procurement-v1-design.md`

## Recommended Codex settings

- Model: **GPT-5.6 Sol**
- Reasoning: **Medium**
- Agents: **1**
- Parallel agents: **Off**
- Subagents: **Off**
- If running through Superpowers, use `executing-plans` rather than subagent dispatch.

## Global Constraints

- Start only after SC-PROC-01 is merged and Staging contract/API surface is known.
- Fetch fresh `origin/main`; create `feat/sc-proc-02-allocation-workbench` from current main.
- Read only this plan, the canonical spec, SC-PROC-01 API contract, and exact frontend reference files named below.
- Do not edit Supabase schema/functions in this slice unless a genuine SC-PROC-01 contract defect is found; report first.
- Do not implement PO draft/release behavior yet.
- Do not mutate Retool, Live OPS, or production Supabase.
- Preserve the accepted Planning UI/workbench from PR #237 except for the bounded handoff transition behavior.
- Preserve multi-school display filtering semantics; browser filters must never shrink authoritative backend write scope unless the API contract explicitly accepts them.
- Recommendation is display-only until operator confirmation.
- React does not aggregate Purchase Handoff lines or recalculate supplier eligibility/rebalance ratios.
- Keep the current Atlas sidebar, typography, palette, spacing language and dense workbench style.
- No dashboard/KPI-card redesign.
- TDD with focused Vitest files during implementation; comprehensive frontend checks via GitHub Actions.
- Hosted browser acceptance at 1366×768 and 1920×1080 is mandatory before merge.

---

### Task 1: Create the connected school-catering Procurement API/model boundary

**Files:**
- Create: `src/modules/atlas/procurement/schoolCateringProcurementModel.ts`
- Create: `src/modules/atlas/procurement/schoolCateringProcurementApi.ts`
- Create: `src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts`
- Reference only: `src/modules/atlas/connection/atlasRpc.ts`
- Reference only: `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts`
- Reference only: `docs/api/sc-proc-01-school-catering-allocation.md`

**Interfaces:**
- `SchoolCateringProcurementApi.getWorkbench(...)`
- `SchoolCateringProcurementApi.saveAllocation(request)`
- `SchoolCateringProcurementApi.confirmRecommendations(request)`
- `SchoolCateringProcurementApi.releasePurchaseHandoff(request)` is **not** placed here; Planning/Confirmed Need owns that call.
- Model types exactly mirror the shaped SC-PROC-01 read, not private tables.

- [ ] **Step 1: Write failing adapter tests**

Test that the adapter calls exact RPC names and preserves backend errors/readback:

```ts
it("calls the shaped procurement workbench RPC", async () => {
  const transport = createRecordingTransport({
    rpc: "get_school_catering_procurement_workbench",
    response: workbenchFixture,
  });
  const api = createSchoolCateringProcurementApi(transport);

  await api.getWorkbench(subject, correlationId, {
    dateStart: "2026-08-31",
    dateEnd: "2026-09-06",
    deliveryLocationIds: [],
    states: [],
  });

  expect(transport.calls[0]?.name).toBe(
    "get_school_catering_procurement_workbench",
  );
});
```

Also assert command wrappers use:

```text
save_school_catering_supplier_allocation
confirm_school_catering_supplier_recommendations
```

and do not alter server payload quantities/fingerprints.

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts
```

Expected: FAIL because files/functions do not exist.

- [ ] **Step 3: Define focused model types**

At minimum:

```ts
export type AllocationFamilyState =
  | "UNASSIGNED"
  | "IMBALANCED"
  | "BALANCED"
  | "STALE_REBALANCE_AVAILABLE"
  | "STALE_REQUIRES_REALLOCATION";

export type SupplierSplitDraft = {
  supplierId: string;
  quantity: string;
};

export type AllocationFamilyRow = {
  key: {
    serviceDate: string;
    deliveryLocationId: string;
    ingredientId: string;
    unitId: string;
  };
  familyId: string | null;
  familyVersion: number | null;
  sourceFingerprint: string;
  school: { id: string; name: string };
  deliveryLocation: { id: string; name: string };
  ingredient: { id: string; name: string };
  unit: { id: string; code: string; name: string };
  demandQuantity: string;
  allocatedQuantity: string;
  deltaQuantity: string;
  state: AllocationFamilyState;
  acceptedSplits: Array<{
    supplierId: string;
    supplierName: string;
    quantity: string;
    ratio: string;
  }>;
  recommendation: null | {
    supplierId: string;
    supplierName: string;
    quantity: string;
  };
  rebalanceProposal: null | Array<{
    supplierId: string;
    supplierName: string;
    quantity: string;
    ratio: string;
  }>;
  eligibleSuppliers: Array<{
    supplierId: string;
    supplierName: string;
    priority: number;
  }>;
  blockers: Array<{ code: string; message: string }>;
  warnings: Array<{ code: string; message: string }>;
  allowedActions: {
    saveAllocation: boolean;
    confirmDefault: boolean;
  };
};
```

Adapt exact field casing at the RPC boundary once SC-PROC-01 is merged; component code consumes camelCase model types only.

- [ ] **Step 4: Implement API adapter**

Follow the existing `atlasRpc` envelope conventions. Do not expose Supabase client use directly to components.

- [ ] **Step 5: Run GREEN**

```bash
pnpm exec vitest run src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts
```

- [ ] **Step 6: Commit**

```bash
git add src/modules/atlas/procurement/schoolCateringProcurementModel.ts src/modules/atlas/procurement/schoolCateringProcurementApi.ts src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts
git commit -m "feat: add connected procurement allocation API"
```

---

### Task 2: Add review-mode fixtures for allocation states without creating a second domain model

**Files:**
- Create: `src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.ts`
- Create: `src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.test.ts`
- Modify: `src/modules/atlas/review/reviewMode.ts`
- Reference only: `src/modules/atlas/planning-inputs/confirmed-needs/reviewConfirmedNeedApi.ts`

**Interfaces:**
- Produces a `SchoolCateringProcurementApi` implementation for hosted/review mode.
- Fixture scenarios needed in this slice:
  - ready/balanced mix
  - unassigned
  - imbalanced
  - stale-rebalance-available
  - stale-requires-reallocation
  - permission denied
  - transport/server error.

- [ ] **Step 1: Write failing review API tests**

Assert that review commands mutate only the in-memory review fixture and reproduce backend-shaped behavior:

```ts
it("keeps a recommendation read-only until confirm", async () => {
  const api = createReviewSchoolCateringProcurementApi("procurement_unassigned");
  const before = await api.getWorkbench(...args);
  expect(before.workbench.families[0]?.familyId).toBeNull();

  await api.confirmRecommendations(confirmRequest);
  const after = await api.getWorkbench(...args);
  expect(after.workbench.families[0]?.state).toBe("BALANCED");
});
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.test.ts
```

- [ ] **Step 3: Add only the scenarios needed for Procurement QA**

Extend `AtlasReviewScenario` with exact names:

```text
procurement_ready
procurement_unassigned
procurement_imbalanced
procurement_rebalance
procurement_reallocation_required
procurement_permission_denied
procurement_server_error
```

Do not create dozens of redundant scenarios.

- [ ] **Step 4: Implement review API through the same model interface**

No component should branch on review vs connected behavior except API construction.

- [ ] **Step 5: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.test.ts
git add src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.ts src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.test.ts src/modules/atlas/review/reviewMode.ts
git commit -m "test: add procurement allocation review scenarios"
```

---

### Task 3: Extend Confirmed Need with the recoverable two-command handoff transition

**Files:**
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel.ts`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/reviewConfirmedNeedApi.ts`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx`
- Modify: adjacent Confirmed Need tests covering release/date safety
- Reference only: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`

**Interfaces:**
- Existing CN release remains command 1.
- New Planning API method: `releaseSchoolCateringPurchaseHandoff(request)` calls `release_school_catering_purchase_handoff`.
- UI-level transition state:

```ts
type PurchaseTransitionState =
  | { kind: "idle" }
  | { kind: "releasing-confirmed-need" }
  | { kind: "releasing-handoff"; confirmedNeedVersion: number }
  | { kind: "handoff-retry-required"; confirmedNeedVersion: number; message: string }
  | { kind: "complete" };
```

- [ ] **Step 1: Write failing transition tests**

Cover exactly:

```text
DRAFT/VALIDATED/etc. → existing backend action gating unchanged
APPROVED/releasable → click Chuyển sang lên đơn calls Confirmed Need release first
CN release failure → handoff command not called
CN release success + handoff success → transition complete
CN release success + handoff failure → retry state shown, CN release not called again on retry
retry handoff success → complete
service-date safety from PR #235 remains green
```

Use mock methods/call-order assertions:

```ts
expect(api.releaseConfirmedNeeds).toHaveBeenCalledTimes(1);
expect(api.releaseSchoolCateringPurchaseHandoff).toHaveBeenCalledTimes(1);
expect(invocationOrder).toEqual(["confirmed-need", "purchase-handoff"]);
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx
```

If the exact existing test filename differs on merged main, run the adjacent `confirmed-needs/*.test.tsx` files only.

- [ ] **Step 3: Add the API method and typed handoff result**

Do not fold both RPCs into one frontend-created fake transaction. Each call keeps its own command ID/idempotency key/expected version.

- [ ] **Step 4: Implement recoverable UI orchestration**

On command-1 success, use authoritative readback/resulting CN version for command 2. If command 2 fails, show a compact warning such as:

```text
Nhu cầu đã được chốt để chuyển mua, nhưng chưa tạo được bàn giao mua hàng.
```

Primary retry action:

```text
Thử lại chuyển sang lên đơn
```

Retry calls only the handoff command against refreshed authoritative CN state.

- [ ] **Step 5: Run focused Confirmed Need regression GREEN**

```bash
pnpm exec vitest run src/modules/atlas/planning-inputs/confirmed-needs
```

Expected: all Confirmed Need tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/modules/atlas/planning-inputs/confirmed-needs
git commit -m "feat: connect Planning to purchase handoff"
```

---

### Task 4: Enable the Procurement page in Atlas navigation and wire connected/review APIs

**Files:**
- Modify: `src/modules/atlas/AtlasApp.tsx`
- Modify: `src/modules/atlas/AtlasApp.test.tsx`
- Create: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx`
- Create: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx`

**Interfaces:**
- Extend `MasterDataPageId` with `"purchase-planning"`.
- Enable sidebar label `Kế hoạch mua hàng`.
- `SchoolCateringProcurementWorkbench` props:

```ts
type Props = {
  authState: AtlasAuthState;
  api?: SchoolCateringProcurementApi;
  mode: "connected" | "review";
  initialDateStart?: string;
  initialDateEnd?: string;
};
```

- First slice visible stages:
  - `allocation` active and functional
  - `purchase-orders` visible as disabled/`Sắp triển khai` until SC-PROC-03, or omit the second selector until SC-PROC-03 if that is more consistent with current Atlas disclosure; do not implement fake PO behavior.

- [ ] **Step 1: Write failing navigation/page tests**

Assert:

```ts
expect(screen.getByRole("button", { name: /Kế hoạch mua hàng/i })).toBeEnabled();
userEvent.click(...);
expect(screen.getByRole("heading", { name: /Phân bổ nhà cung ứng/i })).toBeVisible();
```

Review mode must inject `createReviewSchoolCateringProcurementApi`; connected mode injects `createSchoolCateringProcurementApi` using existing transport construction.

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/AtlasApp.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
```

- [ ] **Step 3: Extend navigation/page type and API construction**

Add one active sidebar item with the existing `ShoppingCart` icon and remove `description="Chưa triển khai"` for this page.

Do not enable `Kho` or unrelated pages.

- [ ] **Step 4: Render a minimal connected Procurement workbench shell**

At this step the workbench only needs loading/error/empty/table container states; detailed table/editing arrives in later tasks.

- [ ] **Step 5: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/AtlasApp.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
git add src/modules/atlas/AtlasApp.tsx src/modules/atlas/AtlasApp.test.tsx src/modules/atlas/procurement
git commit -m "feat: enable connected Procurement page"
```

---

### Task 5: Build the dense Allocation Family table and filters

**Files:**
- Create: `src/modules/atlas/procurement/AllocationFamilyTable.tsx`
- Create: `src/modules/atlas/procurement/AllocationFamilyTable.test.tsx`
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx`
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx`
- Modify: `src/styles.css`

**Interfaces:**
- Table receives already-authoritative `AllocationFamilyRow[]`.
- Filters are presentation selection over returned rows; changing backend date range/school scope triggers a shaped read, but the table never recomputes family totals.
- Selected family key is exact tuple + source fingerprint.

- [ ] **Step 1: Write failing table/filter tests**

Prove columns and status filtering:

```text
Ngày
Trường / nơi giao
Nguyên liệu
Đơn vị
Nhu cầu
Đã phân bổ
Còn lại / vượt
NCC
Trạng thái
```

Fast filters:

```text
Tất cả
Chưa phân bổ
Chưa đủ
Đã đủ
Cần phân bổ lại
```

`STALE_REBALANCE_AVAILABLE` and `STALE_REQUIRES_REALLOCATION` both appear under `Cần phân bổ lại` but retain distinct row copy.

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/AllocationFamilyTable.test.tsx
```

- [ ] **Step 3: Implement table-first UI**

Use the same dense visual grammar as the polished Planning workbench:

```text
no hero card
no KPI tiles
one compact context/filter rail
one dominant table surface
local horizontal overflow only if necessary
sticky/legible header where existing table pattern permits
```

Do not introduce new color tokens.

- [ ] **Step 4: Run GREEN**

```bash
pnpm exec vitest run src/modules/atlas/procurement/AllocationFamilyTable.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
```

- [ ] **Step 5: Commit**

```bash
git add src/modules/atlas/procurement/AllocationFamilyTable.tsx src/modules/atlas/procurement/AllocationFamilyTable.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx src/styles.css
git commit -m "feat: add Procurement allocation family table"
```

---

### Task 6: Add the attached supplier split editor and manual save

**Files:**
- Create: `src/modules/atlas/procurement/SupplierSplitEditor.tsx`
- Create: `src/modules/atlas/procurement/SupplierSplitEditor.test.tsx`
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx`
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx`
- Modify: `src/styles.css`

**Interfaces:**
- Editor draft rows use `SupplierSplitDraft[]`.
- Initial draft priority:
  1. accepted splits when current;
  2. safe rebalance proposal when state `STALE_REBALANCE_AVAILABLE`;
  3. default recommendation for unallocated family;
  4. empty row when backend says reallocation required/no recommendation.
- Save submits the complete family split list and current backend fingerprint/version.

- [ ] **Step 1: Write failing editor tests**

Prove:

```text
accepted 60/40 renders 2 rows
unallocated default renders priority-1 supplier at full demand but does not call save
rebalance 72/48 is clearly labelled Đề xuất cân bằng lại
ineligible prior supplier is not silently copied into editable proposal
operator can add/remove eligible supplier rows
Save sends complete intended rows, no split_ratio field
backend error/readback refreshes family state
```

Do not treat client-side arithmetic as authoritative. Client may display a convenience sum/delta, but backend result decides success.

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/SupplierSplitEditor.test.tsx
```

- [ ] **Step 3: Implement the attached editor**

Use compact row controls inside the selected-family surface. Primary action text:

```text
Lưu phân bổ
```

For safe rebalance proposal, show previous/new demand and ratios succinctly; do not require the operator to understand internal revision IDs.

- [ ] **Step 4: Connect command and authoritative refresh**

After success, refresh the shaped workbench and reselect the same family tuple. If source changed, discard stale draft and show backend safe message.

- [ ] **Step 5: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/procurement/SupplierSplitEditor.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
git add src/modules/atlas/procurement/SupplierSplitEditor.tsx src/modules/atlas/procurement/SupplierSplitEditor.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx src/styles.css
git commit -m "feat: add Procurement supplier split editor"
```

---

### Task 7: Add bulk confirmation of untouched default recommendations

**Files:**
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx`
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx`

**Interfaces:**
- Bulk action label: `Xác nhận phân bổ đề xuất`.
- Candidate list comes only from currently loaded rows where backend `allowedActions.confirmDefault === true` and recommendation exists.
- Send each candidate's tuple, source fingerprint and recommended supplier ID exactly as read.

- [ ] **Step 1: Write failing bulk-result tests**

Prove:

```text
button count reflects explicit eligible candidates
manual/current allocations are excluded
click sends explicit candidate list, not filter-only command
partial result 218 confirmed / 2 skipped shows concise summary and exceptions
refresh occurs after command
no candidate → action disabled/hidden with backend-safe explanation
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
```

- [ ] **Step 3: Implement bulk confirmation UI**

Do not retry skipped candidates automatically. Surface skipped families in the table/filter state so operator can resolve them.

- [ ] **Step 4: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
git add src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
git commit -m "feat: confirm default Procurement allocations in bulk"
```

---

### Task 8: Connect Planning completion to Procurement navigation without hiding failure states

**Files:**
- Modify: `src/modules/atlas/AtlasApp.tsx`
- Modify: `src/modules/atlas/AtlasApp.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx` only if a navigation callback must pass through this owner
- Modify: relevant Planning tests

**Interfaces:**
- On completed Purchase Handoff, navigate Atlas shell to `purchase-planning`.
- Initial Procurement range should use the Planning service week/date context already owned in memory, if available; otherwise workbench defaults to current backend-supported week range without inventing a new global state store.

- [ ] **Step 1: Write failing integration test**

Drive:

```text
Planning → Confirmed Need releasable → Chuyển sang lên đơn
→ CN release succeeds
→ handoff release succeeds
→ Atlas active page = purchase-planning
→ Procurement workbench loads the matching period
```

Also prove handoff retry state does **not** navigate early.

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/AtlasApp.test.tsx src/modules/atlas/planning-inputs/confirmed-needs
```

- [ ] **Step 3: Implement the narrow navigation callback**

Prefer an explicit React callback from Atlas shell/page owner rather than DOM events, URL hacks or a new global state library.

- [ ] **Step 4: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/AtlasApp.test.tsx src/modules/atlas/planning-inputs/confirmed-needs src/modules/atlas/procurement
git add src/modules/atlas/AtlasApp.tsx src/modules/atlas/AtlasApp.test.tsx src/modules/atlas/planning-inputs src/modules/atlas/procurement
git commit -m "feat: continue Planning into Procurement"
```

Only stage changed Planning files.

---

### Task 9: Certify responsive operator UX and open a Draft PR

**Files:**
- Modify: `src/styles.css` only for defects found by focused browser inspection
- Modify: Procurement tests only for actual regressions found

**Interfaces:**
- No new business behavior.
- Hosted acceptance gate for `Phân bổ nhà cung ứng` and Planning→Procurement transition.

- [ ] **Step 1: Run one bounded local frontend certification**

```bash
pnpm exec vitest run src/modules/atlas/procurement src/modules/atlas/planning-inputs/confirmed-needs src/modules/atlas/AtlasApp.test.tsx
pnpm typecheck
pnpm build:review
git diff --check
```

Expected: PASS/exit 0. Do not repeatedly run the full 650+ test suite locally.

- [ ] **Step 2: Push and create Draft PR**

Recommended title:

```text
SC-PROC-02: Connect school-catering supplier allocation workbench
```

PR body scope statement:

```text
Connected Allocation Family UI only.
Uses SC-PROC-01 backend authority.
No PO draft/release behavior.
No Supabase schema change unless an approved SC-PROC-01 defect fix is separately documented.
No Retool/Live OPS mutation.
```

- [ ] **Step 3: Let GitHub Actions run comprehensive checks**

Required:

```text
Format/typecheck/test/build → success
Qodana → success or changed-file findings resolved
Cloudflare Pages preview → success
Supabase workflow → unchanged backend should remain green under existing conditions
```

- [ ] **Step 4: Inspect exact-head Cloudflare preview**

At **1366×768** and **1920×1080**, inspect:

```text
Planning one-click transition
recoverable handoff failure scenario in review mode
Procurement navigation/sidebar
Allocation table density/alignment
attached split editor
bulk default action
stale/rebalance state
horizontal overflow
sticky behavior
console errors/warnings
```

Acceptance requirement: no page-level horizontal overflow, no new console errors/warnings, primary actions remain visible, and table/editing density is at least as direct as the accepted Planning workbench.

- [ ] **Step 5: Stop at hosted review gate**

Do not mark ready or merge without user approval. SC-PROC-03 starts only after this slice is accepted/merged.
