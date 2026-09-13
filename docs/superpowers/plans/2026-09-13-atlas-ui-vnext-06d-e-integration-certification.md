# Atlas UI vNext 06D-E Integration and Certification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge 06D-A/B/C/D across all seven connected workbenches, remove plain-text treatment from real operator commands, certify the exact frontend/backend boundary, and leave the existing #286 entrypoint cutover candidate ready for a separate rebase/re-certification decision.

**Architecture:** This is a closeout/certification slice, not a new feature layer. Use the shared 06D-A recipes to classify every remaining `utility` use by operator semantics, run full frontend and disposable Supabase regression certification, capture visual evidence at four standard viewports, and perform only read-only hosted verification. Do not merge, deploy production, or mutate Staging/live OPS.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Vitest 4.1.10, Storybook 10.5, Vite 8.1.4, pnpm 11.7.0, Supabase CLI 2.111.0, Cloudflare Pages branch previews.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Requires 06D-A/B/C/D to be individually green before this plan begins.
- No schema, migration, RLS, RPC, Edge Function, domain-contract, Retool, or hosted business-data change.
- Keep one dominant business action per active operator decision.
- Real textual business commands use `businessPrimary`, `secondary`, `tertiary`, or `destructive`; transparent `utility` is not a generic text-button style.
- Keep shell navigation, tabs, link-like navigation affordances, and the intentional circular Refresh behavior semantically intact.
- Production entrypoint PR #286 remains Draft/open/unmerged during 06D.
- Live OPS project `qnthofvccilhnefdcxnz` is a hard no-write/no-Atlas target.
- Atlas Staging `rnzxmxiiqgtdevzregff` verification is read-only; expected frontier remains `20260908225248_purchase_preparation_replacement_frontier` until a separately authorized backend change exists.
- No Production Supabase project creation or production environment activation belongs to 06D.

---

### Task 1: Classify every remaining transparent utility control

**Files:**
- Modify as required under: `src/vnext/atlas/**`
- Test: `src/vnext/atlas/AtlasConvergence.test.tsx`
- Test: existing workbench tests touched by each variant change.

**Interfaces:**
- Consumes: 06D-A button variants.
- Produces: no ordinary operator command rendered as visually plain text by default.

- [ ] **Step 1: Capture the exact remaining utility inventory**

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

- [ ] **Step 2: Add convergence regression for real command surfaces**

Verify representative controls by accessible name plus emitted CSS/variant semantics:

```text
School Defaults: Lưu thay đổi → businessPrimary
Ingredient row: Xem / sửa → tertiary
Recipe locked forward action: Tạo lệnh điều chỉnh → secondary
Planning Review: Đóng/Quay lại → tertiary or secondary according to hierarchy
PXK export → secondary
```

Also assert shell navigation remains navigation, not business-primary treatment.

- [ ] **Step 3: Run convergence test and confirm remaining failures**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: FAIL only where textual business commands still use transparent `utility`.

- [ ] **Step 4: Apply the smallest semantic variant changes**

Examples:

```tsx
<Button variant="tertiary" size="sm">Xem / sửa</Button>
<Button variant="secondary" size="sm">Xuất XLSX</Button>
<Button variant="tertiary" size="sm">Đóng</Button>
```

Do not simulate buttons with per-component background/radius props; use shared recipes.

- [ ] **Step 5: Re-run affected tests and commit**

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

- [ ] **Step 1: Run focused 06D regressions**

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

- [ ] **Step 3: Run explicit structural/build checks**

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

- [ ] **Step 4: Audit browser assets**

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

- [ ] **Step 1: Use the existing local vNext review harness**

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

- [ ] **Step 2: Verify the six owner PPT findings**

```text
PPT-1 School Defaults: direct Lưu, #, explicit status
PPT-2 Ingredient/Supplier: stable attached 62/38 detail
PPT-3 Recipe: new duplicate ADD blocked with explicit adjustment transition
PPT-4 Recipe: lock state and forward action unmistakable
PPT-5 Menu: complete active Dish Type columns, local horizontal scroll
PPT-6 Pantry: School on every line, aligned fields, Ghi chú/Lý do semantics
```

- [ ] **Step 3: Verify cross-cutting 06D interaction grammar**

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

- [ ] **Step 4: Stop on any Product acceptance failure**

Fix only inside the relevant 06D boundary, rerun focused tests, then repeat the affected viewport review.

---

### Task 4: Certify the backend boundary without changing it

**Files:**
- No backend/source changes expected.

- [ ] **Step 1: Run disposable Supabase Full Integration once on exact final 06D head**

```bash
pnpm certify:supabase:full-integration
```

Expected: PASS with zero backend changes.

If Docker cannot start, prove the local Docker/Linux engine is unavailable, then use the repository's existing GitHub Supabase Integration workflow on the exact 06D head. Do not modify scripts/workflow to bypass infrastructure.

- [ ] **Step 2: Recheck Staging read-only**

Require:

```text
migration count: 72
frontier: 20260908225248_purchase_preparation_replacement_frontier
```

No migration, fixture import, business command, Auth mutation, or staging data repair is authorized.

- [ ] **Step 3: Confirm live OPS isolation**

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
