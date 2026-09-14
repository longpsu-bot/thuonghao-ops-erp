# Atlas UI vNext 06D-E Integration and Certification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge 06D-A/B/C/D across all seven connected workbenches, remove plain-text treatment from real operator commands, certify the exact frontend/backend boundary, and leave the existing #286 entrypoint cutover candidate ready for a separate rebase/re-certification decision.

**Architecture:** This is a closeout/certification slice, not a new feature layer. Use the shared 06D-A recipes to classify every remaining `utility` use by operator semantics, run full frontend and disposable Supabase regression certification, capture visual evidence at four standard viewports, and perform only read-only hosted verification. Do not merge, deploy production, or mutate Staging/live OPS.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Vitest 4.1.10, Storybook 10.5, Vite 8.1.4, pnpm 11.7.0, Supabase CLI 2.111.0, Cloudflare Pages branch previews.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Requires 06D-A/B/C/D to be individually green before this plan begins.
- No broad schema, RLS, Edge Function, Retool, or hosted business-data change. The
  Product Owner-approved document-freeze amendment below permits only the additive
  snapshot/read-model fields proven necessary by the document audit.
- Keep one dominant business action per active operator decision.
- Real textual business commands use `businessPrimary`, `secondary`, `tertiary`, or `destructive`; transparent `utility` is not a generic text-button style.
- Keep shell navigation, tabs, link-like navigation affordances, and the intentional circular Refresh behavior semantically intact.
- Production entrypoint PR #286 remains Draft/open/unmerged during 06D.
- Live OPS project `qnthofvccilhnefdcxnz` is a hard no-write/no-Atlas target.
- Atlas Staging `rnzxmxiiqgtdevzregff` verification is read-only; expected frontier remains `20260908225248_purchase_preparation_replacement_frontier` until a separately authorized backend change exists.
- No Production Supabase project creation or production environment activation belongs to 06D.

---

## 06D-E document-freeze amendment — 2026-09-14

This amendment supersedes the original task order without removing the original
convergence and certification tasks below. The Product Owner-provided right-hand
workbook layouts are controlling document requirements. Retool remains read-only
workflow evidence and must not be copied as architecture.

### Document-contract audit matrix

| Document                     | Current Atlas support                                                                                                                                                                         | Staff target requirement                                                                                                                                                                                                 | Existing authoritative field?                                                                                                                                         | Template-only change? | Read-model/snapshot change required?                                                                                                                                                                                          | Exact files/contracts affected                                                                                                                          |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Confirmed Need Shopping List | No staff Shopping List workbook exists. Confirmed Need already owns one canonical local draft and one authoritative `Lưu`; generated purchase review remains a separate preliminary artifact. | Per-date continuous table; School only on the first row of each group; no `X` markers or School-band rows; editable quantity/note; hidden stable Atlas identities; whole-workbook validation and local-draft-only apply. | Yes: batch/version, line/revision/decision, date, School, location, Ingredient, Unit, quantity and policy are already present. Returned line order is deterministic.  | Yes.                  | No backend delta. Validate import against the complete current workbench and reject every stale, missing, duplicate or mismatched row.                                                                                        | New Confirmed Need workbook module/tests; Confirmed Need controller/workbench; exporter injection through `AtlasVNextConnectedApp` and `AtlasVNextApp`. |
| Official supplier PO         | Released-only XLSX/PDF guard exists. `Tổng`, `Theo trường` and `Theo hàng` exist, but details use merged group bands/spacers and location text rather than immutable School facts.            | Preserve `Tổng` business structure; continuous detail tables; first-row School/Ingredient identity with blank continuation rows; dark headers; Supplier/date placement; exact quantities; authoritative School order.    | Supplier snapshot, date, Ingredient, Unit, exact quantity and location identity exist. Immutable School name/order and per-School released quantity breakdown do not. | No.                   | Add the smallest immutable released-line School breakdown snapshot and shaped read. Legacy released rows without the snapshot remain non-exportable; never reconstruct released School history from current masters in React. | `SCHOOL-CATERING-PROCUREMENT.v1`; one additive migration and focused pgTAP; procurement model, fixtures, exporters and tests.                           |
| School Dispatch / PXK        | Released/superseded-only individual XLSX/PDF guard exists. The current workbook is a simple four-column sheet with no sensory/signature hierarchy and no grouped export.                      | Seven-column PXK hierarchy, target widths/heights, Times New Roman, A4 portrait, sensory and processing columns, three-party signatures, and grouped immutable-snapshot output ordered by date/School.                   | Document number/date, School, location/address, note and exact lines are immutable. Immutable School display order and document header/company identity are absent.   | No.                   | Add the smallest School document-header configuration and immutable released header/display-order snapshot. Missing legacy snapshot fails closed; no hardcoded or mutable React lookup.                                       | `SCHOOL-DISPATCH-RELEASE.v1`; one additive migration and focused pgTAP; dispatch model, fixtures, exporters/tests and grouped-export UI callback.       |

The requested newer Retool `(2).json` was not present in the supplied attachment
directory. The retained February ZIP was therefore inspected directly. Its
`js_shop_Export.js`, Shopping List import, PO/PXK exporters and source SQL confirm
School display ordering, supplier/date grouping, editable local import, grouped
packaging and `contract_type`-selected PXK headers. The supplied right-hand XLSX
layouts override those legacy template choices.

### Amended execution order

#### A. Document-contract audit

- [x] Inspect the three left/current and right/staff-target workbook halves.
- [x] Compare current Atlas exporters, retained Retool evidence and authoritative
      read models.
- [x] Freeze the matrix above before source changes.

#### B. Confirmed Need Shopping List XLSX freeze

- [x] Write failing structural and round-trip tests first.
- [x] Implement exact full-batch export with staff-visible columns and hidden Atlas
      identity/context columns.
- [x] Implement whole-workbook parse/validation and local-draft-only apply.
- [x] Integrate explicit `Xuất Excel` / `Nhập Excel` actions while retaining normal
      `Lưu` as the sole backend persistence command.
- [x] Preserve `generatedPurchaseReviewExport.ts` as a separate preliminary output.

#### C. Official PO document freeze

- [x] Add focused failing pgTAP and TypeScript tests for immutable School breakdown
      authority and target workbook structure.
- [x] Add only the additive released-line School snapshot/read-model correction
      proven necessary by the audit.
- [x] Rebuild `Theo trường` and `Theo hàng` as compact continuous target layouts;
      retain the existing `Tổng` business structure.
- [x] Align PDF hierarchy with the same released facts and keep the released-only
      guard unchanged.

#### D. School Dispatch / PXK document freeze

- [x] Add focused failing pgTAP and TypeScript tests for document-header snapshot,
      School ordering, target XLSX geometry and released-only grouped export.
- [x] Add only the additive School header configuration and immutable released
      header/order snapshot proven necessary by the audit.
- [x] Match the supplied seven-column A4 portrait PXK layout and three-party
      signature block deliberately.
- [x] Implement grouped workbook export over authoritative released/superseded
      snapshots ordered by service date and immutable School display order.
- [x] Align PDF hierarchy with the approved PXK document hierarchy.

#### E. vNext exporter integration

- [x] Inject Shopping List, PO and PXK callbacks from `AtlasVNextConnectedApp`.
- [x] Keep presentation components free of heavy exporter imports and never run an
      exporter automatically.

#### F. Utility-command convergence

- [x] Execute original Task 1 below after document actions are integrated.

#### G. Full frontend certification

- [ ] Execute original Task 2 plus focused document tests.

#### H. Backend/Supabase certification

- [x] Run focused pgTAP/security/currentness tests and
      `pnpm certify:supabase:full-integration` once on the exact final head.
- [x] Do not deploy the new migration to Staging in this task.

#### I. Final four-viewport Product acceptance

- [x] Execute original Task 3 for all seven modules and additionally verify Shopping
      List local-draft import, released-only PO/PXK exports and grouped PXK workflow.
- [x] Generate deterministic workbooks and visually compare them with the supplied
      right-hand targets; record current output, target, differences and disposition.

#### J. Exact-head preview / PR closeout

- [ ] Execute original Task 5 for PR #288, require exact local/origin SHA equality,
      Frontend CI and Cloudflare success, and update the PR body with document audit,
      freezes, authority delta, certification, safety and limitations.
- [ ] Keep PR #288 Draft/open/unmerged. Do not mark Ready.

#### K. Stop before #288 merge

- [ ] Do not merge #288 and do not start or modify #286.
- [ ] End only as `UI_PRODUCT_ACCEPTANCE_READY` or `BLOCKED`, followed by
      `NEXT_GATE: STOP_BEFORE_PR_288_MERGE`.

---

### 2026-09-14 certification evidence

- Deterministic document evidence is stored outside the repository under the
  task-local `document-acceptance` directory. The Shopping List matches the
  supplied right-hand continuous School-first layout; differences are fixture date
  and row volume only. The PO retains `Tổng` and matches the continuous `Theo
trường` / `Theo hàng` hierarchy with the supplied logo; differences are fixture
  business values only. PXK matches the seven-column A4 portrait hierarchy,
  sensory/processing columns, issuer header/logo, document number and signatures;
  differences are fixture business values and row volume only. Disposition: PASS.
- The review harness produced 32 captures: all seven shell modules plus both
  Planning phases at 1366×768, 1440×900, 1920×1080 and 360×800. Every capture had
  document `scrollWidth <= clientWidth` and zero application console/page errors.
  One repeatable `HTMLElement.focus` exception originates in Storybook's own
  instrumented iframe bundle and is retained separately as a harness-only warning.
- The browser-asset audit found zero secret/service-role/JWT/database-URL patterns,
  zero live OPS project references and zero embedded Supabase project URLs or
  publishable keys in `dist` and `storybook-static`. Generic `service_role` strings
  inside the bundled Supabase client library are not credentials.
- Direct Supabase CLI access from this worktree was unavailable because the stored
  management session returned 401. Read-only GitHub deployment evidence shows the
  latest Atlas Staging deployment is successful at
  `147648712ce57355d66773edd45a5e3ecd6458c9`; that deployed tree has exactly 72
  migrations ending at
  `20260908225248_purchase_preparation_replacement_frontier`, and no later Staging
  deployment run exists. No Staging or live write was performed.
- `pnpm certify:supabase:full-integration` passes. The exact `pnpm
certify:frontend` command reaches its parallel Vitest phase but exceeds this
  host's resource envelope; no timeout was weakened. The unchanged serial suite
  passes 143 files / 1771 tests, and typecheck, Vite build and Storybook build pass.
  Exact-head GitHub Frontend CI remains the authoritative parallel gate.

---

### Task 1: Classify every remaining transparent utility control

**Files:**

- Modify as required under: `src/vnext/atlas/**`
- Test: `src/vnext/atlas/AtlasConvergence.test.tsx`
- Test: existing workbench tests touched by each variant change.

**Interfaces:**

- Consumes: 06D-A button variants.
- Produces: no ordinary operator command rendered as visually plain text by default.

- [x] **Step 1: Capture the exact remaining utility inventory**

Run:

```bash
rg -n 'variant="utility"' src/vnext/atlas
```

Classify every match before editing:

```text
KEEP_UTILITY_NAVIGATION  — shell navigation, compact navigator-only affordance
KEEP_ICON_UTILITY        — routine Refresh or icon-only close/calendar utility
CHANGE_TERTIARY          — low-emphasis real command: Xem, Sửa, Đóng, Kiểm tra, Bỏ
CHANGE_SECONDARY         — supporting command: Xuất, Áp dụng, Xem trước, Thêm when not dominant
CHANGE_PRIMARY           — sole dominant current business command only
```

Known baseline textual utility sites requiring review include:

```text
src/vnext/atlas/recipes/DishCatalogue.tsx
src/vnext/atlas/recipes/DishRecipeWorkbench.tsx
src/vnext/atlas/recipes/ChangeOrderWorkbench.tsx
src/vnext/atlas/recipes/ChangeOrderDetail.tsx
src/vnext/atlas/master-data/IngredientCatalogue.tsx
src/vnext/atlas/master-data/SupplierCatalogue.tsx
src/vnext/atlas/master-data/SupplierDetail.tsx
src/vnext/atlas/master-data/IngredientPriorityEditor.tsx
src/vnext/atlas/dispatch/SchoolPxkTable.tsx
src/vnext/atlas/dispatch/SchoolPxkDetail.tsx
src/vnext/atlas/planning/PlanningSourceReview.tsx
src/vnext/atlas/AtlasSchoolScope.tsx
src/vnext/atlas/AtlasVNextShell.tsx
```

Do not change a match merely because it appears in this list; apply operator semantics.

- [x] **Step 2: Add convergence regression for real command surfaces**

Verify representative controls by accessible name plus emitted CSS/variant semantics:

```text
School Defaults: Lưu thay đổi → businessPrimary
Ingredient row: Xem / sửa → tertiary
Recipe locked forward action: Tạo lệnh điều chỉnh → secondary
Planning Review: Đóng/Quay lại → tertiary or secondary according to hierarchy
PXK export → secondary
```

Also assert shell navigation remains navigation, not business-primary treatment.

- [x] **Step 3: Run convergence test and confirm remaining failures**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: FAIL only where textual business commands still use transparent `utility`.

- [x] **Step 4: Apply the smallest semantic variant changes**

Examples:

```tsx
<Button variant="tertiary" size="sm">Xem / sửa</Button>
<Button variant="secondary" size="sm">Xuất XLSX</Button>
<Button variant="tertiary" size="sm">Đóng</Button>
```

Do not simulate buttons with per-component background/radius props; use shared recipes.

- [x] **Step 5: Re-run affected tests and commit**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/master-data src/vnext/atlas/recipes src/vnext/atlas/planning src/vnext/atlas/dispatch src/vnext/atlas/reconciliation
pnpm typecheck
git add src/vnext/atlas
git commit -m "refactor(atlas): converge operator command affordance"
```

---

### Task 2: Run exact full frontend certification

**Files:**

- No source edits unless a failure is proven to originate in 06D changes.

- [x] **Step 1: Run focused 06D regressions**

```bash
pnpm exec vitest run \
  src/vnext/atlas/AtlasDateInput.test.tsx \
  src/vnext/atlas/AtlasRefreshButton.test.tsx \
  src/vnext/atlas/AtlasDesignLanguageReference.test.tsx \
  src/vnext/atlas/schools \
  src/vnext/atlas/master-data \
  src/vnext/atlas/recipes \
  src/vnext/atlas/planning \
  src/vnext/atlas/dispatch \
  src/vnext/atlas/reconciliation \
  src/vnext/atlas/AtlasConvergence.test.tsx \
  src/vnext/atlas/AtlasModuleExit.test.tsx \
  src/vnext/atlas/AtlasPageTransition.test.tsx
```

Expected: PASS.

- [ ] **Step 2: Run authoritative frontend certification once**

```bash
pnpm certify:frontend
```

Expected: PASS. If local resource-sensitive tests time out, do not raise timeout budgets or edit unrelated tests. Differentially reproduce against the pre-06D baseline under equivalent conditions before classifying a regression.

- [x] **Step 3: Run explicit structural/build checks**

```bash
pnpm ui:vnext:typegen
pnpm ui:vnext:check
pnpm typecheck
pnpm build
pnpm build-storybook
pnpm exec prettier --check src/vnext/atlas docs/ui/atlas-vnext-design-language-v1.md
git diff --check
```

Expected: PASS.

- [x] **Step 4: Audit browser assets**

Require:

```text
no service-role/secret key patterns
no live OPS project ref qnthofvccilhnefdcxnz
no unexpected staging credential material
no Mantine presentation dependency newly introduced by 06D
```

Publishable browser configuration/project refs are not privileged secrets; service-role/secret keys are.

---

### Task 3: Capture final Product visual acceptance across the seven shell modules

**Files:**

- No repository screenshot commits. Store review evidence outside the public repo or as safe CI artifacts only.

- [x] **Step 1: Use the existing local vNext review harness**

Review shell modules:

```text
schools
ingredients-suppliers
recipes
planning
procurement
pxk
reconciliation
```

Within Planning, cover both `Nguồn lập nhu cầu` and `Xác nhận nhu cầu` peer phases. Use:

```text
1366×768
1440×900
1920×1080
360×800
```

- [x] **Step 2: Verify the six owner PPT findings**

```text
PPT-1 School Defaults: direct Lưu, #, explicit status
PPT-2 Ingredient/Supplier: stable attached 62/38 detail
PPT-3 Recipe: new duplicate ADD blocked with explicit adjustment transition
PPT-4 Recipe: lock state and forward action unmistakable
PPT-5 Menu: complete active Dish Type columns, local horizontal scroll
PPT-6 Pantry: School on every line, aligned fields, Ghi chú/Lý do semantics
```

- [x] **Step 3: Verify cross-cutting 06D interaction grammar**

```text
Vietnamese calendar opens from field and icon
Vietnamese month/day labels; Monday-first week
dd/mm/yyyy visible; ISO state retained
selected date and today visually distinct
calendar overlay not clipped and remains under Atlas portal/theme scope
button roles visibly surfaced at rest
8px normal controls; Refresh remains circular
hover/pressed/focus/disabled states distinct
no document-wide horizontal overflow
reduced motion suppresses sanctioned detail/page animations
no console warnings/errors attributable to 06D
```

- [x] **Step 4: Stop on any Product acceptance failure**

Fix only inside the relevant 06D boundary, rerun focused tests, then repeat the affected viewport review.

---

### Task 4: Certify the backend boundary without changing it

**Files:**

- No backend/source changes expected.

- [x] **Step 1: Run disposable Supabase Full Integration once on exact final 06D head**

```bash
pnpm certify:supabase:full-integration
```

Expected: PASS with zero backend changes.

If Docker cannot start, prove the local Docker/Linux engine is unavailable, then use the repository's existing GitHub Supabase Integration workflow on the exact 06D head. Do not modify scripts/workflow to bypass infrastructure.

- [x] **Step 2: Recheck Staging read-only**

Require:

```text
migration count: 72
frontier: 20260908225248_purchase_preparation_replacement_frontier
```

No migration, fixture import, business command, Auth mutation, or staging data repair is authorized.

- [x] **Step 3: Confirm live OPS isolation**

Require environment guards still reject:

```text
qnthofvccilhnefdcxnz
```

No Atlas connection to live OPS is added.

---

### Task 5: Exact-head branch preview and final 06D state

**Files:**

- No production deployment changes unless the existing branch-preview path is demonstrably broken by 06D.

- [ ] **Step 1: Push exact 06D head and wait for Frontend CI**

```bash
git status --short
git push origin HEAD
```

Require local/origin SHA equality, clean worktree, and exact-head Frontend CI success.

- [ ] **Step 2: Inspect Cloudflare branch preview**

Require:

```text
correct 06D styles
no console errors
no document-wide overflow desktop/mobile
no privileged secrets in browser assets
```

If staging browser credentials remain unavailable, record `STAGING_BROWSER_AUTH_NOT_AVAILABLE`; do not request/expose passwords just to clear 06D.

- [ ] **Step 3: Record final state**

Use exactly one:

```text
UI_PRODUCT_ACCEPTANCE_READY
BLOCKED
```

`UI_PRODUCT_ACCEPTANCE_READY` requires focused tests, full frontend certification, exact-head Supabase integration, four-viewport Product acceptance, and zero unauthorized backend/hosted writes.

---

### Task 6: Prepare #286 for a separate cutover re-certification; do not merge it

**Files:**

- Draft PR #286 branch only after 06D is separately merged to `main` and owner explicitly authorizes updating that candidate.

- [ ] **Step 1: Stop at the 06D merge gate**

Do not rebase #286 while 06D remains a Draft implementation PR. Report exact 06D head and wait for explicit merge authorization.

- [ ] **Step 2: After authorized 06D merge, rebase/recreate #286 from new exact `main`**

Preserve its three-file intent:

```text
src/main.tsx
index.html
src/productionEntrypoint.test.ts
```

If domain/workbench changes appear in #286, classify `VNEXT06C_SCOPE_DRIFT` and stop.

- [ ] **Step 3: Re-run #286 cutover certification**

```bash
pnpm exec vitest run src/productionEntrypoint.test.ts src/vnext/atlas/AtlasPageTransition.test.tsx
pnpm certify:frontend
pnpm build
```

Also rerun exact-head Supabase Full Integration, preview, environment rejection, secret audit, and rollback proof as established in 06C/06C1.

- [ ] **Step 4: Leave #286 Draft/open/unmerged**

`ENTRYPOINT_CANDIDATE_READY` after 06D re-certification still does not authorize merge or Atlas Production backend activation.

## 06D Final Exit Gate

```text
06D-A shared interaction         PASS
06D-B master data                PASS
06D-C Recipe                     PASS
06D-D Planning                   PASS
Utility-command convergence      PASS
Full frontend certification      PASS
Supabase exact-head integration  PASS
Four-viewport Product acceptance PASS
Staging read-only frontier       PASS
Hosted business writes           ZERO
UI_PRODUCT_ACCEPTANCE_READY       YES
PR #286 merged                    NO
```
