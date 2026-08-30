# School-Catering Procurement V1 — PO Draft, Release, Numbering and Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete School-Catering Procurement V1 from balanced Allocation Families through supplier/date PO drafts, independent PO release with automated official numbering, and supplier-facing print/PDF export while preserving PA-05E wholesale behavior.

**Architecture:** Extend the existing shared Purchase Order aggregate narrowly instead of creating a second school-catering PO subsystem. `Tạo đơn mua` materializes DRAFT revisions from current balanced family/supplier splits for a service-date range; source changes make drafts stale by derivation. `Phát hành cho NCC` validates one current draft, generates `PO-YYYYMMDD-NNNN` server-side, and records an immutable `RELEASED_TO_SUPPLIER` commitment. Browser export renders from the released shaped read model and uses print-to-PDF without introducing a new PDF dependency.

**Tech Stack:** PostgreSQL/Supabase migrations and pgTAP, PL/pgSQL Atlas command/runtime conventions, React 19, TypeScript 7, Mantine 9, Vitest/Testing Library, CSS print media, existing `atlasRpc`, Vite/Cloudflare Pages.

**Spec:** `docs/superpowers/specs/2026-08-30-school-catering-procurement-v1-design.md`

## Recommended Codex settings

- Model: **GPT-5.6 Sol**
- Reasoning: **Medium**
- Agents: **1**
- Parallel agents: **Off**
- Subagents: **Off**
- If running through Superpowers, use `executing-plans` rather than subagent dispatch.

## Global Constraints

- Start only after SC-PROC-02 is accepted/merged.
- Fetch fresh `origin/main`; create `feat/sc-proc-03-po-release` from current main.
- Read only this plan, canonical spec, SC-PROC-01 API contract, PA-05E contract/migration/test, and exact frontend files named below before editing.
- Do not mutate Live OPS, Retool or production Supabase.
- Existing PA-05E supplier-direct wholesale allocation and PO release must remain behaviorally and structurally compatible.
- No released-PO cancellation/revision/replacement in V1.
- No supplier acknowledgement/rejection/partial confirmation in V1.
- No pricing, tax, currency, invoice, payment, Warehouse, Dispatch or Finance behavior.
- No external supplier email/message sending.
- No generic numbering engine. PO number allocation is Procurement-owned only.
- No new frontend PDF dependency. Use print-ready HTML/CSS and browser PDF printing unless an already-installed canonical export utility exists on the then-current main.
- School display filters do not create partial supplier/date POs; draft materialization scope is service-date range.
- React cannot edit PO supplier/quantity independently of Allocation Families.
- TDD for every backend and UI behavior; focused local checks, comprehensive CI in GitHub Actions.
- Hosted browser acceptance at 1366×768 and 1920×1080 before merge.

---

### Task 1: Extend the shared Purchase Order aggregate without breaking PA-05E

**Files:**
- Create via `pnpm exec supabase migration new sc_proc_03_school_catering_purchase_orders`; use the generated `supabase/migrations/<timestamp>_sc_proc_03_school_catering_purchase_orders.sql`
- Create: `supabase/tests/sc_proc_03_school_catering_purchase_orders.sql`
- Reference only: `supabase/migrations/20260716023909_pa_05e_procurement_command_family.sql`
- Reference only: `supabase/tests/pa_05e_procurement_command_family.sql`
- Reference only: SC-PROC-01 migration and test on merged main

**Interfaces:**
- Extends shared tables exactly as canonical spec Section 8.
- Adds Procurement-owned PO numbering counter relation/private helper.
- Produces no new public API in this task.

- [ ] **Step 1: Write failing schema/backward-compatibility assertions**

Require:

```text
purchase_orders.order_context default SUPPLIER_DIRECT_WHOLESALE
purchase_orders.service_date nullable for wholesale, required by school-catering invariant
unique school-catering supplier + service_date root
purchase_order_revisions.delivery_location_id nullable
purchase_order_revisions.delivery_location_snapshot nullable
purchase_order_lines.fulfilment_allocation_line_id nullable
purchase_order_lines.purchase_allocation_family_id nullable FK
exact XOR on stable PO line source
purchase_order_line_revisions.fulfilment_allocation_line_revision_id nullable
purchase_order_line_revisions.purchase_allocation_supplier_split_id nullable FK
exact XOR on line-revision source
```

Add tests that the existing PA-05E insert/release path still populates wholesale context and single destination without passing new fields.

- [ ] **Step 2: Run RED**

```bash
pnpm exec supabase start --exclude edge-runtime,imgproxy,logflare,mailpit,postgres-meta,realtime,storage-api,studio,supavisor,vector
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
```

Expected: FAIL because new PO context/lineage columns do not exist.

- [ ] **Step 3: Generate migration**

```bash
pnpm exec supabase migration new sc_proc_03_school_catering_purchase_orders
```

Use the generated timestamp from current main.

- [ ] **Step 4: Implement the narrow shared PO extension**

Semantically enforce:

```sql
order_context in ('SUPPLIER_DIRECT_WHOLESALE', 'SCHOOL_CATERING')
```

and school-catering root rules:

```text
SCHOOL_CATERING → purchase_orders.service_date IS NOT NULL
one SCHOOL_CATERING root per supplier_id + service_date
```

Use partial unique indexes/check constraints so wholesale rows remain valid.

XOR stable source:

```text
(fulfilment_allocation_line_id IS NOT NULL) XOR
(purchase_allocation_family_id IS NOT NULL)
```

XOR revision source:

```text
(fulfilment_allocation_line_revision_id IS NOT NULL) XOR
(purchase_allocation_supplier_split_id IS NOT NULL)
```

- [ ] **Step 5: Add Procurement-owned number counter**

Create a private relation such as:

```text
atlas_procurement.purchase_order_number_counters
- service_date date primary key
- last_value bigint not null check last_value >= 0
- updated_at timestamptz
```

Create a **private** helper owned by Procurement runtime that row-locks/upserts the date counter and returns:

```text
PO-YYYYMMDD-NNNN
```

with four-digit minimum left padding. Counter starts at 0001 per service date. Do not expose the counter/helper to `authenticated`.

- [ ] **Step 6: Run shared schema + wholesale regression GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
pnpm exec supabase test db supabase/tests/pa_05e_procurement_command_family.sql --local
```

Expected: both PASS.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/*_sc_proc_03_school_catering_purchase_orders.sql supabase/tests/sc_proc_03_school_catering_purchase_orders.sql
git commit -m "feat: extend purchase orders for school catering"
```

---

### Task 2: Add service-date-range PO draft materialization

**Files:**
- Modify: SC-PROC-03 migration
- Modify: `supabase/tests/sc_proc_03_school_catering_purchase_orders.sql`
- Create: `docs/api/sc-proc-03-school-catering-purchase-orders.md`
- Reference only: SC-PROC-01 allocation API contract

**Interfaces:**
- Produces: `atlas_api.create_school_catering_purchase_order_drafts(request jsonb) returns jsonb`
- Capability: `school_catering_purchase_order.create_drafts`
- Payload: `{ "date_start": "YYYY-MM-DD", "date_end": "YYYY-MM-DD" }`
- Range bound: maximum 31 calendar days for V1.
- Business result is per service date; blocked dates may be skipped while ready dates materialize.

- [ ] **Step 1: Write failing command tests**

Create current accepted family revisions/splits across two service dates:

```text
02/09 ready → Supplier A + B
03/09 one UNASSIGNED/STALE family
```

Assert command result:

```json
{
  "date_results": [
    {"service_date":"2026-09-02","status":"DRAFTS_CREATED","po_count":2},
    {"service_date":"2026-09-03","status":"SKIPPED","error_code":"ALLOCATION_IMBALANCED"}
  ]
}
```

and only 02/09 drafts exist.

Also prove:

```text
range >31 days rejected
zero ready suppliers → no empty PO
one PO root per supplier/date
one PO line per accepted Allocation Family for that supplier/date
multi-school destinations preserved line-by-line
ordered qty = accepted supplier split qty
no official document_number on draft
repeat with unchanged allocation is idempotent/no duplicate current draft
changed current allocation produces successor DRAFT revision only for affected supplier/date root
unrelated draft root/revision unchanged
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
```

- [ ] **Step 3: Implement draft command**

Server flow per date:

```text
validate/authorize/range
→ derive all candidate families in authorized school-catering scope for date
→ require every family has current accepted balanced non-stale allocation
→ collect current supplier splits
→ group supplier + date
→ lock existing school-catering PO roots in deterministic supplier order
→ create missing roots / successor DRAFT revisions only when source set changed
→ create one stable/current line per family/supplier split
→ preserve line-level destination/date/ingredient/unit
→ structured per-date result
```

Do not accept school IDs or supplier IDs as a filter in this command. A date is either fully draftable for the authorized scope or skipped.

- [ ] **Step 4: Document exact command/read/release contract file**

Start `docs/api/sc-proc-03-school-catering-purchase-orders.md` with this command and reserve the same file for Tasks 3–4. Include exact payload/result/status semantics and range limit.

- [ ] **Step 5: Run GREEN and commit**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
git add supabase/migrations/*_sc_proc_03_school_catering_purchase_orders.sql supabase/tests/sc_proc_03_school_catering_purchase_orders.sql docs/api/sc-proc-03-school-catering-purchase-orders.md
git commit -m "feat: create school catering PO drafts"
```

---

### Task 3: Add the shaped school-catering PO read model and derived staleness

**Files:**
- Modify: SC-PROC-03 migration
- Modify: `supabase/tests/sc_proc_03_school_catering_purchase_orders.sql`
- Modify: `docs/api/sc-proc-03-school-catering-purchase-orders.md`

**Interfaces:**
- Produces: `atlas_api.get_school_catering_purchase_orders(request jsonb) returns jsonb`
- Read filters: date range, optional supplier IDs/status; read-only school display filter is allowed if it filters rendered lines but **must not redefine draft command scope**.
- Returns summary + selected/detail fields, source lineage, staleness, release eligibility and export readiness.

- [ ] **Step 1: Add failing read-model tests**

Assert one shaped PO contains:

```json
{
  "supplier": {"id":"...","name":"..."},
  "service_date": "2026-09-02",
  "status": "DRAFT",
  "document_number": null,
  "is_stale": false,
  "release_allowed": true,
  "lines": [
    {
      "school": {"id":"...","name":"..."},
      "delivery_location": {"id":"...","name":"..."},
      "ingredient": {"id":"...","name":"..."},
      "quantity": "60.000000",
      "unit": {"id":"...","code":"kg"}
    }
  ]
}
```

Then create a successor Allocation Family revision and assert the old/current DRAFT read becomes:

```text
is_stale = true
release_allowed = false
disabled_reason_code = PO_DRAFT_STALE
```

without writing another PO revision during the read.

- [ ] **Step 2: Run RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
```

- [ ] **Step 3: Implement shaped read**

Staleness is derived by comparing each school-catering PO line revision's `purchase_allocation_supplier_split_id` to the currently accepted family revision/split for that family/supplier. Re-check current supplier eligibility for release readiness.

Read status fields must distinguish:

```text
DRAFT_CURRENT
DRAFT_STALE
RELEASED_TO_SUPPLIER
```

while preserving authoritative root/revision status separately if needed.

- [ ] **Step 4: Run GREEN and commit**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
git add supabase/migrations/*_sc_proc_03_school_catering_purchase_orders.sql supabase/tests/sc_proc_03_school_catering_purchase_orders.sql docs/api/sc-proc-03-school-catering-purchase-orders.md
git commit -m "feat: add school catering PO read model"
```

---

### Task 4: Add independent PO release with automated official numbering

**Files:**
- Modify: SC-PROC-03 migration
- Modify: `supabase/tests/sc_proc_03_school_catering_purchase_orders.sql`
- Modify: `docs/api/sc-proc-03-school-catering-purchase-orders.md`
- Reference only: `supabase/tests/pa_05e_procurement_command_family.sql`

**Interfaces:**
- Produces: `atlas_api.release_school_catering_purchase_order(request jsonb) returns jsonb`
- Capability: `school_catering_purchase_order.release`
- Payload: `{ "purchase_order_id": "uuid", "purchase_order_revision_id": "uuid" }`
- The payload never accepts `document_number`.

- [ ] **Step 1: Add failing release tests**

Prove:

```text
current non-stale DRAFT releases
official number format = PO-YYYYMMDD-NNNN
first two 02/09 releases = PO-20260902-0001 and PO-20260902-0002
first 03/09 release = PO-20260903-0001
number stored once on root/released snapshot
exact replay returns same number/IDs
concurrent distinct releases on same date get distinct numbers
concurrent duplicate release yields one valid release + safe replay/conflict outcome
stale draft → PO_DRAFT_STALE, no number consumed/commit
supplier made inactive/ineligible before release → SUPPLIER_INELIGIBLE
already released → replay when same command identity; otherwise PO_ALREADY_RELEASED
no Planning or Allocation Family mutation
```

Do not assert gapless rollback behavior beyond “failed release does not create a released PO with a number”; sequence gaps are permitted by contract.

- [ ] **Step 2: Run RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
```

- [ ] **Step 3: Implement the release command**

Lock order should be deterministic:

```text
actor/security context
→ supplier
→ school-catering PO root/current revision/lines
→ source family roots/current revisions/splits
→ number-counter row for service date
→ receipt/event/audit completion
```

After all validation and before final update, allocate official number under the same transaction. Released revision/line content remains immutable; V1 provides no released amendment path.

- [ ] **Step 4: Run SC-PROC-03 and PA-05E regression GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
pnpm exec supabase test db supabase/tests/pa_05e_procurement_command_family.sql --local
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_sc_proc_03_school_catering_purchase_orders.sql supabase/tests/sc_proc_03_school_catering_purchase_orders.sql docs/api/sc-proc-03-school-catering-purchase-orders.md
git commit -m "feat: release numbered school catering POs"
```

---

### Task 5: Register SC-PROC-03 APIs and add bounded Supabase smoke coverage

**Files:**
- Modify: `docs/api/api-contracts.md`
- Modify: `docs/architecture/pa-06a-application-connection-contract.md`
- Modify: `scripts/atlas-staging-contract.mjs` and its test if this remains the canonical registry on current main
- Modify: `.github/workflows/supabase-integration.yml`

**Interfaces:**
- Adds exactly three public functions:

```text
create_school_catering_purchase_order_drafts
get_school_catering_purchase_orders
release_school_catering_purchase_order
```

- [ ] **Step 1: Register exactly the three APIs**

Update the canonical function registry/count and API catalogue. Do not add public numbering helpers.

- [ ] **Step 2: Add focused Draft smoke**

Add:

```bash
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
```

Do not replace the existing smoke with full certification.

- [ ] **Step 3: Run bounded backend certification once**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
pnpm exec supabase test db supabase/tests/pa_05e_procurement_command_family.sql --local
git diff --check
```

Expected: PASS/clean.

- [ ] **Step 4: Commit**

```bash
git add docs/api/api-contracts.md docs/architecture/pa-06a-application-connection-contract.md docs/api/sc-proc-03-school-catering-purchase-orders.md scripts/atlas-staging-contract.mjs scripts/atlas-staging-contract.test.mjs .github/workflows/supabase-integration.yml
git commit -m "docs: register school catering PO APIs"
```

Only stage changed files.

---

### Task 6: Extend connected Procurement API/model for PO lifecycle

**Files:**
- Modify: `src/modules/atlas/procurement/schoolCateringProcurementModel.ts`
- Modify: `src/modules/atlas/procurement/schoolCateringProcurementApi.ts`
- Modify: `src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts`
- Modify: `src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.ts`
- Modify: its test

**Interfaces:**
- Add API methods:

```ts
getPurchaseOrders(...): Promise<...>
createPurchaseOrderDrafts(request): Promise<...>
releasePurchaseOrder(request): Promise<...>
```

- Model types:

```ts
export type PurchaseOrderDisplayState =
  | "DRAFT_CURRENT"
  | "DRAFT_STALE"
  | "RELEASED_TO_SUPPLIER";

export type SchoolCateringPurchaseOrderRow = {
  purchaseOrderId: string;
  purchaseOrderRevisionId: string;
  version: number;
  supplier: { id: string; name: string };
  serviceDate: string;
  documentNumber: string | null;
  state: PurchaseOrderDisplayState;
  lineCount: number;
  deliveryLocationCount: number;
  isStale: boolean;
  releaseAllowed: boolean;
  disabledReasonCode: string | null;
};
```

- [ ] **Step 1: Write failing adapter/review tests**

Prove exact RPC names and payloads; release request must contain no `document_number`.

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.test.ts
```

- [ ] **Step 3: Implement model/API/review scenarios**

Add review states sufficient for:

```text
PO drafts current
PO draft stale
mixed ready/stale
released numbered POs
partial bulk release result
```

Do not add supplier acknowledgement states.

- [ ] **Step 4: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.test.ts
git add src/modules/atlas/procurement
git commit -m "feat: connect school catering PO APIs"
```

---

### Task 7: Add the `Đơn mua` workbench stage and date-range draft action

**Files:**
- Create: `src/modules/atlas/procurement/PurchaseOrderWorkbench.tsx`
- Create: `src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx`
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx`
- Modify: `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx`
- Modify: `src/styles.css`

**Interfaces:**
- Two active stages now exactly:

```text
Phân bổ nhà cung ứng
Đơn mua
```

- Draft command receives only selected `dateStart/dateEnd` from the Procurement scope control.
- School display filters are not sent to `createPurchaseOrderDrafts`.

- [ ] **Step 1: Write failing two-stage/draft tests**

Prove:

```text
switching stage preserves date range
Đơn mua groups date then supplier
Tạo đơn mua calls date-range command only
school filter does not appear in draft payload
partial date result shows created dates and blocked dates
Tạo lại đơn cần cập nhật uses the same date-range backend command against stale affected roots
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
```

- [ ] **Step 3: Implement table-first PO stage**

Recommended row hierarchy:

```text
02/09/2026
  NCC A · 18 dòng · 6 nơi giao · DRAFT
  NCC B · 12 dòng · 4 nơi giao · DRAFT
03/09/2026
  NCC A · PO-20260903-0001 · Đã phát hành
```

No editable quantity/supplier controls exist in PO detail. For changes, operator returns to `Phân bổ nhà cung ứng`.

- [ ] **Step 4: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
git add src/modules/atlas/procurement src/styles.css
git commit -m "feat: add Procurement purchase order workbench"
```

---

### Task 8: Add independent PO release and bulk-release convenience

**Files:**
- Modify: `src/modules/atlas/procurement/PurchaseOrderWorkbench.tsx`
- Modify: `src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx`

**Interfaces:**
- Single action: `Phát hành cho NCC` calls one release RPC.
- Bulk action: `Phát hành tất cả đơn sẵn sàng` or selected-row equivalent loops over eligible POs independently and records per-PO outcome.

- [ ] **Step 1: Write failing single/bulk release tests**

Prove:

```text
single release updates row with official number from authoritative readback
stale row release disabled
bulk action excludes non-ready POs
A success + B failure + C success results in A/C released and B error retained
frontend does not attempt rollback of successful A/C
no document number is generated client-side
```

Use mocked results:

```ts
releasePurchaseOrder
  .mockResolvedValueOnce(success("PO-20260902-0001"))
  .mockResolvedValueOnce(error("PO_DRAFT_STALE"))
  .mockResolvedValueOnce(success("PO-20260902-0002"));
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx
```

- [ ] **Step 3: Implement independent release loop**

Use stable PO IDs/revisions captured from current read. Process sequentially or with a small bounded concurrency that preserves deterministic result mapping; V1 recommendation is sequential to minimize race/debug complexity and supplier release traffic.

After each release result, refresh PO read once after the batch completes rather than once per item unless backend readback makes per-item refresh necessary.

- [ ] **Step 4: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx
git add src/modules/atlas/procurement/PurchaseOrderWorkbench.tsx src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx
git commit -m "feat: release supplier purchase orders"
```

---

### Task 9: Add supplier-facing print/PDF export without a new dependency

**Files:**
- Create: `src/modules/atlas/procurement/PurchaseOrderPrintView.tsx`
- Create: `src/modules/atlas/procurement/PurchaseOrderPrintView.test.tsx`
- Modify: `src/modules/atlas/procurement/PurchaseOrderWorkbench.tsx`
- Modify: `src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx`
- Modify: `src/styles.css`

**Interfaces:**
- Official print source: released PO detail only.
- Draft preview may print only with visible `BẢN NHÁP / DRAFT` marker.
- Official output uses server `documentNumber` and immutable released lines.
- Export action uses `window.print()` with a dedicated print region; operator chooses “Save as PDF” in browser print dialog.

- [ ] **Step 1: Write failing print-view tests**

Official released view must include:

```text
ĐƠN ĐẶT HÀNG
PO-20260902-0001
supplier name
service date
school/delivery location
ingredient
unit
quantity
XÁC NHẬN / signature area
```

Draft view must visibly include `BẢN NHÁP` and must not invent an official number.

- [ ] **Step 2: Run RED**

```bash
pnpm exec vitest run src/modules/atlas/procurement/PurchaseOrderPrintView.test.tsx
```

- [ ] **Step 3: Implement A4 print layout**

Use semantic HTML tables and CSS `@media print`. Reuse the existing Atlas font stack; do not add fonts or dependencies. The print region should be A4-friendly and avoid splitting a line row where possible.

Example print-only CSS intent:

```css
@media print {
  .atlas-no-print { display: none !important; }
  .purchase-order-print { display: block !important; }
  .purchase-order-print table { width: 100%; border-collapse: collapse; }
  .purchase-order-print tr { break-inside: avoid; }
}
```

Do not hardcode colors required for meaning; document remains legible in grayscale.

- [ ] **Step 4: Add print action**

`In / Lưu PDF` renders the selected PO print region and calls `window.print()` only after the current detail is loaded. No ZIP library or client-generated PDF binary in V1.

- [ ] **Step 5: Run GREEN and commit**

```bash
pnpm exec vitest run src/modules/atlas/procurement/PurchaseOrderPrintView.test.tsx src/modules/atlas/procurement/PurchaseOrderWorkbench.test.tsx
git add src/modules/atlas/procurement src/styles.css
git commit -m "feat: add supplier PO print export"
```

---

### Task 10: Add end-to-end cross-stage certification through released PO

**Files:**
- Create or extend: `supabase/tests/sc_proc_03_school_catering_purchase_orders.sql`
- Create: `src/modules/atlas/procurement/schoolCateringProcurement.integration.test.tsx`
- Modify only if needed: focused review fixtures

**Interfaces:**
- Certifies full V1 chain and upstream-change behavior.

- [ ] **Step 1: Add database full-chain pgTAP scenario**

Exercise authoritative backend chain:

```text
released school-catering Confirmed Need
→ release_school_catering_purchase_handoff
→ save/confirm supplier allocation
→ create PO drafts
→ release PO
```

Assert exact line quantity/unit/date/destination lineage back to Confirmed Need/Purchase Handoff.

- [ ] **Step 2: Add upstream-change/stale scenario**

Before PO release, construct a later valid source/handoff revision and prove:

```text
family allocation stale
old draft stale
old draft release fails
operator confirms rebalance successor
regenerate affected supplier/date draft
new draft releases
```

After release, construct a further source change and prove the released PO remains unchanged.

- [ ] **Step 3: Add frontend cross-stage integration test**

In review mode drive:

```text
Planning completion callback
→ Procurement allocation family
→ save split/default confirm
→ switch Đơn mua
→ create draft
→ release
→ official PO number visible
→ print view uses released number
```

This test should cross component stages rather than re-test every local control.

- [ ] **Step 4: Run focused integration GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
pnpm exec vitest run src/modules/atlas/procurement/schoolCateringProcurement.integration.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/tests/sc_proc_03_school_catering_purchase_orders.sql src/modules/atlas/procurement/schoolCateringProcurement.integration.test.tsx src/modules/atlas/procurement/reviewSchoolCateringProcurementApi.ts
git commit -m "test: certify school catering Procurement flow"
```

Only stage review fixture if changed.

---

### Task 11: Final bounded certification, Draft PR, and hosted acceptance

**Files:**
- Modify only files needed to address actual certification findings.

**Interfaces:**
- No new behavior; final review gate.

- [ ] **Step 1: Run one bounded local backend/frontend certification**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
pnpm exec supabase test db supabase/tests/sc_proc_03_school_catering_purchase_orders.sql --local
pnpm exec supabase test db supabase/tests/pa_05e_procurement_command_family.sql --local
pnpm exec vitest run src/modules/atlas/procurement src/modules/atlas/planning-inputs/confirmed-needs src/modules/atlas/AtlasApp.test.tsx
pnpm typecheck
pnpm build:review
git diff --check
```

Expected: all focused tests PASS; typecheck/build exit 0; diff clean. Do not repeatedly run the repository-wide Vitest suite locally.

- [ ] **Step 2: Push and create Draft PR**

Recommended title:

```text
SC-PROC-03: Complete school-catering supplier PO flow
```

PR body must state:

```text
Completes V1 through RELEASED_TO_SUPPLIER.
No supplier acknowledgement/revision/cancellation.
No Warehouse/Dispatch/Finance.
No external email/message send.
Official numbers are server generated at release.
PA-05E wholesale regression is required.
```

- [ ] **Step 3: Let GitHub Actions run comprehensive certification**

Required:

```text
Frontend CI → success
Supabase Smoke → success while Draft
Qodana → success or changed-file findings resolved
Cloudflare Pages → exact-head preview success
Supabase Full Integration → success when PR reaches the existing ready/non-Draft gate
```

- [ ] **Step 4: Hosted browser acceptance**

Inspect exact-head preview at **1366×768** and **1920×1080**:

```text
Phân bổ nhà cung ứng
rebalance state
Đơn mua grouping
create/regenerate draft
single release
mixed bulk release result
official PO number display
DRAFT print watermark
released print layout
page/local horizontal overflow
console warnings/errors
```

Also rehearse at least one realistic back-and-forth upstream change before PO release and confirm only affected family/PO draft becomes stale.

- [ ] **Step 5: Stop for user acceptance**

Do not merge until user approves the hosted V1 Procurement flow. Released-PO correction/supplier acknowledgement is a later separately designed slice.
